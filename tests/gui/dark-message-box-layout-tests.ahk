#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

; 创建真实公共消息框并读取原生控件矩形，验证长正文、图标和按钮的共享布局边界。

try {
    if A_Args.Length == 2 && A_Args[1] == "--dialog-child" {
        RunDarkMessageBoxChild(A_Args[2])
        ExitApp(0)
    }
    RunDarkMessageBoxLayoutTests()
    FileAppend("DARK_MESSAGE_BOX_LAYOUT|PASS`n", "*")
    ExitApp(0)
} catch as testError {
    FileAppend(testError.File " (" testError.Line "): " testError.Message
        "`n" testError.Stack "`n", "**")
    ExitApp(1)
}

class UiThemeService {
    static Color(name) {
        colors := Map(
            "Window", "1E1E1E", "Text", "F2F2F2",
            "Primary", "0E639C", "ButtonText", "FFFFFF",
            "Toolbar", "333333", "ToolbarText", "F2F2F2",
            "WarningIcon", "FBBF24")
        return colors[name]
    }
}

class LocalizationService {
    static GetUiFontName() {
        return "Microsoft YaHei UI"
    }
}

class WindowHierarchy {
    static Acquire(*) {
        return ""
    }

    static Release(*) {
        return ""
    }

    static CompleteClose(*) {
    }
}

class ButtonFeedbackMode {
    static Dismissive := 0
}

Tr(text, values*) {
    return values.Length ? Format(text, values*) : text
}

NormalizeUserVisibleParentheses(text) {
    return text
}

InitializeApplicationWindow(guiObj) {
    guiObj.BackColor := UiThemeService.Color("Window")
}

RestoreHoveredButton(*) {
}

RegisterHoverButton(*) {
}

RegisterButtonClick(control, callback, *) {
    control.OnEvent("Click", callback)
}

RedrawRoundedButton(*) {
}

RenderRoundedButtonNow(*) {
    return false
}

