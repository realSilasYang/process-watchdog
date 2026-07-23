class MaintenanceActorIdentity {
    __New(pid, creationIdentity, imagePath, rootPath, parentChain) {
        this.PID := Integer(pid)
        this.CreationIdentity := creationIdentity
        this.ImagePath := imagePath
        this.RootPath := rootPath
        this.ParentChain := parentChain
        this.Key := this.PID ":" this.CreationIdentity
    }
}

class MaintenanceActorMatchResult {
    __New(matched, evidence := "", learnableSignature := "") {
        this.Matched := !!matched
        this.Evidence := evidence
        this.LearnableSignature := learnableSignature
    }
}

class MaintenanceActorMatcher {
    static InstallerPattern :=
        "(^|[^a-z])(update|updater|upgrade|patch|patcher|setup|install|installer|msiexec|winget|squirrel|mainten|unins)([^a-z]|$)"

    __New(liveCreationResolver := "") {
        this.LiveCreationResolver := liveCreationResolver
    }

    Match(processInfo, targetPath, rootPath, learnedActors, targetPid := 0,
        targetCreationIdentity := "", processMap := "", maintenanceBlocking := false) {
        pid := this.Value(processInfo, "pid", 0)
        if !pid || (targetPid && pid == targetPid)
            return MaintenanceActorMatchResult(false)

        executablePath := this.Canonical(this.Value(processInfo, "exe", ""))
        targetPath := this.Canonical(targetPath)
        rootPath := this.Canonical(rootPath)
        if (executablePath != "" && targetPath != ""
            && executablePath == targetPath)
            return MaintenanceActorMatchResult(false)

        learned := this.MatchesLearnedPath(processInfo, learnedActors, rootPath)
        installerLike := this.Value(processInfo, "installerLike",
            this.IsInstallerLike(processInfo))
        underRoot := executablePath != ""
            && this.PathIsWithinRoot(executablePath, rootPath)
        referencesRoot := this.ReferencesRoot(processInfo, targetPath, rootPath)
        descendant := this.IsDescendantOfTarget(processInfo, targetPid,
            targetCreationIdentity, processMap)
        evidence := ""
        if learned
            evidence := "learned-scoped-path"
        else if installerLike && underRoot
            evidence := "installer-under-root"
        else if installerLike && referencesRoot
            evidence := "installer-references-root"
        else if installerLike && descendant
            evidence := "installer-descendant"
        else if maintenanceBlocking && descendant
            evidence := "maintenance-descendant"
        if evidence == ""
            return MaintenanceActorMatchResult(false)

        signature := this.BuildLearningSignature(processInfo, rootPath)
        return MaintenanceActorMatchResult(true, evidence, signature)
    }

    CreateIdentity(processInfo, rootPath, processMap := "") {
        pid := this.Value(processInfo, "pid", 0)
        if !pid
            return ""
        creationIdentity := this.Value(processInfo, "liveCreationIdentity", "")
        if creationIdentity == "" {
            creationIdentity := this.ResolveLiveCreation(pid)
            if creationIdentity != ""
                processInfo.liveCreationIdentity := creationIdentity
        }
        if creationIdentity == ""
            return ""
        return MaintenanceActorIdentity(pid, creationIdentity,
            this.Canonical(this.Value(processInfo, "exe", "")),
            this.Canonical(rootPath),
            this.BuildParentChain(processInfo, processMap))
    }

    IsIdentityAlive(identity) {
        if !(identity is MaintenanceActorIdentity) || !ProcessExist(identity.PID)
            return false
        currentCreation := this.ResolveLiveCreation(identity.PID)
        return currentCreation != ""
            && currentCreation == identity.CreationIdentity
    }

    RetainLiveRecords(previousRecords, activeRecords) {
        if Type(previousRecords) != "Map" || Type(activeRecords) != "Map"
            return activeRecords
        for identityKey, actorRecord in previousRecords {
            if activeRecords.Has(identityKey)
                continue
            if !IsObject(actorRecord) || !actorRecord.HasOwnProp("Identity")
                continue
            identity := actorRecord.Identity
            if !(identity is MaintenanceActorIdentity)
                || identity.Key != identityKey
                || !this.IsIdentityAlive(identity)
                continue
            activeRecords[identityKey] := actorRecord
        }
        return activeRecords
    }

    IsInstallerLike(processInfo) {
        nameAndCommand := StrLower(this.Value(processInfo, "name", "")
            " " this.Value(processInfo, "cmd", ""))
        return RegExMatch(nameAndCommand,
            MaintenanceActorMatcher.InstallerPattern) != 0
    }

    MatchesLearnedPath(processInfo, learnedActors, rootPath) {
        executablePath := this.Canonical(this.Value(processInfo, "exe", ""))
        if executablePath == "" || Type(learnedActors) != "Array"
            return false
        for signature in learnedActors {
            normalized := this.NormalizeLearnedSignature(signature, rootPath)
            if (normalized != ""
                && executablePath == this.SignatureExecutablePath(normalized))
                return true
        }
        return false
    }

