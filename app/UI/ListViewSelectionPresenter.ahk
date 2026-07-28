; ListView 圆角选中态呈现器。
; 控件仍负责命中测试、键盘导航、多选、拖拽、图标与文字绘制；这里仅在
; NM_CUSTOMDRAW 的条目预绘制阶段替换原生矩形选中底色，因此不会改变列表语义。

class ListViewSelectionPresenter {
    static HorizontalInsetDip := 4
    static VerticalInsetDip := 2
    static RadiusDip := 7

    __New(listView) {
        this.listView := listView
        this.notifyCallback := ObjBindMethod(this, "HandleCustomDraw")
        this.attached := false
        if IsObject(listView) && listView.Hwnd {
            listView.OnNotify(Win32.NM_CUSTOMDRAW, this.notifyCallback)
            this.attached := true
        }
    }

    Dispose(*) {
        if !this.attached
            return
        this.attached := false
        try this.listView.OnNotify(Win32.NM_CUSTOMDRAW,
            this.notifyCallback, -1)
        this.listView := ""
        this.notifyCallback := ""
    }

    IsNotificationItemSelected(listView, lParam, itemState) {
        if itemState & Win32.CDIS_SELECTED
            return true
        ; 弹出菜单接管焦点后，NMCUSTOMDRAW.uItemState 可能暂时丢失
        ; CDIS_SELECTED；以 ListView 自身保存的行状态为准，避免圆角遮罩消失。
        itemSpecOffset := A_PtrSize == 8 ? 56 : 36
        itemIndex := NumGet(lParam, itemSpecOffset, "UPtr")
        return (SendMessage(Win32.LVM_GETITEMSTATE, itemIndex,
            Win32.LVIS_SELECTED, listView.Hwnd) & Win32.LVIS_SELECTED) != 0
    }

    RefreshItem(row) {
        if !this.attached || row <= 0 || row > this.listView.GetCount()
            return false
        itemIndex := row - 1
        redrawRequested := SendMessage(Win32.LVM_REDRAWITEMS,
            itemIndex, itemIndex, this.listView.Hwnd)
        DllCall("user32\UpdateWindow", "Ptr", this.listView.Hwnd, "Int")
        return redrawRequested != 0
    }

    DrawColumnSeparators(listView, hdc) {
        if !hdc || !IsObject(listView) || !listView.Hwnd
            return false
        hHeader := SendMessage(Win32.LVM_GETHEADER, 0, 0, listView.Hwnd)
        if !hHeader
            return false
        ; 隐藏的原生表头仍持有列顺序和实时像素宽度。
        columnCount := SendMessage(Win32.HDM_GETITEMCOUNT, 0, 0, hHeader)
        if columnCount <= 1
            return true
        order := Buffer(columnCount * 4, 0)
        if !SendMessage(Win32.LVM_GETCOLUMNORDERARRAY, columnCount,
                order.Ptr, listView.Hwnd)
            return false

        visibleWidths := []
        Loop columnCount {
            columnIndex := NumGet(order, (A_Index - 1) * 4, "Int")
            width := SendMessage(Win32.LVM_GETCOLUMNWIDTH, columnIndex,
                0, listView.Hwnd)
            if width > 0
                visibleWidths.Push(width)
        }
        if visibleWidths.Length <= 1
            return true

        clientRect := Buffer(16, 0)
        if !DllCall("user32\GetClientRect", "Ptr", listView.Hwnd,
                "Ptr", clientRect, "Int")
            return false
        clientLeft := NumGet(clientRect, 0, "Int")
        clientTop := NumGet(clientRect, 4, "Int")
        clientRight := NumGet(clientRect, 8, "Int")
        clientBottom := NumGet(clientRect, 12, "Int")
        if clientRight <= clientLeft || clientBottom <= clientTop
            return false

        ; DC_BRUSH 随绘制上下文复用，不在滚动和选择重绘中反复创建 GDI 对象。
        brush := DllCall("gdi32\GetStockObject", "Int", Win32.DC_BRUSH,
            "Ptr")
        if !brush
            return false
        previousBrushColor := DllCall("gdi32\SetDCBrushColor", "Ptr", hdc,
            "UInt", RoundedButtonRenderer.ColorToBgr(
                UiThemeService.Color("Divider")), "UInt")
        separatorRect := Buffer(16, 0)
        boundaryX := clientLeft
        try {
            for visibleIndex, width in visibleWidths {
                boundaryX += width
                if visibleIndex >= visibleWidths.Length
                    break
                ; 边界落在左列最后一个像素上，与原生报表视图的列线对齐。
                lineX := boundaryX - 1
                if lineX < clientLeft || lineX >= clientRight
                    continue
                NumPut("Int", lineX, separatorRect, 0)
                NumPut("Int", clientTop, separatorRect, 4)
                NumPut("Int", lineX + 1, separatorRect, 8)
                NumPut("Int", clientBottom, separatorRect, 12)
                DllCall("user32\FillRect", "Ptr", hdc,
                    "Ptr", separatorRect, "Ptr", brush, "Int")
            }
        } finally DllCall("gdi32\SetDCBrushColor", "Ptr", hdc,
            "UInt", previousBrushColor, "UInt")
        return true
    }

