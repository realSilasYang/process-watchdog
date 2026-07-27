; 开源项目捐赠窗口。
; 二维码直接读取发行包内的 PNG 资源，不创建临时文件或外部渲染进程；
; 缺少单张资源时仍显示另一张二维码，并在原位置给出明确提示。

class DonationWindow extends ManagedWindow {
    __New(mainGui) {
        this.owner := mainGui
        this.messageText := ""
        this.qrLabels := []
        this.qrPictures := []
    }

    Show(*) {
        if this.ShowExisting()
            return

        if !this.CreateOwnedGui(this.owner, "", Tr("支持开源项目"))
            return
        try {
            this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
            this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
            InitializeApplicationWindow(this.gui)

            compactLayout := LocalizationService.UsesCompactLayout()
            windowWidth := compactLayout ? 570 : 680
            contentMargin := compactLayout ? 34 : 38
            qrSize := compactLayout ? 180 : 190
            qrGap := compactLayout ? 36 : 52
            firstQrX := (windowWidth - qrSize * 2 - qrGap) // 2
            secondQrX := firstQrX + qrSize + qrGap

            ; 说明文字的真实高度取决于语言、字体和 DPI，不能再用固定高度。
            ; 先让原生 Text 控件完成换行测量，再以它的实际底边安排分隔线和二维码。
            this.messageText := this.gui.Add("Text", "x" contentMargin
                " y22 w" (windowWidth - contentMargin * 2)
                " Center BackgroundTrans c"
                UiThemeService.Color("Text"),
                Tr("如果小助手为您节省了排查问题和恢复程序的时间，欢迎通过下方二维码打赏作者！`n进程守护小助手持续保持开源，项目的长期维护有赖于您的支持和鼓励~"))
            this.messageText.GetPos(, &messageY, , &messageHeight)
            dividerY := messageY + messageHeight + 17
            this.gui.Add("Text", "x" contentMargin " y" dividerY
                " w" (windowWidth - contentMargin * 2) " h1 Background"
                UiThemeService.Color("Divider"))
            qrLabelY := dividerY + 15

            this.AddQrCode(firstQrX, qrLabelY, qrSize, Tr("微信支付"),
                GetApplicationAssetPath("donate\微信个人收款码-界面.png"))
            this.AddQrCode(secondQrX, qrLabelY, qrSize, Tr("支付宝"),
                GetApplicationAssetPath("donate\支付宝个人收款码-界面.png"))

            windowHeight := qrLabelY + 24 + qrSize + 22
            this.gui.Show("w" windowWidth " h" windowHeight)
        } catch as openErr {
            this.Close()
            throw openErr
        }
    }

    AddQrCode(x, y, size, label, imagePath) {
        if FileExist(imagePath) {
            ; 发行用二维码保留了扫码所需静区，但移除了源图中过量的透明外边。
            ; 标签与深色二维码底板保留少量间距，避免浅色主题下文字被底板遮挡。
            picture := this.gui.Add("Picture",
                "x" x " y" (y + 24) " w" size " h" size, imagePath)
            this.qrPictures.Push(picture)
        } else {
            this.gui.Add("Text", "x" x " y" (y + 24)
                " w" size " h" size " Center 0x200 Background"
                UiThemeService.Color("Surface") " c"
                UiThemeService.Color("MutedText"),
                Tr("二维码图片未找到"))
        }
        this.gui.SetFont("s10 c" UiThemeService.Color("MutedText"),
            LocalizationService.GetUiFontName())
        labelControl := this.gui.Add("Text", "x" x " y" y " w" size
            " h20 Center BackgroundTrans", label)
        this.qrLabels.Push(labelControl)
        this.gui.SetFont("s10 c" UiThemeService.Color("Text"),
            LocalizationService.GetUiFontName())
    }

    Close(*) {
        this.DestroyGui()
        this.messageText := ""
        this.qrLabels := []
        this.qrPictures := []
    }
}
