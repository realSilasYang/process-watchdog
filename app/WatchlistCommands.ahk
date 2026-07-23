RegisterApp(path, enabled := 1, runAsAdmin := 0, workingDirectory := "", arguments := "", environment := "", maintenanceConfig := "", storedResolvedTarget := "", resolvedTargetManual := false, shortcutArguments := "", displayConfig := "") {
    path := NormalizeTargetPath(path)
    if (path == "")
        return false
    ; 目录仅用于批量导入，不能作为可启动/可探活的单个目标。
    if DirExist(path)
        return false
    if App.appStates.Has(path)
        return false
    resolvedTarget := ""
    resolutionSource := ""
    SplitPath(path, , , &pathExtension)
    if (StrLower(pathExtension) == "lnk")
        resolvedTarget := App.shortcutTargetResolver.ResolveForState(path,
            storedResolvedTarget, &resolutionSource, resolvedTargetManual)
    if (StrLower(pathExtension) == "lnk" && FileExist(path)) {
        descriptor := App.shortcutTargetResolver.Read(path)
        if descriptor.Readable {
            if (shortcutArguments == "")
                shortcutArguments := descriptor.Arguments
            if (workingDirectory == "")
                workingDirectory := descriptor.WorkingDirectory
        }
    }
    identityTarget := resolvedTarget != "" ? resolvedTarget
        : (App.shortcutTargetResolver.IsPotentialProcessTarget(path)
            ? path : "")
    if App.targetIdentityService.FindConflict(identityTarget)
        return false
    normalizedMaintenance := App.maintenanceConfigCodec.Normalize(
        maintenanceConfig, path)
    if (StrLower(pathExtension) == "lnk" && resolvedTarget != "") {
        requestedMaintenance := false
        if (maintenanceConfig && Type(maintenanceConfig) == "Object"
            && maintenanceConfig.HasOwnProp("Enabled"))
            requestedMaintenance := !!maintenanceConfig.Enabled
        normalizedMaintenance.Enabled := requestedMaintenance
            && IsMaintenanceSupportedTarget(resolvedTarget)
        if (!normalizedMaintenance.RootIsCustom || normalizedMaintenance.InstallRoot == "") {
            SplitPath(resolvedTarget, , &resolvedDirectory)
            normalizedMaintenance.InstallRoot := NormalizeMaintenanceRoot(resolvedDirectory)
        }
    }
    fingerprintTarget := resolvedTarget != "" ? resolvedTarget : path
    currentFingerprint := App.targetFileInspector.GetFingerprint(
        fingerprintTarget)
    displayConfig := App.displayConfigCodec.Normalize(displayConfig)
    App.appStates[path] := TargetSupervisor({
        State: "初始化...", FailCount: 0, Pending: false, Enabled: enabled ? 1 : 0,
        TargetStartTicks: 0, RunAsAdmin: runAsAdmin ? 1 : 0, WorkDir: workingDirectory,
        Args: arguments, ShortcutArgs: shortcutArguments, EnvVars: environment,
        PID: 0, LastKnownPID: 0, PIDCreationIdentity: "", PIDImagePath: "",
        PIDElevationState: -1, PIDElevationChecked: false,
        LastKnownPIDCreationIdentity: "",
        ResolvedTarget: resolvedTarget, ShortcutTargetSource: resolutionSource,
        ResolvedTargetManual: !!resolvedTargetManual,
        ShortcutResolveCheckedTicks: GetTickCount64(),
        VerifyAttempts: 0,
        OneShot: IsOneShotTarget(path, resolvedTarget), MaintenanceConfig: normalizedMaintenance,
        MaintenanceMode: MaintenancePhase.Normal, MaintenanceStartedTicks: 0,
        MaintenanceStartedAt: "", MaintenanceLastActivityTicks: 0,
        MaintenanceRestartDueTicks: 0, MaintenanceBaselineFingerprint: currentFingerprint,
        ArbitrationSnapshotRequestTicks: 0, ArbitrationSignalBaselineTicks: 0,
        MaintenanceFileChanged: false, ExplicitMaintenance: false,
        MaintenanceWatcherRoot: "", MaintenanceWatcherPath: "", KnownActorIdentities: Map(),
        TransientActorIdentities: Map(), LastActorSeenTicks: 0, LastFileActivityTicks: 0,
        MaintenanceFingerprintCheckedTicks: 0,
        MaintenanceReadyCheckedTicks: 0, MaintenanceLastReady: true,
        SafetyFingerprint: currentFingerprint, SafetyStableSince: GetTickCount64(),
        MaintenanceLearningCandidates: Map(), MissingSinceTicks: 0,
        DisplayConfig: displayConfig, TargetSpecs: "", TargetSpecsFingerprint: "",
        Scheduler: App.scheduler
    })
    App.targetSpecsService.Get(path, App.appStates[path], true)
    App.appOrder.Push(path)
    if enabled
        App.maintenanceCoordinator.EnsureWatcher(path, App.appStates[path])
    try {
        stateObj := App.appStates[path]
        iconIdx := GetMainListIconIndex(path, stateObj, Main.lv.IL)
        statusText := enabled ? "初始化..." : "⏸️ 已暂停"
        row := Main.lv.Add("Icon" iconIdx,
            FormatMainListLabel(GetMainDisplayName(path, stateObj), runAsAdmin),
            FormatMainStatusLabel(statusText), path)
        Main.listProjection.Remember(path, row)
        SetMainListStatus(row, statusText)
        return true
    } catch as projectionErr {
        App.maintenanceCoordinator.CloseWatcher(App.appStates[path])
        App.appStates.Delete(path)
        RemoveAppOrderPath(path)
        LogMsg("添加监控项失败，已回滚内存状态: " projectionErr.Message)
        return false
    }
}

