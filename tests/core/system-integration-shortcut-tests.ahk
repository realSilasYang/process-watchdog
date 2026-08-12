#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 快捷方式必须在写入后读回验证，并显式通知 Windows Shell 更新开始菜单缓存。
; 用例只操作系统临时目录，不触碰用户桌面、开始菜单或项目配置。

try {
    RunSystemIntegrationShortcutTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.File " (" testError.Line "): " testError.Message
        "`n" testError.Stack "`n", "**")
    ExitApp(1)
}

#Include ..\..\进程守护小助手.ahk

AssertSystemIntegrationShortcut(condition, message) {
    if !condition
        throw Error(message)
}

RunSystemIntegrationShortcutTests() {
    testRoot := A_Temp "\watchdog-shortcut-test-" A_TickCount "-"
        ProcessExist()
    DirCreate(testRoot)
    try {
        sourceShortcut := testRoot "\source.lnk"
        sourceCreated := CreateApplicationShortcutFile(sourceShortcut,
            A_ScriptFullPath, A_ScriptDir, A_AhkPath, false, A_AhkPath)
        if !sourceCreated {
            sourceInfo := ShortcutResolver.Read(sourceShortcut)
            throw Error("源码版快捷方式创建或读回校验失败：target="
                sourceInfo.TargetPath "；arguments=" sourceInfo.Arguments
                "；workingDirectory=" sourceInfo.WorkingDirectory
                "；appId=" ReadShortcutAppUserModelId(sourceShortcut)
                "；expectedAppId=" GetApplicationUserModelId())
        }
        FileGetShortcut(sourceShortcut, &sourceTarget, &sourceWorkingDir,
            &sourceArguments, , &sourceIcon)
        AssertSystemIntegrationShortcut(sourceTarget == A_ScriptFullPath
            && sourceWorkingDir == A_ScriptDir
            && sourceArguments == "",
            "源码版快捷方式没有使用脚本目标或保留工作目录")
        AssertSystemIntegrationShortcut(!PathsEquivalent(sourceTarget,
                A_AhkPath) && !InStr(sourceArguments, A_ScriptFullPath),
            "源码版快捷方式重新绑定了公共解释器，可能污染其它 AHK 脚本图标")
        AssertSystemIntegrationShortcut(sourceIcon == A_AhkPath,
            "源码版快捷方式没有保留专属图标路径")
        AssertSystemIntegrationShortcut(ReadShortcutAppUserModelId(
                sourceShortcut) == GetApplicationUserModelId(),
            "源码版快捷方式没有写入产品专属 AppUserModelID")
        AssertSystemIntegrationShortcut(NotifyShellShortcutChanged(
            sourceShortcut, false), "新建快捷方式没有通知 Windows Shell")
        AssertSystemIntegrationShortcut(NotifyShellShortcutChanged(
            sourceShortcut, true), "覆盖快捷方式没有通知 Windows Shell")

        compiledShortcut := testRoot "\compiled.lnk"
        AssertSystemIntegrationShortcut(CreateApplicationShortcutFile(
            compiledShortcut, A_AhkPath, A_ScriptDir, A_AhkPath,
            true, A_AhkPath), "EXE 版快捷方式创建或读回校验失败")
        FileGetShortcut(compiledShortcut, &compiledTarget, ,
            &compiledArguments)
        AssertSystemIntegrationShortcut(compiledTarget == A_AhkPath
            && compiledArguments == "",
            "EXE 版快捷方式目标或参数错误")
        AssertSystemIntegrationShortcut(ReadShortcutAppUserModelId(
                compiledShortcut) == GetApplicationUserModelId(),
            "EXE 版快捷方式没有写入产品专属 AppUserModelID")
        ; 构造旧版的共享解释器目标。即使其 AppID 已经正确，迁移器也必须
        ; 重建它，否则 Shell 仍可能把产品 Logo 关联到普通 AHK 脚本。
        AssertSystemIntegrationShortcut(WriteApplicationShortcut(
                sourceShortcut, A_AhkPath, A_ScriptDir,
                '"' A_ScriptFullPath '"', "test", A_AhkPath,
                GetApplicationUserModelId())
            && ReadShortcutAppUserModelId(sourceShortcut)
                == GetApplicationUserModelId(),
            "测试无法构造旧版共享解释器快捷方式")
        AssertSystemIntegrationShortcut(!ApplicationShortcutMatches(
                sourceShortcut, A_ScriptFullPath, false, A_AhkPath,
                A_ScriptDir),
            "快捷方式校验没有识别被公共解释器身份污染的入口")
        AssertSystemIntegrationShortcut(LegacyApplicationShortcutLaunchMatches(
                sourceShortcut, A_ScriptFullPath, A_ScriptDir, false,
                A_AhkPath),
            "迁移器没有识别属于本项目的旧版共享解释器快捷方式")
        AssertSystemIntegrationShortcut(RepairApplicationShortcutIdentities(
                [sourceShortcut], {
                    ScriptPath: A_ScriptFullPath,
                    WorkingDirectory: A_ScriptDir,
                    Compiled: false,
                    InterpreterPath: A_AhkPath
                }) == 1
            && ApplicationShortcutMatches(sourceShortcut,
                A_ScriptFullPath, false, A_AhkPath, A_ScriptDir)
            && ReadShortcutAppUserModelId(sourceShortcut)
                == GetApplicationUserModelId(),
            "既有快捷方式没有迁移为隔离目标和产品专属 AppUserModelID")

        chainRoot := testRoot "\button-chain"
        DirCreate(chainRoot)
        probeScript := chainRoot "\shortcut-launch-probe.ahk"
        probeOutput := chainRoot "\shortcut-launch-result.txt"
        FileAppend('#Requires AutoHotkey v2.0`n'
            . 'FileAppend(A_WorkingDir "|" A_Args.Length, '
            . 'A_ScriptDir "\shortcut-launch-result.txt", "UTF-8")`n'
            . 'ExitApp`n', probeScript, "UTF-8")
        chainPaths := {
            Desktop: chainRoot "\desktop.lnk",
            Programs: chainRoot "\programs.lnk"
        }
        chainLaunchSpec := {
            ScriptPath: probeScript,
            WorkingDirectory: chainRoot,
            Compiled: false,
            InterpreterPath: A_AhkPath,
            IconPath: A_AhkPath
        }
        createdPaths := CreateApplicationShortcuts(chainPaths,
            chainLaunchSpec)
        AssertSystemIntegrationShortcut(
            createdPaths.Desktop == chainPaths.Desktop
                && createdPaths.Programs == chainPaths.Programs
                && ApplicationShortcutMatches(chainPaths.Desktop,
                    probeScript, false, A_AhkPath, chainRoot)
                && ApplicationShortcutMatches(chainPaths.Programs,
                    probeScript, false, A_AhkPath, chainRoot),
            "创建按钮链路没有同时生成可验证的桌面与开始菜单入口")
        FileGetShortcut(chainPaths.Programs, &programsTarget, ,
            &programsArguments, , &programsIcon)
        AssertSystemIntegrationShortcut(PathsEquivalent(programsTarget,
                probeScript) && !PathsEquivalent(programsTarget, A_AhkPath)
                && programsArguments == ""
                && PathsEquivalent(programsIcon, A_AhkPath)
                && ReadShortcutAppUserModelId(chainPaths.Programs)
                    == GetApplicationUserModelId(),
            "创建按钮生成的开始菜单入口未满足目标隔离、Logo 或 AppID 约束")
        Run(chainPaths.Desktop, chainRoot)
        deadline := A_TickCount + 10000
        while !FileExist(probeOutput) && A_TickCount < deadline
            Sleep(50)
        AssertSystemIntegrationShortcut(FileExist(probeOutput)
                && FileRead(probeOutput, "UTF-8") == chainRoot "|0",
            "源码快捷方式未能经系统文件关联启动或工作目录不正确")

        rollbackRoot := testRoot "\rollback"
        DirCreate(rollbackRoot)
        rollbackPrograms := rollbackRoot "\programs.lnk"
        rollbackDesktop := rollbackRoot "\missing\desktop.lnk"
        FileAppend("original", rollbackPrograms, "UTF-8-RAW")
        rollbackFailed := false
        try CreateApplicationShortcuts({
            Desktop: rollbackDesktop,
            Programs: rollbackPrograms
        }, chainLaunchSpec)
        catch
            rollbackFailed := true
        AssertSystemIntegrationShortcut(rollbackFailed
                && FileRead(rollbackPrograms, "UTF-8-RAW") == "original"
                && !FileExist(rollbackDesktop)
                && CountSystemIntegrationShortcutFiles(rollbackRoot,
                    "*.backup-*") == 0,
            "双入口创建失败后没有完整恢复原快捷方式状态")
        FileCreateShortcut(A_ComSpec, compiledShortcut, A_Temp)
        AssertSystemIntegrationShortcut(!ApplicationShortcutMatches(
            compiledShortcut, A_AhkPath, true, A_AhkPath),
            "读回校验没有识别被替换成错误目标的快捷方式")
    } finally {
        expectedPrefix := A_Temp "\watchdog-shortcut-test-"
        if InStr(testRoot, expectedPrefix) == 1 && DirExist(testRoot)
            DirDelete(testRoot, true)
    }
}

CountSystemIntegrationShortcutFiles(directory, pattern) {
    count := 0
    Loop Files directory "\" pattern, "FR"
        count++
    return count
}
