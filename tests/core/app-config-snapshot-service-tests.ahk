#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\..\src\Config\IniFieldCodec.ahk
#Include ..\..\src\Config\DisplayConfigCodec.ahk
#Include ..\..\src\Config\MaintenanceConfigCodec.ahk
#Include ..\..\src\Config\AppConfigSnapshotService.ahk

AssertAppConfigSnapshot(value, message) {
    if !value
        throw Error(message)
}

class AppConfigSnapshotActorMatcher {
    NormalizeLearnedSignature(actor, *) {
        return Trim(String(actor))
    }
}

AppConfigSnapshotNormalizePath(path) {
    normalized := StrReplace(Trim(String(path)), "/", "\")
    return StrLen(normalized) > 3 ? RTrim(normalized, "\") : normalized
}

AppConfigSnapshotPathsEquivalent(firstPath, secondPath) {
    return StrLower(AppConfigSnapshotNormalizePath(firstPath))
        == StrLower(AppConfigSnapshotNormalizePath(secondPath))
}

AppConfigSnapshotDefaultRoot(path) {
    SplitPath(path, , &directory)
    return directory
}

AppConfigSnapshotSupportsTarget(path) {
    SplitPath(path, , , &extension)
    return StrLower(extension) == "exe"
}

AppConfigSnapshotNormalizeRoot(path, fallbackPath := "") {
    normalized := AppConfigSnapshotNormalizePath(path)
    return normalized != "" ? normalized
        : AppConfigSnapshotDefaultRoot(fallbackPath)
}

AppConfigSnapshotParseInteger(value, minValue, maxValue) {
    if !IsInteger(value)
        return 0
    parsed := Integer(value)
    return parsed >= minValue && parsed <= maxValue ? parsed : 0
}

CreateAppConfigSnapshotService() {
    displayCodec := DisplayConfigCodec(AppConfigSnapshotNormalizePath,
        AppConfigSnapshotPathsEquivalent)
    maintenanceCodec := MaintenanceConfigCodec({
        GetDefaultRoot: AppConfigSnapshotDefaultRoot,
        IsSupportedTarget: AppConfigSnapshotSupportsTarget,
        NormalizeRoot: AppConfigSnapshotNormalizeRoot,
        ParseBoundedInteger: AppConfigSnapshotParseInteger,
        PathsEquivalent: AppConfigSnapshotPathsEquivalent
    }, AppConfigSnapshotActorMatcher())
    return AppConfigSnapshotService(maintenanceCodec, displayCodec,
        AppConfigSnapshotNormalizePath, AppConfigSnapshotPathsEquivalent)
}

CreateAppConfigMaintenance(enabled := false, installRoot := "C:\Apps",
    actors := "") {
    return {
        Enabled: enabled,
        InstallRoot: installRoot,
        RootIsCustom: false,
        DetectionSeconds: 10,
        StableSeconds: 8,
        MaxWaitSeconds: 1800,
        LearnedActors: Type(actors) == "Array" ? actors : []
    }
}

RunAppConfigSnapshotServiceTests() {
    service := CreateAppConfigSnapshotService()
    shortcutPath := "C:\Links\Product.lnk"
    stateObj := {
        Enabled: 1,
        RunAsAdmin: 1,
        WorkDir: "C:\Work",
        Args: "--user",
        ShortcutArgs: "--embedded",
        EnvVars: "MODE=test",
        ResolvedTarget: "C:/Apps/Product.exe",
        ResolvedTargetManual: false,
        MaintenanceConfig: CreateAppConfigMaintenance(true, "C:\Apps",
            ["installer.exe"]),
        DisplayConfig: {Name: "产品", IconPath: "C:/Icons/Product.ico"}
    }
    snapshot := service.CreateSnapshot(shortcutPath, stateObj)
    AssertAppConfigSnapshot(snapshot.Path == shortcutPath
        && snapshot.ResolvedTarget == "C:\Apps\Product.exe"
        && snapshot.Maintenance.Enabled
        && snapshot.Display.IconPath == "C:\Icons\Product.ico",
        "快捷方式快照没有结合真实目标保留升级保护或规范化路径")
    stateObj.MaintenanceConfig.LearnedActors.Push("late-change.exe")
    AssertAppConfigSnapshot(snapshot.Maintenance.LearnedActors.Length == 1,
        "已捕获快照仍引用可变运行态维护数组")

    prepared := service.PrepareState([
        {Path: ""},
        snapshot,
        {Path: "c:/links/product.lnk", Enabled: 0}
    ])
    AssertAppConfigSnapshot(prepared.Items.Length == 1
        && prepared.Index.Has("C:\LINKS\PRODUCT.LNK"),
        "快照准备没有丢弃空路径或合并等价重复路径")

    equivalentSnapshot := service.CreateSnapshot(
        "c:/links/product.lnk", stateObj)
    equivalentSnapshot.Maintenance.LearnedActors.RemoveAt(2)
    AssertAppConfigSnapshot(service.SnapshotsEqual(snapshot,
        equivalentSnapshot), "等价路径的相同配置被错误识别为变化")
    equivalentSnapshot.Display.Name := "另一个名称"
    AssertAppConfigSnapshot(!service.SnapshotsEqual(snapshot,
        equivalentSnapshot), "展示自定义没有参与快照比较")

    secondSnapshot := service.CreateSnapshot("D:\Tools\Other.exe", "")
    AssertAppConfigSnapshot(service.StatesEqual([snapshot, secondSnapshot],
        [snapshot, secondSnapshot])
        && !service.StatesEqual([snapshot, secondSnapshot],
            [secondSnapshot, snapshot]),
        "快照状态比较没有保留用户可见顺序语义")

    firstOrderItem := service.CreateSnapshot("C:\A.exe", "")
    secondOrderItem := service.CreateSnapshot("C:\B.exe", "")
    extraBeforeItem := service.CreateSnapshot("C:\ExtraBefore.exe", "")
    extraAfterItem := service.CreateSnapshot("C:\ExtraAfter.exe", "")
    mergedOrder := service.MergeTransitionOrder(
        [firstOrderItem, extraBeforeItem, secondOrderItem, extraAfterItem],
        [firstOrderItem, secondOrderItem],
        [secondOrderItem, firstOrderItem])
    AssertAppConfigSnapshot(mergedOrder.Length == 4
        && mergedOrder[1].Path == extraBeforeItem.Path
        && mergedOrder[2].Path == secondOrderItem.Path
        && mergedOrder[3].Path == firstOrderItem.Path
        && mergedOrder[4].Path == extraAfterItem.Path,
        "差异恢复重排时丢失或错误放置了当前独有监控项")

    sourceMaintenance := CreateAppConfigMaintenance(false, "C:\Old",
        ["keep.exe", "remove.exe"])
    targetMaintenance := CreateAppConfigMaintenance(true, "D:\New",
        ["keep.exe", "add.exe"])
    targetMaintenance.StableSeconds := 12
    currentMaintenance := CreateAppConfigMaintenance(false, "C:\Old",
        ["keep.exe", "remove.exe", "concurrent.exe"])
    currentMaintenance.DetectionSeconds := 15
    mergedMaintenance := service.MergeMaintenanceTransition(
        currentMaintenance, sourceMaintenance, targetMaintenance)
    AssertAppConfigSnapshot(mergedMaintenance.Enabled
        && mergedMaintenance.InstallRoot == "D:\New"
        && mergedMaintenance.DetectionSeconds == 15
        && mergedMaintenance.StableSeconds == 12
        && mergedMaintenance.LearnedActors.Length == 3
        && mergedMaintenance.LearnedActors[1] == "keep.exe"
        && mergedMaintenance.LearnedActors[2] == "concurrent.exe"
        && mergedMaintenance.LearnedActors[3] == "add.exe",
        "维护配置三方合并覆盖了并发修改或丢失了学习证据")
    mergedWithoutRoot := service.MergeMaintenanceTransition(
        currentMaintenance, sourceMaintenance, targetMaintenance, false)
    AssertAppConfigSnapshot(mergedWithoutRoot.InstallRoot == "C:\Old",
        "身份迁移未被接受时仍错误迁移了升级保护目录")

    mergedDisplay := service.MergeDisplayTransition(
        {Name: "并发名称", IconPath: "C:\Old.ico"},
        {Name: "旧名称", IconPath: "C:\Old.ico"},
        {Name: "新名称", IconPath: "D:\New.ico"})
    AssertAppConfigSnapshot(mergedDisplay.Name == "并发名称"
        && mergedDisplay.IconPath == "D:\New.ico",
        "展示配置三方合并没有逐字段保护并发修改")
}

try {
    RunAppConfigSnapshotServiceTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
