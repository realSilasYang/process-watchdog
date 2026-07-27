; 应用专用的圆角按钮绘制与指针交互管线。
; 本模块统一处理悬浮、按下、抬起反馈、光标选择和输入框命中测试；原生子类回调
; 只记录短时交互状态，真正的功能回调在有效的鼠标抬起后分发，避免按下即误触。

class ButtonFeedbackMode {
    static Persistent := 0
    static Dismissive := 1
}

class ButtonFeedbackTiming {
    static ReleaseResetMs := 50
}

class RoundedButtonRenderer {
    static RadiusDip := 6
    static token := 0
    static moduleHandle := 0

    static EnsureStarted() {
        if this.token
            return true
        if !this.moduleHandle {
            this.moduleHandle := DllCall("kernel32\LoadLibraryW",
                "Str", "gdiplus.dll", "Ptr")
            if !this.moduleHandle
                return false
        }
        startupInput := Buffer(A_PtrSize == 8 ? 24 : 16, 0)
        NumPut("UInt", 1, startupInput, 0)
        token := 0
        status := DllCall("gdiplus\GdiplusStartup", "UPtr*", &token,
            "Ptr", startupInput, "Ptr", 0, "UInt")
        if status || !token {
            this.ReleaseModule()
            return false
        }
        this.token := token
        return true
    }

    static Shutdown(*) {
        token := this.token
        this.token := 0
        try {
            if token
                DllCall("gdiplus\GdiplusShutdown", "UPtr", token)
        } finally this.ReleaseModule()
    }

    static ReleaseModule() {
        if !this.moduleHandle
            return
        DllCall("kernel32\FreeLibrary", "Ptr", this.moduleHandle)
        this.moduleHandle := 0
    }

    static ColorToArgb(color, alpha := 255) {
        colorValue := ParseButtonColorValue(color)
        if (colorValue < 0)
            colorValue := ParseButtonColorValue(
                UiThemeService.Color("Window"))
        return ((alpha & 0xFF) << 24) | colorValue
    }

    static ColorToBgr(color) {
        colorValue := ParseButtonColorValue(color)
        if (colorValue < 0)
            colorValue := 0xFFFFFF
        return ((colorValue & 0xFF) << 16)
            | (colorValue & 0x00FF00)
            | ((colorValue >> 16) & 0xFF)
    }

    static MeasureText(hdc, text) {
        if (text == "")
            return {Width: 0, Height: 0}
        extent := Buffer(8, 0)
        if !DllCall("gdi32\GetTextExtentPoint32W", "Ptr", hdc, "Str", text,
                "Int", StrLen(text), "Ptr", extent, "Int")
            return {Width: 0, Height: 0}
        return {
            Width: NumGet(extent, 0, "Int"),
            Height: NumGet(extent, 4, "Int")
        }
    }

    static CreateIconFont(icon, dpi) {
        pixelHeight := Max(1, Round(icon.sizeDip * dpi / 96))
        return DllCall("gdi32\CreateFontW",
            "Int", -pixelHeight, "Int", 0, "Int", 0, "Int", 0,
            "Int", 400, "UInt", 0, "UInt", 0, "UInt", 0,
            "UInt", 1, "UInt", 0, "UInt", 0, "UInt", 5,
            "UInt", 0, "Str", icon.fontName, "Ptr")
    }

