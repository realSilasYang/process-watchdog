; 不激活主 ListView 的右键浮层菜单。
; 参考“键鼠重映射小助手”的做法：用 NoActivate 所有者窗口承载菜单项，
; 避免原生 Menu.Show 进入菜单循环后抢走 ListView 焦点并首帧绘制方形选中底色。

class MainContextPopupWindow {
    static MinWindowWidth := 200
    static MaxWindowWidth := 320
    static ItemHeight := 30
    static ItemGap := 0
    static Padding := 6
    static TextInsetDip := 12
    static CheckSlotDip := 18
    static CheckGapDip := 8
    static CheckInsetDip := 16
    static WindowRadiusDip := 9
    static RowRadiusDip := 6
    static ColorLabelHeight := 18
    static ColorSectionTopGap := 6
    static SwatchSize := 24
    static SwatchGap := 6
    static SwatchTopGap := 8
    static SelectedMarkFontSize := 13

    __New(ownerGui) {
        this.OwnerGui := ownerGui
        this.Gui := ""
        this.Disposed := false
        this.VisibilityTimer := ObjBindMethod(this, "MonitorVisibility")
        this.PointerDownCallback := ObjBindMethod(this, "OnPointerDown")
    }

    Show(items) {
        if this.Disposed || !IsObject(items) || items.Length <= 0
            return false
        ownerFocus := DllCall("user32\GetFocus", "Ptr")
        foregroundHwnd := DllCall("user32\GetForegroundWindow", "Ptr")
        this.Hide()
        this.Build(items)
        this.Gui.Show("Hide NoActivate w" this.WindowWidth
            " h" this.WindowHeight)
        this.ApplyRoundedRegion()
        point := Buffer(8, 0)
        if !DllCall("user32\GetCursorPos", "Ptr", point, "Int") {
            this.Hide()
            return false
        }
        x := NumGet(point, 0, "Int")
        y := NumGet(point, 4, "Int") + 4
        this.ConstrainToWorkArea(&x, &y, this.WindowWidth,
            this.WindowHeight)
        shown := DllCall("user32\SetWindowPos", "Ptr", this.Gui.Hwnd,
            "Ptr", -1, "Int", x, "Int", y, "Int", 0, "Int", 0,
            "UInt", 0x0051, "Int") != 0 ; 不改尺寸、不激活并显示窗口
        if shown {
            if ownerFocus
                    && DllCall("user32\IsWindow", "Ptr", ownerFocus, "Int")
                    && DllCall("user32\GetFocus", "Ptr") != ownerFocus
                DllCall("user32\SetFocus", "Ptr", ownerFocus, "Ptr")
            OnMessage(Win32.WM_LBUTTONDOWN, this.PointerDownCallback)
            OnMessage(Win32.WM_RBUTTONDOWN, this.PointerDownCallback)
            OnMessage(Win32.WM_NCLBUTTONDOWN, this.PointerDownCallback)
            SetTimer(this.VisibilityTimer, 50)
        }
        return shown
    }