ToggleItemPause(*) {
    if (Main.lv.GetNext(0) == 0)
        return

    App.editSessionId++
    undoState := CaptureAppConfigState()
    row := 0
    changedAny := false

    Loop {
        row := Main.lv.GetNext(row)
        if (row == 0)
            break

        chkPath := Main.lv.GetText(row, 3)
        if App.appStates.Has(chkPath) {
            newState := !App.appStates[chkPath].Enabled
            App.appStates[chkPath].Enabled := newState
            if (!newState) {
                App.appStates[chkPath].CancelScheduledTasks()
                App.appStates[chkPath].TransitionTo(GuardPhase.Paused)
                App.maintenanceCoordinator.CleanupTarget(chkPath, App.appStates[chkPath], true)
                UpdateState(chkPath, "⏸️ 已暂停")
                App.appStates[chkPath].Pending := false
                App.appStates[chkPath].TargetStartTicks := 0
                App.appStates[chkPath].FailCount := 0
                ClearStateProcessIdentity(App.appStates[chkPath])
            } else {
                App.appStates[chkPath].CancelScheduledTasks()
                App.appStates[chkPath].TransitionTo(GuardPhase.Initializing)
                App.maintenanceCoordinator.ResetSession(chkPath, App.appStates[chkPath], false)
                App.maintenanceCoordinator.EnsureWatcher(chkPath, App.appStates[chkPath])
                App.appStates[chkPath].Pending := false
                App.appStates[chkPath].TargetStartTicks := 0
                App.appStates[chkPath].FailCount := 0
                ClearStateProcessIdentity(App.appStates[chkPath])
                UpdateState(chkPath, "初始化...")
            }
            LogMsg((newState ? "恢复" : "暂停") "守护: " chkPath)
            changedAny := true
        }
    }

    if (changedAny) {
        CommitUndoState(undoState)
        SaveAppsToIni()
        OnLVSelectChange() ; 刷新按钮显示状态
    }
    ControlFocus(Main.lv) ; 保持选中行使用活动焦点配色
}

OnDoubleClick(GuiCtrlObj, Item) {
    TriggerEdit(GuiCtrlObj, Item)
}

