#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

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
    }
}

AssertFileScan(value, message) {
    if !value
        throw Error(message)
}

FileScanTestCanonical(path) {
    return StrLower(RTrim(StrReplace(String(path), "/", "\"), "\"))
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

CreateFileScanTestService(state, rootPath, scriptPath) {
    return FileScanService({
        CanonicalPath: FileScanTestCanonical,
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
        TempDirectory: rootPath
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
        AssertFileScan(service.WriteWorkerFile(flatOutput, "batch", rootPath,
            false, 20, 5), "非递归扫描结果写入失败")
        flatPaths := service.ReadResult(flatOutput, &flatTruncated, &flatReady)
        flatSet := FileScanPathSet(flatPaths)
        AssertFileScan(flatReady && !flatTruncated,
            "非递归扫描结果协议无效（ready=" flatReady
            "，truncated=" flatTruncated "）")
        AssertFileScan(flatPaths.Length == 2
            && flatSet.Has(FileScanTestCanonical(rootExe))
            && flatSet.Has(FileScanTestCanonical(rootScript))
            && !flatSet.Has(FileScanTestCanonical(nestedScript)),
            "非递归扫描文件集合错误（count=" flatPaths.Length "）")
        AssertFileScan(!FileExist(flatOutput),
            "非递归扫描结果文件未由服务清理")

        recursiveOutput := rootPath "\recursive-result.tmp"
        AssertFileScan(service.WriteWorkerFile(recursiveOutput, "batch",
            rootPath, true, 20, 5), "递归扫描结果写入失败")
        recursivePaths := service.ReadResult(recursiveOutput,
            &recursiveTruncated, &recursiveReady)
        recursiveSet := FileScanPathSet(recursivePaths)
        AssertFileScan(recursiveReady && !recursiveTruncated
            && recursivePaths.Length == 3
            && recursiveSet.Has(FileScanTestCanonical(nestedScript)),
            "递归扫描没有严格包含预期的可守护文件")

        limitedOutput := rootPath "\limited-result.tmp"
        AssertFileScan(service.WriteWorkerFile(limitedOutput, "batch",
            rootPath, true, 1, 5), "限量扫描结果写入失败")
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

        state.ThrowIdentity := true
        firstJob := service.Start("batch", rootPath, true, 10, 5)
        secondJob := service.Start("batch", rootPath, true, 10, 5)
        AssertFileScan(IsObject(firstJob) && IsObject(secondJob)
            && firstJob.Path != secondJob.Path
            && firstJob.CreationIdentity == ""
            && service.Workers.Count == 2
            && InStr(state.LastCommand, "--file-scan-worker"),
            "身份读取异常后任务丢失，或同毫秒输出路径发生冲突")

        FileAppend("partial", firstJob.Path ".writing", "UTF-8")
        service.Stop(firstJob.Pid, firstJob.Path, firstJob.CreationIdentity)
        AssertFileScan(service.Workers.Count == 1
            && !FileExist(firstJob.Path ".writing"),
            "停止工作器没有清除任务登记和临时输出")

        service.Shutdown()
        service.Shutdown()
        AssertFileScan(service.Stopped && service.Workers.Count == 0
            && service.Start("batch", rootPath, true, 10, 5) == "",
            "文件扫描服务关闭不是幂等终态")

        failedState := FileScanTestState()
        failedState.ThrowLaunch := true
        failedService := CreateFileScanTestService(failedState, rootPath,
            scriptPath)
        AssertFileScan(failedService.Start("batch", rootPath, true, 10, 5)
            == "" && failedState.Logs.Length == 1,
            "工作器启动异常没有被隔离并记录")
        failedService.Shutdown()

        raceState := FileScanTestState()
        raceService := CreateFileScanTestService(raceState, rootPath,
            scriptPath)
        raceState.Service := raceService
        raceState.ShutdownDuringLaunch := true
        AssertFileScan(raceService.Start("batch", rootPath, true, 10, 5)
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
