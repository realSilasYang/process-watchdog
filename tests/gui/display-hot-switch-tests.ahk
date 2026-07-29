#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 在一个真实 GUI 进程内连续切换全部语言与内容字体，验证显示刷新不会替换
; 应用根状态、核心守护、目标控制器、主窗口或列表句柄，也不会累积原生资源。

try {
    RunDisplayHotSwitchTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.File "（" testError.Line "）："
        testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}

#Include ..\..\进程守护小助手.ahk

AssertDisplayHotSwitch(condition, message) {
    if !condition
        throw Error(message)
}

DisplayHotSwitchNoop(*) {
}

class DisplayHotSwitchStatusPaintProbe {
    static TargetHwnd := 0
    static PaintCount := 0
    static FurthestInvalidatedX := 0
    static CallbackPointer := 0

    static Install(hwnd) {
        this.TargetHwnd := hwnd
        this.PaintCount := 0
        this.FurthestInvalidatedX := 0
        this.CallbackPointer := CallbackCreate(ObjBindMethod(this,
            "WindowProc"),, 6)
        if !DllCall("comctl32\SetWindowSubclass", "Ptr", hwnd,
                "Ptr", this.CallbackPointer, "UPtr", 1, "UPtr", 0, "Int") {
            CallbackFree(this.CallbackPointer)
            this.CallbackPointer := 0
            throw Error("无法安装状态栏绘制探针")
        }
    }

    static Uninstall() {
        if this.TargetHwnd && this.CallbackPointer {
            DllCall("comctl32\RemoveWindowSubclass", "Ptr", this.TargetHwnd,
                "Ptr", this.CallbackPointer, "UPtr", 1, "Int")
            CallbackFree(this.CallbackPointer)
        }
        this.CallbackPointer := 0
        this.TargetHwnd := 0
    }

    static WindowProc(hwnd, message, wParam, lParam, subclassId, referenceData) {
        if hwnd == this.TargetHwnd && message == 0x000F { ; WM_PAINT：统计真实绘制请求
            this.PaintCount++
            updateRect := Buffer(16, 0)
            if DllCall("user32\GetUpdateRect", "Ptr", hwnd, "Ptr", updateRect,
                    "Int", 0, "Int") {
                this.FurthestInvalidatedX := Max(this.FurthestInvalidatedX,
                    NumGet(updateRect, 8, "Int"))
            }
        }
        return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd,
            "UInt", message, "UPtr", wParam, "Ptr", lParam, "Ptr")
    }
}

GetDisplayHotSwitchWindowText(hwnd) {
    length := DllCall("user32\GetWindowTextLengthW", "Ptr", hwnd, "Int")
    if length <= 0
        return ""
    textBuffer := Buffer((length + 1) * 2, 0)
    copied := DllCall("user32\GetWindowTextW", "Ptr", hwnd,
        "Ptr", textBuffer, "Int", length + 1, "Int")
    return copied > 0 ? StrGet(textBuffer, copied, "UTF-16") : ""
}

GetDisplayHotSwitchFontFace(hwnd) {
    fontHandle := SendMessage(Win32.WM_GETFONT, 0, 0, hwnd)
    if !fontHandle
        return ""
    logFont := Buffer(92, 0)
    if !DllCall("gdi32\GetObjectW", "Ptr", fontHandle, "Int",
            logFont.Size, "Ptr", logFont, "Int")
        return ""
    return StrGet(logFont.Ptr + 28, 32, "UTF-16")
}

GetDisplayHotSwitchFontWeight(hwnd) {
    fontHandle := SendMessage(Win32.WM_GETFONT, 0, 0, hwnd)
    if !fontHandle
        return 0
    logFont := Buffer(92, 0)
    if !DllCall("gdi32\GetObjectW", "Ptr", fontHandle, "Int",
            logFont.Size, "Ptr", logFont, "Int")
        return 0
    return NumGet(logFont, 16, "Int")
}

GetDisplayHotSwitchFontHeight(hwnd) {
    fontHandle := SendMessage(Win32.WM_GETFONT, 0, 0, hwnd)
    if !fontHandle
        return 0
    logFont := Buffer(92, 0)
    if !DllCall("gdi32\GetObjectW", "Ptr", fontHandle, "Int",
            logFont.Size, "Ptr", logFont, "Int")
        return 0
    return NumGet(logFont, 0, "Int")
}

GetDisplayHotSwitchResourceCount(kind) {
    processHandle := DllCall("kernel32\GetCurrentProcess", "Ptr")
    return DllCall("user32\GetGuiResources", "Ptr", processHandle,
        "UInt", kind, "UInt")
}

DisplayHotSwitchMenuHasItem(menuObj, itemName) {
    try {
        menuObj.Enable(itemName)
        return true
    } catch {
        return false
    }
}

class DisplayHotSwitchFailingRegistry {
    stopped := false

    Shutdown(*) {
        throw Error("模拟下级窗口注册表关闭失败")
    }
}

