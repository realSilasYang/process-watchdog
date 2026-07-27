#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 用真实 Windows 进程验证守护目标的端到端识别。
; 覆盖命令脚本、直接 EXE、普通快捷方式、短命启动器转交、快速退出和并发退出；
; 测试只在临时目录创建短时目标，完成后按 PID 关闭并删除，不读取或修改用户配置。

#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\Core\GuardTypes.ahk
#Include ..\..\src\Core\GuardStateMachine.ahk
#Include ..\..\src\Maintenance\MaintenanceStateMachine.ahk
#Include ..\..\src\Core\GuardWorkGate.ahk
#Include ..\..\src\Core\WatchdogScheduler.ahk
#Include ..\..\src\Core\RestartPolicy.ahk
#Include ..\..\src\Core\TargetSupervisor.ahk
#Include ..\..\src\Core\TargetSpecs.ahk
#Include ..\..\src\Core\GuardRuntime.ahk
#Include ..\..\src\Inspection\ShortcutResolver.ahk
#Include ..\..\src\Inspection\ShortcutTargetResolver.ahk
#Include ..\..\src\Inspection\ProcessSnapshotIndex.ahk
#Include ..\..\src\Inspection\ProcessInspector.ahk
#Include ..\..\src\Inspection\TargetProbe.ahk
#Include ..\..\src\Execution\TargetLauncher.ahk

AssertLiveTarget(value, message) {
    if !value
        throw Error(message)
}

QuoteLiveTarget(argument) {
    return '"' String(argument) '"'
}

FindLiveTargetExecutable(candidates*) {
    for candidate in candidates {
        if candidate != "" && FileExist(candidate)
            return candidate
    }
    return ""
}

