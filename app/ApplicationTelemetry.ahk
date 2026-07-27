; 主窗口状态计时、统计投影与应用日志入口。
; 倒计时刷新只负责把既有守护状态投影到界面；核心进程检查由守护运行时调度，
; 同一轮检查复用进程快照索引，不能从显示文案反向驱动状态机。
UpdateCountdownUI() {
    try UpdateCountdownUICore()
    catch as countdownErr {
        try SetTimer(UpdateCountdownUI, 0)
        LogMsg(Tr("刷新主窗口状态失败，已暂停界面倒计时刷新：{1}",
            TrDiagnostic(countdownErr.Message)))
    }
}

UpdateCountdownUICore() {
    for appPath, stateObj in App.appStates {
        if (stateObj.Pending && stateObj.TargetStartTicks > 0) {
            rem := (stateObj.TargetStartTicks - GetTickCount64()) // 1000
            if (rem > 0) {
                statusText := stateObj.Phase == GuardPhase.CoolingDown
                    ? Tr("⏳ 稍后自动重试 {1} 秒", rem)
                    : (stateObj.FailCount > 0
                        ? Tr("⏳ 重试倒计时 {1} 秒", rem)
                        : Tr("⏳ 启动倒计时 {1} 秒", rem))
                statusKind := stateObj.Phase == GuardPhase.CoolingDown
                    ? GuardStatusKind.CoolingDown
                    : (stateObj.FailCount > 0
                        ? GuardStatusKind.RetryCountdown
                        : GuardStatusKind.StartCountdown)
                UpdateState(appPath, statusText, "", 0, false, statusKind)
            } else if stateObj.Phase != GuardPhase.Verifying {
                UpdateState(appPath, Tr("🚀 正在启动..."), "", 0, false,
                    GuardStatusKind.Starting)
            }
        }
    }
    UpdateStatsUI()
}

UpdateStatsUI() {
    total := App.appStates.Count
    running := 0
    paused := 0
    stopped := 0
    pending := 0
    updating := 0
    invalid := 0

    for _, obj in App.appStates {
        if (!obj.Enabled) {
            paused++
        } else if App.maintenanceCoordinator.IsBlocking(obj) {
            updating++
        } else if obj.MissingSinceTicks || obj.Phase == GuardPhase.Exhausted {
            invalid++
        } else if obj.Phase == GuardPhase.Running {
            running++
        } else if obj.Phase == GuardPhase.SuspectedStopped {
            stopped++
        } else if obj.Phase == GuardPhase.Initializing
            || obj.Phase == GuardPhase.WaitingRestart
            || obj.Phase == GuardPhase.Starting
            || obj.Phase == GuardPhase.Verifying
            || obj.Phase == GuardPhase.CoolingDown {
            pending++
        }
    }

    colon := LocalizationService.IsChinese() ? "：" : ": "
    statusItems := [
        {Text: ResolveMainStatsLabel(Tr("统计：运行"), "统计：运行",
                "运行中") colon running,
            IconPath: GetApplicationAssetPath(
                "ui-icons\lucide\circle-check-big.svg")},
        {Text: ResolveMainStatsLabel(Tr("统计：暂停"), "统计：暂停",
                "已暂停") colon paused,
            IconPath: GetApplicationAssetPath(
                "ui-icons\lucide\circle-pause.svg")},
        {Text: ResolveMainStatsLabel(Tr("统计：停止"), "统计：停止",
                "已停止") colon stopped,
            IconPath: GetApplicationAssetPath("ui-icons\lucide\ban.svg")},
        {Text: ResolveMainStatsLabel(Tr("统计：恢复"), "统计：恢复",
                "恢复中") colon pending,
            IconPath: GetApplicationAssetPath(
                "ui-icons\lucide\hourglass.svg")},
        {Text: ResolveMainStatsLabel(Tr("统计：升级"), "统计：升级",
                "升级中") colon updating,
            IconPath: GetApplicationAssetPath(
                "ui-icons\lucide\refresh-cw.svg")},
        {Text: ResolveMainStatsLabel(Tr("统计：失效"), "统计：失效",
                "已失效") colon invalid,
            IconPath: GetApplicationAssetPath(
                "ui-icons\lucide\circle-x.svg")},
        {Text: ResolveMainStatsLabel(Tr("统计：总计"), "统计：总计",
                "总计") colon total,
            IconPath: GetApplicationAssetPath(
                "ui-icons\lucide\target.svg"), SeparatorBefore: true}
    ]
    if App.appsDirty {
        statusItems.Push({Text: Tr("配置未保存"),
            IconPath: GetApplicationAssetPath(
                "ui-icons\lucide\triangle-alert.svg")})
    }
    statsStr := ""
    for index, item in statusItems {
        if index > 1
            statsStr .= item.HasOwnProp("SeparatorBefore")
                && item.SeparatorBefore ? " | " : "   "
        statsStr .= item.Text
    }
    if Main.statsPresenter {
        Main.statsPresenter.SetItems(statusItems, statsStr)
    } else if Main.statsText.Text != statsStr {
        ; 测试替身或极早启动阶段没有自绘投影时仍保留完整纯文本回退。
        Main.statsText.Text := statsStr
    }
}