    Build(items) {
        menuColor := UiThemeService.Color("Menu")
        textColor := UiThemeService.Color("Text")
        hoverColor := UiThemeService.Color("MenuHover")
        this.Gui := Gui("+Owner" this.OwnerGui.Hwnd
            " -Caption +ToolWindow +AlwaysOnTop +E0x08000000")
        this.Gui.BackColor := menuColor
        this.Gui.MarginX := 0
        this.Gui.MarginY := 0
        this.Gui.SetFont("s10 c" textColor,
            LocalizationService.GetLanguageSystemUiFontName())
        this.WindowWidth := this.ResolveWindowWidth(items)
        y := MainContextPopupWindow.Padding
        contentWidth := this.WindowWidth
            - MainContextPopupWindow.Padding * 2
        this.SwatchButtons := []
        this.ColorLabel := ""
        this.ColorLabelIcon := ""
        for item in items {
            if item.HasOwnProp("ColorPalette") && item.ColorPalette {
                this.AddColorPalette(item, &y, contentWidth, menuColor,
                    textColor)
                continue
            }
            enabled := !(item.HasOwnProp("Enabled") && !item.Enabled)
            checkText := item.HasOwnProp("Check") && item.Check ? "✓" : ""
            rowButton := this.Gui.Add("Text",
                "x" MainContextPopupWindow.Padding " y" y
                " w" contentWidth " h" MainContextPopupWindow.ItemHeight
                " 0x200 Background" menuColor " c" textColor,
                item.Text)
            rowButton.SetFont("s10 norm",
                LocalizationService.GetLanguageSystemUiFontName())
            RegisterHoverButton(rowButton, menuColor, hoverColor,
                hoverColor, textColor, "left",
                MainContextPopupWindow.TextInsetDip)
            ; 普通按钮默认使用粗体；菜单项恢复常规字重以贴近原生菜单。
            rowButton.SetFont("s10 norm",
                LocalizationService.GetLanguageSystemUiFontName())
            try rowButton.Opt("-0x10000")
            if App.uiInteractions.HasButton(rowButton.Hwnd) {
                buttonState := App.uiInteractions.GetButton(rowButton.Hwnd)
                buttonState.parentColor := menuColor
                buttonState.radiusDip := MainContextPopupWindow.RowRadiusDip
                buttonState.noFocus := true
                buttonState.rightText := checkText
                buttonState.rightTextWidthDip :=
                    MainContextPopupWindow.CheckSlotDip
                buttonState.rightTextGapDip :=
                    MainContextPopupWindow.CheckGapDip
                buttonState.rightTextInsetDip :=
                    MainContextPopupWindow.CheckInsetDip
                if !enabled
                    buttonState.textColor := UiThemeService.Color("MutedText")
                RedrawRoundedButton(rowButton.Hwnd)
            }
            if enabled && item.HasOwnProp("Action") && IsObject(item.Action) {
                RegisterButtonClick(rowButton,
                    ObjBindMethod(this, "InvokeAction", item.Action),
                    ButtonFeedbackMode.Dismissive)
            } else {
                SetRegisteredButtonEnabled(rowButton, false)
            }
            y += MainContextPopupWindow.ItemHeight
                + MainContextPopupWindow.ItemGap
        }
        this.WindowHeight := y - MainContextPopupWindow.ItemGap
            + MainContextPopupWindow.Padding
    }

    AddColorPalette(item, &y, contentWidth, menuColor, textColor) {
        y += MainContextPopupWindow.ColorSectionTopGap
        label := this.Gui.Add("Text", "x-10000 y" y " w1 h"
            MainContextPopupWindow.ColorLabelHeight
            " Center 0x200 Background" menuColor " c" textColor, item.Text)
        label.SetFont("s10 norm bold",
            LocalizationService.GetLanguageSystemUiFontName())
        iconSize := 18
        iconGap := 6
        textWidth := Min(Max(1, contentWidth - iconSize - iconGap),
            this.MeasureControlTextWidthDip(label, item.Text) + 2)
        headingWidth := iconSize + iconGap + textWidth
        headingX := MainContextPopupWindow.Padding
            + Max(0, Floor((contentWidth - headingWidth) / 2))
        label.Move(headingX + iconSize + iconGap, y, textWidth,
            MainContextPopupWindow.ColorLabelHeight)
        iconControl := this.Gui.Add("Text", "x" headingX " y" y " w"
            iconSize " h" MainContextPopupWindow.ColorLabelHeight
            " Center 0x200 Background" menuColor, "")
        RegisterHoverButton(iconControl, menuColor, menuColor, menuColor,
            textColor, "center", 0)
        try iconControl.Opt("-0x10000")
        if App.uiInteractions.HasButton(iconControl.Hwnd) {
            iconState := App.uiInteractions.GetButton(iconControl.Hwnd)
            iconState.parentColor := menuColor
            iconState.noFocus := true
            iconName := item.HasOwnProp("IconName")
                ? item.IconName : "palette.svg"
            iconColorRole := item.HasOwnProp("IconColorRole")
                    && UiThemeService.HasColor(item.IconColorRole)
                ? item.IconColorRole : "ThemeIcon"
            SetButtonLucideIcon(iconControl, iconName, iconSize, 0,
                "theme:" iconColorRole)
            SetRegisteredButtonEnabled(iconControl, false)
        }
        this.ColorLabel := label
        this.ColorLabelIcon := iconControl
        y += MainContextPopupWindow.ColorLabelHeight
            + MainContextPopupWindow.SwatchTopGap

        presets := MainSequenceColorPalette.Presets()
        swatchRowWidth := (presets.Length + 1)
            * MainContextPopupWindow.SwatchSize
            + presets.Length * MainContextPopupWindow.SwatchGap
        startX := MainContextPopupWindow.Padding
            + Max(0, Floor((contentWidth - swatchRowWidth) / 2))
        selectedColor := item.HasOwnProp("SelectedColor")
            ? MainSequenceColorPalette.NormalizeKey(item.SelectedColor) : ""
        for index, preset in presets
            this.AddColorSwatch(startX, y, index - 1, preset.Key,
                selectedColor, item.Action, this.GetPresetTooltip(preset.Key))
        this.AddColorSwatch(startX, y, presets.Length, "", selectedColor,
            item.Action, Tr("清除圆点颜色"))
        y += MainContextPopupWindow.SwatchSize
    }

