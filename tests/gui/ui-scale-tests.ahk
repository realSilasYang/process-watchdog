#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证用户缩放在真实窗口中同时影响客户区控件和字体，而不是只放大外框。
#Include ..\..\src\Platform\Win32.ahk

AssertUiScale(value, message) {
    if !value
        throw Error(message)
}

GetUiScaleFontHeight(hWnd) {
    fontHandle := SendMessage(Win32.WM_GETFONT, 0, 0, hWnd)
    if !fontHandle
        return 0
    logFont := Buffer(92, 0)
    if !DllCall("gdi32\GetObjectW", "Ptr", fontHandle, "Int", 92,
            "Ptr", logFont)
        return 0
    return NumGet(logFont, 0, "Int")
}

GetUiScaleControlBounds(hWnd) {
    rect := Buffer(16, 0)
    if !DllCall("user32\GetWindowRect", "Ptr", hWnd, "Ptr", rect, "Int")
        throw Error("无法读取缩放控件的窗口矩形")
    return {
        Left: NumGet(rect, 0, "Int"),
        Top: NumGet(rect, 4, "Int"),
        Width: NumGet(rect, 8, "Int") - NumGet(rect, 0, "Int"),
        Height: NumGet(rect, 12, "Int") - NumGet(rect, 4, "Int")
    }
}

GetUiScaleClientOrigin(hWnd) {
    point := Buffer(8, 0)
    if !DllCall("user32\ClientToScreen", "Ptr", hWnd, "Ptr", point, "Int")
        throw Error("无法读取缩放窗口的客户区原点")
    return {X: NumGet(point, 0, "Int"), Y: NumGet(point, 4, "Int")}
}

RunUiScaleTests() {
    testGui := ""
    try {
        UiScaleService.Configure(100)
        testGui := Gui("+ToolWindow", "UI scale test")
        testGui.SetFont("s10", "Segoe UI")
        control := testGui.Add("Text", "x20 y30 w80 h30 0x200", "Scale")
        testGui.Show("w300 h200")
        baseFontHeight := GetUiScaleFontHeight(control.Hwnd)
        baseBounds := GetUiScaleControlBounds(control.Hwnd)
        baseOrigin := GetUiScaleClientOrigin(testGui.Hwnd)

        UiScaleService.Configure(150)
        AssertUiScale(UiScaleService.ScaleShowOptions("x3 y4 w80 h30")
                == "x3 y4 w120 h45",
            "界面缩放没有正确转换窗口展示尺寸")
        AssertUiScale(UiScaleService.Unscale(120) == 80,
            "界面缩放没有正确还原保存尺寸")
        AssertUiScale(UiScaleService.ApplyWindow(testGui),
            "界面缩放没有应用到真实窗口")
        scaledBounds := GetUiScaleControlBounds(control.Hwnd)
        scaledOrigin := GetUiScaleClientOrigin(testGui.Hwnd)
        scaledFontHeight := GetUiScaleFontHeight(control.Hwnd)
        testGui.Show(UiScaleService.ScaleShowOptions("w638 h555"))
        testGui.GetClientPos(,, &scaledClientWidth, &scaledClientHeight)
        AssertUiScale(UiScaleService.Unscale(scaledClientWidth) == 638
                && UiScaleService.Unscale(scaledClientHeight) == 555,
            "界面缩放后的窗口尺寸无法还原为保存尺寸: "
                scaledClientWidth "x" scaledClientHeight)
        AssertUiScale(scaledBounds.Width == Round(baseBounds.Width * 1.5)
            && scaledBounds.Height == Round(baseBounds.Height * 1.5)
            && scaledBounds.Left - scaledOrigin.X == Round(
                (baseBounds.Left - baseOrigin.X) * 1.5)
            && scaledBounds.Top - scaledOrigin.Y == Round(
                (baseBounds.Top - baseOrigin.Y) * 1.5),
            "UI scale geometry mismatch: base="
                baseBounds.Left "," baseBounds.Top "," baseBounds.Width
                "," baseBounds.Height " origin=" baseOrigin.X ","
                baseOrigin.Y " scaled=" scaledBounds.Left ","
                scaledBounds.Top "," scaledBounds.Width ","
                scaledBounds.Height " origin=" scaledOrigin.X ","
                scaledOrigin.Y)
        AssertUiScale(Abs(scaledFontHeight) >= Round(Abs(baseFontHeight) * 1.4),
            "UI scale font mismatch: base=" baseFontHeight
                " scaled=" scaledFontHeight)
    } finally {
        UiScaleService.Configure(100)
        if IsObject(testGui) {
            try UiScaleService.ReleaseWindow(testGui.Hwnd)
            try testGui.Destroy()
        }
    }
}

try {
    RunUiScaleTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message Chr(10) testError.Stack, "**")
    ExitApp(1)
}
