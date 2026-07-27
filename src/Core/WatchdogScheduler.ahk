; 全应用共享的单定时器任务调度器。
; 待执行任务按截止时间维护在最小堆中，堆和定时器只在短临界区内修改；
; 回调在临界区外运行，并通过任务令牌与目标代际自行拒绝过期工作。

class WatchdogScheduler {
    __New(clock := "", autoArm := true, errorHandler := "") {
        this.Clock := clock
        this.AutoArm := !!autoArm
        this.ErrorHandler := errorHandler
        this.Queue := []
        this.NextSequence := 1
        this.Running := false
        this.Stopped := false
        this.LastError := ""
        this.TimerCallback := ObjBindMethod(this, "OnTimer")
    }

    Now() {
        return IsObject(this.Clock) ? this.Clock.Call()
            : DllCall("kernel32\GetTickCount64", "UInt64")
    }

    Schedule(task, taskCallback, dueTicks) {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if this.Stopped
                throw Error("调度器已停止")
            item := {
                Task: task,
                Callback: taskCallback,
                DueTicks: dueTicks,
                Sequence: this.NextSequence
            }
            this.NextSequence++
            task.Scheduler := this
            task.DueTicks := dueTicks
            this.HeapPush(item)
            shouldArm := this.AutoArm
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        if shouldArm && !this.ArmNext()
            throw (this.LastError is Error ? this.LastError
                : Error("无法挂载守护任务定时器"))
        return task
    }

    Cancel(task) {
        if !IsObject(task)
            return
        previousCritical := A_IsCritical
        Critical("On")
        try {
            task.Cancelled := true
            shouldArm := this.AutoArm
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        return !shouldArm || this.ArmNext()
    }

    RunDue(nowTicks := "") {
        if (nowTicks == "")
            nowTicks := this.Now()
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if this.Stopped || this.Running
                return 0
            this.Running := true
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        executed := 0
        try {
            Loop {
                item := ""
                previousCritical := A_IsCritical
                Critical("On")
                try {
                    this.DiscardInactiveHead()
                    if this.Stopped || !this.Queue.Length
                        || this.Queue[1].DueTicks > nowTicks
                        break
                    item := this.HeapPop()
                } finally {
                    Critical(previousCritical ? previousCritical : "Off")
                }
                task := item.Task
                if this.IsInactive(task)
                    continue
                executed++
                try item.Callback.Call()
                catch as taskError {
                    this.LastError := taskError
                    if IsObject(this.ErrorHandler)
                        try this.ErrorHandler.Call(taskError, task)
                }
                if !task.Cancelled
                    task.Completed := true
            }
        } finally {
            previousCritical := A_IsCritical
            Critical("On")
            try this.Running := false
            finally Critical(previousCritical ? previousCritical : "Off")
            if this.AutoArm
                this.ArmNext()
        }
        return executed
    }

    OnTimer(*) {
        this.RunDue()
    }

    ArmNext() {
        failedItems := []
        timerError := ""
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if this.Stopped || this.Running
                return true
            try {
                ; 先撤销旧截止时间，再按当前堆顶重新挂载。第二步一旦失败，
                ; 整个队列都已失去唤醒来源，必须统一失败而不能只取消新任务。
                this.SetSharedTimer(0)
                this.DiscardInactiveHead()
                if !this.Queue.Length
                    return true
                delayMs := Max(1, this.Queue[1].DueTicks - this.Now())
                this.SetSharedTimer(-Min(delayMs, 0x7FFFFFFF))
            } catch as armError {
                timerError := armError
                this.LastError := armError
                failedItems := this.Queue
                this.Queue := []
                for item in failedItems {
                    if IsObject(item.Task)
                        item.Task.Cancelled := true
                }
            }
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        if timerError is Error {
            for item in failedItems {
                if IsObject(this.ErrorHandler) {
                    try this.ErrorHandler.Call(timerError, item.Task)
                }
            }
            return false
        }
        return true
    }

    SetSharedTimer(period) {
        SetTimer(this.TimerCallback, period)
    }

    Shutdown() {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if this.Stopped
                return
            this.Stopped := true
            try this.SetSharedTimer(0)
            for item in this.Queue
                item.Task.Cancelled := true
            this.Queue := []
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
    }

    DiscardInactiveHead() {
        while this.Queue.Length && this.IsInactive(this.Queue[1].Task)
            this.HeapPop()
    }

    IsInactive(task) {
        return !IsObject(task) || task.Cancelled || task.Completed
    }

    HeapPush(item) {
        this.Queue.Push(item)
        index := this.Queue.Length
        while (index > 1) {
            parentIndex := Floor(index / 2)
            if !this.IsEarlier(this.Queue[index], this.Queue[parentIndex])
                break
            temporary := this.Queue[parentIndex]
            this.Queue[parentIndex] := this.Queue[index]
            this.Queue[index] := temporary
            index := parentIndex
        }
    }

    HeapPop() {
        if !this.Queue.Length
            return ""
        first := this.Queue[1]
        last := this.Queue.Pop()
        if this.Queue.Length {
            this.Queue[1] := last
            index := 1
            Loop {
                leftIndex := index * 2
                if (leftIndex > this.Queue.Length)
                    break
                rightIndex := leftIndex + 1
                earlierIndex := leftIndex
                if (rightIndex <= this.Queue.Length
                    && this.IsEarlier(this.Queue[rightIndex],
                        this.Queue[leftIndex]))
                    earlierIndex := rightIndex
                if !this.IsEarlier(this.Queue[earlierIndex],
                    this.Queue[index])
                    break
                temporary := this.Queue[index]
                this.Queue[index] := this.Queue[earlierIndex]
                this.Queue[earlierIndex] := temporary
                index := earlierIndex
            }
        }
        return first
    }

    IsEarlier(first, second) {
        return first.DueTicks < second.DueTicks
            || (first.DueTicks == second.DueTicks
                && first.Sequence < second.Sequence)
    }
}
