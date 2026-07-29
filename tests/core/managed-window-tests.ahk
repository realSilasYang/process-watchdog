#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证托管窗口创建、层级租约、关闭顺序和幂等清理。
; 原生窗口意外消失与显式关闭都必须恢复上级交互，并且只执行一次资源收尾。

#Include ..\..\src\UI\ManagedWindow.ahk

class FakeManagedWindowCallbacks {
    __New(events) {
        this.Events := events
        this.FailRestore := false
    }

    RestoreInteractions(*) {
        this.Events.Push("restore")
        if this.FailRestore
            throw Error("restore failed")
    }

    HideTransientWindows(*) {
        this.Events.Push("hide")
    }

    UnregisterControls(hwnd) {
        this.Events.Push("unregister:" hwnd)
    }

    ReleaseIcons(hwnd) {
        this.Events.Push("icons:" hwnd)
    }
}

class FakeManagedGui {
    __New(hwnd, factory) {
        this.Hwnd := hwnd
        this.Factory := factory
        this.ShowCount := 0
        this.DestroyCount := 0
    }

    Show(*) {
        this.ShowCount++
        this.Factory.Events.Push("show:" this.Hwnd)
    }

    Destroy(*) {
        this.DestroyCount++
        this.Factory.Events.Push("destroy:" this.Hwnd)
        this.Factory.Alive[this.Hwnd] := false
    }
}

class FakeManagedGuiFactory {
    __New(events) {
        this.Events := events
        this.Alive := Map()
        this.NextHwnd := 200
        this.FailNext := false
        this.Created := []
    }

    Create(options, title) {
        this.Events.Push("create:" options ":" title)
        if this.FailNext {
            this.FailNext := false
            throw Error("create failed")
        }
        hwnd := this.NextHwnd++
        guiObj := FakeManagedGui(hwnd, this)
        this.Alive[hwnd] := true
        this.Created.Push(guiObj)
        return guiObj
    }

    IsWindow(hwnd) {
        return this.Alive.Get(hwnd, false)
    }
}

class FakeManagedWindowHierarchy {
    __New(events) {
        this.Events := events
        this.AcquireAllowed := true
        this.Locked := false
        this.ActivatedHwnd := 0
        this.ReleaseCount := 0
        this.PrepareRestoreCount := 0
    }

    Acquire(ownerGui, childHwnd := 0) {
        this.Events.Push("acquire:" ownerGui.Hwnd ":" childHwnd)
        if !this.AcquireAllowed
            return ""
        return {OwnerHwnd: ownerGui.Hwnd, ChildHwnd: childHwnd,
            Released: false}
    }

    Release(lease) {
        if !IsObject(lease) || lease.Released
            return ""
        lease.Released := true
        this.ReleaseCount++
        this.Events.Push("release:" lease.ChildHwnd)
        return {Mode: "owner", OwnerHwnd: lease.OwnerHwnd,
            Activate: true}
    }

    CompleteClose(closeContext) {
        if !IsObject(closeContext)
            return
        this.Events.Push("complete:" closeContext.OwnerHwnd)
    }

    PrepareChildRestore(childHwnd) {
        this.PrepareRestoreCount++
        return false
    }

    IsOwnerLocked(guiObj) {
        return this.Locked
    }

    ActivateTopOwned(guiObj) {
        this.ActivatedHwnd := guiObj.Hwnd
        this.Events.Push("activate:" guiObj.Hwnd)
        return true
    }
}

AssertManagedWindow(value, message) {
    if !value
        throw Error(message)
}

AssertManagedWindowEqual(expected, actual, message) {
    if expected != actual
        throw Error(message "（预期 " expected "，实际 " actual "）")
}

JoinManagedEvents(events, startIndex := 1) {
    result := ""
    Loop events.Length - startIndex + 1 {
        eventIndex := startIndex + A_Index - 1
        result .= (result == "" ? "" : "|") events[eventIndex]
    }
    return result
}

