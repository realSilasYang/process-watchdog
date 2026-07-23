#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\..\src\Core\GuardTypes.ahk
#Include ..\..\src\Core\GuardStateMachine.ahk
#Include ..\..\src\Maintenance\MaintenanceStateMachine.ahk
#Include ..\..\src\Core\GuardWorkGate.ahk
#Include ..\..\src\Core\WatchdogScheduler.ahk
#Include ..\..\src\Core\RestartPolicy.ahk
#Include ..\..\src\Core\TargetSupervisor.ahk
#Include ..\..\src\Core\TargetSpecs.ahk
#Include ..\..\src\Inspection\ProcessSnapshotIndex.ahk
#Include ..\..\src\Core\GuardRuntime.ahk

class GuardRuntimeTestClock {
    __New(nowTicks := 0) {
        this.Ticks := nowTicks
    }

    Call() {
        return this.Ticks
    }
}

class GuardRuntimeFakeMaintenance {
    __New() {
        this.Blocking := false
        this.Stopped := false
    }

    IsBlocking(*) {
        return this.Blocking
    }

    StartTimers() {
        return true
    }

    ClearTargetMissing(*) {
        return false
    }

    Shutdown() {
        this.Stopped := true
    }
}

class GuardRuntimeFakeSnapshots {
    __New() {
        this.LatestSnapshotTicks := 0
    }

    Pump() {
        return false
    }

    GetIndex() {
        return ""
    }

    RequestFresh() {
        return 0
    }
}

class GuardRuntimeFakeLauncher {
    __New() {
        this.LaunchCount := 0
    }

    Launch(*) {
        this.LaunchCount++
        return {PID: 0}
    }
}

class GuardRuntimeTestContext {
    static Observation := ""
    static Status := ""
    static Logs := []
    static Runtime := ""
    static ReplacementOnObserve := ""
    static ThrowOnObserve := false
}

AssertGuardRuntime(condition, message) {
    if !condition
        throw Error(message)
}

AssertGuardRuntimeEqual(expected, actual, message) {
    if (expected != actual)
        throw Error(message "；预期=" expected "，实际=" actual)
}

GuardRuntimeNormalize(path) {
    return StrLower(path)
}

GuardRuntimeClearIdentity(stateObj, *) {
    stateObj.PID := 0
    stateObj.PIDCreationIdentity := ""
}

GuardRuntimeGetLogPath(*) {
    return ""
}

GuardRuntimeGetSpecs(*) {
    return ""
}

GuardRuntimeLog(message) {
    GuardRuntimeTestContext.Logs.Push(message)
}

GuardRuntimeLogSlow(*) {
}

GuardRuntimeObserve(path, *) {
    if GuardRuntimeTestContext.ThrowOnObserve
        throw Error("模拟探活异常")
    if GuardRuntimeTestContext.ReplacementOnObserve != "" {
        GuardRuntimeTestContext.Runtime.appStates[path] :=
            GuardRuntimeTestContext.ReplacementOnObserve
        GuardRuntimeTestContext.ReplacementOnObserve := ""
    }
    return GuardRuntimeTestContext.Observation
}

GuardRuntimeRefreshShortcut(*) {
    return false
}

GuardRuntimeSaveApps(*) {
}

GuardRuntimeSetIdentity(stateObj, pid) {
    stateObj.PID := pid
    stateObj.PIDCreationIdentity := "CREATION-" pid
}

GuardRuntimeIdentityValid(*) {
    return false
}

GuardRuntimeTargetExists(*) {
    return true
}

GuardRuntimeUpdateRunning(path, stateObj, *) {
    stateObj.State := "RUNNING:" path
}

GuardRuntimeUpdateState(path, statusText, *) {
    GuardRuntimeTestContext.Status := path "|" statusText
}

CreateGuardRuntimeSupervisor(scheduler) {
    stateObj := TargetSupervisor({Enabled: true})
    stateObj.Scheduler := scheduler
    stateObj.MaintenanceConfig := {Enabled: false}
    return stateObj
}