    static DrawPixelImage(hdc, image, x, y, width, height) {
        if !IsObject(image) || !image.HasOwnProp("Pixels")
            || !image.HasOwnProp("Width") || !image.HasOwnProp("Height")
            || image.Width <= 0 || image.Height <= 0
            || width <= 0 || height <= 0
            return false
        graphics := 0
        bitmap := 0
        try {
            ; SvgRenderLibrary 返回预乘 BGRA；PixelFormat32bppPARGB 可让 GDI+
            ; 直接在已绘制的按钮表面执行 SourceOver 合成，不产生黑色底板。
            if DllCall("gdiplus\GdipCreateBitmapFromScan0",
                "Int", image.Width, "Int", image.Height,
                "Int", image.Width * 4, "Int", 0x000E200B,
                "Ptr", image.Pixels.Ptr, "Ptr*", &bitmap, "UInt") || !bitmap
                return false
            if DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdc,
                "Ptr*", &graphics, "UInt") || !graphics
                return false
            DllCall("gdiplus\GdipSetCompositingMode", "Ptr", graphics,
                "Int", 0) ; SourceOver：透明像素保留按钮原有背景。
            DllCall("gdiplus\GdipSetCompositingQuality", "Ptr", graphics,
                "Int", 2)
            DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", graphics,
                "Int", 7) ; HighQualityBicubic：高 DPI 缩放时保持边缘平滑。
            DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", graphics,
                "Int", 4)
            return DllCall("gdiplus\GdipDrawImageRectI", "Ptr", graphics,
                "Ptr", bitmap, "Int", x, "Int", y,
                "Int", width, "Int", height, "UInt") == 0
        } catch {
            return false
        } finally {
            if graphics
                DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
            if bitmap
                DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)
        }
    }

    static MixColor(foreground, background, foregroundWeight) {
        foregroundValue := ParseButtonColorValue(foreground)
        backgroundValue := ParseButtonColorValue(background)
        if (foregroundValue < 0 || backgroundValue < 0)
            return foreground
        foregroundWeight := Max(0, Min(1, foregroundWeight))
        backgroundWeight := 1 - foregroundWeight
        red := Round(((foregroundValue >> 16) & 0xFF) * foregroundWeight
            + ((backgroundValue >> 16) & 0xFF) * backgroundWeight)
        green := Round(((foregroundValue >> 8) & 0xFF) * foregroundWeight
            + ((backgroundValue >> 8) & 0xFF) * backgroundWeight)
        blue := Round((foregroundValue & 0xFF) * foregroundWeight
            + (backgroundValue & 0xFF) * backgroundWeight)
        return Format("{:02X}{:02X}{:02X}", red, green, blue)
    }

    static CreateRoundedPath(width, height, radius, inset := 0.5,
        offsetX := 0, offsetY := 0) {
        path := 0
        if DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &path, "UInt") || !path
            return 0
        pathWidth := Max(1.0, width - inset * 2)
        pathHeight := Max(1.0, height - inset * 2)
        diameter := Max(2.0, Min(radius * 2.0, pathWidth, pathHeight))
        pathLeft := offsetX + inset
        pathTop := offsetY + inset
        try {
            DllCall("gdiplus\GdipAddPathArc", "Ptr", path,
                "Float", pathLeft, "Float", pathTop,
                "Float", diameter, "Float", diameter,
                "Float", 180.0, "Float", 90.0)
            DllCall("gdiplus\GdipAddPathArc", "Ptr", path,
                "Float", pathLeft + pathWidth - diameter, "Float", pathTop,
                "Float", diameter, "Float", diameter, "Float", 270.0, "Float", 90.0)
            DllCall("gdiplus\GdipAddPathArc", "Ptr", path,
                "Float", pathLeft + pathWidth - diameter,
                "Float", pathTop + pathHeight - diameter,
                "Float", diameter, "Float", diameter, "Float", 0.0, "Float", 90.0)
            DllCall("gdiplus\GdipAddPathArc", "Ptr", path,
                "Float", pathLeft, "Float", pathTop + pathHeight - diameter,
                "Float", diameter, "Float", diameter, "Float", 90.0, "Float", 90.0)
            DllCall("gdiplus\GdipClosePathFigure", "Ptr", path)
            return path
        } catch {
            DllCall("gdiplus\GdipDeletePath", "Ptr", path)
            return 0
        }
    }

    static IsDisabled(state) {
        ; 下级窗口打开时，上级 GUI 会被临时禁用，但可见按钮不应因此改变配色。
        ; 这里只读取控件自身的 WS_DISABLED；交互可用性仍由 IsControlEffectivelyEnabled 判断。
        try return !DllCall("user32\IsWindowEnabled", "Ptr", state.ctrl.Hwnd, "Int")
        catch
            return true
    }

    static DrawSurface(hdc, width, height, state) {
        graphics := 0
        path := 0
        brush := 0
        if DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdc, "Ptr*", &graphics, "UInt") || !graphics
            return false
        try {
            DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics, "Int", 4)
            DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", graphics, "Int", 4)
            DllCall("gdiplus\GdipSetCompositingQuality", "Ptr", graphics, "Int", 2)
            parentColor := UiThemeService.Color("Window")
            DllCall("gdiplus\GdipGraphicsClear", "Ptr", graphics,
                "UInt", this.ColorToArgb(parentColor))

            dpi := DllCall("user32\GetDpiForWindow", "Ptr", state.ctrl.Hwnd, "UInt")
            if !dpi
                dpi := 96
            radius := Max(3, Round(this.RadiusDip * dpi / 96))
            path := this.CreateRoundedPath(width, height, radius)
            if !path
                return false

            backgroundColor := state.HasOwnProp("current") ? state.current : state.normal
            if this.IsDisabled(state)
                backgroundColor := this.MixColor(state.normal,
                    parentColor, 0.58)
            if DllCall("gdiplus\GdipCreateSolidFill", "UInt", this.ColorToArgb(backgroundColor),
                "Ptr*", &brush, "UInt") || !brush
                return false
            if DllCall("gdiplus\GdipFillPath", "Ptr", graphics, "Ptr", brush,
                "Ptr", path, "UInt")
                return false
            return true
        } finally {
            if brush
                DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
            if path
                DllCall("gdiplus\GdipDeletePath", "Ptr", path)
            if graphics
                DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
        }
    }

    static DrawText(hdc, width, height, state) {
        hFont := DllCall("user32\SendMessageW", "Ptr", state.ctrl.Hwnd,
            "UInt", Win32.WM_GETFONT, "Ptr", 0, "Ptr", 0, "Ptr")
        if !hFont
            hFont := DllCall("gdi32\GetStockObject", "Int", 17, "Ptr") ; DEFAULT_GUI_FONT：控件未指定字体时使用系统界面字体。
        previousFont := hFont ? DllCall("gdi32\SelectObject", "Ptr", hdc,
            "Ptr", hFont, "Ptr") : 0
        iconFont := 0
        try {
            DllCall("gdi32\SetBkMode", "Ptr", hdc, "Int", 1) ; TRANSPARENT：绘制文字时不填充字符背景。
            textColor := state.HasOwnProp("textColor") ? state.textColor : "FFFFFF"
            if this.IsDisabled(state)
                textColor := this.MixColor(textColor,
                    UiThemeService.Color("Window"), 0.58)
            DllCall("gdi32\SetTextColor", "Ptr", hdc, "UInt", this.ColorToBgr(textColor))
            dpi := DllCall("user32\GetDpiForWindow", "Ptr", state.ctrl.Hwnd, "UInt")
            if !dpi
                dpi := 96
            horizontalInsetDip := state.HasOwnProp("textInsetDip")
                ? state.textInsetDip : 4
            horizontalInset := Max(3, Round(horizontalInsetDip * dpi / 96))
            textRect := Buffer(16, 0)
            NumPut("Int", horizontalInset, "Int", 0, "Int", width - horizontalInset,
                "Int", height, textRect)
            text := ""
            try text := state.ctrl.Text
            textAlign := state.HasOwnProp("textAlign")
                ? StrLower(String(state.textAlign)) : "center"
            textFlags := 0x00008824 ; 单行、垂直居中、隐藏前缀并在不足时显示省略号。
            if textAlign == "right"
                textFlags |= 0x00000002
            else if textAlign != "left"
                textFlags |= 0x00000001
            if state.HasOwnProp("buttonImage") {
                image := state.buttonImage
                if !IsObject(image) || !image.HasOwnProp("Width")
                    || !image.HasOwnProp("Height") || image.Width <= 0
                    || image.Height <= 0 {
                    DllCall("user32\DrawTextW", "Ptr", hdc, "Str", text,
                        "Int", -1, "Ptr", textRect, "UInt", textFlags, "Int")
                    return
                }
                textExtent := this.MeasureText(hdc, text)
                imageBoxSize := Max(1, Round(image.sizeDip * dpi / 96))
                imageAspectRatio := image.Width / image.Height
                if imageAspectRatio >= 1 {
                    imageWidth := imageBoxSize
                    imageHeight := Max(1, Round(imageBoxSize / imageAspectRatio))
                } else {
                    imageHeight := imageBoxSize
                    imageWidth := Max(1, Round(imageBoxSize * imageAspectRatio))
                }
                availableWidth := Max(1, width - horizontalInset * 2)
                if imageWidth > availableWidth {
                    imageHeight := Max(1, Round(imageHeight
                        * availableWidth / imageWidth))
                    imageWidth := availableWidth
                }
                gap := text == "" ? 0 : Min(
                    Max(0, Round(image.gapDip * dpi / 96)),
                    Max(0, availableWidth - imageWidth))
                contentWidth := Min(availableWidth,
                    imageWidth + gap + textExtent.Width)
                if textAlign == "left"
                    contentX := horizontalInset
                else if textAlign == "right"
                    contentX := width - horizontalInset - contentWidth
                else
                    contentX := Floor((width - contentWidth) / 2)
                imageY := Floor((height - imageHeight) / 2)
                if !this.DrawPixelImage(hdc, image, contentX, imageY,
                        imageWidth, imageHeight) {
                    DllCall("user32\DrawTextW", "Ptr", hdc, "Str", text,
                        "Int", -1, "Ptr", textRect, "UInt", textFlags, "Int")
                    return
                }
                textLeft := contentX + imageWidth + gap
                textRect := Buffer(16, 0)
                NumPut("Int", textLeft, "Int", 0,
                    "Int", contentX + contentWidth, "Int", height, textRect)
                DllCall("user32\DrawTextW", "Ptr", hdc, "Str", text,
                    "Int", -1, "Ptr", textRect, "UInt", 0x00008824, "Int")
                return
            }
            if !state.HasOwnProp("buttonIcon") {
                DllCall("user32\DrawTextW", "Ptr", hdc, "Str", text,
                    "Int", -1, "Ptr", textRect, "UInt", textFlags, "Int")
                return
            }

            icon := state.buttonIcon
            iconFont := this.CreateIconFont(icon, dpi)
            if !iconFont {
                DllCall("user32\DrawTextW", "Ptr", hdc, "Str", text,
                    "Int", -1, "Ptr", textRect, "UInt", textFlags, "Int")
                return
            }

            textExtent := this.MeasureText(hdc, text)
            DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", iconFont, "Ptr")
            iconExtent := this.MeasureText(hdc, icon.glyph)
            DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr")
            if (iconExtent.Width <= 0) {
                DllCall("user32\DrawTextW", "Ptr", hdc, "Str", text,
                    "Int", -1, "Ptr", textRect, "UInt", textFlags, "Int")
                return
            }

            availableWidth := Max(1, width - horizontalInset * 2)
            iconWidth := Min(iconExtent.Width, availableWidth)
            gap := text == "" ? 0 : Min(
                Max(0, Round(icon.gapDip * dpi / 96)),
                Max(0, availableWidth - iconWidth))
            contentWidth := Min(availableWidth,
                iconWidth + gap + textExtent.Width)
            if textAlign == "left"
                contentX := horizontalInset
            else if textAlign == "right"
                contentX := width - horizontalInset - contentWidth
            else
                contentX := Floor((width - contentWidth) / 2)

            iconRect := Buffer(16, 0)
            NumPut("Int", contentX, "Int", 0,
                "Int", contentX + iconWidth, "Int", height, iconRect)
            DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", iconFont, "Ptr")
            DllCall("user32\DrawTextW", "Ptr", hdc, "Str", icon.glyph,
                "Int", -1, "Ptr", iconRect, "UInt", 0x00008825, "Int")

            DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr")
            textLeft := contentX + iconWidth + gap
            textRect := Buffer(16, 0)
            NumPut("Int", textLeft, "Int", 0,
                "Int", contentX + contentWidth, "Int", height, textRect)
            DllCall("user32\DrawTextW", "Ptr", hdc, "Str", text,
                "Int", -1, "Ptr", textRect, "UInt", 0x00008824, "Int")
        } finally {
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", previousFont, "Ptr")
            if iconFont
                DllCall("gdi32\DeleteObject", "Ptr", iconFont)
        }
    }

    static FillRoundedRectangle(hdc, left, top, right, bottom, color,
        radius) {
        width := right - left
        height := bottom - top
        if !hdc || width <= 0 || height <= 0 || !this.EnsureStarted()
            return false
        graphics := 0
        path := 0
        brush := 0
        if DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdc,
                "Ptr*", &graphics, "UInt") || !graphics
            return false
        try {
            DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics,
                "Int", 4)
            DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", graphics,
                "Int", 4)
            DllCall("gdiplus\GdipSetCompositingQuality", "Ptr", graphics,
                "Int", 2)
            path := this.CreateRoundedPath(width, height, radius, 0.5,
                left, top)
            if !path
                return false
            if DllCall("gdiplus\GdipCreateSolidFill", "UInt",
                    this.ColorToArgb(color), "Ptr*", &brush, "UInt") || !brush
                return false
            return DllCall("gdiplus\GdipFillPath", "Ptr", graphics,
                "Ptr", brush, "Ptr", path, "UInt") == 0
        } finally {
            if brush
                DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
            if path
                DllCall("gdiplus\GdipDeletePath", "Ptr", path)
            if graphics
                DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
        }
    }

    static MaskOutsideRoundedRectangle(hdc, outerLeft, outerTop,
        outerRight, outerBottom, innerLeft, innerTop, innerRight,
        innerBottom, color, radius) {
        if !hdc || outerRight <= outerLeft || outerBottom <= outerTop
            || innerRight <= innerLeft || innerBottom <= innerTop
            || !this.EnsureStarted()
            return false
        graphics := 0
        path := 0
        brush := 0
        if DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdc,
                "Ptr*", &graphics, "UInt") || !graphics
            return false
        if DllCall("gdiplus\GdipCreatePath", "Int", 0,
                "Ptr*", &path, "UInt") || !path {
            DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
            return false
        }
        try {
            DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics,
                "Int", 4)
            DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", graphics,
                "Int", 4)
            DllCall("gdiplus\GdipAddPathRectangle", "Ptr", path,
                "Float", outerLeft, "Float", outerTop,
                "Float", outerRight - outerLeft,
                "Float", outerBottom - outerTop)
            DllCall("gdiplus\GdipStartPathFigure", "Ptr", path)
            inset := 0.5
            innerWidth := innerRight - innerLeft
            innerHeight := innerBottom - innerTop
            diameter := Max(2.0, Min(radius * 2.0,
                innerWidth - inset * 2, innerHeight - inset * 2))
            pathLeft := innerLeft + inset
            pathTop := innerTop + inset
            pathWidth := innerWidth - inset * 2
            pathHeight := innerHeight - inset * 2
            DllCall("gdiplus\GdipAddPathArc", "Ptr", path,
                "Float", pathLeft, "Float", pathTop,
                "Float", diameter, "Float", diameter,
                "Float", 180.0, "Float", 90.0)
            DllCall("gdiplus\GdipAddPathArc", "Ptr", path,
                "Float", pathLeft + pathWidth - diameter,
                "Float", pathTop, "Float", diameter, "Float", diameter,
                "Float", 270.0, "Float", 90.0)
            DllCall("gdiplus\GdipAddPathArc", "Ptr", path,
                "Float", pathLeft + pathWidth - diameter,
                "Float", pathTop + pathHeight - diameter,
                "Float", diameter, "Float", diameter,
                "Float", 0.0, "Float", 90.0)
            DllCall("gdiplus\GdipAddPathArc", "Ptr", path,
                "Float", pathLeft,
                "Float", pathTop + pathHeight - diameter,
                "Float", diameter, "Float", diameter,
                "Float", 90.0, "Float", 90.0)
            DllCall("gdiplus\GdipClosePathFigure", "Ptr", path)
            if DllCall("gdiplus\GdipCreateSolidFill", "UInt",
                    this.ColorToArgb(color), "Ptr*", &brush, "UInt") || !brush
                return false
            ; FillModeAlternate 使同一路径内的外矩形减去内圆角矩形。
            return DllCall("gdiplus\GdipFillPath", "Ptr", graphics,
                "Ptr", brush, "Ptr", path, "UInt") == 0
        } finally {
            if brush
                DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
            if path
                DllCall("gdiplus\GdipDeletePath", "Ptr", path)
            if graphics
                DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
        }
    }

    static Draw(hdc, width, height, state) {
        if !this.EnsureStarted() || width <= 0 || height <= 0
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
        drawn := false
        try {
            if !this.DrawSurface(memoryDc, width, height, state)
                return false
            this.DrawText(memoryDc, width, height, state)
            drawn := !!DllCall("gdi32\BitBlt", "Ptr", hdc, "Int", 0, "Int", 0,
                "Int", width, "Int", height, "Ptr", memoryDc, "Int", 0, "Int", 0,
                "UInt", 0x00CC0020, "Int") ; SRCCOPY：把离屏按钮像素原样复制到目标设备上下文。
            return drawn
        } finally {
            if previousBitmap
                DllCall("gdi32\SelectObject", "Ptr", memoryDc, "Ptr", previousBitmap, "Ptr")
            DllCall("gdi32\DeleteObject", "Ptr", bitmap)
            DllCall("gdi32\DeleteDC", "Ptr", memoryDc)
        }
    }
}

