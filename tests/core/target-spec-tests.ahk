#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证启动、探测和维护规格对象的字段归一化与默认语义。
; 快捷方式启动入口和真实进程身份必须保持分离，防止安装器升级后识别错目标。

#Include ..\..\src\Core\TargetSpecs.ahk
#Include ..\..\src\Inspection\ShortcutResolver.ahk

AssertTargetSpec(value, message) {
    if !value
        throw Error(message)
}

AssertTargetSpecEqual(expected, actual, message) {
    if (expected != actual)
        throw Error(message "（预期 " expected "，实际 " actual "）")
}

RunTargetSpecTests() {
    executablePlan := TargetSpecFactory.Create("C:\Apps\Tool.exe", {
        EntryExists: true, Arguments: "--quiet", WorkingDirectory: "C:\Apps",
        RunAsAdmin: true
    })
    AssertTargetSpecEqual(TargetProbeKind.ImagePath,
        executablePlan.Probe.Kind, "EXE 应使用镜像路径探活")
    AssertTargetSpecEqual("C:\Apps\Tool.exe",
        executablePlan.Launch.TargetPath, "EXE 启动入口错误")
    AssertTargetSpec(executablePlan.Launch.RunAsAdmin,
        "管理员启动要求没有进入启动规格")

    scriptPlan := TargetSpecFactory.Create("C:\Jobs\main.py", {
        EntryExists: true, RuntimePath: "C:\Python\python.exe",
        RuntimeArguments: "-I -u"
    })
    AssertTargetSpecEqual(TargetProbeKind.CommandTarget,
        scriptPlan.Probe.Kind, "绝对脚本应使用命令目标探活")
    AssertTargetSpecEqual("C:\Jobs\main.py", scriptPlan.Probe.TargetPath,
        "脚本探活身份必须保留绝对路径")
    AssertTargetSpec(TargetSpecFactory.IsPreciseProcessIdentityPath(
        "C:\Jobs\main.py"), "绝对脚本路径应构成精确身份")
    AssertTargetSpec(!TargetSpecFactory.IsPreciseProcessIdentityPath("main.py"),
        "相对脚本路径不得构成可持久化的精确身份")
    AssertTargetSpec(scriptPlan.Launch.RuntimePath
            == "C:\Python\python.exe"
        && scriptPlan.Launch.RuntimeArguments == "-I -u"
        && scriptPlan.Probe.LauncherPath == "C:\Python\python.exe",
        "通用运行时设置没有进入直接脚本启动规格")
    AssertTargetSpec(TargetSpecFactory.SupportsCustomRuntime(
            "C:\Jobs\main.py")
        && TargetSpecFactory.SupportsCustomRuntime("C:\Jobs\service.jar")
        && TargetSpecFactory.SupportsCustomRuntime("C:\Jobs\console.msc")
        && !TargetSpecFactory.SupportsCustomRuntime("C:\Apps\Tool.exe")
        && !TargetSpecFactory.SupportsCustomRuntime("C:\Links\Tool.lnk"),
        "自定义运行时适用目标分类错误")
    extensionlessPlan := TargetSpecFactory.Create("C:\Jobs\worker", {
        EntryExists: true, RuntimePath: "C:\Tools\runtime.exe"
    })
    AssertTargetSpecEqual(TargetProbeKind.CommandTarget,
        extensionlessPlan.Probe.Kind,
        "自定义运行时目标没有统一按命令行中的目标路径探活")

    shortcutPlan := TargetSpecFactory.Create("C:\Links\Tool.lnk", {
        EntryExists: true, ResolvedTarget: "C:\Apps\Tool.exe",
        ResolvedTargetExists: true, Arguments: "--user",
        ShortcutArguments: "--embedded", WorkingDirectory: "C:\Custom",
        RuntimePath: "C:\Python\python.exe", RuntimeArguments: "-I"
    })
    AssertTargetSpecEqual("C:\Links\Tool.lnk",
        shortcutPlan.Launch.TargetPath, "存在的快捷方式应保持为启动入口")
    AssertTargetSpecEqual("--user", shortcutPlan.Launch.Arguments,
        "通过快捷方式启动时不得重复追加内置参数")
    AssertTargetSpec(shortcutPlan.Launch.UsesShortcutEntry,
        "快捷方式启动入口标记缺失")
    AssertTargetSpec(shortcutPlan.Launch.RuntimePath == "",
        "快捷方式不应被自定义运行时绕过原启动入口")
    AssertTargetSpecEqual("C:\Apps\Tool.exe",
        shortcutPlan.Probe.TargetPath, "快捷方式探活必须使用真实进程身份")

    missingShortcutPlan := TargetSpecFactory.Create("C:\Links\Tool.lnk", {
        EntryExists: false, ResolvedTarget: "C:\Apps\Tool.exe",
        ResolvedTargetExists: true, Arguments: "--user",
        ShortcutArguments: "--embedded"
    })
    AssertTargetSpecEqual("C:\Apps\Tool.exe",
        missingShortcutPlan.Launch.TargetPath,
        "缺失快捷方式应回退到已确认的真实启动目标")
    AssertTargetSpecEqual("--embedded --user",
        missingShortcutPlan.Launch.Arguments,
        "回退启动时应合并快捷方式内置参数与用户参数")
    AssertTargetSpec(!missingShortcutPlan.Launch.UsesShortcutEntry,
        "回退启动不得继续标记为快捷方式入口")

    missingResolvedPlan := TargetSpecFactory.Create("C:\Links\Tool.lnk", {
        EntryExists: false, ResolvedTarget: "C:\Apps\Tool.exe",
        ResolvedTargetExists: false
    })
    AssertTargetSpec(!missingResolvedPlan.Launch.Available,
        "快捷方式和真实目标都缺失时不得生成可执行启动规格")
    AssertTargetSpecEqual(TargetProbeKind.ImagePath,
        missingResolvedPlan.Probe.Kind,
        "文件暂时缺失不能抹掉已确认的进程探活身份")

    fallbackPlan := TargetSpecFactory.Create("C:\Links\Viewer.lnk", {
        EntryExists: true, ShortcutReadable: true,
        ShortcutWorkingDirectory: "C:\Apps\Viewer"
    })
    AssertTargetSpecEqual(TargetProbeKind.WorkingDirectory,
        fallbackPlan.Probe.Kind, "未解析快捷方式应进入有限目录兜底")
    AssertTargetSpec(!fallbackPlan.Probe.Precise,
        "目录兜底不得标记为精确进程身份")

    oneShotPlan := TargetSpecFactory.Create("C:\Links\Action.lnk", {
        EntryExists: true, ShortcutReadable: true,
        ShortcutArguments: "shell:AppsFolder\Package!App",
        ShortcutTargetsGenericLauncher: true
    })
    AssertTargetSpec(oneShotPlan.IsOneShot,
        "通用启动器快捷方式应识别为非驻留目标")
    AssertTargetSpecEqual(TargetProbeKind.None, oneShotPlan.Probe.Kind,
        "非驻留目标不应生成持续探活规格")

    urlPlan := TargetSpecFactory.Create("C:\Links\Portal.url", {
        EntryExists: true
    })
    AssertTargetSpec(urlPlan.IsOneShot, "URL 应识别为非驻留目标")

    shortcutPath := A_Temp "\watchdog-target-spec-" A_TickCount ".lnk"
    try {
        FileCreateShortcut(A_AhkPath, shortcutPath, A_Temp, "--spec-test")
        shortcutInfo := ShortcutResolver.Read(shortcutPath)
        AssertTargetSpec(shortcutInfo.Readable, "真实快捷方式读取失败")
        AssertTargetSpecEqual(A_AhkPath, shortcutInfo.TargetPath,
            "快捷方式目标读取错误")
        AssertTargetSpecEqual("--spec-test", shortcutInfo.Arguments,
            "快捷方式参数读取错误")
    } finally {
        try FileDelete(shortcutPath)
    }
    AssertTargetSpec(!ShortcutResolver.Read(shortcutPath).Readable,
        "缺失快捷方式不得报告为可读")
}

try {
    RunTargetSpecTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n", "**")
    ExitApp(1)
}
