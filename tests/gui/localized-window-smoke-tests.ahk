#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 用全部受支持语言分别创建主要生产窗口，验证本地化标题、控件边界和单行文案宽度。
; 自动化批量测试创建真实窗口但不映射到桌面；人工预览使用完整主题窗口。
; 全程不保存设置、不启动守护，也不读取或覆盖正式配置。

try {
    if A_Args.Length && A_Args[1] == "--about-preview"
        RunAboutSettingsPreview()
    else if A_Args.Length && A_Args[1] == "--environment-preview"
        RunEnvironmentSettingsPreview()
    else if A_Args.Length && A_Args[1] == "--donation-preview"
        RunDonationPreview("dark")
    else if A_Args.Length && A_Args[1] == "--donation-preview-light"
        RunDonationPreview("light")
    else
        RunLocalizedWindowSmokeTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.File "（" testError.Line "）："
        testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}

#Include ..\..\进程守护小助手.ahk

AssertLocalizedWindow(condition, message) {
    if !condition
        throw Error(message)
}

LocalizedWindowNoop(*) {
}

GetNativeWindowText(hwnd) {
    length := DllCall("user32\GetWindowTextLengthW", "Ptr", hwnd, "Int")
    if length <= 0
        return ""
    textBuffer := Buffer((length + 1) * 2, 0)
    copied := DllCall("user32\GetWindowTextW", "Ptr", hwnd,
        "Ptr", textBuffer, "Int", length + 1, "Int")
    return copied > 0 ? StrGet(textBuffer, copied, "UTF-16") : ""
}

GetLocalizedWindowFontSpec(hwnd) {
    fontHandle := SendMessage(Win32.WM_GETFONT, 0, 0, hwnd)
    if !fontHandle
        return {Face: "", Weight: 0, Height: 0}
    logFont := Buffer(92, 0)
    if !DllCall("gdi32\GetObjectW", "Ptr", fontHandle, "Int",
            logFont.Size, "Ptr", logFont, "Int")
        return {Face: "", Weight: 0, Height: 0}
    return {
        Face: StrGet(logFont.Ptr + 28, 32, "UTF-16"),
        Weight: NumGet(logFont, 16, "Int"),
        Height: NumGet(logFont, 0, "Int")
    }
}

MeasureNativeControlText(hwnd, text) {
    deviceContext := DllCall("user32\GetDC", "Ptr", hwnd, "Ptr")
    if !deviceContext
        return 0
    fontHandle := SendMessage(Win32.WM_GETFONT, 0, 0, hwnd)
    priorFont := fontHandle
        ? DllCall("gdi32\SelectObject", "Ptr", deviceContext,
            "Ptr", fontHandle, "Ptr") : 0
    try {
        extent := Buffer(8, 0)
        if !DllCall("gdi32\GetTextExtentPoint32W", "Ptr", deviceContext,
            "Str", text, "Int", StrLen(text), "Ptr", extent, "Int")
            return 0
        return NumGet(extent, 0, "Int")
    } finally {
        if priorFont
            DllCall("gdi32\SelectObject", "Ptr", deviceContext,
                "Ptr", priorFont)
        DllCall("user32\ReleaseDC", "Ptr", hwnd, "Ptr", deviceContext)
    }
}

AssertProductionWindowLayout(guiObj, language, windowName) {
    clientRect := Buffer(16, 0)
    DllCall("user32\GetClientRect", "Ptr", guiObj.Hwnd, "Ptr", clientRect)
    clientWidth := NumGet(clientRect, 8, "Int")
    clientHeight := NumGet(clientRect, 12, "Int")
    AssertLocalizedWindow(clientWidth > 0 && clientHeight > 0,
        language " " windowName " 没有有效客户区")
    windowDpi := DllCall("user32\GetDpiForWindow", "Ptr", guiObj.Hwnd,
        "UInt")
    if !windowDpi
        windowDpi := 96

    for controlHwnd in WinGetControlsHwnd("ahk_id " guiObj.Hwnd) {
        if !DllCall("user32\IsWindowVisible", "Ptr", controlHwnd, "Int")
            continue
        controlRect := Buffer(16, 0)
        if !DllCall("user32\GetWindowRect", "Ptr", controlHwnd,
            "Ptr", controlRect, "Int")
            continue
        DllCall("user32\MapWindowPoints", "Ptr", 0, "Ptr", guiObj.Hwnd,
            "Ptr", controlRect, "UInt", 2)
        left := NumGet(controlRect, 0, "Int")
        top := NumGet(controlRect, 4, "Int")
        right := NumGet(controlRect, 8, "Int")
        bottom := NumGet(controlRect, 12, "Int")
        AssertLocalizedWindow(left >= -2 && top >= -2
            && right <= clientWidth + 2 && bottom <= clientHeight + 2,
            language " " windowName " 的控件超出窗口边界："
                GetNativeWindowText(controlHwnd))

        className := WinGetClass("ahk_id " controlHwnd)
        text := GetNativeWindowText(controlHwnd)
        if className == "Edit" {
            editStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
                controlHwnd, "Int", -16, "Ptr")
            if !(editStyle & 0x4) {
                margins := SendMessage(Win32.EM_GETMARGINS, 0, 0,
                    controlHwnd)
                leftMargin := margins & 0xFFFF
                rightMargin := (margins >> 16) & 0xFFFF
                expectedMargin := Max(4, Round(6 * windowDpi / 96))
                AssertLocalizedWindow(leftMargin >= expectedMargin
                    && rightMargin >= expectedMargin,
                    language " " windowName
                        " 的单行输入框缺少左右内边距：" text)
            }
        }
        AssertLocalizedWindow(RegExMatch(language, "^zh-")
            || !RegExMatch(text, "[\x{3400}-\x{9FFF}]"),
            language " " windowName " 的可见控件仍含中文：" text)
        controlWidth := right - left
        controlHeight := bottom - top
        if text == "" || InStr(text, "`n") || InStr(text, "`r")
            || controlHeight > 34
            || (className != "Static" && className != "Button")
            continue
        textWidth := MeasureNativeControlText(controlHwnd, text)
        style := DllCall("user32\GetWindowLongPtrW", "Ptr", controlHwnd,
            "Int", -16, "Ptr")
        isCheckControl := className == "Button" && (style & 0xF) >= 2
            && (style & 0xF) <= 9
        horizontalPadding := isCheckControl ? 26 : 8
        AssertLocalizedWindow(textWidth <= controlWidth - horizontalPadding + 3,
            language " " windowName " 的单行文本可能被截断：" text
                "（文本=" textWidth "px，控件=" controlWidth "px）")
    }
}

AssertWindowTitle(guiObj, expectedTitle, language, windowName) {
    actualTitle := GetNativeWindowText(guiObj.Hwnd)
    AssertLocalizedWindow(actualTitle == expectedTitle,
        language " " windowName " 标题错误：" actualTitle)
}

MeasureWrappedControlTextHeight(hwnd, text, width) {
    deviceContext := DllCall("user32\GetDC", "Ptr", hwnd, "Ptr")
    if !deviceContext
        return 0
    fontHandle := SendMessage(Win32.WM_GETFONT, 0, 0, hwnd)
    priorFont := fontHandle
        ? DllCall("gdi32\SelectObject", "Ptr", deviceContext,
            "Ptr", fontHandle, "Ptr") : 0
    try {
        measureRect := Buffer(16, 0)
        NumPut("Int", width, measureRect, 8)
        DllCall("user32\DrawTextW", "Ptr", deviceContext, "Str", text,
            "Int", -1, "Ptr", measureRect, "UInt", 0x0410, "Int")
            ; DT_CALCRECT | DT_WORDBREAK：按控件实际字体和宽度计算换行高度。
        return NumGet(measureRect, 12, "Int")
    } finally {
        if priorFont
            DllCall("gdi32\SelectObject", "Ptr", deviceContext,
                "Ptr", priorFont)
        DllCall("user32\ReleaseDC", "Ptr", hwnd, "Ptr", deviceContext)
    }
}

GetControlCenterY(hwnd) {
    controlRect := Buffer(16, 0)
    if !DllCall("user32\GetWindowRect", "Ptr", hwnd,
            "Ptr", controlRect, "Int")
        return 0
    return (NumGet(controlRect, 4, "Int")
        + NumGet(controlRect, 12, "Int")) / 2
}

GetControlClientRect(hwnd, parentHwnd) {
    controlRect := Buffer(16, 0)
    if !DllCall("user32\GetWindowRect", "Ptr", hwnd,
            "Ptr", controlRect, "Int")
        return {Left: 0, Top: 0, Right: 0, Bottom: 0,
            Width: 0, Height: 0}
    DllCall("user32\MapWindowPoints", "Ptr", 0, "Ptr", parentHwnd,
        "Ptr", controlRect, "UInt", 2)
    left := NumGet(controlRect, 0, "Int")
    top := NumGet(controlRect, 4, "Int")
    right := NumGet(controlRect, 8, "Int")
    bottom := NumGet(controlRect, 12, "Int")
    return {Left: left, Top: top, Right: right, Bottom: bottom,
        Width: right - left, Height: bottom - top}
}

GetWindowClientRect(hwnd) {
    clientRect := Buffer(16, 0)
    if !DllCall("user32\GetClientRect", "Ptr", hwnd, "Ptr", clientRect,
            "Int")
        return {Width: 0, Height: 0}
    return {
        Width: NumGet(clientRect, 8, "Int"),
        Height: NumGet(clientRect, 12, "Int")
    }
}

AssertSettingsPageContentInset(settingsDialog, language, pageName) {
    firstTab := settingsDialog.tabButtons[1]
    firstTabRect := GetControlClientRect(firstTab.Hwnd,
        settingsDialog.gui.Hwnd)
    firstTabTextWidth := MeasureNativeControlText(firstTab.Hwnd,
        firstTab.Text)
    windowDpi := DllCall("user32\GetDpiForWindow", "Ptr",
        settingsDialog.gui.Hwnd, "UInt")
    if !windowDpi
        windowDpi := 96
    ; 内容不仅不能越过首个选项卡文字的左边，还要保留至少 4 个逻辑像素。
    requiredLeft := firstTabRect.Left
        + Floor((firstTabRect.Width - firstTabTextWidth) / 2)
        + Max(4, Round(4 * windowDpi / 96))
    tolerance := Max(2, Round(2 * windowDpi / 96))
    firstContentTop := ""
    for control in settingsDialog.tabControls[settingsDialog.activeTab] {
        if !control.Visible
            continue
        controlRect := GetControlClientRect(control.Hwnd,
            settingsDialog.gui.Hwnd)
        if firstContentTop == "" || controlRect.Top < firstContentTop
            firstContentTop := controlRect.Top
        AssertLocalizedWindow(controlRect.Left + tolerance >= requiredLeft,
            language " " pageName " 的内容越过选项卡文字安全线："
                GetNativeWindowText(control.Hwnd))
    }
    requiredTopGap := Max(20, Round(20 * windowDpi / 96))
    AssertLocalizedWindow(firstContentTop != ""
        && firstContentTop - firstTabRect.Bottom >= requiredTopGap - tolerance,
        language " " pageName " 的正文没有与顶部选项卡留出足够距离")
}

FindChildControlByText(parentHwnd, expectedText) {
    for controlHwnd in WinGetControlsHwnd("ahk_id " parentHwnd) {
        if GetNativeWindowText(controlHwnd) == expectedText
            return controlHwnd
    }
    return 0
}

CountThinHorizontalSeparators(parentHwnd, upperBoundary,
    lowerBoundary, windowDpi) {
    clientRect := Buffer(16, 0)
    DllCall("user32\GetClientRect", "Ptr", parentHwnd, "Ptr", clientRect)
    clientWidth := NumGet(clientRect, 8, "Int")
    maximumHeight := Max(2, Round(2 * windowDpi / 96))
    count := 0
    for controlHwnd in WinGetControlsHwnd("ahk_id " parentHwnd) {
        if WinGetClass("ahk_id " controlHwnd) != "Static"
            continue
        rect := GetControlClientRect(controlHwnd, parentHwnd)
        if rect.Height <= maximumHeight
            && rect.Width >= Floor(clientWidth * 0.6)
            && rect.Top > upperBoundary && rect.Bottom < lowerBoundary
            count++
    }
    return count
}

CreateLocalizedSmokeState(path, maintenanceRoot := "") {
    global App
    maintenanceConfig := App.maintenanceConfigCodec.CreateDefault(path)
    if maintenanceRoot != "" {
        maintenanceConfig.InstallRoot := maintenanceRoot
        maintenanceConfig.RootIsCustom := true
    }
    return TargetSupervisor({
        WorkDir: maintenanceRoot,
        Args: "--smoke-test",
        EnvVars: "SMOKE_TEST=1",
        ResolvedTarget: "",
        ResolvedTargetManual: false,
        ShortcutTargetSource: "",
        MaintenanceConfig: maintenanceConfig,
        DisplayConfig: App.displayConfigCodec.CreateDefault(),
        Scheduler: App.scheduler
    })
}

