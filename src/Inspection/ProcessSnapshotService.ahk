; 进程快照工作器的生命周期与发布服务。
; 父进程以唯一文件名启动子进程采集 WMI 结果，只有完整写入并通过格式校验的快照才发布；
; 发布时分别保留内容时间和工作器请求代际，短时单次定时器只负责收取结果，不在界面线程查询 WMI；
; 关闭是终态，任何启动中或迟到的工作器都必须再次验证代际，不能在关闭后复活。

class ProcessSnapshotService {
    static FailureLaunchFailed := "LaunchFailed"
    static FailureExitedWithoutResult := "ExitedWithoutResult"
    static FailureTimedOut := "TimedOut"
    static FailureMalformedResult := "MalformedResult"
    static FailureCancelled := "Cancelled"

    __New(creationIdentityResolver := "", indexFactory := "",
        snapshotPublishedCallback := "", encoder := "", decoder := "",
        logger := "", clock := "", reuseIntervalMs := 5000,
        maximumAgeMs := 30000, autoStart := true) {
        this.CreationIdentityResolver := creationIdentityResolver
        this.IndexFactory := indexFactory
        this.SnapshotPublishedCallback := snapshotPublishedCallback
        this.Encoder := encoder
        this.Decoder := decoder
        this.Logger := logger
        this.Localizer := ""
        this.DiagnosticLocalizer := ""
        this.Clock := clock
        this.ReuseIntervalMs := Max(100, Integer(reuseIntervalMs))
        this.MaximumAgeMs := Max(this.ReuseIntervalMs, Integer(maximumAgeMs))
        this.AutoStart := !!autoStart
        this.Stopped := false
        this.LatestSnapshot := []
        this.LatestSnapshotTicks := 0
        this.LatestSnapshotRequestTicks := 0
        this.LatestSupportsCommandLine := true
        this.LatestIndex := ""
        this.LatestNativeSnapshotTicks := 0
        this.RetryAfterTicks := 0
        this.RequestTicks := 0
        this.WorkerPid := 0
        this.WorkerHandle := 0
        this.WorkerCreationIdentity := ""
        this.WorkerPath := ""
        this.WorkerStartedTicks := 0
        this.WorkerSequence := 0
        this.LastIssuedRequestTicks := 0
        this.PendingFreshRequestTicks := 0
        this.WorkerStarting := false
        this.PumpRunning := false
        this.WorkerPollIntervalMs := 250
        this.WorkerPollTimer := ObjBindMethod(this, "PollWorker")
        this.LastWorkerFailureReason := ""
        this.LastWorkerFailureDetail := ""
        this.LastWorkerFailureTicks := 0
        this.LastWorkerRetryTicks := 0
        this.LastWorkerSuccessTicks := 0
        this.WorkerFailureCount := 0
        this.WorkerFailuresByReason := Map()
        this.WorkerFailuresByReason.CaseSense := "Off"
        this.WorkerFailureLogTicks := Map()
        this.WorkerFailureLogTicks.CaseSense := "Off"
        this.WorkerFailureLogIntervalMs := 30000
    }

