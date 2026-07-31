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
            "Toolbar", "333333", "ToolbarText", "F2F2F2")
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

UnregisterGuiControls(*) {
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
    iconText := mode == "message" ? "❌" : "⬆️"
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
    } else {
        confirmRect := GetDarkMessageControlRect(controls["立即更新"],
            dialogHwnd)
        cancelRect := GetDarkMessageControlRect(controls["稍后"],
            dialogHwnd)
        AssertDarkMessageBox(Abs(confirmRect.Left + cancelRect.Right
                - clientWidth) <= 2,
            "确认框按钮组没有水平居中于窗口：left=" confirmRect.Left
                " right=" cancelRect.Right " client=" clientWidth)
    }
}

GetDarkMessageBoxTestTitle(mode) {
    return mode == "message" ? "消息框布局测试" : "确认框布局测试"
}

GetDarkMessageBoxTestMessage(mode) {
    if mode == "message" {
        return "创建快捷方式失败："
        . "用户配置目录\AppData\Roaming\Microsoft\Windows\Start Menu\"
        . "Programs\进程守护小助手.lnk"
    }
    return "发现新版本 2.0.6，当前版本为 2.0.5。`n`n"
        . "更新包验证完成后将自动重启。是否立即更新？"
}

RunDarkMessageBoxChild(mode) {
    if mode != "message" && mode != "confirm"
        throw Error("未知弹窗测试模式：" mode)
    ; 父测试进程异常退出时，子进程也会自行结束，避免 CI 桌面遗留阻塞弹窗。
    SetTimer((*) => ExitApp(1), -15000)
    title := GetDarkMessageBoxTestTitle(mode)
    message := GetDarkMessageBoxTestMessage(mode)
    if mode == "message"
        ShowDarkMsgBox(message, title, "Error")
    else
        ShowDarkConfirmBox(message, title, "立即更新", "稍后")
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
}
