#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

; 在独立进程中验证历史操作气泡的定位、焦点、动画、圆角和重复显示计时，
; 使较长的计时场景拥有独立超时、阶段输出和资源清理边界。

class UiThemeService {
    static Color(name) {
        colors := Map(
            "Window", "1E1E1E", "Tooltip", "202020",
            "TooltipText", "F2F2F2")
        return colors[name]
    }
}

class LocalizationService {
    static GetLanguageSystemUiFontName() {
        return "Microsoft YaHei UI"
    }
}

NormalizeUserVisibleParentheses(text) {
    return text
}

#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\app\Windows\HistoryToastWindow.ahk

AssertHistoryToast(condition, message) {
    if !condition
        throw Error(message)
}

ReportHistoryToastStage(name) {
    FileAppend("HISTORY_TOAST|STAGE|" name "`n", "*")
}

RunHistoryToastTests() {
    owner := ""
    historyToast := ""
    try {
        owner := Gui("+Resize +MinSize420x260", "History toast test owner")
        owner.BackColor := UiThemeService.Color("Window")
        owner.SetFont("s10 cF2F2F2", "Microsoft YaHei UI")
        ownerEdit := owner.Add("Edit",
            "x16 y42 w260 h28 Background252526 cF2F2F2", "editable")
        statusBar := owner.Add("Text",
            "x10 y250 w410 h20 Background1E1E1E cA8AAA9", "status")
        owner.Show("w430 h270")
        dpi := DllCall("user32\GetDpiForWindow", "Ptr", owner.Hwnd,
            "UInt")
        if !dpi
            dpi := 96

        global Main := {gui: owner, statsText: statusBar}
        DllCall("user32\SetFocus", "Ptr", ownerEdit.Hwnd, "Ptr")
        focusBeforeToast := DllCall("user32\GetFocus", "Ptr")
        AssertHistoryToast(focusBeforeToast == ownerEdit.Hwnd,
            "气泡测试输入框无法取得焦点")

        ReportHistoryToastStage("show")
        historyToast := HistoryToastWindow()
        AssertHistoryToast(historyToast.Show(
            "已撤销：添加守护对象：Smoke target"), "历史气泡无法显示")
        AssertHistoryToast(historyToast.animationPhase == "show",
            "历史气泡没有开始进入动画")
        initialToastRect := Buffer(16, 0)
        statusBarRect := Buffer(16, 0)
        AssertHistoryToast(DllCall("user32\GetWindowRect", "Ptr",
                historyToast.gui.Hwnd, "Ptr", initialToastRect, "Int")
            && DllCall("user32\GetWindowRect", "Ptr", statusBar.Hwnd,
                "Ptr", statusBarRect, "Int"), "无法读取气泡进入动画边界")
        expectedToastGap := Max(1, Round(3 * dpi / 96))
        AssertHistoryToast(NumGet(initialToastRect, 12, "Int")
                <= NumGet(statusBarRect, 4, "Int") - expectedToastGap,
            "气泡进入动画覆盖了状态栏")
        Sleep(220)
        AssertHistoryToast(DllCall("user32\IsWindowVisible", "Ptr",
                historyToast.gui.Hwnd, "Int"), "历史气泡不可见")
        AssertHistoryToast(historyToast.animationPhase == "idle"
            && historyToast.currentAlpha == 255,
            "历史气泡没有以完全不透明状态结束进入动画")
        AssertHistoryToast(DllCall("user32\GetFocus", "Ptr")
                == focusBeforeToast, "历史气泡抢走了键盘焦点")
        AssertHistoryToast(historyToast.textControl.Text
                == "已撤销：添加守护对象：Smoke target",
            "历史气泡没有保留具体操作文字")

        ReportHistoryToastStage("layout")
        toastWindowRect := Buffer(16, 0)
        toastTextRect := Buffer(16, 0)
        DllCall("user32\GetWindowRect", "Ptr", historyToast.gui.Hwnd,
            "Ptr", toastWindowRect)
        DllCall("user32\GetWindowRect", "Ptr",
            historyToast.textControl.Hwnd, "Ptr", toastTextRect)
        DllCall("user32\GetWindowRect", "Ptr", statusBar.Hwnd,
            "Ptr", statusBarRect)
        AssertHistoryToast(NumGet(toastWindowRect, 0, "Int")
                == NumGet(statusBarRect, 0, "Int")
            && NumGet(statusBarRect, 4, "Int")
                - NumGet(toastWindowRect, 12, "Int") == expectedToastGap,
            "历史气泡没有紧贴状态栏上方并左对齐")
        toastTextStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
            historyToast.textControl.Hwnd, "Int", -16, "Ptr")
        AssertHistoryToast((toastTextStyle & 0x0003) == 0,
            "历史气泡文字没有明确左对齐")
        toastTextWidth := NumGet(toastTextRect, 8, "Int")
            - NumGet(toastTextRect, 0, "Int")
        AssertHistoryToast(toastTextWidth > Round(120 * dpi / 96)
            && NumGet(toastTextRect, 8, "Int")
                < NumGet(toastWindowRect, 8, "Int"),
            "历史气泡文字宽度无效或超出气泡")
        regionProbe := DllCall("gdi32\CreateRectRgn", "Int", 0, "Int", 0,
            "Int", 1, "Int", 1, "Ptr")
        try AssertHistoryToast(DllCall("user32\GetWindowRgn", "Ptr",
                historyToast.gui.Hwnd, "Ptr", regionProbe, "Int") > 0,
            "历史气泡没有圆角窗口区域")
        finally DllCall("gdi32\DeleteObject", "Ptr", regionProbe)

        ReportHistoryToastStage("hide")
        historyToast.Hide()
        AssertHistoryToast(historyToast.animationPhase == "hide",
            "历史气泡没有开始退出动画")
        Sleep(50)
        DllCall("user32\GetWindowRect", "Ptr", historyToast.gui.Hwnd,
            "Ptr", toastWindowRect)
        AssertHistoryToast(DllCall("user32\IsWindowVisible", "Ptr",
                historyToast.gui.Hwnd, "Int")
            && historyToast.currentAlpha < 255,
            "历史气泡退出动画没有可见过渡")
        AssertHistoryToast(NumGet(toastWindowRect, 12, "Int")
                <= NumGet(statusBarRect, 4, "Int") - expectedToastGap,
            "历史气泡退出动画覆盖了状态栏")
        Sleep(150)
        AssertHistoryToast(!DllCall("user32\IsWindowVisible", "Ptr",
                historyToast.gui.Hwnd, "Int"), "历史气泡退出动画没有隐藏窗口")

        ReportHistoryToastStage("repeat")
        historyToast.Show("已撤销：添加守护对象：Smoke target")
        Sleep(1920)
        historyToast.Show("已重做：暂停：Smoke target")
        Sleep(1820)
        AssertHistoryToast(DllCall("user32\IsWindowVisible", "Ptr",
                historyToast.gui.Hwnd, "Int"),
            "重复显示历史气泡没有重置三秒计时")
        Sleep(1700)
        AssertHistoryToast(!DllCall("user32\IsWindowVisible", "Ptr",
                historyToast.gui.Hwnd, "Int"), "历史气泡超过三秒后仍然可见")
        ReportHistoryToastStage("complete")
    } finally {
        if historyToast
            try historyToast.Close()
        if owner
            try owner.Destroy()
    }
}

try {
    RunHistoryToastTests()
    FileAppend("HISTORY_TOAST|PASS`n", "*")
    ExitApp(0)
} catch as testError {
    FileAppend(testError.File " (" testError.Line "): " testError.Message
        "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
