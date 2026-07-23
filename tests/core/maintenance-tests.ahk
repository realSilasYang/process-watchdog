#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\..\src\Maintenance\MaintenanceStateMachine.ahk
#Include ..\..\src\Maintenance\MaintenanceActorMatcher.ahk

class FakeCreationResolver {
    __New() {
        this.Values := Map()
    }

    Call(pid) {
        return this.Values.Has(pid) ? this.Values[pid] : ""
    }
}

AssertMaintenance(value, message) {
    if !value
        throw Error(message)
}

AssertMaintenanceEqual(expected, actual, message) {
    if (expected != actual)
        throw Error(message "（预期 " expected "，实际 " actual "）")
}

AssertMaintenanceThrows(callback, message) {
    didThrow := false
    try callback.Call()
    catch
        didThrow := true
    if !didThrow
        throw Error(message)
}

RunMaintenanceTests() {
    stateMachine := MaintenanceStateMachine()
    AssertMaintenanceEqual(MaintenancePhase.Normal, stateMachine.Phase,
        "升级保护状态机初始阶段错误")
    stateMachine.Transition(MaintenancePhase.Arbitrating)
    stateMachine.Transition(MaintenancePhase.Updating)
    stateMachine.Transition(MaintenancePhase.Stabilizing)
    stateMachine.Transition(MaintenancePhase.Normal)
    AssertMaintenance(!stateMachine.IsBlocking(),
        "恢复 Normal 后仍被视为升级阻塞")
    stateMachine.Transition(MaintenancePhase.Recovering)
    stateMachine.Transition(MaintenancePhase.TimedOut)
    AssertMaintenance(stateMachine.IsBlocking(),
        "TimedOut 必须继续阻止自动启动")
    AssertMaintenanceThrows(
        ObjBindMethod(stateMachine, "Transition", MaintenancePhase.Updating),
        "TimedOut 不应直接跳回 Updating")
    stateMachine.Transition(MaintenancePhase.Normal)
    AssertMaintenanceThrows(
        ObjBindMethod(stateMachine, "Transition", "UnknownPhase"),
        "状态机接受了未知升级保护阶段")
    AssertMaintenanceThrows(
        (*) => MaintenanceStateMachine("UnknownPhase"),
        "状态机接受了未知初始阶段")

    allowedTransitions := [
        [MaintenancePhase.Normal, MaintenancePhase.Arbitrating],
        [MaintenancePhase.Normal, MaintenancePhase.Updating],
        [MaintenancePhase.Normal, MaintenancePhase.Stabilizing],
        [MaintenancePhase.Normal, MaintenancePhase.Recovering],
        [MaintenancePhase.Arbitrating, MaintenancePhase.Updating],
        [MaintenancePhase.Arbitrating, MaintenancePhase.Normal],
        [MaintenancePhase.Arbitrating, MaintenancePhase.TimedOut],
        [MaintenancePhase.Updating, MaintenancePhase.Stabilizing],
        [MaintenancePhase.Updating, MaintenancePhase.Normal],
        [MaintenancePhase.Updating, MaintenancePhase.TimedOut],
        [MaintenancePhase.Stabilizing, MaintenancePhase.Updating],
        [MaintenancePhase.Stabilizing, MaintenancePhase.Normal],
        [MaintenancePhase.Stabilizing, MaintenancePhase.TimedOut],
        [MaintenancePhase.Recovering, MaintenancePhase.Updating],
        [MaintenancePhase.Recovering, MaintenancePhase.Stabilizing],
        [MaintenancePhase.Recovering, MaintenancePhase.Normal],
        [MaintenancePhase.Recovering, MaintenancePhase.TimedOut],
        [MaintenancePhase.TimedOut, MaintenancePhase.Normal]
    ]
    for transition in allowedTransitions {
        transitionMachine := MaintenanceStateMachine(transition[1])
        transitionMachine.Transition(transition[2])
        AssertMaintenanceEqual(transition[2], transitionMachine.Phase,
            "合法升级保护转换被拒绝")
    }
    forbiddenTransitions := [
        [MaintenancePhase.Normal, MaintenancePhase.TimedOut],
        [MaintenancePhase.Arbitrating, MaintenancePhase.Stabilizing],
        [MaintenancePhase.Updating, MaintenancePhase.Recovering],
        [MaintenancePhase.Stabilizing, MaintenancePhase.Recovering],
        [MaintenancePhase.Recovering, MaintenancePhase.Arbitrating],
        [MaintenancePhase.TimedOut, MaintenancePhase.Updating]
    ]
    for transition in forbiddenTransitions {
        transitionMachine := MaintenanceStateMachine(transition[1])
        AssertMaintenanceThrows(ObjBindMethod(transitionMachine,
            "Transition", transition[2]), "非法升级保护转换未被拒绝")
    }

    creationResolver := FakeCreationResolver()
    matcher := MaintenanceActorMatcher(creationResolver)
    rootPath := "C:\Program Files\Product"
    targetPath := rootPath "\Product.exe"

    updater := {pid: 501, parent: 0, name: "Updater.exe", cmd: "",
        exe: rootPath "\Updater.exe", creation: "SNAPSHOT-A"}
    creationResolver.Values[501] := "LIVE-A"
    updaterMatch := matcher.Match(updater, targetPath, rootPath, [])
    AssertMaintenance(updaterMatch.Matched,
        "安装根目录内的更新程序没有被识别")
    AssertMaintenanceEqual("installer-under-root", updaterMatch.Evidence,
        "更新程序根目录证据错误")
    AssertMaintenanceEqual(
        "P:c:\program files\product\updater.exe|R:c:\program files\product",
        updaterMatch.LearnableSignature,
        "学习特征没有绑定完整路径与作用根")

    outsideUpdater := {pid: 502, parent: 0, name: "Updater.exe", cmd: "",
        exe: "D:\Unrelated\Updater.exe", creation: "SNAPSHOT-B"}
    creationResolver.Values[502] := "LIVE-B"
    AssertMaintenance(!matcher.Match(outsideUpdater, targetPath, rootPath,
        []).Matched, "无关目录中的同名更新程序被错误识别")
    AssertMaintenance(!matcher.Match(outsideUpdater, targetPath, rootPath,
        ["N:updater.exe"]).Matched,
        "纯名称历史特征仍能触发升级保护")
    AssertMaintenanceEqual("", matcher.BuildLearningSignature({
        pid: 503, parent: 0, name: "Updater.exe", cmd: "", exe: ""
    }, rootPath), "缺少完整路径的演员不应生成永久特征")
    AssertMaintenance(matcher.PathIsWithinRoot("C:\Product\Updater.exe",
        "C:\"), "驱动器根目录未被识别为路径作用根")
    AssertMaintenance(!matcher.PathIsWithinRoot("C:\Product2\Updater.exe",
        "C:\Product"), "相邻目录被错误识别为路径作用根的子目录")

    helperPath := "C:\Shared\ProductMaintenance.exe"
    scopedSignature := "P:c:\shared\productmaintenance.exe"
        . "|R:c:\program files\product"
    helper := {pid: 504, parent: 0, name: "Helper.exe", cmd: "",
        exe: helperPath, creation: "SNAPSHOT-C"}
    creationResolver.Values[504] := "LIVE-C"
    AssertMaintenance(matcher.Match(helper, targetPath, rootPath,
        [scopedSignature]).Matched,
        "同一作用根的已学习完整路径没有命中")
    AssertMaintenance(!matcher.Match(helper,
        "D:\Other\Other.exe", "D:\Other", [scopedSignature]).Matched,
        "已学习路径越过其作用根命中其他目标")

    commandUpdater := {pid: 505, parent: 0, name: "setup.exe",
        cmd: '"C:\Tools\setup.exe" --root="C:\Program Files\Product"',
        exe: "C:\Tools\setup.exe", creation: "SNAPSHOT-D"}
    creationResolver.Values[505] := "LIVE-D"
    commandMatch := matcher.Match(commandUpdater, targetPath, rootPath, [])
    AssertMaintenance(commandMatch.Matched,
        "命令行引用安装根的安装程序没有被识别")
    AssertMaintenanceEqual("installer-references-root", commandMatch.Evidence,
        "命令行作用根证据错误")

    processMap := Map(
        100, {pid: 100, parent: 0, name: "Product.exe", cmd: "",
            exe: targetPath, creation: "TARGET"},
        200, {pid: 200, parent: 100, name: "Bridge.exe", cmd: "",
            exe: "C:\Tools\Bridge.exe", creation: "BRIDGE"})
    descendant := {pid: 506, parent: 200, name: "Worker.exe", cmd: "",
        exe: "C:\Tools\Worker.exe", creation: "WORKER"}
    creationResolver.Values[100] := "TARGET-LIVE"
    creationResolver.Values[506] := "WORKER-LIVE"
    descendantMatch := matcher.Match(descendant, targetPath, rootPath, [],
        100, "TARGET-LIVE", processMap, true)
    AssertMaintenance(descendantMatch.Matched,
        "升级期间的多级子进程没有按父链识别")
    AssertMaintenanceEqual("maintenance-descendant",
        descendantMatch.Evidence, "多级父链证据错误")
    descendantIdentity := matcher.CreateIdentity(descendant, rootPath,
        processMap)
    AssertMaintenanceEqual("506:WORKER-LIVE", descendantIdentity.Key,
        "演员身份没有组合 PID 与创建身份")
    AssertMaintenanceEqual(2, descendantIdentity.ParentChain.Length,
        "演员身份没有保留完整父链")

    currentPid := DllCall("kernel32\GetCurrentProcessId", "UInt")
    creationResolver.Values[currentPid] := "ORIGINAL"
    liveIdentity := MaintenanceActorIdentity(currentPid, "ORIGINAL",
        A_AhkPath, rootPath, [])
    AssertMaintenance(matcher.IsIdentityAlive(liveIdentity),
        "相同创建身份的活动演员被错误清除")
    creationResolver.Values[currentPid] := "REUSED"
    AssertMaintenance(!matcher.IsIdentityAlive(liveIdentity),
        "PID 复用后旧演员身份仍被视为活动")

    previousRecords := Map(liveIdentity.Key, {Identity: liveIdentity})
    creationResolver.Values[currentPid] := "ORIGINAL"
    retainedRecords := matcher.RetainLiveRecords(previousRecords, Map())
    AssertMaintenance(retainedRecords.Has(liveIdentity.Key),
        "快照短暂缺少证据时丢弃了仍可核对身份的演员")
    creationResolver.Values[currentPid] := "REUSED"
    retainedRecords := matcher.RetainLiveRecords(previousRecords, Map())
    AssertMaintenance(!retainedRecords.Has(liveIdentity.Key),
        "PID 复用后仍保留旧演员缓存")

    reusedTargetDescendant := {pid: 507, parent: currentPid,
        name: "Worker.exe", cmd: "", exe: "C:\Tools\Worker.exe",
        creation: "WORKER-2", maintenanceCandidate: true}
    AssertMaintenance(!matcher.Match(reusedTargetDescendant, targetPath,
        rootPath, [], currentPid, "ORIGINAL", Map(), true).Matched,
        "目标 PID 被复用后仍接受旧父子关系")
}

try {
    RunMaintenanceTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.File " (" testError.Line "): " testError.Message
        "`n", "**")
    ExitApp(1)
}
