; 主窗口守护列表的命令与配置投影。
; 添加、编辑、暂停、撤销和重做都先更新受控的运行态，再以差量方式同步列表与配置；
; 路径始终保存在隐藏身份列中，显示名称、图标和状态文案不参与目标身份判断。

GetGuardActivationStatus(enabled) {
    return enabled ? Tr("初始化...") : Tr("⏸️ 已暂停")
}

GetGuardActivationStatusKind(enabled) {
    return enabled ? GuardStatusKind.Initializing : GuardStatusKind.Paused
}

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
    initialStatus := GetGuardActivationStatus(enabled)
    stateObj := TargetSupervisor({
        State: initialStatus, StatusKind: GetGuardActivationStatusKind(enabled),
        FailCount: 0, Pending: false,
        Enabled: enabled ? 1 : 0,
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
        TransientActorIdentities: Map(), LastActorSeenTicks: 0,
        MaintenanceActorCheckedTicks: 0, LastFileActivityTicks: 0,
        MaintenanceFingerprintCheckedTicks: 0,
        MaintenanceReadyCheckedTicks: 0, MaintenanceLastReady: true,
        SafetyFingerprint: currentFingerprint, SafetyStableSince: GetTickCount64(),
        MaintenanceLearningCandidates: Map(), MissingSinceTicks: 0,
        DisplayConfig: displayConfig, TargetSpecs: "", TargetSpecsFingerprint: "",
        Scheduler: App.scheduler
    })
    App.appStates[path] := stateObj
    try {
        App.targetSpecsService.Get(path, stateObj, true)
        App.appOrder.Push(path)
        if enabled
            App.maintenanceCoordinator.EnsureWatcher(path, stateObj)
        iconIdx := GetMainListIconIndex(path, stateObj, Main.lv.IL)
        row := Main.lv.Add("Icon" iconIdx,
            FormatMainListLabel(GetMainDisplayName(path, stateObj), runAsAdmin),
            FormatMainStatusLabel(initialStatus), path, Main.lv.GetCount() + 1)
        Main.listProjection.Remember(path, row)
        SetMainListStatus(row, initialStatus)
        SetMainListAdminOverlay(row, runAsAdmin)
        ScheduleMainListTemporarySortRefresh()
        return true
    } catch as projectionErr {
        App.maintenanceCoordinator.CloseWatcher(stateObj)
        if App.appStates.Has(path) && App.appStates[path] == stateObj
            App.appStates.Delete(path)
        RemoveAppOrderPath(path)
        row := Main.lv.GetCount()
        while row > 0 {
            try {
                if PathsEquivalent(Main.lv.GetText(row, 3), path)
                    Main.lv.Delete(row)
            }
            row--
        }
        try Main.listProjection.Rebuild(Main.lv)
        try Main.listProjection.RefreshSequenceFromOrder(Main.lv, App.appOrder)
        try RefreshMainStatusSortKeys()
        LogMsg(Tr("添加监控项失败，已回滚内存状态：{1}",
            TrDiagnostic(projectionErr.Message)))
        return false
    }
}

HandleGuardMutationError(operationError, description := "") {
    LogMsg(Tr("保存监控配置失败：{1}",
        TrDiagnostic(operationError.Message)))
}

QueueGuardMutation(callback, description := "") {
    if App.shutdownStarted
        return false
    queued := App.guardMutationQueue.Enqueue(callback, description)
    return queued
}

QueueExclusiveGuardMutation(owner, operationKey, callback,
    description := "") {
    if App.shutdownStarted
        return false
    return App.guardMutationQueue.EnqueueExclusive(owner, operationKey,
        callback, description)
}

