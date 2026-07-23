class GuardRuntime {
    __New(runtime, callbacks) {
        this.Runtime := runtime
        this.Callbacks := callbacks
        this.CachedSnapshotIndex := ""
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

    HandleTaskError(taskError, task) {
        taskKind := task is TargetScheduledTask ? task.Kind : "Unknown"
        this.Log("后台调度任务异常（" taskKind "）：" taskError.Message)
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
                if (stateObj.Pending
                    && (!this.Runtime.maintenanceCoordinator
                        .IsBlocking(stateObj)
                        || stateObj.MaintenanceMode
                            == MaintenancePhase.TimedOut)) {
                    continue
                }
                hasLivePid := this.Callbacks.StateProcessIdentityIsValid
                    .Call(path, stateObj)
                maintenanceNeedsSnapshot := stateObj.MaintenanceMode
                    == MaintenancePhase.Arbitrating
                    || stateObj.MaintenanceMode == MaintenancePhase.Recovering
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
            }

            if needSnapshot {
                this.CachedSnapshotIndex := this.Runtime.processSnapshots
                    .GetIndex()
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

                if this.Runtime.maintenanceCoordinator.IsBlocking(stateObj) {
                    targetSnapshotReady := canValidateWithSnapshot
                        && (stateObj.MaintenanceMode
                                != MaintenancePhase.Arbitrating
                            || (stateObj.ArbitrationSnapshotRequestTicks
                                && this.Runtime.processSnapshots
                                    .LatestSnapshotTicks
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
                                observation.PID)
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
                        this.UpdateState(path, stateObj, "❌ 目标不存在")
                        stateObj.Pending := false
                        continue
                    }
                    if (stateObj.Phase == GuardPhase.Initializing
                        || stateObj.Phase == GuardPhase.Exhausted) {
                        this.UpdateState(path, stateObj, "初始化...")
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
                if this.Callbacks.TargetReferenceExists.Call(path,
                    stateObj) {
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
                isRunning := targetObservation.IsRunning()
                    ? targetObservation.PID : 0
                if isRunning {
                    this.Callbacks.SetProcessIdentity.Call(stateObj,
                        isRunning)
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
                            isRunning)
                }

                isScript := RegExMatch(extension,
                    "i)^(ahk|py|pyw|js|vbs|vbe|wsf|ps1|bat|cmd|rb|pl|php|lua|jar|sh|bash)$")
                missingState := isScript
                    ? "❌ 脚本不存在" : "❌ 程序不存在"

                if isRunning {
                    this.Callbacks.SetProcessIdentity.Call(stateObj,
                        isRunning)
                    this.Callbacks.UpdateRunningState.Call(path, stateObj,
                        observationGeneration)
                    stateObj.FailCount := 0
                    continue
                }

                if (InStr(path, "\")
                    && !this.Callbacks.TargetReferenceExists.Call(path,
                        stateObj)) {
                    if (this.Runtime.maintenanceCoordinator
                        .IsProtectionEnabled(path, stateObj)
                        && this.Runtime.maintenanceCoordinator
                            .HasRecentSignal(stateObj)) {
                        this.Runtime.maintenanceCoordinator.Enter(path,
                            stateObj, "目标文件缺失时检测到升级活动")
                        continue
                    }
                    this.Runtime.maintenanceCoordinator.MarkTargetMissing(
                        path, stateObj, missingState)
                    continue
                }

                if (stateObj.Phase != GuardPhase.SuspectedStopped) {
                    stateObj.TransitionTo(GuardPhase.SuspectedStopped)
                    this.UpdateState(path, stateObj, "⚠️ 疑似停止")
                } else {
                    this.UpdateState(path, stateObj, "⚠️ 疑似停止")
                    this.Log("检测到进程停止，准备重启: " targetName
                        "（将在 " (this.Runtime.retryDelayArray[1] / 1000)
                        " 秒后启动）")
                    if !this.Runtime.maintenanceCoordinator.BeginArbitration(
                        path, stateObj) {
                        this.ScheduleRestartFor(path, stateObj,
                            this.Runtime.retryDelayArray[1])
                    }
                }
            }
        } catch as monitorError {
            try this.Log("主进程监控异常: " monitorError.Message)
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

    Restart(path, expectedSupervisor := "", scheduledTask := "") {
        if this.Stopped
            return
        path := this.NormalizePath(path)
        if !this.Runtime.guardWorkGate.TryEnter() {
            if (scheduledTask is TargetScheduledTask
                && !this.IsScheduledTaskCurrent(path, expectedSupervisor,
                    scheduledTask, "Restart"))
                return
            this.ScheduleRestartFor(path, expectedSupervisor, 100)
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
            this.ScheduleRestartFor(path, stateObj, 1000)
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
                "", 1000)
            if !this.IsSupervisorCurrent(path, stateObj,
                operationGeneration)
                return
            if existingObservation.IsRunning() {
                this.Callbacks.SetProcessIdentity.Call(stateObj,
                    existingObservation.PID)
                this.Log("进程仍在运行，忽略重复启动: " path)
                stateObj.Pending := false
                stateObj.TargetStartTicks := 0
                this.Callbacks.UpdateRunningState.Call(path, stateObj,
                    operationGeneration)
                return
            }
            if existingObservation.IsUnknown() {
                stateObj.Pending := true
                this.UpdateState(path, stateObj, "⏳ 等待进程状态...")
                this.Log("暂时无法核对现有进程，延迟启动以避免重复实例: " path)
                this.ScheduleRestartFor(path, stateObj, 2000)
                return
            }
            this.Callbacks.ClearProcessIdentity.Call(stateObj)
        } else if this.Callbacks.StateProcessIdentityIsValid.Call(path,
            stateObj) {
            this.Log("进程仍在运行，忽略重复启动: " path)
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
            this.UpdateState(path, stateObj, "❌ 程序不存在")
            this.Log("启动前没有可用的启动目标，已停止重试: " path
                . (launchPlan.UnavailableReason != ""
                    ? "（" launchPlan.UnavailableReason "）" : ""))
            return
        }
        safeReason := ""
        if !this.Runtime.maintenanceCoordinator.CanSafelyLaunch(path,
            stateObj, &safeReason) {
            stateObj.Pending := this.Runtime.maintenanceCoordinator
                .IsBlocking(stateObj)
            stateObj.TargetStartTicks := 0
            if !this.Runtime.maintenanceCoordinator.IsBlocking(stateObj)
                this.UpdateState(path, stateObj, "⏳ 等待安全启动条件")
            this.Log("安全启动门暂缓启动: " path "（" safeReason "）")
            return
        }

        if !this.CanOperationContinue(path, stateObj,
            operationGeneration)
            return
        stateObj.IsRestarting := true
        stateObj.TransitionTo(GuardPhase.Starting)
        stateObj.TargetStartTicks := 0
        stateObj.VerifyAttempts := 0
        this.UpdateState(path, stateObj, "🚀 正在启动...")
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
                this.Log("已启动批处理并劫持输出到: " outputLogPath)

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
                this.UpdateState(path, stateObj, "✅ 已启动（非驻留目标）")
                this.Log("已启动非驻留目标: "
                    (targetName ? targetName : path))
                return
            }

            if (newPid && !launchPlan.UsesShortcutEntry)
                this.Callbacks.SetProcessIdentity.Call(stateObj, newPid)
            this.Runtime.processSnapshots.RequestFresh()
            this.Log("已发送启动指令: "
                (targetName ? targetName : path)
                (isAdmin ? "（管理员权限）" : ""))
            this.UpdateState(path, stateObj, "⏳ 验证运行状态...")
            this.ScheduleVerificationFor(path, stateObj, 1500)
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
        this.Log("启动失败 [" stateObj.FailCount "/" maxAttempts "]: "
            (targetName ? targetName : path) " - " errorMessage)

        retryAction := RestartPolicy.NextAfterFailure(stateObj.FailCount,
            this.Runtime.retryDelayArray)
        if !retryAction.CoolingDown {
            this.ScheduleRestartFor(path, stateObj, retryAction.DelayMs)
            this.Log("等待 " (retryAction.DelayMs / 1000)
                " 秒后进行第 " retryAction.Attempt " 次尝试...")
        } else {
            this.ScheduleRestartFor(path, stateObj, retryAction.DelayMs,
                GuardPhase.CoolingDown)
            this.UpdateState(path, stateObj, "⏳ 启动失败，稍后自动重试")
            this.Log("已用完快速重试，将每隔 "
                (retryAction.DelayMs / 1000) " 秒继续尝试启动: " targetName)
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
        if !stateObj.Enabled
            return
        if this.Runtime.maintenanceCoordinator.IsBlocking(stateObj) {
            stateObj.Pending := true
            stateObj.TargetStartTicks := 0
            return
        }

        SplitPath(path, &targetName)
        verificationObservation := this.Callbacks
            .StateProcessIdentityIsValid.Call(path, stateObj)
            ? ProcessObservation.Running(stateObj.PID,
                stateObj.PIDCreationIdentity, this.Now(), "cached-identity")
            : this.Callbacks.ObserveTarget.Call(path)
        if !this.IsSupervisorCurrent(path, stateObj, operationGeneration)
            return
        if verificationObservation.IsRunning() {
            this.Callbacks.SetProcessIdentity.Call(stateObj,
                verificationObservation.PID)
            this.Callbacks.UpdateRunningState.Call(path, stateObj,
                operationGeneration)
            stateObj.FailCount := 0
            stateObj.Pending := false
            this.Log("启动成功且运行稳定: "
                (targetName ? targetName : path))
        } else if verificationObservation.IsUnknown() {
            stateObj.Pending := true
            this.UpdateState(path, stateObj, "⏳ 等待进程状态...")
            this.ScheduleVerificationFor(path, stateObj, 2000)
        } else {
            this.ProcessRestartFailure(path, targetName,
                this.Runtime.retryDelayArray.Length,
                "进程启动后迅速退出或未成功常驻后台", stateObj,
                operationGeneration)
        }
    }

    NormalizePath(path) {
        return this.Callbacks.NormalizeTargetPath.Call(path)
    }

    UpdateState(path, expectedSupervisor, statusText) {
        expectedGeneration := expectedSupervisor is TargetSupervisor
            ? expectedSupervisor.Generation : 0
        if !this.IsSupervisorCurrent(path, expectedSupervisor,
            expectedGeneration) || !expectedSupervisor.Enabled
            return false
        this.Callbacks.UpdateState.Call(path, statusText,
            expectedSupervisor, expectedGeneration)
        return true
    }

    Log(message) {
        this.Callbacks.Log.Call(message)
    }

    Now() {
        if this.Runtime.scheduler is WatchdogScheduler
            return this.Runtime.scheduler.Now()
        return DllCall("kernel32\GetTickCount64", "UInt64")
    }
}
