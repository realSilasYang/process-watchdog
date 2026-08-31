#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 询问恢复按全局停止次数阈值触发，条目开关只决定是否参与询问。

try {
    RunGuardRuntimePromptTests()
    FileAppend("GUARD_RUNTIME_PROMPT|PASS`n", "*")
    ExitApp(0)
} catch as testError {
    FileAppend(testError.File " (" testError.Line "): " testError.Message
        "`n" testError.Stack "`n", "**")
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
}
