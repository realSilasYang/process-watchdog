; 直接文件目标的更名与移动识别服务。
; 主路径使用卷序列号和文件 ID 直接找回同一卷内的新位置；目录通知仅作为
; 不支持文件 ID 的回退。候选只冻结对应控制器，必须经用户确认后才会改写配置。

class TargetRelocationService {
    static PollIntervalMs := 500
    static CandidateDelayMs := 1500
    static RenameEventLifetimeMs := 10000
    static RenamePairLifetimeMs := 5000
    static DeliveryRetryIntervalMs := 3000
    static IgnoreCooldownMs := 600000
    static BaselineRefreshIntervalMs := 60000
    static FILE_ACTION_RENAMED_OLD_NAME := 4
    static FILE_ACTION_RENAMED_NEW_NAME := 5

    __New(runtime, callbacks) {
        this.Runtime := runtime
        this.Callbacks := callbacks
        this.Targets := Map()
        this.Targets.CaseSense := "Off"
        this.Watchers := Map()
        this.Watchers.CaseSense := "Off"
        this.RenameHints := Map()
        this.RenameHints.CaseSense := "Off"
        this.PendingCandidates := Map()
        this.PendingCandidates.CaseSense := "Off"
        this.IgnoredCandidates := Map()
        this.IgnoredCandidates.CaseSense := "Off"
        this.NextToken := 1
        this.Running := false
        this.Stopped := false
        this.PollTimer := ObjBindMethod(this, "PollTick")
    }

    Start() {
        if this.Stopped || this.Running
            return false
        this.SyncTargets()
        try SetTimer(this.PollTimer, TargetRelocationService.PollIntervalMs)
        catch
            return false
        this.Running := true
        return true
    }

    Shutdown(*) {
        if this.Stopped
            return
        this.Stopped := true
        this.Running := false
        try SetTimer(this.PollTimer, 0)
        for _, entry in this.Watchers
            try entry.Watcher.Close()
        this.Watchers.Clear()
        for _, candidate in this.PendingCandidates {
            stateObj := candidate.State
            if IsObject(stateObj) && stateObj.HasOwnProp("RelocationPending")
                stateObj.RelocationPending := false
        }
        this.PendingCandidates.Clear()
        this.Targets.Clear()
        this.RenameHints.Clear()
        this.IgnoredCandidates.Clear()
    }

    SyncTargets() {
        if this.Stopped
            return 0
        desired := Map()
        desired.CaseSense := "Off"
        for path, stateObj in this.Runtime.appStates {
            path := this.NormalizePath(path)
            if this.IsEligiblePath(path)
                desired[path] := stateObj
        }

        stalePaths := []
        for path, record in this.Targets {
            if !desired.Has(path) || desired[path] != record.State
                stalePaths.Push(path)
        }
        for path in stalePaths
            this.RemoveTarget(path, false)

        for path, stateObj in desired {
            if this.Targets.Has(path)
                continue
            identity := this.GetIdentity(path)
            record := {
                Path: path,
                State: stateObj,
                Identity: identity,
                MissingObservedTicks: 0,
                LastBaselineTicks: identity.Available ? this.Now() : 0,
                WatchRoot: ""
            }
            this.Targets[path] := record
            this.SubscribeDirectory(record)
        }
        return this.Targets.Count
    }

    RemoveTarget(path, resetState := true) {
        path := this.NormalizePath(path)
        if !this.Targets.Has(path)
            return false
        record := this.Targets[path]
        this.Targets.Delete(path)
        this.UnsubscribeDirectory(record)
        if this.PendingCandidates.Has(path) {
            candidate := this.PendingCandidates[path]
            this.PendingCandidates.Delete(path)
            this.NotifyInvalidated(candidate)
            if resetState
                this.ReleaseState(candidate)
        }
        canonicalPath := this.CanonicalPath(path)
        if this.RenameHints.Has(canonicalPath)
            this.RenameHints.Delete(canonicalPath)
        return true
    }

