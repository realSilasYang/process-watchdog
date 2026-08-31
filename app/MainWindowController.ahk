; 主窗口交互控制器。
; 这里集中处理显示、隐藏、缩放、右键菜单和系统通知回流；MainWindow 只持有
; 长期控件状态，入口脚本只负责装配事件与启动顺序。

OnMainGuiClose(*) {
    HideMainGui()
}

HideMainGui(force := false) {
    if IsSet(Main) && IsObject(Main.contextPopup)
        try Main.contextPopup.Hide()
    if !force && WindowHierarchy.IsOwnerLocked(Main.gui) {
        WindowHierarchy.ActivateTopOwned(Main.gui)
        return false
    }
    if IsSet(GuiModules)
        GuiModules.HideTransientWindows()
    Main.gui.GetClientPos(,, &gW, &gH)
    if (gW > 0 && gH > 0) {
        try {
            c1 := SendMessage(Win32.LVM_GETCOLUMNWIDTH, 0, 0,
                Main.lv.Hwnd)
            c2 := SendMessage(Win32.LVM_GETCOLUMNWIDTH, 1, 0,
                Main.lv.Hwnd)
            windowDpi := DllCall("user32\GetDpiForWindow", "Ptr",
                Main.gui.Hwnd, "UInt")
            dpiScale := (windowDpi ? windowDpi : 96) / 96
            savedLayout := App.windowLayoutService.Save({
                Width: UiScaleService.Unscale(gW),
                Height: UiScaleService.Unscale(gH),
                Column1: UiScaleService.Unscale(c1 / dpiScale),
                Column2: UiScaleService.Unscale(c2 / dpiScale)
            })
            ; Hide 是运行态布局的提交边界；恢复前不能继续持有旧尺寸，
            ; 否则托盘恢复会重新使用过期的窗口大小。
            App.windowLayoutService.Apply(App, savedLayout)
        } catch as layoutErr {
            LogMsg(Tr("保存窗口布局失败：{1}",
                TrDiagnostic(layoutErr.Message)))
        }
    }
    Main.gui.Hide()
    return true
}

LayoutMainListHeader(clientWidth) {
    if !Main.HasOwnProp("listHeader") || !IsObject(Main.listHeader)
        return false
    try {
        ; LVM_GETCOLUMNWIDTH 返回物理像素，而 GuiControl.Move 使用经 DPI
        ; 缩放前的逻辑尺寸。先换算一次，避免高 DPI 下伪表头宽度被重复放大。
        windowDpi := DllCall("user32\GetDpiForWindow", "Ptr",
            Main.gui.Hwnd, "UInt")
        dpiScale := (windowDpi ? windowDpi : 96) / 96
        sequenceWidth := Round(SendMessage(Win32.LVM_GETCOLUMNWIDTH, 3, 0,
            Main.lv.Hwnd) / dpiScale)
        nameWidth := Round(SendMessage(Win32.LVM_GETCOLUMNWIDTH, 0, 0,
            Main.lv.Hwnd) / dpiScale)
        statusWidth := Round(SendMessage(Win32.LVM_GETCOLUMNWIDTH, 1, 0,
            Main.lv.Hwnd) / dpiScale)
        if IsSet(UiScaleService)
            Main.listHeader.Height := UiScaleService.Scale(
                ListViewPseudoHeader.DefaultHeight)
        return Main.listHeader.SetBounds(UiScaleService.Scale(10),
            UiScaleService.Scale(60),
            [sequenceWidth, nameWidth, statusWidth],
            Max(0, clientWidth - UiScaleService.Scale(20)))
    } catch {
        return false
    }
}

OnMainListTemporarySortChanged(header, column, descending) {
    Main.contextTargetRow := 0
    Main.listProjection.Rebuild(Main.lv)
}

PrepareMainListTemporarySort(header, column, descending) {
    if column == 5
        RefreshMainStatusSortKeys(descending, false)
}

ScheduleMainListTemporarySortRefresh(changedColumn := 0) {
    if !Main.HasOwnProp("listHeader") || !IsObject(Main.listHeader)
        || !Main.listHeader.HasActiveSort()
        return false
    if changedColumn && Main.listHeader.GetSortColumn() != changedColumn
        return false
    SetTimer(ApplyMainListTemporarySort, -1)
    return true
}

ApplyMainListTemporarySort(*) {
    if !Main.HasOwnProp("listHeader") || !IsObject(Main.listHeader)
        || !Main.listHeader.HasActiveSort()
        return false
    Main.lv.Opt("-Redraw")
    try {
        Main.listHeader.ApplyCurrentSort()
        Main.listProjection.Rebuild(Main.lv)
    } finally Main.lv.Opt("+Redraw")
    return true
}

ClearMainListTemporarySort() {
    SetTimer(ApplyMainListTemporarySort, 0)
    if Main.HasOwnProp("listHeader") && IsObject(Main.listHeader)
        Main.listHeader.ClearSort()
}

PositionMainCommandButtons(clientWidth) {
    positions := GetMainCommandButtonPositions(clientWidth, true)
    result := AtomicControlLayout.Apply(Main.gui, [
        {Control: Main.btnAdd, X: UiScaleService.Scale(10),
            Y: UiScaleService.Scale(15),
            Width: UiScaleService.Scale(80), Height: UiScaleService.Scale(30)},
        {Control: Main.btnPause, X: UiScaleService.Scale(100),
            Y: UiScaleService.Scale(15),
            Width: UiScaleService.Scale(80), Height: UiScaleService.Scale(30)},
        {Control: Main.btnDel, X: UiScaleService.Scale(190),
            Y: UiScaleService.Scale(15),
            Width: UiScaleService.Scale(80), Height: UiScaleService.Scale(30)},
        {Control: Main.btnSet, X: positions.Settings,
            Y: UiScaleService.Scale(15),
            Width: UiScaleService.Scale(Main.settingsButtonWidth),
            Height: UiScaleService.Scale(30)},
        {Control: Main.btnSupport, X: positions.Support,
            Y: UiScaleService.Scale(15),
            Width: UiScaleService.Scale(Main.supportButtonWidth),
            Height: UiScaleService.Scale(30)},
        {Control: Main.btnAbout, X: positions.About,
            Y: UiScaleService.Scale(15),
            Width: UiScaleService.Scale(Main.aboutButtonWidth),
            Height: UiScaleService.Scale(30)}
    ], {ParentColor: UiThemeService.Color("Window"), ClearMargin: 2})
    return result.Status == AtomicControlLayout.Applied
        || result.Status == AtomicControlLayout.Unchanged
}

SuspendMainListResizeRedraw() {
    hwnd := Main.lv.Hwnd
    if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
        || !DllCall("user32\IsWindowVisible", "Ptr", hwnd, "Int")
        return false
    DllCall("user32\SendMessageW", "Ptr", hwnd,
        "UInt", Win32.WM_SETREDRAW, "Ptr", false, "Ptr", 0, "Ptr")
    return true
}

