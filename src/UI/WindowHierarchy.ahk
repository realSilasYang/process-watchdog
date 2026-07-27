; 多级窗口所有权、模态租约和独立最小化管理器。
; 每个下级窗口只禁用直接上级，关闭时按租约恢复原状态；最小化前临时解除原生 Owner，
; 避免 Windows 连带最小化主窗口，恢复后再重建正确层级和前台焦点。

class WindowHierarchyPlatform {
    IsGuiAlive(guiObj) {
        if !guiObj || Type(guiObj) != "Gui"
            return false
        try return this.IsWindow(guiObj.Hwnd)
        catch
            return false
    }

    GetHwnd(guiObj) {
        return guiObj.Hwnd
    }

    IsWindow(hwnd) {
        return hwnd && DllCall("user32\IsWindow", "Ptr", hwnd, "Int") != 0
    }

    IsWindowEnabled(hwnd) {
        return DllCall("user32\IsWindowEnabled", "Ptr", hwnd, "Int") != 0
    }

    SetGuiEnabled(guiObj, enabled) {
        guiObj.Opt(enabled ? "-Disabled" : "+Disabled")
    }

    IsWindowVisible(hwnd) {
        return DllCall("user32\IsWindowVisible", "Ptr", hwnd, "Int") != 0
    }

    IsWindowMinimized(hwnd) {
        return DllCall("user32\IsIconic", "Ptr", hwnd, "Int") != 0
    }

    GetNativeOwner(childHwnd) {
        return DllCall("user32\GetWindowLongPtrW", "Ptr", childHwnd,
            "Int", Win32.GWLP_HWNDPARENT, "Ptr")
    }

    SetNativeOwner(childHwnd, ownerHwnd) {
        return DllCall("user32\SetWindowLongPtrW", "Ptr", childHwnd,
            "Int", Win32.GWLP_HWNDPARENT, "Ptr", ownerHwnd, "Ptr")
    }

    MinimizeWindow(hwnd) {
        return DllCall("user32\ShowWindow", "Ptr", hwnd,
            "Int", Win32.SW_MINIMIZE, "Int")
    }

    GetOwnedWindowOwner(childHwnd) {
        return DllCall("user32\GetWindow", "Ptr", childHwnd,
            "UInt", 4, "Ptr") ; GW_OWNER：查询下级窗口当前登记的原生所有者。
    }

    GetLastActivePopup(hwnd) {
        return DllCall("user32\GetLastActivePopup", "Ptr", hwnd, "Ptr")
    }

    ActivateOwnedWindow(hwnd) {
        WinActivate("ahk_id " hwnd)
    }

    ActivateOwnerWindow(hwnd) {
        DllCall("user32\SetForegroundWindow", "Ptr", hwnd, "Int")
        DllCall("user32\SetActiveWindow", "Ptr", hwnd, "Ptr")
    }
}

class WindowHierarchyManager {
    __New(platform) {
        if !IsObject(platform)
            throw TypeError("窗口层级平台适配器无效")
        this.Platform := platform
        this.OwnerLocks := Map()
    }

    IsGuiAlive(guiObj) {
        try return this.Platform.IsGuiAlive(guiObj)
        catch
            return false
    }

    FindOwnerHwnd(childHwnd) {
        if !childHwnd
            return 0
        for ownerHwnd, entry in this.OwnerLocks {
            if entry.Children.Has(childHwnd)
                return ownerHwnd
        }
        return 0
    }

    MinimizeChildIndependently(childHwnd) {
        ownerHwnd := this.FindOwnerHwnd(childHwnd)
        if !ownerHwnd || !this.Platform.IsWindow(childHwnd)
            || !this.Platform.IsWindow(ownerHwnd)
            return false
        if (this.Platform.GetNativeOwner(childHwnd) != ownerHwnd)
            return false

        ; Win32 会把带 Owner 的窗口作为一个激活组处理。最小化命令执行期间
        ; 临时解除原生 Owner，只改变下级窗口的显示状态，随后立即恢复层级关系。
        detached := false
        try {
            this.Platform.SetNativeOwner(childHwnd, 0)
            detached := true
            this.Platform.MinimizeWindow(childHwnd)
        } catch {
            return false
        } finally {
            if detached && this.Platform.IsWindow(childHwnd)
                && this.Platform.IsWindow(ownerHwnd)
                try this.Platform.SetNativeOwner(childHwnd, ownerHwnd)
        }
        return true
    }

