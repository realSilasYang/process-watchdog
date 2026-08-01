; Everything 后台实例的本机发现与启动服务。
; 只检查注册信息、标准目录、PATH 和用户可见快捷方式等有界来源，不在 GUI 线程
; 执行全盘递归扫描；找到 Everything.exe 后使用官方 -startup 参数后台启动。

class EverythingRuntimeStartResult {
    __New(found := false, started := false, path := "", pid := 0,
        failure := "", discoverySummary := "") {
        this.Found := !!found
        this.Started := !!started
        this.Path := path
        this.PID := pid ? Integer(pid) : 0
        this.Failure := failure
        this.DiscoverySummary := discoverySummary
    }
}

class EverythingRuntimeService {
    static DownloadUrl := "https://www.voidtools.com/downloads/"
    static MaximumShortcutCandidates := 64

    __New(callbacks := "") {
        this.CachedExecutable := ""
        this.LastDiscoverySummary := ""
        this.LastCandidateCount := 0
        this.CandidateCollector := this.GetCallback(callbacks,
            "CollectCandidates")
        this.FileExistsCallback := this.GetCallback(callbacks, "FileExists")
        this.LaunchCallback := this.GetCallback(callbacks, "Launch")
    }

    GetCallback(callbacks, name) {
        return IsObject(callbacks) && callbacks.HasOwnProp(name)
            && IsObject(callbacks.%name%) ? callbacks.%name% : ""
    }

    FindExecutable(forceRefresh := false) {
        if !forceRefresh && this.IsExecutable(this.CachedExecutable)
            return this.CachedExecutable

        candidates := this.CandidateCollector
            ? this.CandidateCollector.Call() : this.CollectCandidates()
        if Type(candidates) != "Array"
            candidates := []
        this.LastCandidateCount := candidates.Length
        seen := Map()
        seen.CaseSense := "Off"
        for rawCandidate in candidates {
            candidate := this.NormalizeExecutableCandidate(rawCandidate)
            if candidate == "" || seen.Has(candidate)
                continue
            seen[candidate] := true
            if this.IsExecutable(candidate) {
                this.CachedExecutable := candidate
                this.LastDiscoverySummary := this.BuildDiscoverySummary(
                    candidates.Length, candidate)
                return candidate
            }
        }
        this.CachedExecutable := ""
        this.LastDiscoverySummary := this.BuildDiscoverySummary(
            candidates.Length, "")
        return ""
    }

    StartSilently() {
        executablePath := this.FindExecutable()
        if executablePath == ""
            return EverythingRuntimeStartResult(false, false, "", 0,
                "未在注册表、常见安装目录、PATH、桌面或开始菜单快捷方式中找到 Everything.exe。",
                this.LastDiscoverySummary)
        try {
            if this.LaunchCallback
                pid := this.LaunchCallback.Call(executablePath,
                    "-startup", "Hide")
            else {
                pid := 0
                Run('"' executablePath '" -startup', "", "Hide", &pid)
            }
            return EverythingRuntimeStartResult(true, true,
                executablePath, pid, "", this.LastDiscoverySummary)
        } catch as launchError {
            return EverythingRuntimeStartResult(true, false,
                executablePath, 0, launchError.Message,
                this.LastDiscoverySummary)
        }
    }

    BuildDiscoverySummary(candidateCount, selectedPath) {
        if selectedPath != "" {
            return Format("已检查 {1} 个 Everything 候选，采用：{2}",
                candidateCount, selectedPath)
        }
        return Format(
            "已检查 {1} 个 Everything 候选；来源包括注册表、标准安装目录、PATH、桌面和开始菜单快捷方式。",
            candidateCount)
    }

    IsExecutable(path) {
        path := String(path)
        if path == ""
            return false
        if this.FileExistsCallback
            return !!this.FileExistsCallback.Call(path)
        return !!FileExist(path) && !DirExist(path)
    }

    CollectCandidates() {
        candidates := []
        this.AddRegistryCandidates(candidates)
        this.AddKnownPathCandidates(candidates)
        this.AddEnvironmentPathCandidates(candidates)
        this.AddShortcutCandidates(candidates)
        return candidates
    }