class RoundedButtonInputRouter {
    static SubclassId := 0x52424E ; "RBN"
    static callbackPtr := 0

    static EnsureCallback() {
        if this.callbackPtr
            return true
        try this.callbackPtr := CallbackCreate(ButtonControlSubclassProc, "", 6)
        catch
            this.callbackPtr := 0
        return this.callbackPtr != 0
    }

    static Attach(hWnd) {
        if !hWnd || !this.EnsureCallback()
            return false
        return !!DllCall("comctl32\SetWindowSubclass", "Ptr", hWnd,
            "Ptr", this.callbackPtr, "UPtr", this.SubclassId, "UPtr", 0, "Int")
    }

    static Detach(hWnd) {
        if hWnd && this.callbackPtr && DllCall("user32\IsWindow", "Ptr", hWnd, "Int")
            DllCall("comctl32\RemoveWindowSubclass", "Ptr", hWnd,
                "Ptr", this.callbackPtr, "UPtr", this.SubclassId, "Int")
    }

    static Shutdown() {
        if !this.callbackPtr
            return
        if IsSet(App) {
            for hWnd, state in App.uiInteractions.Buttons {
                if state.HasOwnProp("roundedOwnerDraw") && state.roundedOwnerDraw
                    this.Detach(hWnd)
            }
        }
        CallbackFree(this.callbackPtr)
        this.callbackPtr := 0
    }
}

; 指针命中、悬浮提示和输入光标根据原生子控件句柄统一分发。
IsRoundedButtonInputRouted(hwnd) {
    if !App.uiInteractions.HasButton(hwnd)
        return false
    state := App.uiInteractions.GetButton(hwnd)
    return state.HasOwnProp("roundedOwnerDraw") && state.roundedOwnerDraw
}

OnMouseMove_Tooltip(wParam, lParam, msg, hwnd) {
    if !IsRoundedButtonInputRouted(hwnd)
        UpdateButtonHover(hwnd)
    if IsSet(GuiModules)
        GuiModules.tooltip.HandleMouseMove(wParam, lParam, msg, hwnd)
}

OnMouseLeave_Hover(wParam, lParam, msg, hwnd) {
    if IsRoundedButtonInputRouted(hwnd)
        return
    HandleButtonMouseLeave(hwnd)
}

HandleButtonMouseLeave(hwnd) {
    if (App.uiInteractions.PressedButton == hwnd) {
        if App.uiInteractions.HasButton(hwnd) {
            pressedState := App.uiInteractions.GetButton(hwnd)
            if !(pressedState.HasOwnProp("cursorOnly") && pressedState.cursorOnly)
                SetButtonBackground(pressedState.ctrl, pressedState.normal)
        }
        App.uiInteractions.ClearHoveredButton(hwnd)
        return
    }
    if (App.uiInteractions.HoveredButton == hwnd)
        RestoreHoveredButton()
}

OnGlobalPointerDown(wParam, lParam, msg, hwnd) {
    if App.uiInteractions.HasButton(hwnd) && !IsRoundedButtonInputRouted(hwnd)
        BeginButtonPress(hwnd)

    PruneTextInputCursorStates()
    if App.uiInteractions.HasTextInput(hwnd) {
        clickedTextState := App.uiInteractions.GetTextInput(hwnd)
        if (clickedTextState.HasOwnProp("hideCaret") && clickedTextState.hideCaret)
            ScheduleHideTextCaret(clickedTextState.editHwnd)
        return
    }

    focusedHwnd := DllCall("user32\GetFocus", "Ptr")
    if !App.uiInteractions.HasTextInput(focusedHwnd)
        return
    rootHwnd := DllCall("user32\GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr") ; GA_ROOT：取得控件所属的最上层窗口。
    if rootHwnd && DllCall("user32\IsWindowEnabled", "Ptr", rootHwnd, "Int")
        DllCall("user32\SetFocus", "Ptr", rootHwnd, "Ptr")
}

OnGlobalPointerUp(wParam, lParam, msg, hwnd) {
    if !IsRoundedButtonInputRouted(hwnd)
        EndButtonPress()

    if !App.uiInteractions.HasTextInput(hwnd)
        return
    releasedTextState := App.uiInteractions.GetTextInput(hwnd)
    if (releasedTextState.HasOwnProp("hideCaret") && releasedTextState.hideCaret)
        ScheduleHideTextCaret(releasedTextState.editHwnd)
}

OnButtonPressCancelled(wParam, lParam, msg, hwnd) {
    if IsRoundedButtonInputRouted(hwnd)
        return
    CancelButtonPress()
}

OnButtonCaptureChanged(wParam, lParam, msg, hwnd) {
    if IsRoundedButtonInputRouted(hwnd)
        return
    HandleButtonCaptureChanged(hwnd)
}

HandleButtonCaptureChanged(hwnd) {
    if (App.uiInteractions.PressedButton == hwnd)
        SetTimer(CancelButtonPressAfterCaptureLoss.Bind(hwnd), -50)
}

CancelButtonPressAfterCaptureLoss(expectedHwnd, *) {
    if (App.uiInteractions.PressedButton == expectedHwnd
        && DllCall("user32\GetCapture", "Ptr") != expectedHwnd)
        CancelButtonPress()
}

