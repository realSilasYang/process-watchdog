; 核心守护运行时协调器。
; 它把定时检查、进程探测、重新启动、升级保护和界面状态投影串到每个目标控制器上；
; 所有异步结果都必须验证控制器实例、代际和任务槽，过期回调不能修改新状态。

class GuardRuntime {
    __New(runtime, callbacks) {
        this.Runtime := runtime
        this.Callbacks := callbacks
        this.CachedSnapshotIndex := ""
        this.SnapshotWaitTimeoutMs := 10000
        ; 启动入口可能先创建一个短命中间进程，再异步转交给真正目标。首次稳定性
        ; 检查只取得“已停止”时再复核一次，避免把正常但稍慢的转交误算为启动失败；
        ; 两次检查仍停止则立即回到原有阶梯重试，不无限延长失败判定。
        this.LaunchVerificationDelayMs := 1500
        this.LaunchVerificationRetryDelayMs := 1000
        this.LaunchStoppedEvidenceRequired := 2
        this.TargetErrorLogTicks := Map()
        this.TargetErrorLogTicks.CaseSense := "Off"
        this.Running := false
        this.Stopped := false
        this.MonitorTimer := ObjBindMethod(this, "MonitorTick")
    }

    Start() {
        if this.Running || this.Stopped
            return false
        this.Running := true
        try {
            SetTimer(this.MonitorTimer, this.Runtime.checkInterval)
            if !this.Runtime.maintenanceCoordinator.StartTimers() {
                SetTimer(this.MonitorTimer, 0)
                this.Running := false
                return false
            }
            return true
        } catch {
            try SetTimer(this.MonitorTimer, 0)
            this.Running := false
            throw
        }
    }

    RestartMonitorTimer() {
        try SetTimer(this.MonitorTimer, 0)
        if this.Running && !this.Stopped
            SetTimer(this.MonitorTimer, this.Runtime.checkInterval)
    }

    Shutdown(*) {
        if this.Stopped
            return
        this.Stopped := true
        this.Running := false
        try SetTimer(this.MonitorTimer, 0)
        for _, stateObj in this.Runtime.appStates
            try stateObj.CancelScheduledTasks()
        if this.Runtime.scheduler is WatchdogScheduler
            try this.Runtime.scheduler.Shutdown()
        try this.Runtime.maintenanceCoordinator.Shutdown()
    }

    OnSnapshotPublished(snapshot, snapshotIndex) {
        if this.Stopped || !(snapshotIndex is ProcessSnapshotIndex)
            return false
        nowTicks := this.Now()
        resumed := false
        for path, stateObj in this.Runtime.appStates {
            if !stateObj.Enabled || !stateObj.IsSnapshotWaitCurrent()
                || this.Runtime.maintenanceCoordinator.IsBlocking(stateObj)
                || snapshotIndex.RequestTicks
                    < stateObj.SnapshotRequestTicks
                || nowTicks > stateObj.SnapshotWaitDeadlineTicks {
                continue
            }
            purpose := stateObj.SnapshotWaitPurpose
            notBeforeTicks := stateObj.SnapshotNotBeforeTicks
            stateObj.ClearSnapshotCoordination()
            delayMs := Max(1, notBeforeTicks - nowTicks)
            task := purpose == "Restart"
                ? this.ScheduleRestartFor(path, stateObj, delayMs)
                : this.ScheduleVerificationFor(path, stateObj, delayMs)
            if !(task is TargetScheduledTask)
                continue
            stateObj.StoreSnapshotEvidence(purpose, snapshotIndex)
            stateObj.TargetStartTicks := 0
            resumed := true
        }
        return resumed
    }

    HandleTaskError(taskError, task) {
        taskKind := task is TargetScheduledTask ? task.Kind : "Unknown"
        this.Log(this.Text("后台调度任务异常（{1}）：{2}",
            taskKind, this.DiagnosticText(taskError.Message)))
        if this.Stopped || !(task is TargetScheduledTask)
            return
        stateObj := task.Owner
        path := this.NormalizePath(task.Path)
        if !(stateObj is TargetSupervisor)
            || !this.IsSupervisorCurrent(path, stateObj, task.Generation) {
            return
        }
        ; 回调可能在消费任务槽后才异常。统一作废同代任务和快照证据，
        ; 清除 Pending 后交给下一轮监控重新核对，避免该目标永久失去守护。
        stateObj.CancelScheduledTasks()
        stateObj.Pending := this.Runtime.maintenanceCoordinator
            .IsBlocking(stateObj)
        stateObj.TargetStartTicks := 0
        stateObj.IsRestarting := false
        if !stateObj.Enabled {
            stateObj.TransitionTo(GuardPhase.Paused)
            return
        }
        if !stateObj.Pending {
            stateObj.TransitionTo(GuardPhase.Initializing)
            this.UpdateState(path, stateObj, this.Text("初始化..."),
                GuardStatusKind.Initializing)
        }
    }

    IsSupervisorCurrent(path, expectedSupervisor,
        expectedGeneration := 0) {
        path := this.NormalizePath(path)
        return expectedSupervisor is TargetSupervisor
            && this.Runtime.appStates.Has(path)
            && this.Runtime.appStates[path] == expectedSupervisor
            && (!expectedGeneration
                || expectedSupervisor.Generation == expectedGeneration)
    }

