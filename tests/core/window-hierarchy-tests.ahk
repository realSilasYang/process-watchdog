#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\UI\WindowHierarchy.ahk

class FakeWindowHierarchyPlatform {
    __New() {
        this.Alive := Map()
        this.Enabled := Map()
        this.Visible := Map()
        this.Minimized := Map()
        this.NativeOwners := Map()
        this.LastActivePopups := Map()
        this.GuiEnableChanges := []
        this.NativeOwnerChanges := []
        this.MinimizeCalls := []
        this.OwnedActivations := []
        this.OwnerActivations := []
    }

    AddWindow(hwnd, enabled := true, visible := true, minimized := false) {
        this.Alive[hwnd] := true
        this.Enabled[hwnd] := enabled
        this.Visible[hwnd] := visible
        this.Minimized[hwnd] := minimized
        return {Hwnd: hwnd}
    }

    IsGuiAlive(guiObj) {
        return IsObject(guiObj) && guiObj.HasOwnProp("Hwnd")
            && this.IsWindow(guiObj.Hwnd)
    }

    GetHwnd(guiObj) {
        return guiObj.Hwnd
    }

    IsWindow(hwnd) {
        return hwnd && this.Alive.Get(hwnd, false)
    }

    IsWindowEnabled(hwnd) {
        return this.Enabled.Get(hwnd, false)
    }

    SetGuiEnabled(guiObj, enabled) {
        this.Enabled[guiObj.Hwnd] := enabled
        this.GuiEnableChanges.Push({Hwnd: guiObj.Hwnd, Enabled: enabled})
    }

    IsWindowVisible(hwnd) {
        return this.Visible.Get(hwnd, false)
    }

    IsWindowMinimized(hwnd) {
        return this.Minimized.Get(hwnd, false)
    }

    GetNativeOwner(childHwnd) {
        return this.NativeOwners.Get(childHwnd, 0)
    }

    SetNativeOwner(childHwnd, ownerHwnd) {
        this.NativeOwners[childHwnd] := ownerHwnd
        this.NativeOwnerChanges.Push({Child: childHwnd, Owner: ownerHwnd})
    }

    MinimizeWindow(hwnd) {
        this.Minimized[hwnd] := true
        this.MinimizeCalls.Push(hwnd)
    }

    GetOwnedWindowOwner(childHwnd) {
        return this.NativeOwners.Get(childHwnd, 0)
    }

    GetLastActivePopup(hwnd) {
        return this.LastActivePopups.Get(hwnd, hwnd)
    }

    ActivateOwnedWindow(hwnd) {
        this.OwnedActivations.Push(hwnd)
    }

    ActivateOwnerWindow(hwnd) {
        this.OwnerActivations.Push(hwnd)
    }
}

AssertWindowHierarchy(value, message) {
    if !value
        throw Error(message)
}

AssertWindowHierarchyEqual(expected, actual, message) {
    if expected != actual
        throw Error(message "（预期 " expected "，实际 " actual "）")
}

