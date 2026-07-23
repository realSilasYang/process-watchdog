class SettingsWindow extends ManagedWindow {
    __New(mainGui) {
        this.owner := mainGui
        this.tabButtons := []
        this.tabButtonPages := []
        this.tabControls := []
        this.activeTab := 0
        this.intervalEdit := ""
        this.retryEdit := ""
        this.showAtStartupCheck := ""
        this.recursiveImportCheck := ""
        this.gracefulStopEdit := ""
        this.ctrlCWaitEdit := ""
        this.logMaxEdit := ""
        this.logDirEdit := ""
        this.logRetentionEdit := ""
        this.clearLogsOnStartupCheck := ""
        this.forceTerminateCheck := ""
        this.preferEverythingCheck := ""
        this.nativeScanTimeoutEdit := ""
        this.everythingMaxResultsEdit := ""
        this.taskButton := ""
    }

    Show(*) {
        if this.ShowExisting()
            return

        if !this.CreateOwnedGui(this.owner, "-MinimizeBox -MaximizeBox", "小助手设置")
            return
        try {
        this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
        this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
        SetDarkTitleBar(this.gui.Hwnd)
        SetWindowIcon(this.gui.Hwnd, A_ScriptDir "\watchdog.ico")
        this.gui.BackColor := "1E1E1E"
        this.gui.SetFont("s10 cWhite", "Microsoft YaHei")

        this.tabButtons := []
        this.tabButtonPages := []
        this.tabControls := []
        this.activeTab := 0
        Loop 5
            this.tabControls.Push([])

        this.gui.SetFont("s9 cWhite", "Microsoft YaHei")
        this.CreateTabButton(5, 15, 88, "系统集成")
        this.CreateTabButton(1, 107, 88, "监控与启动")
        this.CreateTabButton(2, 199, 88, "停止")
        this.CreateTabButton(3, 291, 52, "日志")
        this.CreateTabButton(4, 347, 88, "搜索与导入")
        this.gui.Add("Text", "x15 y46 w490 h1 Background3A3A3A")
        this.gui.SetFont("s10 cWhite", "Microsoft YaHei")

        this.AddTabControl(1, this.gui.Add("Text", "x25 y60 w210 h26 0x200 BackgroundTrans", "状态检查间隔（毫秒）:"))
        this.intervalEdit := this.AddSettingsEdit(1, 245, 60, 120, App.checkInterval, "Number")
        this.AddTabControl(1, this.gui.Add("Text", "x25 y96 w210 h26 0x200 BackgroundTrans", "重启等待序列（秒）:"))
        this.retryEdit := this.AddSettingsEdit(1, 245, 96, 190, App.retrySequence)
        this.showAtStartupCheck := this.AddTabControl(1, this.gui.Add("CheckBox", "x25 y136 w320 h24", "启动后显示主窗口"))
        this.showAtStartupCheck.Value := App.showAtStartup ? 1 : 0
        this.recursiveImportCheck := this.AddTabControl(1, this.gui.Add("CheckBox", "x25 y172 w420 h24", "批量导入文件夹时递归扫描子目录"))
        this.recursiveImportCheck.Value := App.recursiveBatchImport ? 1 : 0

        this.AddTabControl(2, this.gui.Add("Text", "x25 y60 w220 h26 0x200 BackgroundTrans", "窗口程序关闭等待（秒）:"))
        this.gracefulStopEdit := this.AddSettingsEdit(2, 255, 60, 110, App.gracefulStopSeconds, "Number")
        this.AddTabControl(2, this.gui.Add("Text", "x25 y96 w220 h26 0x200 BackgroundTrans", "命令行程序退出等待（秒）:"))
        this.ctrlCWaitEdit := this.AddSettingsEdit(2, 255, 96, 110, App.ctrlCWaitSeconds, "Number")
        this.forceTerminateCheck := this.AddTabControl(2, this.gui.Add("CheckBox", "x25 y136 w380 h24", "正常关闭超时后允许强制终止"))
        this.forceTerminateCheck.Value := App.allowForceTerminate ? 1 : 0

        this.AddTabControl(3, this.gui.Add("Text", "x25 y60 w220 h26 0x200 BackgroundTrans", "运行日志内存上限（条）:"))
        this.logMaxEdit := this.AddSettingsEdit(3, 255, 60, 110, App.logMaxEntries, "Number")
        this.AddTabControl(3, this.gui.Add("Text", "x25 y96 w220 h26 0x200 BackgroundTrans", "批处理日志保留时间（天）:"))
        this.logRetentionEdit := this.AddSettingsEdit(3, 255, 96, 110, App.logRetentionDays, "Number")
        this.AddTabControl(3, this.gui.Add("Text", "x25 y132 w220 h26 0x200 BackgroundTrans", "批处理日志保存目录:"))
        this.logDirEdit := this.AddSettingsEdit(3, 25, 162, 402, App.logDirectory)
        btnLogDir := this.AddTabControl(3, this.gui.Add("Text", "x431 y162 w64 h26 Center 0x200 Background333333 cWhite", "📂 浏览"))
        this.clearLogsOnStartupCheck := this.AddTabControl(3, this.gui.Add("CheckBox", "x25 y202 w350 h24", "启动时清空批处理日志"))
        this.clearLogsOnStartupCheck.Value := App.clearLogsOnStartup ? 1 : 0

        this.preferEverythingCheck := this.AddTabControl(4, this.gui.Add("CheckBox", "x25 y64 w360 h24", "优先使用 Everything 搜索"))
        this.preferEverythingCheck.Value := App.preferEverything ? 1 : 0
        this.AddTabControl(4, this.gui.Add("Text", "x25 y104 w220 h26 0x200 BackgroundTrans", "内置搜索最长扫描时间（秒）:"))
        this.nativeScanTimeoutEdit := this.AddSettingsEdit(4, 255, 104, 110, App.nativeScanTimeoutSeconds, "Number")
        this.AddTabControl(4, this.gui.Add("Text", "x25 y140 w220 h26 0x200 BackgroundTrans", "搜索结果数量上限:"))
        this.everythingMaxResultsEdit := this.AddSettingsEdit(4, 255, 140, 110, App.everythingMaxResults, "Number")

        this.AddTabControl(5, this.gui.Add("Text", "x25 y65 w300 h30 0x200 BackgroundTrans", "桌面与开始菜单快捷方式"))
        btnShortcut := this.AddTabControl(5, this.gui.Add("Text", "x423 y66 w72 h28 Center 0x200 Background333333 cWhite", "🔗 创建"))
        this.AddTabControl(5, this.gui.Add("Text", "x25 y108 w470 h1 Background333333"))
        this.AddTabControl(5, this.gui.Add("Text", "x25 y125 w300 h30 0x200 BackgroundTrans", "开机自动启动（计划任务）"))
        this.taskButton := this.AddTabControl(5, this.gui.Add("Text", "x423 y126 w72 h28 Center 0x200 Background333333 cWhite", "🚀 开启"))

        for editCtrl in [this.intervalEdit, this.retryEdit, this.gracefulStopEdit, this.ctrlCWaitEdit, this.logMaxEdit, this.logRetentionEdit, this.logDirEdit, this.nativeScanTimeoutEdit, this.everythingMaxResultsEdit]
            SetDarkControl(editCtrl.Hwnd)
        for checkCtrl in [this.showAtStartupCheck, this.recursiveImportCheck, this.forceTerminateCheck, this.clearLogsOnStartupCheck, this.preferEverythingCheck] {
            SetDarkControl(checkCtrl.Hwnd)
            RegisterHandCursorControl(checkCtrl)
        }

        btnSave := this.gui.Add("Text", "x183 y247 w72 h28 Center 0x200 Background0078D7 cWhite", "💾 保存")
        btnCancel := this.gui.Add("Text", "x265 y247 w72 h28 Center 0x200 Background333333 cWhite", "❌ 取消")
        RegisterHoverButton(btnLogDir, "333333")
        RegisterHoverButton(btnSave, "0078D7")
        RegisterHoverButton(btnCancel, "333333")
        RegisterHoverButton(btnShortcut, "333333")
        RegisterHoverButton(this.taskButton, "333333")
        RegisterButtonClick(btnSave, ObjBindMethod(this, "Save"), ButtonFeedbackMode.Dismissive)
        RegisterButtonClick(btnCancel, ObjBindMethod(this, "Close"), ButtonFeedbackMode.Dismissive)
        RegisterButtonClick(btnShortcut, ObjBindMethod(this, "CreateShortcut"))
        RegisterButtonClick(btnLogDir, ObjBindMethod(this, "BrowseLogDirectory"))
        RegisterButtonClick(this.taskButton, ObjBindMethod(this, "ToggleTaskAction"))
        this.UpdateTaskButtonStatus()
        this.SwitchTab(5)
        this.gui.Show("w520 h290")
        } catch as openErr {
            this.Close()
            throw openErr
        }
    }

    CreateTabButton(index, x, width, text) {
        button := this.gui.Add("Text", "x" x " y12 w" width " h28 Center 0x200 Background2D2D30 cE8E8E8", text)
        this.tabButtons.Push(button)
        this.tabButtonPages.Push(index)
        RegisterHoverButton(button, "2D2D30", "", "", "E8E8E8")
        RegisterButtonClick(button, ObjBindMethod(this, "SwitchTab", index))
        return button
    }

    AddTabControl(index, control) {
        this.tabControls[index].Push(control)
        return control
    }

    AddSettingsEdit(index, x, y, width, value, extraOptions := "") {
        inputControl := AddCenteredSingleLineEdit(this.gui, x, y, width, 26, value, extraOptions)
        this.AddTabControl(index, inputControl.Background)
        return this.AddTabControl(index, inputControl.Edit)
    }

    SwitchTab(index, *) {
        if (index < 1 || index > this.tabControls.Length)
            return
        for tabIndex, controls in this.tabControls {
            isVisible := tabIndex == index
            for control in controls
                try control.Visible := isVisible
        }
        for buttonIndex, button in this.tabButtons {
            isActive := this.tabButtonPages[buttonIndex] == index
            normalColor := isActive ? "005A9E" : "2D2D30"
            SetHoverButtonColors(button, normalColor)
            SetButtonBackground(button, normalColor)
        }
        this.activeTab := index
    }

    BrowseLogDirectory(*) {
        if !this.IsOpen()
            return
        this.gui.Opt("+OwnDialogs")
        initialDir := DirExist(this.logDirEdit.Value) ? this.logDirEdit.Value : App.logDirectory
        selected := FileSelect("D", initialDir, "选择批处理日志目录")
        if selected && this.IsOpen()
            this.logDirEdit.Value := selected
    }

    CreateShortcut(*) {
        if this.IsOpen()
            CreateDesktopShortcut(this.gui)
    }

    ToggleTaskAction(*) {
        if this.IsOpen()
            ToggleTask(this.gui)
    }

    Save(*) {
        if !this.IsOpen()
            return

        sequenceText := StrReplace(StrReplace(Trim(this.retryEdit.Value), " ", ""), "，", ",")
        newDelays := ParseRetrySequence(sequenceText)
        if !newDelays {
            ShowDarkMsgBox("重试序列格式错误！必须是逗号分隔的正整数（如: 1,10,60），每项范围为 1-86400 秒。", "参数错误", "Error", this.gui)
            return
        }
        if !IsValidCheckInterval(this.intervalEdit.Value) {
            ShowDarkMsgBox("轮询间隔必须为 500-86400000 毫秒的正整数！", "参数错误", "Error", this.gui)
            return
        }
        if (newDelays.Length == 0) {
            ShowDarkMsgBox("重试序列不能为空！", "参数错误", "Error", this.gui)
            return
        }

        gracefulStopSeconds := ParseBoundedInteger(this.gracefulStopEdit.Value, 1, 300)
        ctrlCWaitSeconds := ParseBoundedInteger(this.ctrlCWaitEdit.Value, 1, 60)
        logMaxEntries := ParseBoundedInteger(this.logMaxEdit.Value, 50, 10000)
        logRetentionDays := ParseBoundedInteger(this.logRetentionEdit.Value, 1, 3650)
        nativeScanTimeoutSeconds := ParseBoundedInteger(this.nativeScanTimeoutEdit.Value, 1, 120)
        everythingMaxResults := ParseBoundedInteger(this.everythingMaxResultsEdit.Value, 10, 1000)
        logDirectory := Trim(this.logDirEdit.Value)
        if !gracefulStopSeconds || !ctrlCWaitSeconds || !logMaxEntries || !logRetentionDays || !nativeScanTimeoutSeconds || !everythingMaxResults || logDirectory == "" {
            ShowDarkMsgBox("扩展设置包含无效数值。`n`n窗口程序关闭等待: 1-300 秒`n命令行程序退出等待: 1-60 秒`n日志条数: 50-10000`n日志保留: 1-3650 天`n内置搜索扫描: 1-120 秒`n搜索结果: 10-1000", "参数错误", "Error", this.gui)
            return
        }

        options := {
            ShowAtStartup: this.showAtStartupCheck.Value != 0,
            RecursiveBatchImport: this.recursiveImportCheck.Value != 0,
            LogMaxEntries: logMaxEntries,
            LogDirectory: logDirectory,
            LogRetentionDays: logRetentionDays,
            ClearLogsOnStartup: this.clearLogsOnStartupCheck.Value != 0,
            GracefulStopSeconds: gracefulStopSeconds,
            CtrlCWaitSeconds: ctrlCWaitSeconds,
            AllowForceTerminate: this.forceTerminateCheck.Value != 0,
            PreferEverything: this.preferEverythingCheck.Value != 0,
            NativeScanTimeoutSeconds: nativeScanTimeoutSeconds,
            EverythingMaxResults: everythingMaxResults
        }
        newInterval := Integer(this.intervalEdit.Value)
        newRetrySequence := this.retryEdit.Value
        options.CheckInterval := newInterval
        options.RetrySequence := newRetrySequence
        try savedSettings := App.runtimeSettingsService.Save(options)
        catch as saveError {
            LogMsg("保存运行参数失败: " saveError.Message)
            ShowDarkMsgBox("保存设置失败，请查看运行日志。", "保存失败", "Error", this.gui)
            return
        }

        App.runtimeSettingsService.Apply(App, savedSettings)
        while (App.logMessages.Length > App.logMaxEntries)
            App.logMessages.Pop()
        App.guardRuntime.RestartMonitorTimer()
        LogMsg("设置已更新: 轮询=" App.checkInterval "ms, 序列=[" App.retrySequence "], 日志上限=" App.logMaxEntries)
        this.Close()
    }

    UpdateTaskButtonStatus() {
        if !this.taskButton || Type(this.taskButton) != "Gui.Text"
            return
        this.taskButton.Text := CheckTaskExists() ? "🛑 关闭" : "🚀 开启"
    }

    Close(*) {
        this.DestroyGui()
        this.tabButtons := []
        this.tabButtonPages := []
        this.tabControls := []
        this.activeTab := 0
        this.intervalEdit := ""
        this.retryEdit := ""
        this.showAtStartupCheck := ""
        this.recursiveImportCheck := ""
        this.gracefulStopEdit := ""
        this.ctrlCWaitEdit := ""
        this.logMaxEdit := ""
        this.logDirEdit := ""
        this.logRetentionEdit := ""
        this.clearLogsOnStartupCheck := ""
        this.forceTerminateCheck := ""
        this.preferEverythingCheck := ""
        this.nativeScanTimeoutEdit := ""
        this.everythingMaxResultsEdit := ""
        this.taskButton := ""
    }
}