CreateDisplayHotSwitchMainWindow() {
    global Main
    Main := MainWindow()
    InitializeApplicationWindow(Main.gui)
    Main.gui.SetFont("s10 c" UiThemeService.Color("Text"),
        LocalizationService.GetUiFontName())
    Main.btnAdd := Main.gui.Add("Text",
        "x10 y15 w80 h30 Center 0x200 Background"
            UiThemeService.Color("Add") " c"
            UiThemeService.Color("ButtonText"),
        Tr("➕ 添加"))
    Main.btnPause := Main.gui.Add("Text",
        "x+10 y15 w80 h30 Center 0x200 Background"
            UiThemeService.Color("PauseDisabled") " c"
            UiThemeService.Color("DisabledButtonText"),
        Tr("⏸️ 暂停"))
    Main.btnDel := Main.gui.Add("Text",
        "x+10 y15 w80 h30 Center 0x200 Background"
            UiThemeService.Color("DeleteDisabled") " c"
            UiThemeService.Color("DisabledButtonText"),
        Tr("🗑️ 删除"))
    Main.settingsButtonWidth := 70
    Main.supportButtonWidth := 100
    Main.donateButtonWidth := 70
    Main.btnSet := Main.gui.Add("Text",
        "x480 y15 w70 h30 Center 0x200 Background"
            UiThemeService.Color("Toolbar") " c"
            UiThemeService.Color("ToolbarText"),
        Tr("设置"))
    Main.btnSupport := Main.gui.Add("Text",
        "x560 y15 w100 h30 Center 0x200 Background"
            UiThemeService.Color("Toolbar") " c"
            UiThemeService.Color("ToolbarText"),
        Tr("帮助信息"))
    Main.btnDonate := Main.gui.Add("Text",
        "x670 y15 w50 h30 Center 0x200 Background"
            UiThemeService.Color("Toolbar") " c"
            UiThemeService.Color("ToolbarText"),
        Tr("捐赠"))
    RegisterHoverButton(Main.btnAdd, UiThemeService.Color("Add"))
    SetButtonLeadingTextSlot(Main.btnAdd, 20, 4)
    RegisterHoverButton(Main.btnPause,
        UiThemeService.Color("PauseDisabled"),
        UiThemeService.Color("PauseDisabled"), "",
        UiThemeService.Color("DisabledButtonText"))
    SetButtonLeadingTextSlot(Main.btnPause, 20, 4)
    RegisterHoverButton(Main.btnDel,
        UiThemeService.Color("DeleteDisabled"),
        UiThemeService.Color("DeleteDisabled"), "",
        UiThemeService.Color("DisabledButtonText"))
    SetButtonLeadingTextSlot(Main.btnDel, 20, 4)
    RegisterHoverButton(Main.btnSet, UiThemeService.Color("Toolbar"))
    RegisterHoverButton(Main.btnSupport, UiThemeService.Color("Toolbar"))
    RegisterHoverButton(Main.btnDonate, UiThemeService.Color("Toolbar"))
    SetButtonLucideIcon(Main.btnSet, "settings.svg", 15, 6)
    SetButtonLucideIcon(Main.btnSupport, "circle-question-mark.svg", 15, 6)
    SetButtonLucideIcon(Main.btnDonate, "heart.svg", 15, 6)

    Main.gui.SetFont("s12 c" UiThemeService.Color("Text"),
        LocalizationService.GetUiFontName())
    Main.lv := Main.gui.Add("ListView",
        "x10 y60 w710 h390 Report +LV0x10002 -Hdr Background"
            UiThemeService.Color("Surface") " c"
            UiThemeService.Color("Text"),
        [Tr("守护对象"), Tr("状态"), Tr("完整路径"), Tr("序号"), ""])
    Main.lv.ModifyCol(1, 430)
    Main.lv.ModifyCol(2, 180)
    Main.lv.ModifyCol(3, 0)
    Main.lv.ModifyCol(4, "Center 48")
    Main.lv.ModifyCol(5, 0)
    Main.listProjection.ApplyColumnOrder(Main.lv)
    Main.gui.SetFont("s10 c" UiThemeService.Color("Text"),
        LocalizationService.GetUiFontName())
    Main.statsText := Main.gui.Add("Text",
        "x10 y460 w710 h20 c" UiThemeService.Color("MutedText")
            " Background" UiThemeService.Color("Window") " +0xD",
        Tr("载入中..."))
    Main.statsPresenter := SvgStatusBarPresenter(Main.statsText)
    Main.gui.Show("Hide w730 h520")
}

AssertMainCommandButtonLayout(clientWidth) {
    PositionMainCommandButtons(clientWidth)
    Main.btnPause.GetPos(&pauseX,, &pauseW)
    Main.btnDel.GetPos(&deleteX,, &deleteW)
    Main.btnSet.GetPos(&settingsX,, &settingsW)
    Main.btnSupport.GetPos(&supportX,, &supportW)
    Main.btnDonate.GetPos(&donateX,, &donateW)
    AssertDisplayHotSwitch(deleteX >= pauseX + pauseW,
        clientWidth " 宽度下暂停和删除按钮顺序或间距错误")
    AssertDisplayHotSwitch(settingsX >= deleteX + deleteW,
        clientWidth " 宽度下右侧按钮侵入左侧命令区")
    AssertDisplayHotSwitch(settingsX + settingsW <= supportX
        && supportX + supportW <= donateX,
        clientWidth " 宽度下右侧按钮互相重叠")
    AssertDisplayHotSwitch(donateX + donateW
        <= clientWidth - Main.commandButtonRightMargin,
        clientWidth " 宽度下右侧按钮超出客户区")
}

AssertMainCommandButtonSelectionState() {
    Main.lv.Modify(0, "-Select")
    RefreshMainCommandState(true)
    deleteState := App.uiInteractions.GetButton(Main.btnDel.Hwnd)
    pauseState := App.uiInteractions.GetButton(Main.btnPause.Hwnd)
    addState := App.uiInteractions.GetButton(Main.btnAdd.Hwnd)
    AssertDisplayHotSwitch(!addState.HasOwnProp("buttonImage")
        && !deleteState.HasOwnProp("buttonImage")
        && !pauseState.HasOwnProp("buttonImage")
        && addState.HasOwnProp("leadingTextSlotDip")
        && deleteState.HasOwnProp("leadingTextSlotDip")
        && pauseState.HasOwnProp("leadingTextSlotDip")
        && addState.leadingTextSlotDip == 20
        && deleteState.leadingTextSlotDip == 20
        && pauseState.leadingTextSlotDip == 20
        && addState.leadingTextGapDip == 4
        && deleteState.leadingTextGapDip == 4
        && pauseState.leadingTextGapDip == 4
        && pauseState.leadingTextVisualSizeDip == 10
        && Main.btnAdd.Text == Tr("➕ 添加")
        && Main.btnDel.Text == Tr("🗑️ 删除")
        && Main.btnPause.Text == Tr("⏸️ 暂停")
        && deleteState.normal
            == UiThemeService.Color("DeleteDisabled")
        && pauseState.normal == UiThemeService.Color("PauseDisabled")
        && deleteState.current == deleteState.normal
        && pauseState.current == pauseState.normal
        && !CanHoverButton(deleteState) && !CanHoverButton(pauseState),
        "无选择时删除／暂停按钮没有进入不可用状态")

    Main.lv.Modify(1, "Select Focus")
    RefreshMainCommandState(true)
    AssertDisplayHotSwitch(deleteState.normal == UiThemeService.Color("Delete")
        && pauseState.normal == UiThemeService.Color("Pause")
        && deleteState.current == deleteState.normal
        && pauseState.current == pauseState.normal
        && CanHoverButton(deleteState) && CanHoverButton(pauseState)
        && Main.btnPause.Text == Tr("⏸️ 暂停")
        && !deleteState.HasOwnProp("buttonImage")
        && !pauseState.HasOwnProp("buttonImage"),
        "选中守护对象后删除／暂停按钮没有恢复可用颜色和交互")

    selectedPath := Main.lv.GetText(1, 3)
    selectedState := App.appStates[selectedPath]
    selectedState.Enabled := 0
    RefreshMainCommandState(true)
    AssertDisplayHotSwitch(Main.btnPause.Text == Tr("▶️ 恢复")
        && !pauseState.HasOwnProp("buttonImage"),
        "暂停守护对象的恢复按钮没有切换为原有字符图标")
    mixedPath := A_Temp "\watchdog-mixed-button-state.exe"
    mixedRow := Main.lv.Add("", "Mixed State", Tr("初始化"), mixedPath,
        Main.lv.GetCount() + 1)
    App.appStates[mixedPath] := {Enabled: 1}
    Main.listProjection.Remember(mixedPath, mixedRow)
    try {
        Main.lv.Modify(mixedRow, "Select")
        RefreshMainCommandState(true)
        AssertDisplayHotSwitch(Main.btnPause.Text == Tr("🔄 反转状态")
            && !pauseState.HasOwnProp("buttonImage"),
            "混合选择的反转状态按钮没有切换为原有字符图标")
    } finally {
        App.appStates.Delete(mixedPath)
        Main.lv.Delete(mixedRow)
        Main.listProjection.Rebuild(Main.lv)
        selectedState.Enabled := 1
    }

    Main.lv.Modify(0, "-Select")
    RefreshMainCommandState(true)
    AssertDisplayHotSwitch(deleteState.normal
            == UiThemeService.Color("DeleteDisabled")
        && pauseState.normal == UiThemeService.Color("PauseDisabled")
        && deleteState.current == deleteState.normal
        && pauseState.current == pauseState.normal,
        "取消选择后删除／暂停按钮没有恢复不可用颜色")
}