ResumeMainListResizeRedraw(suspended) {
    if !suspended
        return false
    hwnd := Main.lv.Hwnd
    if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
        return false
    DllCall("user32\SendMessageW", "Ptr", hwnd,
        "UInt", Win32.WM_SETREDRAW, "Ptr", true, "Ptr", 0, "Ptr")
    ; ListView 已启用 LVS_EX_DOUBLEBUFFER；一次同步刷新只会提交最终列布局。
    return DllCall("user32\RedrawWindow", "Ptr", hwnd, "Ptr", 0,
        "Ptr", 0, "UInt", Win32.RDW_CONTROL_REFRESH, "Int") != 0
}

InitializeMainListSmoothScroll() {
    if !IsSet(Main) || !IsObject(Main.lv) || !Main.lv.Hwnd
        return false
    if !Main.listWheelRegistered {
        Main.listWheelCallback := HandleMainListMouseWheel
        OnMessage(Win32.WM_MOUSEWHEEL, Main.listWheelCallback)
        Main.listWheelRegistered := true
    }
    if Main.listWheelSubclassAttached
        return true
    Main.listWheelSubclassCallback := CallbackCreate(
        MainListWheelSubclassProc, "", 6)
    attached := !!DllCall("comctl32\SetWindowSubclass", "Ptr",
        Main.lv.Hwnd, "Ptr", Main.listWheelSubclassCallback,
        "UPtr", MainWindow.ListWheelSubclassId, "UPtr", 0, "Int")
    if attached {
        Main.listWheelSubclassAttached := true
        return true
    }
    CallbackFree(Main.listWheelSubclassCallback)
    Main.listWheelSubclassCallback := 0
    return false
}

MainListWheelSubclassProc(hwnd, message, wParam, lParam, subclassId,
        referenceData) {
    try {
        if message == Win32.WM_MOUSEWHEEL && !Main.listDragActive {
            ProcessMainListWheelDelta(SignedMainListWord(wParam >> 16))
            return 0
        }
        if message == Win32.WM_LBUTTONDOWN
                || message == Win32.WM_KEYDOWN
            StopMainListSmoothScroll(true)
        if message == Win32.WM_NCDESTROY
            Main.listWheelSubclassAttached := false
    } catch {
        ; 原生回调边界不得接收 AHK 异常。
    }
    return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd,
        "UInt", message, "UPtr", wParam, "Ptr", lParam, "Ptr")
}

ShutdownMainListSmoothScroll() {
    if !IsSet(Main)
        return false
    StopMainListSmoothScroll(true)
    if Main.listWheelRegistered {
        try OnMessage(Win32.WM_MOUSEWHEEL, Main.listWheelCallback, 0)
        Main.listWheelRegistered := false
        Main.listWheelCallback := 0
    }
    if Main.listWheelSubclassAttached && Main.lv && Main.lv.Hwnd
            && DllCall("user32\IsWindow", "Ptr", Main.lv.Hwnd, "Int") {
        DllCall("comctl32\RemoveWindowSubclass", "Ptr", Main.lv.Hwnd,
            "Ptr", Main.listWheelSubclassCallback, "UPtr",
            MainWindow.ListWheelSubclassId, "Int")
    }
    Main.listWheelSubclassAttached := false
    if Main.listWheelSubclassCallback {
        CallbackFree(Main.listWheelSubclassCallback)
        Main.listWheelSubclassCallback := 0
    }
    return true
}

HandleMainListMouseWheel(wParam, lParam, msg, hwnd) {
    if !IsSet(Main) || Main.listDragActive
            || !IsMainListScreenPoint(lParam, hwnd)
        return
    return ProcessMainListWheelDelta(SignedMainListWord(wParam >> 16))
}

IsMainListScreenPoint(lParam, messageHwnd := 0) {
    if !IsSet(Main) || !IsObject(Main.lv) || !Main.lv.Hwnd
            || !DllCall("user32\IsWindow", "Ptr", Main.lv.Hwnd, "Int")
        return false
    screenX := SignedMainListWord(lParam)
    screenY := SignedMainListWord(lParam >> 16)
    if messageHwnd {
        listRoot := DllCall("user32\GetAncestor", "Ptr", Main.lv.Hwnd,
            "UInt", 2, "Ptr") ; 根窗口
        messageRoot := DllCall("user32\GetAncestor", "Ptr", messageHwnd,
            "UInt", 2, "Ptr")
        if !listRoot || messageRoot != listRoot
            return false
        point := (screenY << 32) | (screenX & 0xFFFFFFFF)
        pointHwnd := DllCall("user32\WindowFromPoint", "Int64", point,
            "Ptr")
        pointRoot := pointHwnd ? DllCall("user32\GetAncestor", "Ptr",
            pointHwnd, "UInt", 2, "Ptr") : 0
        if pointRoot && pointRoot != listRoot
            return false
    }
    if messageHwnd == Main.lv.Hwnd && !lParam
        return true
    rect := Buffer(16, 0)
    if !DllCall("user32\GetWindowRect", "Ptr", Main.lv.Hwnd,
            "Ptr", rect, "Int")
        return false
    return screenX >= NumGet(rect, 0, "Int")
        && screenX < NumGet(rect, 8, "Int")
        && screenY >= NumGet(rect, 4, "Int")
        && screenY < NumGet(rect, 12, "Int")
}

ProcessMainListWheelDelta(wheelDelta) {
    if !wheelDelta
        return 0
    scrollLines := GetMainListSystemWheelScrollLines()
    if !scrollLines {
        StopMainListSmoothScroll(true)
        return 0
    }
    if Main.listWheelDeltaRemainder
            && (Main.listWheelDeltaRemainder > 0) != (wheelDelta > 0)
        Main.listWheelDeltaRemainder := 0
    Main.listWheelDeltaRemainder += wheelDelta
    wheelNotches := Main.listWheelDeltaRemainder > 0
        ? Floor(Main.listWheelDeltaRemainder / MainWindow.WheelDelta)
        : Ceil(Main.listWheelDeltaRemainder / MainWindow.WheelDelta)
    if wheelNotches {
        Main.listWheelDeltaRemainder -= wheelNotches
            * MainWindow.WheelDelta
        QueueMainListSmoothScroll(-wheelNotches * scrollLines)
    }
    return 0
}

GetMainListSystemWheelScrollLines() {
    scrollLines := 0
    if !DllCall("user32\SystemParametersInfoW", "UInt", 0x0068,
            "UInt", 0, "UInt*", &scrollLines, "UInt", 0, "Int")
        return 3
    if scrollLines != 0xFFFFFFFF
        return Max(0, Integer(scrollLines))
    clientRect := Buffer(16, 0)
    if !DllCall("user32\GetClientRect", "Ptr", Main.lv.Hwnd,
            "Ptr", clientRect, "Int")
        return 1
    clientHeight := NumGet(clientRect, 12, "Int")
    visibleLines := Floor(clientHeight / GetMainListRowHeightPixels())
    return Max(1, visibleLines - 1)
}

