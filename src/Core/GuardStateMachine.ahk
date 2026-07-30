; 普通守护阶段的纯状态转换规则。
; 状态机只根据明确事件返回下一阶段，不读取界面文案或全局运行态，
; 让“未知”“疑似停止”和“确认停止”保持不同语义，避免证据不足时盲目启动。

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
}