TriggerEdit(GuiCtrlObj, Item) {
    App.editSessionId++
    rows := []
    row := 0
    Loop {
        row := GuiCtrlObj.GetNext(row)
        if (!row)
            break
        rows.Push(row)
    }
    if (rows.Length == 0 && Item > 0)
        rows.Push(Item)

    if (rows.Length == 0)
        return

    App.batchEditRows := rows
    StartNextInlineEdit(GuiCtrlObj, App.editSessionId)
}

StartNextInlineEdit(GuiCtrlObj, sessionId := 0) {
    if (sessionId && sessionId != App.editSessionId)
        return
    if (App.batchEditRows.Length > 0) {
        Item := App.batchEditRows.RemoveAt(1)
        GuiCtrlObj.Opt("-ReadOnly")
        realPath := GuiCtrlObj.GetText(Item, 3)
        GuiCtrlObj.Modify(Item, "Col1", realPath) ; 临时变成真实路径
        SendMessage(0x1076, Item - 1, 0, GuiCtrlObj.Hwnd)

        App.editMonitorItem := Item
        hEdit := SendMessage(0x1018, 0, 0, GuiCtrlObj.Hwnd)
        if hEdit {
            SetDarkControl(hEdit)
            RegisterTextInputHwnd(hEdit)
            App.activeInlineEditHwnd := hEdit
        }
        SetTimer(CheckEditMonitor.Bind(GuiCtrlObj, sessionId), 100)
    }
}

CheckEditMonitor(GuiCtrlObj, sessionId := 0) {
    if (sessionId && sessionId != App.editSessionId) {
        SetTimer(, 0)
        hEdit := 0
        try hEdit := SendMessage(0x1018, 0, 0, GuiCtrlObj.Hwnd)
        if hEdit
            try SendMessage(0x0100, 27, 0, hEdit)
        if App.activeInlineEditHwnd {
            App.uiInteractions.RemoveTextInput(App.activeInlineEditHwnd)
            App.activeInlineEditHwnd := 0
        }
        try GuiCtrlObj.Opt("+ReadOnly")
        return
    }
    hEdit := SendMessage(0x1018, 0, 0, GuiCtrlObj.Hwnd)
    if (!hEdit) {
        SetTimer(, 0)
        if App.activeInlineEditHwnd {
            App.uiInteractions.RemoveTextInput(App.activeInlineEditHwnd)
            App.activeInlineEditHwnd := 0
        }
        GuiCtrlObj.Opt("+ReadOnly")
        SetTimer(ProcessEditFinish.Bind(GuiCtrlObj, App.editMonitorItem, sessionId), -50)
    }
}

