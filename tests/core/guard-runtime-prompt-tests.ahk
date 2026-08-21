#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 询问恢复按全局停止次数阈值触发，条目开关只决定是否参与询问。

try {
    RunGuardRuntimePromptTests()
    FileAppend("GUARD_RUNTIME_PROMPT|PASS`n", "*")
    ExitApp(0)
} catch as testError {
    FileAppend(testError.File " (" testError.Line "): " testError.Message
        "`n" testError.Stack "`n", "**")
    ExitApp(1)
}

#Include ..\..\进程守护小助手.ahk

AssertGuardRuntimePrompt(condition, message) {
    if !condition
        throw Error(message)
}

RunGuardRuntimePromptTests() {
    runtime := {askBeforeRestartFromStopCount: 2}
    runtimeController := GuardRuntime(runtime, {})
    supervisor := TargetSupervisor({AskBeforeRestart: true})
    AssertGuardRuntimePrompt(!runtimeController.ShouldPromptAfterConfirmedStop(
        supervisor) && supervisor.StopCountSinceGuardReset == 1,
        "全局阈值为 2 时首次确认停止仍显示了恢复选择")
    AssertGuardRuntimePrompt(runtimeController.ShouldPromptAfterConfirmedStop(
        supervisor) && supervisor.StopCountSinceGuardReset == 2,
        "全局阈值为 2 时第二次确认停止没有显示恢复选择")

    supervisor.ResetGuardAttemptState()
    runtime.askBeforeRestartFromStopCount := 1
    AssertGuardRuntimePrompt(runtimeController.ShouldPromptAfterConfirmedStop(
        supervisor) && supervisor.StopCountSinceGuardReset == 1,
        "全局阈值为 1 时首次确认停止没有显示恢复选择")

    supervisor.AskBeforeRestart := false
    AssertGuardRuntimePrompt(!runtimeController.ShouldPromptAfterConfirmedStop(
        supervisor), "未开启询问恢复的条目仍显示了恢复选择")
}