ResolveMainStatsLabel(translated, translationKey, simplifiedFallback) {
    return translated == translationKey ? simplifiedFallback : translated
}

UpdateState(updPath, statusStr, expectedState := "",
    expectedGeneration := 0, forceProjection := false, statusKind := "") {
    updPath := NormalizeTargetPath(updPath)
    if !App.appStates.Has(updPath)
        return
    stateObj := App.appStates[updPath]
    if (expectedState != "" && stateObj != expectedState)
        return false
    if (expectedGeneration && stateObj.Generation != expectedGeneration)
        return false
    stateChanged := stateObj.State != statusStr
    statusKindChanged := statusKind != ""
        && stateObj.StatusKind != statusKind
    if stateChanged
        stateObj.State := statusStr
    if statusKindChanged
        stateObj.StatusKind := statusKind
    if (stateChanged || statusKindChanged || forceProjection) {
        row := FindRow(updPath)
        if (row > 0)
            SetMainListStatus(row, statusStr)
    }
    return true
}

FindRow(searchPath) {
    return Main.listProjection.Find(Main.lv, searchPath)
}

/*
 * 停止目标按干预程度逐级进行：先向窗口发送 WM_CLOSE，再为控制台程序发送
 * Ctrl+C；只有前两步超时且用户允许时才强制结束进程。具体等待与结果判定由
 * TargetStopper 负责，本模块只提供需要独立控制台上下文的 Ctrl+C 工作进程。
 */
SendConsoleCtrlCWorker(pid, expectedCreationIdentity := "") {
    if !pid || !ProcessExist(pid)
        return false
    if expectedCreationIdentity != ""
        && App.processInspector.GetCreationIdentity(pid)
            != expectedCreationIdentity
        return false
    try DllCall("kernel32\FreeConsole")
    attached := DllCall("kernel32\AttachConsole", "UInt", pid, "Int")
    if !attached
        return false
    sent := false
    try {
        if expectedCreationIdentity != ""
            && App.processInspector.GetCreationIdentity(pid)
                != expectedCreationIdentity
            return false
        DllCall("kernel32\SetConsoleCtrlHandler", "Ptr", 0, "Int", 1)
        ; 工作进程只连接目标控制台，组 0 因此仅广播给该控制台内的进程。
        sent := !!DllCall("kernel32\GenerateConsoleCtrlEvent", "UInt", Win32.CTRL_C_EVENT,
            "UInt", 0, "Int")
        if sent
            Sleep(100)
    } finally {
        DllCall("kernel32\SetConsoleCtrlHandler", "Ptr", 0, "Int", 0)
        DllCall("kernel32\FreeConsole")
    }
    return sent
}

