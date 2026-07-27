; 撤销与重做结果气泡。
; 窗口不拥有主窗口、不会激活或改变焦点；文本按实际字体和主窗口
; 可用宽度测量，始终贴在底部状态栏上方，显示时轻微下滑淡入，
; 三秒后向上淡出。

class HistoryToastWindow {
    __New() {
        this.gui := ""
        this.textControl := ""
        this.hideTimer := ObjBindMethod(this, "BeginHide")
        this.animationTimer := ObjBindMethod(this, "AdvanceAnimation")
        this.animationPhase := "idle"
        this.animationStartedTicks := 0
        this.animationDurationMs := 0
        this.animationFromY := 0
        this.animationToY := 0
        this.animationFromAlpha := 255
        this.animationToAlpha := 255
        this.currentY := 0
        this.currentAlpha := 255
        this.currentX := 0
        this.toastWidth := 0
        this.toastHeight := 0
        this.targetY := 0
        this.animationDpi := 96
    }

    IsOpen() {
        if !this.gui
            return false
        try hwnd := this.gui.Hwnd
        catch
            hwnd := 0
        if hwnd && DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
            return true
        this.gui := ""
        this.textControl := ""
        this.CancelTimers()
        return false
    }

    EnsureCreated() {
        if this.IsOpen()
            return true
        ; WS_EX_NOACTIVATE 保持主窗口焦点，WS_EX_LAYERED 只用于整窗口淡入淡出。
        this.gui := Gui("-Caption +ToolWindow +AlwaysOnTop +E0x08080000")
        this.gui.BackColor := UiThemeService.Color("Tooltip")
        this.gui.MarginX := 14
        this.gui.MarginY := 9
        this.gui.SetFont("s9 bold c" UiThemeService.Color("TooltipText"),
            LocalizationService.GetLanguageSystemUiFontName())
        this.textControl := this.gui.Add("Text", "x14 y9 w1 h1 Left Background"
            UiThemeService.Color("Tooltip") " c"
            UiThemeService.Color("TooltipText"), "")
        if (VerCompare(A_OSVersion, "10.0.22000") >= 0)
            try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.gui.Hwnd,
                "Int", 33, "Int*", 2, "Int", 4)
        return true
    }

    Show(text, *) {
        text := RTrim(NormalizeUserVisibleParentheses(text), "`r`n")
        if text == "" || !IsSet(Main) || !Main.gui
            return false
        if !this.EnsureCreated()
            return false

        this.CancelTimers()
        wasVisible := DllCall("user32\IsWindowVisible", "Ptr",
            this.gui.Hwnd, "Int") != 0
        this.textControl.Text := text
        if !this.LayoutText(text, &windowWidthDip, &windowHeightDip)
            return false
        this.gui.Show((wasVisible ? "" : "Hide ")
            "NoActivate w" windowWidthDip " h" windowHeightDip)
        this.ApplyRoundedRegion()
        if !this.GetTargetBounds(&targetX, &targetY, &toastWidth,
                &toastHeight, &windowDpi) {
            this.HideNow()
            return false
        }

        this.targetY := targetY
        this.currentX := targetX
        this.toastWidth := toastWidth
        this.toastHeight := toastHeight
        this.animationDpi := windowDpi
        startOffset := Round((wasVisible ? 4 : 10) * windowDpi / 96)
        ; 动画只在最终位置上方活动，任何一帧都不会压住状态栏。
        startY := targetY - startOffset
        startAlpha := wasVisible ? 176 : 0
        this.SetWindowAlpha(startAlpha)
        if !this.SetWindowBounds(targetX, startY, toastWidth, toastHeight,
                true) {
            this.HideNow()
            return false
        }
        this.BeginAnimation("show", startY, targetY, startAlpha, 255, 160)
        return true
    }

    LayoutText(text, &windowWidthDip, &windowHeightDip) {
        if !this.IsOpen() || !IsSet(Main) || !Main.gui
            return false
        mainRect := Buffer(16, 0)
        if !DllCall("user32\GetClientRect", "Ptr", Main.gui.Hwnd,
                "Ptr", mainRect, "Int")
            return false
        windowDpi := DllCall("user32\GetDpiForWindow", "Ptr", Main.gui.Hwnd,
            "UInt")
        if !windowDpi
            windowDpi := 96
        clientWidthPx := NumGet(mainRect, 8, "Int")
        maximumWindowWidthDip := Min(480,
            Max(120, Floor(clientWidthPx * 96 / windowDpi) - 24))
        maximumTextWidthPx := Max(1,
            Round((maximumWindowWidthDip - 28) * windowDpi / 96))

        deviceContext := DllCall("user32\GetDC", "Ptr",
            this.textControl.Hwnd, "Ptr")
        if !deviceContext
            return false
        fontHandle := SendMessage(Win32.WM_GETFONT, 0, 0,
            this.textControl.Hwnd)
        previousFont := fontHandle
            ? DllCall("gdi32\SelectObject", "Ptr", deviceContext,
                "Ptr", fontHandle, "Ptr") : 0
        try {
            naturalWidthPx := 1
            Loop Parse, text, "`n", "`r" {
                lineText := A_LoopField != "" ? A_LoopField : " "
                extent := Buffer(8, 0)
                if DllCall("gdi32\GetTextExtentPoint32W", "Ptr",
                        deviceContext, "Str", lineText, "Int",
                        StrLen(lineText), "Ptr", extent, "Int")
                    naturalWidthPx := Max(naturalWidthPx,
                        NumGet(extent, 0, "Int"))
            }
            textWidthPx := Min(naturalWidthPx, maximumTextWidthPx)
            measureRect := Buffer(16, 0)
            NumPut("Int", textWidthPx, measureRect, 8)
            ; DT_CALCRECT／DT_WORDBREAK／DT_EXPANDTABS／DT_NOPREFIX：文字测量组合标志。
            ; 按真实字体计算多行高度，不把名称中的 & 误当成快捷键。
            DllCall("user32\DrawTextW", "Ptr", deviceContext, "Str", text,
                "Int", -1, "Ptr", measureRect, "UInt", 0x0C50, "Int")
            textHeightPx := Max(1, NumGet(measureRect, 12, "Int"))
            textWidthDip := Max(1, Ceil(textWidthPx * 96 / windowDpi))
            textHeightDip := Max(1, Ceil(textHeightPx * 96 / windowDpi))
            this.textControl.Move(14, 9, textWidthDip, textHeightDip)
            windowWidthDip := textWidthDip + 28
            windowHeightDip := textHeightDip + 18
            return true
        } finally {
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", deviceContext,
                    "Ptr", previousFont)
            DllCall("user32\ReleaseDC", "Ptr", this.textControl.Hwnd,
                "Ptr", deviceContext)
        }
    }

    GetTargetBounds(&x, &y, &width, &height, &dpi) {
        if !this.IsOpen() || !IsSet(Main) || !Main.gui
            return false
        mainHwnd := Main.gui.Hwnd
        if !DllCall("user32\IsWindowVisible", "Ptr", mainHwnd, "Int")
            || DllCall("user32\IsIconic", "Ptr", mainHwnd, "Int")
            return false
        clientRect := Buffer(16, 0)
        clientOrigin := Buffer(8, 0)
        statusRect := Buffer(16, 0)
        toastRect := Buffer(16, 0)
        if !DllCall("user32\GetClientRect", "Ptr", mainHwnd, "Ptr",
                clientRect, "Int")
            || !DllCall("user32\ClientToScreen", "Ptr", mainHwnd,
                "Ptr", clientOrigin, "Int")
            || !DllCall("user32\GetWindowRect", "Ptr", this.gui.Hwnd,
                "Ptr", toastRect, "Int")
            return false
        dpi := DllCall("user32\GetDpiForWindow", "Ptr", mainHwnd, "UInt")
        if !dpi
            dpi := 96
        width := NumGet(toastRect, 8, "Int") - NumGet(toastRect, 0, "Int")
        height := NumGet(toastRect, 12, "Int") - NumGet(toastRect, 4, "Int")
        gap := Max(1, Round(3 * dpi / 96))

        ; 状态栏是气泡的真实锚点：左边缘完全对齐，底边保留 3 DIP
        ; 间距。直接读取屏幕矩形可避免边框、DPI 和客户区换算误差。
        statusHwnd := 0
        if Main.HasOwnProp("statsText") && IsObject(Main.statsText)
            try statusHwnd := Main.statsText.Hwnd
        if statusHwnd
            && DllCall("user32\IsWindow", "Ptr", statusHwnd, "Int")
            && DllCall("user32\GetWindowRect", "Ptr", statusHwnd,
                "Ptr", statusRect, "Int") {
            x := NumGet(statusRect, 0, "Int")
            y := NumGet(statusRect, 4, "Int") - height - gap
        } else {
            ; 极早启动或测试替身没有状态栏时，按正式布局的 10 DIP
            ; 左边距与 20 DIP 状态栏高度退化定位。
            inset := Round(10 * dpi / 96)
            statusHeight := Round(20 * dpi / 96)
            x := NumGet(clientOrigin, 0, "Int") + inset
            y := NumGet(clientOrigin, 4, "Int")
                + NumGet(clientRect, 12, "Int") - statusHeight
                - height - gap
        }
        return width > 0 && height > 0
    }

    Reposition(*) {
        if !this.IsOpen() || !DllCall("user32\IsWindowVisible", "Ptr",
                this.gui.Hwnd, "Int")
            return false
        hadTarget := this.toastWidth > 0 && this.toastHeight > 0
        previousTargetY := this.targetY
        if !this.GetTargetBounds(&targetX, &targetY, &toastWidth,
                &toastHeight, &windowDpi)
            return false

        this.targetY := targetY
        this.currentX := targetX
        this.toastWidth := toastWidth
        this.toastHeight := toastHeight
        this.animationDpi := windowDpi
        if hadTarget && (this.animationPhase == "show"
                || this.animationPhase == "hide") {
            ; 主窗口移动或缩放时整体平移当前动画轨迹，避免下一帧跳回旧位置。
            deltaY := targetY - previousTargetY
            this.animationFromY += deltaY
            this.animationToY += deltaY
            this.currentY += deltaY
        } else {
            this.currentY := targetY
        }
        return this.SetWindowBounds(targetX, this.currentY, toastWidth,
            toastHeight)
    }

    SetWindowBounds(x, y, width, height, showWindow := false) {
        flags := 0x0010 | (showWindow ? 0x0040 : 0)
        return !!DllCall("user32\SetWindowPos", "Ptr", this.gui.Hwnd,
            "Ptr", -1, "Int", x, "Int", y, "Int", width, "Int", height,
            "UInt", flags, "Int")
    }

    SetWindowPosition(x, y) {
        ; SWP_NOSIZE／SWP_NOACTIVATE：动画帧只移动窗口，不重复触发尺寸布局。
        return !!DllCall("user32\SetWindowPos", "Ptr", this.gui.Hwnd,
            "Ptr", -1, "Int", x, "Int", y, "Int", 0, "Int", 0,
            "UInt", 0x0011, "Int")
    }

    SetWindowAlpha(alpha) {
        if !this.IsOpen()
            return false
        alpha := Max(0, Min(255, Round(alpha)))
        if !DllCall("user32\SetLayeredWindowAttributes", "Ptr",
                this.gui.Hwnd, "UInt", 0, "UChar", alpha, "UInt", 0x2,
                "Int")
            return false
        this.currentAlpha := alpha
        return true
    }

    BeginAnimation(phase, fromY, toY, fromAlpha, toAlpha, durationMs) {
        try SetTimer(this.animationTimer, 0)
        this.animationPhase := phase
        this.animationStartedTicks := DllCall("kernel32\GetTickCount64", "UInt64")
        this.animationDurationMs := Max(1, durationMs)
        this.animationFromY := fromY
        this.animationToY := toY
        this.animationFromAlpha := fromAlpha
        this.animationToAlpha := toAlpha
        this.currentY := fromY
        this.currentAlpha := fromAlpha
        SetTimer(this.animationTimer, 15)
    }

    AdvanceAnimation(*) {
        if this.animationPhase == "idle" || !this.IsOpen() {
            try SetTimer(this.animationTimer, 0)
            return
        }
        elapsed := DllCall("kernel32\GetTickCount64", "UInt64")
            - this.animationStartedTicks
        progress := Min(1, elapsed / this.animationDurationMs)
        ; easeOutCubic：开始反应快、结尾柔和，又不会延长操作反馈。
        easedProgress := 1 - ((1 - progress) ** 3)
        nextY := Round(this.animationFromY
            + (this.animationToY - this.animationFromY) * easedProgress)
        nextAlpha := Round(this.animationFromAlpha
            + (this.animationToAlpha - this.animationFromAlpha)
                * easedProgress)
        this.SetWindowPosition(this.currentX, nextY)
        this.SetWindowAlpha(nextAlpha)
        this.currentY := nextY

        if progress < 1
            return
        try SetTimer(this.animationTimer, 0)
        completedPhase := this.animationPhase
        this.animationPhase := "idle"
        if completedPhase == "show" {
            this.SetWindowAlpha(255)
            this.currentY := this.targetY
            SetTimer(this.hideTimer, -3000)
        } else {
            this.HideNow()
        }
    }

    ApplyRoundedRegion() {
        if !this.IsOpen()
            return false
        windowRect := Buffer(16, 0)
        if !DllCall("user32\GetWindowRect", "Ptr", this.gui.Hwnd,
                "Ptr", windowRect, "Int")
            return false
        width := NumGet(windowRect, 8, "Int") - NumGet(windowRect, 0, "Int")
        height := NumGet(windowRect, 12, "Int") - NumGet(windowRect, 4, "Int")
        windowDpi := DllCall("user32\GetDpiForWindow", "Ptr", this.gui.Hwnd,
            "UInt")
        radius := Max(8, Round(10 * (windowDpi ? windowDpi : 96) / 96))
        cornerDiameter := radius * 2
        region := DllCall("gdi32\CreateRoundRectRgn", "Int", 0, "Int", 0,
            "Int", width + 1, "Int", height + 1, "Int", cornerDiameter,
            "Int", cornerDiameter, "Ptr")
        if !region
            return false
        if DllCall("user32\SetWindowRgn", "Ptr", this.gui.Hwnd, "Ptr",
                region, "Int", true, "Int")
            return true
        DllCall("gdi32\DeleteObject", "Ptr", region)
        return false
    }

    BeginHide(*) {
        try SetTimer(this.hideTimer, 0)
        if !this.IsOpen() || !DllCall("user32\IsWindowVisible", "Ptr",
                this.gui.Hwnd, "Int")
            return
        try SetTimer(this.animationTimer, 0)
        fromY := this.currentY ? this.currentY : this.targetY
        fromAlpha := this.currentAlpha
        hideOffset := Round(8 * this.animationDpi / 96)
        this.BeginAnimation("hide", fromY, this.targetY - hideOffset,
            fromAlpha, 0, 140)
    }

    Hide(*) {
        this.BeginHide()
    }

    HideNow() {
        try SetTimer(this.hideTimer, 0)
        try SetTimer(this.animationTimer, 0)
        this.animationPhase := "idle"
        if this.IsOpen() {
            try this.gui.Hide()
            try this.SetWindowAlpha(255)
        }
        this.currentAlpha := 255
        this.currentY := 0
        this.currentX := 0
        this.toastWidth := 0
        this.toastHeight := 0
    }

    CancelTimers() {
        try SetTimer(this.hideTimer, 0)
        try SetTimer(this.animationTimer, 0)
        this.animationPhase := "idle"
    }

    Close(*) {
        this.CancelTimers()
        if this.IsOpen() {
            guiObj := this.gui
            this.gui := ""
            this.textControl := ""
            try guiObj.Destroy()
        }
    }
}