RunWindowHierarchyTests() {
    platform := FakeWindowHierarchyPlatform()
    manager := WindowHierarchyManager(platform)
    owner := platform.AddWindow(101)
    childOne := platform.AddWindow(201)
    childTwo := platform.AddWindow(202)
    platform.NativeOwners[201] := 101
    platform.NativeOwners[202] := 101
    platform.LastActivePopups[101] := 202

    firstLease := manager.Acquire(owner, childOne.Hwnd)
    secondLease := manager.Acquire(owner, childTwo.Hwnd)
    AssertWindowHierarchy(IsObject(firstLease) && IsObject(secondLease),
        "有效窗口无法取得所有权租约")
    AssertWindowHierarchy(!platform.Enabled[101]
        && platform.GuiEnableChanges.Length == 1,
        "同一所有者的嵌套租约没有只禁用一次窗口")
    AssertWindowHierarchy(manager.IsOwnerLocked(owner),
        "有效嵌套租约未锁定所有者")

    childClose := manager.Release(firstLease)
    AssertWindowHierarchy(childClose.Mode == "child" && !platform.Enabled[101],
        "释放一个嵌套租约时过早恢复了所有者")
    manager.CompleteClose(childClose)
    AssertWindowHierarchyEqual(202, platform.OwnedActivations[-1],
        "关闭中间子窗口后没有激活最上层可见窗口")
    AssertWindowHierarchy(manager.Release(firstLease) == "",
        "重复释放租约改变了窗口层级状态")

    ownerClose := manager.Release(secondLease)
    AssertWindowHierarchy(ownerClose.Mode == "owner" && platform.Enabled[101],
        "最后一个租约释放后没有恢复所有者")
    manager.CompleteClose(ownerClose)
    AssertWindowHierarchyEqual(101, platform.OwnerActivations[-1],
        "可见且未最小化的所有者没有恢复前台")
    AssertWindowHierarchy(!manager.IsOwnerLocked(owner),
        "全部租约释放后仍残留所有者锁")

    disabledOwner := platform.AddWindow(102, false)
    disabledChild := platform.AddWindow(203)
    platform.NativeOwners[203] := 102
    disabledLease := manager.Acquire(disabledOwner, disabledChild.Hwnd)
    disabledClose := manager.Release(disabledLease)
    manager.CompleteClose(disabledClose)
    AssertWindowHierarchy(!platform.Enabled[102]
        && platform.OwnerActivations[-1] != 102,
        "原本禁用的所有者被错误启用或激活")

    staleOwner := platform.AddWindow(103)
    staleChild := platform.AddWindow(204)
    platform.NativeOwners[204] := 103
    manager.Acquire(staleOwner, staleChild.Hwnd)
    manager.Acquire(staleOwner, staleChild.Hwnd)
    platform.Alive[204] := false
    AssertWindowHierarchy(!manager.IsOwnerLocked(staleOwner)
        && platform.Enabled[103],
        "重复子窗口引用失效后没有一次性清除全部租约")

    nestedOwner := platform.AddWindow(104)
    nestedChildOwner := platform.AddWindow(205)
    grandChild := platform.AddWindow(301)
    platform.NativeOwners[205] := 104
    platform.NativeOwners[301] := 205
    platform.LastActivePopups[104] := 205
    platform.LastActivePopups[205] := 301
    manager.Acquire(nestedOwner, nestedChildOwner.Hwnd)
    manager.Acquire(nestedChildOwner, grandChild.Hwnd)
    AssertWindowHierarchy(manager.ActivateTopOwned(nestedOwner),
        "嵌套层级没有找到最上层可见窗口")
    AssertWindowHierarchyEqual(301, platform.OwnedActivations[-1],
        "嵌套层级激活了错误窗口")

    minimizeOwner := platform.AddWindow(105)
    minimizeChild := platform.AddWindow(206)
    platform.NativeOwners[206] := 105
    manager.Acquire(minimizeOwner, minimizeChild.Hwnd)
    AssertWindowHierarchy(manager.MinimizeChildIndependently(206),
        "有效子窗口无法独立最小化")
    AssertWindowHierarchy(platform.Minimized[206]
        && !platform.Minimized[105],
        "独立最小化错误影响了所有者")
    changeCount := platform.NativeOwnerChanges.Length
    AssertWindowHierarchy(changeCount >= 2
        && platform.NativeOwnerChanges[changeCount - 1].Owner == 0
        && platform.NativeOwnerChanges[changeCount].Owner == 105,
        "独立最小化没有临时解除并恢复原生 Owner")
    AssertWindowHierarchy(!manager.MinimizeChildIndependently(999),
        "未登记窗口被错误当作下级窗口最小化")

    AssertWindowHierarchy(manager.Release({}) == ""
        && manager.Release(0) == "",
        "畸形租约没有被安全拒绝")
    manager.CompleteClose({})
}

try {
    RunWindowHierarchyTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.File " (" testError.Line "): " testError.Message
        "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
