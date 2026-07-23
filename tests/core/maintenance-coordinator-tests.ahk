#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\..\src\Core\GuardTypes.ahk
#Include ..\..\src\Core\GuardStateMachine.ahk
#Include ..\..\src\Maintenance\MaintenanceStateMachine.ahk
#Include ..\..\src\Core\GuardWorkGate.ahk
#Include ..\..\src\Core\WatchdogScheduler.ahk
#Include ..\..\src\Core\TargetSupervisor.ahk
#Include ..\..\src\Inspection\ProcessSnapshotIndex.ahk
#Include ..\..\src\Maintenance\MaintenanceActorMatcher.ahk
#Include ..\..\src\Maintenance\MaintenanceCoordinator.ahk

class MaintenanceCoordinatorTestContext {
    static Runtime := ""
    static Coordinator := ""
    static Existing := false
    static ScheduledDelay := 0
    static SavedApps := 0
    static Logs := []
}

class MaintenanceFakeInspector {
    GetCreationIdentity(pid) {
        return pid ? "CREATION-" pid : ""
    }

    CaptureNativeSnapshot() {
        return {Ready: true, Processes: []}
    }

    GetImagePath(*) {
        return ""
    }
}

class MaintenanceFakeSnapshots {
    __New() {
        this.LatestSnapshotTicks := 0
        this.LatestSnapshot := []
        this.ReuseIntervalMs := 5000
        this.IndexFactory := MaintenanceTestCreateIndex
        this.RequestCount := 0
    }

    RequestFresh() {
        this.RequestCount++
        return 24680
    }

    Start() {
        return true
    }

    Stop(*) {
    }
}

class MaintenanceFakeWatcher {
    __New(rootPath) {
        this.RootPath := rootPath
        this.Active := false
        this.Closed := false
        this.ThrowOnPoll := false
    }

    Open() {
        this.Active := true
        return true
    }

    Close() {
        this.Active := false
        this.Closed := true
    }

    Poll() {
        if this.ThrowOnPoll
            throw Error("模拟目录监听异常")
        return []
    }
}

AssertCoordinator(condition, message) {
    if !condition
        throw Error(message)
}

AssertCoordinatorEqual(expected, actual, message) {
    if (expected != actual)
        throw Error(message "；预期=" expected "，实际=" actual)
}