AssertMainCommandButtonThemeState() {
    requestedTheme := UiThemeService.GetRequestedTheme()
    try {
        Main.lv.Modify(0, "-Select")
        for theme in ["dark", "light"] {
            UiThemeService.Configure(theme)
            ; 只调用生产代码的主题刷新入口，验证它自身承担命令状态同步。
            RefreshMainWindowTheme()
            deleteState := App.uiInteractions.GetButton(Main.btnDel.Hwnd)
            pauseState := App.uiInteractions.GetButton(Main.btnPause.Hwnd)
            AssertDisplayHotSwitch(deleteState.normal
                    == UiThemeService.Color("DeleteDisabled")
                && pauseState.normal == UiThemeService.Color("PauseDisabled")
                && deleteState.current == deleteState.normal
                && pauseState.current == pauseState.normal
                && deleteState.textColor
                    == UiThemeService.Color("DisabledButtonText")
                && pauseState.textColor
                    == UiThemeService.Color("DisabledButtonText"),
                theme " 主题刷新后无选择命令仍残留旧主题或可用配色")
        }
    } finally {
        UiThemeService.Configure(requestedTheme)
        RefreshMainWindowTheme()
    }
}

AssertPausedReloadResumeProjection() {
    targetPath := A_WinDir "\System32\cmd.exe"
    pausedStatus := GetGuardActivationStatus(false)
    initializingStatus := GetGuardActivationStatus(true)
    stateObj := TargetSupervisor({
        Enabled: 0,
        ; 模拟旧版本重载暂停守护对象时留下的内部／列表分裂状态。
        State: initializingStatus,
        Scheduler: App.scheduler,
        MaintenanceConfig: App.maintenanceConfigCodec.CreateDefault(targetPath),
        DisplayConfig: App.displayConfigCodec.CreateDefault()
    })
    stateObj.Pending := true
    stateObj.TargetStartTicks := GetTickCount64() + 5000
    stateObj.FailCount := 3
    stateObj.VerifyAttempts := 2
    stateObj.UncertainObservationCount := 2
    stateObj.StoppedEvidenceTicks := GetTickCount64()
    stateObj.ManualRestartRequested := true
    stateObj.IsRestarting := true

    App.appStates[targetPath] := stateObj
    App.appOrder.Push(targetPath)
    row := Main.lv.Add("", "Command Prompt",
        FormatMainStatusLabel(pausedStatus), targetPath, Main.lv.GetCount() + 1)
    Main.listProjection.Remember(targetPath, row)
    SetMainListStatus(row, pausedStatus)
    Main.lv.Modify(0, "-Select -Focus")
    Main.lv.Modify(row, "Select Focus")
    staleGeneration := stateObj.Generation
    try {
        ToggleItemPauseCore([targetPath])
        AssertDisplayHotSwitch(stateObj.Enabled
            && stateObj.Phase == GuardPhase.Initializing
            && stateObj.State == initializingStatus
            && stateObj.StatusKind == GuardStatusKind.Initializing
            && Main.lv.GetText(row, 2)
                == FormatMainStatusLabel(initializingStatus),
            "重载后的暂停守护对象恢复时，控制器、阶段和列表状态没有同步初始化")
        AssertDisplayHotSwitch(!stateObj.Pending
            && stateObj.TargetStartTicks == 0
            && stateObj.FailCount == 0
            && stateObj.VerifyAttempts == 0
            && stateObj.UncertainObservationCount == 0
            && stateObj.StoppedEvidenceTicks == 0
            && !stateObj.ManualRestartRequested
            && !stateObj.IsRestarting,
            "恢复守护后仍继承暂停前的倒计时、失败或验证证据")
        AssertDisplayHotSwitch(UpdateState(targetPath, "迟到的旧状态",
                stateObj, staleGeneration) == false
            && stateObj.State == initializingStatus
            && Main.lv.GetText(row, 2)
                == FormatMainStatusLabel(initializingStatus),
            "恢复守护推进代际后，迟到状态仍覆盖了初始化投影")
    } finally {
        try App.maintenanceCoordinator.CleanupTarget(targetPath, stateObj,
            false)
        if App.appStates.Has(targetPath)
            App.appStates.Delete(targetPath)
        RemoveAppOrderPath(targetPath)
        try Main.lv.Delete(row)
        Main.listProjection.Rebuild(Main.lv)
        Main.listProjection.RefreshSequence(Main.lv)
        RefreshMainStatusSortKeys()
        Main.lv.Modify(1, "Select Focus")
    }
}

