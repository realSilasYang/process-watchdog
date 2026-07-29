#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证直接文件目标的更名候选识别、竞态复核、升级保护隔离与忽略冷却。
; 测试使用可控文件身份和目录事件，不创建生产窗口，也不读写用户配置。

#Include ..\..\src\Core\GuardTypes.ahk
#Include ..\..\src\Core\TargetRelocationService.ahk

AssertTargetRelocation(value, message) {
    if !value
        throw Error(message)
}

class TargetRelocationTestGate {
    TryEnter() {
        return true
    }

    Leave() {
    }
}

class TargetRelocationTestState {
    __New() {
        this.Enabled := true
        this.Generation := 1
        this.RelocationPending := false
        this.MaintenanceBusy := false
        this.MaintenanceProtectionEnabled := false
        this.RecentMaintenanceSignal := false
        this.State := ""
        this.StatusKind := ""
        this.ResetCount := 0
    }

    CancelScheduledTasks(*) {
        this.Generation++
    }
}

class TargetRelocationTestWatcher {
    __New(rootPath) {
        this.Root := rootPath
        this.Active := true
        this.Changes := []
        this.Closed := false
    }

    Open() {
        this.Active := true
        return true
    }

    Poll() {
        changes := this.Changes
        this.Changes := []
        return changes
    }

    Close() {
        this.Active := false
        this.Closed := true
    }
}

class TargetRelocationTestHarness {
    __New() {
        this.Clock := 100
        this.Files := Map()
        this.Files.CaseSense := "Off"
        this.Identities := Map()
        this.Identities.CaseSense := "Off"
        this.Resolutions := Map()
        this.Resolutions.CaseSense := "Off"
        this.ConflictTarget := ""
        this.Candidates := []
        this.Invalidated := []
        this.Logs := []
        this.Watchers := []
        this.ThrowWatcherFactory := false
        this.ThrowCandidateDelivery := false
        this.Runtime := {
            appStates: Map(),
            guardWorkGate: TargetRelocationTestGate()
        }
        this.Runtime.appStates.CaseSense := "Off"
        this.Service := TargetRelocationService(this.Runtime, {
            CanonicalPath: ObjBindMethod(this, "CanonicalPath"),
            DirectoryExists: ObjBindMethod(this, "DirectoryExists"),
            FindConflict: ObjBindMethod(this, "FindConflict"),
            GetIdentity: ObjBindMethod(this, "GetIdentity"),
            HasRecentMaintenanceSignal: ObjBindMethod(this,
                "HasRecentMaintenanceSignal"),
            IsMaintenanceBlocking: ObjBindMethod(this,
                "IsMaintenanceBlocking"),
            IsMaintenanceProtectionEnabled: ObjBindMethod(this,
                "IsMaintenanceProtectionEnabled"),
            Localize: ObjBindMethod(this, "Localize"),
            LocalizeDiagnostic: ObjBindMethod(this, "LocalizeDiagnostic"),
            Log: ObjBindMethod(this, "Log"),
            NormalizePath: ObjBindMethod(this, "NormalizePath"),
            Now: ObjBindMethod(this, "Now"),
            OnCandidate: ObjBindMethod(this, "OnCandidate"),
            OnCandidateInvalidated: ObjBindMethod(this, "OnInvalidated"),
            PathsEquivalent: ObjBindMethod(this, "PathsEquivalent"),
            ResetState: ObjBindMethod(this, "ResetState"),
            ResolveIdentityPath: ObjBindMethod(this, "ResolveIdentityPath"),
            TargetExists: ObjBindMethod(this, "TargetExists"),
            UpdateState: ObjBindMethod(this, "UpdateState"),
            WatcherFactory: ObjBindMethod(this, "CreateWatcher")
        })
    }

    AddTarget(path, identity) {
        stateObj := TargetRelocationTestState()
        this.Runtime.appStates[path] := stateObj
        this.Files[path] := true
        this.Identities[path] := identity
        return stateObj
    }

    MoveTarget(oldPath, newPath, identity) {
        this.Files[oldPath] := false
        this.Files[newPath] := true
        this.Identities[newPath] := identity
        this.Resolutions[oldPath] := newPath
    }

