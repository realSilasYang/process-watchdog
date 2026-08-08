#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

; 创建真实深色 GUI，验证主列表列顺序、DPI 列宽、窗口层级租约和基础原生资源。
; 这是无需人工点击的界面冒烟测试，任何断言失败都会以非零退出码报告。

#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\UI\MainListProjection.ahk
#Include ..\..\src\UI\ListViewFocusService.ahk
#Include ..\..\src\UI\AtomicControlLayout.ahk
#Include ..\..\src\UI\ListViewPseudoHeader.ahk
#Include ..\..\src\UI\WindowHierarchy.ahk

; 列表自绘只依赖主题色。此测试使用最小适配器，避免启动完整守护运行时或读取用户配置。
class UiThemeService {
    static Color(name) {
        colors := Map(
            "Window", "1E1E1E", "Surface", "252526",
            "Tooltip", "202020", "TooltipText", "F2F2F2")
        return colors.Has(name) ? colors[name] : "F2F2F2"
    }
}

class RoundedButtonRenderer {
    static ColorToBgr(color) {
        value := Integer("0x" color)
        return ((value & 0xFF) << 16) | (value & 0x00FF00)
            | ((value >> 16) & 0xFF)
    }

    static MaskOutsideRoundedRectangle(hdc, outerLeft, outerTop,
        outerRight, outerBottom, innerLeft, innerTop, innerRight,
        innerBottom, color, radius) {
        brush := DllCall("gdi32\CreateSolidBrush", "UInt",
            this.ColorToBgr(color), "Ptr")
        outerRegion := DllCall("gdi32\CreateRectRgn",
            "Int", outerLeft, "Int", outerTop,
            "Int", outerRight, "Int", outerBottom, "Ptr")
        innerRegion := DllCall("gdi32\CreateRoundRectRgn",
            "Int", innerLeft, "Int", innerTop,
            "Int", innerRight, "Int", innerBottom,
            "Int", radius * 2, "Int", radius * 2, "Ptr")
        try {
            if !brush || !outerRegion || !innerRegion
                return false
            DllCall("gdi32\CombineRgn", "Ptr", outerRegion,
                "Ptr", outerRegion, "Ptr", innerRegion, "Int", 4)
            return DllCall("gdi32\FillRgn", "Ptr", hdc,
                "Ptr", outerRegion, "Ptr", brush, "Int") != 0
        }
        finally {
            if innerRegion
                DllCall("gdi32\DeleteObject", "Ptr", innerRegion)
            if outerRegion
                DllCall("gdi32\DeleteObject", "Ptr", outerRegion)
            if brush
                DllCall("gdi32\DeleteObject", "Ptr", brush)
        }
    }

    static Shutdown(*) {
    }
}

#Include ..\..\app\UI\ListViewSelectionPresenter.ahk

; 原生列边界的具体像素由 Windows 主题和桌面合成器决定，CI 虚拟桌面不能
; 稳定比较颜色。测试子类只记录生产刷新入口的真实执行次数和返回值，用来
; 验证连续状态更新确实合并为一次整控件重绘，而不是退回逐行刷新。
class GuiSmokeListViewSelectionPresenter extends ListViewSelectionPresenter {
    nativeRefreshCount := 0
    lastNativeRefreshSucceeded := false

    RefreshNativeSurface(*) {
        refreshSucceeded := super.RefreshNativeSurface()
        this.nativeRefreshCount += 1
        this.lastNativeRefreshSucceeded := refreshSucceeded
        return refreshSucceeded
    }
}

AssertGuiSmoke(condition, message) {
    if !condition
        throw Error(message)
}

ReportGuiSmokeStage(name, details := "") {
    FileAppend("GUI_SMOKE|STAGE|" name
        (details == "" ? "" : "|" details) "`n", "*")
}

GetGuiSmokePathOrder(listView) {
    order := ""
    Loop listView.GetCount()
        order .= (A_Index == 1 ? "" : "|") listView.GetText(A_Index, 3)
    return order
}

GetGuiSmokeColumnFormat(listView, columnIndex) {
    ; 从原生 Header 读取 HDITEMW.fmt；其低两位与 ListView 列共享
    ; Left／Right／Center 对齐语义，只请求 HDI_FORMAT 即可验证真实显示格式。
    headerHwnd := SendMessage(Win32.LVM_GETHEADER, 0, 0, listView.Hwnd)
    if !headerHwnd
        return -1
    headerItem := Buffer(A_PtrSize == 8 ? 72 : 48, 0)
    NumPut("UInt", 0x0004, headerItem, 0) ; HDI_FORMAT：读取表头格式字段
    ; HDM_GETITEMW：读取从零开始的内部列索引。
    if !SendMessage(0x120B, columnIndex, headerItem.Ptr, headerHwnd)
        return -1
    return NumGet(headerItem, A_PtrSize == 8 ? 28 : 20, "Int")
}

AssertGuiSmokeSequenceCentered(listView, context) {
    ; 序号是内部第 4 列，对应 Header 中从零开始的索引 3。
    sequenceFormat := GetGuiSmokeColumnFormat(listView, 3)
    AssertGuiSmoke(sequenceFormat >= 0
        && (sequenceFormat & 0x0003) == 0x0002,
        context "后序号列不再居中")
}

GetGuiSmokeNameOrder(listView) {
    order := ""
    Loop listView.GetCount()
        order .= (A_Index == 1 ? "" : "|") listView.GetText(A_Index, 1)
    return order
}

