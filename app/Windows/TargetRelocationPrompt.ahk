; 守护目标更名候选确认窗口。
; 窗口只展示核心服务已经核验的强证据候选；确认操作进入守护配置串行队列，
; 关闭或忽略仅释放当前候选，不会修改路径，也不会阻塞其它目标的守护计时器。

class TargetRelocationPrompt extends ManagedWindow {
    __New(mainGui) {
        this.owner := mainGui
        this.candidate := ""
        this.queuedCandidates := []
        this.oldPathEdit := ""
        this.newPathEdit := ""
        this.descriptionLabel := ""
        this.evidenceLabel := ""
        this.updateButton := ""
        this.ignoreButton := ""
        this.closingSilently := false
    }

    Show(candidate) {
        if !IsObject(candidate) || !candidate.HasOwnProp("Token")
            return false
        if !App.targetRelocationService.ValidateCandidate(candidate)
            return false
        if IsObject(this.candidate) {
            if this.candidate.Token == candidate.Token {
                this.ShowExisting()
                return true
            }
            if !this.HasQueuedToken(candidate.Token)
                this.queuedCandidates.Push(candidate)
            return true
        }
        return this.OpenCandidate(candidate)
    }

    OpenCandidate(candidate) {
        if !App.targetRelocationService.ValidateCandidate(candidate)
            return false
        this.candidate := candidate
        compactLayout := LocalizationService.UsesCompactLayout()
        windowWidth := compactLayout ? 560 : 680
        contentWidth := windowWidth - 48
        if !this.CreateOwnedGui(this.owner,
            "-MinimizeBox -MaximizeBox", Tr("确认目标新位置")) {
            this.candidate := ""
            return false
        }
        try {
            InitializeApplicationWindow(this.gui, "norm s10")
            this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
            this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))

            this.gui.SetFont("s11 bold c" UiThemeService.Color("Text"),
                LocalizationService.GetLanguageSystemUiFontName())
            this.gui.Add("Text", "x24 y20 w" contentWidth
                " h26 BackgroundTrans", Tr("检测到守护目标可能已更名"))
            this.gui.SetFont("norm s9 c" UiThemeService.Color("MutedText"),
                LocalizationService.GetUiFontName())
            isVersionedEntry := candidate.HasOwnProp("Evidence")
                && candidate.Evidence == "VersionedEntryUnique"
            descriptionText := isVersionedEntry
                ? Tr("升级期间发现唯一同名新版本入口；已记录并持续校验候选 SHA-256。确认后将更新守护目标，名称、图标和启动设置保持不变。")
                : Tr("小助手找到了与原文件内容完全一致的新路径。确认后将更新守护目标，名称、图标和启动设置保持不变。")
            this.descriptionLabel := this.gui.Add("Text",
                "x24 y52 w" contentWidth " h42 BackgroundTrans",
                descriptionText)

            this.gui.SetFont("norm s9 c" UiThemeService.Color("Text"),
                LocalizationService.GetUiFontName())
            this.gui.Add("Text", "x24 y102 w" contentWidth
                " h18 BackgroundTrans", Tr("原路径："))
            oldInput := AddCenteredSingleLineEdit(this.gui, 24, 122,
                contentWidth, 28, candidate.OldPath, "ReadOnly",
                UiThemeService.Color("Surface"))
            this.oldPathEdit := oldInput.Edit
            RegisterTextInputControl(this.oldPathEdit, true)
            SetDarkControl(this.oldPathEdit.Hwnd)

            this.gui.Add("Text", "x24 y158 w" contentWidth
                " h18 BackgroundTrans", Tr("新路径："))
            newInput := AddCenteredSingleLineEdit(this.gui, 24, 178,
                contentWidth, 28, candidate.NewPath, "ReadOnly",
                UiThemeService.Color("Surface"))
            this.newPathEdit := newInput.Edit
            RegisterTextInputControl(this.newPathEdit, true)
            SetDarkControl(this.newPathEdit.Hwnd)

