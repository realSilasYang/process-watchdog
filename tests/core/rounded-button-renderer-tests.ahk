#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

try {
    RunRoundedButtonRendererTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.File " (" testError.Line "): " testError.Message
        "`n" testError.Stack "`n", "**")
    ExitApp(1)
}

#Include ..\..\进程守护小助手.ahk

AssertRoundedButtonRenderer(condition, message) {
    if !condition
        throw Error(message)
}

RunRoundedButtonRendererTests() {
    AssertRoundedButtonRenderer(RoundedButtonRenderer.EnsureStarted(),
        "GDI+ 按钮渲染器无法初始化")
    AssertRoundedButtonRenderer(RoundedButtonRenderer.token != 0,
        "GDI+ 初始化后没有保存令牌")
    AssertRoundedButtonRenderer(RoundedButtonRenderer.moduleHandle != 0,
        "GDI+ 初始化期间没有持有模块引用")
    RoundedButtonRenderer.Shutdown()
    AssertRoundedButtonRenderer(RoundedButtonRenderer.token == 0,
        "GDI+ 按钮渲染器关闭后没有清空令牌")
    AssertRoundedButtonRenderer(RoundedButtonRenderer.moduleHandle == 0,
        "GDI+ 按钮渲染器关闭后没有释放模块引用")
    AssertRoundedButtonRenderer(RoundedButtonRenderer.EnsureStarted(),
        "GDI+ 按钮渲染器关闭后无法重新初始化")
    RoundedButtonRenderer.Shutdown()
}
