#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 询问恢复按全局停止次数阈值触发，条目开关只决定是否参与询问。

try {
    RunGuardRuntimePromptTests()
    try FileAppend("GUARD_RUNTIME_PROMPT|PASS`n", "*")
    ExitApp(0)
} catch as testError {
    failureText := testError.File " (" testError.Line "): "
        . testError.Message "`n" testError.Stack "`n"
    try FileAppend(failureText, "**")
    catch {
        ; 直接双击运行时没有标准错误句柄，仍要把原始失败原因展示出来。
        try MsgBox(failureText, A_ScriptName, "Iconx")
    }
    ExitApp(1)
}

#Include ..\..\进程守护小助手.ahk

AssertGuardRuntimePrompt(condition, message) {
    if !condition
        throw Error(message)
}

SnapshotResumeTestLog(*) {
}

SnapshotResumeTestNormalize(path) {
    return path
}

class FailingSnapshotResumeSupervisor extends TargetSupervisor {
    ScheduleRestart(*) {
        throw Error("模拟单个目标恢复调度异常")
    }

    ScheduleVerification(*) {
        throw Error("模拟单个目标复核调度异常")
    }
}

class BatchManualStopTestProbe {
    Observe(*) {
        return ProcessObservation.Running(12345, "BATCH-TEST-ID")
    }
}

class BatchManualStopTestSpecs {
    Get(*) {
        return {Probe: {Kind: TargetProbeKind.ProcessName,
            TargetPath: "batch-test"}}
    }
}

class BatchManualStopTestStopper {
    static Active := 0
    static MaximumActive := 0
    static Started := 0

    static Reset() {
        this.Active := 0
        this.MaximumActive := 0
        this.Started := 0
    }

    Stop(*) {
        BatchManualStopTestStopper.Active++
        BatchManualStopTestStopper.Started++
        BatchManualStopTestStopper.MaximumActive := Max(
            BatchManualStopTestStopper.MaximumActive,
            BatchManualStopTestStopper.Active)
        try {
            ; 真实停止会等待窗口关闭、Ctrl+C 或强制终止。保持多个定时器
            ; 同时挂起，才能覆盖 AutoHotkey 的线程总数上限。
            Sleep(250)
            return TargetStopResult(true, TargetStopStage.AlreadyStopped)
        } finally BatchManualStopTestStopper.Active--
    }
}