GetMainListRowHeightPixels() {
    if Main.lv.GetCount() > 0 {
        rowRect := Buffer(16, 0)
        NumPut("Int", 0, rowRect, 0)
        if SendMessage(Win32.LVM_GETITEMRECT, 0, rowRect.Ptr,
                Main.lv.Hwnd) {
            height := NumGet(rowRect, 12, "Int")
                - NumGet(rowRect, 4, "Int")
            if height > 0
                return height
        }
    }
    dpi := DllCall("user32\GetDpiForWindow", "Ptr", Main.lv.Hwnd, "UInt")
    return Max(20, Round(28 * (dpi ? dpi : 96) / 96))
}

GetMainListHeightSnapDeltaPixels() {
    clientRect := Buffer(16, 0)
    if !DllCall("user32\GetClientRect", "Ptr", Main.lv.Hwnd,
            "Ptr", clientRect, "Int")
        return 0
    clientHeight := NumGet(clientRect, 12, "Int")
    rowHeight := GetMainListRowHeightPixels()
    if clientHeight <= 0 || rowHeight <= 0
        return 0
    remainder := Mod(clientHeight, rowHeight)
    if remainder <= 1 || rowHeight - remainder <= 1
        return remainder <= 1 ? -remainder : rowHeight - remainder
    return remainder * 2 < rowHeight ? -remainder : rowHeight - remainder
}

GetSnappedMainWindowHeight(heightDip) {
    dpi := DllCall("user32\GetDpiForWindow", "Ptr", Main.lv.Hwnd, "UInt")
    deltaPixels := GetMainListHeightSnapDeltaPixels()
    deltaDip := Round(deltaPixels * 96 / (dpi ? dpi : 96))
    return Max(300, Integer(heightDip) + deltaDip)
}

SnapMainWindowHeightToListRows(*) {
    if !IsSet(Main) || !IsObject(Main.gui) || !Main.gui.Hwnd
            || !DllCall("user32\IsWindowVisible", "Ptr", Main.gui.Hwnd, "Int")
            || DllCall("user32\IsIconic", "Ptr", Main.gui.Hwnd, "Int")
            || DllCall("user32\IsZoomed", "Ptr", Main.gui.Hwnd, "Int")
        return false
    Main.gui.GetClientPos(,, &clientWidth, &clientHeight)
    clientWidthDip := UiScaleService.Unscale(clientWidth)
    clientHeightDip := UiScaleService.Unscale(clientHeight)
    snappedHeight := GetSnappedMainWindowHeight(clientHeightDip)
    if snappedHeight == clientHeightDip
        return false
    Main.gui.Show(UiScaleService.ScaleShowOptions("NoActivate w"
        clientWidthDip " h" snappedHeight))
    return true
}

MainWindowResizeFinished(wParam, lParam, msg, hwnd) {
    if hwnd != Main.gui.Hwnd
        return
    SnapMainWindowHeightToListRows()
}

AlignMainListBottomIfScrolled() {
    itemCount := Main.lv.GetCount()
    if !itemCount
        || SendMessage(Win32.LVM_GETTOPINDEX, 0, 0, Main.lv.Hwnd) <= 0
        return false
    clientRect := Buffer(16, 0)
    lastItemRect := Buffer(16, 0)
    NumPut("Int", Win32.LVIR_BOUNDS, lastItemRect, 0)
    if !DllCall("user32\GetClientRect", "Ptr", Main.lv.Hwnd,
            "Ptr", clientRect, "Int")
        || !SendMessage(Win32.LVM_GETITEMRECT, itemCount - 1,
            lastItemRect.Ptr, Main.lv.Hwnd)
        return false
    bottomGap := NumGet(clientRect, 12, "Int")
        - NumGet(lastItemRect, 12, "Int")
    if bottomGap <= 0
        return false
    SendMessage(Win32.LVM_SCROLL, 0, -bottomGap, Main.lv.Hwnd)
    return true
}

QueueMainListSmoothScroll(lines) {
    try lines := Integer(lines)
    catch
        return false
    if !lines
        return false
    BeginMainListTimerResolution()
    if Main.pendingListScrollLines
            && (Main.pendingListScrollLines > 0) != (lines > 0) {
        SetTimer(Main.smoothListScrollTimer, 0)
        Main.pendingListScrollLines := 0
    }
    maximum := MainWindow.SmoothScrollMaximumQueuedLines
    Main.pendingListScrollLines := Max(-maximum,
        Min(maximum, Main.pendingListScrollLines + lines))
    return AdvanceMainListSmoothScroll()
}

AdvanceMainListSmoothScroll(*) {
    if !IsSet(Main) || Main.listDragActive
            || !Main.pendingListScrollLines || !Main.lv || !Main.lv.Hwnd
            || !DllCall("user32\IsWindow", "Ptr", Main.lv.Hwnd, "Int")
            || !DllCall("user32\IsWindowVisible", "Ptr", Main.lv.Hwnd,
                "Int") {
        StopMainListSmoothScroll()
        return false
    }
    direction := Main.pendingListScrollLines > 0 ? 1 : -1
    before := SendMessage(Win32.LVM_GETTOPINDEX, 0, 0, Main.lv.Hwnd)
    SendMessage(Win32.LVM_SCROLL, 0,
        direction * GetMainListRowHeightPixels(), Main.lv.Hwnd)
    after := SendMessage(Win32.LVM_GETTOPINDEX, 0, 0, Main.lv.Hwnd)
    if after == before {
        StopMainListSmoothScroll()
        return false
    }
    Main.pendingListScrollLines -= direction
    if Main.pendingListScrollLines
        ScheduleNextMainListSmoothScroll()
    else
        StopMainListSmoothScroll()
    return true
}

ScheduleNextMainListSmoothScroll() {
    remainingLines := Abs(Main.pendingListScrollLines)
    accelerationRange := Max(1,
        MainWindow.SmoothScrollAccelerationLines - 1)
    speedRatio := Min(1, Max(0,
        (remainingLines - 1) / accelerationRange))
    easedSpeed := 1 - ((1 - speedRatio) * (1 - speedRatio))
    interval := Round(MainWindow.SmoothScrollSlowIntervalMs
        - (MainWindow.SmoothScrollSlowIntervalMs
            - MainWindow.SmoothScrollFastIntervalMs) * easedSpeed)
    Main.lastSmoothListScrollIntervalMs := interval
    SetTimer(Main.smoothListScrollTimer, -interval)
    return interval
}

BeginMainListTimerResolution() {
    if Main.smoothListTimerResolutionActive
        return true
    try Main.smoothListTimerResolutionActive := DllCall(
        "winmm\timeBeginPeriod", "UInt",
        MainWindow.SmoothScrollTimerResolutionMs, "UInt") == 0
    catch
        Main.smoothListTimerResolutionActive := false
    return Main.smoothListTimerResolutionActive
}

EndMainListTimerResolution() {
    if !Main.smoothListTimerResolutionActive
        return false
    Main.smoothListTimerResolutionActive := false
    try DllCall("winmm\timeEndPeriod", "UInt",
        MainWindow.SmoothScrollTimerResolutionMs, "UInt")
    return true
}

