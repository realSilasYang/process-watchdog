; 单个守护目标的运行时所有者。
; 控制器持有当前代际、守护阶段和已计划任务；暂停、删除、改路径或进入升级保护时
; 会先使旧任务槽及快照握手失效，从根源上阻止迟到回调重新启动已经变化的目标。

class TargetScheduledTask {
    __New(kind, generation, path := "", owner := "") {
        this.Kind := kind
        this.Generation := generation
        this.Path := path
        this.Owner := owner
        this.Scheduler := ""
        this.DueTicks := 0
        this.Cancelled := false
        this.Completed := false
    }

    Arm(scheduler, taskCallback, dueTicks) {
        if !(scheduler is WatchdogScheduler)
            throw TypeError("目标任务需要 WatchdogScheduler")
        scheduler.Schedule(this, taskCallback, dueTicks)
    }

    Cancel() {
        if this.Cancelled || this.Completed
            return
        this.Cancelled := true
        if this.Scheduler is WatchdogScheduler
            this.Scheduler.Cancel(this)
    }
}

class TargetSupervisor {
    __New(initialValues := "") {
        ; 核心控制器只保存调用方提供的展示文本；默认值留空，避免纯核心对象
        ; 在英语系统中自行注入中文状态。正式注册路径会传入已本地化的初始状态。
        this.State := ""
        this.StatusKind := ""
        this.FailCount := 0
        this.Pending := false
        this.Enabled := 1
        this.TargetStartTicks := 0
        this.RunAsAdmin := 0
        this.WorkDir := ""
        this.Args := ""
        this.ShortcutArgs := ""
        this.EnvVars := ""
        this.RuntimePath := ""
        this.RuntimeArgs := ""
        this.PID := 0
        this.LastKnownPID := 0
        this.PIDCreationIdentity := ""
        this.PIDImagePath := ""
        this.PIDElevationState := -1
        this.PIDElevationChecked := false
        this.LastKnownPIDCreationIdentity := ""
        this.ResolvedTarget := ""
        this.ShortcutTargetSource := ""
        this.ResolvedTargetManual := false
        this.ShortcutResolveCheckedTicks := 0
        this.VerifyAttempts := 0
        this.UncertainObservationCount := 0
        this.SnapshotWaitPurpose := ""
        this.SnapshotRequestTicks := 0
        this.SnapshotWaitDeadlineTicks := 0
        this.SnapshotNotBeforeTicks := 0
        this.SnapshotWaitGeneration := 0
        this.SnapshotReadyPurpose := ""
        this.SnapshotReadyIndex := ""
        this.SnapshotReadyGeneration := 0
        this.Generation := 1
        this.OneShot := false
        this.MaintenanceConfig := ""
        this.MaintenanceStateMachine := MaintenanceStateMachine()
        this.MaintenanceStartedTicks := 0
        this.MaintenanceStartedAt := ""
        this.MaintenanceLastActivityTicks := 0
        this.MaintenanceRestartDueTicks := 0
        this.MaintenanceBaselineFingerprint := ""
        this.ArbitrationSnapshotRequestTicks := 0
        this.ArbitrationSignalBaselineTicks := 0
        this.MaintenanceFileChanged := false
        this.ExplicitMaintenance := false
        this.MaintenanceWatcherRoot := ""
        this.MaintenanceWatcherPath := ""
        this.KnownActorIdentities := Map()
        this.TransientActorIdentities := Map()
        this.LastActorSeenTicks := 0
        this.MaintenanceActorCheckedTicks := 0
        this.LastFileActivityTicks := 0
        this.MaintenanceFingerprintCheckedTicks := 0
        this.MaintenanceReadyCheckedTicks := 0
        this.MaintenanceLastReady := true
        this.SafetyFingerprint := ""
        this.SafetyStableSince := 0
        this.MaintenanceLearningCandidates := Map()
        this.MissingSinceTicks := 0
        this.DisplayConfig := ""
        this.TargetSpecs := ""
        this.TargetSpecsFingerprint := ""
        this.Scheduler := ""
        this.RestartTask := ""
        this.VerifyTask := ""
        this.IsRestarting := false
        this.ManualRestartRequested := false
        this.StoppedEvidenceTicks := 0

        if IsObject(initialValues) {
            for propertyName, propertyValue in initialValues.OwnProps()
                this.%propertyName% := propertyValue
        }
        if this.StatusKind == ""
            this.StatusKind := this.Enabled ? GuardStatusKind.Initializing
                : GuardStatusKind.Paused
        initialPhase := this.Enabled ? GuardPhase.Initializing
            : GuardPhase.Paused
        this.StateMachine := GuardStateMachine(initialPhase)
    }

    Phase {
        get => this.StateMachine.Phase
    }

    MaintenanceMode {
        get => this.MaintenanceStateMachine.Phase
        set => this.MaintenanceStateMachine.Transition(value)
    }

    TransitionTo(nextPhase) {
        return this.StateMachine.Transition(nextPhase)
    }

    RestoreMaintenanceMode(restoredPhase) {
        return this.MaintenanceStateMachine.Restore(restoredPhase)
    }

    CancelScheduledTasks(invalidateGeneration := true) {
        if this.RestartTask is TargetScheduledTask
            this.RestartTask.Cancel()
        if this.VerifyTask is TargetScheduledTask
            this.VerifyTask.Cancel()
        this.RestartTask := ""
        this.VerifyTask := ""
        this.ClearSnapshotCoordination()
        if invalidateGeneration
            this.Generation++
    }