    Acquire(ownerGui, childHwnd := 0) {
        if !this.IsGuiAlive(ownerGui)
            return ""
        try ownerHwnd := this.Platform.GetHwnd(ownerGui)
        catch
            return ""
        this.PruneOwner(ownerGui)
        if this.OwnerLocks.Has(ownerHwnd) {
            entry := this.OwnerLocks[ownerHwnd]
            if (entry.Gui == ownerGui) {
                entry.Count++
                this.AddChildReference(entry, childHwnd)
                return this.CreateLease(ownerHwnd, childHwnd)
            }
            this.OwnerLocks.Delete(ownerHwnd)
        }

        wasEnabled := this.Platform.IsWindowEnabled(ownerHwnd)
        entry := {
            Gui: ownerGui,
            Count: 1,
            RestoreEnabled: wasEnabled,
            Children: Map()
        }
        this.AddChildReference(entry, childHwnd)
        this.OwnerLocks[ownerHwnd] := entry
        if wasEnabled {
            try this.Platform.SetGuiEnabled(ownerGui, false)
            catch {
                this.OwnerLocks.Delete(ownerHwnd)
                return ""
            }
        }
        return this.CreateLease(ownerHwnd, childHwnd)
    }

    Release(lease) {
        if !this.IsValidLease(lease) || lease.Released
            return ""
        lease.Released := true
        ownerHwnd := lease.OwnerHwnd
        if !this.OwnerLocks.Has(ownerHwnd)
            return ""

        entry := this.OwnerLocks[ownerHwnd]
        this.RemoveChildReference(entry, lease.ChildHwnd)
        entry.Count--
        if (entry.Count > 0)
            return {Mode: "child", Owner: entry.Gui}

        this.OwnerLocks.Delete(ownerHwnd)
        return this.RestoreOwner(entry, ownerHwnd)
    }

    CompleteClose(closeContext) {
        if !IsObject(closeContext) || !closeContext.HasOwnProp("Mode")
            return
        if (closeContext.Mode == "child") {
            if closeContext.HasOwnProp("Owner")
                this.ActivateTopOwned(closeContext.Owner)
            return
        }
        if (closeContext.Mode != "owner")
            return
        if !closeContext.HasOwnProp("Activate") || !closeContext.Activate
            return
        if !closeContext.HasOwnProp("Owner")
            || !this.IsGuiAlive(closeContext.Owner)
            return
        if !closeContext.HasOwnProp("OwnerHwnd")
            return
        ownerHwnd := closeContext.OwnerHwnd
        if !this.Platform.IsWindowVisible(ownerHwnd)
            || this.Platform.IsWindowMinimized(ownerHwnd)
            return
        try this.Platform.ActivateOwnerWindow(ownerHwnd)
    }

    PruneOwner(ownerGui) {
        if !this.IsGuiAlive(ownerGui)
            return false
        try ownerHwnd := this.Platform.GetHwnd(ownerGui)
        catch
            return false
        if !this.OwnerLocks.Has(ownerHwnd)
            return false
        entry := this.OwnerLocks[ownerHwnd]
        if (entry.Gui != ownerGui) {
            this.OwnerLocks.Delete(ownerHwnd)
            return false
        }

        staleChildren := []
        for childHwnd, referenceCount in entry.Children {
            if !this.Platform.IsWindow(childHwnd)
                || this.Platform.GetOwnedWindowOwner(childHwnd) != ownerHwnd
                staleChildren.Push({Hwnd: childHwnd, Count: referenceCount})
        }
        for staleChild in staleChildren {
            entry.Children.Delete(staleChild.Hwnd)
            entry.Count -= staleChild.Count
        }
        if (entry.Count > 0)
            return true

        this.OwnerLocks.Delete(ownerHwnd)
        closeContext := this.RestoreOwner(entry, ownerHwnd)
        this.CompleteClose(closeContext)
        return false
    }