MovePointerToControlCenter(control) {
    try hWnd := control.Hwnd
    catch
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

UnregisterGuiControls(*) {
}

ScaleApplicationShowOptions(options) {
    return options
}

ApplyApplicationWindowScale(*) {
    return false
}

ReleaseApplicationWindowScale(*) {
    return false
}

#Include ..\..\app\UI\DarkMessageBox.ahk

AssertDarkMessageBox(condition, message) {
    if !condition
        throw Error(message)
}

GetDarkMessageControlRect(controlHwnd, dialogHwnd) {
    rect := Buffer(16, 0)
    if !DllCall("user32\GetWindowRect", "Ptr", controlHwnd, "Ptr", rect,
            "Int")
        return ""
    DllCall("user32\MapWindowPoints", "Ptr", 0, "Ptr", dialogHwnd,
        "Ptr", rect, "UInt", 2)
    return {
        Left: NumGet(rect, 0, "Int"),
        Top: NumGet(rect, 4, "Int"),
        Right: NumGet(rect, 8, "Int"),
        Bottom: NumGet(rect, 12, "Int")
    }
}

ReadDarkMessageControlText(controlHwnd) {
    length := DllCall("user32\GetWindowTextLengthW", "Ptr", controlHwnd,
        "Int")
    textBuffer := Buffer((length + 1) * 2, 0)
    DllCall("user32\GetWindowTextW", "Ptr", controlHwnd, "Ptr", textBuffer,
        "Int", length + 1)
    return StrGet(textBuffer, length, "UTF-16")
}

InspectDarkMessageBox(dialogHwnd, message, mode) {
    clientRect := Buffer(16, 0)
    DllCall("user32\GetClientRect", "Ptr", dialogHwnd,
        "Ptr", clientRect)
    clientWidth := NumGet(clientRect, 8, "Int")
    controls := Map()
    for controlHwnd in WinGetControlsHwnd("ahk_id " dialogHwnd)
        controls[ReadDarkMessageControlText(controlHwnd)] := controlHwnd

    AssertDarkMessageBox(controls.Has(message), "弹窗正文控件缺失")
    iconText := mode == "message" ? "❌"
        : mode == "confirm" ? "⬆️" : "⚠"
    AssertDarkMessageBox(controls.Has(iconText), "弹窗图标控件缺失")
    messageRect := GetDarkMessageControlRect(controls[message], dialogHwnd)
    iconRect := GetDarkMessageControlRect(controls[iconText], dialogHwnd)
    AssertDarkMessageBox(Abs((messageRect.Top + messageRect.Bottom)
            - (iconRect.Top + iconRect.Bottom)) <= 2,
        "图标与正文没有垂直居中对齐")

    if mode == "message" {
        buttonRect := GetDarkMessageControlRect(controls["确 定"],
            dialogHwnd)
        AssertDarkMessageBox(Abs(buttonRect.Left + buttonRect.Right
                - clientWidth) <= 2,
            "确定按钮没有水平居中于窗口：left=" buttonRect.Left
                " right=" buttonRect.Right " client=" clientWidth)
    } else if mode == "confirm" {
        confirmRect := GetDarkMessageControlRect(controls["立即更新"],
            dialogHwnd)
        cancelRect := GetDarkMessageControlRect(controls["稍后"],
            dialogHwnd)
        AssertDarkMessageBox(Abs(confirmRect.Left + cancelRect.Right
                - clientWidth) <= 2,
            "确认框按钮组没有水平居中于窗口：left=" confirmRect.Left
                " right=" cancelRect.Right " client=" clientWidth)
    } else {
        firstChoiceRect := Buffer(16, 0)
        AssertDarkMessageBox(DllCall("user32\GetWindowRect",
            "Ptr", controls["立即恢复"], "Ptr", firstChoiceRect, "Int"),
            "无法读取立即恢复按钮屏幕位置")
        cursorPoint := Buffer(8, 0)
        cursorX := 0
        cursorY := 0
        cursorInsideButton := false
        Loop 40 {
            AssertDarkMessageBox(DllCall("user32\GetCursorPos",
                "Ptr", cursorPoint, "Int"), "无法读取系统鼠标位置")
            cursorX := NumGet(cursorPoint, 0, "Int")
            cursorY := NumGet(cursorPoint, 4, "Int")
            cursorInsideButton := cursorX >= NumGet(firstChoiceRect, 0, "Int")
                && cursorX < NumGet(firstChoiceRect, 8, "Int")
                && cursorY >= NumGet(firstChoiceRect, 4, "Int")
                && cursorY < NumGet(firstChoiceRect, 12, "Int")
            if cursorInsideButton
                break
            Sleep(25)
        }
        AssertDarkMessageBox(cursorInsideButton,
            "事件提醒窗口显示后鼠标没有定位到立即恢复按钮：cursor="
                cursorX "," cursorY " button="
                NumGet(firstChoiceRect, 0, "Int") ","
                NumGet(firstChoiceRect, 4, "Int") "-"
                NumGet(firstChoiceRect, 8, "Int") ","
                NumGet(firstChoiceRect, 12, "Int"))
    }
}

GetDarkMessageBoxTestTitle(mode) {
    return mode == "message" ? "消息框布局测试"
        : mode == "confirm" ? "确认框布局测试" : "事件提醒布局测试"
}

GetDarkMessageBoxTestMessage(mode) {
    if mode == "message" {
        return "创建快捷方式失败："
        . "用户配置目录\AppData\Roaming\Microsoft\Windows\Start Menu\"
        . "Programs\进程守护小助手.lnk"
    }
    if mode == "confirm"
        return "发现新版本 2.0.6，当前版本为 2.0.5。`n`n"
            . "更新包验证完成后将自动重启。是否立即更新？"
    return "监测到守护对象已停止：测试守护对象"
}

RunDarkMessageBoxChild(mode) {
    if mode != "message" && mode != "confirm" && mode != "choice"
        throw Error("未知弹窗测试模式：" mode)
    ; 父测试进程异常退出时，子进程也会自行结束，避免 CI 桌面遗留阻塞弹窗。
    SetTimer((*) => ExitApp(1), -15000)
    title := GetDarkMessageBoxTestTitle(mode)
    message := GetDarkMessageBoxTestMessage(mode)
    if mode == "message"
        ShowDarkMsgBox(message, title, "Error")
    else if mode == "confirm"
        ShowDarkConfirmBox(message, title, "立即更新", "稍后")
    else
        ShowDarkChoiceBox(message, title, [
            {Text: "立即恢复", Value: "resume"},
            {Text: "等待1分钟", Value: "wait1"},
            {Text: "等待3分钟", Value: "wait3"},
            {Text: "暂停守护", Value: "pause"}])
}

RunDarkMessageBoxLayoutCase(mode) {
    title := GetDarkMessageBoxTestTitle(mode)
    message := GetDarkMessageBoxTestMessage(mode)
    commandLine := '"' A_AhkPath '" /ErrorStdOut "' A_ScriptFullPath
        . '" --dialog-child ' mode
    childPid := 0
    dialogHwnd := 0
    FileAppend("DARK_MESSAGE_BOX_LAYOUT|STAGE|launch-" mode "`n", "*")
    try {
        DetectHiddenWindows(false)
        Run(commandLine, A_ScriptDir, "", &childPid)
        dialogHwnd := WinWait(title " ahk_class AutoHotkeyGUI ahk_pid "
            childPid, , 10)
        AssertDarkMessageBox(dialogHwnd,
            "等待弹窗子进程超时：" title "（PID " childPid "）")
        ; 可见就绪已证明控件构造完成；随后按捕获的 HWND 读取，避免显示过渡
        ; 瞬间让 WinGetControlsHwnd 再次按可见性过滤掉同一窗口。
        DetectHiddenWindows(true)
        if mode == "choice"
            Sleep(150)
        FileAppend("DARK_MESSAGE_BOX_LAYOUT|STAGE|inspect-" mode "`n", "*")
        InspectDarkMessageBox(dialogHwnd, message, mode)
    } finally {
        if dialogHwnd && DllCall("user32\IsWindow", "Ptr", dialogHwnd,
                "Int")
            try WinClose("ahk_id " dialogHwnd)
        if childPid {
            try ProcessWaitClose(childPid, 5)
            if ProcessExist(childPid)
                try ProcessClose(childPid)
            try ProcessWaitClose(childPid, 5)
        }
    }
    FileAppend("DARK_MESSAGE_BOX_LAYOUT|STAGE|closed-" mode "`n", "*")
}

RunDarkMessageBoxLayoutTests() {
    RunDarkMessageBoxLayoutCase("message")
    RunDarkMessageBoxLayoutCase("confirm")
    RunDarkMessageBoxLayoutCase("choice")
}
