#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 快捷方式必须在写入后读回验证，并显式通知 Windows Shell 更新开始菜单缓存。
; 用例只操作系统临时目录，不触碰用户桌面、开始菜单或项目配置。

try {
    RunSystemIntegrationShortcutTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.File " (" testError.Line "): " testError.Message
        "`n" testError.Stack "`n", "**")
    ExitApp(1)
}

#Include ..\..\进程守护小助手.ahk

AssertSystemIntegrationShortcut(condition, message) {
    if !condition
        throw Error(message)
}

RunSystemIntegrationShortcutTests() {
    testRoot := A_Temp "\watchdog-shortcut-test-" A_TickCount "-"
        ProcessExist()
    DirCreate(testRoot)
    try {
        sourceShortcut := testRoot "\source.lnk"
        AssertSystemIntegrationShortcut(CreateApplicationShortcutFile(
            sourceShortcut, A_ScriptFullPath, A_ScriptDir, A_AhkPath,
            false, A_AhkPath), "源码版快捷方式创建或读回校验失败")
        FileGetShortcut(sourceShortcut, &sourceTarget, &sourceWorkingDir,
            &sourceArguments)
        AssertSystemIntegrationShortcut(sourceTarget == A_AhkPath
            && sourceWorkingDir == A_ScriptDir
            && sourceArguments == '"' A_ScriptFullPath '"',
            "源码版快捷方式没有保留解释器、脚本参数或工作目录")
        AssertSystemIntegrationShortcut(NotifyShellShortcutChanged(
            sourceShortcut, false), "新建快捷方式没有通知 Windows Shell")
        AssertSystemIntegrationShortcut(NotifyShellShortcutChanged(
            sourceShortcut, true), "覆盖快捷方式没有通知 Windows Shell")

        compiledShortcut := testRoot "\compiled.lnk"
        AssertSystemIntegrationShortcut(CreateApplicationShortcutFile(
            compiledShortcut, A_AhkPath, A_ScriptDir, A_AhkPath,
            true, A_AhkPath), "EXE 版快捷方式创建或读回校验失败")
        FileGetShortcut(compiledShortcut, &compiledTarget, ,
            &compiledArguments)
        AssertSystemIntegrationShortcut(compiledTarget == A_AhkPath
            && compiledArguments == "",
            "EXE 版快捷方式目标或参数错误")

        FileCreateShortcut(A_ComSpec, compiledShortcut, A_Temp)
        AssertSystemIntegrationShortcut(!ApplicationShortcutMatches(
            compiledShortcut, A_AhkPath, true, A_AhkPath),
            "读回校验没有识别被替换成错误目标的快捷方式")
    } finally {
        expectedPrefix := A_Temp "\watchdog-shortcut-test-"
        if InStr(testRoot, expectedPrefix) == 1 && DirExist(testRoot)
            DirDelete(testRoot, true)
    }
}
