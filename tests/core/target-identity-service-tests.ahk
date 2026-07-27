#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证目标身份冲突检测和快捷方式身份刷新事务。
; 刷新期间控制器若被替换或新身份与现有项目冲突，任何候选结果都不能提交。

#Include ..\..\src\Core\TargetSpecs.ahk
#Include ..\..\src\Core\TargetIdentityService.ahk

AssertTargetIdentityService(value, message) {
    if !value
        throw Error(message)
}

class TargetIdentityTestSpecsService {
    __New() {
        this.GetCount := 0
        this.ForceCount := 0
    }

    Get(path, stateObj := "", forceRefresh := false) {
        this.GetCount += 1
        if forceRefresh
            this.ForceCount += 1
        resolvedTarget := IsObject(stateObj)
            && stateObj.HasOwnProp("ResolvedTarget")
                ? stateObj.ResolvedTarget : ""
        probeKind := IsObject(stateObj) && stateObj.HasOwnProp("ProbeKind")
            ? stateObj.ProbeKind
            : (resolvedTarget != "" ? TargetProbeKind.ImagePath
                : TargetProbeKind.Unknown)
        available := !IsObject(stateObj) || !stateObj.HasOwnProp("Available")
            || stateObj.Available
        return {
            ResolvedTarget: resolvedTarget,
            Probe: {Kind: probeKind, TargetPath: resolvedTarget},
            Launch: {Available: available}
        }
    }
}

class TargetIdentityTestShortcutResolver {
    __New() {
        this.NextTarget := ""
        this.Source := "测试来源"
        this.Arguments := ""
        this.Readable := true
        this.ResolveCount := 0
        this.ReadCount := 0
        this.OnResolve := ""
    }

    ResolveEffective(path, allowMissing, &resolutionSource) {
        this.ResolveCount += 1
        resolutionSource := this.Source
        if this.OnResolve
            this.OnResolve.Call(path)
        return this.NextTarget
    }

    Read(*) {
        this.ReadCount += 1
        return {Readable: this.Readable, Arguments: this.Arguments}
    }
}

class TargetIdentityTestFileInspector {
    __New() {
        this.Count := 0
    }

    GetFingerprint(path) {
        this.Count += 1
        return "FP:" path
    }
}

class TargetIdentityTestCoordinator {
    __New() {
        this.CloseCount := 0
        this.EnsureCount := 0
    }

    CloseWatcher(*) {
        this.CloseCount += 1
    }

    EnsureWatcher(*) {
        this.EnsureCount += 1
    }
}

