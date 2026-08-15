; ListView 空白区域的焦点交接。
; 选中状态与键盘焦点是两个独立状态：点击空白区域只移除焦点，保留选择，
; 让后续命令仍可作用于用户刚才选中的守护对象。
class ListViewFocusService {
    static NoAction := 0
    static Handled := 1
    static SuppressDefault := 2

    static PrepareContextSelection(listView, item) {
        if !IsObject(listView) || !listView.Hwnd
                || item < 1 || item > listView.GetCount()
            return false
        itemIsSelected := (SendMessage(Win32.LVM_GETITEMSTATE, item - 1,
            Win32.LVIS_SELECTED, listView.Hwnd) & Win32.LVIS_SELECTED) != 0
        ; 右键已选行时保留整个多选集合，供批量命令使用；右键未选行时
        ; 才切换为单选，避免命令误作用于此前的选择。
        if !itemIsSelected {
            listView.Modify(0, "-Select")
            listView.Modify(item, "Select Focus Vis")
        } else {
            listView.Modify(item, "Focus Vis")
        }
        return itemIsSelected
    }

    static HandleBlankPointerDown(listView, rootHwnd, pointerHwnd, lParam,
        pointerMessage, passiveSurfaceHwnds := "") {
        ; 标题栏按钮、标题栏拖动和窗口边框都使用非客户区鼠标消息。
        ; OnMessage 回调返回非空值会吞掉 Windows 默认处理，因此这里必须在
        ; 查看窗口句柄前就明确拒绝 WM_NCLBUTTONDOWN 等非客户区消息。
        if pointerMessage != Win32.WM_LBUTTONDOWN
            return this.NoAction
        if !IsObject(listView) || !listView.Hwnd || !rootHwnd
            return this.NoAction

        suppressDefault := false
        if pointerHwnd == listView.Hwnd {
            ; ListView 的空白区默认处理仍会重新设置键盘焦点；命中空白区时
            ; 必须拦截本次按下消息，才能让焦点稳定留在主窗口。
            if !this.IsBlankListPoint(listView.Hwnd, lParam)
                return this.NoAction
            suppressDefault := true
        } else if pointerHwnd != rootHwnd
            && !this.IsPassiveSurface(pointerHwnd, passiveSurfaceHwnds) {
            return this.NoAction
        }

        if !DllCall("user32\IsWindow", "Ptr", rootHwnd, "Int")
            || !DllCall("user32\IsWindowEnabled", "Ptr", rootHwnd, "Int")
            return this.NoAction

        focusTarget := this.ResolveFocusTarget(rootHwnd, pointerHwnd,
            passiveSurfaceHwnds)
        DllCall("user32\SetFocus", "Ptr", focusTarget, "Ptr")
        this.ClearFocusedItem(listView.Hwnd)
        DllCall("user32\RedrawWindow", "Ptr", listView.Hwnd, "Ptr", 0,
            "Ptr", 0, "UInt", Win32.RDW_CONTROL_REFRESH, "Int")
        return suppressDefault ? this.SuppressDefault : this.Handled
    }

    static ClearFocusedItem(listHwnd) {
        ; Gui.ListView.Modify(0, "-Focus") 不会可靠地把 Focus 选项批量应用
        ; 到全部条目。LVM_SETITEMSTATE 的 -1 索引是公共控件明确支持的
        ; “全部条目”入口，只清 LVIS_FOCUSED，不改变 LVIS_SELECTED。
        item := Buffer(A_PtrSize == 8 ? 88 : 60, 0)
        NumPut("UInt", 0, item, 12)
        NumPut("UInt", Win32.LVIS_FOCUSED, item, 16)
        return SendMessage(Win32.LVM_SETITEMSTATE, -1, item.Ptr, listHwnd) != 0
    }

    static IsPassiveSurface(hwnd, surfaces) {
        if !IsObject(surfaces)
            return false
        for surfaceHwnd in surfaces {
            if hwnd == surfaceHwnd
                return true
        }
        return false
    }

    static ResolveFocusTarget(rootHwnd, pointerHwnd, surfaces) {
        ; 顶层 GUI 收到焦点后，Windows 对话框管理器会恢复上次获得焦点的
        ; 子控件，通常正是 ListView。使用可见但不可操作的状态栏 STATIC
        ; 作为焦点落点，既不显示输入焦点，也不会立即跳回列表。
        if this.IsPassiveSurface(pointerHwnd, surfaces)
            return pointerHwnd
        if IsObject(surfaces) {
            for surfaceHwnd in surfaces {
                if surfaceHwnd
                    && DllCall("user32\IsWindowVisible", "Ptr", surfaceHwnd,
                        "Int")
                    && DllCall("user32\IsWindowEnabled", "Ptr", surfaceHwnd,
                        "Int")
                    return surfaceHwnd
            }
        }
        return rootHwnd
    }

    static IsBlankListPoint(listHwnd, lParam) {
        point := Buffer(24, 0)
        NumPut("Int", this.SignedWord(lParam & 0xFFFF), point, 0)
        NumPut("Int", this.SignedWord((lParam >> 16) & 0xFFFF), point, 4)
        return SendMessage(Win32.LVM_HITTEST, 0, point.Ptr, listHwnd) < 0
    }

    static SignedWord(value) {
        return value & 0x8000 ? value - 0x10000 : value
    }
}
