; 进程守护小助手设置窗口。
; 显示、启动、监控、停止策略和日志按选项卡组织；所有输入先完成范围校验，
; 再通过配置服务一次提交并应用，避免部分字段已经生效而其余字段仍保存失败。

class SettingsWindow extends ManagedWindow {
    __New(mainGui) {
        this.owner := mainGui
        this.tabButtons := []
        this.tabButtonPages := []
        this.tabControls := []
        this.tabBuilt := []
        this.layout := ""
        this.activeTab := 0
        this.tabDivider := ""
        this.languageLabel := ""
        this.languageDropDown := ""
        this.languageCodes := []
        this.fontLabel := ""
        this.fontDropDown := ""
        this.fontValues := []
        this.fontDropDownTopIndex := 0
        this.themeLabel := ""
        this.themeDropDown := ""
        this.themeValues := []
        this.scaleLabel := ""
        this.scaleDropDown := ""
        this.scaleValues := []
        this.fontDropDownCommandHandler := ObjBindMethod(this,
            "OnFontDropDownCommand")
        this.fontDropDownCommandRegistered := false
        this.fontRefreshInProgress := false
        this.intervalLabel := ""
        this.intervalEdit := ""
        this.retryLabel := ""
        this.retryEdit := ""
        this.runAsAdministratorCheck := ""
        this.showAtStartupCheck := ""
        this.checkUpdatesOnStartupCheck := ""
        this.recursiveImportCheck := ""
        this.gracefulStopLabel := ""
        this.gracefulStopEdit := ""
        this.ctrlCWaitLabel := ""
        this.ctrlCWaitEdit := ""
        this.logMaxLabel := ""
        this.logMaxEdit := ""
        this.logDirLabel := ""
        this.logDirEdit := ""
        this.logRetentionLabel := ""
        this.logRetentionEdit := ""
        this.logBrowseButton := ""
        this.clearLogsOnStartupCheck := ""
        this.forceTerminateCheck := ""
        this.shortcutLabel := ""
        this.taskLabel := ""
        this.shortcutButton := ""
        this.shortcutFeedbackText := ""
        this.shortcutFeedbackTimer := 0
        this.shortcutFeedbackGeneration := 0
        this.taskButton := ""
        this.taskStatusTimer := ObjBindMethod(this,
            "RefreshTaskStatusAfterTabShow")
        this.saveButton := ""
        this.cancelButton := ""
    }

