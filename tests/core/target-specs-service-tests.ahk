#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证目标规格服务的构建、缓存和失效条件。
; 快捷方式读取时间变化不应无故清缓存，真正影响启动或探测语义的变化必须重建。

#Include ..\..\src\Core\TargetSpecs.ahk
#Include ..\..\src\Inspection\ShortcutResolver.ahk
#Include ..\..\src\Core\TargetSpecsService.ahk

AssertTargetSpecsService(value, message) {
    if !value
        throw Error(message)
}

class TargetSpecsServiceTestResolver {
    __New() {
        this.Descriptor := ShortcutDescriptor("")
        this.ResolvedTarget := ""
        this.ReadCount := 0
        this.ResolveCount := 0
    }

    Read(path) {
        this.ReadCount += 1
        return ShortcutDescriptor(path, this.Descriptor.Readable,
            this.Descriptor.TargetPath, this.Descriptor.WorkingDirectory,
            this.Descriptor.Arguments, this.Descriptor.ErrorMessage)
    }

    ResolveEffective(*) {
        this.ResolveCount += 1
        return this.ResolvedTarget
    }

    IsGenericLauncher(path) {
        SplitPath(path, &fileName)
        return RegExMatch(fileName, "i)^(?:cmd|autohotkey.*)\.exe$") != 0
    }
}

TargetSpecsServiceTestNormalize(path) {
    return StrReplace(Trim(String(path), ' `t`r`n"'), "/", "\")
}

RunTargetSpecsServiceTests() {
    resolver := TargetSpecsServiceTestResolver()
    service := TargetSpecsService(resolver, TargetSpecsServiceTestNormalize)
    testId := DllCall("kernel32\GetCurrentProcessId", "UInt")
    shortcutPath := A_Temp "\watchdog-target-specs-service-" testId ".lnk"
    try {
        try FileDelete(shortcutPath)
        FileAppend("placeholder", shortcutPath, "UTF-8")
        resolver.Descriptor := ShortcutDescriptor(shortcutPath, true,
            A_AhkPath, A_Temp, "--embedded")
        resolver.ResolvedTarget := A_AhkPath
        stateObj := {
            ResolvedTarget: "",
            WorkDir: "",
            Args: "--user",
            ShortcutArgs: "",
            EnvVars: "LANG=zh_CN",
            RuntimePath: "",
            RuntimeArgs: "",
            RunAsAdmin: true,
            ShortcutResolveCheckedTicks: 1,
            OneShot: false
        }

        firstSpecs := service.Get(shortcutPath, stateObj)
        AssertTargetSpecsService(firstSpecs.Launch.TargetPath == shortcutPath
            && firstSpecs.Launch.Arguments == "--user"
            && firstSpecs.Probe.TargetPath == A_AhkPath
            && firstSpecs.Launch.WorkingDirectory == A_Temp
            && firstSpecs.Launch.RunAsAdmin
            && resolver.ReadCount == 1 && resolver.ResolveCount == 1,
            "目标规格服务没有分离快捷方式启动入口与真实探活身份")
        cachedSpecs := service.Get(shortcutPath, stateObj)
        AssertTargetSpecsService(ObjPtr(cachedSpecs) == ObjPtr(firstSpecs)
            && resolver.ReadCount == 1,
            "未变化目标规格没有复用缓存")

        stateObj.ShortcutResolveCheckedTicks := 999999
        afterCheckTick := service.Get(shortcutPath, stateObj)
        AssertTargetSpecsService(ObjPtr(afterCheckTick) == ObjPtr(firstSpecs),
            "仅快捷方式检查时间变化仍触发了无意义规格重建")
        stateObj.Args := "--changed"
        changedSpecs := service.Get(shortcutPath, stateObj)
        AssertTargetSpecsService(ObjPtr(changedSpecs) != ObjPtr(firstSpecs)
            && changedSpecs.Launch.Arguments == "--changed",
            "启动参数变化没有使目标规格缓存失效")
        stateObj.RuntimePath := A_AhkPath
        runtimeChangedSpecs := service.Get(shortcutPath, stateObj)
        AssertTargetSpecsService(ObjPtr(runtimeChangedSpecs)
                != ObjPtr(changedSpecs)
            && runtimeChangedSpecs.Launch.RuntimePath == "",
            "运行时设置变化没有使规格缓存失效，或错误覆盖了快捷方式入口")
        forcedSpecs := service.Get(shortcutPath, stateObj, true)
        AssertTargetSpecsService(ObjPtr(forcedSpecs)
                != ObjPtr(runtimeChangedSpecs),
            "显式刷新没有重建目标规格")

        try FileDelete(shortcutPath)
        resolver.ReadCount := 0
        resolver.ResolveCount := 0
        savedState := {
            ResolvedTarget: A_AhkPath,
            ShortcutArgs: "--embedded",
            Args: "--outer",
            WorkDir: A_Temp,
            EnvVars: "",
            RuntimePath: "", RuntimeArgs: "",
            RunAsAdmin: false,
            OneShot: false
        }
        missingSpecs := service.Get(shortcutPath, savedState, true)
        AssertTargetSpecsService(missingSpecs.Launch.TargetPath == A_AhkPath
            && missingSpecs.Launch.Arguments == "--embedded --outer"
            && missingSpecs.Probe.TargetPath == A_AhkPath
            && resolver.ReadCount == 0 && resolver.ResolveCount == 0,
            "已保存真实身份没有优先于缺失快捷方式重新解析")

        FileAppend("placeholder", shortcutPath, "UTF-8")
        resolver.Descriptor := ShortcutDescriptor(shortcutPath, true,
            A_AhkPath, A_Temp, "shell:AppsFolder\Package!App")
        resolver.ResolvedTarget := ""
        oneShotState := {
            ResolvedTarget: "", ShortcutArgs: "", Args: "", WorkDir: "",
            EnvVars: "", RunAsAdmin: false, OneShot: false,
            RuntimePath: "", RuntimeArgs: ""
        }
        oneShotSpecs := service.Get(shortcutPath, oneShotState, true)
        AssertTargetSpecsService(oneShotSpecs.IsOneShot
            && oneShotState.OneShot
            && oneShotSpecs.Probe.Kind == TargetProbeKind.None,
            "非驻留快捷方式结论没有同步回控制器状态")
    } finally {
        try FileDelete(shortcutPath)
    }
}

try {
    RunTargetSpecsServiceTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
