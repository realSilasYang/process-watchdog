class EnvironmentSettingsDialog extends ManagedWindow {
    __New(mainGui) {
        this.owner := mainGui
        this.path := ""
        this.state := ""
        this.workDirEdit := ""
        this.argsEdit := ""
        this.envEdit := ""
        this.autoResolveCheck := ""
        this.resolvedTargetEdit := ""
        this.resolvedTargetBrowse := ""
    }

    Show(path, stateObj) {
        if this.ShowExisting()
            return

        this.path := path
        this.state := stateObj
        if !this.CreateOwnedGui(this.owner, "", "高级运行环境设置")
            return
        try {
        SetDarkTitleBar(this.gui.Hwnd)
        SetWindowIcon(this.gui.Hwnd, A_ScriptDir "\watchdog.ico")
        this.gui.BackColor := "1E1E1E"
        this.gui.SetFont("s10 cWhite", "Microsoft YaHei")

        this.gui.Add("Text", "x20 y20 w460 h20 BackgroundTrans", "目标程序: " path)
        SplitPath(path, , , &pathExtension)
        isShortcut := StrLower(pathExtension) == "lnk"
        verticalOffset := isShortcut ? 40 : 0
        if isShortcut {
            isManual := stateObj.HasOwnProp("ResolvedTargetManual") && stateObj.ResolvedTargetManual
            this.autoResolveCheck := this.gui.Add("CheckBox", "x20 y56 w120 h25", "自动识别进程")
            this.autoResolveCheck.Value := isManual ? 0 : 1
            resolvedInput := AddCenteredSingleLineEdit(this.gui, 150, 55, 280, 25,
                stateObj.HasOwnProp("ResolvedTarget") ? stateObj.ResolvedTarget : "", "", "333333")
            this.resolvedTargetEdit := resolvedInput.Edit
            this.resolvedTargetBrowse := this.gui.Add("Button", "x440 y55 w40 h25 Background555555 cWhite", "...")
            this.resolvedTargetEdit.Enabled := isManual
            this.resolvedTargetBrowse.Enabled := isManual
            SetDarkControl(this.autoResolveCheck.Hwnd)
            SetDarkControl(this.resolvedTargetEdit.Hwnd)
            SetDarkControl(this.resolvedTargetBrowse.Hwnd)
            RegisterHandCursorControl(this.autoResolveCheck)
            RegisterTextInputControl(this.resolvedTargetEdit)
            RegisterHoverButton(this.resolvedTargetBrowse, "555555")
            this.autoResolveCheck.OnEvent("Click", ObjBindMethod(this, "ToggleResolvedTargetMode"))
            RegisterButtonClick(this.resolvedTargetBrowse, ObjBindMethod(this, "BrowseResolvedTarget"))
        }

        this.gui.Add("Text", "x20 y" (60 + verticalOffset) " w120 h20 BackgroundTrans", "工作目录（CWD）:")
        workDirInput := AddCenteredSingleLineEdit(this.gui, 150, 55 + verticalOffset, 280, 25, stateObj.HasOwnProp("WorkDir") ? stateObj.WorkDir : "", "", "333333")
        this.workDirEdit := workDirInput.Edit
        btnBrowse := this.gui.Add("Button", "x440 y" (55 + verticalOffset) " w40 h25 Background555555 cWhite", "...")

        this.gui.Add("Text", "x20 y" (100 + verticalOffset) " w120 h20 BackgroundTrans", "启动参数（Args）:")
        argsInput := AddCenteredSingleLineEdit(this.gui, 150, 95 + verticalOffset, 330, 25, stateObj.HasOwnProp("Args") ? stateObj.Args : "", "", "333333")
        this.argsEdit := argsInput.Edit

        this.gui.Add("Text", "x20 y" (140 + verticalOffset) " w250 h20 BackgroundTrans", "环境变量（每行一个 KEY=VALUE）:")
        this.envEdit := this.gui.Add("Edit", "x20 y" (165 + verticalOffset) " w460 h100 Background333333 cWhite -E0x200 Multi VScroll", stateObj.HasOwnProp("EnvVars") ? stateObj.EnvVars : "")
        RegisterTextInputControl(this.envEdit)

        btnSave := this.gui.Add("Button", "x175 y" (295 + verticalOffset) " w70 h30 Background0078D7 cWhite Default", "保存")
        btnCancel := this.gui.Add("Button", "x255 y" (295 + verticalOffset) " w70 h30 Background555555 cWhite", "取消")
        RegisterHoverButton(btnBrowse, "555555")
        RegisterHoverButton(btnSave, "0078D7")
        RegisterHoverButton(btnCancel, "555555")

        SetDarkControl(this.envEdit.Hwnd)
        SetDarkControl(this.workDirEdit.Hwnd)
        SetDarkControl(this.argsEdit.Hwnd)
        SetDarkControl(btnBrowse.Hwnd)
        SetDarkControl(btnSave.Hwnd)
        SetDarkControl(btnCancel.Hwnd)
        RegisterButtonClick(btnBrowse, ObjBindMethod(this, "BrowseWorkDir"))
        RegisterButtonClick(btnSave, ObjBindMethod(this, "Save"), ButtonFeedbackMode.Dismissive)
        RegisterButtonClick(btnCancel, ObjBindMethod(this, "Close"), ButtonFeedbackMode.Dismissive)
        this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
        this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
        this.gui.Show("w500 h" (340 + verticalOffset))
        } catch as openErr {
            this.Close()
            throw openErr
        }
    }

    BrowseWorkDir(*) {
        if !this.IsOpen()
            return
        this.gui.Opt("+OwnDialogs")
        selected := FileSelect("D", this.workDirEdit.Value != "" ? this.workDirEdit.Value : "", "选择工作目录")
        if selected && this.IsOpen()
            this.workDirEdit.Value := selected
    }

    ToggleResolvedTargetMode(*) {
        if !this.IsOpen() || !this.resolvedTargetEdit
            return
        manualMode := this.autoResolveCheck.Value == 0
        this.resolvedTargetEdit.Enabled := manualMode
        this.resolvedTargetBrowse.Enabled := manualMode
        if !manualMode {
            automaticTarget := App.shortcutTargetResolver.ResolveEffective(
                this.path, true)
            this.resolvedTargetEdit.Value := automaticTarget
        }
    }

    BrowseResolvedTarget(*) {
        if !this.IsOpen() || !this.resolvedTargetEdit.Enabled
            return
        this.gui.Opt("+OwnDialogs")
        selected := SelectFileWithNamedFilter(this.gui.Hwnd,
            this.resolvedTargetEdit.Value,
            "选择快捷方式对应的真实进程", "支持的程序与脚本",
            "*.exe;*.com;*.ahk;*.py;*.pyw;*.js;*.vbs;*.ps1;*.bat;*.cmd")
        if selected && this.IsOpen()
            this.resolvedTargetEdit.Value := selected
    }

    Save(*) {
        if !this.IsOpen() || !this.state
            return
        path := this.path
        resolvedTarget := this.state.HasOwnProp("ResolvedTarget") ? this.state.ResolvedTarget : ""
        resolvedTargetManual := false
        resolutionSource := this.state.HasOwnProp("ShortcutTargetSource")
            ? this.state.ShortcutTargetSource : ""
        if this.resolvedTargetEdit {
            resolvedTargetManual := this.autoResolveCheck.Value == 0
            if resolvedTargetManual {
                resolvedTarget := NormalizeTargetPath(this.resolvedTargetEdit.Value)
                if (!App.shortcutTargetResolver.IsPotentialProcessTarget(
                    resolvedTarget) || !FileExist(resolvedTarget)
                    || !App.shortcutTargetResolver.IsUsableTarget(
                        resolvedTarget)) {
                    ShowDarkMsgBox("请选择现有且可执行的真实程序或脚本路径。", "真实进程路径无效", "Error", this.gui)
                    return
                }
                resolutionSource := "用户指定"
            } else {
                resolvedTarget := App.shortcutTargetResolver.ResolveForState(
                    path, "", &resolutionSource)
            }
            if (resolvedTarget != "") {
                conflictPath := App.targetIdentityService.FindConflict(
                    resolvedTarget, path)
                if (conflictPath != "") {
                    ShowDarkMsgBox("该真实进程已由其他监控项守护。", "监控目标重复", "Error", this.gui)
                    return
                }
            }
        }
        identityChanged := !PathsEquivalent(this.state.ResolvedTarget, resolvedTarget)
            || this.state.ResolvedTargetManual != resolvedTargetManual
        nextWorkDir := Trim(this.workDirEdit.Value)
        nextArgs := Trim(this.argsEdit.Value)
        nextEnvVars := Trim(this.envEdit.Value)
        settingsChanged := identityChanged || this.state.WorkDir != nextWorkDir
            || this.state.Args != nextArgs || this.state.EnvVars != nextEnvVars
        if !settingsChanged {
            this.state.ShortcutTargetSource := resolutionSource
            this.state.ShortcutResolveCheckedTicks := GetTickCount64()
            if App.appsDirty && !SaveAppsToIni() {
                ShowDarkMsgBox("保存高级运行环境设置失败，请查看运行日志。",
                    "保存失败", "Error", this.gui)
                return
            }
            this.Close()
            return
        }
        undoState := CaptureAppConfigState()
        stateObj := this.state
        priorPhase := stateObj.Phase
        stateObj.CancelScheduledTasks()
        if identityChanged {
            App.maintenanceCoordinator.CleanupTarget(path, stateObj, false)
            ClearStateProcessIdentity(stateObj)
        }
        stateObj.WorkDir := nextWorkDir
        stateObj.Args := nextArgs
        stateObj.EnvVars := nextEnvVars
        stateObj.ResolvedTarget := resolvedTarget
        stateObj.ResolvedTargetManual := resolvedTargetManual
        stateObj.ShortcutTargetSource := resolutionSource
        stateObj.ShortcutResolveCheckedTicks := GetTickCount64()
        stateObj.OneShot := IsOneShotTarget(path, resolvedTarget)
        App.targetSpecsService.Get(path, stateObj, true)
        if identityChanged {
            stateObj.MaintenanceConfig := App.maintenanceConfigCodec
                .NormalizeSnapshot(stateObj.MaintenanceConfig, path,
                    resolvedTarget)
            fingerprintTarget := resolvedTarget != "" ? resolvedTarget : path
            refreshedFingerprint := App.targetFileInspector.GetFingerprint(
                fingerprintTarget)
            stateObj.SafetyFingerprint := refreshedFingerprint
            stateObj.MaintenanceBaselineFingerprint := refreshedFingerprint
            stateObj.SafetyStableSince := GetTickCount64()
            stateObj.MaintenanceFingerprintCheckedTicks := 0
            stateObj.MaintenanceReadyCheckedTicks := 0
            if stateObj.Enabled && stateObj.MaintenanceConfig.Enabled
                App.maintenanceCoordinator.EnsureWatcher(path, stateObj)
            App.maintenanceCoordinator.SaveJournal()
        }
        if (stateObj.Enabled
            && !App.maintenanceCoordinator.IsBlocking(stateObj)) {
            stateObj.Pending := false
            stateObj.TargetStartTicks := 0
            stateObj.VerifyAttempts := 0
            if StateProcessIdentityIsValid(path, stateObj) {
                UpdateRunningState(path, stateObj, stateObj.Generation)
            } else if !(stateObj.OneShot
                && priorPhase == GuardPhase.Running) {
                stateObj.TransitionTo(GuardPhase.Initializing)
                UpdateState(path, "初始化...", stateObj,
                    stateObj.Generation)
            }
        }
        CommitUndoState(undoState)
        if !SaveAppsToIni() {
            ShowDarkMsgBox("保存高级运行环境设置失败，请查看运行日志。",
                "保存失败", "Error", this.gui)
            return
        }
        this.Close()
        LogMsg("已更新高级运行环境设置: " path)
    }

    Close(*) {
        this.DestroyGui()
        this.workDirEdit := ""
        this.argsEdit := ""
        this.envEdit := ""
        this.autoResolveCheck := ""
        this.resolvedTargetEdit := ""
        this.resolvedTargetBrowse := ""
        this.path := ""
        this.state := ""
    }
}
