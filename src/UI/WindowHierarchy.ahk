; 多级窗口所有权、模态租约和独立最小化管理器。
; 每个下级窗口只禁用直接上级，关闭时按租约恢复原状态；最小化期间挂起模态关系并
; 解除原生 Owner，使焦点回到直接上级，恢复下级窗口时再重建正确层级。

class WindowHierarchyPlatform {
    __New() {
        this.TaskbarList := ""
    }

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

    PromoteToTaskbar(childHwnd) {
        originalStyle := DllCall("user32\GetWindowLongPtrW",
            "Ptr", childHwnd, "Int", Win32.GWL_EXSTYLE, "Ptr")
        taskbarStyle := (originalStyle | Win32.WS_EX_APPWINDOW)
            & ~Win32.WS_EX_TOOLWINDOW
        if taskbarStyle != originalStyle {
            DllCall("user32\SetWindowLongPtrW", "Ptr", childHwnd,
                "Int", Win32.GWL_EXSTYLE, "Ptr", taskbarStyle, "Ptr")
            this.RefreshWindowFrame(childHwnd)
        }
        return originalStyle
    }

    RestoreTaskbarStyle(childHwnd, originalStyle) {
        DllCall("user32\SetWindowLongPtrW", "Ptr", childHwnd,
            "Int", Win32.GWL_EXSTYLE, "Ptr", originalStyle, "Ptr")
        this.RefreshWindowFrame(childHwnd)
    }

    RegisterTaskbarTab(childHwnd) {
        if !this.IsWindow(childHwnd)
            return false
        Loop 2 {
            taskbarList := this.GetTaskbarList()
            if !taskbarList
                return false
            try result := ComCall(4, taskbarList, "Ptr", childHwnd,
                "Int")
            catch
                result := -1
            if result >= 0
                return true
            this.TaskbarList := ""
        }
        return false
    }

    UnregisterTaskbarTab(childHwnd) {
        Loop 2 {
            taskbarList := this.GetTaskbarList()
            if !taskbarList
                return false
            try result := ComCall(5, taskbarList, "Ptr", childHwnd,
                "Int")
            catch
                result := -1
            if result >= 0
                return true
            this.TaskbarList := ""
        }
        return false
    }

    GetTaskbarList() {
        if IsObject(this.TaskbarList)
            return this.TaskbarList
        try taskbarList := ComObject(
            "{56FDF344-FD6D-11D0-958A-006097C9A090}",
            "{56FDF342-FD6D-11D0-958A-006097C9A090}")
        catch
            return ""
        try {
            if ComCall(3, taskbarList, "Int") < 0
                return ""
        } catch {
            return ""
        }
        this.TaskbarList := taskbarList
        return taskbarList
    }

    RefreshWindowFrame(hwnd) {
        static SWP_NOSIZE := 0x0001
        static SWP_NOMOVE := 0x0002
        static SWP_NOZORDER := 0x0004
        static SWP_NOACTIVATE := 0x0010
        static SWP_FRAMECHANGED := 0x0020
        DllCall("user32\SetWindowPos", "Ptr", hwnd, "Ptr", 0,
            "Int", 0, "Int", 0, "Int", 0, "Int", 0,
            "UInt", SWP_NOSIZE | SWP_NOMOVE | SWP_NOZORDER
                | SWP_NOACTIVATE | SWP_FRAMECHANGED, "Int")
    }