    IsScheduledTaskCurrent(path, expectedSupervisor, task,
        expectedKind) {
        return this.IsSupervisorCurrent(path, expectedSupervisor,
            task is TargetScheduledTask ? task.Generation : -1)
            && expectedSupervisor.IsScheduledTaskCurrent(task, expectedKind)
    }

    ScheduleRestart(path, delayMs, phase := "",
        expectedSupervisor := "") {
        if this.Stopped
            return ""
        previousCritical := A_IsCritical
        Critical("On")
        try {
            path := this.NormalizePath(path)
            if !this.Runtime.appStates.Has(path)
                return ""
            stateObj := this.Runtime.appStates[path]
            if (expectedSupervisor is TargetSupervisor
                && stateObj != expectedSupervisor) {
                return ""
            }
            if !stateObj.Enabled
                return ""
            if this.Runtime.maintenanceCoordinator.IsBlocking(stateObj) {
                stateObj.CancelScheduledTasks()
                stateObj.Pending := true
                stateObj.TargetStartTicks := 0
                return ""
            }
            return stateObj.ScheduleRestart(path,
                ObjBindMethod(this, "Restart"), delayMs, this.Now(), phase)
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
    }

    ScheduleRestartFor(path, expectedSupervisor, delayMs,
        phase := "") {
        return this.ScheduleRestart(path, delayMs, phase,
            expectedSupervisor)
    }

    ScheduleVerification(path, delayMs, expectedSupervisor := "") {
        if this.Stopped
            return ""
        previousCritical := A_IsCritical
        Critical("On")
        try {
            path := this.NormalizePath(path)
            if !this.Runtime.appStates.Has(path)
                return ""
            stateObj := this.Runtime.appStates[path]
            if (expectedSupervisor is TargetSupervisor
                && stateObj != expectedSupervisor) {
                return ""
            }
            if !stateObj.Enabled
                return ""
            if this.Runtime.maintenanceCoordinator.IsBlocking(stateObj) {
                stateObj.CancelScheduledTasks()
                stateObj.Pending := true
                stateObj.TargetStartTicks := 0
                return ""
            }
            return stateObj.ScheduleVerification(path,
                ObjBindMethod(this, "Verify"), delayMs)
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
    }

    ScheduleVerificationFor(path, expectedSupervisor, delayMs) {
        return this.ScheduleVerification(path, delayMs,
            expectedSupervisor)
    }

    MonitorTick() {
        if this.Stopped
            return
        if !this.Runtime.guardWorkGate.TryEnter()
            return
        loopStartedTicks := 0
        try {
            loopStartedTicks := this.Now()
            nowTicks := this.Now()
            orderedPaths := this.Runtime.appOrder.Clone()
            needSnapshot := false
            for path in orderedPaths {
                if !this.Runtime.appStates.Has(path)
                    continue
                stateObj := this.Runtime.appStates[path]
                if !stateObj.Enabled || stateObj.OneShot
                    continue
                this.RecoverOrphanedPending(path, stateObj)
                if (stateObj.Pending
                    && (!this.Runtime.maintenanceCoordinator
                        .IsBlocking(stateObj)
                        || stateObj.MaintenanceMode
                            == MaintenancePhase.TimedOut)) {
                    continue
                }
                try {
                    hasLivePid := this.Callbacks.StateProcessIdentityIsValid
                        .Call(path, stateObj)
                    maintenanceNeedsSnapshot := stateObj.MaintenanceMode
                        == MaintenancePhase.Arbitrating
                        || stateObj.MaintenanceMode
                            == MaintenancePhase.Recovering
                    if (InStr(path, "\") && !hasLivePid
                        && !maintenanceNeedsSnapshot
                        && !this.Callbacks.TargetReferenceExists.Call(path,
                            stateObj)) {
                        continue
                    }
                    if (InStr(path, "\")
                        && (!hasLivePid || maintenanceNeedsSnapshot)) {
                        needSnapshot := true
                        break
                    }
                } catch as targetScanFailure {
                    this.LogTargetMonitorError(path, targetScanFailure)
                }
            }

            if needSnapshot {
                this.CachedSnapshotIndex := this.Runtime.processSnapshots
                    .GetIndex()
                if !(this.CachedSnapshotIndex is ProcessSnapshotIndex)
                    this.CachedSnapshotIndex :=
                        this.BuildNativeFallbackSnapshotIndex(orderedPaths)
                snapshotReady := this.CachedSnapshotIndex
                    is ProcessSnapshotIndex
            } else {
                this.CachedSnapshotIndex := ""
                snapshotReady := true
                this.Runtime.processSnapshots.Pump()
            }
            canValidateWithSnapshot := needSnapshot && snapshotReady

            for path in orderedPaths {
                if !this.Runtime.appStates.Has(path)
                    continue
                stateObj := this.Runtime.appStates[path]
                if !stateObj.Enabled
                    continue

                try {
                if this.Runtime.maintenanceCoordinator.IsBlocking(stateObj) {
                    targetSnapshotReady := canValidateWithSnapshot
                        && (stateObj.MaintenanceMode
                                != MaintenancePhase.Arbitrating
                            || (stateObj.ArbitrationSnapshotRequestTicks
                                && this.Runtime.processSnapshots
                                    .LatestSnapshotRequestTicks
                                    >= stateObj
                                        .ArbitrationSnapshotRequestTicks))
                    if (InStr(path, "\") && targetSnapshotReady) {
                        observationGeneration := stateObj.Generation
                        observation := this.Callbacks.ObserveTarget.Call(path,
                            this.CachedSnapshotIndex)
                        if !this.IsSupervisorCurrent(path, stateObj,
                            observationGeneration)
                            continue
                        if observation.IsRunning() {
                            this.Callbacks.SetProcessIdentity.Call(stateObj,
                                observation.PID,
                                observation.CreationIdentity)
                            if (stateObj.MaintenanceMode
                                == MaintenancePhase.Arbitrating) {
                                this.Runtime.maintenanceCoordinator
                                    .ResetSession(path, stateObj)
                                this.Callbacks.UpdateRunningState.Call(path,
                                    stateObj, observationGeneration)
                            }
                        } else if observation.IsStopped() && stateObj.PID {
                            this.Callbacks.ClearProcessIdentity.Call(stateObj)
                        }
                    }
                    continue
                }

                if stateObj.Pending
                    continue

                if stateObj.OneShot {
                    if (InStr(path, "\")
                        && !this.Callbacks.TargetReferenceExists.Call(path,
                            stateObj)) {
                        stateObj.TransitionTo(GuardPhase.Exhausted)
                        this.UpdateState(path, stateObj,
                            this.Text("❌ 目标不存在"),
                            GuardStatusKind.TargetMissing)
                        stateObj.Pending := false
                        continue
                    }
                    if (stateObj.Phase == GuardPhase.Initializing
                        || stateObj.Phase == GuardPhase.Exhausted) {
                        this.UpdateState(path, stateObj,
                            this.Text("初始化..."),
                            GuardStatusKind.Initializing)
                        stateObj.Pending := true
                        this.RestartCore(path)
                    }
                    continue
                }

                if (InStr(path, "\") && !snapshotReady
                    && !this.Callbacks.StateProcessIdentityIsValid.Call(path,
                        stateObj)) {
                    continue
                }

                SplitPath(path, &targetName, , &extension)
                if (StrLower(extension) == "lnk"
                    && (!stateObj.ResolvedTarget
                        || !FileExist(stateObj.ResolvedTarget))
                    && this.Callbacks.RefreshShortcutIdentity.Call(path,
                        stateObj)) {
                    this.Callbacks.SaveApps.Call()
                }
                if this.Runtime.maintenanceCoordinator.TargetSubjectExists(
                    path, stateObj) {
                    this.Runtime.maintenanceCoordinator.ClearTargetMissing(
                        path, stateObj)
                }
                observationGeneration := stateObj.Generation
                targetObservation := this.Callbacks
                    .StateProcessIdentityIsValid.Call(path, stateObj)
                    ? ProcessObservation.Running(stateObj.PID,
                        stateObj.PIDCreationIdentity, nowTicks,
                        "cached-identity")
                    : this.Callbacks.ObserveTarget.Call(path,
                        this.CachedSnapshotIndex)
                if !this.IsSupervisorCurrent(path, stateObj,
                    observationGeneration)
                    continue
                if targetObservation.IsUnknown()
                    continue
                stateObj.UncertainObservationCount := 0
                isRunning := targetObservation.IsRunning()
                    ? targetObservation.PID : 0
                if isRunning {
                    stateObj.StoppedEvidenceTicks := 0
                    this.Callbacks.SetProcessIdentity.Call(stateObj,
                        isRunning, targetObservation.CreationIdentity)
                } else {
                    this.Callbacks.ClearProcessIdentity.Call(stateObj)
                }

                if (!isRunning && StrLower(extension) == "lnk"
                    && this.Callbacks.RefreshShortcutIdentity.Call(path,
                        stateObj)) {
                    this.Callbacks.SaveApps.Call()
                    observationGeneration := stateObj.Generation
                    targetObservation := this.Callbacks.ObserveTarget.Call(
                        path, this.CachedSnapshotIndex)
                    if !this.IsSupervisorCurrent(path, stateObj,
                        observationGeneration)
                        continue
                    if targetObservation.IsUnknown()
                        continue
                    isRunning := targetObservation.IsRunning()
                        ? targetObservation.PID : 0
                    if isRunning
                        this.Callbacks.SetProcessIdentity.Call(stateObj,
                            isRunning, targetObservation.CreationIdentity)
                }

                isScript := RegExMatch(extension,
                    "i)^(ahk|py|pyw|js|vbs|vbe|wsf|ps1|bat|cmd|rb|pl|php|lua|jar|sh|bash)$")
                missingState := isScript
                    ? this.Text("❌ 脚本不存在")
                    : this.Text("❌ 程序不存在")

                if isRunning {
                    this.Callbacks.SetProcessIdentity.Call(stateObj,
                        isRunning, targetObservation.CreationIdentity)
                    this.Callbacks.UpdateRunningState.Call(path, stateObj,
                        observationGeneration)
                    stateObj.FailCount := 0
                    continue
                }

                if (InStr(path, "\")
                    && !this.Runtime.maintenanceCoordinator
                        .TargetSubjectExists(path, stateObj)) {
                    if (this.Runtime.maintenanceCoordinator
                        .IsProtectionEnabled(path, stateObj)
                        && this.Runtime.maintenanceCoordinator
                            .HasRecentSignal(stateObj)) {
                        this.Runtime.maintenanceCoordinator.Enter(path,
                            stateObj, this.Text("目标文件缺失时检测到升级活动"))
                        continue
                    }
                    this.Runtime.maintenanceCoordinator.MarkTargetMissing(
                        path, stateObj, missingState,
                        isScript ? GuardStatusKind.ScriptMissing
                            : GuardStatusKind.ProgramMissing)
                    continue
                }

                if (stateObj.Phase != GuardPhase.SuspectedStopped) {
                    stateObj.StoppedEvidenceTicks := targetObservation
                        .CapturedAtTicks ? targetObservation.CapturedAtTicks
                        : nowTicks
                    stateObj.TransitionTo(GuardPhase.SuspectedStopped)
                    this.UpdateState(path, stateObj,
                        this.Text("⚠️ 疑似停止"),
                        GuardStatusKind.SuspectedStop)
                } else {
                    stoppedEvidenceTicks := targetObservation.CapturedAtTicks
                        ? targetObservation.CapturedAtTicks : nowTicks
                    if (stateObj.StoppedEvidenceTicks
                        && stoppedEvidenceTicks
                            <= stateObj.StoppedEvidenceTicks) {
                        continue
                    }
                    stateObj.StoppedEvidenceTicks := stoppedEvidenceTicks
                    this.UpdateState(path, stateObj,
                        this.Text("⚠️ 疑似停止"),
                        GuardStatusKind.SuspectedStop)
                    this.Log(this.Text("检测到进程停止，准备重启：{1}（将在 {2} 秒后启动）",
                        targetName,
                        this.Runtime.retryDelayArray[1] / 1000))
                    if !this.Runtime.maintenanceCoordinator.BeginArbitration(
                        path, stateObj) {
                        this.ScheduleRestartFor(path, stateObj,
                            this.Runtime.retryDelayArray[1])
                    }
                }
                } catch as targetMonitorFailure {
                    this.LogTargetMonitorError(path, targetMonitorFailure)
                }
            }
        } catch as monitorError {
            try this.Log(this.Text("主进程监控异常：{1}",
                this.DiagnosticText(monitorError.Message)))
        } finally {
            this.Runtime.guardWorkGate.Leave()
            if loopStartedTicks
                this.Callbacks.LogSlow.Call("主进程监控", loopStartedTicks)
        }
    }

    CanOperationContinue(path, stateObj, generation) {
        return this.IsSupervisorCurrent(path, stateObj, generation)
            && stateObj.Enabled
            && !this.Runtime.maintenanceCoordinator.IsBlocking(stateObj)
    }

    BuildNativeFallbackSnapshotIndex(orderedPaths) {
        if !IsObject(this.Runtime.processInspector)
            return ""
        wantedNames := Map()
        wantedNames.CaseSense := "Off"
        for path in orderedPaths {
            if !this.Runtime.appStates.Has(path)
                continue
            stateObj := this.Runtime.appStates[path]
            if !stateObj.Enabled
                continue
            try fallbackSpecs := this.Callbacks.GetTargetSpecs.Call(path,
                stateObj)
            catch
                continue
            if !IsObject(fallbackSpecs) || !fallbackSpecs.HasOwnProp("Probe")
                || fallbackSpecs.Probe.Kind != TargetProbeKind.ImagePath {
                continue
            }
            SplitPath(fallbackSpecs.Probe.TargetPath, &targetName)
            if targetName != ""
                wantedNames[targetName] := true
        }
        if !wantedNames.Count
            return ""
        try snapshotResult := this.Runtime.processInspector
            .CaptureNativeSnapshot()
        catch
            return ""
        if !IsObject(snapshotResult) || !snapshotResult.HasOwnProp("Ready")
            || !snapshotResult.Ready
            || !snapshotResult.HasOwnProp("Processes")
            || Type(snapshotResult.Processes) != "Array" {
            return ""
        }
        capturedAtTicks := snapshotResult.HasOwnProp("CapturedAtTicks")
            ? snapshotResult.CapturedAtTicks : this.Now()
        fallbackProcesses := []
        for processInfo in snapshotResult.Processes {
            if !IsObject(processInfo) || !processInfo.HasOwnProp("name")
                || !wantedNames.Has(processInfo.name) {
                continue
            }
            copiedProcess := ProcessSnapshotIndex.CopyProcessInfo(processInfo)
            copiedProcess.exe := this.Runtime.processInspector.GetImagePath(
                copiedProcess.pid)
            copiedProcess.identity := this.Runtime.processInspector
                .GetCreationIdentity(copiedProcess.pid)
            copiedProcess.observedTicks := capturedAtTicks
            fallbackProcesses.Push(copiedProcess)
        }
        return ProcessSnapshotIndex(fallbackProcesses, capturedAtTicks,
            false, "", ObjBindMethod(this.Runtime.processInspector,
                "GetCreationIdentity"))
    }

    RecoverOrphanedPending(path, stateObj) {
        if !stateObj.Pending
            return false
        if this.Runtime.maintenanceCoordinator.IsBlocking(stateObj)
            || stateObj.ManualRestartRequested || stateObj.IsRestarting {
            return false
        }
        hasRestartTask := stateObj.RestartTask is TargetScheduledTask
            && stateObj.IsScheduledTaskCurrent(stateObj.RestartTask,
                "Restart")
        hasVerifyTask := stateObj.VerifyTask is TargetScheduledTask
            && stateObj.IsScheduledTaskCurrent(stateObj.VerifyTask,
                "Verify")
        if hasRestartTask || hasVerifyTask
            return false
        stateObj.CancelScheduledTasks()
        stateObj.Pending := false
        stateObj.TargetStartTicks := 0
        stateObj.IsRestarting := false
        if stateObj.Enabled {
            stateObj.TransitionTo(GuardPhase.Initializing)
            this.UpdateState(path, stateObj, this.Text("初始化..."),
                GuardStatusKind.Initializing)
        }
        this.Log(this.Text("主进程监控异常：{1}",
            path " | orphaned-pending"))
        return true
    }

    BeginSnapshotWait(path, stateObj, purpose) {
        expectedGeneration := stateObj.Generation
        if !this.IsSupervisorCurrent(path, stateObj, expectedGeneration)
            || !stateObj.Enabled
            || this.Runtime.maintenanceCoordinator.IsBlocking(stateObj) {
            return false
        }
        stateObj.ClearSnapshotCoordination()
        requestTicks := this.Runtime.processSnapshots.RequestFresh()
        if !this.IsSupervisorCurrent(path, stateObj, expectedGeneration)
            || !stateObj.Enabled
            || this.Runtime.maintenanceCoordinator.IsBlocking(stateObj)
            || !requestTicks {
            return false
        }
        deadlineTicks := this.Now() + this.SnapshotWaitTimeoutMs
        task := purpose == "Restart"
            ? this.ScheduleRestartFor(path, stateObj,
                this.SnapshotWaitTimeoutMs)
            : this.ScheduleVerificationFor(path, stateObj,
                this.SnapshotWaitTimeoutMs)
        if !(task is TargetScheduledTask)
            return false
        stateObj.BeginSnapshotWait(purpose, requestTicks, deadlineTicks)
        stateObj.TargetStartTicks := 0
        stateObj.UncertainObservationCount := Min(
            stateObj.UncertainObservationCount + 1, 2)
        this.UpdateState(path, stateObj,
            this.Text("⏳ 等待进程状态..."),
            GuardStatusKind.WaitingObservation)
        if stateObj.UncertainObservationCount == 1 {
            this.Log(this.Text("暂时无法核对现有进程，延迟启动以避免重复实例：{1}",
                path))
        }
        return true
    }

    HandleUncertainObservation(path, stateObj, observation) {
        if !this.IsSupervisorCurrent(path, stateObj, stateObj.Generation)
            return false
        stateObj.ClearSnapshotCoordination()
        stateObj.UncertainObservationCount := Min(
            stateObj.UncertainObservationCount + 1, 2)
        stateObj.Pending := false
        stateObj.TargetStartTicks := 0
        this.UpdateState(path, stateObj,
            this.Text("⏳ 等待进程状态..."),
            GuardStatusKind.WaitingObservation)
        if stateObj.UncertainObservationCount == 1 {
            this.Log(this.Text("暂时无法核对现有进程，延迟启动以避免重复实例：{1}",
                path))
        }
        return false
    }

    ScheduleRestartPreservingSnapshot(path, stateObj, delayMs) {
        snapshotIndex := stateObj.TakeSnapshotEvidence("Restart")
        wasWaiting := stateObj.IsSnapshotWaitCurrent("Restart")
        if wasWaiting {
            requestTicks := stateObj.SnapshotRequestTicks
            deadlineTicks := stateObj.SnapshotWaitDeadlineTicks
            notBeforeTicks := stateObj.SnapshotNotBeforeTicks
        }
        task := this.ScheduleRestartFor(path, stateObj, delayMs)
        if !(task is TargetScheduledTask)
            return ""
        if snapshotIndex is ProcessSnapshotIndex
            stateObj.StoreSnapshotEvidence("Restart", snapshotIndex)
        else if wasWaiting
            stateObj.BeginSnapshotWait("Restart", requestTicks,
                deadlineTicks, notBeforeTicks)
        if (snapshotIndex is ProcessSnapshotIndex || wasWaiting)
            stateObj.TargetStartTicks := 0
        return task
    }

    Restart(path, expectedSupervisor := "", scheduledTask := "") {
        if this.Stopped
            return
        path := this.NormalizePath(path)
        if !this.Runtime.guardWorkGate.TryEnter() {
            if (scheduledTask is TargetScheduledTask
                && !this.IsScheduledTaskCurrent(path, expectedSupervisor,
                    scheduledTask, "Restart"))
                return
            if expectedSupervisor is TargetSupervisor
                this.ScheduleRestartPreservingSnapshot(path,
                    expectedSupervisor, 100)
            else
                this.ScheduleRestart(path, 100)
            return
        }
        try this.RestartCore(path, expectedSupervisor, scheduledTask)
        finally this.Runtime.guardWorkGate.Leave()
    }

    RestartCore(path, expectedSupervisor := "", scheduledTask := "") {
        path := this.NormalizePath(path)
        if scheduledTask is TargetScheduledTask {
            if !this.IsScheduledTaskCurrent(path, expectedSupervisor,
                scheduledTask, "Restart")
                return
            stateObj := expectedSupervisor
            if !stateObj.ConsumeScheduledTask(scheduledTask, "Restart")
                return
        } else {
            if !this.Runtime.appStates.Has(path)
                return
            stateObj := this.Runtime.appStates[path]
            stateObj.CancelScheduledTasks()
        }
        operationGeneration := stateObj.Generation
        if stateObj.IsRestarting {
            this.ScheduleRestartPreservingSnapshot(path, stateObj, 1000)
            return
        }
        snapshotIndex := stateObj.TakeSnapshotEvidence("Restart")
        if !(snapshotIndex is ProcessSnapshotIndex)
            && stateObj.IsSnapshotWaitCurrent("Restart") {
            if this.Now() < stateObj.SnapshotWaitDeadlineTicks {
                remainingMs := Max(1, stateObj.SnapshotWaitDeadlineTicks
                    - this.Now())
                requestTicks := stateObj.SnapshotRequestTicks
                deadlineTicks := stateObj.SnapshotWaitDeadlineTicks
                notBeforeTicks := stateObj.SnapshotNotBeforeTicks
                retryTask := this.ScheduleRestartFor(path, stateObj,
                    remainingMs)
                if retryTask is TargetScheduledTask {
                    stateObj.BeginSnapshotWait("Restart", requestTicks,
                        deadlineTicks, notBeforeTicks)
                    stateObj.TargetStartTicks := 0
                }
                return
            }
            stateObj.ClearSnapshotCoordination()
            this.HandleUncertainObservation(path, stateObj,
                ProcessObservation.Unknown(this.Now(), "process-command",
                    "等待后台进程快照超时",
                    ProcessObservationReason.SnapshotUnavailable))
            return
        }
        if !stateObj.Enabled {
            stateObj.Pending := false
            stateObj.TargetStartTicks := 0
            return
        }

        if InStr(path, "\") {
            SplitPath(path, , , &restartExtension)
            if (StrLower(restartExtension) == "lnk"
                && this.Callbacks.RefreshShortcutIdentity.Call(path,
                    stateObj, true)) {
                this.Callbacks.SaveApps.Call()
            }
            existingObservation := this.Callbacks.ObserveTarget.Call(path,
                snapshotIndex, snapshotIndex is ProcessSnapshotIndex
                    ? 0 : 1000)
            if !this.IsSupervisorCurrent(path, stateObj,
                operationGeneration)
                return
            if existingObservation.IsRunning() {
                stateObj.StoppedEvidenceTicks := 0
                this.Callbacks.SetProcessIdentity.Call(stateObj,
                    existingObservation.PID,
                    existingObservation.CreationIdentity)
                this.Log(this.Text("进程仍在运行，忽略重复启动：{1}", path))
                stateObj.Pending := false
                stateObj.TargetStartTicks := 0
                this.Callbacks.UpdateRunningState.Call(path, stateObj,
                    operationGeneration)
                return
            }
            if existingObservation.IsUnknown() {
                if existingObservation.NeedsFreshSnapshot()
                    && !(snapshotIndex is ProcessSnapshotIndex) {
                    if this.BeginSnapshotWait(path, stateObj, "Restart")
                        return
                    if !this.CanOperationContinue(path, stateObj,
                        operationGeneration)
                        return
                }
                this.HandleUncertainObservation(path, stateObj,
                    existingObservation)
                return
            }
            stateObj.UncertainObservationCount := 0
            this.Callbacks.ClearProcessIdentity.Call(stateObj)
        } else if this.Callbacks.StateProcessIdentityIsValid.Call(path,
            stateObj) {
            this.Log(this.Text("进程仍在运行，忽略重复启动：{1}", path))
            stateObj.Pending := false
            stateObj.TargetStartTicks := 0
            this.Callbacks.UpdateRunningState.Call(path, stateObj,
                operationGeneration)
            return
        }
        if this.Runtime.maintenanceCoordinator.IsBlocking(stateObj) {
            stateObj.Pending := true
            stateObj.TargetStartTicks := 0
            return
        }

        targetPlan := this.Callbacks.GetTargetSpecs.Call(path, stateObj,
            true)
        launchPlan := targetPlan.Launch
        if !launchPlan.Available {
            stateObj.Pending := false
            stateObj.TargetStartTicks := 0
            this.UpdateState(path, stateObj, this.Text("❌ 程序不存在"),
                GuardStatusKind.ProgramMissing)
            this.Log(this.Text("启动前没有可用的启动目标，已停止重试：{1}{2}", path,
                launchPlan.UnavailableReason != ""
                    ? this.Text("（{1}）",
                        this.DiagnosticText(
                            launchPlan.UnavailableReason)) : ""))
            return
        }
        safeReason := ""
        if !this.Runtime.maintenanceCoordinator.CanSafelyLaunch(path,
            stateObj, &safeReason) {
            stateObj.Pending := this.Runtime.maintenanceCoordinator
                .IsBlocking(stateObj)
            stateObj.TargetStartTicks := 0
            if !this.Runtime.maintenanceCoordinator.IsBlocking(stateObj)
                this.UpdateState(path, stateObj,
                    this.Text("⏳ 等待安全启动条件"),
                    GuardStatusKind.SafeStartWait)
            this.Log(this.Text("安全启动门暂缓启动：{1}（{2}）",
                path, this.DiagnosticText(safeReason)))
            return
        }

        if !this.CanOperationContinue(path, stateObj,
            operationGeneration)
            return
        stateObj.IsRestarting := true
        stateObj.TransitionTo(GuardPhase.Starting)
        stateObj.TargetStartTicks := 0
        stateObj.VerifyAttempts := 0
        this.UpdateState(path, stateObj, this.Text("🚀 正在启动..."),
            GuardStatusKind.Starting)
        SplitPath(path, &targetName)
        maxAttempts := this.Runtime.retryDelayArray.Length

        try {
            if !this.CanOperationContinue(path, stateObj,
                operationGeneration)
                return
            outputLogPath := launchPlan.Kind == TargetLaunchKind.Batch
                ? this.Callbacks.GetLogFilePath.Call(path) : ""
            launchResult := this.Runtime.targetLauncher.Launch(launchPlan,
                A_AhkPath, A_IsCompiled, outputLogPath)
            newPid := launchResult.PID
            isAdmin := launchPlan.RunAsAdmin
            if outputLogPath != ""
                this.Log(this.Text("已启动批处理并重定向输出到：{1}",
                    outputLogPath))

            if !this.CanOperationContinue(path, stateObj,
                operationGeneration) {
                stateObj.Pending := false
                stateObj.TargetStartTicks := 0
                return
            }

            if targetPlan.IsOneShot {
                this.Callbacks.ClearProcessIdentity.Call(stateObj, false)
                stateObj.Pending := false
                stateObj.FailCount := 0
                stateObj.TransitionTo(GuardPhase.Running)
                this.UpdateState(path, stateObj,
                    this.Text("✅ 已启动（非驻留目标）"),
                    GuardStatusKind.Running)
                this.Log(this.Text("已启动非驻留目标：{1}",
                    targetName ? targetName : path))
                return
            }

            ; Run 返回的 PID 可能属于启动器、文件关联宿主或 UAC 中间进程。
            ; 它只用于诊断，绝不在目标探测确认前写入受信进程身份。
            verificationNeedsCommandLine := targetPlan.Probe.Kind
                == TargetProbeKind.CommandTarget
            verificationRequestTicks := verificationNeedsCommandLine
                ? this.Runtime.processSnapshots.RequestFresh() : 0
            this.Log(this.Text("已发送启动指令：{1}{2}",
                targetName ? targetName : path,
                isAdmin ? this.Text("（管理员权限）") : ""))
            this.UpdateState(path, stateObj,
                this.Text("⏳ 验证运行状态..."),
                GuardStatusKind.Verifying)
            verificationDelayMs := this.LaunchVerificationDelayMs
            verificationDueTicks := this.Now() + verificationDelayMs
            verificationTask := this.ScheduleVerificationFor(path, stateObj,
                verificationDelayMs)
            if verificationRequestTicks
                && verificationTask is TargetScheduledTask {
                stateObj.BeginSnapshotWait("Verify", verificationRequestTicks,
                    this.Now() + this.SnapshotWaitTimeoutMs,
                    verificationDueTicks)
            }
        } catch as restartError {
            this.ProcessRestartFailure(path, targetName, maxAttempts,
                restartError.Message, stateObj, operationGeneration)
        } finally {
            stateObj.IsRestarting := false
        }
    }

    ProcessRestartFailure(path, targetName, maxAttempts, errorMessage,
        expectedSupervisor, expectedGeneration) {
        if !this.IsSupervisorCurrent(path, expectedSupervisor,
            expectedGeneration)
            return
        stateObj := expectedSupervisor
        if this.Runtime.maintenanceCoordinator.IsBlocking(stateObj)
            return
        stateObj.FailCount := Min(stateObj.FailCount + 1, maxAttempts)
        this.Log(this.Text("启动失败 [{1}/{2}]：{3} - {4}",
            stateObj.FailCount, maxAttempts, targetName ? targetName : path,
            this.DiagnosticText(errorMessage)))

        retryAction := RestartPolicy.NextAfterFailure(stateObj.FailCount,
            this.Runtime.retryDelayArray)
        if !retryAction.CoolingDown {
            this.ScheduleRestartFor(path, stateObj, retryAction.DelayMs)
            this.Log(this.Text("等待 {1} 秒后进行第 {2} 次尝试...",
                retryAction.DelayMs / 1000, retryAction.Attempt))
        } else {
            this.ScheduleRestartFor(path, stateObj, retryAction.DelayMs,
                GuardPhase.CoolingDown)
            this.UpdateState(path, stateObj,
                this.Text("⏳ 启动失败，稍后自动重试"),
                GuardStatusKind.LaunchRetry)
            this.Log(this.Text("已用完快速重试，将每隔 {1} 秒继续尝试启动：{2}",
                retryAction.DelayMs / 1000, targetName))
        }
    }

    Verify(path, expectedSupervisor := "", scheduledTask := "") {
        if this.Stopped
            return
        path := this.NormalizePath(path)
        if !this.Runtime.guardWorkGate.TryEnter() {
            if (scheduledTask is TargetScheduledTask
                && !this.IsScheduledTaskCurrent(path, expectedSupervisor,
                    scheduledTask, "Verify"))
                return
            this.ScheduleVerificationFor(path, expectedSupervisor, 100)
            return
        }
        try this.VerifyCore(path, expectedSupervisor, scheduledTask)
        finally this.Runtime.guardWorkGate.Leave()
    }

    VerifyCore(path, expectedSupervisor := "", scheduledTask := "") {
        path := this.NormalizePath(path)
        if scheduledTask is TargetScheduledTask {
            if !this.IsScheduledTaskCurrent(path, expectedSupervisor,
                scheduledTask, "Verify")
                return
            stateObj := expectedSupervisor
            if !stateObj.ConsumeScheduledTask(scheduledTask, "Verify")
                return
        } else {
            if !this.Runtime.appStates.Has(path)
                return
            stateObj := this.Runtime.appStates[path]
        }
        operationGeneration := stateObj.Generation
        snapshotIndex := stateObj.TakeSnapshotEvidence("Verify")
        if !stateObj.Enabled
            return
        if this.Runtime.maintenanceCoordinator.IsBlocking(stateObj) {
            stateObj.ClearSnapshotCoordination()
            stateObj.Pending := true
            stateObj.TargetStartTicks := 0
            return
        }
        hasLiveIdentity := this.Callbacks.StateProcessIdentityIsValid.Call(
            path, stateObj)
        if hasLiveIdentity
            stateObj.ClearSnapshotCoordination()
        else if !(snapshotIndex is ProcessSnapshotIndex)
            && stateObj.IsSnapshotWaitCurrent("Verify") {
            if this.Now() < stateObj.SnapshotWaitDeadlineTicks {
                remainingMs := Max(1, stateObj.SnapshotWaitDeadlineTicks
                    - this.Now())
                this.ScheduleVerificationFor(path, stateObj, remainingMs)
                stateObj.TargetStartTicks := 0
                return
            }
            stateObj.ClearSnapshotCoordination()
            this.HandleUncertainObservation(path, stateObj,
                ProcessObservation.Unknown(this.Now(), "process-command",
                    "等待后台进程快照超时",
                    ProcessObservationReason.SnapshotUnavailable))
            return
        }

        SplitPath(path, &targetName)
        verificationObservation := hasLiveIdentity
            ? ProcessObservation.Running(stateObj.PID,
                stateObj.PIDCreationIdentity, this.Now(), "cached-identity")
            : this.Callbacks.ObserveTarget.Call(path, snapshotIndex)
        if !this.IsSupervisorCurrent(path, stateObj, operationGeneration)
            return
        if verificationObservation.IsRunning() {
            stateObj.StoppedEvidenceTicks := 0
            stateObj.ClearSnapshotCoordination()
            stateObj.UncertainObservationCount := 0
            this.Callbacks.SetProcessIdentity.Call(stateObj,
                verificationObservation.PID,
                verificationObservation.CreationIdentity)
            this.Callbacks.UpdateRunningState.Call(path, stateObj,
                operationGeneration)
            stateObj.FailCount := 0
            stateObj.VerifyAttempts := 0
            stateObj.Pending := false
            this.Log(this.Text("启动成功且运行稳定：{1}",
                targetName ? targetName : path))
        } else if verificationObservation.IsUnknown() {
            if verificationObservation.NeedsFreshSnapshot()
                && !(snapshotIndex is ProcessSnapshotIndex) {
                if this.BeginSnapshotWait(path, stateObj, "Verify")
                    return
                if !this.CanOperationContinue(path, stateObj,
                    operationGeneration)
                    return
            }
            this.HandleUncertainObservation(path, stateObj,
                verificationObservation)
        } else {
            stateObj.ClearSnapshotCoordination()
            stateObj.UncertainObservationCount := 0
            stateObj.VerifyAttempts++
            if stateObj.VerifyAttempts < this.LaunchStoppedEvidenceRequired {
                retryDelayMs := this.LaunchVerificationRetryDelayMs
                retryDueTicks := this.Now() + retryDelayMs
                retryTask := this.ScheduleVerificationFor(path, stateObj,
                    retryDelayMs)
                if retryTask is TargetScheduledTask {
                    ; 命令型与工作目录型目标依赖完整进程快照。只有首次复核确有需要
                    ; 时才请求一次新快照；原生 EXE 继续使用轻量的即时系统快照。
                    targetPlan := this.Callbacks.GetTargetSpecs.Call(path,
                        stateObj, false)
                    probeKind := targetPlan.Probe.Kind
                    if (probeKind == TargetProbeKind.CommandTarget
                        || probeKind == TargetProbeKind.WorkingDirectory) {
                        requestTicks := this.Runtime.processSnapshots
                            .RequestFresh()
                        if requestTicks {
                            stateObj.BeginSnapshotWait("Verify", requestTicks,
                                this.Now() + this.SnapshotWaitTimeoutMs,
                                retryDueTicks)
                        }
                    }
                    stateObj.Pending := true
                    stateObj.TargetStartTicks := 0
                    this.UpdateState(path, stateObj,
                        this.Text("⏳ 验证运行状态..."),
                        GuardStatusKind.Verifying)
                    return
                }
            }
            this.ProcessRestartFailure(path, targetName,
                this.Runtime.retryDelayArray.Length,
                this.Text("进程启动后迅速退出或未成功常驻后台"), stateObj,
                operationGeneration)
        }
    }

    NormalizePath(path) {
        return this.Callbacks.NormalizeTargetPath.Call(path)
    }

    UpdateState(path, expectedSupervisor, statusText, statusKind := "") {
        expectedGeneration := expectedSupervisor is TargetSupervisor
            ? expectedSupervisor.Generation : 0
        if !this.IsSupervisorCurrent(path, expectedSupervisor,
            expectedGeneration) || !expectedSupervisor.Enabled
            return false
        this.Callbacks.UpdateState.Call(path, statusText,
            expectedSupervisor, expectedGeneration, false, statusKind)
        return true
    }

    Log(message) {
        this.Callbacks.Log.Call(message)
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

    LogTargetMonitorError(path, targetError) {
        nowTicks := this.Now()
        if (this.TargetErrorLogTicks.Has(path)
            && nowTicks - this.TargetErrorLogTicks[path] < 30000) {
            return false
        }
        this.TargetErrorLogTicks[path] := nowTicks
        errorMessage := IsObject(targetError)
            && targetError.HasOwnProp("Message")
            ? targetError.Message : String(targetError)
        this.Log(this.Text("主进程监控异常：{1}",
            path " | " this.DiagnosticText(errorMessage)))
        return true
    }

    Now() {
        if this.Runtime.scheduler is WatchdogScheduler
            return this.Runtime.scheduler.Now()
        return DllCall("kernel32\GetTickCount64", "UInt64")
    }
}