CaptureSelectedWatchPaths(includeContextTarget := false) {
    paths := []
    seen := Map()
    seen.CaseSense := "Off"
    row := 0
    Loop {
        row := Main.lv.GetNext(row)
        if !row
            break
        rawPath := Main.lv.GetText(row, 3)
        if !App.appStates.Has(rawPath)
            continue
        path := NormalizeTargetPath(rawPath)
        if path != "" && App.appStates.Has(path) && !seen.Has(path) {
            seen[path] := true
            paths.Push(path)
        }
    }
    if !paths.Length && includeContextTarget && Main.contextTargetRow > 0 {
        path := NormalizeTargetPath(
            Main.lv.GetText(Main.contextTargetRow, 3))
        if path != "" && App.appStates.Has(path)
            paths.Push(path)
    }
    return paths
}

ToggleItemPause(*) {
    paths := CaptureSelectedWatchPaths()
    if !paths.Length
        return
    QueueGuardMutation(ToggleItemPauseCore.Bind(paths))
}

ToggleItemPauseCore(paths) {
    App.editSessionId++
    undoState := CaptureAppConfigState()
    changedAny := false

    for chkPath in paths {
        if App.appStates.Has(chkPath) {
            stateObj := App.appStates[chkPath]
            newEnabled := !stateObj.Enabled
            stateObj.Enabled := newEnabled
            stateObj.CancelScheduledTasks()
            operationGeneration := stateObj.Generation
            stateObj.ResetGuardAttemptState()
            ClearStateProcessIdentity(stateObj)
            if (!newEnabled) {
                stateObj.TransitionTo(GuardPhase.Paused)
                ; 强制同步一次投影：这也能自愈旧版本曾产生的“控制器文本是
                ; 初始化、列表文本却是已暂停”分裂状态。
                UpdateState(chkPath, GetGuardActivationStatus(false),
                    stateObj, operationGeneration, true,
                    GuardStatusKind.Paused)
                App.maintenanceCoordinator.CleanupTarget(chkPath,
                    stateObj, false)
            } else {
                stateObj.TransitionTo(GuardPhase.Initializing)
                UpdateState(chkPath, GetGuardActivationStatus(true),
                    stateObj, operationGeneration, true,
                    GuardStatusKind.Initializing)
                App.maintenanceCoordinator.ResetSession(chkPath, stateObj,
                    false)
                App.maintenanceCoordinator.EnsureWatcher(chkPath, stateObj)
            }
            LogMsg(newEnabled ? Tr("恢复守护：{1}", chkPath)
                : Tr("暂停守护：{1}", chkPath))
            changedAny := true
        }
    }

    if (changedAny) {
        App.maintenanceCoordinator.SaveJournal()
        CommitUndoState(undoState,
            CreateAppHistoryAction("toggle-pause", paths))
        SaveAppsToIni()
        OnLVSelectChange() ; 刷新按钮显示状态
    }
    try ControlFocus(Main.lv) ; 保持选中行使用活动焦点配色
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
        if App.appStates.Has(GuiCtrlObj.GetText(row, 3))
            rows.Push(row)
    }
    if (rows.Length == 0 && Item > 0
            && App.appStates.Has(GuiCtrlObj.GetText(Item, 3)))
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
    if !App.guardWorkGate.TryEnter() {
        SetTimer(ProcessEditFinish.Bind(GuiCtrlObj, Item, sessionId), -25)
        return
    }
    try ProcessEditFinishCore(GuiCtrlObj, Item, sessionId)
    finally App.guardWorkGate.Leave()
}

