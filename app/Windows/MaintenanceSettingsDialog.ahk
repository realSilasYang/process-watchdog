; 单个守护项的软件升级保护设置窗口。
; 用户配置与后台实时学习到的更新程序特征在保存时合并；除非用户明确清空，
; 窗口打开期间新发现的证据不会被旧表单覆盖，未变化的设置也不会创建撤销记录。

class MaintenanceSettingsDialog extends ManagedWindow {
    __New(mainGui) {
        this.owner := mainGui
        this.path := ""
        this.state := ""
        this.enableCheck := ""
        this.rootEdit := ""
        this.detectionEdit := ""
        this.stableEdit := ""
        this.maxWaitEdit := ""
        this.learnedEdit := ""
        this.learnedActors := []
        this.learnedActorsCleared := false
    }

    Show(path, stateObj) {
        if this.ShowExisting()
            return
        this.path := path
        this.state := stateObj
        this.learnedActors := []
        this.learnedActorsCleared := false
        for signature in stateObj.MaintenanceConfig.LearnedActors
            this.learnedActors.Push(signature)
        isCompact := LocalizationService.UsesCompactLayout()
        windowWidth := isCompact ? 540 : 720
        contentWidth := windowWidth - 40
        if !this.CreateOwnedGui(this.owner, "-MinimizeBox -MaximizeBox",
            Tr("软件升级保护"))
            return
        try {
            InitializeApplicationWindow(this.gui)

            this.gui.Add("Text", "x20 y14 w" contentWidth
                " h20 BackgroundTrans", Tr("守护目标："))
            targetInput := AddCenteredSingleLineEdit(this.gui, 20, 38,
                contentWidth, 26, path, "ReadOnly",
                UiThemeService.Color("Surface"))
            RegisterTextInputControl(targetInput.Edit, true)
            SetDarkControl(targetInput.Edit.Hwnd)

            this.enableCheck := this.gui.Add("CheckBox", "x20 y76 w"
                contentWidth " h24 c" UiThemeService.Color("Text"),
                Tr("自动识别升级并保护启动过程"))
            this.enableCheck.Value := stateObj.MaintenanceConfig.Enabled ? 1 : 0
            SetDarkControl(this.enableCheck.Hwnd)
            RegisterHandCursorControl(this.enableCheck)

            browseWidth := isCompact ? 48 : 70
            autoWidth := isCompact ? 44 : 70
            rootInputWidth := contentWidth - browseWidth - autoWidth - 20
            browseX := 20 + rootInputWidth + 10
            autoX := browseX + browseWidth + 10
            this.gui.Add("Text", "x20 y108 w" contentWidth
                " h20 BackgroundTrans", Tr("安装足迹目录："))
            rootInput := AddCenteredSingleLineEdit(this.gui, 20, 132,
                rootInputWidth, 26,
                stateObj.MaintenanceConfig.InstallRoot, "",
                UiThemeService.Color("Input"))
            this.rootEdit := rootInput.Edit
            btnBrowse := this.gui.Add("Text", "x" browseX " y132 w"
                browseWidth " h26 Center 0x200 Background"
                    UiThemeService.Color("Toolbar") " c"
                    UiThemeService.Color("ToolbarText"), Tr("浏览"))
            btnAutoRoot := this.gui.Add("Text", "x" autoX " y132 w"
                autoWidth " h26 Center 0x200 Background"
                    UiThemeService.Color("Toolbar") " c"
                    UiThemeService.Color("ToolbarText"), Tr("自动"))

            timingGap := 20
            timingWidth := Floor((contentWidth - timingGap * 2) / 3)
            shortTimingWidth := 60
            longTimingWidth := 76
            detectionX := 20
            stableX := detectionX + timingWidth + timingGap
            maxWaitX := stableX + timingWidth + timingGap
            this.gui.Add("Text", "x" detectionX " y176 w" timingWidth
                " h20 BackgroundTrans", Tr("退出检测窗口（秒）："))
            detectionInputX := detectionX
                + Floor((timingWidth - shortTimingWidth) / 2)
            stableInputX := stableX
                + Floor((timingWidth - shortTimingWidth) / 2)
            maxWaitInputX := maxWaitX
                + Floor((timingWidth - longTimingWidth) / 2)
            detectionInput := AddCenteredSingleLineEdit(this.gui,
                detectionInputX,
                200, shortTimingWidth, 26,
                stateObj.MaintenanceConfig.DetectionSeconds, "Number")
            this.detectionEdit := detectionInput.Edit
            this.gui.Add("Text", "x" stableX " y176 w" timingWidth
                " h20 BackgroundTrans", Tr("文件稳定等待（秒）："))
            stableInput := AddCenteredSingleLineEdit(this.gui, stableInputX,
                200,
                shortTimingWidth, 26,
                stateObj.MaintenanceConfig.StableSeconds, "Number")
            this.stableEdit := stableInput.Edit
            this.gui.Add("Text", "x" maxWaitX " y176 w" timingWidth
                " h20 BackgroundTrans", Tr("最长升级等待（秒）："))
            maxWaitInput := AddCenteredSingleLineEdit(this.gui,
                maxWaitInputX,
                200, longTimingWidth, 26,
                stateObj.MaintenanceConfig.MaxWaitSeconds, "Number")
            this.maxWaitEdit := maxWaitInput.Edit

            clearWidth := isCompact ? 100 : 120
            this.gui.Add("Text", "x20 y246 w" (contentWidth - clearWidth - 10)
                " h20 BackgroundTrans", Tr("已自动学习的更新程序特征："))
            btnClearLearned := this.gui.Add("Text", "x"
                (windowWidth - 20 - clearWidth)
                " y242 w" clearWidth " h26 Center 0x200 Background"
                    UiThemeService.Color("Toolbar") " c"
                    UiThemeService.Color("ToolbarText"),
                Tr("清除记录"))
            this.learnedEdit := this.gui.Add("Edit",
                "x20 y270 w" contentWidth
                " h70 Background" UiThemeService.Color("Surface") " c"
                    UiThemeService.Color("ReadonlyText")
                    " -E0x200 ReadOnly Multi VScroll",
                this.GetLearnedText())
            RegisterTextInputControl(this.learnedEdit, true)
            SetDarkControl(this.learnedEdit.Hwnd)

            this.gui.Add("Text", "x20 y352 w" contentWidth
                " h24 0x200 BackgroundTrans c"
                    UiThemeService.Color("HintText"),
                this.GetStatusText())

            isBlocking := App.maintenanceCoordinator.IsBlocking(stateObj)
            resumeWidth := isCompact ? 210 : 300
            actionWidth := isBlocking ? resumeWidth + 180 : 170
            actionStartX := Round((windowWidth - actionWidth) / 2)
            btnSaveX := isBlocking ? actionStartX + resumeWidth + 10 : actionStartX
            btnCancelX := btnSaveX + 90
            if isBlocking {
                btnResume := this.gui.Add("Text",
                    "x" actionStartX " y390 w" resumeWidth
                    " h28 Center 0x200 Background" UiThemeService.Color("Pause")
                        " c" UiThemeService.Color("ButtonText"),
                    Tr("结束升级等待并恢复守护"))
                RegisterHoverButton(btnResume, UiThemeService.Color("Pause"))
                SetButtonLucideIcon(btnResume, "play.svg", 14, 6)
                RegisterButtonClick(btnResume, ObjBindMethod(this, "ResumeProtection"),
                    ButtonFeedbackMode.Dismissive)
            }
            btnSave := this.gui.Add("Text", "x" btnSaveX
                " y390 w80 h28 Center 0x200 Background"
                    UiThemeService.Color("Primary") " c"
                    UiThemeService.Color("ButtonText"), Tr("保存"))
            btnCancel := this.gui.Add("Text", "x" btnCancelX
                " y390 w80 h28 Center 0x200 Background"
                    UiThemeService.Color("Toolbar") " c"
                    UiThemeService.Color("ToolbarText"), Tr("取消"))

            for editControl in [this.rootEdit, this.detectionEdit, this.stableEdit, this.maxWaitEdit]
                SetDarkControl(editControl.Hwnd)
            RegisterHoverButton(btnBrowse, UiThemeService.Color("Toolbar"))
            RegisterHoverButton(btnAutoRoot, UiThemeService.Color("Toolbar"))
            RegisterHoverButton(btnClearLearned, UiThemeService.Color("Toolbar"))
            RegisterHoverButton(btnSave, UiThemeService.Color("Primary"))
            RegisterHoverButton(btnCancel, UiThemeService.Color("Toolbar"))
            SetButtonLucideIcon(btnBrowse, "folder-open.svg", 14, 6)
            SetButtonLucideIcon(btnAutoRoot, "wand-sparkles.svg", 14, 6)
            SetButtonLucideIcon(btnClearLearned, "trash-2.svg", 14, 6)
            RegisterButtonClick(btnBrowse, ObjBindMethod(this, "BrowseRoot"))
            RegisterButtonClick(btnAutoRoot, ObjBindMethod(this, "UseAutomaticRoot"))
            RegisterButtonClick(btnClearLearned, ObjBindMethod(this, "ClearLearned"))
            RegisterButtonClick(btnSave, ObjBindMethod(this, "Save"), ButtonFeedbackMode.Dismissive)
            RegisterButtonClick(btnCancel, ObjBindMethod(this, "Close"), ButtonFeedbackMode.Dismissive)
            this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
            this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
            ShowApplicationWindow(this.gui, "w" windowWidth " h435")
            ShowSingleLineEditFromStart(targetInput.Edit)
        } catch as openErr {
            this.Close()
            throw openErr
        }
    }