    AddColorSwatch(startX, y, index, presetKey, selectedColor, action,
            tooltipText) {
        menuColor := UiThemeService.Color("Menu")
        colorKey := MainSequenceColorPalette.NormalizeKey(presetKey)
        color := colorKey == "" ? menuColor
            : MainSequenceColorPalette.Color(colorKey)
        mark := colorKey == "" ? "✕"
            : (colorKey == selectedColor ? "✓" : "")
        x := startX + index * (MainContextPopupWindow.SwatchSize
            + MainContextPopupWindow.SwatchGap)
        button := this.Gui.Add("Text", "x" x " y" y " w"
            MainContextPopupWindow.SwatchSize " h"
            MainContextPopupWindow.SwatchSize
            " Center 0x200 Background" color " c"
            UiThemeService.Color("Text"), mark)
        button.SetFont("s" MainContextPopupWindow.SelectedMarkFontSize
            " norm bold",
            LocalizationService.GetLanguageSystemUiFontName())
        RegisterHoverButton(button, color, color, color,
            colorKey == "" ? UiThemeService.Color("MutedText")
                : UiThemeService.Color("Text"), "center", 0)
        try button.Opt("-0x10000")
        if App.uiInteractions.HasButton(button.Hwnd) {
            state := App.uiInteractions.GetButton(button.Hwnd)
            state.parentColor := menuColor
            state.radiusDip := 5
            state.noFocus := true
            if colorKey == ""
                SetButtonClearMark(button, 16, 2)
            RedrawRoundedButton(button.Hwnd)
        }
        SetButtonTooltip(button, tooltipText)
        if IsObject(action)
            RegisterButtonClick(button,
                ObjBindMethod(this, "InvokeColorAction", action, colorKey),
                ButtonFeedbackMode.Dismissive)
        this.SwatchButtons.Push({Control: button, Key: colorKey})
        return button
    }

    GetPresetTooltip(presetKey) {
        switch MainSequenceColorPalette.NormalizeKey(presetKey) {
            case "sage": return Tr("雾松绿")
            case "mist": return Tr("青灰蓝")
            case "lavender": return Tr("薰衣草紫")
            case "rose": return Tr("烟粉")
            case "amber": return Tr("浅琥珀")
            case "teal": return Tr("静谧青")
            case "pearl": return Tr("珍珠灰")
            default: return Tr("清除圆点颜色")
        }
    }