    NormalizePath(path) {
        return StrReplace(Trim(String(path)), "/", "\")
    }

    CanonicalPath(path) {
        return StrLower(this.NormalizePath(path))
    }

    PathsEquivalent(firstPath, secondPath) {
        return this.CanonicalPath(firstPath) == this.CanonicalPath(secondPath)
    }

    TargetExists(path) {
        return this.Files.Has(path) && this.Files[path]
    }

    DirectoryExists(*) {
        return true
    }

    GetIdentity(path) {
        if this.TargetExists(path) && this.Identities.Has(path)
            return this.Identities[path]
        return {Available: false, NativeIdentityAvailable: false}
    }

    ResolveIdentityPath(path, *) {
        return this.Resolutions.Has(path) ? this.Resolutions[path] : ""
    }

    FindConflict(*) {
        return this.ConflictTarget
    }

    IsMaintenanceBlocking(stateObj) {
        return stateObj.MaintenanceBusy
    }

    IsMaintenanceProtectionEnabled(path, stateObj) {
        return stateObj.MaintenanceProtectionEnabled
    }

    HasRecentMaintenanceSignal(path, stateObj) {
        return stateObj.RecentMaintenanceSignal
    }

    UpdateState(path, statusText, stateObj, generation,
        forceProjection, statusKind) {
        if stateObj.Generation != generation
            return false
        stateObj.State := statusText
        stateObj.StatusKind := statusKind
        return true
    }

    ResetState(path, stateObj) {
        stateObj.RelocationPending := false
        stateObj.ResetCount++
        return true
    }

    OnCandidate(candidate) {
        if this.ThrowCandidateDelivery
            throw Error("模拟确认窗口投递失败")
        this.Candidates.Push(candidate)
        return true
    }

    OnInvalidated(candidate) {
        this.Invalidated.Push(candidate)
    }

    CreateWatcher(rootPath) {
        if this.ThrowWatcherFactory
            throw Error("模拟目录监听器创建失败")
        watcher := TargetRelocationTestWatcher(rootPath)
        this.Watchers.Push(watcher)
        return watcher
    }

    Now() {
        return this.Clock
    }

    Advance(milliseconds) {
        this.Clock += milliseconds
    }

    Localize(template, values*) {
        return values.Length ? Format(template, values*) : template
    }

    LocalizeDiagnostic(text) {
        return text
    }

    Log(message) {
        this.Logs.Push(message)
    }
}

CreateRelocationIdentity(volume := 1, high := 2, low := 3) {
    return {
        Available: true,
        NativeIdentityAvailable: true,
        VolumeSerial: volume,
        FileIndexHigh: high,
        FileIndexLow: low,
        Fingerprint: Format("FP-{}-{}-{}", volume, high, low)
    }
}

CreateEventOnlyIdentity() {
    return {
        Available: true,
        NativeIdentityAvailable: false,
        VolumeSerial: 0,
        FileIndexHigh: 0,
        FileIndexLow: 0,
        Fingerprint: "NO-ID"
    }
}

DetectRelocationCandidate(harness, oldPath, newPath, identity) {
    stateObj := harness.AddTarget(oldPath, identity)
    harness.Service.SyncTargets()
    harness.MoveTarget(oldPath, newPath, identity)
    AssertTargetRelocation(!harness.Service.TryDetect(oldPath, stateObj),
        "首次缺失观察没有执行候选稳定延迟")
    harness.Advance(TargetRelocationService.CandidateDelayMs + 1)
    AssertTargetRelocation(harness.Service.TryDetect(oldPath, stateObj),
        "稳定延迟后没有识别更名候选")
    return {State: stateObj, Candidate: harness.Candidates[-1]}
}

RunTargetRelocationServiceTests() {
    oldExe := "C:\Apps\Tool\Tool.exe"
    newExe := "C:\Apps\Renamed\Tool Next.exe"
    identity := CreateRelocationIdentity()
    harness := TargetRelocationTestHarness()
    detection := DetectRelocationCandidate(harness, oldExe, newExe, identity)
    AssertTargetRelocation(detection.Candidate.Evidence == "FileIdentity"
        && detection.State.RelocationPending
        && detection.State.StatusKind == GuardStatusKind.RelocationPending
        && harness.Service.ValidateCandidate(detection.Candidate),
        "文件 ID 候选没有冻结控制器或通过确认前复核")

    AssertTargetRelocation(harness.Service.Ignore(detection.Candidate)
        && !detection.State.RelocationPending
        && detection.State.ResetCount == 1,
        "忽略候选没有释放控制器")
    harness.Advance(TargetRelocationService.CandidateDelayMs + 1)
    AssertTargetRelocation(!harness.Service.TryDetect(oldExe,
        detection.State), "忽略冷却期间重复发布了同一候选")

    harness.Files[oldExe] := true
    harness.Identities[oldExe] := identity
    harness.Service.ObserveAvailable(oldExe, detection.State, true)
    newerExe := "C:\Apps\Tool\Tool 2.exe"
    harness.MoveTarget(oldExe, newerExe, identity)
    AssertTargetRelocation(!harness.Service.TryDetect(oldExe,
        detection.State), "目标再次更名时跳过了稳定延迟")
    harness.Advance(TargetRelocationService.CandidateDelayMs + 1)
    AssertTargetRelocation(harness.Service.TryDetect(oldExe,
        detection.State), "原路径恢复后没有解除忽略冷却")
    changedCandidate := harness.Candidates[-1]
    harness.Files[newerExe] := false
    AssertTargetRelocation(!harness.Service.ValidateCandidate(changedCandidate)
        && harness.Service.Invalidate(changedCandidate)
        && !detection.State.RelocationPending,
        "确认前候选再次变化时没有作废并恢复控制器")

    scriptHarness := TargetRelocationTestHarness()
    oldScript := "C:\Scripts\worker.py"
    newScript := "C:\Scripts\worker-renamed.py"
    scriptIdentity := CreateRelocationIdentity(4, 5, 6)
    scriptDetection := DetectRelocationCandidate(scriptHarness, oldScript,
        newScript, scriptIdentity)
    AssertTargetRelocation(scriptHarness.Service.ValidateCandidate(
        scriptDetection.Candidate), "脚本更名没有被识别")
    scriptDetection.State.Generation++
    AssertTargetRelocation(!scriptHarness.Service.ValidateCandidate(
        scriptDetection.Candidate), "控制器代际变化后仍接受迟到候选")
    scriptHarness.Service.Invalidate(scriptDetection.Candidate)

    maintenanceHarness := TargetRelocationTestHarness()
    maintenanceState := maintenanceHarness.AddTarget(oldExe, identity)
    maintenanceHarness.Service.SyncTargets()
    maintenanceHarness.MoveTarget(oldExe, newExe, identity)
    maintenanceHarness.Service.TryDetect(oldExe, maintenanceState)
    maintenanceHarness.Advance(TargetRelocationService.CandidateDelayMs + 1)
    maintenanceState.MaintenanceBusy := true
    AssertTargetRelocation(!maintenanceHarness.Service.TryDetect(oldExe,
        maintenanceState) && !maintenanceHarness.Candidates.Length,
        "升级保护活动中发布了更名候选")
    maintenanceState.MaintenanceBusy := false
    maintenanceState.MaintenanceProtectionEnabled := true
    maintenanceState.RecentMaintenanceSignal := true
    AssertTargetRelocation(!maintenanceHarness.Service.TryDetect(oldExe,
        maintenanceState) && !maintenanceHarness.Candidates.Length,
        "近期升级信号尚未消退时发布了更名候选")
    maintenanceState.RecentMaintenanceSignal := false
    AssertTargetRelocation(maintenanceHarness.Service.TryDetect(oldExe,
        maintenanceState), "升级保护恢复正常后没有重新评估候选")

    ; 暂停期间发生更名时，恢复操作会重置控制器代际并先投影为初始化。
    ; 没有启用升级保护的条目即使残留目录活动信号，也必须继续识别新路径。
    pauseResumeHarness := TargetRelocationTestHarness()
    pausedScriptIdentity := CreateRelocationIdentity(7, 8, 9)
    pausedScriptState := pauseResumeHarness.AddTarget(oldScript,
        pausedScriptIdentity)
    pauseResumeHarness.Service.SyncTargets()
    pausedScriptState.Enabled := false
    pausedScriptState.CancelScheduledTasks()
    pauseResumeHarness.MoveTarget(oldScript, newScript,
        pausedScriptIdentity)
    pausedScriptState.RecentMaintenanceSignal := true
    AssertTargetRelocation(!pauseResumeHarness.Service.TryDetect(oldScript,
        pausedScriptState), "暂停状态仍然发布了更名候选")
    pausedScriptState.Enabled := true
    pausedScriptState.CancelScheduledTasks()
    AssertTargetRelocation(!pauseResumeHarness.Service.TryDetect(oldScript,
        pausedScriptState), "恢复后的首次缺失观察跳过了稳定延迟")
    pauseResumeHarness.Advance(
        TargetRelocationService.CandidateDelayMs + 1)
    AssertTargetRelocation(pauseResumeHarness.Service.TryDetect(oldScript,
            pausedScriptState)
            && pausedScriptState.RelocationPending
            && pauseResumeHarness.Candidates.Length == 1,
        "未启用升级保护时，近期目录活动阻止了暂停恢复后的更名识别")

    incompatibleHarness := TargetRelocationTestHarness()
    incompatibleState := incompatibleHarness.AddTarget(oldScript,
        scriptIdentity)
    incompatibleHarness.Service.SyncTargets()
    incompatibleHarness.MoveTarget(oldScript, "C:\Scripts\worker.txt",
        scriptIdentity)
    incompatibleHarness.Service.TryDetect(oldScript, incompatibleState)
    incompatibleHarness.Advance(TargetRelocationService.CandidateDelayMs + 1)
    AssertTargetRelocation(!incompatibleHarness.Service.TryDetect(oldScript,
        incompatibleState), "扩展名不兼容的文件被当作脚本更名")

    conflictHarness := TargetRelocationTestHarness()
    conflictState := conflictHarness.AddTarget(oldExe, identity)
    conflictHarness.Service.SyncTargets()
    conflictHarness.MoveTarget(oldExe, newExe, identity)
    conflictHarness.ConflictTarget := "C:\Other\Existing.exe"
    conflictHarness.Service.TryDetect(oldExe, conflictState)
    conflictHarness.Advance(TargetRelocationService.CandidateDelayMs + 1)
    AssertTargetRelocation(!conflictHarness.Service.TryDetect(oldExe,
        conflictState), "与现有守护身份冲突的候选仍被发布")

    eventHarness := TargetRelocationTestHarness()
    eventOld := "C:\Legacy\job.py"
    eventNew := "C:\Legacy\job-new.py"
    eventIdentity := CreateEventOnlyIdentity()
    eventState := eventHarness.AddTarget(eventOld, eventIdentity)
    eventHarness.Service.SyncTargets()
    eventHarness.Files[eventOld] := false
    eventHarness.Files[eventNew] := true
    eventHarness.Identities[eventNew] := eventIdentity
    watcherEntry := ""
    for _, entry in eventHarness.Service.Watchers {
        watcherEntry := entry
        break
    }
    AssertTargetRelocation(IsObject(watcherEntry),
        "没有为不支持文件 ID 的目标建立共享目录监听")
    eventHarness.Service.ProcessRenameEvents(watcherEntry, [
        {Action: TargetRelocationService.FILE_ACTION_RENAMED_OLD_NAME,
            RelativePath: "job.py"},
        {Action: TargetRelocationService.FILE_ACTION_RENAMED_NEW_NAME,
            RelativePath: "job-new.py"}
    ])
    eventHarness.Service.TryDetect(eventOld, eventState)
    eventHarness.Advance(TargetRelocationService.CandidateDelayMs + 1)
    AssertTargetRelocation(eventHarness.Service.TryDetect(eventOld,
        eventState) && eventHarness.Candidates[-1].Evidence == "RenameEvent",
        "Windows OLD／NEW 重命名事件没有作为文件 ID 回退证据")
    eventCandidate := eventHarness.Candidates[-1]
    AssertTargetRelocation(eventHarness.Service.ValidateCandidate(
        eventCandidate), "目录事件候选没有通过确认前文件指纹复核")
    replacedEventIdentity := CreateEventOnlyIdentity()
    replacedEventIdentity.Fingerprint := "REPLACED-FILE"
    eventHarness.Identities[eventNew] := replacedEventIdentity
    AssertTargetRelocation(!eventHarness.Service.ValidateCandidate(
            eventCandidate)
        && eventHarness.Service.Invalidate(eventCandidate),
        "仅凭目录事件识别的候选被其它文件替换后仍可确认")

    sharedWatcherHarness := TargetRelocationTestHarness()
    firstSharedPath := "C:\Shared\first.exe"
    secondSharedPath := "C:\Shared\second.exe"
    sharedWatcherHarness.AddTarget(firstSharedPath,
        CreateRelocationIdentity(8, 1, 1))
    sharedWatcherHarness.AddTarget(secondSharedPath,
        CreateRelocationIdentity(8, 1, 2))
    sharedWatcherHarness.Service.SyncTargets()
    sharedEntry := ""
    for _, watcherEntryCandidate in sharedWatcherHarness.Service.Watchers {
        sharedEntry := watcherEntryCandidate
        break
    }
    AssertTargetRelocation(sharedWatcherHarness.Service.Watchers.Count == 1
            && IsObject(sharedEntry)
            && sharedEntry.Subscribers.Count == 2,
        "同一目录的多个守护目标没有共享单个监听器")
    sharedWatcherHarness.Runtime.appStates.Delete(firstSharedPath)
    sharedWatcherHarness.Service.SyncTargets()
    AssertTargetRelocation(sharedWatcherHarness.Service.Watchers.Count == 1
            && sharedEntry.Subscribers.Count == 1
            && !sharedEntry.Watcher.Closed,
        "移除一个共享订阅时提前关闭了仍在使用的目录监听器")
    sharedWatcherHarness.Runtime.appStates.Delete(secondSharedPath)
    sharedWatcherHarness.Service.SyncTargets()
    AssertTargetRelocation(sharedWatcherHarness.Service.Watchers.Count == 0
            && sharedEntry.Watcher.Closed,
        "最后一个共享订阅移除后没有释放目录监听器")

    failedWatcherHarness := TargetRelocationTestHarness()
    failedWatcherHarness.ThrowWatcherFactory := true
    failedWatcherHarness.AddTarget("C:\Unavailable\target.exe",
        CreateRelocationIdentity(9, 1, 1))
    AssertTargetRelocation(failedWatcherHarness.Service.SyncTargets() == 1
            && failedWatcherHarness.Service.Watchers.Count == 0
            && failedWatcherHarness.Logs.Length
            && InStr(failedWatcherHarness.Logs[-1],
                "模拟目录监听器创建失败"),
        "目录监听器创建失败拖垮了目标同步或没有留下诊断")

    failedDeliveryHarness := TargetRelocationTestHarness()
    failedDeliveryHarness.ThrowCandidateDelivery := true
    deliveryState := failedDeliveryHarness.AddTarget(oldExe, identity)
    failedDeliveryHarness.Service.SyncTargets()
    failedDeliveryHarness.MoveTarget(oldExe, newExe, identity)
    failedDeliveryHarness.Service.TryDetect(oldExe, deliveryState)
    failedDeliveryHarness.Advance(
        TargetRelocationService.CandidateDelayMs + 1)
    AssertTargetRelocation(failedDeliveryHarness.Service.TryDetect(oldExe,
            deliveryState)
            && deliveryState.RelocationPending
            && failedDeliveryHarness.Candidates.Length == 0
            && failedDeliveryHarness.Logs.Length
            && InStr(failedDeliveryHarness.Logs[-1],
                "模拟确认窗口投递失败"),
        "确认窗口投递失败后没有保持冻结或记录诊断")
    failedDeliveryHarness.ThrowCandidateDelivery := false
    failedDeliveryHarness.Advance(
        TargetRelocationService.DeliveryRetryIntervalMs + 1)
    AssertTargetRelocation(
        failedDeliveryHarness.Service.RetryPendingDeliveries() == 1
            && failedDeliveryHarness.Candidates.Length == 1
            && failedDeliveryHarness.Service.ValidateCandidate(
                failedDeliveryHarness.Candidates[1]),
        "确认窗口恢复后没有重新投递仍然有效的候选")
}

try {
    RunTargetRelocationServiceTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