StopMainListSmoothScroll(resetWheelRemainder := false) {
    if !IsSet(Main)
        return false
    try SetTimer(Main.smoothListScrollTimer, 0)
    Main.pendingListScrollLines := 0
    EndMainListTimerResolution()
    if resetWheelRemainder
        Main.listWheelDeltaRemainder := 0
    return true
}

SignedMainListWord(value) {
    value &= 0xFFFF
    return value & 0x8000 ? value - 0x10000 : value
}

; 缩放只调整命令栏、列表和可见列，不改变图标逻辑尺寸或隐藏身份列。
GuiResized(GuiObj, MinMax, Width, Height) {
    if (MinMax == -1) {
        if IsSet(Main) && IsObject(Main.contextPopup)
            try Main.contextPopup.Hide()
        return
    }
    PositionMainCommandButtons(Width)
    MoveAndRefreshResizableText(Main.statsText, UiScaleService.Scale(10),
        Height - UiScaleService.Scale(20),
        Width - UiScaleService.Scale(20), UiScaleService.Scale(20))
    if IsSet(GuiModules)
        try GuiModules.historyToast.Reposition()

    listRedrawSuspended := SuspendMainListResizeRedraw()
    try {
        Main.lv.Move(UiScaleService.Scale(10), UiScaleService.Scale(92),
            Width - UiScaleService.Scale(20),
            Height - UiScaleService.Scale(117))
        AlignMainListBottomIfScrolled()

        ; 名称列吸收剩余宽度，状态列保持可读下限，路径身份列始终隐藏。
        rc := Buffer(16)
        DllCall("GetClientRect", "Ptr", Main.lv.Hwnd, "Ptr", rc)
        clientW := NumGet(rc, 8, "Int")

        col2W := SendMessage(Win32.LVM_GETCOLUMNWIDTH, 1, 0, Main.lv.Hwnd)
        sequenceW := SendMessage(Win32.LVM_GETCOLUMNWIDTH, 3, 0,
            Main.lv.Hwnd)

        if (clientW > col2W + sequenceW) {
            SendMessage(0x101E, 0, clientW - col2W - sequenceW,
                Main.lv.Hwnd) ; 自动拉伸守护对象列（内部索引 0）
        }
        SendMessage(0x101E, 2, 0, Main.lv.Hwnd) ; 隐藏完整路径列（内部索引 2）
        LayoutMainListHeader(Width)
    } finally ResumeMainListResizeRedraw(listRedrawSuspended)
}

ShowContextMenu(GuiCtrlObj, Item, IsRightClick, X, Y) {
    if (Item <= 0)
        return
    Main.contextTargetRow := Item
    ListViewFocusService.PrepareContextSelection(Main.lv, Item)
    path := Main.lv.GetText(Item, 3)
    if !App.appStates.Has(path) {
        Main.contextTargetRow := 0
        return
    }
    stateObj := App.appStates[path]
    isAdmin := stateObj.HasOwnProp("RunAsAdmin") && stateObj.RunAsAdmin
    askBeforeRestart := stateObj.HasOwnProp("AskBeforeRestart")
        && stateObj.AskBeforeRestart
    batchLogSupported := false
    try batchLogSupported := App.targetSpecsService.Get(path,
        stateObj).Launch.Kind == TargetLaunchKind.Batch
    ; 使用不激活的自绘浮层而非原生 Menu.Show，避免右键菜单接管焦点时
    ; ListView 在首帧把选中背景重绘成方形。
    popupItems := BuildMainContextPopupItems(isAdmin, batchLogSupported,
        askBeforeRestart)
    RefreshMainCommandState(true)
    if Main.HasOwnProp("listSelectionPresenter")
        Main.listSelectionPresenter.RefreshItem(Item)
    if IsObject(Main.contextPopup)
        Main.contextPopup.Show(popupItems)
}

OpenFileLocation(*) {
    if (Main.contextTargetRow <= 0)
        return
    path := Main.lv.GetText(Main.contextTargetRow, 3)
    locationPath := FileExist(path) ? path
        : App.targetIdentityService.GetMonitoredTargetPath(path)
    if locationPath != "" && FileExist(locationPath)
            && !DirExist(locationPath)
            && IsExplorerDefaultFileManager()
            && OpenFileSelectionWithExplorer(locationPath)
        return
    directoryPath := ResolveOpenLocationDirectory(locationPath)
    if directoryPath != ""
        OpenDirectoryWithDefaultFileManager(directoryPath)
}

ResolveOpenLocationDirectory(locationPath) {
    try locationPath := Trim(String(locationPath))
    catch
        return ""
    if locationPath == ""
        return ""
    if DirExist(locationPath)
        return locationPath
    SplitPath(locationPath, , &directoryPath)
    return DirExist(directoryPath) ? directoryPath : ""
}

OpenFileSelectionWithExplorer(filePath) {
    if filePath == "" || !FileExist(filePath) || DirExist(filePath)
        return false
    try {
        Run('explorer.exe /select,"' filePath '"')
        return true
    } catch {
        return false
    }
}

OpenDirectoryWithDefaultFileManager(directoryPath) {
    if directoryPath == "" || !DirExist(directoryPath)
        return false
    try {
        Run('"' directoryPath '"')
        return true
    } catch {
        return false
    }
}

IsExplorerDefaultFileManager() {
    for shellClass in ["Directory", "Drive", "Folder"] {
        defaultVerb := ReadFolderShellDefaultVerb(shellClass)
        if !IsExplorerFolderShellVerb(shellClass, defaultVerb)
            return false
    }
    return true
}

ReadFolderShellDefaultVerb(shellClass) {
    for keyName in [
        "HKEY_CURRENT_USER\Software\Classes\" shellClass "\shell",
        "HKEY_LOCAL_MACHINE\Software\Classes\" shellClass "\shell",
        "HKEY_CLASSES_ROOT\" shellClass "\shell"
    ] {
        defaultVerb := ReadRegistryDefaultValue(keyName)
        if defaultVerb != ""
            return defaultVerb
    }
    return ""
}

IsExplorerFolderShellVerb(shellClass, defaultVerb) {
    try defaultVerb := Trim(String(defaultVerb))
    catch
        return true
    normalizedVerb := StrLower(defaultVerb)
    if normalizedVerb == "" || normalizedVerb == "none"
        return true

    command := ReadFolderShellVerbCommand(shellClass, defaultVerb)
    if command != "" {
        normalizedCommand := StrLower(command)
        if InStr(normalizedCommand, "explorer.exe")
            return true
        if normalizedVerb != "open"
                && normalizedVerb != "opennewwindow"
                && normalizedVerb != "explore"
            return false
    }
    return normalizedVerb == "open"
        || normalizedVerb == "opennewwindow"
        || normalizedVerb == "explore"
}

ReadFolderShellVerbCommand(shellClass, verb) {
    for rootKey in ["HKEY_CURRENT_USER", "HKEY_LOCAL_MACHINE",
            "HKEY_CLASSES_ROOT"] {
        keyName := rootKey "\Software\Classes\" shellClass "\shell\" verb "\command"
        command := ReadRegistryDefaultValue(keyName)
        if command != ""
            return command
    }
    return ""
}

