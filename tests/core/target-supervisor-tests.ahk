#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\..\src\Core\GuardTypes.ahk
#Include ..\..\src\Core\GuardStateMachine.ahk
#Include ..\..\src\Maintenance\MaintenanceStateMachine.ahk
#Include ..\..\src\Core\WatchdogScheduler.ahk
#Include ..\..\src\Core\RestartPolicy.ahk
#Include ..\..\src\Core\TargetSupervisor.ahk

class FakeSupervisorClock {
    __New(nowTicks := 0) {
        this.NowTicks := nowTicks
    }

    Call() {
        return this.NowTicks
    }

    Advance(elapsedMs) {
        this.NowTicks += elapsedMs
    }
}

AssertSupervisor(value, message) {
    if !value
        throw Error(message)
}

AssertSupervisorEqual(expected, actual, message) {
    if (expected != actual)
        throw Error(message "（预期 " expected "，实际 " actual "）")
}

RunRestartProbe(path, supervisor, task) {
    if supervisor.ConsumeScheduledTask(task, "Restart")
        supervisor.RestartProbeRuns++
}

RunVerifyProbe(path, supervisor, task) {
    if supervisor.ConsumeScheduledTask(task, "Verify")
        supervisor.VerifyProbeRuns++
}

RecordScheduledValue(values, value) {
    values.Push(value)
}

IncrementScheduledCounter(counter) {
    counter.Count++
}

ScheduleNestedTask(scheduler, clock, values) {
    values.Push("outer")
    scheduler.Schedule(TargetScheduledTask("Nested", 1),
        RecordScheduledValue.Bind(values, "inner"), clock.Call())
}

ShutdownSchedulerDuringCallback(scheduler, values) {
    values.Push("shutdown")
    scheduler.Shutdown()
}

