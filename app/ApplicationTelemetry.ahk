/*  * ========================================================================
 * 核心后台轮询与状态调度 (Heartbeat Polling)
 * ========================================================================
 * 运行于独立时钟周期的循环池：
 * 定时执行进程检查；每轮复用同一个进程快照索引，避免逐项目重复查询或建索引。
 */
UpdateCountdownUI() {
    try UpdateCountdownUICore()
    catch as countdownErr {
        try SetTimer(UpdateCountdownUI, 0)
        LogMsg("刷新主窗口状态失败，已暂停界面倒计时刷新: "
            countdownErr.Message)
    }
}

UpdateCountdownUICore() {
    for appPath, stateObj in App.appStates {
        if (stateObj.Pending && stateObj.TargetStartTicks > 0) {
            rem := (stateObj.TargetStartTicks - GetTickCount64()) // 1000
            if (rem > 0) {
                prefix := stateObj.Phase == GuardPhase.CoolingDown
                    ? "⏳ 稍后自动重试"
                    : (stateObj.FailCount > 0 ? "⏳ 重试倒计时"
                        : "⏳ 启动倒计时")
                UpdateState(appPath, prefix " " rem "s")
            } else if stateObj.Phase != GuardPhase.Verifying {
                UpdateState(appPath, "🚀 正在启动...")
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
        st := obj.State
        if (!obj.Enabled) {
            paused++
        } else if App.maintenanceCoordinator.IsBlocking(obj) {
            updating++
        } else if obj.Phase == GuardPhase.CoolingDown {
            pending++
        } else if InStr(st, "不存在") {
            invalid++
        } else if InStr(st, "运行中") {
            running++
        } else if InStr(st, "已停止") || InStr(st, "疑似停止") || InStr(st, "启动失败") || InStr(st, "非驻留") {
            stopped++
        } else if InStr(st, "倒计时") || InStr(st, "启动") || InStr(st, "验证") || InStr(st, "初始化") {
            pending++
        }
    }

    statsStr := "✅ 运行: " running "   🚫 停止: " stopped "   ⏳ 恢复: " pending "   🔄 升级: " updating "   ⏸️ 暂停: " paused "   ❌ 失效: " invalid "   |   🎯 总计: " total
    if App.appsDirty
        statsStr .= "   ⚠️ 配置未保存"
    if (Main.statsText.Text != statsStr) {
        Main.statsText.Text := statsStr
    }
}

UpdateState(updPath, statusStr, expectedState := "",
    expectedGeneration := 0) {
    updPath := NormalizeTargetPath(updPath)
    if !App.appStates.Has(updPath)
        return
    stateObj := App.appStates[updPath]
    if (expectedState != "" && stateObj != expectedState)
        return false
    if (expectedGeneration && stateObj.Generation != expectedGeneration)
        return false
    if (stateObj.State != statusStr) {
        stateObj.State := statusStr
        row := FindRow(updPath)
        if (row > 0)
            SetMainListStatus(row, statusStr)
    }
    return true
}

FindRow(searchPath) {
    return Main.listProjection.Find(Main.lv, searchPath)
}

/*  * ========================================================================
 * 温柔关闭策略 (Graceful Shutdown)
 * ========================================================================
 * 三级梯度退出：
 * 1. WM_CLOSE → 向所有窗口发送关闭请求
 * 2. CTRL_C_EVENT → 向控制台程序发送 Ctrl+C
 * 3. TerminateProcess → 暴力击杀兆底
 */
SendConsoleCtrlCWorker(pid) {
    if !pid || !ProcessExist(pid)
        return false
    try DllCall("kernel32\FreeConsole")
    attached := DllCall("kernel32\AttachConsole", "UInt", pid, "Int")
    if !attached
        return false
    sent := false
    try {
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

SendConsoleCtrlC(pid) {
    workerCommand := A_IsCompiled
        ? '"' A_ScriptFullPath '" --send-ctrl-c ' pid
        : '"' A_AhkPath '" "' A_ScriptFullPath '" --send-ctrl-c ' pid
    try return RunWait(workerCommand, A_ScriptDir, "Hide") == 0
    catch
        return false
}

GracefulStop(pid) {
    result := App.targetStopper.Stop(pid, App.gracefulStopSeconds,
        App.ctrlCWaitSeconds, App.allowForceTerminate, SendConsoleCtrlC,
        ElevatedKillProcess)
    switch result.Stage {
        case TargetStopStage.ForceSkipped:
            LogMsg("温和关闭超时，已按设置跳过强制终止 PID: " pid)
        case TargetStopStage.ForceTerminated:
            LogMsg("温和关闭超时，已强制终止进程 PID: " pid)
        case TargetStopStage.ElevatedKill:
            LogMsg("常规终止权限不足，已提权终止进程 PID: " pid)
        case TargetStopStage.Failed:
            errorDetail := result.ErrorMessage != ""
                ? "（" result.ErrorMessage "）" : ""
            LogMsg("无法停止进程 PID: " pid errorDetail)
    }
    return result.Stopped
}

ElevatedKillProcess(pid) {
    try return RunWait("*RunAs taskkill /F /PID " pid, , "Hide") == 0
    catch
        return false
}

LogMsg(msg) {
    msg := NormalizeUserVisibleParentheses(msg)
    App.logMessages.InsertAt(1, Format("{1} - {2}", FormatTime(A_Now, "HH:mm:ss"), msg))
    while (App.logMessages.Length > App.logMaxEntries)
        App.logMessages.Pop()
    App.logRevision++
}

ReadApplicationVersion() {
    versionPath := A_ScriptDir "\VERSION"
    try {
        version := Trim(FileRead(versionPath, "UTF-8"))
        if RegExMatch(version, "^\d+\.\d+\.\d+$")
            return version
    }
    return "0.1.0"
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