ProcessEditFinishCore(GuiCtrlObj, Item, sessionId := 0) {
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
                LogMsg(Tr("拒绝将应用路径改为已存在的监控项：{1}", newPath))
                newPath := previousPath
            } else if (identityConflict != "") {
                LogMsg(Tr("拒绝修改路径，真实进程已由其它项目守护：{1}",
                    identityConflict))
                newPath := previousPath
            } else {
                undoState := CaptureAppConfigState()
                if Type(undoState) != "Array"
                    throw Error(Tr("监控项路径无效：{1}", previousPath))
                targetState := App.appConfigSnapshotService
                    .PrepareState(undoState).Items
                pathChanged := false
                for targetItem in targetState {
                    if !PathsEquivalent(targetItem.Path, previousPath)
                        continue
                    targetItem.Path := newPath
                    targetItem.ResolvedTarget := prospectiveResolvedTarget
                    targetItem.ResolvedTargetManual := false
                    targetItem.ShortcutArgs := prospectiveShortcutArgs
                    if (prospectiveWorkingDirectory != "")
                        targetItem.WorkDir := prospectiveWorkingDirectory
                    targetItem.Maintenance := App.maintenanceConfigCodec
                        .NormalizeSnapshot(targetItem.Maintenance, newPath,
                            prospectiveResolvedTarget)
                    pathChanged := true
                    break
                }
                if !pathChanged
                    throw Error(Tr("监控项路径无效：{1}", previousPath))
                ApplyState(targetState, undoState)
                App.appConfigHistoryService.Commit(undoState, targetState,
                    CreateAppHistoryAction("edit-path",
                        [previousPath, newPath]))
                LogMsg(Tr("已更新应用程序路径。"))
            }
        }

        realPath := GuiCtrlObj.GetText(Item, 3)
        stateObj := App.appStates.Has(realPath) ? App.appStates[realPath] : ""
        isAdmin := stateObj && stateObj.HasOwnProp("RunAsAdmin") ? stateObj.RunAsAdmin : 0
        GuiCtrlObj.Modify(Item, "Col1", FormatMainListLabel(
            GetMainDisplayName(realPath, stateObj), isAdmin)) ; 恢复显示应用名
    } catch as editError {
        LogMsg(Tr("保存监控配置失败：{1}",
            TrDiagnostic(editError.Message)))
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
            if !App.appStates.Has(savePath)
                continue
            stateObj := App.appStates[savePath]
            snapshot := App.appConfigSnapshotService.CreateSnapshot(savePath,
                stateObj)
            if !snapshot
                throw Error(Tr("监控项路径无效：{1}", savePath))
            state.Push(snapshot)
        }
    } catch as snapshotError {
        LogMsg(Tr("捕获监控项历史失败：{1}",
            TrDiagnostic(snapshotError.Message)))
        return ""
    }
    return state
}

AppConfigStateOrderMatchesCurrent(state) {
    if Type(state) != "Array"
        return false
    currentPaths := []
    Loop Main.lv.GetCount() {
        path := Main.lv.GetText(A_Index, 3)
        if App.appStates.Has(path)
            currentPaths.Push(path)
    }
    if state.Length != currentPaths.Length
        return false
    for index, item in state {
        if !item.HasOwnProp("Path")
            return false
        if !PathsEquivalent(item.Path, currentPaths[index])
            return false
    }
    return true
}

CreateAppHistoryAction(kind, paths := "", fields := "") {
    normalizedPaths := []
    if Type(paths) == "Array" {
        for path in paths
            normalizedPaths.Push(path)
    } else if paths != "" {
        normalizedPaths.Push(paths)
    }
    normalizedFields := []
    if Type(fields) == "Array" {
        for field in fields
            normalizedFields.Push(field)
    }
    return {Kind: kind, Paths: normalizedPaths, Fields: normalizedFields}
}

CommitUndoState(beforeState, action := "") {
    if (Type(beforeState) != "Array")
        return false
    afterState := CaptureAppConfigState()
    return App.appConfigHistoryService.Commit(beforeState, afterState, action)
}

CloneRuntimeSettingsHistoryState(settings) {
    clone := {}
    for propertyName in ["UiLanguage", "UiFont", "Theme", "CheckInterval",
            "RetrySequence", "ShowAtStartup", "CheckUpdatesOnStartup",
            "RecursiveBatchImport", "LogMaxEntries", "LogDirectory",
            "LogRetentionDays", "ClearLogsOnStartup", "GracefulStopSeconds",
            "CtrlCWaitSeconds", "AllowForceTerminate"]
        clone.%propertyName% := settings.%propertyName%
    clone.RetryDelayArray := []
    for delay in settings.RetryDelayArray
        clone.RetryDelayArray.Push(delay)
    return clone
}