RunGuardRuntimeTests() {
    clock := GuardRuntimeTestClock(1000)
    scheduler := WatchdogScheduler(clock, false, "")
    maintenance := GuardRuntimeFakeMaintenance()
    launcher := GuardRuntimeFakeLauncher()
    states := Map()
    states.CaseSense := "Off"
    runtime := {
        appStates: states,
        appOrder: [],
        checkInterval: 2000,
        retryDelayArray: [5000, 30000],
        guardWorkGate: GuardWorkGate(),
        scheduler: scheduler,
        maintenanceCoordinator: maintenance,
        processSnapshots: GuardRuntimeFakeSnapshots(),
        targetLauncher: launcher
    }
    callbacks := {
        ClearProcessIdentity: GuardRuntimeClearIdentity,
        GetLogFilePath: GuardRuntimeGetLogPath,
        GetTargetSpecs: GuardRuntimeGetSpecs,
        Log: GuardRuntimeLog,
        LogSlow: GuardRuntimeLogSlow,
        NormalizeTargetPath: GuardRuntimeNormalize,
        ObserveTarget: GuardRuntimeObserve,
        RefreshShortcutIdentity: GuardRuntimeRefreshShortcut,
        SaveApps: GuardRuntimeSaveApps,
        SetProcessIdentity: GuardRuntimeSetIdentity,
        StateProcessIdentityIsValid: GuardRuntimeIdentityValid,
        TargetReferenceExists: GuardRuntimeTargetExists,
        UpdateRunningState: GuardRuntimeUpdateRunning,
        UpdateState: GuardRuntimeUpdateState
    }
    guard := GuardRuntime(runtime, callbacks)
    scheduler.ErrorHandler := ObjBindMethod(guard, "HandleTaskError")
    GuardRuntimeTestContext.Runtime := runtime

    path := "c:\apps\target.exe"
    stateObj := CreateGuardRuntimeSupervisor(scheduler)
    states[path] := stateObj
    runtime.appOrder.Push(path)
    AssertGuardRuntime(guard.IsSupervisorCurrent(path, stateObj,
        stateObj.Generation), "当前控制器未通过所有权校验")

    replacement := CreateGuardRuntimeSupervisor(scheduler)
    states[path] := replacement
    AssertGuardRuntime(!guard.IsSupervisorCurrent(path, stateObj,
        stateObj.Generation), "同路径替换后旧控制器仍通过校验")
    GuardRuntimeTestContext.Status := ""
    AssertGuardRuntime(!guard.UpdateState(path, stateObj, "旧状态")
        && GuardRuntimeTestContext.Status == "",
        "旧控制器仍能把状态写回同路径的新控制器")
    AssertGuardRuntime(guard.UpdateState(path, replacement, "新状态")
        && InStr(GuardRuntimeTestContext.Status, "新状态"),
        "当前控制器的状态更新被错误拒绝")
    AssertGuardRuntime(guard.ScheduleRestartFor(path, stateObj, 100) == ""
        && replacement.RestartTask == "",
        "旧控制器仍能给同路径的新控制器安排重启")
    AssertGuardRuntime(guard.ScheduleVerification(path, 100, stateObj) == ""
        && replacement.VerifyTask == "",
        "旧控制器仍能给同路径的新控制器安排验证")
    Critical("On")
    try {
        currentTask := guard.ScheduleRestartFor(path, replacement, 100)
        AssertGuardRuntime(currentTask is TargetScheduledTask
            && A_IsCritical != 0,
            "所有权调度破坏了调用方的临界状态")
    } finally Critical("Off")
    replacement.CancelScheduledTasks()
    states[path] := stateObj

    stateObj.Enabled := false
    stateObj.CancelScheduledTasks()
    AssertGuardRuntime(guard.ScheduleRestart(path, 100) == ""
        && guard.ScheduleVerification(path, 100) == ""
        && !guard.UpdateState(path, stateObj, "不应写入"),
        "已暂停控制器仍接受后台状态写入或调度任务")
    stateObj.Enabled := true

    AssertGuardRuntime(runtime.guardWorkGate.TryEnter(),
        "测试无法占用守护工作门")
    deferredTask := guard.ScheduleRestart(path, 0)
    scheduler.RunDue(clock.Ticks)
    AssertGuardRuntime(stateObj.RestartTask is TargetScheduledTask
        && stateObj.RestartTask != deferredTask,
        "工作门忙碌时没有重新排队重启任务")
    AssertGuardRuntimeEqual(clock.Ticks + 100,
        stateObj.RestartTask.DueTicks,
        "工作门忙碌后的重启退让时间错误")
    runtime.guardWorkGate.Leave()
    stateObj.CancelScheduledTasks()

    restartGeneration := stateObj.Generation
    blockedRestartTask := guard.ScheduleRestart(path, 0)
    AssertGuardRuntime(runtime.guardWorkGate.TryEnter(),
        "测试无法占用重启阻塞路径的守护工作门")
    maintenance.Blocking := true
    scheduler.RunDue(clock.Ticks)
    runtime.guardWorkGate.Leave()
    AssertGuardRuntime(blockedRestartTask.Cancelled
        && !blockedRestartTask.Completed,
        "升级保护切入后仍保留已到期的重启任务")
    AssertGuardRuntime(stateObj.RestartTask == ""
        && stateObj.VerifyTask == "",
        "升级保护切入后没有清空重启任务槽位")
    AssertGuardRuntime(stateObj.Generation > restartGeneration,
        "升级保护切入后没有作废旧重启任务代际")
    AssertGuardRuntime(stateObj.Pending && stateObj.TargetStartTicks == 0,
        "升级保护切入后没有清除重启倒计时")

    maintenance.Blocking := false
    blockedVerifyTask := guard.ScheduleVerification(path, 0)
    verifyGeneration := stateObj.Generation
    AssertGuardRuntime(runtime.guardWorkGate.TryEnter(),
        "测试无法占用验证阻塞路径的守护工作门")
    maintenance.Blocking := true
    scheduler.RunDue(clock.Ticks)
    runtime.guardWorkGate.Leave()
    AssertGuardRuntime(blockedVerifyTask.Cancelled
        && !blockedVerifyTask.Completed,
        "升级保护切入后仍保留已到期的验证任务")
    AssertGuardRuntime(stateObj.RestartTask == ""
        && stateObj.VerifyTask == "",
        "升级保护切入后没有清空验证任务槽位")
    AssertGuardRuntime(stateObj.Generation > verifyGeneration,
        "升级保护切入后没有作废旧验证任务代际")
    AssertGuardRuntime(stateObj.Pending && stateObj.TargetStartTicks == 0,
        "升级保护切入后没有清除验证倒计时")
    maintenance.Blocking := false

    GuardRuntimeTestContext.Observation := ProcessObservation.Unknown(
        1000, "snapshot-unavailable")
    firstTask := guard.ScheduleRestart(path, 0)
    AssertGuardRuntime(firstTask is TargetScheduledTask,
        "重启调度没有返回任务令牌")
    scheduler.RunDue(clock.Ticks)
    AssertGuardRuntimeEqual(0, launcher.LaunchCount,
        "未知探活结果仍触发了重复启动")
    AssertGuardRuntime(stateObj.RestartTask is TargetScheduledTask,
        "未知探活结果没有安排延迟复核")
    AssertGuardRuntimeEqual(clock.Ticks + 2000,
        stateObj.RestartTask.DueTicks,
        "未知探活后的延迟复核时间错误")

    staleTask := stateObj.RestartTask
    replacement := CreateGuardRuntimeSupervisor(scheduler)
    states[path] := replacement
    clock.Ticks += 2000
    scheduler.RunDue(clock.Ticks)
    AssertGuardRuntime(!replacement.Pending,
        "旧任务回调修改了同路径的新控制器")
    AssertGuardRuntime(staleTask.Completed,
        "调度器没有完成已失效的旧任务")

    states[path] := replacement
    maintenance.Blocking := true
    blockedTask := guard.ScheduleRestart(path, 5000)
    AssertGuardRuntime(blockedTask == "",
        "升级保护期间仍创建了重启任务")
    AssertGuardRuntime(replacement.Pending
        && replacement.TargetStartTicks == 0,
        "升级保护期间没有清除普通重启倒计时")

    maintenance.Blocking := false
    aliasPath := "target.exe"
    raceState := CreateGuardRuntimeSupervisor(scheduler)
    replacementAfterProbe := CreateGuardRuntimeSupervisor(scheduler)
    states.Clear()
    states[aliasPath] := raceState
    runtime.appOrder := [aliasPath]
    GuardRuntimeTestContext.Observation := ProcessObservation.Running(
        99, "CREATION-99", clock.Ticks, "test")
    GuardRuntimeTestContext.ReplacementOnObserve := replacementAfterProbe
    guard.MonitorTick()
    AssertGuardRuntimeEqual(0, raceState.PID,
        "探活期间被替换的旧控制器仍被写入运行身份")
    AssertGuardRuntime(states[aliasPath] == replacementAfterProbe,
        "探活期间创建的新控制器映射被旧结果覆盖")

    GuardRuntimeTestContext.ThrowOnObserve := true
    guard.MonitorTick()
    GuardRuntimeTestContext.ThrowOnObserve := false
    AssertGuardRuntime(!runtime.guardWorkGate.Busy,
        "探活异常后没有释放共享守护工作门")
    AssertGuardRuntime(GuardRuntimeTestContext.Logs.Length
        && InStr(GuardRuntimeTestContext.Logs[-1], "主进程监控异常"),
        "探活异常没有写入运行日志")
    guard.MonitorTick()
    AssertGuardRuntime(!runtime.guardWorkGate.Busy,
        "探活异常后的下一轮监控无法正常结束")

    guard.Shutdown()
    AssertGuardRuntime(scheduler.Stopped,
        "运行时关闭没有停止共享调度器")
    AssertGuardRuntime(maintenance.Stopped,
        "运行时关闭没有清理升级编排器")
    GuardRuntimeTestContext.ThrowOnObserve := true
    guard.MonitorTick()
    GuardRuntimeTestContext.ThrowOnObserve := false
    AssertGuardRuntime(guard.ScheduleRestart(path, 100) == ""
        && guard.ScheduleVerification(path, 100) == "",
        "运行时关闭后仍接受迟到轮次或新调度任务")
}

try {
    RunGuardRuntimeTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n", "**")
    ExitApp(1)
}