ReadRegistryDefaultValue(keyName) {
    try return Trim(String(RegRead(keyName)))
    catch
        return ""
}

ManualStopRequestIsCurrent(path, stateObj, expectedGeneration := 0) {
    try {
        if !IsObject(stateObj) || !App.appStates.Has(path)
            || App.appStates[path] != stateObj
            || !stateObj.ManualStopRequested
            || (expectedGeneration
                && stateObj.Generation != expectedGeneration)
            || (expectedGeneration && stateObj.HasOwnProp(
                "ManualStopGeneration")
                && stateObj.ManualStopGeneration != expectedGeneration)
            return false
        return true
    } catch {
        return false
    }
}

ClearManualStopRequest(stateObj, expectedGeneration := 0) {
    if !IsObject(stateObj) || !stateObj.ManualStopRequested
        return false
    if expectedGeneration && stateObj.HasOwnProp("ManualStopGeneration")
        && stateObj.ManualStopGeneration != expectedGeneration
        return false
    stateObj.ManualStopRequested := false
    if stateObj.HasOwnProp("ManualStopGeneration")
        stateObj.ManualStopGeneration := 0
    return true
}

ManualStopKnownProcessIsStopped(stateObj) {
    try return stateObj.PID && stateObj.PIDCreationIdentity
        && App.targetStopper.GetIdentityStatus(stateObj.PID,
            stateObj.PIDCreationIdentity) == 0
    catch
        return false
}

ScheduleManualStopDispatch(delayMs := 1) {
    if !App.HasOwnProp("manualStopQueue") || !App.manualStopQueue.Length
        return false
    if App.HasOwnProp("manualStopInFlight")
        && App.HasOwnProp("manualStopMaxConcurrency")
        && App.manualStopInFlight >= Max(1,
            Integer(App.manualStopMaxConcurrency))
        return false
    if !App.HasOwnProp("manualStopDispatchTimer")
        App.manualStopDispatchTimer := DispatchManualStopQueue.Bind()
    if App.HasOwnProp("manualStopDispatchArmed")
        && App.manualStopDispatchArmed
        return true
    App.manualStopDispatchArmed := true
    try {
        SetTimer(App.manualStopDispatchTimer, -Max(1, delayMs))
        return true
    } catch as scheduleError {
        App.manualStopDispatchArmed := false
        FailQueuedManualStops(scheduleError)
        return false
    }
}

DispatchManualStopQueue(*) {
    if !App.HasOwnProp("manualStopQueue")
        return
    App.manualStopDispatchArmed := false
    try {
        maxConcurrency := App.HasOwnProp("manualStopMaxConcurrency")
            ? Max(1, Integer(App.manualStopMaxConcurrency)) : 4
        while App.manualStopQueue.Length
            && App.manualStopInFlight < maxConcurrency {
            request := App.manualStopQueue.RemoveAt(1)
            if !IsObject(request)
                continue
            App.manualStopInFlight++
            try {
                SetTimer(DispatchManualStopRequest.Bind(request), -1)
            } catch as dispatchError {
                App.manualStopInFlight := Max(0,
                    App.manualStopInFlight - 1)
                try FinalizeManualStopFailure(request.Path, request.State,
                    request.Generation,
                    Tr("结束运行失败，目标进程未能停止：{1}", request.Path))
                try LogMsg(Tr("后台调度任务异常（{1}）：{2}",
                    request.Path, TrDiagnostic(dispatchError.Message)))
            }
        }
    } finally {
        if App.manualStopQueue.Length
            && App.manualStopInFlight < maxConcurrency
            ScheduleManualStopDispatch(1)
    }
}

DispatchManualStopRequest(request, *) {
    try {
        try PerformManualStop(request.Path, request.State,
            request.Generation, 0)
        catch as dispatchError {
            try FinalizeManualStopFailure(request.Path, request.State,
                request.Generation,
                Tr("结束运行失败，目标进程未能停止：{1}", request.Path))
            try LogMsg(Tr("后台调度任务异常（{1}）：{2}",
                request.Path, TrDiagnostic(dispatchError.Message)))
        }
    } finally {
        App.manualStopInFlight := Max(0, App.manualStopInFlight - 1)
        if App.manualStopQueue.Length
            && (!App.HasOwnProp("manualStopMaxConcurrency")
                || App.manualStopInFlight < Max(1,
                    Integer(App.manualStopMaxConcurrency)))
            ScheduleManualStopDispatch(1)
    }
}

FailQueuedManualStops(scheduleError := "") {
    if !App.HasOwnProp("manualStopQueue")
        return 0
    failed := 0
    while App.manualStopQueue.Length {
        request := App.manualStopQueue.RemoveAt(1)
        if !IsObject(request)
            continue
        failed++
        try FinalizeManualStopFailure(request.Path, request.State,
            request.Generation,
            Tr("结束运行失败，目标进程未能停止：{1}", request.Path))
        if IsObject(scheduleError)
            try LogMsg(Tr("后台调度任务异常（{1}）：{2}", request.Path,
                TrDiagnostic(scheduleError.Message)))
    }
    return failed
}

RestartSelectedApp(*) {
    paths := CaptureSelectedWatchPaths(true)
    if !paths.Length
        return
    QueueGuardMutation(BeginManualRestartRequests.Bind(paths))
}

ClearManualRestartRequest(stateObj, expectedGeneration) {
    if !stateObj.ManualRestartRequested
            || stateObj.ManualRestartGeneration != expectedGeneration {
        return false
    }
    stateObj.ManualRestartRequested := false
    stateObj.ManualRestartGeneration := 0
    return true
}

BeginManualRestartRequests(paths) {
    resumedAny := false
    resumedPaths := []
    undoState := ""
    for path in paths {
        if !App.appStates.Has(path)
            continue
        stateObj := App.appStates[path]
        if stateObj.ManualRestartRequested || stateObj.ManualStopRequested
            continue
        wasEnabled := !!stateObj.Enabled
        if !wasEnabled {
            if Type(undoState) != "Array"
                undoState := CaptureAppConfigState()
            stateObj.Enabled := 1
        }
        stateObj.CancelScheduledTasks()
        stateObj.ResetGuardAttemptState()
        operationGeneration := stateObj.Generation
        stateObj.ManualRestartRequested := true
        stateObj.ManualRestartGeneration := operationGeneration
        stateObj.Pending := true
        ; 暂停项被隐式恢复后立即投影重启状态，不能在异步任务运行前继续显示暂停。
        UpdateState(path, Tr("⏳ 停止原进程..."), stateObj,
            operationGeneration, !wasEnabled)
        try {
            SetTimer(PerformManualRestart.Bind(path, stateObj,
                operationGeneration, 0), -1)
            if !wasEnabled {
                resumedAny := true
                resumedPaths.Push(path)
            }
        }
        catch {
            ClearManualRestartRequest(stateObj, operationGeneration)
            stateObj.Pending := false
            if !wasEnabled {
                stateObj.Enabled := 0
                stateObj.TransitionTo(GuardPhase.Paused)
                UpdateState(path, Tr("⏸️ 已暂停"), stateObj,
                    stateObj.Generation)
            } else {
                UpdateState(path, Tr("❌ 无法停止原进程"), stateObj,
                    stateObj.Generation)
            }
            LogMsg(Tr("手动重启已取消，原进程未能停止：{1}", path))
        }
    }

    if resumedAny {
        CommitUndoState(undoState,
            CreateAppHistoryAction("toggle-pause", resumedPaths))
        SaveAppsToIni()
    }
    if paths.Length > 0
        OnLVSelectChange()
}