    Show(*) {
        if this.ShowExisting()
            return

        if !this.CreateOwnedGui(this.owner, "-MinimizeBox -MaximizeBox",
                Tr("进程守护小助手设置"))
            return
        try {
        this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
        this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
        isCompact := LocalizationService.UsesCompactLayout()
        fontName := LocalizationService.GetUiFontName()
        windowWidth := isCompact ? 460 : 600
        windowHeight := 390
        actionY := windowHeight - 40
        InitializeApplicationWindow(this.gui, "s10", fontName)

        this.tabButtons := []
        this.tabButtonPages := []
        this.tabControls := []
        this.tabBuilt := []
        this.activeTab := 0
        Loop 5
            this.tabControls.Push([])
        Loop 5
            this.tabBuilt.Push(false)

        this.gui.SetFont("norm s10 c"
            UiThemeService.Color("Text"), fontName)
        tabLabels := [Tr("显示"), Tr("启动"), Tr("监控"),
            Tr("停止策略"), Tr("日志")]
        tabIconNames := ["monitor.svg", "rocket.svg", "activity.svg",
            "octagon-x.svg", "logs.svg"]
        tabIconColorRoles := ["DisplayIcon", "StartupIcon", "MonitoringIcon",
            "StrongDangerIcon", "LogsIcon"]
        tabGap := 8
        tabWidths := this.GetTabButtonWidths(tabLabels, windowWidth - 30,
            isCompact, tabGap)
        tabGroupWidth := tabGap * (tabLabels.Length - 1)
        for tabWidth in tabWidths
            tabGroupWidth += tabWidth
        tabX := 15 + Floor(((windowWidth - 30) - tabGroupWidth) / 2)
        for tabIndex, tabLabel in tabLabels {
            this.CreateTabButton(tabIndex, tabX, tabWidths[tabIndex],
                tabLabel, tabIconNames[tabIndex],
                tabIconColorRoles[tabIndex])
            tabX += tabWidths[tabIndex] + tabGap
        }
        pageX := 30
        pageRight := windowWidth - 30
        displayFieldWidth := Min(isCompact ? 240 : 294,
            windowWidth - 60)
        displayFieldX := Floor((windowWidth - displayFieldWidth) / 2)
        this.layout := {
            IsCompact: isCompact,
            FontName: fontName,
            WindowWidth: windowWidth,
            WindowHeight: windowHeight,
            ContentX: pageX,
            ContentRight: pageRight,
            ContentWidth: pageRight - pageX,
            DisplayField: {X: displayFieldX, Width: displayFieldWidth},
            StartupChecks: "",
            MonitoringField: "",
            StopPolicyField: "",
            LogField: "",
            ActionY: actionY
        }
        this.tabDivider := this.gui.Add("Text", "x15 y48 w"
            (windowWidth - 30)
            " h1 Background" UiThemeService.Color("Divider"))
        this.gui.SetFont("norm s10 c" UiThemeService.Color("Text"), fontName)

        displayFieldFirstY := 70
        displayFieldRowGap := 68
        displayDropDownOffset := 30
        ; 显示页使用统一宽度的纵向字段：语义图标和标题在上，值控件在下一行。
        this.languageLabel := this.AddDisplayFieldHeader(displayFieldFirstY,
            Tr("界面语言："), "languages.svg", "LanguageIcon")
        languageLabels := []
        this.languageCodes := []
        selectedLanguageIndex := 1
        for choiceIndex, choice in LocalizationService.GetLanguageChoices() {
            this.languageCodes.Push(choice.Code)
            languageLabels.Push(choice.Label)
            if choice.Code == App.uiLanguage
                selectedLanguageIndex := choiceIndex
        }
        this.languageDropDown := this.AddTabControl(1, this.gui.Add(
            "DropDownList", "x" displayFieldX " y" (displayFieldFirstY
                + displayDropDownOffset) " w"
                displayFieldWidth " Choose"
                selectedLanguageIndex " Background" UiThemeService.Color("Input")
                    " c" UiThemeService.Color("Text") " -Border -E0x200",
                AddComboBoxDisplayPadding(languageLabels)))
        ApplyDarkComboBoxTheme(this.languageDropDown.Hwnd)
        this.fontLabel := this.AddDisplayFieldHeader(displayFieldFirstY
            + displayFieldRowGap,
            Tr("界面内容字体："), "type.svg", "FontIcon")
        fontLabels := [Tr("跟随语言默认（{1}）",
            LocalizationService.GetLanguageDefaultUiFontName())]
        this.fontValues := ["auto"]
        selectedFontIndex := 1
        for installedFont in LocalizationService.GetInstalledUiFontNames() {
            this.fontValues.Push(installedFont)
            fontLabels.Push(installedFont)
            if StrLower(installedFont) == StrLower(App.uiFont)
                selectedFontIndex := this.fontValues.Length
        }
        fontDropDownRows := 12
        this.fontDropDown := this.AddTabControl(1, this.gui.Add(
            "DropDownList", "x" displayFieldX " y" (displayFieldFirstY
                + displayFieldRowGap + displayDropDownOffset) " w"
                displayFieldWidth
                " r" fontDropDownRows " Choose"
                selectedFontIndex " Background" UiThemeService.Color("Input")
                    " c" UiThemeService.Color("Text") " -Border -E0x200",
                AddComboBoxDisplayPadding(fontLabels)))
        ApplyDarkComboBoxTheme(this.fontDropDown.Hwnd)
        OnMessage(Win32.WM_COMMAND, this.fontDropDownCommandHandler)
        this.fontDropDownCommandRegistered := true

        this.themeLabel := this.AddDisplayFieldHeader(displayFieldFirstY
            + displayFieldRowGap * 2,
            Tr("主题："), "palette.svg", "ThemeIcon")
        this.themeValues := ["auto", "light", "dark"]
        themeLabels := [Tr("跟随系统"), Tr("浅色"), Tr("深色")]
        selectedThemeIndex := 1
        for themeIndex, themeCode in this.themeValues {
            if themeCode == App.uiTheme
                selectedThemeIndex := themeIndex
        }
        this.themeDropDown := this.AddTabControl(1, this.gui.Add(
            "DropDownList", "x" displayFieldX " y" (displayFieldFirstY
                + displayFieldRowGap * 2 + displayDropDownOffset) " w"
                displayFieldWidth " Choose"
                selectedThemeIndex " Background" UiThemeService.Color("Input")
                    " c" UiThemeService.Color("Text") " -Border -E0x200",
                AddComboBoxDisplayPadding(themeLabels)))
        ApplyDarkComboBoxTheme(this.themeDropDown.Hwnd)
        this.scaleLabel := this.AddDisplayFieldHeader(displayFieldFirstY
            + displayFieldRowGap * 3,
            Tr("界面缩放："), "scan-search.svg", "DisplayIcon")
        this.scaleValues := UiScaleService.GetChoices()
        scaleLabels := []
        selectedScaleIndex := 1
        for scaleIndex, scaleValue in this.scaleValues {
            scaleLabels.Push(scaleValue "%")
            if scaleValue == App.uiScale
                selectedScaleIndex := scaleIndex
        }
        this.scaleDropDown := this.AddTabControl(1, this.gui.Add(
            "DropDownList", "x" displayFieldX " y" (displayFieldFirstY
                + displayFieldRowGap * 3 + displayDropDownOffset) " w"
                displayFieldWidth " Choose" selectedScaleIndex
                " Background" UiThemeService.Color("Input")
                    " c" UiThemeService.Color("Text") " -Border -E0x200",
                AddComboBoxDisplayPadding(scaleLabels)))
        ApplyDarkComboBoxTheme(this.scaleDropDown.Hwnd)
        this.tabBuilt[1] := true

        ; 显示页先完成布局并立即展示；其余页面在首次切换时创建。
        actionGroupX := Floor((windowWidth - 154) / 2)
        this.saveButton := this.gui.Add("Text", "x" actionGroupX " y"
            actionY " w72 h28 Center 0x200 Background"
                UiThemeService.Color("Save") " c"
                UiThemeService.Color("ButtonText"), Tr("保存"))
        this.cancelButton := this.gui.Add("Text", "x" (actionGroupX + 82)
            " y" actionY " w72 h28 Center 0x200 Background"
                UiThemeService.Color("Toolbar") " c"
                UiThemeService.Color("ToolbarText"), Tr("取消"))
        RegisterHoverButton(this.saveButton, UiThemeService.Color("Save"))
        RegisterHoverButton(this.cancelButton, UiThemeService.Color("Toolbar"))
        RegisterButtonClick(this.saveButton, ObjBindMethod(this, "Save"), ButtonFeedbackMode.Dismissive)
        RegisterButtonClick(this.cancelButton, ObjBindMethod(this, "Close"), ButtonFeedbackMode.Dismissive)
        this.SwitchTab(1)
        ShowApplicationWindow(this.gui, "w" windowWidth " h" windowHeight)
        ; 原生控件首次显示时可能重建主题句柄，显示后再同步一次收起区和弹出列表。
        ApplyDarkComboBoxTheme(this.languageDropDown.Hwnd)
        ApplyDarkComboBoxTheme(this.fontDropDown.Hwnd)
        ApplyDarkComboBoxTheme(this.themeDropDown.Hwnd)
        ApplyDarkComboBoxTheme(this.scaleDropDown.Hwnd)
        } catch as openErr {
            this.Close()
            throw openErr
        }
    }

    GetTabButtonWidths(tabLabels, availableWidth, isCompact, tabGap) {
        tabWidths := []
        desiredTotal := 0
        for tabLabel in tabLabels {
            labelLength := StrLen(tabLabel)
            tabWidth := isCompact
                ? Min(140, Max(76, 46 + labelLength * 14))
                : Min(220, Max(86, 46 + labelLength * 8))
            tabWidths.Push(tabWidth)
            desiredTotal += tabWidth
        }
        contentWidth := availableWidth - tabGap * (tabLabels.Length - 1)
        if desiredTotal <= contentWidth
            return tabWidths

        minWidth := isCompact ? 68 : 76
        adjustedTotal := 0
        scale := contentWidth / desiredTotal
        for tabIndex, tabWidth in tabWidths {
            tabWidths[tabIndex] := Max(minWidth, Floor(tabWidth * scale))
            adjustedTotal += tabWidths[tabIndex]
        }
        while adjustedTotal > contentWidth {
            for tabIndex, tabWidth in tabWidths {
                if adjustedTotal <= contentWidth
                    break
                if tabWidth > minWidth {
                    tabWidths[tabIndex] := tabWidth - 1
                    adjustedTotal--
                }
            }
        }
        return tabWidths
    }