GetRuntimeSettingsHistoryFields(beforeState, afterState) {
    fieldSpecs := [
        {Property: "UiLanguage", Label: "界面语言："},
        {Property: "UiFont", Label: "界面内容字体："},
        {Property: "Theme", Label: "主题："},
        {Property: "ShowAtStartup", Label: "启动时显示主窗口"},
        {Property: "CheckUpdatesOnStartup", Label: "启动时检查小助手更新"},
        {Property: "CheckInterval", Label: "进程状态检查间隔（毫秒）："},
        {Property: "RetrySequence", Label: "崩溃自动重启延迟序列（秒）："},
        {Property: "RecursiveBatchImport", Label: "导入文件夹时包含子目录"},
        {Property: "GracefulStopSeconds", Label: "GUI 程序关闭超时（秒）："},
        {Property: "CtrlCWaitSeconds", Label: "CLI 程序关闭超时（秒）："},
        {Property: "AllowForceTerminate", Label: "正常关闭超时后允许强制终止"},
        {Property: "LogMaxEntries", Label: "运行日志显示上限（条）："},
        {Property: "LogDirectory", Label: "批处理日志保存路径："},
        {Property: "LogRetentionDays", Label: "批处理日志保留天数："},
        {Property: "ClearLogsOnStartup", Label: "启动时清空批处理日志"}
    ]
    changedFields := []
    for fieldSpec in fieldSpecs {
        propertyName := fieldSpec.Property
        if beforeState.%propertyName% != afterState.%propertyName%
            changedFields.Push(fieldSpec.Label)
    }
    return changedFields
}

CommitRuntimeSettingsUndoState(beforeState, afterState) {
    fields := GetRuntimeSettingsHistoryFields(beforeState, afterState)
    if !fields.Length
        return false
    return App.appConfigHistoryService.CommitCustom(
        CloneRuntimeSettingsHistoryState(beforeState),
        CloneRuntimeSettingsHistoryState(afterState),
        ApplyRuntimeSettingsHistoryTransition,
        CreateAppHistoryAction("runtime-settings", "", fields))
}

ApplyRuntimeSettingsSnapshot(settings) {
    priorInterval := App.checkInterval
    displayChanged := settings.UiLanguage != App.uiLanguage
        || settings.UiFont != App.uiFont || settings.Theme != App.uiTheme
    if displayChanged
        ApplyDisplaySettingsHot(settings.UiLanguage, settings.UiFont,
            settings.Theme)
    App.runtimeSettingsService.Apply(App, settings)
    while (App.logMessages.Length > App.logMaxEntries)
        App.logMessages.Pop()
    if App.checkInterval != priorInterval
        App.guardRuntime.RestartMonitorTimer()
}

ApplyRuntimeSettingsHistoryTransition(targetState, sourceState) {
    try {
        savedTarget := App.runtimeSettingsService.Save(targetState)
        ApplyRuntimeSettingsSnapshot(savedTarget)
    } catch as applyError {
        try {
            restoredSource := App.runtimeSettingsService.Save(sourceState)
            ApplyRuntimeSettingsSnapshot(restoredSource)
        } catch as rollbackError {
            throw Error(applyError.Message " | " rollbackError.Message)
        }
        throw applyError
    }
    return true
}

FindHistorySnapshot(items, path) {
    if Type(items) != "Array"
        return ""
    for item in items {
        if item.HasOwnProp("Path") && PathsEquivalent(item.Path, path)
            return item
    }
    return ""
}

GetHistoryTargetName(entry, path) {
    for items in [entry.After, entry.Before] {
        item := FindHistorySnapshot(items, path)
        if !item
            continue
        if item.HasOwnProp("Display") && IsObject(item.Display)
            && item.Display.HasOwnProp("Name") && Trim(item.Display.Name) != ""
            return Trim(item.Display.Name)
    }
    return GetDefaultMainDisplayName(path)
}

