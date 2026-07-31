#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证主脚本装配后的关键集成契约，不启动真实守护循环。
; 覆盖配置、目标规格、重载命令和界面适配，防止迁移后入口仍调用旧实现。

try {
    RunMainIntegrationTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.File " (" testError.Line "): " testError.Message
        "`n" testError.Stack "`n", "**")
    ExitApp(1)
}

#Include ..\..\进程守护小助手.ahk

class SnapshotDeliveryTestSink {
    __New() {
        this.Count := 0
    }

    OnSnapshotPublished(*) {
        this.Count++
        return true
    }
}

class UnavailableIdentityTestInspector {
    GetCreationIdentity(*) {
        return ""
    }

    GetImagePath(*) {
        return "C:\observed.exe"
    }
}

class ReentrantWatchlistPersistenceTestService {
    __New(innerService, targetPath) {
        this.InnerService := innerService
        this.TargetPath := targetPath
        this.SaveCount := 0
    }

    Save(parameters*) {
        global App
        this.SaveCount++
        saveResult := this.InnerService.Save(parameters*)
        if this.SaveCount == 1 {
            App.appStates[this.TargetPath].Args := "--二次修改"
            if !SaveAppsToIni()
                throw Error("保存重入请求没有被接受")
        }
        return saveResult
    }
}

RunWatchPathTransitionSnapshotTests() {
    global App
    previousPath := A_Temp "\watchdog-relocation-before.py"
    requestedPath := A_Temp "\watchdog-relocation-after.py"
    installRoot := A_Temp "\watchdog-relocation-product"
    learnedActor := "P:" installRoot "\updater.exe|R:" installRoot
    maintenanceConfig := App.maintenanceConfigCodec.CreateDefault(previousPath)
    maintenanceConfig.Enabled := true
    maintenanceConfig.RootIsCustom := true
    maintenanceConfig.InstallRoot := installRoot
    maintenanceConfig.DetectionSeconds := 17
    maintenanceConfig.StableSeconds := 23
    maintenanceConfig.MaxWaitSeconds := 2400
    maintenanceConfig.LearnedActors := [learnedActor]
    displayConfig := {
        Name: "迁移测试自定义名称",
        IconPath: A_AhkPath
    }
    stateObj := TargetSupervisor({
        Enabled: false,
        RunAsAdmin: true,
        WorkDir: A_Temp,
        Args: "--profile relocation",
        EnvVars: "WATCHDOG_RELOCATION=1",
        RuntimePath: A_AhkPath,
        RuntimeArgs: "/ErrorStdOut",
        ResolvedTarget: "",
        ResolvedTargetManual: false,
        ShortcutArgs: "",
        MaintenanceConfig: maintenanceConfig,
        DisplayConfig: displayConfig,
        Scheduler: App.scheduler
    })
    App.appStates[previousPath] := stateObj
    try {
        beforeState := [App.appConfigSnapshotService.CreateSnapshot(
            previousPath, stateObj)]
        transition := PrepareWatchPathTransitionFromState(previousPath,
            requestedPath, beforeState)
        if !transition.Changed || transition.TargetState.Length != 1
            throw Error("路径迁移没有生成唯一目标快照")
        migrated := transition.TargetState[1]
        expectedMaintenance := App.maintenanceConfigCodec.NormalizeSnapshot(
            maintenanceConfig, requestedPath, "")
        if !PathsEquivalent(migrated.Path, requestedPath)
            || migrated.Enabled != 0 || migrated.RunAsAdmin != 1
            || migrated.WorkDir != A_Temp
            || migrated.Args != "--profile relocation"
            || migrated.EnvVars != "WATCHDOG_RELOCATION=1"
            || !PathsEquivalent(migrated.RuntimePath, A_AhkPath)
            || migrated.RuntimeArgs != "/ErrorStdOut"
            || !App.displayConfigCodec.Equals(migrated.Display,
                displayConfig)
            || !App.maintenanceConfigCodec.Equals(migrated.Maintenance,
                expectedMaintenance) {
            throw Error("路径迁移丢失名称、图标、参数、环境、运行时或升级保护配置")
        }

        history := AppConfigHistoryService(App.appConfigSnapshotService)
        action := CreateAppHistoryAction("relocate-path",
            [previousPath, requestedPath])
        if !history.Commit(transition.BeforeState, transition.TargetState,
                action)
            || !history.Undo((*) => true, &undoEntry)
            || undoEntry.Action.Kind != "relocate-path"
            || undoEntry.Action.Paths.Length != 2
            || !history.Redo((*) => true, &redoEntry)
            || redoEntry != undoEntry {
            throw Error("路径迁移没有建立可撤销且可重做的独立历史记录")
        }
    } finally {
        if App.appStates.Has(previousPath)
            App.appStates.Delete(previousPath)
    }
}