SendConsoleCtrlC(pid, expectedCreationIdentity := "") {
    workerCommand := A_IsCompiled
        ? '"' A_ScriptFullPath '" --send-ctrl-c ' pid
        : '"' A_AhkPath '" "' A_ScriptFullPath '" --send-ctrl-c ' pid
    if expectedCreationIdentity != ""
        workerCommand .= " " expectedCreationIdentity
    try return RunWait(workerCommand, A_ScriptDir, "Hide") == 0
    catch
        return false
}

StopTargetProcess(pid, expectedCreationIdentity := "") {
    result := App.targetStopper.Stop(pid, App.gracefulStopSeconds,
        App.ctrlCWaitSeconds, App.allowForceTerminate, SendConsoleCtrlC,
        ElevatedKillProcess, expectedCreationIdentity)
    switch result.Stage {
        case TargetStopStage.ForceSkipped:
            LogMsg(Tr("正常关闭超时，已按设置跳过强制终止 PID：{1}", pid))
        case TargetStopStage.ForceTerminated:
            LogMsg(Tr("正常关闭超时，已强制终止进程 PID：{1}", pid))
        case TargetStopStage.ElevatedKill:
            LogMsg(Tr("常规终止权限不足，已提权终止进程 PID：{1}", pid))
        case TargetStopStage.Failed:
            errorDetail := result.ErrorMessage != ""
                ? Tr("（{1}）", TrDiagnostic(result.ErrorMessage)) : ""
            LogMsg(Tr("无法停止进程 PID：{1}{2}", pid, errorDetail))
    }
    return result
}

GracefulStop(pid, expectedCreationIdentity := "") {
    return StopTargetProcess(pid, expectedCreationIdentity).Stopped
}

ElevatedKillProcess(pid, expectedCreationIdentity := "") {
    errorMessage := ""
    return App.targetStopper.TerminateVerifiedProcess(pid,
        expectedCreationIdentity, &errorMessage) >= 0
}

LogMsg(msg) {
    msg := NormalizeUserVisibleParentheses(msg)
    App.logMessages.InsertAt(1, Format("{1} - {2}", FormatTime(A_Now, "HH:mm:ss"), msg))
    while (App.logMessages.Length > App.logMaxEntries)
        App.logMessages.Pop()
    App.logRevision++
}

BuildDiagnosticStateSummary() {
    phaseCounts := Map()
    maintenanceCounts := Map()
    enabledCount := 0
    pausedCount := 0
    for path, stateObj in App.appStates {
        if stateObj.Enabled
            enabledCount++
        else
            pausedCount++
        try phase := String(stateObj.Phase)
        catch
            phase := "unavailable"
        phaseCounts[phase] := phaseCounts.Has(phase)
            ? phaseCounts[phase] + 1 : 1
        try maintenancePhaseValue := String(stateObj.MaintenanceMode)
        catch
            maintenancePhaseValue := "unavailable"
        maintenanceCounts[maintenancePhaseValue] := maintenanceCounts.Has(
            maintenancePhaseValue) ? maintenanceCounts[maintenancePhaseValue] + 1 : 1
    }

    text := "TargetCount=" App.appStates.Count "`r`n"
        . "EnabledCount=" enabledCount "`r`n"
        . "PausedCount=" pausedCount "`r`n"
        . "CheckIntervalMs=" App.checkInterval "`r`n"
        . "RetrySequence=" App.retrySequence "`r`n"
        . "SchedulerQueue=" App.scheduler.Queue.Length "`r`n"
        . "ConfigWarnings=" App.configLoadWarnings.Length "`r`n"
        . "RecoveryEntries=" App.configRecoveryEntries.Length "`r`n"
        . "LogEntries=" App.logMessages.Length "`r`n"
        . "LogRevision=" App.logRevision "`r`n"
    for phase, count in phaseCounts
        text .= "GuardPhase." phase "=" count "`r`n"
    for phase, count in maintenanceCounts
        text .= "MaintenancePhase." phase "=" count "`r`n"
    return text
}

GetLogText() {
    result := ""
    for entry in App.logMessages
        result .= entry . "`n"
    return result
}
