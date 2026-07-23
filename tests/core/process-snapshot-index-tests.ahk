#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\..\src\Core\GuardTypes.ahk
#Include ..\..\src\Inspection\ProcessSnapshotIndex.ahk

AssertTrue(value, message) {
    if !value
        throw Error(message)
}

AssertEqual(expected, actual, message) {
    if (expected != actual)
        throw Error(message "（预期 " expected "，实际 " actual "）")
}

CountCanonicalization(counter, path) {
    counter.Count += 1
    return ProcessSnapshotIndex.NormalizePath(path)
}

RunProcessSnapshotIndexTests() {
    currentPid := DllCall("kernel32\GetCurrentProcessId", "UInt")
    deadPid := 0x7FFFFFFF
    while (deadPid > 0 && ProcessExist(deadPid))
        deadPid--
    capturedAt := 10000
    snapshot := [
        {pid: currentPid, parent: 0, name: "Sample.exe",
            cmd: '"C:\Apps\Sample.exe"', exe: "C:\Apps\Sample.exe",
            creation: "LIVE", observedTicks: capturedAt},
        {pid: currentPid, parent: 0, name: "python.exe",
            cmd: 'python.exe "C:\Jobs\worker.py"', exe: "C:\Python\python.exe",
            creation: "SCRIPT", observedTicks: capturedAt},
        {pid: currentPid, parent: 0, name: "python.exe",
            cmd: "python.exe main.py", exe: "C:\Python\python.exe",
            creation: "RELATIVE", observedTicks: capturedAt},
        {pid: deadPid, parent: 0, name: "Dead.exe",
            cmd: 'python.exe "C:\Jobs\dead.py"', exe: "C:\Apps\Dead.exe",
            creation: "DEAD", observedTicks: capturedAt}
    ]
    index := ProcessSnapshotIndex(snapshot, capturedAt, true)

    AssertTrue(index.IsFresh(11000, 1000), "边界年龄的快照应保持新鲜")
    AssertTrue(!index.IsFresh(11001, 1000), "超过最大年龄的快照必须失效")
    AssertTrue(index.ObserveImagePath("C:\Apps\Sample.exe").IsRunning(),
        "实时镜像路径没有命中")
    AssertTrue(index.ObserveImagePath("C:\Apps\Dead.exe").IsStopped(),
        "死亡 PID 不得继续表示运行")
    AssertTrue(index.ObserveCommandTarget("C:\Jobs\worker.py").IsRunning(),
        "绝对脚本路径没有命中")
    relativeObservation := index.ObserveCommandTarget("C:\First\main.py")
    AssertTrue(relativeObservation.IsUnknown(),
        "相对脚本路径必须返回未知而不是按文件名冒认")
    AssertTrue(index.ObserveCommandTarget("C:\Jobs\dead.py").IsStopped(),
        "死亡脚本 PID 不得继续表示运行")

    noCommandLineIndex := ProcessSnapshotIndex(snapshot, capturedAt, false)
    AssertTrue(noCommandLineIndex.ObserveCommandTarget(
        "C:\Jobs\worker.py").IsUnknown(),
        "不含命令行的快照不能证明脚本已经停止")

    partialSnapshotIndex := ProcessSnapshotIndex([{
        pid: currentPid, parent: 0, name: "python.exe", cmd: "",
        exe: "C:\Python\python.exe", creation: "LIVE",
        observedTicks: capturedAt
    }], capturedAt, true)
    AssertTrue(partialSnapshotIndex.ObserveCommandTarget(
        "C:\Jobs\worker.py").IsUnknown(),
        "目标解释器命令行缺失时不能证明脚本已经停止")
    AssertTrue(partialSnapshotIndex.ObserveCommandTarget(
        "C:\Jobs\worker.ahk").IsStopped(),
        "无关解释器的命令行缺失不应阻塞其他脚本类型")

    mutableSnapshot := [{
        pid: currentPid, parent: 0, name: "Immutable.exe",
        cmd: '"C:\Apps\Immutable.exe"', exe: "C:\Apps\Immutable.exe",
        creation: "LIVE", observedTicks: capturedAt
    }]
    immutableIndex := ProcessSnapshotIndex(mutableSnapshot, capturedAt, true)
    mutableSnapshot[1].exe := "C:\Apps\Changed.exe"
    AssertTrue(immutableIndex.ObserveImagePath(
        "C:\Apps\Immutable.exe").IsRunning(),
        "索引结果不应随调用方修改原始快照而变化")

    powershellTargets := ProcessSnapshotIndex.ExtractCommandTargets(
        'powershell.exe -NoProfile -File:"C:\Jobs\task.ps1"')
    AssertEqual(1, powershellTargets.Absolute.Length,
        "PowerShell -File: 参数没有被索引")
    AssertEqual("C:\Jobs\task.ps1", powershellTargets.Absolute[1],
        "PowerShell 脚本路径解析错误")

    embeddedPowerShellTargets := {Absolute: [], Relative: []}
    embeddedPowerShellAdded := ProcessSnapshotIndex.AddEmbeddedCommandCandidates(
        embeddedPowerShellTargets, "& 'C:\Jobs\command task.ps1'")
    AssertTrue(embeddedPowerShellAdded
        && embeddedPowerShellTargets.Absolute.Length == 1,
        "嵌套单引号脚本路径解析失败")
    powershellCommandTargets := ProcessSnapshotIndex.ExtractCommandTargets(
        "powershell.exe -NoProfile -Command `"& 'C:\Jobs\command task.ps1'`"")
    AssertEqual(1, powershellCommandTargets.Absolute.Length,
        "PowerShell -Command 中的绝对脚本没有被索引")
    AssertEqual("C:\Jobs\command task.ps1",
        powershellCommandTargets.Absolute[1],
        "PowerShell -Command 脚本路径解析错误")

    cmdTargets := ProcessSnapshotIndex.ExtractCommandTargets(
        'cmd.exe /d /c ""C:\Jobs\build task.cmd" --quiet"')
    AssertEqual(1, cmdTargets.Absolute.Length,
        "cmd /c 嵌套命令中的绝对脚本没有被索引")
    AssertEqual("C:\Jobs\build task.cmd", cmdTargets.Absolute[1],
        "cmd /c 嵌套脚本路径解析错误")

    pythonTargets := ProcessSnapshotIndex.ExtractCommandTargets(
        'python.exe -u "C:\Jobs\worker.py"')
    AssertEqual("C:\Jobs\worker.py", pythonTargets.Absolute[1],
        "Python 前置参数后的脚本路径解析错误")

    equalsPathTargets := ProcessSnapshotIndex.ExtractCommandTargets(
        'python.exe "C:\Jobs\channel=stable\worker.py"')
    AssertEqual("C:\Jobs\channel=stable\worker.py",
        equalsPathTargets.Absolute[1],
        "路径中的等号不得被误认为参数赋值分隔符")

    javaTargets := ProcessSnapshotIndex.ExtractCommandTargets(
        'javaw.exe -Xmx512m -jar "C:\Apps\worker.jar"')
    AssertEqual("C:\Apps\worker.jar", javaTargets.Absolute[1],
        "Java -jar 目标路径解析错误")

    unrelatedTargets := ProcessSnapshotIndex.ExtractCommandTargets(
        'viewer.exe --note "C:\Jobs\worker.py"')
    AssertEqual(0, unrelatedTargets.Absolute.Length,
        "无关程序引用脚本路径时不得冒认脚本正在执行")

    mscTargets := ProcessSnapshotIndex.ExtractCommandTargets(
        'mmc.exe "C:\Windows\System32\services.msc"')
    AssertEqual(1, mscTargets.Absolute.Length,
        "MMC 控制台目标没有被索引")
    AssertEqual("C:\Windows\System32\services.msc", mscTargets.Absolute[1],
        "MMC 控制台路径解析错误")

    canonicalizationCounter := {Count: 0}
    syntheticProcesses := []
    Loop 1000 {
        syntheticProcesses.Push({
            pid: currentPid, parent: 0, name: "App" A_Index ".exe",
            cmd: '"C:\Apps\App' A_Index '.exe"',
            exe: "C:\Apps\App" A_Index ".exe",
            creation: "LIVE", observedTicks: capturedAt
        })
    }
    buildStarted := A_TickCount
    largeIndex := ProcessSnapshotIndex(syntheticProcesses, capturedAt, true,
        CountCanonicalization.Bind(canonicalizationCounter))
    buildElapsed := A_TickCount - buildStarted
    AssertEqual(1000, canonicalizationCounter.Count,
        "1000 项快照构建时每个镜像路径应只规范化一次")
    AssertTrue(largeIndex.ObserveImagePath("C:\Apps\App1000.exe").IsRunning(),
        "1000 项快照的尾部镜像路径没有命中")
    AssertEqual(1001, canonicalizationCounter.Count,
        "索引查询不应重新扫描并规范化全部快照项")
    AssertTrue(buildElapsed < 3000,
        "1000 项快照索引构建耗时异常：" buildElapsed " 毫秒")
}

try {
    RunProcessSnapshotIndexTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
