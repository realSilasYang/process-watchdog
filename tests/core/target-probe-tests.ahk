#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

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
    imagePaths := Map()
    probe := TargetProbe(ProvideTestSnapshot.Bind(snapshotProvider),
        ProvideNativeTestSnapshot.Bind(nativeProvider),
        ResolveTestImagePath.Bind(imagePaths), ResolveTestCreationIdentity,
        CanonicalizeTestPath, ReadTestClock)

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
    AssertTargetProbe(providerFailure.IsUnknown(),
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
