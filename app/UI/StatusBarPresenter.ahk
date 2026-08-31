; 行内 SVG 图标与文本的双缓冲自绘投影。
; 主窗口统计栏和普通说明标签仍保留原生 Text 控件作为布局与无障碍文本载体；
; 此处只接管像素绘制，让图标不依赖 Emoji 字体，并避免缩放或重绘时发生裁切。

class SvgStatusBarPresenter {
    static Presenters := Map()

    __New(ctrl, iconSizeDip := 15, iconGapDip := 5,
        groupGapDip := 13, textColorRole := "MutedText",
        backgroundColorRole := "Window") {
        this.ctrl := ctrl
        this.hwnd := ctrl.Hwnd
        this.iconSizeDip := iconSizeDip
        this.iconGapDip := iconGapDip
        this.groupGapDip := groupGapDip
        this.textColorRole := textColorRole
        this.backgroundColorRole := backgroundColorRole
        this.items := []
        this.svgSnapshots := Map()
        this.PruneInvalidPresenters()
        SvgStatusBarPresenter.Presenters[this.hwnd] := this
    }

    Dispose() {
        if this.hwnd && SvgStatusBarPresenter.Presenters.Has(this.hwnd)
            && SvgStatusBarPresenter.Presenters[this.hwnd] == this
            SvgStatusBarPresenter.Presenters.Delete(this.hwnd)
        this.items := []
        this.svgSnapshots.Clear()
        this.ctrl := ""
        this.hwnd := 0
    }

    PruneInvalidPresenters() {
        staleHandles := []
        for hwnd in SvgStatusBarPresenter.Presenters {
            if !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
                staleHandles.Push(hwnd)
        }
        for hwnd in staleHandles
            SvgStatusBarPresenter.Presenters.Delete(hwnd)
    }

    static Has(hwnd) {
        if !hwnd || !this.Presenters.Has(hwnd)
            return false
        if DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
            return true
        this.Presenters.Delete(hwnd)
        return false
    }

    static Get(hwnd) {
        return this.Has(hwnd) ? this.Presenters[hwnd] : ""
    }

    SetItems(items, accessibleText := "") {
        this.items := IsObject(items) ? items : []
        try this.ctrl.Text := accessibleText
        this.Redraw()
    }

    Redraw() {
        if this.hwnd && DllCall("user32\IsWindow", "Ptr", this.hwnd,
                "Int") {
            DllCall("user32\RedrawWindow", "Ptr", this.hwnd, "Ptr", 0,
                "Ptr", 0, "UInt", Win32.RDW_BUTTON_REFRESH, "Int")
        }
    }

    GetIcon(svgPath, dpi, tintColor := "") {
        try svgPath := String(svgPath)
        catch
            return false
        if svgPath == "" || !FileExist(svgPath) || DirExist(svgPath)
            return false
        tintColor := Trim(String(tintColor))
        cacheKey := svgPath Chr(31) dpi Chr(31) StrUpper(tintColor)
        if this.svgSnapshots.Has(cacheKey)
            return this.svgSnapshots[cacheKey]
        targetPixels := Max(1, Round(this.iconSizeDip * dpi / 96))
        renderSize := Max(64, Min(512, targetPixels * 4))
        snapshot := App.svgRenderer.RenderFile(svgPath, dpi, renderSize)
        if snapshot && tintColor != "" {
            tintedSnapshot := TintButtonIconSnapshot(snapshot, tintColor)
            if tintedSnapshot
                snapshot := tintedSnapshot
        }
        image := snapshot ? {
            Width: snapshot.Width,
            Height: snapshot.Height,
            Pixels: snapshot.Pixels
        } : false
        this.svgSnapshots[cacheKey] := image
        return image
    }

    MeasureItems(hdc, dpi, groupGap) {
        iconSize := Max(1, Round(this.iconSizeDip * dpi / 96))
        iconGap := Max(0, Round(this.iconGapDip * dpi / 96))
        widths := []
        totalWidth := 0
        for index, item in this.items {
            textExtent := RoundedButtonRenderer.MeasureText(hdc, item.Text)
            groupWidth := iconSize + iconGap + textExtent.Width
            if item.HasOwnProp("SeparatorBefore") && item.SeparatorBefore
                groupWidth += Max(1, Round(9 * dpi / 96))
            widths.Push(groupWidth)
            totalWidth += groupWidth
            if index < this.items.Length
                totalWidth += groupGap
        }
        return {Widths: widths, TotalWidth: totalWidth,
            IconSize: iconSize, IconGap: iconGap}
    }

