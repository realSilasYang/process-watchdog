#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

; 创建真实可编辑 ListView，验证原生标签编辑框使用当前深色输入配色。

#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\UI\UiThemeService.ahk

ColorRefFromHex(color) {
    value := Integer("0x" color)
    return ((value & 0xFF) << 16) | (value & 0x00FF00)
        | ((value >> 16) & 0xFF)
}

ApplyDarkControlTheme(hWnd, themeName) {
    return DllCall("uxtheme\SetWindowTheme", "Ptr", hWnd,
        "WStr", themeName, "Ptr", 0, "Int") == 0
}

SetDarkControl(hWnd) {
    return ApplyDarkControlTheme(hWnd,
        UiThemeService.GetExplorerThemeName())
}

ApplyProductionListViewTheme(hListView) {
    dark := UiThemeService.IsDark()
    UiThemeService.AllowDarkModeForWindow(hListView, dark)
    DllCall("uxtheme\SetWindowTheme", "Ptr", hListView, "WStr",
        UiThemeService.GetListThemeName(), "Ptr", 0, "Int")
    SendMessage(0x1001, 0,
        ColorRefFromHex(UiThemeService.Color("Surface")),, hListView)
    SendMessage(0x1024, 0,
        ColorRefFromHex(UiThemeService.Color("Text")),, hListView)
    SendMessage(0x1026, 0,
        ColorRefFromHex(UiThemeService.Color("Surface")),, hListView)
    DllCall("user32\RedrawWindow", "Ptr", hListView, "Ptr", 0,
        "Ptr", 0, "UInt", Win32.RDW_CONTROL_REFRESH, "Int")
}

#Include ..\..\app\UI\DarkInlineEditThemeRegistry.ahk

global InlineEditThemeTestListView := ""
global InlineEditThemeTestCreatedHwnd := 0
global InlineEditThemeTestF2Count := 0

HandleInlineEditThemeTestKeyDown(wParam, lParam, message, hwnd) {
    global InlineEditThemeTestListView, InlineEditThemeTestCreatedHwnd
    global InlineEditThemeTestF2Count
    if !IsObject(InlineEditThemeTestListView)
        || hwnd != InlineEditThemeTestListView.Hwnd || wParam != 113 {
        return
    }

    InlineEditThemeTestF2Count++
    InlineEditThemeTestListView.Opt("-ReadOnly")
    editHwnd := SendMessage(0x1076, 0, 0, ,
        InlineEditThemeTestListView.Hwnd)
    if editHwnd {
        SetDarkControl(editHwnd)
        DarkInlineEditThemeRegistry.Register(editHwnd,
            InlineEditThemeTestListView.Hwnd)
    }
    InlineEditThemeTestCreatedHwnd := editHwnd
    ; 正式代码接管 F2；返回整数可阻止原生 ListView 再次处理同一按键并替换已应用主题的编辑框。
    return 0
}

AssertInlineEditTheme(condition, message) {
    if !condition
        throw Error(message)
}