FormatHistoryTargetList(entry, paths) {
    if Type(paths) != "Array" || !paths.Length
        return ""
    names := []
    maximumNames := Min(paths.Length, 3)
    Loop maximumNames
        names.Push(GetHistoryTargetName(entry, paths[A_Index]))
    language := LocalizationService.GetLanguage()
    separator := RegExMatch(language, "^(?:zh-|ja-JP)") ? "、" : ", "
    text := ""
    for index, name in names
        text .= (index > 1 ? separator : "") name
    if paths.Length > maximumNames
        text .= "…（" paths.Length "）"
    return text
}

GetHistoryPauseActionLabel(entry, paths) {
    enabledValue := -1
    mixed := false
    for path in paths {
        item := FindHistorySnapshot(entry.After, path)
        if !item || !item.HasOwnProp("Enabled")
            continue
        currentEnabled := !!item.Enabled
        if enabledValue == -1
            enabledValue := currentEnabled
        else if enabledValue != currentEnabled
            mixed := true
    }
    if mixed || enabledValue == -1
        return Tr("反转状态")
    return enabledValue ? Tr("恢复") : Tr("暂停")
}

FormatHistoryAction(entry) {
    action := entry.HasOwnProp("Action") && IsObject(entry.Action)
        ? entry.Action : CreateAppHistoryAction("config")
    paths := action.HasOwnProp("Paths") ? action.Paths : []
    targetText := FormatHistoryTargetList(entry, paths)
    switch action.Kind {
        case "add": label := Tr("添加监控项")
        case "delete": label := Tr("删除")
        case "toggle-pause": label := GetHistoryPauseActionLabel(entry, paths)
        case "edit-path": label := Tr("编辑完整路径")
        case "reorder": label := Tr("调整守护顺序")
        case "run-as-admin": label := Tr("管理员运行状态")
        case "display": label := Tr("自定义名称和图标")
        case "environment": label := Tr("进程识别与启动设置")
        case "maintenance": label := Tr("软件升级保护")
        case "runtime-settings":
            label := Tr("小助手设置")
            fieldLabels := []
            if action.HasOwnProp("Fields") {
                actionFields := action.Fields
                for fieldKey in actionFields
                    fieldLabels.Push(RTrim(Tr(fieldKey), "：: "))
            }
            targetText := ""
            language := LocalizationService.GetLanguage()
            separator := RegExMatch(language, "^(?:zh-|ja-JP)") ? "、" : ", "
            for index, fieldLabel in fieldLabels
                targetText .= (index > 1 ? separator : "") fieldLabel
        default: label := Tr("监控配置")
    }
    return targetText != "" ? label "：" targetText : label
}

ShowHistoryResult(entry, isUndo) {
    detail := FormatHistoryAction(entry)
    message := isUndo ? Tr("已撤销：{1}", detail) : Tr("已重做：{1}", detail)
    LogMsg(message)
    if IsSet(GuiModules)
        GuiModules.historyToast.Show(message)
}

PerformUndo() {
    QueueGuardMutation(PerformUndoCore)
}

PerformUndoCore() {
    if App.appConfigHistoryService.Undo(
            (targetState, sourceState) => ApplyState(targetState, sourceState),
            &entry)
        ShowHistoryResult(entry, true)
}

PerformRedo() {
    QueueGuardMutation(PerformRedoCore)
}

