class ProcessSnapshotService {
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
        this.Clock := clock
        this.ReuseIntervalMs := Max(100, Integer(reuseIntervalMs))
        this.MaximumAgeMs := Max(this.ReuseIntervalMs, Integer(maximumAgeMs))
        this.AutoStart := !!autoStart
        this.Stopped := false
        this.LatestSnapshot := []
        this.LatestSnapshotTicks := 0
        this.LatestSupportsCommandLine := true
        this.LatestIndex := ""
        this.LatestNativeSnapshotTicks := 0
        this.RetryAfterTicks := 0
        this.RequestTicks := 0
        this.WorkerPid := 0
        this.WorkerCreationIdentity := ""
        this.WorkerPath := ""
        this.WorkerStartedTicks := 0
        this.WorkerSequence := 0
        this.WorkerStarting := false
    }

    StoreSnapshot(snapshot, capturedAtTicks := 0,
        supportsCommandLine := true, snapshotIndex := "") {
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
        this.LatestSnapshot := snapshot
        this.LatestSnapshotTicks := capturedAtTicks
        this.LatestSupportsCommandLine := !!supportsCommandLine
        this.LatestIndex := snapshotIndex
        return true
    }

    PublishSnapshot(snapshot, capturedAtTicks := 0,
        supportsCommandLine := true, snapshotIndex := "") {
        if !this.StoreSnapshot(snapshot, capturedAtTicks,
            supportsCommandLine, snapshotIndex) {
            return false
        }
        if IsObject(this.SnapshotPublishedCallback) {
            try this.SnapshotPublishedCallback.Call(this.LatestSnapshot,
                this.LatestIndex)
            catch as callbackError
                this.Log("处理后台进程快照时发生错误: " callbackError.Message)
        }
        return true
    }

    StoreNativeSnapshot(capturedAtTicks := 0) {
        if this.Stopped
            return false
        this.LatestNativeSnapshotTicks := capturedAtTicks
            ? capturedAtTicks : this.Now()
        return true
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
                this.LatestSupportsCommandLine) {
                return ""
            }
        }
        return this.LatestIndex
    }

    Start() {
        if this.Stopped
            return false
        this.Pump()
        startReserved := false
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if this.Stopped || this.WorkerPid || this.WorkerStarting
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
        workerCreationIdentity := ""
        accepted := false
        try {
            nowTicks := this.Now()
            outputPath := this.NextWorkerOutputPath(nowTicks)
            try FileDelete(outputPath)
            try FileDelete(outputPath ".writing")
            workerCommand := A_IsCompiled
                ? ('"' A_ScriptFullPath '" --process-snapshot-worker "'
                    outputPath '"')
                : ('"' A_AhkPath '" "' A_ScriptFullPath
                    '" --process-snapshot-worker "' outputPath '"')
            Run(workerCommand, A_ScriptDir, "Hide", &workerPid)
            workerCreationIdentity := this.ResolveCreationIdentity(
                workerPid)
            previousCritical := A_IsCritical
            Critical("On")
            try {
                if !this.Stopped {
                    this.WorkerPid := workerPid
                    this.WorkerCreationIdentity := workerCreationIdentity
                    this.WorkerPath := outputPath
                    this.WorkerStartedTicks := nowTicks
                    this.RequestTicks := nowTicks
                    accepted := true
                }
            } finally {
                Critical(previousCritical ? previousCritical : "Off")
            }
        } catch as workerError {
            if !this.Stopped {
                try this.DelayRetry(5000, nowTicks)
                this.Log("无法启动后台进程快照任务: " workerError.Message)
            }
        } finally {
            if startReserved {
                previousCritical := A_IsCritical
                Critical("On")
                try this.WorkerStarting := false
                finally Critical(previousCritical ? previousCritical : "Off")
            }
            if !accepted {
                if this.CanTerminateWorker(workerPid, workerCreationIdentity) {
                    try ProcessClose(workerPid)
                    try ProcessWaitClose(workerPid, 1)
                }
                if outputPath != "" {
                    try FileDelete(outputPath)
                    try FileDelete(outputPath ".writing")
                }
            }
        }
        return accepted
    }

    Pump() {
        if this.Stopped
            return false
        if !this.WorkerPid
            return false
        outputPath := this.WorkerPath
        if outputPath != "" && FileExist(outputPath) {
            snapshot := this.ReadWorkerResult(outputPath, &resultReady)
            snapshotTicks := this.Now()
            this.ResetWorkerState(true)
            if !resultReady || !snapshot.Length {
                this.DelayRetry(3000, snapshotTicks)
                this.Log("后台进程快照为空或不完整，已忽略本次结果并安排重试。")
                return false
            }
            this.RetryAfterTicks := 0
            return this.PublishSnapshot(snapshot, snapshotTicks, true)
        }
        currentCreation := this.ResolveCreationIdentity(this.WorkerPid)
        if (!ProcessExist(this.WorkerPid)
            || (this.WorkerCreationIdentity != ""
                && currentCreation != this.WorkerCreationIdentity)) {
            this.ResetWorkerState(true)
            this.DelayRetry(3000)
            return false
        }
        if (this.Now() - this.WorkerStartedTicks > 30000) {
            this.StopWorker()
            this.DelayRetry(5000)
        }
        return false
    }

    RequestFresh() {
        if this.Stopped
            return 0
        this.Pump()
        nowTicks := this.Now()
        if (this.WorkerPid
            && nowTicks - this.WorkerStartedTicks <= 250) {
            requestTicks := this.RequestTicks
                ? this.RequestTicks : this.WorkerStartedTicks
        } else {
            if this.WorkerPid
                this.StopWorker(false)
            this.RetryAfterTicks := 0
            requestTicks := nowTicks
            if this.Start()
                requestTicks := this.RequestTicks
        }
        this.ClearLatest()
        this.LatestNativeSnapshotTicks := 0
        this.RequestTicks := requestTicks
        return requestTicks
    }

    Stop(waitForExit := true) {
        this.Stopped := true
        this.AutoStart := false
        this.StopWorker(waitForExit)
        this.ClearLatest()
        this.LatestNativeSnapshotTicks := 0
    }

    StopWorker(waitForExit := true) {
        if this.CanTerminateWorker(this.WorkerPid,
            this.WorkerCreationIdentity) {
            try ProcessClose(this.WorkerPid)
            if waitForExit
                try ProcessWaitClose(this.WorkerPid, 1)
        }
        this.ResetWorkerState(true)
    }

    CanTerminateWorker(pid, expectedCreationIdentity) {
        if !pid || expectedCreationIdentity == ""
            return false
        currentCreationIdentity := this.ResolveCreationIdentity(pid)
        return currentCreationIdentity != ""
            && currentCreationIdentity == expectedCreationIdentity
    }

    NextWorkerOutputPath(nowTicks := 0) {
        if !nowTicks
            nowTicks := this.Now()
        this.WorkerSequence++
        return A_Temp "\watchdog-processes-" A_ScriptHwnd "-"
            . nowTicks "-" this.WorkerSequence ".tmp"
    }

    ClearLatest() {
        this.LatestSnapshot := []
        this.LatestSnapshotTicks := 0
        this.LatestSupportsCommandLine := true
        this.LatestIndex := ""
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

    WriteWorkerFile(outputPath, snapshotProvider) {
        if !IsObject(snapshotProvider) || !IsObject(this.Encoder)
            return false
        try snapshot := snapshotProvider.Call(&snapshotReady)
        catch
            return false
        if !snapshotReady || Type(snapshot) != "Array"
            return false
        try {
            outputText := "SNAPSHOT|" snapshot.Length "`r`n"
            for processInfo in snapshot {
                outputText .= processInfo.pid "|" processInfo.parent
                outputText .= "|" this.Encoder.Call(processInfo.name)
                outputText .= "|" this.Encoder.Call(processInfo.cmd)
                outputText .= "|" this.Encoder.Call(processInfo.exe)
                outputText .= "|" this.Encoder.Call(processInfo.creation)
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

    ReadWorkerResult(outputPath, &resultReady := false) {
        resultReady := false
        snapshot := []
        if !IsObject(this.Decoder)
            return snapshot
        try snapshotText := FileRead(outputPath, "UTF-16")
        catch
            return snapshot
        snapshotTicks := this.Now()
        expectedCount := -1
        Loop Parse, snapshotText, "`n", "`r" {
            if A_LoopField == ""
                continue
            if expectedCount < 0 {
                headerParts := StrSplit(A_LoopField, "|")
                if (headerParts.Length != 2 || headerParts[1] != "SNAPSHOT")
                    return []
                try expectedCount := Integer(headerParts[2])
                catch
                    return []
                if expectedCount < 0
                    return []
                continue
            }
            parts := StrSplit(A_LoopField, "|")
            if parts.Length != 6
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
                    observedTicks: snapshotTicks})
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
        this.WorkerPid := 0
        this.WorkerCreationIdentity := ""
        this.WorkerPath := ""
        this.WorkerStartedTicks := 0
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

    Now() {
        if IsObject(this.Clock) {
            try return Integer(this.Clock.Call())
        }
        return DllCall("kernel32\GetTickCount64", "UInt64")
    }
}