RunOneLocalizedWindowPass(language, previewEnvironment := false,
    previewAbout := false, previewDonation := false, requestedTheme := "") {
    global App
    LocalizationService.Configure(language)
    LocalizationService.ConfigureUiFont("auto")
    if requestedTheme != ""
        UiThemeService.Configure(requestedTheme)
    App := ApplicationState()
    App.logMessages := [Tr("进程守护小助手已静默启动。")]
    App.logRevision := 1

    owner := ""
    settingsDialog := ""
    addWindow := ""
    customWindow := ""
    environmentWindow := ""
    maintenanceWindow := ""
    helpDialog := ""
    logWindowInstance := ""
    batchLogNoticeDialog := ""
    supportInfoDialog := ""
    donationDialog := ""
    tooltipDialog := ""
    try {
        ManagedWindow.ConfigureLifecycle(ManagedWindowLifecycle({
            RestoreInteractions: RestoreHoveredButton,
            HideTransientWindows: LocalizedWindowNoop,
            UnregisterControls: UnregisterGuiControls,
            ReleaseIcons: ReleaseWindowIcons
        }, WindowHierarchy))
        owner := Gui("+Resize", "Localized smoke owner")
        ; 人工预览解除所有者关系前仍可能短暂绘制该窗口，因此所有者也必须
        ; 使用与目标窗口相同的标题栏和客户区主题，避免浅色空白窗口闪现。
        InitializeApplicationWindow(owner)
        owner.Show((previewEnvironment || previewAbout || previewDonation
            ? "" : "Hide ")
            "w730 h520")

        executablePath := A_WinDir "\System32\notepad.exe"
        executableState := CreateLocalizedSmokeState(executablePath,
            A_WinDir "\System32")
        scriptPath := A_Temp "\Localized Runtime Smoke.py"
        scriptState := CreateLocalizedSmokeState(scriptPath, A_Temp)
        scriptState.RuntimePath := A_AhkPath
        scriptState.RuntimeArgs := "/ErrorStdOut"
        shortcutPath := A_Temp "\Localized Smoke Shortcut.lnk"
        try FileDelete(shortcutPath)
        shortcutState := CreateLocalizedSmokeState(shortcutPath,
            A_WinDir "\System32")
        shortcutState.ResolvedTarget := executablePath
        shortcutState.ShortcutTargetSource := "快捷方式目标"

        settingsDialog := SettingsWindow(owner)
        settingsDialog.Show()
        if ApplicationWindowPresenter.AutomationHidden
            AssertLocalizedWindow(!DllCall("user32\IsWindowVisible", "Ptr",
                settingsDialog.gui.Hwnd, "Int"),
                language " 自动化设置窗口意外映射到用户桌面")
        AssertLocalizedWindow(settingsDialog.tabBuilt.Length == 5
            && settingsDialog.tabBuilt[1]
            && !settingsDialog.tabBuilt[2]
            && !settingsDialog.tabBuilt[3]
            && !settingsDialog.tabBuilt[4]
            && !settingsDialog.tabBuilt[5]
            && settingsDialog.tabControls[1].Length > 0
            && settingsDialog.tabControls[2].Length == 0
            && settingsDialog.tabControls[3].Length == 0
            && settingsDialog.tabControls[4].Length == 0
            && settingsDialog.tabControls[5].Length == 0,
            language " 设置窗口首开没有只构建当前可见的通用页")
        if previewAbout {
            settingsDialog.SwitchTab(5)
            ; 视觉预览解除测试所有者关系，便于截图工具单独定位设置窗口。
            DllCall("user32\SetWindowLongPtrW", "Ptr",
                settingsDialog.gui.Hwnd, "Int", -8, "Ptr", 0, "Ptr")
            DllCall("user32\EnableWindow", "Ptr", owner.Hwnd, "Int", true)
            WinHide("ahk_id " owner.Hwnd)
            settingsDialog.gui.Show("x0 y0")
            DllCall("user32\SetFocus", "Ptr", 0)
            WinSetAlwaysOnTop(1, "ahk_id " settingsDialog.gui.Hwnd)
            WinActivate("ahk_id " settingsDialog.gui.Hwnd)
            while settingsDialog.IsOpen()
                Sleep(50)
            return
        }
        initialSettingsControlCount := WinGetControlsHwnd(
            "ahk_id " settingsDialog.gui.Hwnd).Length
        AssertLocalizedWindow(settingsDialog.SwitchTab(5)
            && settingsDialog.activeTab == 5
            && settingsDialog.tabBuilt[5]
            && settingsDialog.tabControls[5].Length > 0
            && WinGetControlsHwnd("ahk_id " settingsDialog.gui.Hwnd).Length
                > initialSettingsControlCount,
            language " 关于页没有在首次切换的重绘事务中延迟构建")
        AssertLocalizedWindow(settingsDialog.aboutLogo.Visible
            && !settingsDialog.showAtStartupCheck.Visible
            && !settingsDialog.saveButton.Visible
            && !settingsDialog.cancelButton.Visible,
            language " 首次切换关于页后仍显示其他页面或全局保存区")
        AssertLocalizedWindow(settingsDialog.SwitchTab(1)
            && settingsDialog.activeTab == 1
            && settingsDialog.showAtStartupCheck.Visible
            && !settingsDialog.aboutLogo.Visible
            && settingsDialog.saveButton.Visible
            && settingsDialog.cancelButton.Visible,
            language " 关于页切回通用页后没有一次性恢复最终可见状态")
        WinHide("ahk_id " settingsDialog.gui.Hwnd)
        AssertWindowTitle(settingsDialog.gui, Tr("小助手设置"), language,
            "SettingsWindow")
        AssertProductionWindowLayout(settingsDialog.gui, language,
            "SettingsWindow")
        versionCaption := settingsDialog.SplitFieldCaption(Tr("当前版本："))
        runtimeCaption := settingsDialog.SplitFieldCaption(Tr("运行环境："))
        AssertLocalizedWindow(settingsDialog.versionLabel.Text
            == versionCaption.Label
            && settingsDialog.versionValue.Text
                == GetApplicationEditionSummary(),
            language " 关于页没有显示当前版本和发行形态")
        AssertLocalizedWindow(settingsDialog.runtimeLabel.Text
            == runtimeCaption.Label
            && settingsDialog.runtimeValue.Text
                == GetAutoHotkeyRuntimeSummary(),
            language " 关于页没有显示实际 AutoHotkey 运行环境")
        AssertLocalizedWindow(settingsDialog.checkUpdateButton.Text
            == Tr("立即检查更新"),
            language " 设置窗口没有显示立即检查更新按钮")
        AssertLocalizedWindow(settingsDialog.tabButtons[1].Text == Tr("通用"),
            language " 设置窗口首个选项卡没有显示为通用")
        expectedTabLabels := [Tr("通用"), Tr("监控与启动"),
            Tr("停止策略"), Tr("日志"), Tr("关于")]
        expectedTabIcons := ["sliders-horizontal.svg", "activity.svg",
            "octagon-x.svg", "logs.svg", "circle-info.svg"]
        AssertLocalizedWindow(settingsDialog.tabButtons.Length == 5
            && settingsDialog.tabControls.Length == 5,
            language " 设置窗口没有严格收敛为五个选项卡")
        for tabIndex, expectedTabLabel in expectedTabLabels {
            AssertLocalizedWindow(settingsDialog.tabButtons[tabIndex].Text
                == expectedTabLabel,
                language " 设置窗口选项卡名称或顺序错误：" tabIndex)
            tabButtonState := App.uiInteractions.GetButton(
                settingsDialog.tabButtons[tabIndex].Hwnd)
            AssertLocalizedWindow(tabButtonState.HasOwnProp("buttonImage")
                && tabButtonState.buttonImage.sourcePath
                    == GetApplicationAssetPath("ui-icons\lucide\"
                        expectedTabIcons[tabIndex]),
                language " 设置窗口选项卡缺少匹配语义的 SVG 图标："
                    tabIndex)
        }
        AssertLocalizedWindow(settingsDialog.activeTab == 1,
            language " 设置窗口没有默认打开通用页")
        activeTabState := App.uiInteractions.GetButton(
            settingsDialog.tabButtons[1].Hwnd)
        inactiveTabState := App.uiInteractions.GetButton(
            settingsDialog.tabButtons[2].Hwnd)
        AssertLocalizedWindow(activeTabState.textColor
            == UiThemeService.Color("TabActiveText")
            && inactiveTabState.textColor
                == UiThemeService.Color("TabText")
            && activeTabState.textAlign == "center"
            && inactiveTabState.textAlign == "center",
            language " 设置窗口标签文字颜色或居中对齐错误")
        AssertLocalizedWindow(!FindChildControlByText(
            settingsDialog.gui.Hwnd, "搜索与导入"),
            language " 设置窗口仍显示已下线的搜索与导入选项卡")
        AssertLocalizedWindow(settingsDialog.fontLabel.Text
            == Tr("界面内容字体："),
            language " 设置窗口没有明确标示界面内容字体")
        expectedSystemFont := LocalizationService
            .GetLanguageSystemUiFontName()
        tabFont := GetLocalizedWindowFontSpec(
            settingsDialog.tabButtons[1].Hwnd)
        actionFont := GetLocalizedWindowFontSpec(
            settingsDialog.checkUpdateButton.Hwnd)
        AssertLocalizedWindow(tabFont.Face == expectedSystemFont
            && tabFont.Weight >= 700
            && actionFont.Face == expectedSystemFont
            && actionFont.Weight >= 700
            && Abs(tabFont.Height) <= Abs(actionFont.Height),
            language " 按钮或切换标签没有使用系统 UI 字体粗体")
        labelCenterY := GetControlCenterY(settingsDialog.languageLabel.Hwnd)
        comboCenterY := GetControlCenterY(settingsDialog.languageDropDown.Hwnd)
        windowDpi := DllCall("user32\GetDpiForWindow", "Ptr",
            settingsDialog.gui.Hwnd, "UInt")
        centerTolerance := Max(2, Round(2 * windowDpi / 96))
        settingsClientRect := GetWindowClientRect(settingsDialog.gui.Hwnd)
        saveButtonHwnd := FindChildControlByText(settingsDialog.gui.Hwnd,
            Tr("保存"))
        cancelButtonHwnd := FindChildControlByText(settingsDialog.gui.Hwnd,
            Tr("取消"))
        AssertLocalizedWindow(saveButtonHwnd && cancelButtonHwnd,
            language " 设置窗口无法定位底部保存或取消按钮")
        saveButtonRect := GetControlClientRect(saveButtonHwnd,
            settingsDialog.gui.Hwnd)
        cancelButtonRect := GetControlClientRect(cancelButtonHwnd,
            settingsDialog.gui.Hwnd)
        requiredBottomGap := Max(10, Round(10 * windowDpi / 96))
        AssertLocalizedWindow(saveButtonRect.Top == cancelButtonRect.Top
            && settingsClientRect.Height - saveButtonRect.Bottom
                >= requiredBottomGap,
            language " 设置正文下移时连带改变了底部操作区位置")
        AssertLocalizedWindow(Abs(labelCenterY - comboCenterY)
            <= centerTolerance,
            language " 界面语言标签与下拉框没有垂直居中对齐")
        fontLabelCenterY := GetControlCenterY(settingsDialog.fontLabel.Hwnd)
        fontComboCenterY := GetControlCenterY(
            settingsDialog.fontDropDown.Hwnd)
        AssertLocalizedWindow(Abs(fontLabelCenterY - fontComboCenterY)
            <= centerTolerance,
            language " 内容字体标签与下拉框没有垂直居中对齐")
        comboPadding := GetComboBoxDisplayPadding()
        for paddedDropDown in [settingsDialog.languageDropDown,
                settingsDialog.fontDropDown, settingsDialog.themeDropDown] {
            paddedText := paddedDropDown.Text
            comboStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
                paddedDropDown.Hwnd, "Int", -16, "Ptr")
            comboExStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
                paddedDropDown.Hwnd, "Int", -20, "Ptr")
            AssertLocalizedWindow(SubStr(paddedText, 1, 1) == comboPadding
                && SubStr(paddedText, -1) == comboPadding,
                language " 设置下拉框没有保留左右显示内边距")
            AssertLocalizedWindow(!(comboStyle & 0x00800000)
                && !(comboExStyle & 0x00020201),
                language " 设置下拉框仍保留原生边框样式")
        }
        AssertLocalizedWindow(settingsDialog.fontValues.Length > 1
            && settingsDialog.fontValues[
                settingsDialog.fontDropDown.Value] == App.uiFont
            && Trim(settingsDialog.fontDropDown.Text, comboPadding)
                == Tr("跟随语言默认（{1}）",
                    LocalizationService.GetLanguageDefaultUiFontName()),
            language " 字体菜单没有选中当前设置或缺少已安装字体")

        ; 用一份故意过期的枚举缓存模拟设置窗口打开后系统字体发生变化，
        ; 再发送原生 CBN_DROPDOWN，验证每次展开都会抛弃旧缓存并保留有效选择。
        selectedFontBeforeRefresh := settingsDialog.fontValues[
            settingsDialog.fontDropDown.Value]
        LocalizationService.InstalledUiFonts :=
            ["__Watchdog_Stale_Font_Cache__"]
        fontControlId := DllCall("user32\GetDlgCtrlID", "Ptr",
            settingsDialog.fontDropDown.Hwnd, "Int")
        DllCall("user32\SendMessageW", "Ptr", settingsDialog.gui.Hwnd,
            "UInt", Win32.WM_COMMAND, "Ptr", fontControlId
                | (Win32.CBN_DROPDOWN << 16),
            "Ptr", settingsDialog.fontDropDown.Hwnd, "Ptr")
        staleFontStillPresent := false
        for refreshedFontValue in settingsDialog.fontValues {
            if refreshedFontValue == "__Watchdog_Stale_Font_Cache__" {
                staleFontStillPresent := true
                break
            }
        }
        AssertLocalizedWindow(!staleFontStillPresent
            && settingsDialog.fontValues.Length > 1
            && settingsDialog.fontValues[
                settingsDialog.fontDropDown.Value] == selectedFontBeforeRefresh
            && SubStr(settingsDialog.fontDropDown.Text, 1, 1)
                == comboPadding
            && SubStr(settingsDialog.fontDropDown.Text, -1)
                == comboPadding,
            language " 展开字体下拉框时没有同步最新字体状态")

        ; 逐页验证所有设置项的归属；每次切页后同时执行边界与截断检查，
        ; 避免隐藏页中的问题被默认页掩盖。
        settingsDialog.SwitchTab(1)
        AssertLocalizedWindow(settingsDialog.showAtStartupCheck.Visible
            && settingsDialog.checkUpdatesOnStartupCheck.Visible
            && settingsDialog.languageDropDown.Visible
            && settingsDialog.fontDropDown.Visible
            && settingsDialog.intervalEdit == "",
            language " 通用页的控件归属错误")
        showAtStartupRect := GetControlClientRect(
            settingsDialog.showAtStartupCheck.Hwnd,
            settingsDialog.gui.Hwnd)
        checkUpdatesAtStartupRect := GetControlClientRect(
            settingsDialog.checkUpdatesOnStartupCheck.Hwnd,
            settingsDialog.gui.Hwnd)
        AssertLocalizedWindow(Abs(showAtStartupRect.Top
                - checkUpdatesAtStartupRect.Top) <= centerTolerance
            && showAtStartupRect.Left > checkUpdatesAtStartupRect.Right,
            language " 两个启动时行为选项没有按更新在左、主窗口在右排列")
        AssertProductionWindowLayout(settingsDialog.gui, language,
            "SettingsWindow General")
        AssertSettingsPageContentInset(settingsDialog, language,
            "SettingsWindow General")

        settingsDialog.SwitchTab(2)
        AssertLocalizedWindow(settingsDialog.tabBuilt[2]
            && settingsDialog.tabControls[2].Length > 0,
            language " 监控与启动页没有在首次切换时构建")
        firstTabState := App.uiInteractions.GetButton(
            settingsDialog.tabButtons[1].Hwnd)
        secondTabState := App.uiInteractions.GetButton(
            settingsDialog.tabButtons[2].Hwnd)
        AssertLocalizedWindow(settingsDialog.intervalEdit.Visible
            && settingsDialog.retryEdit.Visible
            && settingsDialog.recursiveImportCheck.Visible
            && !settingsDialog.showAtStartupCheck.Visible
            && settingsDialog.gracefulStopEdit == ""
            && firstTabState.textColor == UiThemeService.Color("TabText")
            && secondTabState.textColor
                == UiThemeService.Color("TabActiveText"),
            language " 监控与启动页的控件归属错误")
        AssertProductionWindowLayout(settingsDialog.gui, language,
            "SettingsWindow Monitoring")
        AssertSettingsPageContentInset(settingsDialog, language,
            "SettingsWindow Monitoring")
        recursiveImportRect := GetControlClientRect(
            settingsDialog.recursiveImportCheck.Hwnd,
            settingsDialog.gui.Hwnd)
        AssertLocalizedWindow(Abs((recursiveImportRect.Left
                + recursiveImportRect.Right) / 2
                - settingsClientRect.Width / 2) <= centerTolerance,
            language " 导入子目录选项没有按实际文字宽度水平居中")

        settingsDialog.SwitchTab(3)
        AssertLocalizedWindow(settingsDialog.tabBuilt[3]
            && settingsDialog.tabControls[3].Length > 0,
            language " 停止策略页没有在首次切换时构建")
        AssertLocalizedWindow(settingsDialog.gracefulStopEdit.Visible
            && settingsDialog.ctrlCWaitEdit.Visible
            && settingsDialog.forceTerminateCheck.Visible
            && !settingsDialog.intervalEdit.Visible
            && settingsDialog.logMaxEdit == "",
            language " 停止策略页的控件归属错误")
        AssertProductionWindowLayout(settingsDialog.gui, language,
            "SettingsWindow StopPolicy")
        AssertSettingsPageContentInset(settingsDialog, language,
            "SettingsWindow StopPolicy")
        forceTerminateRect := GetControlClientRect(
            settingsDialog.forceTerminateCheck.Hwnd,
            settingsDialog.gui.Hwnd)
        AssertLocalizedWindow(Abs((forceTerminateRect.Left
                + forceTerminateRect.Right) / 2
                - settingsClientRect.Width / 2) <= centerTolerance,
            language " 强制终止选项没有按实际文字宽度水平居中")

        settingsDialog.SwitchTab(4)
        AssertLocalizedWindow(settingsDialog.tabBuilt[4]
            && settingsDialog.tabControls[4].Length > 0,
            language " 日志页没有在首次切换时构建")
        AssertLocalizedWindow(settingsDialog.logMaxEdit.Visible
            && settingsDialog.logRetentionEdit.Visible
            && settingsDialog.logDirEdit.Visible
            && settingsDialog.clearLogsOnStartupCheck.Visible
            && !settingsDialog.gracefulStopEdit.Visible
            && !settingsDialog.aboutLogo.Visible,
            language " 日志页的控件归属错误")
        AssertProductionWindowLayout(settingsDialog.gui, language,
            "SettingsWindow Logs")
        AssertSettingsPageContentInset(settingsDialog, language,
            "SettingsWindow Logs")
        clearLogsCenteredRect := GetControlClientRect(
            settingsDialog.clearLogsOnStartupCheck.Hwnd,
            settingsDialog.gui.Hwnd)
        AssertLocalizedWindow(Abs((clearLogsCenteredRect.Left
                + clearLogsCenteredRect.Right) / 2
                - settingsClientRect.Width / 2) <= centerTolerance,
            language " 启动清理日志选项没有按实际文字宽度水平居中")

        logBrowseHwnd := FindChildControlByText(settingsDialog.gui.Hwnd,
            Tr("浏览"))
        AssertLocalizedWindow(logBrowseHwnd,
            language " 日志页无法定位路径浏览按钮")
        logPathRect := GetControlClientRect(settingsDialog.logDirEdit.Hwnd,
            settingsDialog.gui.Hwnd)
        logBrowseRect := GetControlClientRect(logBrowseHwnd,
            settingsDialog.gui.Hwnd)
        retryRect := GetControlClientRect(settingsDialog.retryEdit.Hwnd,
            settingsDialog.gui.Hwnd)
        clearLogsRect := GetControlClientRect(
            settingsDialog.clearLogsOnStartupCheck.Hwnd,
            settingsDialog.gui.Hwnd)
        logRowGap := Max(8, Round(8 * windowDpi / 96))
        AssertLocalizedWindow(logPathRect.Width > retryRect.Width
            && Abs(logBrowseRect.Right - logPathRect.Right)
                <= centerTolerance
            && logBrowseRect.Top >= logPathRect.Bottom + logRowGap
            && clearLogsRect.Top >= logBrowseRect.Bottom + logRowGap,
            language " 日志路径输入框未延长，或浏览按钮没有独占下一行")

        alignedInputs := [
            {Label: Tr("进程状态检查间隔（毫秒）："),
                Edit: settingsDialog.intervalEdit},
            {Label: Tr("崩溃自动重启延迟序列（秒）："),
                Edit: settingsDialog.retryEdit},
            {Label: Tr("GUI 程序关闭超时（秒）："),
                Edit: settingsDialog.gracefulStopEdit},
            {Label: Tr("CLI 程序关闭超时（秒）："),
                Edit: settingsDialog.ctrlCWaitEdit},
            {Label: Tr("运行日志显示上限（条）："),
                Edit: settingsDialog.logMaxEdit},
            {Label: Tr("批处理日志保留天数："),
                Edit: settingsDialog.logRetentionEdit},
            {Label: Tr("批处理日志保存路径："),
                Edit: settingsDialog.logDirEdit}
        ]
        alignedInputLeft := ""
        for alignedInput in alignedInputs {
            alignedLabelHwnd := FindChildControlByText(
                settingsDialog.gui.Hwnd, alignedInput.Label)
            AssertLocalizedWindow(alignedLabelHwnd,
                language " 无法定位设置标签：" alignedInput.Label)
            alignedLabelStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
                alignedLabelHwnd, "Int", -16, "Ptr")
            AssertLocalizedWindow((alignedLabelStyle & 0x3) == 0x2,
                language " 输入框标签没有右对齐：" alignedInput.Label)
            alignedEditRect := GetControlClientRect(
                alignedInput.Edit.Hwnd, settingsDialog.gui.Hwnd)
            if alignedInputLeft == ""
                alignedInputLeft := alignedEditRect.Left
            else
                AssertLocalizedWindow(Abs(alignedEditRect.Left
                    - alignedInputLeft) <= centerTolerance,
                    language " 设置输入框没有形成统一垂直线："
                        alignedInput.Label)
        }
        settingsDialog.intervalEdit.GetPos(, , &intervalInputWidth)
        settingsDialog.retryEdit.GetPos(, , &retryInputWidth)
        settingsDialog.gracefulStopEdit.GetPos(, , &guiTimeoutInputWidth)
        settingsDialog.ctrlCWaitEdit.GetPos(, , &cliTimeoutInputWidth)
        settingsDialog.logMaxEdit.GetPos(, , &logMaxInputWidth)
        settingsDialog.logRetentionEdit.GetPos(, , &retentionInputWidth)
        settingsDialog.logDirEdit.GetPos(, , &logPathInputWidth)
        AssertLocalizedWindow(logPathInputWidth > retryInputWidth
            && retryInputWidth > intervalInputWidth
            && intervalInputWidth > logMaxInputWidth
            && logMaxInputWidth > retentionInputWidth
            && retentionInputWidth > guiTimeoutInputWidth
            && guiTimeoutInputWidth > cliTimeoutInputWidth,
            language " 设置输入框宽度没有按字段通常输入长度固定分配")

        aboutControlCountBeforeRepeat := settingsDialog.tabControls[5].Length
        settingsDialog.SwitchTab(5)
        AssertLocalizedWindow(settingsDialog.tabControls[5].Length
                == aboutControlCountBeforeRepeat,
            language " 重复切换关于页时又创建了一批控件")
        AssertLocalizedWindow(settingsDialog.aboutLogo.Visible
            && settingsDialog.aboutName.Visible
            && settingsDialog.aboutSubtitle.Visible
            && settingsDialog.versionLabel.Visible
            && settingsDialog.versionValue.Visible
            && settingsDialog.runtimeLabel.Visible
            && settingsDialog.runtimeValue.Visible
            && settingsDialog.aboutTopDivider.Visible
            && settingsDialog.aboutInfoDivider.Visible
            && settingsDialog.aboutBottomDivider.Visible
            && settingsDialog.checkUpdateButton.Visible
            && settingsDialog.projectButton.Visible
            && !settingsDialog.saveButton.Visible
            && !settingsDialog.cancelButton.Visible
            && !settingsDialog.checkUpdatesOnStartupCheck.Visible
            && !settingsDialog.logMaxEdit.Visible,
            language " 关于页的控件归属错误")
        AssertLocalizedWindow(settingsDialog.aboutName.Text
            == Tr("进程守护小助手"),
            language " 关于页没有显示标准软件名称")
        AssertLocalizedWindow(settingsDialog.aboutSubtitle.Text
            == Tr("持续守护重要程序与自动化任务，让日常工作稳定运行"),
            language " 关于页没有显示本地化产品简介")
        AssertLocalizedWindow(settingsDialog.projectButton.Text
            == Tr("开源地址")
            && App.uiInteractions.HasButton(
                settingsDialog.projectButton.Hwnd)
            && SettingsWindow.ProjectHomeUrl
                == "https://github.com/realSilasYang/process-watchdog",
            language " 关于页的开源地址按钮文本、交互或地址错误")
        updateButtonState := App.uiInteractions.GetButton(
            settingsDialog.checkUpdateButton.Hwnd)
        projectButtonState := App.uiInteractions.GetButton(
            settingsDialog.projectButton.Hwnd)
        AssertLocalizedWindow(!updateButtonState.HasOwnProp("buttonIcon")
            && updateButtonState.HasOwnProp("buttonImage")
            && updateButtonState.buttonImage.sourcePath
                == GetApplicationAssetPath(
                    "ui-icons\lucide\refresh-cw-action.svg"),
            language " 关于页立即检查更新按钮缺少匹配语义的 SVG 图标")
        AssertLocalizedWindow(!projectButtonState.HasOwnProp("buttonIcon")
            && projectButtonState.HasOwnProp("buttonImage")
            && projectButtonState.buttonImage.Width >= 64
            && projectButtonState.buttonImage.Height >= 64
            && projectButtonState.buttonImage.Pixels.Size
                == projectButtonState.buttonImage.Width
                    * projectButtonState.buttonImage.Height * 4
            && projectButtonState.buttonImage.sourcePath
                == GetApplicationAssetPath("ui-icons\external-link.svg")
            && projectButtonState.HasOwnProp("tooltipText")
            && projectButtonState.tooltipText
                == SettingsWindow.ProjectHomeUrl,
            language " 关于页开源地址按钮没有加载透明 SVG 外链图标")
        tooltipDialog := DarkTooltipWindow()
        tooltipDialog.HandleMouseMove(0, 0, Win32.WM_MOUSEMOVE,
            settingsDialog.projectButton.Hwnd)
        Sleep(550)
        AssertLocalizedWindow(tooltipDialog.IsOpen()
            && tooltipDialog.textControl.Text
                == SettingsWindow.ProjectHomeUrl,
            language " 开源地址按钮悬浮后没有显示完整网址")
        tooltipDialog.Close()
        tooltipDialog := ""
        saveButtonState := App.uiInteractions.GetButton(
            settingsDialog.saveButton.Hwnd)
        cancelButtonState := App.uiInteractions.GetButton(
            settingsDialog.cancelButton.Hwnd)
        AssertLocalizedWindow(!saveButtonState.HasOwnProp("buttonImage")
            && !saveButtonState.HasOwnProp("buttonIcon")
            && !cancelButtonState.HasOwnProp("buttonImage")
            && !cancelButtonState.HasOwnProp("buttonIcon"),
            language " 设置窗口保存或取消按钮不应显示前置图标")
        aboutTitleFont := GetLocalizedWindowFontSpec(
            settingsDialog.aboutName.Hwnd)
        aboutSubtitleFont := GetLocalizedWindowFontSpec(
            settingsDialog.aboutSubtitle.Hwnd)
        versionLabelFont := GetLocalizedWindowFontSpec(
            settingsDialog.versionLabel.Hwnd)
        versionValueFont := GetLocalizedWindowFontSpec(
            settingsDialog.versionValue.Hwnd)
        runtimeLabelFont := GetLocalizedWindowFontSpec(
            settingsDialog.runtimeLabel.Hwnd)
        runtimeValueFont := GetLocalizedWindowFontSpec(
            settingsDialog.runtimeValue.Hwnd)
        updateButtonFont := GetLocalizedWindowFontSpec(
            settingsDialog.checkUpdateButton.Hwnd)
        projectButtonFont := GetLocalizedWindowFontSpec(
            settingsDialog.projectButton.Hwnd)
        expectedContentFont := LocalizationService.GetUiFontName()
        AssertLocalizedWindow(aboutTitleFont.Face == expectedSystemFont
            && aboutTitleFont.Weight >= 700
            && (language != "zh-CN"
                || aboutTitleFont.Face == "Microsoft YaHei UI")
            && aboutSubtitleFont.Face == expectedContentFont
            && aboutSubtitleFont.Weight < 700
            && versionLabelFont.Face == expectedContentFont
            && versionLabelFont.Weight < 700
            && versionValueFont.Face == expectedContentFont
            && versionValueFont.Weight < 700
            && runtimeLabelFont.Face == expectedContentFont
            && runtimeLabelFont.Weight < 700
            && runtimeValueFont.Face == expectedContentFont
            && runtimeValueFont.Weight < 700
            && updateButtonFont.Face == expectedSystemFont
            && updateButtonFont.Weight >= 700
            && projectButtonFont.Face == expectedSystemFont
            && projectButtonFont.Weight >= 700
            && Abs(aboutTitleFont.Height) > Abs(versionValueFont.Height)
            && Abs(versionValueFont.Height) > Abs(versionLabelFont.Height)
            && Abs(versionLabelFont.Height) > Abs(aboutSubtitleFont.Height),
            language " 关于页标题、信息或操作按钮的字体层级错误")
        aboutWindowRect := Buffer(16, 0)
        DllCall("user32\GetClientRect", "Ptr", settingsDialog.gui.Hwnd,
            "Ptr", aboutWindowRect)
        aboutCenterX := NumGet(aboutWindowRect, 8, "Int") / 2
        aboutCenteredControls := [settingsDialog.aboutLogo,
            settingsDialog.aboutName, settingsDialog.aboutSubtitle,
            settingsDialog.aboutTopDivider,
            settingsDialog.aboutInfoDivider,
            settingsDialog.aboutBottomDivider]
        for aboutControl in aboutCenteredControls {
            aboutRect := GetControlClientRect(aboutControl.Hwnd,
                settingsDialog.gui.Hwnd)
            AssertLocalizedWindow(Abs((aboutRect.Left + aboutRect.Right) / 2
                    - aboutCenterX) <= centerTolerance,
                language " 关于页项目没有水平居中："
                    GetNativeWindowText(aboutControl.Hwnd))
        }
        versionLabelRect := GetControlClientRect(
            settingsDialog.versionLabel.Hwnd, settingsDialog.gui.Hwnd)
        versionValueRect := GetControlClientRect(
            settingsDialog.versionValue.Hwnd, settingsDialog.gui.Hwnd)
        runtimeLabelRect := GetControlClientRect(
            settingsDialog.runtimeLabel.Hwnd, settingsDialog.gui.Hwnd)
        runtimeValueRect := GetControlClientRect(
            settingsDialog.runtimeValue.Hwnd, settingsDialog.gui.Hwnd)
        infoDividerRect := GetControlClientRect(
            settingsDialog.aboutInfoDivider.Hwnd, settingsDialog.gui.Hwnd)
        AssertLocalizedWindow(versionLabelRect.Right < infoDividerRect.Left
            && versionValueRect.Right < infoDividerRect.Left
            && runtimeLabelRect.Left > infoDividerRect.Right
            && runtimeValueRect.Left > infoDividerRect.Right
            && versionLabelRect.Top == runtimeLabelRect.Top
            && versionValueRect.Top == runtimeValueRect.Top
            && versionLabelRect.Bottom < versionValueRect.Top
            && runtimeLabelRect.Bottom < runtimeValueRect.Top,
            language " 关于页版本和运行环境没有按双列信息层级排列")
        aboutLogoRect := GetControlClientRect(settingsDialog.aboutLogo.Hwnd,
            settingsDialog.gui.Hwnd)
        aboutNameRect := GetControlClientRect(settingsDialog.aboutName.Hwnd,
            settingsDialog.gui.Hwnd)
        aboutSubtitleRect := GetControlClientRect(
            settingsDialog.aboutSubtitle.Hwnd, settingsDialog.gui.Hwnd)
        topDividerRect := GetControlClientRect(
            settingsDialog.aboutTopDivider.Hwnd, settingsDialog.gui.Hwnd)
        bottomDividerRect := GetControlClientRect(
            settingsDialog.aboutBottomDivider.Hwnd, settingsDialog.gui.Hwnd)
        updateButtonRect := GetControlClientRect(
            settingsDialog.checkUpdateButton.Hwnd, settingsDialog.gui.Hwnd)
        projectButtonRect := GetControlClientRect(
            settingsDialog.projectButton.Hwnd, settingsDialog.gui.Hwnd)
        AssertLocalizedWindow(aboutNameRect.Bottom < aboutSubtitleRect.Top
            && aboutSubtitleRect.Bottom < topDividerRect.Top
            && topDividerRect.Bottom < versionLabelRect.Top
            && versionLabelRect.Bottom < versionValueRect.Top
            && versionValueRect.Bottom < bottomDividerRect.Top
            && bottomDividerRect.Bottom < updateButtonRect.Top
            && updateButtonRect.Top == projectButtonRect.Top
            && updateButtonRect.Right < projectButtonRect.Left
            && Abs((updateButtonRect.Left + projectButtonRect.Right) / 2
                    - aboutCenterX) <= centerTolerance
            && topDividerRect.Left == bottomDividerRect.Left
            && topDividerRect.Right == bottomDividerRect.Right,
            language " 关于页分区顺序、间距或分割线宽度错误")
        aboutContentBoundary := Round(47 * windowDpi / 96)
        aboutTopMargin := aboutLogoRect.Top - aboutContentBoundary
        aboutBottomMargin := NumGet(aboutWindowRect, 12, "Int")
            - Max(updateButtonRect.Bottom, projectButtonRect.Bottom)
        aboutCenterTolerance := Max(6, Round(6 * windowDpi / 96))
        minimumActionHeight := Round(36 * windowDpi / 96)
        AssertLocalizedWindow(Abs(aboutTopMargin - aboutBottomMargin)
                <= aboutCenterTolerance
            && updateButtonRect.Height >= minimumActionHeight
            && projectButtonRect.Height >= minimumActionHeight,
            language " 关于页内容没有垂直居中，或操作按钮仍然过矮")
        AssertProductionWindowLayout(settingsDialog.gui, language,
            "SettingsWindow About")
        AssertSettingsPageContentInset(settingsDialog, language,
            "SettingsWindow About")
        settingsDialog.SetUpdateCheckActive(true)
        AssertLocalizedWindow(settingsDialog.checkUpdateButton.Visible
            && !settingsDialog.checkUpdateButton.Enabled
            && settingsDialog.checkUpdateButton.Text == Tr("正在检查更新…"),
            language " 更新检查期间没有在原按钮内显示检查状态")
        AssertProductionWindowLayout(settingsDialog.gui, language,
            "SettingsWindow checking update")
        AssertSettingsPageContentInset(settingsDialog, language,
            "SettingsWindow checking update")
        settingsDialog.SetUpdateCheckActive(false)
        AssertLocalizedWindow(settingsDialog.checkUpdateButton.Visible
            && settingsDialog.checkUpdateButton.Enabled
            && settingsDialog.checkUpdateButton.Text
                == Tr("立即检查更新"),
            language " 更新检查结束后没有恢复按钮")

        settingsDialog.SwitchTab(1)
        AssertLocalizedWindow(settingsDialog.saveButton.Visible
            && settingsDialog.cancelButton.Visible,
            language " 返回可编辑设置页后没有恢复全局保存区")

        AssertLocalizedWindow(settingsDialog.shortcutLabel
            && settingsDialog.taskLabel && settingsDialog.shortcutButton
            && settingsDialog.taskButton,
            language " 快捷方式或计划任务设置缺少实例控件引用")
        shortcutRect := GetControlClientRect(
            settingsDialog.shortcutLabel.Hwnd,
            settingsDialog.gui.Hwnd)
        taskRect := GetControlClientRect(settingsDialog.taskLabel.Hwnd,
            settingsDialog.gui.Hwnd)
        shortcutButtonRect := GetControlClientRect(
            settingsDialog.shortcutButton.Hwnd,
            settingsDialog.gui.Hwnd)
        taskButtonRect := GetControlClientRect(
            settingsDialog.taskButton.Hwnd, settingsDialog.gui.Hwnd)
        shortcutActionGap := shortcutButtonRect.Left - shortcutRect.Right
        taskActionGap := taskButtonRect.Left - taskRect.Right
        compactIntegrationGap := Round(24 * windowDpi / 96)
        AssertLocalizedWindow(shortcutButtonRect.Left
                > shortcutRect.Right
            && taskButtonRect.Left > taskRect.Right
            && shortcutButtonRect.Left == taskButtonRect.Left
            && Min(shortcutActionGap, taskActionGap)
                <= compactIntegrationGap,
            language " 系统集成标签与按钮间距过大或按钮未对齐")
        integrationGroupLeft := Min(shortcutRect.Left, taskRect.Left)
        integrationGroupRight := Max(shortcutButtonRect.Right,
            taskButtonRect.Right)
        AssertLocalizedWindow(Abs((integrationGroupLeft
                + integrationGroupRight) / 2
                - settingsClientRect.Width / 2) <= centerTolerance,
            language " 快捷方式与计划任务的标签按钮组没有整体水平居中")
        AssertLocalizedWindow(CountThinHorizontalSeparators(
            settingsDialog.gui.Hwnd, shortcutRect.Bottom, taskRect.Top,
            windowDpi) == 0,
            language " 快捷方式和计划任务之间仍存在分割线")
        shortcutButtonState := App.uiInteractions.GetButton(
            settingsDialog.shortcutButton.Hwnd)
        taskButtonState := App.uiInteractions.GetButton(
            settingsDialog.taskButton.Hwnd)
        browseButtonState := App.uiInteractions.GetButton(logBrowseHwnd)
        taskIconByText := Map(
            "…", "loader-circle.svg",
            Tr("开启"), "play.svg",
            Tr("关闭"), "power.svg",
            Tr("切换"), "repeat-2.svg",
            Tr("冲突"), "triangle-alert.svg")
        AssertLocalizedWindow(shortcutButtonState.HasOwnProp("buttonImage")
            && shortcutButtonState.buttonImage.sourcePath
                == GetApplicationAssetPath(
                    "ui-icons\lucide\square-plus.svg")
            && browseButtonState.HasOwnProp("buttonImage")
            && browseButtonState.buttonImage.sourcePath
                == GetApplicationAssetPath(
                    "ui-icons\lucide\folder-open.svg")
            && taskIconByText.Has(settingsDialog.taskButton.Text)
            && (settingsDialog.taskButton.Text != "…"
                || !settingsDialog.taskButton.Enabled)
            && taskButtonState.HasOwnProp("buttonImage")
            && taskButtonState.buttonImage.sourcePath
                == GetApplicationAssetPath("ui-icons\lucide\"
                    taskIconByText[settingsDialog.taskButton.Text]),
            language " 创建、计划任务或浏览按钮没有使用匹配语义的 SVG 图标")
        initialShortcutFeedbackGeneration :=
            settingsDialog.shortcutFeedbackGeneration
        AssertLocalizedWindow(settingsDialog.shortcutButton.Text
                == Tr("创建")
            && settingsDialog.ShowShortcutCreatedFeedback()
            && settingsDialog.shortcutButton.Text == Tr("创建成功！")
            && settingsDialog.shortcutFeedbackTimer
            && settingsDialog.shortcutFeedbackGeneration
                > initialShortcutFeedbackGeneration
            && !shortcutButtonState.HasOwnProp("buttonIcon")
            && !shortcutButtonState.HasOwnProp("buttonImage"),
            language " 快捷方式创建成功后没有在原按钮中显示无图标反馈")
        shortcutFeedbackTimer := settingsDialog.shortcutFeedbackTimer
        shortcutFeedbackGeneration :=
            settingsDialog.shortcutFeedbackGeneration
        SetTimer(shortcutFeedbackTimer, 0)
        settingsDialog.RestoreShortcutButton(shortcutFeedbackGeneration)
        AssertLocalizedWindow(settingsDialog.shortcutButton.Text
                == Tr("创建")
            && !settingsDialog.shortcutFeedbackTimer
            && shortcutButtonState.HasOwnProp("buttonImage")
            && shortcutButtonState.buttonImage.sourcePath
                == GetApplicationAssetPath(
                    "ui-icons\lucide\square-plus.svg"),
            language " 快捷方式按钮没有在三秒反馈结束后恢复文字和 SVG 图标")
        comboHandles := GetComboBoxThemeHandles(
            settingsDialog.languageDropDown.Hwnd)
        AssertLocalizedWindow(comboHandles.Combo
            && DllCall("uxtheme\GetWindowTheme", "Ptr",
                comboHandles.Combo, "Ptr"),
            language " 界面语言下拉框收起区没有应用原生主题")
        AssertLocalizedWindow(comboHandles.List
            && DllCall("uxtheme\GetWindowTheme", "Ptr",
                comboHandles.List, "Ptr"),
            language " 界面语言下拉列表没有应用原生主题")
        AssertLocalizedWindow(
            DarkComboBoxListThemeRegistry.IsRegistered(comboHandles.List),
            language " 界面语言下拉列表没有注册深色背景绘制")
        listDeviceContext := DllCall("user32\GetDC", "Ptr",
            comboHandles.List, "Ptr")
        AssertLocalizedWindow(listDeviceContext,
            language " 无法读取界面语言下拉列表的绘制上下文")
        try {
            listBrush := DarkComboBoxListThemeRegistry.HandleListColor(
                listDeviceContext, comboHandles.List)
            AssertLocalizedWindow(listBrush
                && DllCall("gdi32\GetBkColor", "Ptr", listDeviceContext,
                    "UInt")
                    == DarkComboBoxListThemeRegistry.BackgroundColorRef
                && DllCall("gdi32\GetTextColor", "Ptr", listDeviceContext,
                    "UInt")
                    == DarkComboBoxListThemeRegistry.TextColorRef,
                language " 界面语言下拉列表没有应用深色背景和浅色文字")
        } finally DllCall("user32\ReleaseDC", "Ptr", comboHandles.List,
            "Ptr", listDeviceContext)
        fontComboHandles := GetComboBoxThemeHandles(
            settingsDialog.fontDropDown.Hwnd)
        AssertLocalizedWindow(fontComboHandles.Combo
            && DllCall("uxtheme\GetWindowTheme", "Ptr",
                fontComboHandles.Combo, "Ptr"),
            language " 内容字体下拉框收起区没有应用原生主题")
        ; 字体列表通常带原生滚动条；部分 Windows 构建对带 WS_VSCROLL 的
        ; ComboLBox 即使 SetWindowTheme 成功也会让 GetWindowTheme 返回空句柄，
        ; 因此这里验证窗口存在、深色绘制注册及实际 DC 颜色，不依赖该假阴性。
        AssertLocalizedWindow(fontComboHandles.List
            && DllCall("user32\IsWindow", "Ptr", fontComboHandles.List,
                "Int"),
            language " 内容字体下拉列表窗口不存在")
        AssertLocalizedWindow(
            DarkComboBoxListThemeRegistry.IsRegistered(
                fontComboHandles.List),
            language " 内容字体下拉列表没有注册深色背景绘制")
        fontListDeviceContext := DllCall("user32\GetDC", "Ptr",
            fontComboHandles.List, "Ptr")
        AssertLocalizedWindow(fontListDeviceContext,
            language " 无法读取内容字体下拉列表的绘制上下文")
        try {
            fontListBrush := DarkComboBoxListThemeRegistry.HandleListColor(
                fontListDeviceContext, fontComboHandles.List)
            AssertLocalizedWindow(fontListBrush
                && DllCall("gdi32\GetBkColor", "Ptr",
                    fontListDeviceContext, "UInt")
                    == DarkComboBoxListThemeRegistry.BackgroundColorRef
                && DllCall("gdi32\GetTextColor", "Ptr",
                    fontListDeviceContext, "UInt")
                    == DarkComboBoxListThemeRegistry.TextColorRef,
                language " 内容字体下拉列表没有应用深色背景和浅色文字")
        } finally DllCall("user32\ReleaseDC", "Ptr",
            fontComboHandles.List, "Ptr", fontListDeviceContext)
        settingsDialog.Close()
        AssertLocalizedWindow(
            !settingsDialog.fontDropDownCommandRegistered,
            language " 设置窗口关闭后仍保留字体下拉消息监听")
        AssertLocalizedWindow(
            !DarkComboBoxListThemeRegistry.IsRegistered(comboHandles.List),
            language " 设置窗口关闭后仍保留下拉列表深色绘制注册")
        AssertLocalizedWindow(
            !DarkComboBoxListThemeRegistry.IsRegistered(
                fontComboHandles.List),
            language " 设置窗口关闭后仍保留字体下拉列表深色绘制注册")

        addWindow := AddItemDialog(owner)
        addWindow.Show()
        addPointerOnSearchButton := IsPointerInsideButton(
            addWindow.searchButton.Hwnd)
        WinHide("ahk_id " addWindow.gui.Hwnd)
        AssertWindowTitle(addWindow.gui, Tr("添加监控项"), language,
            "AddItemDialog")
        AssertProductionWindowLayout(addWindow.gui, language,
            "AddItemDialog")
        addSearchState := App.uiInteractions.GetButton(
            addWindow.searchButton.Hwnd)
        addBrowseState := App.uiInteractions.GetButton(
            addWindow.browseButton.Hwnd)
        addOkState := App.uiInteractions.GetButton(addWindow.okButton.Hwnd)
        addCancelState := App.uiInteractions.GetButton(
            addWindow.cancelButton.Hwnd)
        addSearchRect := GetControlClientRect(addWindow.searchButton.Hwnd,
            addWindow.gui.Hwnd)
        addBrowseRect := GetControlClientRect(addWindow.browseButton.Hwnd,
            addWindow.gui.Hwnd)
        addHintRect := GetControlClientRect(addWindow.pathHint.Hwnd,
            addWindow.gui.Hwnd)
        addPathRect := GetControlClientRect(addWindow.edit.Hwnd,
            addWindow.gui.Hwnd)
        addOkRect := GetControlClientRect(addWindow.okButton.Hwnd,
            addWindow.gui.Hwnd)
        addCancelRect := GetControlClientRect(addWindow.cancelButton.Hwnd,
            addWindow.gui.Hwnd)
        addClientRect := GetWindowClientRect(addWindow.gui.Hwnd)
        addDpiScale := DllCall("user32\GetDpiForWindow", "Ptr",
            addWindow.gui.Hwnd, "UInt") / 96
        addUtilityHintGap := addHintRect.Top
            - Max(addSearchRect.Bottom, addBrowseRect.Bottom)
        addHintPathGap := addPathRect.Top - addHintRect.Bottom
        addPathActionGap := addOkRect.Top - addPathRect.Bottom
        addUtilityCenterX := (addSearchRect.Left + addBrowseRect.Right) / 2
        addHintCenterX := (addHintRect.Left + addHintRect.Right) / 2
        addPathCenterX := (addPathRect.Left + addPathRect.Right) / 2
        addActionCenterX := (addOkRect.Left + addCancelRect.Right) / 2
        addHintStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
            addWindow.pathHint.Hwnd, "Int", -16, "Ptr")
        addHintTextWidth := 0
        for addHintLine in StrSplit(addWindow.pathHint.Text, "`n")
            addHintTextWidth := Max(addHintTextWidth,
                MeasureNativeControlText(addWindow.pathHint.Hwnd,
                    addHintLine))
        AssertLocalizedWindow(addWindow.searchButton.Text == Tr("搜索...")
            && addWindow.browseButton.Text == Tr("选择...")
            && addWindow.okButton.Text == Tr("确 定")
            && addWindow.cancelButton.Text == Tr("取 消"),
            language " 添加窗口按钮文字没有使用当前语言")
        AssertLocalizedWindow(addSearchState.HasOwnProp("buttonImage")
            && addSearchState.buttonImage.sourcePath
                == GetApplicationAssetPath("ui-icons\lucide\search.svg")
            && addBrowseState.HasOwnProp("buttonImage")
            && addBrowseState.buttonImage.sourcePath
                == GetApplicationAssetPath(
                    "ui-icons\lucide\folder-open.svg"),
            language " 添加窗口搜索或选择按钮没有使用预期 SVG 图标")
        AssertLocalizedWindow(!addOkState.HasOwnProp("buttonImage")
            && !addOkState.HasOwnProp("buttonIcon")
            && !addCancelState.HasOwnProp("buttonImage")
            && !addCancelState.HasOwnProp("buttonIcon")
            && !RegExMatch(addWindow.okButton.Text addWindow.cancelButton.Text,
                "[✔❌]"),
            language " 添加窗口确定／取消按钮不应带有图标或 Emoji")
        AssertLocalizedWindow(addPointerOnSearchButton,
            language " 添加窗口首次显示后鼠标没有位于搜索按钮中心")
        AssertLocalizedWindow(addHintTextWidth <= addHintRect.Right
                - addHintRect.Left,
            language " 添加窗口路径提示文字超出控件宽度")
        addBottomGap := addClientRect.Height - addOkRect.Bottom
        AssertLocalizedWindow(
            addUtilityHintGap >= Round(10 * addDpiScale)
            && addHintPathGap >= 0
            && addHintPathGap <= Round(8 * addDpiScale)
            && addPathActionGap >= 0
            && addPathActionGap <= Round(14 * addDpiScale)
            && addOkRect.Top == addCancelRect.Top
            && addOkRect.Right < addCancelRect.Left
            && Abs(addUtilityCenterX - addClientRect.Width / 2)
                <= Max(1, Round(addDpiScale))
            && Abs(addHintCenterX - addClientRect.Width / 2)
                <= Max(1, Round(addDpiScale))
            && Abs(addPathCenterX - addClientRect.Width / 2)
                <= Max(1, Round(addDpiScale))
            && Abs(addActionCenterX - addClientRect.Width / 2)
                <= Max(1, Round(addDpiScale))
            && (addHintStyle & 0x1) == 0x1
            && InStr(addWindow.pathHint.Text, "【")
            && InStr(addWindow.pathHint.Text, "】")
            && !InStr(addWindow.pathHint.Text, "（")
            && !InStr(addWindow.pathHint.Text, "）")
            && addBottomGap >= Round(10 * addDpiScale)
            && addBottomGap <= Round(20 * addDpiScale),
            language " 添加窗口布局不正确：间距=" addUtilityHintGap "/"
                addHintPathGap "/" addPathActionGap "，操作区中心="
                addActionCenterX "/" (addClientRect.Width / 2)
                "，底边距=" addBottomGap)
        if language == "zh-CN" {
            normalActionTop := addOkRect.Top
            normalClientHeight := addClientRect.Height
            addWindow.SetBatchUi(true, Tr("正在扫描..."))
            WinHide("ahk_id " addWindow.gui.Hwnd)
            batchStatusRect := GetControlClientRect(
                addWindow.batchStatus.Hwnd, addWindow.gui.Hwnd)
            batchActionRect := GetControlClientRect(addWindow.okButton.Hwnd,
                addWindow.gui.Hwnd)
            batchClientRect := GetWindowClientRect(addWindow.gui.Hwnd)
            AssertLocalizedWindow(addWindow.batchStatus.Visible
                && batchStatusRect.Bottom < batchActionRect.Top
                && batchActionRect.Top > normalActionTop
                && batchClientRect.Height > normalClientHeight,
                "zh-CN 添加窗口批量状态布局没有扩展或发生控件重叠")
            addWindow.SetBatchUi(false)
            WinHide("ahk_id " addWindow.gui.Hwnd)
            restoredActionRect := GetControlClientRect(
                addWindow.okButton.Hwnd, addWindow.gui.Hwnd)
            restoredClientRect := GetWindowClientRect(addWindow.gui.Hwnd)
            AssertLocalizedWindow(!addWindow.batchStatus.Visible
                && restoredActionRect.Top == normalActionTop
                && restoredClientRect.Height == normalClientHeight,
                "zh-CN 添加窗口结束批量状态后没有恢复紧凑布局")
        }
        addWindow.search.Show()
        if addWindow.search.gui {
            searchEditFocusedOnOpen := DllCall("user32\GetFocus", "Ptr")
                == addWindow.search.searchEdit.Hwnd
            WinHide("ahk_id " addWindow.search.gui.Hwnd)
            AssertWindowTitle(addWindow.search.gui, Tr("⚡️搜索⚡️"),
                language, "ApplicationSearchDialog")
            AssertProductionWindowLayout(addWindow.search.gui, language,
                "ApplicationSearchDialog")
            searchSelectState := App.uiInteractions.GetButton(
                addWindow.search.selectButton.Hwnd)
            AssertLocalizedWindow(addWindow.search.selectButton.Text
                    == Tr("确 定")
                && !searchSelectState.HasOwnProp("buttonImage")
                && !searchSelectState.HasOwnProp("buttonIcon")
                && !RegExMatch(addWindow.search.selectButton.Text, "[✔❌]"),
                language " 程序搜索确认按钮未保持纯文字")
            AssertLocalizedWindow(addWindow.search.searchLabel.Text
                    == Tr("搜索：")
                && !InStr(addWindow.search.searchLabel.Text, "🔍")
                && addWindow.search.searchLabelPresenter.items.Length == 1
                && addWindow.search.searchLabelPresenter.items[1].Text == ""
                && addWindow.search.searchLabelPresenter.items[1].IconPath
                    == GetApplicationAssetPath(
                        "ui-icons\lucide\search.svg")
                && addWindow.search.listHeader.Columns.Length == 3
                && addWindow.search.listHeader.Columns[3].Column == 3
                && addWindow.search.listHeader.Columns[3].Label
                    == Tr("扩展名")
                && addWindow.search.listHeader.RestoreColumn == 0
                && IsObject(addWindow.search.listSelectionPresenter)
                && addWindow.search.listSelectionPresenter.attached
                && addWindow.search.listSelectionPresenter.radiusDip == 4
                && addWindow.search.searchInputX == 52
                && searchEditFocusedOnOpen,
                language " 程序搜索栏、初始焦点或 SVG 搜索图标不正确")
            searchNativeHeader := SendMessage(Win32.LVM_GETHEADER, 0, 0,
                addWindow.search.lv.Hwnd)
            searchNativeColumnCount := searchNativeHeader
                ? SendMessage(0x1200, 0, 0, searchNativeHeader) : 0
            searchColumnWidthSum := 0
            Loop 3
                searchColumnWidthSum += SendMessage(
                    Win32.LVM_GETCOLUMNWIDTH, A_Index - 1, 0,
                    addWindow.search.lv.Hwnd)
            searchListClient := GetWindowClientRect(
                addWindow.search.lv.Hwnd)
            AssertLocalizedWindow(searchNativeColumnCount == 3
                && Abs(searchColumnWidthSum - searchListClient.Width) <= 3,
                language " 程序搜索结果没有严格收敛为填满内容区的三列")
            searchClientRect := GetControlClientRect(
                addWindow.search.resultStatusText.Hwnd,
                addWindow.search.gui.Hwnd)
            ; GetControlClientRect 返回 Win32 物理像素；窗口边界也必须走
            ; GetClientRect，不能与受 DPI 缩放的 AHK 逻辑尺寸混合比较。
            searchWindowClientRect := Buffer(16, 0)
            DllCall("user32\GetClientRect", "Ptr",
                addWindow.search.gui.Hwnd, "Ptr", searchWindowClientRect)
            searchClientWidth := NumGet(searchWindowClientRect, 8, "Int")
            searchClientHeight := NumGet(searchWindowClientRect, 12, "Int")
            AssertLocalizedWindow(searchClientRect.Left >= 0
                && searchClientRect.Top >= 0
                && searchClientRect.Right <= searchClientWidth
                && searchClientRect.Bottom <= searchClientHeight,
                language " 程序搜索结果状态栏超出窗口边界")

            ; 去掉隐藏的第四列后，伪表头的第三态仍必须恢复
            ; Everything 的原始返回顺序，不能停留在上一次降序结果。
            addWindow.search.resultRows := [
                {Name: "beta.exe", FullPath: "C:\beta.exe",
                    Extension: "exe", IconIndex: 0},
                {Name: "alpha.exe", FullPath: "C:\alpha.exe",
                    Extension: "exe", IconIndex: 0}
            ]
            for searchRow in addWindow.search.resultRows
                addWindow.search.lv.Add("", searchRow.Name,
                    searchRow.FullPath, searchRow.Extension)
            addWindow.search.listHeader.SortByDisplayColumn(1)
            searchAscendingFirst := addWindow.search.lv.GetText(1, 1)
            addWindow.search.listHeader.SortByDisplayColumn(1)
            searchDescendingFirst := addWindow.search.lv.GetText(1, 1)
            addWindow.search.listHeader.SortByDisplayColumn(1)
            AssertLocalizedWindow(searchAscendingFirst == "alpha.exe"
                && searchDescendingFirst == "beta.exe"
                && addWindow.search.lv.GetText(1, 1) == "beta.exe"
                && addWindow.search.lv.GetText(2, 1) == "alpha.exe"
                && !addWindow.search.listHeader.HasActiveSort(),
                language " 程序搜索去掉第四列后无法恢复原始顺序")
            addWindow.search.ShowEmptySearchState()

            ; 空输入必须保持空闲；即使此前存在结果和批次计时器，清空搜索框
            ; 也要立即作废会话并清空列表，不能退化为“搜索全部程序”。
            addWindow.search.lv.Add("", "stale.exe", executablePath, "exe")
            addWindow.search.everythingResultCount := 1
            addWindow.search.everythingResultIndex := 1
            addWindow.search.resultStatusText.Text := "stale search"
            SetTimer(addWindow.search.resultConsumeTimer, 60000)
            idleSessionBeforeClear :=
                addWindow.search.everythingSearchSessionId
            addWindow.search.searchEdit.Value := "   "
            addWindow.search.OnSearchChanged()
            AssertLocalizedWindow(
                addWindow.search.everythingSearchSessionId
                    > idleSessionBeforeClear
                && addWindow.search.everythingResultCount == 0
                && addWindow.search.everythingResultIndex == 0
                && addWindow.search.resultStatusText.Text == ""
                && addWindow.search.lv.GetCount() == 0
                && !addWindow.search.everythingLib,
                language " 空搜索词仍启动查询或保留搜索进度")

            ; 非空输入也要立即停止旧结果消费，并在完整防抖周期内保持空闲。
            addWindow.search.lv.Add("", "stale.exe", executablePath, "exe")
            addWindow.search.everythingResultCount := 1
            addWindow.search.everythingResultIndex := 1
            SetTimer(addWindow.search.resultConsumeTimer, 60000)
            debounceSessionBeforeInput :=
                addWindow.search.everythingSearchSessionId
            addWindow.search.searchEdit.Value := "note"
            addWindow.search.OnSearchChanged()
            Sleep(40)
            addWindow.search.searchEdit.Value := "notepad"
            addWindow.search.OnSearchChanged()
            Sleep(80)
            AssertLocalizedWindow(
                addWindow.search.everythingSearchSessionId
                    >= debounceSessionBeforeInput + 2
                && addWindow.search.everythingResultCount == 0
                && addWindow.search.everythingResultIndex == 0
                && addWindow.search.resultStatusText.Text == ""
                && addWindow.search.lv.GetCount() == 0
                && !addWindow.search.everythingLib,
                language " 连续输入未被防抖或仍在消费旧搜索结果")
            SetTimer(addWindow.search.searchTimer, 0)

            ; 强制模拟 SDK 缺失。组件本身不完整时应直接提示重新安装；只有
            ; SDK 可用但 IPC 后台未就绪时才进入 Everything 发现与静默启动。
            ; 两种情况都绝不能回退到为文件夹批量导入保留的后台扫描器。
            if addWindow.search.everythingLib {
                DllCall("kernel32\FreeLibrary", "Ptr",
                    addWindow.search.everythingLib)
                addWindow.search.everythingLib := 0
                addWindow.search.everythingFunctions := Map()
            }
            addWindow.search.everythingDllPath := A_Temp
                . "\missing-everything-sdk.dll"
            addWindow.search.searchEdit.Value := "notepad"
            workerCountBeforeSearch := App.fileScanner.Workers.Count
            AssertLocalizedWindow(!addWindow.search.RunEverythingSearch()
                && App.fileScanner.Workers.Count == workerCountBeforeSearch
                && addWindow.search.resultStatusText.Text == Tr(
                    "Everything 搜索组件缺失或无法加载，请完整解压或重新安装小助手。"),
                language " Everything SDK 缺失时仍触发了内置搜索回退")
            searchSessionBeforeClose :=
                addWindow.search.everythingSearchSessionId
            searchLabelHwnd := addWindow.search.searchLabel.Hwnd
            SetTimer(addWindow.search.resultConsumeTimer, 60000)
            addWindow.search.Close()
            AssertLocalizedWindow(
                addWindow.search.everythingSearchSessionId
                    > searchSessionBeforeClose
                && addWindow.search.everythingResultCount == 0
                && addWindow.search.everythingResultIndex == 0
                && addWindow.search.resultStatusText == ""
                && !SvgStatusBarPresenter.Has(searchLabelHwnd),
                language " 关闭程序搜索窗口后没有取消结果加载")
        }
        addWindow.Close()

        customWindow := CustomDisplayDialog(owner)
        customWindow.Show(executablePath, executableState)
        WinHide("ahk_id " customWindow.gui.Hwnd)
        AssertWindowTitle(customWindow.gui, Tr("自定义名称和图标"), language,
            "CustomDisplayDialog")
        AssertProductionWindowLayout(customWindow.gui, language,
            "CustomDisplayDialog")
        customDefaultNameState := App.uiInteractions.GetButton(
            customWindow.defaultNameButton.Hwnd)
        customDefaultIconState := App.uiInteractions.GetButton(
            customWindow.defaultIconButton.Hwnd)
        customBrowseHwnd := FindChildControlByText(customWindow.gui.Hwnd,
            Tr("浏览"))
        customSaveHwnd := FindChildControlByText(customWindow.gui.Hwnd,
            Tr("保存"))
        customCancelHwnd := FindChildControlByText(customWindow.gui.Hwnd,
            Tr("取消"))
        customBrowseState := App.uiInteractions.GetButton(customBrowseHwnd)
        customSaveState := App.uiInteractions.GetButton(customSaveHwnd)
        customCancelState := App.uiInteractions.GetButton(customCancelHwnd)
        AssertLocalizedWindow(customWindow.defaultNameButton.Text
                == Tr("恢复默认")
            && customWindow.defaultIconButton.Text == Tr("恢复默认")
            && !customDefaultNameState.HasOwnProp("buttonImage")
            && !customDefaultNameState.HasOwnProp("buttonIcon")
            && !customDefaultIconState.HasOwnProp("buttonImage")
            && !customDefaultIconState.HasOwnProp("buttonIcon")
            && !customWindow.defaultNameButton.Enabled
            && !customWindow.defaultIconButton.Enabled
            && customBrowseState.buttonImage.sourcePath
                == GetApplicationAssetPath(
                    "ui-icons\lucide\folder-open.svg")
            && !customSaveState.HasOwnProp("buttonImage")
            && !customSaveState.HasOwnProp("buttonIcon")
            && !customCancelState.HasOwnProp("buttonImage")
            && !customCancelState.HasOwnProp("buttonIcon"),
            language " 自定义名称和图标窗口的纯文字恢复、浏览 SVG 或保存／取消规则错误")
        customWindow.nameEdit.Value := "Temporary name"
        customWindow.iconEdit.Value := executablePath
        customWindow.UpdateDefaultButtonStates()
        AssertLocalizedWindow(customWindow.defaultNameButton.Enabled
            && customWindow.defaultIconButton.Enabled,
            language " 自定义内容不为空时恢复默认按钮未启用")
        customWindow.UseDefaultName()
        customWindow.UseDefaultIcon()
        AssertLocalizedWindow(customWindow.nameEdit.Value == ""
            && customWindow.iconEdit.Value == ""
            && !customWindow.defaultNameButton.Enabled
            && !customWindow.defaultIconButton.Enabled,
            language " 恢复默认按钮没有清除自定义值或恢复禁用状态")
        customWindow.Close()

        environmentWindow := EnvironmentSettingsDialog(owner)
        environmentWindow.Show(shortcutPath, shortcutState)
        if previewEnvironment {
            ; 视觉预览需要让捕获工具直接定位目标窗口。仅在显式预览模式下
            ; 临时解除所有者关系；正常产品窗口和自动化测试仍保留模态层级。
            DllCall("user32\SetWindowLongPtrW", "Ptr",
                environmentWindow.gui.Hwnd, "Int", -8, "Ptr", 0, "Ptr")
            DllCall("user32\EnableWindow", "Ptr", owner.Hwnd, "Int", true)
            WinHide("ahk_id " owner.Hwnd)
            environmentWindow.gui.Show()
            DllCall("user32\SetFocus", "Ptr", 0)
            WinSetAlwaysOnTop(1, "ahk_id " environmentWindow.gui.Hwnd)
            WinActivate("ahk_id " environmentWindow.gui.Hwnd)
            while environmentWindow.IsOpen()
                Sleep(50)
            return
        }
        WinHide("ahk_id " environmentWindow.gui.Hwnd)
        AssertWindowTitle(environmentWindow.gui, Tr("进程识别与启动设置"),
            language, "EnvironmentSettingsDialog")
        AssertProductionWindowLayout(environmentWindow.gui, language,
            "EnvironmentSettingsDialog")
        environmentBrowseState := App.uiInteractions.GetButton(
            FindChildControlByText(environmentWindow.gui.Hwnd,
                Tr("选择文件夹")))
        environmentSaveState := App.uiInteractions.GetButton(
            FindChildControlByText(environmentWindow.gui.Hwnd, Tr("保存")))
        environmentCancelState := App.uiInteractions.GetButton(
            FindChildControlByText(environmentWindow.gui.Hwnd, Tr("取消")))
        AssertLocalizedWindow(environmentBrowseState.buttonImage.sourcePath
                == GetApplicationAssetPath(
                    "ui-icons\lucide\folder-open.svg")
            && !environmentSaveState.HasOwnProp("buttonImage")
            && !environmentSaveState.HasOwnProp("buttonIcon")
            && !environmentCancelState.HasOwnProp("buttonImage")
            && !environmentCancelState.HasOwnProp("buttonIcon"),
            language " 进程设置窗口的浏览 SVG 或保存／取消纯文字规则错误")
        identityTitleFont := GetLocalizedWindowFontSpec(
            environmentWindow.identitySectionTitle.Hwnd)
        launchTitleFont := GetLocalizedWindowFontSpec(
            environmentWindow.launchSectionTitle.Hwnd)
        automaticLabelFont := GetLocalizedWindowFontSpec(
            environmentWindow.autoResolveLabel.Hwnd)
        manualLabelFont := GetLocalizedWindowFontSpec(
            environmentWindow.manualResolveLabel.Hwnd)
        sourceFont := GetLocalizedWindowFontSpec(
            environmentWindow.resolutionSourceText.Hwnd)
        workDirFont := GetLocalizedWindowFontSpec(
            environmentWindow.workDirEdit.Hwnd)
        AssertLocalizedWindow(identityTitleFont.Weight >= 700
            && launchTitleFont.Weight >= 700
            && automaticLabelFont.Weight < 700
            && manualLabelFont.Weight < 700
            && sourceFont.Weight < 700
            && workDirFont.Weight < 700,
            language " 进程识别与启动设置的标题粗体泄漏到正文控件")
        automaticRadioRect := GetControlClientRect(
            environmentWindow.autoResolveRadio.Hwnd,
            environmentWindow.gui.Hwnd)
        automaticLabelRect := GetControlClientRect(
            environmentWindow.autoResolveLabel.Hwnd,
            environmentWindow.gui.Hwnd)
        manualRadioRect := GetControlClientRect(
            environmentWindow.manualResolveRadio.Hwnd,
            environmentWindow.gui.Hwnd)
        manualLabelRect := GetControlClientRect(
            environmentWindow.manualResolveLabel.Hwnd,
            environmentWindow.gui.Hwnd)
        AssertLocalizedWindow(automaticRadioRect.Right
            <= automaticLabelRect.Left
            && manualRadioRect.Right <= manualLabelRect.Left
            && environmentWindow.autoResolveRadio.Text
                == Tr("自动识别进程")
            && environmentWindow.manualResolveRadio.Text == Tr("用户指定"),
            language " 进程识别模式没有分离原生标记与主题文字")
        resolvedStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
            environmentWindow.resolvedTargetEdit.Hwnd, "Int", -16, "Ptr")
        AssertLocalizedWindow(environmentWindow.resolvedTargetEdit.Enabled
            && (resolvedStyle & 0x0800)
            && environmentWindow.resolutionActionButton.Text
                == Tr("重新识别")
            && App.uiInteractions.GetButton(
                environmentWindow.resolutionActionButton.Hwnd)
                    .buttonImage.sourcePath
                == GetApplicationAssetPath(
                    "ui-icons\lucide\scan-search.svg")
            && PathsEquivalent(environmentWindow.resolvedTargetEdit.Value,
                executablePath)
            && InStr(environmentWindow.resolutionSourceText.Text,
                Tr("已保存身份")),
            language " 自动识别结果没有以可复制只读状态保留已保存身份")
        AssertLocalizedWindow(!(DllCall("user32\GetWindowLongPtrW", "Ptr",
            environmentWindow.envEdit.Hwnd, "Int", -16, "Ptr")
                & 0x00200000),
            language " 单行环境变量内容仍显示垂直滚动条")

        environmentWindow.SetResolvedTargetMode(true)
        manualStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
            environmentWindow.resolvedTargetEdit.Hwnd, "Int", -16, "Ptr")
        AssertLocalizedWindow(!(manualStyle & 0x0800)
            && environmentWindow.resolutionActionButton.Text
                == Tr("选择程序")
            && App.uiInteractions.GetButton(
                environmentWindow.resolutionActionButton.Hwnd)
                    .buttonImage.sourcePath
                == GetApplicationAssetPath(
                    "ui-icons\lucide\folder-open.svg")
            && environmentWindow.manualResolveRadio.Value == 1,
            language " 切换为手动指定后真实进程输入框仍不可编辑")
        environmentWindow.SetResolvedTargetMode(false)
        automaticStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
            environmentWindow.resolvedTargetEdit.Hwnd, "Int", -16, "Ptr")
        AssertLocalizedWindow((automaticStyle & 0x0800)
            && PathsEquivalent(environmentWindow.resolvedTargetEdit.Value,
                executablePath)
            && App.uiInteractions.GetButton(
                environmentWindow.resolutionActionButton.Hwnd)
                    .buttonImage.sourcePath
                == GetApplicationAssetPath(
                    "ui-icons\lucide\scan-search.svg")
            && environmentWindow.autoResolveRadio.Value == 1,
            language " 重新启用自动识别时丢失了暂时不可用的已保存身份")

        environmentWindow.envEdit.Value :=
            "A=1`nB=2`nC=3`nD=4`nE=5`nF=6`nG=7`nH=8"
        environmentWindow.UpdateEnvironmentScrollBar()
        AssertLocalizedWindow(environmentWindow.envScrollVisible
            && (DllCall("user32\GetWindowLongPtrW", "Ptr",
                environmentWindow.envEdit.Hwnd, "Int", -16, "Ptr")
                    & 0x00200000),
            language " 环境变量溢出后没有按需显示垂直滚动条")
        environmentWindow.envEdit.Value := "SMOKE_TEST=1"
        environmentWindow.UpdateEnvironmentScrollBar()
        AssertLocalizedWindow(!environmentWindow.envScrollVisible
            && !(DllCall("user32\GetWindowLongPtrW", "Ptr",
                environmentWindow.envEdit.Hwnd, "Int", -16, "Ptr")
                    & 0x00200000),
            language " 环境变量恢复为短内容后没有移除垂直滚动条")
        environmentWindow.Close()

        environmentWindow.Show(executablePath, executableState)
        WinHide("ahk_id " environmentWindow.gui.Hwnd)
        AssertWindowTitle(environmentWindow.gui, Tr("进程识别与启动设置"),
            language, "EnvironmentSettingsDialog direct target")
        AssertProductionWindowLayout(environmentWindow.gui, language,
            "EnvironmentSettingsDialog direct target")
        AssertLocalizedWindow(!environmentWindow.resolvedTargetEdit,
            language " 直接目标错误显示了快捷方式真实进程编辑器")
        environmentWindow.Close()

        environmentWindow.Show(scriptPath, scriptState)
        WinHide("ahk_id " environmentWindow.gui.Hwnd)
        AssertLocalizedWindow(environmentWindow.supportsCustomRuntime
            && environmentWindow.runtimePathEdit
            && environmentWindow.runtimeArgsEdit
            && PathsEquivalent(environmentWindow.runtimePathEdit.Value,
                A_AhkPath)
            && environmentWindow.runtimeArgsEdit.Value == "/ErrorStdOut"
            && App.uiInteractions.GetButton(
                FindChildControlByText(environmentWindow.gui.Hwnd,
                    Tr("选择程序"))).buttonImage.sourcePath
                == GetApplicationAssetPath(
                    "ui-icons\lucide\folder-open.svg"),
            language " 直接脚本没有显示通用运行时路径、参数或浏览操作")
        environmentWindow.Close()

        maintenanceWindow := MaintenanceSettingsDialog(owner)
        maintenanceWindow.Show(executablePath, executableState)
        WinHide("ahk_id " maintenanceWindow.gui.Hwnd)
        AssertWindowTitle(maintenanceWindow.gui, Tr("软件升级保护"),
            language, "MaintenanceSettingsDialog")
        AssertProductionWindowLayout(maintenanceWindow.gui, language,
            "MaintenanceSettingsDialog")
        maintenanceBrowseState := App.uiInteractions.GetButton(
            FindChildControlByText(maintenanceWindow.gui.Hwnd, Tr("浏览")))
        maintenanceAutoState := App.uiInteractions.GetButton(
            FindChildControlByText(maintenanceWindow.gui.Hwnd, Tr("自动")))
        maintenanceClearState := App.uiInteractions.GetButton(
            FindChildControlByText(maintenanceWindow.gui.Hwnd,
                Tr("清除记录")))
        maintenanceSaveState := App.uiInteractions.GetButton(
            FindChildControlByText(maintenanceWindow.gui.Hwnd, Tr("保存")))
        maintenanceCancelState := App.uiInteractions.GetButton(
            FindChildControlByText(maintenanceWindow.gui.Hwnd, Tr("取消")))
        AssertLocalizedWindow(maintenanceBrowseState.buttonImage.sourcePath
                == GetApplicationAssetPath(
                    "ui-icons\lucide\folder-open.svg")
            && maintenanceAutoState.buttonImage.sourcePath
                == GetApplicationAssetPath(
                    "ui-icons\lucide\wand-sparkles.svg")
            && maintenanceClearState.buttonImage.sourcePath
                == GetApplicationAssetPath("ui-icons\lucide\trash-2.svg")
            && !maintenanceSaveState.HasOwnProp("buttonImage")
            && !maintenanceSaveState.HasOwnProp("buttonIcon")
            && !maintenanceCancelState.HasOwnProp("buttonImage")
            && !maintenanceCancelState.HasOwnProp("buttonIcon"),
            language " 升级保护窗口的功能 SVG 或保存／取消纯文字规则错误")
        maintenanceWindow.Close()

        helpDialog := HelpWindow(owner)
        helpDialog.Show()
        WinHide("ahk_id " helpDialog.gui.Hwnd)
        AssertWindowTitle(helpDialog.gui, Tr("使用说明"), language,
            "HelpWindow")
        AssertProductionWindowLayout(helpDialog.gui, language, "HelpWindow")
        AssertLocalizedWindow(InStr(helpDialog.textEdit.Value,
            Tr("一、快速上手")),
            language " 使用说明正文没有切换语言")
        helpDialog.Close()

        logWindowInstance := LogWindow(owner)
        logWindowInstance.Show()
        WinHide("ahk_id " logWindowInstance.gui.Hwnd)
        AssertWindowTitle(logWindowInstance.gui, Tr("运行日志"), language,
            "LogWindow")
        AssertProductionWindowLayout(logWindowInstance.gui, language,
            "LogWindow")
        logExportState := App.uiInteractions.GetButton(
            logWindowInstance.exportButton.Hwnd)
        AssertLocalizedWindow(logExportState.buttonImage.sourcePath
                == GetApplicationAssetPath(
                    "ui-icons\lucide\package-open.svg"),
            language " 导出诊断包按钮缺少匹配语义的 SVG 图标")
        logWindowInstance.Close()

        batchLogPath := A_Temp
            . "\ProcessWatchdogLogs\9E0E36BA28EF0D760CB588F5E3EE9F52.log"
        batchLogNoticeDialog := BatchOutputLogNoticeWindow(owner)
        batchLogNoticeDialog.Show(batchLogPath)
        WinHide("ahk_id " batchLogNoticeDialog.gui.Hwnd)
        AssertWindowTitle(batchLogNoticeDialog.gui, Tr("运行日志"), language,
            "BatchOutputLogNoticeWindow")
        AssertProductionWindowLayout(batchLogNoticeDialog.gui, language,
            "BatchOutputLogNoticeWindow")
        AssertLocalizedWindow(batchLogNoticeDialog.pathEdit.Value
                == batchLogPath
            && batchLogNoticeDialog.pathEdit.Enabled
            && App.uiInteractions.HasButton(
                batchLogNoticeDialog.confirmButton.Hwnd),
            language " 批处理输出日志提示没有完整显示路径或注册确认按钮")
        batchLogNoticeDialog.Close()

        supportInfoDialog := SupportInfoWindow(owner)
        supportInfoDialog.Show()
        WinHide("ahk_id " supportInfoDialog.gui.Hwnd)
        AssertWindowTitle(supportInfoDialog.gui, Tr("帮助信息"), language,
            "SupportInfoWindow")
        AssertProductionWindowLayout(supportInfoDialog.gui, language,
            "SupportInfoWindow")
        AssertLocalizedWindow(App.uiInteractions.HasButton(
            supportInfoDialog.guideButton.Hwnd)
            && App.uiInteractions.HasButton(
                supportInfoDialog.logButton.Hwnd)
            && App.uiInteractions.HasButton(
                supportInfoDialog.feedbackButton.Hwnd),
            language " 帮助信息窗口按钮没有注册交互")
        supportGuideState := App.uiInteractions.GetButton(
            supportInfoDialog.guideButton.Hwnd)
        supportLogState := App.uiInteractions.GetButton(
            supportInfoDialog.logButton.Hwnd)
        supportFeedbackState := App.uiInteractions.GetButton(
            supportInfoDialog.feedbackButton.Hwnd)
        AssertLocalizedWindow(!supportGuideState.HasOwnProp("buttonIcon")
            && supportGuideState.HasOwnProp("buttonImage")
            && supportGuideState.buttonImage.sourcePath
                == GetApplicationAssetPath(
                    "ui-icons\lucide\book-open.svg")
            && !supportLogState.HasOwnProp("buttonIcon")
            && supportLogState.HasOwnProp("buttonImage")
            && supportLogState.buttonImage.sourcePath
                == GetApplicationAssetPath("ui-icons\lucide\logs.svg")
            && !supportFeedbackState.HasOwnProp("buttonIcon")
            && supportFeedbackState.HasOwnProp("buttonImage")
            && supportFeedbackState.buttonImage.sourcePath
                == GetApplicationAssetPath(
                    "ui-icons\lucide\message-square-text.svg")
            && !supportFeedbackState.HasOwnProp("tooltipText"),
            language " 帮助信息窗口 SVG 图标或反馈按钮提示状态错误")
        supportInfoRect := GetWindowClientRect(supportInfoDialog.gui.Hwnd)
        supportButtonRects := [
            GetControlClientRect(supportInfoDialog.guideButton.Hwnd,
                supportInfoDialog.gui.Hwnd),
            GetControlClientRect(supportInfoDialog.logButton.Hwnd,
                supportInfoDialog.gui.Hwnd),
            GetControlClientRect(supportInfoDialog.feedbackButton.Hwnd,
                supportInfoDialog.gui.Hwnd)
        ]
        supportWindowDpi := DllCall("user32\GetDpiForWindow", "Ptr",
            supportInfoDialog.gui.Hwnd, "UInt")
        if !supportWindowDpi
            supportWindowDpi := 96
        expectedSupportWidthDip := LocalizationService.UsesCompactLayout()
            ? 220 : 300
        expectedSupportButtonWidthDip := LocalizationService.UsesCompactLayout()
            ? 150 : 220
        supportButtonFont := GetLocalizedWindowFontSpec(
            supportInfoDialog.guideButton.Hwnd)
        AssertLocalizedWindow(supportInfoRect.Width
                <= Round(expectedSupportWidthDip * supportWindowDpi / 96) + 2
            && Abs(supportButtonRects[1].Width
                - Round(expectedSupportButtonWidthDip * supportWindowDpi / 96)) <= 2
            && Abs(supportButtonFont.Height)
                >= Round(12 * supportWindowDpi / 96)
            && supportButtonRects[1].Top < supportButtonRects[2].Top
            && supportButtonRects[2].Top < supportButtonRects[3].Top
            && supportButtonRects[1].Left == supportButtonRects[2].Left
            && supportButtonRects[2].Left == supportButtonRects[3].Left,
            language " 帮助信息窗口没有按窄窗口纵向排列三个操作")
        AssertLocalizedWindow(supportInfoDialog.guideButton.Text
            == Tr("使用说明")
            && supportInfoDialog.logButton.Text == Tr("运行日志")
            && supportInfoDialog.feedbackButton.Text == Tr("提交反馈")
            && !FindChildControlByText(supportInfoDialog.gui.Hwnd,
                Tr("请选择要打开的内容："))
            && SupportInfoWindow.FeedbackUrl
                == "https://github.com/realSilasYang/process-watchdog/issues?q=sort:updated-desc+is:issue+state:open+",
            language " 帮助信息窗口文本精简或反馈地址错误")
        supportInfoDialog.Close()

        donationDialog := DonationWindow(owner)
        donationDialog.Show()
        if previewDonation {
            ; 视觉预览解除测试所有者关系，便于截图工具单独定位捐赠窗口。
            DllCall("user32\SetWindowLongPtrW", "Ptr",
                donationDialog.gui.Hwnd, "Int", -8, "Ptr", 0, "Ptr")
            DllCall("user32\EnableWindow", "Ptr", owner.Hwnd, "Int", true)
            WinHide("ahk_id " owner.Hwnd)
            donationDialog.gui.Show("x0 y0")
            DllCall("user32\SetFocus", "Ptr", 0)
            WinSetAlwaysOnTop(1, "ahk_id " donationDialog.gui.Hwnd)
            WinActivate("ahk_id " donationDialog.gui.Hwnd)
            while donationDialog.IsOpen()
                Sleep(50)
            return
        }
        WinHide("ahk_id " donationDialog.gui.Hwnd)
        AssertWindowTitle(donationDialog.gui, Tr("支持开源项目"), language,
            "DonationWindow")
        AssertProductionWindowLayout(donationDialog.gui, language,
            "DonationWindow")
        AssertLocalizedWindow(donationDialog.qrPictures.Length == 2,
            language " 捐赠窗口没有加载两张二维码")
        AssertLocalizedWindow(donationDialog.qrLabels.Length == 2
            && donationDialog.messageText,
            language " 捐赠窗口缺少说明或支付方式标签")
        donationClientRect := GetWindowClientRect(donationDialog.gui.Hwnd)
        donationMessageRect := GetControlClientRect(
            donationDialog.messageText.Hwnd, donationDialog.gui.Hwnd)
        donationLabelRects := [
            GetControlClientRect(donationDialog.qrLabels[1].Hwnd,
                donationDialog.gui.Hwnd),
            GetControlClientRect(donationDialog.qrLabels[2].Hwnd,
                donationDialog.gui.Hwnd)
        ]
        donationPictureRects := [
            GetControlClientRect(donationDialog.qrPictures[1].Hwnd,
                donationDialog.gui.Hwnd),
            GetControlClientRect(donationDialog.qrPictures[2].Hwnd,
                donationDialog.gui.Hwnd)
        ]
        donationDpi := DllCall("user32\GetDpiForWindow", "Ptr",
            donationDialog.gui.Hwnd, "UInt")
        if !donationDpi
            donationDpi := 96
        expectedDonationQrSize := LocalizationService.UsesCompactLayout()
            ? 180 : 190
        measuredDonationMessageHeight := MeasureWrappedControlTextHeight(
            donationDialog.messageText.Hwnd,
            donationDialog.messageText.Text, donationMessageRect.Width)
        AssertLocalizedWindow(measuredDonationMessageHeight
                <= donationMessageRect.Height + 2
            && donationLabelRects[1].Top > donationMessageRect.Bottom
            && donationLabelRects[1].Top == donationLabelRects[2].Top
            && donationPictureRects[1].Top >= donationLabelRects[1].Bottom
                + Round(3 * donationDpi / 96)
            && donationPictureRects[1].Top <= donationLabelRects[1].Bottom
                + Round(8 * donationDpi / 96)
            && donationPictureRects[1].Top == donationPictureRects[2].Top
            && Abs(donationPictureRects[1].Width
                - Round(expectedDonationQrSize * donationDpi / 96)) <= 2
            && Abs(donationPictureRects[1].Height
                - Round(expectedDonationQrSize * donationDpi / 96)) <= 2
            && Abs(donationPictureRects[2].Width
                - donationPictureRects[1].Width) <= 1
            && donationClientRect.Height - donationPictureRects[1].Bottom
                >= Round(18 * donationDpi / 96)
            && donationClientRect.Height - donationPictureRects[1].Bottom
                <= Round(26 * donationDpi / 96),
            language " 捐赠窗口说明、标签、二维码或底部留白布局失衡")
        donationDialog.Close()

        tooltipDialog := DarkTooltipWindow()
        tooltipDialog.Show("First line`nSecond line`n")
        WinHide("ahk_id " tooltipDialog.gui.Hwnd)
        AssertLocalizedWindow(tooltipDialog.textControl.Text
            == "First line`nSecond line",
            language " 悬浮提示没有裁掉末尾空白行")
        tooltipDialog.Close()

        AssertLocalizedWindow(App.uiInteractions.Buttons.Count == 0
            && App.uiInteractions.TextInputs.Count == 0,
            language " 关闭所有窗口后仍保留交互注册")
    } finally {
        if tooltipDialog
            try tooltipDialog.Close()
        if donationDialog
            try donationDialog.Close()
        if batchLogNoticeDialog
            try batchLogNoticeDialog.Close()
        if supportInfoDialog
            try supportInfoDialog.Close()
        if logWindowInstance
            try logWindowInstance.Close()
        if helpDialog
            try helpDialog.Close()
        if maintenanceWindow
            try maintenanceWindow.Close()
        if environmentWindow
            try environmentWindow.Close()
        if customWindow
            try customWindow.Close()
        if addWindow
            try addWindow.Shutdown()
        if settingsDialog
            try settingsDialog.Close()
        if owner
            try owner.Destroy()
        try App.fileScanner.Shutdown()
        try App.processSnapshots.Shutdown()
        try App.guardRuntime.Shutdown()
        try App.iconResources.Shutdown()
        try App.svgRenderer.Shutdown()
        try ShutdownRoundedButtonRenderer()
    }
}

