; ==========================================
; 11. 界面按钮事件处理与独立 GUI
; ==========================================
; 注册新监视进程：调用文件选择器后将对象推送至检测队列并入库
AddItem(*) {
    GuiModules.addItem.Show()
}

DelItem(*) {
    row := 0
    delList := []
    Loop {
        row := Main.lv.GetNext(row)
        if (row == 0)
            break
        delList.Push(row)
    }

    if (delList.Length == 0)
        return

    App.editSessionId++
    undoState := CaptureAppConfigState()

    ; 从后往前删防止行号错乱
    Loop delList.Length {
        idx := delList.Length - A_Index + 1
        currRow := delList[idx]
        try {
            delPath := Main.lv.GetText(currRow, 3)
            if App.appStates.Has(delPath) {
                App.appStates[delPath].CancelScheduledTasks()
                App.maintenanceCoordinator.CleanupTarget(delPath, App.appStates[delPath], true)
            }
            App.appStates.Delete(delPath)
            RemoveAppOrderPath(delPath)
            LogMsg("已取消监控: " delPath)
        }
        Main.lv.Delete(currRow)
    }

    Main.listProjection.Rebuild(Main.lv)

    CommitUndoState(undoState)
    SaveAppsToIni()
    Main.contextTargetRow := 0
    OnLVSelectChange() ; 刷新按钮显示状态
}

; ==========================================
; 显示程序基础设置面板界面
; ==========================================
ShowSettings(*) {
    GuiModules.settings.Show()
}

CreateDesktopShortcut(ownerGui := "", *) {
    try {
        desktopPath := A_Desktop "\进程守护小助手.lnk"
        programsPath := A_Programs "\进程守护小助手.lnk"
        scriptPath := A_ScriptFullPath
        iconPath := A_ScriptDir "\watchdog.ico"

        if A_IsCompiled {
            FileCreateShortcut(scriptPath, desktopPath, A_ScriptDir, "", "进程守护小助手", iconPath)
            FileCreateShortcut(scriptPath, programsPath, A_ScriptDir, "", "进程守护小助手", iconPath)
        } else {
            ; 指定快捷方式链接的根目标至 A_AhkPath 原宿主解释器环境，并赋予当前看门狗对应路径的图标定义信息
            FileCreateShortcut(A_AhkPath, desktopPath, A_ScriptDir, '"' scriptPath '"', "进程守护小助手", iconPath, , , 1)
            FileCreateShortcut(A_AhkPath, programsPath, A_ScriptDir, '"' scriptPath '"', "进程守护小助手", iconPath, , , 1)
        }
        ShowDarkMsgBox("桌面与开始菜单快捷方式创建成功！", "成功", "Info", ownerGui)
        LogMsg("已创建桌面与开始菜单快捷方式。")
    } catch as shortcutErr {
        ShowDarkMsgBox("创建快捷方式失败: " shortcutErr.Message, "错误", "Error", ownerGui)
        LogMsg("创建快捷方式失败: " shortcutErr.Message)
    }
}
ShowLog(*) {
    GuiModules.log.Show()
}

ShowHelp(*) {
    GuiModules.help.Show()
}


; ==========================================
; 12. 计划任务机制 (COM 接口高级配置)
; ==========================================
CheckTaskExists() {
    task := GetWatchdogTask()
    return task && IsOwnedWatchdogTask(task)
}

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

UpdateTaskButtonStatus() {
    GuiModules.settings.UpdateTaskButtonStatus()
}

; 用于添加/移除该看门狗脚本在 Windows 全局的系统自动开机计划任务
ToggleTask(ownerGui := "", *) {
    try {
        service := ComObject("Schedule.Service")
        service.Connect()
        rootFolder := service.GetFolder("\")

        existingTask := GetWatchdogTask()
        if (existingTask && !IsOwnedWatchdogTask(existingTask)) {
            ShowDarkMsgBox("检测到同名计划任务，但它并非当前程序创建；为避免误删，请先在任务计划程序中处理它。", "计划任务冲突", "Error", ownerGui)
            return
        }
        if existingTask {
            ; 删除任务
            rootFolder.DeleteTask("进程守护小助手", 0)
            LogMsg("已删除自启计划任务。")
        } else {
            ; 创建新任务
            taskDef := service.NewTask(0)

            ; 1. 注册信息
            taskDef.RegistrationInfo.Description := "进程守护小助手 - 开机自启守护程序"

            ; 2. 触发器 (开机/登录时触发)
            trigger := taskDef.Triggers.Create(9) ; 9 = TASK_TRIGGER_LOGON

            ; 3. 运行设置 (核心修改区)
            settings := taskDef.Settings
            settings.Enabled := true
            settings.Hidden := false

            ; 电源策略：电池供电时仍允许任务启动，切换供电状态时不停止任务
            settings.DisallowStartIfOnBatteries := false ; 允许在仅用电池时启动
            settings.StopIfGoingOnBatteries := false     ; 拔下电源时不停止任务

            ; 时间管理选项修正：配置全局 ExecutionTimeLimit 约束条件设为关闭(即 "PT0S" 最大长期不受中断)
            settings.ExecutionTimeLimit := "PT0S"        ; PT0S 代表不限制时间

            ; 使用 Windows 10/11 任务定义
            settings.Compatibility := 6

            ; 4. 操作 (通过 cmd start 异步启动，使计划任务能立即标记为“完成”并确保托盘图标正常显示)
            action := taskDef.Actions.Create(0) ; 0 = TASK_ACTION_EXEC
            action.Path := A_ComSpec
            if A_IsCompiled {
                action.Arguments := '/c start "" "' A_ScriptFullPath '"'
            } else {
                action.Arguments := '/c start "" "' A_AhkPath '" "' A_ScriptFullPath '"'
            }
            action.WorkingDirectory := A_ScriptDir

            ; 5. 权限主体 (最高管理员权限运行)
            principal := taskDef.Principal
            principal.RunLevel := 1  ; 1 = TASK_RUNLEVEL_HIGHEST
            principal.LogonType := 3 ; 3 = TASK_LOGON_INTERACTIVE_TOKEN

            ; 6. 注册写入任务
            ; 参数 6 = TASK_CREATE_OR_UPDATE
            rootFolder.RegisterTaskDefinition("进程守护小助手", taskDef, 6, "", "", 3)

            LogMsg("已创建最高权限的开机自启计划任务（Win10配置/适配笔记本）。")
        }

        UpdateTaskButtonStatus()
        ShowDarkMsgBox("计划任务状态已更新。", "提示", "Info", ownerGui)

    } catch as taskErr {
        ShowDarkMsgBox("操作计划任务时发生错误！`n`n" taskErr.Message, "错误", "Error", ownerGui)
        LogMsg("计划任务操作失败: " taskErr.Message)
    }
}
