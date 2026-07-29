; 主窗口交互控制器。
; 这里集中处理显示、隐藏、缩放、右键菜单和系统通知回流；MainWindow 只持有
; 长期控件状态，入口脚本只负责装配事件与启动顺序。

OnMainGuiClose(*) {
    HideMainGui()
}

HideMainGui(force := false) {
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
            App.windowLayoutService.Save({
                Width: Round(gW), Height: Round(gH),
                Column1: Round(c1 / dpiScale),
                Column2: Round(c2 / dpiScale)
            })
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
        return Main.listHeader.SetBounds(10, 60,
            [sequenceWidth, nameWidth, statusWidth], Max(0, clientWidth - 20))
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

; 缩放只调整命令栏、列表和可见列，不改变图标逻辑尺寸或隐藏身份列。
GuiResized(GuiObj, MinMax, Width, Height) {
    if (MinMax == -1)
        return
    PositionMainCommandButtons(Width)

    Main.lv.Move(10, 88, Width - 20, Height - 113)
    MoveAndRefreshResizableText(Main.statsText, 10, Height - 20,
        Width - 20, 20)
    if IsSet(GuiModules)
        try GuiModules.historyToast.Reposition()

    ; 名称列吸收剩余宽度，状态列保持可读下限，路径身份列始终隐藏。
    rc := Buffer(16)
    DllCall("GetClientRect", "Ptr", Main.lv.Hwnd, "Ptr", rc)
    clientW := NumGet(rc, 8, "Int")

    col2W := SendMessage(Win32.LVM_GETCOLUMNWIDTH, 1, 0, Main.lv.Hwnd)
    sequenceW := SendMessage(Win32.LVM_GETCOLUMNWIDTH, 3, 0, Main.lv.Hwnd)

    if (clientW > col2W + sequenceW) {
        SendMessage(0x101E, 0, clientW - col2W - sequenceW,
            Main.lv.Hwnd) ; 自动拉伸守护对象列（内部索引 0）
    }
    SendMessage(0x101E, 2, 0, Main.lv.Hwnd) ; 隐藏完整路径列（内部索引 2）
    LayoutMainListHeader(Width)
}

ShowContextMenu(GuiCtrlObj, Item, IsRightClick, X, Y) {
    if (Item <= 0)
        return
    Main.contextTargetRow := Item
    ; 右键未选中的行时将其设为唯一选中项，避免菜单误作用于旧选择。
    isSelected := false
    probeRow := 0
    Loop {
        probeRow := Main.lv.GetNext(probeRow)
        if !probeRow
            break
        if (probeRow == Item) {
            isSelected := true
            break
        }
    }
    if !isSelected {
        Main.lv.Modify(0, "-Select")
        Main.lv.Modify(Item, "Select Focus")
    }
    path := Main.lv.GetText(Item, 3)
    if !App.appStates.Has(path) {
        Main.contextTargetRow := 0
        return
    }
    stateObj := App.appStates[path]
    isAdmin := stateObj.HasOwnProp("RunAsAdmin") && stateObj.RunAsAdmin
    maintenanceSupported := IsMaintenanceSupportedTarget(path)
    maintenanceEnabled := maintenanceSupported
        && stateObj.HasOwnProp("MaintenanceConfig")
        && stateObj.MaintenanceConfig.Enabled
    batchLogSupported := false
    try batchLogSupported := App.targetSpecsService.Get(path,
        stateObj).Launch.Kind == TargetLaunchKind.Batch
    ; 每次弹出前在同一菜单句柄上刷新条目，避免保留上一个守护对象的勾选或禁用状态。
    ConfigureMainContextMenu(isAdmin, maintenanceEnabled,
        maintenanceSupported, batchLogSupported)
    if Main.HasOwnProp("listSelectionPresenter")
        Main.listSelectionPresenter.RefreshItem(Item)
    ContextMenuPresenter.Show(Main.contextMenu)
}

OpenFileLocation(*) {
    if (Main.contextTargetRow <= 0)
        return
    path := Main.lv.GetText(Main.contextTargetRow, 3)
    locationPath := FileExist(path) ? path
        : App.targetIdentityService.GetMonitoredTargetPath(path)
    SplitPath(locationPath, , &dir)
    if FileExist(locationPath)
        Run('explorer.exe /select,"' locationPath '"')
    else if FileExist(dir)
        Run('explorer.exe "' dir '"')
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

    try ShowMainGui()
    try WinShow("ahk_id " Main.gui.Hwnd)
    try WinRestore("ahk_id " Main.gui.Hwnd)

    try ShowLog()
    if GuiModules.log.IsOpen() {
        logHwnd := GuiModules.log.gui.Hwnd
        try WinShow("ahk_id " logHwnd)
        try WinRestore("ahk_id " logHwnd)
        try WinActivate("ahk_id " logHwnd)
    }
}

ShowMainGui(*) {
    Main.gui.Show()
    if WindowHierarchy.IsOwnerLocked(Main.gui)
        WindowHierarchy.ActivateTopOwned(Main.gui)
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
            "", "", "", "", false, shortcutArgs) {
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
