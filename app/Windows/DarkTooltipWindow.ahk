class DarkTooltipWindow extends ManagedWindow {
    __New() {
        this.hoverTimer := 0
        this.lastHwnd := 0
        this.lastRow := 0
        this.textControl := ""
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
            if (control == Main.lv) {
                hitTestInfo := Buffer(24, 0)
                point := Buffer(8)
                DllCall("user32\GetCursorPos", "Ptr", point)
                DllCall("user32\ScreenToClient", "Ptr", Main.lv.Hwnd, "Ptr", point)
                NumPut("Int", NumGet(point, 0, "Int"), hitTestInfo, 0)
                NumPut("Int", NumGet(point, 4, "Int"), hitTestInfo, 4)
                result := SendMessage(Win32.LVM_HITTEST, 0, hitTestInfo.Ptr, Main.lv.Hwnd)
                if (result != -1) {
                    this.lastRow := result + 1
                    path := Main.lv.GetText(result + 1, 3)
                    if App.appStates.Has(path)
                        text := this.BuildEnvironmentText(App.appStates[path])
                }
            } else if (control == Main.btnAdd) {
                text := "添加程序、脚本或快捷方式`n支持搜索、文件夹批量导入和文件拖放"
            } else if (control == Main.btnDel) {
                text := "删除选中的守护项目（支持多选，可撤销）`n快捷键：Delete"
            } else if (control == Main.btnPause) {
                text := "暂停或恢复选中项目的守护，不会退出目标`n支持多选；混合状态时逐项反转"
            } else if (control == Main.btnSet) {
                text := "配置系统集成、监控与启动、停止`n以及日志、搜索与导入选项"
            } else if (control == Main.btnLog) {
                text := "查看实时运行日志`n涵盖监控、重启、升级保护与操作记录"
            } else if (control == Main.btnHelp) {
                text := "查看支持类型、操作方法、守护设置`n以及升级保护说明"
            }
            if (text != "") {
                this.hoverTimer := ObjBindMethod(this, "Show", text)
                SetTimer(this.hoverTimer, -500)
            }
        }
    }

    BuildEnvironmentText(state) {
        hasEnvironment := (state.HasOwnProp("WorkDir") && state.WorkDir != "")
            || (state.HasOwnProp("Args") && state.Args != "")
            || (state.HasOwnProp("EnvVars") && state.EnvVars != "")
        if !hasEnvironment
            return ""
        text := "独立环境配置 💡`n"
        if (state.HasOwnProp("WorkDir") && state.WorkDir != "")
            text .= "📁 工作目录: " state.WorkDir "`n"
        if (state.HasOwnProp("Args") && state.Args != "")
            text .= "⚙️ 启动参数: " state.Args "`n"
        if (state.HasOwnProp("EnvVars") && state.EnvVars != "") {
            count := 0
            Loop Parse, state.EnvVars, "`n", "`r" {
                if Trim(A_LoopField) != ""
                    count++
            }
            text .= "🌿 环境变量: " count " 项`n"
        }
        return text
    }

    Show(text, *) {
        text := NormalizeUserVisibleParentheses(text)
        this.hoverTimer := 0
        if !this.IsOpen() {
            this.gui := Gui("-Caption +ToolWindow +AlwaysOnTop +LastFound")
            this.gui.BackColor := "202020"
            this.gui.SetFont("s9 cE5E5E5", "Microsoft YaHei")
            this.gui.MarginX := 12
            this.gui.MarginY := 8
            this.textControl := this.gui.Add("Text", "Background202020", text)
            if (VerCompare(A_OSVersion, "10.0.18362") >= 0) {
                try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.gui.Hwnd, "Int", 33, "Int*", 2, "Int", 4)
                try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.gui.Hwnd, "Int", 2, "Int*", 2, "Int", 4)
            }
        } else {
            this.textControl.Text := text
        }
        this.ResizeTextControl(text)
        point := Buffer(8)
        DllCall("user32\GetCursorPos", "Ptr", point)
        mouseX := NumGet(point, 0, "Int")
        mouseY := NumGet(point, 4, "Int")
        this.gui.Show("x" (mouseX + 10) " y" (mouseY + 20) " NoActivate AutoSize")
    }

    ResizeTextControl(text) {
        deviceContext := DllCall("user32\GetDC", "Ptr", this.textControl.Hwnd, "Ptr")
        if !deviceContext
            return
        fontHandle := SendMessage(0x0031, 0, 0, this.textControl.Hwnd) ; WM_GETFONT
        previousFont := fontHandle
            ? DllCall("gdi32\SelectObject", "Ptr", deviceContext, "Ptr", fontHandle, "Ptr") : 0
        try {
            dpi := 96
            try dpi := DllCall("user32\GetDpiForWindow", "Ptr", this.gui.Hwnd, "UInt")
            if !dpi
                dpi := 96
            maxWidthPx := Round(440 * dpi / 96)
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
                "Ptr", measureRect, "UInt", 0x0C50, "Int") ; CALCRECT | NOPREFIX | WORDBREAK | EXPANDTABS
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
    }
}
