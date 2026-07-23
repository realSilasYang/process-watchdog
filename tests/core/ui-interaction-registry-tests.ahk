#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\..\src\UI\UiInteractionRegistry.ahk

class FakeUiCursorLoader {
    __New() {
        this.CallCount := 0
        this.FailNext := false
    }

    Load(cursorId) {
        this.CallCount++
        if this.FailNext {
            this.FailNext := false
            return 0
        }
        return cursorId + 100000
    }
}

AssertUiRegistry(value, message) {
    if !value
        throw Error(message)
}

AssertUiRegistryEqual(expected, actual, message) {
    if expected != actual
        throw Error(message "（预期 " expected "，实际 " actual "）")
}

RunUiInteractionRegistryTests() {
    loader := FakeUiCursorLoader()
    registry := UiInteractionRegistry(ObjBindMethod(loader, "Load"))
    firstButton := {Name: "first"}
    replacementButton := {Name: "replacement"}

    AssertUiRegistry(!registry.RegisterButton(0, firstButton)
        && !registry.RegisterButton(101, "bad"),
        "无效按钮注册没有被拒绝")
    AssertUiRegistry(registry.RegisterButton(101, firstButton)
        && registry.HasButton(101)
        && registry.GetButton(101) == firstButton,
        "有效按钮状态没有被登记")
    AssertUiRegistry(!registry.SetPressedButton(999)
        && !registry.SetHoveredButton(999),
        "未登记按钮被错误设为活动交互目标")
    AssertUiRegistry(registry.RegisterButton(101, replacementButton)
        && registry.Buttons.Count == 1
        && registry.GetButton(101) == replacementButton,
        "同一句柄重新注册后留下了重复状态")

    registry.SetPressedButton(101)
    registry.SetHoveredButton(101)
    AssertUiRegistry(!registry.ClearPressedButton(999)
        && !registry.ClearHoveredButton(999)
        && registry.PressedButton == 101
        && registry.HoveredButton == 101,
        "条件清理错误移除了其他按钮的交互状态")
    removedButton := registry.RemoveButton(101)
    AssertUiRegistry(removedButton == replacementButton
        && !registry.HasButton(101)
        && !registry.PressedButton
        && !registry.HoveredButton,
        "删除按钮没有原子清理按下和悬浮状态")
    AssertUiRegistry(registry.RemoveButton(101) == "",
        "重复删除按钮没有保持幂等")

    textState := {editHwnd: 202, hideCaret: true}
    AssertUiRegistry(!registry.RegisterTextInput(201, {})
        && !registry.RegisterTextInput(201, {editHwnd: 0})
        && registry.RegisterTextInput(201, textState)
        && registry.GetTextInput(201) == textState,
        "文本输入目标登记边界错误")
    AssertUiRegistry(registry.RemoveTextInput(201)
        && !registry.RemoveTextInput(201)
        && !registry.HasTextInput(201),
        "文本输入目标注销没有保持幂等")

    AssertUiRegistry(registry.ShouldPruneButtons(1000)
        && !registry.ShouldPruneButtons(1500)
        && registry.ShouldPruneButtons(2000),
        "按钮失效状态清理节流边界错误")
    AssertUiRegistry(registry.ShouldPruneButtons(100),
        "系统计时回绕后没有重新允许清理")
    AssertUiRegistry(!registry.ShouldPruneButtons(-1)
        && !registry.ShouldPruneButtons(200, 0),
        "无效清理时间参数没有被拒绝")
    zeroClockRegistry := UiInteractionRegistry(ObjBindMethod(loader, "Load"))
    AssertUiRegistry(zeroClockRegistry.ShouldPruneButtons(0)
        && !zeroClockRegistry.ShouldPruneButtons(1),
        "零时刻首次清理没有被正确节流")

    handCursor := registry.GetCursor(UiCursorKind.Hand, 32649)
    AssertUiRegistryEqual(132649, handCursor,
        "系统光标加载结果错误")
    AssertUiRegistryEqual(handCursor,
        registry.GetCursor(UiCursorKind.Hand, 99999),
        "同类系统光标没有复用缓存")
    AssertUiRegistryEqual(1, loader.CallCount,
        "已缓存光标仍被重复加载")
    loader.FailNext := true
    AssertUiRegistry(registry.GetCursor(UiCursorKind.Text, 32513) == 0
        && registry.GetCursor(UiCursorKind.Text, 32513) == 132513
        && loader.CallCount == 3,
        "光标加载失败被错误缓存或无法重试")
}

try {
    RunUiInteractionRegistryTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.File " (" testError.Line "): " testError.Message
        "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
