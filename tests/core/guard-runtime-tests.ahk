#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证守护运行时对探测、重试、暂停、升级保护和界面状态的协调。
; 重点构造过期控制器、代际和任务槽，证明迟到回调不会修改已经变化的守护项。

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

    TargetSubjectExists(*) {
        return true
    }

    CanSafelyLaunch(path, stateObj, &reason) {
        reason := ""
        return true
    }

    BeginArbitration(*) {
        return false
    }

    IsProtectionEnabled(*) {
        return false
    }

    HasRecentSignal(*) {
        return false
    }

    MarkTargetMissing(*) {
    }

    Enter(*) {
        return false
    }

    Shutdown() {
        this.Stopped := true
    }
}

class GuardRuntimeFakeSnapshots {
    __New(clock) {
        this.Clock := clock
        this.LatestSnapshotTicks := 0
        this.LatestSnapshotRequestTicks := 0
        this.RequestCount := 0
        this.RequestEnabled := true
        this.OnRequest := ""
        this.Index := ""
    }

    Pump() {
        return false
    }

    GetIndex(*) {
        return this.Index
    }

    RequestFresh() {
        this.RequestCount++
        if IsObject(this.OnRequest)
            this.OnRequest.Call()
        return this.RequestEnabled ? this.Clock.Ticks : 0
    }
}

class GuardRuntimeFakeLauncher {
    __New() {
        this.LaunchCount := 0
        this.ReturnPid := 0
    }

    Launch(*) {
        this.LaunchCount++
        return {PID: this.ReturnPid}
    }
}

class GuardRuntimeFakeInspector {
    __New(clock) {
        this.Clock := clock
        this.Processes := []
        this.ImagePaths := Map()
        this.Identities := Map()
        this.CaptureCount := 0
        this.ImagePathQueries := []
        this.IdentityQueries := []
    }

    CaptureNativeSnapshot() {
        this.CaptureCount++
        return {Ready: true, Processes: this.Processes,
            CapturedAtTicks: this.Clock.Ticks, Reason: ""}
    }

    GetImagePath(pid) {
        this.ImagePathQueries.Push(pid)
        return this.ImagePaths.Has(pid) ? this.ImagePaths[pid] : ""
    }

    GetCreationIdentity(pid) {
        this.IdentityQueries.Push(pid)
        return this.Identities.Has(pid) ? this.Identities[pid] : ""
    }
}