    SplitFieldCaption(caption) {
        caption := Trim(caption)
        if RegExMatch(caption, "^(.*?)([：:])$", &parts)
            return {Label: Trim(parts[1]), Separator: parts[2]}
        return {Label: caption, Separator: "："}
    }

    CreateTabButton(index, x, width, text, iconName, iconColorRole) {
        button := this.gui.Add("Text", "x" x " y11 w" width " h30 Center 0x200 Background"
            UiThemeService.Color("Tab") " c" UiThemeService.Color("TabText"), text)
        this.tabButtons.Push(button)
        this.tabButtonPages.Push(index)
        RegisterHoverButton(button, UiThemeService.Color("Tab"), "", "",
            UiThemeService.Color("TabText"), "center")
        SetButtonLucideIcon(button, iconName, 14, 6,
            "theme:" iconColorRole)
        RegisterButtonClick(button, ObjBindMethod(this, "SwitchTab", index))
        return button
    }

    AddTabControl(index, control) {
        this.tabControls[index].Push(control)
        if this.activeTab && index != this.activeTab
            try control.Visible := false
        return control
    }

    AddDisplayFieldHeader(y, caption, iconName, iconColorRole) {
        fieldLayout := this.layout.DisplayField
        iconSize := 26
        iconControl := this.AddTabControl(1, this.gui.Add("Text",
            "x" fieldLayout.X " y" y " w" iconSize " h" iconSize
                " Center 0x200 Background" UiThemeService.Color("Window"),
            ""))
        ; 禁用的同色圆角控件只承担 SVG 绘制，不进入 Tab 顺序，也没有悬浮背景。
        RegisterHoverButton(iconControl, UiThemeService.Color("Window"),
            UiThemeService.Color("Window"), UiThemeService.Color("Window"))
        SetButtonLucideIcon(iconControl, iconName, 22, 0,
            "theme:" iconColorRole)
        SetRegisteredButtonEnabled(iconControl, false)
        return this.AddTabControl(1, this.gui.Add("Text",
            "x" (fieldLayout.X + 32) " y" y " w"
                (fieldLayout.Width - 32)
                " h26 0x200 BackgroundTrans",
            this.SplitFieldCaption(caption).Label))
    }

    AddSettingsFieldLabel(index, y, caption, groupControls := "") {
        labelControl := this.AddTabControl(index, this.gui.Add("Text",
            "x0 y" y " h24 0x200 BackgroundTrans",
            this.SplitFieldCaption(caption).Label))
        if IsObject(groupControls)
            groupControls.Push(labelControl)
        return labelControl
    }

    AddSettingsEdit(index, x, y, width, value, extraOptions := "",
            groupControls := "") {
        inputControl := AddCenteredSingleLineEdit(this.gui, x, y, width,
            26, value, extraOptions)
        backgroundControl := this.AddTabControl(index,
            inputControl.Background)
        editControl := this.AddTabControl(index, inputControl.Edit)
        if IsObject(groupControls) {
            groupControls.Push(backgroundControl)
            groupControls.Push(editControl)
        }
        return editControl
    }

    CenterSettingsControlGroup(controls) {
        groupWidth := 0
        for control in controls {
            control.GetPos(, , &controlWidth)
            groupWidth := Max(groupWidth, controlWidth)
        }
        groupX := Max(15,
            Floor((this.layout.WindowWidth - groupWidth) / 2))
        for control in controls
            control.Move(groupX)
        return {X: groupX, Width: groupWidth}
    }

    EnsureTabBuilt(index) {
        if index < 1 || index > this.tabBuilt.Length
            return false
        if this.tabBuilt[index]
            return true
        switch index {
            case 2: this.BuildStartupTab()
            case 3: this.BuildMonitoringTab()
            case 4: this.BuildStopPolicyTab()
            case 5: this.BuildLogTab()
            default: return false
        }
        return this.tabBuilt[index]
    }