IsScrollBarHitTestCode(lParam) {
    hitTestCode := lParam & 0xFFFF
    return hitTestCode == Win32.HTHSCROLL
        || hitTestCode == Win32.HTVSCROLL
}

IsNativeScrollBarControl(hwnd) {
    if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
        return false
    classNameBuffer := Buffer(64 * 2, 0)
    classNameLength := DllCall("user32\GetClassNameW", "Ptr", hwnd,
        "Ptr", classNameBuffer, "Int", 64, "Int")
    return classNameLength > 0
        && StrLower(StrGet(classNameBuffer, classNameLength, "UTF-16"))
            == "scrollbar"
}

GetVisibleScrollBarRectangle(hwnd, objectId) {
    scrollBarInfo := Buffer(60, 0)
    NumPut("UInt", scrollBarInfo.Size, scrollBarInfo, 0)
    if !DllCall("user32\GetScrollBarInfo", "Ptr", hwnd, "Int", objectId,
        "Ptr", scrollBarInfo, "Int")
        return ""
    state := NumGet(scrollBarInfo, 36, "UInt")
    if state & (Win32.STATE_SYSTEM_INVISIBLE
        | Win32.STATE_SYSTEM_OFFSCREEN)
        return ""
    left := NumGet(scrollBarInfo, 4, "Int")
    top := NumGet(scrollBarInfo, 8, "Int")
    right := NumGet(scrollBarInfo, 12, "Int")
    bottom := NumGet(scrollBarInfo, 16, "Int")
    if right <= left || bottom <= top
        return ""
    return {Left: left, Top: top, Right: right, Bottom: bottom}
}

PointInsideScreenRectangle(x, y, rectangle) {
    return IsObject(rectangle)
        && x >= rectangle.Left && x < rectangle.Right
        && y >= rectangle.Top && y < rectangle.Bottom
}

IsPointerOverTextInputScrollBar(editHwnd) {
    if !editHwnd || !DllCall("user32\IsWindow", "Ptr", editHwnd, "Int")
        return false
    cursorPoint := Buffer(8, 0)
    if !DllCall("user32\GetCursorPos", "Ptr", cursorPoint, "Int")
        return false
    cursorX := NumGet(cursorPoint, 0, "Int")
    cursorY := NumGet(cursorPoint, 4, "Int")
    horizontalBar := GetVisibleScrollBarRectangle(editHwnd,
        Win32.OBJID_HSCROLL)
    if PointInsideScreenRectangle(cursorX, cursorY, horizontalBar)
        return true
    verticalBar := GetVisibleScrollBarRectangle(editHwnd,
        Win32.OBJID_VSCROLL)
    if PointInsideScreenRectangle(cursorX, cursorY, verticalBar)
        return true
    ; 两条滚动条同时可见时，右下角交汇区也属于滚动区域。
    if IsObject(horizontalBar) && IsObject(verticalBar) {
        cornerRectangle := {
            Left: verticalBar.Left,
            Top: horizontalBar.Top,
            Right: verticalBar.Right,
            Bottom: horizontalBar.Bottom
        }
        return PointInsideScreenRectangle(cursorX, cursorY,
            cornerRectangle)
    }
    return false
}

OnSetCursor(wParam, lParam, msg, hwnd) {
    cursorTargetHwnd := wParam
        && DllCall("user32\IsWindow", "Ptr", wParam, "Int") ? wParam : hwnd
    if IsScrollBarHitTestCode(lParam)
        || IsNativeScrollBarControl(cursorTargetHwnd) {
        SetArrowCursor()
        return 1
    }
    textTargetHwnd := App.uiInteractions.HasTextInput(wParam) ? wParam
        : (App.uiInteractions.HasTextInput(hwnd) ? hwnd : 0)
    if textTargetHwnd {
        textInputState := App.uiInteractions.GetTextInput(textTargetHwnd)
        if DllCall("user32\IsWindow", "Ptr", textTargetHwnd, "Int")
            && DllCall("user32\IsWindow", "Ptr", textInputState.editHwnd, "Int")
            && IsControlEffectivelyEnabled(textInputState.editHwnd) {
            if IsPointerOverTextInputScrollBar(textInputState.editHwnd)
                || (textInputState.HasOwnProp("useArrowCursor")
                    && textInputState.useArrowCursor)
                SetArrowCursor()
            else
                SetTextCursor()
            return 1
        }
        App.uiInteractions.RemoveTextInput(textTargetHwnd)
    }

    ; WM_SETCURSOR 的 wParam 是鼠标所在子窗口句柄；部分系统版本回调 hwnd 会是父窗口，需同时检查两者。
    buttonHwnd := App.uiInteractions.HasButton(wParam) ? wParam : hwnd
    if App.uiInteractions.HasButton(buttonHwnd)
        && !IsRoundedButtonInputRouted(buttonHwnd)
        && IsHoverButtonAvailable(App.uiInteractions.GetButton(buttonHwnd)) {
        SetHandCursor()
        return 1
    }
}

SetHandCursor() {
    cursorHandle := App.uiInteractions.GetCursor(UiCursorKind.Hand, 32649) ; IDC_HAND：系统标准手型光标。
    if cursorHandle
        DllCall("user32\SetCursor", "Ptr", cursorHandle)
}

SetArrowCursor() {
    cursorHandle := App.uiInteractions.GetCursor(UiCursorKind.Arrow,
        Win32.IDC_ARROW)
    if cursorHandle
        DllCall("user32\SetCursor", "Ptr", cursorHandle)
}

SetTextCursor() {
    cursorHandle := App.uiInteractions.GetCursor(UiCursorKind.Text,
        Win32.IDC_IBEAM)
    if cursorHandle
        DllCall("user32\SetCursor", "Ptr", cursorHandle)
}

RegisterTextInputControl(inputControl, hideCaret := false, useArrowCursor := false) {
    try textEditHwnd := inputControl.Hwnd
    catch
        return
    RegisterTextInputHwnd(textEditHwnd, hideCaret, useArrowCursor)
}

RegisterTextInputHwnd(textEditHwnd, hideCaret := false, useArrowCursor := false) {
    if !textEditHwnd || !DllCall("user32\IsWindow", "Ptr", textEditHwnd, "Int")
        return
    PruneTextInputCursorStates()
    App.uiInteractions.RegisterTextInput(textEditHwnd, {
        editHwnd: textEditHwnd,
        hideCaret: hideCaret,
        useArrowCursor: useArrowCursor
    })
}

RegisterTextInputHitTarget(backgroundControl, inputControl) {
    try backgroundHwnd := backgroundControl.Hwnd
    catch
        return
    try textEditHwnd := inputControl.Hwnd
    catch
        return
    if !backgroundHwnd || !textEditHwnd
        return
    PruneTextInputCursorStates()
    App.uiInteractions.RegisterTextInput(backgroundHwnd,
        {editHwnd: textEditHwnd})
    backgroundControl.OnEvent("Click", PlaceTextCaretAtPointer.Bind(inputControl))
}

UnregisterGuiControls(guiHwnd) {
    if !guiHwnd
        return
    hoverHandles := []
    for controlHwnd, _ in App.uiInteractions.Buttons {
        if (!DllCall("user32\IsWindow", "Ptr", controlHwnd, "Int")
            || controlHwnd == guiHwnd
            || DllCall("user32\GetAncestor", "Ptr", controlHwnd, "UInt", 2, "Ptr") == guiHwnd)
            hoverHandles.Push(controlHwnd)
    }
    for controlHwnd in hoverHandles {
        RoundedButtonInputRouter.Detach(controlHwnd)
        CancelButtonReleaseReset(controlHwnd)
        if (App.uiInteractions.PressedButton == controlHwnd)
            CancelButtonPress()
        App.uiInteractions.RemoveButton(controlHwnd)
    }
    inputHandles := []
    for controlHwnd, textInputState in App.uiInteractions.TextInputs {
        if (!DllCall("user32\IsWindow", "Ptr", controlHwnd, "Int")
            || !DllCall("user32\IsWindow", "Ptr", textInputState.editHwnd, "Int")
            || controlHwnd == guiHwnd
            || DllCall("user32\GetAncestor", "Ptr", controlHwnd, "UInt", 2, "Ptr") == guiHwnd)
            inputHandles.Push(controlHwnd)
    }
    for controlHwnd in inputHandles
        App.uiInteractions.RemoveTextInput(controlHwnd)
}

PruneTextInputCursorStates() {
    staleTextTargets := []
    for targetHwnd, textInputState in App.uiInteractions.TextInputs {
        if !DllCall("user32\IsWindow", "Ptr", targetHwnd, "Int")
            || !DllCall("user32\IsWindow", "Ptr", textInputState.editHwnd, "Int")
            staleTextTargets.Push(targetHwnd)
    }
    for targetHwnd in staleTextTargets
        App.uiInteractions.RemoveTextInput(targetHwnd)
}

