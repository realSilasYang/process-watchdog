#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证进程快照工作器启动、完整结果发布、超时和终态关闭。
; 损坏输出、PID 身份不符和关闭后的迟到启动都不得替换当前有效快照。

#Include ..\..\src\Core\GuardTypes.ahk
#Include ..\..\src\Inspection\ProcessSnapshotIndex.ahk
#Include ..\..\src\Inspection\ProcessSnapshotService.ahk

AssertSnapshotService(value, message) {
    if !value
        throw Error(message)
}

BuildTestSnapshotIndex(snapshot, capturedAtTicks, supportsCommandLine) {
    return ProcessSnapshotIndex(snapshot, capturedAtTicks,
        supportsCommandLine)
}

StopServiceWhileBuildingIndex(serviceHolder, snapshot, capturedAtTicks,
    supportsCommandLine) {
    serviceHolder.Service.Stop()
    return ProcessSnapshotIndex(snapshot, capturedAtTicks,
        supportsCommandLine)
}

ReadSnapshotTestClock(clockState) {
    return clockState.Now
}

RecordPublishedSnapshot(publishedState, snapshot, snapshotIndex) {
    publishedState.Count += 1
    publishedState.Length := snapshot.Length
    publishedState.Ticks := snapshotIndex.CapturedAtTicks
}

IdentitySnapshotField(value) {
    return String(value)
}

ResolveWorkerTestIdentity(identityState, pid) {
    return identityState.Has(pid) ? identityState[pid] : ""
}

ProvideWorkerTestSnapshot(snapshot, &snapshotReady) {
    snapshotReady := true
    return snapshot
}

ProvideDelayedWorkerTestSnapshot(clockState, snapshot, &snapshotReady) {
    clockState.Now += 750
    snapshotReady := true
    return snapshot
}

class FailingPathProcessSnapshotService extends ProcessSnapshotService {
    NextWorkerOutputPath(*) {
        throw Error("output path unavailable")
    }
}

class HandleBoundProcessSnapshotService extends ProcessSnapshotService {
    __New(parameters*) {
        super.__New(parameters*)
        this.FakeHandleStatus := 1
        this.TerminationCount := 0
        this.CloseCount := 0
    }

    GetWorkerHandleStatus(handle) {
        return handle ? this.FakeHandleStatus : -1
    }

    TerminateBoundWorker(handle, waitForExit := true) {
        if !handle
            return false
        this.TerminationCount++
        this.FakeHandleStatus := 0
        return true
    }

    CloseWorkerHandle(handle) {
        if handle
            this.CloseCount++
    }
}