    BuildStartupTab() {
        layout := this.layout
        this.gui.SetFont("norm s10 c" UiThemeService.Color("Text"),
            layout.FontName)

        ; 启动与系统集成集中在页面顶部，保留标签按钮组与三项启动偏好的紧凑结构。
        integrationFirstY := 70
        integrationRowGap := 36
        startupCheckFirstY := 144
        startupCheckRowGap := 32
        this.shortcutLabel := this.AddTabControl(2, this.gui.Add("Text",
            "x" layout.ContentX " y" integrationFirstY
                " h28 0x200 BackgroundTrans",
            Tr("桌面与开始菜单快捷方式")))
        this.taskLabel := this.AddTabControl(2, this.gui.Add("Text",
            "x" layout.ContentX " y" (integrationFirstY
                + integrationRowGap) " h28 0x200 BackgroundTrans",
            Tr("开机自动启动（计划任务）")))
        this.shortcutLabel.GetPos(, , &shortcutLabelWidth)
        this.taskLabel.GetPos(, , &taskLabelWidth)
        integrationLabelWidth := Max(shortcutLabelWidth, taskLabelWidth)
        integrationGap := 18
        integrationButtonWidth := 72
        integrationGroupWidth := integrationLabelWidth + integrationGap
            + integrationButtonWidth
        integrationGroupX := Max(15,
            Floor((layout.WindowWidth - integrationGroupWidth) / 2))
        integrationActionX := integrationGroupX + integrationLabelWidth
            + integrationGap
        this.shortcutLabel.Move(integrationGroupX)
        this.taskLabel.Move(integrationGroupX)
        this.shortcutButton := this.AddTabControl(2, this.gui.Add("Text", "x"
            integrationActionX " y" integrationFirstY
                " w72 h28 Center 0x200 Background"
                UiThemeService.Color("Toolbar") " c"
                UiThemeService.Color("ToolbarText"), Tr("创建")))
        this.shortcutFeedbackText := this.AddTabControl(2,
            this.gui.Add("Text", "x" integrationActionX
                " y" integrationFirstY " h28 Center 0x200 BackgroundTrans c"
                    UiThemeService.Color("Text"), Tr("创建成功！")))
        this.shortcutFeedbackText.GetPos(, , &shortcutFeedbackWidth)
        shortcutFeedbackWidth := Max(integrationButtonWidth,
            shortcutFeedbackWidth + 8)
        shortcutFeedbackX := integrationActionX
            + Floor((integrationButtonWidth - shortcutFeedbackWidth) / 2)
        shortcutFeedbackX := Max(integrationActionX - integrationGap + 4,
            Min(shortcutFeedbackX,
                layout.ContentRight - shortcutFeedbackWidth))
        this.shortcutFeedbackText.Move(shortcutFeedbackX, ,
            shortcutFeedbackWidth)
        this.taskButton := this.AddTabControl(2, this.gui.Add("Text", "x"
            integrationActionX " y" (integrationFirstY + integrationRowGap)
                " w72 h28 Center 0x200 Background"
                UiThemeService.Color("Toolbar") " c"
                UiThemeService.Color("ToolbarText"), "…"))
        startupChecks := []
        this.runAsAdministratorCheck := this.AddTabControl(2,
            this.gui.Add("CheckBox", "x0 y" startupCheckFirstY " h24 c"
                UiThemeService.Color("Text"),
                Tr("以管理员身份运行")))
        startupChecks.Push(this.runAsAdministratorCheck)
        this.runAsAdministratorCheck.Value :=
            App.runAsAdministrator ? 1 : 0
        this.checkUpdatesOnStartupCheck := this.AddTabControl(2,
            this.gui.Add("CheckBox", "x0 y" (startupCheckFirstY
                + startupCheckRowGap) " h24 c"
                UiThemeService.Color("Text"),
                Tr("启动时检查小助手更新")))
        startupChecks.Push(this.checkUpdatesOnStartupCheck)
        this.checkUpdatesOnStartupCheck.Value :=
            App.checkUpdatesOnStartup ? 1 : 0
        this.showAtStartupCheck := this.AddTabControl(2,
            this.gui.Add("CheckBox", "x0 y" (startupCheckFirstY
                + startupCheckRowGap * 2) " h24 c"
                UiThemeService.Color("Text"),
                Tr("启动时显示主窗口")))
        startupChecks.Push(this.showAtStartupCheck)
        this.showAtStartupCheck.Value := App.showAtStartup ? 1 : 0
        layout.StartupChecks := this.CenterSettingsControlGroup(startupChecks)
        for checkControl in [this.runAsAdministratorCheck,
                this.checkUpdatesOnStartupCheck,
                this.showAtStartupCheck] {
            SetDarkControl(checkControl.Hwnd)
            RegisterHandCursorControl(checkControl)
        }
        RegisterHoverButton(this.shortcutButton,
            UiThemeService.Color("Toolbar"))
        RegisterHoverButton(this.taskButton, UiThemeService.Color("Toolbar"))
        SetButtonLucideIcon(this.shortcutButton, "square-plus.svg", 14, 6,
            "theme:BrowseIcon")
        ; 任务状态只在该页首次显示后查询，创建阶段保持中性加载状态。
        SetButtonLucideIcon(this.taskButton, "loader-circle.svg", 14, 6,
            "theme:InitializingIcon")
        SetRegisteredButtonEnabled(this.taskButton, false)
        RegisterButtonClick(this.shortcutButton,
            ObjBindMethod(this, "CreateShortcut"))
        RegisterButtonClick(this.taskButton,
            ObjBindMethod(this, "ToggleTaskAction"))
        this.shortcutFeedbackText.Visible := false
        this.tabBuilt[2] := true
    }

    BuildMonitoringTab() {
        layout := this.layout
        this.gui.SetFont("norm s10 c" UiThemeService.Color("Text"),
            layout.FontName)
        ; 监控字段按本页最长控件整体居中，标题和值控件共享左边界。
        fieldControls := []
        this.intervalLabel := this.AddSettingsFieldLabel(3, 70,
            Tr("进程状态检查间隔（毫秒）："), fieldControls)
        this.intervalEdit := this.AddSettingsEdit(3, 0, 96,
            80, App.checkInterval, "Number", fieldControls)
        this.retryLabel := this.AddSettingsFieldLabel(3, 150,
            Tr("崩溃自动重启延迟序列（秒）："), fieldControls)
        this.retryEdit := this.AddSettingsEdit(3, 0, 176, 147,
            App.retrySequence, "", fieldControls)
        this.askBeforeRestartFromStopCountLabel := this.AddSettingsFieldLabel(
            3, 230, Tr("如果设置了恢复前询问，应从第几次停止开始询问？"), fieldControls)
        this.askBeforeRestartFromStopCountEdit := this.AddSettingsEdit(3, 0,
            256, 60, App.askBeforeRestartFromStopCount, "Number",
            fieldControls)
        this.recursiveImportCheck := this.AddTabControl(3,
            this.gui.Add("CheckBox", "x0 y302 h24 c"
                UiThemeService.Color("Text"),
                Tr("导入文件夹时包含子目录")))
        fieldControls.Push(this.recursiveImportCheck)
        layout.MonitoringField := this.CenterSettingsControlGroup(
            fieldControls)
        this.recursiveImportCheck.Value := App.recursiveBatchImport ? 1 : 0
        for editControl in [this.intervalEdit, this.retryEdit,
                this.askBeforeRestartFromStopCountEdit]
            SetDarkControl(editControl.Hwnd)
        SetDarkControl(this.recursiveImportCheck.Hwnd)
        RegisterHandCursorControl(this.recursiveImportCheck)
        this.tabBuilt[3] := true
    }

    BuildStopPolicyTab() {
        layout := this.layout
        this.gui.SetFont("norm s10 c" UiThemeService.Color("Text"),
            layout.FontName)
        ; 停止策略字段沿用统一的“标题在上、值在下”结构。
        fieldControls := []
        this.gracefulStopLabel := this.AddSettingsFieldLabel(4, 70,
            Tr("GUI 程序关闭超时（秒）："), fieldControls)
        this.gracefulStopEdit := this.AddSettingsEdit(4, 0,
            96, 43, App.gracefulStopSeconds, "Number", fieldControls)
        this.ctrlCWaitLabel := this.AddSettingsFieldLabel(4, 150,
            Tr("CLI 程序关闭超时（秒）："), fieldControls)
        this.ctrlCWaitEdit := this.AddSettingsEdit(4, 0, 176,
            40, App.ctrlCWaitSeconds, "Number", fieldControls)
        this.forceTerminateCheck := this.AddTabControl(4,
            this.gui.Add("CheckBox", "x0 y222 h24 c"
                UiThemeService.Color("Text"),
                Tr("正常关闭超时后允许强制终止")))
        fieldControls.Push(this.forceTerminateCheck)
        layout.StopPolicyField := this.CenterSettingsControlGroup(
            fieldControls)
        this.forceTerminateCheck.Value := App.allowForceTerminate ? 1 : 0
        for editControl in [this.gracefulStopEdit, this.ctrlCWaitEdit]
            SetDarkControl(editControl.Hwnd)
        SetDarkControl(this.forceTerminateCheck.Hwnd)
        RegisterHandCursorControl(this.forceTerminateCheck)
        this.tabBuilt[4] := true
    }