ProcessEditFinish(GuiCtrlObj, Item, sessionId := 0) {
    if (sessionId && sessionId != App.editSessionId)
        return
    try {
        newPath := NormalizeTargetPath(GuiCtrlObj.GetText(Item, 1))
        previousPath := GuiCtrlObj.GetText(Item, 3)

        if (newPath != "" && newPath != previousPath) {
            prospectiveResolvedTarget := ""
            prospectiveResolutionSource := ""
            prospectiveShortcutArgs := ""
            prospectiveWorkingDirectory := ""
            SplitPath(newPath, , , &prospectiveExtension)
            if (StrLower(prospectiveExtension) == "lnk") {
                prospectiveResolvedTarget := App.shortcutTargetResolver
                    .ResolveForState(newPath, "", &prospectiveResolutionSource)
                descriptor := App.shortcutTargetResolver.Read(newPath)
                if descriptor.Readable {
                    prospectiveWorkingDirectory := descriptor.WorkingDirectory
                    prospectiveShortcutArgs := descriptor.Arguments
                }
            }
            prospectiveIdentity := prospectiveResolvedTarget != ""
                ? prospectiveResolvedTarget
                : (App.shortcutTargetResolver.IsPotentialProcessTarget(newPath)
                    ? newPath : "")
            identityConflict := App.targetIdentityService.FindConflict(
                prospectiveIdentity, previousPath)
            if DirExist(newPath) {
                newPath := previousPath
            } else if !App.appStates.Has(previousPath) {
                ; 状态已被其它操作移除时，不能只改 ListView 而留下无状态孤儿行。
                newPath := previousPath
            } else if App.appStates.Has(newPath) {
                LogMsg("拒绝将应用路径改为已存在的监控项: " newPath)
                newPath := previousPath
            } else if (identityConflict != "") {
                LogMsg("拒绝修改路径，真实进程已由其它项目守护: " identityConflict)
                newPath := previousPath
            } else {
                undoState := CaptureAppConfigState()
                stateObj := App.appStates[previousPath]
                stateObj.CancelScheduledTasks()
                App.maintenanceCoordinator.CleanupTarget(previousPath, stateObj, true)
                stateObj.Pending := false
                stateObj.TargetStartTicks := 0
                stateObj.FailCount := 0
                ClearStateProcessIdentity(stateObj)
                stateObj.VerifyAttempts := 0
                stateObj.ResolvedTarget := ""
                stateObj.ResolvedTargetManual := false
                stateObj.ShortcutTargetSource := ""
                stateObj.ShortcutArgs := ""
                SplitPath(newPath, , , &newExtension)
                if (StrLower(newExtension) == "lnk") {
                    stateObj.ResolvedTarget := prospectiveResolvedTarget
                    stateObj.ShortcutTargetSource := prospectiveResolutionSource
                    stateObj.ShortcutArgs := prospectiveShortcutArgs
                    if (prospectiveWorkingDirectory != "")
                        stateObj.WorkDir := prospectiveWorkingDirectory
                }
                stateObj.ShortcutResolveCheckedTicks := GetTickCount64()
                stateObj.OneShot := IsOneShotTarget(newPath, stateObj.ResolvedTarget)
                App.targetSpecsService.Get(newPath, stateObj, true)
                stateObj.MaintenanceConfig := App.maintenanceConfigCodec.Normalize(
                    stateObj.MaintenanceConfig, newPath)
                fingerprintTarget := stateObj.ResolvedTarget != "" ? stateObj.ResolvedTarget : newPath
                stateObj.MaintenanceBaselineFingerprint := App
                    .targetFileInspector.GetFingerprint(fingerprintTarget)
                stateObj.SafetyFingerprint := stateObj.MaintenanceBaselineFingerprint
                stateObj.SafetyStableSince := GetTickCount64()
                stateObj.KnownActorIdentities := Map()
                stateObj.TransientActorIdentities := Map()
                stateObj.LastActorSeenTicks := 0
                stateObj.LastFileActivityTicks := 0
                stateObj.State := "初始化..."
                stateObj.TransitionTo(GuardPhase.Initializing)
                App.appStates.Delete(previousPath)
                App.appStates[newPath] := stateObj
                ReplaceAppOrderPath(previousPath, newPath)
                App.maintenanceCoordinator.EnsureWatcher(newPath, stateObj)
                GuiCtrlObj.Modify(Item, "Col3", newPath)
                SetMainListStatus(Item, "初始化...")
                iconIdx := GetMainListIconIndex(newPath, stateObj, GuiCtrlObj.IL)
                if iconIdx
                    GuiCtrlObj.Modify(Item, "Icon" iconIdx)
                Main.listProjection.Rebuild(GuiCtrlObj)
                CommitUndoState(undoState)
                SaveAppsToIni()
                LogMsg("更新了应用程序路径。")
            }
        }

        realPath := GuiCtrlObj.GetText(Item, 3)
        stateObj := App.appStates.Has(realPath) ? App.appStates[realPath] : ""
        isAdmin := stateObj && stateObj.HasOwnProp("RunAsAdmin") ? stateObj.RunAsAdmin : 0
        GuiCtrlObj.Modify(Item, "Col1", FormatMainListLabel(
            GetMainDisplayName(realPath, stateObj), isAdmin)) ; 恢复显示应用名
    } catch {
        realPath := GuiCtrlObj.GetText(Item, 3)
        stateObj := App.appStates.Has(realPath) ? App.appStates[realPath] : ""
        isAdmin := stateObj && stateObj.HasOwnProp("RunAsAdmin") ? stateObj.RunAsAdmin : 0
        GuiCtrlObj.Modify(Item, "Col1", FormatMainListLabel(
            GetMainDisplayName(realPath, stateObj), isAdmin))
    }
    StartNextInlineEdit(GuiCtrlObj, sessionId)
}