PerformManualRestart(path, expectedSupervisor, expectedGeneration,
    attempt) {
    if !App.guardRuntime.IsSupervisorCurrent(path, expectedSupervisor,
            expectedGeneration) {
        if App.appStates.Has(path)
                && App.appStates[path] == expectedSupervisor
            ClearManualRestartRequest(expectedSupervisor,
                expectedGeneration)
        return
    }
    if !App.guardWorkGate.TryEnter("ManualRestart") {
        retryCallback := PerformManualRestart.Bind(path,
            expectedSupervisor, expectedGeneration, attempt)
        TryScheduleManualRestartCallback(retryCallback, path,
            expectedSupervisor, expectedGeneration)
        return
    }

    operationGeneration := expectedGeneration
    gateHeld := true
    try {
        if !App.guardRuntime.IsSupervisorCurrent(path, expectedSupervisor,
                expectedGeneration)
            return
        stateObj := expectedSupervisor
        stateObj.CancelScheduledTasks()
        operationGeneration := stateObj.Generation
        stateObj.ManualRestartGeneration := operationGeneration
        stateObj.Pending := true
        stateObj.TargetStartTicks := 0
        UpdateState(path, Tr("⏳ 停止原进程..."), stateObj,
            operationGeneration)
        observation := ObserveTarget(path, "", 1000)
        if !App.guardRuntime.IsSupervisorCurrent(path, stateObj,
                operationGeneration)
            return
        if observation.IsUnknown() {
            ScheduleManualRestartRetry(path, stateObj,
                operationGeneration, attempt)
            return
        }
        if observation.IsRunning() {
            pid := observation.PID
            creationIdentity := observation.CreationIdentity
            if creationIdentity == ""
                creationIdentity := App.processInspector
                    .GetCreationIdentity(pid)
            if creationIdentity == "" {
                ScheduleManualRestartRetry(path, stateObj,
                    operationGeneration, attempt)
                return
            }
            ; 目标身份和事务代际已在门内冻结；耗时停止在门外执行，避免阻塞其它目标。
            App.guardWorkGate.Leave()
            gateHeld := false
            try stopResult := StopTargetProcess(pid, creationIdentity)
            catch as stopError {
                errorDetail := TrDiagnostic(stopError.Message)
                LogMsg(Tr("无法停止进程 PID：{1}{2}", pid,
                    Tr("（{1}）", errorDetail)))
                stopResult := TargetStopResult(false,
                    TargetStopStage.Failed, errorDetail)
            }
            completionCallback := CompleteManualRestartAfterStop.Bind(path,
                stateObj, operationGeneration, pid, creationIdentity,
                stopResult)
            try SetTimer(completionCallback, -1)
            catch
                completionCallback.Call()
            return
        }

        FinalizeManualRestart(path, stateObj, operationGeneration)
    } finally {
        if App.appStates.Has(path)
                && App.appStates[path] == expectedSupervisor
                && expectedSupervisor.ManualRestartRequested
                && expectedSupervisor.Generation != operationGeneration {
            ClearManualRestartRequest(expectedSupervisor,
                operationGeneration)
        }
        if gateHeld
            App.guardWorkGate.Leave()
    }
}

CompleteManualRestartAfterStop(path, expectedSupervisor,
    expectedGeneration, pid, creationIdentity, stopResult) {
    if !App.guardRuntime.IsSupervisorCurrent(path, expectedSupervisor,
            expectedGeneration) {
        if App.appStates.Has(path)
                && App.appStates[path] == expectedSupervisor
            ClearManualRestartRequest(expectedSupervisor,
                expectedGeneration)
        return
    }
    if !App.guardWorkGate.TryEnter("ManualRestartAfterStop") {
        retryCallback := CompleteManualRestartAfterStop.Bind(path,
            expectedSupervisor, expectedGeneration, pid,
            creationIdentity, stopResult)
        TryScheduleManualRestartCallback(retryCallback, path,
            expectedSupervisor, expectedGeneration)
        return
    }
    try {
        if !App.guardRuntime.IsSupervisorCurrent(path, expectedSupervisor,
                expectedGeneration)
            return
        stateObj := expectedSupervisor
        if !stopResult.Stopped {
            ClearManualRestartRequest(stateObj, expectedGeneration)
            stateObj.Pending := false
            identityStatus := App.targetStopper.GetIdentityStatus(pid,
                creationIdentity)
            if identityStatus == 0
                ClearStateProcessIdentity(stateObj)
            else
                SetStateProcessIdentity(stateObj, pid, creationIdentity)
            UpdateState(path, Tr("❌ 无法停止原进程"), stateObj,
                expectedGeneration)
            LogMsg(Tr("手动重启已取消，原进程未能停止：{1}", path))
            return
        }
        FinalizeManualRestart(path, stateObj, expectedGeneration)
    } finally App.guardWorkGate.Leave()
}

FinalizeManualRestart(path, stateObj, expectedGeneration) {
    if !App.guardRuntime.IsSupervisorCurrent(path, stateObj,
            expectedGeneration) || !stateObj.Enabled {
        ClearManualRestartRequest(stateObj, expectedGeneration)
        if !stateObj.Enabled {
            stateObj.Pending := false
            stateObj.TargetStartTicks := 0
        }
        return false
    }
    stateObj.Pending := true
    stateObj.TargetStartTicks := 0
    stateObj.FailCount := 0
    ClearManualRestartRequest(stateObj, expectedGeneration)
    ClearStateProcessIdentity(stateObj)
    ; 调用方持有共享工作门，直接进入核心启动事务，避免重复获取工作门。
    App.guardRuntime.RestartCore(path, stateObj)
    LogMsg(Tr("手动触发了重新启动：{1}", path))
    return true
}

ScheduleManualRestartRetry(path, stateObj, operationGeneration, attempt) {
    if attempt >= 4 {
        ClearManualRestartRequest(stateObj, operationGeneration)
        stateObj.Pending := false
        UpdateState(path, Tr("⏳ 等待进程状态..."), stateObj,
            operationGeneration)
        LogMsg(Tr("暂时无法查询进程状态，稍后重试手动重启：{1}", path))
        return false
    }
    UpdateState(path, Tr("⏳ 等待进程状态..."), stateObj,
        operationGeneration)
    if attempt == 0
        LogMsg(Tr("暂时无法查询进程状态，稍后重试手动重启：{1}", path))
    retryCallback := PerformManualRestart.Bind(path, stateObj,
        operationGeneration, attempt + 1)
    return TryScheduleManualRestartCallback(retryCallback, path, stateObj,
        operationGeneration, 2000)
}