    BuildLogTab() {
        layout := this.layout
        this.gui.SetFont("norm s10 c" UiThemeService.Color("Text"),
            layout.FontName)
        ; 日志字段保留短控件组的左边界；路径框只向右延长，不重新居中。
        fieldControls := []
        this.logMaxLabel := this.AddSettingsFieldLabel(5, 70,
            Tr("运行日志显示上限（条）："), fieldControls)
        this.logMaxEdit := this.AddSettingsEdit(5, 0, 96, 48,
            App.logMaxEntries, "Number", fieldControls)
        this.logRetentionLabel := this.AddSettingsFieldLabel(5, 132,
            Tr("批处理日志保留天数："), fieldControls)
        this.logRetentionEdit := this.AddSettingsEdit(5, 0,
            158, 45, App.logRetentionDays, "Number", fieldControls)
        this.logDirLabel := this.AddSettingsFieldLabel(5, 194,
            Tr("批处理日志保存路径："), fieldControls)
        logFieldAnchorWidth := layout.IsCompact ? 240 : 294
        logFieldX := Floor((layout.WindowWidth - logFieldAnchorWidth) / 2)
        logPathWidth := Min(Round(logFieldAnchorWidth * 1.5),
            layout.ContentRight - logFieldX)
        this.logDirEdit := this.AddSettingsEdit(5, 0, 220,
            logPathWidth, App.logDirectory, "", fieldControls)
        this.logBrowseButton := this.AddTabControl(5,
            this.gui.Add("Text", "x0 y258 w72 h26 Center 0x200 Background"
                    UiThemeService.Color("Toolbar") " c"
                    UiThemeService.Color("ToolbarText"), Tr("浏览")))
        fieldControls.Push(this.logBrowseButton)
        this.clearLogsOnStartupCheck := this.AddTabControl(5,
            this.gui.Add("CheckBox", "x0 y296 h24 c"
                UiThemeService.Color("Text"),
                Tr("启动时清空批处理日志")))
        fieldControls.Push(this.clearLogsOnStartupCheck)
        logFieldWidth := 0
        for fieldControl in fieldControls {
            fieldControl.GetPos(, , &fieldControlWidth)
            logFieldWidth := Max(logFieldWidth, fieldControlWidth)
            fieldControl.Move(logFieldX)
        }
        layout.LogField := {X: logFieldX, Width: logFieldWidth,
            AnchorWidth: logFieldAnchorWidth, PathWidth: logPathWidth}
        this.clearLogsOnStartupCheck.Value :=
            App.clearLogsOnStartup ? 1 : 0
        for editControl in [this.logMaxEdit, this.logRetentionEdit,
                this.logDirEdit]
            SetDarkControl(editControl.Hwnd)
        SetDarkControl(this.clearLogsOnStartupCheck.Hwnd)
        RegisterHandCursorControl(this.clearLogsOnStartupCheck)
        RegisterHoverButton(this.logBrowseButton,
            UiThemeService.Color("Toolbar"))
        SetButtonLucideIcon(this.logBrowseButton, "folder-open.svg", 14, 6,
            "theme:BrowseIcon")
        RegisterButtonClick(this.logBrowseButton,
            ObjBindMethod(this, "BrowseLogDirectory"))
        this.tabBuilt[5] := true
    }

    OnFontDropDownCommand(wParam, lParam, *) {
        ; 只处理字体控件的展开和关闭通知，避免其它下拉框触发字体枚举。
        if !this.fontDropDownCommandRegistered || !this.IsOpen()
            || !this.fontDropDown || lParam != this.fontDropDown.Hwnd
            return
        notificationCode := (wParam >> 16) & 0xFFFF
        if notificationCode == Win32.CBN_CLOSEUP {
            this.CaptureFontDropDownTopIndex()
            return
        }
        if notificationCode != Win32.CBN_DROPDOWN
            return
        this.RefreshFontDropDown()
        this.RestoreFontDropDownTopIndex()
    }

    CaptureFontDropDownTopIndex() {
        if !this.fontDropDown
            return this.fontDropDownTopIndex
        topIndex := SendMessage(Win32.CB_GETTOPINDEX, 0, 0,
            this.fontDropDown.Hwnd)
        if topIndex >= 0
            this.fontDropDownTopIndex := topIndex
        return this.fontDropDownTopIndex
    }

    RestoreFontDropDownTopIndex() {
        if !this.fontDropDown || !this.fontValues.Length
            return false
        topIndex := Max(0, Min(this.fontDropDownTopIndex,
            this.fontValues.Length - 1))
        SendMessage(Win32.CB_SETTOPINDEX, topIndex, 0,
            this.fontDropDown.Hwnd)
        return true
    }

    RefreshFontDropDown(*) {
        if this.fontRefreshInProgress || !this.IsOpen()
            || !this.fontDropDown
            return false
        this.fontRefreshInProgress := true
        try {
            selectedFont := "auto"
            selectedIndex := this.fontDropDown.Value
            if selectedIndex >= 1 && selectedIndex <= this.fontValues.Length
                selectedFont := this.fontValues[selectedIndex]

            LocalizationService.RefreshInstalledUiFontNames()
            defaultFontName := LocalizationService
                .GetLanguageDefaultUiFontName()
            refreshedFonts := LocalizationService.GetInstalledUiFontNames()
            fontLabels := [Tr("跟随语言默认（{1}）", defaultFontName)]
            refreshedValues := ["auto"]
            refreshedSelection := 1
            for installedFont in refreshedFonts {
                refreshedValues.Push(installedFont)
                fontLabels.Push(installedFont)
                if StrLower(installedFont) == StrLower(selectedFont)
                    refreshedSelection := refreshedValues.Length
            }

            ; 删除条目可能让原生 ComboBox 重建弹出列表句柄，先撤销旧注册，
            ; 更新完成后再应用深色主题和滚动条绘制。
            UnregisterDarkComboBoxTheme(this.fontDropDown.Hwnd)
            this.fontDropDown.Delete()
            this.fontDropDown.Add(AddComboBoxDisplayPadding(fontLabels))
            this.fontValues := refreshedValues
            this.fontDropDown.Value := refreshedSelection
            ApplyDarkComboBoxTheme(this.fontDropDown.Hwnd)
            return true
        } finally this.fontRefreshInProgress := false
    }