RunManagedWindowTests() {
    events := []
    callbacks := FakeManagedWindowCallbacks(events)
    factory := FakeManagedGuiFactory(events)
    hierarchy := FakeManagedWindowHierarchy(events)
    missingCallbackRejected := false
    try ManagedWindowLifecycle({}, hierarchy,
        ObjBindMethod(factory, "Create"), ObjBindMethod(factory, "IsWindow"))
    catch
        missingCallbackRejected := true
    AssertManagedWindow(missingCallbackRejected,
        "缺少清理回调的窗口生命周期仍被接受")

    lifecycle := ManagedWindowLifecycle({
        RestoreInteractions: ObjBindMethod(callbacks, "RestoreInteractions"),
        HideTransientWindows: ObjBindMethod(callbacks,
            "HideTransientWindows"),
        UnregisterControls: ObjBindMethod(callbacks, "UnregisterControls"),
        ReleaseIcons: ObjBindMethod(callbacks, "ReleaseIcons")
    }, hierarchy, ObjBindMethod(factory, "Create"),
        ObjBindMethod(factory, "IsWindow"))
    ManagedWindow.ConfigureLifecycle(lifecycle)

    owner := {Hwnd: 10}
    window := ManagedWindow()
    AssertManagedWindow(window.CreateOwnedGui(owner, " +Resize ", "child")
        && window.IsOpen() && window.ownerLease,
        "有效下级窗口没有完成创建和所有权登记")
    AssertManagedWindow(JoinManagedEvents(events) ==
        "restore|hide|create:+Owner10  +Resize:child|acquire:10:200",
        "下级窗口创建顺序或参数错误")

    hierarchy.Locked := true
    AssertManagedWindow(window.ShowExisting()
        && hierarchy.ActivatedHwnd == 200
        && hierarchy.PrepareRestoreCount == 1
        && factory.Created[1].ShowCount == 0,
        "存在更深层窗口时错误显示了直接所有者")
    hierarchy.Locked := false
    AssertManagedWindow(window.ShowExisting()
        && hierarchy.PrepareRestoreCount == 2
        && factory.Created[1].ShowCount == 1,
        "未锁定的既有窗口没有恢复显示")

    destroyStart := events.Length + 1
    firstGui := factory.Created[1]
    window.DestroyGui()
    AssertManagedWindow(!window.gui && !window.ownerLease
        && firstGui.DestroyCount == 1,
        "标准销毁没有清空窗口和租约引用")
    AssertManagedWindowEqual(
        "release:200|unregister:200|destroy:200|icons:200|complete:10",
        JoinManagedEvents(events, destroyStart),
        "标准销毁没有遵循恢复、注销、销毁、释图和激活顺序")
    eventCountAfterDestroy := events.Length
    window.DestroyGui()
    AssertManagedWindowEqual(eventCountAfterDestroy, events.Length,
        "重复销毁仍执行了生命周期副作用")

    events.Length := 0
    deadWindow := ManagedWindow()
    AssertManagedWindow(deadWindow.CreateOwnedGui(owner, "", "dead"),
        "外部销毁测试窗口创建失败")
    deadGui := deadWindow.gui
    factory.Alive[deadGui.Hwnd] := false
    events.Length := 0
    AssertManagedWindow(!deadWindow.IsOpen() && !deadWindow.gui
        && !deadWindow.ownerLease && deadGui.DestroyCount == 0,
        "原生窗口失效后没有收敛托管引用")
    AssertManagedWindowEqual(
        "release:" deadGui.Hwnd "|unregister:" deadGui.Hwnd
            "|icons:" deadGui.Hwnd "|complete:10",
        JoinManagedEvents(events),
        "外部销毁路径没有清理控件、图标和所有权")

    events.Length := 0
    hierarchy.AcquireAllowed := false
    rejectedWindow := ManagedWindow()
    AssertManagedWindow(!rejectedWindow.CreateOwnedGui(owner, "", "reject")
        && !rejectedWindow.gui,
        "所有权租约失败后仍保留新建窗口")
    rejectedGui := factory.Created[-1]
    AssertManagedWindow(rejectedGui.DestroyCount == 1
        && InStr(JoinManagedEvents(events), "unregister:" rejectedGui.Hwnd)
        && InStr(JoinManagedEvents(events), "icons:" rejectedGui.Hwnd),
        "所有权租约失败没有回滚窗口资源")
    hierarchy.AcquireAllowed := true

    events.Length := 0
    factory.FailNext := true
    failedWindow := ManagedWindow()
    createFailed := false
    try failedWindow.CreateStandaloneGui("", "failure")
    catch
        createFailed := true
    AssertManagedWindow(createFailed && !failedWindow.gui
        && JoinManagedEvents(events) == "restore|hide|create::failure",
        "GUI 创建异常没有清空引用或保持原错误")

    events.Length := 0
    callbacks.FailRestore := true
    standaloneWindow := ManagedWindow()
    AssertManagedWindow(standaloneWindow.CreateStandaloneGui(
        " +Resize ", "standalone") && standaloneWindow.IsOpen()
        && !standaloneWindow.ownerLease,
        "非关键准备回调失败阻断了独立窗口创建")
    AssertManagedWindow(!InStr(JoinManagedEvents(events), "acquire:"),
        "独立窗口错误取得了所有者租约")
    standaloneWindow.DestroyGui()
}

try {
    RunManagedWindowTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.File " (" testError.Line "): " testError.Message
        "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