TargetIdentityTestCanonical(path) {
    path := StrLower(StrReplace(Trim(String(path)), "/", "\"))
    return StrLen(path) > 3 ? RTrim(path, "\") : path
}

TargetIdentityTestPathsEquivalent(firstPath, secondPath) {
    if (firstPath == "" || secondPath == "")
        return firstPath == secondPath
    return TargetIdentityTestCanonical(firstPath)
        == TargetIdentityTestCanonical(secondPath)
}

TargetIdentityTestNormalizeRoot(path) {
    path := StrReplace(Trim(String(path)), "/", "\")
    return StrLen(path) > 3 ? RTrim(path, "\") : path
}

TargetIdentityTestNow(clock) {
    return clock.Value
}

TargetIdentityTestLog(messages, message) {
    messages.Push(message)
}

TargetIdentityTestInvalidate(counter, path, stateObj) {
    counter.Count++
    counter.LastPath := path
    counter.LastState := stateObj
    return true
}

TargetIdentityReplaceState(runtime, path, replacement, *) {
    runtime.appStates[path] := replacement
}

CreateTargetIdentityState(targetPath, shortcutArguments := "--old") {
    return {
        ResolvedTarget: targetPath,
        ResolvedTargetManual: false,
        ShortcutResolveCheckedTicks: 0,
        ShortcutTargetSource: "旧来源",
        ShortcutArgs: shortcutArguments,
        MaintenanceConfig: {
            RootIsCustom: false,
            InstallRoot: "C:\Old"
        },
        SafetyFingerprint: "OLD-FP",
        MaintenanceBaselineFingerprint: "OLD-BASE",
        SafetyStableSince: 1,
        MaintenanceFingerprintCheckedTicks: 1,
        MaintenanceReadyCheckedTicks: 1,
        Available: true
    }
}

RunTargetIdentityServiceTests() {
    runtime := {
        appStates: Map(),
        targetSpecsService: TargetIdentityTestSpecsService(),
        shortcutTargetResolver: TargetIdentityTestShortcutResolver(),
        targetFileInspector: TargetIdentityTestFileInspector(),
        maintenanceCoordinator: TargetIdentityTestCoordinator()
    }
    runtime.appStates.CaseSense := "Off"
    clock := {Value: 100000}
    messages := []
    invalidations := {Count: 0, LastPath: "", LastState: ""}
    service := TargetIdentityService(runtime, {
        InvalidateRuntimeIdentity: TargetIdentityTestInvalidate.Bind(
            invalidations),
        Log: TargetIdentityTestLog.Bind(messages),
        NormalizeRoot: TargetIdentityTestNormalizeRoot,
        Now: TargetIdentityTestNow.Bind(clock),
        PathsEquivalent: TargetIdentityTestPathsEquivalent
    })
    linkPath := "C:\Links\App.lnk"
    otherPath := "C:\Links\Other.lnk"
    stateObj := CreateTargetIdentityState("C:\Old\App.exe")
    otherState := CreateTargetIdentityState("C:\Taken\App.exe")
    runtime.appStates[linkPath] := stateObj
    runtime.appStates[otherPath] := otherState

    AssertTargetIdentityService(
        service.GetMonitoredTargetPath("C:\Direct\App.exe")
            == "C:\Direct\App.exe"
        && service.GetMonitoredTargetPath(linkPath) == stateObj.ResolvedTarget
        && service.GetMaintenanceSubjectPath(linkPath)
            == stateObj.ResolvedTarget,
        "监控目标和维护目标没有统一使用真实快捷方式身份")
    AssertTargetIdentityService(
        service.FindConflict("c:/taken/app.exe") == otherPath
        && service.FindConflict("C:\Taken\App.exe", otherPath) == "",
        "重复真实身份检测或排除路径错误")
    otherState.ProbeKind := TargetProbeKind.ProcessName
    AssertTargetIdentityService(
        service.FindConflict("C:\Taken\App.exe") == "",
        "非精确进程名探活被错误用于身份冲突")
    otherState.ProbeKind := TargetProbeKind.ImagePath
    AssertTargetIdentityService(service.TargetReferenceExists(linkPath,
        stateObj), "可启动目标被错误识别为不可用")
    stateObj.Available := false
    AssertTargetIdentityService(!service.TargetReferenceExists(linkPath,
        stateObj), "不可启动目标被错误识别为可用")
    stateObj.Available := true

    stateObj.ShortcutResolveCheckedTicks := clock.Value - 1000
    runtime.shortcutTargetResolver.NextTarget := "D:\New\App.exe"
    AssertTargetIdentityService(!service.RefreshShortcut(linkPath, stateObj)
        && runtime.shortcutTargetResolver.ResolveCount == 0,
        "刷新节流窗口内仍执行了昂贵的快捷方式解析")
    stateObj.ResolvedTargetManual := true
    AssertTargetIdentityService(!service.RefreshShortcut(linkPath, stateObj,
        true) && runtime.shortcutTargetResolver.ResolveCount == 0,
        "手工真实身份被自动解析覆盖")
    stateObj.ResolvedTargetManual := false

    stateObj.ShortcutResolveCheckedTicks := 0
    runtime.shortcutTargetResolver.NextTarget := otherState.ResolvedTarget
    runtime.shortcutTargetResolver.Source := "冲突来源"
    runtime.shortcutTargetResolver.Arguments := "--conflicting"
    beforeConflict := {
        Target: stateObj.ResolvedTarget,
        Args: stateObj.ShortcutArgs,
        Source: stateObj.ShortcutTargetSource,
        Root: stateObj.MaintenanceConfig.InstallRoot,
        Fingerprint: stateObj.SafetyFingerprint
    }
    AssertTargetIdentityService(!service.RefreshShortcut(linkPath, stateObj,
        true), "冲突的真实身份仍被写入控制器")
    AssertTargetIdentityService(
        stateObj.ResolvedTarget == beforeConflict.Target
        && stateObj.ShortcutArgs == beforeConflict.Args
        && stateObj.ShortcutTargetSource == beforeConflict.Source
        && stateObj.MaintenanceConfig.InstallRoot == beforeConflict.Root
        && stateObj.SafetyFingerprint == beforeConflict.Fingerprint,
        "身份冲突失败路径部分污染了控制器配置")

    runtime.shortcutTargetResolver.NextTarget := "c:/old/app.exe"
    runtime.shortcutTargetResolver.Source := "快捷方式目标"
    runtime.shortcutTargetResolver.Arguments := "--changed"
    forceCountBefore := runtime.targetSpecsService.ForceCount
    Critical("On")
    try {
        AssertTargetIdentityService(service.RefreshShortcut(linkPath,
            stateObj, true), "快捷方式参数变化没有被报告")
        AssertTargetIdentityService(A_IsCritical != 0,
            "身份刷新破坏了调用方临界状态")
    } finally Critical("Off")
    AssertTargetIdentityService(stateObj.ShortcutArgs == "--changed"
        && stateObj.ShortcutTargetSource == "快捷方式目标"
        && runtime.targetSpecsService.ForceCount == forceCountBefore + 1
        && invalidations.Count == 0,
        "同一真实身份的参数更新没有精准失效规格缓存")

    clock.Value := 200000
    runtime.shortcutTargetResolver.NextTarget := "D:\New\App.exe"
    runtime.shortcutTargetResolver.Source := "安装目录特征"
    runtime.shortcutTargetResolver.Arguments := "--new"
    AssertTargetIdentityService(service.RefreshShortcut(linkPath, stateObj,
        true), "新的非冲突真实身份没有刷新")
    AssertTargetIdentityService(stateObj.ResolvedTarget == "D:\New\App.exe"
        && stateObj.ShortcutArgs == "--new"
        && stateObj.MaintenanceConfig.InstallRoot == "D:\New"
        && stateObj.SafetyFingerprint == "FP:D:\New\App.exe"
        && stateObj.MaintenanceBaselineFingerprint
            == stateObj.SafetyFingerprint
        && stateObj.SafetyStableSince == clock.Value
        && stateObj.MaintenanceFingerprintCheckedTicks == clock.Value
        && stateObj.MaintenanceReadyCheckedTicks == 0
        && invalidations.Count == 1
        && invalidations.LastPath == linkPath
        && invalidations.LastState == stateObj
        && runtime.maintenanceCoordinator.CloseCount == 1
        && runtime.maintenanceCoordinator.EnsureCount == 1,
        "真实身份迁移没有原子更新目录、指纹或监听器")

    stateObj.MaintenanceConfig.RootIsCustom := true
    stateObj.MaintenanceConfig.InstallRoot := "X:\Custom"
    runtime.shortcutTargetResolver.NextTarget := "E:\Another\App.exe"
    AssertTargetIdentityService(service.RefreshShortcut(linkPath, stateObj,
        true) && stateObj.MaintenanceConfig.InstallRoot == "X:\Custom"
        && runtime.maintenanceCoordinator.CloseCount == 1,
        "自定义维护目录被真实身份刷新覆盖")

    staleState := stateObj
    replacement := CreateTargetIdentityState("Z:\Replacement\App.exe")
    runtime.appStates[linkPath] := staleState
    runtime.shortcutTargetResolver.NextTarget := "F:\Late\App.exe"
    runtime.shortcutTargetResolver.OnResolve := TargetIdentityReplaceState.Bind(
        runtime, linkPath, replacement)
    staleTargetBefore := staleState.ResolvedTarget
    AssertTargetIdentityService(!service.RefreshShortcut(linkPath, staleState,
        true) && staleState.ResolvedTarget == staleTargetBefore
        && replacement.ResolvedTarget == "Z:\Replacement\App.exe",
        "解析期间被替换的旧控制器仍写入了迟到结果")
    runtime.shortcutTargetResolver.OnResolve := ""
}

try {
    RunTargetIdentityServiceTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
