class FileScanService {
    static MaximumResultLimit := 20000

    __New(callbacks, host := "") {
        this.Callbacks := callbacks
        this.ScriptPath := IsObject(host) && host.HasOwnProp("ScriptPath")
            ? host.ScriptPath : A_ScriptFullPath
        this.ScriptDirectory := IsObject(host)
            && host.HasOwnProp("ScriptDirectory")
            ? host.ScriptDirectory : A_ScriptDir
        this.InterpreterPath := IsObject(host)
            && host.HasOwnProp("InterpreterPath")
            ? host.InterpreterPath : A_AhkPath
        this.Compiled := IsObject(host) && host.HasOwnProp("Compiled")
            ? !!host.Compiled : !!A_IsCompiled
        this.ScriptWindow := IsObject(host) && host.HasOwnProp("ScriptWindow")
            ? host.ScriptWindow : A_ScriptHwnd
        this.TempDirectory := IsObject(host)
            && host.HasOwnProp("TempDirectory")
            ? host.TempDirectory : A_Temp
        this.Workers := Map()
        this.Workers.CaseSense := "Off"
        this.Stopped := false
    }

    IsSupported(filePath) {
        if !FileExist(filePath) || DirExist(filePath)
            return false
        SplitPath(filePath, &fileName, , &extension)
        if !RegExMatch(extension,
            "i)^(exe|com|msc|ahk|py|pyw|js|vbs|vbe|wsf|ps1|bat|cmd|rb|pl|php|lua|jar|sh|bash|lnk|url|appref-ms)$")
            return false
        candidatePath := this.CanonicalPath(filePath)
        scriptPath := this.CanonicalPath(this.ScriptPath)
        if ((candidatePath != "" && scriptPath != ""
                && candidatePath == scriptPath)
            || RegExMatch(fileName, "i)^_codex_.*\.ahk$"))
            return false
        return true
    }

