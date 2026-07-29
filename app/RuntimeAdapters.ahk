; 配置校验与目标规格适配层。
; 本模块把界面输入和应用层函数调用适配为核心层使用的明确规格对象。
; 路径、环境变量、快捷方式与维护配置在进入守护状态机前统一规范化，
; 使核心逻辑不依赖控件文本，也不会把查询失败误当成目标已经停止。
GetApplicationRootFilePath(relativePath) {
    ; 正式入口从安装根目录读取资源；独立测试通过 #Include 从 tests 子目录
    ; 启动时，则从本模块位置回溯项目根目录。应用资源和第三方运行库共享
    ; 同一条定位规则，避免某个入口只能显示降级效果。
    relativePath := LTrim(String(relativePath), "\/")
    packagedPath := A_ScriptDir "\" relativePath
    if FileExist(packagedPath)
        return packagedPath
    SplitPath(A_LineFile, , &moduleDirectory)
    return moduleDirectory "\..\" relativePath
}

GetApplicationAssetPath(relativePath) {
    return GetApplicationRootFilePath("assets\" relativePath)
}

GetApplicationIconPath() {
    ; 所有窗口从统一资源路径取得应用图标，避免测试入口和正式入口行为分叉。
    return GetApplicationAssetPath("app\watchdog.ico")
}

ParseBoundedInteger(value, minValue, maxValue) {
    value := Trim(String(value))
    if !RegExMatch(value, "^\d+$")
        return false
    try parsed := Integer(value)
    catch
        return false
    return (parsed >= minValue && parsed <= maxValue) ? parsed : false
}

IsValidCheckInterval(value) {
    if !RegExMatch(Trim(String(value)), "^\d+$")
        return false
    try value := Integer(value)
    catch
        return false
    return value >= 500 && value <= 86400000
}

ParseRetrySequence(sequence) {
    sequence := StrReplace(StrReplace(Trim(sequence), " ", ""), "，", ",")
    if (sequence == "")
        return false
    result := []
    retryParts := StrSplit(sequence, ",")
    if (retryParts.Length > 10)
        return false
    for value in retryParts {
        if !RegExMatch(value, "^\d+$")
            return false
        try seconds := Integer(value)
        catch
            return false
        if (seconds < 1 || seconds > 86400)
            return false
        result.Push(seconds * 1000)
    }
    return result.Length ? result : false
}

NormalizeTargetPath(path) {
    path := Trim(path)
    ; 用户经常直接粘贴资源管理器中的带引号路径；引号属于输入包装而不是路径本身。
    if (StrLen(path) >= 2 && SubStr(path, 1, 1) == '"' && SubStr(path, -1) == '"')
        path := Trim(SubStr(path, 2, -1))
    return StrReplace(path, "/", "\")
}

GetCanonicalPath(path) {
    path := Trim(String(path), " `t`r`n`"")
    if (path == "")
        return ""
    path := StrReplace(path, "/", "\")
    fullPathBuffer := Buffer(32768 * 2, 0)
    length := DllCall("kernel32\GetFullPathNameW", "Str", path, "UInt", 32768, "Ptr", fullPathBuffer, "Ptr", 0, "UInt")
    fullPath := length && length < 32768 ? StrGet(fullPathBuffer, length, "UTF-16") : path
    if FileExist(fullPath) {
        longPathBuffer := Buffer(32768 * 2, 0)
        longLength := DllCall("kernel32\GetLongPathNameW", "WStr", fullPath,
            "Ptr", longPathBuffer, "UInt", 32768, "UInt")
        if (longLength && longLength < 32768)
            fullPath := StrGet(longPathBuffer, longLength, "UTF-16")
    }
    if (SubStr(fullPath, 1, 4) == "\\?\")
        fullPath := SubStr(fullPath, 5)
    return StrLower(StrLen(fullPath) > 3 ? RTrim(fullPath, "\") : fullPath)
}

PathsEquivalent(firstPath, secondPath) {
    if (firstPath == "" || secondPath == "")
        return firstPath == secondPath
    return GetCanonicalPath(firstPath) == GetCanonicalPath(secondPath)
}

SignedWord(value) {
    value := value & 0xFFFF
    return value > 0x7FFF ? value - 0x10000 : value
}

GetTickCount64() {
    return DllCall("kernel32\GetTickCount64", "UInt64")
}

LogSlowBackgroundOperation(operationName, startedTicks, thresholdMs := 200) {
    elapsedMs := GetTickCount64() - startedTicks
    if (elapsedMs < thresholdMs)
        return
    static lastLoggedTicks := Map()
    nowTicks := GetTickCount64()
    if (lastLoggedTicks.Has(operationName)
        && nowTicks - lastLoggedTicks[operationName] < 30000)
        return
    lastLoggedTicks[operationName] := nowTicks
    LogMsg(Tr("后台任务耗时较长：{1}，本次 {2} 毫秒",
        Tr(operationName), elapsedMs))
}

IsMaintenanceSupportedTarget(path) {
    if !InStr(path, "\")
        return false
    SplitPath(path, , , &extension)
    extension := StrLower(extension)
    if (extension == "lnk") {
        effectiveTarget := App.targetIdentityService.GetMonitoredTargetPath(
            path)
        if (effectiveTarget == "" && IsOneShotTarget(path))
            return false
    }
    return RegExMatch(extension, "i)^(exe|com|ahk|py|pyw|js|vbs|vbe|wsf|ps1|bat|cmd|rb|pl|php|lua|jar|sh|bash|lnk)$") != 0
}

GetDefaultMaintenanceRoot(path) {
    if !IsMaintenanceSupportedTarget(path)
        return ""
    SplitPath(path, , , &extension)
    if (StrLower(extension) == "lnk") {
        effectiveTarget := App.targetIdentityService.GetMonitoredTargetPath(
            path)
        if (effectiveTarget != "") {
            SplitPath(effectiveTarget, , &effectiveDirectory)
            if (effectiveDirectory != "")
                return effectiveDirectory
        }
        workingDir := App.shortcutTargetResolver.GetWorkingDirectory(path)
        if (workingDir != "")
            return StrLen(workingDir) > 3 ? RTrim(workingDir, "\") : workingDir
        targetPath := App.shortcutTargetResolver.GetTargetPath(path)
        if (targetPath != "") {
            SplitPath(targetPath, , &targetDirectory)
            return targetDirectory
        }
    }
    SplitPath(path, , &directory)
    return directory
}

NormalizeMaintenanceRoot(rootPath, targetPath := "") {
    rootPath := Trim(rootPath)
    if (rootPath == "" && targetPath != "")
        rootPath := GetDefaultMaintenanceRoot(targetPath)
    rootPath := StrReplace(rootPath, "/", "\")
    if (StrLen(rootPath) > 3)
        rootPath := RTrim(rootPath, "\")
    return rootPath
}

RegisterPersistedWatchItem(record) {
    return RegisterApp(record.Path, record.Enabled, record.RunAsAdmin,
        record.WorkDir, record.Args, record.EnvVars, record.Maintenance,
        record.ResolvedTarget, record.ResolvedTargetManual,
        record.ShortcutArgs, record.Display, record.RuntimePath,
        record.RuntimeArgs)
}

LoadWatchlistFromConfig() {
    loadResult := App.watchlistPersistenceService.Load(
        RegisterPersistedWatchItem)
    App.configLoadWarnings := loadResult.Warnings
    App.configRecoveryEntries := loadResult.RecoveryEntries
    if App.configLoadWarnings.Length {
        LogMsg(BuildConfigLoadDiagnostic(App.configLoadWarnings,
            App.configRepository.Path))
        try TrayTip(Tr("{1} 条监控配置未载入，相关守护对象当前不会被守护。点击查看具体位置和原因。",
            App.configLoadWarnings.Length), Tr("监控配置加载异常"), 2)
    }
}

BuildConfigLoadDiagnostic(warnings, configPath) {
    diagnostic := Tr("监控配置加载异常：共 {1} 条记录未能载入。",
        warnings.Length)
    for index, warning in warnings {
        targetText := warning.Target != "" ? warning.Target
            : Tr("无法从损坏记录中提取")
        diagnostic .= Tr("`r`n  [{1}] 位置：[{2}] {3}", index,
            warning.Section, warning.Key)
        diagnostic .= Tr("`r`n      目标：{1}", targetText)
        diagnostic .= Tr("`r`n      问题：{1}：{2}",
            TrDiagnostic(warning.Field), TrDiagnostic(warning.Reason))
        diagnostic .= Tr("`r`n      影响：该守护对象本次未加入守护列表。")
    }
    diagnostic .= Tr("`r`n  配置文件：{1}", configPath)
    diagnostic .= Tr("`r`n  处理建议：确认目标路径后，可在主界面重新添加该守护对象；也可退出小助手后检查上述配置位置。后续保存配置时，损坏记录会转存到 [Recovery]，不会被静默删除。")
    return diagnostic
}

QueryProcessSnapshot(&snapshotReady) {
    snapshotReady := false
    snapshot := []
    try {
        wmiService := ComObjGet("winmgmts:")
        processes := wmiService.ExecQuery("SELECT ProcessId, ParentProcessId, Name, CommandLine, ExecutablePath, CreationDate FROM Win32_Process")
        for process in processes {
            processInfo := {pid: 0, parent: 0, name: "", cmd: "", exe: "",
                creation: "", identity: "", observedTicks: GetTickCount64()}
            try processInfo.pid := Integer(process.ProcessId)
            try processInfo.parent := Integer(process.ParentProcessId)
            try processInfo.name := process.Name
            try processInfo.cmd := process.CommandLine
            try processInfo.exe := process.ExecutablePath
            try processInfo.creation := process.CreationDate
            if processInfo.pid
                processInfo.identity := App.processInspector
                    .GetCreationIdentity(processInfo.pid)
            if processInfo.pid
                snapshot.Push(processInfo)
        }
        snapshotReady := true
    } catch {
        snapshotReady := false
        snapshot := []
    }
    return snapshot
}

CreateProcessSnapshotIndex(snapshot, capturedAtTicks := 0,
    supportsCommandLine := true) {
    if !capturedAtTicks
        capturedAtTicks := GetTickCount64()
    return ProcessSnapshotIndex(snapshot, capturedAtTicks,
        supportsCommandLine, GetCanonicalPath,
        ObjBindMethod(App.processInspector, "GetCreationIdentity"))
}

QuoteCommandLineArgument(argument) {
    return '"' String(argument) '"'
}

BuildReloadValidationCommand(interpreterPath, scriptPath) {
    return QuoteCommandLineArgument(interpreterPath) . " /ErrorStdOut "
        . QuoteCommandLineArgument(scriptPath) . " --startup-validation"
}

BuildReloadHandoffCommand(currentPid, compiled, interpreterPath, scriptPath) {
    currentPid := Integer(currentPid)
    if compiled {
        return QuoteCommandLineArgument(scriptPath) . " --reload-handoff "
            . currentPid
    }
    return QuoteCommandLineArgument(interpreterPath) . " "
        . QuoteCommandLineArgument(scriptPath) . " --reload-handoff "
        . currentPid
}

ValidateApplicationUpdateReadyPath(candidatePath, tempRoot := "") {
    if candidatePath == ""
        return ""
    if tempRoot == ""
        tempRoot := A_Temp
    candidatePath := GetCanonicalPath(candidatePath)
    tempRoot := GetCanonicalPath(tempRoot)
    if candidatePath == "" || tempRoot == ""
        return ""
    SplitPath(candidatePath, &fileName, &parentDirectory)
    SplitPath(parentDirectory, &parentName)
    if fileName != "application-ready.signal"
        || !RegExMatch(parentName, "^processwatchdogupdateapply-[^-]+-.+$")
        || SubStr(GetCanonicalPath(parentDirectory), 1,
            StrLen(tempRoot) + 1) != tempRoot "\"
        return ""
    return candidatePath
}

GetApplicationUpdateReadyPath() {
    for argumentIndex, argument in A_Args {
        if StrLower(argument) != "--update-ready"
            || argumentIndex >= A_Args.Length
            continue
        return ValidateApplicationUpdateReadyPath(
            A_Args[argumentIndex + 1])
    }
    return ""
}

WriteApplicationUpdateReadySignal(readyPath, version) {
    readyPath := ValidateApplicationUpdateReadyPath(readyPath)
    if readyPath == ""
        return false
    temporaryPath := readyPath ".tmp."
        DllCall("kernel32\GetCurrentProcessId", "UInt")
    try {
        try FileDelete(temporaryPath)
        FileAppend("READY|" version, temporaryPath, "UTF-8")
        FileMove(temporaryPath, readyPath, true)
        return true
    } catch {
        try FileDelete(temporaryPath)
        return false
    }
}

ProcessMaintenanceCommandClient() {
    if (A_Args.Length < 1)
        return false
    option := StrLower(A_Args[1])
    if (option == "--startup-validation")
        ExitApplication(0)
    if (option == "--process-snapshot-worker" && A_Args.Length >= 2) {
        succeeded := App.processSnapshots.WriteWorkerFile(A_Args[2],
            QueryProcessSnapshot)
        ExitApplication(succeeded ? 0 : 1)
    }
    if (option == "--send-ctrl-c" && A_Args.Length >= 2) {
        expectedCreationIdentity := A_Args.Length >= 3 ? A_Args[3] : ""
        succeeded := SendConsoleCtrlCWorker(Integer(A_Args[2]),
            expectedCreationIdentity)
        ExitApplication(succeeded ? 0 : 1)
    }
    if (option == "--file-scan-worker" && A_Args.Length >= 5) {
        succeeded := App.fileScanner.WriteWorkerFile(A_Args[2], A_Args[3],
            Integer(A_Args[4]) != 0, Integer(A_Args[5]),
            A_Args.Length >= 6 ? Integer(A_Args[6]) : 60)
        ExitApplication(succeeded ? 0 : 1)
    }
    if (option != "--maintenance-begin" && option != "--maintenance-end")
        return false
    if (A_Args.Length < 2)
        return true
    command := (option == "--maintenance-begin" ? "BEGIN|" : "END|") A_Args[2]
    targetWindow := FindRunningApplicationWindow()
    if targetWindow {
        Loop 3 {
            if SendMaintenanceCopyData(targetWindow, command)
                break
            Sleep(200)
        }
        return true
    }
    App.maintenanceCoordinator.PendingCommands.Push(command)
    return false
}

FindRunningApplicationWindow() {
    hiddenWindowsBefore := A_DetectHiddenWindows
    try {
        DetectHiddenWindows(true)
        for candidateWindow in WinGetList("ahk_class AutoHotkeyGUI") {
            if !SendMaintenanceCopyData(candidateWindow, "PING|", 500)
                continue
            rootOwner := DllCall("user32\GetAncestor", "Ptr",
                candidateWindow, "UInt", 3, "Ptr") ; GA_ROOTOWNER：取得最上层所有者窗口
            return rootOwner ? rootOwner : candidateWindow
        }
    } finally {
        DetectHiddenWindows(hiddenWindowsBefore)
    }
    return 0
}

SendMaintenanceCopyData(targetWindow, command, timeoutMs := 3000) {
    characterCount := StrPut(command, "UTF-16")
    commandBuffer := Buffer(characterCount * 2, 0)
    StrPut(command, commandBuffer, "UTF-16")
    structureSize := A_PtrSize == 8 ? 24 : 12
    copyData := Buffer(structureSize, 0)
    NumPut("UPtr", 1, copyData, 0)
    NumPut("UInt", characterCount * 2, copyData, A_PtrSize)
    NumPut("Ptr", commandBuffer.Ptr, copyData, A_PtrSize == 8 ? 16 : 8)
    messageResult := 0
    return DllCall("user32\SendMessageTimeoutW", "Ptr", targetWindow,
        "UInt", Win32.WM_COPYDATA, "Ptr", A_ScriptHwnd, "Ptr", copyData.Ptr,
        "UInt", 0x0002, "UInt", Max(1, Integer(timeoutMs)),
        "UPtr*", &messageResult, "Ptr") && messageResult != 0
}

ReceiveMaintenanceCopyData(wParam, lParam, msg, hwnd) {
    if !lParam
        return 0
    byteCount := NumGet(lParam, A_PtrSize, "UInt")
    dataPointer := NumGet(lParam, A_PtrSize == 8 ? 16 : 8, "Ptr")
    if !dataPointer || byteCount < 2 || Mod(byteCount, 2)
        return 0
    command := StrGet(dataPointer, byteCount // 2 - 1, "UTF-16")
    return App.maintenanceCoordinator.QueueCommand(command) ? 1 : 0
}

ClearStateProcessIdentity(stateObj, rememberLast := true) {
    if !stateObj
        return
    if rememberLast && stateObj.HasOwnProp("PID") && stateObj.PID {
        stateObj.LastKnownPID := stateObj.PID
        stateObj.LastKnownPIDCreationIdentity := stateObj.PIDCreationIdentity
    }
    stateObj.PID := 0
    stateObj.PIDCreationIdentity := ""
    stateObj.PIDImagePath := ""
    stateObj.PIDElevationState := -1
    stateObj.PIDElevationChecked := false
}

SetStateProcessIdentity(stateObj, pid, observedCreationIdentity := "") {
    pid := pid ? Integer(pid) : 0
    if !pid {
        ClearStateProcessIdentity(stateObj)
        return false
    }
    observedCreationIdentity := String(observedCreationIdentity)
    currentCreationIdentity := ""
    if (stateObj.PID == pid && stateObj.HasOwnProp("PIDCreationIdentity")
        && stateObj.PIDCreationIdentity != "" && ProcessExist(pid)) {
        currentCreationIdentity := App.processInspector.GetCreationIdentity(pid)
        if (currentCreationIdentity == ""
            || currentCreationIdentity == stateObj.PIDCreationIdentity)
            return true
    }
    stateObj.PID := pid
    stateObj.LastKnownPID := pid
    stateObj.PIDCreationIdentity := currentCreationIdentity != ""
        ? currentCreationIdentity
        : (observedCreationIdentity != "" ? observedCreationIdentity
            : App.processInspector.GetCreationIdentity(pid))
    stateObj.PIDImagePath := App.processInspector.GetImagePath(pid)
    stateObj.LastKnownPIDCreationIdentity := stateObj.PIDCreationIdentity
    stateObj.PIDElevationState := -1
    stateObj.PIDElevationChecked := false
    return true
}

EnsureStateProcessElevation(stateObj) {
    if !stateObj || !stateObj.HasOwnProp("PID") || !stateObj.PID
        return -1
    if stateObj.HasOwnProp("PIDElevationChecked") && stateObj.PIDElevationChecked
        return stateObj.HasOwnProp("PIDElevationState")
            ? stateObj.PIDElevationState : -1
    stateObj.PIDElevationState :=
        App.processInspector.GetElevationState(stateObj.PID)
    stateObj.PIDElevationChecked := true
    return stateObj.PIDElevationState
}

IsRunAsAdminMismatch(stateObj) {
    return stateObj.RunAsAdmin
        && EnsureStateProcessElevation(stateObj) == 0
}

UpdateRunningState(path, stateObj, expectedGeneration := 0) {
    path := NormalizeTargetPath(path)
    if !App.appStates.Has(path) || App.appStates[path] != stateObj
        return false
    if !stateObj.Enabled || (expectedGeneration
        && stateObj.Generation != expectedGeneration)
        return false
    if !expectedGeneration
        expectedGeneration := stateObj.Generation
    mismatchStatus := Tr("⚠️ 运行中（权限不符）")
    permissionMismatch := IsRunAsAdminMismatch(stateObj)
    if (!App.appStates.Has(path) || App.appStates[path] != stateObj
        || !stateObj.Enabled || stateObj.Generation != expectedGeneration)
        return false
    stateObj.TransitionTo(GuardPhase.Running)
    stateObj.StoppedEvidenceTicks := 0
    if permissionMismatch {
        if (stateObj.State != mismatchStatus)
            LogMsg(Tr("检测到运行中的目标未使用管理员权限：{1}", path))
        UpdateState(path, mismatchStatus, stateObj, expectedGeneration,
            false, GuardStatusKind.PermissionMismatch)
        return false
    }
    UpdateState(path, Tr("✅ 运行中"), stateObj, expectedGeneration,
        false, GuardStatusKind.Running)
    return true
}

DoesProcessMatchTarget(pid, targetPath, stateObj := "") {
    if !pid || !ProcessExist(pid)
        return false
    creationIdentityVerified := false
    if stateObj && stateObj.HasOwnProp("PIDCreationIdentity")
        && stateObj.PIDCreationIdentity != "" {
        currentCreation := App.processInspector.GetCreationIdentity(pid)
        if currentCreation == ""
            return false
        if currentCreation != stateObj.PIDCreationIdentity
            return false
        creationIdentityVerified := true
    }
    specs := App.targetSpecsService.Get(targetPath, stateObj)
    if creationIdentityVerified
        return true
    switch specs.Probe.Kind {
        case TargetProbeKind.ImagePath:
            imagePath := App.processInspector.GetImagePath(pid)
            return imagePath != "" && PathsEquivalent(imagePath,
                specs.Probe.TargetPath)
        case TargetProbeKind.ProcessName:
            try processName := ProcessGetName(pid)
            catch
                return false
            SplitPath(specs.Probe.TargetPath, &wantedName)
            return wantedName != ""
                && StrLower(processName) == StrLower(wantedName)
        case TargetProbeKind.WorkingDirectory:
            imagePath := App.processInspector.GetImagePath(pid)
            if imagePath == ""
                return false
            rootPath := RTrim(GetCanonicalPath(
                specs.Probe.WorkingDirectory), "\")
            canonicalImage := GetCanonicalPath(imagePath)
            if rootPath == "" || (canonicalImage != rootPath
                && InStr(canonicalImage, rootPath "\") != 1)
                return false
            if specs.Probe.PreferredName == ""
                return true
            SplitPath(imagePath, &imageName)
            return StrLower(imageName) == StrLower(
                specs.Probe.PreferredName)
    }
    ; 解释型脚本必须重新核对命令目标；仅凭一个没有创建身份的 PID
    ; 无法证明它仍是先前匹配到的脚本宿主。
    return false
}

StateProcessIdentityIsValid(path, stateObj) {
    return stateObj && stateObj.PID
        && DoesProcessMatchTarget(stateObj.PID, path, stateObj)
}

InvalidateShortcutRuntimeIdentity(path, stateObj) {
    path := NormalizeTargetPath(path)
    if !IsObject(stateObj) || !App.appStates.Has(path)
        || App.appStates[path] != stateObj {
        return false
    }
    stateObj.CancelScheduledTasks()
    stateObj.ResetGuardAttemptState()
    ClearStateProcessIdentity(stateObj)
    if !stateObj.Enabled {
        stateObj.Pending := false
        stateObj.TransitionTo(GuardPhase.Paused)
    } else if App.maintenanceCoordinator.IsBlocking(stateObj) {
        stateObj.Pending := true
    } else {
        stateObj.Pending := false
        stateObj.TransitionTo(GuardPhase.Initializing)
    }
    return true
}

ObserveTarget(target, snapshotIndex := "", maximumSnapshotAgeMs := 0) {
    target := NormalizeTargetPath(target)
    stateObj := App.appStates.Has(target) ? App.appStates[target] : ""
    specs := App.targetSpecsService.Get(target, stateObj)
    return App.targetProbe.Observe(specs.Probe, snapshotIndex,
        maximumSnapshotAgeMs)
}

IsOneShotTarget(path, resolvedTarget := "") {
    descriptor := ShortcutDescriptor(path)
    SplitPath(path, , , &extension)
    if (StrLower(extension) == "lnk" && FileExist(path))
        descriptor := App.shortcutTargetResolver.Read(path)
    specs := TargetSpecFactory.Create(path, {
        ResolvedTarget: resolvedTarget,
        EntryExists: !InStr(path, "\") || !!FileExist(path),
        ResolvedTargetExists: resolvedTarget != "" && !!FileExist(resolvedTarget),
        ShortcutArguments: descriptor.Arguments,
        ShortcutWorkingDirectory: descriptor.WorkingDirectory,
        ShortcutReadable: descriptor.Readable,
        ShortcutTargetsGenericLauncher: descriptor.Readable
            && App.shortcutTargetResolver.IsGenericLauncher(
                descriptor.TargetPath)
    })
    return specs.IsOneShot
}
