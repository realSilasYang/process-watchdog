#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证批量导入目录扫描工作器协议、结果上限、取消、超时和临时文件清理。
; 不完整输出必须被拒绝，并发扫描也不能复用同一个结果路径。

#Include ..\..\src\Config\IniFieldCodec.ahk
#Include ..\..\src\Inspection\FileScanService.ahk

class FileScanTestState {
    __New() {
        this.Now := 100000
        this.Identity := ""
        this.ThrowIdentity := false
        this.ThrowLaunch := false
        this.ShutdownDuringLaunch := false
        this.Service := ""
        this.LaunchCount := 0
        this.LastCommand := ""
        this.Logs := []
        this.HashClockAdvance := 0
    }
}

class TestFileScanService extends FileScanService {
    __New(parameters*) {
        super.__New(parameters*)
        this.NextHandle := 1000
        this.HandleStatus := Map()
        this.TerminatedHandles := []
        this.ClosedHandles := []
        this.IndexedCandidates := ""
    }

    OpenWorkerHandle(pid) {
        this.NextHandle++
        this.HandleStatus[this.NextHandle] := 1
        return this.NextHandle
    }

    GetWorkerHandleStatus(handle) {
        return this.HandleStatus.Has(handle) ? this.HandleStatus[handle] : -1
    }

    TerminateBoundWorker(handle, waitForExit := true) {
        if !this.HandleStatus.Has(handle)
            return false
        this.HandleStatus[handle] := 0
        this.TerminatedHandles.Push(handle)
        return true
    }

    CloseWorkerHandle(handle) {
        if handle
            this.ClosedHandles.Push(handle)
    }

    QueryEverythingCandidates(rootPath, previousPath, expectedSize) {
        if Type(this.IndexedCandidates) == "Array"
            return {Available: true, Paths: this.IndexedCandidates.Clone()}
        return super.QueryEverythingCandidates(rootPath, previousPath,
            expectedSize)
    }
}

AssertFileScan(value, message) {
    if !value
        throw Error(message)
}

