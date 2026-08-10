; 软件升级相关进程的身份匹配器。
; 综合进程路径、父子关系、命令行、安装目录和已学习特征判断更新参与者；
; 单一弱信号不会直接进入升级保护，PID 还必须与创建时间配对以防复用误认。

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
        targetCreationIdentity := "", processMap := "", maintenanceBlocking := false,
        trackedActorAnchors := "", confirmedFootprint := false) {
        context := this.CreateMatchContext(targetPath, rootPath, learnedActors,
            targetPid, targetCreationIdentity, processMap,
            maintenanceBlocking, trackedActorAnchors, confirmedFootprint)
        return this.MatchPrepared(processInfo, context)
    }

    CreateMatchContext(targetPath, rootPath, learnedActors, targetPid := 0,
        targetCreationIdentity := "", processMap := "", maintenanceBlocking := false,
        trackedActorAnchors := "", confirmedFootprint := false) {
        canonicalRoot := this.Canonical(rootPath)
        return {
            TargetPath: this.Canonical(targetPath),
            RootPath: canonicalRoot,
            LearnedPaths: this.BuildLearnedPathSet(learnedActors,
                canonicalRoot),
            TargetPid: targetPid,
            TargetCreationIdentity: targetCreationIdentity,
            ProcessMap: processMap,
            MaintenanceBlocking: !!maintenanceBlocking,
            TrackedActorAnchors: trackedActorAnchors,
            ConfirmedFootprint: !!confirmedFootprint
        }
    }

    MatchPrepared(processInfo, context) {
        targetPid := context.TargetPid
        pid := this.Value(processInfo, "pid", 0)
        if !pid || (targetPid && pid == targetPid)
            return MaintenanceActorMatchResult(false)

        executablePath := this.CanonicalExecutablePath(processInfo)
        targetPath := context.TargetPath
        rootPath := context.RootPath
        if (executablePath != "" && targetPath != ""
            && executablePath == targetPath)
            return MaintenanceActorMatchResult(false)

        learned := executablePath != ""
            && context.LearnedPaths.Has(executablePath)
        installerLike := this.Value(processInfo, "installerLike",
            this.IsInstallerLike(processInfo))
        underRoot := executablePath != ""
            && this.CanonicalPathIsWithinRoot(executablePath, rootPath)
        referencesRoot := this.ReferencesCanonicalRoot(processInfo,
            targetPath, rootPath)
        descendant := this.IsDescendantOfTarget(processInfo, targetPid,
            context.TargetCreationIdentity, context.ProcessMap)
        actorDescendant := context.MaintenanceBlocking
            && this.IsDescendantOfTrackedActor(processInfo,
                context.ProcessMap, context.TrackedActorAnchors)
        evidence := ""
        if learned
            evidence := "learned-scoped-path"
        else if installerLike && underRoot
            evidence := "installer-under-root"
        else if installerLike && referencesRoot
            evidence := "installer-references-root"
        else if installerLike && descendant
            evidence := "installer-descendant"
        else if context.MaintenanceBlocking && context.ConfirmedFootprint
            && installerLike
            ; 例如由 Windows Installer 服务代理的 msiexec，命令行可能只有
            ; 产品代码，既不在安装目录内，也没有目标父进程关系。只有目标
            ; 足迹已经发生变化时才接受这条弱关联，避免普通运行期误匹配。
            evidence := "maintenance-installer-signal"
        else if context.MaintenanceBlocking && context.ConfirmedFootprint
            && underRoot
            evidence := "maintenance-under-root"
        else if context.MaintenanceBlocking && context.ConfirmedFootprint
            && referencesRoot
            evidence := "maintenance-references-root"
        else if context.MaintenanceBlocking && (descendant || actorDescendant)
            evidence := "maintenance-descendant"
        if evidence == ""
            return MaintenanceActorMatchResult(false)

        signature := evidence == "maintenance-installer-signal" ? ""
            : this.BuildLearningSignature(processInfo, rootPath)
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
        return this.GetIdentityStatus(identity) != 0
    }

    GetIdentityStatus(identity) {
        if !(identity is MaintenanceActorIdentity) || !ProcessExist(identity.PID)
            return 0
        currentCreation := this.ResolveLiveCreation(identity.PID)
        if currentCreation == ""
            return -1
        return currentCreation == identity.CreationIdentity ? 1 : 0
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
                || this.GetIdentityStatus(identity) == 0
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
        executablePath := this.CanonicalExecutablePath(processInfo)
        if executablePath == ""
            return false
        if Type(learnedActors) == "Map"
            return learnedActors.Has(executablePath)
        if Type(learnedActors) != "Array"
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
        ; 旧版本可能把 msiexec、winget 等全局工具写入学习记录。其完整
        ; 路径不能证明以后仍服务于本目标，因此只接受安装根内的专属程序。
        if !this.PathIsWithinRoot(executablePath, signatureRoot)
            return ""
        return "P:" executablePath "|R:" signatureRoot
    }

    BuildLearningSignature(processInfo, rootPath) {
        executablePath := this.CanonicalExecutablePath(processInfo)
        rootPath := this.Canonical(rootPath)
        if executablePath == "" || rootPath == ""
            return ""
        if !this.CanonicalPathIsWithinRoot(executablePath, rootPath)
            || this.CanonicalPathIsWithinRoot(executablePath,
                this.Canonical(A_Temp))
            return ""
        return "P:" executablePath "|R:" rootPath
    }

    SignatureExecutablePath(signature) {
        scopeMarker := InStr(signature, "|R:", false, 3)
        return scopeMarker ? SubStr(signature, 3, scopeMarker - 3) : ""
    }

    ReferencesRoot(processInfo, targetPath, rootPath) {
        return this.ReferencesCanonicalRoot(processInfo,
            this.Canonical(targetPath), this.Canonical(rootPath))
    }

    ReferencesCanonicalRoot(processInfo, targetPath, rootPath) {
        if rootPath == ""
            return false
        for candidate in this.CanonicalCommandPaths(processInfo) {
            if (candidate == targetPath
                || this.CanonicalPathIsWithinRoot(candidate, rootPath))
                return true
        }
        return false
    }

    CanonicalCommandPaths(processInfo) {
        if processInfo.HasOwnProp("maintenanceCommandPaths")
            return processInfo.maintenanceCommandPaths
        paths := []
        for argument in this.ParseCommandLine(
                this.Value(processInfo, "cmd", "")) {
            candidate := Trim(argument, " `t`r`n`"',;()")
            separator := InStr(candidate, "=")
            if (separator > 0 && separator < StrLen(candidate))
                candidate := SubStr(candidate, separator + 1)
            candidate := this.Canonical(candidate)
            if candidate != ""
                && RegExMatch(candidate, "i)^[a-z]:\\|^\\\\")
                paths.Push(candidate)
        }
        processInfo.maintenanceCommandPaths := paths
        return paths
    }

    CanonicalExecutablePath(processInfo) {
        if processInfo.HasOwnProp("maintenanceCanonicalExe")
            return processInfo.maintenanceCanonicalExe
        executablePath := this.Canonical(this.Value(processInfo, "exe", ""))
        processInfo.maintenanceCanonicalExe := executablePath
        return executablePath
    }

    IsDescendantOfTarget(processInfo, targetPid, targetCreationIdentity,
        processMap := "") {
        if !targetPid || targetCreationIdentity == ""
            return false
        if ProcessExist(targetPid) {
            currentCreation := this.ResolveLiveCreation(targetPid)
            if (currentCreation == ""
                || currentCreation != targetCreationIdentity)
                return false
        } else {
            ; 目标可能在创建更新器后立即退出。此时只能使用同一份快照中
            ; 已记录的创建身份继续追溯，绝不能让一个旧 PID 单独充当父链锚点。
            if Type(processMap) != "Map" || !processMap.Has(targetPid)
                return false
            snapshotTarget := processMap[targetPid]
            snapshotCreation := this.Value(snapshotTarget, "identity", "")
            if snapshotCreation == ""
                snapshotCreation := this.Value(snapshotTarget,
                    "liveCreationIdentity", "")
            if (snapshotCreation == ""
                || snapshotCreation != targetCreationIdentity)
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

    BuildActorAnchorMap(actorRecords) {
        anchors := Map()
        this.AddActorAnchors(anchors, actorRecords)
        return anchors
    }

    AddActorAnchors(anchors, actorRecords) {
        if Type(anchors) != "Map" || Type(actorRecords) != "Map"
            return anchors
        for _, actorRecord in actorRecords {
            if !IsObject(actorRecord) || !actorRecord.HasOwnProp("Identity")
                || !(actorRecord.Identity is MaintenanceActorIdentity) {
                continue
            }
            identity := actorRecord.Identity
            if !anchors.Has(identity.PID)
                anchors[identity.PID] := []
            anchors[identity.PID].Push(identity)
        }
        return anchors
    }

    IsDescendantOfTrackedActor(processInfo, processMap, actorAnchors) {
        if Type(actorAnchors) != "Map" || !actorAnchors.Count
            return false
        parentPid := this.Value(processInfo, "parent", 0)
        childInfo := processInfo
        visited := Map()
        Loop 16 {
            if !parentPid || visited.Has(parentPid)
                return false
            if actorAnchors.Has(parentPid) {
                for actorIdentity in actorAnchors[parentPid] {
                    if this.ActorAnchorMatches(actorIdentity, parentPid,
                        childInfo, processMap) {
                        return true
                    }
                }
            }
            visited[parentPid] := true
            if Type(processMap) != "Map" || !processMap.Has(parentPid)
                return false
            childInfo := processMap[parentPid]
            parentPid := this.Value(childInfo, "parent", 0)
        }
        return false
    }

    BuildLearnedPathSet(learnedActors, rootPath) {
        learnedPaths := Map()
        learnedPaths.CaseSense := "Off"
        if Type(learnedActors) != "Array"
            return learnedPaths
        for signature in learnedActors {
            normalized := this.NormalizeLearnedSignature(signature, rootPath)
            if normalized != ""
                learnedPaths[this.SignatureExecutablePath(normalized)] := true
        }
        return learnedPaths
    }

    ActorAnchorMatches(identity, actorPid, childInfo, processMap) {
        if !(identity is MaintenanceActorIdentity)
            || identity.PID != actorPid {
            return false
        }
        if Type(processMap) == "Map" && processMap.Has(actorPid) {
            actorInfo := processMap[actorPid]
            snapshotIdentity := this.ProcessCreationIdentity(actorInfo)
            return snapshotIdentity != ""
                && snapshotIdentity == identity.CreationIdentity
        }
        identityStatus := this.GetIdentityStatus(identity)
        if identityStatus > 0
            return true
        if identityStatus < 0
            return false
        ; 父更新器可能已经退出，子进程仍保留原父 PID。只有子进程的
        ; FILETIME 创建身份明确晚于已跟踪父进程时，才接受这次短命交接。
        childCreation := this.ProcessCreationIdentity(childInfo)
        return this.CreationIdentityIsLater(childCreation,
            identity.CreationIdentity)
    }

    ProcessCreationIdentity(processInfo) {
        creationIdentity := this.Value(processInfo,
            "liveCreationIdentity", "")
        if creationIdentity == ""
            creationIdentity := this.Value(processInfo, "identity", "")
        if creationIdentity == "" {
            pid := this.Value(processInfo, "pid", 0)
            if pid
                creationIdentity := this.ResolveLiveCreation(pid)
            if creationIdentity != ""
                processInfo.liveCreationIdentity := creationIdentity
        }
        return String(creationIdentity)
    }

    CreationIdentityIsLater(candidateIdentity, earlierIdentity) {
        candidateIdentity := String(candidateIdentity)
        earlierIdentity := String(earlierIdentity)
        if !RegExMatch(candidateIdentity, "i)^[0-9a-f]{16}$")
            || !RegExMatch(earlierIdentity, "i)^[0-9a-f]{16}$") {
            return false
        }
        try return Integer("0x" candidateIdentity)
            > Integer("0x" earlierIdentity)
        catch
            return false
    }

    PathIsWithinRoot(candidatePath, rootPath) {
        candidatePath := this.Canonical(candidatePath)
        rootPath := this.Canonical(rootPath)
        return this.CanonicalPathIsWithinRoot(candidatePath, rootPath)
    }

    CanonicalPathIsWithinRoot(candidatePath, rootPath) {
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