    StoreSnapshot(snapshot, capturedAtTicks := 0,
        supportsCommandLine := true, snapshotIndex := "",
        requestTicks := 0) {
        if this.Stopped || Type(snapshot) != "Array"
            return false
        if !capturedAtTicks
            capturedAtTicks := this.Now()
        if !(snapshotIndex is ProcessSnapshotIndex)
            || snapshotIndex.CapturedAtTicks != capturedAtTicks
            || snapshotIndex.SupportsCommandLine != !!supportsCommandLine {
            if !IsObject(this.IndexFactory)
                return false
            try snapshotIndex := this.IndexFactory.Call(snapshot,
                capturedAtTicks, supportsCommandLine)
            catch
                return false
        }
        previousCritical := A_IsCritical
        Critical("On")
        try {
            ; 索引构建可能被关闭流程打断，提交时必须再次确认服务仍存活；
            ; 相关字段作为一个快照整体发布，读取方不能看见半新半旧状态。
            if this.Stopped
                return false
            this.LatestSnapshot := snapshot
            this.LatestSnapshotTicks := capturedAtTicks
            this.LatestSnapshotRequestTicks := requestTicks
                ? requestTicks : capturedAtTicks
            this.LatestSupportsCommandLine := !!supportsCommandLine
            snapshotIndex.RequestTicks := this.LatestSnapshotRequestTicks
            this.LatestIndex := snapshotIndex
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        return true
    }

    PublishSnapshot(snapshot, capturedAtTicks := 0,
        supportsCommandLine := true, snapshotIndex := "",
        requestTicks := 0) {
        if !this.StoreSnapshot(snapshot, capturedAtTicks,
            supportsCommandLine, snapshotIndex, requestTicks) {
            return false
        }
        if IsObject(this.SnapshotPublishedCallback) {
            try this.SnapshotPublishedCallback.Call(this.LatestSnapshot,
                this.LatestIndex)
            catch as callbackError
                this.Log(this.Text("处理后台进程快照时发生错误：{1}",
                    this.DiagnosticText(callbackError.Message)))
        }
        return true
    }

    StoreNativeSnapshot(capturedAtTicks := 0) {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if this.Stopped
                return false
            this.LatestNativeSnapshotTicks := capturedAtTicks
                ? capturedAtTicks : this.Now()
            return true
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
    }

    HasFreshSnapshot(maximumAgeMs := 0, nowTicks := 0) {
        maximumAgeMs := maximumAgeMs > 0
            ? maximumAgeMs : this.ReuseIntervalMs
        if !nowTicks
            nowTicks := this.Now()
        return this.LatestSnapshotTicks > 0
            && nowTicks >= this.LatestSnapshotTicks
            && nowTicks - this.LatestSnapshotTicks <= maximumAgeMs
    }

    HasFreshNativeSnapshot(maximumAgeMs := 0, nowTicks := 0) {
        maximumAgeMs := maximumAgeMs > 0
            ? maximumAgeMs : this.ReuseIntervalMs
        if !nowTicks
            nowTicks := this.Now()
        return this.LatestNativeSnapshotTicks > 0
            && nowTicks >= this.LatestNativeSnapshotTicks
            && nowTicks - this.LatestNativeSnapshotTicks <= maximumAgeMs
    }

    GetIndex(maximumAgeMs := 0) {
        this.Pump()
        maximumAgeMs := maximumAgeMs > 0
            ? maximumAgeMs : this.ReuseIntervalMs
        if !this.HasFreshSnapshot(maximumAgeMs) {
            if !this.Stopped && this.AutoStart && !this.WorkerPid
                this.Start()
            return ""
        }
        if !(this.LatestIndex is ProcessSnapshotIndex)
            || this.LatestIndex.CapturedAtTicks != this.LatestSnapshotTicks {
            if !this.StoreSnapshot(this.LatestSnapshot,
                this.LatestSnapshotTicks,
                this.LatestSupportsCommandLine, "",
                this.LatestSnapshotRequestTicks) {
                return ""
            }
        }
        return this.LatestIndex
    }

    Start(requestTicks := 0) {
        if this.Stopped || this.PumpRunning
            return false
        this.Pump()
        startReserved := false
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if this.Stopped || this.PumpRunning || this.WorkerPid
                || this.WorkerStarting
                || !this.CanRetry() {
                return false
            }
            this.WorkerStarting := true
            startReserved := true
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        nowTicks := 0
        outputPath := ""
        workerPid := 0
        workerHandle := 0
        workerCreationIdentity := ""
        accepted := false
        try {
            nowTicks := this.Now()
            if !requestTicks
                requestTicks := this.PendingFreshRequestTicks
                    ? this.PendingFreshRequestTicks
                    : this.IssueRequestTicks(nowTicks)
            outputPath := this.NextWorkerOutputPath(nowTicks)
            try FileDelete(outputPath)
            try FileDelete(outputPath ".writing")
            workerCommand := A_IsCompiled
                ? ('"' A_ScriptFullPath '" --process-snapshot-worker "'
                    outputPath '"')
                : ('"' A_AhkPath '" "' A_ScriptFullPath
                    '" --process-snapshot-worker "' outputPath '"')
            Run(workerCommand, A_ScriptDir, "Hide", &workerPid)
            workerHandle := this.OpenWorkerHandle(workerPid)
            workerCreationIdentity := this.ResolveCreationIdentity(
                workerPid)
            if !workerHandle && workerCreationIdentity == ""
                throw Error("OpenProcess")
            previousCritical := A_IsCritical
            Critical("On")
            try {
                if !this.Stopped {
                    this.WorkerPid := workerPid
                    this.WorkerHandle := workerHandle
                    this.WorkerCreationIdentity := workerCreationIdentity
                    this.WorkerPath := outputPath
                    this.WorkerStartedTicks := nowTicks
                    this.RequestTicks := requestTicks
                    if (this.PendingFreshRequestTicks
                        && requestTicks >= this.PendingFreshRequestTicks) {
                        this.PendingFreshRequestTicks := 0
                    }
                    accepted := true
                }
            } finally {
                Critical(previousCritical ? previousCritical : "Off")
            }
        } catch as workerError {
            if !this.Stopped {
                try this.DelayRetry(5000, nowTicks)
                failureDetail := this.DiagnosticText(workerError.Message)
                this.RecordWorkerFailure(
                    ProcessSnapshotService.FailureLaunchFailed,
                    failureDetail, this.RetryAfterTicks,
                    this.Text("无法启动后台进程快照任务：{1}",
                        failureDetail))
            }
        } finally {
            if startReserved {
                previousCritical := A_IsCritical
                Critical("On")
                try this.WorkerStarting := false
                finally Critical(previousCritical ? previousCritical : "Off")
            }
            if !accepted {
                if workerHandle {
                    try this.TerminateBoundWorker(workerHandle, true)
                    this.CloseWorkerHandle(workerHandle)
                } else if this.CanTerminateWorker(workerPid,
                    workerCreationIdentity) {
                    try ProcessClose(workerPid)
                    try ProcessWaitClose(workerPid, 1)
                }
                if outputPath != "" {
                    try FileDelete(outputPath)
                    try FileDelete(outputPath ".writing")
                }
            }
        }
        if accepted
            this.ArmWorkerPoll()
        return accepted
    }

    PollWorker(*) {
        if this.Stopped
            return
        this.Pump()
        if !this.WorkerPid && this.PendingFreshRequestTicks
            && this.CanRetry() {
            this.Start(this.PendingFreshRequestTicks)
        }
        if this.WorkerPid || this.PendingFreshRequestTicks
            this.ArmWorkerPoll()
    }

    ArmWorkerPoll() {
        if this.Stopped || (!this.WorkerPid
            && !this.PendingFreshRequestTicks)
            return false
        try {
            delayMs := this.WorkerPollIntervalMs
            if !this.WorkerPid && this.RetryAfterTicks {
                delayMs := Max(delayMs, this.RetryAfterTicks - this.Now())
            }
            SetTimer(this.WorkerPollTimer, -Max(1, delayMs))
            return true
        } catch {
            return false
        }
    }

    Pump() {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if this.Stopped || this.PumpRunning
                return false
            this.PumpRunning := true
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        try return this.PumpWorker()
        finally {
            previousCritical := A_IsCritical
            Critical("On")
            try this.PumpRunning := false
            finally Critical(previousCritical ? previousCritical : "Off")
        }
    }

    PumpWorker() {
        if this.Stopped
            return false
        if !this.WorkerPid
            return false
        outputPath := this.WorkerPath
        if outputPath != "" && FileExist(outputPath) {
            completedRequestTicks := this.RequestTicks
                ? this.RequestTicks : this.WorkerStartedTicks
            snapshot := this.ReadWorkerResult(outputPath, &resultReady,
                &snapshotTicks)
            completedIsObsolete := this.PendingFreshRequestTicks
                && completedRequestTicks < this.PendingFreshRequestTicks
            this.ResetWorkerState(true)
            if completedIsObsolete {
                this.RetryAfterTicks := 0
                this.RecordWorkerFailure(
                    ProcessSnapshotService.FailureCancelled,
                    "SupersededResult", 0)
                return false
            }
            if !resultReady || !snapshot.Length {
                this.PendingFreshRequestTicks := Max(
                    this.PendingFreshRequestTicks, completedRequestTicks)
                this.DelayRetry(3000)
                this.RecordWorkerFailure(
                    ProcessSnapshotService.FailureMalformedResult,
                    resultReady ? "EmptySnapshot" : "InvalidProtocol",
                    this.RetryAfterTicks,
                    this.Text("后台进程快照为空或不完整，已忽略本次结果并安排重试。")
                        . " [ProcessSnapshot=MalformedResult]")
                return false
            }
            this.RetryAfterTicks := 0
            published := this.PublishSnapshot(snapshot, snapshotTicks, true,
                "", completedRequestTicks)
            if published
                this.RecordWorkerSuccess()
            return published
        }
        workerHandleStatus := this.GetWorkerHandleStatus(
            this.WorkerHandle)
        currentCreation := this.WorkerHandle
            ? "" : this.ResolveCreationIdentity(this.WorkerPid)
        workerExited := this.WorkerHandle
            ? workerHandleStatus == 0
            : (!ProcessExist(this.WorkerPid)
                || (this.WorkerCreationIdentity != ""
                    && currentCreation != ""
                    && currentCreation != this.WorkerCreationIdentity))
        if workerExited {
            failedRequestTicks := this.RequestTicks
            this.ResetWorkerState(true)
            if failedRequestTicks
                this.PendingFreshRequestTicks := Max(
                    this.PendingFreshRequestTicks, failedRequestTicks)
            this.DelayRetry(3000)
            this.RecordWorkerFailure(
                ProcessSnapshotService.FailureExitedWithoutResult,
                "WorkerExitedBeforeResult", this.RetryAfterTicks,
                this.Text("后台进程快照为空或不完整，已忽略本次结果并安排重试。")
                    . " [ProcessSnapshot=ExitedWithoutResult]")
            return false
        }
        if (this.Now() - this.WorkerStartedTicks > 30000) {
            timedOutRequestTicks := this.RequestTicks
            if this.StopWorker(false) {
                if timedOutRequestTicks
                    this.PendingFreshRequestTicks := Max(
                        this.PendingFreshRequestTicks,
                        timedOutRequestTicks)
                this.DelayRetry(5000)
            } else {
                this.DelayRetry(2000)
            }
            this.RecordWorkerFailure(
                ProcessSnapshotService.FailureTimedOut,
                "WorkerDeadlineExceeded", this.RetryAfterTicks,
                this.Text("后台进程快照为空或不完整，已忽略本次结果并安排重试。")
                    . " [ProcessSnapshot=TimedOut]")
        }
        return false
    }

    RequestFresh() {
        if this.Stopped || this.PumpRunning
            return 0
        this.Pump()
        nowTicks := this.Now()
        requestTicks := this.IssueRequestTicks(nowTicks)
        this.ClearLatest()
        this.LatestNativeSnapshotTicks := 0
        if this.WorkerPid {
            this.PendingFreshRequestTicks := Max(
                this.PendingFreshRequestTicks, requestTicks)
            if !this.StopWorker(false) {
                this.ArmWorkerPoll()
                return requestTicks
            }
            this.RecordWorkerFailure(
                ProcessSnapshotService.FailureCancelled,
                "SupersededByFreshRequest", 0)
        }
        this.RetryAfterTicks := 0
        this.PendingFreshRequestTicks := Max(
            this.PendingFreshRequestTicks, requestTicks)
        if this.Start(requestTicks)
            return requestTicks
        this.ArmWorkerPoll()
        return requestTicks
    }

    Stop(waitForExit := true) {
        this.Stopped := true
        this.AutoStart := false
        this.PendingFreshRequestTicks := 0
        this.StopWorker(waitForExit)
        this.ClearLatest()
        this.LatestNativeSnapshotTicks := 0
    }

    StopWorker(waitForExit := true) {
        pid := this.WorkerPid
        handle := this.WorkerHandle
        expectedIdentity := this.WorkerCreationIdentity
        if !pid {
            this.ResetWorkerState(true)
            return true
        }
        if handle {
            if this.GetWorkerHandleStatus(handle) == 0
                terminated := true
            else
                terminated := this.TerminateBoundWorker(handle, waitForExit)
            if !terminated
                return false
            this.ResetWorkerState(true)
            return true
        }
        if !ProcessExist(pid) {
            this.ResetWorkerState(true)
            return true
        }
        currentIdentity := this.ResolveCreationIdentity(pid)
        if (expectedIdentity == "" || currentIdentity == "")
            return false
        if currentIdentity != expectedIdentity {
            ; 原工作器已经退出且 PID 被复用，只清理本服务的旧跟踪，绝不终止新进程。
            this.ResetWorkerState(true)
            return true
        }
        try ProcessClose(pid)
        if waitForExit
            try ProcessWaitClose(pid, 1)
        if ProcessExist(pid)
            && this.ResolveCreationIdentity(pid) == expectedIdentity {
            return false
        }
        this.ResetWorkerState(true)
        return true
    }

    CanTerminateWorker(pid, expectedCreationIdentity) {
        if !pid || expectedCreationIdentity == ""
            return false
        currentCreationIdentity := this.ResolveCreationIdentity(pid)
        return currentCreationIdentity != ""
            && currentCreationIdentity == expectedCreationIdentity
    }

    OpenWorkerHandle(pid) {
        if !pid
            return 0
        ; SYNCHRONIZE | PROCESS_TERMINATE。句柄始终绑定本次创建的进程对象，
        ; 即使系统随后复用同一 PID，也不会观察或结束无关进程。
        return DllCall("kernel32\OpenProcess", "UInt", 0x00100001,
            "Int", false, "UInt", pid, "Ptr")
    }

    GetWorkerHandleStatus(handle) {
        if !handle
            return -1
        waitResult := DllCall("kernel32\WaitForSingleObject", "Ptr",
            handle, "UInt", 0, "UInt")
        if waitResult == 0x00000102
            return 1
        if waitResult == 0x00000000
            return 0
        return -1
    }

    TerminateBoundWorker(handle, waitForExit := true) {
        if !handle
            return false
        if this.GetWorkerHandleStatus(handle) == 0
            return true
        if !DllCall("kernel32\TerminateProcess", "Ptr", handle,
            "UInt", 1) {
            return false
        }
        waitMilliseconds := waitForExit ? 1000 : 0
        return DllCall("kernel32\WaitForSingleObject", "Ptr", handle,
            "UInt", waitMilliseconds, "UInt") == 0x00000000
    }

    CloseWorkerHandle(handle) {
        if handle
            try DllCall("kernel32\CloseHandle", "Ptr", handle)
    }

    IssueRequestTicks(nowTicks := 0) {
        if !nowTicks
            nowTicks := this.Now()
        requestTicks := Max(nowTicks, this.LastIssuedRequestTicks + 1)
        this.LastIssuedRequestTicks := requestTicks
        return requestTicks
    }

    NextWorkerOutputPath(nowTicks := 0) {
        if !nowTicks
            nowTicks := this.Now()
        this.WorkerSequence++
        return A_Temp "\watchdog-processes-" A_ScriptHwnd "-"
            . nowTicks "-" this.WorkerSequence ".tmp"
    }

    ClearLatest() {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            this.LatestSnapshot := []
            this.LatestSnapshotTicks := 0
            this.LatestSnapshotRequestTicks := 0
            this.LatestSupportsCommandLine := true
            this.LatestIndex := ""
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
    }

    CanRetry(nowTicks := 0) {
        if !nowTicks
            nowTicks := this.Now()
        return !this.RetryAfterTicks || nowTicks >= this.RetryAfterTicks
    }

    DelayRetry(delayMs, nowTicks := 0) {
        if !nowTicks
            nowTicks := this.Now()
        this.RetryAfterTicks := nowTicks + Max(0, Integer(delayMs))
    }

    RecordWorkerFailure(reason, detail := "", retryTicks := 0,
        logMessage := "") {
        reason := Trim(String(reason))
        if reason == ""
            return false
        detail := this.DiagnosticValue(detail)
        nowTicks := this.Now()
        shouldLog := false
        previousCritical := A_IsCritical
        Critical("On")
        try {
            this.LastWorkerFailureReason := reason
            this.LastWorkerFailureDetail := detail
            this.LastWorkerFailureTicks := nowTicks
            this.LastWorkerRetryTicks := retryTicks
            this.WorkerFailureCount++
            this.WorkerFailuresByReason[reason] :=
                this.WorkerFailuresByReason.Has(reason)
                ? this.WorkerFailuresByReason[reason] + 1 : 1
            if logMessage != ""
                && (!this.WorkerFailureLogTicks.Has(reason)
                    || nowTicks - this.WorkerFailureLogTicks[reason]
                        >= this.WorkerFailureLogIntervalMs) {
                this.WorkerFailureLogTicks[reason] := nowTicks
                shouldLog := true
            }
        } finally Critical(previousCritical ? previousCritical : "Off")
        if shouldLog
            this.Log(logMessage)
        return true
    }

    RecordWorkerSuccess() {
        successTicks := this.Now()
        previousCritical := A_IsCritical
        Critical("On")
        try this.LastWorkerSuccessTicks := successTicks
        finally Critical(previousCritical ? previousCritical : "Off")
    }

    BuildDiagnosticText(prefix := "ProcessSnapshotWorker") {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            text := prefix ".Active=" (this.WorkerPid ? 1 : 0) "`r`n"
                . prefix ".Pid=" this.WorkerPid "`r`n"
                . prefix ".StartedTicks=" this.WorkerStartedTicks "`r`n"
                . prefix ".PendingRequestTicks="
                    . this.PendingFreshRequestTicks "`r`n"
                . prefix ".RetryAfterTicks=" this.RetryAfterTicks "`r`n"
                . prefix ".LastFailureReason="
                    . this.LastWorkerFailureReason "`r`n"
                . prefix ".LastFailureDetail="
                    . this.LastWorkerFailureDetail "`r`n"
                . prefix ".LastFailureTicks="
                    . this.LastWorkerFailureTicks "`r`n"
                . prefix ".LastFailureRetryTicks="
                    . this.LastWorkerRetryTicks "`r`n"
                . prefix ".LastSuccessTicks="
                    . this.LastWorkerSuccessTicks "`r`n"
                . prefix ".FailureCount=" this.WorkerFailureCount "`r`n"
            for reason, count in this.WorkerFailuresByReason
                text .= prefix ".FailureByReason."
                    . RegExReplace(reason, "[^A-Za-z0-9_.-]", "_")
                    . "=" count "`r`n"
            return text
        } finally Critical(previousCritical ? previousCritical : "Off")
    }