PlaceTextCaretAtPointer(inputControl, *) {
    try textEditHwnd := inputControl.Hwnd
    catch
        return
    if !IsControlEffectivelyEnabled(textEditHwnd)
        return

    cursorPoint := Buffer(8, 0)
    editRect := Buffer(16, 0)
    if !DllCall("user32\GetCursorPos", "Ptr", cursorPoint, "Int")
        return
    if !DllCall("user32\ScreenToClient", "Ptr", textEditHwnd, "Ptr", cursorPoint, "Int")
        return
    if !DllCall("user32\GetClientRect", "Ptr", textEditHwnd, "Ptr", editRect, "Int")
        return

    clientWidth := NumGet(editRect, 8, "Int")
    clientHeight := NumGet(editRect, 12, "Int")
    if (clientWidth <= 0 || clientHeight <= 0)
        return
    pointerX := Max(0, Min(NumGet(cursorPoint, 0, "Int"), clientWidth - 1))
    pointerY := Floor(clientHeight / 2)
    packedPoint := (pointerX & 0xFFFF) | ((pointerY & 0xFFFF) << 16)

    ControlFocus(inputControl)
    characterIndex := SendMessage(Win32.EM_CHARFROMPOS, 0, packedPoint, textEditHwnd) & 0xFFFF
    SendMessage(Win32.EM_SETSEL, characterIndex, characterIndex, textEditHwnd)
}

ScheduleHideTextCaret(textEditHwnd) {
    if textEditHwnd
        SetTimer(HideTextCaret.Bind(textEditHwnd), -10)
}

HideTextCaret(textEditHwnd, *) {
    if DllCall("user32\IsWindow", "Ptr", textEditHwnd, "Int")
        && DllCall("user32\GetFocus", "Ptr") == textEditHwnd
        DllCall("user32\HideCaret", "Ptr", textEditHwnd)
}

ParseButtonColorValue(color) {
    normalizedColor := Trim(String(color))
    if (SubStr(normalizedColor, 1, 1) == "#")
        normalizedColor := SubStr(normalizedColor, 2)
    if (StrLower(SubStr(normalizedColor, 1, 2)) == "0x")
        normalizedColor := SubStr(normalizedColor, 3)
    if !RegExMatch(normalizedColor, "i)^[0-9a-f]{6}$")
        return -1
    return Integer("0x" normalizedColor)
}

GetButtonColorLuma(color) {
    colorValue := ParseButtonColorValue(color)
    if (colorValue < 0)
        return -1
    red := (colorValue >> 16) & 0xFF
    green := (colorValue >> 8) & 0xFF
    blue := colorValue & 0xFF
    return red * 299 + green * 587 + blue * 114
}

DarkenButtonColor(color, factor := 0.86) {
    colorValue := ParseButtonColorValue(color)
    if (colorValue < 0)
        return color
    red := Round(((colorValue >> 16) & 0xFF) * factor)
    green := Round(((colorValue >> 8) & 0xFF) * factor)
    blue := Round((colorValue & 0xFF) * factor)
    return Format("{:02X}{:02X}{:02X}", red, green, blue)
}

LightenButtonColor(color, ratio := 0.12) {
    colorValue := ParseButtonColorValue(color)
    if (colorValue < 0)
        return color
    red := Round(((colorValue >> 16) & 0xFF) * (1 - ratio) + 255 * ratio)
    green := Round(((colorValue >> 8) & 0xFF) * (1 - ratio) + 255 * ratio)
    blue := Round((colorValue & 0xFF) * (1 - ratio) + 255 * ratio)
    return Format("{:02X}{:02X}{:02X}", red, green, blue)
}

ResolveButtonHoverColor(normalColor, requestedHoverColor := "") {
    if (requestedHoverColor == "")
        return LightenButtonColor(normalColor)
    ; 相同颜色用于不可用按钮的无反馈状态，不强制制造悬浮变化。
    if (StrLower(normalColor) == StrLower(requestedHoverColor))
        return requestedHoverColor
    normalLuma := GetButtonColorLuma(normalColor)
    hoverLuma := GetButtonColorLuma(requestedHoverColor)
    if (normalLuma >= 0 && hoverLuma > normalLuma)
        return requestedHoverColor
    return LightenButtonColor(normalColor)
}

ResolveButtonPressedColor(normalColor, requestedPressedColor := "") {
    if (requestedPressedColor == "")
        return DarkenButtonColor(normalColor)
    normalLuma := GetButtonColorLuma(normalColor)
    pressedLuma := GetButtonColorLuma(requestedPressedColor)
    if (normalLuma >= 0 && pressedLuma >= 0 && pressedLuma < normalLuma)
        return requestedPressedColor
    return DarkenButtonColor(normalColor)
}

ResolvePersistentButtonPressedColor(hoverColor, requestedPressedColor := "") {
    if (requestedPressedColor != "") {
        hoverLuma := GetButtonColorLuma(hoverColor)
        pressedLuma := GetButtonColorLuma(requestedPressedColor)
        if (hoverLuma >= 0 && pressedLuma > hoverLuma)
            return requestedPressedColor
    }
    return LightenButtonColor(hoverColor)
}

ResolveButtonFeedbackPressedColor(normalColor, hoverColor, requestedPressedColor, feedbackMode) {
    if (feedbackMode == ButtonFeedbackMode.Dismissive)
        return ResolveButtonPressedColor(normalColor, requestedPressedColor)
    return ResolvePersistentButtonPressedColor(hoverColor, requestedPressedColor)
}

ButtonControlSubclassProc(hWnd, message, wParam, lParam, subclassId, referenceData) {
    try {
        switch message {
            case Win32.WM_MOUSEMOVE:
                UpdateButtonHover(hWnd)
            case Win32.WM_MOUSELEAVE:
                HandleButtonMouseLeave(hWnd)
            case Win32.WM_LBUTTONDOWN, Win32.WM_LBUTTONDBLCLK:
                DllCall("user32\SetFocus", "Ptr", hWnd, "Ptr")
                BeginButtonPress(hWnd)
                return 0
            case Win32.WM_LBUTTONUP:
                EndButtonPress()
                return 0
            case Win32.WM_SETCURSOR:
                if App.uiInteractions.HasButton(hWnd)
                    && IsHoverButtonAvailable(
                        App.uiInteractions.GetButton(hWnd)) {
                    SetHandCursor()
                    return 1
                }
            case Win32.WM_SETFOCUS, Win32.WM_KILLFOCUS:
                SetTimer(RedrawRoundedButton.Bind(hWnd), -1)
            case Win32.WM_CANCELMODE:
                if (App.uiInteractions.PressedButton == hWnd)
                    CancelButtonPress()
            case Win32.WM_CAPTURECHANGED:
                HandleButtonCaptureChanged(hWnd)
            case Win32.WM_NCDESTROY:
                RoundedButtonInputRouter.Detach(hWnd)
        }
    } catch {
        ; Win32 子类回调不能让 AHK 异常越过原生窗口过程边界。
    }
    return DllCall("comctl32\DefSubclassProc", "Ptr", hWnd, "UInt", message,
        "Ptr", wParam, "Ptr", lParam, "Ptr")
}

EnableRoundedButtonRendering(ctrl) {
    try hWnd := ctrl.Hwnd
    catch
        return false
    if !hWnd || !RoundedButtonRenderer.EnsureStarted()
        return false
    try className := StrLower(WinGetClass("ahk_id " hWnd))
    catch
        return false
    style := DllCall("user32\GetWindowLongW", "Ptr", hWnd, "Int", -16, "Int") ; GWL_STYLE：读取控件窗口样式位。
    if (className == "static") {
        ; SS_OWNERDRAW 保留 SS_NOTIFY、WS_TABSTOP 和垂直居中等其余样式。
        ownerDrawStyle := (style & ~0x1F) | 0x0D
    } else if (className == "button") {
        ownerDrawStyle := (style & ~0x0F) | 0x0B ; BS_OWNERDRAW：由应用完整绘制按钮外观。
    } else {
        return false
    }
    if !RoundedButtonInputRouter.Attach(hWnd)
        return false
    if (ownerDrawStyle != style) {
        DllCall("kernel32\SetLastError", "UInt", 0)
        previousStyle := DllCall("user32\SetWindowLongW", "Ptr", hWnd,
            "Int", -16, "Int", ownerDrawStyle, "Int")
        if (!previousStyle && A_LastError) {
            RoundedButtonInputRouter.Detach(hWnd)
            return false
        }
        DllCall("user32\SetWindowPos", "Ptr", hWnd, "Ptr", 0,
            "Int", 0, "Int", 0, "Int", 0, "Int", 0,
            "UInt", 0x0037, "Int") ; 通知边框样式变化，但不激活、移动、缩放或调整层级。
    }
    return true
}

RedrawRoundedButton(hWnd) {
    if hWnd && DllCall("user32\IsWindow", "Ptr", hWnd, "Int")
        DllCall("user32\RedrawWindow", "Ptr", hWnd, "Ptr", 0, "Ptr", 0,
            "UInt", Win32.RDW_BUTTON_REFRESH, "Int")
}

