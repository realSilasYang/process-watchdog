class MaintenancePhase {
    static Normal := "Normal"
    static Arbitrating := "Arbitrating"
    static Updating := "Updating"
    static Stabilizing := "Stabilizing"
    static Recovering := "Recovering"
    static TimedOut := "TimedOut"
}

class MaintenanceStateMachine {
    static AllowedTransitions := Map(
        MaintenancePhase.Normal, Map(
            MaintenancePhase.Normal, true,
            MaintenancePhase.Arbitrating, true,
            MaintenancePhase.Updating, true,
            MaintenancePhase.Stabilizing, true,
            MaintenancePhase.Recovering, true),
        MaintenancePhase.Arbitrating, Map(
            MaintenancePhase.Arbitrating, true,
            MaintenancePhase.Updating, true,
            MaintenancePhase.Normal, true,
            MaintenancePhase.TimedOut, true),
        MaintenancePhase.Updating, Map(
            MaintenancePhase.Updating, true,
            MaintenancePhase.Stabilizing, true,
            MaintenancePhase.Normal, true,
            MaintenancePhase.TimedOut, true),
        MaintenancePhase.Stabilizing, Map(
            MaintenancePhase.Stabilizing, true,
            MaintenancePhase.Updating, true,
            MaintenancePhase.Normal, true,
            MaintenancePhase.TimedOut, true),
        MaintenancePhase.Recovering, Map(
            MaintenancePhase.Recovering, true,
            MaintenancePhase.Updating, true,
            MaintenancePhase.Stabilizing, true,
            MaintenancePhase.Normal, true,
            MaintenancePhase.TimedOut, true),
        MaintenancePhase.TimedOut, Map(
            MaintenancePhase.TimedOut, true,
            MaintenancePhase.Normal, true))

    __New(initialPhase := "") {
        if initialPhase == ""
            initialPhase := MaintenancePhase.Normal
        if !MaintenanceStateMachine.AllowedTransitions.Has(initialPhase)
            throw ValueError("未知升级保护阶段", -1, initialPhase)
        this.Phase := initialPhase
    }

    Transition(nextPhase) {
        if !MaintenanceStateMachine.AllowedTransitions.Has(nextPhase)
            throw ValueError("未知升级保护阶段", -1, nextPhase)
        if !MaintenanceStateMachine.AllowedTransitions[this.Phase].Has(nextPhase)
            throw Error("不允许的升级保护阶段转换: " this.Phase " -> " nextPhase)
        previousPhase := this.Phase
        this.Phase := nextPhase
        return previousPhase
    }

    IsBlocking() {
        return this.Phase != MaintenancePhase.Normal
    }
}
