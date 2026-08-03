; 主窗口的关于入口。
; 产品信息、更新检查、项目地址和打赏入口集中在一个只读子窗口；更新任务仍由
; 应用级服务持有，窗口关闭后不会中断后台检查，结果回调只同步仍存在的控件。

class AboutWindow extends ManagedWindow {
    static ProjectHomeUrl :=
        "https://github.com/realSilasYang/process-watchdog"

    __New(mainGui) {
        this.owner := mainGui
        this.logo := ""
        this.productName := ""
        this.subtitle := ""
        this.versionLabel := ""
        this.versionValue := ""
        this.runtimeLabel := ""
        this.runtimeValue := ""
        this.topDivider := ""
        this.infoDivider := ""
        this.bottomDivider := ""
        this.checkUpdateButton := ""
        this.projectButton := ""
        this.donationButton := ""
        this.updateCheckActive := false
    }

    Show(*) {
        if this.ShowExisting()
            return

        if !this.CreateOwnedGui(this.owner, "-MinimizeBox -MaximizeBox",
                Tr("关于"))
            return
        try {
            this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
            this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
            compactLayout := LocalizationService.UsesCompactLayout()
            fontName := LocalizationService.GetUiFontName()
            windowWidth := compactLayout ? 520 : 680
            contentX := compactLayout ? 50 : 60
            contentWidth := windowWidth - contentX * 2
            InitializeApplicationWindow(this.gui, "s10", fontName)

            logoSize := 44
            this.logo := this.gui.Add("Picture",
                "x" Floor((windowWidth - logoSize) / 2)
                    " y20 w" logoSize " h" logoSize,
                GetApplicationIconPath())
            this.gui.SetFont("bold s14 c" UiThemeService.Color("Text"),
                LocalizationService.GetLanguageSystemUiFontName())
            this.productName := this.gui.Add("Text",
                "x" contentX " y70 w" contentWidth
                    " h30 Center 0x200 BackgroundTrans",
                Tr("进程守护小助手"))
            this.gui.SetFont("norm s9 c" UiThemeService.Color("MutedText"),
                fontName)
            this.subtitle := this.gui.Add("Text",
                "x" contentX " y106 w" contentWidth
                    " h22 Center 0x200 BackgroundTrans",
                Tr("持续守护重要程序与自动化任务，让日常工作稳定运行"))

            this.topDivider := this.gui.Add("Text",
                "x" contentX " y140 w" contentWidth
                    " h1 Background" UiThemeService.Color("Divider"))
            infoCenterX := windowWidth // 2
            infoGap := compactLayout ? 14 : 20
            leftInfoWidth := infoCenterX - infoGap - contentX
            rightInfoX := infoCenterX + infoGap
            rightInfoWidth := windowWidth - contentX - rightInfoX
            versionCaption := this.SplitFieldCaption(Tr("当前版本："))
            runtimeCaption := this.SplitFieldCaption(Tr("运行环境："))
            this.gui.SetFont("norm s10 c" UiThemeService.Color("MutedText"),
                fontName)
            this.versionLabel := this.gui.Add("Text",
                "x" contentX " y153 w" leftInfoWidth
                    " h22 Center 0x200 BackgroundTrans", versionCaption)
            this.runtimeLabel := this.gui.Add("Text",
                "x" rightInfoX " y153 w" rightInfoWidth
                    " h22 Center 0x200 BackgroundTrans", runtimeCaption)
            this.gui.SetFont("norm s11 c" UiThemeService.Color("Text"),
                fontName)
            this.versionValue := this.gui.Add("Text",
                "x" contentX " y180 w" leftInfoWidth
                    " h28 Center 0x200 BackgroundTrans",
                GetApplicationEditionSummary())
            this.runtimeValue := this.gui.Add("Text",
                "x" rightInfoX " y180 w" rightInfoWidth
                    " h28 Center 0x200 BackgroundTrans",
                GetAutoHotkeyRuntimeSummary())
            this.infoDivider := this.gui.Add("Text",
                "x" infoCenterX " y153 w1 h55 Background"
                    UiThemeService.Color("Divider"))
            this.bottomDivider := this.gui.Add("Text",
                "x" contentX " y221 w" contentWidth
                    " h1 Background" UiThemeService.Color("Divider"))

            updateWidth := compactLayout ? 126 : 205
            projectWidth := compactLayout ? 112 : 175
            donationWidth := compactLayout ? 88 : 96
            actionGap := compactLayout ? 10 : 12
            actionWidth := updateWidth + projectWidth + donationWidth
                + actionGap * 2
            actionX := Floor((windowWidth - actionWidth) / 2)
            this.gui.SetFont("bold s10 c" UiThemeService.Color("ToolbarText"),
                LocalizationService.GetLanguageSystemUiFontName())
            this.checkUpdateButton := this.gui.Add("Text",
                "x" actionX " y237 w" updateWidth
                    " h36 Center 0x200 Background"
                    UiThemeService.Color("Toolbar") " c"
                    UiThemeService.Color("ToolbarText"), Tr("检查更新"))
            this.donationButton := this.gui.Add("Text",
                "x" (actionX + updateWidth + actionGap)
                    " y237 w" donationWidth
                    " h36 Center 0x200 Background"
                    UiThemeService.Color("Toolbar") " c"
                    UiThemeService.Color("ToolbarText"), Tr("打赏"))
            this.projectButton := this.gui.Add("Text",
                "x" (actionX + updateWidth + donationWidth + actionGap * 2)
                    " y237 w" projectWidth
                    " h36 Center 0x200 Background"
                    UiThemeService.Color("Toolbar") " c"
                    UiThemeService.Color("ToolbarText"), Tr("开源地址"))
            for button in [this.checkUpdateButton, this.donationButton,
                    this.projectButton]
                RegisterHoverButton(button, UiThemeService.Color("Toolbar"))
            SetButtonLucideIcon(this.checkUpdateButton,
                "refresh-cw-action.svg", 15, 7)
            SetButtonSvgIcon(this.projectButton,
                GetApplicationAssetPath("ui-icons\external-link.svg"), 14, 7)
            SetButtonLucideIcon(this.donationButton, "heart.svg", 15, 7)
            SetButtonTooltip(this.projectButton, Tr("点个 star 吧~"))
            SetButtonTooltip(this.donationButton,
                Tr("快揭不开锅了（≥Д≤）"))
            RegisterButtonClick(this.checkUpdateButton,
                ObjBindMethod(this, "CheckUpdate"))
            RegisterButtonClick(this.projectButton,
                ObjBindMethod(this, "OpenProjectHomepage"))
            RegisterButtonClick(this.donationButton,
                ObjBindMethod(this, "OpenDonation"))
            this.SetUpdateCheckActive(
                App.applicationUpdateService.IsChecking())
            ShowApplicationWindow(this.gui, "w" windowWidth " h291")
        } catch as openErr {
            this.Close()
            throw openErr
        }
    }