GetDisplayHotSwitchMenuText(menuObj, position) {
    textBuffer := Buffer(1024, 0)
    copied := DllCall("user32\GetMenuStringW", "Ptr", menuObj.Handle,
        "UInt", position, "Ptr", textBuffer, "Int", 512,
        "UInt", 0x0400, "Int") ; MF_BYPOSITION：按菜单位置读取
    return copied > 0 ? StrGet(textBuffer, copied, "UTF-16") : ""
}

GetDisplayHotSwitchMenuStyle(menuObj) {
    structureSize := A_PtrSize == 8 ? 40 : 28
    menuInfo := Buffer(structureSize, 0)
    NumPut("UInt", structureSize, menuInfo, 0)
    NumPut("UInt", Win32.MIM_STYLE, menuInfo, 4)
    if !DllCall("user32\GetMenuInfo", "Ptr", menuObj.Handle,
            "Ptr", menuInfo, "Int")
        return 0
    return NumGet(menuInfo, 8, "UInt")
}

GetDisplayHotSwitchMenuItemType(menuObj, position) {
    structureSize := A_PtrSize == 8 ? 80 : 48
    itemInfo := Buffer(structureSize, 0)
    NumPut("UInt", structureSize, itemInfo, 0)
    NumPut("UInt", Win32.MIIM_FTYPE, itemInfo, 4)
    if !DllCall("user32\GetMenuItemInfoW", "Ptr", menuObj.Handle,
            "UInt", position, "Int", true, "Ptr", itemInfo, "Int")
        return 0
    return NumGet(itemInfo, 8, "UInt")
}

GetDisplayHotSwitchMenuItemId(menuObj, position) {
    return DllCall("user32\GetMenuItemID", "Ptr", menuObj.Handle,
        "Int", position, "UInt")
}

MeasureDisplayHotSwitchMenuItem(menuObj, position) {
    itemId := GetDisplayHotSwitchMenuItemId(menuObj, position)
    measureItem := Buffer(A_PtrSize == 8 ? 32 : 24, 0)
    NumPut("UInt", Win32.ODT_MENU, measureItem, 0)
    NumPut("UInt", itemId, measureItem, 8)
    result := OnMeasureApplicationControl(0, measureItem.Ptr,
        Win32.WM_MEASUREITEM, Main.gui.Hwnd)
    return {Result: result, Id: itemId,
        Width: NumGet(measureItem, 12, "UInt"),
        Height: NumGet(measureItem, 16, "UInt")}
}

DrawDisplayHotSwitchMenuItem(menuObj, position, itemState) {
    measurement := MeasureDisplayHotSwitchMenuItem(menuObj, position)
    screenDc := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
    memoryDc := DllCall("gdi32\CreateCompatibleDC", "Ptr", screenDc,
        "Ptr")
    bitmap := DllCall("gdi32\CreateCompatibleBitmap", "Ptr", screenDc,
        "Int", measurement.Width, "Int", measurement.Height, "Ptr")
    previousBitmap := bitmap ? DllCall("gdi32\SelectObject", "Ptr",
        memoryDc, "Ptr", bitmap, "Ptr") : 0
    try {
        if !screenDc || !memoryDc || !bitmap
            throw Error("无法建立右键菜单绘制探针")
        drawItem := Buffer(A_PtrSize == 8 ? 64 : 48, 0)
        itemHwndOffset := A_PtrSize == 8 ? 24 : 20
        hdcOffset := itemHwndOffset + A_PtrSize
        rectOffset := hdcOffset + A_PtrSize
        NumPut("UInt", Win32.ODT_MENU, drawItem, 0)
        NumPut("UInt", measurement.Id, drawItem, 8)
        NumPut("UInt", 1, drawItem, 12) ; ODA_DRAWENTIRE：要求完整绘制菜单项
        NumPut("UInt", itemState, drawItem, 16)
        NumPut("Ptr", menuObj.Handle, drawItem, itemHwndOffset)
        NumPut("Ptr", memoryDc, drawItem, hdcOffset)
        NumPut("Int", measurement.Width, drawItem, rectOffset + 8)
        NumPut("Int", measurement.Height, drawItem, rectOffset + 12)
        result := OnDrawApplicationControl(0, drawItem.Ptr,
            Win32.WM_DRAWITEM, Main.gui.Hwnd)
        dpi := DllCall("user32\GetDpiForWindow", "Ptr", Main.gui.Hwnd,
            "UInt")
        if !dpi
            dpi := 96
        backgroundProbeX := Max(1, measurement.Width
            - Round(12 * dpi / 96))
        return {Result: result,
            Background: DllCall("gdi32\GetPixel", "Ptr", memoryDc,
                "Int", backgroundProbeX,
                "Int", measurement.Height // 2, "UInt"),
            CornerBackground: DllCall("gdi32\GetPixel", "Ptr", memoryDc,
                "Int", 1, "Int", 1, "UInt")}
    } finally {
        if previousBitmap
            DllCall("gdi32\SelectObject", "Ptr", memoryDc,
                "Ptr", previousBitmap, "Ptr")
        if bitmap
            DllCall("gdi32\DeleteObject", "Ptr", bitmap)
        if memoryDc
            DllCall("gdi32\DeleteDC", "Ptr", memoryDc)
        if screenDc
            DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDc)
    }
}

