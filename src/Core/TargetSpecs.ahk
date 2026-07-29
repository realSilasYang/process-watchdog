; 目标启动、探测和维护所需的不可变规格对象。
; 启动入口与进程识别身份刻意分离：快捷方式可负责启动，真实可执行文件负责探测；
; 各层只接收所需规格，避免再次从全局配置拼装出含义不一致的参数。

class TargetLaunchKind {
    static Direct := "Direct"
    static Batch := "Batch"
    static AutoHotkey := "AutoHotkey"
    static PowerShell := "PowerShell"
}

class TargetProbeKind {
    static ProcessName := "ProcessName"
    static ImagePath := "ImagePath"
    static CommandTarget := "CommandTarget"
    static WorkingDirectory := "WorkingDirectory"
    static None := "None"
    static Unknown := "Unknown"
}

class LaunchSpec {
    __New(kind, targetPath := "", arguments := "", workingDirectory := "",
        environment := "", runAsAdmin := false, available := true,
        usesShortcutEntry := false, unavailableReason := "",
        runtimePath := "", runtimeArguments := "") {
        this.Kind := kind
        this.TargetPath := targetPath
        this.Arguments := arguments
        this.WorkingDirectory := workingDirectory
        this.Environment := environment
        this.RunAsAdmin := !!runAsAdmin
        this.Available := !!available
        this.UsesShortcutEntry := !!usesShortcutEntry
        this.UnavailableReason := unavailableReason
        this.RuntimePath := runtimePath
        this.RuntimeArguments := runtimeArguments
    }
}

class ProbeSpec {
    __New(kind, targetPath := "", workingDirectory := "",
        preferredName := "", precise := true, reason := "",
        launcherPath := "") {
        this.Kind := kind
        this.TargetPath := targetPath
        this.WorkingDirectory := workingDirectory
        this.PreferredName := preferredName
        this.Precise := !!precise
        this.Reason := reason
        this.LauncherPath := launcherPath
    }
}

class TargetSpecs {
    __New(configuredPath, launchSpec, probeSpec, isOneShot := false,
        resolvedTarget := "") {
        this.ConfiguredPath := configuredPath
        this.Launch := launchSpec
        this.Probe := probeSpec
        this.IsOneShot := !!isOneShot
        this.ResolvedTarget := resolvedTarget
    }
}

class TargetSpecFactory {
    static CommandTargetExtensions :=
        "^(?:msc|ahk|py|pyw|js|vbs|vbe|wsf|ps1|bat|cmd|rb|pl|php|lua|jar|sh|bash)$"

    static Create(configuredPath, options := "") {
        configuredPath := this.NormalizePath(configuredPath)
        resolvedTarget := this.NormalizePath(this.Option(options,
            "ResolvedTarget", ""))
        configuredArguments := Trim(String(this.Option(options,
            "Arguments", "")))
        shortcutArguments := Trim(String(this.Option(options,
            "ShortcutArguments", "")))
        workingDirectory := this.NormalizePath(this.Option(options,
            "WorkingDirectory", ""))
        shortcutWorkingDirectory := this.NormalizePath(this.Option(options,
            "ShortcutWorkingDirectory", ""))
        environment := String(this.Option(options, "Environment", ""))
        runtimePath := this.NormalizePath(this.Option(options,
            "RuntimePath", ""))
        runtimeArguments := Trim(String(this.Option(options,
            "RuntimeArguments", "")))
        runAsAdmin := !!this.Option(options, "RunAsAdmin", false)
        entryExists := !!this.Option(options, "EntryExists", true)
        resolvedTargetExists := !!this.Option(options, "ResolvedTargetExists",
            resolvedTarget != "")

        if !InStr(configuredPath, "\") {
            launch := LaunchSpec(TargetLaunchKind.Direct, configuredPath,
                configuredArguments, workingDirectory, environment, runAsAdmin,
                configuredPath != "", false, "", runtimePath,
                runtimeArguments)
            probe := ProbeSpec(TargetProbeKind.ProcessName, configuredPath)
            return TargetSpecs(configuredPath, launch, probe)
        }

        SplitPath(configuredPath, , , &configuredExtension, &configuredBaseName)
        configuredExtension := StrLower(configuredExtension)
        if (configuredExtension == "lnk") {
            shortcutReadable := !!this.Option(options, "ShortcutReadable", false)
            genericLauncher := !!this.Option(options,
                "ShortcutTargetsGenericLauncher", false)
            oneShotHint := !!this.Option(options, "OneShotHint", false)
            isOneShot := resolvedTarget == ""
                && ((shortcutReadable && shortcutArguments != ""
                    && genericLauncher) || oneShotHint)

            usesShortcutEntry := entryExists
            launchTarget := usesShortcutEntry ? configuredPath
                : (resolvedTargetExists ? resolvedTarget : "")
            launchArguments := usesShortcutEntry ? configuredArguments
                : this.JoinArguments(shortcutArguments, configuredArguments)
            launchWorkingDirectory := workingDirectory != ""
                ? workingDirectory : shortcutWorkingDirectory
            available := launchTarget != ""
            launch := LaunchSpec(this.ResolveLaunchKind(launchTarget), launchTarget,
                launchArguments, launchWorkingDirectory, environment, runAsAdmin,
                available, usesShortcutEntry,
                available ? "" : "快捷方式及已解析目标均不可用")

            if (resolvedTarget != "") {
                probe := this.CreatePathProbe(resolvedTarget,
                    "快捷方式已解析真实目标")
            } else if isOneShot {
                probe := ProbeSpec(TargetProbeKind.None, "", "", "",
                    true, "非驻留快捷方式不执行持续探活")
            } else if (shortcutReadable && shortcutWorkingDirectory != "") {
                preferredName := configuredBaseName != ""
                    ? configuredBaseName ".exe" : ""
                probe := ProbeSpec(TargetProbeKind.WorkingDirectory, "",
                    shortcutWorkingDirectory, preferredName, false,
                    "只能使用快捷方式工作目录进行有限兜底")
            } else {
                probe := ProbeSpec(TargetProbeKind.Unknown, "", "", "",
                    false, entryExists ? "快捷方式进程身份无法确定"
                        : "快捷方式缺失且没有已保存的真实目标")
            }
            return TargetSpecs(configuredPath, launch, probe, isOneShot,
                resolvedTarget)
        }

        isOneShot := configuredExtension == "url"
            || configuredExtension == "appref-ms"
        launch := LaunchSpec(this.ResolveLaunchKind(configuredPath), configuredPath,
            configuredArguments, workingDirectory, environment, runAsAdmin,
            entryExists, false, entryExists ? "" : "启动目标不存在",
            runtimePath, runtimeArguments)
        probe := isOneShot
            ? ProbeSpec(TargetProbeKind.None, "", "", "", true,
                "非驻留目标不执行持续探活")
            : (runtimePath != ""
                ? ProbeSpec(TargetProbeKind.CommandTarget, configuredPath,
                    "", "", true, "自定义运行时按运行时和目标路径探活",
                    runtimePath)
                : this.CreatePathProbe(configuredPath))
        return TargetSpecs(configuredPath, launch, probe, isOneShot)
    }