    GetLearnedText() {
        if !this.learnedActors.Length
            return Tr("尚未从真实升级过程学习到更新程序特征。")
        lines := []
        for signature in this.learnedActors {
            normalized := App.maintenanceActorMatcher.NormalizeLearnedSignature(
                signature, this.state.MaintenanceConfig.InstallRoot)
            if normalized != "" {
                actorPath := App.maintenanceActorMatcher.SignatureExecutablePath(
                    normalized)
                lines.Push(Tr("完整路径：{1}", actorPath))
            }
        }
        if !lines.Length
            return Tr("尚未从真实升级过程学习到更新程序特征。")
        text := ""
        for index, line in lines
            text .= (index > 1 ? "`r`n" : "") line
        return text
    }

    GetStatusText() {
        if !this.state
            return ""
        if this.state.ExplicitMaintenance
            return Tr("当前状态：显式升级维护已开始，正在等待结束命令")
        switch this.state.MaintenanceMode {
            case MaintenancePhase.Arbitrating:
                return Tr("当前状态：正在判断本次退出是否由升级引起")
            case MaintenancePhase.Updating:
                return Tr("当前状态：已暂停自动启动，正在等待升级完成")
            case MaintenancePhase.Stabilizing:
                return Tr("当前状态：升级活动已结束，正在确认程序文件稳定")
            case MaintenancePhase.Recovering:
                return Tr("当前状态：已从上次运行恢复未完成的升级保护")
            case MaintenancePhase.TimedOut:
                return Tr("当前状态：升级等待超时，需要确认后恢复")
            default:
                return Tr("当前状态：正常守护")
        }
    }

