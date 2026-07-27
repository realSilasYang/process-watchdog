; 主窗口的帮助信息入口。
; 该窗口只负责在使用说明、运行日志和反馈页面之间分流；选择后先释放自身的
; 所有权租约，再打开目标内容，避免形成不必要的三级窗口关系。

class SupportInfoWindow extends ManagedWindow {
    static FeedbackUrl := "https://github.com/realSilasYang/process-watchdog/issues?q=sort:updated-desc+is:issue+state:open+"

    __New(mainGui) {
        this.owner := mainGui
        this.guideButton := ""
        this.logButton := ""
        this.feedbackButton := ""
    }

    Show(*) {
        if this.ShowExisting()
            return

        if !this.CreateOwnedGui(this.owner, "", Tr("帮助信息"))
            return
        try {
            this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
            this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
            InitializeApplicationWindow(this.gui)

            compactLayout := LocalizationService.UsesCompactLayout()
            windowWidth := compactLayout ? 220 : 300
            buttonWidth := compactLayout ? 150 : 220
            buttonX := (windowWidth - buttonWidth) // 2

            this.gui.SetFont("s10 bold c" UiThemeService.Color("ButtonText"),
                LocalizationService.GetLanguageSystemUiFontName())
            this.guideButton := this.gui.Add("Button",
                "x" buttonX " y18 w" buttonWidth " h36",
                Tr("使用说明"))
            this.logButton := this.gui.Add("Button",
                "x" buttonX " y62 w" buttonWidth " h36",
                Tr("运行日志"))
            this.feedbackButton := this.gui.Add("Button",
                "x" buttonX " y106 w" buttonWidth " h36",
                Tr("提交反馈"))

            for button in [this.guideButton, this.logButton,
                    this.feedbackButton] {
                RegisterHoverButton(button, UiThemeService.Color("Toolbar"))
                SetButtonTextColor(button, UiThemeService.Color("ToolbarText"))
            }
            SetButtonLucideIcon(this.guideButton, "book-open.svg", 16, 7)
            SetButtonLucideIcon(this.logButton, "logs.svg", 16, 7)
            SetButtonLucideIcon(this.feedbackButton,
                "message-square-text.svg", 16, 7)
            RegisterButtonClick(this.guideButton,
                ObjBindMethod(this, "OpenGuide"), ButtonFeedbackMode.Dismissive)
            RegisterButtonClick(this.logButton,
                ObjBindMethod(this, "OpenLog"), ButtonFeedbackMode.Dismissive)
            RegisterButtonClick(this.feedbackButton,
                ObjBindMethod(this, "OpenFeedback"),
                ButtonFeedbackMode.Dismissive)
            this.gui.Show("w" windowWidth " h160")
        } catch as openErr {
            this.Close()
            throw openErr
        }
    }

    OpenGuide(*) {
        this.Close()
        ShowHelp()
    }

    OpenLog(*) {
        this.Close()
        ShowLog()
    }

    OpenFeedback(*) {
        this.Close()
        try Run(SupportInfoWindow.FeedbackUrl)
    }

    Close(*) {
        this.DestroyGui()
        this.guideButton := ""
        this.logButton := ""
        this.feedbackButton := ""
    }
}