AssertContextMenuPresentation() {
    itemCount := DllCall("user32\GetMenuItemCount", "Ptr",
        Main.contextMenu.Handle, "Int")
    ownerDrawCount := 0
    separatorPosition := -1
    Loop itemCount {
        itemType := GetDisplayHotSwitchMenuItemType(Main.contextMenu,
            A_Index - 1)
        if itemType & Win32.MFT_OWNERDRAW
            ownerDrawCount++
        if separatorPosition < 0 && itemType & Win32.MFT_SEPARATOR
            separatorPosition := A_Index - 1
    }
    normalMeasure := MeasureDisplayHotSwitchMenuItem(Main.contextMenu, 0)
    lastMeasure := MeasureDisplayHotSwitchMenuItem(Main.contextMenu,
        itemCount - 1)
    dpi := DllCall("user32\GetDpiForWindow", "Ptr", Main.gui.Hwnd,
        "UInt")
    if !dpi
        dpi := 96
    separatorPresentationValid := true
    if separatorPosition >= 0 {
        separatorMeasure := MeasureDisplayHotSwitchMenuItem(
            Main.contextMenu, separatorPosition)
        separatorPresentationValid := separatorMeasure.Result == 1
            && separatorMeasure.Height == Round(
                ContextMenuPresenter.SeparatorHeightDip * dpi / 96)
    }
    normalModel := ContextMenuPresenter.ItemsById[normalMeasure.Id]
    lastModel := ContextMenuPresenter.ItemsById[lastMeasure.Id]
    fontHandle := ContextMenuPresenter.GetFont(normalModel, dpi)
    fontInfo := Buffer(92, 0)
    fontHeight := DllCall("gdi32\GetObjectW", "Ptr", fontHandle,
        "Int", fontInfo.Size, "Ptr", fontInfo, "Int")
        ? Abs(NumGet(fontInfo, 0, "Int")) : 0
    normalDraw := DrawDisplayHotSwitchMenuItem(Main.contextMenu, 0, 0)
    selectedDraw := DrawDisplayHotSwitchMenuItem(Main.contextMenu, 0,
        Win32.ODS_SELECTED)
    outerPaddedItemHeight := Round((ContextMenuPresenter.ItemHeightDip
        + ContextMenuPresenter.OuterVerticalPaddingDip) * dpi / 96)
    AssertDisplayHotSwitch(ownerDrawCount == itemCount
        && normalMeasure.Result == 1
        && normalMeasure.Height >= outerPaddedItemHeight
        && lastMeasure.Result == 1
        && lastMeasure.Height >= outerPaddedItemHeight
        && normalModel.First && !normalModel.Last
        && lastModel.Last && !lastModel.First
        && separatorPresentationValid
        && fontHeight >= Round(
            ContextMenuPresenter.FontSizePt * dpi / 72) - 1
        && normalDraw.Result == 1 && selectedDraw.Result == 1
        && normalDraw.Background == RoundedButtonRenderer.ColorToBgr(
            UiThemeService.Color("Menu"))
        && selectedDraw.Background == RoundedButtonRenderer.ColorToBgr(
            UiThemeService.Color("MenuHover"))
        && selectedDraw.CornerBackground
            == RoundedButtonRenderer.ColorToBgr(UiThemeService.Color("Menu")),
        "右键菜单没有按当前 DPI 应用字号、行距或圆角主题悬浮色")

    popupRegion := ContextMenuPresenter.CreateRoundedWindowRegion(
        Round(220 * dpi / 96), Round(160 * dpi / 96), dpi)
    try AssertDisplayHotSwitch(ContextMenuPresenter.winEventHook
            && popupRegion
            && !DllCall("gdi32\PtInRegion", "Ptr", popupRegion,
                "Int", 0, "Int", 0, "Int")
            && DllCall("gdi32\PtInRegion", "Ptr", popupRegion,
                "Int", Round(110 * dpi / 96),
                "Int", Round(80 * dpi / 96), "Int"),
        "右键菜单没有安装弹出窗口监听或生成圆角窗口区域")
    finally {
        if popupRegion
            DllCall("gdi32\DeleteObject", "Ptr", popupRegion)
    }
    regionWindow := Gui("-Caption +ToolWindow")
    regionWindow.Show("Hide w220 h160")
    regionProbe := DllCall("gdi32\CreateRectRgn",
        "Int", 0, "Int", 0, "Int", 1, "Int", 1, "Ptr")
    try AssertDisplayHotSwitch(
        ContextMenuPresenter.ApplyRoundedPopupWindow(regionWindow.Hwnd)
            && DllCall("user32\GetWindowRgn", "Ptr", regionWindow.Hwnd,
                "Ptr", regionProbe, "Int") > 0
            && !DllCall("gdi32\PtInRegion", "Ptr", regionProbe,
                "Int", 0, "Int", 0, "Int"),
        "右键菜单圆角区域没有实际应用到原生窗口")
    finally {
        if regionProbe
            DllCall("gdi32\DeleteObject", "Ptr", regionProbe)
        regionWindow.Destroy()
    }
}

AssertContextMenuToggleLayout() {
    AssertDisplayHotSwitch(
        FormatContextMenuToggleLabel("开关", true) == "开关`t✓"
        && FormatContextMenuToggleLabel("开关", false) == "开关",
        "右键菜单开关状态没有使用最右侧快捷键栏")

    ConfigureMainContextMenu(true, true, true, true)
    contextMenuHandle := Main.contextMenu.Handle
    AssertDisplayHotSwitch(
        GetDisplayHotSwitchMenuStyle(Main.contextMenu) & Win32.MNS_NOCHECK
        && GetDisplayHotSwitchMenuText(Main.contextMenu, 3)
            == Tr("🎨 自定义名称和图标")
        && GetDisplayHotSwitchMenuText(Main.contextMenu, 4)
            == Tr("🛡️ 以管理员身份运行") "`t✓"
        && GetDisplayHotSwitchMenuText(Main.contextMenu, 6)
            == Tr("🔄 软件升级保护") "`t✓"
        && GetDisplayHotSwitchMenuText(Main.contextMenu, 8)
            == Tr("📄 查看批处理输出日志"),
        "右键菜单仍保留左侧勾选栏、勾号没有统一靠右或菜单仍含省略号")

    ConfigureMainContextMenu(false, false, false, false)
    maintenanceState := DllCall("user32\GetMenuState", "Ptr",
        Main.contextMenu.Handle, "UInt", 6, "UInt", 0x0400, "UInt")
    AssertDisplayHotSwitch(
        GetDisplayHotSwitchMenuText(Main.contextMenu, 4)
            == Tr("🛡️ 以管理员身份运行")
        && Main.contextMenu.Handle == contextMenuHandle
        && GetDisplayHotSwitchMenuText(Main.contextMenu, 6)
            == Tr("🔄 软件升级保护")
        && (maintenanceState & 0x0003)
        && DllCall("user32\GetMenuItemCount", "Ptr",
            Main.contextMenu.Handle, "Int") == 7,
        "非批处理守护对象仍显示输出日志，或关闭状态菜单没有正确刷新")
    ConfigureMainContextMenu(false, false, true, true)
    AssertContextMenuPresentation()
}

