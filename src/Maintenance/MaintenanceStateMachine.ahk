; 软件升级保护阶段及纯转换规则。
; 从候选检测、退出确认、升级活动、文件稳定到恢复守护逐步推进，
; 超时和用户结束等待都有明确出口，不与普通守护状态文案互相驱动。

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

    ; 仅供持久化会话恢复使用。恢复不是运行期事件，不能为了装载 TimedOut
    ; 而放宽 Normal 的合法转换集合；未知阶段仍必须被拒绝。
    Restore(restoredPhase) {
        if !MaintenanceStateMachine.AllowedTransitions.Has(restoredPhase)
            throw ValueError("未知升级保护阶段", -1, restoredPhase)
        previousPhase := this.Phase
        this.Phase := restoredPhase
        return previousPhase
    }

    IsBlocking() {
        return this.Phase != MaintenancePhase.Normal
    }
}