RunTargetSupervisorTests() {
    fakeClock := FakeSupervisorClock(1000)
    scheduler := WatchdogScheduler(fakeClock, false)
    supervisor := TargetSupervisor({Enabled: 1, Scheduler: scheduler})
    supervisor.RestartProbeRuns := 0
    supervisor.VerifyProbeRuns := 0
    AssertSupervisorEqual(GuardPhase.Initializing, supervisor.Phase,
        "启用目标的初始守护阶段错误")
    AssertSupervisorEqual(MaintenancePhase.Normal,
        supervisor.MaintenanceMode, "控制器的升级保护初始阶段错误")
    supervisor.MaintenanceMode := MaintenancePhase.Arbitrating
    AssertSupervisor(supervisor.MaintenanceStateMachine.IsBlocking(),
        "控制器没有持有独立升级保护状态机")
    supervisor.MaintenanceMode := MaintenancePhase.Normal

    initialGeneration := supervisor.Generation
    restartTask := supervisor.ScheduleRestart("C:\Apps\Target.exe",
        RunRestartProbe, 30, fakeClock.Call())
    AssertSupervisor(supervisor.IsScheduledTaskCurrent(restartTask,
        "Restart"), "新建重启任务没有归属到控制器")
    AssertSupervisorEqual(GuardPhase.WaitingRestart, supervisor.Phase,
        "重启倒计时没有进入等待阶段")
    supervisor.CancelScheduledTasks()
    AssertSupervisor(restartTask.Cancelled, "取消时没有作废重启任务令牌")
    AssertSupervisor(supervisor.Generation > initialGeneration,
        "取消任务没有推进控制器代际")
    fakeClock.Advance(80)
    scheduler.RunDue()
    AssertSupervisorEqual(0, supervisor.RestartProbeRuns,
        "已取消的重启回调仍然执行")

    oldVerifyTask := supervisor.ScheduleVerification(
        "C:\Apps\Target.exe", RunVerifyProbe, 1000)
    currentVerifyTask := supervisor.ScheduleVerification(
        "C:\Apps\Target.exe", RunVerifyProbe, 30)
    AssertSupervisor(oldVerifyTask.Cancelled,
        "同一控制器的新验证任务没有淘汰旧任务")
    AssertSupervisor(supervisor.IsScheduledTaskCurrent(currentVerifyTask,
        "Verify"), "最新验证任务没有占有验证槽位")
    fakeClock.Advance(80)
    scheduler.RunDue()
    AssertSupervisorEqual(1, supervisor.VerifyProbeRuns,
        "最新验证任务没有且仅执行一次")
    AssertSupervisor(currentVerifyTask.Completed,
        "已执行验证任务没有标记完成")

    pausedSupervisor := TargetSupervisor({Enabled: 0,
        Scheduler: scheduler})
    AssertSupervisorEqual(GuardPhase.Paused, pausedSupervisor.Phase,
        "禁用目标的初始守护阶段错误")

    invalidRejected := false
    try pausedSupervisor.TransitionTo("Not-A-Guard-Phase")
    catch ValueError
        invalidRejected := true
    AssertSupervisor(invalidRejected, "状态机接受了未知守护阶段")

    fastRetry := RestartPolicy.NextAfterFailure(1, [1000, 3000, 5000])
    AssertSupervisorEqual(3000, fastRetry.DelayMs,
        "快速重试没有使用下一档延迟")
    AssertSupervisor(!fastRetry.CoolingDown,
        "未耗尽的重试序列错误进入冷却")
    cooledRetry := RestartPolicy.NextAfterFailure(3, [1000, 3000, 5000])
    AssertSupervisorEqual(5000, cooledRetry.DelayMs,
        "冷却恢复没有复用最后一档延迟")
    AssertSupervisor(cooledRetry.CoolingDown,
        "耗尽的重试序列没有进入冷却恢复")
    prolongedRetry := RestartPolicy.NextAfterFailure(100,
        [1000, 3000, 5000])
    AssertSupervisorEqual(5000, prolongedRetry.DelayMs,
        "长期恢复延迟越过了配置边界")
    scheduler.Shutdown()

    orderClock := FakeSupervisorClock(5000)
    orderScheduler := WatchdogScheduler(orderClock, false)
    executionOrder := []
    orderScheduler.Schedule(TargetScheduledTask("Test", 1),
        RecordScheduledValue.Bind(executionOrder, 3), 5300)
    orderScheduler.Schedule(TargetScheduledTask("Test", 1),
        RecordScheduledValue.Bind(executionOrder, 1), 5100)
    orderScheduler.Schedule(TargetScheduledTask("Test", 1),
        RecordScheduledValue.Bind(executionOrder, 2), 5100)
    orderClock.Advance(100)
    AssertSupervisorEqual(2, orderScheduler.RunDue(),
        "调度器没有一次执行全部到期任务")
    AssertSupervisorEqual("1,2", executionOrder[1] "," executionOrder[2],
        "最小堆没有按到期时间和入队顺序执行")
    orderClock.Advance(200)
    orderScheduler.RunDue()
    AssertSupervisorEqual(3, executionOrder[3],
        "较晚任务在错误时间执行")
    orderScheduler.Shutdown()

    nestedClock := FakeSupervisorClock(7000)
    nestedScheduler := WatchdogScheduler(nestedClock, false)
    nestedValues := []
    nestedScheduler.Schedule(TargetScheduledTask("Nested", 1),
        ScheduleNestedTask.Bind(nestedScheduler, nestedClock,
            nestedValues), nestedClock.Call())
    AssertSupervisorEqual(2, nestedScheduler.RunDue(),
        "任务回调中新入队的到期任务没有在同轮安全执行")
    AssertSupervisor(nestedValues.Length == 2
        && nestedValues[1] == "outer" && nestedValues[2] == "inner",
        "任务回调内调度破坏了最小堆顺序")
    nestedScheduler.Shutdown()

    shutdownClock := FakeSupervisorClock(8000)
    shutdownScheduler := WatchdogScheduler(shutdownClock, false)
    shutdownValues := []
    activeShutdownTask := TargetScheduledTask("Shutdown", 1)
    cancelledAfterShutdown := TargetScheduledTask("AfterShutdown", 1)
    shutdownScheduler.Schedule(activeShutdownTask,
        ShutdownSchedulerDuringCallback.Bind(shutdownScheduler,
            shutdownValues), shutdownClock.Call())
    shutdownScheduler.Schedule(cancelledAfterShutdown,
        RecordScheduledValue.Bind(shutdownValues, "unexpected"),
        shutdownClock.Call())
    AssertSupervisorEqual(1, shutdownScheduler.RunDue(),
        "回调内关闭调度器后仍执行了后续任务")
    AssertSupervisor(activeShutdownTask.Completed
        && !activeShutdownTask.Cancelled,
        "回调内关闭调度器破坏了当前任务的完成状态")
    AssertSupervisor(cancelledAfterShutdown.Cancelled
        && !cancelledAfterShutdown.Completed,
        "回调内关闭调度器没有取消队列中的后续任务")
    AssertSupervisor(shutdownScheduler.Stopped
        && !shutdownScheduler.Running
        && shutdownScheduler.Queue.Length == 0,
        "回调内关闭后调度器没有进入稳定停止状态")

    bulkClock := FakeSupervisorClock(10000)
    bulkScheduler := WatchdogScheduler(bulkClock, false)
    bulkCounter := {Count: 0}
    Loop 1000 {
        bulkScheduler.Schedule(TargetScheduledTask("Bulk", 1),
            IncrementScheduledCounter.Bind(bulkCounter),
            10000 + Mod(A_Index, 100))
    }
    bulkClock.Advance(100)
    bulkStarted := A_TickCount
    AssertSupervisorEqual(1000, bulkScheduler.RunDue(),
        "批量调度没有执行全部到期任务")
    bulkElapsed := A_TickCount - bulkStarted
    AssertSupervisorEqual(1000, bulkCounter.Count,
        "批量调度丢失了任务")
    AssertSupervisor(bulkElapsed < 3000,
        "1000 项调度执行耗时异常：" bulkElapsed " 毫秒")
    bulkScheduler.Shutdown()

    liveScheduler := WatchdogScheduler()
    liveSupervisor := TargetSupervisor({Enabled: 1,
        Scheduler: liveScheduler})
    liveSupervisor.VerifyProbeRuns := 0
    liveSupervisor.ScheduleVerification("C:\Apps\Live.exe",
        RunVerifyProbe, 30)
    liveDeadline := liveScheduler.Now() + 1000
    while (!liveSupervisor.VerifyProbeRuns
        && liveScheduler.Now() < liveDeadline)
        Sleep(20)
    AssertSupervisorEqual(1, liveSupervisor.VerifyProbeRuns,
        "共享调度器的实际单次计时器没有触发到期任务")
    liveScheduler.Shutdown()
}

try {
    RunTargetSupervisorTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