PerformRedoCore() {
    if App.appConfigHistoryService.Redo(
            (targetState, sourceState) => ApplyState(targetState, sourceState),
            &entry)
        ShowHistoryResult(entry, false)
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
        stateObj.ResetGuardAttemptState()
        ClearStateProcessIdentity(stateObj)
        fingerprintTarget := nextResolvedTarget != "" ? nextResolvedTarget : path
        refreshedFingerprint := App.targetFileInspector.GetFingerprint(
            fingerprintTarget)
        stateObj.MaintenanceBaselineFingerprint := refreshedFingerprint
        stateObj.SafetyFingerprint := refreshedFingerprint
        stateObj.SafetyStableSince := GetTickCount64()
        stateObj.MaintenanceFingerprintCheckedTicks := 0
        stateObj.MaintenanceReadyCheckedTicks := 0
        stateObj.State := GetGuardActivationStatus(nextEnabled)
        stateObj.StatusKind := GetGuardActivationStatusKind(nextEnabled)
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
            stateObj.State := Tr("初始化...")
            stateObj.StatusKind := GuardStatusKind.Initializing
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
    ClearMainListTemporarySort()
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
                displayName, displayStatus, item.Path, projectedRow)
            SetMainListStatus(insertedRow, stateObj.State)
            SetMainListAdminOverlay(insertedRow, stateObj.RunAsAdmin)
        } else {
            if (Main.lv.GetText(currentRow, 1) != displayName)
                Main.lv.Modify(currentRow, "Col1", displayName)
            if (Main.lv.GetText(currentRow, 2) != displayStatus)
                SetMainListStatus(currentRow, stateObj.State)
            iconIndex := GetMainListIconIndex(item.Path, stateObj, Main.lv.IL)
            if iconIndex
                Main.lv.Modify(currentRow, "Icon" iconIndex)
            SetMainListAdminOverlay(currentRow, stateObj.RunAsAdmin)
        }
    }

    App.appOrder := []
    for item in items {
        if App.appStates.Has(item.Path)
            App.appOrder.Push(item.Path)
    }
    Main.listProjection.Rebuild(Main.lv)
    Main.listProjection.RefreshSequenceFromOrder(Main.lv, App.appOrder)
    RefreshMainStatusSortKeys()
}

ApplyState(stateArr, sourceStateArr := "", rollbackOnFailure := true) {
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
                if !RegisterApp(item.Path, item.Enabled, item.RunAsAdmin, item.WorkDir, item.Args,
                    item.EnvVars, item.Maintenance, item.ResolvedTarget,
                    item.ResolvedTargetManual, item.ShortcutArgs, item.Display) {
                    throw Error(Tr("监控项路径无效：{1}", item.Path))
                }
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
    } catch as applyError {
        if rollbackOnFailure && Type(currentState) == "Array" {
            try ApplyState(currentState, "", false)
            catch as rollbackError {
                LogMsg(Tr("保存监控配置失败：{1}",
                    TrDiagnostic(rollbackError.Message)))
            }
        }
        throw applyError
    } finally {
        try Main.lv.Opt("+Redraw")
        try RestoreMainListInteraction(interaction)
    }
    OnLVSelectChange()
    return true
}

