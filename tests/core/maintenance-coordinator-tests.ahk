#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证升级保护协调器的参与者识别、目录监听、稳定确认、超时和恢复守护。
; 所有定时器与回调都需验证会话所有权，停止后的事件不得重新打开升级会话。

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
    static ScheduledCount := 0
    static SavedApps := 0
    static Logs := []
    static ReplaceDuringRefresh := false
    static QueryCount := 0
    static RestoredSessions := Map()
    static RecoveryObservation := ""
    static TargetReady := true
    static FingerprintOverride := ""
    static FingerprintCount := 0
}

class MaintenanceFakeInspector {
    __New() {
        this.NativeReady := true
        this.CaptureCount := 0
        this.CreationOverrides := Map()
    }

    GetCreationIdentity(pid) {
        if this.CreationOverrides.Has(pid)
            return this.CreationOverrides[pid]
        return MaintenanceTestCreationIdentity(pid)
    }

    CaptureNativeSnapshot() {
        this.CaptureCount++
        return {Ready: this.NativeReady, Processes: []}
    }

    GetImagePath(*) {
        return ""
    }
}

class MaintenanceFakeSnapshots {
    __New() {
        this.LatestSnapshotTicks := 0
        this.LatestSnapshotRequestTicks := 0
        this.LatestSnapshot := []
        this.LatestNativeSnapshotTicks := 0
        this.ReuseIntervalMs := 5000
        this.IndexFactory := MaintenanceTestCreateIndex
        this.RequestCount := 0
        this.StartCount := 0
        this.PumpCount := 0
    }

    RequestFresh() {
        this.RequestCount++
        return 24680
    }

    Start() {
        this.StartCount++
        return true
    }

    Pump() {
        this.PumpCount++
        return false
    }

    HasFreshSnapshot(*) {
        return false
    }

    HasFreshNativeSnapshot(*) {
        return false
    }

    CanRetry(*) {
        return true
    }

    StoreNativeSnapshot(capturedAtTicks := 0) {
        this.LatestNativeSnapshotTicks := capturedAtTicks
        return true
    }

