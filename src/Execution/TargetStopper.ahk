; 守护目标的分级停止执行边界。
; 窗口程序先请求正常关闭，控制台程序再尝试发送 Ctrl+C，只有用户允许且等待超时后
; 才强制结束；每一步都返回明确阶段与结果，调用方可据此记录真实失败原因。

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
    __New(creationIdentityResolver := "", clock := "") {
        this.CreationIdentityResolver := creationIdentityResolver
        this.Clock := clock
    }

    Stop(pid, gracefulWaitSeconds, ctrlCWaitSeconds, allowForceTerminate,
        sendCtrlC := "", elevatedKill := "", expectedCreationIdentity := "") {
        if !pid || !ProcessExist(pid)
            return TargetStopResult(true, TargetStopStage.AlreadyStopped)
        if expectedCreationIdentity == "" {
            return TargetStopResult(false, TargetStopStage.Failed,
                "缺少进程创建身份，已拒绝停止现存进程")
        }
        identityStatus := this.GetIdentityStatus(pid,
            expectedCreationIdentity)
        if identityStatus == 0
            return TargetStopResult(true, TargetStopStage.AlreadyStopped)
        if identityStatus < 0
            return TargetStopResult(false, TargetStopStage.Failed)

        windowCloseRequested := false
        try windowCloseRequested := this.RequestWindowClose(pid,
            expectedCreationIdentity)
        if windowCloseRequested && this.WaitUntilStopped(pid,
            gracefulWaitSeconds, expectedCreationIdentity)
            return TargetStopResult(true, TargetStopStage.WindowClose)

        ctrlSent := false
        identityStatus := this.GetIdentityStatus(pid,
            expectedCreationIdentity)
        if identityStatus == 0
            return TargetStopResult(true, TargetStopStage.WindowClose)
        if identityStatus < 0
            return TargetStopResult(false, TargetStopStage.Failed)
        if IsObject(sendCtrlC) {
            try ctrlSent := !!sendCtrlC.Call(pid,
                expectedCreationIdentity)
        }
        if (ctrlSent && this.WaitUntilStopped(pid, ctrlCWaitSeconds,
            expectedCreationIdentity))
            return TargetStopResult(true, TargetStopStage.ConsoleCtrlC)

        if !allowForceTerminate
            return TargetStopResult(false, TargetStopStage.ForceSkipped)

        identityStatus := this.GetIdentityStatus(pid,
            expectedCreationIdentity)
        if identityStatus == 0
            return TargetStopResult(true, TargetStopStage.ConsoleCtrlC)
        if identityStatus < 0
            return TargetStopResult(false, TargetStopStage.Failed)
        forceError := ""
        terminateStatus := this.TerminateVerifiedProcess(pid,
            expectedCreationIdentity, &forceError)
        if terminateStatus == 0
            return TargetStopResult(true, TargetStopStage.AlreadyStopped)
        if (terminateStatus > 0 && this.WaitUntilStopped(pid, 1,
            expectedCreationIdentity))
            return TargetStopResult(true, TargetStopStage.ForceTerminated)

        if IsObject(elevatedKill) {
            identityStatus := this.GetIdentityStatus(pid,
                expectedCreationIdentity)
            if identityStatus == 0
                return TargetStopResult(true, TargetStopStage.ForceTerminated)
            if identityStatus < 0
                return TargetStopResult(false, TargetStopStage.Failed,
                    forceError)
            elevatedSucceeded := false
            try elevatedSucceeded := !!elevatedKill.Call(pid,
                expectedCreationIdentity)
            if (elevatedSucceeded && this.WaitUntilStopped(pid, 1,
                expectedCreationIdentity))
                return TargetStopResult(true, TargetStopStage.ElevatedKill)
        }
        return TargetStopResult(false, TargetStopStage.Failed, forceError)
    }

    TerminateVerifiedProcess(pid, expectedCreationIdentity,
        &errorMessage := "") {
        errorMessage := ""
        if !pid || !ProcessExist(pid)
            return 0
        if expectedCreationIdentity == "" {
            errorMessage := "缺少进程创建身份，已拒绝强制终止"
            return -1
        }
        ; 同时请求 PROCESS_TERMINATE 与 PROCESS_QUERY_LIMITED_INFORMATION，
        ; 以便在终止前再次核对进程创建身份。
        accessMask := 0x0001 | 0x1000
        processHandle := DllCall("kernel32\OpenProcess", "UInt",
            accessMask, "Int", false, "UInt", pid, "Ptr")
        if !processHandle {
            errorMessage := "无法打开目标进程，系统错误：" A_LastError
            return -1
        }
        try {
            creationTime := Buffer(8, 0)
            exitTime := Buffer(8, 0)
            kernelTime := Buffer(8, 0)
            userTime := Buffer(8, 0)
            if !DllCall("kernel32\GetProcessTimes", "Ptr", processHandle,
                "Ptr", creationTime, "Ptr", exitTime, "Ptr", kernelTime,
                "Ptr", userTime, "Int") {
                errorMessage := "无法核对目标进程创建身份，系统错误："
                    A_LastError
                return -1
            }
            actualIdentity := Format("{:016X}",
                NumGet(creationTime, 0, "UInt64"))
            if actualIdentity != expectedCreationIdentity
                return 0
            if !DllCall("kernel32\TerminateProcess", "Ptr", processHandle,
                "UInt", 1, "Int") {
                errorMessage := "无法终止目标进程，系统错误：" A_LastError
                return -1
            }
            DllCall("kernel32\WaitForSingleObject", "Ptr", processHandle,
                "UInt", 1000, "UInt")
            return 1
        } finally {
            DllCall("kernel32\CloseHandle", "Ptr", processHandle)
        }
    }

    WaitUntilStopped(pid, timeoutSeconds, expectedCreationIdentity := "") {
        if !pid || !ProcessExist(pid)
            return true
        if expectedCreationIdentity != "" {
            deadlineTicks := this.Now() + Max(0, timeoutSeconds) * 1000
            Loop {
                identityStatus := this.GetIdentityStatus(pid,
                    expectedCreationIdentity)
                if identityStatus == 0
                    return true
                if identityStatus < 0 || this.Now() >= deadlineTicks
                    return false
                Sleep(Min(50, Max(1, deadlineTicks - this.Now())))
            }
        }
        try {
            ; ProcessWaitClose 超时时返回仍在运行的 PID，进程已退出时返回 0；
            ; 因此这里必须按返回值判断，而不能把“调用成功”误当成“目标已退出”。
            return !ProcessWaitClose(pid, Max(0, timeoutSeconds))
        } catch {
            return !ProcessExist(pid)
        }
    }

    RequestWindowClose(pid, expectedCreationIdentity := "") {
        if expectedCreationIdentity == ""
            return false
        if this.GetIdentityStatus(pid, expectedCreationIdentity) != 1
            return false
        hiddenWindowsBefore := A_DetectHiddenWindows
        requestedAny := false
        try {
            DetectHiddenWindows(true)
            for windowHandle in WinGetList("ahk_pid " pid) {
                if this.GetIdentityStatus(pid, expectedCreationIdentity) != 1
                    return false
                try {
                    PostMessage(Win32.WM_CLOSE, 0, 0, , windowHandle)
                    requestedAny := true
                }
            }
        } finally {
            DetectHiddenWindows(hiddenWindowsBefore)
        }
        return requestedAny
    }

    GetIdentityStatus(pid, expectedCreationIdentity := "") {
        if !pid || !ProcessExist(pid)
            return 0
        if expectedCreationIdentity == ""
            return 1
        if !IsObject(this.CreationIdentityResolver)
            return -1
        try currentIdentity := String(
            this.CreationIdentityResolver.Call(pid))
        catch
            return -1
        if currentIdentity == ""
            return -1
        return currentIdentity == expectedCreationIdentity ? 1 : 0
    }

    Now() {
        if IsObject(this.Clock)
            return this.Clock.Call()
        return DllCall("kernel32\GetTickCount64", "UInt64")
    }
}
