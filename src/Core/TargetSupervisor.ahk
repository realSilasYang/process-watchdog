class TargetScheduledTask {
    __New(kind, generation) {
        this.Kind := kind
        this.Generation := generation
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
        this.State := "初始化..."
        this.FailCount := 0
        this.Pending := false
        this.Enabled := 1
        this.TargetStartTicks := 0
        this.RunAsAdmin := 0
        this.WorkDir := ""
        this.Args := ""
        this.ShortcutArgs := ""
        this.EnvVars := ""
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

        if IsObject(initialValues) {
            for propertyName, propertyValue in initialValues.OwnProps()
                this.%propertyName% := propertyValue
        }
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

    CancelScheduledTasks(invalidateGeneration := true) {
        if this.RestartTask is TargetScheduledTask
            this.RestartTask.Cancel()
        if this.VerifyTask is TargetScheduledTask
            this.VerifyTask.Cancel()
        this.RestartTask := ""
        this.VerifyTask := ""
        if invalidateGeneration
            this.Generation++
    }

    ScheduleRestart(path, restartCallback, delayMs, nowTicks,
        phase := "") {
        this.CancelScheduledTasks()
        this.Pending := true
        this.TargetStartTicks := nowTicks + delayMs
        this.TransitionTo(phase != "" ? phase : GuardPhase.WaitingRestart)
        task := TargetScheduledTask("Restart", this.Generation)
        timerCallback := restartCallback.Bind(path, this, task)
        this.RestartTask := task
        task.Arm(this.Scheduler, timerCallback, nowTicks + delayMs)
        return task
    }

    ScheduleVerification(path, verifyCallback, delayMs) {
        if this.VerifyTask is TargetScheduledTask
            this.VerifyTask.Cancel()
        task := TargetScheduledTask("Verify", this.Generation)
        timerCallback := verifyCallback.Bind(path, this, task)
        this.VerifyTask := task
        task.Arm(this.Scheduler, timerCallback,
            this.Scheduler.Now() + delayMs)
        this.TransitionTo(GuardPhase.Verifying)
        return task
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