OnDrawRoundedButton(wParam, lParam, msg, hwnd) {
    if !lParam
        return
    itemHwndOffset := A_PtrSize == 8 ? 24 : 20
    itemHwnd := NumGet(lParam, itemHwndOffset, "Ptr")
    if !App.uiInteractions.HasButton(itemHwnd)
        return
    state := App.uiInteractions.GetButton(itemHwnd)
    if !state.HasOwnProp("roundedOwnerDraw") || !state.roundedOwnerDraw
        return
    hdcOffset := itemHwndOffset + A_PtrSize
    rectOffset := hdcOffset + A_PtrSize
    itemHdc := NumGet(lParam, hdcOffset, "Ptr")
    left := NumGet(lParam, rectOffset, "Int")
    top := NumGet(lParam, rectOffset + 4, "Int")
    right := NumGet(lParam, rectOffset + 8, "Int")
    bottom := NumGet(lParam, rectOffset + 12, "Int")
    if RoundedButtonRenderer.Draw(itemHdc, right - left, bottom - top, state)
        return 1
}

OnRoundedButtonFocusChanged(wParam, lParam, msg, hwnd) {
    if IsRoundedButtonInputRouted(hwnd)
        return
    if App.uiInteractions.HasButton(hwnd) {
        state := App.uiInteractions.GetButton(hwnd)
        if state.HasOwnProp("roundedOwnerDraw") && state.roundedOwnerDraw
            SetTimer(RedrawRoundedButton.Bind(hwnd), -1)
    }
}

ShutdownRoundedButtonRenderer(*) {
    RoundedButtonInputRouter.Shutdown()
    RoundedButtonRenderer.Shutdown()
}

RegisterHoverButton(ctrl, normalColor := "333333", hoverColor := "", pressedColor := "",
    textColor := "", textAlign := "center", textInsetDip := 4) {
    try hWnd := ctrl.Hwnd
    catch
        return
    if !hWnd
        return
    ; 所有可交互按钮统一使用当前语言的 Windows 系统 UI 字体粗体。只指定粗体
    ; 属性而不指定字号和颜色，保留各窗口为按钮设置的原始尺寸与文字颜色。
    try ctrl.SetFont("norm bold", LocalizationService.GetLanguageSystemUiFontName())
    ; Text 伪按钮补上 WS_TABSTOP，配合全局 Enter/Space 处理提供键盘操作。
    try ctrl.Opt("+0x10000")
    if textColor == "" {
        textColor := StrLower(normalColor)
                == StrLower(UiThemeService.Color("Toolbar"))
            ? UiThemeService.Color("ToolbarText")
            : UiThemeService.Color("ButtonText")
    }
    hoverColor := ResolveButtonHoverColor(normalColor, hoverColor)
    requestedPressedColor := pressedColor
    pressedColor := ResolvePersistentButtonPressedColor(hoverColor, pressedColor)
    state := {
        ctrl: ctrl,
        normal: normalColor,
        hover: hoverColor,
        pressed: pressedColor,
        requestedPressed: requestedPressedColor,
        feedbackMode: ButtonFeedbackMode.Persistent,
        current: normalColor,
        textColor: textColor,
        textAlign: textAlign,
        textInsetDip: textInsetDip,
        roundedOwnerDraw: false
    }
    if !App.uiInteractions.RegisterButton(hWnd, state)
        return
    state.roundedOwnerDraw := EnableRoundedButtonRendering(ctrl)
    if state.roundedOwnerDraw
        RedrawRoundedButton(hWnd)
}

; 图标与正文分别使用符号字体和当前语言的系统 UI 字体，避免 Emoji 字体回退
; 造成图标过小、字重不一致或基线漂移。尺寸以 DIP 保存并随窗口 DPI 缩放。
SetButtonIcon(ctrl, glyph, fontName := "Segoe MDL2 Assets", sizeDip := 14,
    gapDip := 7) {
    try hWnd := ctrl.Hwnd
    catch
        return false
    if !App.uiInteractions.HasButton(hWnd)
        return false
    state := App.uiInteractions.GetButton(hWnd)
    if !state.HasOwnProp("roundedOwnerDraw") || !state.roundedOwnerDraw
        return false
    try {
        sizeDip := Max(8, sizeDip + 0)
        gapDip := Max(0, gapDip + 0)
    } catch {
        return false
    }
    if (glyph == "" || fontName == "")
        return false
    state.buttonIcon := {
        glyph: String(glyph),
        fontName: String(fontName),
        sizeDip: sizeDip,
        gapDip: gapDip
    }
    if state.HasOwnProp("buttonImage")
        state.DeleteProp("buttonImage")
    RedrawRoundedButton(hWnd)
    return true
}

ClearButtonIcon(ctrl) {
    try hWnd := ctrl.Hwnd
    catch
        return false
    if !App.uiInteractions.HasButton(hWnd)
        return false
    state := App.uiInteractions.GetButton(hWnd)
    changed := false
    if state.HasOwnProp("buttonIcon") {
        state.DeleteProp("buttonIcon")
        changed := true
    }
    if state.HasOwnProp("buttonImage") {
        state.DeleteProp("buttonImage")
        changed := true
    }
    if changed
        RedrawRoundedButton(hWnd)
    return changed
}

; SVG 只在按钮创建时通过 resvg 解析一次，状态对象持有渲染后的预乘 BGRA
; Buffer。每次重绘只进行内存像素合成，不读取文件、不重新解析 SVG，也不持有
; HBITMAP／HICON，窗口销毁并注销交互状态后即可自动释放全部图像内存。
SetButtonSvgIcon(ctrl, svgPath, sizeDip := 14, gapDip := 7) {
    try hWnd := ctrl.Hwnd
    catch
        return false
    if !App.uiInteractions.HasButton(hWnd)
        return false
    state := App.uiInteractions.GetButton(hWnd)
    if !state.HasOwnProp("roundedOwnerDraw") || !state.roundedOwnerDraw
        return false
    try {
        sizeDip := Max(8, sizeDip + 0)
        gapDip := Max(0, gapDip + 0)
        svgPath := String(svgPath)
    } catch {
        return false
    }
    if svgPath == "" || !FileExist(svgPath) || DirExist(svgPath)
        return false
    if state.HasOwnProp("buttonImage")
        && state.buttonImage.HasOwnProp("sourcePath")
        && state.buttonImage.sourcePath == svgPath
        && state.buttonImage.sizeDip == sizeDip
        && state.buttonImage.gapDip == gapDip
        return true
    dpi := DllCall("user32\GetDpiForWindow", "Ptr", hWnd, "UInt")
    if !dpi
        dpi := 96
    targetPixels := Max(1, Round(sizeDip * dpi / 96))
    ; 四倍超采样兼顾小尺寸斜线质量与一次性创建开销；最低 64 像素可让
    ; 100% DPI 下的 14 DIP 图标仍保留足够的边缘覆盖信息。
    renderSize := Max(64, Min(512, targetPixels * 4))
    snapshot := App.svgRenderer.RenderFile(svgPath, dpi, renderSize)
    if !snapshot
        return false
    state.buttonImage := {
        Width: snapshot.Width,
        Height: snapshot.Height,
        Pixels: snapshot.Pixels,
        sizeDip: sizeDip,
        gapDip: gapDip,
        sourcePath: svgPath
    }
    if state.HasOwnProp("buttonIcon")
        state.DeleteProp("buttonIcon")
    RedrawRoundedButton(hWnd)
    return true
}

