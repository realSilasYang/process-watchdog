; 开源项目打赏窗口。
; 二维码直接读取发行包内的 PNG 资源，不创建临时文件或外部渲染进程；
; 缺少单张资源时仍显示另一张二维码，并在原位置给出明确提示。

class DonationWindow extends ManagedWindow {
    __New(mainGui) {
        this.owner := mainGui
        this.messageText := ""
        this.qrLabels := []
        this.qrPictures := []
    }

    Show(ownerGui := "", *) {
        if this.ShowExisting()
            return

        actualOwner := Type(ownerGui) == "Gui" ? ownerGui : this.owner
        if !this.CreateOwnedGui(actualOwner, "", Tr("支持开源项目"))
            return
        try {
            this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
            this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
            InitializeApplicationWindow(this.gui)

            compactLayout := LocalizationService.UsesCompactLayout()
            windowWidth := compactLayout ? 500 : 680
            contentMargin := compactLayout ? 34 : 38
            qrSize := compactLayout ? 180 : 190
            qrGap := compactLayout ? 36 : 52
            firstQrX := (windowWidth - qrSize * 2 - qrGap) // 2
            secondQrX := firstQrX + qrSize + qrGap

            ; 说明文字的真实高度取决于语言、字体和 DPI，不能再用固定高度。
            ; 先让原生 Text 控件完成换行测量，再以它的实际底边安排二维码。
            this.messageText := this.gui.Add("Text", "x" contentMargin
                " y22 w" (windowWidth - contentMargin * 2)
                " Center BackgroundTrans c"
                UiThemeService.Color("Text"),
                Tr("如果小助手为您节省了恢复程序的时间，欢迎通过下方二维码打赏作者！`n请选择扶贫方式（≥Д≤）"))
            this.messageText.GetPos(, &messageY, , &messageHeight)
            qrLabelY := messageY + messageHeight + 10

            this.AddQrCode(firstQrX, qrLabelY, qrSize, Tr("微信支付"),
                "微信个人收款码")
            this.AddQrCode(secondQrX, qrLabelY, qrSize, Tr("支付宝"),
                "支付宝个人收款码")

            windowHeight := qrLabelY + 24 + qrSize + 22
            ShowApplicationWindow(this.gui,
                "w" windowWidth " h" windowHeight)
        } catch as openErr {
            this.Close()
            throw openErr
        }
    }

    AddQrCode(x, y, size, label, assetStem) {
        imagePath := this.ResolveQrImagePath(assetStem)
        if FileExist(imagePath) {
            ; 主题专用图片保留扫码静区，并让二维码底板与窗口明暗一致。
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

    ResolveQrImagePath(assetStem) {
        preferredSuffix := UiThemeService.IsDark()
            ? "-界面.png" : "-浅色界面.png"
        fallbackSuffix := UiThemeService.IsDark()
            ? "-浅色界面.png" : "-界面.png"
        preferredPath := GetApplicationAssetPath(
            "donate\" assetStem preferredSuffix)
        if FileExist(preferredPath)
            return preferredPath
        fallbackPath := GetApplicationAssetPath(
            "donate\" assetStem fallbackSuffix)
        return FileExist(fallbackPath) ? fallbackPath : preferredPath
    }

    Close(*) {
        this.DestroyGui()
        this.messageText := ""
        this.qrLabels := []
        this.qrPictures := []
    }
}