RunMainIntegrationTests() {
    global App
    ; 本用例校验中文界面的全角标点契约，不依赖执行测试的 Windows 语言。
    LocalizationService.Configure("zh-CN")
    App := ApplicationState()
    RunWatchPathTransitionSnapshotTests()
    maintenanceSink := SnapshotDeliveryTestSink()
    guardSink := SnapshotDeliveryTestSink()
    originalMaintenanceCoordinator := App.maintenanceCoordinator
    originalGuardRuntime := App.guardRuntime
    App.maintenanceCoordinator := maintenanceSink
    App.guardRuntime := guardSink
    deliverySnapshot := []
    deliveryIndex := ProcessSnapshotIndex([], GetTickCount64(), true)
    if !App.guardWorkGate.TryEnter()
        throw Error("快照串行交付测试无法占用共享工作门")
    try {
        if App.OnProcessSnapshotPublished(deliverySnapshot, deliveryIndex)
            throw Error("共享工作门繁忙时后台快照越过串行边界修改了核心状态")
        if maintenanceSink.Count || guardSink.Count
            throw Error("共享工作门繁忙时后台快照已被提前交付")
    } finally App.guardWorkGate.Leave()
    if !App.DeliverPendingProcessSnapshot()
        || maintenanceSink.Count != 1 || guardSink.Count != 1 {
        throw Error("共享工作门释放后待处理快照没有且仅有一次串行交付")
    }
    App.maintenanceCoordinator := originalMaintenanceCoordinator
    App.guardRuntime := originalGuardRuntime
    if GetGuardActivationStatus(true) != Tr("初始化...")
        || GetGuardActivationStatus(false) != Tr("⏸️ 已暂停") {
        throw Error("启用和暂停目标没有使用唯一的初始状态映射")
    }
    if FormatMainStatusLabel("⚠️ 运行中 (权限不符)")
        != "运行中（权限不符）" {
        throw Error("主列表没有规范化空格加半角括号")
    }
    if FormatMainListLabel("uTools", true)
            != FormatMainListLabel("uTools", false)
        || InStr(FormatMainListLabel("uTools", true), "🛡️")
        || !InStr(FileRead(A_ScriptDir
            "\..\..\app\UI\MainVisualPipeline.ahk", "UTF-8"),
            "Win32.SIID_SHIELD") {
        throw Error("主列表管理员状态没有使用 Windows 原生 UAC 盾牌")
    }
    systemIntegrationSource := FileRead(A_ScriptDir
        "\..\..\app\SystemIntegration.ahk", "UTF-8")
    if InStr(systemIntegrationSource, "计划任务状态已更新。")
        throw Error("计划任务成功后仍会显示多余的状态更新弹窗")
    if InStr(systemIntegrationSource,
            "桌面与开始菜单快捷方式创建成功！") {
        throw Error("创建快捷方式成功后仍会显示多余的成功弹窗")
    }
    normalizedText := NormalizeUserVisibleParentheses(
        "操作失败 (错误 5)，稍后重试 (文件忙)")
    if normalizedText != "操作失败（错误 5），稍后重试（文件忙）"
        throw Error("动态用户文本没有完整转换全角括号")
    if !IsScrollBarHitTestCode(Win32.HTHSCROLL)
        || !IsScrollBarHitTestCode(Win32.HTVSCROLL)
        || IsScrollBarHitTestCode(1) {
        throw Error("滚动条命中区域没有稳定映射为普通光标")
    }
    if OnSetCursor(0, Win32.HTHSCROLL,
        Win32.WM_SETCURSOR, 0) != 1 {
        throw Error("滚动条命中消息没有被普通光标处理器接管")
    }
    sampleRectangle := {Left: 10, Top: 20, Right: 30, Bottom: 40}
    if !PointInsideScreenRectangle(10, 20, sampleRectangle)
        || !PointInsideScreenRectangle(29, 39, sampleRectangle)
        || PointInsideScreenRectangle(30, 40, sampleRectangle) {
        throw Error("滚动条屏幕矩形边界判断错误")
    }
    currentPid := DllCall("kernel32\GetCurrentProcessId", "UInt")
    if !IsApplicationNotificationClick(Win32.NIN_BALLOONUSERCLICK,
        A_ScriptHwnd) {
        throw Error("当前脚本的通知点击没有被识别")
    }
    if IsApplicationNotificationClick(Win32.NIN_BALLOONUSERCLICK,
        A_ScriptHwnd + 1) {
        throw Error("其他窗口的托盘回调被错误识别为本应用通知点击")
    }
    if IsApplicationNotificationClick(Win32.NIN_BALLOONUSERCLICK - 1,
        A_ScriptHwnd) {
        throw Error("非点击托盘事件被错误识别为通知点击")
    }
    configDiagnostic := BuildConfigLoadDiagnostic([{
        Key: "App7", Section: "Maintenance", Field: "升级保护配置",
        Reason: "编码损坏", Target: "C:\Tools\Example.exe"
    }], "C:\Config\watchdog.ini")
    for expectedDetail in ["[Maintenance] App7", "C:\Tools\Example.exe",
        "升级保护配置：编码损坏", "本次未加入守护列表",
        "C:\Config\watchdog.ini", "[Recovery]"] {
        if !InStr(configDiagnostic, expectedDetail)
            throw Error("配置加载诊断缺少用户可操作信息：" expectedDetail)
    }
    expectedValidationCommand := Format('"{1}" /ErrorStdOut "{2}" --startup-validation',
        A_AhkPath, A_ScriptFullPath)
    if BuildReloadValidationCommand(A_AhkPath, A_ScriptFullPath)
        != expectedValidationCommand {
        throw Error("重载解析命令没有正确拼接解释器和脚本路径")
    }
    expectedHandoffCommand := Format('"{1}" "{2}" --reload-handoff {3}',
        A_AhkPath, A_ScriptFullPath, currentPid)
    if BuildReloadHandoffCommand(currentPid, false, A_AhkPath,
        A_ScriptFullPath) != expectedHandoffCommand {
        throw Error("源码脚本重载交接命令拼接错误")
    }
    expectedCompiledHandoff := Format('"{1}" --reload-handoff {2}',
        A_ScriptFullPath, currentPid)
    if BuildReloadHandoffCommand(currentPid, true, A_AhkPath,
        A_ScriptFullPath) != expectedCompiledHandoff {
        throw Error("编译程序重载交接命令拼接错误")
    }
    messageLayout := CalculateDarkDialogLayout(300, 74, [70])
    if messageLayout.IconY != 42 || messageLayout.MessageY != 20
        || messageLayout.ButtonXs[1] != 115 {
        throw Error("长文本消息框没有垂直居中图标或水平居中确定按钮")
    }
    confirmLayout := CalculateDarkDialogLayout(360, 18, [100, 100], 22)
    if confirmLayout.IconY != 20 || confirmLayout.MessageY != 26
        || confirmLayout.ButtonXs[1] != 74
        || confirmLayout.ButtonXs[2] != 186 {
        throw Error("确认框没有垂直居中正文或水平居中按钮组")
    }
    readyDirectory := A_Temp "\ProcessWatchdogUpdateApply-"
        . currentPid "-integration"
    readyPath := readyDirectory "\application-ready.signal"
    DirCreate(readyDirectory)
    try {
        if ValidateApplicationUpdateReadyPath(readyPath) == ""
            throw Error("合法更新就绪信号路径被拒绝")
        if ValidateApplicationUpdateReadyPath(
                A_Temp "\outside-ready.signal") != ""
            throw Error("安装助手目录外的就绪信号路径被接受")
        if !WriteApplicationUpdateReadySignal(readyPath, "9.8.7")
            throw Error("更新就绪信号无法原子写入")
        if Trim(FileRead(readyPath, "UTF-8")) != "READY|9.8.7"
            throw Error("更新就绪信号内容与目标版本不一致")
    } finally {
        try DirDelete(readyDirectory, true)
    }
    projectRoot := A_ScriptDir "\..\.."
    projectMainScript := projectRoot "\进程守护小助手.ahk"
    executableValidationCommand := BuildReloadValidationCommand(A_AhkPath,
        projectMainScript)
    if RunWait(executableValidationCommand, projectRoot, "Hide") != 0
        throw Error("重载解析命令无法实际执行主脚本验证模式")
    sandboxConfigPath := A_Temp "\watchdog-main-sandbox-" currentPid ".ini"
    try FileDelete(sandboxConfigPath)
    App.SetConfigRepository(WatchdogConfigRepository(sandboxConfigPath))
    currentCreation := App.processInspector.GetCreationIdentity(currentPid)
    stateObj := {
        PID: currentPid,
        LastKnownPID: currentPid,
        PIDCreationIdentity: "STALE-CREATION-ID",
        PIDImagePath: "C:\stale.exe",
        LastKnownPIDCreationIdentity: "STALE-CREATION-ID",
        PIDElevationState: 0,
        PIDElevationChecked: true
    }
    SetStateProcessIdentity(stateObj, currentPid)
    if (currentCreation != "" && stateObj.PIDCreationIdentity != currentCreation)
        throw Error("相同数字的复用 PID 没有刷新创建身份")
    originalProcessInspector := App.processInspector
    App.processInspector := UnavailableIdentityTestInspector()
    try {
        observedState := {
            PID: 0, LastKnownPID: 0, PIDCreationIdentity: "",
            PIDImagePath: "", LastKnownPIDCreationIdentity: "",
            PIDElevationState: -1, PIDElevationChecked: false
        }
        SetStateProcessIdentity(observedState, currentPid,
            "OBSERVED-CREATION-ID")
        if observedState.PIDCreationIdentity != "OBSERVED-CREATION-ID"
            throw Error("进程身份二次查询失败时丢失了探测层已核验的创建身份")
    } finally App.processInspector := originalProcessInspector

    fakeShortcut := A_Temp "\codex-missing-shortcut.lnk"
    App.appStates[fakeShortcut] := TargetSupervisor({
        ResolvedTarget: A_AhkPath, ShortcutArgs: "--shortcut",
        Args: "--user", WorkDir: A_Temp, EnvVars: "", RunAsAdmin: false,
        OneShot: false, ShortcutResolveCheckedTicks: 0
    })
    snapshotIndex := CreateProcessSnapshotIndex([{
        pid: currentPid, parent: 0, name: "AutoHotkey64.exe",
        cmd: '"' A_AhkPath '"', exe: A_AhkPath,
        creation: currentCreation, observedTicks: GetTickCount64()
    }], GetTickCount64(), true)
    try {
        observation := ObserveTarget(fakeShortcut, snapshotIndex)
        if !observation.IsRunning() || observation.PID != currentPid
            throw Error("缺失快捷方式没有使用已保存的真实目标探活")
        missingShortcutPlan := App.targetSpecsService.Get(fakeShortcut,
            App.appStates[fakeShortcut], true)
        if (missingShortcutPlan.Launch.TargetPath != A_AhkPath)
            throw Error("缺失快捷方式没有回退到已保存的真实启动目标")
        if (missingShortcutPlan.Launch.Arguments != "--shortcut --user")
            throw Error("快捷方式回退启动没有正确合并参数")
        cachedShortcutPlan := App.targetSpecsService.Get(fakeShortcut,
            App.appStates[fakeShortcut])
        if (ObjPtr(cachedShortcutPlan) != ObjPtr(missingShortcutPlan))
            throw Error("未变化的目标规格没有复用缓存实例")
        App.appStates[fakeShortcut].Args := "--changed"
        changedShortcutPlan := App.targetSpecsService.Get(fakeShortcut,
            App.appStates[fakeShortcut])
        if (ObjPtr(changedShortcutPlan) == ObjPtr(missingShortcutPlan)
            || changedShortcutPlan.Launch.Arguments
                != "--shortcut --changed")
            throw Error("启动参数变化后目标规格缓存没有失效")
    } finally {
        App.appStates.Delete(fakeShortcut)
    }

    unresolvedShortcut := A_Temp "\codex-unresolved-shortcut.lnk"
    App.appStates[unresolvedShortcut] := TargetSupervisor({
        ResolvedTarget: "", ShortcutArgs: "", Args: "", WorkDir: "",
        EnvVars: "", RunAsAdmin: false, OneShot: false,
        ShortcutResolveCheckedTicks: 0
    })
    try {
        observation := ObserveTarget(unresolvedShortcut, snapshotIndex)
        if observation.IsRunning()
            throw Error("无身份的缺失快捷方式被错误识别为运行中")
        if !observation.IsUnknown()
            throw Error("无身份的缺失快捷方式没有返回不确定状态")
    } finally {
        App.appStates.Delete(unresolvedShortcut)
    }

    scriptTarget := "C:\Jobs\observation-test.py"
    App.appStates[scriptTarget] := TargetSupervisor({
        Args: "", WorkDir: "", EnvVars: "", RunAsAdmin: false,
        OneShot: false, ShortcutResolveCheckedTicks: 0
    })
    try {
        incompleteIndex := CreateProcessSnapshotIndex([{
            pid: currentPid, parent: 0, name: "python.exe", cmd: "",
            exe: "C:\Python\python.exe", creation: currentCreation,
            observedTicks: GetTickCount64()
        }], GetTickCount64(), true)
        incompleteObservation := ObserveTarget(scriptTarget,
            incompleteIndex)
        if !incompleteObservation.IsUnknown()
            throw Error("候选解释器命令行缺失时没有返回 Unknown")

        completeEmptyIndex := CreateProcessSnapshotIndex([], GetTickCount64(),
            true)
        stoppedObservation := ObserveTarget(scriptTarget,
            completeEmptyIndex)
        if !stoppedObservation.IsStopped()
            throw Error("完整快照没有候选进程时没有返回 Stopped")
    } finally {
        App.appStates.Delete(scriptTarget)
    }

    reusedPath := A_Temp "\codex-reused-target.exe"
    oldSupervisor := TargetSupervisor({Enabled: 1})
    oldTask := TargetScheduledTask("Restart", oldSupervisor.Generation)
    oldSupervisor.RestartTask := oldTask
    App.appStates[reusedPath] := oldSupervisor
    if !App.guardRuntime.IsScheduledTaskCurrent(reusedPath, oldSupervisor,
        oldTask,
        "Restart")
        throw Error("当前控制器的任务令牌未被接受")
    replacementSupervisor := TargetSupervisor({Enabled: 1})
    App.appStates[reusedPath] := replacementSupervisor
    try {
        if App.guardRuntime.IsScheduledTaskCurrent(reusedPath, oldSupervisor,
            oldTask,
            "Restart")
            throw Error("删除后同路径重建错误接纳了旧控制器任务")
        if UpdateState(reusedPath, "旧状态", oldSupervisor) != false
            throw Error("旧控制器仍能通过主界面状态回调覆盖新守护对象")
        if UpdateRunningState(reusedPath, oldSupervisor) != false
            throw Error("旧控制器仍能通过运行状态回调覆盖新守护对象")
    } finally {
        oldSupervisor.CancelScheduledTasks()
        App.appStates.Delete(reusedPath)
    }

    realShortcut := A_Temp "\watchdog-main-integration-" A_TickCount ".lnk"
    try {
        embeddedArguments := '"' A_ScriptFullPath '" --inner'
        FileCreateShortcut(A_AhkPath, realShortcut, A_Temp,
            embeddedArguments)
        resolutionSource := ""
        resolvedTarget := App.shortcutTargetResolver.ResolveForState(
            realShortcut, "", &resolutionSource)
        if !PathsEquivalent(resolvedTarget, A_ScriptFullPath)
            throw Error("真实快捷方式没有解析到实际目标：" resolvedTarget
                "（来源：" resolutionSource "，预期：" A_ScriptFullPath "）")
        realShortcutState := {
            ResolvedTarget: resolvedTarget, ShortcutArgs: embeddedArguments,
            Args: "--outer", WorkDir: A_Temp, EnvVars: "",
            RunAsAdmin: false, OneShot: false,
            ShortcutResolveCheckedTicks: 0
        }
        existingShortcutPlan := App.targetSpecsService.Get(realShortcut,
            realShortcutState, true)
        if !PathsEquivalent(existingShortcutPlan.Launch.TargetPath, realShortcut)
            throw Error("存在的快捷方式没有保持为启动入口")
        if (existingShortcutPlan.Launch.Arguments != "--outer")
            throw Error("通过快捷方式启动时重复追加了内置参数")
        if !PathsEquivalent(existingShortcutPlan.Probe.TargetPath,
            A_ScriptFullPath)
            throw Error("快捷方式启动入口和进程探活身份没有分离")
    } finally {
        try FileDelete(realShortcut)
    }

    staleTicks := GetTickCount64() - 6000
    staleSnapshot := [{
        pid: currentPid, parent: 0, name: "AutoHotkey64.exe",
        cmd: '"' A_AhkPath '"', exe: A_AhkPath,
        creation: currentCreation, observedTicks: staleTicks
    }]
    staleIndex := CreateProcessSnapshotIndex(staleSnapshot, staleTicks, true)
    App.processSnapshots.StoreSnapshot(staleSnapshot, staleTicks, true,
        staleIndex)
    App.processSnapshots.WorkerPid := currentPid
    App.processSnapshots.WorkerCreationIdentity := currentCreation
    App.processSnapshots.WorkerPath := A_Temp "\watchdog-stale-snapshot-test-"
        GetTickCount64() ".tmp"
    App.processSnapshots.WorkerStartedTicks := GetTickCount64()
    try {
        staleResult := App.processSnapshots.GetIndex(5000)
        if staleResult != ""
            throw Error("超过最大年龄的进程快照仍被用于守护决策")
    } finally {
        App.processSnapshots.ResetWorkerState(false)
    }

    scanResultPath := A_Temp "\watchdog-scan-result-test-" currentPid ".tmp"
    try {
        try FileDelete(scanResultPath)
        FileAppend("COMPLETE|1`r`n"
            IniFieldCodec.Encode(A_AhkPath) "`r`n", scanResultPath,
            "UTF-16")
        scanPaths := App.fileScanner.ReadResult(scanResultPath, &scanTruncated,
            &scanReady)
        if (!scanReady || scanTruncated || scanPaths.Length != 1
            || scanPaths[1] != A_AhkPath)
            throw Error("完整文件扫描结果没有通过数量校验")
        FileAppend("COMPLETE|2`r`n"
            IniFieldCodec.Encode(A_AhkPath) "`r`n", scanResultPath,
            "UTF-16")
        scanPaths := App.fileScanner.ReadResult(scanResultPath, &scanTruncated,
            &scanReady)
        if scanReady || scanPaths.Length
            throw Error("缺少记录的文件扫描结果仍被接受")
    } finally {
        try FileDelete(scanResultPath)
    }

    configPath := A_Temp "\watchdog-main-config-test-" currentPid ".ini"
    originalRepository := App.configRepository
    try {
        try FileDelete(configPath)
        App.SetConfigRepository(WatchdogConfigRepository(configPath))
        App.appStates := Map()
        App.appStates.CaseSense := "Off"
        App.appOrder := [A_AhkPath]
        App.configRecoveryEntries := []
        preservedRecovery := IniFieldCodec.Encode(
            "Source=App99`nApp=damaged-record")
        App.configRepository.WriteValue("Recovery", "Entry7",
            preservedRecovery)
        App.configRecoveryEntries := App.watchlistPersistenceService
            .ReadRecoveryEntries()
        if (App.configRecoveryEntries.Length != 1
            || App.configRecoveryEntries[1].SerializedValue
                != preservedRecovery)
            throw Error("已有恢复记录没有载入内存")
        App.appStates[A_AhkPath] := TargetSupervisor({
            Enabled: 1, RunAsAdmin: 0, WorkDir: A_Temp,
            Args: "--标签=测试|值", EnvVars: "LANG=zh_CN",
            ResolvedTarget: A_AhkPath, ResolvedTargetManual: false,
            ShortcutArgs: "", MaintenanceConfig:
                App.maintenanceConfigCodec.CreateDefault(A_AhkPath),
            DisplayConfig: App.displayConfigCodec.CreateDefault()
        })
        Critical("On")
        try {
            if !SaveAppsToIni()
                throw Error("守护对象没有通过配置仓储保存")
            if !A_IsCritical
                throw Error("守护对象保存破坏了调用方的临界状态")
        } finally Critical("Off")
        appEntries := App.configRepository.ReadSectionEntries("Apps")
        maintenanceValues := App.configRepository.ReadSectionMap("Maintenance")
        if appEntries.Length != 1 || appEntries[1].Key != "App1"
            throw Error("守护对象保存顺序或键名错误")
        savedParts := StrSplit(appEntries[1].Value, "|")
        if savedParts.Length != 9
            throw Error("当前守护对象配置不是九字段格式")
        if IniFieldCodec.Decode(savedParts[5]) != "--标签=测试|值"
            throw Error("守护对象参数没有无损编码")
        if !maintenanceValues.Has("App1")
            throw Error("守护对象缺少对应的升级保护配置")
        recoveryValues := App.configRepository.ReadSectionMap("Recovery")
        if (recoveryValues.Count != 1
            || !recoveryValues.Has("Entry1")
            || recoveryValues["Entry1"] != preservedRecovery)
            throw Error("再次保存时丢失或改写了已有恢复记录")
        savedText := FileRead(configPath, "UTF-16")
        if !InStr(savedText, "; 每个 AppN 对应一个守护对象")
            throw Error("守护对象分区注释没有随事务写入")

        ; 第一次提交完成但尚未退出保存函数时模拟用户再次修改。
        ; 最新修订必须由同一保存者继续提交，不能被 isSaving 静默吞掉。
        basePersistenceService := App.watchlistPersistenceService
        reentrantService := ReentrantWatchlistPersistenceTestService(
            basePersistenceService, A_AhkPath)
        App.watchlistPersistenceService := reentrantService
        App.appStates[A_AhkPath].Args := "--首次修改"
        if !SaveAppsToIni()
            throw Error("带重入修改的守护对象保存失败")
        App.watchlistPersistenceService := basePersistenceService
        reentrantParts := StrSplit(App.configRepository
            .ReadSectionEntries("Apps")[1].Value, "|")
        if reentrantService.SaveCount != 2
            || IniFieldCodec.Decode(reentrantParts[5]) != "--二次修改"
            || App.appsDirty
            || App.appConfigPersistedRevision != App.appConfigSaveRevision {
            throw Error("保存期间发生的二次修改没有提交到最新修订")
        }

        validRepository := App.configRepository
        App.SetConfigRepository(WatchdogConfigRepository(
            A_Temp "\missing-watchdog-config-parent-" currentPid
                "\watchdog.ini"))
        if SaveAppsToIni() || !App.appsDirty
            throw Error("主配置保存失败后没有保留待重试状态")
        if App.configSaveRetryDelayMs != 10000
            throw Error("主配置保存失败后没有推进重试退避")
        App.SetConfigRepository(validRepository)
        App.RetryDirtyAppConfig()
        if App.appsDirty || App.configSaveRetryDelayMs != 5000
            throw Error("主配置自动重试成功后没有清除待保存状态")
    } finally {
        try SetTimer(App.configSaveRetryTimer, 0)
        App.SetConfigRepository(originalRepository)
        try FileDelete(configPath)
        Loop Files, configPath ".tmp.*"
            try FileDelete(A_LoopFileFullPath)
    }
    try FileDelete(sandboxConfigPath)
}