RunInlineEditThemeTests() {
    UiThemeService.Configure("dark")
    testGui := Gui()
    testGui.BackColor := UiThemeService.Color("Window")
    listView := testGui.AddListView("w720 r3 Background"
        UiThemeService.Color("Surface") " c" UiThemeService.Color("Text")
        " Report +LV0x10002 -E0x200 -HScroll -Hdr -ReadOnly",
        ["守护对象", "状态", "完整路径", "序号", "状态排序键"])
    listView.Add("",
        "C:\Program Files\Example\uTools.exe",
        "运行中", "C:\Program Files\Example\uTools.exe",
        "4", "running")
    listView.ModifyCol(1, 620)
    listView.ModifyCol(2, 100)
    listView.ModifyCol(3, 0)
    listView.ModifyCol(4, 0)
    listView.ModifyCol(5, 0)
    ApplyProductionListViewTheme(listView.Hwnd)
    ; 窗口完全位于虚拟桌面外时，GetPixel 无法可靠采样客户端 DC。NoActivate 可在
    ; 保留真实绘制路径的同时，避免短暂的可视探针抢走键盘焦点。
    testGui.Show("x20 y20 NoActivate AutoSize")
    ApplyProductionListViewTheme(listView.Hwnd)
    listView.Modify(1, "Select Focus")
    listView.Focus()

    global InlineEditThemeTestListView := listView
    global InlineEditThemeTestCreatedHwnd := 0
    global InlineEditThemeTestF2Count := 0
    OnMessage(0x0100, HandleInlineEditThemeTestKeyDown)
    try {
        AssertInlineEditTheme(DllCall("user32\PostMessageW", "Ptr",
            listView.Hwnd, "UInt", 0x0100, "UPtr", 113, "Ptr", 0, "Int"),
            "无法投递真实 F2 标签编辑消息")
        Loop 20 {
            if InlineEditThemeTestCreatedHwnd
                break
            Sleep(25)
        }
        editHwnd := InlineEditThemeTestCreatedHwnd
        Sleep(50)
    } finally {
        OnMessage(0x0100, HandleInlineEditThemeTestKeyDown, 0)
    }
    AssertInlineEditTheme(editHwnd
        && DllCall("user32\IsWindow", "Ptr", editHwnd, "Int"),
        "ListView 没有创建原生标签编辑框")
    AssertInlineEditTheme(InlineEditThemeTestF2Count == 1,
        "F2 标签编辑消息没有且仅处理一次")
    AssertInlineEditTheme(SendMessage(0x1018, 0, 0, , listView.Hwnd)
            == editHwnd,
        "F2 被 ListView 重复处理并替换了已主题化的编辑框")
    editParent := DllCall("user32\GetParent", "Ptr", editHwnd, "Ptr")
    AssertInlineEditTheme(editParent == listView.Hwnd,
        "原生标签编辑框的直接父窗口不是 ListView")
    AssertInlineEditTheme(DarkInlineEditThemeRegistry.ListViews.Has(
            listView.Hwnd),
        "ListView 没有安装标签编辑主题子类")

    deviceContext := DllCall("user32\GetDC", "Ptr", editHwnd, "Ptr")
    AssertInlineEditTheme(deviceContext, "无法取得标签编辑框设备上下文")
    try {
        ; 通过 ListView 子类发送真实的父窗口通知。
        brush := DllCall("user32\SendMessageW", "Ptr", listView.Hwnd,
            "UInt", 0x0133, "UPtr", deviceContext, "Ptr", editHwnd, "Ptr")
        expectedBackground := ColorRefFromHex(UiThemeService.Color("Input"))
        expectedText := ColorRefFromHex(UiThemeService.Color("Text"))
        AssertInlineEditTheme(brush
            == DllCall("gdi32\GetStockObject", "Int", 18, "Ptr"),
            "标签编辑框没有返回主题 DC 画刷")
        AssertInlineEditTheme(DllCall("gdi32\GetBkColor", "Ptr",
                deviceContext, "UInt") == expectedBackground,
            "标签编辑框背景没有使用深色输入配色")
        AssertInlineEditTheme(DllCall("gdi32\GetTextColor", "Ptr",
                deviceContext, "UInt") == expectedText,
            "标签编辑框文字没有使用深色主题配色")
        AssertInlineEditTheme(DllCall("gdi32\GetDCBrushColor", "Ptr",
                deviceContext, "UInt") == expectedBackground,
            "标签编辑框画刷颜色没有使用深色输入配色")

        ; 在正常原生重绘后验证实际客户端表面，以识别仅在测试主动发送
        ; WM_CTLCOLOREDIT 时才生效的错误处理实现。
        DllCall("user32\RedrawWindow", "Ptr", editHwnd, "Ptr", 0,
            "Ptr", 0, "UInt", Win32.RDW_CONTROL_REFRESH, "Int")
        clientRect := Buffer(16, 0)
        rectAvailable := DllCall("user32\GetClientRect", "Ptr", editHwnd,
            "Ptr", clientRect, "Int")
        clientWidth := NumGet(clientRect, 8, "Int")
        clientHeight := NumGet(clientRect, 12, "Int")
        currentEditHwnd := SendMessage(0x1018, 0, 0, , listView.Hwnd)
        AssertInlineEditTheme(rectAvailable && clientWidth > 8
            && clientHeight > 2 && currentEditHwnd == editHwnd,
            "标签编辑框重绘前已失效或没有可取样客户区：width=" clientWidth
                " height=" clientHeight " current=" currentEditHwnd
                " expected=" editHwnd)
        sampleX := clientWidth - 4
        sampleY := Floor(clientHeight / 2)
        renderedBackground := DllCall("gdi32\GetPixel", "Ptr",
            deviceContext, "Int", sampleX, "Int", sampleY, "UInt")
        AssertInlineEditTheme(renderedBackground == expectedBackground,
            "原生重绘后的标签编辑框仍不是深色背景：actual="
                Format("0x{:06X}", renderedBackground)
                " expected=" Format("0x{:06X}", expectedBackground)
                " sample=" sampleX "," sampleY
                " size=" clientWidth "x" clientHeight)
    } finally {
        DllCall("user32\ReleaseDC", "Ptr", editHwnd, "Ptr", deviceContext)
    }

    AssertInlineEditTheme(DarkInlineEditThemeRegistry.Refresh(editHwnd),
        "主题热切换无法刷新活动标签编辑框")
    DarkInlineEditThemeRegistry.Unregister(editHwnd)
    AssertInlineEditTheme(!DarkInlineEditThemeRegistry.EditHandles.Has(editHwnd),
        "标签编辑结束后仍残留主题注册")
    AssertInlineEditTheme(!DarkInlineEditThemeRegistry.ListViews.Has(
            listView.Hwnd),
        "标签编辑结束后仍残留 ListView 子类注册")

    ; 销毁窗口也必须清理由于异常路径而未先注销的编辑会话。
    AssertInlineEditTheme(DarkInlineEditThemeRegistry.Register(editHwnd,
        listView.Hwnd), "销毁清理测试无法重新注册标签编辑主题")
    listHwnd := listView.Hwnd
    testGui.Destroy()
    AssertInlineEditTheme(!DarkInlineEditThemeRegistry.EditHandles.Has(editHwnd),
        "ListView 销毁后仍残留标签编辑框映射")
    AssertInlineEditTheme(!DarkInlineEditThemeRegistry.ListViews.Has(listHwnd),
        "ListView 销毁后仍残留子类状态")
}

try {
    RunInlineEditThemeTests()
    FileAppend("INLINE_EDIT_THEME|PASS`n", "*")
    ExitApp(0)
} catch as testError {
    FileAppend(testError.File " (" testError.Line "): " testError.Message
        "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