CaptureAppConfigState() {
    state := []
    try {
        Loop Main.lv.GetCount() {
            savePath := Main.lv.GetText(A_Index, 3)
            stateObj := App.appStates.Has(savePath)
                ? App.appStates[savePath] : ""
            snapshot := App.appConfigSnapshotService.CreateSnapshot(savePath,
                stateObj)
            if !snapshot
                throw Error("监控项路径无效: " savePath)
            state.Push(snapshot)
        }
    } catch as snapshotError {
        LogMsg("捕获监控项历史失败: " snapshotError.Message)
        return ""
    }
    return state
}

AppConfigStateOrderMatchesCurrent(state) {
    if (Type(state) != "Array" || state.Length != Main.lv.GetCount())
        return false
    for index, item in state {
        if !item.HasOwnProp("Path")
            return false
        if !PathsEquivalent(item.Path, Main.lv.GetText(index, 3))
            return false
    }
    return true
}

CommitUndoState(beforeState) {
    if (Type(beforeState) != "Array")
        return false
    afterState := CaptureAppConfigState()
    return App.appConfigHistoryService.Commit(beforeState, afterState)
}

PerformUndo() {
    if App.appConfigHistoryService.Undo(
        (targetState, sourceState) => ApplyState(targetState, sourceState))
        LogMsg("已撤销上一步操作。")
}

PerformRedo() {
    if App.appConfigHistoryService.Redo(
        (targetState, sourceState) => ApplyState(targetState, sourceState))
        LogMsg("已重做操作。")
}

CaptureMainListInteraction() {
    selectedPaths := Map()
    selectedPaths.CaseSense := "Off"
    row := 0
    Loop {
        row := Main.lv.GetNext(row)
        if !row
            break
        selectedPaths[Main.lv.GetText(row, 3)] := true
    }
    focusedRow := Main.lv.GetNext(0, "Focused")
    return {
        SelectedPaths: selectedPaths,
        FocusedPath: focusedRow ? Main.lv.GetText(focusedRow, 3) : "",
        HadKeyboardFocus: DllCall("user32\GetFocus", "Ptr") == Main.lv.Hwnd
    }
}

RestoreMainListInteraction(interaction) {
    Main.lv.Modify(0, "-Select -Focus")
    focusRow := 0
    firstSelectedRow := 0
    Loop Main.lv.GetCount() {
        path := Main.lv.GetText(A_Index, 3)
        if interaction.SelectedPaths.Has(path) {
            Main.lv.Modify(A_Index, "Select")
            if !firstSelectedRow
                firstSelectedRow := A_Index
        }
        if (interaction.FocusedPath != "" && PathsEquivalent(path, interaction.FocusedPath))
            focusRow := A_Index
    }
    if !focusRow
        focusRow := firstSelectedRow
    if focusRow
        Main.lv.Modify(focusRow, "Focus")
    if interaction.HadKeyboardFocus
        ControlFocus(Main.lv)
}

