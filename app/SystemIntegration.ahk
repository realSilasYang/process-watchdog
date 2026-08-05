; 主窗口命令与 Windows 系统集成操作。
; 窗口命令只收集当前选择并调用既有应用服务；快捷方式和计划任务则在这里统一管理
; 固定名称、所有权校验与系统接口错误，避免设置窗口直接持有系统资源。

; 添加窗口拥有文件选择、批量导入和注册流程，主窗口按钮只负责显示该窗口。
AddItem(*) {
    GuiModules.addItem.Show()
}

DelItem(*) {
    paths := CaptureSelectedWatchPaths()
    if !paths.Length
        return
    QueueGuardMutation(DelItemCore.Bind(paths))
}

DelItemCore(paths) {
    App.editSessionId++
    undoState := CaptureAppConfigState()
    changedAny := false
    for delPath in paths {
        if App.appStates.Has(delPath) {
            stateObj := App.appStates[delPath]
            stateObj.CancelScheduledTasks()
            try App.maintenanceCoordinator.CleanupTarget(delPath,
                stateObj, false)
            catch as cleanupError {
                ; 删除的首要承诺是立即停止守护。监听器清理异常不能让控制器
                ; 继续藏在内存中；编排器的共享订阅会在后续轮询自行剔除。
                LogMsg(Tr("升级文件监听异常：{1}",
                    TrDiagnostic(cleanupError.Message)))
            }
            App.appStates.Delete(delPath)
            RemoveAppOrderPath(delPath)
            LogMsg(Tr("已取消监控：{1}", delPath))
            changedAny := true
        }
        row := FindRow(delPath)
        if row > 0
            Main.lv.Delete(row)
    }

    if !changedAny
        return
    Main.listProjection.Rebuild(Main.lv)
    Main.listProjection.RefreshSequenceFromOrder(Main.lv, App.appOrder)
    RefreshMainStatusSortKeys()

    App.maintenanceCoordinator.SaveJournal()
    CommitUndoState(undoState, CreateAppHistoryAction("delete", paths))
    SaveAppsToIni()
    Main.contextTargetRow := 0
    OnLVSelectChange() ; 刷新按钮显示状态
}

; 设置、日志和使用说明都由模块注册表持有，重复点击只激活现有实例。
ShowSettings(*) {
    GuiModules.settings.Show()
}

ShowAbout(*) {
    GuiModules.about.Show()
}

CreateApplicationShortcutFile(shortcutPath, scriptPath, workingDirectory,
    iconPath, compiled, interpreterPath) {
    if compiled {
        FileCreateShortcut(scriptPath, shortcutPath, workingDirectory, "",
            Tr("进程守护小助手"), iconPath)
    } else {
        ; 源码版仍显式绑定当前 AHK 解释器，不能依赖另一台设备上可能缺失或
        ; 指向旧版本的 .ahk 文件关联。
        FileCreateShortcut(interpreterPath, shortcutPath, workingDirectory,
            '"' scriptPath '"', Tr("进程守护小助手"), iconPath, , , 1)
    }
    return ApplicationShortcutMatches(shortcutPath, scriptPath, compiled,
        interpreterPath)
}

