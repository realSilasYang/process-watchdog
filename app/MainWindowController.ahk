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

PositionMainCommandButtons(clientWidth) {
    positions := GetMainCommandButtonPositions(clientWidth)
    result := AtomicControlLayout.Apply(Main.gui, [
        {Control: Main.btnSet, X: positions.Settings, Y: 15,
            Width: Main.settingsButtonWidth, Height: 30},
        {Control: Main.btnSupport, X: positions.Support, Y: 15,
            Width: Main.supportButtonWidth, Height: 30},
        {Control: Main.btnAbout, X: positions.About, Y: 15,
            Width: Main.aboutButtonWidth, Height: 30}
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

; 缩放只调整命令栏、列表和可见列，不改变图标逻辑尺寸或隐藏身份列。
GuiResized(GuiObj, MinMax, Width, Height) {
    if (MinMax == -1)
        return
    PositionMainCommandButtons(Width)
    MoveAndRefreshResizableText(Main.statsText, 10, Height - 20,
        Width - 20, 20)
    if IsSet(GuiModules)
        try GuiModules.historyToast.Reposition()

    listRedrawSuspended := SuspendMainListResizeRedraw()
    try {
        Main.lv.Move(10, 88, Width - 20, Height - 113)

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
    ; 右键未选中的行时将其设为唯一选中项，避免菜单误作用于旧选择。
    selectedRow := Main.lv.GetNext(0)
    hasAdditionalSelection := selectedRow
        && Main.lv.GetNext(selectedRow) > 0
    if selectedRow != Item || hasAdditionalSelection {
        Main.lv.Modify(0, "-Select")
        Main.lv.Modify(Item, "Select Focus Vis")
    } else {
        Main.lv.Modify(Item, "Focus Vis")
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
    ; 使用不激活的自绘浮层而非原生 Menu.Show，避免右键菜单接管焦点时
    ; ListView 在首帧把选中背景重绘成方形。
    popupItems := BuildMainContextPopupItems(isAdmin, maintenanceEnabled,
        maintenanceSupported, batchLogSupported)
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
    blockedAny := false
    undoState := ""
    for path in paths {
        if !App.appStates.Has(path)
            continue
        stateObj := App.appStates[path]
        if App.maintenanceCoordinator.IsBlocking(stateObj) {
            blockedAny := true
            continue
        }
        if stateObj.ManualRestartRequested || stateObj.ManualStopRequested
            continue
        wasEnabled := !!stateObj.Enabled
        if !wasEnabled {
            if Type(undoState) != "Array"
                undoState := CaptureAppConfigState()
            stateObj.Enabled := 1
            try App.maintenanceCoordinator.EnsureWatcher(path, stateObj)
            catch {
                stateObj.Enabled := 0
                try App.maintenanceCoordinator.CloseWatcher(stateObj)
                stateObj.TransitionTo(GuardPhase.Paused)
                throw
            }
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
                try App.maintenanceCoordinator.CleanupTarget(path,
                    stateObj, false)
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
    if blockedAny {
        ShowDarkMsgBoxDeferred(Tr("该软件正在升级保护中。请等待升级完成，或在“软件升级保护”中结束等待后再重新启动。"),
            Tr("暂时无法重新启动"), "Info", Main.gui)
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
    if App.maintenanceCoordinator.IsBlocking(expectedSupervisor) {
        ClearManualRestartRequest(expectedSupervisor, expectedGeneration)
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
        if App.maintenanceCoordinator.IsBlocking(stateObj) {
            ClearManualRestartRequest(stateObj, expectedGeneration)
            return
        }
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
            expectedGeneration) || !stateObj.Enabled
            || App.maintenanceCoordinator.IsBlocking(stateObj) {
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
            stateObj.Pending := App.maintenanceCoordinator.IsBlocking(
                stateObj)
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

RefreshMainCommandButtonsAfterShow() {
    ; 这些 STATIC 在隐藏的主窗口中完成 owner-draw 注册。状态同步和 SVG
    ; 注入会提前消耗无效区域，因此窗口首次显示后必须重新制造一次可见期
    ; 绘制；这与鼠标首次经过时触发的可靠刷新路径完全相同。
    return RedrawVisibleRoundedButtons([
        Main.btnAdd, Main.btnPause, Main.btnDel,
        Main.btnSet, Main.btnSupport, Main.btnAbout
    ])
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
    ShowMainGuiWithOptions()
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
