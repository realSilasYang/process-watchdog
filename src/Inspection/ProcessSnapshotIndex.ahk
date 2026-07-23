class ProcessSnapshotIndex {
    __New(processes, capturedAtTicks := 0, supportsCommandLine := true,
        canonicalizePath := "") {
        this.Processes := []
        for processInfo in processes
            this.Processes.Push(ProcessSnapshotIndex.CopyProcessInfo(processInfo))
        this.CapturedAtTicks := capturedAtTicks
        this.SupportsCommandLine := supportsCommandLine
        this.CanonicalizePath := canonicalizePath
        this.ByPID := Map()
        this.ByImagePath := Map()
        this.ByImagePath.CaseSense := "Off"
        this.ByName := Map()
        this.ByName.CaseSense := "Off"
        this.ByCommandTarget := Map()
        this.ByCommandTarget.CaseSense := "Off"
        this.ByRelativeCommandName := Map()
        this.ByRelativeCommandName.CaseSense := "Off"
        this.Build()
    }

    IsFresh(nowTicks, maximumAgeMs) {
        return this.CapturedAtTicks > 0 && nowTicks >= this.CapturedAtTicks
            && nowTicks - this.CapturedAtTicks <= maximumAgeMs
    }

    ObserveImagePath(targetPath) {
        key := this.Canonical(targetPath)
        observation := this.ObserveEntries(this.ByImagePath, key, "process-image")
        if !observation.IsStopped()
            return observation
        SplitPath(targetPath, &targetName)
        if (targetName != "" && this.HasLiveEntryWithoutValue(this.ByName,
            StrLower(targetName), "exe")) {
            return ProcessObservation.Unknown(this.CapturedAtTicks,
                "process-image", "同名进程的镜像路径不可用")
        }
        return observation
    }

    ObserveCommandTarget(targetPath) {
        if !this.SupportsCommandLine {
            return ProcessObservation.Unknown(this.CapturedAtTicks,
                "process-command", "快照不包含命令行信息")
        }
        key := this.Canonical(targetPath)
        observation := this.ObserveEntries(this.ByCommandTarget, key,
            "process-command")
        if !observation.IsStopped()
            return observation
        SplitPath(targetPath, &targetName)
        if (targetName != "" && this.HasLiveEntry(this.ByRelativeCommandName,
            StrLower(targetName))) {
            return ProcessObservation.Unknown(this.CapturedAtTicks,
                "process-command", "命令行只包含相对目标路径，无法证明完整身份")
        }
        if this.HasLiveCommandLineGap(targetPath) {
            return ProcessObservation.Unknown(this.CapturedAtTicks,
                "process-command", "候选解释器的命令行不可用")
        }
        return observation
    }

    ObserveExecutableInRoot(rootPath, preferredName := "") {
        root := RTrim(this.Canonical(rootPath), "\")
        if (root == "")
            return ProcessObservation.Stopped(this.CapturedAtTicks,
                "process-working-directory")
        candidates := []
        if (preferredName != "" && this.ByName.Has(preferredName))
            candidates := this.ByName[preferredName]
        else if (preferredName == "")
            candidates := this.Processes
        matching := []
        for processInfo in candidates {
            if (!processInfo.HasOwnProp("exe") || processInfo.exe == ""
                || !this.IsAlive(processInfo.pid))
                continue
            imagePath := this.Canonical(processInfo.exe)
            if (imagePath == root || InStr(imagePath, root "\") == 1)
                matching.Push(processInfo)
        }
        if (preferredName != "" && matching.Length)
            return this.RunningObservation(matching[1], "process-working-directory")
        if (preferredName == "" && matching.Length == 1)
            return this.RunningObservation(matching[1], "process-working-directory")
        if (matching.Length > 1)
            return ProcessObservation.Unknown(this.CapturedAtTicks,
                "process-working-directory", "安装目录内存在多个候选进程")
        if (preferredName != "" && this.HasLiveEntryWithoutValue(this.ByName,
            preferredName, "exe")) {
            return ProcessObservation.Unknown(this.CapturedAtTicks,
                "process-working-directory", "同名进程的镜像路径不可用")
        }
        return ProcessObservation.Stopped(this.CapturedAtTicks,
            "process-working-directory")
    }

    Build() {
        for processInfo in this.Processes {
            if !processInfo.HasOwnProp("pid") || !processInfo.pid
                continue
            this.ByPID[processInfo.pid] := processInfo
            if processInfo.HasOwnProp("name") && processInfo.name != ""
                this.AddEntry(this.ByName, StrLower(processInfo.name), processInfo)
            if processInfo.HasOwnProp("exe") && processInfo.exe != ""
                this.AddEntry(this.ByImagePath, this.Canonical(processInfo.exe),
                    processInfo)
            if !this.SupportsCommandLine || !processInfo.HasOwnProp("cmd")
                continue
            candidates := ProcessSnapshotIndex.ExtractCommandTargets(processInfo.cmd)
            for candidatePath in candidates.Absolute
                this.AddEntry(this.ByCommandTarget, this.Canonical(candidatePath),
                    processInfo)
            for candidateName in candidates.Relative
                this.AddEntry(this.ByRelativeCommandName, StrLower(candidateName),
                    processInfo)
        }
    }

    ObserveEntries(indexMap, key, source) {
        if (key == "" || !indexMap.Has(key))
            return ProcessObservation.Stopped(this.CapturedAtTicks, source)
        for processInfo in indexMap[key] {
            if this.IsAlive(processInfo.pid)
                return this.RunningObservation(processInfo, source)
        }
        return ProcessObservation.Stopped(this.CapturedAtTicks, source,
            "快照中的候选 PID 已结束")
    }

    HasLiveEntry(indexMap, key) {
        if (key == "" || !indexMap.Has(key))
            return false
        for processInfo in indexMap[key]
            if this.IsAlive(processInfo.pid)
                return true
        return false
    }

    HasLiveEntryWithoutValue(indexMap, key, propertyName) {
        if (key == "" || !indexMap.Has(key))
            return false
        for processInfo in indexMap[key] {
            if this.IsAlive(processInfo.pid)
                && (!processInfo.HasOwnProp(propertyName)
                    || processInfo.%propertyName% == "")
                return true
        }
        return false
    }

    HasLiveCommandLineGap(targetPath) {
        SplitPath(targetPath, , , &targetExtension)
        for processInfo in this.Processes {
            if (!processInfo.HasOwnProp("name")
                || !ProcessSnapshotIndex.CommandLauncherMatchesExtension(
                    processInfo.name, targetExtension))
                continue
            if this.IsAlive(processInfo.pid)
                && (!processInfo.HasOwnProp("cmd") || processInfo.cmd == "")
                return true
        }
        return false
    }

    RunningObservation(processInfo, source) {
        creationIdentity := processInfo.HasOwnProp("creation")
            ? processInfo.creation : ""
        return ProcessObservation.Running(processInfo.pid, creationIdentity,
            this.CapturedAtTicks, source)
    }

    IsAlive(pid) {
        return pid && ProcessExist(pid)
    }

    Canonical(path) {
        if IsObject(this.CanonicalizePath)
            return this.CanonicalizePath.Call(path)
        return ProcessSnapshotIndex.NormalizePath(path)
    }

    AddEntry(indexMap, key, processInfo) {
        if (key == "")
            return
        if !indexMap.Has(key)
            indexMap[key] := []
        indexMap[key].Push(processInfo)
    }

    static CopyProcessInfo(processInfo) {
        copy := {}
        for propertyName in ["pid", "parent", "name", "cmd", "exe", "creation",
            "observedTicks"] {
            if processInfo.HasOwnProp(propertyName)
                copy.%propertyName% := processInfo.%propertyName%
        }
        return copy
    }

    static CommandLauncherMatchesExtension(processName, targetExtension) {
        SplitPath(processName, &launcherName)
        launcherName := StrLower(launcherName)
        targetExtension := StrLower(targetExtension)
        switch targetExtension {
            case "msc": return RegExMatch(launcherName, "^mmc\.exe$") != 0
            case "ahk": return RegExMatch(launcherName, "^autohotkey.*\.exe$") != 0
            case "py", "pyw": return RegExMatch(launcherName, "^pythonw?\.exe$") != 0
            case "js": return RegExMatch(launcherName, "^(?:node|wscript|cscript)\.exe$") != 0
            case "vbs", "vbe", "wsf": return RegExMatch(launcherName, "^(?:wscript|cscript)\.exe$") != 0
            case "ps1": return RegExMatch(launcherName, "^(?:powershell(?:_ise)?|pwsh)\.exe$") != 0
            case "bat", "cmd": return launcherName == "cmd.exe"
            case "rb": return launcherName == "ruby.exe"
            case "pl": return launcherName == "perl.exe"
            case "php": return launcherName == "php.exe"
            case "lua": return launcherName == "lua.exe"
            case "jar": return RegExMatch(launcherName, "^javaw?\.exe$") != 0
            case "sh", "bash": return RegExMatch(launcherName, "^(?:bash|sh)\.exe$") != 0
        }
        return false
    }

    static NormalizePath(path) {
        path := Trim(String(path), " `t`r`n`"")
        path := StrReplace(path, "/", "\")
        return StrLower(StrLen(path) > 3 ? RTrim(path, "\") : path)
    }

    static ExtractCommandTargets(commandLine) {
        result := {Absolute: [], Relative: []}
        arguments := this.ParseCommandLine(commandLine)
        if (arguments.Length < 2)
            return result
        SplitPath(arguments[1], &launcherName)
        launcherName := StrLower(launcherName)
        isPowerShellLauncher := RegExMatch(launcherName,
            "i)^(?:powershell(?:_ise)?|pwsh)\.exe$") != 0

        if isPowerShellLauncher {
            for index, argument in arguments {
                if (index == 1)
                    continue
                normalizedArgument := StrLower(argument)
                if (normalizedArgument == "-file" || normalizedArgument == "-f") {
                    if (index < arguments.Length)
                        this.AddCommandCandidate(result, arguments[index + 1])
                    return result
                }
                if RegExMatch(argument, "i)^-(?:file|f)[:=](.+)$", &match) {
                    this.AddCommandCandidate(result, match[1])
                    return result
                }
                if (normalizedArgument == "-command"
                    || normalizedArgument == "-c") {
                    if (index < arguments.Length) {
                        Loop arguments.Length - index {
                            commandPart := arguments[index + A_Index]
                            if !this.AddEmbeddedCommandCandidates(result,
                                commandPart)
                                this.AddCommandCandidate(result, commandPart)
                        }
                    }
                    return result
                }
            }
        }

        if RegExMatch(launcherName, "i)^javaw?\.exe$") {
            for index, argument in arguments {
                if (index > 1 && StrLower(argument) == "-jar") {
                    if (index < arguments.Length)
                        this.AddCommandCandidate(result, arguments[index + 1])
                    return result
                }
            }
        }

        if RegExMatch(launcherName, "i)^cmd\.exe$") {
            if RegExMatch(commandLine, "i)\s/[ck]\s+(.+)$", &commandMatch) {
                commandBody := Trim(commandMatch[1])
                if (SubStr(commandBody, 1, 2) == Chr(34) Chr(34)
                    && SubStr(commandBody, -1) == Chr(34))
                    commandBody := SubStr(commandBody, 2, -1)
                this.AddEmbeddedCommandCandidates(result, commandBody)
            }
            commandIndex := 0
            for index, argument in arguments {
                if (index > 1 && (StrLower(argument) == "/c"
                    || StrLower(argument) == "/k")) {
                    commandIndex := index
                    break
                }
            }
            if commandIndex {
                Loop arguments.Length - commandIndex {
                    commandPart := arguments[commandIndex + A_Index]
                    if !this.AddEmbeddedCommandCandidates(result, commandPart)
                        this.AddCommandCandidate(result, commandPart)
                }
            }
            return result
        }

        if !this.IsSupportedCommandLauncher(launcherName)
            return result
        for index, argument in arguments {
            if (index == 1 || argument == "" || SubStr(argument, 1, 1) == "-"
                || SubStr(argument, 1, 1) == "/")
                continue
            if (this.AddEmbeddedCommandCandidates(result, argument)
                || this.AddCommandCandidate(result, argument))
                break
        }
        return result
    }

    static IsSupportedCommandLauncher(launcherName) {
        return RegExMatch(launcherName,
            "i)^(?:autohotkey.*|pythonw?|node|wscript|cscript|ruby|perl|php|lua|bash|sh|powershell(?:_ise)?|pwsh|javaw?|cmd|mmc)\.exe$") != 0
    }

    static AddCommandCandidate(result, argument) {
        candidate := Trim(String(argument), " `t`r`n`"',;()")
        separator := InStr(candidate, "=")
        optionPrefix := separator > 1 ? SubStr(candidate, 1, separator - 1) : ""
        if (separator > 0 && separator < StrLen(candidate)
            && !InStr(optionPrefix, "\") && !InStr(optionPrefix, ":"))
            candidate := SubStr(candidate, separator + 1)
        candidate := StrReplace(candidate, "/", "\")
        SplitPath(candidate, &candidateName, , &extension)
        if !RegExMatch(extension,
            "i)^(msc|ahk|py|pyw|js|vbs|vbe|wsf|ps1|bat|cmd|rb|pl|php|lua|jar|sh|bash)$")
            return false
        if RegExMatch(candidate, "i)^[a-z]:\\|^\\\\")
            this.PushUniqueCandidate(result.Absolute, candidate)
        else if (candidateName != "")
            this.PushUniqueCandidate(result.Relative, candidateName)
        return true
    }

    static PushUniqueCandidate(candidates, candidate) {
        normalizedCandidate := StrLower(StrReplace(candidate, "/", "\"))
        for existingCandidate in candidates {
            if (StrLower(StrReplace(existingCandidate, "/", "\"))
                == normalizedCandidate)
                return false
        }
        candidates.Push(candidate)
        return true
    }

    static AddEmbeddedCommandCandidates(result, argumentText) {
        extensions := "msc|ahk|py|pyw|js|vbs|vbe|wsf|ps1|bat|cmd|rb|pl|php|lua|jar|sh|bash"
        argumentText := String(argumentText)
        added := false
        for quoteCharacter in [Chr(34), "'"] {
            startPosition := 1
            while openPosition := InStr(argumentText, quoteCharacter, true,
                startPosition) {
                closePosition := InStr(argumentText, quoteCharacter, true,
                    openPosition + 1)
                if !closePosition
                    break
                quotedValue := SubStr(argumentText, openPosition + 1,
                    closePosition - openPosition - 1)
                if this.AddCommandCandidate(result, quotedValue)
                    added := true
                startPosition := closePosition + 1
            }
        }
        unquotedPattern := "i)(?:^|[\s=&])((?:[a-z]:\\|\\\\)"
            . "[^\s\x22'&|<>]+?\.(?:" . extensions . "))"
            . "(?=$|[\s&|<>])"
        startPosition := 1
        while RegExMatch(argumentText, unquotedPattern, &match, startPosition) {
            if this.AddCommandCandidate(result, match[1])
                added := true
            startPosition := match.Pos + Max(match.Len, 1)
        }
        return added
    }

    static ParseCommandLine(commandLine) {
        arguments := []
        if (Trim(commandLine) == "")
            return arguments
        argumentCount := 0
        argumentVector := DllCall("shell32\CommandLineToArgvW", "WStr", commandLine,
            "Int*", &argumentCount, "Ptr")
        if !argumentVector
            return arguments
        try {
            Loop argumentCount {
                argumentPointer := NumGet(argumentVector,
                    (A_Index - 1) * A_PtrSize, "Ptr")
                arguments.Push(argumentPointer
                    ? StrGet(argumentPointer, "UTF-16") : "")
            }
        } finally {
            DllCall("kernel32\LocalFree", "Ptr", argumentVector, "Ptr")
        }
        return arguments
    }
}