TryScheduleManualRestartCallback(callback, path, stateObj,
    expectedGeneration, delayMs := 100) {
    try {
        SetTimer(callback, -Max(1, delayMs))
        return true
    } catch as timerError {
        if App.guardRuntime.IsSupervisorCurrent(path, stateObj,
                expectedGeneration) {
            ClearManualRestartRequest(stateObj, expectedGeneration)
            stateObj.Pending := false
            stateObj.TargetStartTicks := 0
            if !stateObj.Pending {
                stateObj.TransitionTo(GuardPhase.Initializing)
                UpdateState(path, Tr("初始化..."), stateObj,
                    expectedGeneration)
            }
        }
        LogMsg(Tr("后台调度任务异常（{1}）：{2}", path,
            TrDiagnostic(timerError.Message)))
        return false
    }
}

; 托盘、通知和标题栏关闭最终都汇入同一组窗口生命周期操作。
IsApplicationNotificationClick(lParam, hwnd) {
    return hwnd == A_ScriptHwnd
        && (lParam & 0xFFFF) == Win32.NIN_BALLOONUSERCLICK
}

OnTrayNotification(wParam, lParam, msg, hwnd) {
    if !IsApplicationNotificationClick(lParam, hwnd)
        return
    ; Windows 消息回调内不直接创建 GUI，避免通知连点造成重入和焦点竞争。
    SetTimer(OpenNotificationWindows, -1)
    return 0
}

OpenNotificationWindows(*) {
    if !IsSet(Main) || !IsSet(GuiModules)
        return
    if IsSet(App) && App.shutdownStarted
        return

    ; 主窗口的显示、恢复、激活和最终自绘表面刷新由同一入口完成。
    ; 这里不要再追加 WinShow/WinRestore，否则会在已提交的首帧后再次
    ; 触发 ListView 的原生焦点绘制，导致圆角选中层和彩点短暂丢失。
    try ShowMainGui()

    try ShowLog()
    if GuiModules.log.IsOpen() {
        logHwnd := GuiModules.log.gui.Hwnd
        try WinShow("ahk_id " logHwnd)
        try WinRestore("ahk_id " logHwnd)
        try WinActivate("ahk_id " logHwnd)
    }
}

RefreshMainCommandButtonsAfterShow() {
    ; 隐藏或最小化窗口恢复后，ListView 可能只提交原生矩形选中底色，且
    ; 序号列的 NM_CUSTOMDRAW 不一定随父窗口恢复首帧执行。先在同一可见期
    ; 同步刷新列表，再刷新 owner-draw 按钮，鼠标移动不再承担修复职责。
    listRefreshed := false
    if Main.HasOwnProp("listSelectionPresenter")
            && IsObject(Main.listSelectionPresenter)
        try listRefreshed := Main.listSelectionPresenter.RefreshNativeSurface()
    buttonRefreshed := RedrawVisibleRoundedButtons([
        Main.btnAdd, Main.btnPause, Main.btnDel,
        Main.btnSet, Main.btnSupport, Main.btnAbout
    ])
    return listRefreshed || buttonRefreshed
}

PrepareMainWindowFirstVisibleSurface() {
    ; Gui.Show 会让原生子控件和非客户区进入可见生命周期。必须在窗口已映射、
    ; 但仍被 DWM 排除在合成之外时重新声明主题并同步画完全部首帧表面。
    UiThemeService.ApplyProcessPreference()
    ApplyNativeWindowTheme(Main.gui.Hwnd)
    Main.gui.BackColor := UiThemeService.Color("Window")
    ApplyDarkListViewTheme(Main.lv.Hwnd)
    if Main.HasOwnProp("listHeader") && IsObject(Main.listHeader) {
        Main.listHeader.ApplyAppearance(UiThemeService.Color("Toolbar"),
            UiThemeService.Color("MutedText"),
            LocalizationService.GetLanguageSystemUiFontName())
    }
    if Main.HasOwnProp("statsPresenter") && IsObject(Main.statsPresenter)
        Main.statsPresenter.Redraw()
    else if Main.HasOwnProp("statsText") && IsObject(Main.statsText)
        Main.statsText.Redraw()
    UiScaleService.RescaleWindowFonts(Main.gui)
    RefreshMainCommandButtonsAfterShow()
    DllCall("user32\RedrawWindow", "Ptr", Main.gui.Hwnd, "Ptr", 0,
        "Ptr", 0, "UInt", Win32.RDW_LAYOUT_REFRESH, "Int")
    return true
}

ShowMainGuiWithOptions(showOptions := "") {
    ; 映射窗口前先遮蔽，避免默认浅色非客户区、ListView 或 owner-draw
    ; STATIC 在主题重申完成前被 DWM 提交为一个可见帧。
    result := FirstVisibleWindowPresenter.Show(Main.gui, showOptions,
        Main.firstVisiblePresentationCompleted,
        PrepareMainWindowFirstVisibleSurface,
        RefreshMainCommandButtonsAfterShow)
    Main.firstVisiblePresentationCompleted := result.FirstVisibleCompleted
    return result.Visible
}

ShowMainGui(*) {
    mainHwnd := Main.gui.Hwnd
    wasFirstVisible := Main.firstVisiblePresentationCompleted
    wasVisible := DllCall("user32\IsWindowVisible", "Ptr", mainHwnd,
        "Int") != 0
    wasMinimized := DllCall("user32\IsIconic", "Ptr", mainHwnd,
        "Int") != 0
    needsRestoreCloak := wasFirstVisible
        && (!wasVisible || wasMinimized)
    cloakApplied := needsRestoreCloak
        && FirstVisibleWindowPresenter.SetCloaked(mainHwnd, true)
    ; 已显示窗口从托盘重新取得焦点时，Gui.Show/WinActivate 会先让原生
    ; ListView 画出矩形焦点选中态。只冻结列表，不冻结主窗口；激活完成后
    ; 再同步提交圆角自绘终态，标题栏和其余控件仍可正常完成激活动画。
    listRedrawSuspended := wasFirstVisible && wasVisible && !wasMinimized
        && SuspendMainListResizeRedraw()
    visible := false
    try {
        try {
            showOptions := !wasVisible
                ? "w" App.savedWidth " h" App.savedHeight : ""
            visible := ShowMainGuiWithOptions(showOptions)
            if WindowHierarchy.IsOwnerLocked(Main.gui)
                WindowHierarchy.ActivateTopOwned(Main.gui)
            else if visible
                try WinActivate("ahk_id " mainHwnd)
        } finally {
            ResumeMainListResizeRedraw(listRedrawSuspended)
            listRedrawSuspended := false
        }
        ; 激活可能重新写入 CDIS_FOCUS；在激活完成后再提交一次合并的最终表面。
        if visible
            RefreshMainCommandButtonsAfterShow()
        if cloakApplied
            FirstVisibleWindowPresenter.FlushComposition()
    } finally {
        ; Show/Activate 异常时也不能让 ListView 留在停绘状态。
        ResumeMainListResizeRedraw(listRedrawSuspended)
        if cloakApplied {
            FirstVisibleWindowPresenter.SetCloaked(mainHwnd, false)
            FirstVisibleWindowPresenter.FlushComposition()
        }
    }
    return visible
}

