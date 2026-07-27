#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证进程快照按 PID、路径和文件名建立的只读索引。
; 多个同名候选、不可访问路径和创建身份都要保留，供后续探测做严格判定。

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

ResolveSnapshotIndexIdentity(identityState, pid) {
    return identityState.Has(pid) ? identityState[pid] : ""
}

class AlwaysLiveProcessSnapshotIndex extends ProcessSnapshotIndex {
    GetLiveStatus(*) {
        return 1
    }
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
    AssertTrue(relativeObservation.IsUnknown()
        && relativeObservation.ReasonCode
            == ProcessObservationReason.RelativeCommandTarget,
        "相对脚本路径必须返回未知而不是按文件名冒认")
    AssertTrue(index.ObserveCommandTarget("C:\Jobs\dead.py").IsStopped(),
        "死亡脚本 PID 不得继续表示运行")

    noCommandLineIndex := ProcessSnapshotIndex(snapshot, capturedAt, false)
    noCommandLineObservation := noCommandLineIndex.ObserveCommandTarget(
        "C:\Jobs\worker.py")
    AssertTrue(noCommandLineObservation.IsUnknown()
        && noCommandLineObservation.ReasonCode
            == ProcessObservationReason.CommandLineUnavailable,
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

    liveIdentityState := Map(currentPid, "NEW-INSTANCE")
    reusedPidIndex := ProcessSnapshotIndex([{
        pid: currentPid, parent: 0, name: "Reused.exe",
        cmd: '"C:\Apps\Reused.exe"', exe: "C:\Apps\Reused.exe",
        creation: "20260725000000.000000+000",
        identity: "OLD-INSTANCE", observedTicks: capturedAt
    }], capturedAt, true, "",
        ResolveSnapshotIndexIdentity.Bind(liveIdentityState))
    AssertTrue(reusedPidIndex.ObserveImagePath(
        "C:\Apps\Reused.exe").IsStopped(),
        "快照 PID 已被新进程复用时不得继续报告旧目标正在运行")
    liveIdentityState[currentPid] := ""
    inaccessibleIdentityIndex := ProcessSnapshotIndex([{
        pid: currentPid, parent: 0, name: "Restricted.exe",
        cmd: '"C:\Apps\Restricted.exe"',
        exe: "C:\Apps\Restricted.exe", identity: "EXPECTED-INSTANCE",
        creation: "20260725000000.000000+000",
        observedTicks: capturedAt
    }], capturedAt, true, "",
        ResolveSnapshotIndexIdentity.Bind(liveIdentityState))
    inaccessibleIdentityObservation := inaccessibleIdentityIndex
        .ObserveImagePath("C:\Apps\Restricted.exe")
    AssertTrue(inaccessibleIdentityObservation.IsUnknown()
        && inaccessibleIdentityObservation.ReasonCode
            == ProcessObservationReason.ProcessIdentityUnavailable,
        "创建身份不可核对时不得把快照候选报告为确定运行")

    workingDirectoryIndex := ProcessSnapshotIndex([{
        pid: currentPid, parent: 0, name: "Actual.exe", cmd: "",
        exe: "C:\Suite\Actual.exe", creation: "LIVE",
        observedTicks: capturedAt
    }], capturedAt, false)
    workingDirectoryObservation := workingDirectoryIndex
        .ObserveExecutableInRoot("C:\Suite", "ShortcutName.exe")
    AssertTrue(workingDirectoryObservation.IsRunning(),
        "快捷方式名称与真实进程名不同时，安装目录内的唯一候选未被识别")

    ambiguousWorkingDirectoryIndex := ProcessSnapshotIndex([{
        pid: currentPid, parent: 0, name: "First.exe", cmd: "",
        exe: "C:\Suite\First.exe", creation: "LIVE",
        observedTicks: capturedAt
    }, {
        pid: currentPid, parent: 0, name: "Second.exe", cmd: "",
        exe: "C:\Suite\Second.exe", creation: "LIVE",
        observedTicks: capturedAt
    }], capturedAt, false)
    AssertTrue(ambiguousWorkingDirectoryIndex.ObserveExecutableInRoot(
        "C:\Suite", "ShortcutName.exe").IsUnknown(),
        "首选名称未命中且目录内有多个候选时不得猜测其中一个进程")

    duplicateInstanceIndex := AlwaysLiveProcessSnapshotIndex([{
        pid: 910002, parent: 0, name: "SingleInstance.exe", cmd: "",
        exe: "C:\Apps\SingleInstance.exe",
        identity: "01DCBEEF00000200", observedTicks: capturedAt
    }, {
        pid: 910001, parent: 0, name: "SingleInstance.exe", cmd: "",
        exe: "C:\Apps\SingleInstance.exe",
        identity: "01DCBEEF00000100", observedTicks: capturedAt
    }], capturedAt, false)
    oldestInstanceObservation := duplicateInstanceIndex.ObserveImagePath(
        "C:\Apps\SingleInstance.exe")
    AssertTrue(oldestInstanceObservation.IsRunning()
        && oldestInstanceObservation.PID == 910001,
        "同路径出现拒绝型临时实例时没有优先保留创建时间最早的原实例")

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

    redirectedCmdTargets := ProcessSnapshotIndex.ExtractCommandTargets(
        'cmd /d /c ""C:\Jobs\build task.cmd" >> "C:\Logs\build.log" 2>&1"')
    AssertEqual(1, redirectedCmdTargets.Absolute.Length,
        "小助手生成的带日志重定向批处理命令没有被索引")
    AssertEqual("C:\Jobs\build task.cmd",
        redirectedCmdTargets.Absolute[1],
        "带日志重定向批处理的主脚本路径解析错误")

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

    interpreterCases := [
        {Name: "Node.js", Command: 'node.exe "C:\Jobs\worker.js"',
            Target: "C:\Jobs\worker.js"},
        {Name: "Python Launcher", Command: 'py.exe -3.14 "C:\Jobs\worker.py"',
            Target: "C:\Jobs\worker.py"},
        {Name: "Versioned Python", Command: 'python3.14.exe "C:\Jobs\worker.py"',
            Target: "C:\Jobs\worker.py"},
        {Name: "Deno", Command: 'deno.exe run "C:\Jobs\worker.js"',
            Target: "C:\Jobs\worker.js"},
        {Name: "VBScript", Command: 'wscript.exe //B "C:\Jobs\task.vbs"',
            Target: "C:\Jobs\task.vbs"},
        {Name: "Ruby", Command: 'ruby.exe "C:\Jobs\worker.rb"',
            Target: "C:\Jobs\worker.rb"},
        {Name: "Perl", Command: 'perl.exe "C:\Jobs\worker.pl"',
            Target: "C:\Jobs\worker.pl"},
        {Name: "PHP", Command: 'php.exe "C:\Jobs\worker.php"',
            Target: "C:\Jobs\worker.php"},
        {Name: "Lua", Command: 'lua.exe "C:\Jobs\worker.lua"',
            Target: "C:\Jobs\worker.lua"},
        {Name: "Bash", Command: 'bash.exe "C:\Jobs\worker.sh"',
            Target: "C:\Jobs\worker.sh"}
    ]
    for interpreterCase in interpreterCases {
        parsedTargets := ProcessSnapshotIndex.ExtractCommandTargets(
            interpreterCase.Command)
        AssertTrue(parsedTargets.Absolute.Length == 1
            && parsedTargets.Absolute[1] == interpreterCase.Target,
            interpreterCase.Name " 命令行没有解析出唯一的绝对目标路径")
    }
    nodePreloadTargets := ProcessSnapshotIndex.ExtractCommandTargets(
        'node.exe --require "C:\Lib\preload.js" "C:\Jobs\worker.js"')
    AssertTrue(nodePreloadTargets.Absolute.Length == 1
        && nodePreloadTargets.Absolute[1] == "C:\Jobs\worker.js",
        "Node.js 预加载模块被错误当成主守护目标")

    codeExecutionCases := [
        "python.exe -c C:\Jobs\worker.py",
        "python.exe -m C:\Jobs\worker.py",
        "node.exe -e C:\Jobs\worker.js",
        "node.exe --eval=C:\Jobs\worker.js",
        "deno.exe eval C:\Jobs\worker.js",
        "ruby.exe -e C:\Jobs\worker.rb",
        "perl.exe -e C:\Jobs\worker.pl",
        "php.exe -r C:\Jobs\worker.php",
        "lua.exe -e C:\Jobs\worker.lua"
    ]
    for commandLine in codeExecutionCases {
        codeTargets := ProcessSnapshotIndex.ExtractCommandTargets(commandLine)
        AssertTrue(codeTargets.Absolute.Length == 0
            && codeTargets.Relative.Length == 0,
            "代码执行或模块参数中的路径被误认成主脚本：" commandLine)
    }

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
