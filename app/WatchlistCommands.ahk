; 主窗口守护列表的命令与配置投影。
; 添加、编辑、暂停、撤销和重做都先更新受控的运行态，再以差量方式同步列表与配置；
; 路径始终保存在隐藏身份列中，显示名称、图标和状态文案不参与目标身份判断。

GetGuardActivationStatus(enabled) {
    return enabled ? Tr("初始化...") : Tr("⏸️ 已暂停")
}

GetGuardActivationStatusKind(enabled) {
    return enabled ? GuardStatusKind.Initializing : GuardStatusKind.Paused
}

RegisterApp(path, enabled := 1, runAsAdmin := 0, workingDirectory := "", arguments := "", environment := "", storedResolvedTarget := "", resolvedTargetManual := false, shortcutArguments := "", displayConfig := "", runtimePath := "", runtimeArguments := "", storedContentHash := "", storedContentSize := 0, askBeforeRestart := false) {
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
    contentHash := RegExMatch(storedContentHash, "i)^[0-9a-f]{64}$")
        ? StrUpper(storedContentHash) : ""
    try contentSize := Max(0, Integer(storedContentSize))
    catch
        contentSize := 0
    contentSignature := App.targetFileInspector.GetContentSignature(path)
    if contentSignature.Available {
        contentHash := contentSignature.ContentHash
        contentSize := contentSignature.FileSize
    }
    displayConfig := App.displayConfigCodec.Normalize(displayConfig)
    initialStatus := GetGuardActivationStatus(enabled)
    stateObj := TargetSupervisor({
        State: initialStatus, StatusKind: GetGuardActivationStatusKind(enabled),
        FailCount: 0, Pending: false,
        Enabled: enabled ? 1 : 0,
        AskBeforeRestart: askBeforeRestart ? 1 : 0,
        TargetStartTicks: 0, RunAsAdmin: runAsAdmin ? 1 : 0, WorkDir: workingDirectory,
        Args: arguments, ShortcutArgs: shortcutArguments, EnvVars: environment,
        RuntimePath: runtimePath, RuntimeArgs: runtimeArguments,
        PID: 0, LastKnownPID: 0, PIDCreationIdentity: "", PIDImagePath: "",
        PIDElevationState: -1, PIDElevationChecked: false,
        LastKnownPIDCreationIdentity: "",
        ResolvedTarget: resolvedTarget, ShortcutTargetSource: resolutionSource,
        ResolvedTargetManual: !!resolvedTargetManual,
        ShortcutResolveCheckedTicks: GetTickCount64(),
        VerifyAttempts: 0,
        OneShot: IsOneShotTarget(path, resolvedTarget), MissingSinceTicks: 0,
        ContentHash: contentHash, ContentSize: contentSize,
        DisplayConfig: displayConfig, TargetSpecs: "", TargetSpecsFingerprint: "",
        Scheduler: App.scheduler
    })
    App.appStates[path] := stateObj
    try {
        App.targetSpecsService.Get(path, stateObj, true)
        App.appOrder.Push(path)
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
        LogMsg(Tr("添加守护对象失败，已回滚内存状态：{1}",
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
    ; GetNext() 默认枚举选中行，不能传入不存在的 "S"/"Selected" 选项。
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

GetCommonMainSequenceColor(paths) {
    if Type(paths) != "Array" || !paths.Length
        return ""
    commonKey := ""
    for index, path in paths {
        key := GetMainSequenceColorKey(path)
        if index == 1
            commonKey := key
        else if key != commonKey
            return ""
    }
    return commonKey
}

SetSelectedMainSequenceColor(colorKey, *) {
    paths := CaptureSelectedWatchPaths(true)
    if !paths.Length
        return false
    requestedKey := StrLower(Trim(String(colorKey)))
    colorKey := MainSequenceColorPalette.NormalizeKey(requestedKey)
    if requestedKey != "" && colorKey == ""
        return false
    if requestedKey == ""
        colorKey := MainSequenceColorPalette.NoneKey
    return QueueGuardMutation(SetSelectedMainSequenceColorCore.Bind(
        paths.Clone(), colorKey))
}

RefreshMainSequenceVisual(path) {
    row := FindRow(path)
    if row > 0 && Main.HasOwnProp("listSelectionPresenter")
            && IsObject(Main.listSelectionPresenter)
        Main.listSelectionPresenter.RefreshItem(row)
}

SetSelectedMainSequenceColorCore(paths, colorKey) {
    undoState := CaptureAppConfigState()
    changedPaths := []
    for path in paths {
        if !App.appStates.Has(path)
            continue
        stateObj := App.appStates[path]
        display := stateObj.HasOwnProp("DisplayConfig")
            ? App.displayConfigCodec.Normalize(stateObj.DisplayConfig)
            : App.displayConfigCodec.CreateDefault()
        if display.SequenceColor == colorKey
            continue
        display.SequenceColor := colorKey
        stateObj.DisplayConfig := display
        changedPaths.Push(path)
        RefreshMainSequenceVisual(path)
    }
    if !changedPaths.Length
        return false
    CommitUndoState(undoState,
        CreateAppHistoryAction("display", changedPaths[1]))
    if !SaveAppsToIni()
        return false
    LogMsg(Tr("已更新主窗口显示设置：{1}", Tr("设置序号圆点")))
    return true
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
            } else {
                stateObj.TransitionTo(GuardPhase.Initializing)
                UpdateState(chkPath, GetGuardActivationStatus(true),
                    stateObj, operationGeneration, true,
                    GuardStatusKind.Initializing)
            }
            LogMsg(newEnabled ? Tr("恢复守护：{1}", chkPath)
                : Tr("暂停守护：{1}", chkPath))
            changedAny := true
        }
    }

    if (changedAny) {
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
            ; 原生标签编辑框需要先应用 Edit 自身的深色视觉样式，再由父
            ; ListView 子类响应 WM_CTLCOLOREDIT。两层缺一都会在真实主窗口
            ; 的首次编辑生命周期中退回亮色，不能把这里视为重复调用。
            SetDarkControl(hEdit)
            DarkInlineEditThemeRegistry.Register(hEdit, GuiCtrlObj.Hwnd)
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
            DarkInlineEditThemeRegistry.Unregister(
                App.activeInlineEditHwnd)
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
            DarkInlineEditThemeRegistry.Unregister(
                App.activeInlineEditHwnd)
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
    if !App.guardWorkGate.TryEnter("InlineEdit") {
        SetTimer(ProcessEditFinish.Bind(GuiCtrlObj, Item, sessionId), -25)
        return
    }
    try ProcessEditFinishCore(GuiCtrlObj, Item, sessionId)
    finally App.guardWorkGate.Leave()
}

PrepareWatchPathTransition(previousPath, requestedPath) {
    return PrepareWatchPathTransitionFromState(previousPath, requestedPath,
        CaptureAppConfigState())
}

; 把路径迁移的快照变换与 GUI 捕获分离，便于逐字段验证且保证手工编辑、
; 自动找回都走同一规则。这里只构造目标状态，不修改运行态或持久化文件。
PrepareWatchPathTransitionFromState(previousPath, requestedPath,
    beforeState) {
    previousPath := NormalizeTargetPath(previousPath)
    newPath := NormalizeTargetPath(requestedPath)
    if (newPath == "" || PathsEquivalent(newPath, previousPath))
        return {Changed: false, PreviousPath: previousPath, NewPath: previousPath}
    if DirExist(newPath)
        throw Error(Tr("守护对象不能指向文件夹：{1}", newPath))
    if !App.appStates.Has(previousPath)
        throw Error(Tr("守护对象路径无效：{1}", previousPath))
    if App.appStates.Has(newPath)
        throw Error(Tr("拒绝更新路径，已存在相同的守护对象：{1}", newPath))

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
    if identityConflict != "" {
        throw Error(Tr("拒绝修改路径，真实进程已由其它守护对象守护：{1}",
            identityConflict))
    }

    if Type(beforeState) != "Array"
        throw Error(Tr("守护对象路径无效：{1}", previousPath))
    targetState := App.appConfigSnapshotService.PrepareState(beforeState).Items
    pathChanged := false
    for targetItem in targetState {
        if !PathsEquivalent(targetItem.Path, previousPath)
            continue
        targetItem.Path := newPath
        targetItem.ResolvedTarget := prospectiveResolvedTarget
        targetItem.ResolvedTargetManual := false
        targetItem.ShortcutArgs := prospectiveShortcutArgs
        if !TargetSpecFactory.SupportsCustomRuntime(newPath) {
            targetItem.RuntimePath := ""
            targetItem.RuntimeArgs := ""
        }
        if prospectiveWorkingDirectory != ""
            targetItem.WorkDir := prospectiveWorkingDirectory
        pathChanged := true
        break
    }
    if !pathChanged
        throw Error(Tr("守护对象路径无效：{1}", previousPath))
    return {
        Changed: true,
        PreviousPath: previousPath,
        NewPath: newPath,
        BeforeState: beforeState,
        TargetState: targetState
    }
}

ApplyWatchPathTransition(previousPath, requestedPath,
    historyKind := "edit-path", preserveInlineEditSession := false) {
    transition := PrepareWatchPathTransition(previousPath, requestedPath)
    if !transition.Changed
        return false
    selectedBefore := false
    row := 0
    Loop {
        row := Main.lv.GetNext(row)
        if !row
            break
        if PathsEquivalent(Main.lv.GetText(row, 3), transition.PreviousPath) {
            selectedBefore := true
            break
        }
    }
    ApplyState(transition.TargetState, transition.BeforeState, true,
        preserveInlineEditSession)
    App.appConfigHistoryService.Commit(transition.BeforeState,
        transition.TargetState, CreateAppHistoryAction(historyKind,
            [transition.PreviousPath, transition.NewPath]))
    if selectedBefore {
        migratedRow := FindRow(transition.NewPath)
        if migratedRow > 0
            Main.lv.Modify(migratedRow, "Select Focus Vis")
    }
    return true
}

QueueTargetRelocationPrompt(candidate) {
    if App.shutdownStarted
        return false
    SetTimer(ShowTargetRelocationPrompt.Bind(candidate), -1)
    return true
}

ShowTargetRelocationPrompt(candidate, *) {
    if App.shutdownStarted || !IsSet(GuiModules)
        return false
    if !App.targetRelocationService.ValidateCandidate(candidate) {
        App.targetRelocationService.Invalidate(candidate)
        return false
    }
    GuiModules.targetRelocation.Show(candidate)
    return true
}

InvalidateTargetRelocationPrompt(candidate) {
    if App.shutdownStarted
        return false
    SetTimer(CloseInvalidTargetRelocationPrompt.Bind(candidate), -1)
    return true
}

CloseInvalidTargetRelocationPrompt(candidate, *) {
    if IsSet(GuiModules)
        GuiModules.targetRelocation.Invalidate(candidate)
}

QueueTargetRelocationConfirmation(candidate) {
    if !App.targetRelocationService.ValidateCandidate(candidate)
        return false
    return QueueExclusiveGuardMutation(candidate.State, "relocate-path",
        ConfirmTargetRelocationCore.Bind(candidate),
        Tr("自动识别目标新位置"))
}

ConfirmTargetRelocationCore(candidate) {
    if !App.targetRelocationService.ValidateCandidate(candidate) {
        App.targetRelocationService.Invalidate(candidate)
        LogMsg(Tr("检测到的目标新位置已失效，请重新操作。"))
        return false
    }
    try {
        if !ApplyWatchPathTransition(candidate.OldPath, candidate.NewPath,
            "relocate-path")
            throw Error(Tr("守护对象路径无效：{1}", candidate.OldPath))
        App.targetRelocationService.Complete(candidate)
        App.targetRelocationService.SyncTargets()
        LogMsg(Tr("已更新已更名的守护目标：{1} -> {2}",
            candidate.OldPath, candidate.NewPath))
        return true
    } catch as relocationError {
        App.targetRelocationService.Invalidate(candidate)
        throw relocationError
    }
}

IgnoreTargetRelocation(candidate) {
    return App.targetRelocationService.Ignore(candidate)
}

ResetTargetRelocationState(path, stateObj) {
    if !App.appStates.Has(path) || App.appStates[path] != stateObj
        return false
    stateObj.RelocationPending := false
    if FileExist(path) && !DirExist(path) {
        stateObj.ResetGuardAttemptState()
        stateObj.TransitionTo(GuardPhase.Initializing)
        UpdateState(path, Tr("初始化..."), stateObj, stateObj.Generation,
            true, GuardStatusKind.Initializing)
        return true
    }
    SplitPath(path, , , &extension)
    isScript := RegExMatch(extension,
        "i)^(ahk|py|pyw|js|vbs|vbe|wsf|ps1|bat|cmd|rb|pl|php|lua|jar|sh|bash)$")
    stateObj.MissingSinceTicks := GetTickCount64()
    stateObj.TransitionTo(GuardPhase.Exhausted)
    UpdateState(path, isScript ? Tr("❌ 脚本不存在") : Tr("❌ 程序不存在"),
        stateObj, stateObj.Generation, true,
        isScript ? GuardStatusKind.ScriptMissing
            : GuardStatusKind.ProgramMissing)
    return true
}

ProcessEditFinishCore(GuiCtrlObj, Item, sessionId := 0) {
    if (sessionId && sessionId != App.editSessionId)
        return
    try {
        newPath := NormalizeTargetPath(GuiCtrlObj.GetText(Item, 1))
        previousPath := GuiCtrlObj.GetText(Item, 3)

        if (newPath != "" && !PathsEquivalent(newPath, previousPath)) {
            if ApplyWatchPathTransition(previousPath, newPath, "edit-path", true)
                LogMsg(Tr("已更新守护对象路径。"))
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
                throw Error(Tr("守护对象路径无效：{1}", savePath))
            state.Push(snapshot)
        }
    } catch as snapshotError {
        LogMsg(Tr("捕获守护对象历史失败：{1}",
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
    for propertyName in ["UiLanguage", "UiFont", "Theme", "UiScale", "CheckInterval",
            "RetrySequence", "AskBeforeRestartFromStopCount", "ShowAtStartup", "RunAsAdministrator",
            "CheckUpdatesOnStartup", "RecursiveBatchImport", "LogMaxEntries",
            "LogDirectory",
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
        {Property: "UiScale", Label: "界面缩放："},
        {Property: "ShowAtStartup", Label: "启动时显示主窗口"},
        {Property: "RunAsAdministrator", Label: "以管理员身份运行"},
        {Property: "CheckUpdatesOnStartup", Label: "启动时检查小助手更新"},
        {Property: "CheckInterval", Label: "进程状态检查间隔（毫秒）："},
        {Property: "RetrySequence", Label: "崩溃自动重启延迟序列（秒）："},
        {Property: "AskBeforeRestartFromStopCount",
            Label: "如果设置了恢复前询问，应从第几次停止开始询问？"},
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

ApplyRuntimeElevationSettingChange(previousValue, nextValue) {
    previousValue := !!previousValue
    nextValue := !!nextValue
    if previousValue == nextValue
        return false
    if A_IsAdmin || !nextValue {
        try SynchronizeWatchdogTaskElevation(nextValue)
        catch as taskElevationError
            LogMsg(Tr("计划任务操作失败：{1}",
                TrDiagnostic(taskElevationError.Message)))
    }
    if nextValue && !A_IsAdmin
        SetTimer(ReloadScriptElevated, -1)
    return true
}

ApplyRuntimeSettingsSnapshot(settings) {
    priorInterval := App.checkInterval
    priorRunAsAdministrator := App.runAsAdministrator
    displayChanged := settings.UiLanguage != App.uiLanguage
        || settings.UiFont != App.uiFont || settings.Theme != App.uiTheme
        || settings.UiScale != App.uiScale
    if displayChanged
        ApplyDisplaySettingsHot(settings.UiLanguage, settings.UiFont,
            settings.Theme, settings.UiScale)
    App.runtimeSettingsService.Apply(App, settings)
    ApplyRuntimeElevationSettingChange(priorRunAsAdministrator,
        App.runAsAdministrator)
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
        case "add": label := Tr("添加守护对象")
        case "delete": label := Tr("删除")
        case "toggle-pause": label := GetHistoryPauseActionLabel(entry, paths)
        case "edit-path": label := Tr("编辑完整路径")
        case "relocate-path": label := Tr("更新已更名的守护目标")
        case "reorder": label := Tr("调整守护顺序")
        case "run-as-admin": label := Tr("管理员运行状态")
        case "ask-before-restart": label := Tr("每次恢复前询问")
        case "display": label := Tr("自定义名称和图标")
        case "environment": label := Tr("进程识别与启动设置")
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

    nextDisplay := App.appConfigSnapshotService.MergeDisplayTransition(
        stateObj.HasOwnProp("DisplayConfig") ? stateObj.DisplayConfig : "",
        sourceItem.Display, targetItem.Display)

    if (identityChanged || enabledChanged) {
        stateObj.CancelScheduledTasks()
    }

    if (!!sourceItem.RunAsAdmin != !!targetItem.RunAsAdmin
        && !!stateObj.RunAsAdmin == !!sourceItem.RunAsAdmin)
        stateObj.RunAsAdmin := targetItem.RunAsAdmin
    if (!!sourceItem.AskBeforeRestart != !!targetItem.AskBeforeRestart
        && !!stateObj.AskBeforeRestart == !!sourceItem.AskBeforeRestart)
        stateObj.AskBeforeRestart := targetItem.AskBeforeRestart ? 1 : 0
    RefreshMainSequenceVisual(path)
    for propertyName in ["WorkDir", "Args", "ShortcutArgs", "EnvVars",
        "RuntimePath", "RuntimeArgs"] {
        if (sourceItem.%propertyName% != targetItem.%propertyName%
            && stateObj.%propertyName% == sourceItem.%propertyName%)
            stateObj.%propertyName% := targetItem.%propertyName%
    }
    stateObj.ResolvedTarget := nextResolvedTarget
    stateObj.ResolvedTargetManual := nextResolvedTargetManual
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
        stateObj.State := GetGuardActivationStatus(nextEnabled)
        stateObj.StatusKind := GetGuardActivationStatusKind(nextEnabled)
        stateObj.TransitionTo(nextEnabled ? GuardPhase.Initializing
            : GuardPhase.Paused)
    }
    return {RuntimeChanged: identityChanged || enabledChanged}
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
    AlignMainListBottomIfScrolled()
}

ToggleAskBeforeRestart(*) {
    paths := CaptureSelectedWatchPaths(true)
    if !paths.Length
        return
    QueueGuardMutation(ToggleAskBeforeRestartCore.Bind(paths),
        "切换每次恢复前询问")
}

ToggleAskBeforeRestartCore(paths) {
    App.editSessionId++
    undoState := CaptureAppConfigState()
    changedPaths := []
    for path in paths {
        if !App.appStates.Has(path)
            continue
        stateObj := App.appStates[path]
        nextValue := !(stateObj.HasOwnProp("AskBeforeRestart")
            && stateObj.AskBeforeRestart)
        stateObj.AskBeforeRestart := nextValue ? 1 : 0
        stateObj.StopCountSinceGuardReset := 0
        RefreshMainSequenceVisual(path)
        changedPaths.Push(path)
    }
    if !changedPaths.Length
        return false
    CommitUndoState(undoState,
        CreateAppHistoryAction("ask-before-restart", changedPaths))
    if !SaveAppsToIni()
        return false
    LogMsg(nextValue
        ? Tr("已开启每次恢复前询问：{1}", changedPaths[1])
        : Tr("已关闭每次恢复前询问，改为静默恢复：{1}", changedPaths[1]))
    return true
}

ResetAskBeforeRestartStopCounts() {
    for _, stateObj in App.appStates
        stateObj.StopCountSinceGuardReset := 0
}

QueueRestartDecisionPrompt(path, stateObj, generation, targetName) {
    if !App.guardRuntime.IsSupervisorCurrent(path, stateObj, generation)
        return false
    if !stateObj.StopPromptPending
        return false
    if stateObj.HasOwnProp("StopPromptTaskQueued")
        && stateObj.StopPromptTaskQueued
        return true
    ; 弹窗首行必须与主列表保持一致，优先使用用户自定义的守护对象名称。
    targetName := GetMainDisplayName(path, stateObj)
    stateObj.StopPromptTaskQueued := true
    try {
        SetTimer(ShowRestartDecisionPrompt.Bind(path, stateObj, generation,
            targetName), -1)
        return true
    } catch {
        stateObj.StopPromptTaskQueued := false
        return false
    }
}

ShowRestartDecisionPrompt(path, stateObj, generation, targetName, *) {
    if !App.guardRuntime.IsSupervisorCurrent(path, stateObj, generation)
        || !stateObj.StopPromptPending {
        if App.guardRuntime.IsSupervisorCurrent(path, stateObj, generation)
            stateObj.StopPromptTaskQueued := false
        return
    }
    choices := [
        {Text: Tr("立即恢复"), Value: "now"},
        {Text: Tr("等待 1 分钟"), Value: "minute1"},
        {Text: Tr("等待 3 分钟"), Value: "minute3"},
        {Text: Tr("暂停守护"), Value: "pause"}
    ]
    try decision := ShowDarkChoiceBox(
        Tr("监测到守护对象已停止：{1}`n请选择后续处理方式。", targetName),
        Tr("进程守护小助手 事件提醒"), choices, Main.gui)
    catch as promptError {
        LogMsg(Tr("恢复选择弹窗创建失败：{1}",
            TrDiagnostic(promptError.Message)))
        decision := "pause"
    }
    applyChoice := ApplyRestartDecision.Bind(path, stateObj,
        generation, decision)
    if !QueueGuardMutation(applyChoice, "处理停止后的恢复选择")
        applyChoice.Call()
}

ApplyRestartDecision(path, stateObj, generation, decision) {
    if !App.guardRuntime.IsSupervisorCurrent(path, stateObj, generation)
        || !stateObj.StopPromptPending
        return false
    stateObj.StopPromptTaskQueued := false
    if decision == "pause" {
        ToggleItemPauseCore([path])
        return true
    }
    stateObj.StopPromptPending := false
    stateObj.StopPromptGeneration := 0
    stateObj.Pending := false
    stateObj.TargetStartTicks := 0
    delayMs := decision == "minute1" ? 60000
        : (decision == "minute3" ? 180000 : 0)
    task := App.guardRuntime.ScheduleRestartFor(path, stateObj, delayMs)
    if !(task is TargetScheduledTask) {
        stateObj.Pending := false
        stateObj.TransitionTo(GuardPhase.Initializing)
        UpdateState(path, Tr("初始化..."), stateObj,
            stateObj.Generation, false, GuardStatusKind.Initializing)
        return false
    }
    LogMsg(delayMs == 0
        ? Tr("已选择立即恢复：{1}", path)
        : Tr("已选择等待 {1} 分钟后恢复：{2}", delayMs / 60000, path))
    return true
}

ApplyState(stateArr, sourceStateArr := "", rollbackOnFailure := true,
    preserveInlineEditSession := false) {
    if !preserveInlineEditSession {
        App.editSessionId++
        App.batchEditRows := []
        App.editMonitorItem := 0
    }
    Main.contextTargetRow := 0
    currentState := CaptureAppConfigState()
    preparedState := App.appConfigSnapshotService.PrepareState(stateArr)
    sourceState := App.appConfigSnapshotService.PrepareState(sourceStateArr)
    isTransition := Type(sourceStateArr) == "Array"
    interaction := CaptureMainListInteraction()
    Main.lv.Opt("-Redraw")
    try {
        runtimeChanged := false
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
            App.appStates.Delete(existingPath)
            runtimeChanged := true
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
                    runtimeChanged := runtimeChanged || transitionResult.RuntimeChanged
                }
            } else if !isTransition {
                currentItem := App.appConfigSnapshotService.CreateSnapshot(
                    item.Path, App.appStates[item.Path])
                transitionResult := ApplyAppConfigTransition(item.Path,
                    App.appStates[item.Path],
                    currentItem, item)
                runtimeChanged := runtimeChanged || transitionResult.RuntimeChanged
            }
        }
        for item in preparedState.Items {
            shouldAdd := !App.appStates.Has(item.Path)
                && (!isTransition || !sourceState.Index.Has(item.Path))
            if shouldAdd {
                if !RegisterApp(item.Path, item.Enabled, item.RunAsAdmin, item.WorkDir, item.Args,
                    item.EnvVars, item.ResolvedTarget,
                    item.ResolvedTargetManual, item.ShortcutArgs, item.Display,
                    item.RuntimePath, item.RuntimeArgs, item.ContentHash,
                    item.ContentSize, item.AskBeforeRestart) {
                    throw Error(Tr("守护对象路径无效：{1}", item.Path))
                }
            }
        }
        projectedItems := isTransition
            ? App.appConfigSnapshotService.MergeTransitionOrder(currentState,
                sourceState.Items, preparedState.Items)
            : preparedState.Items
        SyncMainListToConfigState(projectedItems)
        if !SaveAppsToIni()
            throw Error(Tr("监控配置尚未保存，请查看运行日志。"))
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
