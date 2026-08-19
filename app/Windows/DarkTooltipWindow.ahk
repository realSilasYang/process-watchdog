; 主题悬浮提示窗口。
; 根据文本测量结果和当前显示器工作区动态定位，既不抢夺键盘焦点，也不越出屏幕；
; 字体和窗口句柄只在窗口存活期间使用，销毁后必须清空以免命中旧对象。

class DarkTooltipWindow extends ManagedWindow {
    __New() {
        this.hoverTimer := 0
        this.lastHwnd := 0
        this.lastRow := 0
        this.textControl := ""
        this.appearanceKey := ""
    }

    GetPresentationConfig() {
        if UiThemeService.IsDark() {
            return {
                Key: "dark",
                Background: UiThemeService.Color("Tooltip"),
                Text: UiThemeService.Color("TooltipText"),
                FontSize: 10,
                PaddingX: 12,
                PaddingY: 8,
                MaxTextWidth: 440,
                DelayMs: 500,
                OffsetX: 10,
                OffsetY: 20,
                ExtendedStyle: ""
            }
        }
        return {
            Key: "light",
            Background: UiThemeService.Color("HoverPreview"),
            Text: UiThemeService.Color("HoverPreviewText"),
            FontSize: 10,
            PaddingX: 12,
            PaddingY: 8,
            MaxTextWidth: 420,
            DelayMs: 350,
            OffsetX: 12,
            OffsetY: 20,
            ; WS_EX_NOACTIVATE | WS_EX_TRANSPARENT：不抢焦点，命中测试穿透。
            ExtendedStyle: " +E0x08000020"
        }
    }

    HandleMouseMove(wParam, lParam, msg, hwnd) {
        if (hwnd == this.lastHwnd) {
            if (hwnd != Main.lv.Hwnd)
                return
            probe := Buffer(24, 0)
            NumPut("Int", SignedWord(lParam), probe, 0)
            NumPut("Int", SignedWord(lParam >> 16), probe, 4)
            probeRow := SendMessage(Win32.LVM_HITTEST, 0, probe.Ptr, Main.lv.Hwnd)
            probeRow := probeRow >= 0 ? probeRow + 1 : 0
            if (probeRow == this.lastRow)
                return
        }
        this.lastHwnd := hwnd
        this.lastRow := 0
        this.CancelTimer()
        this.Hide(false)

        try {
            control := GuiCtrlFromHwnd(hwnd)
            if !control
                return
            text := ""
            ; 普通窗口可把提示直接附着在共享按钮状态上；显式文本优先于
            ; 主窗口的固定说明，也使 URL 提示天然复用当前主题的提示窗口。
            if App.uiInteractions.HasButton(hwnd) {
                buttonState := App.uiInteractions.GetButton(hwnd)
                if buttonState.HasOwnProp("tooltipText")
                    text := buttonState.tooltipText
            }
            if text == "" && IsSet(Main) {
                if (control == Main.lv) {
                    hitTestInfo := Buffer(24, 0)
                    point := Buffer(8)
                    DllCall("user32\GetCursorPos", "Ptr", point)
                    DllCall("user32\ScreenToClient", "Ptr", Main.lv.Hwnd,
                        "Ptr", point)
                    NumPut("Int", NumGet(point, 0, "Int"), hitTestInfo, 0)
                    NumPut("Int", NumGet(point, 4, "Int"), hitTestInfo, 4)
                    result := SendMessage(Win32.LVM_HITTEST, 0,
                        hitTestInfo.Ptr, Main.lv.Hwnd)
                    if (result != -1) {
                        this.lastRow := result + 1
                        path := Main.lv.GetText(result + 1, 3)
                        if App.appStates.Has(path)
                            text := this.BuildEnvironmentText(
                                App.appStates[path])
                    }
                } else if (control == Main.btnAdd) {
                    text := Tr("添加程序、脚本或快捷方式`n支持搜索、文件夹批量导入和文件拖放")
                        . "`nCtrl+N"
                } else if (control == Main.btnDel) {
                    text := Tr("删除选中的守护对象（支持多选，可撤销）`n快捷键：Delete")
                } else if (control == Main.btnPause) {
                    text := Tr("暂停或恢复选中守护对象，不会退出目标`n支持多选；混合状态时逐项反转`n快捷键：Space")
                } else if (control == Main.btnSet) {
                    text := Tr("配置显示、启动、监控、停止策略与日志")
                } else if (control == Main.btnSupport) {
                    text := Tr("打开帮助`n可选择查看使用说明、运行日志或提交反馈")
                } else if (control == Main.btnAbout) {
                    text := Tr("查看版本、运行环境和项目入口")
                }
            }
            if (text != "")
                this.Schedule(text)
        }
    }

    Schedule(text) {
        text := RTrim(NormalizeUserVisibleParentheses(text), "`r`n")
        if text == ""
            return false
        this.CancelTimer()
        this.Hide(false)
        this.hoverTimer := ObjBindMethod(this, "Show", text)
        SetTimer(this.hoverTimer, -this.GetPresentationConfig().DelayMs)
        return true
    }

