class ShortcutTargetResolver {
    static MaximumCandidateCount := 200
    static TargetExtensions :=
        "exe|com|msc|ahk|py|pyw|js|vbs|vbe|wsf|ps1|bat|cmd|rb|pl|php|lua|jar|sh|bash"
    static GenericLauncherPattern :=
        "i)^(explorer|cmd|powershell|pwsh|wscript|cscript|rundll32|regsvr32|msiexec|pythonw?|node|javaw?|dotnet|autohotkey.*)\.exe$"
    static AuxiliaryExecutablePattern :=
        "i)(^|[._ -])(update|updater|upgrade|patch|setup|install|unins|uninstall|repair|helper|service|connector|crash|report|telemetry)([._ -]|$)"

    __New(processSnapshots, callbacks) {
        this.ProcessSnapshots := processSnapshots
        this.Callbacks := callbacks
        this.VersionCache := Map()
    }

    Read(path) {
        try descriptor := this.Callbacks.ReadShortcut.Call(path)
        catch as readError
            return ShortcutDescriptor(path, false, "", "", "",
                readError.Message)
        return descriptor is ShortcutDescriptor
            ? descriptor : ShortcutDescriptor(path, false, "", "", "",
                "快捷方式读取器返回了无效结果")
    }

    GetWorkingDirectory(path) {
        descriptor := this.Read(path)
        return descriptor.Readable ? descriptor.WorkingDirectory : ""
    }

    GetTargetPath(path) {
        descriptor := this.Read(path)
        return descriptor.Readable ? descriptor.TargetPath : ""
    }

    IsValidExecutableFile(path) {
        if !FileExist(path) || DirExist(path)
            return false
        fileHandle := DllCall("kernel32\CreateFileW", "WStr", path,
            "UInt", 0x80000000, "UInt", Win32.FILE_SHARE_ALL, "Ptr", 0,
            "UInt", Win32.OPEN_EXISTING, "UInt", Win32.FILE_ATTRIBUTE_NORMAL,
            "Ptr", 0, "Ptr")
        if (!fileHandle || fileHandle == -1)
            return false
        header := Buffer(2, 0)
        bytesRead := 0
        try {
            if !DllCall("kernel32\ReadFile", "Ptr", fileHandle,
                "Ptr", header.Ptr, "UInt", 2, "UInt*", &bytesRead,
                "Ptr", 0, "Int")
                return false
        } finally {
            DllCall("kernel32\CloseHandle", "Ptr", fileHandle)
        }
        return bytesRead == 2 && NumGet(header, 0, "UShort") == 0x5A4D
    }

    IsUsableTarget(path) {
        if !FileExist(path) || DirExist(path)
            return false
        if !this.IsPotentialProcessTarget(path)
            return false
        SplitPath(path, , , &extension)
        extension := StrLower(extension)
        return extension != "exe" && extension != "com"
            || this.IsValidExecutableFile(path)
    }

    IsGenericLauncher(path) {
        SplitPath(path, &fileName)
        return RegExMatch(fileName,
            ShortcutTargetResolver.GenericLauncherPattern) != 0
    }

    IsAuxiliaryExecutableName(fileName) {
        if RegExMatch(fileName,
            ShortcutTargetResolver.AuxiliaryExecutablePattern)
            return true
        SplitPath(fileName, , , , &baseName)
        return RegExMatch(baseName,
            "i)^(?:update|updater|upgrade|patch|setup|install|installer|unins|uninstall|repair|helper|connector|crashreport|telemetry)")
            || RegExMatch(baseName,
                "i)(?:update|updater|upgrade|patch|setup|installer|unins|uninstall|repair|helper|connector|crashreport|telemetry)$")
    }

    ExtractArgumentTarget(arguments) {
        if (arguments == "")
            return ""
        extensions := ShortcutTargetResolver.TargetExtensions
        matched := RegExMatch(arguments,
            "i)\x22([a-z]:\\[^\x22]+\.(?:" extensions "))\x22", &match)
        if !matched {
            matched := RegExMatch(arguments,
                "i)(?:^|\s|=)([a-z]:\\.+?\.(?:" extensions
                    "))(?=\s|$)", &match)
        }
        if matched {
            candidatePath := Trim(match[1])
            if this.IsUsableTarget(candidatePath)
                return candidatePath
        }
        return ""
    }

    IsPotentialProcessTarget(path) {
        return TargetSpecFactory.IsPreciseProcessIdentityPath(path)
    }