    SuspendTabRedraw() {
        transaction := {Active: false, Hwnd: 0}
        if !this.IsOpen()
            return transaction
        hwnd := this.gui.Hwnd
        if !DllCall("user32\IsWindowVisible", "Ptr", hwnd, "Int")
            return transaction

        ; 父窗口暂停绘制后，批量显隐子控件不会把中间状态提交到屏幕。不能对
        ; 隐藏页子控件逐个发送 WM_SETREDRAW：DefWindowProc 会改写 WS_VISIBLE，
        ; 恢复时反而可能让本应隐藏的控件重新出现。
        transaction.Hwnd := hwnd
        transaction.Active := true
        try {
            DllCall("user32\SendMessageW", "Ptr", hwnd,
                "UInt", Win32.WM_SETREDRAW, "Ptr", false,
                "Ptr", 0, "Ptr")
        } catch as suspendError {
            this.ResumeTabRedraw(transaction)
            throw suspendError
        }
        return transaction
    }

    ResumeTabRedraw(transaction) {
        if !IsObject(transaction) || !transaction.Active
            return
        transaction.Active := false
        hwnd := transaction.Hwnd
        if !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
            return
        DllCall("user32\SendMessageW", "Ptr", hwnd,
            "UInt", Win32.WM_SETREDRAW, "Ptr", true, "Ptr", 0, "Ptr")
        DllCall("user32\RedrawWindow", "Ptr", hwnd, "Ptr", 0,
            "Ptr", 0, "UInt", Win32.RDW_LAYOUT_REFRESH, "Int")
    }

    SetTabButtonVisualState(button, normalColor, textColor) {
        SetHoverButtonColors(button, normalColor)
        try hwnd := button.Hwnd
        catch
            return false
        if !App.uiInteractions.HasButton(hwnd) {
            SetButtonBackground(button, normalColor)
            SetButtonTextColor(button, textColor)
            return false
        }
        ; 切页事务结束时由父窗口统一重绘。这里只更新所有者绘制状态，不让
        ; 背景色、文字色各自生成一帧；抬起后 50 ms 反馈尚未结束时仍保留
        ; 当前按压色，随后定时器会恢复到这里写入的新 normal。
        state := App.uiInteractions.GetButton(hwnd)
        if !state.HasOwnProp("releaseResetTimer") || !state.releaseResetTimer
            state.current := normalColor
        state.textColor := textColor
        RefreshButtonImageTint(state)
        return true
    }

    SwitchTab(index, *) {
        if (index < 1 || index > this.tabControls.Length)
            return
        if this.activeTab == index
            return true

        redrawTransaction := this.SuspendTabRedraw()
        try {
            ; 首次访问页面时，控件的创建和初始隐藏也必须位于同一绘制事务中，
            ; 否则新控件会在 AddTabControl 隐藏它之前短暂出现在当前页面。
            if !this.EnsureTabBuilt(index)
                return
            ApplyApplicationWindowScale(this.gui)
            for tabIndex, controls in this.tabControls {
                isVisible := tabIndex == index
                for control in controls {
                    controlVisible := isVisible
                    if control == this.shortcutFeedbackText
                        controlVisible := isVisible
                            && !!this.shortcutFeedbackTimer
                    else if control == this.shortcutButton
                        controlVisible := isVisible
                            && !this.shortcutFeedbackTimer
                    try control.Visible := controlVisible
                }
            }
            for buttonIndex, button in this.tabButtons {
                isActive := this.tabButtonPages[buttonIndex] == index
                normalColor := isActive ? UiThemeService.Color("TabActive")
                    : UiThemeService.Color("Tab")
                textColor := isActive ? UiThemeService.Color("TabActiveText")
                    : UiThemeService.Color("TabText")
                this.SetTabButtonVisualState(button, normalColor, textColor)
            }
            this.activeTab := index
            if index == 2 && this.taskButton
                SetTimer(this.taskStatusTimer, -1)
            return true
        } finally this.ResumeTabRedraw(redrawTransaction)
    }

    BrowseLogDirectory(*) {
        if !this.IsOpen()
            return
        this.gui.Opt("+OwnDialogs")
        initialDir := DirExist(this.logDirEdit.Value) ? this.logDirEdit.Value : App.logDirectory
        selected := SelectDirectoryWithModernDialog(this.gui.Hwnd,
            initialDir, Tr("选择批处理日志目录"))
        if selected && this.IsOpen()
            this.logDirEdit.Value := selected
    }

    CreateShortcut(*) {
        if this.IsOpen() && CreateDesktopShortcut(this.gui)
            this.ShowShortcutCreatedFeedback()
    }

    ShowShortcutCreatedFeedback() {
        if !this.IsOpen() || !this.shortcutButton
            || !this.shortcutFeedbackText
            return false
        this.CancelShortcutFeedback()
        this.shortcutFeedbackGeneration++
        generation := this.shortcutFeedbackGeneration
        this.shortcutButton.Visible := false
        this.shortcutFeedbackText.Visible := this.activeTab == 2
        timer := ObjBindMethod(this, "RestoreShortcutButton", generation)
        this.shortcutFeedbackTimer := timer
        SetTimer(timer, -3000)
        return true
    }

    RestoreShortcutButton(generation, *) {
        if generation != this.shortcutFeedbackGeneration
            return
        this.shortcutFeedbackTimer := 0
        if !this.IsOpen() || !this.shortcutButton
            || !this.shortcutFeedbackText
            return
        this.shortcutFeedbackText.Visible := false
        this.shortcutButton.Visible := this.activeTab == 2
    }

    CancelShortcutFeedback() {
        if this.shortcutFeedbackTimer
            try SetTimer(this.shortcutFeedbackTimer, 0)
        this.shortcutFeedbackTimer := 0
        this.shortcutFeedbackGeneration++
    }

    ToggleTaskAction(*) {
        if this.IsOpen()
            ToggleTask(this.gui)
    }

    Save(*) {
        if !this.IsOpen()
            return
        QueueExclusiveGuardMutation(this, "save",
            ObjBindMethod(this, "SaveTransaction"))
    }