    MinimizeWindow(hwnd) {
        ; 已显示的窗口只修改扩展样式时，Shell 不一定重新创建任务栏按钮。
        ; 先隐藏再以不激活的最小化状态显示，强制 Shell 重新评估新 Owner 和样式。
        DllCall("user32\ShowWindow", "Ptr", hwnd,
            "Int", Win32.SW_HIDE, "Int")
        return DllCall("user32\ShowWindow", "Ptr", hwnd,
            "Int", Win32.SW_SHOWMINNOACTIVE, "Int")
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
        entry := this.OwnerLocks[ownerHwnd]
        if entry.SuspendedChildren.Has(childHwnd) {
            this.ActivateAfterChildSuspended(entry, ownerHwnd)
            return true
        }
        if (this.Platform.GetNativeOwner(childHwnd) != ownerHwnd)
            return false

        ; Win32 会把带 Owner 的窗口作为一个激活组处理。最小化命令执行期间
        ; 解除原生 Owner，并挂起该子窗口的模态锁。Owner 直到子窗口恢复时才
        ; 重新绑定，避免最小化状态再次沿原生窗口组传播到直接上级。
        detached := false
        try {
            this.Platform.SetNativeOwner(childHwnd, 0)
            detached := true
            originalStyle := this.Platform.PromoteToTaskbar(childHwnd)
            entry.SuspendedChildren[childHwnd] := {
                ExtendedStyle: originalStyle,
                TaskbarRegistered: false
            }
            this.Platform.MinimizeWindow(childHwnd)
            entry.SuspendedChildren[childHwnd].TaskbarRegistered :=
                this.Platform.RegisterTaskbarTab(childHwnd)
        } catch {
            if entry.SuspendedChildren.Has(childHwnd) {
                suspendedState := entry.SuspendedChildren[childHwnd]
                entry.SuspendedChildren.Delete(childHwnd)
                try this.Platform.UnregisterTaskbarTab(childHwnd)
                if IsObject(suspendedState)
                    && suspendedState.HasOwnProp("ExtendedStyle")
                    try this.Platform.RestoreTaskbarStyle(childHwnd,
                        suspendedState.ExtendedStyle)
            }
            if detached && this.Platform.IsWindow(childHwnd)
                && this.Platform.IsWindow(ownerHwnd)
                try this.Platform.SetNativeOwner(childHwnd, ownerHwnd)
            return false
        }
        this.UpdateOwnerModalState(entry, ownerHwnd)
        this.ActivateAfterChildSuspended(entry, ownerHwnd)
        return true
    }

