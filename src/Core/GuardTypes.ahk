class ProcessObservationStatus {
    static Running := "Running"
    static Stopped := "Stopped"
    static Unknown := "Unknown"
}

class ProcessObservation {
    __New(status, pid := 0, creationIdentity := "", capturedAtTicks := 0,
        source := "", reason := "") {
        this.Status := status
        this.PID := pid ? Integer(pid) : 0
        this.CreationIdentity := creationIdentity
        this.CapturedAtTicks := capturedAtTicks
        this.Source := source
        this.Reason := reason
    }

    static Running(pid, creationIdentity := "", capturedAtTicks := 0,
        source := "") {
        return ProcessObservation(ProcessObservationStatus.Running, pid,
            creationIdentity, capturedAtTicks, source)
    }

    static Stopped(capturedAtTicks := 0, source := "", reason := "") {
        return ProcessObservation(ProcessObservationStatus.Stopped, 0, "",
            capturedAtTicks, source, reason)
    }

    static Unknown(capturedAtTicks := 0, source := "", reason := "") {
        return ProcessObservation(ProcessObservationStatus.Unknown, 0, "",
            capturedAtTicks, source, reason)
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