RunGuardRuntimePromptTests() {
    runtime := {askBeforeRestartFromStopCount: 2}
    runtimeController := GuardRuntime(runtime, {})
    supervisor := TargetSupervisor({AskBeforeRestart: true})
    AssertGuardRuntimePrompt(!runtimeController.ShouldPromptAfterConfirmedStop(
        supervisor) && supervisor.StopCountSinceGuardReset == 1,
        "全局阈值为 2 时首次确认停止仍显示了恢复选择")
    AssertGuardRuntimePrompt(runtimeController.ShouldPromptAfterConfirmedStop(
        supervisor) && supervisor.StopCountSinceGuardReset == 2,
        "全局阈值为 2 时第二次确认停止没有显示恢复选择")

    supervisor.ResetGuardAttemptState()
    runtime.askBeforeRestartFromStopCount := 1
    AssertGuardRuntimePrompt(runtimeController.ShouldPromptAfterConfirmedStop(
        supervisor) && supervisor.StopCountSinceGuardReset == 1,
        "全局阈值为 1 时首次确认停止没有显示恢复选择")

    supervisor.AskBeforeRestart := false
    AssertGuardRuntimePrompt(!runtimeController.ShouldPromptAfterConfirmedStop(
        supervisor), "未开启询问恢复的条目仍显示了恢复选择")

    ; 迟到的停止回调不能清理已经进入下一代的手动结束事务。
    manualStopSupervisor := TargetSupervisor()
    manualStopSupervisor.ManualStopRequested := true
    manualStopSupervisor.ManualStopGeneration :=
        manualStopSupervisor.Generation
    AssertGuardRuntimePrompt(!ClearManualStopRequest(manualStopSupervisor,
        manualStopSupervisor.Generation + 1)
        && manualStopSupervisor.ManualStopRequested,
        "旧代际停止回调错误清理了当前手动结束请求")
    AssertGuardRuntimePrompt(ClearManualStopRequest(manualStopSupervisor,
        manualStopSupervisor.Generation)
        && !manualStopSupervisor.ManualStopRequested
        && manualStopSupervisor.ManualStopGeneration == 0,
        "当前代际停止回调没有正确清理手动结束请求")

    ; 同一份进程快照可能同时恢复多个目标。前一个目标调度失败时，
    ; 后一个目标仍必须保留自己的恢复任务。
    for purpose in ["Restart", "Verify"] {
        batchRuntime := {
            appStates: Map(),
            scheduler: WatchdogScheduler("", false),
            checkInterval: 2000
        }
        batchRuntime.appStates.CaseSense := "Off"
        failedPath := "C:\\batch-failed-" purpose ".exe"
        resumedPath := "C:\\batch-resumed-" purpose ".exe"
        failedSupervisor := FailingSnapshotResumeSupervisor()
        resumedSupervisor := TargetSupervisor()
        failedSupervisor.Scheduler := batchRuntime.scheduler
        resumedSupervisor.Scheduler := batchRuntime.scheduler
        failedSupervisor.Pending := true
        resumedSupervisor.Pending := true
        failedSupervisor.BeginSnapshotWait(purpose, 1, 10000)
        resumedSupervisor.BeginSnapshotWait(purpose, 1, 10000)
        batchRuntime.appStates[failedPath] := failedSupervisor
        batchRuntime.appStates[resumedPath] := resumedSupervisor
        batchRuntimeController := GuardRuntime(batchRuntime, {
            Log: SnapshotResumeTestLog,
            NormalizeTargetPath: SnapshotResumeTestNormalize
        })
        snapshotIndex := ProcessSnapshotIndex([], 100)
        AssertGuardRuntimePrompt(batchRuntimeController.OnSnapshotPublished(
            [], snapshotIndex), "单个目标恢复异常导致批次没有继续处理：" purpose)
        AssertGuardRuntimePrompt(!failedSupervisor.Pending
            && failedSupervisor.Phase == GuardPhase.Initializing,
            "恢复调度失败的目标没有回到可重试状态：" purpose)
        resumedTask := purpose == "Restart"
            ? resumedSupervisor.RestartTask : resumedSupervisor.VerifyTask
        AssertGuardRuntimePrompt(resumedSupervisor.Pending
            && resumedTask is TargetScheduledTask,
            "前一个目标恢复异常干扰了后一个目标的恢复：" purpose)
    }

    ; 批量手动结束必须一次性派发全部对象；每个对象的停止完成回调独立
    ; 收尾，不能因前面的对象占用工作门而让尾部对象永久保持 Pending。
    global App
    batchApp := {appStates: Map(), guardWorkGate: GuardWorkGate(),
        targetProbe: BatchManualStopTestProbe(),
        targetSpecsService: BatchManualStopTestSpecs(),
        targetStopper: BatchManualStopTestStopper(),
        gracefulStopSeconds: 1, ctrlCWaitSeconds: 1,
        allowForceTerminate: false, logMessages: [], logMaxEntries: 100,
        logRevision: 0, shutdownStarted: false}
    batchApp.appStates.CaseSense := "Off"
    App := batchApp
    BatchManualStopTestStopper.Reset()
    batchStates := []
    Loop 13 {
        batchPath := "__batch-manual-stop-" A_Index "__"
        batchState := TargetSupervisor()
        batchState.Enabled := 0
        batchState.ManualStopRequested := true
        batchState.ManualStopGeneration := batchState.Generation
        batchState.Pending := true
        batchApp.appStates[batchPath] := batchState
        batchStates.Push({Path: batchPath, State: batchState,
            Generation: batchState.Generation})
    }
    for request in batchStates
        SetTimer(PerformManualStop.Bind(request.Path, request.State,
            request.Generation, 0), -1)
    Sleep(1500)
    AssertGuardRuntimePrompt(BatchManualStopTestStopper.Started == 13
        && BatchManualStopTestStopper.MaximumActive == 13,
        "批量结束没有同时进入全部 13 个停止任务（最大并发："
            BatchManualStopTestStopper.MaximumActive "）")
    for request in batchStates
        AssertGuardRuntimePrompt(!request.State.Pending
            && !request.State.ManualStopRequested
            && !request.State.ManualStopInProgress
            && !request.State.ManualStopPID
            && request.State.ManualStopCreationIdentity == "",
            "批量结束的尾部对象没有完成独立收尾：" request.Path)

    ; 完成收尾不应因为其它后台任务暂时持有工作门而重新依赖定时器。
    busyPath := "__batch-manual-stop-gate-busy__"
    busyState := TargetSupervisor({Enabled: 0, Pending: true,
        ManualStopRequested: true,
        ManualStopGeneration: 1, ManualStopPID: 12345,
        ManualStopCreationIdentity: "BATCH-TEST-ID"})
    batchApp.appStates[busyPath] := busyState
    AssertGuardRuntimePrompt(batchApp.guardWorkGate.TryEnter("test-blocker"),
        "无法建立停止完成工作门竞争测试")
    CompleteManualStopAfterStop(busyPath, busyState, 1, 12345,
        "BATCH-TEST-ID", TargetStopResult(true,
            TargetStopStage.AlreadyStopped))
    batchApp.guardWorkGate.Leave()
    AssertGuardRuntimePrompt(!busyState.Pending
        && !busyState.ManualStopRequested
        && !busyState.ManualStopInProgress,
        "工作门竞争导致停止完成收尾被延迟")
}
