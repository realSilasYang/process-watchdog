; 用户配置与守护后台任务之间的异步串行队列。
; 界面线程只提交已经捕获好的操作意图；队列在共享工作门空闲时逐项执行，
; 因而不会用 Sleep 等待后台任务，也不会让被中断的监控回调继续覆盖用户设置。

class GuardMutationQueue {
    __New(workGate, errorHandler := "", autoArm := true,
        retryDelayMs := 25) {
        if !(workGate is GuardWorkGate)
            throw TypeError("配置变更队列需要 GuardWorkGate")
        this.WorkGate := workGate
        this.ErrorHandler := errorHandler
        this.AutoArm := !!autoArm
        this.RetryDelayMs := Max(1, Integer(retryDelayMs))
        this.Pending := []
        this.ExclusiveOperations := Map()
        this.Draining := false
        this.Stopped := false
        this.LastError := ""
        this.TimerCallback := ObjBindMethod(this, "Drain")
    }

    Count {
        get => this.Pending.Length
    }

    ExclusiveCount {
        get => this.ExclusiveOperations.Count
    }

    Enqueue(callback, description := "", completionCallback := "") {
        if !IsObject(callback)
            throw TypeError("配置变更回调无效")
        if completionCallback != "" && !IsObject(completionCallback)
            throw TypeError("配置变更收尾回调无效")
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if this.Stopped
                return false
            operation := {Callback: callback,
                Description: String(description),
                CompletionCallback: completionCallback}
            this.Pending.Push(operation)
            shouldArm := this.AutoArm && !this.Draining
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        if shouldArm && !this.Arm(1) {
            previousCritical := A_IsCritical
            Critical("On")
            try {
                for index, pendingOperation in this.Pending {
                    if pendingOperation == operation {
                        this.Pending.RemoveAt(index)
                        break
                    }
                }
            } finally {
                Critical(previousCritical ? previousCritical : "Off")
            }
            this.CompleteOperation(operation)
            scheduleError := this.LastError is Error
                ? this.LastError : Error("无法创建配置变更定时器")
            if IsObject(this.ErrorHandler)
                try this.ErrorHandler.Call(scheduleError,
                    operation.Description)
            return false
        }
        return true
    }

    EnqueueExclusive(owner, operationKey, callback, description := "") {
        if !IsObject(owner)
            throw TypeError("排他配置变更所有者无效")
        if !IsObject(callback)
            throw TypeError("配置变更回调无效")
        key := Format("{:X}:{}", ObjPtr(owner),
            StrLower(String(operationKey)))
        token := {}
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if this.Stopped || this.ExclusiveOperations.Has(key)
                return false
            this.ExclusiveOperations[key] := token
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        completion := ObjBindMethod(this, "ReleaseExclusiveOperation",
            key, token)
        try queued := this.Enqueue(callback, description, completion)
        catch as enqueueError {
            this.ReleaseExclusiveOperation(key, token)
            throw enqueueError
        }
        if !queued
            this.ReleaseExclusiveOperation(key, token)
        return queued
    }

    ReleaseExclusiveOperation(key, token, *) {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if !this.ExclusiveOperations.Has(key)
                || this.ExclusiveOperations[key] != token
                return false
            this.ExclusiveOperations.Delete(key)
            return true
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
    }

    CompleteOperation(operation) {
        if !IsObject(operation)
            || !operation.HasOwnProp("CompletionCallback")
            || !IsObject(operation.CompletionCallback)
            return false
        completion := operation.CompletionCallback
        operation.CompletionCallback := ""
        try completion.Call()
        catch
            return false
        return true
    }

    Drain(*) {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if this.Stopped || this.Draining || !this.Pending.Length
                return false
            this.Draining := true
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }

        gateAcquired := false
        operation := ""
        try {
            gateAcquired := this.WorkGate.TryEnter()
            if !gateAcquired
                return false
            previousCritical := A_IsCritical
            Critical("On")
            try {
                if this.Stopped || !this.Pending.Length
                    return false
                operation := this.Pending.RemoveAt(1)
            } finally {
                Critical(previousCritical ? previousCritical : "Off")
            }
            try {
                try operation.Callback.Call()
                catch as operationError {
                    this.LastError := operationError
                    if IsObject(this.ErrorHandler) {
                        try this.ErrorHandler.Call(operationError,
                            operation.Description)
                    }
                }
            } finally this.CompleteOperation(operation)
            return true
        } finally {
            if gateAcquired
                this.WorkGate.Leave()
            previousCritical := A_IsCritical
            Critical("On")
            try {
                this.Draining := false
                shouldRetry := !this.Stopped && this.Pending.Length > 0
            } finally {
                Critical(previousCritical ? previousCritical : "Off")
            }
            if shouldRetry && this.AutoArm
                && !this.Arm(gateAcquired ? 1 : this.RetryDelayMs) {
                this.FailPendingAfterArmError()
            }
        }
    }

    FailPendingAfterArmError() {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            failedOperations := this.Pending
            this.Pending := []
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        scheduleError := this.LastError is Error
            ? this.LastError : Error("无法创建配置变更定时器")
        if IsObject(this.ErrorHandler) {
            for operation in failedOperations {
                this.CompleteOperation(operation)
                try this.ErrorHandler.Call(scheduleError,
                    operation.Description)
            }
        } else {
            for operation in failedOperations
                this.CompleteOperation(operation)
        }
        return failedOperations.Length
    }

    Arm(delayMs) {
        if this.Stopped
            return false
        try {
            SetTimer(this.TimerCallback, -Max(1, Integer(delayMs)))
            return true
        } catch as timerError {
            this.LastError := timerError
            return false
        }
    }

    Shutdown(flushPending := true) {
        pendingOperations := []
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if this.Stopped
                return 0
            this.Stopped := true
            pendingOperations := this.Pending
            this.Pending := []
            try SetTimer(this.TimerCallback, 0)
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        for operation in pendingOperations {
            try {
                if flushPending {
                    try operation.Callback.Call()
                    catch as operationError {
                        this.LastError := operationError
                        if IsObject(this.ErrorHandler) {
                            try this.ErrorHandler.Call(operationError,
                                operation.Description)
                        }
                    }
                }
            } finally this.CompleteOperation(operation)
        }
        return pendingOperations.Length
    }
}