MaintenanceTestCanonical(path) {
    return StrLower(RTrim(StrReplace(path, "/", "\"), "\"))
}

MaintenanceTestShutdownServices() {
}

MaintenanceTestClearIdentity(stateObj) {
    stateObj.PID := 0
    stateObj.PIDCreationIdentity := ""
}

MaintenanceTestDeserializeSession(*) {
    return {Path: "", StartedAt: "", BaselineFingerprint: "",
        FileChanged: false, Explicit: false}
}

MaintenanceTestFingerprint(path) {
    return "FP:" path
}

MaintenanceTestSubject(path) {
    return path
}

MaintenanceTestHash(*) {
    return "App1"
}

MaintenanceTestSupported(*) {
    return true
}

MaintenanceTestReady(*) {
    return true
}

MaintenanceTestLog(message) {
    MaintenanceCoordinatorTestContext.Logs.Push(message)
}

MaintenanceTestLogSlow(*) {
}

MaintenanceTestNormalizeRoot(rootPath, *) {
    return rootPath
}

MaintenanceTestNormalizeTarget(path) {
    return path
}

MaintenanceTestObserve(*) {
    return ProcessObservation.Stopped(1, "test")
}

MaintenanceTestQuerySnapshot(&ready) {
    ready := true
    return []
}

MaintenanceTestRefreshShortcut(*) {
    return false
}

MaintenanceTestSaveApps(*) {
    MaintenanceCoordinatorTestContext.SavedApps++
}

MaintenanceTestScheduleRestart(path, stateObj, delayMs) {
    MaintenanceCoordinatorTestContext.ScheduledDelay := delayMs
}

MaintenanceTestSerializeSession(*) {
    return "STATE"
}

MaintenanceTestSetIdentity(stateObj, pid) {
    stateObj.PID := pid
    stateObj.PIDCreationIdentity := "CREATION-" pid
}

MaintenanceTestTargetExists(*) {
    return MaintenanceCoordinatorTestContext.Existing
}

MaintenanceTestUpdateRunning(path, stateObj) {
    stateObj.State := "RUNNING:" path
}

MaintenanceTestUpdateState(path, statusText, *) {
    runtime := MaintenanceCoordinatorTestContext.Runtime
    if runtime.appStates.Has(path)
        runtime.appStates[path].State := statusText
}

MaintenanceTestCreateIndex(snapshot, capturedAtTicks,
    supportsCommandLine := true) {
    return ProcessSnapshotIndex(snapshot, capturedAtTicks,
        supportsCommandLine, MaintenanceTestCanonical)
}

CreateMaintenanceTestSupervisor(rootPath) {
    stateObj := TargetSupervisor({Enabled: true})
    stateObj.MaintenanceConfig := {
        Enabled: true,
        InstallRoot: rootPath,
        DetectionSeconds: 5,
        StableSeconds: 3,
        MaxWaitSeconds: 60,
        LearnedActors: []
    }
    stateObj.Enabled := true
    stateObj.SafetyFingerprint := ""
    return stateObj
}

RunMaintenanceCoordinatorTests() {
    journalPath := A_Temp "\watchdog-maintenance-coordinator-"
        DllCall("kernel32\GetCurrentProcessId", "UInt") ".ini"
    rootPath := A_Temp "\watchdog-maintenance-root-"
        DllCall("kernel32\GetCurrentProcessId", "UInt")
    try FileDelete(journalPath)
    try DirCreate(rootPath)

    snapshots := MaintenanceFakeSnapshots()
    runtime := {
        appStates: Map(),
        maintenanceJournalPath: journalPath,
        maintenancePollInterval: 1000,
        maintenanceProcessInterval: 1000,
        maintenanceFingerprintInterval: 30000,
        maintenanceFingerprintRetryInterval: 5000,
        guardWorkGate: GuardWorkGate(),
        retryDelayArray: [5000],
        processInspector: MaintenanceFakeInspector(),
        processSnapshots: snapshots,
        maintenanceActorMatcher: MaintenanceActorMatcher(
            (*) => "LIVE"),
        scheduler: ""
    }
    callbacks := {
        CanonicalPath: MaintenanceTestCanonical,
        ShutdownServices: MaintenanceTestShutdownServices,
        ClearProcessIdentity: MaintenanceTestClearIdentity,
        DeserializeSession: MaintenanceTestDeserializeSession,
        GetFingerprint: MaintenanceTestFingerprint,
        GetMaintenanceSubjectPath: MaintenanceTestSubject,
        HashPath: MaintenanceTestHash,
        IsSupportedTarget: MaintenanceTestSupported,
        IsTargetFileReady: MaintenanceTestReady,
        Log: MaintenanceTestLog,
        LogSlow: MaintenanceTestLogSlow,
        NormalizeRoot: MaintenanceTestNormalizeRoot,
        NormalizeTargetPath: MaintenanceTestNormalizeTarget,
        ObserveTarget: MaintenanceTestObserve,
        QueryProcessSnapshot: MaintenanceTestQuerySnapshot,
        RefreshShortcutIdentity: MaintenanceTestRefreshShortcut,
        SaveApps: MaintenanceTestSaveApps,
        ScheduleRestart: MaintenanceTestScheduleRestart,
        SerializeSession: MaintenanceTestSerializeSession,
        SetProcessIdentity: MaintenanceTestSetIdentity,
        TargetReferenceExists: MaintenanceTestTargetExists,
        UpdateRunningState: MaintenanceTestUpdateRunning,
        UpdateState: MaintenanceTestUpdateState,
        WatcherFactory: MaintenanceFakeWatcher
    }
    coordinator := MaintenanceCoordinator(runtime, callbacks)
    MaintenanceCoordinatorTestContext.Runtime := runtime
    MaintenanceCoordinatorTestContext.Coordinator := coordinator

    path := rootPath "\App.exe"
    stateObj := CreateMaintenanceTestSupervisor(rootPath)
    runtime.appStates.CaseSense := "Off"
    runtime.appStates[path] := stateObj

    replacementState := CreateMaintenanceTestSupervisor(rootPath)
    runtime.appStates[path] := replacementState
    originalStateText := replacementState.State
    AssertCoordinator(!coordinator.UpdateState(path, stateObj, "旧状态")
        && replacementState.State == originalStateText,
        "升级编排器允许旧控制器覆盖同路径的新状态")
    AssertCoordinator(coordinator.UpdateState(path, replacementState,
        "当前状态") && replacementState.State == "当前状态",
        "升级编排器错误拒绝当前控制器的状态写入")
    runtime.appStates[path] := stateObj

    AssertCoordinator(coordinator.QueueCommand("BEGIN|" path),
        "初始化前的显式维护命令未进入队列")
    AssertCoordinatorEqual(1, coordinator.PendingCommands.Length,
        "初始化前的显式维护命令队列长度错误")
    coordinator.PendingCommands := []
    coordinator.Initialized := true
    AssertCoordinator(coordinator.QueueCommand("BEGIN|" path),
        "显式维护开始命令执行失败")
    AssertCoordinatorEqual(MaintenancePhase.Updating,
        stateObj.MaintenanceMode, "显式维护没有进入升级阶段")
    AssertCoordinator(stateObj.ExplicitMaintenance && stateObj.Pending,
        "显式维护状态未完整写入控制器")
    AssertCoordinator(FileExist(journalPath),
        "升级保护会话没有由编排器持久化")

    AssertCoordinator(coordinator.QueueCommand("END|" path),
        "显式维护结束命令执行失败")
    AssertCoordinatorEqual(MaintenancePhase.Stabilizing,
        stateObj.MaintenanceMode, "显式维护结束后没有进入稳定确认")
    AssertCoordinator(!stateObj.ExplicitMaintenance,
        "显式维护结束后标记未清除")

    AssertCoordinator(coordinator.QueueCommand("BEGIN|" path),
        "超时恢复测试无法开始显式维护")
    stateObj.MaintenanceMode := MaintenancePhase.TimedOut
    AssertCoordinator(coordinator.QueueCommand("END|" path),
        "显式维护超时后无法结束等待")
    AssertCoordinator(!stateObj.ExplicitMaintenance
        && stateObj.MaintenanceMode == MaintenancePhase.Stabilizing
        && stateObj.MaintenanceStartedTicks > 0,
        "显式维护超时结束后没有进入新的稳定确认阶段")

    coordinator.ResetSession(path, stateObj, false)
    AssertCoordinator(runtime.guardWorkGate.TryEnter(),
        "无法占用显式维护命令测试的共享工作门")
    AssertCoordinator(coordinator.QueueCommand("BEGIN|" path),
        "共享工作门繁忙时显式维护命令未被接收")
    AssertCoordinatorEqual(1, coordinator.PendingCommands.Length,
        "共享工作门繁忙时显式维护命令没有排队")
    AssertCoordinatorEqual(MaintenancePhase.Normal,
        stateObj.MaintenanceMode, "排队命令越过共享工作门修改了状态")
    runtime.guardWorkGate.Leave()
    coordinator.EventTick()
    AssertCoordinatorEqual(0, coordinator.PendingCommands.Length,
        "文件监听轮次没有清空显式维护命令队列")
    AssertCoordinator(stateObj.ExplicitMaintenance
        && stateObj.MaintenanceMode == MaintenancePhase.Updating,
        "排队的显式维护命令没有在工作门内执行")
    AssertCoordinator(coordinator.QueueCommand("END|" path),
        "排队命令完成后无法结束显式维护")

    originalJournalPath := runtime.maintenanceJournalPath
    runtime.maintenanceJournalPath := rootPath "\missing\maintenance.ini"
    Critical("On")
    try {
        AssertCoordinator(!coordinator.SaveJournal(),
            "无效恢复日志路径没有触发保存失败")
        AssertCoordinator(A_IsCritical != 0,
            "恢复日志保存失败破坏了调用方的临界状态")
    } finally Critical("Off")
    AssertCoordinator(coordinator.JournalDirty
        && coordinator.JournalRetryDueTicks > 0
        && coordinator.JournalRetryDelayMs == 10000,
        "恢复日志保存失败后没有保留待重试状态")
    runtime.maintenanceJournalPath := originalJournalPath
    AssertCoordinator(coordinator.SaveJournal(),
        "恢复日志保存失败后无法再次保存")
    AssertCoordinator(!coordinator.JournalDirty
        && coordinator.JournalRetryDueTicks == 0
        && coordinator.JournalRetryDelayMs == 5000,
        "恢复日志重试成功后没有清除待保存状态")

    coordinator.ResetSession(path, stateObj, false)
    MaintenanceCoordinatorTestContext.Existing := false
    AssertCoordinator(coordinator.BeginArbitration(path, stateObj),
        "停止目标没有进入升级仲裁")
    AssertCoordinatorEqual(MaintenancePhase.Arbitrating,
        stateObj.MaintenanceMode, "升级仲裁阶段错误")
    AssertCoordinatorEqual(24680,
        stateObj.ArbitrationSnapshotRequestTicks,
        "升级仲裁没有保存新鲜快照请求边界")
    AssertCoordinatorEqual(1, snapshots.RequestCount,
        "升级仲裁没有且仅有一次请求后台快照")

    AssertCoordinator(runtime.guardWorkGate.TryEnter(),
        "空闲的共享守护工作门无法进入")
    AssertCoordinator(!runtime.guardWorkGate.TryEnter(),
        "共享守护工作门允许了重入")
    runtime.guardWorkGate.Leave()

    secondPath := rootPath "\Other.exe"
    secondState := CreateMaintenanceTestSupervisor(rootPath)
    runtime.appStates[secondPath] := secondState
    AssertCoordinator(coordinator.EnsureWatcher(path, stateObj),
        "首个目录监听器创建失败")
    AssertCoordinator(coordinator.EnsureWatcher(secondPath, secondState),
        "共享目录监听器订阅失败")
    AssertCoordinatorEqual(1, coordinator.Watchers.Count,
        "相同安装根目录创建了重复监听器")
    rootKey := MaintenanceTestCanonical(rootPath)
    AssertCoordinatorEqual(2,
        coordinator.Watchers[rootKey].subscribers.Count,
        "共享监听器没有登记两个目标")

    replacementState := CreateMaintenanceTestSupervisor(rootPath)
    runtime.appStates[path] := replacementState
    AssertCoordinator(coordinator.EnsureWatcher(path, replacementState),
        "同路径的新控制器无法接管目录监听订阅")
    coordinator.CloseWatcher(stateObj)
    AssertCoordinator(coordinator.Watchers.Has(rootKey)
        && coordinator.Watchers[rootKey].subscribers.Has(path)
        && coordinator.Watchers[rootKey].subscribers[path]
            == replacementState,
        "旧控制器清理时删除了同路径新控制器的监听订阅")
    stateObj := replacementState
    coordinator.Watchers[rootKey].watcher.ThrowOnPoll := true
    stateObj.MaintenanceFingerprintCheckedTicks := 0
    coordinator.EventTick()
    AssertCoordinator(!runtime.guardWorkGate.Busy,
        "目录监听异常后没有释放共享守护工作门")
    AssertCoordinator(MaintenanceCoordinatorTestContext.Logs.Length
        && InStr(MaintenanceCoordinatorTestContext.Logs[-1],
            "升级文件监听异常"),
        "目录监听异常没有写入运行日志")
    AssertCoordinator(stateObj.MaintenanceFingerprintCheckedTicks > 0,
        "单个目录监听异常阻断了本轮目标指纹复核")
    coordinator.Watchers[rootKey].watcher.ThrowOnPoll := false
    coordinator.CloseWatcher(stateObj)
    AssertCoordinatorEqual(1, coordinator.Watchers.Count,
        "移除一个订阅时错误关闭了共享监听器")
    coordinator.CloseWatcher(secondState)
    AssertCoordinatorEqual(0, coordinator.Watchers.Count,
        "最后一个订阅移除后监听器没有释放")

    coordinator.Shutdown()
    AssertCoordinator(!coordinator.Initialize()
        && !coordinator.EnsureWatcher(path, stateObj),
        "已关闭的升级协调器仍能重新初始化或创建监听器")
    coordinator.EventTick()
    AssertCoordinatorEqual(0, coordinator.Watchers.Count,
        "已关闭的升级协调器被迟到的计时器回调重新创建监听器")

    try FileDelete(journalPath)
    try DirDelete(rootPath)
}

try {
    RunMaintenanceCoordinatorTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n", "**")
    ExitApp(1)
}
