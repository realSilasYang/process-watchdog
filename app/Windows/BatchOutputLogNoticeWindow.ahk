; 批处理输出日志尚未生成时的专用提示窗口。
; 它明确说明日志的创建条件，并将长路径放入可选择复制的只读输入框；窗口
; 复用托管生命周期、应用主题、SVG 图标与圆角按钮，不再使用通用旧式消息框。

class BatchOutputLogNoticeWindow extends ManagedWindow {
    __New(mainGui) {
        this.owner := mainGui
        this.iconBadge := ""
        this.pathEdit := ""
        this.confirmButton := ""
        this.logPath := ""
    }

    Show(logPath) {
        this.logPath := String(logPath)
        if this.IsOpen() {
            this.pathEdit.Value := this.logPath
            ShowSingleLineEditFromStart(this.pathEdit)
            this.ShowExisting()
            this.confirmButton.Focus()
            return
        }

        compactLayout := LocalizationService.UsesCompactLayout()
        windowWidth := compactLayout ? 420 : 560
        contentWidth := windowWidth - 48
        if !this.CreateOwnedGui(this.owner,
            "-MinimizeBox -MaximizeBox", Tr("运行日志"))
            return
        try {
            InitializeApplicationWindow(this.gui, "norm s10")

            ; 禁用的圆角图标块只承担视觉提示，不进入 Tab 顺序，也不显示手型光标。
            this.iconBadge := this.gui.Add("Text",
                "x24 y22 w44 h44 Center 0x200 Background"
                    UiThemeService.Color("Surface"), "")
            RegisterHoverButton(this.iconBadge,
                UiThemeService.Color("Surface"))
            SetButtonLucideIcon(this.iconBadge, "file-clock.svg", 24, 0)
            SetRegisteredButtonEnabled(this.iconBadge, false)

            textX := 82
            textWidth := windowWidth - textX - 24
            this.gui.SetFont("s11 bold c" UiThemeService.Color("Text"),
                LocalizationService.GetLanguageSystemUiFontName())
            this.gui.Add("Text", "x" textX " y20 w" textWidth
                " h24 BackgroundTrans", Tr("尚未生成批处理输出日志"))
            this.gui.SetFont("norm s9 c" UiThemeService.Color("MutedText"),
                LocalizationService.GetUiFontName())
            this.gui.Add("Text", "x" textX " y48 w" textWidth
                " h38 BackgroundTrans", Tr(
                    "小助手只有在启动 BAT 或 CMD 项目时才会创建此文件。"))

            this.gui.SetFont("norm s9 c" UiThemeService.Color("MutedText"),
                LocalizationService.GetUiFontName())
            this.gui.Add("Text", "x24 y94 w" contentWidth
                " h18 BackgroundTrans", Tr("日志保存位置："))
            pathInput := AddCenteredSingleLineEdit(this.gui, 24, 116,
                contentWidth, 28, this.logPath, "ReadOnly",
                UiThemeService.Color("Surface"))
            this.pathEdit := pathInput.Edit
            RegisterTextInputControl(this.pathEdit, true)
            SetDarkControl(this.pathEdit.Hwnd)

            this.gui.Add("Text", "x24 y160 w" contentWidth
                " h1 Background" UiThemeService.Color("Divider"))
            buttonWidth := compactLayout ? 82 : 96
            this.confirmButton := this.gui.Add("Text",
                "x" Floor((windowWidth - buttonWidth) / 2)
                    " y176 w" buttonWidth " h30 Center 0x200 Background"
                    UiThemeService.Color("Primary") " c"
                    UiThemeService.Color("ButtonText"), Tr("确定"))
            RegisterHoverButton(this.confirmButton,
                UiThemeService.Color("Primary"))
            RegisterButtonClick(this.confirmButton,
                ObjBindMethod(this, "Close"), ButtonFeedbackMode.Dismissive)
            this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
            this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
            this.gui.Show("w" windowWidth " h224")
            ShowSingleLineEditFromStart(this.pathEdit)
            this.confirmButton.Focus()
        } catch as openErr {
            this.Close()
            throw openErr
        }
    }

    Close(*) {
        this.DestroyGui()
        this.iconBadge := ""
        this.pathEdit := ""
        this.confirmButton := ""
        this.logPath := ""
    }
}