RunProcessSnapshotServiceTests() {
    currentPid := DllCall("kernel32\GetCurrentProcessId", "UInt")
    clockState := {Now: 10000}
    publishedState := {Count: 0, Length: 0, Ticks: 0}
    service := ProcessSnapshotService("", BuildTestSnapshotIndex,
        RecordPublishedSnapshot.Bind(publishedState), IdentitySnapshotField,
        IdentitySnapshotField, "", ReadSnapshotTestClock.Bind(clockState),
        5000, 30000, false)
    snapshot := [{pid: currentPid, parent: 0, name: "Sample.exe",
        cmd: '"C:\Apps\Sample.exe"', exe: "C:\Apps\Sample.exe",
        creation: "CURRENT", observedTicks: clockState.Now}]

    lateServiceHolder := {Service: ""}
    lateService := ProcessSnapshotService("",
        StopServiceWhileBuildingIndex.Bind(lateServiceHolder), "",
        IdentitySnapshotField, IdentitySnapshotField, "",
        ReadSnapshotTestClock.Bind(clockState), 5000, 30000, false)
    lateServiceHolder.Service := lateService
    AssertSnapshotService(!lateService.StoreSnapshot(snapshot, 9999, true)
        && lateService.Stopped && lateService.LatestSnapshotTicks == 0
        && lateService.LatestIndex == "",
        "索引构建期间关闭后仍提交了迟到的进程快照")

    AssertSnapshotService(service.PublishSnapshot(snapshot, 10000, true),
        "有效快照发布失败")
    AssertSnapshotService(publishedState.Count == 1
        && publishedState.Length == 1 && publishedState.Ticks == 10000,
        "快照发布回调没有收到已建立索引的快照")
    AssertSnapshotService(service.LatestSnapshotRequestTicks == 10000
        && service.LatestIndex.RequestTicks == 10000,
        "直接发布的快照没有保留默认请求代际")
    AssertSnapshotService(service.HasFreshSnapshot(5000),
        "刚发布的快照没有被判定为新鲜")
    AssertSnapshotService(service.GetIndex(5000) is ProcessSnapshotIndex,
        "新鲜快照没有返回索引")
    service.LatestIndex := ""
    rebuiltIndex := service.GetIndex(5000)
    AssertSnapshotService(rebuiltIndex is ProcessSnapshotIndex
        && rebuiltIndex.RequestTicks == 10000
        && service.LatestSnapshotRequestTicks == 10000,
        "重建索引时丢失了原快照请求代际")

    clockState.Now := 15000
    AssertSnapshotService(service.HasFreshSnapshot(5000),
        "快照在最大年龄边界上提前失效")
    clockState.Now := 15001
    AssertSnapshotService(!service.HasFreshSnapshot(5000)
        && service.GetIndex(5000) == "",
        "过期快照仍被用于进程判断")

    service.StoreNativeSnapshot(15001)
    AssertSnapshotService(service.HasFreshNativeSnapshot(5000),
        "原生快照时间没有被记录")
    clockState.Now := 20002
    AssertSnapshotService(!service.HasFreshNativeSnapshot(5000),
        "过期原生快照仍被视为新鲜")

    service.DelayRetry(3000, 20002)
    AssertSnapshotService(!service.CanRetry(23001)
        && service.CanRetry(23002),
        "后台快照重试窗口边界错误")

    workerIdentityState := Map(321, "CURRENT")
    identityService := ProcessSnapshotService(
        ResolveWorkerTestIdentity.Bind(workerIdentityState),
        BuildTestSnapshotIndex, "", IdentitySnapshotField,
        IdentitySnapshotField, "", ReadSnapshotTestClock.Bind(clockState),
        5000, 30000, false)
    AssertSnapshotService(identityService.CanTerminateWorker(321, "CURRENT"),
        "创建身份完全匹配的工作进程无法终止")
    AssertSnapshotService(!identityService.CanTerminateWorker(321, "OTHER")
        && !identityService.CanTerminateWorker(321, ""),
        "缺失或不匹配的已保存身份仍允许终止工作进程")
    workerIdentityState[321] := ""
    AssertSnapshotService(!identityService.CanTerminateWorker(321, "CURRENT"),
        "当前创建身份不可读时仍允许终止工作进程")

    ; 创建时间暂不可读时，启动时取得的内核句柄仍能唯一绑定工作器，
    ; 超时和关闭不应因此永久占住任务槽。
    handleService := HandleBoundProcessSnapshotService("",
        BuildTestSnapshotIndex, "", IdentitySnapshotField,
        IdentitySnapshotField, "", ReadSnapshotTestClock.Bind(clockState),
        5000, 30000, false)
    handleService.WorkerPid := 321
    handleService.WorkerHandle := 123
    handleService.WorkerCreationIdentity := ""
    handleService.WorkerPath := A_Temp "\watchdog-fake-worker.tmp"
    AssertSnapshotService(handleService.StopWorker(false)
        && handleService.WorkerPid == 0
        && handleService.WorkerHandle == 0
        && handleService.TerminationCount == 1
        && handleService.CloseCount == 1,
        "句柄已绑定时，创建身份为空的工作器无法安全终止并释放任务槽")
    handleService.WorkerPid := 654
    handleService.WorkerHandle := 456
    handleService.FakeHandleStatus := 0
    AssertSnapshotService(handleService.StopWorker(false)
        && handleService.TerminationCount == 1
        && handleService.CloseCount == 2,
        "已经退出的句柄工作器被重复终止或没有释放句柄")
    firstWorkerPath := identityService.NextWorkerOutputPath(24000)
    secondWorkerPath := identityService.NextWorkerOutputPath(24000)
    AssertSnapshotService(firstWorkerPath != secondWorkerPath
        && InStr(firstWorkerPath, "-24000-1.tmp")
        && InStr(secondWorkerPath, "-24000-2.tmp"),
        "同一毫秒启动的后台快照工作器复用了结果文件路径")
    identityService.WorkerStarting := true
    AssertSnapshotService(!identityService.Start(),
        "后台快照工作器启动尚未提交时允许了重复启动")
    identityService.WorkerStarting := false

    failingPathService := FailingPathProcessSnapshotService("",
        BuildTestSnapshotIndex, "", IdentitySnapshotField,
        IdentitySnapshotField, "",
        ReadSnapshotTestClock.Bind(clockState),
        5000, 30000, false)
    clockState.Now := 24000
    failedStartResult := failingPathService.Start()
    AssertSnapshotService(!failedStartResult
        && !failingPathService.WorkerStarting,
        "启动准备异常后后台快照服务终态错误"
        . "（result=" failedStartResult
        . "，starting=" failingPathService.WorkerStarting "）")
    queuedRequestTicks := failingPathService.RequestFresh()
    AssertSnapshotService(queuedRequestTicks > 0
        && failingPathService.PendingFreshRequestTicks == queuedRequestTicks,
        "工作器处于失败退避期时没有保留新鲜快照请求")
    failingPathService.Stop()
    AssertSnapshotService(!failingPathService.PendingFreshRequestTicks,
        "关闭快照服务后仍保留失败重试请求")

    outputPath := A_Temp "\watchdog-snapshot-service-test-"
        DllCall("kernel32\GetCurrentProcessId", "UInt") ".tmp"
    try {
        try FileDelete(outputPath)
        try FileDelete(outputPath ".writing")
        AssertSnapshotService(service.WriteWorkerFile(outputPath,
            ProvideWorkerTestSnapshot.Bind(snapshot)),
            "后台快照结果文件写入失败")
        AssertSnapshotService(FileExist(outputPath)
            && !FileExist(outputPath ".writing"),
            "后台快照没有通过原子结果文件交付")
        decodedSnapshot := service.ReadWorkerResult(outputPath, &resultReady,
            &capturedAtTicks)
        AssertSnapshotService(resultReady && decodedSnapshot.Length == 1
            && decodedSnapshot[1].pid == currentPid
            && decodedSnapshot[1].exe == "C:\Apps\Sample.exe"
            && capturedAtTicks == clockState.Now,
            "后台快照结果文件回读错误")

        FileDelete(outputPath)
        captureStartTicks := clockState.Now
        AssertSnapshotService(service.WriteWorkerFile(outputPath,
            ProvideDelayedWorkerTestSnapshot.Bind(clockState, snapshot)),
            "耗时快照结果文件写入失败")
        service.ReadWorkerResult(outputPath, &delayedReady,
            &delayedCapturedAtTicks)
        AssertSnapshotService(delayedReady
            && delayedCapturedAtTicks == captureStartTicks
            && delayedCapturedAtTicks < clockState.Now,
            "快照时间必须记录工作器采集起点，而不是父进程读取结果的时间")

        completeText := FileRead(outputPath, "UTF-16")
        FileDelete(outputPath)
        FileAppend(StrReplace(completeText, "SNAPSHOT|1", "SNAPSHOT|2"),
            outputPath, "UTF-16")
        truncatedSnapshot := service.ReadWorkerResult(outputPath,
            &truncatedReady)
        AssertSnapshotService(!truncatedReady
            && truncatedSnapshot.Length == 0,
            "缺少记录的后台快照仍被当作完整证据")

        FileDelete(outputPath)
        FileAppend(completeText "BROKEN`r`n", outputPath, "UTF-16")
        corruptSnapshot := service.ReadWorkerResult(outputPath,
            &corruptReady)
        AssertSnapshotService(!corruptReady && corruptSnapshot.Length == 0,
            "包含损坏记录的后台快照仍被部分接受")

        FileDelete(outputPath)
        requestCaptureTicks := clockState.Now
        AssertSnapshotService(service.WriteWorkerFile(outputPath,
            ProvideWorkerTestSnapshot.Bind(snapshot)),
            "用于请求代际验证的工作器结果写入失败")
        clockState.Now := 26000
        service.WorkerPid := currentPid
        service.WorkerPath := outputPath
        service.WorkerStartedTicks := 25000
        service.RequestTicks := 25000
        AssertSnapshotService(service.Pump()
            && service.LatestSnapshotTicks == requestCaptureTicks
            && service.LatestSnapshotRequestTicks == 25000
            && service.LatestIndex.RequestTicks == 25000,
            "工作器发布时用完成时刻冒充了请求代际")
        service.PumpRunning := true
        AssertSnapshotService(!service.Pump() && service.RequestFresh() == 0,
            "快照发布过程允许了重入 Pump 或并发刷新")
        service.PumpRunning := false
    } finally {
        try FileDelete(outputPath)
        try FileDelete(outputPath ".writing")
    }

    clockState.Now := 26000
    service.RequestTicks := 25000
    service.WorkerPid := currentPid
    service.WorkerStartedTicks := clockState.Now
    freshRequestTicks := service.RequestFresh()
    AssertSnapshotService(freshRequestTicks > service.RequestTicks
        && freshRequestTicks >= clockState.Now,
        "强制刷新错误复用了请求之前已经开始采集的工作进程")
    AssertSnapshotService(service.WorkerPid == currentPid
        && service.PendingFreshRequestTicks == freshRequestTicks,
        "身份不可核对的旧工作器不应失去跟踪，新的请求应等待后续采集")
    AssertSnapshotService(service.LatestSnapshotTicks == 0
        && service.LatestNativeSnapshotTicks == 0,
        "强制刷新没有使旧快照失效")
    service.WorkerPid := 0
    service.WorkerStartedTicks := 0

    AssertSnapshotService(service.PublishSnapshot(snapshot,
        clockState.Now, true),
        "停止前无法建立用于生命周期验证的快照")
    service.AutoStart := true
    service.Stop()
    AssertSnapshotService(service.Stopped && !service.AutoStart
        && service.WorkerPid == 0 && service.WorkerHandle == 0
        && service.LatestSnapshotTicks == 0,
        "停止快照服务后仍保留可自动启动的活动状态")
    AssertSnapshotService(!service.Start() && service.RequestFresh() == 0
        && service.GetIndex(5000) == "" && service.WorkerPid == 0,
        "停止快照服务后仍能重新启动后台工作器")
    AssertSnapshotService(!service.PublishSnapshot(snapshot,
            clockState.Now, true)
        && !service.StoreSnapshot(snapshot, clockState.Now, true)
        && !service.StoreNativeSnapshot(clockState.Now)
        && service.LatestSnapshotTicks == 0
        && service.LatestNativeSnapshotTicks == 0,
        "停止快照服务后仍接纳迟到的快照写入")
}

try {
    RunProcessSnapshotServiceTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