    DiagnosticValue(value) {
        value := String(value)
        value := RegExReplace(value, "[\r\n=]+", " ")
        return SubStr(value, 1, 500)
    }

    WriteWorkerFile(outputPath, snapshotProvider) {
        if !IsObject(snapshotProvider) || !IsObject(this.Encoder)
            return false
        capturedAtTicks := this.Now()
        try snapshot := snapshotProvider.Call(&snapshotReady)
        catch
            return false
        if !snapshotReady || Type(snapshot) != "Array"
            return false
        try {
            outputText := "SNAPSHOT|" snapshot.Length "|"
                . capturedAtTicks "`r`n"
            for processInfo in snapshot {
                outputText .= processInfo.pid "|" processInfo.parent
                outputText .= "|" this.Encoder.Call(processInfo.name)
                outputText .= "|" this.Encoder.Call(processInfo.cmd)
                outputText .= "|" this.Encoder.Call(processInfo.exe)
                outputText .= "|" this.Encoder.Call(processInfo.creation)
                outputText .= "|" this.Encoder.Call(
                    processInfo.HasOwnProp("identity")
                        ? processInfo.identity : "")
                    . "`r`n"
            }
        } catch {
            return false
        }
        tempPath := outputPath ".writing"
        try {
            try FileDelete(tempPath)
            FileAppend(outputText, tempPath, "UTF-16")
            FileMove(tempPath, outputPath, 1)
            return true
        } catch {
            try FileDelete(tempPath)
            return false
        }
    }