CanonicalizeLiveTargetPath(path) {
    path := Trim(String(path), " `t`r`n`"")
    path := StrReplace(path, "/", "\")
    fullPathBuffer := Buffer(32768 * 2, 0)
    fullLength := DllCall("kernel32\GetFullPathNameW", "WStr", path,
        "UInt", 32768, "Ptr", fullPathBuffer.Ptr, "Ptr", 0, "UInt")
    if fullLength && fullLength < 32768
        path := StrGet(fullPathBuffer.Ptr, fullLength, "UTF-16")
    if FileExist(path) {
        longPathBuffer := Buffer(32768 * 2, 0)
        longLength := DllCall("kernel32\GetLongPathNameW", "WStr", path,
            "Ptr", longPathBuffer.Ptr, "UInt", 32768, "UInt")
        if longLength && longLength < 32768
            path := StrGet(longPathBuffer.Ptr, longLength, "UTF-16")
    }
    return StrLower(StrLen(path) > 3 ? RTrim(path, "\") : path)
}

GetLiveTargetFingerprint(path) {
    try return FileGetSize(path) "|" FileGetTime(path, "M")
    catch
        return "MISSING"
}

class LiveTargetSnapshotStub {
    __New() {
        this.LatestSnapshot := []
    }

    HasFreshSnapshot(*) {
        return false
    }
}

class LiveGuardMaintenanceStub {
    __New() {
        this.Stopped := false
    }

    StartTimers() {
        return true
    }

    IsBlocking(*) {
        return false
    }

    CanSafelyLaunch(path, stateObj, &reason) {
        reason := ""
        return true
    }

    TargetSubjectExists(path, *) {
        return !!FileExist(path)
    }

    ClearTargetMissing(*) {
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

    BeginArbitration(*) {
        return false
    }

    Shutdown() {
        this.Stopped := true
    }
}

class LiveGuardSnapshotProvider {
    __New(processInspector) {
        this.ProcessInspector := processInspector
        this.RequestTicks := 0
        this.CaptureCount := 0
        this.LatestIndex := ""
    }

    Pump() {
        return false
    }

    GetIndex(*) {
        if this.LatestIndex is ProcessSnapshotIndex
            return this.LatestIndex
        this.LatestIndex := this.CaptureIndex()
        return this.LatestIndex
    }

    RequestFresh() {
        this.RequestTicks := DllCall("kernel32\GetTickCount64", "UInt64")
        return this.RequestTicks
    }

    CaptureIndex() {
        this.CaptureCount++
        capturedAtTicks := DllCall("kernel32\GetTickCount64", "UInt64")
        snapshot := CaptureLiveTargetSnapshot()
        for processInfo in snapshot {
            processInfo.identity := this.ProcessInspector
                .GetCreationIdentity(processInfo.pid)
        }
        snapshotIndex := ProcessSnapshotIndex(snapshot, capturedAtTicks, true,
            CanonicalizeLiveTargetPath,
            ObjBindMethod(this.ProcessInspector, "GetCreationIdentity"))
        snapshotIndex.RequestTicks := this.RequestTicks
            ? this.RequestTicks : capturedAtTicks
        return snapshotIndex
    }

    PublishFresh(guardEngine) {
        snapshotIndex := this.CaptureIndex()
        this.LatestIndex := snapshotIndex
        return guardEngine.OnSnapshotPublished(snapshotIndex.Processes,
            snapshotIndex)
    }

    Invalidate() {
        this.LatestIndex := ""
    }
}

class LiveGuardRecordingLauncher extends TargetLauncher {
    __New(processes) {
        this.Processes := processes
    }

    Launch(parameters*) {
        launchResult := super.Launch(parameters*)
        LiveGuardTestContext.Invocations.Push({PID: launchResult.PID,
            Command: launchResult.Invocation.Command})
        if launchResult.PID
            this.Processes.Push(launchResult.PID)
        return launchResult
    }
}

class LiveGuardTestContext {
    static Specs := Map()
    static Runtime := ""
    static Inspector := ""
    static Probe := ""
    static LogPath := ""
    static Logs := []
    static Invocations := []
    static LastObservations := Map()
}

LiveGuardNormalize(path) {
    return CanonicalizeLiveTargetPath(path)
}

LiveGuardGetSpecs(path, *) {
    path := CanonicalizeLiveTargetPath(path)
    if !LiveGuardTestContext.Specs.Has(path)
        throw Error("真实守护测试缺少目标规格：" path)
    return LiveGuardTestContext.Specs[path]
}

LiveGuardObserve(path, snapshotIndex := "", *) {
    guardSpecs := LiveGuardGetSpecs(path)
    observation := LiveGuardTestContext.Probe.Observe(guardSpecs.Probe,
        snapshotIndex)
    LiveGuardTestContext.LastObservations[
        CanonicalizeLiveTargetPath(path)] := observation
    return observation
}

LiveGuardClearIdentity(stateObj, rememberLast := true) {
    if rememberLast && stateObj.PID {
        stateObj.LastKnownPID := stateObj.PID
        stateObj.LastKnownPIDCreationIdentity :=
            stateObj.PIDCreationIdentity
    }
    stateObj.PID := 0
    stateObj.PIDCreationIdentity := ""
}

LiveGuardSetIdentity(stateObj, pid, creationIdentity := "") {
    stateObj.PID := Integer(pid)
    stateObj.PIDCreationIdentity := creationIdentity != ""
        ? creationIdentity : LiveGuardTestContext.Inspector
            .GetCreationIdentity(pid)
    stateObj.LastKnownPID := stateObj.PID
    stateObj.LastKnownPIDCreationIdentity := stateObj.PIDCreationIdentity
    return stateObj.PIDCreationIdentity != ""
}

LiveGuardIdentityIsValid(path, stateObj) {
    if !stateObj.PID || !ProcessExist(stateObj.PID)
        return false
    currentIdentity := LiveGuardTestContext.Inspector
        .GetCreationIdentity(stateObj.PID)
    return currentIdentity != ""
        && currentIdentity == stateObj.PIDCreationIdentity
}

LiveGuardReferenceExists(path, *) {
    return !!FileExist(path)
}

LiveGuardRefreshShortcut(*) {
    return false
}

LiveGuardUpdateRunning(path, stateObj, expectedGeneration := 0) {
    if expectedGeneration && stateObj.Generation != expectedGeneration
        return false
    stateObj.TransitionTo(GuardPhase.Running)
    stateObj.Pending := false
    stateObj.TargetStartTicks := 0
    stateObj.State := "RUNNING:" path
    stateObj.StatusKind := GuardStatusKind.Running
    return true
}

LiveGuardUpdateState(path, statusText, expectedSupervisor := "",
    expectedGeneration := 0, forceProjection := false, statusKind := "") {
    normalizedPath := CanonicalizeLiveTargetPath(path)
    runtime := LiveGuardTestContext.Runtime
    if !runtime.appStates.Has(normalizedPath)
        return false
    stateObj := runtime.appStates[normalizedPath]
    if expectedSupervisor is TargetSupervisor
        && stateObj != expectedSupervisor {
        return false
    }
    if expectedGeneration && stateObj.Generation != expectedGeneration
        return false
    stateObj.State := statusText
    if statusKind != ""
        stateObj.StatusKind := statusKind
    return true
}

LiveGuardLog(message) {
    LiveGuardTestContext.Logs.Push(message)
}

LiveGuardGetLogPath(*) {
    return LiveGuardTestContext.LogPath
}

LiveGuardNoop(*) {
}

BuildLiveGuardDiagnostic(observation) {
    diagnostic := observation.Reason
    liveSnapshot := []
    try liveSnapshot := CaptureLiveTargetSnapshot()
    for logLine in LiveGuardTestContext.Logs
        diagnostic .= "`nLOG: " logLine
    for invocation in LiveGuardTestContext.Invocations {
        diagnostic .= "`nRUN: PID=" invocation.PID
            . " ALIVE=" (!!ProcessExist(invocation.PID))
            . " COMMAND=" invocation.Command
        for processInfo in liveSnapshot {
            if processInfo.pid == invocation.PID {
                diagnostic .= "`nWMI: " processInfo.cmd
                break
            }
        }
    }
    if LiveGuardTestContext.LogPath != "" {
        try diagnostic .= "`nBATCH: " FileRead(
            LiveGuardTestContext.LogPath, "UTF-8")
    }
    return diagnostic
}

BuildLiveGuardStateDiagnostic(path, stateObj) {
    normalizedPath := CanonicalizeLiveTargetPath(path)
    lastObservation := LiveGuardTestContext.LastObservations.Has(normalizedPath)
        ? LiveGuardTestContext.LastObservations[normalizedPath] : ""
    observation := LiveGuardObserve(path)
    diagnostic := "阶段=" stateObj.Phase
        . "，PID=" stateObj.PID
        . "，创建身份=" (stateObj.PIDCreationIdentity != ""
            ? stateObj.PIDCreationIdentity : "<空>")
        . "，Pending=" stateObj.Pending
        . "，失败次数=" stateObj.FailCount
        . "，重启任务=" (stateObj.RestartTask is TargetScheduledTask)
        . "，验证任务=" (stateObj.VerifyTask is TargetScheduledTask)
    if lastObservation is ProcessObservation {
        diagnostic .= "`n验证时探测=" lastObservation.Status
            . "，来源=" lastObservation.Source
            . "，原因码=" (lastObservation.ReasonCode != ""
                ? lastObservation.ReasonCode : "<空>")
            . "，原因=" (lastObservation.Reason != ""
                ? lastObservation.Reason : "<空>")
            . "，快照时间=" lastObservation.CapturedAtTicks
    }
    diagnostic .= "`n当前探测=" observation.Status
        . "，来源=" observation.Source
        . "，原因码=" (observation.ReasonCode != ""
            ? observation.ReasonCode : "<空>")
        . "，原因=" (observation.Reason != ""
            ? observation.Reason : "<空>")
    return diagnostic "`n" BuildLiveGuardDiagnostic(observation)
}

CreateLiveGuardSupervisor(scheduler) {
    stateObj := TargetSupervisor({Enabled: true})
    stateObj.Scheduler := scheduler
    stateObj.MaintenanceConfig := {Enabled: false}
    return stateObj
}

WaitForLiveGuardSpecs(guardSpecs, shouldRun, timeoutMs := 7000) {
    probeKind := guardSpecs.Probe.Kind
    if probeKind == TargetProbeKind.ImagePath
        return WaitForLiveTarget(probeKind,
            guardSpecs.Probe.TargetPath, shouldRun, timeoutMs)
    if probeKind == TargetProbeKind.CommandTarget
        return WaitForLiveTarget(probeKind,
            guardSpecs.Probe.TargetPath, shouldRun, timeoutMs)
    return ProcessObservation.Unknown(0, "live-guard",
        "真实恢复测试不支持该探测类型")
}

RunLiveGuardRecoveryTests(recoveryTargets, quickExitTarget, tempRoot,
    processes) {
    scheduler := WatchdogScheduler("", false, "")
    maintenance := LiveGuardMaintenanceStub()
    inspector := ProcessInspector()
    snapshots := LiveGuardSnapshotProvider(inspector)
    probeEngine := TargetProbe(ObjBindMethod(snapshots, "GetIndex"),
        ObjBindMethod(inspector, "CaptureNativeSnapshot"),
        ObjBindMethod(inspector, "GetImagePath"),
        ObjBindMethod(inspector, "GetCreationIdentity"),
        CanonicalizeLiveTargetPath,
        ObjBindMethod(inspector, "CaptureAutoHotkeyScriptSnapshot"))
    launcher := LiveGuardRecordingLauncher(processes)
    states := Map()
    states.CaseSense := "Off"
    orderedPaths := []
    specsByPath := Map()
    specsByPath.CaseSense := "Off"
    for recoveryTarget in recoveryTargets {
        normalizedPath := CanonicalizeLiveTargetPath(recoveryTarget.Path)
        stateObj := CreateLiveGuardSupervisor(scheduler)
        states[normalizedPath] := stateObj
        orderedPaths.Push(normalizedPath)
        specsByPath[normalizedPath] := recoveryTarget.Specs
        recoveryTarget.State := stateObj
    }
    runtime := {
        appStates: states,
        appOrder: orderedPaths,
        checkInterval: 1000,
        retryDelayArray: [100, 500],
        guardWorkGate: GuardWorkGate(),
        scheduler: scheduler,
        maintenanceCoordinator: maintenance,
        processSnapshots: snapshots,
        processInspector: inspector,
        targetLauncher: launcher
    }
    callbacks := {
        ClearProcessIdentity: LiveGuardClearIdentity,
        GetLogFilePath: LiveGuardGetLogPath,
        GetTargetSpecs: LiveGuardGetSpecs,
        Log: LiveGuardLog,
        LogSlow: LiveGuardNoop,
        NormalizeTargetPath: LiveGuardNormalize,
        ObserveTarget: LiveGuardObserve,
        RefreshShortcutIdentity: LiveGuardRefreshShortcut,
        SaveApps: LiveGuardNoop,
        SetProcessIdentity: LiveGuardSetIdentity,
        StateProcessIdentityIsValid: LiveGuardIdentityIsValid,
        TargetReferenceExists: LiveGuardReferenceExists,
        UpdateRunningState: LiveGuardUpdateRunning,
        UpdateState: LiveGuardUpdateState
    }
    guardEngine := GuardRuntime(runtime, callbacks)
    scheduler.ErrorHandler := ObjBindMethod(guardEngine, "HandleTaskError")
    LiveGuardTestContext.Specs := specsByPath
    LiveGuardTestContext.Runtime := runtime
    LiveGuardTestContext.Inspector := inspector
    LiveGuardTestContext.Probe := probeEngine
    LiveGuardTestContext.LogPath := tempRoot "\guard-batch.log"
    LiveGuardTestContext.Logs := []
    LiveGuardTestContext.Invocations := []
    LiveGuardTestContext.LastObservations := Map()

    try {
        ; 先由正式监控轮次接管现存进程身份，再同时终止所有目标，证明并发
        ; 崩溃不会让某一项遗漏或直接用同一份旧快照确认两次停止。
        guardEngine.MonitorTick()
        for recoveryTarget in recoveryTargets {
            AssertLiveTarget(recoveryTarget.State.Phase == GuardPhase.Running
                && recoveryTarget.State.PID,
                recoveryTarget.Name " 未被 GuardRuntime 接管为运行状态")
        }
        for recoveryTarget in recoveryTargets {
            if recoveryTarget.State.PID
                try ProcessClose(recoveryTarget.State.PID)
        }
        for recoveryTarget in recoveryTargets {
            if recoveryTarget.State.PID
                ProcessWaitClose(recoveryTarget.State.PID, 5)
        }
        ; ProcessWaitClose 只确认 PID 句柄已结束；WMI 命令行快照可能仍短暂保留
        ; 刚退出的进程。先等正式探测面确认全部目标停止，再验证守护状态机的
        ; 两次独立停止证据，避免把系统快照传播延迟误报为产品回归。
        confirmedRecoveryTargets := []
        for recoveryTarget in recoveryTargets {
            stoppedObservation := WaitForLiveGuardSpecs(
                recoveryTarget.Specs, false)
            if stoppedObservation.IsStopped() {
                confirmedRecoveryTargets.Push(recoveryTarget)
                continue
            }
            ; 本机可能同时存在小助手无权读取命令行的同类解释器。正式守护在
            ; 这种情况下必须保守地返回未知，测试也不能伪造“已停止”证据；
            ; 其余能够明确探测的目标继续覆盖完整恢复链路。
            AssertLiveTarget(stoppedObservation.IsUnknown()
                && stoppedObservation.ReasonCode
                    == ProcessObservationReason.CommandLineUnavailable,
                recoveryTarget.Name " 退出后仍出现在实时进程快照中："
                    stoppedObservation.Reason)
        }
        AssertLiveTarget(confirmedRecoveryTargets.Length >= 3,
            "可明确确认停止的真实目标不足，无法覆盖并发恢复链路")
        recoveryTargets := confirmedRecoveryTargets
        snapshots.Invalidate()
        inspector.AutoHotkeyScriptSnapshot := ""
        guardEngine.MonitorTick()
        for recoveryTarget in recoveryTargets {
            AssertLiveTarget(recoveryTarget.State.Phase
                == GuardPhase.SuspectedStopped
                && recoveryTarget.State.RestartTask == "",
                recoveryTarget.Name " 首次停止证据未停留在疑似停止"
                    "（实际阶段：" recoveryTarget.State.Phase
                    "，重启任务：" Type(recoveryTarget.State.RestartTask) "）")
        }
        Sleep(50)
        snapshots.Invalidate()
        inspector.AutoHotkeyScriptSnapshot := ""
        guardEngine.MonitorTick()
        for recoveryTarget in recoveryTargets {
            AssertLiveTarget(recoveryTarget.State.RestartTask
                is TargetScheduledTask,
                recoveryTarget.Name " 第二次独立停止证据没有安排恢复")
        }
        Sleep(120)
        scheduler.RunDue()

        ; 生产服务会把多个启动请求合并为一份后台快照。这里同样立即发布共享
        ; 快照，不能先为每个目标串行执行 WMI 轮询，否则会人为越过等待期限。
        ; 启动验证最多包含初次检查和一次短命启动器转交复核。每轮都发布同一份
        ; 共享快照并等待当前最晚任务，既贴近生产服务的合并采集方式，也用固定
        ; 轮数保证测试不会因错误调度而无限等待。
        Loop 2 {
            snapshots.PublishFresh(guardEngine)
            latestVerificationDue := 0
            for recoveryTarget in recoveryTargets {
                if recoveryTarget.State.VerifyTask is TargetScheduledTask {
                    latestVerificationDue := Max(latestVerificationDue,
                        recoveryTarget.State.VerifyTask.DueTicks)
                }
            }
            if !latestVerificationDue
                break
            verificationWaitMs := Max(1,
                latestVerificationDue - scheduler.Now() + 50)
            Sleep(verificationWaitMs)
            scheduler.RunDue()
        }
        for recoveryTarget in recoveryTargets {
            AssertLiveTarget(recoveryTarget.State.Phase == GuardPhase.Running
                && recoveryTarget.State.PID
                && recoveryTarget.State.PIDCreationIdentity != ""
                && !recoveryTarget.State.Pending
                && recoveryTarget.State.FailCount == 0,
                recoveryTarget.Name " 重启后没有通过 GuardRuntime 稳定验证：`n"
                    . BuildLiveGuardStateDiagnostic(recoveryTarget.Path,
                        recoveryTarget.State))
        }

        ; 快速退出目标必须进入失败重试，而不能因 Run 返回过 PID 就被当成成功。
        quickPath := CanonicalizeLiveTargetPath(quickExitTarget.Path)
        quickState := CreateLiveGuardSupervisor(scheduler)
        states[quickPath] := quickState
        orderedPaths.Push(quickPath)
        specsByPath[quickPath] := quickExitTarget.Specs
        guardEngine.RestartCore(quickPath, quickState)
        AssertLiveTarget(quickState.VerifyTask is TargetScheduledTask,
            "快速退出目标启动后没有进入稳定验证")
        AssertLiveTarget(LiveGuardTestContext.Invocations.Length > 0,
            "快速退出目标没有留下可核对的启动记录")
        quickInvocation := LiveGuardTestContext.Invocations[-1]
        if ProcessExist(quickInvocation.PID)
            ProcessWaitClose(quickInvocation.PID, 5)
        quickStoppedObservation := WaitForLiveGuardSpecs(
            quickExitTarget.Specs, false)
        AssertLiveTarget(quickStoppedObservation.IsStopped(),
            "快速退出测试目标在验证前没有明确退出："
                . quickStoppedObservation.Reason)
        quickDueTicks := quickState.VerifyTask.DueTicks
        Sleep(Max(1, quickDueTicks - scheduler.Now() + 50))
        scheduler.RunDue()
        AssertLiveTarget(quickState.VerifyAttempts == 1
            && quickState.FailCount == 0
            && quickState.VerifyTask is TargetScheduledTask,
            "快速退出目标的首次停止证据没有进入有界复核")
        quickSecondDueTicks := quickState.VerifyTask.DueTicks
        Sleep(Max(1, quickSecondDueTicks - scheduler.Now() + 50))
        scheduler.RunDue()
        AssertLiveTarget(quickState.FailCount == 1
            && quickState.RestartTask is TargetScheduledTask
            && quickState.Phase != GuardPhase.Running,
            "快速退出目标被错误当成稳定运行，或没有进入重试")
        quickState.CancelScheduledTasks()
    } finally {
        guardEngine.Shutdown()
        LiveGuardTestContext.Specs := Map()
        LiveGuardTestContext.Runtime := ""
        LiveGuardTestContext.Inspector := ""
        LiveGuardTestContext.Probe := ""
    }
}

CreateLiveShortcutResolver() {
    return ShortcutTargetResolver(LiveTargetSnapshotStub(), {
        ReadShortcut: ObjBindMethod(ShortcutResolver, "Read"),
        CanonicalPath: CanonicalizeLiveTargetPath,
        GetFileFingerprint: GetLiveTargetFingerprint,
        NormalizeTargetPath: CanonicalizeLiveTargetPath
    })
}

CaptureLiveTargetSnapshot() {
    snapshot := []
    wmiService := ComObjGet("winmgmts:")
    processes := wmiService.ExecQuery("SELECT ProcessId, ParentProcessId, "
        . "Name, CommandLine, ExecutablePath, CreationDate FROM Win32_Process")
    for process in processes {
        processInfo := {pid: 0, parent: 0, name: "", cmd: "", exe: "",
            creation: "", observedTicks: A_TickCount}
        try processInfo.pid := Integer(process.ProcessId)
        try processInfo.parent := Integer(process.ParentProcessId)
        try processInfo.name := process.Name
        try processInfo.cmd := process.CommandLine
        try processInfo.exe := process.ExecutablePath
        try processInfo.creation := process.CreationDate
        if processInfo.pid
            snapshot.Push(processInfo)
    }
    return snapshot
}

ObserveLiveTarget(kind, targetPath) {
    snapshotTicks := DllCall("kernel32\GetTickCount64", "UInt64")
    snapshotIndex := ProcessSnapshotIndex(CaptureLiveTargetSnapshot(),
        snapshotTicks, true, CanonicalizeLiveTargetPath)
    return kind == TargetProbeKind.CommandTarget
        ? snapshotIndex.ObserveCommandTarget(targetPath)
        : snapshotIndex.ObserveImagePath(targetPath)
}

WaitForLiveTarget(kind, targetPath, shouldRun, timeoutMs := 5000) {
    deadline := DllCall("kernel32\GetTickCount64", "UInt64") + timeoutMs
    observation := ProcessObservation.Unknown(0, "live-test")
    Loop {
        observation := ObserveLiveTarget(kind, targetPath)
        if shouldRun ? observation.IsRunning() : observation.IsStopped()
            return observation
        if DllCall("kernel32\GetTickCount64", "UInt64") >= deadline {
            ; Win32_Process 可能在 Shell 启动快捷方式后恰好落后一轮查询；
            ; 截止时使用独立终态快照，避免把提供者缓存边界当成探活失败。
            Sleep(100)
            return ObserveLiveTarget(kind, targetPath)
        }
        Sleep(100)
    }
}

DescribeLiveTargetLaunch(observation, targetPath, launcherPid) {
    details := "status=" observation.Status
        . ";reasonCode=" observation.ReasonCode
        . ";launcherPid=" launcherPid
        . ";launcherAlive=" (!!launcherPid && !!ProcessExist(launcherPid))
    SplitPath(targetPath, &targetName)
    try snapshot := CaptureLiveTargetSnapshot()
    catch as snapshotError
        return details ";snapshotError=" Type(snapshotError)
    candidateCount := 0
    for processInfo in snapshot {
        isLauncher := launcherPid && processInfo.pid == launcherPid
        isTargetName := processInfo.name != ""
            && StrLower(processInfo.name) == StrLower(targetName)
        if !isLauncher && !isTargetName
            continue
        candidateCount++
        details .= "|candidatePid=" processInfo.pid
            . ";name=" processInfo.name
            . ";exe=" processInfo.exe
            . ";cmd=" processInfo.cmd
    }
    return details ";candidateCount=" candidateCount
}

StartLiveExecutable(executablePath, arguments, processes) {
    Run(QuoteLiveTarget(executablePath) " " arguments, A_Temp, "Hide", &pid)
    AssertLiveTarget(pid && ProcessWait(pid, 5),
        "真实 EXE 测试进程没有启动：" executablePath)
    processes.Push(pid)
    return pid
}

CopyLiveExecutable(sourcePath, targetPath) {
    FileCopy(sourcePath, targetPath, 1)
    AssertLiveTarget(FileExist(targetPath),
        "无法准备真实 EXE 测试目标：" targetPath)
    return targetPath
}

CloseLiveTargetProcesses(rootPids, tempRoot := "") {
    rootPidSet := Map()
    for pid in rootPids {
        rootPidSet[pid] := true
    }
    canonicalRoot := tempRoot != ""
        ? CanonicalizeLiveTargetPath(tempRoot) : ""
    Loop 20 {
        try snapshot := CaptureLiveTargetSnapshot()
        catch {
            ; 有临时目录身份时宁可等待下一轮快照，也不依据可能已复用的 PID 关闭进程。
            if canonicalRoot == "" {
                for pid in rootPidSet {
                    try ProcessClose(pid)
                }
            }
            Sleep(100)
            continue
        }
        ; PID 在 Windows 上会被快速复用。每轮都从当前路径证据重建集合，避免把
        ; 已退出测试进程的旧 PID 误认为新的无关进程。
        tracked := Map()
        for processInfo in snapshot {
            belongsToTempRoot := canonicalRoot != ""
                && ((processInfo.HasOwnProp("cmd")
                        && InStr(CanonicalizeLiveTargetPath(
                            processInfo.cmd), canonicalRoot))
                    || (processInfo.HasOwnProp("exe")
                        && InStr(CanonicalizeLiveTargetPath(
                            processInfo.exe), canonicalRoot) == 1))
            if belongsToTempRoot
                tracked[processInfo.pid] := true
            else if canonicalRoot == "" && rootPidSet.Has(processInfo.pid)
                tracked[processInfo.pid] := true
        }
        changed := true
        while changed {
            changed := false
            for processInfo in snapshot {
                if tracked.Has(processInfo.pid)
                    || !tracked.Has(processInfo.parent)
                    continue
                tracked[processInfo.pid] := true
                changed := true
            }
        }
        if tracked.Count == 0
            return true
        closeOrder := []
        for processInfo in snapshot {
            if tracked.Has(processInfo.pid)
                closeOrder.Push(processInfo.pid)
        }
        Loop closeOrder.Length {
            pid := closeOrder[closeOrder.Length - A_Index + 1]
            try ProcessClose(pid)
        }
        Sleep(100)
    }
    return false
}

DeleteLiveTargetTempRoot(tempRoot) {
    Loop 20 {
        try DirDelete(tempRoot, true)
        if !DirExist(tempRoot)
            return true
        Sleep(100)
    }
    return false
}

DeleteStaleLiveTargetRoots() {
    Loop Files, A_Temp "\watchdog-live-command-target-*", "D"
        DeleteLiveTargetTempRoot(A_LoopFileFullPath)
}

RunLiveCommandTargetTests() {
    DeleteStaleLiveTargetRoots()
    tempRoot := A_Temp "\watchdog-live-command-target-"
        . DllCall("kernel32\GetCurrentProcessId", "UInt")
    processes := []
    targets := []
    try {
        DirCreate(tempRoot)

        ahkTarget := tempRoot "\live.ahk"
        FileAppend("#Requires AutoHotkey v2.0 64-bit`r`nSleep(60000)`r`n",
            ahkTarget, "UTF-8-RAW")
        targets.Push({Name: "AutoHotkey", Path: ahkTarget,
            Command: QuoteLiveTarget(A_AhkPath) " " QuoteLiveTarget(ahkTarget)})

        cmdTarget := tempRoot "\live.cmd"
        FileAppend("@echo off`r`nping -n 61 127.0.0.1 >nul`r`n",
            cmdTarget, "UTF-8-RAW")
        targets.Push({Name: "CMD", Path: cmdTarget,
            Command: 'cmd.exe /d /c ""' cmdTarget '""'})

        vbsTarget := tempRoot "\live.vbs"
        FileAppend("WScript.Sleep 60000`r`n", vbsTarget, "UTF-8-RAW")
        targets.Push({Name: "VBScript", Path: vbsTarget,
            Command: 'wscript.exe //B ' QuoteLiveTarget(vbsTarget)})

        powershellPath := FindLiveTargetExecutable(
            A_WinDir "\System32\WindowsPowerShell\v1.0\powershell.exe",
            A_WinDir "\Sysnative\WindowsPowerShell\v1.0\powershell.exe")
        if powershellPath != "" {
            psTarget := tempRoot "\live.ps1"
            FileAppend("Start-Sleep -Seconds 60`r`n", psTarget, "UTF-8-RAW")
            targets.Push({Name: "PowerShell", Path: psTarget,
                Command: QuoteLiveTarget(powershellPath)
                    . " -NoProfile -ExecutionPolicy Bypass -File "
                    . QuoteLiveTarget(psTarget)})
        }

        pythonPath := FindLiveTargetExecutable("C:\Python314\python.exe",
            "C:\Python313\python.exe", "C:\Python312\python.exe")
        if pythonPath != "" {
            pythonTarget := tempRoot "\live.py"
            FileAppend("import time`r`ntime.sleep(15)`r`n", pythonTarget,
                "UTF-8-RAW")
            targets.Push({Name: "Python", Path: pythonTarget,
                Command: QuoteLiveTarget(pythonPath) " "
                    . QuoteLiveTarget(pythonTarget)})
        }

        nodePath := FindLiveTargetExecutable(
            "D:\Program Files\nodejs\node.exe",
            A_ProgramFiles "\nodejs\node.exe")
        if nodePath != "" {
            nodeTarget := tempRoot "\live.js"
            FileAppend("setTimeout(() => {}, 15000);`r`n", nodeTarget,
                "UTF-8-RAW")
            targets.Push({Name: "Node.js", Path: nodeTarget,
                Command: QuoteLiveTarget(nodePath) " " QuoteLiveTarget(nodeTarget)})
        }

        for target in targets {
            Run(target.Command, tempRoot, "Hide", &pid)
            AssertLiveTarget(pid && ProcessWait(pid, 5),
                target.Name " 测试进程没有启动")
            target.PID := pid
            processes.Push(pid)
        }

        Sleep(800)
        snapshotTicks := DllCall("kernel32\GetTickCount64", "UInt64")
        snapshotIndex := ProcessSnapshotIndex(CaptureLiveTargetSnapshot(),
            snapshotTicks, true)
        for target in targets {
            observation := snapshotIndex.ObserveCommandTarget(target.Path)
            AssertLiveTarget(observation.IsRunning(),
                target.Name " 真实进程未按完整目标路径识别："
                    . observation.Reason)
        }

        pingSource := FindLiveTargetExecutable(
            A_WinDir "\System32\PING.EXE",
            A_WinDir "\Sysnative\PING.EXE")
        AssertLiveTarget(pingSource != "",
            "系统 PING.EXE 不可用，无法执行真实 EXE 守护测试")

        directExe := CopyLiveExecutable(pingSource,
            tempRoot "\WatchdogLiveDirect.exe")
        directPid := StartLiveExecutable(directExe,
            "-t 127.0.0.1", processes)
        directObservation := WaitForLiveTarget(TargetProbeKind.ImagePath,
            directExe, true)
        AssertLiveTarget(directObservation.IsRunning(),
            "直接 EXE 未按完整镜像路径识别：" directObservation.Reason)

        shortcutExe := CopyLiveExecutable(pingSource,
            tempRoot "\WatchdogLiveShortcut.exe")
        shortcutPath := tempRoot "\WatchdogLiveShortcut.lnk"
        FileCreateShortcut(shortcutExe, shortcutPath, tempRoot,
            "-t 127.0.0.1")
        shortcutInfo := ShortcutResolver.Read(shortcutPath)
        AssertLiveTarget(shortcutInfo.Readable
            && CanonicalizeLiveTargetPath(shortcutInfo.TargetPath)
                == CanonicalizeLiveTargetPath(shortcutExe),
            "普通快捷方式没有解析到真实 EXE：读取值="
                . shortcutInfo.TargetPath "，预期值=" shortcutExe)
        shortcutSpecs := TargetSpecFactory.Create(shortcutPath, {
            ResolvedTarget: shortcutInfo.TargetPath,
            ShortcutArguments: shortcutInfo.Arguments,
            ShortcutWorkingDirectory: shortcutInfo.WorkingDirectory,
            ShortcutReadable: true,
            EntryExists: true,
            ResolvedTargetExists: true
        })
        AssertLiveTarget(shortcutSpecs.Launch.UsesShortcutEntry
            && shortcutSpecs.Probe.Kind == TargetProbeKind.ImagePath
            && CanonicalizeLiveTargetPath(shortcutSpecs.Probe.TargetPath)
                == CanonicalizeLiveTargetPath(shortcutExe),
            "普通快捷方式没有正确分离启动入口与探活身份")
        Run(shortcutPath, tempRoot, "Hide", &shortcutLauncherPid)
        if shortcutLauncherPid
            processes.Push(shortcutLauncherPid)
        shortcutObservation := WaitForLiveTarget(TargetProbeKind.ImagePath,
            shortcutExe, true)
        AssertLiveTarget(shortcutObservation.IsRunning(),
            "普通快捷方式启动后的真实进程未被识别："
                . shortcutObservation.Reason " ["
                . DescribeLiveTargetLaunch(shortcutObservation, shortcutExe,
                    shortcutLauncherPid) "]")

        transferredExe := CopyLiveExecutable(pingSource,
            tempRoot "\WatchdogLiveTransferred.exe")
        transferShortcut := tempRoot "\WatchdogLiveTransferred.lnk"
        transferArguments := '/d /c start "" /b "' transferredExe
            . '" -t 127.0.0.1'
        FileCreateShortcut(A_ComSpec, transferShortcut, tempRoot,
            transferArguments)
        transferResolver := CreateLiveShortcutResolver()
        transferSource := ""
        resolvedTransferredExe := transferResolver.ResolveEffective(
            transferShortcut, false, &transferSource)
        AssertLiveTarget(CanonicalizeLiveTargetPath(resolvedTransferredExe)
                == CanonicalizeLiveTargetPath(transferredExe)
            && transferSource == "快捷方式参数",
            "短命启动器快捷方式没有解析到转交后的真实 EXE")
        transferSpecs := TargetSpecFactory.Create(transferShortcut, {
            ResolvedTarget: resolvedTransferredExe,
            ShortcutArguments: transferArguments,
            ShortcutWorkingDirectory: tempRoot,
            ShortcutReadable: true,
            EntryExists: true,
            ResolvedTargetExists: true
        })
        Run(transferShortcut, tempRoot, "Hide", &transferLauncherPid)
        if transferLauncherPid
            processes.Push(transferLauncherPid)
        transferredObservation := WaitForLiveTarget(TargetProbeKind.ImagePath,
            transferredExe, true)
        AssertLiveTarget(transferredObservation.IsRunning(),
            "短命启动器转交后的真实进程未被识别："
                . transferredObservation.Reason)

        quickExitExe := CopyLiveExecutable(pingSource,
            tempRoot "\WatchdogLiveQuickExit.exe")
        quickPid := StartLiveExecutable(quickExitExe,
            "-n 1 127.0.0.1", processes)
        ProcessWaitClose(quickPid, 5)
        quickObservation := WaitForLiveTarget(TargetProbeKind.ImagePath,
            quickExitExe, false)
        AssertLiveTarget(quickObservation.IsStopped(),
            "迅速退出的目标仍被误判为运行中：" quickObservation.Reason)

        recoveryTargets := []
        for target in targets {
            if target.Name != "AutoHotkey" && target.Name != "CMD"
                && target.Name != "VBScript"
                && target.Name != "PowerShell" {
                continue
            }
            recoveryTargets.Push({Name: target.Name, Path: target.Path,
                PID: target.PID,
                Specs: TargetSpecFactory.Create(target.Path,
                    {EntryExists: true})})
        }
        directSpecs := TargetSpecs(directExe,
            LaunchSpec(TargetLaunchKind.Direct, directExe,
                "-t 127.0.0.1", tempRoot),
            ProbeSpec(TargetProbeKind.ImagePath, directExe))
        recoveryTargets.Push({Name: "直接 EXE", Path: directExe,
            PID: directPid, Specs: directSpecs})
        recoveryTargets.Push({Name: "普通快捷方式", Path: shortcutPath,
            PID: shortcutObservation.PID, Specs: shortcutSpecs})
        recoveryTargets.Push({Name: "短命启动器转交", Path: transferShortcut,
            PID: transferredObservation.PID, Specs: transferSpecs})
        quickExitSpecs := TargetSpecs(quickExitExe,
            LaunchSpec(TargetLaunchKind.Direct, quickExitExe,
                "-n 1 127.0.0.1", tempRoot),
            ProbeSpec(TargetProbeKind.ImagePath, quickExitExe))
        RunLiveGuardRecoveryTests(recoveryTargets,
            {Path: quickExitExe, Specs: quickExitSpecs}, tempRoot, processes)

        concurrentExeA := CopyLiveExecutable(pingSource,
            tempRoot "\WatchdogLiveConcurrentA.exe")
        concurrentExeB := CopyLiveExecutable(pingSource,
            tempRoot "\WatchdogLiveConcurrentB.exe")
        concurrentPidA := StartLiveExecutable(concurrentExeA,
            "-t 127.0.0.1", processes)
        concurrentPidB := StartLiveExecutable(concurrentExeB,
            "-t 127.0.0.1", processes)
        AssertLiveTarget(WaitForLiveTarget(TargetProbeKind.ImagePath,
                concurrentExeA, true).IsRunning()
            && WaitForLiveTarget(TargetProbeKind.ImagePath,
                concurrentExeB, true).IsRunning(),
            "并发目标没有同时进入运行状态")
        ProcessClose(concurrentPidA)
        ProcessClose(concurrentPidB)
        ProcessWaitClose(concurrentPidA, 5)
        ProcessWaitClose(concurrentPidB, 5)
        AssertLiveTarget(WaitForLiveTarget(TargetProbeKind.ImagePath,
                concurrentExeA, false).IsStopped()
            && WaitForLiveTarget(TargetProbeKind.ImagePath,
                concurrentExeB, false).IsStopped(),
            "并发退出后至少一个目标仍被误判为运行中")
    } finally {
        processesClosed := CloseLiveTargetProcesses(processes, tempRoot)
        tempDeleted := DeleteLiveTargetTempRoot(tempRoot)
        AssertLiveTarget(processesClosed,
            "真实进程测试结束后仍有属于临时目标的进程存活")
        AssertLiveTarget(tempDeleted,
            "真实进程测试结束后无法删除临时目录")
    }
}

try {
    RunLiveCommandTargetTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
