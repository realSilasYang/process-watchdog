class TargetStopStage {
    static AlreadyStopped := "AlreadyStopped"
    static WindowClose := "WindowClose"
    static ConsoleCtrlC := "ConsoleCtrlC"
    static ForceTerminated := "ForceTerminated"
    static ElevatedKill := "ElevatedKill"
    static ForceSkipped := "ForceSkipped"
    static Failed := "Failed"
}

class TargetStopResult {
    __New(stopped, stage, errorMessage := "") {
        this.Stopped := !!stopped
        this.Stage := stage
        this.ErrorMessage := errorMessage
    }
}

class TargetStopper {
    Stop(pid, gracefulWaitSeconds, ctrlCWaitSeconds, allowForceTerminate,
        sendCtrlC := "", elevatedKill := "") {
        if !pid || !ProcessExist(pid)
            return TargetStopResult(true, TargetStopStage.AlreadyStopped)

        try this.RequestWindowClose(pid)
        if this.WaitUntilStopped(pid, gracefulWaitSeconds)
            return TargetStopResult(true, TargetStopStage.WindowClose)

        ctrlSent := false
        if IsObject(sendCtrlC) {
            try ctrlSent := !!sendCtrlC.Call(pid)
        }
        if (ctrlSent && this.WaitUntilStopped(pid, ctrlCWaitSeconds))
            return TargetStopResult(true, TargetStopStage.ConsoleCtrlC)

        if !allowForceTerminate
            return TargetStopResult(false, TargetStopStage.ForceSkipped)

        forceError := ""
        try ProcessClose(pid)
        catch as closeError
            forceError := closeError.Message
        if this.WaitUntilStopped(pid, 1)
            return TargetStopResult(true, TargetStopStage.ForceTerminated)

        if IsObject(elevatedKill) {
            elevatedSucceeded := false
            try elevatedSucceeded := !!elevatedKill.Call(pid)
            if (elevatedSucceeded && !ProcessExist(pid))
                return TargetStopResult(true, TargetStopStage.ElevatedKill)
        }
        return TargetStopResult(false, TargetStopStage.Failed, forceError)
    }

    WaitUntilStopped(pid, timeoutSeconds) {
        if !pid || !ProcessExist(pid)
            return true
        try {
            ; ProcessWaitClose returns the still-running PID on timeout and 0
            ; after the process has disappeared.
            return !ProcessWaitClose(pid, Max(0, timeoutSeconds))
        } catch {
            return !ProcessExist(pid)
        }
    }

    RequestWindowClose(pid) {
        hiddenWindowsBefore := A_DetectHiddenWindows
        try {
            DetectHiddenWindows(true)
            for windowHandle in WinGetList("ahk_pid " pid)
                try PostMessage(Win32.WM_CLOSE, 0, 0, , windowHandle)
        } finally {
            DetectHiddenWindows(hiddenWindowsBefore)
        }
    }
}