    AddRegistryCandidates(candidates) {
        for appPathKey in [
            "HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths\Everything.exe",
            "HKLM\Software\Microsoft\Windows\CurrentVersion\App Paths\Everything.exe",
            "HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\Everything.exe"
        ]
            candidates.Push(this.TryReadDefaultRegistryValue(appPathKey))

        for settingsKey in [
            "HKCU\Software\voidtools\Everything",
            "HKLM\Software\voidtools\Everything",
            "HKLM\Software\WOW6432Node\voidtools\Everything"
        ] {
            installLocation := this.TryReadRegistryValue(settingsKey,
                "InstallLocation")
            if installLocation != ""
                candidates.Push(RTrim(installLocation, "\")
                    "\Everything.exe")
        }

        for uninstallRoot in [
            "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        ] {
            try {
                Loop Reg, uninstallRoot, "K" {
                    itemKey := uninstallRoot "\" A_LoopRegName
                    displayName := this.TryReadRegistryValue(itemKey,
                        "DisplayName")
                    if !RegExMatch(displayName, "i)^Everything(?:\s|$)")
                        continue
                    installLocation := this.TryReadRegistryValue(itemKey,
                        "InstallLocation")
                    if installLocation != ""
                        candidates.Push(RTrim(installLocation, "\")
                            "\Everything.exe")
                    candidates.Push(this.TryReadRegistryValue(itemKey,
                        "DisplayIcon"))
                }
            }
        }
    }

    AddKnownPathCandidates(candidates) {
        programFilesX86 := EnvGet("ProgramFiles(x86)")
        localAppData := EnvGet("LOCALAPPDATA")
        knownPaths := [
            A_ProgramFiles "\Everything\Everything.exe",
            programFilesX86 != ""
                ? programFilesX86 "\Everything\Everything.exe" : "",
            localAppData != ""
                ? localAppData "\Programs\Everything\Everything.exe" : "",
            localAppData != ""
                ? localAppData "\Everything\Everything.exe" : "",
            A_AppData "\Everything\Everything.exe",
            A_ScriptDir "\Everything.exe"
        ]
        for candidate in knownPaths
            candidates.Push(candidate)
    }

    AddEnvironmentPathCandidates(candidates) {
        pathValue := EnvGet("PATH")
        Loop Parse, pathValue, ";" {
            directory := Trim(A_LoopField, " `t`r`n`"")
            if directory != ""
                candidates.Push(RTrim(directory, "\") "\Everything.exe")
        }
    }

    AddShortcutCandidates(candidates) {
        roots := [A_Desktop, A_DesktopCommon, A_StartMenu,
            A_StartMenuCommon]
        visitedRoots := Map()
        visitedRoots.CaseSense := "Off"
        shortcutCount := 0
        for root in roots {
            root := RTrim(String(root), "\")
            if root == "" || !DirExist(root) || visitedRoots.Has(root)
                continue
            visitedRoots[root] := true
            try {
                Loop Files, root "\*Everything*.lnk", "FR" {
                    descriptor := ShortcutResolver.Read(A_LoopFileFullPath)
                    if descriptor.Readable
                        candidates.Push(descriptor.TargetPath)
                    shortcutCount++
                    if shortcutCount
                        >= EverythingRuntimeService.MaximumShortcutCandidates
                        return
                }
            }
        }
    }

    TryReadDefaultRegistryValue(keyName) {
        try return RegRead(keyName)
        catch
            return ""
    }

    TryReadRegistryValue(keyName, valueName) {
        try return RegRead(keyName, valueName)
        catch
            return ""
    }

    NormalizeExecutableCandidate(value) {
        value := Trim(String(value))
        if value == ""
            return ""
        if SubStr(value, 1, 1) == '"' {
            if RegExMatch(value, '^"([^"]+)"', &quotedMatch)
                value := quotedMatch[1]
        } else {
            value := RegExReplace(value, ",\s*-?\d+\s*$")
        }
        value := Trim(value, " `t`r`n`"")
        value := this.ExpandEnvironmentVariables(value)
        return StrReplace(value, "/", "\")
    }

    ExpandEnvironmentVariables(value) {
        if value == "" || !InStr(value, "%")
            return value
        requiredLength := DllCall("kernel32\ExpandEnvironmentStringsW",
            "WStr", value, "Ptr", 0, "UInt", 0, "UInt")
        if !requiredLength
            return value
        output := Buffer(requiredLength * 2, 0)
        copiedLength := DllCall("kernel32\ExpandEnvironmentStringsW",
            "WStr", value, "Ptr", output.Ptr, "UInt", requiredLength,
            "UInt")
        return copiedLength ? StrGet(output, "UTF-16") : value
    }
}