AssertMainStatusSemanticPriority() {
    expectedOrder := [
        GuardStatusKind.MaintenanceTimedOut,
        GuardStatusKind.PermissionMismatch,
        GuardStatusKind.TargetMissing,
        GuardStatusKind.ProgramMissing,
        GuardStatusKind.ScriptMissing,
        GuardStatusKind.SuspectedStop,
        GuardStatusKind.LaunchRetry,
        GuardStatusKind.CoolingDown,
        GuardStatusKind.RetryCountdown,
        GuardStatusKind.Unknown,
        GuardStatusKind.MaintenanceArbitrating,
        GuardStatusKind.MaintenanceUpdating,
        GuardStatusKind.MaintenanceFileWaiting,
        GuardStatusKind.MaintenanceStabilizing,
        GuardStatusKind.MaintenanceRecovering,
        GuardStatusKind.SafeStartWait,
        GuardStatusKind.WaitingObservation,
        GuardStatusKind.StartCountdown,
        GuardStatusKind.Starting,
        GuardStatusKind.Verifying,
        GuardStatusKind.Initializing,
        GuardStatusKind.Paused,
        GuardStatusKind.Running
    ]
    previousPriority := 0
    for statusKind in expectedOrder {
        priority := GetMainStatusSemanticPriority(statusKind)
        AssertDisplayHotSwitch(priority > previousPriority,
            "主列表状态语义优先级不严格递增：" statusKind)
        previousPriority := priority
    }
    firstNonAbnormalPriority := GetMainStatusSemanticPriority(
        GuardStatusKind.MaintenanceArbitrating)
    for abnormalKind in expectedOrder {
        if abnormalKind == GuardStatusKind.MaintenanceArbitrating
            break
        AssertDisplayHotSwitch(
            GetMainStatusSemanticPriority(abnormalKind)
                < firstNonAbnormalPriority,
            "主列表异常状态没有排在过渡或正常状态之前：" abnormalKind)
    }
}

AssertMainStatusSortKeyDirection(stateObj) {
    ascendingFirst := GetMainStatusSortKey(stateObj, 1, false)
    ascendingSecond := GetMainStatusSortKey(stateObj, 2, false)
    descendingFirst := GetMainStatusSortKey(stateObj, 1, true)
    descendingSecond := GetMainStatusSortKey(stateObj, 2, true)
    AssertDisplayHotSwitch(DllCall("shlwapi\StrCmpLogicalW", "Str",
            ascendingFirst, "Str", ascendingSecond, "Int") < 0,
        "状态升序键没有保留同组守护对象的自定义顺序")
    AssertDisplayHotSwitch(DllCall("shlwapi\StrCmpLogicalW", "Str",
            descendingFirst, "Str", descendingSecond, "Int") > 0,
        "状态降序键会反转同组守护对象的自定义顺序")
}

AssertMainStatusResizeRecovery() {
    originalText := Main.statsText.Text
    Main.gui.Show("Hide NoActivate w730 h520")
    Sleep(20)
    GuiResized(Main.gui, 0, 580, 300)
    Main.statsText.GetPos(&smallX, &smallY, &smallWidth, &smallHeight)
    DisplayHotSwitchStatusPaintProbe.Install(Main.statsText.Hwnd)
    try GuiResized(Main.gui, 0, 730, 520)
    finally DisplayHotSwitchStatusPaintProbe.Uninstall()
    Main.statsText.GetPos(&restoredX, &restoredY, &restoredWidth,
        &restoredHeight)
    clientRect := Buffer(16, 0)
    DllCall("user32\GetClientRect", "Ptr", Main.statsText.Hwnd,
        "Ptr", clientRect, "Int")
    restoredClientWidth := NumGet(clientRect, 8, "Int")
    AssertDisplayHotSwitch(smallX == 10 && smallY == 280
        && smallWidth == 560 && smallHeight == 20,
        "主状态栏缩小时没有跟随客户区")
    AssertDisplayHotSwitch(restoredX == 10 && restoredY == 500
        && restoredWidth == 710 && restoredHeight == 20
        && Main.statsText.Text == originalText,
        "主状态栏扩大后没有恢复完整宽度或原文本")
    AssertDisplayHotSwitch(DisplayHotSwitchStatusPaintProbe.PaintCount > 0
        && DisplayHotSwitchStatusPaintProbe.FurthestInvalidatedX
            >= restoredClientWidth,
        "主状态栏扩大后没有重绘到新控件区域的最右边：paint="
            DisplayHotSwitchStatusPaintProbe.PaintCount "，right="
            DisplayHotSwitchStatusPaintProbe.FurthestInvalidatedX
            "，width=" restoredClientWidth)
    AssertDisplayHotSwitch(Main.statsPresenter.items.Length == 7
        && Main.statsPresenter.items[1].IconPath
            == GetApplicationAssetPath(
                "ui-icons\lucide\circle-check-big.svg")
        && RegExMatch(Main.statsPresenter.items[1].Text, "^运行中：\d+$")
        && RegExMatch(Main.statsPresenter.items[2].Text, "^已暂停：\d+$")
        && RegExMatch(Main.statsPresenter.items[3].Text, "^已停止：\d+$")
        && RegExMatch(Main.statsPresenter.items[4].Text, "^恢复中：\d+$")
        && RegExMatch(Main.statsPresenter.items[5].Text, "^升级中：\d+$")
        && RegExMatch(Main.statsPresenter.items[6].Text, "^已失效：\d+$")
        && Main.statsPresenter.items[2].IconPath
            == GetApplicationAssetPath(
                "ui-icons\lucide\circle-pause.svg")
        && Main.statsPresenter.items[7].SeparatorBefore
        && !RegExMatch(Main.statsText.Text,
            "[✅🚫⏳🔄⏸❌🎯]"),
        "主状态栏的七组 SVG、语义措辞、顺序或 Emoji 清理不正确")
    Main.gui.Hide()
}

CreateDisplayHotSwitchState(path) {
    stateObj := TargetSupervisor({
        State: Tr("⏳ 重试倒计时 {1} 秒", 7),
        StatusKind: GuardStatusKind.RetryCountdown,
        Scheduler: App.scheduler,
        MaintenanceConfig: App.maintenanceConfigCodec.CreateDefault(path),
        DisplayConfig: App.displayConfigCodec.CreateDefault()
    })
    stateObj.Pending := true
    stateObj.FailCount := 1
    stateObj.TargetStartTicks := GetTickCount64() + 7000
    stateObj.TransitionTo(GuardPhase.WaitingRestart)
    stateObj.Generation := 17
    return stateObj
}

