; 主列表原位路径编辑框的深色主题注册与原生子类生命周期。
; WM_CTLCOLOREDIT 会发送给编辑框的直接父窗口，因此 ListView 标签编辑必须在
; ListView 子类中处理，不能依赖顶层窗口消息钩子。
class DarkInlineEditThemeRegistry {
    static EditHandles := Map()
    static ListViews := Map()
    static SubclassId := 0x44494554 ; 子类标识 "DIET"
    static CallbackPtr := 0

    static EnsureCallback() {
        if this.CallbackPtr
            return true
        try this.CallbackPtr := CallbackCreate(
            DarkInlineEditThemeListViewProc, "", 6)
        catch
            this.CallbackPtr := 0
        return this.CallbackPtr != 0
    }

    static EnsureListViewSubclass(hListView) {
        if this.ListViews.Has(hListView)
            return true
        if !this.EnsureCallback()
            return false
        if !DllCall("comctl32\SetWindowSubclass", "Ptr", hListView,
            "Ptr", this.CallbackPtr, "UPtr", this.SubclassId,
            "UPtr", 0, "Int") {
            return false
        }
        this.ListViews[hListView] := 0
        return true
    }

    static Register(hEdit, hListView) {
        if !hEdit || !hListView
            || !DllCall("user32\IsWindow", "Ptr", hEdit, "Int")
            || !DllCall("user32\IsWindow", "Ptr", hListView, "Int") {
            return false
        }

        if this.EditHandles.Has(hEdit) {
            previousListView := this.EditHandles[hEdit]
            if previousListView != hListView
                this.Unregister(hEdit)
            else {
                this.ApplyAppearance(hEdit)
                return true
            }
        }
        if !this.EnsureListViewSubclass(hListView)
            return false

        this.EditHandles[hEdit] := hListView
        this.ListViews[hListView] += 1
        this.ApplyAppearance(hEdit)
        return true
    }

    static ApplyAppearance(hEdit) {
        ApplyDarkControlTheme(hEdit, UiThemeService.GetExplorerThemeName())
        DllCall("user32\RedrawWindow", "Ptr", hEdit, "Ptr", 0,
            "Ptr", 0, "UInt", Win32.RDW_CONTROL_REFRESH, "Int")
    }

    static Refresh(hEdit) {
        if !hEdit || !this.EditHandles.Has(hEdit)
            return false
        hListView := this.EditHandles[hEdit]
        if !DllCall("user32\IsWindow", "Ptr", hEdit, "Int")
            || !DllCall("user32\IsWindow", "Ptr", hListView, "Int") {
            this.Unregister(hEdit)
            return false
        }
        this.ApplyAppearance(hEdit)
        return true
    }

    static Unregister(hEdit) {
        if !hEdit || !this.EditHandles.Has(hEdit)
            return false
        hListView := this.EditHandles[hEdit]
        this.EditHandles.Delete(hEdit)
        if this.ListViews.Has(hListView) {
            remainingEdits := Max(0, this.ListViews[hListView] - 1)
            if remainingEdits
                this.ListViews[hListView] := remainingEdits
            else
                this.DetachListView(hListView)
        }
        return true
    }

    static DetachListView(hListView) {
        if this.ListViews.Has(hListView)
            this.ListViews.Delete(hListView)
        if hListView && this.CallbackPtr
            && DllCall("user32\IsWindow", "Ptr", hListView, "Int") {
            DllCall("comctl32\RemoveWindowSubclass", "Ptr", hListView,
                "Ptr", this.CallbackPtr, "UPtr", this.SubclassId, "Int")
        }
    }

    static HandleListViewDestroyed(hListView) {
        staleEdits := []
        for hEdit, ownerListView in this.EditHandles {
            if ownerListView == hListView
                staleEdits.Push(hEdit)
        }
        for hEdit in staleEdits
            this.EditHandles.Delete(hEdit)
        this.DetachListView(hListView)
    }

    static HandleEditColor(hListView, deviceContext, editHwnd) {
        if !deviceContext || !editHwnd
            || !this.EditHandles.Has(editHwnd)
            || this.EditHandles[editHwnd] != hListView {
            return 0
        }
        backgroundColor := ColorRefFromHex(UiThemeService.Color("Input"))
        textColor := ColorRefFromHex(UiThemeService.Color("Text"))
        DllCall("gdi32\SetTextColor", "Ptr", deviceContext,
            "UInt", textColor)
        DllCall("gdi32\SetBkColor", "Ptr", deviceContext,
            "UInt", backgroundColor)
        DllCall("gdi32\SetDCBrushColor", "Ptr", deviceContext,
            "UInt", backgroundColor)
        return DllCall("gdi32\GetStockObject", "Int", 18, "Ptr")
    }

}

DarkInlineEditThemeListViewProc(hWnd, message, wParam, lParam,
    subclassId, referenceData) {
    try {
        switch message {
            case 0x0133: ; 编辑框颜色消息 WM_CTLCOLOREDIT
                brush := DarkInlineEditThemeRegistry.HandleEditColor(
                    hWnd, wParam, lParam)
                if brush
                    return brush
            case 0x0082: ; 窗口销毁消息 WM_NCDESTROY
                DarkInlineEditThemeRegistry.HandleListViewDestroyed(hWnd)
        }
    } catch {
        ; 不允许 AHK 异常越过原生回调边界。
    }
    return DllCall("comctl32\DefSubclassProc", "Ptr", hWnd,
        "UInt", message, "UPtr", wParam, "Ptr", lParam, "Ptr")
}
