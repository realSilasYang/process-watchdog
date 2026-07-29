; 短生命周期 GUI 的统一所有权与关闭基类。
; 创建下级窗口时申请层级租约，关闭时先恢复直接上级，再销毁当前窗口并清理控件注册；
; 原生窗口被外部销毁和显式 Close 最终都汇合到同一幂等收尾路径。

class ManagedWindowLifecycle {
    __New(callbacks, hierarchy, guiFactory := "", windowValidator := "") {
        if !IsObject(hierarchy)
            throw TypeError("窗口层级管理器无效")
        this.Hierarchy := hierarchy
        this.RestoreInteractionsCallback := this.RequireCallback(callbacks,
            "RestoreInteractions")
        this.HideTransientWindowsCallback := this.RequireCallback(callbacks,
            "HideTransientWindows")
        this.UnregisterControlsCallback := this.RequireCallback(callbacks,
            "UnregisterControls")
        this.ReleaseIconsCallback := this.RequireCallback(callbacks,
            "ReleaseIcons")
        this.GuiFactory := IsObject(guiFactory) ? guiFactory
            : ObjBindMethod(this, "CreateNativeGui")
        this.WindowValidator := IsObject(windowValidator) ? windowValidator
            : ObjBindMethod(this, "IsNativeWindow")
    }

    RequireCallback(callbacks, name) {
        if !IsObject(callbacks) || !callbacks.HasOwnProp(name)
            || !IsObject(callbacks.%name%)
            throw TypeError("缺少窗口生命周期回调: " name)
        return callbacks.%name%
    }

    PrepareForCreate() {
        this.CallSafely(this.RestoreInteractionsCallback)
        this.CallSafely(this.HideTransientWindowsCallback)
    }

    CreateGui(options, title) {
        return this.GuiFactory.Call(Trim(options), title)
    }

    IsWindow(hwnd) {
        if !hwnd
            return false
        try return !!this.WindowValidator.Call(hwnd)
        catch
            return false
    }

    UnregisterControls(hwnd) {
        if hwnd
            this.CallSafely(this.UnregisterControlsCallback, hwnd)
    }

    ReleaseIcons(hwnd) {
        if hwnd
            this.CallSafely(this.ReleaseIconsCallback, hwnd)
    }

    CallSafely(callback, args*) {
        try callback.Call(args*)
    }

    CreateNativeGui(options, title) {
        return Gui(options, title)
    }

    IsNativeWindow(hwnd) {
        return DllCall("user32\IsWindow", "Ptr", hwnd, "Int") != 0
    }
}

class ManagedWindow {
    static Lifecycle := ""

    gui := ""
    ownerLease := ""

    static ConfigureLifecycle(lifecycle) {
        if !(lifecycle is ManagedWindowLifecycle)
            throw TypeError("托管窗口生命周期适配器无效")
        this.Lifecycle := lifecycle
        return lifecycle
    }

    GetLifecycle() {
        if !(ManagedWindow.Lifecycle is ManagedWindowLifecycle)
            throw Error("托管窗口生命周期尚未配置")
        return ManagedWindow.Lifecycle
    }

    IsOpen() {
        if !this.gui
            return false
        lifecycle := this.GetLifecycle()
        try hwnd := this.gui.Hwnd
        catch
            hwnd := 0
        if lifecycle.IsWindow(hwnd)
            return true

        this.gui := ""
        closeContext := this.ReleaseOwner()
        try {
            if hwnd {
                lifecycle.UnregisterControls(hwnd)
                lifecycle.ReleaseIcons(hwnd)
            }
        } finally lifecycle.Hierarchy.CompleteClose(closeContext)
        return false
    }

    ShowExisting() {
        if !this.IsOpen()
            return false
        lifecycle := this.GetLifecycle()
        lifecycle.Hierarchy.PrepareChildRestore(this.gui.Hwnd)
        if lifecycle.Hierarchy.IsOwnerLocked(this.gui) {
            lifecycle.Hierarchy.ActivateTopOwned(this.gui)
            return true
        }
        this.gui.Show()
        return true
    }

    CreateStandaloneGui(options, title) {
        lifecycle := this.GetLifecycle()
        lifecycle.PrepareForCreate()
        this.ReleaseStaleOwner(lifecycle)
        try this.gui := lifecycle.CreateGui(options, title)
        catch as createErr {
            this.gui := ""
            throw createErr
        }
        return true
    }

    CreateOwnedGui(ownerGui, options, title) {
        lifecycle := this.GetLifecycle()
        lifecycle.PrepareForCreate()
        this.ReleaseStaleOwner(lifecycle)
        try this.gui := lifecycle.CreateGui(
            "+Owner" ownerGui.Hwnd " " options, title)
        catch as createErr {
            this.gui := ""
            throw createErr
        }
        this.ownerLease := lifecycle.Hierarchy.Acquire(ownerGui,
            this.gui.Hwnd)
        if !this.ownerLease {
            this.DestroyGui()
            return false
        }
        return true
    }

    ReleaseStaleOwner(lifecycle) {
        if !this.ownerLease
            return
        closeContext := this.ReleaseOwner()
        lifecycle.Hierarchy.CompleteClose(closeContext)
    }

    ReleaseOwner() {
        if !this.ownerLease
            return ""
        lifecycle := this.GetLifecycle()
        ownerLease := this.ownerLease
        this.ownerLease := ""
        return lifecycle.Hierarchy.Release(ownerLease)
    }

    DestroyGui() {
        lifecycle := this.GetLifecycle()
        ; 标准模态关闭顺序：先恢复直接上级，再销毁下级，最后交还前台焦点。
        closeContext := this.ReleaseOwner()
        try {
            if !this.gui
                return
            guiObj := this.gui
            this.gui := ""
            try hwnd := guiObj.Hwnd
            catch
                hwnd := 0
            try {
                lifecycle.UnregisterControls(hwnd)
                try guiObj.Destroy()
            } finally lifecycle.ReleaseIcons(hwnd)
        } finally lifecycle.Hierarchy.CompleteClose(closeContext)
    }
}