PrepareGuiSmokeStatusSort(listView, header, column, descending) {
    if column != 5
        return
    Loop listView.GetCount() {
        sequence := Integer(listView.GetText(A_Index, 4))
        stableSequence := descending ? 0x7FFFFFFF - sequence : sequence
        priority := listView.GetText(A_Index, 2) == "Paused" ? 40 : 50
        listView.Modify(A_Index, "Col5", Format("{:02}|{}", priority,
            stableSequence))
    }
}

PostGuiSmokeHeaderNotification(guiObj, cell, notificationCode) {
    controlId := DllCall("user32\GetDlgCtrlID", "Ptr", cell.Hwnd, "Int")
    wParam := controlId | (notificationCode << 16)
    AssertGuiSmoke(DllCall("user32\PostMessageW", "Ptr", guiObj.Hwnd,
        "UInt", Win32.WM_COMMAND, "UPtr", wParam, "Ptr", cell.Hwnd, "Int"),
        "Pseudo header notification could not be posted")
    Sleep(20)
}

SendGuiSmokeHeaderPointerClick(cell, downMessage) {
    clientRect := Buffer(16, 0)
    AssertGuiSmoke(DllCall("user32\GetClientRect", "Ptr", cell.Hwnd,
        "Ptr", clientRect, "Int"), "Pseudo header bounds were not readable")
    x := Max(0, (NumGet(clientRect, 8, "Int") - 1) // 2)
    y := Max(0, (NumGet(clientRect, 12, "Int") - 1) // 2)
    point := ((y & 0xFFFF) << 16) | (x & 0xFFFF)
    SendMessage(downMessage, 1, point, cell.Hwnd)
    SendMessage(Win32.WM_LBUTTONUP, 0, point, cell.Hwnd)
    Sleep(20)
}

GetGuiSmokeControlRectInParent(control, parentHwnd) {
    rect := Buffer(16, 0)
    AssertGuiSmoke(DllCall("user32\GetWindowRect", "Ptr", control.Hwnd,
        "Ptr", rect, "Int"), "Visible control bounds were not readable")
    DllCall("user32\MapWindowPoints", "Ptr", 0, "Ptr", parentHwnd,
        "Ptr", rect, "UInt", 2, "Int")
    return {
        Left: NumGet(rect, 0, "Int"), Top: NumGet(rect, 4, "Int"),
        Right: NumGet(rect, 8, "Int"), Bottom: NumGet(rect, 12, "Int")
    }
}

owner := ""
child := ""
listSelectionPresenter := ""
testFailure := ""
try {
    owner := Gui("+Resize +MinSize420x260", "GUI smoke owner")
    owner.BackColor := "1E1E1E"
    owner.SetFont("s10 cFFFFFF", "Microsoft YaHei UI")
    owner.Add("Text", "x16 y14 w180 BackgroundTrans", "Process watchdog")
    ownerEdit := owner.Add("Edit",
        "x16 y42 w260 h28 Background252526 cFFFFFF", "editable")
    list := owner.Add("ListView",
        "x16 y82 w380 h120 Report +LV0x10002 -Hdr Background252526 cFFFFFF",
        ["Name", "State", "Path", "Sequence", "StatusKey"])
    listSelectionPresenter := GuiSmokeListViewSelectionPresenter(list)
    list.ModifyCol(1, 220)
    list.ModifyCol(2, 110)
    list.ModifyCol(3, 0)
    list.ModifyCol(4, "Center 48")
    list.ModifyCol(5, 0)
    listProjection := MainListProjection()
    AssertGuiSmoke(listProjection.ApplyColumnOrder(list),
        "Main ListView column order was not applied")
    pseudoHeader := ListViewPseudoHeader(owner, list, [
        {Column: 4, Label: "Order", Align: "Center", SortOptions: "Integer",
            SkipAscending: true},
        {Column: 1, Label: "Name", SortOptions: "Logical"},
        {Column: 5, Label: "State", SortOptions: "Logical"}
    ], {
        BackgroundColor: "333333",
        TextColor: "B8BAB9",
        FontName: "Segoe UI",
        CursorRegistrar: (*) => true,
        RestoreColumn: 4,
        RestoreSortOptions: "Integer Center"
    })
    AssertGuiSmoke(pseudoHeader.SetBounds(16, 54, [48, 220, 110], 380),
        "Pseudo header bounds were not applied")
    for headerCell in pseudoHeader.Cells {
        headerStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
            headerCell.Hwnd, "Int", -16, "Ptr")
        AssertGuiSmoke(!(headerStyle & 0x00010000)
                && (headerStyle & 0x3) == 0x1,
            "Pseudo header field was not centered or remained keyboard-selectable through Tab")
        AssertGuiSmoke(SendMessage(0x0301, 0, 0, headerCell.Hwnd) == 0,
            "Pseudo header field did not reject native copy requests")
        AssertGuiSmoke(!pseudoHeader.SetCellTextNoErase(headerCell,
            headerCell.Text),
            "Unchanged pseudo header text still requested a redraw")
    }
    for headerColumn in pseudoHeader.Columns {
        AssertGuiSmoke(StrLower(headerColumn.HeaderAlign) == "center"
                && headerColumn.Padding == "",
            "Pseudo header content retained left alignment or padding")
    }
    ReportGuiSmokeStage("header-structure")
    list.Add("", "Smoke target B", "Paused", "C:\SmokeB.exe", "1", "20")
    list.Add("", "Smoke target A", "Running", "C:\SmokeA.exe", "2", "10")
    customPathOrder := "C:\SmokeB.exe|C:\SmokeA.exe"
    AssertGuiSmoke(pseudoHeader.SortByDisplayColumn(2)
        && list.GetText(1, 1) == "Smoke target A"
        && InStr(pseudoHeader.Cells[2].Text, "↑"),
        "Pseudo header ascending sort or indicator failed")
    AssertGuiSmoke(pseudoHeader.SortByDisplayColumn(2)
        && list.GetText(1, 1) == "Smoke target B"
        && InStr(pseudoHeader.Cells[2].Text, "↓"),
        "Pseudo header descending sort or indicator failed")
    AssertGuiSmoke(pseudoHeader.SortByDisplayColumn(2)
        && !pseudoHeader.HasActiveSort()
        && GetGuiSmokePathOrder(list) == customPathOrder
        && !InStr(pseudoHeader.Cells[2].Text, "↑")
        && !InStr(pseudoHeader.Cells[2].Text, "↓"),
        "Pseudo header third click did not restore custom order")
    AssertGuiSmoke(pseudoHeader.SortByDisplayColumn(3)
        && list.GetText(1, 3) == "C:\SmokeA.exe"
        && list.GetText(1, 5) == "10",
        "Pseudo header did not sort the visible status field by its semantic key")
    AssertGuiSmoke(pseudoHeader.SortByDisplayColumn(3)
        && list.GetText(1, 3) == "C:\SmokeB.exe",
        "Pseudo header semantic status descending sort failed")
    AssertGuiSmoke(pseudoHeader.SortByDisplayColumn(3)
        && GetGuiSmokePathOrder(list) == customPathOrder,
        "Pseudo header semantic status sort did not restore custom order")
    AssertGuiSmoke(pseudoHeader.SortByDisplayColumn(1)
        && pseudoHeader.SortDescending
        && InStr(pseudoHeader.Cells[1].Text, "↓")
        && list.GetText(1, 4) == "2",
        "Sequence field first click did not sort descending")
    AssertGuiSmokeSequenceCentered(list, "序号降序排序")
    AssertGuiSmoke(pseudoHeader.SortByDisplayColumn(1)
        && !pseudoHeader.HasActiveSort()
        && GetGuiSmokePathOrder(list) == customPathOrder,
        "Sequence field second click did not restore custom order")
    AssertGuiSmokeSequenceCentered(list, "序号恢复用户顺序")
    AssertGuiSmoke(pseudoHeader.SortByDisplayColumn(1)
        && pseudoHeader.SortDescending
        && InStr(pseudoHeader.Cells[1].Text, "↓"),
        "Sequence field repeated cycle did not restart descending sort")
    AssertGuiSmoke(pseudoHeader.SortByDisplayColumn(1)
        && !pseudoHeader.HasActiveSort()
        && GetGuiSmokePathOrder(list) == customPathOrder,
        "Sequence field repeated cycle did not restore custom order")
    for testDisplayColumn in [2, 3] {
        AssertGuiSmoke(pseudoHeader.SortByDisplayColumn(testDisplayColumn)
            && !pseudoHeader.SortDescending
            && InStr(pseudoHeader.Cells[testDisplayColumn].Text, "↑"),
            "Pseudo header cycle did not start with ascending sort")
        AssertGuiSmoke(pseudoHeader.SortByDisplayColumn(testDisplayColumn)
            && pseudoHeader.SortDescending
            && InStr(pseudoHeader.Cells[testDisplayColumn].Text, "↓"),
            "Pseudo header cycle did not continue with descending sort")
        AssertGuiSmoke(pseudoHeader.SortByDisplayColumn(testDisplayColumn)
            && !pseudoHeader.HasActiveSort()
            && GetGuiSmokePathOrder(list) == customPathOrder,
            "Pseudo header field did not return to custom order")
        AssertGuiSmoke(pseudoHeader.SortByDisplayColumn(testDisplayColumn)
            && !pseudoHeader.SortDescending
            && InStr(pseudoHeader.Cells[testDisplayColumn].Text, "↑"),
            "Pseudo header fourth click did not restart ascending sort")
        AssertGuiSmoke(pseudoHeader.SortByDisplayColumn(testDisplayColumn)
            && pseudoHeader.SortByDisplayColumn(testDisplayColumn)
            && !pseudoHeader.HasActiveSort()
            && GetGuiSmokePathOrder(list) == customPathOrder,
            "Pseudo header repeated cycle did not restore custom order")
    }
    PostGuiSmokeHeaderNotification(owner, pseudoHeader.Cells[1], 0)
    AssertGuiSmoke(pseudoHeader.SortDisplayColumn == 1
        && pseudoHeader.SortDescending,
        "Sequence rapid cycle did not start with descending sort")
    PostGuiSmokeHeaderNotification(owner, pseudoHeader.Cells[1], 1)
    AssertGuiSmoke(!pseudoHeader.HasActiveSort()
        && GetGuiSmokePathOrder(list) == customPathOrder,
        "Sequence field ignored the immediate restore click")
    for testDisplayColumn in [2, 3] {
        PostGuiSmokeHeaderNotification(owner,
            pseudoHeader.Cells[testDisplayColumn], 0) ; STN_CLICKED：模拟单击通知
        AssertGuiSmoke(pseudoHeader.SortDisplayColumn == testDisplayColumn
            && !pseudoHeader.SortDescending,
            "Pseudo header rapid cycle did not start with ascending sort")
        PostGuiSmokeHeaderNotification(owner,
            pseudoHeader.Cells[testDisplayColumn], 1) ; STN_DBLCLK：模拟双击通知
        AssertGuiSmoke(pseudoHeader.SortDisplayColumn == testDisplayColumn
            && pseudoHeader.SortDescending,
            "Pseudo header ignored the immediate second click")
        PostGuiSmokeHeaderNotification(owner,
            pseudoHeader.Cells[testDisplayColumn], 0) ; STN_CLICKED：再次单击取消排序
        AssertGuiSmoke(!pseudoHeader.HasActiveSort()
            && GetGuiSmokePathOrder(list) == customPathOrder,
            "Pseudo header rapid third click did not restore custom order")
    }
    SendGuiSmokeHeaderPointerClick(pseudoHeader.Cells[2],
        Win32.WM_LBUTTONDOWN)
    AssertGuiSmoke(pseudoHeader.SortDisplayColumn == 2
        && !pseudoHeader.SortDescending,
        "Pseudo header pointer click did not start ascending sort")
    SendGuiSmokeHeaderPointerClick(pseudoHeader.Cells[2],
        Win32.WM_LBUTTONDBLCLK)
    AssertGuiSmoke(pseudoHeader.SortDisplayColumn == 2
        && pseudoHeader.SortDescending,
        "Pseudo header fast second pointer click was ignored")
    SendGuiSmokeHeaderPointerClick(pseudoHeader.Cells[2],
        Win32.WM_LBUTTONDOWN)
    AssertGuiSmoke(!pseudoHeader.HasActiveSort()
        && GetGuiSmokePathOrder(list) == customPathOrder,
        "Pseudo header pointer third click did not restore custom order")
    semanticList := owner.Add("ListView",
        "x410 y82 w1 h1 Report -Hdr", ["Name", "State", "Path",
            "Sequence", "StatusKey"])
    semanticList.ModifyCol(5, 0)
    semanticHeader := ListViewPseudoHeader(owner, semanticList, [
        {Column: 5, Label: "State", SortOptions: "Logical"}
    ], {
        RestoreColumn: 4,
        OnBeforeSort: PrepareGuiSmokeStatusSort.Bind(semanticList)
    })
    semanticHeader.SetBounds(410, 54, [1], 1)
    semanticList.Add("", "First", "Running", "C:\First.exe", "1", "50|1")
    semanticList.Add("", "Second", "Running", "C:\Second.exe", "2", "50|2")
    semanticList.Add("", "Third", "Paused", "C:\Third.exe", "3", "40|3")
    AssertGuiSmoke(semanticHeader.SortByDisplayColumn(1)
        && GetGuiSmokeNameOrder(semanticList) == "Third|First|Second",
        "Semantic status ascending sort lost the saved order within a group")
    AssertGuiSmoke(semanticHeader.SortByDisplayColumn(1)
        && GetGuiSmokeNameOrder(semanticList) == "First|Second|Third",
        "Semantic status descending sort reversed the saved order within a group")
    AssertGuiSmoke(semanticHeader.SortByDisplayColumn(1)
        && GetGuiSmokeNameOrder(semanticList) == "First|Second|Third",
        "Semantic status third click did not restore the saved order")
    columnOrder := Buffer(20, 0)
    AssertGuiSmoke(SendMessage(Win32.LVM_GETCOLUMNORDERARRAY, 5,
        columnOrder.Ptr, list.Hwnd), "Main ListView column order was not readable")
    expectedOrder := [3, 0, 1, 2, 4]
    for testOrderPosition, expectedColumn in expectedOrder {
        AssertGuiSmoke(NumGet(columnOrder, (testOrderPosition - 1) * 4, "Int")
            == expectedColumn, "Main ListView visual column order is incorrect")
    }
    AssertGuiSmoke(list.GetText(1, 1) == "Smoke target B"
        && list.GetText(1, 3) == "C:\SmokeB.exe"
        && list.GetText(1, 4) == "1",
        "Main ListView internal identity columns changed")
    list.Delete(1)
    AssertGuiSmoke(listProjection.RefreshSequence(list) == 1
        && list.GetText(1, 1) == "Smoke target A"
        && list.GetText(1, 4) == "1",
        "Main ListView sequence did not refresh after deletion")
    list.Add("", "Smoke target C", "Paused", "C:\SmokeC.exe", "2", "20")
    ReportGuiSmokeStage("sorting")
    actionButton := owner.Add("Text",
        "x16 y216 w88 h30 Center 0x200 Background333333 cFFFFFF",
        "Action")
    passiveStatus := owner.Add("Text",
        "x114 y216 w282 h30 Background1E1E1E cAAAAAA 0x200", "Status")
    ; 这组测试必须可见才能验证焦点、气泡动画和真实像素；因此显示前就把
    ; 标题栏与原生输入／列表控件设为同一深色主题，禁止测试夹具自身混搭。
    if VerCompare(A_OSVersion, "10.0.17763") >= 0 {
        titleBarAttribute := VerCompare(A_OSVersion, "10.0.18985") >= 0
            ? 20 : 19
        try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", owner.Hwnd,
            "Int", titleBarAttribute, "Int*", 1, "Int", 4)
        try DllCall("uxtheme\SetWindowTheme", "Ptr", ownerEdit.Hwnd,
            "Str", "DarkMode_Explorer", "Ptr", 0)
        try DllCall("uxtheme\SetWindowTheme", "Ptr", list.Hwnd,
            "Str", "DarkMode_Explorer", "Ptr", 0)
    }
    owner.Show("w430 h270")
    visibleDpi := DllCall("user32\GetDpiForWindow", "Ptr", owner.Hwnd,
        "UInt")
    visibleScale := visibleDpi / 96
    visibleHeaderWidths := [52, 216, 104]
    AssertGuiSmoke(pseudoHeader.SetBounds(20, 54,
        visibleHeaderWidths, 372),
        "Visible pseudo header bounds were not applied")
    expectedCellX := Round(20 * visibleScale)
    for visibleIndex, headerCell in pseudoHeader.Cells {
        headerRect := GetGuiSmokeControlRectInParent(headerCell, owner.Hwnd)
        expectedWidth := Round(visibleHeaderWidths[visibleIndex]
            * visibleScale)
        AssertGuiSmoke(headerRect.Left == expectedCellX
            && headerRect.Top == Round(54 * visibleScale)
            && headerRect.Right - headerRect.Left == expectedWidth
            && headerRect.Bottom - headerRect.Top == Round(28 * visibleScale),
            "Visible pseudo header deferred layout produced incorrect bounds")
        expectedCellX += expectedWidth
    }
    AssertGuiSmoke(pseudoHeader.SetBounds(16, 54,
        [48, 220, 110], 380),
        "Visible pseudo header bounds were not restored")
    atomicNoopResult := AtomicControlLayout.Apply(owner, [
        {Control: pseudoHeader.Background, X: 16, Y: 54,
            Width: 380, Height: 28},
        {Control: pseudoHeader.Cells[1], X: 16, Y: 54,
            Width: 48, Height: 28},
        {Control: pseudoHeader.Cells[2], X: 64, Y: 54,
            Width: 220, Height: 28},
        {Control: pseudoHeader.Cells[3], X: 284, Y: 54,
            Width: 110, Height: 28}
    ], {ParentColor: "333333"})
    AssertGuiSmoke(atomicNoopResult.Status == AtomicControlLayout.Unchanged,
        "Unchanged atomic layout did not take its no-paint fast path")
    headerDc := DllCall("user32\GetDC", "Ptr", owner.Hwnd, "Ptr")
    AssertGuiSmoke(headerDc, "Visible pseudo header surface was not readable")
    try {
        AssertGuiSmoke(DllCall("gdi32\GetPixel", "Ptr", headerDc,
                "Int", Round(392 * visibleScale),
                "Int", Round(68 * visibleScale), "UInt")
                == RoundedButtonRenderer.ColorToBgr("333333"),
            "Visible pseudo header did not repaint its restored right edge")
    } finally DllCall("user32\ReleaseDC", "Ptr", owner.Hwnd, "Ptr", headerDc)
    ReportGuiSmokeStage("visible-header-layout")
    ; 焦点重定向必须在真实可见窗口中验证。隐藏父窗口时，Windows 可以合法
    ; 拒绝把焦点交给其子控件，不能据此判断伪表头输入保护失效。
    DllCall("user32\SetFocus", "Ptr", list.Hwnd, "Ptr")
    for headerCell in pseudoHeader.Cells {
        DllCall("user32\SetFocus", "Ptr", headerCell.Hwnd, "Ptr")
        AssertGuiSmoke(DllCall("user32\GetFocus", "Ptr") == list.Hwnd,
            "Pseudo header field retained focus instead of rejecting selection")
    }
    ReportGuiSmokeStage("visible-header-focus")

    ; 非客户区消息必须原样交还给 Windows，否则标题栏最小化、关闭和拖动
    ; 都会失效。客户区的主窗口、状态栏和 ListView 空白区域才交还焦点。
    list.Modify(1, "Select Focus")
    DllCall("user32\SetFocus", "Ptr", list.Hwnd, "Ptr")
    nonClientResult := ListViewFocusService.HandleBlankPointerDown(list,
        owner.Hwnd, owner.Hwnd, 0, Win32.WM_NCLBUTTONDOWN,
        [passiveStatus.Hwnd])
    AssertGuiSmoke(nonClientResult == ListViewFocusService.NoAction
        && DllCall("user32\GetFocus", "Ptr") == list.Hwnd
        && list.GetNext(0, "Focused") == 1 && list.GetNext(0) == 1,
        "Non-client pointer down was swallowed by ListView blur routing")

    rootBlurResult := ListViewFocusService.HandleBlankPointerDown(list,
        owner.Hwnd, owner.Hwnd, 0, Win32.WM_LBUTTONDOWN,
        [passiveStatus.Hwnd])
    rootFocusHwnd := DllCall("user32\GetFocus", "Ptr")
    rootFocusedRow := list.GetNext(0, "Focused")
    rootSelectedRow := list.GetNext(0)
    AssertGuiSmoke(rootBlurResult == ListViewFocusService.Handled
        && rootFocusHwnd == passiveStatus.Hwnd
        && rootFocusedRow == 0 && rootSelectedRow == 1,
        "Clicking the main-window blank surface did not fully blur ListView: result="
            rootBlurResult " focus=" rootFocusHwnd " sink=" passiveStatus.Hwnd
            " focusedRow=" rootFocusedRow " selectedRow=" rootSelectedRow)

    list.Modify(1, "Focus")
    DllCall("user32\SetFocus", "Ptr", list.Hwnd, "Ptr")
    statusBlurResult := ListViewFocusService.HandleBlankPointerDown(list,
        owner.Hwnd, passiveStatus.Hwnd, 0, Win32.WM_LBUTTONDOWN,
        [passiveStatus.Hwnd])
    AssertGuiSmoke(statusBlurResult == ListViewFocusService.Handled
        && DllCall("user32\GetFocus", "Ptr") == passiveStatus.Hwnd
        && list.GetNext(0, "Focused") == 0 && list.GetNext(0) == 1,
        "Clicking the passive status surface did not blur ListView")

    list.Modify(1, "Focus")
    DllCall("user32\SetFocus", "Ptr", list.Hwnd, "Ptr")
    blankListPoint := (100 << 16) | 8
    listBlurResult := ListViewFocusService.HandleBlankPointerDown(list,
        owner.Hwnd, list.Hwnd, blankListPoint, Win32.WM_LBUTTONDOWN,
        [passiveStatus.Hwnd])
    AssertGuiSmoke(listBlurResult == ListViewFocusService.SuppressDefault
        && DllCall("user32\GetFocus", "Ptr") == passiveStatus.Hwnd
        && list.GetNext(0, "Focused") == 0 && list.GetNext(0) == 1,
        "Clicking the ListView blank surface did not suppress refocus")

    list.Modify(1, "Focus")
    DllCall("user32\SetFocus", "Ptr", list.Hwnd, "Ptr")
    rowListPoint := (10 << 16) | 8
    rowHitResult := ListViewFocusService.HandleBlankPointerDown(list,
        owner.Hwnd, list.Hwnd, rowListPoint, Win32.WM_LBUTTONDOWN,
        [passiveStatus.Hwnd])
    AssertGuiSmoke(rowHitResult == ListViewFocusService.NoAction
        && DllCall("user32\GetFocus", "Ptr") == list.Hwnd
        && list.GetNext(0, "Focused") == 1,
        "Clicking a ListView item was mistaken for a blank surface")
    ReportGuiSmokeStage("main-list-blank-focus")

    AssertGuiSmoke(DllCall("user32\IsWindow", "Ptr", owner.Hwnd, "Int"),
        "Owner GUI handle was not created")
    dpi := DllCall("user32\GetDpiForWindow", "Ptr", owner.Hwnd, "UInt")
    AssertGuiSmoke(dpi >= 96, "GUI DPI was not available")
    ReportGuiSmokeStage("surface-before-redraw")
    DllCall("user32\RedrawWindow", "Ptr", owner.Hwnd, "Ptr", 0,
        "Ptr", 0, "UInt", Win32.RDW_LAYOUT_REFRESH, "Int")
    ReportGuiSmokeStage("surface-after-redraw")
    ownerDc := DllCall("user32\GetDC", "Ptr", owner.Hwnd, "Ptr")
    actionDc := DllCall("user32\GetDC", "Ptr", actionButton.Hwnd, "Ptr")
    AssertGuiSmoke(ownerDc && actionDc,
        "GUI smoke theme surfaces were not readable")
    try {
        AssertGuiSmoke(DllCall("gdi32\GetPixel", "Ptr", ownerDc,
                "Int", 5, "Int", 5, "UInt")
                == RoundedButtonRenderer.ColorToBgr("1E1E1E")
            && DllCall("gdi32\GetPixel", "Ptr", actionDc,
                "Int", 4, "Int", 4, "UInt")
                == RoundedButtonRenderer.ColorToBgr("333333"),
            "可见 GUI 冒烟窗口出现了跨主题表面")
    } finally {
        DllCall("user32\ReleaseDC", "Ptr", actionButton.Hwnd,
            "Ptr", actionDc)
        DllCall("user32\ReleaseDC", "Ptr", owner.Hwnd, "Ptr", ownerDc)
    }
    ReportGuiSmokeStage("surface-pixels")
    sequenceWidth := SendMessage(Win32.LVM_GETCOLUMNWIDTH, 3, 0, list.Hwnd)
    AssertGuiSmoke(Abs(sequenceWidth - Round(48 * dpi / 96)) <= 1,
        "Main ListView sequence width did not follow the window DPI")
    headerCellRect := Buffer(16, 0)
    AssertGuiSmoke(DllCall("user32\GetWindowRect", "Ptr",
        pseudoHeader.Cells[1].Hwnd, "Ptr", headerCellRect, "Int"),
        "Pseudo header sequence cell bounds were not readable")
    headerSequenceWidth := NumGet(headerCellRect, 8, "Int")
        - NumGet(headerCellRect, 0, "Int")
    AssertGuiSmoke(Abs(headerSequenceWidth - sequenceWidth) <= 1,
        "Pseudo header sequence cell did not align with the native DPI-scaled column")
    ; 模拟同一轮内的两次状态更新。第二次调度必须替换第一次的单次计时器，
    ; 最终只执行一次生产级整控件重绘。
    list.Modify(2, "Col2", "Updated")
    refreshDelayMs := 25
    AssertGuiSmoke(listSelectionPresenter.ScheduleNativeSurfaceRefresh(
            refreshDelayMs),
        "Native ListView surface refresh was not scheduled")
    AssertGuiSmoke(listSelectionPresenter.ScheduleNativeSurfaceRefresh(
            refreshDelayMs),
        "Repeated native ListView surface refresh was not coalesced")
    ReportGuiSmokeStage("divider-refresh-scheduled")
    refreshDeadline := A_TickCount + 1000
    while listSelectionPresenter.nativeRefreshCount < 1
            && A_TickCount < refreshDeadline
        Sleep(10)
    ; 首次回调完成后再越过一个合并窗口；若旧计时器没有被替换，计数会变成 2。
    Sleep(refreshDelayMs * 2)
    ReportGuiSmokeStage("divider-refresh-ready")
    AssertGuiSmoke(listSelectionPresenter.nativeRefreshCount == 1
        && listSelectionPresenter.lastNativeRefreshSucceeded,
        "Native ListView updates were not coalesced into one full refresh")
    ReportGuiSmokeStage("divider-refresh")
    list.Modify(1, "Select Focus")
    ; 右键菜单接管焦点时，自绘通知可能不再携带 CDIS_SELECTED；真实行状态
    ; 仍须触发后绘制，确保圆角选中态不会退回原生矩形。
    selectionNotification := Buffer(A_PtrSize == 8 ? 80 : 48, 0)
    NumPut("UInt", Win32.CDDS_ITEMPREPAINT, selectionNotification,
        A_PtrSize == 8 ? 24 : 12)
    NumPut("UPtr", 0, selectionNotification,
        A_PtrSize == 8 ? 56 : 36)
    AssertGuiSmoke((SendMessage(Win32.LVM_GETITEMSTATE, 0,
            Win32.LVIS_SELECTED, list.Hwnd) & Win32.LVIS_SELECTED) != 0
        && listSelectionPresenter.HandleCustomDraw(list,
            selectionNotification.Ptr) == Win32.CDRF_NOTIFYPOSTPAINT,
        "ListView lost rounded selection when focus moved to a context menu")
    ReportGuiSmokeStage("selection-before-redraw")
    DllCall("user32\RedrawWindow", "Ptr", list.Hwnd, "Ptr", 0,
        "Ptr", 0, "UInt", Win32.RDW_LAYOUT_REFRESH, "Int")
    ReportGuiSmokeStage("selection-after-redraw")
    itemRect := Buffer(16, 0)
    NumPut("Int", 0, itemRect, 0) ; LVIR_BOUNDS：读取整行边界
    AssertGuiSmoke(SendMessage(0x100E, 0, itemRect.Ptr, list.Hwnd),
        "Selected ListView item bounds were not readable")
    listDc := DllCall("user32\GetDC", "Ptr", list.Hwnd, "Ptr")
    try {
        cornerColor := DllCall("gdi32\GetPixel", "Ptr", listDc,
            "Int", NumGet(itemRect, 0, "Int") + 1,
            "Int", NumGet(itemRect, 4, "Int") + 1, "UInt")
        selectedColor := DllCall("gdi32\GetPixel", "Ptr", listDc,
            "Int", NumGet(itemRect, 8, "Int") - Round(14 * dpi / 96),
            "Int", (NumGet(itemRect, 4, "Int")
                + NumGet(itemRect, 12, "Int")) // 2, "UInt")
        AssertGuiSmoke(cornerColor == RoundedButtonRenderer.ColorToBgr(
                UiThemeService.Color("Surface"))
            && selectedColor != RoundedButtonRenderer.ColorToBgr(
                UiThemeService.Color("Surface")),
            "ListView selected row did not preserve rounded surface corners: corner="
                Format("0x{:06X}", cornerColor) " selected="
                Format("0x{:06X}", selectedColor))
    } finally DllCall("user32\ReleaseDC", "Ptr", list.Hwnd,
        "Ptr", listDc)
    ReportGuiSmokeStage("active-selection-pixels")
    list.Modify(1, "Focus Vis")
    AssertGuiSmoke(list.GetNext(0) == 1
            && list.GetNext(0, "Focused") == 1,
        "Right-click context selection should keep the native focus row visible")
    contextRefreshCount := listSelectionPresenter.nativeRefreshCount
    AssertGuiSmoke(listSelectionPresenter.RefreshItem(1),
        "Selected ListView item could not be redrawn before context menu")
    AssertGuiSmoke(listSelectionPresenter.nativeRefreshCount
            == contextRefreshCount,
        "Right-click context selection must redraw the active row without a delayed full-list repaint")
    contextListDc := DllCall("user32\GetDC", "Ptr", list.Hwnd, "Ptr")
    try {
        contextCornerColor := DllCall("gdi32\GetPixel", "Ptr",
            contextListDc, "Int", NumGet(itemRect, 0, "Int") + 1,
            "Int", NumGet(itemRect, 4, "Int") + 1, "UInt")
        contextSelectedColor := DllCall("gdi32\GetPixel", "Ptr",
            contextListDc, "Int",
            NumGet(itemRect, 8, "Int") - Round(14 * dpi / 96),
            "Int", (NumGet(itemRect, 4, "Int")
                + NumGet(itemRect, 12, "Int")) // 2, "UInt")
        AssertGuiSmoke(contextCornerColor
                == RoundedButtonRenderer.ColorToBgr(
                    UiThemeService.Color("Surface"))
            && contextSelectedColor != RoundedButtonRenderer.ColorToBgr(
                UiThemeService.Color("Surface")),
            "ListView right-click selection reverted to a square background")
    } finally DllCall("user32\ReleaseDC", "Ptr", list.Hwnd,
        "Ptr", contextListDc)
    ReportGuiSmokeStage("context-selection-pixels")
    DllCall("user32\SetFocus", "Ptr", ownerEdit.Hwnd, "Ptr")
    AssertGuiSmoke(listSelectionPresenter.RefreshItem(1),
        "Selected ListView item could not be redrawn after losing focus")
    inactiveListDc := DllCall("user32\GetDC", "Ptr", list.Hwnd, "Ptr")
    try {
        inactiveCornerColor := DllCall("gdi32\GetPixel", "Ptr",
            inactiveListDc, "Int", NumGet(itemRect, 0, "Int") + 1,
            "Int", NumGet(itemRect, 4, "Int") + 1, "UInt")
        inactiveSelectedColor := DllCall("gdi32\GetPixel", "Ptr",
            inactiveListDc, "Int",
            NumGet(itemRect, 8, "Int") - Round(14 * dpi / 96),
            "Int", (NumGet(itemRect, 4, "Int")
                + NumGet(itemRect, 12, "Int")) // 2, "UInt")
        AssertGuiSmoke(inactiveCornerColor
                == RoundedButtonRenderer.ColorToBgr(
                    UiThemeService.Color("Surface"))
            && inactiveSelectedColor != RoundedButtonRenderer.ColorToBgr(
                UiThemeService.Color("Surface")),
            "ListView selection reverted to a rectangle after losing focus")
    } finally DllCall("user32\ReleaseDC", "Ptr", list.Hwnd,
        "Ptr", inactiveListDc)
    ReportGuiSmokeStage("list-rendering")
    child := Gui("+Owner" owner.Hwnd " +Resize", "GUI smoke child")
    child.BackColor := "1E1E1E"
    child.Add("Text", "x12 y12 w180 cFFFFFF BackgroundTrans", "Child window")
    child.Show("w260 h140")

    hierarchy := WindowHierarchyManager(WindowHierarchyPlatform())
    taskbarShellAvailable := hierarchy.Platform.IsTaskbarShellAvailable()
    ReportGuiSmokeStage("window-hierarchy", "taskbar="
        (taskbarShellAvailable ? "available" : "unavailable"))
    lease := hierarchy.Acquire(owner, child.Hwnd)
    childExtendedStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
        child.Hwnd, "Int", Win32.GWL_EXSTYLE, "Ptr")
    AssertGuiSmoke(IsObject(lease), "Owner lease was not acquired")
    AssertGuiSmoke(!DllCall("user32\IsWindowEnabled", "Ptr", owner.Hwnd, "Int"),
        "Owner GUI was not disabled while child lease was active")
    AssertGuiSmoke(hierarchy.MinimizeChildIndependently(child.Hwnd),
        "Owned child could not be minimized independently")
    Sleep(30)
    AssertGuiSmoke(DllCall("user32\IsIconic", "Ptr", child.Hwnd, "Int")
        && !DllCall("user32\IsIconic", "Ptr", owner.Hwnd, "Int"),
        "Minimizing an owned child also minimized its owner")
    AssertGuiSmoke(DllCall("user32\IsWindowEnabled", "Ptr", owner.Hwnd, "Int")
        && DllCall("user32\GetActiveWindow", "Ptr") == owner.Hwnd,
        "Minimizing an owned child did not focus its direct owner")
    AssertGuiSmoke(DllCall("user32\GetWindow", "Ptr", child.Hwnd,
            "UInt", 4, "Ptr") == 0,
        "Minimized child retained its native owner")
    minimizedExtendedStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
        child.Hwnd, "Int", Win32.GWL_EXSTYLE, "Ptr")
    AssertGuiSmoke((minimizedExtendedStyle & Win32.WS_EX_APPWINDOW) != 0
        && (minimizedExtendedStyle & Win32.WS_EX_TOOLWINDOW) == 0,
        "Minimized child did not receive a taskbar entry style")
    suspendedChildState := hierarchy.OwnerLocks[owner.Hwnd]
        .SuspendedChildren[child.Hwnd]
    AssertGuiSmoke(suspendedChildState.TaskbarRegistered
            == taskbarShellAvailable,
        taskbarShellAvailable
            ? "Minimized child was not registered in the assistant taskbar group"
            : "Minimized child attempted taskbar registration without a responsive Shell")

    AssertGuiSmoke(hierarchy.PrepareChildRestore(child.Hwnd),
        "Owned child hierarchy was not prepared for restore")
    child.Show()
    Sleep(30)
    AssertGuiSmoke(DllCall("user32\GetWindow", "Ptr", child.Hwnd,
            "UInt", 4, "Ptr") == owner.Hwnd
        && DllCall("user32\GetWindowLongPtrW", "Ptr", child.Hwnd,
            "Int", Win32.GWL_EXSTYLE, "Ptr") == childExtendedStyle
        && !DllCall("user32\IsWindowEnabled", "Ptr", owner.Hwnd, "Int"),
        "Restoring an owned child did not rebuild its modal hierarchy")
    releasedContext := hierarchy.Release(lease)
    hierarchy.CompleteClose(releasedContext)
    AssertGuiSmoke(DllCall("user32\IsWindowEnabled", "Ptr", owner.Hwnd, "Int"),
        "Owner GUI was not restored after child lease release")

    imageList := IL_Create(2, 2, true)
    AssertGuiSmoke(imageList != 0, "ImageList creation failed")
    IL_Destroy(imageList)
} catch as testError {
    ; GUI 测试运行在无人值守的 CI 桌面上，异常必须进入标准错误并退出；
    ; 让 AHK 显示模态错误框会把真实断言伪装成外层超时。
    testFailure := testError.File . " (" . testError.Line . "): "
        . testError.Message . "`n" . testError.Stack
} finally {
    if listSelectionPresenter
        try listSelectionPresenter.Dispose()
    if child
        try child.Destroy()
    if owner
        try owner.Destroy()
    try RoundedButtonRenderer.Shutdown()
}

if testFailure {
    FileAppend(testFailure "`n", "**")
    ExitApp(1)
}

FileAppend("GUI_SMOKE|PASS|dpi=" dpi "|sequenceWidth=" sequenceWidth "`n", "*")
ExitApp(0)