    IsOwnerLocked(ownerGui) {
        return this.IsGuiAlive(ownerGui) && this.PruneOwner(ownerGui)
    }

    ActivateTopOwned(ownerGui) {
        if !this.IsGuiAlive(ownerGui)
            return false
        this.PruneOwner(ownerGui)
        ownerHwnd := this.Platform.GetHwnd(ownerGui)
        currentHwnd := ownerHwnd
        visited := Map()
        Loop 16 {
            if visited.Has(currentHwnd) || !this.OwnerLocks.Has(currentHwnd)
                break
            visited[currentHwnd] := true
            entry := this.OwnerLocks[currentHwnd]
            this.PruneOwner(entry.Gui)
            if !this.OwnerLocks.Has(currentHwnd)
                break
            entry := this.OwnerLocks[currentHwnd]
            nextHwnd := this.FindVisibleChild(entry, currentHwnd)
            if !nextHwnd
                break
            currentHwnd := nextHwnd
        }
        if (currentHwnd == ownerHwnd)
            return false
        if !this.Platform.IsWindowVisible(currentHwnd)
            return false
        try this.Platform.ActivateOwnedWindow(currentHwnd)
        return true
    }

    AddChildReference(entry, childHwnd) {
        if !childHwnd
            return
        entry.Children[childHwnd] := entry.Children.Get(childHwnd, 0) + 1
    }

    RemoveChildReference(entry, childHwnd) {
        if !childHwnd || !entry.Children.Has(childHwnd)
            return
        referenceCount := entry.Children[childHwnd] - 1
        if (referenceCount > 0)
            entry.Children[childHwnd] := referenceCount
        else
            entry.Children.Delete(childHwnd)
    }

    CreateLease(ownerHwnd, childHwnd) {
        return {
            OwnerHwnd: ownerHwnd,
            ChildHwnd: childHwnd,
            Released: false
        }
    }

    IsValidLease(lease) {
        return IsObject(lease)
            && lease.HasOwnProp("OwnerHwnd")
            && lease.HasOwnProp("ChildHwnd")
            && lease.HasOwnProp("Released")
    }

    RestoreOwner(entry, ownerHwnd) {
        wasVisible := this.Platform.IsWindowVisible(ownerHwnd)
        wasMinimized := this.Platform.IsWindowMinimized(ownerHwnd)
        if entry.RestoreEnabled && this.IsGuiAlive(entry.Gui)
            try this.Platform.SetGuiEnabled(entry.Gui, true)
        return {
            Mode: "owner",
            Owner: entry.Gui,
            OwnerHwnd: ownerHwnd,
            Activate: entry.RestoreEnabled && wasVisible && !wasMinimized
        }
    }

    FindVisibleChild(entry, ownerHwnd) {
        activePopup := this.Platform.GetLastActivePopup(ownerHwnd)
        if entry.Children.Has(activePopup)
            && this.Platform.IsWindowVisible(activePopup)
            return activePopup
        for childHwnd in entry.Children {
            if this.Platform.IsWindowVisible(childHwnd)
                return childHwnd
        }
        return 0
    }
}

class WindowHierarchy {
    static Manager := WindowHierarchyManager(WindowHierarchyPlatform())

    static IsGuiAlive(guiObj) {
        return this.Manager.IsGuiAlive(guiObj)
    }

    static FindOwnerHwnd(childHwnd) {
        return this.Manager.FindOwnerHwnd(childHwnd)
    }

    static MinimizeChildIndependently(childHwnd) {
        return this.Manager.MinimizeChildIndependently(childHwnd)
    }

    static Acquire(ownerGui, childHwnd := 0) {
        return this.Manager.Acquire(ownerGui, childHwnd)
    }

    static Release(lease) {
        return this.Manager.Release(lease)
    }

    static CompleteClose(closeContext) {
        this.Manager.CompleteClose(closeContext)
    }

    static PruneOwner(ownerGui) {
        return this.Manager.PruneOwner(ownerGui)
    }

    static IsOwnerLocked(ownerGui) {
        return this.Manager.IsOwnerLocked(ownerGui)
    }

    static ActivateTopOwned(ownerGui) {
        return this.Manager.ActivateTopOwned(ownerGui)
    }
}