    ReadWorkerResult(outputPath, &resultReady := false,
        &capturedAtTicks := 0) {
        resultReady := false
        capturedAtTicks := 0
        snapshot := []
        if !IsObject(this.Decoder)
            return snapshot
        try snapshotText := FileRead(outputPath, "UTF-16")
        catch
            return snapshot
        expectedCount := -1
        Loop Parse, snapshotText, "`n", "`r" {
            if A_LoopField == ""
                continue
            if expectedCount < 0 {
                headerParts := StrSplit(A_LoopField, "|")
                if (headerParts.Length != 3 || headerParts[1] != "SNAPSHOT")
                    return []
                try expectedCount := Integer(headerParts[2])
                catch
                    return []
                try capturedAtTicks := Integer(headerParts[3])
                catch
                    return []
                if expectedCount < 0 || capturedAtTicks <= 0
                    return []
                continue
            }
            parts := StrSplit(A_LoopField, "|")
            if parts.Length != 7
                return []
            try processId := Integer(parts[1])
            catch
                return []
            if processId <= 0
                return []
            try parentId := Integer(parts[2])
            catch
                return []
            try {
                snapshot.Push({pid: processId, parent: parentId,
                    name: this.Decoder.Call(parts[3]),
                    cmd: this.Decoder.Call(parts[4]),
                    exe: this.Decoder.Call(parts[5]),
                    creation: this.Decoder.Call(parts[6]),
                    identity: this.Decoder.Call(parts[7]),
                    observedTicks: capturedAtTicks})
            } catch
                return []
        }
        if expectedCount < 0 || snapshot.Length != expectedCount
            return []
        resultReady := true
        return snapshot
    }