    BrowseRoot(*) {
        if !this.IsOpen()
            return
        this.gui.Opt("+OwnDialogs")
        initialRoot := DirExist(this.rootEdit.Value) ? this.rootEdit.Value : GetDefaultMaintenanceRoot(this.path)
        selected := SelectDirectoryWithModernDialog(this.gui.Hwnd,
            initialRoot, Tr("选择软件安装目录"))
        if selected && this.IsOpen()
            this.rootEdit.Value := selected
    }

    UseAutomaticRoot(*) {
        if this.IsOpen()
            this.rootEdit.Value := GetDefaultMaintenanceRoot(this.path)
    }

    ClearLearned(*) {
        if !this.IsOpen()
            return
        this.learnedActors := []
        this.learnedActorsCleared := true
        this.learnedEdit.Value := this.GetLearnedText()
        ScheduleHideTextCaret(this.learnedEdit.Hwnd)
    }

    ResumeProtection(*) {
        if !this.IsOpen() || !this.state
            return
        QueueExclusiveGuardMutation(this, "resume-protection",
            ObjBindMethod(this, "ResumeProtectionTransaction"))
    }

    ResumeProtectionTransaction() {
        if !this.IsOpen() || !this.state
            return
        path := this.path
        stateObj := this.state
        if !App.appStates.Has(path) || App.appStates[path] != stateObj
            || !App.maintenanceCoordinator.IsBlocking(stateObj) {
            this.Close()
            return
        }
        App.maintenanceCoordinator.ResetSession(path, stateObj, false)
        stateObj.SafetyFingerprint := App.targetFileInspector.GetFingerprint(path)
        stateObj.SafetyStableSince := 0
        stateObj.LastFileActivityTicks := GetTickCount64()
        App.maintenanceCoordinator.SaveJournal()
        App.maintenanceCoordinator.EnsureWatcher(path, stateObj)
        UpdateState(path, Tr("初始化..."), "", 0, false,
            GuardStatusKind.Initializing)
        this.Close()
        App.guardRuntime.ScheduleRestart(path, 200)
        LogMsg(Tr("用户结束了升级等待，重新执行安全启动检查：{1}", path))
    }

    Save(*) {
        if !this.IsOpen()
            return
        QueueExclusiveGuardMutation(this, "save",
            ObjBindMethod(this, "SaveTransaction"))
    }

