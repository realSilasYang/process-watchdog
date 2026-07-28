#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证共享工作门只允许一个后台操作进入，并能在异常后可靠释放。
; 防止普通轮询与升级保护并发改写同一目标，也防止工作门永久卡住。

#Include ..\..\src\Core\GuardWorkGate.ahk
#Include ..\..\src\Core\GuardMutationQueue.ahk

AssertGuardWorkGate(value, message) {
    if !value
        throw Error(message)
}

RecordGuardMutation(records, value) {
    records.Push(value)
}

ThrowGuardMutationError(*) {
    throw Error("预期的配置变更异常")
}

RecordGuardMutationError(errors, operationError, description) {
    errors.Push(operationError.Message "|" description)
}

class GuardMutationOwner {
}

class FailingArmGuardMutationQueue extends GuardMutationQueue {
    Arm(*) {
        this.LastError := Error("模拟定时器创建失败")
        return false
    }
}

class RetryFailingGuardMutationQueue extends GuardMutationQueue {
    __New(parameters*) {
        super.__New(parameters*)
        this.ArmAttempts := 0
    }

    Arm(*) {
        this.ArmAttempts++
        this.LastError := Error("模拟重试定时器创建失败")
        return false
    }
}

RunGuardWorkGateTests() {
    gate := GuardWorkGate()
    AssertGuardWorkGate(gate.TryEnter(), "空闲工作门无法获取")
    AssertGuardWorkGate(gate.Busy, "工作门获取后没有进入忙碌状态")
    AssertGuardWorkGate(!gate.TryEnter(), "工作门允许重复进入")
    gate.Leave()
    AssertGuardWorkGate(!gate.Busy && gate.TryEnter(),
        "工作门释放后无法重新进入")
    gate.Leave()

    Critical("On")
    try {
        AssertGuardWorkGate(gate.TryEnter(), "临界线程无法获取工作门")
        AssertGuardWorkGate(A_IsCritical != 0,
            "工作门获取破坏了调用方的临界状态")
        gate.Leave()
        AssertGuardWorkGate(A_IsCritical != 0,
            "工作门释放破坏了调用方的临界状态")
    } finally Critical("Off")

    records := []
    errors := []
    queue := GuardMutationQueue(gate,
        RecordGuardMutationError.Bind(errors), false)
    queue.Enqueue(RecordGuardMutation.Bind(records, "first"), "一")
    queue.Enqueue(RecordGuardMutation.Bind(records, "second"), "二")
    AssertGuardWorkGate(gate.TryEnter(), "无法建立队列竞争测试前置状态")
    AssertGuardWorkGate(!queue.Drain() && queue.Count == 2,
        "工作门繁忙时配置队列丢失了待处理操作")
    gate.Leave()
    AssertGuardWorkGate(queue.Drain() && records.Length == 1
        && records[1] == "first" && queue.Count == 1,
        "配置队列没有按先进先出顺序执行首项")
    AssertGuardWorkGate(queue.Drain() && records.Length == 2
        && records[2] == "second" && queue.Count == 0,
        "配置队列没有执行第二项或残留了已完成操作")

    queue.Enqueue(ThrowGuardMutationError, "异常操作")
    queue.Enqueue(RecordGuardMutation.Bind(records, "after-error"))
    AssertGuardWorkGate(queue.Drain() && errors.Length == 1
        && InStr(errors[1], "预期的配置变更异常|异常操作"),
        "配置变更异常没有送达统一错误处理器")
    AssertGuardWorkGate(queue.Drain()
        && records[records.Length] == "after-error",
        "单项配置变更异常阻断了后续队列")

    exclusiveOwner := GuardMutationOwner()
    AssertGuardWorkGate(queue.EnqueueExclusive(exclusiveOwner, "save",
            RecordGuardMutation.Bind(records, "exclusive"), "排他保存")
        && queue.ExclusiveCount == 1,
        "排他配置变更没有登记所有者与操作键")
    AssertGuardWorkGate(!queue.EnqueueExclusive(exclusiveOwner, "save",
            RecordGuardMutation.Bind(records, "duplicate")),
        "同一所有者的同一配置操作被重复排队")
    AssertGuardWorkGate(queue.EnqueueExclusive(exclusiveOwner, "resume",
            RecordGuardMutation.Bind(records, "parallel-kind")),
        "同一所有者的不同配置操作被错误合并")
    AssertGuardWorkGate(queue.Drain()
        && records[records.Length] == "exclusive"
        && queue.ExclusiveCount == 1,
        "排他配置操作执行后没有只释放对应操作键")
    AssertGuardWorkGate(queue.EnqueueExclusive(exclusiveOwner, "save",
            RecordGuardMutation.Bind(records, "exclusive-again")),
        "排他配置操作完成后无法再次提交")
    AssertGuardWorkGate(queue.Drain()
        && records[records.Length] == "parallel-kind",
        "不同操作键没有保持原有先进先出顺序")
    AssertGuardWorkGate(queue.Drain()
        && records[records.Length] == "exclusive-again"
        && queue.ExclusiveCount == 0,
        "排他配置操作队列执行完毕后仍残留操作键")

    AssertGuardWorkGate(queue.EnqueueExclusive(exclusiveOwner, "failure",
            ThrowGuardMutationError, "排他异常")
        && queue.Drain() && queue.ExclusiveCount == 0,
        "排他配置操作异常后没有可靠释放操作键")
    shutdownRecordStart := records.Length
    shutdownErrorStart := errors.Length
    queue.Enqueue(RecordGuardMutation.Bind(records, "shutdown-first"),
        "退出排空一")
    queue.Enqueue(ThrowGuardMutationError, "退出排空异常")
    queue.EnqueueExclusive(exclusiveOwner, "shutdown-exclusive",
        RecordGuardMutation.Bind(records, "shutdown-last"), "退出排空二")
    queue.Shutdown()
    AssertGuardWorkGate(queue.Count == 0 && queue.ExclusiveCount == 0
        && !queue.Drain(),
        "关闭配置队列后仍保留待处理操作或排他操作键")
    AssertGuardWorkGate(records.Length == shutdownRecordStart + 2
        && records[-2] == "shutdown-first"
        && records[-1] == "shutdown-last",
        "关闭配置队列时没有按顺序排空待处理操作")
    AssertGuardWorkGate(errors.Length == shutdownErrorStart + 1
        && InStr(errors[-1], "预期的配置变更异常|退出排空异常"),
        "退出排空中的单项异常没有隔离并送达统一错误处理器")

    failedArmErrors := []
    failedArmQueue := FailingArmGuardMutationQueue(gate,
        RecordGuardMutationError.Bind(failedArmErrors), true)
    AssertGuardWorkGate(!failedArmQueue.Enqueue(
            RecordGuardMutation.Bind(records, "must-not-run"),
            "定时器失败操作")
        && failedArmQueue.Count == 0
        && failedArmErrors.Length == 1,
        "配置变更定时器创建失败后仍遗留不可执行的队列项")
    failedExclusiveOwner := GuardMutationOwner()
    AssertGuardWorkGate(!failedArmQueue.EnqueueExclusive(
            failedExclusiveOwner, "save",
            RecordGuardMutation.Bind(records, "must-not-run-exclusive"),
            "排他定时器失败操作")
        && failedArmQueue.ExclusiveCount == 0,
        "排他配置变更入队失败后仍遗留操作键")

    retryErrors := []
    retryQueue := RetryFailingGuardMutationQueue(gate,
        RecordGuardMutationError.Bind(retryErrors), false)
    retryQueue.Pending.Push({Callback: RecordGuardMutation.Bind(records,
        "blocked"), Description: "门忙重试"})
    retryQueue.AutoArm := true
    AssertGuardWorkGate(gate.TryEnter(), "无法建立重试失败前置状态")
    AssertGuardWorkGate(!retryQueue.Drain(),
        "工作门繁忙时配置队列不应执行操作")
    gate.Leave()
    AssertGuardWorkGate(retryQueue.Count == 0
        && retryQueue.ArmAttempts == 1 && retryErrors.Length == 1,
        "重试定时器创建失败后仍保留永远无法执行的配置操作")
}

try {
    RunGuardWorkGateTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