    ResetWorkerState(deleteFiles := false) {
        outputPath := this.WorkerPath
        try SetTimer(this.WorkerPollTimer, 0)
        this.CloseWorkerHandle(this.WorkerHandle)
        this.WorkerPid := 0
        this.WorkerHandle := 0
        this.WorkerCreationIdentity := ""
        this.WorkerPath := ""
        this.WorkerStartedTicks := 0
        this.RequestTicks := 0
        if deleteFiles && outputPath != "" {
            try FileDelete(outputPath)
            try FileDelete(outputPath ".writing")
        }
    }

    ResolveCreationIdentity(pid) {
        if !IsObject(this.CreationIdentityResolver)
            return ""
        try return String(this.CreationIdentityResolver.Call(pid))
        catch
            return ""
    }

    Log(message) {
        if IsObject(this.Logger) {
            try this.Logger.Call(message)
        }
    }

    Text(template, values*) {
        if IsObject(this.Localizer)
            return this.Localizer.Call(template, values*)
        return values.Length ? Format(template, values*) : template
    }

    DiagnosticText(value) {
        if IsObject(this.DiagnosticLocalizer)
            return this.DiagnosticLocalizer.Call(value)
        return this.Text(value)
    }

    Now() {
        if IsObject(this.Clock) {
            try return Integer(this.Clock.Call())
        }
        return DllCall("kernel32\GetTickCount64", "UInt64")
    }
}
