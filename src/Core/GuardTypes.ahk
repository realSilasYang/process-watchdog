; 守护核心共享的枚举和值对象。
; 这些类型描述进程观测结果、守护阶段和状态转换，不携带 GUI 控件或平台句柄，
; 使探测层、调度层和展示层能够用稳定语义交换信息。

class ProcessObservationStatus {
    static Running := "Running"
    static Stopped := "Stopped"
    static Unknown := "Unknown"
}

class ProcessObservationReason {
    static None := ""
    static SnapshotUnavailable := "SnapshotUnavailable"
    static CommandLineUnavailable := "CommandLineUnavailable"
    static RelativeCommandTarget := "RelativeCommandTarget"
    static InaccessibleImagePath := "InaccessibleImagePath"
    static ProcessIdentityUnavailable := "ProcessIdentityUnavailable"
    static AmbiguousTarget := "AmbiguousTarget"
    static InvalidProbe := "InvalidProbe"
}

class ProcessObservation {
    __New(status, pid := 0, creationIdentity := "", capturedAtTicks := 0,
        source := "", reason := "", reasonCode := "") {
        this.Status := status
        this.PID := pid ? Integer(pid) : 0
        this.CreationIdentity := creationIdentity
        this.CapturedAtTicks := capturedAtTicks
        this.Source := source
        this.Reason := reason
        this.ReasonCode := reasonCode
    }

    static Running(pid, creationIdentity := "", capturedAtTicks := 0,
        source := "") {
        return ProcessObservation(ProcessObservationStatus.Running, pid,
            creationIdentity, capturedAtTicks, source)
    }

    static Stopped(capturedAtTicks := 0, source := "", reason := "",
        reasonCode := "") {
        return ProcessObservation(ProcessObservationStatus.Stopped, 0, "",
            capturedAtTicks, source, reason, reasonCode)
    }

    static Unknown(capturedAtTicks := 0, source := "", reason := "",
        reasonCode := "") {
        return ProcessObservation(ProcessObservationStatus.Unknown, 0, "",
            capturedAtTicks, source, reason, reasonCode)
    }

    IsRunning() {
        return this.Status == ProcessObservationStatus.Running
    }

    IsStopped() {
        return this.Status == ProcessObservationStatus.Stopped
    }

    IsUnknown() {
        return this.Status == ProcessObservationStatus.Unknown
    }

    NeedsFreshSnapshot() {
        return this.IsUnknown()
            && this.ReasonCode == ProcessObservationReason.SnapshotUnavailable
    }
}

class GuardPhase {
    static Initializing := "Initializing"
    static Running := "Running"
    static SuspectedStopped := "SuspectedStopped"
    static WaitingRestart := "WaitingRestart"
    static Starting := "Starting"
    static Verifying := "Verifying"
    static Exhausted := "Exhausted"
    static CoolingDown := "CoolingDown"
    static Paused := "Paused"
}

; 主列表状态图标使用稳定语义键，而不是本地化后的显示文案。守护阶段只描述
; 状态机位置；同一阶段内的“初始化”“等待快照”“倒计时”等用户状态仍需
; 独立键，避免被底部统计栏的粗粒度类别错误合并。
class GuardStatusKind {
    static Initializing := "Initializing"
    static Running := "Running"
    static PermissionMismatch := "PermissionMismatch"
    static Paused := "Paused"
    static SuspectedStop := "SuspectedStop"
    static WaitingObservation := "WaitingObservation"
    static StartCountdown := "StartCountdown"
    static RetryCountdown := "RetryCountdown"
    static CoolingDown := "CoolingDown"
    static Starting := "Starting"
    static Verifying := "Verifying"
    static TargetMissing := "TargetMissing"
    static ProgramMissing := "ProgramMissing"
    static ScriptMissing := "ScriptMissing"
    static RelocationPending := "RelocationPending"
    static SafeStartWait := "SafeStartWait"
    static LaunchRetry := "LaunchRetry"
    static MaintenanceArbitrating := "MaintenanceArbitrating"
    static MaintenanceUpdating := "MaintenanceUpdating"
    static MaintenanceFileWaiting := "MaintenanceFileWaiting"
    static MaintenanceStabilizing := "MaintenanceStabilizing"
    static MaintenanceRecovering := "MaintenanceRecovering"
    static MaintenanceTimedOut := "MaintenanceTimedOut"
    static Unknown := "Unknown"
}