AssertDisplayHotSwitchIdentity(expected) {
    AssertDisplayHotSwitch(App == expected.App,
        "热切换替换了应用根状态")
    AssertDisplayHotSwitch(App.guardRuntime == expected.GuardRuntime
        && App.guardRuntime.Running && !App.guardRuntime.Stopped,
        "热切换停止或替换了核心守护运行时")
    AssertDisplayHotSwitch(App.scheduler == expected.Scheduler,
        "热切换替换了调度器")
    AssertDisplayHotSwitch(Main.gui.Hwnd == expected.MainHwnd
        && Main.lv.Hwnd == expected.ListHwnd
        && Main.contextMenu.Handle == expected.ContextMenuHwnd,
        "热切换重建了主窗口、ListView 或右键菜单")
    AssertDisplayHotSwitch(App.appStates[expected.Path] == expected.State
        && expected.State.Generation == expected.Generation,
        "热切换替换了目标控制器或改变了代际")
    AssertDisplayHotSwitch(
        DllCall("kernel32\GetCurrentProcessId", "UInt") == expected.Pid,
        "热切换改变了进程")
}

SelectDisplayHotSwitchDropDownValue(dropDown, values, expectedValue) {
    for valueIndex, value in values {
        if StrLower(value) == StrLower(expectedValue) {
            dropDown.Value := valueIndex
            return true
        }
    }
    return false
}