    ; 用户暂停、恢复，或配置身份发生变化时，上一轮守护尝试留下的倒计时、
    ; 验证次数和不确定证据都已经失去语义。统一从这里清空，避免某条命令路径
    ; 漏掉字段后，让新一轮守护继承旧轮次的失败或 Pending 状态。
    ResetGuardAttemptState() {
        this.Pending := false
        this.TargetStartTicks := 0
        this.FailCount := 0
        this.VerifyAttempts := 0
        this.UncertainObservationCount := 0
        this.IsRestarting := false
        this.ManualRestartRequested := false
        this.StoppedEvidenceTicks := 0
    }

    BeginSnapshotWait(purpose, requestTicks, deadlineTicks,
        notBeforeTicks := 0) {
        this.SnapshotWaitPurpose := purpose
        this.SnapshotRequestTicks := requestTicks
        this.SnapshotWaitDeadlineTicks := deadlineTicks
        this.SnapshotNotBeforeTicks := notBeforeTicks
        this.SnapshotWaitGeneration := this.Generation
        this.SnapshotReadyPurpose := ""
        this.SnapshotReadyIndex := ""
        this.SnapshotReadyGeneration := 0
    }

    IsSnapshotWaitCurrent(purpose := "") {
        return this.SnapshotWaitPurpose != ""
            && (!purpose || this.SnapshotWaitPurpose == purpose)
            && this.SnapshotRequestTicks > 0
            && this.SnapshotWaitGeneration == this.Generation
    }

    StoreSnapshotEvidence(purpose, snapshotIndex) {
        if !IsObject(snapshotIndex) || !snapshotIndex.HasOwnProp("CapturedAtTicks")
            return false
        this.SnapshotReadyPurpose := purpose
        this.SnapshotReadyIndex := snapshotIndex
        this.SnapshotReadyGeneration := this.Generation
        this.SnapshotWaitPurpose := ""
        this.SnapshotRequestTicks := 0
        this.SnapshotWaitDeadlineTicks := 0
        this.SnapshotNotBeforeTicks := 0
        this.SnapshotWaitGeneration := 0
        return true
    }

    TakeSnapshotEvidence(purpose) {
        if (this.SnapshotReadyPurpose != purpose
            || this.SnapshotReadyGeneration != this.Generation
            || !IsObject(this.SnapshotReadyIndex)
            || !this.SnapshotReadyIndex.HasOwnProp("CapturedAtTicks")) {
            return ""
        }
        snapshotIndex := this.SnapshotReadyIndex
        this.SnapshotReadyPurpose := ""
        this.SnapshotReadyIndex := ""
        this.SnapshotReadyGeneration := 0
        return snapshotIndex
    }

    ClearSnapshotCoordination() {
        this.SnapshotWaitPurpose := ""
        this.SnapshotRequestTicks := 0
        this.SnapshotWaitDeadlineTicks := 0
        this.SnapshotNotBeforeTicks := 0
        this.SnapshotWaitGeneration := 0
        this.SnapshotReadyPurpose := ""
        this.SnapshotReadyIndex := ""
        this.SnapshotReadyGeneration := 0
    }

    ScheduleRestart(path, restartCallback, delayMs, nowTicks,
        phase := "") {
        this.CancelScheduledTasks()
        this.Pending := true
        this.TargetStartTicks := nowTicks + delayMs
        this.TransitionTo(phase != "" ? phase : GuardPhase.WaitingRestart)
        task := TargetScheduledTask("Restart", this.Generation, path, this)
        timerCallback := restartCallback.Bind(path, this, task)
        this.RestartTask := task
        try task.Arm(this.Scheduler, timerCallback, nowTicks + delayMs)
        catch {
            this.RecoverFromSchedulingFailure(task, "Restart")
            throw
        }
        return task
    }

    ScheduleVerification(path, verifyCallback, delayMs) {
        if this.VerifyTask is TargetScheduledTask
            this.VerifyTask.Cancel()
        task := TargetScheduledTask("Verify", this.Generation, path, this)
        timerCallback := verifyCallback.Bind(path, this, task)
        this.VerifyTask := task
        try task.Arm(this.Scheduler, timerCallback,
            this.Scheduler.Now() + delayMs)
        catch {
            this.RecoverFromSchedulingFailure(task, "Verify")
            throw
        }
        this.TransitionTo(GuardPhase.Verifying)
        return task
    }

    RecoverFromSchedulingFailure(task, expectedKind) {
        if task is TargetScheduledTask
            task.Cancelled := true
        if (expectedKind == "Restart" && this.RestartTask == task)
            this.RestartTask := ""
        if (expectedKind == "Verify" && this.VerifyTask == task)
            this.VerifyTask := ""
        this.ClearSnapshotCoordination()
        this.Pending := false
        this.TargetStartTicks := 0
        this.TransitionTo(this.Enabled ? GuardPhase.Initializing
            : GuardPhase.Paused)
    }

    IsScheduledTaskCurrent(task, expectedKind) {
        if !(task is TargetScheduledTask) || task.Cancelled || task.Completed
            return false
        if (task.Generation != this.Generation || task.Kind != expectedKind)
            return false
        currentTask := expectedKind == "Restart"
            ? this.RestartTask : this.VerifyTask
        return currentTask is TargetScheduledTask && currentTask == task
    }

    ConsumeScheduledTask(task, expectedKind) {
        if !this.IsScheduledTaskCurrent(task, expectedKind)
            return false
        if (expectedKind == "Restart")
            this.RestartTask := ""
        else
            this.VerifyTask := ""
        task.Completed := true
        return true
    }
}