RunLocalizedWindowSmokeTests() {
    priorHiddenWindowMode := A_DetectHiddenWindows
    priorAutomationHidden := ApplicationWindowPresenter.AutomationHidden
    DetectHiddenWindows(true)
    ApplicationWindowPresenter.SetAutomationHidden(true)
    try {
        languages := LocalizationService.GetSupportedLanguageCodes()
        for languageIndex, language in languages
            RunOneLocalizedWindowPass(language, false, false, false,
                Mod(languageIndex, 2) ? "light" : "dark")
    } finally {
        ApplicationWindowPresenter.SetAutomationHidden(priorAutomationHidden)
        DetectHiddenWindows(priorHiddenWindowMode)
    }
    languageSummary := ""
    for languageIndex, language in LocalizationService.GetSupportedLanguageCodes()
        languageSummary .= (languageIndex > 1 ? "," : "") language
    FileAppend("LOCALIZED_WINDOW_SMOKE|PASS|languages=" languageSummary
        "`n", "*")
}

RunEnvironmentSettingsPreview() {
    priorHiddenWindowMode := A_DetectHiddenWindows
    DetectHiddenWindows(true)
    try RunOneLocalizedWindowPass("zh-CN", true, false, false, "dark")
    finally DetectHiddenWindows(priorHiddenWindowMode)
}

RunAboutSettingsPreview() {
    priorHiddenWindowMode := A_DetectHiddenWindows
    DetectHiddenWindows(true)
    OnMessage(Win32.WM_MEASUREITEM, OnMeasureApplicationControl)
    OnMessage(Win32.WM_DRAWITEM, OnDrawApplicationControl)
    try RunOneLocalizedWindowPass("zh-CN", false, true, false, "dark")
    finally {
        OnMessage(Win32.WM_MEASUREITEM, OnMeasureApplicationControl, 0)
        OnMessage(Win32.WM_DRAWITEM, OnDrawApplicationControl, 0)
        DetectHiddenWindows(priorHiddenWindowMode)
    }
}

RunDonationPreview(theme := "dark") {
    priorHiddenWindowMode := A_DetectHiddenWindows
    DetectHiddenWindows(true)
    try RunOneLocalizedWindowPass("zh-CN", false, false, true, theme)
    finally DetectHiddenWindows(priorHiddenWindowMode)
}
