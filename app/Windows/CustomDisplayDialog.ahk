; 主列表自定义名称与图标窗口。
; 这里保存的内容只改变主窗口展示，不修改启动入口、进程身份或升级保护判断；
; 默认值与当前展示一致时恢复按钮保持不可用，避免制造没有实际变化的配置记录。

class CustomDisplayDialog extends ManagedWindow {
    __New(mainGui) {
        this.owner := mainGui
        this.path := ""
        this.state := ""
        this.nameEdit := ""
        this.iconEdit := ""
        this.defaultNameButton := ""
        this.defaultIconButton := ""
    }

    Show(path, stateObj) {
        if this.ShowExisting()
            return
        this.path := path
        this.state := stateObj
        displayConfig := stateObj.HasOwnProp("DisplayConfig")
            ? App.displayConfigCodec.Normalize(stateObj.DisplayConfig)
            : App.displayConfigCodec.CreateDefault()
        compactLayout := LocalizationService.UsesCompactLayout()
        windowWidth := compactLayout ? 540 : 650
        defaultButtonWidth := compactLayout ? 80 : 128
        defaultButtonX := windowWidth - 20 - defaultButtonWidth
        browseButtonWidth := 70
        browseButtonX := defaultButtonX - 10 - browseButtonWidth
        if !this.CreateOwnedGui(this.owner,
            "-MinimizeBox -MaximizeBox", Tr("自定义名称和图标"))
            return
        try {
            InitializeApplicationWindow(this.gui)

            this.gui.Add("Text", "x20 y14 w" (windowWidth - 40)
                " h20 BackgroundTrans", Tr("守护对象："))
            targetInput := AddCenteredSingleLineEdit(this.gui,
                20, 38, windowWidth - 40, 26, path, "ReadOnly",
                UiThemeService.Color("Surface"))
            RegisterTextInputControl(targetInput.Edit, true)

            this.gui.Add("Text", "x20 y78 w160 h20 BackgroundTrans", Tr("显示名称："))
            nameInput := AddCenteredSingleLineEdit(this.gui,
                20, 102, defaultButtonX - 30, 26, displayConfig.Name,
                "Limit120", UiThemeService.Color("Input"))
            this.nameEdit := nameInput.Edit
            this.defaultNameButton := this.gui.Add("Text",
                "x" defaultButtonX " y102 w" defaultButtonWidth
                    " h26 Center 0x200 Background"
                    UiThemeService.Color("Toolbar") " c"
                    UiThemeService.Color("ToolbarText"),
                Tr("恢复默认"))

            this.gui.Add("Text", "x20 y142 w160 h20 BackgroundTrans", Tr("图标来源："))
            iconInput := AddCenteredSingleLineEdit(this.gui,
                20, 166, browseButtonX - 30, 26, displayConfig.IconPath,
                "", UiThemeService.Color("Input"))
            this.iconEdit := iconInput.Edit
            btnBrowse := this.gui.Add("Text",
                "x" browseButtonX " y166 w" browseButtonWidth
                    " h26 Center 0x200 Background"
                    UiThemeService.Color("Toolbar") " c"
                    UiThemeService.Color("ToolbarText"),
                Tr("浏览"))
            this.defaultIconButton := this.gui.Add("Text",
                "x" defaultButtonX " y166 w" defaultButtonWidth
                    " h26 Center 0x200 Background"
                    UiThemeService.Color("Toolbar") " c"
                    UiThemeService.Color("ToolbarText"),
                Tr("恢复默认"))

            actionStartX := Round((windowWidth - 170) / 2)
            btnSave := this.gui.Add("Text",
                "x" actionStartX " y212 w80 h28 Center 0x200 Background"
                    UiThemeService.Color("Save") " c"
                    UiThemeService.Color("ButtonText"),
                Tr("保存"))
            btnCancel := this.gui.Add("Text",
                "x" (actionStartX + 90) " y212 w80 h28 Center 0x200 Background"
                    UiThemeService.Color("Toolbar") " c"
                    UiThemeService.Color("ToolbarText"),
                Tr("取消"))

            for editControl in [targetInput.Edit, this.nameEdit, this.iconEdit]
                SetDarkControl(editControl.Hwnd)
            for button in [this.defaultNameButton, btnBrowse,
                this.defaultIconButton, btnCancel]
                RegisterHoverButton(button, UiThemeService.Color("Toolbar"))
            RegisterHoverButton(btnSave, UiThemeService.Color("Save"))
            SetButtonLucideIcon(btnBrowse, "folder-open.svg", 14, 6)
            RegisterButtonClick(this.defaultNameButton,
                ObjBindMethod(this, "UseDefaultName"))
            RegisterButtonClick(btnBrowse, ObjBindMethod(this, "BrowseIcon"))
            RegisterButtonClick(this.defaultIconButton,
                ObjBindMethod(this, "UseDefaultIcon"))
            RegisterButtonClick(btnSave, ObjBindMethod(this, "Save"),
                ButtonFeedbackMode.Dismissive)
            RegisterButtonClick(btnCancel, ObjBindMethod(this, "Close"),
                ButtonFeedbackMode.Dismissive)
            this.nameEdit.OnEvent("Change",
                ObjBindMethod(this, "UpdateDefaultButtonStates"))
            this.iconEdit.OnEvent("Change",
                ObjBindMethod(this, "UpdateDefaultButtonStates"))
            this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
            this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
            ShowApplicationWindow(this.gui, "w" windowWidth " h260")
            ShowSingleLineEditFromStart(targetInput.Edit)
            this.UpdateDefaultButtonStates()
        } catch as openErr {
            this.Close()
            throw openErr
        }
    }