    static CreatePathProbe(targetPath, reason := "") {
        targetPath := this.NormalizePath(targetPath)
        if (targetPath == "")
            return ProbeSpec(TargetProbeKind.Unknown, "", "", "",
                false, reason != "" ? reason : "没有可用的进程身份")
        if !InStr(targetPath, "\")
            return ProbeSpec(TargetProbeKind.ProcessName, targetPath, "",
                "", false, reason)
        SplitPath(targetPath, &fileName, , &extension)
        extension := StrLower(extension)
        if (extension == "exe" || extension == "com")
            return ProbeSpec(TargetProbeKind.ImagePath, targetPath, "", "",
                true, reason)
        if RegExMatch(extension, "i)" this.CommandTargetExtensions)
            return ProbeSpec(TargetProbeKind.CommandTarget, targetPath, "", "",
                true, reason)
        return ProbeSpec(TargetProbeKind.ProcessName, fileName, "", "",
            false, reason != "" ? reason : "目标类型只能按进程名探活")
    }

    static IsPreciseProcessIdentityPath(targetPath) {
        if (targetPath == "" || !InStr(targetPath, "\"))
            return false
        probe := this.CreatePathProbe(targetPath)
        return probe.Kind == TargetProbeKind.ImagePath
            || probe.Kind == TargetProbeKind.CommandTarget
    }

    static SupportsCustomRuntime(targetPath) {
        targetPath := this.NormalizePath(targetPath)
        if (targetPath == "" || !InStr(targetPath, "\"))
            return false
        SplitPath(targetPath, , , &extension)
        extension := StrLower(extension)
        return extension != "lnk" && extension != "exe"
            && extension != "com" && extension != "url"
            && extension != "appref-ms"
    }

    static ResolveLaunchKind(targetPath) {
        SplitPath(targetPath, , , &extension)
        switch StrLower(extension) {
            case "bat", "cmd": return TargetLaunchKind.Batch
            case "ahk": return TargetLaunchKind.AutoHotkey
            case "ps1": return TargetLaunchKind.PowerShell
        }
        return TargetLaunchKind.Direct
    }

    static JoinArguments(first, second) {
        first := Trim(String(first))
        second := Trim(String(second))
        if (first == "")
            return second
        if (second == "")
            return first
        return first " " second
    }

    static NormalizePath(path) {
        path := Trim(String(path), " `t`r`n`"")
        return StrReplace(path, "/", "\")
    }

    static Option(options, propertyName, defaultValue := "") {
        return IsObject(options) && options.HasOwnProp(propertyName)
            ? options.%propertyName% : defaultValue
    }
}
