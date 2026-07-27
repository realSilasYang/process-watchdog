; 小助手版本与运行时信息入口。
; 编译版从 EXE 元数据读取小助手版本，源码版从 VERSION 读取；展示摘要同时标明
; EXE／源码形态和实际 AutoHotkey 运行时，避免三个独立版本概念互相混淆。

ReadApplicationVersion() {
    ; 编译版以 EXE 内嵌版本为权威，避免旁置 VERSION 被误改后检查到错误版本；
    ; 源码版再读取随仓库或源码发行包提供的 VERSION。
    if A_IsCompiled {
        try {
            compiledVersion := FileGetVersion(A_ScriptFullPath)
            if RegExMatch(compiledVersion,
                    "^((?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\."
                    . "(?:0|[1-9]\d*))(?:\.0)?$", &versionMatch)
                return versionMatch[1]
        }
    }
    versionPath := A_ScriptDir "\VERSION"
    try {
        version := Trim(FileRead(versionPath, "UTF-8"))
        if RegExMatch(version,
                "^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\."
                . "(?:0|[1-9]\d*)$")
            return version
    }
    return "unknown"
}

BuildApplicationVersionSummary(applicationVersion, autoHotkeyVersion,
    compiled) {
    applicationVersion := String(applicationVersion)
    if applicationVersion == "" || applicationVersion == "unknown"
        applicationVersion := Tr("未知版本")
    autoHotkeyVersion := String(autoHotkeyVersion)
    if autoHotkeyVersion == ""
        autoHotkeyVersion := Tr("未知版本")
    return compiled
        ? Tr("当前版本：{1}（EXE 版；内嵌 AutoHotkey {2} x64）",
            applicationVersion, autoHotkeyVersion)
        : Tr("当前版本：{1}（源码版；本机 AutoHotkey {2} x64）",
            applicationVersion, autoHotkeyVersion)
}

GetApplicationVersionSummary() {
    ; A_AhkVersion 在编译版中代表 EXE 内嵌运行时，在源码版中代表当前解释器。
    return BuildApplicationVersionSummary(ReadApplicationVersion(),
        A_AhkVersion, A_IsCompiled)
}

BuildApplicationEditionSummary(applicationVersion, compiled) {
    applicationVersion := String(applicationVersion)
    versionText := applicationVersion == ""
        || applicationVersion == "unknown"
        ? Tr("未知版本") : "v" applicationVersion
    return compiled ? Tr("{1}（EXE 版）", versionText)
        : Tr("{1}（源码版）", versionText)
}

GetApplicationEditionSummary() {
    return BuildApplicationEditionSummary(ReadApplicationVersion(),
        A_IsCompiled)
}

BuildAutoHotkeyRuntimeSummary(autoHotkeyVersion) {
    autoHotkeyVersion := String(autoHotkeyVersion)
    if autoHotkeyVersion == ""
        autoHotkeyVersion := Tr("未知版本")
    return "AutoHotkey " autoHotkeyVersion " x64"
}

GetAutoHotkeyRuntimeSummary() {
    return BuildAutoHotkeyRuntimeSummary(A_AhkVersion)
}
