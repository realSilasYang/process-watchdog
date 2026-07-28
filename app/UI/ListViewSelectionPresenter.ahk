; ListView 选中态与列边界呈现器。
; 控件仍负责命中测试、键盘导航、多选、拖拽、图标与文字绘制；这里在
; NM_CUSTOMDRAW 后绘制阶段收圆选中背景并补齐连续列线，不改变列表语义。

class ListViewSelectionPresenter {
    static HorizontalInsetDip := 4
    static VerticalInsetDip := 2
    static RadiusDip := 7

    __New(listView) {
        this.listView := listView
        this.notifyCallback := ObjBindMethod(this, "HandleCustomDraw")
        this.attached := false
        this.separatorXs := []
        this.separatorClientTop := 0
        this.separatorClientBottom := 0
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
        this.separatorXs := []
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

    PrepareColumnSeparators(listView) {
        this.separatorXs := []
        this.separatorClientTop := 0
        this.separatorClientBottom := 0
        if !IsObject(listView) || !listView.Hwnd
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

        boundaryX := clientLeft
        for visibleIndex, width in visibleWidths {
            boundaryX += width
            if visibleIndex >= visibleWidths.Length
                break
            lineX := boundaryX - 1
            if lineX >= clientLeft && lineX < clientRight
                this.separatorXs.Push(lineX)
        }
        this.separatorClientTop := clientTop
        this.separatorClientBottom := clientBottom
        return true
    }

    DrawColumnSeparators(hdc, requestedTop := "",
        requestedBottom := "") {
        if !hdc || !this.separatorXs.Length
            return false
        drawTop := requestedTop == ""
            ? this.separatorClientTop
            : Max(this.separatorClientTop, Integer(requestedTop))
        drawBottom := requestedBottom == ""
            ? this.separatorClientBottom
            : Min(this.separatorClientBottom, Integer(requestedBottom))
        if drawBottom <= drawTop
            return true

        ; DC_BRUSH 随绘制上下文复用，不在滚动和选择重绘中反复创建 GDI 对象。
        brush := DllCall("gdi32\GetStockObject", "Int", Win32.DC_BRUSH,
            "Ptr")
        if !brush
            return false
        previousBrushColor := DllCall("gdi32\SetDCBrushColor", "Ptr", hdc,
            "UInt", RoundedButtonRenderer.ColorToBgr(
                UiThemeService.Color("Divider")), "UInt")
        separatorRect := Buffer(16, 0)
        try {
            for lineX in this.separatorXs {
                NumPut("Int", lineX, separatorRect, 0)
                NumPut("Int", drawTop, separatorRect, 4)
                NumPut("Int", lineX + 1, separatorRect, 8)
                NumPut("Int", drawBottom, separatorRect, 12)
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
        if drawStage == Win32.CDDS_PREPAINT {
            this.PrepareColumnSeparators(listView)
            return Win32.CDRF_NOTIFYITEMDRAW
                | Win32.CDRF_NOTIFYPOSTPAINT
        }
        if drawStage == Win32.CDDS_POSTPAINT {
            hdcOffset := A_PtrSize == 8 ? 32 : 16
            hdc := NumGet(lParam, hdcOffset, "Ptr")
            this.DrawColumnSeparators(hdc)
            return Win32.CDRF_DODEFAULT
        }
        if drawStage != Win32.CDDS_ITEMPREPAINT
            && drawStage != Win32.CDDS_ITEMPOSTPAINT
            return
        if drawStage == Win32.CDDS_ITEMPREPAINT
            ; 每一行都必须进入后绘制。控件级 POSTPAINT 的裁剪区通常排除
            ; 条目区域，单靠它画出的竖线会在每一行处断开。
            return Win32.CDRF_NOTIFYPOSTPAINT

        itemStateOffset := A_PtrSize == 8 ? 64 : 40
        itemState := NumGet(lParam, itemStateOffset, "UInt")
        selected := this.IsNotificationItemSelected(listView, lParam,
            itemState)
        hdcOffset := A_PtrSize == 8 ? 32 : 16
        rectOffset := A_PtrSize == 8 ? 40 : 20
        hdc := NumGet(lParam, hdcOffset, "Ptr")
        left := NumGet(lParam, rectOffset, "Int")
        top := NumGet(lParam, rectOffset + 4, "Int")
        right := NumGet(lParam, rectOffset + 8, "Int")
        bottom := NumGet(lParam, rectOffset + 12, "Int")
        if selected {
            windowDpi := DllCall("user32\GetDpiForWindow", "Ptr",
                listView.Hwnd, "UInt")
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
        }
        ; 最后覆盖本行的两段列边界，选中底色和圆角遮罩都不会再截断它们。
        this.DrawColumnSeparators(hdc, top, bottom)
        return Win32.CDRF_DODEFAULT
    }
}
