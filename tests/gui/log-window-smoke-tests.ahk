#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证运行日志窗口的独立所有权、增量刷新、滚动条和诊断包导出。
; 最小化或关闭日志窗口不得改变主窗口状态，文本可选择复制但不能编辑。

try {
    RunLogWindowSmokeTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.File " (" testError.Line "): " testError.Message
        "`n" testError.Stack "`n", "**")
    ExitApp(1)
}

#Include ..\..\进程守护小助手.ahk

AssertLogWindowSmoke(condition, message) {
    if !condition
        throw Error(message)
}

LogWindowSmokeNoop(*) {
}

LogWindowSmokeState() {
    return "TargetCount=0`r`nLogWindowSmoke=1`r`n"
}

LogWindowSmokeLogs() {
    return GetLogText()
}

RunLogWindowSmokeTests() {
    global App
    UiThemeService.Configure("dark")
    ApplicationWindowPresenter.SetAutomationHidden(true)
    processId := DllCall("kernel32\GetCurrentProcessId", "UInt")
    testRoot := A_Temp "\watchdog-log-window-smoke-" processId
    try DirDelete(testRoot, true)
    DirCreate(testRoot)

    App := {
        uiInteractions: UiInteractionRegistry(),
        iconResources: IconResourceRegistry(),
        svgRenderer: SvgRenderLibrary(
            A_ScriptDir "\..\..\third_party\resvg\resvg.dll"),
        logMessages: [],
        logRevision: 0,
        logMaxEntries: 500
    }
    Loop 80 {
        App.logMessages.Push(Format("{1:02} long diagnostic line {2}",
            A_Index, "x" . "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"))
    }
    App.logRevision := App.logMessages.Length
    App.diagnosticBundleService := DiagnosticBundleService("9.8.7", {
        State: LogWindowSmokeState,
        Logs: LogWindowSmokeLogs
    })

    ManagedWindow.ConfigureLifecycle(ManagedWindowLifecycle({
        RestoreInteractions: RestoreHoveredButton,
        HideTransientWindows: LogWindowSmokeNoop,
        UnregisterControls: UnregisterGuiControls,
        ReleaseIcons: ReleaseWindowIcons
    }, WindowHierarchy))
    OnMessage(Win32.WM_DRAWITEM, OnDrawRoundedButton)
    OnMessage(Win32.WM_SETFOCUS, OnRoundedButtonFocusChanged)
    OnMessage(Win32.WM_KILLFOCUS, OnRoundedButtonFocusChanged)

    owner := ""
    logWindowInstance := ""
    try {
        owner := Gui("", "Log smoke owner")
        owner.Show("Hide w420 h260")
        logWindowInstance := LogWindow(owner)
        logWindowInstance.Show()
        AssertLogWindowSmoke(logWindowInstance.IsOpen(),
            "日志窗口没有成功创建")
        AssertLogWindowSmoke(!DllCall("user32\IsWindowVisible", "Ptr",
            logWindowInstance.gui.Hwnd, "Int"),
            "自动化日志窗口意外映射到用户桌面")
        AssertLogWindowSmoke(logWindowInstance.contentPixelWidth == 0
            && logWindowInstance.contentPixelHeight == 0
            && logWindowInstance.CompleteInitialLayout(),
            "日志窗口没有把逐行测量延迟到首屏显示之后")
        try WinHide("ahk_id " logWindowInstance.gui.Hwnd)

        AssertLogWindowSmoke(App.uiInteractions.HasButton(
            logWindowInstance.exportButton.Hwnd), "诊断包按钮没有注册交互状态")
        exportState := App.uiInteractions.GetButton(
            logWindowInstance.exportButton.Hwnd)
        AssertLogWindowSmoke(exportState.HasOwnProp("clickCallback"),
            "诊断包按钮没有绑定点击回调")
        AssertLogWindowSmoke(exportState.HasOwnProp("buttonImage")
            && exportState.buttonImage.sourcePath
                == GetApplicationAssetPath(
                    "ui-icons\lucide\package-open.svg"),
            "诊断包按钮没有使用统一的 SVG 图标")
        AssertLogWindowSmoke(App.uiInteractions.HasTextInput(
            logWindowInstance.textEdit.Hwnd), "日志文本区没有注册光标策略")

        clientRect := Buffer(16, 0)
        DllCall("user32\GetClientRect", "Ptr", logWindowInstance.gui.Hwnd,
            "Ptr", clientRect)
        windowDpi := DllCall("user32\GetDpiForWindow",
            "Ptr", logWindowInstance.gui.Hwnd, "UInt")
        clientWidth := Round(NumGet(clientRect, 8, "Int") * 96
            / Max(96, windowDpi))
        logWindowInstance.exportButton.GetPos(&buttonX, &buttonY,
            &buttonWidth, &buttonHeight)
        AssertLogWindowSmoke(Abs(buttonX * 2 + buttonWidth - clientWidth) <= 2,
            "诊断包按钮没有在日志窗口底部居中")
        AssertLogWindowSmoke(buttonHeight == 30 && buttonY > 0,
            "诊断包按钮尺寸或底部位置错误")

        editStyle := DllCall("user32\GetWindowLongPtrW",
            "Ptr", logWindowInstance.textEdit.Hwnd, "Int", -16, "Ptr")
        AssertLogWindowSmoke((editStyle & 0x800) != 0,
            "日志文本区不是只读控件")
        AssertLogWindowSmoke(logWindowInstance.verticalScrollbarVisible
            && logWindowInstance.horizontalScrollbarVisible,
            "长日志没有按需显示两个滚动条")

        App.logMessages.InsertAt(1, "new smoke log entry")
        App.logRevision++
        logWindowInstance.RefreshContentCore()
        AssertLogWindowSmoke(logWindowInstance.renderedRevision == App.logRevision
            && InStr(logWindowInstance.textEdit.Value, "new smoke log entry"),
            "日志窗口没有发布最新日志修订")

        archivePath := App.diagnosticBundleService.Export(testRoot)
        archiveFile := FileOpen(archivePath, "r")
        signature := archiveFile.Read(2)
        archiveFile.Close()
        AssertLogWindowSmoke(FileGetSize(archivePath) > 100
            && signature == "PK", "日志窗口诊断服务没有生成有效 ZIP")

        logWindowInstance.Close()
        AssertLogWindowSmoke(!logWindowInstance.gui && !logWindowInstance.textEdit
            && !logWindowInstance.exportButton, "日志窗口关闭后仍保留控件引用")
        AssertLogWindowSmoke(App.uiInteractions.Buttons.Count == 0
            && App.uiInteractions.TextInputs.Count == 0,
            "日志窗口关闭后仍保留交互注册")
    } finally {
        if logWindowInstance
            try logWindowInstance.Close()
        if owner
            try owner.Destroy()
        OnMessage(Win32.WM_DRAWITEM, OnDrawRoundedButton, 0)
        OnMessage(Win32.WM_SETFOCUS, OnRoundedButtonFocusChanged, 0)
        OnMessage(Win32.WM_KILLFOCUS, OnRoundedButtonFocusChanged, 0)
        try ShutdownRoundedButtonRenderer()
        try App.svgRenderer.Shutdown()
        try DirDelete(testRoot, true)
    }
    FileAppend("LOG_WINDOW_SMOKE|PASS`n", "*")
}