class GuardRuntimeTestContext {
    static Observation := ""
    static Status := ""
    static StatusKind := ""
    static Logs := []
    static Runtime := ""
    static ReplacementOnObserve := ""
    static ThrowOnObserve := false
    static ThrowPath := ""
    static SnapshotObservation := ""
    static LastSnapshotIndex := ""
    static Specs := ""
    static SpecsByPath := Map()
    static UseIndexedObservation := false
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

GuardRuntimeGetSpecs(path, *) {
    if GuardRuntimeTestContext.SpecsByPath.Has(path)
        return GuardRuntimeTestContext.SpecsByPath[path]
    return GuardRuntimeTestContext.Specs
}

GuardRuntimeLog(message) {
    GuardRuntimeTestContext.Logs.Push(message)
}

GuardRuntimeLogSlow(*) {
}

GuardRuntimeObserve(path, snapshotIndex := "", *) {
    if GuardRuntimeTestContext.ThrowOnObserve
        || (GuardRuntimeTestContext.ThrowPath != ""
            && path == GuardRuntimeTestContext.ThrowPath)
        throw Error("模拟探活异常")
    if GuardRuntimeTestContext.ReplacementOnObserve != "" {
        GuardRuntimeTestContext.Runtime.appStates[path] :=
            GuardRuntimeTestContext.ReplacementOnObserve
        GuardRuntimeTestContext.ReplacementOnObserve := ""
    }
    GuardRuntimeTestContext.LastSnapshotIndex := snapshotIndex
    if GuardRuntimeTestContext.UseIndexedObservation
        && snapshotIndex is ProcessSnapshotIndex {
        observationSpecs := GuardRuntimeGetSpecs(path)
        return observationSpecs.Probe.Kind == TargetProbeKind.ImagePath
            ? snapshotIndex.ObserveImagePath(observationSpecs.Probe.TargetPath)
            : snapshotIndex.ObserveCommandTarget(
                observationSpecs.Probe.TargetPath)
    }
    return snapshotIndex is ProcessSnapshotIndex
        && GuardRuntimeTestContext.SnapshotObservation != ""
        ? GuardRuntimeTestContext.SnapshotObservation
        : GuardRuntimeTestContext.Observation
}

GuardRuntimeRefreshShortcut(*) {
    return false
}

GuardRuntimeSaveApps(*) {
}

GuardRuntimeSetIdentity(stateObj, pid, creationIdentity := "") {
    stateObj.PID := pid
    stateObj.PIDCreationIdentity := creationIdentity != ""
        ? creationIdentity : "CREATION-" pid
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

GuardRuntimeUpdateState(path, statusText, expectedState := "",
    expectedGeneration := 0, forceProjection := false, statusKind := "") {
    GuardRuntimeTestContext.Status := path "|" statusText
    GuardRuntimeTestContext.StatusKind := statusKind
}

BlockGuardRuntimeDuringSnapshotRequest(maintenance, stateObj) {
    stateObj.CancelScheduledTasks()
    stateObj.Pending := true
    stateObj.TargetStartTicks := 0
    maintenance.Blocking := true
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
    inspector := GuardRuntimeFakeInspector(clock)
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
        processSnapshots: GuardRuntimeFakeSnapshots(clock),
        processInspector: inspector,
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
    AssertGuardRuntime(guard.UpdateState(path, replacement, "新状态",
            GuardStatusKind.Starting)
        && InStr(GuardRuntimeTestContext.Status, "新状态")
        && GuardRuntimeTestContext.StatusKind == GuardStatusKind.Starting,
        "当前控制器的状态文本或细粒度视觉键没有一起转发")
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

    stateObj.Pending := true
    stateObj.TransitionTo(GuardPhase.WaitingRestart)
    priorOrphanGeneration := stateObj.Generation
    guard.RecoverOrphanedPending(path, stateObj)
    AssertGuardRuntime(!stateObj.Pending
        && stateObj.Phase == GuardPhase.Initializing
        && stateObj.Generation > priorOrphanGeneration,
        "没有活动任务的孤儿 Pending 未被恢复")

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
        1000, "process-command", "没有足够新的进程快照",
        ProcessObservationReason.SnapshotUnavailable)
    snapshotRequestCount := runtime.processSnapshots.RequestCount
    firstTask := guard.ScheduleRestart(path, 0)
    AssertGuardRuntime(firstTask is TargetScheduledTask,
        "重启调度没有返回任务令牌")
    scheduler.RunDue(clock.Ticks)
    AssertGuardRuntimeEqual(0, launcher.LaunchCount,
        "未知探活结果仍触发了重复启动")
    AssertGuardRuntime(stateObj.RestartTask is TargetScheduledTask
        && stateObj.IsSnapshotWaitCurrent("Restart")
        && runtime.processSnapshots.RequestCount == snapshotRequestCount + 1,
        "快照暂不可用时没有建立一次有代际的等待")
    AssertGuardRuntimeEqual(clock.Ticks + guard.SnapshotWaitTimeoutMs,
        stateObj.RestartTask.DueTicks,
        "快照等待没有使用有限截止时间")

    staleSnapshot := ProcessSnapshotIndex([], clock.Ticks, true)
    staleSnapshot.RequestTicks := stateObj.SnapshotRequestTicks - 1
    AssertGuardRuntime(!guard.OnSnapshotPublished([], staleSnapshot)
        && stateObj.RestartTask is TargetScheduledTask,
        "早于目标请求的旧快照错误唤醒了重启")

    requestedTicks := stateObj.SnapshotRequestTicks
    clock.Ticks += 1500
    freshSnapshot := ProcessSnapshotIndex([], clock.Ticks, true)
    freshSnapshot.RequestTicks := requestedTicks
    GuardRuntimeTestContext.SnapshotObservation := ProcessObservation.Running(
        99, "CREATION-99", clock.Ticks, "process-command")
    AssertGuardRuntime(guard.OnSnapshotPublished([], freshSnapshot),
        "满足请求代际的新快照没有唤醒重启前复核")
    AssertGuardRuntime(stateObj.RestartTask is TargetScheduledTask
        && stateObj.RestartTask.DueTicks == clock.Ticks + 1
        && stateObj.SnapshotReadyIndex == freshSnapshot,
        "新快照没有随恢复任务保存，仍可能被年龄阈值丢弃")
    scheduler.RunDue(clock.Ticks + 1)
    AssertGuardRuntimeEqual(0, launcher.LaunchCount,
        "已证明目标运行的迟到快照仍触发了重复启动")
    AssertGuardRuntime(stateObj.PID == 99
        && stateObj.PIDCreationIdentity == "CREATION-99"
        && stateObj.RestartTask == ""
        && !stateObj.IsSnapshotWaitCurrent(),
        "消费新快照后没有收敛为运行状态")

    stateObj.PID := 0
    GuardRuntimeTestContext.Observation := ProcessObservation.Unknown(
        clock.Ticks, "process-command", "没有足够新的进程快照",
        ProcessObservationReason.SnapshotUnavailable)
    guard.ScheduleRestart(path, 0)
    scheduler.RunDue(clock.Ticks)
    gateRequestTicks := stateObj.SnapshotRequestTicks
    gateSnapshot := ProcessSnapshotIndex([], clock.Ticks + 100, true)
    gateSnapshot.RequestTicks := gateRequestTicks
    clock.Ticks += 100
    guard.OnSnapshotPublished([], gateSnapshot)
    AssertGuardRuntime(runtime.guardWorkGate.TryEnter(),
        "测试无法占用快照恢复路径的守护工作门")
    scheduler.RunDue(clock.Ticks + 1)
    runtime.guardWorkGate.Leave()
    AssertGuardRuntime(stateObj.RestartTask is TargetScheduledTask
        && stateObj.SnapshotReadyIndex == gateSnapshot,
        "工作门退让时丢失了已经发布的快照证据")
    clock.Ticks += 100
    scheduler.RunDue(clock.Ticks)
    AssertGuardRuntime(stateObj.PID == 99,
        "工作门释放后没有使用保留的快照完成复核")
    GuardRuntimeTestContext.SnapshotObservation := ""

    GuardRuntimeTestContext.Observation := ProcessObservation.Unknown(
        clock.Ticks, "process-command", "没有足够新的进程快照",
        ProcessObservationReason.SnapshotUnavailable)
    stateObj.PID := 0
    guard.ScheduleRestart(path, 0)
    scheduler.RunDue(clock.Ticks + 1)
    staleTask := stateObj.RestartTask
    replacement := CreateGuardRuntimeSupervisor(scheduler)
    states[path] := replacement
    replacementGeneration := replacement.Generation
    lateSnapshot := ProcessSnapshotIndex([], clock.Ticks + 200, true)
    lateSnapshot.RequestTicks := stateObj.SnapshotRequestTicks
    guard.OnSnapshotPublished([], lateSnapshot)
    AssertGuardRuntime(!replacement.Pending,
        "迟到快照修改了同路径的新控制器")
    AssertGuardRuntime(replacement.Generation == replacementGeneration
        && replacement.RestartTask == "",
        "迟到快照给替换后的控制器创建了任务")
    staleTask.Cancel()

    timeoutState := CreateGuardRuntimeSupervisor(scheduler)
    states[path] := timeoutState
    timeoutRequestCount := runtime.processSnapshots.RequestCount
    guard.ScheduleRestart(path, 0)
    scheduler.RunDue(clock.Ticks + 1)
    timeoutDueTicks := timeoutState.SnapshotWaitDeadlineTicks
    clock.Ticks := timeoutDueTicks
    scheduler.RunDue(clock.Ticks)
    AssertGuardRuntime(!timeoutState.Pending
        && timeoutState.RestartTask == ""
        && !timeoutState.IsSnapshotWaitCurrent()
        && runtime.processSnapshots.RequestCount == timeoutRequestCount + 1,
        "快照超时后重新发起请求或保留了无限等待任务")

    permanentUnknownState := CreateGuardRuntimeSupervisor(scheduler)
    states[path] := permanentUnknownState
    permanentRequestCount := runtime.processSnapshots.RequestCount
    GuardRuntimeTestContext.Observation := ProcessObservation.Unknown(
        clock.Ticks, "process-command", "候选解释器的命令行不可用",
        ProcessObservationReason.CommandLineUnavailable)
    guard.ScheduleRestart(path, 0)
    scheduler.RunDue(clock.Ticks)
    AssertGuardRuntime(!permanentUnknownState.Pending
        && permanentUnknownState.RestartTask == ""
        && runtime.processSnapshots.RequestCount == permanentRequestCount,
        "永久证据不足被错误当作瞬态快照缺失重复请求")

    interruptedState := CreateGuardRuntimeSupervisor(scheduler)
    states[path] := interruptedState
    GuardRuntimeTestContext.Observation := ProcessObservation.Unknown(
        clock.Ticks, "process-command", "没有足够新的进程快照",
        ProcessObservationReason.SnapshotUnavailable)
    runtime.processSnapshots.OnRequest :=
        BlockGuardRuntimeDuringSnapshotRequest.Bind(maintenance,
            interruptedState)
    interruptedGeneration := interruptedState.Generation
    guard.ScheduleRestart(path, 0)
    scheduler.RunDue(clock.Ticks)
    runtime.processSnapshots.OnRequest := ""
    AssertGuardRuntime(maintenance.Blocking
        && interruptedState.Generation > interruptedGeneration
        && interruptedState.RestartTask == ""
        && !interruptedState.IsSnapshotWaitCurrent()
        && interruptedState.Pending,
        "快照请求期间切入升级保护后，旧重启操作仍建立了等待或覆盖状态")
    maintenance.Blocking := false

    verifyState := CreateGuardRuntimeSupervisor(scheduler)
    states[path] := verifyState
    verifyNotBeforeTicks := clock.Ticks + 1500
    verifyTask := guard.ScheduleVerificationFor(path, verifyState, 1500)
    verifyState.BeginSnapshotWait("Verify", clock.Ticks,
        clock.Ticks + guard.SnapshotWaitTimeoutMs, verifyNotBeforeTicks)
    verifySnapshot := ProcessSnapshotIndex([], clock.Ticks + 200, true)
    verifySnapshot.RequestTicks := clock.Ticks
    GuardRuntimeTestContext.SnapshotObservation := ProcessObservation.Running(
        101, "CREATION-101", clock.Ticks + 200, "process-command")
    clock.Ticks += 200
    AssertGuardRuntime(guard.OnSnapshotPublished([], verifySnapshot)
        && verifyTask.Cancelled
        && verifyState.VerifyTask.DueTicks == verifyNotBeforeTicks,
        "启动验证快照没有遵守最早验证时间或淘汰旧任务")
    clock.Ticks := verifyNotBeforeTicks
    scheduler.RunDue(clock.Ticks)
    AssertGuardRuntime(verifyState.PID == 101
        && verifyState.PIDCreationIdentity == "CREATION-101"
        && verifyState.VerifyTask == ""
        && !verifyState.IsSnapshotWaitCurrent(),
        "启动验证没有消费同代新快照并收敛为运行状态")
    GuardRuntimeTestContext.SnapshotObservation := ""

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

    healthyPath := "healthy.exe"
    healthyState := CreateGuardRuntimeSupervisor(scheduler)
    states[healthyPath] := healthyState
    runtime.appOrder := [aliasPath, healthyPath]
    GuardRuntimeTestContext.ThrowPath := aliasPath
    guard.MonitorTick()
    GuardRuntimeTestContext.ThrowPath := ""
    AssertGuardRuntime(!runtime.guardWorkGate.Busy,
        "探活异常后没有释放共享守护工作门")
    AssertGuardRuntime(healthyState.PID == 99,
        "单个目标探活异常阻断了后续目标的同轮检查")
    AssertGuardRuntime(GuardRuntimeTestContext.Logs.Length
        && InStr(GuardRuntimeTestContext.Logs[-1],
            "主进程监控异常"),
        "目标探活异常没有写入隔离后的运行日志")
    guard.MonitorTick()
    AssertGuardRuntime(!runtime.guardWorkGate.Busy,
        "探活异常后的下一轮监控无法正常结束")

    ; 普通轮询暂时拿不到完整快照或得到 Unknown 时，必须明确投影为
    ; “等待进程状态”，不能无限保留上一轮的运行中、疑似停止等旧状态。
    unavailableSnapshotState := CreateGuardRuntimeSupervisor(scheduler)
    states.Clear()
    states[path] := unavailableSnapshotState
    runtime.appOrder := [path]
    runtime.processSnapshots.Index := ""
    GuardRuntimeTestContext.Status := "旧的运行状态"
    GuardRuntimeTestContext.StatusKind := GuardStatusKind.Running
    GuardRuntimeTestContext.Observation := ProcessObservation.Unknown(
        clock.Ticks, "process-command", "后台快照暂不可用",
        ProcessObservationReason.SnapshotUnavailable)
    guard.MonitorTick()
    AssertGuardRuntime(GuardRuntimeTestContext.StatusKind
            == GuardStatusKind.WaitingObservation
        && unavailableSnapshotState.UncertainObservationCount == 1,
        "普通轮询快照不可用时仍保留过期界面状态")

    unknownAliasPath := "unknown-target.exe"
    unknownAliasState := CreateGuardRuntimeSupervisor(scheduler)
    states.Clear()
    states[unknownAliasPath] := unknownAliasState
    runtime.appOrder := [unknownAliasPath]
    GuardRuntimeTestContext.Status := "旧的疑似停止状态"
    GuardRuntimeTestContext.StatusKind := GuardStatusKind.SuspectedStop
    guard.MonitorTick()
    AssertGuardRuntime(GuardRuntimeTestContext.StatusKind
            == GuardStatusKind.WaitingObservation
        && unknownAliasState.UncertainObservationCount == 1,
        "普通轮询收到 Unknown 后没有收敛为等待状态")

    ; 同一旧快照不能在连续轮次中两次证明停止；只有更新的采集时刻
    ; 才能从“疑似停止”推进到重启倒计时。
    staleEvidenceState := CreateGuardRuntimeSupervisor(scheduler)
    states.Clear()
    states[path] := staleEvidenceState
    runtime.appOrder := [path]
    runtime.processSnapshots.Index := ProcessSnapshotIndex([],
        clock.Ticks, true)
    GuardRuntimeTestContext.SnapshotObservation :=
        ProcessObservation.Stopped(clock.Ticks, "process-image")
    guard.MonitorTick()
    AssertGuardRuntime(staleEvidenceState.Phase
            == GuardPhase.SuspectedStopped
        && staleEvidenceState.RestartTask == "",
        "首次停止观测没有停留在疑似停止阶段")
    guard.MonitorTick()
    AssertGuardRuntime(staleEvidenceState.RestartTask == "",
        "同一份旧快照被重复用作第二次停止证据")
    clock.Ticks += 200
    runtime.processSnapshots.Index := ProcessSnapshotIndex([],
        clock.Ticks, true)
    GuardRuntimeTestContext.SnapshotObservation :=
        ProcessObservation.Stopped(clock.Ticks, "process-image")
    guard.MonitorTick()
    AssertGuardRuntime(staleEvidenceState.RestartTask
        is TargetScheduledTask,
        "更新后的独立快照没有确认停止并安排重启")
    staleEvidenceState.CancelScheduledTasks()
    runtime.processSnapshots.Index := ""
    GuardRuntimeTestContext.SnapshotObservation := ""

    ; WMI 完整快照不可用时，只对守护列表中的原生 EXE 名称构建一次
    ; 受限降级索引；解释型脚本不能借此缺少命令行的索引推断为停止。
    fallbackExePath := "c:\apps\fallback-target.exe"
    fallbackScriptPath := "c:\jobs\fallback-worker.py"
    fallbackExeState := CreateGuardRuntimeSupervisor(scheduler)
    fallbackScriptState := CreateGuardRuntimeSupervisor(scheduler)
    states.Clear()
    states[fallbackExePath] := fallbackExeState
    states[fallbackScriptPath] := fallbackScriptState
    runtime.appOrder := [fallbackExePath, fallbackScriptPath]
    runtime.processSnapshots.Index := ""
    currentPid := DllCall("kernel32\GetCurrentProcessId", "UInt")
    inspector.Processes := [
        {pid: currentPid, parent: 0, name: "fallback-target.exe",
            cmd: "", exe: "", creation: "", observedTicks: clock.Ticks},
        {pid: 424242, parent: 0, name: "unrelated.exe",
            cmd: "", exe: "", creation: "", observedTicks: clock.Ticks}
    ]
    inspector.ImagePaths[currentPid] := fallbackExePath
    inspector.Identities[currentPid] := "FALLBACK-CREATION"
    inspector.CaptureCount := 0
    inspector.ImagePathQueries := []
    inspector.IdentityQueries := []
    GuardRuntimeTestContext.SpecsByPath.Clear()
    GuardRuntimeTestContext.SpecsByPath[fallbackExePath] := TargetSpecs(
        fallbackExePath,
        LaunchSpec(TargetLaunchKind.Direct, fallbackExePath),
        ProbeSpec(TargetProbeKind.ImagePath, fallbackExePath))
    GuardRuntimeTestContext.SpecsByPath[fallbackScriptPath] := TargetSpecs(
        fallbackScriptPath,
        LaunchSpec(TargetLaunchKind.Direct, fallbackScriptPath),
        ProbeSpec(TargetProbeKind.CommandTarget, fallbackScriptPath))
    GuardRuntimeTestContext.UseIndexedObservation := true
    launchesBeforeFallback := launcher.LaunchCount
    guard.MonitorTick()
    AssertGuardRuntime(fallbackExeState.PID == currentPid
        && fallbackExeState.PIDCreationIdentity == "FALLBACK-CREATION",
        "完整快照缺失时，受限原生索引没有识别正在运行的 EXE")
    AssertGuardRuntime(fallbackScriptState.PID == 0
        && fallbackScriptState.Phase == GuardPhase.Initializing
        && fallbackScriptState.RestartTask == ""
        && launcher.LaunchCount == launchesBeforeFallback,
        "无命令行的原生降级索引把解释型脚本误判为停止并启动")
    AssertGuardRuntime(inspector.CaptureCount == 1
        && inspector.ImagePathQueries.Length == 1
        && inspector.ImagePathQueries[1] == currentPid
        && inspector.IdentityQueries.Length >= 1,
        "原生降级没有复用单次快照，或查询了无关进程的路径")
    AssertGuardRuntime(GuardRuntimeTestContext.LastSnapshotIndex
            is ProcessSnapshotIndex
        && !GuardRuntimeTestContext.LastSnapshotIndex.SupportsCommandLine,
        "原生降级索引错误宣称包含命令行证据")
    GuardRuntimeTestContext.UseIndexedObservation := false
    GuardRuntimeTestContext.SpecsByPath.Clear()
    inspector.Processes := []
    inspector.ImagePaths.Clear()
    inspector.Identities.Clear()

    ; 调度回调在消费任务槽之前异常时，统一错误处理必须清除假等待，
    ; 让下一轮监控仍能接管该目标。
    callbackErrorState := CreateGuardRuntimeSupervisor(scheduler)
    states[path] := callbackErrorState
    GuardRuntimeTestContext.ThrowPath := path
    callbackErrorTask := guard.ScheduleRestartFor(path,
        callbackErrorState, 0)
    scheduler.RunDue(clock.Ticks)
    GuardRuntimeTestContext.ThrowPath := ""
    AssertGuardRuntime(callbackErrorTask.Completed
        && !callbackErrorState.Pending
        && callbackErrorState.RestartTask == ""
        && callbackErrorState.VerifyTask == ""
        && callbackErrorState.Phase == GuardPhase.Initializing,
        "调度回调异常后残留了 Pending、任务槽或不可恢复阶段")

    launchState := CreateGuardRuntimeSupervisor(scheduler)
    states[path] := launchState
    GuardRuntimeTestContext.Observation := ProcessObservation.Stopped(
        clock.Ticks, "test")
    GuardRuntimeTestContext.Specs := TargetSpecs(path,
        LaunchSpec(TargetLaunchKind.Direct, path),
        ProbeSpec(TargetProbeKind.ImagePath, path))
    launcher.ReturnPid := 4242
    requestCountBeforeExeLaunch := runtime.processSnapshots.RequestCount
    guard.RestartCore(path, launchState)
    AssertGuardRuntime(launchState.PID == 0,
        "Run 返回的未验证 PID 被直接写入受信进程身份")
    AssertGuardRuntime(runtime.processSnapshots.RequestCount
            == requestCountBeforeExeLaunch
        && !launchState.IsSnapshotWaitCurrent("Verify")
        && launchState.VerifyTask is TargetScheduledTask,
        "原生可探测 EXE 启动后仍无谓等待完整命令行快照")
    firstVerifyDueTicks := launchState.VerifyTask.DueTicks
    clock.Ticks := firstVerifyDueTicks
    scheduler.RunDue(clock.Ticks)
    AssertGuardRuntime(launchState.VerifyAttempts == 1
        && launchState.FailCount == 0
        && launchState.VerifyTask is TargetScheduledTask
        && launchState.RestartTask == "",
        "启动后的首次停止证据没有进入有界复核，或过早计入启动失败")
    secondVerifyDueTicks := launchState.VerifyTask.DueTicks
    clock.Ticks := secondVerifyDueTicks
    scheduler.RunDue(clock.Ticks)
    AssertGuardRuntime(launchState.FailCount == 1
        && launchState.VerifyTask == ""
        && launchState.RestartTask is TargetScheduledTask,
        "两次独立启动停止证据没有进入原有阶梯重试")
    launchState.CancelScheduledTasks()

    scriptPath := "c:\jobs\worker.py"
    scriptState := CreateGuardRuntimeSupervisor(scheduler)
    states.Delete(path)
    states[scriptPath] := scriptState
    GuardRuntimeTestContext.Specs := TargetSpecs(scriptPath,
        LaunchSpec(TargetLaunchKind.Direct, scriptPath),
        ProbeSpec(TargetProbeKind.CommandTarget, scriptPath))
    requestCountBeforeScriptLaunch := runtime.processSnapshots.RequestCount
    guard.RestartCore(scriptPath, scriptState)
    AssertGuardRuntime(scriptState.PID == 0
        && runtime.processSnapshots.RequestCount
            == requestCountBeforeScriptLaunch + 1
        && scriptState.IsSnapshotWaitCurrent("Verify"),
        "解释型脚本启动后未等待同代命令目标快照确认")
    scriptState.CancelScheduledTasks()
    GuardRuntimeTestContext.Specs := ""

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
