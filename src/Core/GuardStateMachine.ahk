class GuardStateMachine {
    static ValidPhases := Map(
        GuardPhase.Initializing, true,
        GuardPhase.Running, true,
        GuardPhase.SuspectedStopped, true,
        GuardPhase.WaitingRestart, true,
        GuardPhase.Starting, true,
        GuardPhase.Verifying, true,
        GuardPhase.Exhausted, true,
        GuardPhase.CoolingDown, true,
        GuardPhase.Paused, true)

    __New(initialPhase := "") {
        this.Phase := ""
        this.Transition(initialPhase != "" ? initialPhase
            : GuardPhase.Initializing)
    }

    Transition(nextPhase) {
        if !GuardStateMachine.ValidPhases.Has(nextPhase)
            throw ValueError("未知守护阶段", -1, nextPhase)
        this.Phase := nextPhase
        return nextPhase
    }

    Is(phase) {
        return this.Phase == phase
    }
}