    AddScannedFile(filePath, deadlineTicks, maximumResults, seen, results) {
        if (this.Now() >= deadlineTicks || results.Length >= maximumResults)
            return false
        if !this.IsSupported(filePath)
            return true
        canonicalPath := this.CanonicalPath(filePath)
        if canonicalPath == ""
            canonicalPath := StrLower(StrReplace(filePath, "/", "\"))
        if !seen.Has(canonicalPath) {
            seen[canonicalPath] := true
            results.Push(filePath)
        }
        return results.Length < maximumResults
    }

    ScanDirectoryToDepth(rootPath, depth, deadlineTicks, maximumResults,
        seen, results) {
        if (depth < 0 || !DirExist(rootPath))
            return true
        try {
            Loop Files, RTrim(rootPath, "\") "\*.*", "FD" {
                if (this.Now() >= deadlineTicks
                    || results.Length >= maximumResults)
                    return false
                if InStr(A_LoopFileAttrib, "H")
                    || InStr(A_LoopFileAttrib, "S")
                    continue
                if DirExist(A_LoopFileFullPath) {
                    if (depth > 0 && !this.ScanDirectoryToDepth(
                        A_LoopFileFullPath, depth - 1, deadlineTicks,
                        maximumResults, seen, results))
                        return false
                } else if !this.AddScannedFile(A_LoopFileFullPath,
                    deadlineTicks, maximumResults, seen, results) {
                    return false
                }
            }
        }
        return true
    }

    ScanDirectoryRecursive(rootPath, deadlineTicks, maximumResults,
        seen, results) {
        if !DirExist(rootPath)
            return true
        try {
            Loop Files, RTrim(rootPath, "\") "\*.*", "FR" {
                if InStr(A_LoopFileAttrib, "H")
                    || InStr(A_LoopFileAttrib, "S")
                    continue
                if !this.AddScannedFile(A_LoopFileFullPath, deadlineTicks,
                    maximumResults, seen, results)
                    return false
            }
        }
        return this.Now() < deadlineTicks
            && results.Length < maximumResults
    }

    WriteWorkerFile(outputPath, mode, rootPath, recursive, maximumResults,
        timeoutSeconds) {
        maximumResults := Max(1, Min(Integer(maximumResults),
            FileScanService.MaximumResultLimit))
        deadlineTicks := this.Now() + Max(1, Integer(timeoutSeconds)) * 1000
        seen := Map()
        seen.CaseSense := "Off"
        results := []
        completed := true
        if (StrLower(mode) == "batch") {
            completed := recursive
                ? this.ScanDirectoryRecursive(rootPath, deadlineTicks,
                    maximumResults, seen, results)
                : this.ScanDirectoryToDepth(rootPath, 0, deadlineTicks,
                    maximumResults, seen, results)
        } else {
            for scanPath in [A_Programs, A_ProgramsCommon, A_Desktop,
                A_DesktopCommon] {
                if !this.ScanDirectoryRecursive(scanPath, deadlineTicks,
                    maximumResults, seen, results) {
                    completed := false
                    break
                }
            }
            if completed {
                for scanPath in [EnvGet("ProgramFiles"),
                    EnvGet("ProgramFiles(x86)"), A_MyDocuments] {
                    if !this.ScanDirectoryToDepth(scanPath, 2, deadlineTicks,
                        maximumResults, seen, results) {
                        completed := false
                        break
                    }
                }
            }
            if completed {
                Loop Parse, DriveGetList() {
                    if !this.ScanDirectoryToDepth(A_LoopField ":\", 1,
                        deadlineTicks, maximumResults, seen, results) {
                        completed := false
                        break
                    }
                }
            }
        }
        outputText := Format("{}|{}`r`n",
            completed ? "COMPLETE" : "TRUNCATED", results.Length)
        for filePath in results
            outputText .= IniFieldCodec.Encode(filePath) "`r`n"
        tempPath := outputPath ".writing"
        try {
            if !this.DeletePathWithRetry(tempPath)
                return false
            FileAppend(outputText, tempPath, "UTF-16")
            FileMove(tempPath, outputPath, 1)
            return true
        } catch {
            this.DeletePathWithRetry(tempPath)
            return false
        }
    }

    Start(mode, rootPath, recursive, maximumResults, timeoutSeconds) {
        static workerSequence := 0
        if this.Stopped
            return ""
        previousCritical := A_IsCritical
        Critical("On")
        try {
            workerSequence++
            currentWorkerSequence := workerSequence
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        timeoutSeconds := Max(1, Integer(timeoutSeconds))
        startedTicks := this.Now()
        outputPath := Format("{}\watchdog-scan-{}-{}-{}.tmp",
            this.TempDirectory, this.ScriptWindow, startedTicks,
            currentWorkerSequence)
        workerPrefix := this.Compiled
            ? '"' this.ScriptPath '"'
            : '"' this.InterpreterPath '" "' this.ScriptPath '"'
        command := Format('{} --file-scan-worker "{}" "{}" "{}" {} {} {}',
            workerPrefix, outputPath, mode, rootPath, recursive ? 1 : 0,
            maximumResults, timeoutSeconds)
        workerPid := 0
        try {
            workerPid := this.LaunchWorker(command)
            if !workerPid
                throw Error("后台扫描进程未返回 PID")
        } catch as scanError {
            this.DeleteOutputFiles(outputPath)
            try this.Callbacks.Log.Call("无法启动后台文件扫描: "
                scanError.Message)
            return ""
        }
        creationIdentity := ""
        try creationIdentity := this.Callbacks.GetCreationIdentity.Call(
            workerPid)
        job := {Pid: workerPid, Path: outputPath,
            CreationIdentity: creationIdentity,
            DeadlineTicks: startedTicks + timeoutSeconds * 1000 + 5000}
        rejectedAfterLaunch := false
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if this.Stopped
                rejectedAfterLaunch := true
            else
                this.Workers[outputPath] := job
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        if rejectedAfterLaunch {
            this.Stop(job.Pid, job.Path, job.CreationIdentity)
            return ""
        }
        return job
    }

    LaunchWorker(command) {
        if this.Callbacks.HasOwnProp("RunWorker")
            return this.Callbacks.RunWorker.Call(command,
                this.ScriptDirectory)
        workerPid := 0
        Run(command, this.ScriptDirectory, "Hide", &workerPid)
        return workerPid
    }

    Stop(workerPid, outputPath, creationIdentity := "") {
        try {
            if workerPid && creationIdentity != "" {
                currentCreation := ""
                try currentCreation := this.Callbacks.GetCreationIdentity.Call(
                    workerPid)
                if currentCreation != ""
                    && currentCreation == creationIdentity {
                    try ProcessClose(workerPid)
                    try ProcessWaitClose(workerPid, 1)
                }
            }
        } finally {
            this.Forget(outputPath)
            if outputPath && !this.DeleteOutputFiles(outputPath)
                try this.Callbacks.Log.Call(
                    "无法清理后台扫描临时文件: " outputPath)
        }
    }

    ReadResult(outputPath, &truncated := false, &resultReady := false) {
        truncated := false
        resultReady := false
        try resultText := FileRead(outputPath, "UTF-16")
        catch
            return []
        try return this.ParseResultText(resultText, &truncated, &resultReady)
        finally {
            this.Forget(outputPath)
            if !this.DeleteOutputFiles(outputPath)
                try this.Callbacks.Log.Call(
                    "无法清理后台扫描结果文件: " outputPath)
        }
    }

    ParseResultText(resultText, &truncated := false,
        &resultReady := false) {
        paths := []
        truncated := false
        resultReady := false
        expectedCount := -1
        Loop Parse, resultText, "`n", "`r" {
            if A_LoopField == ""
                continue
            if expectedCount < 0 {
                headerParts := StrSplit(A_LoopField, "|")
                if (headerParts.Length != 2
                    || (headerParts[1] != "COMPLETE"
                        && headerParts[1] != "TRUNCATED"))
                    return []
                try expectedCount := Integer(headerParts[2])
                catch
                    return []
                if (expectedCount < 0
                    || expectedCount > FileScanService.MaximumResultLimit)
                    return []
                truncated := headerParts[1] == "TRUNCATED"
                continue
            }
            if paths.Length >= expectedCount {
                truncated := false
                return []
            }
            paths.Push(IniFieldCodec.Decode(A_LoopField))
        }
        if expectedCount < 0 || paths.Length != expectedCount {
            truncated := false
            return []
        }
        resultReady := true
        return paths
    }

    Forget(outputPath) {
        if outputPath != "" && this.Workers.Has(outputPath)
            this.Workers.Delete(outputPath)
    }

    DeletePathWithRetry(path, maximumAttempts := 4) {
        if path == "" || !FileExist(path)
            return true
        maximumAttempts := Max(1, Integer(maximumAttempts))
        Loop maximumAttempts {
            try FileDelete(path)
            if !FileExist(path)
                return true
            if A_Index < maximumAttempts
                Sleep(10)
        }
        return !FileExist(path)
    }

    DeleteOutputFiles(outputPath) {
        if outputPath == ""
            return true
        outputDeleted := this.DeletePathWithRetry(outputPath)
        writingDeleted := this.DeletePathWithRetry(outputPath ".writing")
        return outputDeleted && writingDeleted
    }

    Shutdown(*) {
        jobs := []
        alreadyStopped := false
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if this.Stopped {
                alreadyStopped := true
            } else {
                this.Stopped := true
                for _, job in this.Workers
                    jobs.Push(job)
                this.Workers.Clear()
            }
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        if alreadyStopped
            return
        for job in jobs
            this.Stop(job.Pid, job.Path, job.CreationIdentity)
    }

    CanonicalPath(path) {
        return this.Callbacks.CanonicalPath.Call(path)
    }

    Now() {
        return this.Callbacks.Now.Call()
    }
}
