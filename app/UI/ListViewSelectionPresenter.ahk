; ListView 圆角选中态呈现器。
; 控件仍负责命中测试、键盘导航、多选、拖拽、图标与文字绘制；这里在
; NM_CUSTOMDRAW 后绘制阶段收圆选中背景，不改变列表语义。

class ListViewSelectionPresenter {
    static HorizontalInsetDip := 4
    static VerticalInsetDip := 2
    static RadiusDip := 7

    __New(listView, radiusDip := "", subItemDrawCallback := "") {
        this.listView := listView
        this.subItemDrawCallback := IsObject(subItemDrawCallback)
            ? subItemDrawCallback : ""
        try this.radiusDip := radiusDip == ""
            ? ListViewSelectionPresenter.RadiusDip
            : Max(2, Integer(radiusDip))
        catch
            this.radiusDip := ListViewSelectionPresenter.RadiusDip
        this.notifyCallback := ObjBindMethod(this, "HandleCustomDraw")
        this.nativeRefreshCallback := ObjBindMethod(this,
            "RefreshNativeSurface")
        this.attached := false
        if IsObject(listView) && listView.Hwnd {
            listView.OnNotify(Win32.NM_CUSTOMDRAW, this.notifyCallback)
            this.attached := true
        }
    }

    Dispose(*) {
        try SetTimer(this.nativeRefreshCallback, 0)
        if this.attached
            try this.listView.OnNotify(Win32.NM_CUSTOMDRAW,
                this.notifyCallback, -1)
        this.attached := false
        this.listView := ""
        this.subItemDrawCallback := ""
        this.notifyCallback := ""
        this.nativeRefreshCallback := ""
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
        result := SendMessage(Win32.LVM_REDRAWITEMS, row - 1, row - 1,
            this.listView.Hwnd)
        DllCall("user32\UpdateWindow", "Ptr", this.listView.Hwnd, "Int")
        return result != 0
    }

    ScheduleNativeSurfaceRefresh(delayMs := 15) {
        if !this.attached || !IsObject(this.listView)
            || !this.listView.Hwnd
            return false
        try delayMs := Max(1, Integer(delayMs))
        catch
            delayMs := 15
        ; 多个状态字段常在同一轮一起变化；反复设置同一个单次计时器即可
        ; 合并为一次原生整控件绘制，避免逐行刷新留下断开的列边界。
        SetTimer(this.nativeRefreshCallback, -delayMs)
        return true
    }

    RefreshNativeSurface(*) {
        if !this.attached || !IsObject(this.listView)
            || !this.listView.Hwnd
            return false
        try SetTimer(this.nativeRefreshCallback, 0)
        ; 不自行画线；让 Windows ListView 像搜索窗口一样完成一次原生绘制，
        ; 双缓冲会在整帧完成后提交，列边界因此保持连续且不会闪烁。
        return DllCall("user32\RedrawWindow", "Ptr", this.listView.Hwnd,
            "Ptr", 0, "Ptr", 0, "UInt", Win32.RDW_CONTROL_REFRESH,
            "Int") != 0
    }

    HandleCustomDraw(listView, lParam) {
        if !lParam || !this.attached || listView.Hwnd != this.listView.Hwnd
            return
        drawStageOffset := A_PtrSize == 8 ? 24 : 12
        drawStage := NumGet(lParam, drawStageOffset, "UInt")
        if drawStage == Win32.CDDS_PREPAINT
            return Win32.CDRF_NOTIFYITEMDRAW
        if drawStage == (Win32.CDDS_ITEMPREPAINT | Win32.CDDS_SUBITEM) {
            if IsObject(this.subItemDrawCallback) {
                result := this.subItemDrawCallback.Call(listView, lParam)
                return result
            }
            return
        }
        if drawStage != Win32.CDDS_ITEMPREPAINT
            && drawStage != Win32.CDDS_ITEMPOSTPAINT
            return

        itemStateOffset := A_PtrSize == 8 ? 64 : 40
        itemState := NumGet(lParam, itemStateOffset, "UInt")
        if drawStage == Win32.CDDS_ITEMPREPAINT
                && itemState & Win32.CDIS_FOCUS {
            itemState &= ~Win32.CDIS_FOCUS
            NumPut("UInt", itemState, lParam, itemStateOffset)
        }
        selected := this.IsNotificationItemSelected(listView, lParam,
            itemState)
        if drawStage == Win32.CDDS_ITEMPREPAINT {
            flags := IsObject(this.subItemDrawCallback)
                ? Win32.CDRF_NOTIFYITEMDRAW : Win32.CDRF_DODEFAULT
            return selected ? flags | Win32.CDRF_NOTIFYPOSTPAINT : flags
        }
        if !selected
            return

        this.MaskSelectedRow(listView, lParam)
        return Win32.CDRF_DODEFAULT
    }

    MaskSelectedRow(listView, lParam) {
        itemSpecOffset := A_PtrSize == 8 ? 56 : 36
        itemIndex := NumGet(lParam, itemSpecOffset, "UPtr")
        rowRect := Buffer(16, 0)
        NumPut("Int", Win32.LVIR_BOUNDS, rowRect, 0)
        if !SendMessage(Win32.LVM_GETITEMRECT, itemIndex, rowRect.Ptr,
                listView.Hwnd)
            return false
        hdcOffset := A_PtrSize == 8 ? 32 : 16
        hdc := NumGet(lParam, hdcOffset, "Ptr")
        left := NumGet(rowRect, 0, "Int")
        top := NumGet(rowRect, 4, "Int")
        right := NumGet(rowRect, 8, "Int")
        bottom := NumGet(rowRect, 12, "Int")
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
        radius := Max(3, Round(this.radiusDip
            * windowDpi / 96))
        ; 原生绘制完成后只擦除圆角外侧区域：图标、管理员叠层、状态图标、
        ; 文字、拖拽插入标记和系统选中配色均保持公共控件的原始实现。
        return RoundedButtonRenderer.MaskOutsideRoundedRectangle(hdc,
            left, top, right, bottom,
            left + horizontalInset, top + verticalInset,
            right - horizontalInset, bottom - verticalInset,
            UiThemeService.Color("Surface"), radius)
    }
}