    IsEligiblePath(path) {
        path := this.NormalizePath(path)
        if path == "" || !InStr(path, "\")
            return false
        SplitPath(path, , , &extension)
        extension := StrLower(extension)
        return RegExMatch(extension,
            "i)^(exe|com|msc|ahk|py|pyw|js|vbs|vbe|wsf|ps1|bat|cmd|rb|pl|php|lua|jar|sh|bash)$") != 0
    }

    ExtensionsCompatible(previousPath, candidatePath) {
        SplitPath(previousPath, , , &previousExtension)
        SplitPath(candidatePath, , , &candidateExtension)
        previousExtension := StrLower(previousExtension)
        candidateExtension := StrLower(candidateExtension)
        if RegExMatch(previousExtension, "i)^(exe|com)$")
            return RegExMatch(candidateExtension, "i)^(exe|com)$") != 0
        return previousExtension != "" && previousExtension == candidateExtension
    }

    ObserveAvailable(path, stateObj, force := false) {
        path := this.NormalizePath(path)
        if !this.IsCurrent(path, stateObj)
            return false
        if !this.Targets.Has(path)
            this.SyncTargets()
        if !this.Targets.Has(path)
            return false
        record := this.Targets[path]
        nowTicks := this.Now()
        if !force && record.LastBaselineTicks
            && nowTicks - record.LastBaselineTicks
                < TargetRelocationService.BaselineRefreshIntervalMs {
            record.MissingObservedTicks := 0
            return false
        }
        identity := this.GetIdentity(path)
        if !identity.Available
            return false
        record.Identity := identity
        record.LastBaselineTicks := nowTicks
        record.MissingObservedTicks := 0
        this.ClearIgnoredForPath(path)
        return true
    }

    TryDetect(path, stateObj) {
        path := this.NormalizePath(path)
        if !this.IsCurrent(path, stateObj) || !stateObj.Enabled
            || !this.IsEligiblePath(path)
            return false
        if stateObj.HasOwnProp("RelocationPending")
            && stateObj.RelocationPending
            return true
        if this.TargetExists(path) {
            this.ObserveAvailable(path, stateObj)
            return false
        }
        if this.PendingCandidates.Has(path)
            return true
        if !this.Targets.Has(path)
            this.SyncTargets()
        if !this.Targets.Has(path)
            return false
        record := this.Targets[path]
        nowTicks := this.Now()
        if !record.MissingObservedTicks {
            record.MissingObservedTicks := nowTicks
            return false
        }
        if nowTicks - record.MissingObservedTicks
            < TargetRelocationService.CandidateDelayMs
            return false
        if this.IsMaintenanceBusy(path, stateObj)
            return false

        candidateInfo := this.ResolveCandidate(record)
        if !candidateInfo
            return false
        candidatePath := this.NormalizePath(candidateInfo.Path)
        if !this.IsCandidatePathValid(path, candidatePath)
            return false
        signature := this.CandidateSignature(path, candidatePath,
            candidateInfo.Identity)
        if this.IgnoredCandidates.Has(signature)
            && this.IgnoredCandidates[signature] > nowTicks
            return false
        if this.IgnoredCandidates.Has(signature)
            this.IgnoredCandidates.Delete(signature)
        return this.PublishCandidate(path, candidatePath, stateObj,
            candidateInfo.Evidence, candidateInfo.Identity, signature)
    }

    ResolveCandidate(record) {
        canonicalOldPath := this.CanonicalPath(record.Path)
        nowTicks := this.Now()
        if this.RenameHints.Has(canonicalOldPath) {
            hint := this.RenameHints[canonicalOldPath]
            if nowTicks - hint.ObservedTicks
                <= TargetRelocationService.RenameEventLifetimeMs {
                hintedIdentity := this.GetIdentity(hint.NewPath)
                if this.IdentityMatches(record.Identity, hintedIdentity) {
                    return {Path: hint.NewPath, Evidence: "FileIdentity",
                        Identity: hintedIdentity}
                }
                if !record.Identity.NativeIdentityAvailable
                    && hintedIdentity.Available {
                    return {Path: hint.NewPath, Evidence: "RenameEvent",
                        Identity: hintedIdentity}
                }
            }
            this.RenameHints.Delete(canonicalOldPath)
        }
        if !record.Identity.Available
            return ""
        currentPath := this.ResolveIdentityPath(record.Path, record.Identity)
        if currentPath == "" || this.PathsEquivalent(currentPath, record.Path)
            return ""
        currentIdentity := this.GetIdentity(currentPath)
        if !this.IdentityMatches(record.Identity, currentIdentity)
            return ""
        return {Path: currentPath, Evidence: "FileIdentity",
            Identity: currentIdentity}
    }

    PublishCandidate(oldPath, newPath, stateObj, evidence, identity,
        signature) {
        if !this.IsCurrent(oldPath, stateObj)
            return false
        stateObj.CancelScheduledTasks()
        stateObj.RelocationPending := true
        generation := stateObj.Generation
        token := this.NextToken
        this.NextToken++
        candidate := {
            Token: token,
            OldPath: oldPath,
            NewPath: newPath,
            Evidence: evidence,
            Identity: identity,
            Signature: signature,
            State: stateObj,
            Generation: generation,
            DetectedTicks: this.Now(),
            LastDeliveryTicks: 0,
            DeliveryFailures: 0
        }
        this.PendingCandidates[oldPath] := candidate
        this.UpdatePendingState(candidate)
        this.Log(this.Text(
            "检测到守护目标可能已更名，等待用户确认：{1} -> {2}",
            oldPath, newPath))
        this.DeliverCandidate(candidate)
        return true
    }

    ValidateCandidate(candidate) {
        if !IsObject(candidate) || !candidate.HasOwnProp("OldPath")
            || !candidate.HasOwnProp("Token")
            return false
        oldPath := this.NormalizePath(candidate.OldPath)
        if !this.PendingCandidates.Has(oldPath)
            return false
        currentCandidate := this.PendingCandidates[oldPath]
        stateObj := currentCandidate.State
        if currentCandidate.Token != candidate.Token
            || !this.IsCurrent(oldPath, stateObj)
            || stateObj.Generation != currentCandidate.Generation
            || !stateObj.HasOwnProp("RelocationPending")
            || !stateObj.RelocationPending
            || this.TargetExists(oldPath)
            || !this.IsCandidatePathValid(oldPath,
                currentCandidate.NewPath)
            || this.IsMaintenanceBusy(oldPath, stateObj)
            return false
        currentIdentity := this.GetIdentity(currentCandidate.NewPath)
        if (currentCandidate.Evidence == "FileIdentity"
                && !this.IdentityMatches(currentCandidate.Identity,
                    currentIdentity))
            || (currentCandidate.Evidence == "RenameEvent"
                && !this.FallbackIdentityMatches(currentCandidate.Identity,
                    currentIdentity))
            return false
        return true
    }

    Complete(candidate) {
        if !IsObject(candidate) || !candidate.HasOwnProp("OldPath")
            return false
        oldPath := this.NormalizePath(candidate.OldPath)
        if !this.PendingCandidates.Has(oldPath)
            return false
        currentCandidate := this.PendingCandidates[oldPath]
        if currentCandidate.Token != candidate.Token
            return false
        this.PendingCandidates.Delete(oldPath)
        if this.Targets.Has(oldPath)
            this.RemoveTarget(oldPath, false)
        return true
    }

    Ignore(candidate) {
        if !IsObject(candidate) || !candidate.HasOwnProp("OldPath")
            return false
        oldPath := this.NormalizePath(candidate.OldPath)
        if !this.PendingCandidates.Has(oldPath)
            return false
        currentCandidate := this.PendingCandidates[oldPath]
        if currentCandidate.Token != candidate.Token
            return false
        this.IgnoredCandidates[currentCandidate.Signature] := this.Now()
            + TargetRelocationService.IgnoreCooldownMs
        this.PendingCandidates.Delete(oldPath)
        this.ReleaseState(currentCandidate)
        return true
    }

    Invalidate(candidate) {
        if !IsObject(candidate) || !candidate.HasOwnProp("OldPath")
            return false
        oldPath := this.NormalizePath(candidate.OldPath)
        if !this.PendingCandidates.Has(oldPath)
            return false
        currentCandidate := this.PendingCandidates[oldPath]
        if currentCandidate.Token != candidate.Token
            return false
        this.PendingCandidates.Delete(oldPath)
        this.ReleaseState(currentCandidate)
        this.NotifyInvalidated(currentCandidate)
        return true
    }

    RedeliverPending(*) {
        if this.Stopped
            return 0
        delivered := 0
        for _, candidate in this.PendingCandidates {
            if this.ValidateCandidate(candidate)
                && this.DeliverCandidate(candidate) {
                delivered++
            }
        }
        return delivered
    }

    RetryPendingDeliveries() {
        nowTicks := this.Now()
        delivered := 0
        for _, candidate in this.PendingCandidates {
            if !this.ValidateCandidate(candidate)
                continue
            if candidate.LastDeliveryTicks
                && nowTicks - candidate.LastDeliveryTicks
                    < TargetRelocationService.DeliveryRetryIntervalMs
                continue
            if this.DeliverCandidate(candidate)
                delivered++
        }
        return delivered
    }

    PollTick(*) {
        if this.Stopped || !this.Running
            return
        if !this.Runtime.guardWorkGate.TryEnter()
            return
        try {
            this.SyncTargets()
            this.PollWatchers()
            invalidCandidates := []
            for _, candidate in this.PendingCandidates {
                if !this.ValidateCandidate(candidate)
                    invalidCandidates.Push(candidate)
            }
            for candidate in invalidCandidates
                this.Invalidate(candidate)
            this.RetryPendingDeliveries()
            this.PurgeExpiredState()
        } catch as pollError {
            this.Log(this.Text("守护目标更名识别异常：{1}",
                this.DiagnosticText(pollError.Message)))
        } finally this.Runtime.guardWorkGate.Leave()
    }

    SubscribeDirectory(record) {
        SplitPath(record.Path, , &rootPath)
        if rootPath == "" || !this.DirectoryExists(rootPath)
            return false
        rootKey := this.CanonicalPath(rootPath)
        if rootKey == ""
            return false
        if !this.Watchers.Has(rootKey) {
            try watcher := this.Callbacks.WatcherFactory.Call(rootPath)
            catch as watcherError {
                this.Log(this.Text("守护目标目录监听异常（{1}）：{2}",
                    rootPath, this.DiagnosticText(watcherError.Message)))
                return false
            }
            if !IsObject(watcher)
                return false
            subscribers := Map()
            subscribers.CaseSense := "Off"
            this.Watchers[rootKey] := {
                Root: rootPath,
                Watcher: watcher,
                Subscribers: subscribers,
                PendingOldNames: []
            }
        }
        entry := this.Watchers[rootKey]
        entry.Subscribers[record.Path] := record.State
        record.WatchRoot := rootKey
        return true
    }

    UnsubscribeDirectory(record) {
        if record.WatchRoot == "" || !this.Watchers.Has(record.WatchRoot)
            return false
        entry := this.Watchers[record.WatchRoot]
        if entry.Subscribers.Has(record.Path)
            entry.Subscribers.Delete(record.Path)
        if !entry.Subscribers.Count {
            try entry.Watcher.Close()
            this.Watchers.Delete(record.WatchRoot)
        }
        record.WatchRoot := ""
        return true
    }

    PollWatchers() {
        for _, entry in this.Watchers {
            try {
                if !entry.Watcher.Active
                    entry.Watcher.Open()
                if !entry.Watcher.Active
                    continue
                changes := entry.Watcher.Poll()
                this.ProcessRenameEvents(entry, changes)
            } catch as watcherError {
                try entry.Watcher.Close()
                this.Log(this.Text("守护目标目录监听异常（{1}）：{2}",
                    entry.Root, this.DiagnosticText(watcherError.Message)))
            }
        }
    }

    ProcessRenameEvents(entry, changes) {
        nowTicks := this.Now()
        retainedOldNames := []
        for pendingOld in entry.PendingOldNames {
            if nowTicks - pendingOld.ObservedTicks
                <= TargetRelocationService.RenamePairLifetimeMs
                retainedOldNames.Push(pendingOld)
        }
        entry.PendingOldNames := retainedOldNames
        for change in changes {
            if !IsObject(change) || !change.HasOwnProp("Action")
                || !change.HasOwnProp("RelativePath")
                continue
            if change.Action
                == TargetRelocationService.FILE_ACTION_RENAMED_OLD_NAME {
                entry.PendingOldNames.Push({
                    RelativePath: change.RelativePath,
                    ObservedTicks: nowTicks
                })
                continue
            }
            if change.Action
                != TargetRelocationService.FILE_ACTION_RENAMED_NEW_NAME
                || !entry.PendingOldNames.Length
                continue
            oldName := entry.PendingOldNames.RemoveAt(1)
            this.RecordRenamePair(entry, oldName.RelativePath,
                change.RelativePath, nowTicks)
        }
    }

    RecordRenamePair(entry, oldRelativePath, newRelativePath, observedTicks) {
        oldPath := this.CombinePath(entry.Root, oldRelativePath)
        newPath := this.CombinePath(entry.Root, newRelativePath)
        canonicalOld := this.CanonicalPath(oldPath)
        if canonicalOld != "" {
            this.RenameHints[canonicalOld] := {
                NewPath: newPath,
                ObservedTicks: observedTicks
            }
        }
        ; 递归监听器也可能收到子目录改名。若守护目标位于旧目录之下，按相同
        ; 相对后缀推导候选；最终仍需存在性、扩展名与身份冲突复核。
        oldPrefix := canonicalOld "\"
        for targetPath in entry.Subscribers {
            canonicalTarget := this.CanonicalPath(targetPath)
            if canonicalOld == "" || InStr(canonicalTarget, oldPrefix) != 1
                continue
            suffix := SubStr(targetPath, StrLen(oldPath) + 1)
            this.RenameHints[canonicalTarget] := {
                NewPath: newPath suffix,
                ObservedTicks: observedTicks
            }
        }
    }

    IsCandidatePathValid(oldPath, newPath) {
        if newPath == "" || this.PathsEquivalent(oldPath, newPath)
            || !this.TargetExists(newPath)
            || !this.ExtensionsCompatible(oldPath, newPath)
            || this.Runtime.appStates.Has(newPath)
            return false
        return this.Callbacks.FindConflict.Call(newPath, oldPath) == ""
    }

    IsMaintenanceBusy(path, stateObj) {
        return this.Callbacks.IsMaintenanceBlocking.Call(stateObj)
            || (this.Callbacks.IsMaintenanceProtectionEnabled.Call(path,
                    stateObj)
                && this.Callbacks.HasRecentMaintenanceSignal.Call(path,
                    stateObj))
    }

    IdentityMatches(first, second) {
        return IsObject(first) && IsObject(second)
            && first.HasOwnProp("NativeIdentityAvailable")
            && second.HasOwnProp("NativeIdentityAvailable")
            && first.NativeIdentityAvailable
            && second.NativeIdentityAvailable
            && first.VolumeSerial == second.VolumeSerial
            && first.FileIndexHigh == second.FileIndexHigh
            && first.FileIndexLow == second.FileIndexLow
    }

    FallbackIdentityMatches(first, second) {
        return IsObject(first) && IsObject(second)
            && first.HasOwnProp("Available") && first.Available
            && second.HasOwnProp("Available") && second.Available
            && first.HasOwnProp("Fingerprint")
            && second.HasOwnProp("Fingerprint")
            && first.Fingerprint != ""
            && first.Fingerprint == second.Fingerprint
    }

    CandidateSignature(oldPath, newPath, identity) {
        identityText := IsObject(identity)
            && identity.HasOwnProp("NativeIdentityAvailable")
            && identity.NativeIdentityAvailable
            ? Format("{:08X}{:08X}{:08X}", identity.VolumeSerial,
                identity.FileIndexHigh, identity.FileIndexLow)
            : this.CanonicalPath(newPath)
        return this.CanonicalPath(oldPath) "|" identityText
    }

    ClearIgnoredForPath(path) {
        prefix := this.CanonicalPath(path) "|"
        staleKeys := []
        for key in this.IgnoredCandidates {
            if InStr(key, prefix) == 1
                staleKeys.Push(key)
        }
        for key in staleKeys
            this.IgnoredCandidates.Delete(key)
    }

    PurgeExpiredState() {
        nowTicks := this.Now()
        expiredHints := []
        for key, hint in this.RenameHints {
            if nowTicks - hint.ObservedTicks
                > TargetRelocationService.RenameEventLifetimeMs
                expiredHints.Push(key)
        }
        for key in expiredHints
            this.RenameHints.Delete(key)
        expiredIgnores := []
        for key, expiresTicks in this.IgnoredCandidates {
            if expiresTicks <= nowTicks
                expiredIgnores.Push(key)
        }
        for key in expiredIgnores
            this.IgnoredCandidates.Delete(key)
    }

    ReleaseState(candidate) {
        stateObj := candidate.State
        if !this.IsCurrent(candidate.OldPath, stateObj)
            return false
        stateObj.RelocationPending := false
        this.Callbacks.ResetState.Call(candidate.OldPath, stateObj)
        return true
    }

    UpdatePendingState(candidate) {
        this.Callbacks.UpdateState.Call(candidate.OldPath,
            this.Text("等待确认目标新位置"), candidate.State,
            candidate.Generation, true,
            GuardStatusKind.RelocationPending)
    }

    DeliverCandidate(candidate) {
        candidate.LastDeliveryTicks := this.Now()
        try {
            deliveryResult := this.Callbacks.OnCandidate.Call(candidate)
            if Type(deliveryResult) == "Integer" && !deliveryResult {
                candidate.DeliveryFailures++
                this.Log(this.Text("守护目标更名识别异常：{1}",
                    this.Text("确认窗口暂时无法显示，将稍后重试")))
                return false
            }
            candidate.DeliveryFailures := 0
            return true
        } catch as deliveryError {
            candidate.DeliveryFailures++
            this.Log(this.Text("守护目标更名识别异常：{1}",
                this.DiagnosticText(deliveryError.Message)))
            return false
        }
    }

    NotifyInvalidated(candidate) {
        try this.Callbacks.OnCandidateInvalidated.Call(candidate)
    }

    IsCurrent(path, stateObj) {
        return IsObject(stateObj) && this.Runtime.appStates.Has(path)
            && this.Runtime.appStates[path] == stateObj
    }

    GetIdentity(path) {
        try return this.Callbacks.GetIdentity.Call(path)
        catch
            return {Available: false, NativeIdentityAvailable: false}
    }

    ResolveIdentityPath(path, identity) {
        try return this.Callbacks.ResolveIdentityPath.Call(path, identity)
        catch
            return ""
    }

    TargetExists(path) {
        try return !!this.Callbacks.TargetExists.Call(path)
        catch
            return false
    }

    DirectoryExists(path) {
        try return !!this.Callbacks.DirectoryExists.Call(path)
        catch
            return false
    }

    NormalizePath(path) {
        return this.Callbacks.NormalizePath.Call(path)
    }

    CanonicalPath(path) {
        return this.Callbacks.CanonicalPath.Call(path)
    }

    PathsEquivalent(firstPath, secondPath) {
        return this.Callbacks.PathsEquivalent.Call(firstPath, secondPath)
    }

    CombinePath(rootPath, relativePath) {
        return RTrim(rootPath, "\") "\" LTrim(relativePath, "\")
    }

    Now() {
        return this.Callbacks.Now.Call()
    }

    Log(message) {
        try this.Callbacks.Log.Call(message)
    }

    Text(template, values*) {
        if this.Callbacks.HasOwnProp("Localize")
            && IsObject(this.Callbacks.Localize)
            return this.Callbacks.Localize.Call(template, values*)
        return values.Length ? Format(template, values*) : template
    }

    DiagnosticText(text) {
        if this.Callbacks.HasOwnProp("LocalizeDiagnostic")
            && IsObject(this.Callbacks.LocalizeDiagnostic)
            return this.Callbacks.LocalizeDiagnostic.Call(text)
        return text
    }
}