ApplyAppConfigTransition(path, stateObj, sourceItem, targetItem) {
    currentResolvedTarget := NormalizeTargetPath(stateObj.ResolvedTarget)
    currentResolvedTargetManual := !!stateObj.ResolvedTargetManual
    identityTransition := !PathsEquivalent(sourceItem.ResolvedTarget,
        targetItem.ResolvedTarget)
        || !!sourceItem.ResolvedTargetManual != !!targetItem.ResolvedTargetManual
    identityChanged := identityTransition
        && PathsEquivalent(currentResolvedTarget, sourceItem.ResolvedTarget)
        && currentResolvedTargetManual == !!sourceItem.ResolvedTargetManual
    nextResolvedTarget := identityChanged ? targetItem.ResolvedTarget
        : currentResolvedTarget
    nextResolvedTargetManual := identityChanged ? !!targetItem.ResolvedTargetManual
        : currentResolvedTargetManual
    enabledChanged := !!sourceItem.Enabled != !!targetItem.Enabled
        && !!stateObj.Enabled == !!sourceItem.Enabled
    nextEnabled := enabledChanged ? !!targetItem.Enabled : !!stateObj.Enabled

    previousMaintenance := App.maintenanceConfigCodec.NormalizeSnapshot(
        stateObj.MaintenanceConfig, path, currentResolvedTarget)
    nextMaintenance := App.appConfigSnapshotService
        .MergeMaintenanceTransition(previousMaintenance,
            sourceItem.Maintenance, targetItem.Maintenance,
            !identityTransition || identityChanged)
    nextDisplay := App.appConfigSnapshotService.MergeDisplayTransition(
        stateObj.HasOwnProp("DisplayConfig") ? stateObj.DisplayConfig : "",
        sourceItem.Display, targetItem.Display)
    maintenanceChanged := !App.maintenanceConfigCodec.Equals(
        previousMaintenance, nextMaintenance)
    maintenanceRootChanged := !PathsEquivalent(previousMaintenance.InstallRoot,
        nextMaintenance.InstallRoot)
    previousProtectionEnabled := previousMaintenance.Enabled

    if (identityChanged || enabledChanged) {
        stateObj.CancelScheduledTasks()
        App.maintenanceCoordinator.CleanupTarget(path, stateObj, false)
    } else if (maintenanceChanged && previousProtectionEnabled
        && !nextMaintenance.Enabled) {
        App.maintenanceCoordinator.CleanupTarget(path, stateObj, false)
    } else if (maintenanceChanged && maintenanceRootChanged) {
        App.maintenanceCoordinator.CloseWatcher(stateObj)
    }

    if (!!sourceItem.RunAsAdmin != !!targetItem.RunAsAdmin
        && !!stateObj.RunAsAdmin == !!sourceItem.RunAsAdmin)
        stateObj.RunAsAdmin := targetItem.RunAsAdmin
    for propertyName in ["WorkDir", "Args", "ShortcutArgs", "EnvVars"] {
        if (sourceItem.%propertyName% != targetItem.%propertyName%
            && stateObj.%propertyName% == sourceItem.%propertyName%)
            stateObj.%propertyName% := targetItem.%propertyName%
    }
    stateObj.ResolvedTarget := nextResolvedTarget
    stateObj.ResolvedTargetManual := nextResolvedTargetManual
    stateObj.MaintenanceConfig := nextMaintenance
    stateObj.DisplayConfig := nextDisplay

    if identityChanged {
        stateObj.ShortcutTargetSource := nextResolvedTarget == "" ? ""
            : (nextResolvedTargetManual ? "用户指定" : "已保存身份")
        stateObj.ShortcutResolveCheckedTicks := GetTickCount64()
        stateObj.OneShot := IsOneShotTarget(path, nextResolvedTarget)
    }

    stateObj.Enabled := nextEnabled ? 1 : 0
    App.targetSpecsService.Get(path, stateObj, true)
    if (identityChanged || enabledChanged) {
        stateObj.Pending := false
        stateObj.TargetStartTicks := 0
        stateObj.FailCount := 0
        stateObj.VerifyAttempts := 0
        ClearStateProcessIdentity(stateObj)
        fingerprintTarget := nextResolvedTarget != "" ? nextResolvedTarget : path
        refreshedFingerprint := App.targetFileInspector.GetFingerprint(
            fingerprintTarget)
        stateObj.MaintenanceBaselineFingerprint := refreshedFingerprint
        stateObj.SafetyFingerprint := refreshedFingerprint
        stateObj.SafetyStableSince := GetTickCount64()
        stateObj.MaintenanceFingerprintCheckedTicks := 0
        stateObj.MaintenanceReadyCheckedTicks := 0
        stateObj.State := nextEnabled ? "初始化..." : "⏸️ 已暂停"
        stateObj.TransitionTo(nextEnabled ? GuardPhase.Initializing
            : GuardPhase.Paused)
        if nextEnabled
            App.maintenanceCoordinator.EnsureWatcher(path, stateObj)
        else
            App.maintenanceCoordinator.CloseWatcher(stateObj)
    } else if maintenanceChanged {
        if nextMaintenance.Enabled
            App.maintenanceCoordinator.EnsureWatcher(path, stateObj)
        else
            App.maintenanceCoordinator.CloseWatcher(stateObj)
        if (previousProtectionEnabled && !nextMaintenance.Enabled && stateObj.Enabled) {
            stateObj.State := "初始化..."
            stateObj.TransitionTo(GuardPhase.Initializing)
            App.guardRuntime.ScheduleRestart(path, 200)
        }
    }
    return {
        JournalChanged: identityChanged || enabledChanged
            || (maintenanceChanged && previousProtectionEnabled
                && !nextMaintenance.Enabled)
    }
}

