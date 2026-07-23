class MaintenanceCoordinator {
    __New(runtime, callbacks) {
        this.Runtime := runtime
        this.Callbacks := callbacks
        this.ProcessBaselineReady := false
        this.SnapshotSupportsCommandLine := false
        this.Initialized := false
        this.Stopped := false
        this.PendingCommands := []
        this.JournalDirty := false
        this.JournalRetryDueTicks := 0
        this.JournalRetryDelayMs := 5000
        this.Watchers := Map()
        this.Watchers.CaseSense := "Off"
        this.ProcessTimer := ObjBindMethod(this, "ProcessTick")
        this.EventTimer := ObjBindMethod(this, "EventTick")
    }

    Initialize() {
        if this.Stopped
            return false
        if this.Initialized
            return true
        this.RestoreSessions()
        for path, stateObj in this.Runtime.appStates
            this.EnsureWatcher(path, stateObj)
        snapshot := this.QueryNativeSnapshot(&snapshotReady)
        if snapshotReady {
            initialSnapshotTicks := this.Now()
            initialSnapshotIndex := this.CreateSnapshotIndex(snapshot,
                initialSnapshotTicks, this.SnapshotSupportsCommandLine)
            for path, stateObj in this.Runtime.appStates {
                if !stateObj.Enabled || !InStr(path, "\")
                    continue
                observation := this.Callbacks.ObserveTarget.Call(path,
                    initialSnapshotIndex)
                if observation.IsRunning()
                    this.Callbacks.SetProcessIdentity.Call(stateObj,
                        observation.PID)
            }
            this.RefreshActors(snapshot, true,
                this.SnapshotSupportsCommandLine, initialSnapshotIndex)
        } else {
            this.Log("升级保护初始化时无法建立进程基线，将在下一轮重试。")
        }
        this.Runtime.processSnapshots.Start()
        this.Initialized := true
        this.DrainPendingCommands()
        return true
    }

    StartTimers() {
        if !this.Initialized || this.Stopped
            return false
        eventTimerStarted := false
        try {
            SetTimer(this.EventTimer, this.Runtime.maintenancePollInterval)
            eventTimerStarted := true
            SetTimer(this.ProcessTimer,
                this.Runtime.maintenanceProcessInterval)
            return true
        } catch {
            if eventTimerStarted
                try SetTimer(this.EventTimer, 0)
            try SetTimer(this.ProcessTimer, 0)
            return false
        }
    }

    Shutdown(*) {
        if this.Stopped
            return
        this.Stopped := true
        try SetTimer(this.EventTimer, 0)
        try SetTimer(this.ProcessTimer, 0)
        for _, stateObj in this.Runtime.appStates
            try this.CloseWatcher(stateObj)
        for _, entry in this.Watchers
            try entry.watcher.Close()
        this.Watchers.Clear()
        this.PendingCommands := []
        try this.Runtime.processSnapshots.Stop()
        if this.Initialized
            try this.SaveJournal()
    }

    QueueCommand(command) {
        if this.Stopped
            return false
        if !this.Initialized {
            this.PendingCommands.Push(command)
            return true
        }
        if !this.Runtime.guardWorkGate.TryEnter() {
            this.PendingCommands.Push(command)
            return true
        }
        try return this.ApplyCommand(command)
        finally this.Runtime.guardWorkGate.Leave()
    }

    DrainPendingCommands() {
        if this.Stopped
            return 0
        processed := 0
        while this.PendingCommands.Length {
            command := this.PendingCommands.RemoveAt(1)
            try {
                this.ApplyCommand(command)
                processed++
            } catch as commandError {
                try this.Log("显式升级维护命令执行异常: "
                    commandError.Message)
            }
        }
        return processed
    }

    ApplyCommand(command) {
        separator := InStr(command, "|")
        if !separator
            return false
        action := SubStr(command, 1, separator - 1)
        path := this.Callbacks.NormalizeTargetPath.Call(
            SubStr(command, separator + 1))
        if !this.Runtime.appStates.Has(path) {
            this.Log("显式升级维护命令未找到监控目标: " path)
            return false
        }
        if (action == "BEGIN")
            return this.BeginExplicit(path)
        if (action == "END")
            return this.EndExplicit(path)
        return false
    }

    BeginExplicit(path) {
        if !this.Runtime.appStates.Has(path)
            return false
        stateObj := this.Runtime.appStates[path]
        if !stateObj.Enabled || !this.IsProtectionEnabled(path, stateObj) {
            this.Log("显式升级维护命令被忽略，目标未启用升级保护: " path)
            return false
        }
        if (stateObj.MaintenanceMode == MaintenancePhase.TimedOut)
            this.ResetSession(path, stateObj, false)
        stateObj.ExplicitMaintenance := true
        this.Enter(path, stateObj, "收到显式维护开始命令")
        this.UpdateState(path, stateObj, "🔄 显式升级维护中")
        this.SaveJournal()
        return true
    }

    EndExplicit(path) {
        if !this.Runtime.appStates.Has(path)
            return false
        stateObj := this.Runtime.appStates[path]
        if !stateObj.ExplicitMaintenance
            return false
        if (stateObj.MaintenanceMode == MaintenancePhase.TimedOut)
            this.ResetSession(path, stateObj, false)
        stateObj.ExplicitMaintenance := false
        stateObj.MaintenanceMode := MaintenancePhase.Stabilizing
        stateObj.Pending := true
        stateObj.MaintenanceLastActivityTicks := this.Now()
        if !stateObj.MaintenanceStartedTicks {
            stateObj.MaintenanceStartedTicks := this.Now()
            stateObj.MaintenanceStartedAt := A_NowUTC
        }
        this.UpdateState(path, stateObj, "⏳ 确认升级文件稳定")
        this.SaveJournal()
        this.Log("收到显式维护结束命令，开始执行安全恢复检查: " path)
        return true
    }

    RestoreSessions() {
        journalPath := this.Runtime.maintenanceJournalPath
        if !FileExist(journalPath)
            return
        try sessionText := IniRead(journalPath, "Sessions")
        catch
            return
        Loop Parse, sessionText, "`n", "`r" {
            separator := InStr(A_LoopField, "=")
            if !separator
                continue
            try session := this.Callbacks.DeserializeSession.Call(
                SubStr(A_LoopField, separator + 1))
            catch
                continue
            path := this.Callbacks.NormalizeTargetPath.Call(session.Path)
            if (path == "" || !this.Runtime.appStates.Has(path))
                continue
            stateObj := this.Runtime.appStates[path]
            if !stateObj.Enabled || !this.IsProtectionEnabled(path, stateObj)
                continue
            stateObj.MaintenanceMode := MaintenancePhase.Recovering
            stateObj.Pending := true
            stateObj.TargetStartTicks := 0
            stateObj.MaintenanceStartedAt := session.StartedAt != ""
                ? session.StartedAt : A_NowUTC
            elapsedSeconds := 0
            try elapsedSeconds := Max(0, DateDiff(A_NowUTC,
                stateObj.MaintenanceStartedAt, "Seconds"))
            stateObj.MaintenanceStartedTicks := this.Now()
                - elapsedSeconds * 1000
            stateObj.MaintenanceLastActivityTicks := this.Now()
            stateObj.MaintenanceBaselineFingerprint := session.BaselineFingerprint
            stateObj.MaintenanceFileChanged := session.FileChanged
            stateObj.ExplicitMaintenance := session.Explicit
            if (elapsedSeconds >= stateObj.MaintenanceConfig.MaxWaitSeconds) {
                stateObj.MaintenanceMode := MaintenancePhase.TimedOut
                this.UpdateState(path, stateObj, "⚠️ 升级等待超时")
            } else {
                this.UpdateState(path, stateObj, "🔄 恢复升级保护状态")
            }
            this.Log("已恢复未完成的升级保护会话: " path)
        }
        this.SaveJournal()
    }

    ProcessTick() {
        if this.Stopped || !this.Initialized || !this.ProcessBaselineReady
            return
        if !this.Runtime.guardWorkGate.TryEnter()
            return
        loopStartedTicks := 0
        try {
            loopStartedTicks := this.Now()
            nowTicks := this.Now()
            snapshots := this.Runtime.processSnapshots
            if snapshots.HasFreshSnapshot(snapshots.ReuseIntervalMs, nowTicks)
                return
            if snapshots.HasFreshNativeSnapshot(snapshots.ReuseIntervalMs,
                nowTicks)
                return
            shouldRefreshActors := false
            for path, stateObj in this.Runtime.appStates {
                maintenanceActive := this.IsBlocking(stateObj)
                    && stateObj.MaintenanceMode != MaintenancePhase.TimedOut
                if (stateObj.Enabled && this.IsProtectionEnabled(path, stateObj)
                    && (maintenanceActive || this.HasRecentSignal(stateObj))) {
                    shouldRefreshActors := true
                    break
                }
            }
            if !shouldRefreshActors || !snapshots.CanRetry(nowTicks)
                return
            if snapshots.Pump()
                return
            snapshot := this.QueryNativeSnapshot(&snapshotReady)
            if snapshotReady
                this.RefreshActors(snapshot, false,
                    this.SnapshotSupportsCommandLine)
        } catch as processError {
            try this.Log("升级进程扫描异常: " processError.Message)
        } finally {
            this.Runtime.guardWorkGate.Leave()
            if loopStartedTicks
                this.Callbacks.LogSlow.Call("升级进程扫描", loopStartedTicks)
        }
    }

    EventTick() {
        if this.Stopped || !this.Initialized
            return
        if !this.Runtime.guardWorkGate.TryEnter()
            return
        loopStartedTicks := 0
        try {
            loopStartedTicks := this.Now()
            nowTicks := this.Now()
            this.DrainPendingCommands()
            staleRoots := []
            for rootKey, entry in this.Watchers {
                if !entry.subscribers.Count {
                    staleRoots.Push(rootKey)
                    continue
                }
                try {
                    if !entry.watcher.Active
                        entry.watcher.Open()
                    if !entry.watcher.Active
                        continue
                    changes := entry.watcher.Poll()
                } catch as watcherError {
                    try entry.watcher.Close()
                    this.Log("升级文件监听异常（" entry.rootPath "）："
                        watcherError.Message)
                    continue
                }
                for change in changes {
                    for path, stateObj in entry.subscribers {
                        if (this.Runtime.appStates.Has(path)
                            && this.Runtime.appStates[path] == stateObj
                            && stateObj.Enabled
                            && this.IsProtectionEnabled(path, stateObj)
                            && this.IsRelevantFootprintChange(path, stateObj,
                                change.RelativePath, entry)) {
                            this.RecordFootprintActivity(path, stateObj,
                                change.RelativePath)
                        }
                    }
                }
            }
            for rootKey in staleRoots {
                if this.Watchers.Has(rootKey) {
                    try this.Watchers[rootKey].watcher.Close()
                    this.Watchers.Delete(rootKey)
                }
            }
            normalFingerprintChecks := 0
            normalFingerprintBudget := Max(1,
                Ceil(this.Runtime.appStates.Count
                    * this.Runtime.maintenancePollInterval
                    / this.Runtime.maintenanceFingerprintRetryInterval))
            for path, stateObj in this.Runtime.appStates {
                if !stateObj.Enabled || !this.IsProtectionEnabled(path,
                    stateObj) {
                    this.CloseWatcher(stateObj)
                    continue
                }
                this.EnsureWatcher(path, stateObj)
                watcherActive := stateObj.MaintenanceWatcherRoot != ""
                    && this.Watchers.Has(stateObj.MaintenanceWatcherRoot)
                    && this.Watchers[stateObj.MaintenanceWatcherRoot].watcher.Active
                fingerprintInterval := stateObj.MaintenanceMode
                    == MaintenancePhase.Normal
                    ? (watcherActive
                        ? this.Runtime.maintenanceFingerprintInterval
                        : this.Runtime.maintenanceFingerprintRetryInterval)
                    : 1000
                shouldCheckFingerprint := stateObj.MaintenanceMode
                    != MaintenancePhase.TimedOut
                    && (!stateObj.MaintenanceFingerprintCheckedTicks
                        || nowTicks - stateObj.MaintenanceFingerprintCheckedTicks
                            >= fingerprintInterval)
                if (shouldCheckFingerprint
                    && stateObj.MaintenanceMode == MaintenancePhase.Normal) {
                    if (normalFingerprintChecks >= normalFingerprintBudget)
                        shouldCheckFingerprint := false
                    else
                        normalFingerprintChecks++
                }
                fingerprint := stateObj.SafetyFingerprint
                if shouldCheckFingerprint {
                    fingerprint := this.GetFingerprint(path)
                    stateObj.MaintenanceFingerprintCheckedTicks := nowTicks
                    if (fingerprint != stateObj.SafetyFingerprint) {
                        priorFingerprint := stateObj.SafetyFingerprint
                        stateObj.SafetyFingerprint := fingerprint
                        stateObj.SafetyStableSince := nowTicks
                        stateObj.MaintenanceReadyCheckedTicks := 0
                        if (priorFingerprint != "")
                            this.RecordFootprintActivity(path, stateObj)
                    } else if !stateObj.SafetyStableSince {
                        stateObj.SafetyStableSince := nowTicks
                    }
                    if (stateObj.MaintenanceMode == MaintenancePhase.Normal
                        && nowTicks - stateObj.SafetyStableSince
                            >= stateObj.MaintenanceConfig.StableSeconds * 1000) {
                        stateObj.MaintenanceBaselineFingerprint := fingerprint
                        detectionMs := stateObj.MaintenanceConfig.DetectionSeconds
                            * 1000
                        if ((!stateObj.LastFileActivityTicks
                                || nowTicks - stateObj.LastFileActivityTicks
                                    > detectionMs)
                            && (!stateObj.LastActorSeenTicks
                                || nowTicks - stateObj.LastActorSeenTicks
                                    > detectionMs)) {
                            stateObj.MaintenanceFileChanged := false
                            stateObj.MaintenanceLearningCandidates := Map()
                        }
                    }
                }
                this.Advance(path, stateObj)
            }
            if (this.JournalDirty && nowTicks >= this.JournalRetryDueTicks)
                this.SaveJournal()
        } catch as eventError {
            try this.Log("升级文件监听异常: " eventError.Message)
        } finally {
            this.Runtime.guardWorkGate.Leave()
            if loopStartedTicks
                this.Callbacks.LogSlow.Call("升级文件监听", loopStartedTicks)
        }
    }

    EnsureWatcher(path, stateObj) {
        path := this.Callbacks.NormalizeTargetPath.Call(path)
        if this.Stopped || !(stateObj is TargetSupervisor)
            || !this.Runtime.appStates.Has(path)
            || this.Runtime.appStates[path] != stateObj {
            this.CloseWatcher(stateObj)
            return false
        }
        if !stateObj.Enabled || !this.IsProtectionEnabled(path, stateObj) {
            this.CloseWatcher(stateObj)
            return false
        }
        rootPath := this.Callbacks.NormalizeRoot.Call(
            stateObj.MaintenanceConfig.InstallRoot, path)
        if !DirExist(rootPath) {
            this.CloseWatcher(stateObj)
            return false
        }
        rootKey := this.CanonicalPath(rootPath)
        if rootKey == "" {
            this.CloseWatcher(stateObj)
            return false
        }
        currentRoot := stateObj.MaintenanceWatcherRoot
        if (currentRoot != "" && currentRoot != rootKey)
            this.CloseWatcher(stateObj)
        if !this.Watchers.Has(rootKey) {
            try watcher := this.Callbacks.WatcherFactory.Call(rootPath)
            catch
                return false
            subscribers := Map()
            subscribers.CaseSense := "Off"
            this.Watchers[rootKey] := {
                watcher: watcher, rootPath: rootPath, subscribers: subscribers
            }
        }
        entry := this.Watchers[rootKey]
        entry.subscribers[path] := stateObj
        stateObj.MaintenanceWatcherRoot := rootKey
        stateObj.MaintenanceWatcherPath := path
        if entry.watcher.Active
            return true
        return entry.watcher.Open()
    }

    CloseWatcher(stateObj) {
        rootKey := stateObj.MaintenanceWatcherRoot
        path := stateObj.MaintenanceWatcherPath
        stateObj.MaintenanceWatcherRoot := ""
        stateObj.MaintenanceWatcherPath := ""
        if (rootKey != "" && this.Watchers.Has(rootKey)) {
            entry := this.Watchers[rootKey]
            if (path != "" && entry.subscribers.Has(path)
                && entry.subscribers[path] == stateObj) {
                entry.subscribers.Delete(path)
            }
            if !entry.subscribers.Count {
                try entry.watcher.Close()
                this.Watchers.Delete(rootKey)
            }
        }
    }

    IsRelevantFootprintChange(path, stateObj, relativePath,
        watcherEntry := "") {
        if (relativePath == "*")
            return true
        relativePath := StrReplace(relativePath, "/", "\")
        SplitPath(relativePath, &changedName, , &extension)
        subjectPath := this.Callbacks.GetMaintenanceSubjectPath.Call(path)
        rootPath := watcherEntry && watcherEntry.HasOwnProp("rootPath")
            ? watcherEntry.rootPath : stateObj.MaintenanceConfig.InstallRoot
        canonicalSubject := this.CanonicalPath(subjectPath)
        canonicalRoot := RTrim(this.CanonicalPath(rootPath), "\")
        subjectRelative := canonicalSubject == canonicalRoot ? ""
            : (InStr(canonicalSubject, canonicalRoot "\") == 1
                ? SubStr(canonicalSubject, StrLen(canonicalRoot) + 2) : "")
        if (subjectRelative != ""
            && StrLower(relativePath) == StrLower(subjectRelative))
            return true
        SplitPath(subjectPath, &targetName)
        if (!InStr(subjectRelative, "\")
            && StrLower(changedName) == StrLower(targetName))
            return true
        if (watcherEntry && watcherEntry.subscribers.Count > 1)
            return false
        extension := StrLower(extension)
        return InStr("|exe|com|dll|sys|ocx|cpl|mui|pak|bin|dat|node|asar|jar|",
            "|" extension "|") != 0
    }

    QueryNativeSnapshot(&snapshotReady) {
        this.SnapshotSupportsCommandLine := false
        snapshotResult := this.Runtime.processInspector.CaptureNativeSnapshot()
        snapshotReady := snapshotResult.Ready
        snapshot := snapshotResult.Processes
        if !snapshotReady {
            this.SnapshotSupportsCommandLine := true
            snapshot := this.Callbacks.QueryProcessSnapshot.Call(&snapshotReady)
            if !snapshotReady
                this.Runtime.processSnapshots.DelayRetry(3000)
            return snapshot
        }
        this.EnrichNativeProcessPaths(snapshot)
        return snapshot
    }

    EnrichNativeProcessPaths(snapshot) {
        learnedPathNames := Map()
        learnedPathNames.CaseSense := "Off"
        targetPids := Map()
        for path, stateObj in this.Runtime.appStates {
            if !stateObj.Enabled || !this.IsProtectionEnabled(path, stateObj)
                continue
            if !this.IsBlocking(stateObj) && !this.HasRecentSignal(stateObj)
                continue
            targetPid := stateObj.PID ? stateObj.PID : stateObj.LastKnownPID
            if targetPid
                targetPids[targetPid] := true
            for signature in stateObj.MaintenanceConfig.LearnedActors {
                normalized := this.Runtime.maintenanceActorMatcher
                    .NormalizeLearnedSignature(signature,
                        stateObj.MaintenanceConfig.InstallRoot)
                if normalized != "" {
                    SplitPath(this.Runtime.maintenanceActorMatcher
                        .SignatureExecutablePath(normalized), &actorName)
                    if (actorName != "")
                        learnedPathNames[actorName] := true
                }
            }
        }
        for processInfo in snapshot {
            processInfo.maintenanceCandidate := targetPids.Has(
                processInfo.parent)
            if (this.Runtime.maintenanceActorMatcher.IsInstallerLike(processInfo)
                || learnedPathNames.Has(processInfo.name)) {
                processInfo.exe := this.Runtime.processInspector.GetImagePath(
                    processInfo.pid)
            }
        }
    }

    BuildActorCandidates(snapshot, processMap) {
        learnedPaths := Map()
        learnedPaths.CaseSense := "Off"
        targetPids := Map()
        matcher := this.Runtime.maintenanceActorMatcher
        for path, stateObj in this.Runtime.appStates {
            if !stateObj.Enabled || !this.IsProtectionEnabled(path, stateObj)
                continue
            targetPid := stateObj.PID ? stateObj.PID : stateObj.LastKnownPID
            if targetPid
                targetPids[targetPid] := true
            for signature in stateObj.MaintenanceConfig.LearnedActors {
                normalized := matcher.NormalizeLearnedSignature(signature,
                    stateObj.MaintenanceConfig.InstallRoot)
                if normalized != ""
                    learnedPaths[matcher.SignatureExecutablePath(normalized)] := true
            }
        }
        candidates := []
        for processInfo in snapshot {
            processInfo.installerLike := matcher.IsInstallerLike(processInfo)
            if (processInfo.installerLike
                || (processInfo.HasOwnProp("maintenanceCandidate")
                    && processInfo.maintenanceCandidate)) {
                candidates.Push(processInfo)
                continue
            }
            if (processInfo.exe != "" && learnedPaths.Count
                && learnedPaths.Has(matcher.Canonical(processInfo.exe))) {
                candidates.Push(processInfo)
                continue
            }
            parentPid := processInfo.parent
            visited := Map()
            Loop 16 {
                if !parentPid || visited.Has(parentPid)
                    break
                if targetPids.Has(parentPid) {
                    candidates.Push(processInfo)
                    break
                }
                visited[parentPid] := true
                if !processMap.Has(parentPid)
                    break
                parentPid := processMap[parentPid].parent
            }
        }
        return candidates
    }

    RefreshActors(snapshot, isBaseline := false,
        supportsCommandLine := true, snapshotIndex := "",
        updateSnapshotStore := true) {
        processMap := Map()
        for processInfo in snapshot
            processMap[processInfo.pid] := processInfo
        actorCandidates := this.BuildActorCandidates(snapshot, processMap)
        snapshotTicks := snapshotIndex is ProcessSnapshotIndex
            ? snapshotIndex.CapturedAtTicks : this.Now()
        if updateSnapshotStore && supportsCommandLine {
            if !(snapshotIndex is ProcessSnapshotIndex) {
                snapshotIndex := this.CreateSnapshotIndex(snapshot,
                    snapshotTicks, true)
            }
            this.Runtime.processSnapshots.StoreSnapshot(snapshot,
                snapshotTicks, true, snapshotIndex)
        } else if updateSnapshotStore {
            this.Runtime.processSnapshots.StoreNativeSnapshot(snapshotTicks)
        }
        matcher := this.Runtime.maintenanceActorMatcher
        for path, stateObj in this.Runtime.appStates {
            if !stateObj.Enabled || !this.IsProtectionEnabled(path, stateObj)
                continue
            knownActorIdentities := stateObj.KnownActorIdentities
            transientActorIdentities := stateObj.TransientActorIdentities
            activeKnown := Map()
            activeTransient := Map()
            for processInfo in actorCandidates {
                targetPid := stateObj.PID ? stateObj.PID : stateObj.LastKnownPID
                targetCreation := stateObj.PID
                    ? stateObj.PIDCreationIdentity
                    : stateObj.LastKnownPIDCreationIdentity
                matchResult := matcher.Match(processInfo,
                    this.Callbacks.GetMaintenanceSubjectPath.Call(path),
                    stateObj.MaintenanceConfig.InstallRoot,
                    stateObj.MaintenanceConfig.LearnedActors, targetPid,
                    targetCreation, processMap, this.IsBlocking(stateObj))
                if !matchResult.Matched
                    continue
                identity := matcher.CreateIdentity(processInfo,
                    stateObj.MaintenanceConfig.InstallRoot, processMap)
                if !(identity is MaintenanceActorIdentity)
                    continue
                actorRecord := {Process: processInfo, Identity: identity,
                    Match: matchResult}
                identityKey := identity.Key
                activeKnown[identityKey] := actorRecord
                wasKnown := knownActorIdentities.Has(identityKey)
                shouldTrack := transientActorIdentities.Has(identityKey)
                    || (!isBaseline && !wasKnown)
                    || (stateObj.MaintenanceMode
                        == MaintenancePhase.Recovering && !wasKnown)
                    || (isBaseline && !wasKnown
                        && this.WasProcessStartedRecently(processInfo,
                            stateObj.MaintenanceConfig.DetectionSeconds))
                if shouldTrack {
                    activeTransient[identityKey] := actorRecord
                    if !wasKnown
                        this.RecordActor(path, stateObj, actorRecord)
                }
            }
            matcher.RetainLiveRecords(knownActorIdentities, activeKnown)
            matcher.RetainLiveRecords(transientActorIdentities,
                activeTransient)
            stateObj.KnownActorIdentities := activeKnown
            stateObj.TransientActorIdentities := activeTransient
            if (activeTransient.Count && this.IsBlocking(stateObj))
                stateObj.MaintenanceLastActivityTicks := this.Now()
        }
        this.ProcessBaselineReady := true
    }

    OnSnapshotPublished(snapshot, snapshotIndex) {
        if this.Stopped || !this.Initialized
            return false
        this.RefreshActors(snapshot, !this.ProcessBaselineReady, true,
            snapshotIndex, false)
        return true
    }

    RecordActor(path, stateObj, actorRecord) {
        identityKey := actorRecord.Identity.Key
        stateObj.KnownActorIdentities[identityKey] := actorRecord
        nowTicks := this.Now()
        stateObj.TransientActorIdentities[identityKey] := actorRecord
        stateObj.LastActorSeenTicks := nowTicks
        if this.IsBlocking(stateObj)
            stateObj.MaintenanceLastActivityTicks := nowTicks
        signature := actorRecord.Match.LearnableSignature
        if (signature != "")
            stateObj.MaintenanceLearningCandidates[signature] := true
        if !this.TargetAppearsRunning(stateObj) && stateObj.Enabled
            this.Enter(path, stateObj, "检测到相关安装进程")
        return true
    }

    WasProcessStartedRecently(processInfo, maximumAgeSeconds) {
        if (processInfo.creation == "")
            return false
        creationTime := SubStr(processInfo.creation, 1, 14)
        if !RegExMatch(creationTime, "^\d{14}$")
            return false
        try return Abs(DateDiff(A_Now, creationTime, "Seconds"))
            <= maximumAgeSeconds
        catch
            return false
    }

    IsProtectionEnabled(path, stateObj) {
        return this.Callbacks.IsSupportedTarget.Call(path)
            && stateObj.MaintenanceConfig.Enabled
    }

    IsBlocking(stateObj) {
        return stateObj.MaintenanceStateMachine.IsBlocking()
    }

    TargetAppearsRunning(stateObj) {
        if !stateObj.PID || !ProcessExist(stateObj.PID)
            return false
        if stateObj.PIDCreationIdentity != "" {
            currentCreation := this.Runtime.processInspector
                .GetCreationIdentity(stateObj.PID)
            return currentCreation == ""
                || currentCreation == stateObj.PIDCreationIdentity
        }
        return true
    }

    HasActiveActors(stateObj) {
        staleIdentities := []
        for identityKey, actorRecord in stateObj.TransientActorIdentities {
            if !actorRecord.HasOwnProp("Identity")
                || !this.Runtime.maintenanceActorMatcher
                    .IsIdentityAlive(actorRecord.Identity) {
                staleIdentities.Push(identityKey)
            }
        }
        for identityKey in staleIdentities
            stateObj.TransientActorIdentities.Delete(identityKey)
        return stateObj.TransientActorIdentities.Count > 0
    }

    HasRecentSignal(stateObj) {
        nowTicks := this.Now()
        windowMs := stateObj.MaintenanceConfig.DetectionSeconds * 1000
        return this.HasActiveActors(stateObj)
            || (stateObj.LastActorSeenTicks
                && nowTicks - stateObj.LastActorSeenTicks <= windowMs)
            || (stateObj.LastFileActivityTicks
                && nowTicks - stateObj.LastFileActivityTicks <= windowMs)
    }

    ResetSession(path, stateObj, saveJournal := true) {
        stateObj.MaintenanceMode := MaintenancePhase.Normal
        stateObj.Pending := false
        stateObj.TargetStartTicks := 0
        stateObj.MaintenanceStartedTicks := 0
        stateObj.MaintenanceStartedAt := ""
        stateObj.MaintenanceLastActivityTicks := 0
        stateObj.MaintenanceRestartDueTicks := 0
        stateObj.ArbitrationSnapshotRequestTicks := 0
        stateObj.ArbitrationSignalBaselineTicks := 0
        stateObj.MaintenanceBaselineFingerprint := this.GetFingerprint(path)
        stateObj.MaintenanceFileChanged := false
        stateObj.ExplicitMaintenance := false
        stateObj.TransientActorIdentities := Map()
        stateObj.LastActorSeenTicks := 0
        stateObj.MaintenanceLearningCandidates := Map()
        if saveJournal
            this.SaveJournal()
    }

    CleanupTarget(path, stateObj, saveJournal := true) {
        this.CloseWatcher(stateObj)
        this.ResetSession(path, stateObj, false)
        if saveJournal
            this.SaveJournal()
    }

    RecordFootprintActivity(path, stateObj, relativePath := "") {
        nowTicks := this.Now()
        stateObj.LastFileActivityTicks := nowTicks
        stateObj.SafetyStableSince := 0
        stateObj.MaintenanceLastActivityTicks := nowTicks
        stateObj.MaintenanceFileChanged := true
        stateObj.MaintenanceReadyCheckedTicks := 0
        if (this.IsBlocking(stateObj)
            && stateObj.MaintenanceMode != MaintenancePhase.TimedOut) {
            if (stateObj.MaintenanceMode != MaintenancePhase.Arbitrating)
                stateObj.MaintenanceMode := MaintenancePhase.Updating
        } else if !this.TargetAppearsRunning(stateObj) && stateObj.Enabled {
            if this.Callbacks.TargetReferenceExists.Call(path, stateObj) {
                this.Enter(path, stateObj, relativePath == ""
                    ? "检测到程序文件变化" : "检测到安装目录变化")
            } else {
                this.BeginArbitration(path, stateObj)
            }
        }
    }

    BeginArbitration(path, stateObj) {
        if !this.IsProtectionEnabled(path, stateObj)
            return false
        if this.IsBlocking(stateObj)
            return true
        targetExists := this.Callbacks.TargetReferenceExists.Call(path,
            stateObj)
        if this.HasActiveActors(stateObj)
            || (targetExists && this.HasRecentSignal(stateObj)) {
            this.Enter(path, stateObj, "目标退出时检测到升级信号")
            return true
        }
        nowTicks := this.Now()
        stateObj.CancelScheduledTasks()
        stateObj.MaintenanceMode := MaintenancePhase.Arbitrating
        stateObj.Pending := true
        stateObj.TargetStartTicks := 0
        stateObj.MaintenanceStartedTicks := nowTicks
        stateObj.MaintenanceStartedAt := A_NowUTC
        stateObj.MaintenanceLastActivityTicks := nowTicks
        stateObj.MaintenanceRestartDueTicks := nowTicks
            + this.Runtime.retryDelayArray[1]
        stateObj.MaintenanceBaselineFingerprint := this.GetFingerprint(path)
        stateObj.MaintenanceFileChanged := false
        stateObj.ArbitrationSignalBaselineTicks := Max(
            stateObj.LastActorSeenTicks, stateObj.LastFileActivityTicks)
        snapshotRequestTicks := this.Runtime.processSnapshots.RequestFresh()
        if (stateObj.MaintenanceMode != MaintenancePhase.Arbitrating)
            return true
        stateObj.ArbitrationSnapshotRequestTicks := snapshotRequestTicks
        this.UpdateState(path, stateObj, "⏳ 判断是否正在升级")
        this.SaveJournal()
        return true
    }

    MarkTargetMissing(path, stateObj, statusText) {
        wasBlocking := this.IsBlocking(stateObj)
        firstMissingObservation := !stateObj.MissingSinceTicks
        if (firstMissingObservation || wasBlocking)
            stateObj.CancelScheduledTasks()
        if wasBlocking
            this.ResetSession(path, stateObj, false)
        stateObj.Pending := false
        stateObj.TargetStartTicks := 0
        stateObj.TransitionTo(GuardPhase.Exhausted)
        this.Callbacks.ClearProcessIdentity.Call(stateObj)
        if firstMissingObservation
            stateObj.MissingSinceTicks := this.Now()
        if (stateObj.State != statusText) {
            this.UpdateState(path, stateObj, statusText)
            this.Log("监测到目标文件已不存在，守护进入缺失状态，文件恢复后将自动复核: " path)
        }
        if (firstMissingObservation || wasBlocking)
            this.SaveJournal()
    }

    ClearTargetMissing(path, stateObj) {
        if !stateObj.MissingSinceTicks
            return false
        stateObj.MissingSinceTicks := 0
        stateObj.SafetyFingerprint := this.GetFingerprint(path)
        stateObj.SafetyStableSince := this.Now()
        stateObj.MaintenanceFingerprintCheckedTicks := 0
        stateObj.MaintenanceReadyCheckedTicks := 0
        stateObj.TransitionTo(GuardPhase.Initializing)
        this.UpdateState(path, stateObj, "初始化...")
        this.Log("目标文件已恢复，重新核对运行状态: " path)
        return true
    }

    Enter(path, stateObj, reason := "") {
        if !stateObj.Enabled || !this.IsProtectionEnabled(path, stateObj)
            return false
        if (stateObj.MaintenanceMode == MaintenancePhase.TimedOut)
            return true
        nowTicks := this.Now()
        firstEntry := !this.IsBlocking(stateObj)
            || stateObj.MaintenanceMode == MaintenancePhase.Arbitrating
        if firstEntry {
            stateObj.CancelScheduledTasks()
            stateObj.MaintenanceMode := MaintenancePhase.Updating
            stateObj.Pending := true
            stateObj.TargetStartTicks := 0
            stateObj.ArbitrationSnapshotRequestTicks := 0
            stateObj.ArbitrationSignalBaselineTicks := 0
            stateObj.MaintenanceStartedTicks := nowTicks
            stateObj.MaintenanceStartedAt := A_NowUTC
            if !stateObj.MaintenanceFileChanged
                stateObj.MaintenanceBaselineFingerprint := this.GetFingerprint(path)
            this.Log("已进入软件升级保护: " path
                (reason != "" ? "（" reason "）" : ""))
        }
        stateObj.MaintenanceLastActivityTicks := nowTicks
        stateObj.MaintenanceMode := MaintenancePhase.Updating
        stateObj.Pending := true
        this.UpdateState(path, stateObj, "🔄 软件升级中")
        if firstEntry
            this.SaveJournal()
        return true
    }

    LearnActors(path, stateObj) {
        if !stateObj.MaintenanceFileChanged
            || !stateObj.MaintenanceLearningCandidates.Count
            return false
        known := Map()
        known.CaseSense := "Off"
        for signature in stateObj.MaintenanceConfig.LearnedActors
            known[signature] := true
        changed := false
        for signature in stateObj.MaintenanceLearningCandidates {
            if !known.Has(signature) {
                stateObj.MaintenanceConfig.LearnedActors.Push(signature)
                known[signature] := true
                changed := true
            }
        }
        if changed
            this.Log("已从本次升级过程学习更新程序特征: " path)
        return changed
    }

    Complete(path, stateObj) {
        learnedChanged := this.LearnActors(path, stateObj)
        identityChanged := this.Callbacks.RefreshShortcutIdentity.Call(path,
            stateObj, true)
        currentFingerprint := this.GetFingerprint(path)
        stableMs := stateObj.MaintenanceConfig.StableSeconds * 1000
        stateObj.SafetyFingerprint := currentFingerprint
        stateObj.SafetyStableSince := this.Now() - stableMs
        this.ResetSession(path, stateObj, false)
        this.SaveJournal()
        if (learnedChanged || identityChanged)
            this.Callbacks.SaveApps.Call()
        observation := this.Callbacks.ObserveTarget.Call(path, "", 1000)
        if observation.IsRunning() {
            this.Callbacks.SetProcessIdentity.Call(stateObj, observation.PID)
            stateObj.FailCount := 0
            this.Callbacks.UpdateRunningState.Call(path, stateObj)
            this.Log("软件升级完成，已恢复正常守护: " path)
            return
        }
        if observation.IsUnknown() {
            stateObj.Pending := true
            this.UpdateState(path, stateObj, "⏳ 等待进程状态...")
            this.Callbacks.ScheduleRestart.Call(path, stateObj, 2000)
            return
        }
        this.UpdateState(path, stateObj, "⏳ 升级完成，准备恢复")
        this.Callbacks.ScheduleRestart.Call(path, stateObj, 200)
        this.Log("软件升级完成，准备恢复启动: " path)
    }

    MarkTimedOut(path, stateObj) {
        stateObj.CancelScheduledTasks()
        stateObj.MaintenanceMode := MaintenancePhase.TimedOut
        stateObj.Pending := true
        stateObj.TargetStartTicks := 0
        this.UpdateState(path, stateObj, "⚠️ 升级等待超时")
        this.SaveJournal()
        this.Log("软件升级保护超过最长等待时间，需要用户确认后恢复: " path)
    }

    Advance(path, stateObj) {
        mode := stateObj.MaintenanceMode
        if (mode == MaintenancePhase.Normal
            || mode == MaintenancePhase.TimedOut)
            return
        if !stateObj.Enabled || !this.IsProtectionEnabled(path, stateObj) {
            this.ResetSession(path, stateObj)
            return
        }
        nowTicks := this.Now()
        if (mode == MaintenancePhase.Arbitrating) {
            if this.TargetAppearsRunning(stateObj) {
                this.ResetSession(path, stateObj)
                this.Callbacks.UpdateRunningState.Call(path, stateObj)
                return
            }
            targetExists := this.Callbacks.TargetReferenceExists.Call(path,
                stateObj)
            arbitrationBaseline := stateObj.ArbitrationSignalBaselineTicks
            hasNewSignal := (stateObj.LastActorSeenTicks
                    && stateObj.LastActorSeenTicks > arbitrationBaseline)
                || (stateObj.LastFileActivityTicks
                    && stateObj.LastFileActivityTicks > arbitrationBaseline)
            if this.HasActiveActors(stateObj) || hasNewSignal {
                this.Enter(path, stateObj, "仲裁期间捕获到升级活动")
                return
            }
            elapsedMs := nowTicks - stateObj.MaintenanceStartedTicks
            detectionMs := stateObj.MaintenanceConfig.DetectionSeconds * 1000
            fastDecisionMs := Min(2000, detectionMs)
            fallbackDecisionMs := Min(3500, detectionMs)
            freshSnapshotReady := stateObj.ArbitrationSnapshotRequestTicks
                && this.Runtime.processSnapshots.LatestSnapshotTicks
                    >= stateObj.ArbitrationSnapshotRequestTicks
            if ((freshSnapshotReady && elapsedMs >= fastDecisionMs)
                || elapsedMs >= fallbackDecisionMs) {
                elapsedSeconds := Format("{:.1f}", elapsedMs / 1000)
                decisionNote := freshSnapshotReady
                    ? "后台进程快照已确认"
                    : "后台进程快照未及时返回，已使用快速兜底"
                if !targetExists {
                    SplitPath(path, , , &missingExtension)
                    missingStatus := RegExMatch(missingExtension,
                        "i)^(ahk|py|pyw|js|vbs|vbe|wsf|ps1|bat|cmd|rb|pl|php|lua|jar|sh|bash)$")
                        ? "❌ 脚本不存在" : "❌ 程序不存在"
                    this.Log("未发现升级活动（" decisionNote "，耗时 "
                        elapsedSeconds " 秒），目标仍不存在: " path)
                    this.MarkTargetMissing(path, stateObj, missingStatus)
                    return
                }
                remainingDelay := Max(100,
                    stateObj.MaintenanceRestartDueTicks - nowTicks)
                this.ResetSession(path, stateObj, false)
                this.SaveJournal()
                this.Log("未发现升级活动（" decisionNote "，耗时 "
                    elapsedSeconds " 秒），恢复普通重启流程: " path)
                this.Callbacks.ScheduleRestart.Call(path, stateObj,
                    remainingDelay)
            }
            return
        }
        if (nowTicks - stateObj.MaintenanceStartedTicks
            >= stateObj.MaintenanceConfig.MaxWaitSeconds * 1000) {
            this.MarkTimedOut(path, stateObj)
            return
        }
        if stateObj.ExplicitMaintenance {
            stateObj.MaintenanceLastActivityTicks := nowTicks
            stateObj.MaintenanceMode := MaintenancePhase.Updating
            this.UpdateState(path, stateObj, "🔄 显式升级维护中")
            return
        }
        if this.Callbacks.RefreshShortcutIdentity.Call(path, stateObj) {
            stateObj.MaintenanceReadyCheckedTicks := 0
            this.Callbacks.SaveApps.Call()
        }
        activeActors := this.HasActiveActors(stateObj)
        if (!stateObj.MaintenanceReadyCheckedTicks
            || nowTicks - stateObj.MaintenanceReadyCheckedTicks >= 1000) {
            stateObj.MaintenanceLastReady := this.Callbacks
                .IsTargetFileReady.Call(path)
            stateObj.MaintenanceReadyCheckedTicks := nowTicks
        }
        fileReady := stateObj.MaintenanceLastReady
        quietMs := nowTicks - Max(stateObj.MaintenanceLastActivityTicks,
            stateObj.LastFileActivityTicks)
        stableMs := stateObj.MaintenanceConfig.StableSeconds * 1000
        if activeActors {
            stateObj.MaintenanceLastActivityTicks := nowTicks
            stateObj.MaintenanceMode := MaintenancePhase.Updating
            this.UpdateState(path, stateObj, "🔄 软件升级中")
            return
        }
        if !fileReady {
            stateObj.MaintenanceMode := MaintenancePhase.Updating
            this.UpdateState(path, stateObj, FileExist(path)
                ? "🔄 等待程序文件可用" : "🔄 等待程序文件恢复")
            return
        }
        if (quietMs < stableMs) {
            stateObj.MaintenanceMode := MaintenancePhase.Stabilizing
            remaining := Max(1, Ceil((stableMs - quietMs) / 1000))
            this.UpdateState(path, stateObj, "⏳ 确认升级文件稳定 " remaining "s")
            return
        }
        this.Complete(path, stateObj)
    }

    CanSafelyLaunch(path, stateObj, &reason := "") {
        reason := ""
        if !this.IsProtectionEnabled(path, stateObj)
            return true
        if this.IsBlocking(stateObj) {
            reason := stateObj.MaintenanceMode == MaintenancePhase.TimedOut
                ? "升级等待已超时" : "升级保护仍在进行"
            return false
        }
        if this.HasActiveActors(stateObj) {
            reason := "检测到相关安装进程"
            this.Enter(path, stateObj, reason)
            return false
        }
        maintenanceSubject := this.Callbacks.GetMaintenanceSubjectPath.Call(path)
        if !FileExist(maintenanceSubject) {
            reason := "目标程序文件不存在"
            return false
        }
        currentFingerprint := this.GetFingerprint(path)
        nowTicks := this.Now()
        if (currentFingerprint != stateObj.SafetyFingerprint) {
            stateObj.SafetyFingerprint := currentFingerprint
            stateObj.SafetyStableSince := nowTicks
            this.RecordFootprintActivity(path, stateObj)
            reason := "程序文件刚刚发生变化"
            this.Enter(path, stateObj, reason)
            return false
        }
        stableMs := stateObj.MaintenanceConfig.StableSeconds * 1000
        if !stateObj.SafetyStableSince
            stateObj.SafetyStableSince := nowTicks
        if (nowTicks - stateObj.SafetyStableSince < stableMs
            || (stateObj.LastFileActivityTicks
                && nowTicks - stateObj.LastFileActivityTicks < stableMs)) {
            reason := "程序文件尚未达到稳定等待时间"
            this.Enter(path, stateObj, reason)
            return false
        }
        if !this.Callbacks.IsTargetFileReady.Call(path) {
            reason := "程序文件正在写入或结构不完整"
            this.Enter(path, stateObj, reason)
            return false
        }
        return true
    }

    CreateSnapshotIndex(snapshot, capturedAtTicks,
        supportsCommandLine := true) {
        return this.Runtime.processSnapshots.IndexFactory.Call(snapshot,
            capturedAtTicks, supportsCommandLine)
    }

    IsSupportedTarget(path) {
        return this.Callbacks.IsSupportedTarget.Call(path)
    }

    CanonicalPath(path) {
        return this.Callbacks.CanonicalPath.Call(path)
    }

    GetFingerprint(path) {
        return this.Callbacks.GetFingerprint.Call(path)
    }

    UpdateState(path, expectedSupervisor, statusText) {
        path := this.Callbacks.NormalizeTargetPath.Call(path)
        if !(expectedSupervisor is TargetSupervisor)
            || !this.Runtime.appStates.Has(path)
            || this.Runtime.appStates[path] != expectedSupervisor {
            return false
        }
        this.Callbacks.UpdateState.Call(path, statusText,
            expectedSupervisor)
        return true
    }

    SaveJournal() {
        static isSaving := false
        previousCritical := A_IsCritical
        Critical("On")
        if isSaving {
            Critical(previousCritical ? previousCritical : "Off")
            return false
        }
        isSaving := true
        tempPath := this.Runtime.maintenanceJournalPath ".tmp."
            this.Now() "_" A_ScriptHwnd
        try {
            try FileDelete(tempPath)
            FileAppend("", tempPath, "UTF-16")
            for path, stateObj in this.Runtime.appStates {
                if this.IsBlocking(stateObj)
                    && stateObj.MaintenanceMode
                        != MaintenancePhase.Arbitrating {
                    IniWrite(this.Callbacks.SerializeSession.Call(path,
                        stateObj), tempPath, "Sessions",
                        this.Callbacks.HashPath.Call(path))
                }
            }
            FileMove(tempPath, this.Runtime.maintenanceJournalPath, 1)
            this.JournalDirty := false
            this.JournalRetryDueTicks := 0
            this.JournalRetryDelayMs := 5000
            return true
        } catch as journalError {
            try FileDelete(tempPath)
            this.JournalDirty := true
            retryDelayMs := this.JournalRetryDelayMs
            this.JournalRetryDueTicks := this.Now() + retryDelayMs
            this.JournalRetryDelayMs := Min(retryDelayMs * 2, 60000)
            this.Log("保存升级保护恢复状态失败: " journalError.Message)
            return false
        } finally {
            isSaving := false
            Critical(previousCritical ? previousCritical : "Off")
        }
    }

    Log(message) {
        this.Callbacks.Log.Call(message)
    }

    Now() {
        return DllCall("kernel32\GetTickCount64", "UInt64")
    }
}