    CalculateGapLayout(width, contentWidth, itemCount) {
        gapCount := Max(0, Integer(itemCount) - 1)
        if !gapCount
            return {BaseGap: 0, ExtraGaps: 0}
        available := Max(0, Integer(width) - Integer(contentWidth))
        return {BaseGap: available // gapCount,
            ExtraGaps: Mod(available, gapCount)}
    }

    MinimumGapPixels(dpi) {
        return Max(0, Round(this.groupGapDip * dpi / 96))
    }

    GetMinimumWidthDip() {
        if !this.hwnd || !DllCall("user32\IsWindow", "Ptr", this.hwnd,
                "Int") || !this.items.Length
            return 0
        dpi := DllCall("user32\GetDpiForWindow", "Ptr", this.hwnd, "UInt")
        if !dpi
            dpi := 96
        controlDc := DllCall("user32\GetDC", "Ptr", this.hwnd, "Ptr")
        if !controlDc
            return 0
        measureDc := DllCall("gdi32\CreateCompatibleDC", "Ptr", controlDc,
            "Ptr")
        if !measureDc {
            DllCall("user32\ReleaseDC", "Ptr", this.hwnd, "Ptr", controlDc)
            return 0
        }
        previousFont := 0
        try {
            fontHandle := SendMessage(Win32.WM_GETFONT, 0, 0, this.hwnd)
            if fontHandle
                previousFont := DllCall("gdi32\SelectObject", "Ptr",
                    measureDc, "Ptr", fontHandle, "Ptr")
            layout := this.MeasureItems(measureDc, dpi, 0)
            gapCount := Max(0, this.items.Length - 1)
            requiredPixels := layout.TotalWidth
                + this.MinimumGapPixels(dpi) * gapCount
            return Ceil(requiredPixels * 96 / dpi)
        } finally {
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", measureDc,
                    "Ptr", previousFont, "Ptr")
            DllCall("gdi32\DeleteDC", "Ptr", measureDc)
            DllCall("user32\ReleaseDC", "Ptr", this.hwnd, "Ptr", controlDc)
        }
    }

    DrawSeparator(hdc, x, height, dpi) {
        pen := DllCall("gdi32\CreatePen", "Int", 0,
            "Int", Max(1, Round(dpi / 96)), "UInt",
            RoundedButtonRenderer.ColorToBgr(UiThemeService.Color("Divider")),
            "Ptr")
        if !pen
            return
        oldPen := DllCall("gdi32\SelectObject", "Ptr", hdc,
            "Ptr", pen, "Ptr")
        try {
            top := Max(2, Round(3 * dpi / 96))
            DllCall("gdi32\MoveToEx", "Ptr", hdc, "Int", x,
                "Int", top, "Ptr", 0)
            DllCall("gdi32\LineTo", "Ptr", hdc, "Int", x,
                "Int", Max(top + 1, height - top))
        } finally {
            if oldPen
                DllCall("gdi32\SelectObject", "Ptr", hdc,
                    "Ptr", oldPen, "Ptr")
            DllCall("gdi32\DeleteObject", "Ptr", pen)
        }
    }

    Draw(hdc, width, height) {
        if width <= 0 || height <= 0
            return false
        memoryDc := DllCall("gdi32\CreateCompatibleDC", "Ptr", hdc, "Ptr")
        if !memoryDc
            return false
        bitmap := DllCall("gdi32\CreateCompatibleBitmap", "Ptr", hdc,
            "Int", width, "Int", height, "Ptr")
        if !bitmap {
            DllCall("gdi32\DeleteDC", "Ptr", memoryDc)
            return false
        }
        previousBitmap := DllCall("gdi32\SelectObject", "Ptr", memoryDc,
            "Ptr", bitmap, "Ptr")
        backgroundBrush := 0
        previousFont := 0
        try {
            backgroundBrush := DllCall("gdi32\CreateSolidBrush", "UInt",
                RoundedButtonRenderer.ColorToBgr(
                    UiThemeService.Color(this.backgroundColorRole)), "Ptr")
            fillRect := Buffer(16, 0)
            NumPut("Int", width, fillRect, 8)
            NumPut("Int", height, fillRect, 12)
            DllCall("user32\FillRect", "Ptr", memoryDc, "Ptr", fillRect,
                "Ptr", backgroundBrush)

            fontHandle := SendMessage(Win32.WM_GETFONT, 0, 0, this.hwnd)
            if fontHandle
                previousFont := DllCall("gdi32\SelectObject", "Ptr",
                    memoryDc, "Ptr", fontHandle, "Ptr")
            DllCall("gdi32\SetBkMode", "Ptr", memoryDc, "Int", 1)
            DllCall("gdi32\SetTextColor", "Ptr", memoryDc, "UInt",
                RoundedButtonRenderer.ColorToBgr(
                    UiThemeService.Color(this.textColorRole)))

            dpi := DllCall("user32\GetDpiForWindow", "Ptr", this.hwnd,
                "UInt")
            if !dpi
                dpi := 96
            layout := this.MeasureItems(memoryDc, dpi, 0)
            gapLayout := this.CalculateGapLayout(width, layout.TotalWidth,
                this.items.Length)

            x := 0
            for index, item in this.items {
                if x >= width
                    break
                if item.HasOwnProp("SeparatorBefore")
                    && item.SeparatorBefore {
                    separatorOffset := Max(2, Round(3 * dpi / 96))
                    this.DrawSeparator(memoryDc, x + separatorOffset,
                        height, dpi)
                    x += Max(1, Round(9 * dpi / 96))
                }
                ; 深色主题继续使用 SVG 自带颜色；语义色只修正浅色表面的对比度。
                iconColor := !UiThemeService.IsDark()
                    && item.HasOwnProp("IconColorRole")
                    && UiThemeService.HasColor(item.IconColorRole)
                    ? UiThemeService.Color(item.IconColorRole)
                    : (item.HasOwnProp("IconColor") ? item.IconColor : "")
                image := this.GetIcon(item.IconPath, dpi, iconColor)
                if image {
                    iconY := Floor((height - layout.IconSize) / 2)
                    RoundedButtonRenderer.DrawPixelImage(memoryDc, image,
                        x, iconY, layout.IconSize, layout.IconSize)
                }
                x += layout.IconSize + layout.IconGap
                textExtent := RoundedButtonRenderer.MeasureText(memoryDc,
                    item.Text)
                textRect := TextVisualAlignment.CreateCenteredTextRect(
                    memoryDc, item.Text, x, 0,
                    Min(width, x + textExtent.Width), height)
                DllCall("user32\DrawTextW", "Ptr", memoryDc, "Str",
                    item.Text, "Int", -1, "Ptr", textRect,
                    "UInt", 0x00008824, "Int")
                x += textExtent.Width
                if index < this.items.Length {
                    x += gapLayout.BaseGap
                    if index <= gapLayout.ExtraGaps
                        x++
                }
            }
            DllCall("gdi32\BitBlt", "Ptr", hdc, "Int", 0, "Int", 0,
                "Int", width, "Int", height, "Ptr", memoryDc,
                "Int", 0, "Int", 0, "UInt", 0x00CC0020)
            return true
        } finally {
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", memoryDc,
                    "Ptr", previousFont, "Ptr")
            if backgroundBrush
                DllCall("gdi32\DeleteObject", "Ptr", backgroundBrush)
            if previousBitmap
                DllCall("gdi32\SelectObject", "Ptr", memoryDc,
                    "Ptr", previousBitmap, "Ptr")
            DllCall("gdi32\DeleteObject", "Ptr", bitmap)
            DllCall("gdi32\DeleteDC", "Ptr", memoryDc)
        }
    }
}

OnDrawApplicationControl(wParam, lParam, msg, hwnd) {
    menuResult := ContextMenuPresenter.HandleDraw(lParam)
    if menuResult != ""
        return menuResult
    roundedResult := OnDrawRoundedButton(wParam, lParam, msg, hwnd)
    if roundedResult != ""
        return roundedResult
    if !lParam
        return
    itemHwndOffset := A_PtrSize == 8 ? 24 : 20
    itemHwnd := NumGet(lParam, itemHwndOffset, "Ptr")
    if !SvgStatusBarPresenter.Has(itemHwnd)
        return
    hdcOffset := itemHwndOffset + A_PtrSize
    rectOffset := hdcOffset + A_PtrSize
    itemHdc := NumGet(lParam, hdcOffset, "Ptr")
    left := NumGet(lParam, rectOffset, "Int")
    top := NumGet(lParam, rectOffset + 4, "Int")
    right := NumGet(lParam, rectOffset + 8, "Int")
    bottom := NumGet(lParam, rectOffset + 12, "Int")
    presenter := SvgStatusBarPresenter.Get(itemHwnd)
    if presenter && presenter.Draw(itemHdc, right - left, bottom - top)
        return 1
}