    StoreSnapshot(*) {
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
        this.Changes := []
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
        changes := this.Changes
        this.Changes := []
        return changes
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

MaintenanceTestDeserializeSession(encodedValue) {
    if MaintenanceCoordinatorTestContext.RestoredSessions.Has(encodedValue)
        return MaintenanceCoordinatorTestContext.RestoredSessions[encodedValue]
    return {Path: "", Mode: "", StartedAt: "", BaselineFingerprint: "",
        FileChanged: false, Explicit: false}
}

MaintenanceTestFingerprint(path) {
    MaintenanceCoordinatorTestContext.FingerprintCount++
    if MaintenanceCoordinatorTestContext.FingerprintOverride != ""
        return MaintenanceCoordinatorTestContext.FingerprintOverride
    return "FP:" path
}

class CountingCoordinatorMaintenanceMatcher extends MaintenanceActorMatcher {
    __New(parameters*) {
        super.__New(parameters*)
        this.MatchCounts := Map()
        this.MatchCounts.CaseSense := "Off"
    }

    MatchPrepared(processInfo, context) {
        rootPath := context.RootPath
        this.MatchCounts[rootPath] := this.MatchCounts.Has(rootPath)
            ? this.MatchCounts[rootPath] + 1 : 1
        return super.MatchPrepared(processInfo, context)
    }
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
    return MaintenanceCoordinatorTestContext.TargetReady
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

MaintenanceTestObserve(path := "", snapshotIndex := "",
    maximumSnapshotAgeMs := 0, observationContext := "") {
    if IsObject(MaintenanceCoordinatorTestContext.RecoveryObservation)
        && IsObject(observationContext)
        return MaintenanceCoordinatorTestContext.RecoveryObservation
    return ProcessObservation.Stopped(1, "test")
}

MaintenanceTestQuerySnapshot(&ready) {
    MaintenanceCoordinatorTestContext.QueryCount++
    ready := true
    return []
}

MaintenanceTestRefreshShortcut(*) {
    if MaintenanceCoordinatorTestContext.ReplaceDuringRefresh {
        runtime := MaintenanceCoordinatorTestContext.Runtime
        for path, stateObj in runtime.appStates {
            replacement := CreateMaintenanceTestSupervisor(
                stateObj.MaintenanceConfig.InstallRoot)
            replacement.State := "REPLACEMENT"
            runtime.appStates[path] := replacement
            break
        }
    }
    return false
}

MaintenanceTestCreationIdentity(pid) {
    return pid ? Format("{:016X}", Integer(pid)) : ""
}

MaintenanceTestSaveApps(*) {
    MaintenanceCoordinatorTestContext.SavedApps++
}

MaintenanceTestScheduleRestart(path, stateObj, delayMs) {
    MaintenanceCoordinatorTestContext.ScheduledDelay := delayMs
    MaintenanceCoordinatorTestContext.ScheduledCount++
}

MaintenanceTestSerializeSession(*) {
    return "STATE"
}

MaintenanceTestSetIdentity(stateObj, pid, creationIdentity := "") {
    stateObj.PID := pid
    stateObj.PIDCreationIdentity := creationIdentity != ""
        ? creationIdentity : "CREATION-" pid
}

MaintenanceTestTargetExists(*) {
    return MaintenanceCoordinatorTestContext.Existing
}

MaintenanceTestUpdateRunning(path, stateObj) {
    stateObj.State := "RUNNING:" path
}

MaintenanceTestUpdateState(path, statusText, expectedState := "",
    expectedGeneration := 0, forceProjection := false, statusKind := "") {
    runtime := MaintenanceCoordinatorTestContext.Runtime
    if runtime.appStates.Has(path) {
        runtime.appStates[path].State := statusText
        if statusKind != ""
            runtime.appStates[path].StatusKind := statusKind
    }
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
    inspector := MaintenanceFakeInspector()
    runtime := {
        appStates: Map(),
        maintenanceJournalPath: journalPath,
        maintenancePollInterval: 1000,
        maintenanceProcessInterval: 1000,
        maintenanceFingerprintInterval: 30000,
        maintenanceFingerprintRetryInterval: 5000,
        guardWorkGate: GuardWorkGate(),
        retryDelayArray: [5000],
        processInspector: inspector,
        processSnapshots: snapshots,
        maintenanceActorMatcher: MaintenanceActorMatcher(
            MaintenanceTestCreationIdentity),
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
        TargetSubjectExists: MaintenanceTestTargetExists,
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
    AssertCoordinator(coordinator.QueueCommand("PING|")
        && coordinator.PendingCommands.Length == 0,
        "实例发现探针被错误排入升级维护命令队列")
    coordinator.Initialized := true
    coordinator.ProcessBaselineReady := false
    inspector.NativeReady := true
    baselineCaptureCount := inspector.CaptureCount
    coordinator.ProcessTick()
    AssertCoordinator(coordinator.ProcessBaselineReady
        && inspector.CaptureCount == baselineCaptureCount + 1
        && !runtime.guardWorkGate.Busy,
        "初始化时原生快照失败后，进程轮询没有重建升级参与者基线")
    stateObj.LastFileActivityTicks := coordinator.Now()
    inspector.NativeReady := false
    queryCountBeforeTick := MaintenanceCoordinatorTestContext.QueryCount
    startCountBeforeTick := snapshots.StartCount
    coordinator.ProcessTick()
    AssertCoordinator(snapshots.StartCount == startCountBeforeTick + 1
        && MaintenanceCoordinatorTestContext.QueryCount == queryCountBeforeTick
        && !runtime.guardWorkGate.Busy,
        "升级进程轮询在原生快照失败后同步执行 WMI，或没有释放工作门")
    inspector.NativeReady := true
    stateObj.LastFileActivityTicks := 0

    ; 更新器扫描证据暂不可用时，升级恢复仍应尝试一次受控的目标复核，
    ; 不能因为 MaintenanceActorCheckedTicks 暂未刷新而一路等到超时。
    stateObj.MaintenanceMode := MaintenancePhase.Stabilizing
    stateObj.MaintenanceFileChanged := true
    stateObj.MaintenanceStartedTicks := coordinator.Now() - 10000
    stateObj.MaintenanceLastActivityTicks := coordinator.Now() - 5000
    stateObj.MaintenanceActorCheckedTicks := 0
    recoveryPid := DllCall("kernel32\GetCurrentProcessId", "UInt")
    MaintenanceCoordinatorTestContext.RecoveryObservation :=
        ProcessObservation.Running(recoveryPid, "EXPECTED-CREATION",
            coordinator.Now(), "process-image-inferred")
    MaintenanceCoordinatorTestContext.TargetReady := false
    coordinator.Advance(path, stateObj)
    AssertCoordinator(stateObj.MaintenanceMode == MaintenancePhase.Normal
        && InStr(stateObj.State, "RUNNING:"),
        "升级进程证据暂不可用时，唯一目标复核没有恢复正常守护")
    MaintenanceCoordinatorTestContext.TargetReady := true
    MaintenanceCoordinatorTestContext.RecoveryObservation := ""
    coordinator.ResetSession(path, stateObj, false)

    currentPid := DllCall("kernel32\GetCurrentProcessId", "UInt")
    stateObj.PID := currentPid
    stateObj.PIDCreationIdentity := "EXPECTED-CREATION"
    inspector.CreationOverrides[currentPid] := ""
    AssertCoordinator(!coordinator.TargetAppearsRunning(stateObj),
        "创建身份不可读时被错误当成同一目标仍在运行")
    inspector.CreationOverrides[currentPid] := "EXPECTED-CREATION"
    AssertCoordinator(coordinator.TargetAppearsRunning(stateObj),
        "PID 与创建身份一致时没有识别目标仍在运行")
    inspector.CreationOverrides.Delete(currentPid)
    stateObj.PID := 0
    stateObj.PIDCreationIdentity := ""
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

    ; 快照只描述捕获瞬间。即使新鲜快照已经返回，也不能在完整检测窗口
    ; 结束前断言后续不会启动更新器并恢复普通拉起。
    MaintenanceCoordinatorTestContext.Existing := true
    MaintenanceCoordinatorTestContext.ScheduledCount := 0
    snapshots.LatestSnapshotRequestTicks :=
        stateObj.ArbitrationSnapshotRequestTicks
    stateObj.MaintenanceStartedTicks := coordinator.Now() - 4000
    coordinator.Advance(path, stateObj)
    AssertCoordinator(stateObj.MaintenanceMode
            == MaintenancePhase.Arbitrating
        && MaintenanceCoordinatorTestContext.ScheduledCount == 0,
        "新鲜快照在检测窗口结束前错误恢复了普通重启")
    stateObj.MaintenanceStartedTicks := coordinator.Now() - 6000
    coordinator.Advance(path, stateObj)
    AssertCoordinator(stateObj.MaintenanceMode == MaintenancePhase.Normal
        && MaintenanceCoordinatorTestContext.ScheduledCount == 1,
        "完整检测窗口结束后没有恢复普通重启")

    ; 后台 WMI 快照失败也不能走短窗口兜底，但完整检测窗口结束后必须
    ; 有确定出口，避免升级仲裁永久等待。
    MaintenanceCoordinatorTestContext.ScheduledCount := 0
    snapshots.LatestSnapshotRequestTicks := 0
    AssertCoordinator(coordinator.BeginArbitration(path, stateObj),
        "快照失败出口测试无法开始升级仲裁")
    stateObj.MaintenanceStartedTicks := coordinator.Now() - 4000
    coordinator.Advance(path, stateObj)
    AssertCoordinator(stateObj.MaintenanceMode
            == MaintenancePhase.Arbitrating
        && MaintenanceCoordinatorTestContext.ScheduledCount == 0,
        "快照失败时在检测窗口结束前错误恢复了普通重启")
    stateObj.MaintenanceStartedTicks := coordinator.Now() - 6000
    coordinator.Advance(path, stateObj)
    AssertCoordinator(stateObj.MaintenanceMode == MaintenancePhase.Normal
        && MaintenanceCoordinatorTestContext.ScheduledCount == 1,
        "快照失败后超过完整检测窗口仍未恢复普通重启")

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
    sharedWatcherEntry := coordinator.Watchers[rootKey]
    AssertCoordinator(coordinator.IsRelevantFootprintChange(path, stateObj,
            "SharedRuntime.dll", sharedWatcherEntry)
        && coordinator.IsRelevantFootprintChange(secondPath, secondState,
            "SharedRuntime.dll", sharedWatcherEntry),
        "共享安装目录的公共二进制变化没有保护全部相关目标")
    AssertCoordinator(!coordinator.IsRelevantFootprintChange(path, stateObj,
        "notes.txt", sharedWatcherEntry),
        "共享安装目录中的普通文档变化被错误提升为升级证据")
    AssertCoordinator(coordinator.IsRelevantFootprintChange(path, stateObj,
            "App.exe", sharedWatcherEntry),
        "安装根目录中的目标文件变化没有被识别")
    AssertCoordinator(!coordinator.IsRelevantFootprintChange(path, stateObj,
            "nested\App.exe", sharedWatcherEntry),
        "子目录中的同名文件被错误当成目标文件变化")
    AssertCoordinator(!coordinator.IsRelevantFootprintChange(path, stateObj,
            "*", sharedWatcherEntry),
        "普通状态下的监听溢出被错误当成已确认升级足迹")

    ; 监听溢出或畸形通知没有具体文件路径，只能要求目标指纹立即复核。
    ; 指纹不变时不得制造升级活动；指纹确实变化时仍应进入原有流程。
    stateObj.SafetyFingerprint := "FP:" path
    stateObj.MaintenanceFingerprintCheckedTicks := coordinator.Now()
    stateObj.MaintenanceFileChanged := false
    stateObj.LastFileActivityTicks := 0
    MaintenanceCoordinatorTestContext.FingerprintOverride := "FP:" path
    MaintenanceCoordinatorTestContext.FingerprintCount := 0
    sharedWatcherEntry.watcher.Changes := [{Action: 0, RelativePath: "*"}]
    coordinator.EventTick()
    AssertCoordinator(MaintenanceCoordinatorTestContext.FingerprintCount > 0
        && !stateObj.MaintenanceFileChanged
        && stateObj.LastFileActivityTicks == 0,
        "监听溢出没有复核目标指纹，或在指纹未变时制造了升级活动")

    stateObj.MaintenanceFingerprintCheckedTicks := coordinator.Now()
    MaintenanceCoordinatorTestContext.FingerprintCount := 0
    sharedWatcherEntry.watcher.Changes := [{Action: 3,
        RelativePath: "nested\App.exe"}]
    coordinator.EventTick()
    AssertCoordinator(MaintenanceCoordinatorTestContext.FingerprintCount > 0
        && !stateObj.MaintenanceFileChanged
        && stateObj.LastFileActivityTicks == 0,
        "子目录同名文件没有复核目标指纹，或被直接当成目标文件变化")

    stateObj.MaintenanceFingerprintCheckedTicks := coordinator.Now()
    MaintenanceCoordinatorTestContext.FingerprintOverride := "FP:CHANGED"
    MaintenanceCoordinatorTestContext.FingerprintCount := 0
    sharedWatcherEntry.watcher.Changes := [{Action: 0, RelativePath: "*"}]
    coordinator.EventTick()
    AssertCoordinator(MaintenanceCoordinatorTestContext.FingerprintCount > 0
        && stateObj.MaintenanceFileChanged
        && stateObj.LastFileActivityTicks > 0,
        "监听溢出后的目标指纹真实变化没有进入升级保护流程")
    coordinator.ResetSession(path, stateObj, false)
    MaintenanceCoordinatorTestContext.FingerprintOverride := ""

    stateObj.MaintenanceMode := MaintenancePhase.Updating
    stateObj.MaintenanceFileChanged := true
    stateObj.LastFileActivityTicks := 0
    AssertCoordinator(coordinator.IsRelevantFootprintChange(path, stateObj,
            "notes.txt", sharedWatcherEntry)
        && coordinator.IsRelevantFootprintChange(path, stateObj,
            "*", sharedWatcherEntry),
        "升级会话中的后续写入或监听溢出没有刷新稳定等待")
    coordinator.RecordFootprintActivity(path, stateObj, "*")
    AssertCoordinator(stateObj.LastFileActivityTicks > 0
        && stateObj.MaintenanceMode == MaintenancePhase.Updating,
        "升级会话中的后续文件活动没有延长稳定等待")
    coordinator.ResetSession(path, stateObj, false)

    ; Windows Installer 代理可能只有产品代码，既不在安装根目录也没有
    ; 父子关系。只有足迹已确认变化且进程近期启动时才接受这条弱证据，
    ; 且绝不把它写入永久学习列表。
    msiPid := 720001
    recentCreation := A_Now
    msiProcess := {pid: msiPid, parent: 0, name: "msiexec.exe",
        cmd: "/I {PRODUCT-CODE}", exe: "C:\Windows\System32\msiexec.exe",
        creation: recentCreation, identity: MaintenanceTestCreationIdentity(msiPid)}
    stateObj.MaintenanceMode := MaintenancePhase.Normal
    stateObj.MaintenanceFileChanged := false
    coordinator.RefreshActors([msiProcess], false, true,
        MaintenanceTestCreateIndex([msiProcess], coordinator.Now(), true),
        false)
    AssertCoordinator(stateObj.TransientActorIdentities.Count == 0,
        "普通运行期的外部 msiexec 被错误纳入升级参与者")
    stateObj.MaintenanceMode := MaintenancePhase.Updating
    stateObj.MaintenanceFileChanged := true
    stateObj.MaintenanceLastActivityTicks := coordinator.Now()
    staleMsiPid := 720000
    staleMsiProcess := {pid: staleMsiPid, parent: 0,
        name: "msiexec.exe", cmd: "/I {OTHER-PRODUCT}",
        exe: "C:\Windows\System32\msiexec.exe",
        creation: FormatTime(DateAdd(A_Now, -10, "Minutes"),
            "yyyyMMddHHmmss"),
        identity: MaintenanceTestCreationIdentity(staleMsiPid)}
    coordinator.RefreshActors([staleMsiProcess], false, true,
        MaintenanceTestCreateIndex([staleMsiProcess], coordinator.Now(),
            true), false)
    AssertCoordinator(stateObj.TransientActorIdentities.Count == 0,
        "足迹变化后把早已运行的无关 msiexec 误认成升级参与者")
    coordinator.RefreshActors([msiProcess], false, true,
        MaintenanceTestCreateIndex([msiProcess], coordinator.Now(), true),
        false)
    AssertCoordinator(stateObj.TransientActorIdentities.Count == 1
        && stateObj.TransientActorIdentities[msiPid ":"
            MaintenanceTestCreationIdentity(msiPid)].Match.Evidence
            == "maintenance-installer-signal"
        && stateObj.MaintenanceLearningCandidates.Count == 0,
        "确认足迹后的近期外部 msiexec 没有被识别为临时参与者")
    coordinator.ResetSession(path, stateObj, false)

    ; 普通名称的覆盖/复制进程没有安装器关键词，足迹确认后仍可凭安装
    ; 根目录路径进入完整快照候选集。
    copyPid := 720002
    copyProcess := {pid: copyPid, parent: 0, name: "FileCopyHost.exe",
        cmd: "", exe: rootPath "\FileCopyHost.exe", creation: "",
        identity: MaintenanceTestCreationIdentity(copyPid)}
    stateObj.MaintenanceMode := MaintenancePhase.Updating
    stateObj.MaintenanceFileChanged := true
    stateObj.MaintenanceLastActivityTicks := coordinator.Now()
    coordinator.RefreshActors([copyProcess], false, true,
        MaintenanceTestCreateIndex([copyProcess], coordinator.Now(), true),
        false)
    AssertCoordinator(stateObj.TransientActorIdentities.Count == 1
        && stateObj.TransientActorIdentities[copyPid ":"
            MaintenanceTestCreationIdentity(copyPid)].Match.Evidence
            == "maintenance-under-root",
        "普通名称的安装目录内复制进程没有进入升级参与者")
    coordinator.ResetSession(path, stateObj, false)

    ; 一个目标确认升级足迹后可以扫描完整快照，但不能迫使其他目标也遍历
    ; 全部普通进程。这里用 300 个非候选进程验证对象级候选隔离。
    savedAppStates := runtime.appStates
    runtime.appStates := Map()
    runtime.appStates.CaseSense := "Off"
    runtime.appStates[path] := stateObj
    isolatedRootPath := rootPath "-candidate-isolation"
    isolatedPath := isolatedRootPath "\Second.exe"
    isolatedState := CreateMaintenanceTestSupervisor(isolatedRootPath)
    runtime.appStates[isolatedPath] := isolatedState
    countingMatcher := CountingCoordinatorMaintenanceMatcher(
        MaintenanceTestCreationIdentity)
    runtime.maintenanceActorMatcher := countingMatcher
    stateObj.MaintenanceMode := MaintenancePhase.Updating
    stateObj.MaintenanceFileChanged := true
    stateObj.LastFileActivityTicks := coordinator.Now()
    stateObj.MaintenanceLastActivityTicks := coordinator.Now()
    ordinaryProcesses := []
    Loop 300 {
        ordinaryProcesses.Push({pid: 800000 + A_Index, parent: 0,
            name: "Worker" A_Index ".exe", cmd: "",
            exe: "C:\Neutral\Worker" A_Index ".exe", creation: "",
            identity: MaintenanceTestCreationIdentity(800000 + A_Index)})
    }
    coordinator.RefreshActors(ordinaryProcesses, false, true,
        MaintenanceTestCreateIndex(ordinaryProcesses, coordinator.Now(),
            true), false)
    firstRootKey := countingMatcher.Canonical(rootPath)
    secondRootKey := countingMatcher.Canonical(isolatedRootPath)
    AssertCoordinator(countingMatcher.MatchCounts.Has(firstRootKey)
        && countingMatcher.MatchCounts[firstRootKey] == 300
        && !countingMatcher.MatchCounts.Has(secondRootKey),
        "完整进程快照从已确认升级目标扩散到了其他守护对象"
        . "（已确认=" (countingMatcher.MatchCounts.Has(firstRootKey)
            ? countingMatcher.MatchCounts[firstRootKey] : 0)
        . "，其他=" (countingMatcher.MatchCounts.Has(secondRootKey)
            ? countingMatcher.MatchCounts[secondRootKey] : 0) "）")
    runtime.maintenanceActorMatcher := MaintenanceActorMatcher(
        MaintenanceTestCreationIdentity)
    coordinator.ResetSession(path, stateObj, false)
    runtime.appStates := savedAppStates

    learnedActorPath := rootPath "\ProductMaintenance.exe"
    learnedSignature := "P:" MaintenanceTestCanonical(learnedActorPath)
        . "|R:" MaintenanceTestCanonical(rootPath)
    stateObj.MaintenanceConfig.LearnedActors := [learnedSignature]
    learnedProcess := {pid: 700001, parent: 0, name: "Helper.exe",
        cmd: "", exe: learnedActorPath,
        creation: "很早以前的进程", identity: "LIVE"}
    baselineIndex := MaintenanceTestCreateIndex([learnedProcess],
        coordinator.Now(), true)
    coordinator.RefreshActors([learnedProcess], true, true,
        baselineIndex, false)
    AssertCoordinator(stateObj.TransientActorIdentities.Count == 1
        && coordinator.IsBlocking(stateObj),
        "已配置的更新程序在初始基线中运行较久时被错误忽略")
    coordinator.ResetSession(path, stateObj, false)
    stateObj.KnownActorIdentities := Map()
    stateObj.TransientActorIdentities := Map()
    stateObj.MaintenanceConfig.LearnedActors := []

    ; 已识别更新器退出后，普通名称子进程仍应通过父身份和创建时序接管会话。
    updaterPid := 710001
    childPid := 710002
    updaterProcess := {pid: updaterPid, parent: 0,
        name: "Updater.exe", cmd: "", exe: rootPath "\Updater.exe",
        creation: "", identity: MaintenanceTestCreationIdentity(updaterPid)}
    updaterIndex := MaintenanceTestCreateIndex([updaterProcess],
        coordinator.Now(), true)
    coordinator.RefreshActors([updaterProcess], false, true,
        updaterIndex, false)
    updaterKey := updaterPid ":" MaintenanceTestCreationIdentity(updaterPid)
    AssertCoordinator(stateObj.TransientActorIdentities.Has(updaterKey),
        "首个更新器没有进入短命交接缓存")
    childProcess := {pid: childPid, parent: updaterPid,
        name: "Worker.exe", cmd: "", exe: rootPath "\Worker.exe",
        creation: "", identity: MaintenanceTestCreationIdentity(childPid)}
    childIndex := MaintenanceTestCreateIndex([childProcess],
        coordinator.Now(), true)
    coordinator.RefreshActors([childProcess], false, true,
        childIndex, false)
    childKey := childPid ":" MaintenanceTestCreationIdentity(childPid)
    AssertCoordinator(stateObj.TransientActorIdentities.Has(childKey)
        && stateObj.TransientActorIdentities[childKey].Match.Evidence
            == "maintenance-descendant",
        "短命更新器退出后普通子进程没有接管升级保护会话")
    coordinator.ResetSession(path, stateObj, false)
    stateObj.KnownActorIdentities := Map()
    stateObj.TransientActorIdentities := Map()

    ; 文件稳定不能替代进程证据。扫描时间早于本次文件活动时必须继续等待，
    ; 新扫描确认没有参与者后才能恢复普通守护。
    MaintenanceCoordinatorTestContext.Existing := true
    MaintenanceCoordinatorTestContext.ScheduledCount := 0
    coordinator.Enter(path, stateObj, "测试进程证据门槛")
    evidenceNow := coordinator.Now()
    stateObj.MaintenanceMode := MaintenancePhase.Stabilizing
    stateObj.MaintenanceStartedTicks := evidenceNow - 5000
    stateObj.MaintenanceLastActivityTicks := evidenceNow - 5000
    stateObj.LastFileActivityTicks := evidenceNow - 4000
    stateObj.MaintenanceActorCheckedTicks := evidenceNow - 4500
    coordinator.Advance(path, stateObj)
    AssertCoordinator(stateObj.MaintenanceMode == MaintenancePhase.Stabilizing
        && MaintenanceCoordinatorTestContext.ScheduledCount == 0,
        "早于本次维护活动的进程快照仍放行了升级恢复")
    stateObj.MaintenanceActorCheckedTicks := coordinator.Now()
    coordinator.Advance(path, stateObj)
    AssertCoordinator(stateObj.MaintenanceMode == MaintenancePhase.Normal
        && MaintenanceCoordinatorTestContext.ScheduledCount == 1,
        "新鲜进程快照确认参与者结束后没有恢复普通守护")

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

    runtime.appStates[path] := stateObj
    coordinator.Enter(path, stateObj, "测试完成复核")
    stateObj.MaintenanceMode := MaintenancePhase.Stabilizing
    priorScheduledDelay := MaintenanceCoordinatorTestContext.ScheduledDelay
    MaintenanceCoordinatorTestContext.ReplaceDuringRefresh := true
    coordinator.Complete(path, stateObj)
    MaintenanceCoordinatorTestContext.ReplaceDuringRefresh := false
    AssertCoordinator(runtime.appStates[path] != stateObj
        && runtime.appStates[path].State == "REPLACEMENT"
        && MaintenanceCoordinatorTestContext.ScheduledDelay
            == priorScheduledDelay,
        "升级完成回调替换控制器后，旧会话仍继续提交状态或安排重启")

    timedOutPath := rootPath "\TimedOut.exe"
    invalidSessionPath := rootPath "\InvalidSession.exe"
    recoveringPath := rootPath "\Recovering.exe"
    timedOutState := CreateMaintenanceTestSupervisor(rootPath)
    invalidSessionState := CreateMaintenanceTestSupervisor(rootPath)
    recoveringState := CreateMaintenanceTestSupervisor(rootPath)
    runtime.appStates[timedOutPath] := timedOutState
    runtime.appStates[invalidSessionPath] := invalidSessionState
    runtime.appStates[recoveringPath] := recoveringState
    recentStartedAt := FormatTime(DateAdd(A_NowUTC, -1, "Seconds"),
        "yyyyMMddHHmmss")
    restoredActorIdentity := MaintenanceActorIdentity(730001,
        "0011223344556677", rootPath "\Updater2026.exe", rootPath, [])
    restoredActorSignature := "P:" MaintenanceTestCanonical(
        rootPath "\Updater2026.exe") "|R:" MaintenanceTestCanonical(rootPath)
    restoredActorRecord := {Identity: restoredActorIdentity,
        Match: MaintenanceActorMatchResult(true,
            "installer-under-root", restoredActorSignature)}
    MaintenanceCoordinatorTestContext.RestoredSessions := Map(
        "TIMED", {Path: timedOutPath, Mode: MaintenancePhase.TimedOut,
            StartedAt: recentStartedAt, BaselineFingerprint: "FP-OLD",
            FileChanged: true, Explicit: false},
        "INVALID", {Path: invalidSessionPath, Mode: "BrokenPhase",
            StartedAt: "not-a-time", BaselineFingerprint: "FP-BROKEN",
            FileChanged: true, Explicit: false},
        "ACTIVE", {Path: recoveringPath,
            Mode: MaintenancePhase.Stabilizing,
            StartedAt: recentStartedAt, BaselineFingerprint: "FP-ACTIVE",
            FileChanged: true, Explicit: false,
            ActorRecords: [restoredActorRecord],
            LearningCandidates: [restoredActorSignature]})
    IniDelete(journalPath, "Sessions")
    IniWrite("TIMED", journalPath, "Sessions", "Timed")
    IniWrite("INVALID", journalPath, "Sessions", "Invalid")
    IniWrite("ACTIVE", journalPath, "Sessions", "Active")
    coordinator.RestoreSessions()
    AssertCoordinator(timedOutState.MaintenanceMode
            == MaintenancePhase.TimedOut
        && invalidSessionState.MaintenanceMode == MaintenancePhase.TimedOut,
        "超时或损坏的恢复会话绕过了用户确认并重新进入自动恢复")
    AssertCoordinator(recoveringState.MaintenanceMode
            == MaintenancePhase.Recovering
        && recoveringState.Pending
        && recoveringState.KnownActorIdentities.Has(
            restoredActorIdentity.Key)
        && recoveringState.TransientActorIdentities.Has(
            restoredActorIdentity.Key)
        && recoveringState.MaintenanceLearningCandidates.Has(
            restoredActorSignature),
        "有效的未完成升级会话没有恢复更新器身份和待学习特征")

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