ApplicationShortcutMatches(shortcutPath, scriptPath, compiled,
    interpreterPath) {
    if !FileExist(shortcutPath) || DirExist(shortcutPath)
        return false
    shortcutInfo := ShortcutResolver.Read(shortcutPath)
    if !shortcutInfo.Readable
        return false
    actualTarget := shortcutInfo.TargetPath
    actualArguments := shortcutInfo.Arguments
    expectedTarget := compiled ? scriptPath : interpreterPath
    if StrLower(StrReplace(Trim(actualTarget), "/", "\"))
        != StrLower(StrReplace(Trim(expectedTarget), "/", "\"))
        return false
    expectedArguments := compiled ? "" : '"' scriptPath '"'
    return Trim(actualArguments) == expectedArguments
}

NotifyShellShortcutChanged(shortcutPath, existedBefore := false) {
    if shortcutPath == ""
        return false
    try {
        ; FileCreateShortcut 能写出 LNK，但开始菜单维护着独立应用缓存。明确
        ; 通知项目和父目录，并使用 FLUSH 等待 Shell 接收，避免桌面立即出现
        ; 而“所有应用”仍停留在旧列表，尤其是源码版指向 AHK 解释器时。
        pathFlags := 0x0005 | 0x1000 ; SHCNF_PATHW | SHCNF_FLUSH：宽字符路径并同步刷新
        itemEvent := existedBefore ? 0x2000 : 0x0002
            ; SHCNE_UPDATEITEM 或 SHCNE_CREATE：更新现有项目或发布新项目
        DllCall("shell32\SHChangeNotify", "UInt", itemEvent,
            "UInt", pathFlags, "WStr", shortcutPath, "Ptr", 0)
        SplitPath(shortcutPath, , &shortcutDirectory)
        if shortcutDirectory != "" {
            DllCall("shell32\SHChangeNotify", "UInt", 0x1000,
                "UInt", pathFlags, "WStr", shortcutDirectory, "Ptr", 0)
                ; SHCNE_UPDATEDIR：通知 Shell 重新读取快捷方式所在目录
        }
        return true
    } catch {
        ; 通知失败不影响已经落盘且验证通过的快捷方式；Explorer 的目录
        ; 监听仍会在稍后刷新，不能把可用入口误报为创建失败。
        return false
    }
}

CreateDesktopShortcut(ownerGui := "", *) {
    try {
        shortcutName := Tr("进程守护小助手")
        desktopPath := A_Desktop "\" shortcutName ".lnk"
        programsPath := A_Programs "\" shortcutName ".lnk"
        scriptPath := A_ScriptFullPath
        iconPath := GetApplicationIconPath()
        programsExisted := !!FileExist(programsPath)
        desktopExisted := !!FileExist(desktopPath)

        ; 先创建更容易被忽略的开始菜单入口；只有两处均完成且能读回正确
        ; 目标时才反馈成功，不能再由桌面一处成功掩盖另一处异常。
        if !CreateApplicationShortcutFile(programsPath, scriptPath,
                A_ScriptDir, iconPath, A_IsCompiled, A_AhkPath)
            throw Error(programsPath)
        if !CreateApplicationShortcutFile(desktopPath, scriptPath,
                A_ScriptDir, iconPath, A_IsCompiled, A_AhkPath)
            throw Error(desktopPath)

        NotifyShellShortcutChanged(programsPath, programsExisted)
        NotifyShellShortcutChanged(desktopPath, desktopExisted)
        LogMsg(Tr("已创建桌面与开始菜单快捷方式。") " "
            desktopPath " | " programsPath)
        return true
    } catch as shortcutErr {
        ShowDarkMsgBox(Tr("创建快捷方式失败：{1}",
            TrDiagnostic(shortcutErr.Message)),
            Tr("错误"), "Error", ownerGui)
        LogMsg(Tr("创建快捷方式失败：{1}",
            TrDiagnostic(shortcutErr.Message)))
        return false
    }
}
ShowLog(*) {
    GuiModules.log.Show()
}

ShowHelp(*) {
    GuiModules.help.Show()
}

ShowSupportInfo(*) {
    GuiModules.supportInfo.Show()
}

; 检查工作位于独立进程；这里只负责启动任务以及在结果返回后提供统一的用户决策。
CheckForApplicationUpdate(ownerGui := "", interactive := true, *) {
    try {
        started := App.applicationUpdateService.BeginCheck(interactive,
            ownerGui)
        if !started && interactive {
            ShowDarkMsgBox(Tr("更新检查正在进行，请稍候。"),
                Tr("检查更新"), "Info", ownerGui)
        }
        return started
    } catch as updateError {
        errorText := TrDiagnostic(updateError.Message)
        LogMsg(Tr("无法启动小助手更新检查：{1}", errorText))
        if interactive {
            ShowDarkMsgBox(Tr("无法检查更新：{1}", errorText),
                Tr("检查更新"), "Error", ownerGui)
        }
        return false
    }
}

HandleApplicationUpdateCheckResult(result, interactive := false,
    ownerGui := "") {
    ; 服务在进入结果回调前已经结束工作进程并清理计时器。无论结果内容
    ; 是否有效，都先恢复关于窗口按钮，避免异常结果让界面永久停在检查态。
    if IsSet(GuiModules)
        try GuiModules.about.SetUpdateCheckActive(false)
    if !IsObject(result)
        return
    activeOwner := ""
    if ownerGui && Type(ownerGui) == "Gui" {
        try {
            if WinExist(ownerGui.Hwnd)
                activeOwner := ownerGui
        }
    }
    if !activeOwner && IsSet(Main)
        activeOwner := Main.gui

    if result.Status == "error" {
        ; 早期检查器曾把“没有可安装更新”包装成错误。它表达的是正常的
        ; 最新版本状态，兼容读取后立即归一化，不能继续向用户展示失败框。
        noUpdateText := result.Error != "" ? result.Error : ""
        if noUpdateText == "没有可安装的应用更新"
            || noUpdateText == Tr("没有可安装的应用更新") {
            result := App.applicationUpdateService.CurrentResult()
        } else {
            errorText := result.Error != "" ? TrDiagnostic(result.Error)
                : Tr("未知错误")
            LogMsg(Tr("检查小助手更新失败：{1}", errorText))
            if interactive {
                ShowDarkMsgBox(Tr("检查更新失败：{1}", errorText),
                    Tr("检查更新"), "Error", activeOwner)
            }
            return
        }
    }
    if result.Status == "current" {
        LogMsg(Tr("小助手已是最新版本：{1}", result.CurrentVersion))
        if interactive {
            ShowDarkMsgBox(Tr("当前陪伴您的已经是最新版本的小助手啦！"),
                Tr("检查更新"), "Info", activeOwner)
        }
        return
    }
    if result.Status != "available" {
        LogMsg(Tr("更新检查返回了无法识别的状态：{1}", result.Status))
        return
    }

    LogMsg(Tr("发现小助手新版本：{1}（当前版本：{2}）",
        result.Version, result.CurrentVersion))
    updateMethod := A_IsCompiled
        ? Tr("将下载并校验完整发行包，退出小助手后替换程序文件并自动重启。")
        : (FileExist(A_ScriptDir "\.git")
            ? Tr("将确认源码仓库没有未提交修改，再快速前进到正式发布标签并自动重启。")
            : Tr("将下载并校验源码发行包，保留个人配置后替换源码并自动重启。"))
    message := Tr("发现新版本 {1}，当前版本为 {2}。{3}{3}{4}{3}{3}是否立即更新？",
        result.Version, result.CurrentVersion, Chr(10), updateMethod)
    if !ShowDarkConfirmBox(message, Tr("进程守护小助手更新"),
            Tr("立即更新"), Tr("稍后"), activeOwner)
        return
    try {
        App.applicationUpdateService.BeginInstall(result)
        LogMsg(Tr("更新助手已启动，小助手即将退出并完成更新。"))
        try HideMainGui(true)
        ExitApplication(0)
    } catch as installError {
        errorText := TrDiagnostic(installError.Message)
        LogMsg(Tr("无法启动小助手更新安装：{1}", errorText))
        ShowDarkMsgBox(Tr("无法开始更新：{1}", errorText),
            Tr("进程守护小助手更新"), "Error", activeOwner)
    }
}


; 计划任务使用 COM 接口读取和写入，操作前先确认同名任务确实属于当前脚本。
GetWatchdogTask() {
    try {
        service := ComObject("Schedule.Service")
        service.Connect()
        folder := service.GetFolder("\")
        return folder.GetTask("进程守护小助手")
    } catch {
        return ""
    }
}

IsOwnedWatchdogTask(task) {
    try {
        action := task.Definition.Actions.Item(1)
        commandLine := StrLower(action.Path " " action.Arguments)
        return InStr(commandLine, StrLower(A_ScriptFullPath)) > 0
    } catch {
        return false
    }
}

IsProjectWatchdogTask(task) {
    if !task
        return false
    if IsOwnedWatchdogTask(task)
        return true
    try {
        if task.Definition.RegistrationInfo.Source
            == "realSilasYang/process-watchdog"
            return true
    }
    try {
        action := task.Definition.Actions.Item(1)
        commandLine := StrLower(action.Path " " action.Arguments)
        SplitPath(A_ScriptFullPath, , , , &entryBaseName)
        sameInstallDirectory := InStr(commandLine,
            StrLower(A_ScriptDir "\")) > 0
        productEntry := InStr(commandLine,
            StrLower(entryBaseName ".ahk")) > 0
            || InStr(commandLine, StrLower(entryBaseName ".exe")) > 0
        return sameInstallDirectory && productEntry
    } catch {
        return false
    }
}

UpdateTaskButtonStatus() {
    GuiModules.settings.UpdateTaskButtonStatus()
}

; 切换当前用户登录时启动的计划任务；同名但目标不同的任务只提示冲突，绝不覆盖或删除。
ToggleTask(ownerGui := "", *) {
    try {
        service := ComObject("Schedule.Service")
        service.Connect()
        rootFolder := service.GetFolder("\")

        existingTask := GetWatchdogTask()
        taskOwnedByCurrentEntry := existingTask
            && IsOwnedWatchdogTask(existingTask)
        taskOwnedByProject := existingTask
            && IsProjectWatchdogTask(existingTask)
        if (existingTask && !taskOwnedByProject) {
            ShowDarkMsgBox(Tr("检测到同名计划任务，但它并非当前程序创建；为避免误删，请先在任务计划程序中处理它。"),
                Tr("计划任务冲突"), "Error", ownerGui)
            return
        }
        if taskOwnedByCurrentEntry {
            ; 已确认所有权后才允许删除，避免误伤用户自行创建的同名任务。
            rootFolder.DeleteTask("进程守护小助手", 0)
            LogMsg(Tr("已删除自启计划任务。"))
        } else {
            if taskOwnedByProject {
                ; 同一安装目录从 EXE 切到源码或反向切换时，更新产品自己的旧入口。
                rootFolder.DeleteTask("进程守护小助手", 0)
            }
            ; 新任务的触发器、运行条件、动作和权限主体一次性组装后再注册。
            taskDef := service.NewTask(0)

            ; 注册信息用于任务计划程序中的人工识别。
            taskDef.RegistrationInfo.Description := Tr("进程守护小助手 - 开机自启守护程序")
            taskDef.RegistrationInfo.Source := "realSilasYang/process-watchdog"

            ; 登录触发器比系统启动触发器更适合需要托盘图标的交互程序。
            trigger := taskDef.Triggers.Create(9) ; 9 即 TASK_TRIGGER_LOGON，表示用户登录触发。

            ; 任务在电池供电和长时间运行时都不应被计划程序自动终止。
            settings := taskDef.Settings
            settings.Enabled := true
            settings.Hidden := false

            settings.DisallowStartIfOnBatteries := false ; 允许在仅用电池时启动
            settings.StopIfGoingOnBatteries := false     ; 拔下电源时不停止任务

            ; PT0S 表示不设置执行时限，避免驻留程序被计划程序按默认时限结束。
            settings.ExecutionTimeLimit := "PT0S"        ; PT0S 代表不限制时间

            ; 兼容级别 6 对应 Windows 10 及更新版本的任务定义。
            settings.Compatibility := 6

            ; 通过 cmd 的 start 异步交接进程，使任务动作及时结束且应用进入交互会话。
            action := taskDef.Actions.Create(0) ; 0 即 TASK_ACTION_EXEC，表示执行程序动作。
            action.Path := A_ComSpec
            if A_IsCompiled {
                action.Arguments := '/c start "" "' A_ScriptFullPath '"'
            } else {
                action.Arguments := '/c start "" "' A_AhkPath '" "' A_ScriptFullPath '"'
            }
            action.WorkingDirectory := A_ScriptDir

            ; 使用当前交互用户令牌并请求最高权限，与应用正常启动时的权限要求一致。
            principal := taskDef.Principal
            principal.RunLevel := 1  ; 1 即 TASK_RUNLEVEL_HIGHEST，使用最高可用权限。
            principal.LogonType := 3 ; 3 即 TASK_LOGON_INTERACTIVE_TOKEN，使用交互用户令牌。

            ; 参数 6 表示创建或更新；前面的所有权检查保证这里不会覆盖别人的同名任务。
            rootFolder.RegisterTaskDefinition("进程守护小助手", taskDef, 6, "", "", 3)

            LogMsg(Tr("已创建最高权限的开机自启计划任务（Win10 配置，适配笔记本）。"))
        }

        UpdateTaskButtonStatus()

    } catch as taskErr {
        ShowDarkMsgBox(Tr("操作计划任务时发生错误！`n`n{1}",
            TrDiagnostic(taskErr.Message)),
            Tr("错误"), "Error", ownerGui)
        LogMsg(Tr("计划任务操作失败：{1}",
            TrDiagnostic(taskErr.Message)))
    }
}