    ResolveWindowWidth(items) {
        maxTextWidth := 0
        hasCheckSlot := false
        measure := this.Gui.Add("Text", "x-10000 y-10000 w1 h1", "")
        measure.SetFont("s10 norm",
            LocalizationService.GetLanguageSystemUiFontName())
        hdc := DllCall("user32\GetDC", "Ptr", this.Gui.Hwnd, "Ptr")
        if hdc {
            hFont := DllCall("user32\SendMessageW", "Ptr", measure.Hwnd,
                "UInt", Win32.WM_GETFONT, "Ptr", 0, "Ptr", 0, "Ptr")
            previousFont := hFont
                ? DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", hFont,
                    "Ptr") : 0
            try {
                for item in items {
                    maxTextWidth := Max(maxTextWidth,
                        this.MeasureTextWidth(hdc, item.Text))
                    if item.HasOwnProp("Check")
                        hasCheckSlot := true
                }
            } finally {
                if previousFont
                    DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr",
                        previousFont, "Ptr")
                DllCall("user32\ReleaseDC", "Ptr", this.Gui.Hwnd,
                    "Ptr", hdc)
            }
        }
        dpi := DllCall("user32\GetDpiForWindow", "Ptr", this.Gui.Hwnd,
            "UInt")
        if !dpi
            dpi := 96
        textWidthDip := Round(maxTextWidth * 96 / dpi)
        checkWidthDip := hasCheckSlot
            ? MainContextPopupWindow.CheckSlotDip
                + MainContextPopupWindow.CheckGapDip
                + MainContextPopupWindow.CheckInsetDip
            : 0
        measuredWidth := MainContextPopupWindow.Padding * 2
            + MainContextPopupWindow.TextInsetDip + textWidthDip
            + checkWidthDip
        swatchCount := MainSequenceColorPalette.Presets().Length
        for item in items {
            if item.HasOwnProp("ColorPalette") && item.ColorPalette {
                swatchWidth := (swatchCount + 1)
                    * MainContextPopupWindow.SwatchSize
                    + swatchCount * MainContextPopupWindow.SwatchGap
                measuredWidth := Max(measuredWidth,
                    MainContextPopupWindow.Padding * 2 + swatchWidth)
                break
            }
        }
        minWidth := MainContextPopupWindow.MinWindowWidth
        maxWidth := MainContextPopupWindow.MaxWindowWidth
        return Min(Max(measuredWidth, minWidth), maxWidth)
    }

    MeasureTextWidth(hdc, text) {
        size := Buffer(8, 0)
        text := String(text)
        if DllCall("gdi32\GetTextExtentPoint32W", "Ptr", hdc,
                "Str", text, "Int", StrLen(text), "Ptr", size, "Int")
            return NumGet(size, 0, "Int")
        return 0
    }

    MeasureControlTextWidthDip(control, text) {
        hdc := DllCall("user32\GetDC", "Ptr", control.Hwnd, "Ptr")
        if !hdc
            return 0
        font := DllCall("user32\SendMessageW", "Ptr", control.Hwnd,
            "UInt", Win32.WM_GETFONT, "Ptr", 0, "Ptr", 0, "Ptr")
        previousFont := font ? DllCall("gdi32\SelectObject", "Ptr", hdc,
            "Ptr", font, "Ptr") : 0
        try {
            pixelWidth := this.MeasureTextWidth(hdc, text)
            dpi := DllCall("user32\GetDpiForWindow", "Ptr", control.Hwnd,
                "UInt")
            if !dpi
                dpi := 96
            return Round(pixelWidth * 96 / dpi)
        } finally {
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", hdc,
                    "Ptr", previousFont)
            DllCall("user32\ReleaseDC", "Ptr", control.Hwnd, "Ptr", hdc)
        }
    }

    Hide(*) {
        try SetTimer(this.VisibilityTimer, 0)
        try OnMessage(Win32.WM_LBUTTONDOWN, this.PointerDownCallback, 0)
        try OnMessage(Win32.WM_RBUTTONDOWN, this.PointerDownCallback, 0)
        try OnMessage(Win32.WM_NCLBUTTONDOWN, this.PointerDownCallback, 0)
        popupHwnd := this.GetGuiHwnd()
        if popupHwnd {
            try UnregisterGuiControls(popupHwnd)
            try this.Gui.Destroy()
        }
        this.Gui := ""
        return true
    }

    Dispose(*) {
        if this.Disposed
            return
        this.Disposed := true
        this.Hide()
        this.VisibilityTimer := ""
        this.PointerDownCallback := ""
        this.OwnerGui := ""
    }

    InvokeAction(action, *) {
        this.Hide()
        action.Call()
    }

    InvokeColorAction(action, colorKey, *) {
        this.Hide()
        action.Call(colorKey)
    }

    OnPointerDown(wParam, lParam, msg, hwnd) {
        if !this.IsVisible() || !hwnd
            return
        popupHwnd := this.GetGuiHwnd()
        if !popupHwnd
            return
        rootHwnd := DllCall("user32\GetAncestor", "Ptr", hwnd,
            "UInt", 2, "Ptr") ; 取根窗口句柄（GA_ROOT）
        if rootHwnd != popupHwnd
            this.Hide()
    }

    MonitorVisibility(*) {
        popupHwnd := this.GetGuiHwnd()
        if this.Disposed || !popupHwnd
                || !DllCall("user32\IsWindowVisible", "Ptr", popupHwnd,
                    "Int") {
            SetTimer(this.VisibilityTimer, 0)
            return
        }
        foregroundHwnd := DllCall("user32\GetForegroundWindow", "Ptr")
        if foregroundHwnd != this.OwnerGui.Hwnd
                && foregroundHwnd != popupHwnd
            this.Hide()
    }

    IsVisible() {
        popupHwnd := this.GetGuiHwnd()
        return !this.Disposed && popupHwnd
            && DllCall("user32\IsWindowVisible", "Ptr", popupHwnd,
                "Int") != 0
    }

    GetGuiHwnd() {
        if !IsObject(this.Gui)
            return 0
        try return this.Gui.Hwnd
        catch
            return 0
    }

    ConstrainToWorkArea(&x, &y, width, height) {
        monitorCount := MonitorGetCount()
        target := 0
        Loop monitorCount {
            MonitorGetWorkArea(A_Index, &left, &top, &right, &bottom)
            if x >= left && x < right && y >= top && y < bottom {
                target := A_Index
                break
            }
        }
        if !target
            target := MonitorGetPrimary()
        MonitorGetWorkArea(target, &left, &top, &right, &bottom)
        x := Min(Max(x, left + 4), Max(left + 4, right - width - 4))
        y := Min(Max(y, top + 4), Max(top + 4, bottom - height - 4))
    }

    ApplyRoundedRegion() {
        if !IsObject(this.Gui) || !this.Gui.Hwnd
            return false
        windowRect := Buffer(16, 0)
        if !DllCall("user32\GetWindowRect", "Ptr", this.Gui.Hwnd,
                "Ptr", windowRect, "Int")
            return false
        width := NumGet(windowRect, 8, "Int")
            - NumGet(windowRect, 0, "Int")
        height := NumGet(windowRect, 12, "Int")
            - NumGet(windowRect, 4, "Int")
        windowDpi := DllCall("user32\GetDpiForWindow", "Ptr",
            this.Gui.Hwnd, "UInt")
        if !windowDpi
            windowDpi := 96
        radius := Max(4, Round(MainContextPopupWindow.WindowRadiusDip
            * windowDpi / 96))
        region := DllCall("gdi32\CreateRoundRectRgn",
            "Int", 0, "Int", 0, "Int", width + 1, "Int", height + 1,
            "Int", radius * 2, "Int", radius * 2, "Ptr")
        if !region
            return false
        if !DllCall("user32\SetWindowRgn", "Ptr", this.Gui.Hwnd,
                "Ptr", region, "Int", true, "Int") {
            DllCall("gdi32\DeleteObject", "Ptr", region)
            return false
        }
        if VerCompare(A_OSVersion, "10.0.22000") >= 0
            try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr",
                this.Gui.Hwnd, "Int", 33, "Int*", 2, "Int", 4)
        return true
    }
}