ResizeMainWindowForUiScale(previousScale, nextScale) {
    if previousScale == nextScale || !IsSet(Main) || !Main.gui
        return false
    try Main.gui.GetClientPos(,, &clientWidth, &clientHeight)
    catch
        return false
    if clientWidth <= 0 || clientHeight <= 0
        return false
    ratio := nextScale / previousScale
    targetWidth := Max(1, Round(clientWidth * ratio))
    targetHeight := Max(1, Round(clientHeight * ratio))
    visible := DllCall("user32\IsWindowVisible", "Ptr", Main.gui.Hwnd,
        "Int") != 0
    Main.gui.Show((visible ? "" : "Hide ") "w" targetWidth
        " h" targetHeight)
    return true
}

RefreshMainImageListForUiScale(previousScale, nextScale) {
    if previousScale == nextScale || !IsSet(Main) || !Main.gui
        return false
    dpi := DllCall("user32\GetDpiForWindow", "Ptr", Main.gui.Hwnd, "UInt")
    if !dpi
        dpi := 96
    rebuildRequest := App.iconResources.CreateDpiRebuildRequest(dpi,
        RebuildMainImageList)
    if rebuildRequest.PreviousTimer
        SetTimer(rebuildRequest.PreviousTimer, 0)
    SetTimer(rebuildRequest.Timer, -1)
    return true
}

; 主窗口文件拖放沿用添加窗口的目标解析规则；目录交给批量导入，文件则在
; 同一守护变更事务中注册，以便撤销、持久化与状态刷新保持一致。
ResolveShortcutForAdd(path, &shortcutArguments := "", &resolvedWorkDir := "") {
    shortcutArguments := ""
    resolvedWorkDir := ""
    SplitPath(path, , , &ext)
    if (StrLower(ext) == "lnk") {
        descriptor := App.shortcutTargetResolver.Read(path)
        if descriptor.Readable {
            resolvedWorkDir := descriptor.WorkingDirectory
            shortcutArguments := descriptor.Arguments
        }
    }
    ; 快捷方式始终作为启动入口保存；真实进程身份由 ResolvedTarget 独立维护。
    return path
}

OnGuiDropFiles(GuiObj, CtrlObj, FileArray, X, Y) {
    directories := []
    files := []
    for dropPath in FileArray {
        if DirExist(dropPath)
            directories.Push(dropPath)
        else if App.fileScanner.IsSupported(dropPath)
            files.Push(dropPath)
    }
    if directories.Length {
        GuiModules.addItem.StartBatchImport(directories, files)
        return
    }
    if files.Length
        QueueGuardMutation(AddDroppedWatchItems.Bind(files.Clone()))
}

AddDroppedWatchItems(files) {
    undoState := CaptureAppConfigState()
    addedCount := 0
    addedPaths := []
    for filePath in files {
        shortcutArgs := "", resolvedWorkDir := ""
        resolvedPath := ResolveShortcutForAdd(filePath, &shortcutArgs,
            &resolvedWorkDir)
        if RegisterApp(resolvedPath, 1, 0, resolvedWorkDir,
            "", "", "", false, shortcutArgs) {
            addedCount++
            addedPaths.Push(resolvedPath)
        }
    }
    if addedCount {
        CommitUndoState(undoState,
            CreateAppHistoryAction("add", addedPaths))
        SaveAppsToIni()
    }
    LogMsg(Tr("通过拖拽添加了 {1} 个守护对象。", addedCount))
}

; DPI 切换只重建主列表的小图标集合；旧集合在新集合成功绑定后延迟回收，
; 避免 Windows 仍绘制旧句柄时出现黑底、错位或空白图标。
MainDpiChanged(wParam, lParam, msg, hwnd) {
    if (hwnd != Main.gui.Hwnd)
        return
    newDpi := wParam & 0xFFFF
    iconResources := App.iconResources
    if (!newDpi || newDpi == iconResources.MainDpi)
        return
    rebuildRequest := iconResources.CreateDpiRebuildRequest(newDpi,
        RebuildMainImageList)
    if rebuildRequest.PreviousTimer
        SetTimer(rebuildRequest.PreviousTimer, 0)
    SetTimer(rebuildRequest.Timer, -250)
}

MainWindowMoved(wParam, lParam, msg, hwnd) {
    if (hwnd != Main.gui.Hwnd)
        return
    if IsSet(GuiModules)
        try GuiModules.historyToast.Reposition()
}

RebuildMainImageList(rebuildGeneration, expectedDpi, *) {
    iconResources := App.iconResources
    if !iconResources.AcceptDpiRebuild(rebuildGeneration)
        return
    if !DllCall("user32\IsWindow", "Ptr", Main.gui.Hwnd, "Int")
        return
    currentDpi := DllCall("user32\GetDpiForWindow", "Ptr", Main.gui.Hwnd,
        "UInt")
    if (currentDpi != expectedDpi)
        return
    oldImageList := Main.appIcons
    previousMetrics := iconResources.GetMainIconMetrics()
    newStatusIconIndices := Map()
    newImageList := CreateMainImageList(newStatusIconIndices)
    if !newImageList
        return
    if !iconResources.IsDpiRebuildCurrent(rebuildGeneration) {
        ClearImageListIconCache(newImageList)
        try IL_Destroy(newImageList)
        iconResources.RestoreMainIconMetrics(previousMetrics)
        return
    }
    redrawSuspended := false
    newImageListAttached := false
    try {
        Main.lv.Opt("-Redraw")
        redrawSuspended := true
        Main.lv.SetImageList(newImageList, 1)
        newImageListAttached := true
        Main.appIcons := newImageList
        Main.statusIconIndices := newStatusIconIndices
        Main.lv.IL := newImageList
        Loop Main.lv.GetCount() {
            try {
                path := Main.lv.GetText(A_Index, 3)
                stateObj := App.appStates.Has(path)
                    ? App.appStates[path] : ""
                iconIndex := GetMainListIconIndex(path, stateObj,
                    newImageList)
                if iconIndex
                    Main.lv.Modify(A_Index, "Icon" iconIndex)
                statusText := App.appStates.Has(path)
                    ? App.appStates[path].State
                    : Main.lv.GetText(A_Index, 2)
                SetMainListStatus(A_Index, statusText)
                SetMainListAdminOverlay(A_Index,
                    stateObj && stateObj.RunAsAdmin)
            } catch as rowIconError {
                LogMsg(Tr("DPI 变化后刷新图标失败：{1}",
                    TrDiagnostic(rowIconError.Message)))
            }
        }
    } catch as imageListError {
        LogMsg(Tr("DPI 变化后重建图标列表失败：{1}",
            TrDiagnostic(imageListError.Message)))
    } finally {
        if redrawSuspended
            try Main.lv.Opt("+Redraw")
        if newImageListAttached {
            RetireMainImageList(oldImageList)
        } else {
            ClearImageListIconCache(newImageList)
            try IL_Destroy(newImageList)
            iconResources.RestoreMainIconMetrics(previousMetrics)
        }
    }
}