    BuildEnvironmentText(state) {
        hasEnvironment := (state.HasOwnProp("WorkDir") && state.WorkDir != "")
            || (state.HasOwnProp("Args") && state.Args != "")
            || (state.HasOwnProp("EnvVars") && state.EnvVars != "")
        if !hasEnvironment
            return ""
        text := Tr("独立环境配置 💡`n")
        if (state.HasOwnProp("WorkDir") && state.WorkDir != "")
            text .= Tr("📁 工作目录：{1}`n", state.WorkDir)
        if (state.HasOwnProp("Args") && state.Args != "")
            text .= Tr("⚙️ 启动参数：{1}`n", state.Args)
        if (state.HasOwnProp("EnvVars") && state.EnvVars != "") {
            count := 0
            Loop Parse, state.EnvVars, "`n", "`r" {
                if Trim(A_LoopField) != ""
                    count++
            }
            text .= Tr("🌿 环境变量：{1} 项`n", count)
        }
        return text
    }

    Show(text, *) {
        ; 调用方按项目逐行拼接提示时容易留下末尾换行。DrawText 会把它视为
        ; 一个额外空行，因此在统一入口裁掉行尾换行，再进行测量和显示。
        text := RTrim(NormalizeUserVisibleParentheses(text), "`r`n")
        this.hoverTimer := 0
        appearance := this.GetPresentationConfig()
        if this.IsOpen() && this.appearanceKey != appearance.Key {
            this.DestroyGui()
            this.textControl := ""
        }
        if !this.IsOpen() {
            this.gui := Gui("-Caption +ToolWindow +AlwaysOnTop +LastFound"
                appearance.ExtendedStyle)
            this.gui.BackColor := appearance.Background
            this.gui.SetFont("norm s" appearance.FontSize " c"
                appearance.Text,
                LocalizationService.GetUiFontName())
            this.gui.MarginX := appearance.PaddingX
            this.gui.MarginY := appearance.PaddingY
            this.textControl := this.gui.Add("Text", "Background"
                appearance.Background " c" appearance.Text, text)
            this.appearanceKey := appearance.Key
            if (VerCompare(A_OSVersion, "10.0.18362") >= 0) {
                try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.gui.Hwnd, "Int", 33, "Int*", 2, "Int", 4)
                try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.gui.Hwnd, "Int", 2, "Int*", 2, "Int", 4)
            }
        } else {
            this.textControl.Text := text
        }
        this.textControl.SetFont("norm s" appearance.FontSize " c"
            appearance.Text, LocalizationService.GetUiFontName())
        ForgetApplicationWindowControls(this.gui)
        this.ResizeTextControl(text, appearance.MaxTextWidth)
        point := Buffer(8)
        DllCall("user32\GetCursorPos", "Ptr", point)
        mouseX := NumGet(point, 0, "Int")
        mouseY := NumGet(point, 4, "Int")
        ShowApplicationWindow(this.gui, "x" (mouseX + appearance.OffsetX)
            " y" (mouseY + appearance.OffsetY) " NoActivate AutoSize")
    }

    ResizeTextControl(text, maxTextWidthDip := 440) {
        deviceContext := DllCall("user32\GetDC", "Ptr", this.textControl.Hwnd, "Ptr")
        if !deviceContext
            return
        fontHandle := SendMessage(0x0031, 0, 0, this.textControl.Hwnd) ; WM_GETFONT：读取控件实际使用的字体。
        previousFont := fontHandle
            ? DllCall("gdi32\SelectObject", "Ptr", deviceContext, "Ptr", fontHandle, "Ptr") : 0
        try {
            dpi := 96
            try dpi := DllCall("user32\GetDpiForWindow", "Ptr", this.gui.Hwnd, "UInt")
            if !dpi
                dpi := 96
            maxWidthPx := Round(maxTextWidthDip * dpi / 96)
            naturalWidthPx := 1
            Loop Parse, text, "`n", "`r" {
                lineText := A_LoopField != "" ? A_LoopField : " "
                extent := Buffer(8, 0)
                if DllCall("gdi32\GetTextExtentPoint32W", "Ptr", deviceContext,
                    "Str", lineText, "Int", StrLen(lineText), "Ptr", extent, "Int")
                    naturalWidthPx := Max(naturalWidthPx, NumGet(extent, 0, "Int"))
            }
            textWidthPx := Min(naturalWidthPx, maxWidthPx)
            measureRect := Buffer(16, 0)
            NumPut("Int", textWidthPx, measureRect, 8)
            DllCall("user32\DrawTextW", "Ptr", deviceContext, "Str", text, "Int", -1,
                "Ptr", measureRect, "UInt", 0x0C50, "Int") ; 只测量排版矩形，并启用自动换行和制表符展开。
            textHeightPx := Max(1, NumGet(measureRect, 12, "Int"))
            this.textControl.Move(,, Max(1, Ceil(textWidthPx * 96 / dpi)),
                Max(1, Ceil(textHeightPx * 96 / dpi)))
        } finally {
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", deviceContext, "Ptr", previousFont, "Ptr")
            DllCall("user32\ReleaseDC", "Ptr", this.textControl.Hwnd, "Ptr", deviceContext)
        }
    }

    CancelTimer() {
        if this.hoverTimer {
            SetTimer(this.hoverTimer, 0)
            this.hoverTimer := 0
        }
    }

    Hide(resetTracking := true, *) {
        this.CancelTimer()
        if this.IsOpen()
            try this.gui.Hide()
        if resetTracking {
            this.lastHwnd := 0
            this.lastRow := 0
        }
    }

    Close(*) {
        this.Hide()
        this.DestroyGui()
        this.textControl := ""
        this.appearanceKey := ""
    }
}