            this.gui.SetFont("norm s9 c" UiThemeService.Color("MutedText"),
                LocalizationService.GetUiFontName())
            evidenceText := isVersionedEntry
                ? Tr("唯一同名新版本入口 / SHA-256")
                : Tr("内容完全一致 / SHA-256")
            this.evidenceLabel := this.gui.Add("Text",
                "x24 y216 w" contentWidth
                " h20 Center BackgroundTrans",
                Tr("识别依据：") evidenceText)
            this.gui.Add("Text", "x24 y246 w" contentWidth
                " h1 Background" UiThemeService.Color("Divider"))

            buttonWidth := compactLayout ? 128 : 160
            buttonGap := 14
            buttonStartX := Floor((windowWidth - buttonWidth * 2
                - buttonGap) / 2)
            this.updateButton := this.gui.Add("Button",
                "x" buttonStartX " y264 w" buttonWidth " h34",
                Tr("更新守护路径"))
            this.ignoreButton := this.gui.Add("Button",
                "x" (buttonStartX + buttonWidth + buttonGap)
                    " y264 w" buttonWidth " h34", Tr("忽略"))
            RegisterHoverButton(this.updateButton,
                UiThemeService.Color("Primary"))
            SetButtonTextColor(this.updateButton,
                UiThemeService.Color("ButtonText"))
            RegisterHoverButton(this.ignoreButton,
                UiThemeService.Color("Toolbar"))
            SetButtonTextColor(this.ignoreButton,
                UiThemeService.Color("ToolbarText"))
            RegisterButtonClick(this.updateButton,
                ObjBindMethod(this, "Confirm"),
                ButtonFeedbackMode.Dismissive)
            RegisterButtonClick(this.ignoreButton,
                ObjBindMethod(this, "Ignore"),
                ButtonFeedbackMode.Dismissive)
            ShowApplicationWindow(this.gui, "w" windowWidth " h318")
            ShowSingleLineEditFromStart(this.oldPathEdit)
            ShowSingleLineEditFromStart(this.newPathEdit)
            this.updateButton.Focus()
            return true
        } catch as openError {
            this.CloseSilently()
            throw openError
        }
    }

    Confirm(*) {
        candidate := this.candidate
        if !IsObject(candidate)
            return
        if QueueTargetRelocationConfirmation(candidate)
            this.CloseSilently()
        else {
            App.targetRelocationService.Invalidate(candidate)
            this.CloseSilently()
        }
    }

    Ignore(*) {
        candidate := this.candidate
        if IsObject(candidate)
            IgnoreTargetRelocation(candidate)
        this.CloseSilently()
    }

    Close(*) {
        if this.closingSilently {
            this.CloseSilently()
            return
        }
        this.Ignore()
    }

    Invalidate(candidate) {
        if !IsObject(candidate) || !candidate.HasOwnProp("Token")
            return false
        filtered := []
        for queuedCandidate in this.queuedCandidates {
            if queuedCandidate.Token != candidate.Token
                filtered.Push(queuedCandidate)
        }
        this.queuedCandidates := filtered
        if IsObject(this.candidate)
            && this.candidate.Token == candidate.Token {
            this.CloseSilently()
            return true
        }
        return false
    }

    HasQueuedToken(token) {
        for candidate in this.queuedCandidates {
            if candidate.Token == token
                return true
        }
        return false
    }

    CloseSilently(*) {
        this.closingSilently := true
        try this.DestroyGui()
        finally this.closingSilently := false
        this.candidate := ""
        this.oldPathEdit := ""
        this.newPathEdit := ""
        this.updateButton := ""
        this.ignoreButton := ""
        if this.queuedCandidates.Length
            SetTimer(ObjBindMethod(this, "ShowNext"), -1)
    }

    ShowNext(*) {
        if this.IsOpen() || IsObject(this.candidate)
            return
        while this.queuedCandidates.Length {
            candidate := this.queuedCandidates.RemoveAt(1)
            if this.OpenCandidate(candidate)
                return
        }
    }

    Shutdown(*) {
        this.queuedCandidates := []
        this.CloseSilently()
    }
}
