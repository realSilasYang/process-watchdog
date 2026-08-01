; 短生命周期窗口注册表与应用关闭协调器。
; 各对话框由注册表实例持有，窗口销毁后由自身清空控件引用；关闭流程则按
; “停止守护任务、关闭界面、释放绘图与图标资源”的顺序收敛，保证重复调用仍安全。

class GuiModuleRegistry {
    __New(mainGui) {
        this.display := CustomDisplayDialog(mainGui)
        this.environment := EnvironmentSettingsDialog(mainGui)
        this.maintenance := MaintenanceSettingsDialog(mainGui)
        this.log := LogWindow(mainGui)
        this.batchOutputLogNotice := BatchOutputLogNoticeWindow(mainGui)
        this.settings := SettingsWindow(mainGui)
        this.help := HelpWindow(mainGui)
        this.supportInfo := SupportInfoWindow(mainGui)
        this.donation := DonationWindow(mainGui)
        this.addItem := AddItemDialog(mainGui)
        this.tooltip := DarkTooltipWindow()
        this.historyToast := HistoryToastWindow()
        this.targetRelocation := TargetRelocationPrompt(mainGui)
        this.stopped := false
        if App.HasOwnProp("targetRelocationService")
            SetTimer(ObjBindMethod(App.targetRelocationService,
                "RedeliverPending"), -1)
    }

    HideTransientWindows() {
        this.tooltip.Hide()
        this.historyToast.Hide()
        this.addItem.HideTransientWindows()
    }

    Shutdown(*) {
        if this.stopped
            return
        this.stopped := true
        ; 先关闭可能拥有后台工作器的窗口，再清理其独立提示窗。
        try this.addItem.Shutdown()
        try this.log.Close()
        try this.batchOutputLogNotice.Close()
        try this.settings.Close()
        try this.help.Close()
        try this.supportInfo.Close()
        try this.donation.Close()
        try this.display.Close()
        try this.environment.Close()
        try this.maintenance.Close()
        try this.tooltip.Close()
        try this.historyToast.Close()
        try this.targetRelocation.Shutdown()
    }
}

ShutdownApplication(*) {
    if IsSet(App) {
        if App.shutdownStarted
            return
        App.shutdownStarted := true
        App.reloadInProgress := true
    }

    try {
        if IsSet(App) {
            App.guardMutationQueue.Shutdown()
            App.guardRuntime.Shutdown()
        }
    } catch as shutdownError {
        ReportShutdownFailure(Tr("核心守护"), shutdownError)
    }
    try ShutdownApplicationUi()
    catch as shutdownError
        ReportShutdownFailure(Tr("界面资源"), shutdownError)
    try ShutdownRoundedButtonRenderer()
    catch as shutdownError
        ReportShutdownFailure(Tr("按钮绘制器"), shutdownError)
    try ShutdownIconResampler()
    catch as shutdownError
        ReportShutdownFailure(Tr("图标缩放器"), shutdownError)
    try ShutdownApplicationResources()
    catch as shutdownError
        ReportShutdownFailure(Tr("应用资源"), shutdownError)

    if IsSet(App)
        App.shutdownCompleted := true
}

ExitApplication(exitCode := 0) {
    ; 工作模式在主界面创建前就会退出。先显式完成一次清理，使 OnExit
    ; 只执行幂等空操作，避免清理异常中断 ExitApp 后继续进入正常启动。
    ShutdownApplication()
    ExitApp(exitCode)
}

ReportShutdownFailure(stageName, shutdownError) {
    details := FormatRuntimeErrorDetails(shutdownError)
    message := Tr("退出清理异常（{1}）：{2}", stageName, details)
    try LogMsg(message)
    try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " " message "`r`n",
        A_Temp "\ProcessWatchdogShutdownErrors.log", "UTF-8")
}

FormatRuntimeErrorDetails(runtimeError) {
    if !IsObject(runtimeError)
        return String(runtimeError)
    details := TrDiagnostic(runtimeError.Message)
    try {
        if runtimeError.File != "" {
            details .= "`n" runtimeError.File
            if runtimeError.Line
                details .= Tr("（第 {1} 行）", runtimeError.Line)
        }
    }
    try {
        if runtimeError.What != ""
            details .= Tr("`n位置：{1}", runtimeError.What)
    }
    return details
}

ShutdownApplicationUi(*) {
    try SetTimer(UpdateCountdownUI, 0)
    try ShutdownContextMenuPresenter()
    if IsSet(App) {
        dpiRebuildTimer := App.iconResources.CancelDpiRebuild()
        if dpiRebuildTimer
            try SetTimer(dpiRebuildTimer, 0)
    }
    if IsSet(GuiModules)
        try GuiModules.Shutdown()
    if IsSet(App)
        try App.fileScanner.Shutdown()
    if !IsSet(Main)
        return
    if Main.contextPopup
        try Main.contextPopup.Dispose()
    if Main.listSelectionPresenter
        try Main.listSelectionPresenter.Dispose()
    try UnregisterGuiControls(Main.gui.Hwnd)
    try ReleaseWindowIcons(Main.gui.Hwnd)
    if Main.appIcons {
        mainImageList := Main.appIcons
        Main.appIcons := 0
        try Main.lv.SetImageList(0, 1)
        try Main.lv.IL := 0
        RetireMainImageList(mainImageList)
    }
    if IsSet(App)
        App.iconResources.ClearCache()
}

AcquireApplicationMutex(&alreadyExists := false) {
    mutexHandle := DllCall("kernel32\CreateMutexW", "Ptr", 0, "Int", false,
        "WStr", "Global\Watchdog_Mutex_Strict", "Ptr")
    lastError := DllCall("kernel32\GetLastError", "UInt")
    alreadyExists := mutexHandle && lastError == 183 ; ERROR_ALREADY_EXISTS：同名单实例锁已经存在。
    return mutexHandle
}

GetReloadHandoffPid() {
    for argumentIndex, argument in A_Args {
        if StrLower(argument) != "--reload-handoff"
            || argumentIndex >= A_Args.Length
            continue
        try handoffPid := Integer(A_Args[argumentIndex + 1])
        catch
            return 0
        currentPid := DllCall("kernel32\GetCurrentProcessId", "UInt")
        return handoffPid > 0 && handoffPid != currentPid ? handoffPid : 0
    }
    return 0
}

ReleaseApplicationMutex() {
    if !App.mutexHandle
        return
    try DllCall("kernel32\CloseHandle", "Ptr", App.mutexHandle)
    App.mutexHandle := 0
}

ShutdownApplicationResources(*) {
    if App.appsDirty
        try SaveAppsToIni(false)
    try SetTimer(App.configSaveRetryTimer, 0)
    try App.ClearPendingProcessSnapshot()
    try App.applicationUpdateService.Shutdown()
    try App.svgRenderer.Shutdown()
    ReleaseApplicationMutex()
    try ReleaseWindowIcons(A_ScriptHwnd)
}

OnManagedWindowSystemCommand(wParam, lParam, msg, hwnd) {
    command := wParam & 0xFFF0
    if (command == Win32.SC_MINIMIZE
        && WindowHierarchy.MinimizeChildIndependently(hwnd))
        return 0
    if (command == Win32.SC_RESTORE || command == Win32.SC_MAXIMIZE)
        WindowHierarchy.PrepareChildRestore(hwnd)
}