SaveAppsToIni(markChanged := true) {
    previousCritical := A_IsCritical
    Critical("On")
    try {
        if markChanged {
            App.appConfigSaveRevision++
            App.appsDirty := true
        } else if !App.appsDirty {
            return true
        }
        ; 保存期间再次发生修改时只登记新修订，由当前保存者在本轮提交后
        ; 继续追赶，避免重入调用被静默丢弃或并发写同一个 INI。
        if App.appConfigSaveInProgress
            return true
        App.appConfigSaveInProgress := true
    } finally {
        Critical(previousCritical ? previousCritical : "Off")
    }

    try {
        loop {
            revisionCritical := A_IsCritical
            Critical("On")
            try saveRevision := App.appConfigSaveRevision
            finally Critical(revisionCritical ? revisionCritical : "Off")

            try {
                saveResult := App.watchlistPersistenceService.Save(
                    App.appOrder, App.appStates,
                    App.configRecoveryEntries)
            } catch as saveErr {
                failureCritical := A_IsCritical
                Critical("On")
                try App.appsDirty := true
                finally Critical(failureCritical ? failureCritical : "Off")
                LogMsg(Tr("保存监控配置失败：{1}",
                    TrDiagnostic(saveErr.Message)))
                nowTicks := GetTickCount64()
                if (nowTicks - App.lastSaveWarningTicks > 10000) {
                    try TrayTip(Tr("监控配置尚未保存，请查看运行日志。"),
                        Tr("进程守护小助手"), 3)
                    App.lastSaveWarningTicks := nowTicks
                }
                retryDelayMs := App.configSaveRetryDelayMs
                App.configSaveRetryDelayMs := Min(retryDelayMs * 2, 60000)
                try SetTimer(App.configSaveRetryTimer, -retryDelayMs)
                return false
            }

            successCritical := A_IsCritical
            Critical("On")
            try {
                App.appConfigPersistedRevision := Max(
                    App.appConfigPersistedRevision, saveRevision)
                hasNewerRevision := App.appConfigSaveRevision > saveRevision
                App.appsDirty := hasNewerRevision
                if !hasNewerRevision {
                    App.appOrder := saveResult.OrderedPaths
                    App.configSaveRetryDelayMs := 5000
                    try SetTimer(App.configSaveRetryTimer, 0)
                }
            } finally {
                Critical(successCritical ? successCritical : "Off")
            }
            if !hasNewerRevision
                return true
        }
    } finally {
        finishCritical := A_IsCritical
        Critical("On")
        try App.appConfigSaveInProgress := false
        finally Critical(finishCritical ? finishCritical : "Off")
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

ApplyMainListReorder(selectedPaths, anchorCandidates, appendToEnd := false) {
    if Type(selectedPaths) != "Array" || !selectedPaths.Length
        return false

    selectedSet := Map()
    selectedSet.CaseSense := "Off"
    movingPaths := []
    for path in selectedPaths {
        path := NormalizeTargetPath(path)
        if path != "" && App.appStates.Has(path) && !selectedSet.Has(path) {
            selectedSet[path] := true
            movingPaths.Push(path)
        }
    }
    if !movingPaths.Length
        return false

    currentPaths := []
    remainingPaths := []
    Loop Main.lv.GetCount() {
        path := NormalizeTargetPath(Main.lv.GetText(A_Index, 3))
        if path == "" || !App.appStates.Has(path)
            continue
        currentPaths.Push(path)
        if !selectedSet.Has(path)
            remainingPaths.Push(path)
    }

    insertionIndex := remainingPaths.Length + 1
    if !appendToEnd && Type(anchorCandidates) == "Array" {
        for anchorPath in anchorCandidates {
            for index, remainingPath in remainingPaths {
                if PathsEquivalent(anchorPath, remainingPath) {
                    insertionIndex := index
                    break 2
                }
            }
        }
        if !anchorCandidates.Length
            insertionIndex := 1
    }

    desiredPaths := remainingPaths.Clone()
    for offset, path in movingPaths
        desiredPaths.InsertAt(insertionIndex + offset - 1, path)
    if desiredPaths.Length != currentPaths.Length
        return false
    orderChanged := false
    for index, path in desiredPaths {
        if !PathsEquivalent(path, currentPaths[index]) {
            orderChanged := true
            break
        }
    }
    if !orderChanged
        return false

    App.editSessionId++
    undoState := CaptureAppConfigState()
    selectedMap := Map()
    selectedMap.CaseSense := "Off"
    for path in movingPaths
        selectedMap[path] := true
    interaction := {
        SelectedPaths: selectedMap,
        FocusedPath: movingPaths[1],
        HadKeyboardFocus: DllCall("user32\GetFocus", "Ptr") == Main.lv.Hwnd
    }
    projectedItems := []
    for path in desiredPaths
        projectedItems.Push({Path: path})

    Main.lv.Opt("-Redraw")
    try {
        SyncMainListToConfigState(projectedItems)
        if !AppConfigStateOrderMatchesCurrent(undoState)
            CommitUndoState(undoState,
                CreateAppHistoryAction("reorder", movingPaths))
        SaveAppsToIni()
    } finally {
        try Main.lv.Opt("+Redraw")
        try RestoreMainListInteraction(interaction)
    }
    OnLVSelectChange()
    return true
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
