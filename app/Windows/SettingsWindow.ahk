; 进程守护小助手设置窗口。
; 通用、监控与启动、停止策略和日志按选项卡组织；所有输入先完成范围校验，
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
        this.fontDropDownCommandHandler := ObjBindMethod(this,
            "OnFontDropDownCommand")
        this.fontDropDownCommandRegistered := false
        this.fontRefreshInProgress := false
        this.intervalEdit := ""
        this.retryEdit := ""
        this.showAtStartupCheck := ""
        this.checkUpdatesOnStartupCheck := ""
        this.recursiveImportCheck := ""
        this.gracefulStopEdit := ""
        this.ctrlCWaitEdit := ""
        this.logMaxEdit := ""
        this.logDirEdit := ""
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
            "RefreshTaskStatusAfterShow")
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
        windowWidth := isCompact ? 520 : 680
        actionX := windowWidth - 97
        InitializeApplicationWindow(this.gui, "s10", fontName)

        this.tabButtons := []
        this.tabButtonPages := []
        this.tabControls := []
        this.tabBuilt := []
        this.activeTab := 0
        Loop 4
            this.tabControls.Push([])
        Loop 4
            this.tabBuilt.Push(false)

        this.gui.SetFont("norm " (isCompact ? "s9" : "s8") " c"
            UiThemeService.Color("Text"), fontName)
        tabLabels := [Tr("通用"), Tr("监控与启动"), Tr("停止策略"),
            Tr("日志")]
        tabIconNames := ["sliders-horizontal.svg", "activity.svg",
            "octagon-x.svg", "logs.svg"]
        tabGap := 8
        tabWidths := this.GetTabButtonWidths(tabLabels, windowWidth - 30,
            isCompact, tabGap)
        tabGroupWidth := tabGap * (tabLabels.Length - 1)
        for tabWidth in tabWidths
            tabGroupWidth += tabWidth
        tabX := 15 + Floor(((windowWidth - 30) - tabGroupWidth) / 2)
        firstTabX := tabX
        for tabIndex, tabLabel in tabLabels {
            this.CreateTabButton(tabIndex, tabX, tabWidths[tabIndex],
                tabLabel, tabIconNames[tabIndex])
            tabX += tabWidths[tabIndex] + tabGap
        }
        ; 内容从首个选项卡的文字区域内侧起步。这个边界随语言对应的标签宽度
        ; 自动变化，避免复选框等左对齐控件比顶部导航更靠近窗口边缘。
        contentX := firstTabX + Floor(tabWidths[1] / 2)
        contentRight := windowWidth - 25
        contentWidth := contentRight - contentX
        inputX := isCompact ? 270 : Max(355, contentX + 285)
        labelWidth := inputX - contentX - 10
        this.layout := {
            IsCompact: isCompact,
            FontName: fontName,
            WindowWidth: windowWidth,
            ActionX: actionX,
            ContentX: contentX,
            ContentRight: contentRight,
            ContentWidth: contentWidth,
            InputX: inputX,
            LabelWidth: labelWidth
        }
        this.gui.Add("Text", "x15 y46 w" (windowWidth - 30)
            " h1 Background" UiThemeService.Color("Divider"))
        this.gui.SetFont("norm s10 c" UiThemeService.Color("Text"), fontName)

        ; 通用：系统入口、启动显示以及显示语言和内容字体。
        this.shortcutLabel := this.AddTabControl(1, this.gui.Add("Text",
            "x" contentX " y57 h28 0x200 BackgroundTrans",
            Tr("桌面与开始菜单快捷方式")))
        this.taskLabel := this.AddTabControl(1, this.gui.Add("Text",
            "x" contentX " y95 h28 0x200 BackgroundTrans",
            Tr("开机自动启动（计划任务）")))
        this.shortcutLabel.GetPos(, , &shortcutLabelWidth)
        this.taskLabel.GetPos(, , &taskLabelWidth)
        integrationLabelWidth := Max(shortcutLabelWidth, taskLabelWidth)
        integrationGap := 18
        integrationButtonWidth := 72
        integrationGroupWidth := integrationLabelWidth + integrationGap
            + integrationButtonWidth
        integrationGroupX := Max(15,
            Floor((windowWidth - integrationGroupWidth) / 2))
        integrationActionX := integrationGroupX + integrationLabelWidth
            + integrationGap
        this.shortcutLabel.Move(integrationGroupX)
        this.taskLabel.Move(integrationGroupX)
        this.shortcutButton := this.AddTabControl(1, this.gui.Add("Text", "x"
            integrationActionX " y57 w72 h28 Center 0x200 Background"
                UiThemeService.Color("Toolbar") " c"
                UiThemeService.Color("ToolbarText"),
            Tr("创建")))
        this.shortcutFeedbackText := this.AddTabControl(1,
            this.gui.Add("Text", "x" integrationActionX
                " y57 h28 Center 0x200 BackgroundTrans c"
                    UiThemeService.Color("Text"),
                Tr("创建成功！")))
        this.shortcutFeedbackText.GetPos(, , &shortcutFeedbackWidth)
        shortcutFeedbackWidth := Max(integrationButtonWidth,
            shortcutFeedbackWidth + 8)
        shortcutFeedbackX := integrationActionX
            + Floor((integrationButtonWidth - shortcutFeedbackWidth) / 2)
        shortcutFeedbackX := Max(integrationActionX - integrationGap + 4,
            Min(shortcutFeedbackX, contentRight - shortcutFeedbackWidth))
        this.shortcutFeedbackText.Move(shortcutFeedbackX, ,
            shortcutFeedbackWidth)
        this.taskButton := this.AddTabControl(1, this.gui.Add("Text", "x"
            integrationActionX " y95 w72 h28 Center 0x200 Background"
                UiThemeService.Color("Toolbar") " c"
                UiThemeService.Color("ToolbarText"),
            "…"))
        startupGap := 10
        showAtStartupWidth := isCompact ? 190 : 250
        showAtStartupX := contentRight - showAtStartupWidth
        checkUpdatesWidth := showAtStartupX - contentX - startupGap
        this.checkUpdatesOnStartupCheck := this.AddTabControl(1,
            this.gui.Add("CheckBox", "x" contentX " y133 w"
                checkUpdatesWidth " h24 c" UiThemeService.Color("Text"),
                Tr("启动时检查小助手更新")))
        this.checkUpdatesOnStartupCheck.Value :=
            App.checkUpdatesOnStartup ? 1 : 0
        this.showAtStartupCheck := this.AddTabControl(1,
            this.gui.Add("CheckBox", "x" showAtStartupX " y133 w"
                showAtStartupWidth " h24 c" UiThemeService.Color("Text"),
                Tr("启动时显示主窗口")))
        this.showAtStartupCheck.Value := App.showAtStartup ? 1 : 0
        this.AddTabControl(1, this.gui.Add("Text", "x" contentX " y169 w"
            contentWidth " h1 Background" UiThemeService.Color("Divider")))
        languageLabelWidth := isCompact ? 115 : 150
        languageInputX := contentX + languageLabelWidth + 10
        this.languageLabel := this.AddTabControl(1, this.gui.Add("Text",
            "x" contentX " y178 w" languageLabelWidth
                " h26 Right 0x200 BackgroundTrans", Tr("界面语言：")))
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
            "DropDownList", "x" languageInputX " y180 w"
                (actionX - languageInputX - 8) " Choose"
                selectedLanguageIndex " Background" UiThemeService.Color("Input")
                    " c" UiThemeService.Color("Text") " -Border -E0x200",
                AddComboBoxDisplayPadding(languageLabels)))
        ApplyDarkComboBoxTheme(this.languageDropDown.Hwnd)
        this.fontLabel := this.AddTabControl(1, this.gui.Add("Text",
            "x" contentX " y214 w" languageLabelWidth
                " h26 Right 0x200 BackgroundTrans", Tr("界面内容字体：")))
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
            "DropDownList", "x" languageInputX " y216 w"
                (actionX - languageInputX - 8) " r" fontDropDownRows " Choose"
                selectedFontIndex " Background" UiThemeService.Color("Input")
                    " c" UiThemeService.Color("Text") " -Border -E0x200",
                AddComboBoxDisplayPadding(fontLabels)))
        ApplyDarkComboBoxTheme(this.fontDropDown.Hwnd)
        OnMessage(Win32.WM_COMMAND, this.fontDropDownCommandHandler)
        this.fontDropDownCommandRegistered := true

        this.themeLabel := this.AddTabControl(1, this.gui.Add("Text",
            "x" contentX " y250 w" languageLabelWidth
                " h26 Right 0x200 BackgroundTrans", Tr("主题：")))
        this.themeValues := ["auto", "light", "dark"]
        themeLabels := [Tr("跟随系统"), Tr("浅色"), Tr("深色")]
        selectedThemeIndex := 1
        for themeIndex, themeCode in this.themeValues {
            if themeCode == App.uiTheme
                selectedThemeIndex := themeIndex
        }
        this.themeDropDown := this.AddTabControl(1, this.gui.Add(
            "DropDownList", "x" languageInputX " y252 w"
                (actionX - languageInputX - 8) " Choose"
                selectedThemeIndex " Background" UiThemeService.Color("Input")
                    " c" UiThemeService.Color("Text") " -Border -E0x200",
                AddComboBoxDisplayPadding(themeLabels)))
        ApplyDarkComboBoxTheme(this.themeDropDown.Hwnd)
        for labelAndInput in [
                [this.languageLabel, this.languageDropDown],
                [this.fontLabel, this.fontDropDown],
                [this.themeLabel, this.themeDropDown]] {
            this.AlignControlCentersVertically(labelAndInput[1],
                labelAndInput[2])
        }

        this.tabBuilt[1] := true

        for checkCtrl in [this.showAtStartupCheck,
                this.checkUpdatesOnStartupCheck] {
            SetDarkControl(checkCtrl.Hwnd)
            RegisterHandCursorControl(checkCtrl)
        }
        ; 通用页先完成布局并立即展示；其余页面在首次切换时按同一偏移创建。
        this.OffsetTabControlsY(8, 1)
        actionGroupX := Floor((windowWidth - 154) / 2)
        this.saveButton := this.gui.Add("Text", "x" actionGroupX " y308 w72 h28 Center 0x200 Background" UiThemeService.Color("Primary") " c" UiThemeService.Color("ButtonText"), Tr("保存"))
        this.cancelButton := this.gui.Add("Text", "x" (actionGroupX + 82) " y308 w72 h28 Center 0x200 Background" UiThemeService.Color("Toolbar") " c" UiThemeService.Color("ToolbarText"), Tr("取消"))
        RegisterHoverButton(this.saveButton, UiThemeService.Color("Primary"))
        RegisterHoverButton(this.cancelButton, UiThemeService.Color("Toolbar"))
        RegisterHoverButton(this.shortcutButton,
            UiThemeService.Color("Toolbar"))
        RegisterHoverButton(this.taskButton, UiThemeService.Color("Toolbar"))
        SetButtonLucideIcon(this.shortcutButton, "square-plus.svg", 14, 6)
        ; 计划任务状态稍后通过 COM 核对；首屏先显示中性的加载状态，
        ; 避免连接任务计划程序阻塞窗口出现，也不让临时文案误导用户操作。
        SetButtonLucideIcon(this.taskButton, "loader-circle.svg", 14, 6)
        SetRegisteredButtonEnabled(this.taskButton, false)
        RegisterButtonClick(this.saveButton, ObjBindMethod(this, "Save"), ButtonFeedbackMode.Dismissive)
        RegisterButtonClick(this.cancelButton, ObjBindMethod(this, "Close"), ButtonFeedbackMode.Dismissive)
        RegisterButtonClick(this.shortcutButton,
            ObjBindMethod(this, "CreateShortcut"))
        RegisterButtonClick(this.taskButton, ObjBindMethod(this, "ToggleTaskAction"))
        this.SwitchTab(1)
        this.shortcutFeedbackText.Visible := false
        ShowApplicationWindow(this.gui, "w" windowWidth " h350")
        ; 任务计划程序 COM 查询不参与首屏布局，窗口显示后再读取真实状态。
        SetTimer(this.taskStatusTimer, -1)
        ; 原生控件首次显示时可能重建主题句柄，显示后再同步一次收起区和弹出列表。
        ApplyDarkComboBoxTheme(this.languageDropDown.Hwnd)
        ApplyDarkComboBoxTheme(this.fontDropDown.Hwnd)
        ApplyDarkComboBoxTheme(this.themeDropDown.Hwnd)
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
                ? Min(132, Max(70, 42 + labelLength * 14))
                : Min(210, Max(78, 42 + labelLength * 7))
            tabWidths.Push(tabWidth)
            desiredTotal += tabWidth
        }
        contentWidth := availableWidth - tabGap * (tabLabels.Length - 1)
        if desiredTotal <= contentWidth
            return tabWidths

        minWidth := isCompact ? 64 : 72
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

    CreateTabButton(index, x, width, text, iconName) {
        button := this.gui.Add("Text", "x" x " y12 w" width " h28 Center 0x200 Background"
            UiThemeService.Color("Tab") " c" UiThemeService.Color("TabText"), text)
        this.tabButtons.Push(button)
        this.tabButtonPages.Push(index)
        RegisterHoverButton(button, UiThemeService.Color("Tab"), "", "",
            UiThemeService.Color("TabText"), "center")
        SetButtonLucideIcon(button, iconName, 14, 6)
        RegisterButtonClick(button, ObjBindMethod(this, "SwitchTab", index))
        return button
    }

    AddTabControl(index, control) {
        this.tabControls[index].Push(control)
        if this.activeTab && index != this.activeTab
            try control.Visible := false
        return control
    }

    CenterControlHorizontally(control, windowWidth) {
        control.GetPos(, , &controlWidth)
        control.Move(Max(15, Floor((windowWidth - controlWidth) / 2)))
    }

    AlignControlCentersVertically(labelControl, inputControl) {
        labelControl.GetPos(, , , &labelHeight)
        inputControl.GetPos(, &inputY, , &inputHeight)
        labelControl.Move(, Round(inputY + (inputHeight - labelHeight) / 2))
    }

    AddSettingsEdit(index, x, y, width, value, extraOptions := "") {
        inputControl := AddCenteredSingleLineEdit(this.gui, x, y, width, 26, value, extraOptions)
        this.AddTabControl(index, inputControl.Background)
        return this.AddTabControl(index, inputControl.Edit)
    }

    OffsetTabControlsY(offset, index := 0) {
        pages := index ? [this.tabControls[index]] : this.tabControls
        for controls in pages {
            for control in controls {
                try control.GetPos(, &controlY)
                try control.Move(, controlY + offset)
            }
        }
    }

    EnsureTabBuilt(index) {
        if index < 1 || index > this.tabBuilt.Length
            return false
        if this.tabBuilt[index]
            return true
        switch index {
            case 2: this.BuildMonitoringTab()
            case 3: this.BuildStopPolicyTab()
            case 4: this.BuildLogTab()
            default: return false
        }
        return this.tabBuilt[index]
    }

    BuildMonitoringTab() {
        layout := this.layout
        this.gui.SetFont("norm s10 c" UiThemeService.Color("Text"),
            layout.FontName)
        ; 监控与启动：所有数值标签右对齐，使输入框形成统一垂直线。
        this.AddTabControl(2, this.gui.Add("Text", "x" layout.ContentX
            " y60 w" layout.LabelWidth " h26 Right 0x200 BackgroundTrans",
            Tr("进程状态检查间隔（毫秒）：")))
        ; 固定宽度按各字段通常需要容纳的位数划分，内容变化时不改变布局。
        this.intervalEdit := this.AddSettingsEdit(2, layout.InputX, 60, 96,
            App.checkInterval, "Number")
        this.AddTabControl(2, this.gui.Add("Text", "x" layout.ContentX
            " y96 w" layout.LabelWidth " h26 Right 0x200 BackgroundTrans",
            Tr("崩溃自动重启延迟序列（秒）：")))
        this.retryEdit := this.AddSettingsEdit(2, layout.InputX, 96, 170,
            App.retrySequence)
        this.recursiveImportCheck := this.AddTabControl(2,
            this.gui.Add("CheckBox", "x0 y136 h24 c"
                UiThemeService.Color("Text"),
                Tr("导入文件夹时包含子目录")))
        this.CenterControlHorizontally(this.recursiveImportCheck,
            layout.WindowWidth)
        this.recursiveImportCheck.Value := App.recursiveBatchImport ? 1 : 0
        for editControl in [this.intervalEdit, this.retryEdit]
            SetDarkControl(editControl.Hwnd)
        SetDarkControl(this.recursiveImportCheck.Hwnd)
        RegisterHandCursorControl(this.recursiveImportCheck)
        this.OffsetTabControlsY(8, 2)
        this.tabBuilt[2] := true
    }

    BuildStopPolicyTab() {
        layout := this.layout
        this.gui.SetFont("norm s10 c" UiThemeService.Color("Text"),
            layout.FontName)
        ; 停止策略：分别约束 GUI 和 CLI 目标的正常关闭阶段。
        this.AddTabControl(3, this.gui.Add("Text", "x" layout.ContentX
            " y60 w" layout.LabelWidth " h26 Right 0x200 BackgroundTrans",
            Tr("GUI 程序关闭超时（秒）：")))
        this.gracefulStopEdit := this.AddSettingsEdit(3, layout.InputX,
            60, 64, App.gracefulStopSeconds, "Number")
        this.AddTabControl(3, this.gui.Add("Text", "x" layout.ContentX
            " y96 w" layout.LabelWidth " h26 Right 0x200 BackgroundTrans",
            Tr("CLI 程序关闭超时（秒）：")))
        this.ctrlCWaitEdit := this.AddSettingsEdit(3, layout.InputX, 96, 60,
            App.ctrlCWaitSeconds, "Number")
        this.forceTerminateCheck := this.AddTabControl(3,
            this.gui.Add("CheckBox", "x0 y136 h24 c"
                UiThemeService.Color("Text"),
                Tr("正常关闭超时后允许强制终止")))
        this.CenterControlHorizontally(this.forceTerminateCheck,
            layout.WindowWidth)
        this.forceTerminateCheck.Value := App.allowForceTerminate ? 1 : 0
        for editControl in [this.gracefulStopEdit, this.ctrlCWaitEdit]
            SetDarkControl(editControl.Hwnd)
        SetDarkControl(this.forceTerminateCheck.Hwnd)
        RegisterHandCursorControl(this.forceTerminateCheck)
        this.OffsetTabControlsY(8, 3)
        this.tabBuilt[3] := true
    }

    BuildLogTab() {
        layout := this.layout
        this.gui.SetFont("norm s10 c" UiThemeService.Color("Text"),
            layout.FontName)
        ; 日志：数量与天数沿用同一输入线，路径单独占满下一行。
        this.AddTabControl(4, this.gui.Add("Text", "x" layout.ContentX
            " y60 w" layout.LabelWidth " h26 Right 0x200 BackgroundTrans",
            Tr("运行日志显示上限（条）：")))
        this.logMaxEdit := this.AddSettingsEdit(4, layout.InputX, 60, 72,
            App.logMaxEntries, "Number")
        this.AddTabControl(4, this.gui.Add("Text", "x" layout.ContentX
            " y96 w" layout.LabelWidth " h26 Right 0x200 BackgroundTrans",
            Tr("批处理日志保留天数：")))
        this.logRetentionEdit := this.AddSettingsEdit(4, layout.InputX,
            96, 68, App.logRetentionDays, "Number")
        this.AddTabControl(4, this.gui.Add("Text", "x" layout.ContentX
            " y132 w" layout.LabelWidth " h26 Right 0x200 BackgroundTrans",
            Tr("批处理日志保存路径：")))
        this.logDirEdit := this.AddSettingsEdit(4, layout.InputX, 132,
            layout.ContentRight - layout.InputX, App.logDirectory)
        this.logBrowseButton := this.AddTabControl(4,
            this.gui.Add("Text", "x" layout.InputX
                " y168 w72 h26 Center 0x200 Background"
                    UiThemeService.Color("Toolbar") " c"
                    UiThemeService.Color("ToolbarText"), Tr("浏览")))
        this.clearLogsOnStartupCheck := this.AddTabControl(4,
            this.gui.Add("CheckBox", "x0 y208 h24 c"
                UiThemeService.Color("Text"),
                Tr("启动时清空批处理日志")))
        this.CenterControlHorizontally(this.clearLogsOnStartupCheck,
            layout.WindowWidth)
        this.clearLogsOnStartupCheck.Value :=
            App.clearLogsOnStartup ? 1 : 0
        for editControl in [this.logMaxEdit, this.logRetentionEdit,
                this.logDirEdit]
            SetDarkControl(editControl.Hwnd)
        SetDarkControl(this.clearLogsOnStartupCheck.Hwnd)
        RegisterHandCursorControl(this.clearLogsOnStartupCheck)
        RegisterHoverButton(this.logBrowseButton,
            UiThemeService.Color("Toolbar"))
        SetButtonLucideIcon(this.logBrowseButton, "folder-open.svg", 14, 6)
        RegisterButtonClick(this.logBrowseButton,
            ObjBindMethod(this, "BrowseLogDirectory"))
        this.OffsetTabControlsY(8, 4)
        this.tabBuilt[4] := true
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
        this.shortcutFeedbackText.Visible := this.activeTab == 1
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
        this.shortcutButton.Visible := this.activeTab == 1
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
        logMaxEntries := ParseBoundedInteger(logMaxValue, 50, 10000)
        logRetentionDays := ParseBoundedInteger(logRetentionValue, 1, 3650)
        logDirectory := Trim(logDirectoryValue)
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
            ShowAtStartup: this.showAtStartupCheck.Value != 0,
            CheckUpdatesOnStartup:
                this.checkUpdatesOnStartupCheck.Value != 0,
            RecursiveBatchImport: this.recursiveImportCheck
                ? this.recursiveImportCheck.Value != 0
                : App.recursiveBatchImport,
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
        displayChanged := languageChanged || fontChanged || themeChanged
        if displayChanged {
            try ApplyDisplaySettingsHot(savedSettings.UiLanguage,
                savedSettings.UiFont, savedSettings.Theme)
            catch as displayError {
                ; 配置已经原子写入。热应用失败时只撤销三个显示字段，其余经过
                ; 校验的设置仍然生效，避免一次字体异常吞掉用户的其它修改。
                savedSettings.UiLanguage := priorUiLanguage
                savedSettings.UiFont := priorUiFont
                savedSettings.Theme := priorUiTheme
                rollbackDetail := ""
                try App.configRepository.WriteValues("Settings", [
                    {Key: "UiLanguage", Value: priorUiLanguage},
                    {Key: "UiFont", Value: priorUiFont},
                    {Key: "Theme", Value: priorUiTheme}
                ])
                catch as rollbackError
                    rollbackDetail := Tr("；恢复配置失败：{1}",
                        TrDiagnostic(rollbackError.Message))
                App.runtimeSettingsService.Apply(App, savedSettings)
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
        } else if IsOwnedWatchdogTask(task) {
            this.taskButton.Text := Tr("关闭")
            iconName := "power.svg"
        } else if IsProjectWatchdogTask(task) {
            this.taskButton.Text := Tr("切换")
            iconName := "repeat-2.svg"
        } else {
            this.taskButton.Text := Tr("冲突")
            iconName := "triangle-alert.svg"
        }
        SetButtonLucideIcon(this.taskButton, iconName, 14, 6)
        SetRegisteredButtonEnabled(this.taskButton, true)
        return true
    }

    RefreshTaskStatusAfterShow(*) {
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
        this.DestroyGui()
        this.tabButtons := []
        this.tabButtonPages := []
        this.tabControls := []
        this.tabBuilt := []
        this.layout := ""
        this.activeTab := 0
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
        this.fontRefreshInProgress := false
        this.intervalEdit := ""
        this.retryEdit := ""
        this.showAtStartupCheck := ""
        this.checkUpdatesOnStartupCheck := ""
        this.recursiveImportCheck := ""
        this.gracefulStopEdit := ""
        this.ctrlCWaitEdit := ""
        this.logMaxEdit := ""
        this.logDirEdit := ""
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
