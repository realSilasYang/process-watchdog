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
    static SeparatorHeight := 8
    static WindowRadiusDip := 9
    static RowRadiusDip := 6

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
        for item in items {
            if item.HasOwnProp("Separator") && item.Separator {
                this.Gui.Add("Text", "x" MainContextPopupWindow.Padding
                    " y" (y + MainContextPopupWindow.SeparatorHeight // 2)
                    " w" contentWidth " h1 Background"
                    UiThemeService.Color("Divider"), "")
                y += MainContextPopupWindow.SeparatorHeight
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
                    if item.HasOwnProp("Separator") && item.Separator
                        continue
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

    Hide(*) {
        try SetTimer(this.VisibilityTimer, 0)
        try OnMessage(Win32.WM_LBUTTONDOWN, this.PointerDownCallback, 0)
        try OnMessage(Win32.WM_RBUTTONDOWN, this.PointerDownCallback, 0)
        try OnMessage(Win32.WM_NCLBUTTONDOWN, this.PointerDownCallback, 0)
        if IsObject(this.Gui) && this.Gui.Hwnd {
            try UnregisterGuiControls(this.Gui.Hwnd)
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

    OnPointerDown(wParam, lParam, msg, hwnd) {
        if !this.IsVisible() || !hwnd
            return
        rootHwnd := DllCall("user32\GetAncestor", "Ptr", hwnd,
            "UInt", 2, "Ptr") ; 取根窗口句柄（GA_ROOT）
        if rootHwnd != this.Gui.Hwnd
            this.Hide()
    }

    MonitorVisibility(*) {
        if !this.IsVisible() {
            SetTimer(this.VisibilityTimer, 0)
            return
        }
        foregroundHwnd := DllCall("user32\GetForegroundWindow", "Ptr")
        if foregroundHwnd != this.OwnerGui.Hwnd
                && foregroundHwnd != this.Gui.Hwnd
            this.Hide()
    }

    IsVisible() {
        return !this.Disposed && IsObject(this.Gui) && this.Gui.Hwnd
            && DllCall("user32\IsWindowVisible", "Ptr", this.Gui.Hwnd,
                "Int") != 0
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