    UseDefaultName(*) {
        if this.IsOpen() {
            this.nameEdit.Value := ""
            this.UpdateDefaultButtonStates()
        }
    }

    UseDefaultIcon(*) {
        if this.IsOpen() {
            this.iconEdit.Value := ""
            this.UpdateDefaultButtonStates()
        }
    }

    UpdateDefaultButtonStates(*) {
        if !this.IsOpen()
            return
        SetRegisteredButtonEnabled(this.defaultNameButton,
            Trim(this.nameEdit.Value) != "")
        SetRegisteredButtonEnabled(this.defaultIconButton,
            Trim(this.iconEdit.Value) != "")
    }

    BrowseIcon(*) {
        if !this.IsOpen()
            return
        initialSource := ParseCustomIconSource(this.iconEdit.Value)
        initialPath := initialSource.Path
        if (initialPath == "" || !FileExist(initialPath)) {
            initialSource := ParseCustomIconSource(
                GetMainDisplayIconSource(this.path, this.state))
            initialPath := initialSource.Path
        }
        if !FileExist(initialPath)
            initialPath := ""
        this.gui.Opt("+OwnDialogs")
        selected := SelectFileWithNamedFilter(this.gui.Hwnd, initialPath,
            Tr("选择主窗口图标"), Tr("支持的图标与图片"),
            "*.ico;*.exe;*.dll;*.cpl;*.lnk;*.png;*.jpg;*.jpeg;*.jpe;*.jfif;*.bmp;*.gif;*.tif;*.tiff;*.webp;*.svg;*.ani")
        if selected && this.IsOpen() {
            SplitPath(selected, , , &extension)
            if IsIconResourceContainerExtension(extension) {
                selectedIndex := PathsEquivalent(selected,
                    initialSource.Path) && initialSource.HasIndex
                    ? initialSource.Index : 0
                selectedSource := PickCustomIconResource(this.gui.Hwnd,
                    selected, selectedIndex)
                if selectedSource != ""
                    this.iconEdit.Value := selectedSource
            } else {
                this.iconEdit.Value := selected
            }
        }
        this.UpdateDefaultButtonStates()
    }

    Save(*) {
        if !this.IsOpen()
            return
        QueueExclusiveGuardMutation(this, "save",
            ObjBindMethod(this, "SaveTransaction"))
    }

    SaveTransaction() {
        if !this.IsOpen() || !this.state
            return
        nextDisplay := App.displayConfigCodec.Normalize({
            Name: this.nameEdit.Value,
            IconPath: this.iconEdit.Value
        })
        if (nextDisplay.IconPath != ""
            && !CustomIconSourceExists(nextDisplay.IconPath)) {
            ShowDarkMsgBoxDeferred(Tr("请选择现有的图标、程序、资源库或快捷方式文件。"),
                Tr("图标来源无效"), "Error", this.gui)
            return
        }
        if (nextDisplay.IconPath != ""
            && !IsSupportedCustomIconSource(nextDisplay.IconPath)) {
            ShowDarkMsgBoxDeferred(Tr("该文件不是受支持的图标或图片格式。`n`n支持 ICO、EXE、DLL、CPL、LNK、PNG、JPG、JPEG、JPE、JFIF、BMP、GIF、TIF、TIFF、WebP、SVG 和 ANI。"),
                Tr("不支持的图标格式"), "Error", this.gui)
            return
        }
        priorDisplay := this.state.HasOwnProp("DisplayConfig")
            ? App.displayConfigCodec.Normalize(this.state.DisplayConfig)
            : App.displayConfigCodec.CreateDefault()
        if App.displayConfigCodec.Equals(priorDisplay, nextDisplay) {
            if App.appsDirty && !SaveAppsToIni() {
                ShowDarkMsgBoxDeferred(Tr("保存显示设置失败，请查看运行日志。"),
                    Tr("保存失败"), "Error", this.gui)
                return
            }
            this.Close()
            return
        }

        undoState := CaptureAppConfigState()
        this.state.DisplayConfig := nextDisplay
        RefreshMainListDisplay(this.path)
        CommitUndoState(undoState,
            CreateAppHistoryAction("display", this.path))
        if !SaveAppsToIni() {
            ShowDarkMsgBoxDeferred(Tr("保存显示设置失败，请查看运行日志。"),
                Tr("保存失败"), "Error", this.gui)
            return
        }
        path := this.path
        this.Close()
        LogMsg(Tr("已更新主窗口显示设置：{1}", path))
    }

    Close(*) {
        this.DestroyGui()
        this.path := ""
        this.state := ""
        this.nameEdit := ""
        this.iconEdit := ""
        this.defaultNameButton := ""
        this.defaultIconButton := ""
    }
}