    SaveTransaction() {
        if !this.IsOpen()
            return

        intervalValue := this.intervalEdit ? this.intervalEdit.Value
            : App.checkInterval
        retrySequenceValue := this.retryEdit ? this.retryEdit.Value
            : App.retrySequence
        askBeforeRestartFromStopCountValue :=
            this.askBeforeRestartFromStopCountEdit
                ? this.askBeforeRestartFromStopCountEdit.Value
                : App.askBeforeRestartFromStopCount
        gracefulStopValue := this.gracefulStopEdit
            ? this.gracefulStopEdit.Value : App.gracefulStopSeconds
        ctrlCWaitValue := this.ctrlCWaitEdit ? this.ctrlCWaitEdit.Value
            : App.ctrlCWaitSeconds
        logMaxValue := this.logMaxEdit ? this.logMaxEdit.Value
            : App.logMaxEntries
        logRetentionValue := this.logRetentionEdit
            ? this.logRetentionEdit.Value : App.logRetentionDays
        logDirectoryValue := this.logDirEdit ? this.logDirEdit.Value
            : App.logDirectory
        sequenceText := StrReplace(StrReplace(Trim(retrySequenceValue),
            " ", ""), "，", ",")
        newDelays := ParseRetrySequence(sequenceText)
        if !newDelays {
            ShowDarkMsgBoxDeferred(Tr("崩溃自动重启延迟序列格式错误！必须是逗号分隔的正整数（如：1,10,60），每项范围为 1-86400 秒。"),
                Tr("参数错误"), "Error", this.gui)
            return
        }
        if !IsValidCheckInterval(intervalValue) {
            ShowDarkMsgBoxDeferred(Tr("进程状态检查间隔必须为 500-86400000 毫秒的正整数！"),
                Tr("参数错误"), "Error", this.gui)
            return
        }
        if (newDelays.Length == 0) {
            ShowDarkMsgBoxDeferred(Tr("崩溃自动重启延迟序列不能为空！"),
                Tr("参数错误"), "Error", this.gui)
            return
        }

        gracefulStopSeconds := ParseBoundedInteger(gracefulStopValue, 1, 300)
        ctrlCWaitSeconds := ParseBoundedInteger(ctrlCWaitValue, 1, 60)
        askBeforeRestartFromStopCount := ParseBoundedInteger(
            askBeforeRestartFromStopCountValue, 1, 9999)
        logMaxEntries := ParseBoundedInteger(logMaxValue, 50, 10000)
        logRetentionDays := ParseBoundedInteger(logRetentionValue, 1, 3650)
        logDirectory := Trim(logDirectoryValue)
        if !askBeforeRestartFromStopCount {
            ShowDarkMsgBoxDeferred(Tr("停止后询问恢复的起始停止次数必须为 1-9999。"),
                Tr("参数错误"), "Error", this.gui)
            return
        }
        if !gracefulStopSeconds || !ctrlCWaitSeconds || !logMaxEntries
            || !logRetentionDays || logDirectory == "" {
            ShowDarkMsgBoxDeferred(Tr("扩展设置包含无效数值。`n`nGUI 程序关闭超时：1-300 秒`nCLI 程序关闭超时：1-60 秒`n运行日志显示上限：50-10000 条`n批处理日志保留天数：1-3650 天"),
                Tr("参数错误"), "Error", this.gui)
            return
        }

        options := {
            UiLanguage: this.languageCodes[this.languageDropDown.Value],
            UiFont: this.fontValues[this.fontDropDown.Value],
            Theme: this.themeValues[this.themeDropDown.Value],
            UiScale: this.scaleValues[this.scaleDropDown.Value],
            ShowAtStartup: this.showAtStartupCheck
                ? this.showAtStartupCheck.Value != 0 : App.showAtStartup,
            RunAsAdministrator: this.runAsAdministratorCheck
                ? this.runAsAdministratorCheck.Value != 0
                : App.runAsAdministrator,
            CheckUpdatesOnStartup: this.checkUpdatesOnStartupCheck
                ? this.checkUpdatesOnStartupCheck.Value != 0
                : App.checkUpdatesOnStartup,
            RecursiveBatchImport: this.recursiveImportCheck
                ? this.recursiveImportCheck.Value != 0
                : App.recursiveBatchImport,
            AskBeforeRestartFromStopCount: askBeforeRestartFromStopCount,
            LogMaxEntries: logMaxEntries,
            LogDirectory: logDirectory,
            LogRetentionDays: logRetentionDays,
            ClearLogsOnStartup: this.clearLogsOnStartupCheck
                ? this.clearLogsOnStartupCheck.Value != 0
                : App.clearLogsOnStartup,
            GracefulStopSeconds: gracefulStopSeconds,
            CtrlCWaitSeconds: ctrlCWaitSeconds,
            AllowForceTerminate: this.forceTerminateCheck
                ? this.forceTerminateCheck.Value != 0
                : App.allowForceTerminate
        }
        newInterval := Integer(intervalValue)
        newRetrySequence := retrySequenceValue
        options.CheckInterval := newInterval
        options.RetrySequence := newRetrySequence
        priorSettings := App.runtimeSettingsService.Load()
        try candidateSettings := App.runtimeSettingsService.Validate(options)
        catch as validationError {
            LogMsg(Tr("保存运行参数失败：{1}",
                TrDiagnostic(validationError.Message)))
            ShowDarkMsgBoxDeferred(Tr("保存设置失败，请查看运行日志。"),
                Tr("保存失败"), "Error", this.gui)
            return
        }
        settingsChanged := GetRuntimeSettingsHistoryFields(priorSettings,
            candidateSettings).Length > 0
        if !settingsChanged {
            this.Close()
            return
        }
        priorUiLanguage := App.uiLanguage
        priorUiFont := App.uiFont
        priorUiTheme := App.uiTheme
        priorUiScale := App.uiScale
        priorCheckInterval := App.checkInterval
        try savedSettings := App.runtimeSettingsService.Save(candidateSettings)
        catch as saveError {
            LogMsg(Tr("保存运行参数失败：{1}",
                TrDiagnostic(saveError.Message)))
            ShowDarkMsgBoxDeferred(Tr("保存设置失败，请查看运行日志。"),
                Tr("保存失败"), "Error", this.gui)
            return
        }

        languageChanged := savedSettings.UiLanguage != priorUiLanguage
        fontChanged := savedSettings.UiFont != priorUiFont
        themeChanged := savedSettings.Theme != priorUiTheme
        scaleChanged := savedSettings.UiScale != priorUiScale
        elevationSettingChanged := savedSettings.RunAsAdministrator
            != priorSettings.RunAsAdministrator
        askBeforeRestartFromStopCountChanged :=
            savedSettings.AskBeforeRestartFromStopCount
                != priorSettings.AskBeforeRestartFromStopCount
        displayChanged := languageChanged || fontChanged || themeChanged
            || scaleChanged
        if displayChanged {
            try ApplyDisplaySettingsHot(savedSettings.UiLanguage,
                savedSettings.UiFont, savedSettings.Theme,
                savedSettings.UiScale)
            catch as displayError {
                ; 配置已经原子写入。热应用失败时只撤销三个显示字段，其余经过
                ; 校验的设置仍然生效，避免一次字体异常吞掉用户的其它修改。
                savedSettings.UiLanguage := priorUiLanguage
                savedSettings.UiFont := priorUiFont
                savedSettings.Theme := priorUiTheme
                savedSettings.UiScale := priorUiScale
                rollbackDetail := ""
                try App.configRepository.WriteValues("Settings", [
                    {Key: "UiLanguage", Value: priorUiLanguage},
                    {Key: "UiFont", Value: priorUiFont},
                    {Key: "Theme", Value: priorUiTheme}
                    , {Key: "UiScale", Value: priorUiScale}
                ])
                catch as rollbackError
                    rollbackDetail := Tr("；恢复配置失败：{1}",
                        TrDiagnostic(rollbackError.Message))
                App.runtimeSettingsService.Apply(App, savedSettings)
                if askBeforeRestartFromStopCountChanged
                    ResetAskBeforeRestartStopCounts()
                if elevationSettingChanged
                    ApplyRuntimeElevationSettingChange(
                        priorSettings.RunAsAdministrator,
                        savedSettings.RunAsAdministrator)
                if App.checkInterval != priorCheckInterval
                    App.guardRuntime.RestartMonitorTimer()
                while (App.logMessages.Length > App.logMaxEntries)
                    App.logMessages.Pop()
                CommitRuntimeSettingsUndoState(priorSettings, savedSettings)
                errorDetail := TrDiagnostic(displayError.Message)
                    . rollbackDetail
                LogMsg(Tr("界面显示设置无法即时应用，已恢复原语言、字体和主题：{1}",
                    errorDetail))
                this.Close()
                ShowDarkMsgBoxDeferred(Tr("无法即时切换界面语言、字体或主题，原显示设置已恢复。`n`n{1}",
                    errorDetail), Tr("显示设置应用失败"), "Error", Main.gui)
                return
            }
        }

        App.runtimeSettingsService.Apply(App, savedSettings)
        if askBeforeRestartFromStopCountChanged
            ResetAskBeforeRestartStopCounts()
        if elevationSettingChanged
            ApplyRuntimeElevationSettingChange(
                priorSettings.RunAsAdministrator,
                savedSettings.RunAsAdministrator)
        while (App.logMessages.Length > App.logMaxEntries)
            App.logMessages.Pop()
        if App.checkInterval != priorCheckInterval
            App.guardRuntime.RestartMonitorTimer()
        CommitRuntimeSettingsUndoState(priorSettings, savedSettings)
        LogMsg(Tr("设置已更新：进程检查间隔={1}ms，重启延迟序列=[{2}]，日志显示上限={3}",
            App.checkInterval, App.retrySequence, App.logMaxEntries))
        if displayChanged
            LogMsg(Tr("界面语言、字体和主题已即时更新，无需重新启动小助手。"))
        this.Close()
    }