    HandleCustomDraw(listView, lParam) {
        if !lParam || !this.attached || listView.Hwnd != this.listView.Hwnd
            return
        drawStageOffset := A_PtrSize == 8 ? 24 : 12
        drawStage := NumGet(lParam, drawStageOffset, "UInt")
        if drawStage == Win32.CDDS_PREPAINT
            return Win32.CDRF_NOTIFYITEMDRAW
                | Win32.CDRF_NOTIFYPOSTPAINT
        if drawStage == Win32.CDDS_POSTPAINT {
            hdcOffset := A_PtrSize == 8 ? 32 : 16
            hdc := NumGet(lParam, hdcOffset, "Ptr")
            this.DrawColumnSeparators(listView, hdc)
            return Win32.CDRF_DODEFAULT
        }
        if drawStage != Win32.CDDS_ITEMPREPAINT
            && drawStage != Win32.CDDS_ITEMPOSTPAINT
            return

        itemStateOffset := A_PtrSize == 8 ? 64 : 40
        itemState := NumGet(lParam, itemStateOffset, "UInt")
        if !this.IsNotificationItemSelected(listView, lParam, itemState)
            return
        if drawStage == Win32.CDDS_ITEMPREPAINT
            return Win32.CDRF_NOTIFYPOSTPAINT

        hdcOffset := A_PtrSize == 8 ? 32 : 16
        rectOffset := A_PtrSize == 8 ? 40 : 20
        hdc := NumGet(lParam, hdcOffset, "Ptr")
        left := NumGet(lParam, rectOffset, "Int")
        top := NumGet(lParam, rectOffset + 4, "Int")
        right := NumGet(lParam, rectOffset + 8, "Int")
        bottom := NumGet(lParam, rectOffset + 12, "Int")
        windowDpi := DllCall("user32\GetDpiForWindow", "Ptr", listView.Hwnd,
            "UInt")
        if !windowDpi
            windowDpi := 96
        horizontalInset := Max(2,
            Round(ListViewSelectionPresenter.HorizontalInsetDip
                * windowDpi / 96))
        verticalInset := Max(1,
            Round(ListViewSelectionPresenter.VerticalInsetDip
                * windowDpi / 96))
        radius := Max(3, Round(ListViewSelectionPresenter.RadiusDip
            * windowDpi / 96))
        ; 原生绘制完成后只擦除圆角外侧区域：图标、管理员叠层、状态图标、
        ; 文字、拖拽插入标记和系统选中配色均保持公共控件的原始实现。
        RoundedButtonRenderer.MaskOutsideRoundedRectangle(hdc,
            left, top, right, bottom,
            left + horizontalInset, top + verticalInset,
            right - horizontalInset, bottom - verticalInset,
            UiThemeService.Color("Surface"), radius)
        return Win32.CDRF_DODEFAULT
    }
}
