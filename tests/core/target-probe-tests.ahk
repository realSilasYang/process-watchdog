#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证目标探测器对路径、命令行、快捷方式身份和权限证据的聚合。
; 证据不足必须返回未知，只有明确排除全部候选后才能报告停止。

#Include ..\..\src\Core\GuardTypes.ahk
#Include ..\..\src\Core\TargetSpecs.ahk
#Include ..\..\src\Inspection\ProcessSnapshotIndex.ahk
#Include ..\..\src\Inspection\TargetProbe.ahk

AssertTargetProbe(value, message) {
    if !value
        throw Error(message)
}

ProvideTestSnapshot(providerState, maximumAgeMs) {
    providerState.RequestedAge := maximumAgeMs
    if providerState.ShouldThrow
        throw Error("快照提供器失败")
    return providerState.Index
}

ProvideNativeTestSnapshot(providerState) {
    if providerState.ShouldThrow
        throw Error("原生快照提供器失败")
    return providerState.Result
}

ProvideAutoHotkeyTestSnapshot(providerState, maximumAgeMs) {
    providerState.RequestedAge := maximumAgeMs
    if providerState.ShouldThrow
        throw Error("AutoHotkey 主窗口快照提供器失败")
    return providerState.Result
}

ResolveTestImagePath(imagePaths, pid) {
    return imagePaths.Has(pid) ? imagePaths[pid] : ""
}

ResolveTestCreationIdentity(pid) {
    return "CREATION-" pid
}

CanonicalizeTestPath(path) {
    return ProcessSnapshotIndex.NormalizePath(path)
}

ReadTestClock() {
    return 12345
}