    UpdateTaskButtonStatus() {
        if !this.taskButton || Type(this.taskButton) != "Gui.Text"
            return false
        task := GetWatchdogTask()
        if !this.IsOpen() || !this.taskButton
            || Type(this.taskButton) != "Gui.Text"
            return false
        if !task {
            this.taskButton.Text := Tr("开启")
            iconName := "play.svg"
            iconColorRole := "SuccessIcon"
        } else if IsOwnedWatchdogTask(task)
                && WatchdogTaskRunLevelMatches(task,
                    App.runAsAdministrator) {
            this.taskButton.Text := Tr("关闭")
            iconName := "power.svg"
            iconColorRole := "StrongDangerIcon"
        } else if IsProjectWatchdogTask(task) {
            this.taskButton.Text := Tr("切换")
            iconName := "repeat-2.svg"
            iconColorRole := "RelocationIcon"
        } else {
            this.taskButton.Text := Tr("冲突")
            iconName := "triangle-alert.svg"
            iconColorRole := "WarningIcon"
        }
        SetButtonLucideIcon(this.taskButton, iconName, 14, 6,
            "theme:" iconColorRole)
        SetRegisteredButtonEnabled(this.taskButton, true)
        return true
    }

    RefreshTaskStatusAfterTabShow(*) {
        try SetTimer(this.taskStatusTimer, 0)
        if !this.IsOpen()
            return false
        return this.UpdateTaskButtonStatus()
    }

    Close(*) {
        try SetTimer(this.taskStatusTimer, 0)
        this.CancelShortcutFeedback()
        if this.fontDropDownCommandRegistered {
            try OnMessage(Win32.WM_COMMAND,
                this.fontDropDownCommandHandler, 0)
            this.fontDropDownCommandRegistered := false
        }
        if this.languageDropDown
            try UnregisterDarkComboBoxTheme(this.languageDropDown.Hwnd)
        if this.fontDropDown
            try UnregisterDarkComboBoxTheme(this.fontDropDown.Hwnd)
        if this.themeDropDown
            try UnregisterDarkComboBoxTheme(this.themeDropDown.Hwnd)
        if this.scaleDropDown
            try UnregisterDarkComboBoxTheme(this.scaleDropDown.Hwnd)
        this.DestroyGui()
        this.tabButtons := []
        this.tabButtonPages := []
        this.tabControls := []
        this.tabBuilt := []
        this.layout := ""
        this.activeTab := 0
        this.tabDivider := ""
        this.languageLabel := ""
        this.languageDropDown := ""
        this.languageCodes := []
        this.fontLabel := ""
        this.fontDropDown := ""
        this.fontValues := []
        this.fontDropDownTopIndex := 0
        this.themeLabel := ""
        this.themeDropDown := ""
        this.themeValues := []
        this.scaleLabel := ""
        this.scaleDropDown := ""
        this.scaleValues := []
        this.fontRefreshInProgress := false
        this.intervalLabel := ""
        this.intervalEdit := ""
        this.retryLabel := ""
        this.retryEdit := ""
        this.runAsAdministratorCheck := ""
        this.showAtStartupCheck := ""
        this.checkUpdatesOnStartupCheck := ""
        this.recursiveImportCheck := ""
        this.gracefulStopLabel := ""
        this.gracefulStopEdit := ""
        this.ctrlCWaitLabel := ""
        this.ctrlCWaitEdit := ""
        this.logMaxLabel := ""
        this.logMaxEdit := ""
        this.logDirLabel := ""
        this.logDirEdit := ""
        this.logRetentionLabel := ""
        this.logRetentionEdit := ""
        this.logBrowseButton := ""
        this.clearLogsOnStartupCheck := ""
        this.forceTerminateCheck := ""
        this.shortcutLabel := ""
        this.taskLabel := ""
        this.shortcutButton := ""
        this.shortcutFeedbackText := ""
        this.shortcutFeedbackTimer := 0
        this.taskButton := ""
        this.saveButton := ""
        this.cancelButton := ""
    }
}
