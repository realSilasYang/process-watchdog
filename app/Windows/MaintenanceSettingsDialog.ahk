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
        if !this.CreateOwnedGui(this.owner, "-MinimizeBox -MaximizeBox", "软件升级保护")
            return
        try {
            SetDarkTitleBar(this.gui.Hwnd)
            SetWindowIcon(this.gui.Hwnd, A_ScriptDir "\watchdog.ico")
            this.gui.BackColor := "1E1E1E"
            this.gui.SetFont("s10 cWhite", "Microsoft YaHei")

            this.gui.Add("Text", "x20 y14 w500 h20 BackgroundTrans", "守护目标:")
            targetInput := AddCenteredSingleLineEdit(this.gui, 20, 38, 500, 26, path, "ReadOnly", "2A2A2A")
            RegisterTextInputControl(targetInput.Edit, true)
            SetDarkControl(targetInput.Edit.Hwnd)

            this.enableCheck := this.gui.Add("CheckBox", "x20 y76 w320 h24", "自动识别升级并保护启动过程")
            this.enableCheck.Value := stateObj.MaintenanceConfig.Enabled ? 1 : 0
            SetDarkControl(this.enableCheck.Hwnd)
            RegisterHandCursorControl(this.enableCheck)

            this.gui.Add("Text", "x20 y108 w300 h20 BackgroundTrans", "安装足迹目录:")
            rootInput := AddCenteredSingleLineEdit(this.gui, 20, 132, 388, 26,
                stateObj.MaintenanceConfig.InstallRoot, "", "333333")
            this.rootEdit := rootInput.Edit
            btnBrowse := this.gui.Add("Text", "x418 y132 w48 h26 Center 0x200 Background333333 cWhite", "浏览")
            btnAutoRoot := this.gui.Add("Text", "x476 y132 w44 h26 Center 0x200 Background333333 cWhite", "自动")

            this.gui.Add("Text", "x20 y176 w145 h20 BackgroundTrans", "退出检测窗口（秒）:")
            detectionInput := AddCenteredSingleLineEdit(this.gui, 20, 200, 105, 26,
                stateObj.MaintenanceConfig.DetectionSeconds, "Number")
            this.detectionEdit := detectionInput.Edit
            this.gui.Add("Text", "x190 y176 w145 h20 BackgroundTrans", "文件稳定等待（秒）:")
            stableInput := AddCenteredSingleLineEdit(this.gui, 190, 200, 105, 26,
                stateObj.MaintenanceConfig.StableSeconds, "Number")
            this.stableEdit := stableInput.Edit
            this.gui.Add("Text", "x360 y176 w160 h20 BackgroundTrans", "最长升级等待（秒）:")
            maxWaitInput := AddCenteredSingleLineEdit(this.gui, 360, 200, 105, 26,
                stateObj.MaintenanceConfig.MaxWaitSeconds, "Number")
            this.maxWaitEdit := maxWaitInput.Edit

            this.gui.Add("Text", "x20 y246 w240 h20 BackgroundTrans", "已自动学习的更新程序特征:")
            btnClearLearned := this.gui.Add("Text", "x420 y242 w100 h26 Center 0x200 Background333333 cWhite", "清除记录")
            this.learnedEdit := this.gui.Add("Edit",
                "x20 y270 w500 h70 Background252526 cD8D8D8 -E0x200 ReadOnly Multi VScroll",
                this.GetLearnedText())
            RegisterTextInputControl(this.learnedEdit, true)
            SetDarkControl(this.learnedEdit.Hwnd)

            this.gui.Add("Text", "x20 y352 w500 h24 0x200 BackgroundTrans cAFAFAF",
                this.GetStatusText())

            btnSaveX := App.maintenanceCoordinator.IsBlocking(stateObj) ? 282 : 185
            btnCancelX := App.maintenanceCoordinator.IsBlocking(stateObj) ? 372 : 275
            if App.maintenanceCoordinator.IsBlocking(stateObj) {
                btnResume := this.gui.Add("Text",
                    "x50 y390 w210 h28 Center 0x200 Background6B6244 cWhite",
                    "结束升级等待并恢复守护")
                RegisterHoverButton(btnResume, "6B6244")
                RegisterButtonClick(btnResume, ObjBindMethod(this, "ResumeProtection"),
                    ButtonFeedbackMode.Dismissive)
            }
            btnSave := this.gui.Add("Text", "x" btnSaveX " y390 w80 h28 Center 0x200 Background0078D7 cWhite", "保存")
            btnCancel := this.gui.Add("Text", "x" btnCancelX " y390 w80 h28 Center 0x200 Background333333 cWhite", "取消")

            for editControl in [this.rootEdit, this.detectionEdit, this.stableEdit, this.maxWaitEdit]
                SetDarkControl(editControl.Hwnd)
            RegisterHoverButton(btnBrowse, "333333")
            RegisterHoverButton(btnAutoRoot, "333333")
            RegisterHoverButton(btnClearLearned, "333333")
            RegisterHoverButton(btnSave, "0078D7")
            RegisterHoverButton(btnCancel, "333333")
            RegisterButtonClick(btnBrowse, ObjBindMethod(this, "BrowseRoot"))
            RegisterButtonClick(btnAutoRoot, ObjBindMethod(this, "UseAutomaticRoot"))
            RegisterButtonClick(btnClearLearned, ObjBindMethod(this, "ClearLearned"))
            RegisterButtonClick(btnSave, ObjBindMethod(this, "Save"), ButtonFeedbackMode.Dismissive)
            RegisterButtonClick(btnCancel, ObjBindMethod(this, "Close"), ButtonFeedbackMode.Dismissive)
            this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
            this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
            this.gui.Show("w540 h435")
            ShowSingleLineEditFromStart(targetInput.Edit)
        } catch as openErr {
            this.Close()
            throw openErr
        }
    }

    GetLearnedText() {
        if !this.learnedActors.Length
            return "尚未从真实升级过程学习到更新程序特征。"
        lines := []
        for signature in this.learnedActors {
            normalized := App.maintenanceActorMatcher.NormalizeLearnedSignature(
                signature, this.state.MaintenanceConfig.InstallRoot)
            if normalized != "" {
                actorPath := App.maintenanceActorMatcher.SignatureExecutablePath(
                    normalized)
                lines.Push("完整路径：" actorPath)
            }
        }
        if !lines.Length
            return "尚未从真实升级过程学习到更新程序特征。"
        text := ""
        for index, line in lines
            text .= (index > 1 ? "`r`n" : "") line
        return text
    }

    GetStatusText() {
        if !this.state
            return ""
        if this.state.ExplicitMaintenance
            return "当前状态：显式升级维护已开始，正在等待结束命令"
        switch this.state.MaintenanceMode {
            case MaintenancePhase.Arbitrating:
                return "当前状态：正在判断本次退出是否由升级引起"
            case MaintenancePhase.Updating:
                return "当前状态：已暂停自动启动，正在等待升级完成"
            case MaintenancePhase.Stabilizing:
                return "当前状态：升级活动已结束，正在确认程序文件稳定"
            case MaintenancePhase.Recovering:
                return "当前状态：已从上次运行恢复未完成的升级保护"
            case MaintenancePhase.TimedOut:
                return "当前状态：升级等待超时，需要确认后恢复"
            default:
                return "当前状态：正常守护"
        }
    }

    BrowseRoot(*) {
        if !this.IsOpen()
            return
        this.gui.Opt("+OwnDialogs")
        initialRoot := DirExist(this.rootEdit.Value) ? this.rootEdit.Value : GetDefaultMaintenanceRoot(this.path)
        selected := FileSelect("D", initialRoot, "选择软件安装目录")
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
        path := this.path
        stateObj := this.state
        App.maintenanceCoordinator.ResetSession(path, stateObj, false)
        stateObj.SafetyFingerprint := App.targetFileInspector.GetFingerprint(path)
        stateObj.SafetyStableSince := 0
        stateObj.LastFileActivityTicks := GetTickCount64()
        App.maintenanceCoordinator.SaveJournal()
        App.maintenanceCoordinator.EnsureWatcher(path, stateObj)
        UpdateState(path, "初始化...")
        this.Close()
        App.guardRuntime.ScheduleRestart(path, 200)
        LogMsg("用户结束了升级等待，重新执行安全启动检查: " path)
    }

    Save(*) {
        if !this.IsOpen() || !this.state
            return
        path := this.path
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
            ShowDarkMsgBox("升级保护仅支持具有有效完整路径的程序或脚本，安装足迹目录必须存在并包含目标文件。", "设置无效", "Error", this.gui)
            return
        }
        if !detectionSeconds || !stableSeconds || !maxWaitSeconds || maxWaitSeconds <= stableSeconds {
            ShowDarkMsgBox("时间设置无效。`n`n退出检测窗口：2-120 秒`n文件稳定等待：2-300 秒`n最长升级等待：60-86400 秒，且必须大于稳定等待时间", "设置无效", "Error", this.gui)
            return
        }
        stateObj := this.state
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
                ShowDarkMsgBox("保存软件升级保护设置失败，请查看运行日志。",
                    "保存失败", "Error", this.gui)
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
                UpdateState(path, "初始化...")
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
        CommitUndoState(undoState)
        if !SaveAppsToIni() {
            ShowDarkMsgBox("保存软件升级保护设置失败，请查看运行日志。",
                "保存失败", "Error", this.gui)
            return
        }
        this.Close()
        LogMsg("已更新软件升级保护设置: " path)
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