    SaveTransaction() {
        if !this.IsOpen() || !this.state
            return
        path := this.path
        stateObj := this.state
        if !App.appStates.Has(path) || App.appStates[path] != stateObj {
            this.Close()
            return
        }
        enableProtection := this.enableCheck.Value != 0
        rootPath := NormalizeMaintenanceRoot(this.rootEdit.Value, path)
        detectionSeconds := ParseBoundedInteger(this.detectionEdit.Value, 2, 120)
        stableSeconds := ParseBoundedInteger(this.stableEdit.Value, 2, 300)
        maxWaitSeconds := ParseBoundedInteger(this.maxWaitEdit.Value, 60, 86400)
        maintenanceSubject := App.targetIdentityService
            .GetMaintenanceSubjectPath(path)
        if enableProtection && (!IsMaintenanceSupportedTarget(path) || !DirExist(rootPath)
            || !App.targetFileInspector.IsWithinRoot(maintenanceSubject,
                rootPath)) {
            ShowDarkMsgBoxDeferred(Tr("升级保护仅支持具有有效完整路径的程序或脚本，安装足迹目录必须存在并包含目标文件。"),
                Tr("设置无效"), "Error", this.gui)
            return
        }
        if !detectionSeconds || !stableSeconds || !maxWaitSeconds || maxWaitSeconds <= stableSeconds {
            ShowDarkMsgBoxDeferred(Tr("时间设置无效。`n`n退出检测窗口：2-120 秒`n文件稳定等待：2-300 秒`n最长升级等待：60-86400 秒，且必须大于稳定等待时间"),
                Tr("设置无效"), "Error", this.gui)
            return
        }
        learnedActorsToSave := []
        learnedSeen := Map()
        learnedSeen.CaseSense := "Off"
        for signature in this.learnedActors {
            if !learnedSeen.Has(signature) {
                learnedSeen[signature] := true
                learnedActorsToSave.Push(signature)
            }
        }
        ; 窗口打开期间后台可能学到新特征；除非用户明确清空，否则合并实时值。
        if !this.learnedActorsCleared {
            for signature in stateObj.MaintenanceConfig.LearnedActors {
                if !learnedSeen.Has(signature) {
                    learnedSeen[signature] := true
                    learnedActorsToSave.Push(signature)
                }
            }
        }
        priorMaintenance := App.maintenanceConfigCodec.Normalize(
            stateObj.MaintenanceConfig, path)
        priorInstallRoot := priorMaintenance.InstallRoot
        defaultRoot := GetDefaultMaintenanceRoot(path)
        nextMaintenance := App.maintenanceConfigCodec.Normalize({
            Enabled: enableProtection,
            InstallRoot: rootPath,
            RootIsCustom: GetCanonicalPath(rootPath) != GetCanonicalPath(defaultRoot),
            DetectionSeconds: detectionSeconds,
            StableSeconds: stableSeconds,
            MaxWaitSeconds: maxWaitSeconds,
            LearnedActors: learnedActorsToSave
        }, path)
        if App.maintenanceConfigCodec.Equals(priorMaintenance,
            nextMaintenance) {
            if App.appsDirty && !SaveAppsToIni() {
                ShowDarkMsgBoxDeferred(Tr("保存软件升级保护设置失败，请查看运行日志。"),
                    Tr("保存失败"), "Error", this.gui)
                return
            }
            this.Close()
            return
        }
        undoState := CaptureAppConfigState()
        stateObj.MaintenanceConfig := nextMaintenance
        rootChanged := !PathsEquivalent(priorInstallRoot, nextMaintenance.InstallRoot)
        protectionDisabled := priorMaintenance.Enabled && !nextMaintenance.Enabled
        if protectionDisabled {
            App.maintenanceCoordinator.CleanupTarget(path, stateObj, true)
            if stateObj.Enabled {
                UpdateState(path, Tr("初始化..."), "", 0, false,
                    GuardStatusKind.Initializing)
                App.guardRuntime.ScheduleRestart(path, 200)
            }
        } else if nextMaintenance.Enabled {
            if rootChanged
                App.maintenanceCoordinator.CloseWatcher(stateObj)
            fingerprintTarget := stateObj.ResolvedTarget != "" ? stateObj.ResolvedTarget : path
            stateObj.SafetyFingerprint := App.targetFileInspector
                .GetFingerprint(fingerprintTarget)
            stateObj.SafetyStableSince := GetTickCount64()
            App.maintenanceCoordinator.EnsureWatcher(path, stateObj)
            App.maintenanceCoordinator.SaveJournal()
        }
        CommitUndoState(undoState,
            CreateAppHistoryAction("maintenance", path))
        if !SaveAppsToIni() {
            ShowDarkMsgBoxDeferred(Tr("保存软件升级保护设置失败，请查看运行日志。"),
                Tr("保存失败"), "Error", this.gui)
            return
        }
        this.Close()
        LogMsg(Tr("已更新软件升级保护设置：{1}", path))
    }

    Close(*) {
        this.DestroyGui()
        this.path := ""
        this.state := ""
        this.enableCheck := ""
        this.rootEdit := ""
        this.detectionEdit := ""
        this.stableEdit := ""
        this.maxWaitEdit := ""
        this.learnedEdit := ""
        this.learnedActors := []
        this.learnedActorsCleared := false
    }
}