FileScanTestCanonical(path) {
    path := StrReplace(String(path), "/", "\")
    fullPathBuffer := Buffer(32768 * 2, 0)
    fullLength := DllCall("kernel32\GetFullPathNameW", "Str", path,
        "UInt", 32768, "Ptr", fullPathBuffer, "Ptr", 0, "UInt")
    fullPath := fullLength && fullLength < 32768
        ? StrGet(fullPathBuffer, fullLength, "UTF-16") : path
    if FileExist(fullPath) {
        longPathBuffer := Buffer(32768 * 2, 0)
        longLength := DllCall("kernel32\GetLongPathNameW", "WStr", fullPath,
            "Ptr", longPathBuffer, "UInt", 32768, "UInt")
        if longLength && longLength < 32768
            fullPath := StrGet(longPathBuffer, longLength, "UTF-16")
    }
    if SubStr(fullPath, 1, 4) == "\\?\"
        fullPath := SubStr(fullPath, 5)
    return StrLower(RTrim(fullPath, "\"))
}

FileScanTestNow(state) {
    return state.Now
}

FileScanTestIdentity(state, pid) {
    if state.ThrowIdentity
        throw Error("identity unavailable")
    return state.Identity
}

FileScanTestLaunch(state, command, workingDirectory) {
    state.LaunchCount++
    state.LastCommand := command
    if state.ThrowLaunch
        throw Error("launch unavailable")
    if state.ShutdownDuringLaunch && IsObject(state.Service)
        state.Service.Shutdown()
    return DllCall("kernel32\GetCurrentProcessId", "UInt")
}

FileScanTestLog(state, message) {
    state.Logs.Push(message)
}

FileScanTestContentHash(path) {
    try content := FileRead(path, "UTF-8")
    catch
        return ""
    return content == "content-match"
        ? "C" . Format("{:063}", 0) : ""
}

FileScanTestTimedContentHash(state, path) {
    contentHash := FileScanTestContentHash(path)
    state.Now += state.HashClockAdvance
    return contentHash
}

CreateFileScanTestService(state, rootPath, scriptPath,
    candidateExclusionRoots := "") {
    if Type(candidateExclusionRoots) != "Array"
        candidateExclusionRoots := []
    return TestFileScanService({
        CanonicalPath: FileScanTestCanonical,
        ComputeContentHash: FileScanTestTimedContentHash.Bind(state),
        GetCreationIdentity: FileScanTestIdentity.Bind(state),
        Log: FileScanTestLog.Bind(state),
        Now: FileScanTestNow.Bind(state),
        RunWorker: FileScanTestLaunch.Bind(state)
    }, {
        ScriptPath: scriptPath,
        ScriptDirectory: rootPath,
        InterpreterPath: A_AhkPath,
        Compiled: false,
        ScriptWindow: 77,
        TempDirectory: rootPath,
        CandidateExclusionRoots: candidateExclusionRoots
    })
}

FileScanPathSet(paths) {
    pathSet := Map()
    pathSet.CaseSense := "Off"
    for path in paths
        pathSet[FileScanTestCanonical(path)] := true
    return pathSet
}

RunFileScanServiceTests() {
    processId := DllCall("kernel32\GetCurrentProcessId", "UInt")
    rootPath := Format("{}\ProcessWatchdog-FileScan-{}-{}", A_Temp,
        processId, A_TickCount)
    scriptPath := rootPath "\excluded.ahk"
    state := FileScanTestState()
    service := ""
    try {
        DirCreate(rootPath "\nested")
        rootExe := rootPath "\root.exe"
        rootScript := rootPath "\root.py"
        nestedScript := rootPath "\nested\task.ps1"
        ignoredText := rootPath "\ignored.txt"
        probeScript := rootPath "\_codex_probe.ahk"
        for testFile in [rootExe, rootScript, nestedScript, ignoredText,
            probeScript, scriptPath]
            FileAppend("test", testFile, "UTF-8")

        service := CreateFileScanTestService(state, rootPath, scriptPath)
        AssertFileScan(service.IsSupported(rootExe)
            && service.IsSupported(rootScript)
            && !service.IsSupported(ignoredText)
            && !service.IsSupported(probeScript)
            && !service.IsSupported(scriptPath)
            && !service.IsSupported(rootPath),
            "可守护文件过滤规则错误")

        flatOutput := rootPath "\flat-result.tmp"
        AssertFileScan(service.WriteWorkerFile(flatOutput, rootPath, false,
            20, 5), "非递归扫描结果写入失败")
        flatPaths := service.ReadResult(flatOutput, &flatTruncated, &flatReady)
        flatSet := FileScanPathSet(flatPaths)
        flatPathList := ""
        for flatPath in flatPaths
            flatPathList .= (flatPathList == "" ? "" : "，") flatPath
        AssertFileScan(flatReady && !flatTruncated,
            "非递归扫描结果协议无效（ready=" flatReady
            "，truncated=" flatTruncated "）")
        AssertFileScan(flatPaths.Length == 2
            && flatSet.Has(FileScanTestCanonical(rootExe))
            && flatSet.Has(FileScanTestCanonical(rootScript))
            && !flatSet.Has(FileScanTestCanonical(nestedScript)),
            "非递归扫描文件集合错误（count=" flatPaths.Length
            "，paths=" flatPathList "）")
        AssertFileScan(!FileExist(flatOutput),
            "非递归扫描结果文件未由服务清理")

        recursiveOutput := rootPath "\recursive-result.tmp"
        AssertFileScan(service.WriteWorkerFile(recursiveOutput, rootPath,
            true, 20, 5), "递归扫描结果写入失败")
        recursivePaths := service.ReadResult(recursiveOutput,
            &recursiveTruncated, &recursiveReady)
        recursiveSet := FileScanPathSet(recursivePaths)
        AssertFileScan(recursiveReady && !recursiveTruncated
            && recursivePaths.Length == 3
            && recursiveSet.Has(FileScanTestCanonical(nestedScript)),
            "递归扫描没有严格包含预期的可守护文件")

        limitedOutput := rootPath "\limited-result.tmp"
        AssertFileScan(service.WriteWorkerFile(limitedOutput, rootPath,
            true, 1, 5), "限量扫描结果写入失败")
        limitedPaths := service.ReadResult(limitedOutput, &limitedTruncated,
            &limitedReady)
        AssertFileScan(limitedReady && limitedTruncated
            && limitedPaths.Length == 1,
            "达到结果上限后没有返回截断标记")

        malformedOutput := rootPath "\malformed-result.tmp"
        FileAppend("COMPLETE|2`r`n" IniFieldCodec.Encode(rootExe) "`r`n",
            malformedOutput, "UTF-16")
        malformedPaths := service.ReadResult(malformedOutput,
            &malformedTruncated, &malformedReady)
        AssertFileScan(!malformedReady && !malformedTruncated
            && malformedPaths.Length == 0 && !FileExist(malformedOutput),
            "不完整扫描结果未被整批拒绝和清理")

        oversizedPaths := service.ParseResultText("COMPLETE|20001`r`n",
            &oversizedTruncated, &oversizedReady)
        AssertFileScan(!oversizedReady && !oversizedTruncated
            && oversizedPaths.Length == 0,
            "超出协议上限的声明数量仍被接受")

        contentRoot := rootPath "\content"
        historyDirectory := rootPath
            . "\AppData\Roaming\Code\User\History\-63aa655c"
        gitDirectory := rootPath "\repository\.git\objects"
        cacheDirectory := rootPath "\worker-cache"
        for directory in [contentRoot, historyDirectory, gitDirectory,
                cacheDirectory]
            DirCreate(directory)
        acceptedCandidate := contentRoot "\Bandicam 窗口管理.ahk"
        historyCandidate := historyDirectory "\fmuK.ahk"
        gitCandidate := gitDirectory "\copy.ahk"
        cacheCandidate := cacheDirectory "\copy.ahk"
        for candidatePath in [acceptedCandidate, historyCandidate,
                gitCandidate, cacheCandidate]
            FileAppend("content-match", candidatePath, "UTF-8")
        contentService := CreateFileScanTestService(state, rootPath,
            scriptPath, [cacheDirectory])
        expectedContentHash := FileScanTestContentHash(acceptedCandidate)
        expectedContentSize := FileGetSize(acceptedCandidate)
        contentOutput := rootPath "\content-result.tmp"
        AssertFileScan(contentService.IsPathWithinRoot(acceptedCandidate,
                rootPath)
            && !contentService.IsPathWithinRoot(
                rootPath "-other\copy.ahk", rootPath),
            "内容候选的搜索根边界判断错误")
        AssertFileScan(contentService.WriteContentMatchWorkerFile(
                contentOutput, rootPath, rootPath "\Bandicam窗口管理.ahk",
                expectedContentSize, expectedContentHash, false, 5),
            "内容迁移候选扫描结果写入失败")
        contentPaths := contentService.ReadResult(contentOutput,
            &contentTruncated, &contentReady)
        AssertFileScan(contentReady && !contentTruncated
            && contentPaths.Length == 1
            && FileScanTestCanonical(contentPaths[1])
                == FileScanTestCanonical(acceptedCandidate),
            "VS Code 历史、版本库或缓存副本仍参与内容迁移候选计数")
        contentService.Shutdown()

        timeoutState := FileScanTestState()
        timeoutService := CreateFileScanTestService(timeoutState, rootPath,
            scriptPath)
        secondIndexedCandidate := contentRoot "\second-copy.ahk"
        FileAppend("content-match", secondIndexedCandidate, "UTF-8")
        timeoutService.IndexedCandidates := [acceptedCandidate,
            secondIndexedCandidate]
        timeoutState.HashClockAdvance := 2000
        timeoutOutput := rootPath "\content-timeout-result.tmp"
        AssertFileScan(timeoutService.WriteContentMatchWorkerFile(
                timeoutOutput, rootPath,
                rootPath "\Bandicam窗口管理.ahk", expectedContentSize,
                expectedContentHash, true, 1),
            "索引内容候选超时结果写入失败")
        timeoutPaths := timeoutService.ReadResult(timeoutOutput,
            &timeoutTruncated, &timeoutReady)
        AssertFileScan(timeoutReady && timeoutTruncated
            && timeoutPaths.Length == 1,
            "索引候选未完成哈希时被错误标记为完整扫描")
        timeoutService.Shutdown()

        state.ThrowIdentity := true
        firstJob := service.Start(rootPath, true, 10, 5)
        secondJob := service.Start(rootPath, true, 10, 5)
        AssertFileScan(IsObject(firstJob) && IsObject(secondJob)
            && firstJob.Path != secondJob.Path
            && firstJob.CreationIdentity == ""
            && firstJob.Handle && secondJob.Handle
            && service.Workers.Count == 2
            && InStr(state.LastCommand, "--file-scan-worker"),
            "身份读取异常后任务丢失，或同毫秒输出路径发生冲突")

        FileAppend("partial", firstJob.Path ".writing", "UTF-8")
        service.Stop(firstJob.Pid, firstJob.Path, firstJob.CreationIdentity)
        AssertFileScan(service.Workers.Count == 1
            && !FileExist(firstJob.Path ".writing")
            && service.TerminatedHandles.Length == 1
            && service.ClosedHandles.Length == 1,
            "停止工作器没有通过绑定句柄终止进程、清除登记和临时输出")

        service.Shutdown()
        service.Shutdown()
        AssertFileScan(service.Stopped && service.Workers.Count == 0
            && service.TerminatedHandles.Length == 2
            && service.ClosedHandles.Length == 2
            && service.Start(rootPath, true, 10, 5) == "",
            "文件扫描服务关闭不是幂等终态")

        failedState := FileScanTestState()
        failedState.ThrowLaunch := true
        failedService := CreateFileScanTestService(failedState, rootPath,
            scriptPath)
        AssertFileScan(failedService.Start(rootPath, true, 10, 5)
            == "" && failedState.Logs.Length == 1
            && failedService.LastWorkerFailureReason == "LaunchFailed",
            "工作器启动异常没有被隔离并记录")
        failedService.Shutdown()

        diagnosticState := FileScanTestState()
        diagnosticService := CreateFileScanTestService(diagnosticState,
            rootPath, scriptPath)
        timedOutJob := diagnosticService.StartContentMatch(rootPath,
            rootPath "\old.exe", expectedContentSize, expectedContentHash,
            false, 1)
        diagnosticState.Now := timedOutJob.DeadlineTicks
        timedOutResult := diagnosticService.PollContentMatch(timedOutJob)
        AssertFileScan(timedOutResult.Ready && timedOutResult.Failed
            && timedOutResult.FailureReason == "TimedOut"
            && diagnosticService.LastWorkerFailureReason == "TimedOut",
            "内容扫描超时没有返回并保留结构化失败原因")

        exitedJob := diagnosticService.StartContentMatch(rootPath,
            rootPath "\old.exe", expectedContentSize, expectedContentHash,
            false, 5)
        diagnosticService.HandleStatus[exitedJob.Handle] := 0
        exitedResult := diagnosticService.PollContentMatch(exitedJob)
        AssertFileScan(exitedResult.Ready && exitedResult.Failed
            && exitedResult.FailureReason == "ExitedWithoutResult",
            "内容扫描工作器无结果退出没有与超时区分")

        identityOnlyJob := {Pid: 2147483000, Handle: 0,
            Path: rootPath "\identity-only-no-result.tmp",
            CreationIdentity: "OLD", DeadlineTicks: diagnosticState.Now + 5000,
            Kind: "ContentMatch"}
        identityOnlyResult := diagnosticService.PollContentMatch(
            identityOnlyJob)
        AssertFileScan(identityOnlyResult.Ready && identityOnlyResult.Failed
            && identityOnlyResult.FailureReason == "ExitedWithoutResult",
            "无进程句柄时没有通过 PID 与创建身份识别工作器退出")

        malformedJob := diagnosticService.StartContentMatch(rootPath,
            rootPath "\old.exe", expectedContentSize, expectedContentHash,
            false, 5)
        FileAppend("BROKEN`r`n", malformedJob.Path, "UTF-16")
        malformedResult := diagnosticService.PollContentMatch(malformedJob)
        AssertFileScan(malformedResult.Ready && malformedResult.Failed
            && malformedResult.FailureReason == "MalformedResult",
            "内容扫描损坏结果没有返回结构化失败原因")

        cancelledJob := diagnosticService.StartContentMatch(rootPath,
            rootPath "\old.exe", expectedContentSize, expectedContentHash,
            false, 5)
        AssertFileScan(diagnosticService.StopContentMatch(cancelledJob)
            && diagnosticService.LastWorkerFailureReason == "Cancelled"
            && InStr(diagnosticService.BuildDiagnosticText(),
                "FileScanWorker.FailureByReason.TimedOut=1"),
            "主动取消内容扫描没有记录状态，或诊断文本缺少分类计数")
        diagnosticService.Shutdown()

        raceState := FileScanTestState()
        raceService := CreateFileScanTestService(raceState, rootPath,
            scriptPath)
        raceState.Service := raceService
        raceState.ShutdownDuringLaunch := true
        AssertFileScan(raceService.Start(rootPath, true, 10, 5)
            == "" && raceService.Stopped && raceService.Workers.Count == 0,
            "关闭期间才启动成功的工作器被登记到已停止服务")
    } finally {
        if IsObject(service)
            service.Shutdown()
        try DirDelete(rootPath, true)
    }
}

try {
    RunFileScanServiceTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
