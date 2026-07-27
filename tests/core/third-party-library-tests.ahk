#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证发行包锁定的 Everything 与 resvg 动态库能够按预期加载和关闭。
; 测试只检查明确的本地依赖边界，不从系统搜索路径接受来源不明的同名 DLL。

try {
    RunThirdPartyLibraryTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.File " (" testError.Line "): " testError.Message
        "`n" testError.Stack "`n", "**")
    ExitApp(1)
}

#Include ..\..\进程守护小助手.ahk

AssertThirdPartyLibrary(value, message) {
    if !value
        throw Error(message)
}

RunThirdPartyLibraryTests() {
    searchDialog := ApplicationSearchDialog({})
    searchDialog.everythingDllPath := A_ScriptDir
        . "\..\..\third_party\everything\Everything64.dll"
    AssertThirdPartyLibrary(searchDialog.LoadEverythingLibrary(),
        "项目附带的 Everything64.dll 无法加载")
    AssertThirdPartyLibrary(searchDialog.everythingLib
        && searchDialog.everythingFunctions.Count == 8
        && searchDialog.everythingFunctions.Has("Everything_SetMax")
        && searchDialog.everythingFunctions.Has("Everything_GetLastError"),
        "Everything64.dll 的必需导出没有完整解析")
    searchDialog.Shutdown()
    AssertThirdPartyLibrary(!searchDialog.everythingLib
        && searchDialog.everythingFunctions.Count == 0,
        "Everything64.dll 关闭后仍保留模块或函数指针")

    missingDialog := ApplicationSearchDialog({})
    missingDialog.everythingDllPath := A_Temp
        . "\missing-process-watchdog-everything.dll"
    AssertThirdPartyLibrary(!missingDialog.LoadEverythingLibrary()
        && !missingDialog.everythingLib,
        "Everything64.dll 缺失时没有安全返回不可用状态")
    missingDialog.Shutdown()
}