    NormalizeLearnedSignature(signature, rootPath := "") {
        signature := Trim(String(signature))
        if SubStr(signature, 1, 2) != "P:"
            return ""
        scopeMarker := InStr(signature, "|R:", false, 3)
        if !scopeMarker
            return ""
        executablePath := this.Canonical(SubStr(signature, 3,
            scopeMarker - 3))
        signatureRoot := this.Canonical(SubStr(signature, scopeMarker + 3))
        expectedRoot := this.Canonical(rootPath)
        if executablePath == "" || signatureRoot == ""
            return ""
        if (expectedRoot != "" && signatureRoot != expectedRoot)
            return ""
        return "P:" executablePath "|R:" signatureRoot
    }

    BuildLearningSignature(processInfo, rootPath) {
        executablePath := this.Canonical(this.Value(processInfo, "exe", ""))
        rootPath := this.Canonical(rootPath)
        processName := StrLower(Trim(this.Value(processInfo, "name", "")))
        if executablePath == "" || rootPath == ""
            return ""
        if this.PathIsWithinRoot(executablePath, this.Canonical(A_Temp))
            || RegExMatch(processName, "\d{3,}")
            return ""
        return "P:" executablePath "|R:" rootPath
    }

    SignatureExecutablePath(signature) {
        scopeMarker := InStr(signature, "|R:", false, 3)
        return scopeMarker ? SubStr(signature, 3, scopeMarker - 3) : ""
    }

    ReferencesRoot(processInfo, targetPath, rootPath) {
        if rootPath == ""
            return false
        for argument in this.ParseCommandLine(this.Value(processInfo, "cmd", "")) {
            candidate := Trim(argument, " `t`r`n`"',;()")
            separator := InStr(candidate, "=")
            if (separator > 0 && separator < StrLen(candidate))
                candidate := SubStr(candidate, separator + 1)
            candidate := this.Canonical(candidate)
            if candidate == "" || !RegExMatch(candidate, "i)^[a-z]:\\|^\\\\")
                continue
            if (candidate == targetPath
                || this.PathIsWithinRoot(candidate, rootPath))
                return true
        }
        return false
    }

    IsDescendantOfTarget(processInfo, targetPid, targetCreationIdentity,
        processMap := "") {
        if !targetPid
            return false
        if ProcessExist(targetPid) && targetCreationIdentity != "" {
            currentCreation := this.ResolveLiveCreation(targetPid)
            if (currentCreation == ""
                || currentCreation != targetCreationIdentity)
                return false
        }
        parentPid := this.Value(processInfo, "parent", 0)
        visited := Map()
        Loop 16 {
            if !parentPid || visited.Has(parentPid)
                return false
            if parentPid == targetPid
                return true
            visited[parentPid] := true
            if Type(processMap) != "Map" || !processMap.Has(parentPid)
                return false
            parentPid := this.Value(processMap[parentPid], "parent", 0)
        }
        return false
    }

    BuildParentChain(processInfo, processMap := "") {
        chain := []
        parentPid := this.Value(processInfo, "parent", 0)
        visited := Map()
        Loop 16 {
            if !parentPid || visited.Has(parentPid)
                break
            visited[parentPid] := true
            if Type(processMap) != "Map" || !processMap.Has(parentPid) {
                chain.Push(String(parentPid))
                break
            }
            parentInfo := processMap[parentPid]
            parentCreation := this.Value(parentInfo, "creation", "")
            chain.Push(parentPid ":" parentCreation)
            parentPid := this.Value(parentInfo, "parent", 0)
        }
        return chain
    }

    PathIsWithinRoot(candidatePath, rootPath) {
        candidatePath := this.Canonical(candidatePath)
        rootPath := this.Canonical(rootPath)
        if candidatePath == "" || rootPath == ""
            return false
        rootPrefix := SubStr(rootPath, StrLen(rootPath), 1) == "\"
            ? rootPath : rootPath "\"
        return candidatePath == rootPath
            || InStr(candidatePath, rootPrefix) == 1
    }

    Canonical(path) {
        path := Trim(String(path), " `t`r`n`"")
        path := StrReplace(path, "/", "\")
        return StrLower(StrLen(path) > 3 ? RTrim(path, "\") : path)
    }

    ResolveLiveCreation(pid) {
        try return String(this.LiveCreationResolver.Call(pid))
        catch
            return ""
    }

    ParseCommandLine(commandLine) {
        arguments := []
        if Trim(commandLine) == ""
            return arguments
        argumentCount := 0
        argumentVector := DllCall("shell32\CommandLineToArgvW", "WStr",
            commandLine, "Int*", &argumentCount, "Ptr")
        if !argumentVector
            return arguments
        try {
            Loop argumentCount
                arguments.Push(StrGet(NumGet(argumentVector,
                    (A_Index - 1) * A_PtrSize, "Ptr"), "UTF-16"))
        } finally {
            DllCall("kernel32\LocalFree", "Ptr", argumentVector, "Ptr")
        }
        return arguments
    }

    Value(objectValue, propertyName, defaultValue := "") {
        return IsObject(objectValue) && objectValue.HasOwnProp(propertyName)
            ? objectValue.%propertyName% : defaultValue
    }
}