    ResolveMsiTarget(path) {
        productCode := Buffer(39 * 2, 0)
        featureId := Buffer(256 * 2, 0)
        componentCode := Buffer(39 * 2, 0)
        try result := DllCall("msi\MsiGetShortcutTargetW", "WStr", path,
            "Ptr", productCode.Ptr, "Ptr", featureId.Ptr,
            "Ptr", componentCode.Ptr, "UInt")
        catch
            return ""
        if result != 0
            return ""

        pathLength := 32767
        pathBuffer := Buffer((pathLength + 1) * 2, 0)
        try installState := DllCall("msi\MsiGetComponentPathW",
            "Ptr", productCode.Ptr, "Ptr", componentCode.Ptr,
            "Ptr", pathBuffer.Ptr, "UInt*", &pathLength, "Int")
        catch
            return ""
        if (installState < 0 || pathLength == 0)
            return ""
        resolvedPath := StrGet(pathBuffer.Ptr, pathLength, "UTF-16")
        return this.IsPotentialProcessTarget(resolvedPath)
            ? resolvedPath : ""
    }

    GetExecutableVersionValues(path) {
        values := Map()
        values.CaseSense := "Off"
        try cacheKey := this.Callbacks.CanonicalPath.Call(path) "|"
            . this.Callbacks.GetFileFingerprint.Call(path)
        catch
            return values
        if this.VersionCache.Has(cacheKey)
            return this.VersionCache[cacheKey]

        ignoredHandle := 0
        try infoSize := DllCall("version\GetFileVersionInfoSizeW",
            "WStr", path, "UInt*", &ignoredHandle, "UInt")
        catch
            return values
        if !infoSize
            return values
        infoBuffer := Buffer(infoSize, 0)
        try {
            if !DllCall("version\GetFileVersionInfoW", "WStr", path,
                "UInt", 0, "UInt", infoSize, "Ptr", infoBuffer.Ptr, "Int")
                return values
        } catch {
            return values
        }

        translations := []
        translationPtr := 0
        translationBytes := 0
        try {
            if DllCall("version\VerQueryValueW", "Ptr", infoBuffer.Ptr,
                "WStr", "\VarFileInfo\Translation", "Ptr*", &translationPtr,
                "UInt*", &translationBytes, "Int") {
                Loop translationBytes // 4 {
                    offset := (A_Index - 1) * 4
                    language := NumGet(translationPtr, offset, "UShort")
                    codePage := NumGet(translationPtr, offset + 2, "UShort")
                    translations.Push(Format("{:04X}{:04X}", language,
                        codePage))
                }
            }
        }
        for fieldName in ["ProductName", "FileDescription", "InternalName",
            "OriginalFilename"] {
            values[fieldName] := ""
            for translation in translations {
                valuePtr := 0
                valueLength := 0
                queryPath := "\StringFileInfo\" translation "\" fieldName
                try {
                    if DllCall("version\VerQueryValueW", "Ptr", infoBuffer.Ptr,
                        "WStr", queryPath, "Ptr*", &valuePtr,
                        "UInt*", &valueLength, "Int") && valuePtr
                        && valueLength {
                        values[fieldName] := Trim(StrGet(valuePtr, "UTF-16"))
                        break
                    }
                }
            }
        }
        if (this.VersionCache.Count >= 1000)
            this.VersionCache.Clear()
        this.VersionCache[cacheKey] := values
        return values
    }

    NormalizeIdentityText(value) {
        return RegExReplace(StrLower(Trim(value)), "[^\p{L}\p{N}]+")
    }

    ScoreIdentityText(wanted, candidate) {
        wanted := this.NormalizeIdentityText(wanted)
        candidate := this.NormalizeIdentityText(candidate)
        if (wanted == "" || candidate == "")
            return 0
        if (wanted == candidate)
            return 120
        if (StrLen(wanted) >= 4 && StrLen(candidate) >= 4
            && (InStr(candidate, wanted) || InStr(wanted, candidate)))
            return 55
        return 0
    }

    IsObservedProcessPath(path) {
        try {
            if !this.ProcessSnapshots.HasFreshSnapshot(30000)
                return false
            wanted := this.Callbacks.CanonicalPath.Call(path)
            for processInfo in this.ProcessSnapshots.LatestSnapshot {
                if (processInfo.exe != ""
                    && this.Callbacks.CanonicalPath.Call(processInfo.exe)
                        == wanted)
                    return true
            }
        }
        return false
    }

    ScoreExecutableCandidate(shortcutName, workingDir, candidatePath) {
        SplitPath(candidatePath, &candidateName, , , &candidateBase)
        SplitPath(RTrim(workingDir, "\"), , , , &directoryName)
        score := this.ScoreIdentityText(shortcutName, candidateBase)
        score += this.ScoreIdentityText(directoryName, candidateBase) // 3
        versionValues := this.GetExecutableVersionValues(candidatePath)
        for fieldName in ["ProductName", "FileDescription", "InternalName",
            "OriginalFilename"] {
            identityValue := versionValues.Has(fieldName)
                ? versionValues[fieldName] : ""
            score += this.ScoreIdentityText(shortcutName, identityValue)
            score += this.ScoreIdentityText(directoryName, identityValue) // 4
        }
        if this.IsObservedProcessPath(candidatePath)
            score += 45
        if this.IsAuxiliaryExecutableName(candidateName)
            score -= 90
        return score
    }

    FindExecutableCandidate(path, workingDir) {
        if !DirExist(workingDir)
            return ""
        shortcutName := ""
        SplitPath(path, , , , &shortcutName)
        candidates := []
        try {
            Loop Files, RTrim(workingDir, "\") "\*.exe", "F" {
                if this.IsValidExecutableFile(A_LoopFileFullPath)
                    candidates.Push(A_LoopFileFullPath)
                if (candidates.Length
                    >= ShortcutTargetResolver.MaximumCandidateCount)
                    break
            }
            if (candidates.Length
                >= ShortcutTargetResolver.MaximumCandidateCount)
                return ""
            Loop Files, RTrim(workingDir, "\") "\*.com", "F" {
                if this.IsValidExecutableFile(A_LoopFileFullPath)
                    candidates.Push(A_LoopFileFullPath)
                if (candidates.Length
                    >= ShortcutTargetResolver.MaximumCandidateCount)
                    break
            }
        }
        if (candidates.Length == 1) {
            SplitPath(candidates[1], &onlyName)
            return this.IsAuxiliaryExecutableName(onlyName)
                ? "" : candidates[1]
        }
        if (candidates.Length == 0
            || candidates.Length >= ShortcutTargetResolver.MaximumCandidateCount)
            return ""

        bestPath := ""
        bestScore := -100000
        secondScore := -100000
        for candidatePath in candidates {
            score := this.ScoreExecutableCandidate(shortcutName, workingDir,
                candidatePath)
            if (score > bestScore) {
                secondScore := bestScore
                bestScore := score
                bestPath := candidatePath
            } else if (score > secondScore) {
                secondScore := score
            }
        }
        return bestScore >= 100 && bestScore - secondScore >= 20
            ? bestPath : ""
    }

    ResolveEffective(path, allowMissing := false, &resolutionSource := "") {
        resolutionSource := ""
        msiTarget := this.ResolveMsiTarget(path)
        if (msiTarget != ""
            && (allowMissing || this.IsUsableTarget(msiTarget))) {
            resolutionSource := "Windows Installer"
            return msiTarget
        }

        descriptor := this.Read(path)
        if !descriptor.Readable
            return ""
        argumentTarget := this.ExtractArgumentTarget(descriptor.Arguments)
        if (argumentTarget != "") {
            resolutionSource := "快捷方式参数"
            return argumentTarget
        }
        if (descriptor.TargetPath != ""
            && this.IsUsableTarget(descriptor.TargetPath)
            && (descriptor.Arguments == ""
                || !this.IsGenericLauncher(descriptor.TargetPath))) {
            resolutionSource := "快捷方式目标"
            return descriptor.TargetPath
        }
        if (descriptor.WorkingDirectory == "")
            return ""

        candidatePath := this.FindExecutableCandidate(path,
            descriptor.WorkingDirectory)
        if (candidatePath != "") {
            resolutionSource := "安装目录特征"
            return candidatePath
        }
        return ""
    }

    ResolveForState(path, savedTarget := "", &resolutionSource := "",
        manualOverride := false) {
        normalizedSavedTarget := this.Callbacks.NormalizeTargetPath.Call(
            savedTarget)
        if (manualOverride
            && this.IsPotentialProcessTarget(normalizedSavedTarget)) {
            resolutionSource := "用户指定"
            return normalizedSavedTarget
        }
        freshTarget := this.ResolveEffective(path, true, &resolutionSource)
        if (freshTarget != "")
            return freshTarget
        if this.IsPotentialProcessTarget(normalizedSavedTarget) {
            resolutionSource := "已保存身份"
            return normalizedSavedTarget
        }
        resolutionSource := ""
        return ""
    }
}