    PrepareChildRestore(childHwnd) {
        ownerHwnd := this.FindOwnerHwnd(childHwnd)
        if !ownerHwnd || !this.OwnerLocks.Has(ownerHwnd)
            return false
        entry := this.OwnerLocks[ownerHwnd]
        if !entry.SuspendedChildren.Has(childHwnd)
            return false
        if !this.Platform.IsWindow(childHwnd)
            || !this.Platform.IsWindow(ownerHwnd) {
            this.PruneOwner(entry.Gui)
            return false
        }

        ; 在系统真正还原窗口之前先恢复 Owner 并禁用直接上级，防止还原后的
        ; 子窗口短暂脱离既有层级或与父窗口同时接受输入。
        suspendedState := entry.SuspendedChildren[childHwnd]
        try {
            this.Platform.UnregisterTaskbarTab(childHwnd)
            if IsObject(suspendedState)
                && suspendedState.HasOwnProp("ExtendedStyle")
                this.Platform.RestoreTaskbarStyle(childHwnd,
                    suspendedState.ExtendedStyle)
            this.Platform.SetNativeOwner(childHwnd, ownerHwnd)
        }
        catch
            return false
        entry.SuspendedChildren.Delete(childHwnd)
        this.UpdateOwnerModalState(entry, ownerHwnd)
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
                this.UpdateOwnerModalState(entry, ownerHwnd)
                return this.CreateLease(ownerHwnd, childHwnd)
            }
            this.OwnerLocks.Delete(ownerHwnd)
        }

        wasEnabled := this.Platform.IsWindowEnabled(ownerHwnd)
        entry := {
            Gui: ownerGui,
            Count: 1,
            RestoreEnabled: wasEnabled,
            Children: Map(),
            SuspendedChildren: Map()
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
        if (entry.Count > 0) {
            this.UpdateOwnerModalState(entry, ownerHwnd)
            return {Mode: "child", Owner: entry.Gui,
                OwnerHwnd: ownerHwnd}
        }

        this.OwnerLocks.Delete(ownerHwnd)
        return this.RestoreOwner(entry, ownerHwnd)
    }

    CompleteClose(closeContext) {
        if !IsObject(closeContext) || !closeContext.HasOwnProp("Mode")
            return
        if (closeContext.Mode == "child") {
            if closeContext.HasOwnProp("Owner")
                && !this.ActivateTopOwned(closeContext.Owner)
                && closeContext.HasOwnProp("OwnerHwnd")
                this.ActivateOwnerIfAvailable(closeContext.OwnerHwnd)
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
            suspended := entry.SuspendedChildren.Has(childHwnd)
            nativeOwner := this.Platform.IsWindow(childHwnd)
                ? this.Platform.GetOwnedWindowOwner(childHwnd) : 0
            if !this.Platform.IsWindow(childHwnd)
                || (!suspended && nativeOwner != ownerHwnd)
                || (suspended && nativeOwner != 0)
                staleChildren.Push({Hwnd: childHwnd, Count: referenceCount})
        }
        for staleChild in staleChildren {
            entry.Children.Delete(staleChild.Hwnd)
            if entry.SuspendedChildren.Has(staleChild.Hwnd) {
                suspendedState := entry.SuspendedChildren[staleChild.Hwnd]
                if this.Platform.IsWindow(staleChild.Hwnd) {
                    try this.Platform.UnregisterTaskbarTab(staleChild.Hwnd)
                    if IsObject(suspendedState)
                        && suspendedState.HasOwnProp("ExtendedStyle")
                        try this.Platform.RestoreTaskbarStyle(staleChild.Hwnd,
                            suspendedState.ExtendedStyle)
                }
                entry.SuspendedChildren.Delete(staleChild.Hwnd)
            }
            entry.Count -= staleChild.Count
        }
        if (entry.Count > 0) {
            this.UpdateOwnerModalState(entry, ownerHwnd)
            return true
        }

        this.OwnerLocks.Delete(ownerHwnd)
        closeContext := this.RestoreOwner(entry, ownerHwnd)
        this.CompleteClose(closeContext)
        return false
    }

    IsOwnerLocked(ownerGui) {
        if !this.IsGuiAlive(ownerGui) || !this.PruneOwner(ownerGui)
            return false
        ownerHwnd := this.Platform.GetHwnd(ownerGui)
        return this.OwnerLocks.Has(ownerHwnd)
            && this.HasActiveChildren(this.OwnerLocks[ownerHwnd])
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
        else {
            entry.Children.Delete(childHwnd)
            if entry.SuspendedChildren.Has(childHwnd) {
                suspendedState := entry.SuspendedChildren[childHwnd]
                try this.Platform.UnregisterTaskbarTab(childHwnd)
                if this.Platform.IsWindow(childHwnd)
                    && IsObject(suspendedState) {
                    if suspendedState.HasOwnProp("ExtendedStyle")
                        try this.Platform.RestoreTaskbarStyle(childHwnd,
                            suspendedState.ExtendedStyle)
                }
                entry.SuspendedChildren.Delete(childHwnd)
            }
        }
    }

    HasActiveChildren(entry) {
        for childHwnd in entry.Children {
            if !entry.SuspendedChildren.Has(childHwnd)
                return true
        }
        return false
    }

    UpdateOwnerModalState(entry, ownerHwnd) {
        if !entry.RestoreEnabled || !this.IsGuiAlive(entry.Gui)
            return
        shouldEnable := !this.HasActiveChildren(entry)
        isEnabled := this.Platform.IsWindowEnabled(ownerHwnd)
        if (shouldEnable != isEnabled)
            try this.Platform.SetGuiEnabled(entry.Gui, shouldEnable)
    }

    ActivateAfterChildSuspended(entry, ownerHwnd) {
        if this.HasActiveChildren(entry) {
            this.ActivateTopOwned(entry.Gui)
            return
        }
        this.ActivateOwnerIfAvailable(ownerHwnd)
    }

    ActivateOwnerIfAvailable(ownerHwnd) {
        if !this.Platform.IsWindow(ownerHwnd)
            || !this.Platform.IsWindowVisible(ownerHwnd)
            || this.Platform.IsWindowMinimized(ownerHwnd)
            || !this.Platform.IsWindowEnabled(ownerHwnd)
            return false
        try this.Platform.ActivateOwnerWindow(ownerHwnd)
        return true
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
            && !entry.SuspendedChildren.Has(activePopup)
            && this.Platform.IsWindowVisible(activePopup)
            && !this.Platform.IsWindowMinimized(activePopup)
            return activePopup
        for childHwnd in entry.Children {
            if !entry.SuspendedChildren.Has(childHwnd)
                && this.Platform.IsWindowVisible(childHwnd)
                && !this.Platform.IsWindowMinimized(childHwnd)
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

    static PrepareChildRestore(childHwnd) {
        return this.Manager.PrepareChildRestore(childHwnd)
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
