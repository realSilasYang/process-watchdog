; 用户可选的界面缩放。Windows DPI 仍由系统负责，这里只对应用自己的
; 96-DPI 逻辑布局做二次缩放，避免改变进程识别和图标 DPI 资源语义。
class UiScaleService {
    static Requested := 100
    static Factor := 1.0
    static Choices := [80, 90, 100, 110, 125, 150, 175, 200]
    static FontHandles := Map()
    static AppliedWindows := Map()
    static ScaledControls := Map()

    static Configure(value := 100) {
        normalized := this.Normalize(value, 100)
        this.Requested := normalized
        this.Factor := normalized / 100
        return normalized
    }

    static ReadConfiguredScale(configPath) {
        configured := 100
        try configured := IniRead(configPath, "Settings", "UiScale", 100)
        return this.Normalize(configured, 100)
    }

    static Normalize(value, fallback := 100) {
        try parsed := Integer(value)
        catch
            return fallback
        for choice in this.Choices {
            if parsed == choice
                return choice
        }
        return fallback
    }

    static GetRequested() {
        return this.Requested
    }

    static GetFactor() {
        return this.Factor
    }

    static GetChoices() {
        result := []
        for choice in this.Choices
            result.Push(choice)
        return result
    }

    static Scale(value) {
        return Round(Number(value) * this.Factor)
    }

    static ScaleShowOptions(options) {
        if this.Factor == 1
            return options
        text := Trim(String(options))
        text := this.ReplaceDimensionOption(text, "w")
        text := this.ReplaceDimensionOption(text, "h")
        return text
    }

    static ReplaceDimensionOption(text, optionName) {
        pattern := "i)(?<![A-Za-z])" optionName "(\d+)"
        result := ""
        searchPosition := 1
        while RegExMatch(text, pattern, &match, searchPosition) {
            result .= SubStr(text, searchPosition,
                match.Pos[0] - searchPosition) . optionName
                . this.Scale(match[1])
            searchPosition := match.Pos[0] + match.Len[0]
        }
        return result SubStr(text, searchPosition)
    }

    ; AHK 的 GUI 坐标是逻辑坐标，应用自己的缩放必须在窗口映射后对所有
    ; 子控件做一次统一变换。基准字体由控件自身提供，不依赖具体窗口类型。
    static ApplyWindow(guiObj) {
        if this.Factor == 1 || !IsObject(guiObj)
            return false
        try {
            if IsSet(Main) && IsObject(Main) && Main.HasOwnProp("gui")
                && Main.gui == guiObj
                return false
        }
        try parentHwnd := guiObj.Hwnd
        catch
            return false
        if !parentHwnd || !DllCall("user32\IsWindow", "Ptr", parentHwnd, "Int")
            return false
        try controls := WinGetControlsHwnd("ahk_id " parentHwnd)
        catch
            return false
        origin := Buffer(8, 0)
        if !DllCall("user32\ClientToScreen", "Ptr", parentHwnd,
                "Ptr", origin, "Int")
            return false
        originX := NumGet(origin, 0, "Int")
        originY := NumGet(origin, 4, "Int")
        for childHwnd in controls {
            if this.ScaledControls.Has(childHwnd)
                continue
            rect := Buffer(16, 0)
            if !DllCall("user32\GetWindowRect", "Ptr", childHwnd,
                    "Ptr", rect, "Int")
                continue
            x := this.Scale(NumGet(rect, 0, "Int") - originX)
            y := this.Scale(NumGet(rect, 4, "Int") - originY)
            width := this.Scale(NumGet(rect, 8, "Int")
                - NumGet(rect, 0, "Int"))
            height := this.Scale(NumGet(rect, 12, "Int")
                - NumGet(rect, 4, "Int"))
            DllCall("user32\SetWindowPos", "Ptr", childHwnd, "Ptr", 0,
                "Int", x, "Int", y, "Int", width, "Int", height,
                "UInt", 0x0014, "Int")
            this.ScaleControlFont(childHwnd)
            this.ScaledControls[childHwnd] := true
        }
        DllCall("user32\RedrawWindow", "Ptr", parentHwnd, "Ptr", 0,
            "Ptr", 0, "UInt", 0x0185, "Int")
        this.AppliedWindows[parentHwnd] := true
        return true
    }

    static ScaleControlFont(hWnd) {
        oldHandle := this.FontHandles.Has(hWnd) ? this.FontHandles[hWnd] : 0
        fontHandle := SendMessage(0x0031, 0, 0, hWnd)
        if !fontHandle
            return false
        logFont := Buffer(92, 0)
        if !DllCall("gdi32\GetObjectW", "Ptr", fontHandle, "Int", 92,
                "Ptr", logFont)
            return false
        height := NumGet(logFont, 0, "Int")
        width := NumGet(logFont, 4, "Int")
        NumPut("Int", height < 0 ? -this.Scale(-height) : this.Scale(height),
            logFont, 0)
        NumPut("Int", width ? this.Scale(width) : 0, logFont, 4)
        scaledFont := DllCall("gdi32\CreateFontIndirectW", "Ptr", logFont,
            "Ptr")
        if !scaledFont
            return false
        DllCall("user32\SendMessageW", "Ptr", hWnd, "UInt", 0x0030,
            "Ptr", scaledFont, "Ptr", true, "Ptr") ; WM_SETFONT：通知控件刷新字体。
        this.FontHandles[hWnd] := scaledFont
        if oldHandle && oldHandle != scaledFont
            try DllCall("gdi32\DeleteObject", "Ptr", oldHandle)
        return true
    }

    static RescaleWindowFonts(guiObj) {
        if !IsObject(guiObj) || this.Factor == 1
            return false
        try controls := WinGetControlsHwnd("ahk_id " guiObj.Hwnd)
        catch
            return false
        for childHwnd in controls
            this.ScaleControlFont(childHwnd)
        return true
    }

    static ForgetWindowControls(guiObj) {
        if !IsObject(guiObj)
            return false
        try controls := WinGetControlsHwnd("ahk_id " guiObj.Hwnd)
        catch
            return false
        for childHwnd in controls
            if this.ScaledControls.Has(childHwnd)
                this.ScaledControls.Delete(childHwnd)
        return true
    }

    static ReleaseWindow(hWnd) {
        if this.AppliedWindows.Has(hWnd)
            this.AppliedWindows.Delete(hWnd)
        handles := []
        for childHwnd, fontHandle in this.FontHandles {
            rootHwnd := DllCall("user32\GetAncestor", "Ptr", childHwnd,
                "UInt", 2, "Ptr")
            if childHwnd == hWnd || rootHwnd == hWnd
                handles.Push({Hwnd: childHwnd, Font: fontHandle})
        }
        for entry in handles {
            this.FontHandles.Delete(entry.Hwnd)
            if this.ScaledControls.Has(entry.Hwnd)
                this.ScaledControls.Delete(entry.Hwnd)
            try DllCall("gdi32\DeleteObject", "Ptr", entry.Font)
        }
    }
}

ScaleApplicationShowOptions(options) {
    return UiScaleService.ScaleShowOptions(options)
}

ApplyApplicationWindowScale(guiObj) {
    return UiScaleService.ApplyWindow(guiObj)
}

ReleaseApplicationWindowScale(hWnd) {
    return UiScaleService.ReleaseWindow(hWnd)
}

ForgetApplicationWindowControls(guiObj) {
    return UiScaleService.ForgetWindowControls(guiObj)
}