    SplitFieldCaption(caption) {
        caption := Trim(caption)
        if RegExMatch(caption, "^(.*?)[：:]$", &parts)
            return Trim(parts[1])
        return caption
    }

    OpenProjectHomepage(*) {
        if this.IsOpen()
            try Run(AboutWindow.ProjectHomeUrl)
    }

    OpenDonation(*) {
        if this.IsOpen()
            GuiModules.donation.Show(this.gui)
    }

    CheckUpdate(*) {
        if !this.IsOpen() || this.updateCheckActive
            return
        this.SetUpdateCheckActive(true)
        CheckForApplicationUpdate(this.gui, true)
        this.SetUpdateCheckActive(
            App.applicationUpdateService.IsChecking())
    }

    SetUpdateCheckActive(active) {
        this.updateCheckActive := !!active
        if !this.IsOpen() || !this.checkUpdateButton
            return
        try this.checkUpdateButton.Text := this.updateCheckActive
            ? Tr("正在检查更新…") : Tr("检查更新")
        SetRegisteredButtonEnabled(this.checkUpdateButton,
            !this.updateCheckActive)
    }

    Close(*) {
        this.DestroyGui()
        this.logo := ""
        this.productName := ""
        this.subtitle := ""
        this.versionLabel := ""
        this.versionValue := ""
        this.runtimeLabel := ""
        this.runtimeValue := ""
        this.topDivider := ""
        this.infoDivider := ""
        this.bottomDivider := ""
        this.checkUpdateButton := ""
        this.projectButton := ""
        this.donationButton := ""
        this.updateCheckActive := false
    }
}
