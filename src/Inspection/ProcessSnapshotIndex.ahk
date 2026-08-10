; 一次进程快照的只读索引。
; 同一轮守护检查复用按 PID、规范化路径和文件名建立的映射，减少重复 WMI 查询；
; 索引保留创建身份和可访问性证据，候选匹配仍需由目标探测器完成严格确认。

class ProcessSnapshotIndex {
    __New(processes, capturedAtTicks := 0, supportsCommandLine := true,
        canonicalizePath := "", creationIdentityResolver := "") {
        this.Processes := []
        for processInfo in processes
            this.Processes.Push(ProcessSnapshotIndex.CopyProcessInfo(processInfo))
        this.CapturedAtTicks := capturedAtTicks
        this.RequestTicks := capturedAtTicks
        this.SupportsCommandLine := supportsCommandLine
        this.CanonicalizePath := canonicalizePath
        this.CreationIdentityResolver := creationIdentityResolver
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

    ObserveImagePath(targetPath, fallbackContext := "") {
        key := this.Canonical(targetPath)
        observation := this.ObserveEntries(this.ByImagePath, key, "process-image")
        if !observation.IsStopped()
            return observation
        SplitPath(targetPath, &targetName)
        inaccessibleCandidates := this.GetInaccessibleNameCandidates(targetName,
            &identityUnavailable)
        if (inaccessibleCandidates.Length && !identityUnavailable
            && this.IsImagePathFallbackAllowed(fallbackContext)) {
            inferred := this.InferInaccessibleImageCandidate(
                inaccessibleCandidates, fallbackContext)
            if inferred.HasOwnProp("Observation")
                return inferred.Observation
            if inferred.Ambiguous
                return ProcessObservation.Unknown(this.CapturedAtTicks,
                    "process-image", "存在多个同名进程，无法唯一确认",
                    ProcessObservationReason.AmbiguousTarget)
        }
        if (inaccessibleCandidates.Length || identityUnavailable) {
            return ProcessObservation.Unknown(this.CapturedAtTicks,
                "process-image", "同名进程的镜像路径不可用",
                ProcessObservationReason.InaccessibleImagePath)
        }
        return observation
    }

    GetInaccessibleNameCandidates(targetName, &identityUnavailable := false) {
        candidates := []
        identityUnavailable := false
        if targetName == "" || !this.ByName.Has(StrLower(targetName))
            return candidates
        for processInfo in this.ByName[StrLower(targetName)] {
            if processInfo.HasOwnProp("exe") && processInfo.exe != ""
                continue
            liveStatus := this.GetLiveStatus(processInfo)
            if liveStatus > 0
                candidates.Push(processInfo)
            else if liveStatus < 0
                identityUnavailable := true
        }
        return candidates
    }

    IsImagePathFallbackAllowed(fallbackContext) {
        return IsObject(fallbackContext)
            && fallbackContext.HasOwnProp("AllowInaccessibleImageFallback")
            && fallbackContext.AllowInaccessibleImageFallback
    }

    InferInaccessibleImageCandidate(candidates, fallbackContext) {
        if candidates.Length != 1
            return {Ambiguous: candidates.Length > 1}
        candidate := candidates[1]
        priorPid := this.ContextValue(fallbackContext, "PriorPID", 0)
        priorIdentity := String(this.ContextValue(fallbackContext,
            "PriorCreationIdentity", ""))
        identity := this.ProcessIdentity(candidate)
        matchesPrior := priorPid && candidate.pid == priorPid
            && priorIdentity != "" && identity != ""
            && StrLower(identity) == StrLower(priorIdentity)
        recentSeconds := Max(1, Integer(this.ContextValue(fallbackContext,
            "RecentStartSeconds", 0)))
        recentStart := recentSeconds > 0
            && this.WasProcessStartedRecently(candidate, recentSeconds)
        if matchesPrior || recentStart {
            return {Observation: ProcessObservation.Running(candidate.pid,
                identity, this.CapturedAtTicks, "process-image-inferred")}
        }
        return {}
    }

    WasProcessStartedRecently(processInfo, maximumAgeSeconds) {
        creation := this.ContextValue(processInfo, "creation", "")
        creation := SubStr(String(creation), 1, 14)
        if !RegExMatch(creation, "^\d{14}$")
            return false
        try return Abs(DateDiff(A_Now, creation, "Seconds"))
            <= maximumAgeSeconds
        catch
            return false
    }

    ProcessIdentity(processInfo) {
        if processInfo.HasOwnProp("identity") && processInfo.identity != ""
            return String(processInfo.identity)
        return processInfo.HasOwnProp("creation")
            ? String(processInfo.creation) : ""
    }

    ContextValue(objectValue, propertyName, defaultValue := "") {
        return IsObject(objectValue) && objectValue.HasOwnProp(propertyName)
            ? objectValue.%propertyName% : defaultValue
    }

    ObserveCommandTarget(targetPath, launcherPath := "") {
        if !this.SupportsCommandLine {
            return ProcessObservation.Unknown(this.CapturedAtTicks,
                "process-command", "快照不包含命令行信息",
                ProcessObservationReason.CommandLineUnavailable)
        }
        if launcherPath != ""
            return this.ObserveCustomRuntimeTarget(targetPath, launcherPath)
        key := this.Canonical(targetPath)
        observation := this.ObserveEntries(this.ByCommandTarget, key,
            "process-command")
        if !observation.IsStopped()
            return observation
        SplitPath(targetPath, &targetName)
        if (targetName != "" && this.HasLiveEntry(this.ByRelativeCommandName,
            StrLower(targetName))) {
            return ProcessObservation.Unknown(this.CapturedAtTicks,
                "process-command", "命令行只包含相对目标路径，无法证明完整身份",
                ProcessObservationReason.RelativeCommandTarget)
        }
        if this.HasLiveCommandLineGap(targetPath) {
            return ProcessObservation.Unknown(this.CapturedAtTicks,
                "process-command", "候选解释器的命令行不可用",
                ProcessObservationReason.CommandLineUnavailable)
        }
        return observation
    }

    ObserveCustomRuntimeTarget(targetPath, launcherPath) {
        matching := []
        identityUnavailable := false
        commandLineUnavailable := false
        launcherIdentityUnavailable := false
        for processInfo in this.Processes {
            liveStatus := this.GetLiveStatus(processInfo)
            if liveStatus == 0
                continue
            launcherStatus := this.GetLauncherMatchStatus(processInfo,
                launcherPath)
            if launcherStatus == 0
                continue
            if launcherStatus < 0 {
                launcherIdentityUnavailable := true
                continue
            }
            if !processInfo.HasOwnProp("cmd") || processInfo.cmd == "" {
                commandLineUnavailable := true
                continue
            }
            if !this.CommandLineContainsTarget(processInfo.cmd, targetPath)
                continue
            if liveStatus > 0
                matching.Push(processInfo)
            else
                identityUnavailable := true
        }
        if matching.Length {
            return this.RunningObservation(this.SelectOldestCandidate(matching),
                "process-command")
        }
        if identityUnavailable {
            return ProcessObservation.Unknown(this.CapturedAtTicks,
                "process-command", "候选进程的创建身份无法核对",
                ProcessObservationReason.ProcessIdentityUnavailable)
        }
        if commandLineUnavailable {
            return ProcessObservation.Unknown(this.CapturedAtTicks,
                "process-command", "候选运行时的命令行不可用",
                ProcessObservationReason.CommandLineUnavailable)
        }
        if launcherIdentityUnavailable {
            return ProcessObservation.Unknown(this.CapturedAtTicks,
                "process-command", "候选运行时的镜像路径不可用",
                ProcessObservationReason.InaccessibleImagePath)
        }
        return ProcessObservation.Stopped(this.CapturedAtTicks,
            "process-command")
    }

    GetLauncherMatchStatus(processInfo, launcherPath) {
        wantedLauncher := this.Canonical(launcherPath)
        if wantedLauncher == ""
            return 0
        if processInfo.HasOwnProp("exe") && processInfo.exe != ""
            return this.Canonical(processInfo.exe) == wantedLauncher ? 1 : 0
        SplitPath(launcherPath, &wantedName)
        processName := processInfo.HasOwnProp("name")
            ? processInfo.name : ""
        return wantedName != ""
            && StrLower(processName) == StrLower(wantedName) ? -1 : 0
    }

    CommandLineContainsTarget(commandLine, targetPath) {
        wantedTarget := this.Canonical(targetPath)
        if wantedTarget == ""
            return false
        arguments := ProcessSnapshotIndex.ParseCommandLine(commandLine)
        if arguments.Length < 2
            return false
        for index, argument in arguments {
            if index > 1 && this.Canonical(argument) == wantedTarget
                return true
        }
        return false
    }

    ObserveExecutableInRoot(rootPath, preferredName := "") {
        root := RTrim(this.Canonical(rootPath), "\")
        if (root == "")
            return ProcessObservation.Stopped(this.CapturedAtTicks,
                "process-working-directory")
        matching := []
        preferredMatching := []
        uncertainMatching := []
        preferredUncertain := []
        for processInfo in this.Processes {
            if !processInfo.HasOwnProp("exe") || processInfo.exe == ""
                continue
            liveStatus := this.GetLiveStatus(processInfo)
            if liveStatus == 0
                continue
            imagePath := this.Canonical(processInfo.exe)
            if (imagePath == root || InStr(imagePath, root "\") == 1) {
                processName := processInfo.HasOwnProp("name")
                    ? StrLower(processInfo.name) : ""
                isPreferred := preferredName != ""
                    && processName == StrLower(preferredName)
                if liveStatus > 0 {
                    matching.Push(processInfo)
                    if isPreferred
                        preferredMatching.Push(processInfo)
                } else {
                    uncertainMatching.Push(processInfo)
                    if isPreferred
                        preferredUncertain.Push(processInfo)
                }
            }
        }
        if preferredMatching.Length == 1
            return this.RunningObservation(preferredMatching[1],
                "process-working-directory")
        if preferredMatching.Length > 1
            return ProcessObservation.Unknown(this.CapturedAtTicks,
                "process-working-directory", "安装目录内存在多个同名候选进程",
                ProcessObservationReason.AmbiguousTarget)
        if preferredUncertain.Length
            return ProcessObservation.Unknown(this.CapturedAtTicks,
                "process-working-directory", "首选候选进程的创建身份无法核对",
                ProcessObservationReason.ProcessIdentityUnavailable)
        if matching.Length == 1
            return this.RunningObservation(matching[1], "process-working-directory")
        if (matching.Length > 1)
            return ProcessObservation.Unknown(this.CapturedAtTicks,
                "process-working-directory", "安装目录内存在多个候选进程",
                ProcessObservationReason.AmbiguousTarget)
        if uncertainMatching.Length {
            return ProcessObservation.Unknown(this.CapturedAtTicks,
                "process-working-directory", "候选进程的创建身份无法核对",
                ProcessObservationReason.ProcessIdentityUnavailable)
        }
        if (preferredName != "" && this.HasLiveEntryWithoutValue(this.ByName,
            preferredName, "exe")) {
            return ProcessObservation.Unknown(this.CapturedAtTicks,
                "process-working-directory", "同名进程的镜像路径不可用",
                ProcessObservationReason.InaccessibleImagePath)
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
        identityUnavailable := false
        runningCandidates := []
        for processInfo in indexMap[key] {
            liveStatus := this.GetLiveStatus(processInfo)
            if liveStatus > 0
                runningCandidates.Push(processInfo)
            if liveStatus < 0
                identityUnavailable := true
        }
        if runningCandidates.Length
            return this.RunningObservation(
                this.SelectOldestCandidate(runningCandidates), source)
        if identityUnavailable {
            return ProcessObservation.Unknown(this.CapturedAtTicks, source,
                "候选进程的创建身份无法核对",
                ProcessObservationReason.ProcessIdentityUnavailable)
        }
        return ProcessObservation.Stopped(this.CapturedAtTicks, source,
            "快照中的候选 PID 已结束")
    }

    SelectOldestCandidate(candidates) {
        selected := candidates[1]
        selectedCreation := this.GetCreationSortValue(selected)
        for index, processInfo in candidates {
            if index == 1
                continue
            candidateCreation := this.GetCreationSortValue(processInfo)
            if (candidateCreation > 0
                && (!selectedCreation
                    || candidateCreation < selectedCreation)) {
                selected := processInfo
                selectedCreation := candidateCreation
                continue
            }
            if (candidateCreation == selectedCreation
                && this.ProcessIdValue(processInfo)
                    < this.ProcessIdValue(selected)) {
                selected := processInfo
                selectedCreation := candidateCreation
            }
        }
        return selected
    }

    GetCreationSortValue(processInfo) {
        identity := processInfo.HasOwnProp("identity")
            ? String(processInfo.identity) : ""
        if identity == "" && processInfo.HasOwnProp("creation")
            && RegExMatch(String(processInfo.creation), "i)^[0-9a-f]{16}$")
            identity := String(processInfo.creation)
        if !RegExMatch(identity, "i)^[0-9a-f]{16}$")
            return 0
        try return Integer("0x" identity)
        catch
            return 0
    }

    ProcessIdValue(processInfo) {
        try return Integer(processInfo.pid)
        catch
            return 0x7FFFFFFF
    }

    HasLiveEntry(indexMap, key) {
        if (key == "" || !indexMap.Has(key))
            return false
        for processInfo in indexMap[key]
            if this.GetLiveStatus(processInfo) != 0
                return true
        return false
    }

    HasLiveEntryWithoutValue(indexMap, key, propertyName) {
        if (key == "" || !indexMap.Has(key))
            return false
        for processInfo in indexMap[key] {
            if this.GetLiveStatus(processInfo) != 0
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
            if this.GetLiveStatus(processInfo) != 0
                && (!processInfo.HasOwnProp("cmd") || processInfo.cmd == "")
                return true
        }
        return false
    }

    RunningObservation(processInfo, source) {
        creationIdentity := processInfo.HasOwnProp("identity")
            && processInfo.identity != "" ? processInfo.identity
            : (processInfo.HasOwnProp("creation") ? processInfo.creation : "")
        return ProcessObservation.Running(processInfo.pid, creationIdentity,
            this.CapturedAtTicks, source)
    }

    GetLiveStatus(processInfo) {
        if !IsObject(processInfo) || !processInfo.HasOwnProp("pid")
            || !processInfo.pid || !ProcessExist(processInfo.pid) {
            return 0
        }
        expectedIdentity := processInfo.HasOwnProp("identity")
            ? String(processInfo.identity) : ""
        if expectedIdentity == "" && processInfo.HasOwnProp("creation")
            && RegExMatch(String(processInfo.creation), "i)^[0-9a-f]{16}$") {
            ; 单元调用方和原生适配器可直接把 FILETIME 身份放在 creation；
            ; WMI 的 CreationDate 具有完全不同的长时间戳格式，不会误入此分支。
            expectedIdentity := String(processInfo.creation)
        }
        if !IsObject(this.CreationIdentityResolver)
            return 1
        if expectedIdentity == ""
            return -1
        try currentIdentity := String(
            this.CreationIdentityResolver.Call(processInfo.pid))
        catch
            return -1
        if currentIdentity == ""
            return -1
        return currentIdentity == expectedIdentity ? 1 : 0
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
            "identity", "observedTicks"] {
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
            case "py", "pyw": return RegExMatch(launcherName,
                "^(?:py|python(?:w|\d+(?:\.\d+)?w?)?)\.exe$") != 0
            case "js": return RegExMatch(launcherName,
                "^(?:nodew?|deno|bun|wscript|cscript)\.exe$") != 0
            case "vbs", "vbe", "wsf": return RegExMatch(launcherName, "^(?:wscript|cscript)\.exe$") != 0
            case "ps1": return RegExMatch(launcherName,
                "^(?:powershell(?:_ise)?|pwsh(?:-preview)?)\.exe$") != 0
            case "bat", "cmd": return launcherName == "cmd.exe"
            case "rb": return RegExMatch(launcherName, "^rubyw?\.exe$") != 0
            case "pl": return RegExMatch(launcherName,
                "^(?:w?perl)(?:\d+(?:\.\d+)*)?\.exe$") != 0
            case "php": return RegExMatch(launcherName,
                "^php(?:-cgi|-win)?\.exe$") != 0
            case "lua": return RegExMatch(launcherName,
                "^(?:lua(?:jit|\d+(?:\.\d+)*)?|luajit)\.exe$") != 0
            case "jar": return RegExMatch(launcherName, "^javaw?\.exe$") != 0
            case "sh", "bash": return RegExMatch(launcherName,
                "^(?:bash|sh|zsh|dash)\.exe$") != 0
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
        ; Run 可以用 PATH 中无扩展名的命令启动程序，WMI 会原样保留该命令行。
        ; 后续只匹配受支持的启动器白名单，因此在这里补齐 .exe 不会扩大识别范围。
        if !InStr(launcherName, ".")
            launcherName .= ".exe"
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
        skipNextArgument := false
        for index, argument in arguments {
            if index == 1
                continue
            if skipNextArgument {
                skipNextArgument := false
                continue
            }
            if this.LauncherOptionConsumesNext(launcherName, argument) {
                skipNextArgument := true
                continue
            }
            if this.LauncherExecutesCodeOrModule(launcherName, argument)
                return result
            if (argument == "" || SubStr(argument, 1, 1) == "-"
                || SubStr(argument, 1, 1) == "/")
                continue
            if (this.AddEmbeddedCommandCandidates(result, argument)
                || this.AddCommandCandidate(result, argument))
                break
        }
        return result
    }

    static LauncherExecutesCodeOrModule(launcherName, argument) {
        option := StrLower(argument)
        if RegExMatch(launcherName,
            "i)^(?:py|python(?:w|\d+(?:\.\d+)?w?)?)\.exe$") {
            return RegExMatch(option, "^(?:-c|-m)$") != 0
                || RegExMatch(option, "^-c.+$") != 0
        }
        if RegExMatch(launcherName, "i)^(?:nodew?|bun)\.exe$") {
            return RegExMatch(option,
                "^(?:-e|--eval|-p|--print)(?:=.*)?$") != 0
        }
        if RegExMatch(launcherName, "i)^deno\.exe$")
            return option == "eval"
        if RegExMatch(launcherName,
            "i)^(?:rubyw?|w?perl(?:\d+(?:\.\d+)*)?|php(?:-cgi|-win)?|lua(?:jit|\d+(?:\.\d+)*)?|luajit)\.exe$") {
            return RegExMatch(option,
                "^(?:-e|-r|--eval)(?:=.*)?$") != 0
        }
        return false
    }

    static LauncherOptionConsumesNext(launcherName, argument) {
        option := StrLower(argument)
        if RegExMatch(launcherName, "i)^(?:nodew?)\.exe$") {
            return RegExMatch(option,
                "^(?:-r|--require|--import|--loader|--experimental-loader)$") != 0
        }
        if RegExMatch(launcherName, "i)^bun\.exe$")
            return RegExMatch(option, "^(?:-r|--preload)$") != 0
        if RegExMatch(launcherName, "i)^deno\.exe$") {
            return RegExMatch(option,
                "^(?:-c|--config|--import-map|--cert|--location)$") != 0
        }
        if RegExMatch(launcherName,
            "i)^(?:py|python(?:w|\d+(?:\.\d+)?w?)?)\.exe$") {
            return RegExMatch(option,
                "^(?:-w|-x|--check-hash-based-pycs)$") != 0
        }
        if RegExMatch(launcherName, "i)^rubyw?\.exe$")
            return RegExMatch(option, "^(?:-r|--require|-i|-e)$") != 0
        if RegExMatch(launcherName, "i)^(?:bash|sh|zsh|dash)\.exe$") {
            return RegExMatch(option,
                "^(?:--rcfile|--init-file|--profile|-o)$") != 0
        }
        return false
    }

    static IsSupportedCommandLauncher(launcherName) {
        return RegExMatch(launcherName,
            "i)^(?:autohotkey.*|py|python(?:w|\d+(?:\.\d+)?w?)?|nodew?|deno|bun|wscript|cscript|rubyw?|w?perl(?:\d+(?:\.\d+)*)?|php(?:-cgi|-win)?|lua(?:jit|\d+(?:\.\d+)*)?|luajit|bash|sh|zsh|dash|powershell(?:_ise)?|pwsh(?:-preview)?|javaw?|cmd|mmc)\.exe$") != 0
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