; 全应用的 Lucide 功能图标统一从受许可的资源目录解析。窗口只声明图标文件名
; 与排版尺寸，不再各自拼接资源路径，便于复用同一语义资源并集中审计发行内容。
SetButtonLucideIcon(ctrl, iconName, sizeDip := 14, gapDip := 7) {
    try iconName := String(iconName)
    catch
        return false
    if iconName == "" || InStr(iconName, "\") || InStr(iconName, "/")
        return false
    return SetButtonSvgIcon(ctrl, GetApplicationAssetPath(
        "ui-icons\lucide\" iconName), sizeDip, gapDip)
}

; 悬浮提示跟随按钮交互状态注册，不由具体窗口另建计时器。这样托管窗口销毁并
; 注销 HWND 时，提示文本会与按钮状态一起释放，不会命中已经复用的旧句柄。
SetButtonTooltip(ctrl, text) {
    try hWnd := ctrl.Hwnd
    catch
        return false
    if !App.uiInteractions.HasButton(hWnd)
        return false
    state := App.uiInteractions.GetButton(hWnd)
    try text := String(text)
    catch
        return false
    if text == "" {
        if state.HasOwnProp("tooltipText")
            state.DeleteProp("tooltipText")
    } else {
        state.tooltipText := text
    }
    return true
}

RegisterButtonClick(ctrl, callback, feedbackMode := ButtonFeedbackMode.Persistent) {
    try hWnd := ctrl.Hwnd
    catch
        return
    if !App.uiInteractions.HasButton(hWnd)
        return
    state := App.uiInteractions.GetButton(hWnd)
    state.clickCallback := callback
    state.feedbackMode := feedbackMode
    if state.HasOwnProp("cursorOnly") && state.cursorOnly {
        ; 纯文字标签也可作为原生选择控件的扩大点击区域。为它补齐无色差的
        ; 交互状态后，仍由统一的按下／抬起分发器验证点击，但不会产生按钮底色。
        neutralColor := UiThemeService.Color("Window")
        state.normal := neutralColor
        state.hover := neutralColor
        state.pressed := neutralColor
        state.requestedPressed := neutralColor
        state.current := neutralColor
        state.roundedOwnerDraw := false
    } else {
        state.pressed := ResolveButtonFeedbackPressedColor(state.normal,
            state.hover, state.requestedPressed, feedbackMode)
    }
    state.pendingClick := 0
    state.suppressClickUntil := 0
    state.releaseResetTimer := 0
    ctrl.OnEvent("Click", HandleRegisteredButtonClick)
}

HandleRegisteredButtonClick(guiCtrlObj, eventArgs*) {
    try hWnd := guiCtrlObj.Hwnd
    catch
        return
    if !App.uiInteractions.HasButton(hWnd)
        return
    state := App.uiInteractions.GetButton(hWnd)
    if !state.HasOwnProp("clickCallback")
        return

    if GetKeyState("LButton", "P") {
        ; Click 通知可能由 Text 伪按钮在按下阶段发出。此时只缓存回调，
        ; 没有通过 BeginButtonPress 验证的按下（例如不可用按钮）直接丢弃。
        if (App.uiInteractions.PressedButton != hWnd)
            return
        callbackArgs := [guiCtrlObj]
        for eventArg in eventArgs
            callbackArgs.Push(eventArg)
        state.pendingClick := {
            callback: state.clickCallback,
            args: callbackArgs
        }
        return
    }

    if (state.suppressClickUntil && GetTickCount64() <= state.suppressClickUntil)
        return
    state.suppressClickUntil := 0
    state.clickCallback.Call(guiCtrlObj, eventArgs*)
}

RunDeferredButtonClick(hWnd, pendingClick, *) {
    ReleaseButtonMouseCapture(hWnd)
    if !App.uiInteractions.HasButton(hWnd)
        return
    state := App.uiInteractions.GetButton(hWnd)
    if !IsHoverButtonAvailable(state)
        return
    pendingClick.callback.Call(pendingClick.args*)
}

CancelButtonReleaseReset(hWnd) {
    if !App.uiInteractions.HasButton(hWnd)
        return
    state := App.uiInteractions.GetButton(hWnd)
    if !state.HasOwnProp("releaseResetTimer") || !state.releaseResetTimer
        return
    SetTimer(state.releaseResetTimer, 0)
    state.releaseResetTimer := 0
}

ScheduleButtonReleaseReset(hWnd) {
    if !App.uiInteractions.HasButton(hWnd)
        return
    CancelButtonReleaseReset(hWnd)
    state := App.uiInteractions.GetButton(hWnd)
    resetTimer := ResetButtonAfterRelease.Bind(hWnd)
    state.releaseResetTimer := resetTimer
    SetTimer(resetTimer, -ButtonFeedbackTiming.ReleaseResetMs)
}

ResetButtonAfterRelease(hWnd, *) {
    if !App.uiInteractions.HasButton(hWnd)
        return
    state := App.uiInteractions.GetButton(hWnd)
    state.releaseResetTimer := 0
    if (App.uiInteractions.PressedButton == hWnd)
        return
    if !DllCall("user32\IsWindow", "Ptr", hWnd, "Int")
        return
    App.uiInteractions.ClearHoveredButton(hWnd)
    SetButtonBackground(state.ctrl, state.normal)
}

RegisterHandCursorControl(ctrl) {
    try hWnd := ctrl.Hwnd
    catch
        return
    if hWnd
        App.uiInteractions.RegisterButton(hWnd,
            {ctrl: ctrl, cursorOnly: true})
}

SetRegisteredButtonEnabled(ctrl, enabled) {
    ; 启停已注册按钮时同步清理悬浮、按下和延迟恢复状态。业务窗口无需知道
    ; 圆角所有者绘制、交互注册表和重绘时序，也不会留下“已禁用但仍高亮”。
    if !IsObject(ctrl)
        return false
    try hWnd := ctrl.Hwnd
    catch
        return false
    if !hWnd || !DllCall("user32\IsWindow", "Ptr", hWnd, "Int")
        return false
    enabled := !!enabled
    if App.uiInteractions.HasButton(hWnd) {
        if App.uiInteractions.PressedButton == hWnd
            CancelButtonPress()
        CancelButtonReleaseReset(hWnd)
        App.uiInteractions.ClearHoveredButton(hWnd)
        state := App.uiInteractions.GetButton(hWnd)
        state.current := state.normal
    }
    try ctrl.Enabled := enabled
    catch
        return false
    RedrawRoundedButton(hWnd)
    return true
}

SetHoverButtonColors(ctrl, normalColor, hoverColor := "", pressedColor := "") {
    try hWnd := ctrl.Hwnd
    catch
        return
    if !App.uiInteractions.HasButton(hWnd)
        return
    hoverColor := ResolveButtonHoverColor(normalColor, hoverColor)
    state := App.uiInteractions.GetButton(hWnd)
    state.normal := normalColor
    state.hover := hoverColor
    state.requestedPressed := pressedColor
    state.pressed := ResolveButtonFeedbackPressedColor(normalColor, hoverColor,
        pressedColor, state.feedbackMode)
}

SetButtonTextColor(ctrl, color) {
    try hWnd := ctrl.Hwnd
    catch
        return false
    if !hWnd || !DllCall("user32\IsWindow", "Ptr", hWnd, "Int")
        return false
    if App.uiInteractions.HasButton(hWnd) {
        state := App.uiInteractions.GetButton(hWnd)
        state.textColor := color
        if state.HasOwnProp("roundedOwnerDraw") && state.roundedOwnerDraw {
            RedrawRoundedButton(hWnd)
            return true
        }
    }
    try {
        ctrl.Opt("c" color)
        return true
    } catch {
        return false
    }
}

SetButtonBackground(ctrl, color) {
    try hWnd := ctrl.Hwnd
    catch
        return false
    if !hWnd || !DllCall("user32\IsWindow", "Ptr", hWnd, "Int")
        return false
    ; 业务回调可以立即更新按钮状态，但不能覆盖尚未结束的抬起反馈。
    if App.uiInteractions.HasButton(hWnd) {
        state := App.uiInteractions.GetButton(hWnd)
        if state.HasOwnProp("releaseResetTimer") && state.releaseResetTimer
            return true
        state.current := color
        if state.HasOwnProp("roundedOwnerDraw") && state.roundedOwnerDraw {
            RedrawRoundedButton(hWnd)
            return true
        }
    }

    redrawSuspended := false
    colorApplied := false
    try {
        DllCall("user32\SendMessageW", "Ptr", hWnd, "UInt", Win32.WM_SETREDRAW,
            "Ptr", false, "Ptr", 0, "Ptr")
        redrawSuspended := true
        ctrl.Opt("Background" color)
        colorApplied := true
    } catch {
        colorApplied := false
    } finally {
        if redrawSuspended && DllCall("user32\IsWindow", "Ptr", hWnd, "Int")
            DllCall("user32\SendMessageW", "Ptr", hWnd, "UInt", Win32.WM_SETREDRAW,
                "Ptr", true, "Ptr", 0, "Ptr")
    }
    if !colorApplied
        return false

    try hWnd := ctrl.Hwnd
    catch
        return false
    if !hWnd || !DllCall("user32\IsWindow", "Ptr", hWnd, "Int")
        return false
    DllCall("user32\RedrawWindow", "Ptr", hWnd, "Ptr", 0, "Ptr", 0,
        "UInt", Win32.RDW_BUTTON_REFRESH, "Int")
    return true
}

IsPointerInsideButton(hWnd) {
    if !hWnd || !DllCall("user32\IsWindow", "Ptr", hWnd, "Int")
        return false
    cursorPoint := Buffer(8, 0)
    windowRect := Buffer(16, 0)
    if !DllCall("user32\GetCursorPos", "Ptr", cursorPoint, "Int")
        || !DllCall("user32\GetWindowRect", "Ptr", hWnd, "Ptr", windowRect, "Int")
        return false
    cursorX := NumGet(cursorPoint, 0, "Int")
    cursorY := NumGet(cursorPoint, 4, "Int")
    return cursorX >= NumGet(windowRect, 0, "Int")
        && cursorX < NumGet(windowRect, 8, "Int")
        && cursorY >= NumGet(windowRect, 4, "Int")
        && cursorY < NumGet(windowRect, 12, "Int")
}

MovePointerToControlCenter(control) {
    try hWnd := control.Hwnd
    catch
        return false
    if !hWnd || !DllCall("user32\IsWindow", "Ptr", hWnd, "Int")
        return false
    controlRect := Buffer(16, 0)
    if !DllCall("user32\GetWindowRect", "Ptr", hWnd,
            "Ptr", controlRect, "Int")
        return false
    centerX := (NumGet(controlRect, 0, "Int")
        + NumGet(controlRect, 8, "Int")) // 2
    centerY := (NumGet(controlRect, 4, "Int")
        + NumGet(controlRect, 12, "Int")) // 2
    return !!DllCall("user32\SetCursorPos", "Int", centerX,
        "Int", centerY, "Int")
}

ReleaseButtonMouseCapture(expectedHwnd, *) {
    if (DllCall("user32\GetCapture", "Ptr") == expectedHwnd)
        DllCall("user32\ReleaseCapture", "Int")
}

CancelButtonPress() {
    interactions := App.uiInteractions
    pressedHwnd := interactions.PressedButton
    if !pressedHwnd
        return
    interactions.ClearPressedButton(pressedHwnd)
    if interactions.HasButton(pressedHwnd) {
        pressedState := interactions.GetButton(pressedHwnd)
        if pressedState.HasOwnProp("pendingClick")
            pressedState.pendingClick := 0
        if pressedState.HasOwnProp("suppressClickUntil")
            pressedState.suppressClickUntil := 0
        CancelButtonReleaseReset(pressedHwnd)
        if !(pressedState.HasOwnProp("cursorOnly") && pressedState.cursorOnly)
            SetButtonBackground(pressedState.ctrl, pressedState.normal)
    }
    interactions.ClearHoveredButton(pressedHwnd)
    ReleaseButtonMouseCapture(pressedHwnd)
}

BeginButtonPress(hWnd) {
    interactions := App.uiInteractions
    if !interactions.HasButton(hWnd)
        return
    state := interactions.GetButton(hWnd)
    if (state.HasOwnProp("cursorOnly") && state.cursorOnly)
        && !state.HasOwnProp("clickCallback")
        return
    if !IsHoverButtonAvailable(state)
        return
    if (interactions.PressedButton && interactions.PressedButton != hWnd)
        CancelButtonPress()
    if state.HasOwnProp("pendingClick")
        state.pendingClick := 0
    if state.HasOwnProp("suppressClickUntil")
        state.suppressClickUntil := 0
    CancelButtonReleaseReset(hWnd)
    interactions.SetPressedButton(hWnd)
    interactions.SetHoveredButton(hWnd)
    SetButtonBackground(state.ctrl, state.pressed)
    DllCall("user32\SetCapture", "Ptr", hWnd, "Ptr")
}

EndButtonPress() {
    interactions := App.uiInteractions
    pressedHwnd := interactions.PressedButton
    if !pressedHwnd
        return
    interactions.ClearPressedButton(pressedHwnd)
    if !interactions.HasButton(pressedHwnd) {
        SetTimer(ReleaseButtonMouseCapture.Bind(pressedHwnd), -1)
        interactions.ClearHoveredButton(pressedHwnd)
        return
    }
    state := interactions.GetButton(pressedHwnd)
    pendingClick := state.HasOwnProp("pendingClick") ? state.pendingClick : 0
    state.pendingClick := 0
    if IsPointerInsideButton(pressedHwnd) && IsHoverButtonAvailable(state) {
        ; SS_OWNERDRAW Static 不保证生成 STN_CLICKED；鼠标抬起验证通过后直接补齐回调任务。
        if !pendingClick && state.HasOwnProp("clickCallback") {
            pendingClick := {
                callback: state.clickCallback,
                args: [state.ctrl]
            }
        }
        interactions.SetHoveredButton(pressedHwnd)
        TrackButtonMouseLeave(pressedHwnd)
        ScheduleButtonReleaseReset(pressedHwnd)
        if pendingClick {
            state.suppressClickUntil := GetTickCount64() + 100
            SetTimer(RunDeferredButtonClick.Bind(pressedHwnd, pendingClick), -1)
        } else {
            SetTimer(ReleaseButtonMouseCapture.Bind(pressedHwnd), -1)
        }
        return
    }
    state.suppressClickUntil := 0
    CancelButtonReleaseReset(pressedHwnd)
    SetTimer(ReleaseButtonMouseCapture.Bind(pressedHwnd), -1)
    interactions.ClearHoveredButton(pressedHwnd)
    SetButtonBackground(state.ctrl, state.normal)
}

CanHoverButton(state) {
    ; 删除/暂停在没有选中项目时只是灰色提示态，不显示可用按钮的悬浮反馈。
    if IsSet(Main) && (state.ctrl == Main.btnDel || state.ctrl == Main.btnPause)
        return Main.lv.GetNext(0) > 0
    return true
}

IsHoverButtonAvailable(state) {
    try hWnd := state.ctrl.Hwnd
    catch
        return false
    return IsControlEffectivelyEnabled(hWnd) && CanHoverButton(state)
}

IsControlEffectivelyEnabled(hWnd) {
    if !hWnd
        return false
    rootHwnd := DllCall("user32\GetAncestor", "Ptr", hWnd, "UInt", 2, "Ptr") ; GA_ROOT：从控件向上找到最上层窗口。
    currentHwnd := hWnd
    while currentHwnd {
        if !DllCall("user32\IsWindow", "Ptr", currentHwnd, "Int")
            || !DllCall("user32\IsWindowEnabled", "Ptr", currentHwnd, "Int")
            return false
        if (currentHwnd == rootHwnd)
            return true
        currentHwnd := DllCall("user32\GetParent", "Ptr", currentHwnd, "Ptr")
    }
    return false
}

RestoreHoveredButton() {
    CancelButtonPress()
    interactions := App.uiInteractions
    if !interactions.HoveredButton
        return
    hoveredHwnd := interactions.HoveredButton
    if interactions.HasButton(hoveredHwnd) {
        state := interactions.GetButton(hoveredHwnd)
        ; 抬起后的 50ms 反馈由专用定时器收尾，创建子窗口或失焦不能抢先重置。
        if state.HasOwnProp("releaseResetTimer") && state.releaseResetTimer {
            interactions.ClearHoveredButton(hoveredHwnd)
            return
        }
        if !(state.HasOwnProp("cursorOnly") && state.cursorOnly)
            SetButtonBackground(state.ctrl, state.normal)
    }
    interactions.ClearHoveredButton(hoveredHwnd)
}

UpdateButtonHover(hWnd) {
    interactions := App.uiInteractions
    nowTicks := GetTickCount64()
    if interactions.ShouldPruneButtons(nowTicks) {
        stale := []
        for registeredHwnd, state in interactions.Buttons {
            if !DllCall("user32\IsWindow", "Ptr", registeredHwnd, "Int")
                stale.Push(registeredHwnd)
        }
        for registeredHwnd in stale {
            CancelButtonReleaseReset(registeredHwnd)
            if (interactions.PressedButton == registeredHwnd)
                ReleaseButtonMouseCapture(registeredHwnd)
            interactions.RemoveButton(registeredHwnd)
        }
    }

    if interactions.PressedButton {
        pressedHwnd := interactions.PressedButton
        if (hWnd != pressedHwnd || !interactions.HasButton(pressedHwnd))
            return
        pressedState := interactions.GetButton(pressedHwnd)
        if !IsPointerInsideButton(pressedHwnd) {
            if (interactions.HoveredButton == pressedHwnd) {
                interactions.ClearHoveredButton(pressedHwnd)
                SetButtonBackground(pressedState.ctrl, pressedState.normal)
            }
            return
        }
        if (interactions.HoveredButton != pressedHwnd) {
            interactions.SetHoveredButton(pressedHwnd)
            SetButtonBackground(pressedState.ctrl, pressedState.pressed)
        }
        return
    }

    if (interactions.HoveredButton == hWnd)
        return

    RestoreHoveredButton()
    if !interactions.HasButton(hWnd)
        return
    state := interactions.GetButton(hWnd)
    if !IsHoverButtonAvailable(state)
        return
    SetHandCursor()
    interactions.SetHoveredButton(hWnd)
    TrackButtonMouseLeave(hWnd)
    if (state.HasOwnProp("cursorOnly") && state.cursorOnly)
        return
    ; 抬起后的按下色必须完整保留 50ms，期间轻微移动不能提前切换为悬浮色。
    if state.HasOwnProp("releaseResetTimer") && state.releaseResetTimer
        return
    SetButtonBackground(state.ctrl, state.hover)
}

TrackButtonMouseLeave(hWnd) {
    tmeSize := A_PtrSize == 8 ? 24 : 16
    tme := Buffer(tmeSize, 0)
    NumPut("UInt", tmeSize, tme, 0)
    NumPut("UInt", 0x00000002, tme, 4) ; TME_LEAVE：请求一次鼠标离开控件的通知。
    NumPut("Ptr", hWnd, tme, 8)
    try DllCall("user32\TrackMouseEvent", "Ptr", tme)
}