RunTargetProbeTests() {
    currentPid := DllCall("kernel32\GetCurrentProcessId", "UInt")
    SplitPath(A_AhkPath, &processName)
    snapshotProvider := {Index: "", RequestedAge: -1, ShouldThrow: false}
    nativeProvider := {Result: {Ready: true, Processes: [],
        CapturedAtTicks: 12000}, ShouldThrow: false}
    autoHotkeyProvider := {Result: {Ready: true, Complete: true,
        Scripts: [], CapturedAtTicks: 12000, Reason: ""},
        RequestedAge: -1, ShouldThrow: false}
    imagePaths := Map()
    probe := TargetProbe(ProvideTestSnapshot.Bind(snapshotProvider),
        ProvideNativeTestSnapshot.Bind(nativeProvider),
        ResolveTestImagePath.Bind(imagePaths), ResolveTestCreationIdentity,
        CanonicalizeTestPath,
        ProvideAutoHotkeyTestSnapshot.Bind(autoHotkeyProvider), ReadTestClock)

    nameObservation := probe.Observe(ProbeSpec(TargetProbeKind.ProcessName,
        processName))
    AssertTargetProbe(nameObservation.IsRunning() && nameObservation.PID,
        "进程名探活没有命中当前解释器")

    imagePaths[currentPid] := "C:\Apps\Sample.exe"
    nativeProvider.Result := {Ready: true, Processes: [{pid: currentPid,
        name: "Sample.exe"}], CapturedAtTicks: 12001}
    imageObservation := probe.Observe(ProbeSpec(TargetProbeKind.ImagePath,
        "C:\Apps\Sample.exe"))
    AssertTargetProbe(imageObservation.IsRunning()
        && imageObservation.PID == currentPid,
        "完整镜像路径探活没有命中")

    imagePaths.Delete(currentPid)
    inaccessibleObservation := probe.Observe(ProbeSpec(
        TargetProbeKind.ImagePath, "C:\Apps\Sample.exe"))
    AssertTargetProbe(inaccessibleObservation.IsUnknown(),
        "同名进程镜像路径不可读时没有返回 Unknown")

    ; 升级恢复允许原生快照先发现候选，再复用后台快照核对创建身份，
    ; 以支持新 PID 的近期启动降级确认。
    snapshotProvider.Index := ProcessSnapshotIndex([{
        pid: currentPid, parent: 0, name: "Sample.exe", cmd: "", exe: "",
        identity: "CREATION-" currentPid, observedTicks: 12001
    }], 12001, false, "", ResolveTestCreationIdentity)
    inferredObservation := probe.Observe(ProbeSpec(
        TargetProbeKind.ImagePath, "C:\Apps\Sample.exe"), "", 1000, {
            AllowInaccessibleImageFallback: true,
            PriorPID: currentPid,
            PriorCreationIdentity: "CREATION-" currentPid,
            RecentStartSeconds: 0
        })
    AssertTargetProbe(inferredObservation.IsRunning()
        && inferredObservation.Source == "process-image-inferred",
        "原生快照与后台快照没有协同完成升级恢复降级确认")

    autoHotkeyProvider.Result := {Ready: true, Complete: true,
        Scripts: [{PID: currentPid, Path: "C:\Jobs\hotkey.ahk"}],
        CapturedAtTicks: 12001, Reason: ""}
    autoHotkeyRunning := probe.Observe(ProbeSpec(
        TargetProbeKind.CommandTarget, "C:\Jobs\hotkey.ahk"), "", 900)
    AssertTargetProbe(autoHotkeyRunning.IsRunning()
        && autoHotkeyRunning.PID == currentPid
        && autoHotkeyProvider.RequestedAge == 900,
        "AutoHotkey 主窗口路径没有优先识别正在运行的脚本")
    autoHotkeyProvider.Result := {Ready: true, Complete: true,
        Scripts: [{PID: currentPid, Path: "C:\Jobs\other.ahk"}],
        CapturedAtTicks: 12002, Reason: ""}
    AssertTargetProbe(probe.Observe(ProbeSpec(
        TargetProbeKind.CommandTarget,
        "C:\Jobs\missing.ahk")).IsStopped(),
        "完整 AutoHotkey 主窗口快照没有排除未运行的脚本")

    nativeProvider.Result := {Ready: true, Processes: [],
        CapturedAtTicks: 12002}
    AssertTargetProbe(probe.Observe(ProbeSpec(TargetProbeKind.ImagePath,
        "C:\Apps\Absent.exe")).IsStopped(),
        "完整空原生快照没有返回 Stopped")

    commandGapIndex := ProcessSnapshotIndex([{pid: currentPid, parent: 0,
        name: "python.exe", cmd: "", exe: "C:\Python\python.exe",
        creation: "CURRENT", observedTicks: 12003}], 12003, true)
    AssertTargetProbe(probe.Observe(ProbeSpec(TargetProbeKind.CommandTarget,
        "C:\Jobs\worker.py"), commandGapIndex).IsUnknown(),
        "候选解释器命令行缺失时没有返回 Unknown")

    duplicateRootIndex := ProcessSnapshotIndex([
        {pid: currentPid, parent: 0, name: "First.exe", cmd: "",
            exe: "C:\Suite\First.exe", creation: "FIRST",
            observedTicks: 12004},
        {pid: currentPid, parent: 0, name: "Second.exe", cmd: "",
            exe: "C:\Suite\Second.exe", creation: "SECOND",
            observedTicks: 12004}
    ], 12004, false)
    AssertTargetProbe(probe.Observe(ProbeSpec(
        TargetProbeKind.WorkingDirectory, "", "C:\Suite"),
        duplicateRootIndex).IsUnknown(),
        "工作目录存在多个候选进程时没有返回 Unknown")

    snapshotProvider.ShouldThrow := true
    providerFailure := probe.Observe(ProbeSpec(TargetProbeKind.CommandTarget,
        "C:\Jobs\worker.py"), "", 777)
    AssertTargetProbe(providerFailure.IsUnknown()
        && providerFailure.NeedsFreshSnapshot(),
        "快照提供器异常时没有返回 Unknown")
    AssertTargetProbe(snapshotProvider.RequestedAge == 777,
        "探活引擎没有传递快照最大年龄")
}

try {
    RunTargetProbeTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
