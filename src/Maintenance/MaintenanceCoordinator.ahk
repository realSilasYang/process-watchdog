; 软件升级保护的运行时协调器。
; 它连接更新进程识别、目录监听、文件稳定确认、会话日志和目标控制器阶段转换；
; 普通守护与升级检查共享工作门，所有定时器、监听器和迟到回调都受会话代际约束。

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
        for path, stateObj in this.Runtime.appStates {
            try this.EnsureWatcher(path, stateObj)
            catch as watcherError {
                this.LogTargetError(path, watcherError)
            }
        }
        snapshot := []
        snapshotReady := false
        try snapshot := this.QueryNativeSnapshot(&snapshotReady)
        catch as snapshotError {
            this.Log(this.Text("升级保护初始化时无法建立进程基线，将在下一轮重试。"))
            this.Log(this.Text("升级进程扫描异常：{1}",
                this.DiagnosticText(snapshotError.Message)))
        }
        if snapshotReady {
            initialSnapshotTicks := this.Now()
            initialSnapshotIndex := this.CreateSnapshotIndex(snapshot,
                initialSnapshotTicks, this.SnapshotSupportsCommandLine)
            for path, stateObj in this.Runtime.appStates {
                if !stateObj.Enabled || !InStr(path, "\")
                    continue
                try {
                    observation := this.Callbacks.ObserveTarget.Call(path,
                        initialSnapshotIndex)
                    if observation.IsRunning()
                        this.Callbacks.SetProcessIdentity.Call(stateObj,
                            observation.PID, observation.CreationIdentity)
                } catch as initializationProbeError {
                    this.LogTargetError(path, initializationProbeError)
                }
            }
            try this.RefreshActors(snapshot, true,
                this.SnapshotSupportsCommandLine, initialSnapshotIndex)
            catch as actorError {
                this.Log(this.Text("升级保护初始化时无法建立进程基线，将在下一轮重试。"))
                this.Log(this.Text("升级进程扫描异常：{1}",
                    this.DiagnosticText(actorError.Message)))
            }
        } else {
            this.Log(this.Text("升级保护初始化时无法建立进程基线，将在下一轮重试。"))
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
        if command == "PING|"
            return true
        if !this.Initialized {
            this.PendingCommands.Push(command)
            return true
        }
        if !this.Runtime.guardWorkGate.TryEnter("MaintenanceCommand") {
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
                try this.Log(this.Text("显式升级维护命令执行异常：{1}",
                    this.DiagnosticText(commandError.Message)))
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
            this.Log(this.Text("显式升级维护命令未找到监控目标：{1}", path))
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
            this.Log(this.Text("显式升级维护命令被忽略，目标未启用升级保护：{1}", path))
            return false
        }
        if (stateObj.MaintenanceMode == MaintenancePhase.TimedOut)
            this.ResetSession(path, stateObj, false)
        stateObj.ExplicitMaintenance := true
        this.Enter(path, stateObj, "收到显式维护开始命令")
        this.UpdateState(path, stateObj,
            this.Text("🔄 显式升级维护中"),
            GuardStatusKind.MaintenanceUpdating)
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
        this.UpdateState(path, stateObj,
            this.Text("⏳ 确认升级文件稳定"),
            GuardStatusKind.MaintenanceStabilizing)
        this.SaveJournal()
        this.Log(this.Text("收到显式维护结束命令，开始执行安全恢复检查：{1}", path))
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
            restoredMode := String(session.Mode)
            validActiveMode := restoredMode == MaintenancePhase.Updating
                || restoredMode == MaintenancePhase.Stabilizing
                || restoredMode == MaintenancePhase.Recovering
            restoredAsTimedOut := restoredMode == MaintenancePhase.TimedOut
                || !validActiveMode
            stateObj.Pending := true
            stateObj.TargetStartTicks := 0
            stateObj.MaintenanceStartedAt := session.StartedAt
            elapsedSeconds := 0
            validStartedAt := RegExMatch(stateObj.MaintenanceStartedAt,
                "^\d{14}$") != 0
            if validStartedAt {
                try {
                    elapsedSeconds := DateDiff(A_NowUTC,
                        stateObj.MaintenanceStartedAt, "Seconds")
                    if elapsedSeconds < 0
                        validStartedAt := false
                } catch
                    validStartedAt := false
            }
            if !validStartedAt {
                restoredAsTimedOut := true
                elapsedSeconds := stateObj.MaintenanceConfig.MaxWaitSeconds
                stateObj.MaintenanceStartedAt := A_NowUTC
            }
            stateObj.MaintenanceStartedTicks := this.Now()
                - elapsedSeconds * 1000
            stateObj.MaintenanceLastActivityTicks := this.Now()
            stateObj.MaintenanceActorCheckedTicks := 0
            stateObj.MaintenanceBaselineFingerprint := session.BaselineFingerprint
            stateObj.MaintenanceFileChanged := session.FileChanged
            stateObj.ExplicitMaintenance := session.Explicit
            this.RestoreActorRecords(stateObj, session)
            if (restoredAsTimedOut
                || elapsedSeconds >= stateObj.MaintenanceConfig.MaxWaitSeconds) {
                stateObj.RestoreMaintenanceMode(MaintenancePhase.TimedOut)
                this.UpdateState(path, stateObj,
                    this.Text("⚠️ 升级等待超时"),
                    GuardStatusKind.MaintenanceTimedOut)
            } else {
                stateObj.RestoreMaintenanceMode(MaintenancePhase.Recovering)
                this.UpdateState(path, stateObj,
                    this.Text("🔄 恢复升级保护状态"),
                    GuardStatusKind.MaintenanceRecovering)
            }
            this.Log(this.Text("已恢复未完成的升级保护会话：{1}", path))
        }
        this.SaveJournal()
    }

    RestoreActorRecords(stateObj, session) {
        stateObj.KnownActorIdentities := Map()
        stateObj.TransientActorIdentities := Map()
        stateObj.MaintenanceLearningCandidates := Map()
        if !IsObject(session)
            return false
        restoredTicks := this.Now()
        restoredCount := 0
        if session.HasOwnProp("ActorRecords")
            && Type(session.ActorRecords) == "Array" {
            for actorRecord in session.ActorRecords {
                if !IsObject(actorRecord)
                    || !actorRecord.HasOwnProp("Identity")
                    || !(actorRecord.Identity is MaintenanceActorIdentity)
                    continue
                identity := actorRecord.Identity
                if identity.PID <= 0 || identity.CreationIdentity == ""
                    continue
                if this.Runtime.maintenanceActorMatcher.Canonical(
                    identity.RootPath) != this.Runtime
                        .maintenanceActorMatcher.Canonical(
                            stateObj.MaintenanceConfig.InstallRoot)
                    continue
                actorRecord.LastSeenTicks := restoredTicks
                stateObj.KnownActorIdentities[identity.Key] := actorRecord
                stateObj.TransientActorIdentities[identity.Key] := actorRecord
                restoredCount++
                if actorRecord.HasOwnProp("Match")
                    && IsObject(actorRecord.Match)
                    && actorRecord.Match.HasOwnProp("LearnableSignature")
                    && actorRecord.Match.LearnableSignature != "" {
                    normalizedSignature := this.Runtime
                        .maintenanceActorMatcher.NormalizeLearnedSignature(
                            actorRecord.Match.LearnableSignature,
                            stateObj.MaintenanceConfig.InstallRoot)
                    actorRecord.Match.LearnableSignature := normalizedSignature
                    if normalizedSignature != ""
                        stateObj.MaintenanceLearningCandidates[
                            normalizedSignature] := true
                }
            }
        }
        if session.HasOwnProp("LearningCandidates")
            && Type(session.LearningCandidates) == "Array" {
            for signature in session.LearningCandidates {
                normalizedSignature := this.Runtime.maintenanceActorMatcher
                    .NormalizeLearnedSignature(signature,
                        stateObj.MaintenanceConfig.InstallRoot)
                if normalizedSignature != ""
                    stateObj.MaintenanceLearningCandidates[
                        normalizedSignature] := true
            }
        }
        if restoredCount {
            stateObj.LastActorSeenTicks := restoredTicks
            this.JournalDirty := true
        }
        return restoredCount > 0
    }

    ProcessTick() {
        if this.Stopped || !this.Initialized
            return
        if !this.Runtime.guardWorkGate.TryEnter("MaintenanceProcessTick")
            return
        loopStartedTicks := 0
        try {
            loopStartedTicks := this.Now()
            nowTicks := this.Now()
            snapshots := this.Runtime.processSnapshots
            snapshots.Pump()
            if !this.ProcessBaselineReady {
                ; 初始化瞬间的原生快照可能暂时失败，完整 WMI 快照也可能长期
                ; 不可用。定时器继续用低成本原生枚举重建基线，但绝不在 UI
                ; 线程同步回退 WMI；最近启动的安装器仍按基线规则保守纳入。
                if snapshots.HasFreshSnapshot(snapshots.ReuseIntervalMs,
                    nowTicks) {
                    return
                }
                if snapshots.CanRetry(nowTicks)
                    snapshots.Start()
                baselineSnapshot := this.QueryNativeSnapshot(
                    &baselineReady)
                if baselineReady {
                    baselineIndex := this.CreateSnapshotIndex(
                        baselineSnapshot, nowTicks,
                        this.SnapshotSupportsCommandLine)
                    this.RefreshActors(baselineSnapshot, true,
                        this.SnapshotSupportsCommandLine, baselineIndex)
                }
                return
            }
            if snapshots.HasFreshSnapshot(snapshots.ReuseIntervalMs, nowTicks)
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
            ; 完整命令行快照始终交给后台工作器。原生快照仅提供快速路径，
            ; 不能因为它成功就长期跳过安装器命令行和父子关系证据。
            snapshots.Start()
            if snapshots.HasFreshNativeSnapshot(snapshots.ReuseIntervalMs,
                nowTicks)
                return
            snapshot := this.QueryNativeSnapshot(&snapshotReady)
            if snapshotReady
                this.RefreshActors(snapshot, false,
                    this.SnapshotSupportsCommandLine)
        } catch as processError {
            try this.Log(this.Text("升级进程扫描异常：{1}",
                this.DiagnosticText(processError.Message)))
        } finally {
            this.Runtime.guardWorkGate.Leave()
            if loopStartedTicks
                this.Callbacks.LogSlow.Call("升级进程扫描", loopStartedTicks)
        }
    }

    EventTick() {
        if this.Stopped || !this.Initialized
            return
        if !this.Runtime.guardWorkGate.TryEnter("MaintenanceEventTick")
            return
        loopStartedTicks := 0
        try {
            loopStartedTicks := this.Now()
            nowTicks := this.Now()
            this.DrainPendingCommands()
            staleRoots := []
            fingerprintRequests := Map()
            fingerprintRequests.CaseSense := "Off"
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
                    this.Log(this.Text("升级文件监听异常（{1}）：{2}",
                        entry.rootPath,
                        this.DiagnosticText(watcherError.Message)))
                    continue
                }
                for change in changes {
                    for path, stateObj in entry.subscribers {
                        try {
                            if (this.Runtime.appStates.Has(path)
                                && this.Runtime.appStates[path] == stateObj
                                && stateObj.Enabled
                                && this.IsProtectionEnabled(path, stateObj)) {
                                requiresFingerprint :=
                                    this.FootprintChangeRequiresFingerprint(
                                        path, stateObj, change.RelativePath,
                                        entry)
                                if (requiresFingerprint
                                    && stateObj.MaintenanceMode
                                        == MaintenancePhase.Normal) {
                                    ; 通知溢出和子目录同名文件都不能单独证明目标
                                    ; 已变化，但必须绕过常规间隔在本轮立即复核。
                                    fingerprintRequests[path] := stateObj
                                    stateObj.MaintenanceFingerprintCheckedTicks := 0
                                } else if this.IsRelevantFootprintChange(path,
                                    stateObj, change.RelativePath, entry) {
                                    this.RecordFootprintActivity(path, stateObj,
                                        change.RelativePath)
                                }
                            }
                        } catch as targetEventError {
                            this.LogTargetError(path, targetEventError)
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
                try {
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
                forcedFingerprintCheck := fingerprintRequests.Has(path)
                    && fingerprintRequests[path] == stateObj
                shouldCheckFingerprint := stateObj.MaintenanceMode
                    != MaintenancePhase.TimedOut
                    && (forcedFingerprintCheck
                        || !stateObj.MaintenanceFingerprintCheckedTicks
                        || nowTicks - stateObj.MaintenanceFingerprintCheckedTicks
                            >= fingerprintInterval)
                if (shouldCheckFingerprint
                    && stateObj.MaintenanceMode == MaintenancePhase.Normal
                    && !forcedFingerprintCheck) {
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
                } catch as targetAdvanceError {
                    this.LogTargetError(path, targetAdvanceError)
                }
            }
            if (this.JournalDirty && nowTicks >= this.JournalRetryDueTicks)
                this.SaveJournal()
        } catch as eventError {
            try this.Log(this.Text("升级文件监听异常：{1}",
                this.DiagnosticText(eventError.Message)))
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
        if this.FootprintChangeRequiresFingerprint(path, stateObj,
            relativePath, watcherEntry) {
            return this.IsBlocking(stateObj)
                && stateObj.MaintenanceMode != MaintenancePhase.TimedOut
        }
        ; 进入升级会话后，配置、资源、临时文件以及无扩展名文件同样是
        ; 更新器活动证据。普通运行期仍使用下面的白名单，避免共享安装
        ; 目录中的日常写入触发升级保护。
        if (this.IsBlocking(stateObj)
            && stateObj.MaintenanceMode != MaintenancePhase.TimedOut)
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
        if (!InStr(relativePath, "\") && !InStr(subjectRelative, "\")
            && StrLower(changedName) == StrLower(targetName))
            return true
        extension := StrLower(extension)
        ; 同一套件的多个目标常共享根目录下的 DLL、资源包和运行库。无法把
        ; 公共文件变化唯一归给某个 EXE 时，必须通知全部订阅者，不能让变化
        ; 因“归属不明”而完全消失；目标仍在运行时这只记录证据，不会直接暂停。
        return InStr("|exe|com|dll|sys|ocx|cpl|mui|pak|bin|dat|node|asar|jar|json|xml|ini|cfg|config|resources|nupkg|msi|cab|zip|7z|",
            "|" extension "|") != 0
    }

    FootprintChangeRequiresFingerprint(path, stateObj, relativePath,
        watcherEntry := "") {
        relativePath := StrReplace(relativePath, "/", "\")
        if relativePath == "*"
            return true
        if !InStr(relativePath, "\")
            return false

        subjectPath := this.Callbacks.GetMaintenanceSubjectPath.Call(path)
        rootPath := watcherEntry && watcherEntry.HasOwnProp("rootPath")
            ? watcherEntry.rootPath : stateObj.MaintenanceConfig.InstallRoot
        canonicalSubject := this.CanonicalPath(subjectPath)
        canonicalRoot := RTrim(this.CanonicalPath(rootPath), "\")
        subjectRelative := canonicalSubject == canonicalRoot ? ""
            : (InStr(canonicalSubject, canonicalRoot "\") == 1
                ? SubStr(canonicalSubject, StrLen(canonicalRoot) + 2) : "")
        if subjectRelative == "" || InStr(subjectRelative, "\")
            return false
        SplitPath(relativePath, &changedName)
        SplitPath(subjectPath, &targetName)
        return StrLower(changedName) == StrLower(targetName)
    }

    QueryNativeSnapshot(&snapshotReady) {
        this.SnapshotSupportsCommandLine := false
        snapshotResult := this.Runtime.processInspector.CaptureNativeSnapshot()
        snapshotReady := snapshotResult.Ready
        snapshot := snapshotResult.Processes
        if !snapshotReady
            return snapshot
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
        trackedActorAnchors := Map()
        for path, stateObj in this.Runtime.appStates {
            if !stateObj.Enabled || !this.IsProtectionEnabled(path, stateObj)
                continue
            targetPid := stateObj.PID ? stateObj.PID : stateObj.LastKnownPID
            if targetPid
                targetPids[targetPid] := true
            matcher.AddActorAnchors(trackedActorAnchors,
                stateObj.TransientActorIdentities)
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
            executablePath := matcher.CanonicalExecutablePath(processInfo)
            if (executablePath != "" && learnedPaths.Count
                && learnedPaths.Has(executablePath)) {
                candidates.Push(processInfo)
                continue
            }
            if matcher.IsDescendantOfTrackedActor(processInfo, processMap,
                trackedActorAnchors) {
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
        commonActorCandidates := this.BuildActorCandidates(snapshot,
            processMap)
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
            try {
            knownActorIdentities := stateObj.KnownActorIdentities
            transientActorIdentities := stateObj.TransientActorIdentities
            trackedActorAnchors := matcher.BuildActorAnchorMap(
                transientActorIdentities)
            targetPid := stateObj.PID ? stateObj.PID : stateObj.LastKnownPID
            targetCreation := stateObj.PID
                ? stateObj.PIDCreationIdentity
                : stateObj.LastKnownPIDCreationIdentity
            subjectPath := this.Callbacks.GetMaintenanceSubjectPath.Call(path)
            rootPath := stateObj.MaintenanceConfig.InstallRoot
            maintenanceBlocking := this.IsBlocking(stateObj)
            confirmedFootprint := this.HasConfirmedMaintenanceFootprint(
                stateObj)
            matchContext := matcher.CreateMatchContext(subjectPath, rootPath,
                stateObj.MaintenanceConfig.LearnedActors, targetPid,
                targetCreation, processMap, maintenanceBlocking,
                trackedActorAnchors, confirmedFootprint)
            ; 普通名称的服务、解压器和复制工具只有在本目标已确认发生升级
            ; 足迹变化后才需要完整快照；其他目标继续使用公共小候选集。
            actorCandidates := maintenanceBlocking
                && stateObj.MaintenanceMode != MaintenancePhase.TimedOut
                && confirmedFootprint
                ? snapshot : commonActorCandidates
            activeKnown := Map()
            activeTransient := Map()
            observedTransientCount := 0
            for processInfo in actorCandidates {
                matchResult := matcher.MatchPrepared(processInfo,
                    matchContext)
                if !matchResult.Matched
                    continue
                identity := matcher.CreateIdentity(processInfo, rootPath,
                    processMap)
                if !(identity is MaintenanceActorIdentity)
                    continue
                if (matchResult.Evidence == "maintenance-installer-signal"
                    && !this.WasProcessStartedRecently(processInfo,
                        Max(30, stateObj.MaintenanceConfig.DetectionSeconds * 3))
                    && !transientActorIdentities.Has(identity.Key))
                    continue
                actorRecord := {Process: processInfo, Identity: identity,
                    Match: matchResult, LastSeenTicks: snapshotTicks}
                identityKey := identity.Key
                activeKnown[identityKey] := actorRecord
                wasKnown := knownActorIdentities.Has(identityKey)
                ; 用户规则或已验证学习结果是强证据，即使更新器早于小助手启动，
                ; 也不能被初始基线吞掉；“最近启动”只约束启发式发现的候选。
                strongConfiguredMatch := matchResult.Evidence
                    == "learned-scoped-path"
                shouldTrack := strongConfiguredMatch
                    || transientActorIdentities.Has(identityKey)
                    || (!isBaseline && !wasKnown)
                    || (stateObj.MaintenanceMode
                        == MaintenancePhase.Recovering && !wasKnown)
                    || (isBaseline && !wasKnown
                        && this.WasProcessStartedRecently(processInfo,
                            stateObj.MaintenanceConfig.DetectionSeconds))
                if shouldTrack {
                    activeTransient[identityKey] := actorRecord
                    observedTransientCount++
                    if !wasKnown
                        this.RecordActor(path, stateObj, actorRecord)
                }
            }
            matcher.RetainLiveRecords(knownActorIdentities, activeKnown)
            matcher.RetainLiveRecords(transientActorIdentities,
                activeTransient)
            this.RetainRecentActorAnchors(stateObj,
                transientActorIdentities, activeTransient, snapshotTicks)
            transientActorsChanged := !this.ActorIdentitySetsEqual(
                transientActorIdentities, activeTransient)
            stateObj.KnownActorIdentities := activeKnown
            stateObj.TransientActorIdentities := activeTransient
            stateObj.MaintenanceActorCheckedTicks := snapshotTicks
            if transientActorsChanged && this.IsBlocking(stateObj)
                this.JournalDirty := true
            if (observedTransientCount && this.IsBlocking(stateObj))
                stateObj.MaintenanceLastActivityTicks := this.Now()
            } catch as targetActorError {
                this.LogTargetError(path, targetActorError)
            }
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
        if this.IsBlocking(stateObj)
            this.JournalDirty := true
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
            return currentCreation != ""
                && currentCreation == stateObj.PIDCreationIdentity
        }
        return true
    }

    HasActiveActors(stateObj) {
        staleIdentities := []
        hasActiveActor := false
        nowTicks := this.Now()
        anchorWindowMs := stateObj.MaintenanceConfig.DetectionSeconds * 1000
        for identityKey, actorRecord in stateObj.TransientActorIdentities {
            if !actorRecord.HasOwnProp("Identity") {
                staleIdentities.Push(identityKey)
                continue
            }
            identityStatus := this.Runtime.maintenanceActorMatcher
                .GetIdentityStatus(actorRecord.Identity)
            if identityStatus != 0 {
                hasActiveActor := true
                continue
            }
            lastSeenTicks := actorRecord.HasOwnProp("LastSeenTicks")
                ? actorRecord.LastSeenTicks : stateObj.LastActorSeenTicks
            if !lastSeenTicks || nowTicks < lastSeenTicks
                || nowTicks - lastSeenTicks > anchorWindowMs {
                staleIdentities.Push(identityKey)
            }
        }
        for identityKey in staleIdentities
            stateObj.TransientActorIdentities.Delete(identityKey)
        return hasActiveActor
    }

    RetainRecentActorAnchors(stateObj, previousRecords, activeRecords,
        snapshotTicks) {
        if Type(previousRecords) != "Map" || Type(activeRecords) != "Map"
            return activeRecords
        anchorWindowMs := stateObj.MaintenanceConfig.DetectionSeconds * 1000
        for identityKey, actorRecord in previousRecords {
            if activeRecords.Has(identityKey) || !IsObject(actorRecord)
                || !actorRecord.HasOwnProp("Identity") {
                continue
            }
            lastSeenTicks := actorRecord.HasOwnProp("LastSeenTicks")
                ? actorRecord.LastSeenTicks : stateObj.LastActorSeenTicks
            if lastSeenTicks && snapshotTicks >= lastSeenTicks
                && snapshotTicks - lastSeenTicks <= anchorWindowMs {
                activeRecords[identityKey] := actorRecord
            }
        }
        return activeRecords
    }

    ActorIdentitySetsEqual(firstRecords, secondRecords) {
        if Type(firstRecords) != "Map" || Type(secondRecords) != "Map"
            return false
        if firstRecords.Count != secondRecords.Count
            return false
        for identityKey in firstRecords
            if !secondRecords.Has(identityKey)
                return false
        return true
    }

    HasFreshActorEvidence(stateObj, nowTicks) {
        checkedTicks := stateObj.MaintenanceActorCheckedTicks
        requiredTicks := Max(stateObj.MaintenanceStartedTicks,
            stateObj.LastFileActivityTicks)
        maximumAgeMs := Max(2000,
            this.Runtime.maintenanceProcessInterval * 2)
        return checkedTicks && checkedTicks >= requiredTicks
            && nowTicks >= checkedTicks
            && nowTicks - checkedTicks <= maximumAgeMs
    }

    HasConfirmedMaintenanceFootprint(stateObj) {
        return !!stateObj.MaintenanceFileChanged
            && (stateObj.LastFileActivityTicks
                || stateObj.MaintenanceMode == MaintenancePhase.Recovering)
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
            if this.TargetSubjectExists(path, stateObj) {
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
        targetExists := this.TargetSubjectExists(path, stateObj)
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
        this.UpdateState(path, stateObj,
            this.Text("⏳ 判断是否正在升级"),
            GuardStatusKind.MaintenanceArbitrating)
        this.SaveJournal()
        return true
    }

    MarkTargetMissing(path, stateObj, statusText,
        statusKind := "") {
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
            this.UpdateState(path, stateObj, statusText,
                statusKind != "" ? statusKind
                    : GuardStatusKind.TargetMissing)
            this.Log(this.Text("监测到目标文件已不存在，守护进入缺失状态，文件恢复后将自动复核：{1}", path))
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
        this.UpdateState(path, stateObj, this.Text("初始化..."),
            GuardStatusKind.Initializing)
        this.Log(this.Text("目标文件已恢复，重新核对运行状态：{1}", path))
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
            this.Log(this.Text("已进入软件升级保护：{1}{2}", path,
                reason != "" ? this.Text("（{1}）", this.Text(reason)) : ""))
        }
        stateObj.MaintenanceLastActivityTicks := nowTicks
        stateObj.MaintenanceMode := MaintenancePhase.Updating
        stateObj.Pending := true
        this.UpdateState(path, stateObj, this.Text("🔄 软件升级中"),
            GuardStatusKind.MaintenanceUpdating)
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
        rootPath := stateObj.MaintenanceConfig.InstallRoot
        matcher := this.Runtime.maintenanceActorMatcher
        for signature in stateObj.MaintenanceConfig.LearnedActors {
            normalized := matcher.NormalizeLearnedSignature(signature,
                rootPath)
            if normalized != ""
                known[normalized] := true
        }
        changed := false
        for signature in stateObj.MaintenanceLearningCandidates {
            normalized := matcher.NormalizeLearnedSignature(signature,
                rootPath)
            if (normalized != "" && !known.Has(normalized)) {
                stateObj.MaintenanceConfig.LearnedActors.Push(normalized)
                known[normalized] := true
                changed := true
            }
        }
        if changed
            this.Log(this.Text("已从本次升级过程学习更新程序特征：{1}", path))
        return changed
    }

    Complete(path, stateObj) {
        expectedGeneration := stateObj.Generation
        expectedMode := stateObj.MaintenanceMode
        if !this.IsCurrentSession(path, stateObj, expectedGeneration,
            expectedMode)
            return false
        recoveryObservationContext := this.BuildRecoveryObservationContext(
            stateObj)
        learnedChanged := this.LearnActors(path, stateObj)
        identityChanged := this.Callbacks.RefreshShortcutIdentity.Call(path,
            stateObj, true)
        if !this.IsCurrentSession(path, stateObj, expectedGeneration,
            expectedMode)
            return false
        currentFingerprint := this.GetFingerprint(path)
        if !this.IsCurrentSession(path, stateObj, expectedGeneration,
            expectedMode)
            return false
        stableMs := stateObj.MaintenanceConfig.StableSeconds * 1000
        stateObj.SafetyFingerprint := currentFingerprint
        stateObj.SafetyStableSince := this.Now() - stableMs
        this.ResetSession(path, stateObj, false)
        if !this.IsCurrentSession(path, stateObj, expectedGeneration,
            MaintenancePhase.Normal)
            return false
        this.SaveJournal()
        if !this.IsCurrentSession(path, stateObj, expectedGeneration,
            MaintenancePhase.Normal)
            return false
        if (learnedChanged || identityChanged) {
            this.Callbacks.SaveApps.Call()
            if !this.IsCurrentSession(path, stateObj, expectedGeneration,
                MaintenancePhase.Normal)
                return false
        }
        observation := this.Callbacks.ObserveTarget.Call(path, "", 1000,
            recoveryObservationContext)
        if !this.IsCurrentSession(path, stateObj, expectedGeneration,
            MaintenancePhase.Normal)
            return false
        if observation.IsRunning() {
            this.Callbacks.SetProcessIdentity.Call(stateObj, observation.PID,
                observation.CreationIdentity)
            if !this.IsCurrentSession(path, stateObj, expectedGeneration,
                MaintenancePhase.Normal)
                return false
            stateObj.FailCount := 0
            this.Callbacks.UpdateRunningState.Call(path, stateObj)
            if observation.Source == "process-image-inferred"
                this.Log(this.Text("候选进程镜像路径不可访问"))
            this.Log(this.Text("软件升级完成，已恢复正常守护：{1}", path))
            return true
        }
        if observation.IsUnknown() {
            stateObj.Pending := true
            this.UpdateState(path, stateObj,
                this.Text("⏳ 等待进程状态..."),
                GuardStatusKind.WaitingObservation)
            this.Callbacks.ScheduleRestart.Call(path, stateObj, 2000)
            return true
        }
        this.UpdateState(path, stateObj,
            this.Text("⏳ 升级完成，准备恢复"),
            GuardStatusKind.MaintenanceRecovering)
        this.Callbacks.ScheduleRestart.Call(path, stateObj, 200)
        this.Log(this.Text("软件升级完成，准备恢复启动：{1}", path))
        return true
    }

    BuildRecoveryObservationContext(stateObj) {
        if !stateObj.MaintenanceFileChanged
            return ""
        priorPid := stateObj.PID ? stateObj.PID : stateObj.LastKnownPID
        priorIdentity := stateObj.PIDCreationIdentity != ""
            ? stateObj.PIDCreationIdentity
            : stateObj.LastKnownPIDCreationIdentity
        detectionSeconds := stateObj.MaintenanceConfig.DetectionSeconds
        return {
            AllowInaccessibleImageFallback: true,
            PriorPID: priorPid,
            PriorCreationIdentity: priorIdentity,
            RecentStartSeconds: Max(30, detectionSeconds * 6)
        }
    }

    TryCompleteFromRecoveryObservation(path, stateObj) {
        observationContext := this.BuildRecoveryObservationContext(stateObj)
        if !IsObject(observationContext)
            return false
        try observation := this.Callbacks.ObserveTarget.Call(path, "", 1000,
            observationContext)
        catch
            return false
        if !IsObject(observation) || !observation.IsRunning()
            return false
        this.Complete(path, stateObj)
        return true
    }

    IsCurrentSession(path, stateObj, expectedGeneration,
        expectedMode := "") {
        path := this.Callbacks.NormalizeTargetPath.Call(path)
        return !this.Stopped && stateObj is TargetSupervisor
            && this.Runtime.appStates.Has(path)
            && this.Runtime.appStates[path] == stateObj
            && stateObj.Generation == expectedGeneration
            && (expectedMode == "" || stateObj.MaintenanceMode == expectedMode)
    }

    MarkTimedOut(path, stateObj) {
        stateObj.CancelScheduledTasks()
        stateObj.MaintenanceMode := MaintenancePhase.TimedOut
        stateObj.Pending := true
        stateObj.TargetStartTicks := 0
        this.UpdateState(path, stateObj, this.Text("⚠️ 升级等待超时"),
            GuardStatusKind.MaintenanceTimedOut)
        this.SaveJournal()
        this.Log(this.Text("软件升级保护超过最长等待时间，需要用户确认后恢复：{1}", path))
    }

    Advance(path, stateObj) {
        if stateObj.HasOwnProp("RelocationPending")
            && stateObj.RelocationPending
            return
        mode := stateObj.MaintenanceMode
        if (mode == MaintenancePhase.Normal
            || mode == MaintenancePhase.TimedOut)
            return
        if !stateObj.Enabled || !this.IsProtectionEnabled(path, stateObj) {
            this.ResetSession(path, stateObj)
            return
        }
        if this.Runtime.HasOwnProp("targetRelocationService")
            && IsObject(this.Runtime.targetRelocationService) {
            relocationService := this.Runtime.targetRelocationService
            if stateObj.MaintenanceFileChanged
                && relocationService.TryDetectVersionedUpgrade(path,
                    stateObj)
                return
            if !this.TargetSubjectExists(path, stateObj)
                && relocationService.TryDetect(path, stateObj)
                return
        }
        nowTicks := this.Now()
        if (mode == MaintenancePhase.Arbitrating) {
            if this.TargetAppearsRunning(stateObj) {
                this.ResetSession(path, stateObj)
                this.Callbacks.UpdateRunningState.Call(path, stateObj)
                return
            }
            targetExists := this.TargetSubjectExists(path, stateObj)
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
            freshSnapshotReady := stateObj.ArbitrationSnapshotRequestTicks
                && this.Runtime.processSnapshots.LatestSnapshotRequestTicks
                    >= stateObj.ArbitrationSnapshotRequestTicks
            ; 单次快照只能确认当前存在升级参与者，不能证明检测窗口余下时间
            ; 不会再出现更新器。无论快照是否及时返回，都等待用户配置的完整窗口。
            if (elapsedMs >= detectionMs) {
                elapsedSeconds := Format("{:.1f}", elapsedMs / 1000)
                decisionNote := freshSnapshotReady
                    ? "后台进程快照已确认"
                    : "后台进程快照未及时返回，已等待完整检测窗口"
                if !targetExists {
                    SplitPath(path, , , &missingExtension)
                    missingStatus := RegExMatch(missingExtension,
                        "i)^(ahk|py|pyw|js|vbs|vbe|wsf|ps1|bat|cmd|rb|pl|php|lua|jar|sh|bash)$")
                        ? this.Text("❌ 脚本不存在")
                        : this.Text("❌ 程序不存在")
                    this.Log(this.Text("未发现升级活动（{1}，耗时 {2} 秒），目标仍不存在：{3}",
                        this.Text(decisionNote), elapsedSeconds, path))
                    this.MarkTargetMissing(path, stateObj, missingStatus,
                        RegExMatch(missingExtension,
                            "i)^(ahk|py|pyw|js|vbs|vbe|wsf|ps1|bat|cmd|rb|pl|php|lua|jar|sh|bash)$")
                            ? GuardStatusKind.ScriptMissing
                            : GuardStatusKind.ProgramMissing)
                    return
                }
                remainingDelay := Max(100,
                    stateObj.MaintenanceRestartDueTicks - nowTicks)
                this.ResetSession(path, stateObj, false)
                this.SaveJournal()
                this.Log(this.Text("未发现升级活动（{1}，耗时 {2} 秒），恢复普通重启流程：{3}",
                    this.Text(decisionNote), elapsedSeconds, path))
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
            this.UpdateState(path, stateObj,
                this.Text("🔄 显式升级维护中"),
                GuardStatusKind.MaintenanceUpdating)
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
            this.UpdateState(path, stateObj, this.Text("🔄 软件升级中"),
                GuardStatusKind.MaintenanceUpdating)
            return
        }
        ; 受限权限下目标文件可能暂时不可读，但升级器已经启动了唯一的
        ; 同名新实例。该复核只携带升级会话上下文，必须在 IsReady() 的
        ; 结果阻塞恢复之前执行；普通探活不会进入此分支。
        if !fileReady
            && this.TryCompleteFromRecoveryObservation(path, stateObj)
            return
        if !fileReady {
            stateObj.MaintenanceMode := MaintenancePhase.Updating
            this.UpdateState(path, stateObj, FileExist(path)
                ? this.Text("🔄 等待程序文件可用")
                : this.Text("🔄 等待程序文件恢复"),
                GuardStatusKind.MaintenanceFileWaiting)
            return
        }
        if (quietMs < stableMs) {
            stateObj.MaintenanceMode := MaintenancePhase.Stabilizing
            remaining := Max(1, Ceil((stableMs - quietMs) / 1000))
            this.UpdateState(path, stateObj,
                this.Text("⏳ 确认升级文件稳定 {1}s", remaining),
                GuardStatusKind.MaintenanceStabilizing)
            return
        }
        if !this.HasFreshActorEvidence(stateObj, nowTicks) {
            ; 更新器扫描证据暂不可用时，仍可用升级上下文对目标本身做一次
            ; 受控复核。只有唯一同名候选、创建身份可核对且为升级前同一实例
            ; 或近期启动实例才会通过；普通轮询不会进入这条路径。
            if this.TryCompleteFromRecoveryObservation(path, stateObj)
                return
            this.UpdateState(path, stateObj,
                this.Text("⏳ 等待进程状态..."),
                GuardStatusKind.WaitingObservation)
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
        if !this.TargetSubjectExists(path, stateObj) {
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

    TargetSubjectExists(path, stateObj := "") {
        if this.Callbacks.HasOwnProp("TargetSubjectExists")
            && IsObject(this.Callbacks.TargetSubjectExists) {
            return !!this.Callbacks.TargetSubjectExists.Call(path, stateObj)
        }
        subjectPath := this.Callbacks.GetMaintenanceSubjectPath.Call(path)
        return subjectPath != "" && FileExist(subjectPath)
            && !DirExist(subjectPath)
    }

    CanonicalPath(path) {
        return this.Callbacks.CanonicalPath.Call(path)
    }

    GetFingerprint(path) {
        return this.Callbacks.GetFingerprint.Call(path)
    }

    UpdateState(path, expectedSupervisor, statusText, statusKind := "") {
        path := this.Callbacks.NormalizeTargetPath.Call(path)
        if !(expectedSupervisor is TargetSupervisor)
            || !this.Runtime.appStates.Has(path)
            || this.Runtime.appStates[path] != expectedSupervisor {
            return false
        }
        this.Callbacks.UpdateState.Call(path, statusText,
            expectedSupervisor, 0, false, statusKind)
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
        Critical(previousCritical ? previousCritical : "Off")
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
            this.Log(this.Text("保存升级保护恢复状态失败：{1}",
                this.DiagnosticText(journalError.Message)))
            return false
        } finally {
            finishCritical := A_IsCritical
            Critical("On")
            try isSaving := false
            finally Critical(finishCritical ? finishCritical : "Off")
        }
    }

    Log(message) {
        this.Callbacks.Log.Call(message)
    }

    LogTargetError(path, operationError) {
        errorMessage := IsObject(operationError)
            && operationError.HasOwnProp("Message")
            ? operationError.Message : String(operationError)
        this.Log(this.Text("升级文件监听异常（{1}）：{2}", path,
            this.DiagnosticText(errorMessage)))
    }

    Text(template, values*) {
        if this.Callbacks.HasOwnProp("Localize")
            && IsObject(this.Callbacks.Localize) {
            return this.Callbacks.Localize.Call(template, values*)
        }
        return values.Length ? Format(template, values*) : template
    }

    DiagnosticText(value) {
        if this.Callbacks.HasOwnProp("LocalizeDiagnostic")
            && IsObject(this.Callbacks.LocalizeDiagnostic) {
            return this.Callbacks.LocalizeDiagnostic.Call(value)
        }
        return this.Text(value)
    }

    Now() {
        return DllCall("kernel32\GetTickCount64", "UInt64")
    }
}