RunDisplayHotSwitchTests() {
    global App, Main, GuiModules

    LocalizationService.Configure("zh-CN")
    LocalizationService.ConfigureUiFont("auto")
    UiThemeService.Configure("dark")
    ApplicationWindowPresenter.SetAutomationHidden(true)
    App := ApplicationState()
    processId := DllCall("kernel32\GetCurrentProcessId", "UInt")
    configPath := A_Temp "\watchdog-display-hot-switch-" processId ".ini"
    try FileDelete(configPath)
    repository := WatchdogConfigRepository(configPath, "", Tr,
        LocalizationService.GetAllTranslationCatalogs())
    repository.ReplaceSections([{Name: "Settings", Entries: [
        {Key: "UiLanguage", Value: "zh-CN"},
        {Key: "UiFont", Value: "auto"}
    ]}])
    App.SetConfigRepository(repository)

    ManagedWindow.ConfigureLifecycle(ManagedWindowLifecycle({
        RestoreInteractions: RestoreHoveredButton,
        HideTransientWindows: DisplayHotSwitchNoop,
        UnregisterControls: UnregisterGuiControls,
        ReleaseIcons: ReleaseWindowIcons
    }, WindowHierarchy))
    OnMessage(Win32.WM_MEASUREITEM, OnMeasureApplicationControl)
    OnMessage(Win32.WM_DRAWITEM, OnDrawApplicationControl)
    CreateDisplayHotSwitchMainWindow()
    GuiModules := GuiModuleRegistry(Main.gui)

    targetPath := A_WinDir "\System32\notepad.exe"
    stateObj := CreateDisplayHotSwitchState(targetPath)
    App.appStates[targetPath] := stateObj
    App.appOrder.Push(targetPath)
    row := Main.lv.Add("", "Notepad", stateObj.State, targetPath, 1, "")
    SetMainListStatus(row, stateObj.State)
    Main.listProjection.Rebuild(Main.lv)
    AssertMainStatusSemanticPriority()
    AssertMainStatusSortKeyDirection(stateObj)
    AssertPausedReloadResumeProjection()
    AssertMainCommandButtonSelectionState()
    AssertMainCommandButtonThemeState()
    Main.contextTargetRow := 1
    App.guardRuntime.Running := true
    App.guardRuntime.Stopped := false
    AssertContextMenuToggleLayout()
    ConfigureTrayMenu()
    UpdateStatsUI()
    AssertMainStatusResizeRecovery()

    expected := {
        App: App,
        GuardRuntime: App.guardRuntime,
        Scheduler: App.scheduler,
        MainHwnd: Main.gui.Hwnd,
        ListHwnd: Main.lv.Hwnd,
        ContextMenuHwnd: Main.contextMenu.Handle,
        State: stateObj,
        Generation: stateObj.Generation,
        Path: targetPath,
        Pid: processId
    }

    try {
        ; 首次切换走用户真实路径：打开“设置”、选择语言和字体并保存。
        ; 保存会销毁旧设置窗口，但不得重启脚本或替换任何长期守护对象。
        settingsDialogInstance := GuiModules.settings
        settingsDialogInstance.Show()
        AssertDisplayHotSwitch(SelectDisplayHotSwitchDropDownValue(
            settingsDialogInstance.languageDropDown,
            settingsDialogInstance.languageCodes,
            "en-US"), "设置窗口缺少英语选项")
        AssertDisplayHotSwitch(SelectDisplayHotSwitchDropDownValue(
            settingsDialogInstance.fontDropDown,
            settingsDialogInstance.fontValues,
            "Segoe UI"), "设置窗口缺少 Segoe UI 字体")
        settingsDialogInstance.Save()
        ; 设置保存通过守护工作门异步串行执行；测试显式排空队列后再核对事务结果。
        App.guardMutationQueue.Drain()
        AssertDisplayHotSwitchIdentity(expected)
        AssertDisplayHotSwitch(LocalizationService.GetLanguage() == "en-US"
            && App.uiLanguage == "en-US" && App.uiFont == "Segoe UI",
            "英语和显式字体没有写入当前运行态")
        AssertDisplayHotSwitch(GetDisplayHotSwitchWindowText(Main.gui.Hwnd)
            == "Process Watchdog Assistant",
            "主窗口标题没有立即切换为英文")
        AssertDisplayHotSwitch(Main.btnSet.Text == "Settings"
            && A_TrayMenu.Default == "Show Main Window"
            && DisplayHotSwitchMenuHasItem(Main.contextMenu,
                "📂 Open File Location"),
            "主按钮、托盘或右键菜单没有立即切换为英文")
        AssertDisplayHotSwitch(stateObj.State == "⏳ Retry in 7 seconds"
            && stateObj.StatusKind == GuardStatusKind.RetryCountdown
            && Main.lv.GetText(1, 2) == "Retry in 7 seconds",
            "动态状态、细粒度图标键或列表投影没有立即切换为英文")
        AssertDisplayHotSwitch(
            GetDisplayHotSwitchFontFace(Main.btnSet.Hwnd) == "Segoe UI"
            && GetDisplayHotSwitchFontWeight(Main.btnSet.Hwnd) >= 700
            && GetDisplayHotSwitchFontFace(Main.statsText.Hwnd) == "Segoe UI"
            && GetDisplayHotSwitchFontWeight(Main.statsText.Hwnd) >= 700
            && GetDisplayHotSwitchFontFace(Main.lv.Hwnd) == "Segoe UI",
            "显式字体没有应用到既有主窗口控件")
        englishIni := FileRead(configPath, "UTF-16")
        AssertDisplayHotSwitch(InStr(englishIni,
            "; UiLanguage: interface language")
            && !InStr(englishIni, "; UiLanguage：界面语言"),
            "热切换后没有用新语言重写 INI 就地注释")

        ; 连续缩窄和放宽窗口，覆盖截图中的自绘按钮旧区域残留场景。
        for clientWidth in [730, 580, 900, 620, 730]
            AssertMainCommandButtonLayout(clientWidth)

        languages := LocalizationService.GetSupportedLanguageCodes()
        ; 第一轮预热每种源语言的模板缓存和控件字体，资源基线从预热后开始。
        for language in languages {
            ApplyDisplaySettingsHot(language, "auto")
            AssertContextMenuPresentation()
        }
        baselineGdi := GetDisplayHotSwitchResourceCount(0)
        baselineUser := GetDisplayHotSwitchResourceCount(1)
        Loop 3 {
            for language in languages {
                ApplyDisplaySettingsHot(language, "auto")
                AssertContextMenuPresentation()
                AssertDisplayHotSwitchIdentity(expected)
                AssertDisplayHotSwitch(LocalizationService.GetLanguage()
                    == language
                    && GetDisplayHotSwitchWindowText(Main.gui.Hwnd)
                        == Tr("进程守护小助手")
                    && GetDisplayHotSwitchFontFace(Main.btnSet.Hwnd)
                        == LocalizationService.GetLanguageSystemUiFontName()
                    && GetDisplayHotSwitchFontWeight(Main.btnSet.Hwnd) >= 700
                    && GetDisplayHotSwitchFontFace(Main.statsText.Hwnd)
                        == LocalizationService.GetLanguageSystemUiFontName()
                    && GetDisplayHotSwitchFontWeight(Main.statsText.Hwnd) >= 700
                    && GetDisplayHotSwitchFontFace(Main.lv.Hwnd)
                        == LocalizationService.GetUiFontName()
                    && Abs(GetDisplayHotSwitchFontHeight(Main.btnSet.Hwnd))
                        == Abs(GetDisplayHotSwitchFontHeight(
                            Main.statsText.Hwnd))
                    && Abs(GetDisplayHotSwitchFontHeight(Main.btnSet.Hwnd))
                        < Abs(GetDisplayHotSwitchFontHeight(Main.lv.Hwnd))
                    && stateObj.State
                        == Tr("⏳ 重试倒计时 {1} 秒", 7)
                    && Main.lv.GetText(1, 2)
                        == FormatMainStatusLabel(stateObj.State),
                language " 热切换后的标题、字体或动态状态不正确")
            }
        }
        ; 真实控件再走一次随包内容字体路径：ListView 必须应用 Noto，按钮和状态栏
        ; 则继续使用当前语言的系统 UI 字体粗体。
        ApplyDisplaySettingsHot("ja-JP", "Noto Sans CJK JP")
        AssertDisplayHotSwitch(LocalizationService.GetRequestedUiFont()
            == "Noto Sans CJK JP"
            && GetDisplayHotSwitchFontFace(Main.btnSet.Hwnd)
                == LocalizationService.GetLanguageSystemUiFontName()
            && GetDisplayHotSwitchFontWeight(Main.btnSet.Hwnd) >= 700
            && GetDisplayHotSwitchFontFace(Main.statsText.Hwnd)
                == LocalizationService.GetLanguageSystemUiFontName()
            && GetDisplayHotSwitchFontWeight(Main.statsText.Hwnd) >= 700
            && GetDisplayHotSwitchFontFace(Main.lv.Hwnd)
                == "Noto Sans CJK JP",
            "内容字体和系统强调字体没有保持独立")
        ApplyDisplaySettingsHot("ja-JP", "auto")
        ; 注入注册表关闭异常，验证已经改写的语言、字体和状态会完整回滚。
        stableRegistry := GuiModules
        rollbackLanguage := LocalizationService.GetLanguage()
        rollbackRequestedLanguage := LocalizationService
            .GetRequestedLanguage()
        rollbackRequestedFont := LocalizationService.GetRequestedUiFont()
        rollbackFont := LocalizationService.GetUiFontName()
        rollbackStateText := stateObj.State
        GuiModules := DisplayHotSwitchFailingRegistry()
        rollbackObserved := false
        try ApplyDisplaySettingsHot("zh-CN", "Segoe UI")
        catch
            rollbackObserved := true
        finally GuiModules := stableRegistry
        AssertDisplayHotSwitch(rollbackObserved
            && LocalizationService.GetLanguage() == rollbackLanguage
            && LocalizationService.GetRequestedLanguage()
                == rollbackRequestedLanguage
            && LocalizationService.GetRequestedUiFont()
                == rollbackRequestedFont
            && LocalizationService.GetUiFontName() == rollbackFont
            && stateObj.State == rollbackStateText
            && GetDisplayHotSwitchWindowText(Main.gui.Hwnd)
                == Tr("进程守护小助手"),
            "显示热切换异常后没有完整恢复原语言、字体和状态")
        AssertDisplayHotSwitchIdentity(expected)
        finalGdi := GetDisplayHotSwitchResourceCount(0)
        finalUser := GetDisplayHotSwitchResourceCount(1)
        AssertDisplayHotSwitch(finalGdi - baselineGdi <= 8
            && finalUser - baselineUser <= 8,
            "连续热切换后原生资源持续增长：GDI="
                (finalGdi - baselineGdi) "，USER="
                (finalUser - baselineUser))
        FileAppend("DISPLAY_HOT_SWITCH|PASS|languages=" languages.Length
            "|gdiDelta=" (finalGdi - baselineGdi)
            "|userDelta=" (finalUser - baselineUser) "`n", "*")
    } finally {
        App.guardRuntime.Running := false
        try GuiModules.Shutdown()
        try UnregisterGuiControls(Main.gui.Hwnd)
        try Main.gui.Destroy()
        try App.guardRuntime.Shutdown()
        try App.applicationUpdateService.Shutdown()
        try App.svgRenderer.Shutdown()
        try ShutdownContextMenuPresenter()
        try ShutdownRoundedButtonRenderer()
        try OnMessage(Win32.WM_MEASUREITEM,
            OnMeasureApplicationControl, 0)
        try OnMessage(Win32.WM_DRAWITEM, OnDrawApplicationControl, 0)
        try FileDelete(configPath)
    }
}