SyncMainListToConfigState(items) {
    targetPaths := Map()
    targetPaths.CaseSense := "Off"
    for item in items
        targetPaths[item.Path] := true

    seenRows := Map()
    seenRows.CaseSense := "Off"
    row := Main.lv.GetCount()
    while (row > 0) {
        path := Main.lv.GetText(row, 3)
        if !targetPaths.Has(path) || seenRows.Has(path)
            Main.lv.Delete(row)
        else
            seenRows[path] := true
        row--
    }
    Main.listProjection.Rebuild(Main.lv)

    projectedRow := 0
    for item in items {
        if !App.appStates.Has(item.Path)
            continue
        projectedRow++
        currentRow := 0
        if (projectedRow <= Main.lv.GetCount()
            && StrLower(Main.lv.GetText(projectedRow, 3)) == StrLower(item.Path))
            currentRow := projectedRow
        else
            currentRow := FindRow(item.Path)
        stateObj := App.appStates[item.Path]
        displayName := FormatMainListLabel(
            GetMainDisplayName(item.Path, stateObj), stateObj.RunAsAdmin)
        displayStatus := FormatMainStatusLabel(stateObj.State)
        if (currentRow != projectedRow) {
            if currentRow
                Main.lv.Delete(currentRow)
            iconIndex := GetMainListIconIndex(item.Path, stateObj, Main.lv.IL)
            insertedRow := Main.lv.Insert(projectedRow, "Icon" iconIndex,
                displayName, displayStatus, item.Path)
            SetMainListStatus(insertedRow, stateObj.State)
        } else {
            if (Main.lv.GetText(currentRow, 1) != displayName)
                Main.lv.Modify(currentRow, "Col1", displayName)
            if (Main.lv.GetText(currentRow, 2) != displayStatus)
                SetMainListStatus(currentRow, stateObj.State)
            iconIndex := GetMainListIconIndex(item.Path, stateObj, Main.lv.IL)
            if iconIndex
                Main.lv.Modify(currentRow, "Icon" iconIndex)
        }
    }

    App.appOrder := []
    for item in items {
        if App.appStates.Has(item.Path)
            App.appOrder.Push(item.Path)
    }
    Main.listProjection.Rebuild(Main.lv)
}

ApplyState(stateArr, sourceStateArr := "") {
    App.editSessionId++
    App.batchEditRows := []
    App.editMonitorItem := 0
    Main.contextTargetRow := 0
    currentState := CaptureAppConfigState()
    preparedState := App.appConfigSnapshotService.PrepareState(stateArr)
    sourceState := App.appConfigSnapshotService.PrepareState(sourceStateArr)
    isTransition := Type(sourceStateArr) == "Array"
    interaction := CaptureMainListInteraction()
    Main.lv.Opt("-Redraw")
    try {
        journalChanged := false
        pathsToRemove := []
        if isTransition {
            for sourcePath, sourceItem in sourceState.Index {
                if !preparedState.Index.Has(sourcePath) && App.appStates.Has(sourcePath)
                    pathsToRemove.Push(sourcePath)
            }
        } else {
            for existingPath, existingState in App.appStates {
                if !preparedState.Index.Has(existingPath)
                    pathsToRemove.Push(existingPath)
            }
        }
        for existingPath in pathsToRemove {
            existingState := App.appStates[existingPath]
            existingState.CancelScheduledTasks()
            App.maintenanceCoordinator.CleanupTarget(existingPath, existingState, false)
            App.appStates.Delete(existingPath)
            journalChanged := true
        }

        for item in preparedState.Items {
            if !App.appStates.Has(item.Path)
                continue
            if (isTransition && sourceState.Index.Has(item.Path)) {
                sourceItem := sourceState.Index[item.Path]
                if !App.appConfigSnapshotService.SnapshotsEqual(sourceItem,
                    item) {
                    transitionResult := ApplyAppConfigTransition(item.Path,
                        App.appStates[item.Path],
                        sourceItem, item)
                    journalChanged := journalChanged || transitionResult.JournalChanged
                }
            } else if !isTransition {
                currentItem := App.appConfigSnapshotService.CreateSnapshot(
                    item.Path, App.appStates[item.Path])
                transitionResult := ApplyAppConfigTransition(item.Path,
                    App.appStates[item.Path],
                    currentItem, item)
                journalChanged := journalChanged || transitionResult.JournalChanged
            }
        }
        for item in preparedState.Items {
            shouldAdd := !App.appStates.Has(item.Path)
                && (!isTransition || !sourceState.Index.Has(item.Path))
            if shouldAdd {
                RegisterApp(item.Path, item.Enabled, item.RunAsAdmin, item.WorkDir, item.Args,
                    item.EnvVars, item.Maintenance, item.ResolvedTarget,
                    item.ResolvedTargetManual, item.ShortcutArgs, item.Display)
            }
        }
        projectedItems := isTransition
            ? App.appConfigSnapshotService.MergeTransitionOrder(currentState,
                sourceState.Items, preparedState.Items)
            : preparedState.Items
        SyncMainListToConfigState(projectedItems)
        if journalChanged
            App.maintenanceCoordinator.SaveJournal()
        SaveAppsToIni()
    } finally {
        try Main.lv.Opt("+Redraw")
        try RestoreMainListInteraction(interaction)
    }
    OnLVSelectChange()
}

SaveAppsToIni() {
    static isSaving := false
    previousCritical := A_IsCritical
    Critical("On")
    if isSaving {
        Critical(previousCritical ? previousCritical : "Off")
        return false
    }
    isSaving := true
    try {
        saveResult := App.watchlistPersistenceService.Save(App.appOrder,
            App.appStates, App.configRecoveryEntries)
        App.appOrder := saveResult.OrderedPaths
        App.appsDirty := false
        App.configSaveRetryDelayMs := 5000
        try SetTimer(App.configSaveRetryTimer, 0)
        return true
    } catch as saveErr {
        App.appsDirty := true
        LogMsg("保存监控配置失败: " saveErr.Message)
        nowTicks := GetTickCount64()
        if (nowTicks - App.lastSaveWarningTicks > 10000) {
            try TrayTip("监控配置尚未保存，请查看运行日志。", "进程守护小助手", 3)
            App.lastSaveWarningTicks := nowTicks
        }
        retryDelayMs := App.configSaveRetryDelayMs
        App.configSaveRetryDelayMs := Min(retryDelayMs * 2, 60000)
        try SetTimer(App.configSaveRetryTimer, -retryDelayMs)
        return false
    } finally {
        isSaving := false
        Critical(previousCritical ? previousCritical : "Off")
    }
}

SyncAppOrderFromListView() {
    newOrder := []
    Loop Main.lv.GetCount() {
        path := Main.lv.GetText(A_Index, 3)
        if App.appStates.Has(path)
            newOrder.Push(path)
    }
    App.appOrder := newOrder
}

RemoveAppOrderPath(path) {
    for index, existingPath in App.appOrder {
        if PathsEquivalent(existingPath, path) {
            App.appOrder.RemoveAt(index)
            return true
        }
    }
    return false
}
ReplaceAppOrderPath(previousPath, newPath) {
    for index, existingPath in App.appOrder {
        if PathsEquivalent(existingPath, previousPath) {
            App.appOrder[index] := newPath
            return true
        }
    }
    App.appOrder.Push(newPath)
    return false
}
