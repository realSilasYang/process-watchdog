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
        if !this.CreateOwnedGui(this.owner,
            "-MinimizeBox -MaximizeBox", "自定义显示")
            return
        try {
            SetDarkTitleBar(this.gui.Hwnd)
            SetWindowIcon(this.gui.Hwnd, A_ScriptDir "\watchdog.ico")
            this.gui.BackColor := "1E1E1E"
            this.gui.SetFont("s10 cWhite", "Microsoft YaHei")

            this.gui.Add("Text", "x20 y14 w500 h20 BackgroundTrans", "守护目标:")
            targetInput := AddCenteredSingleLineEdit(this.gui,
                20, 38, 500, 26, path, "ReadOnly", "2A2A2A")
            RegisterTextInputControl(targetInput.Edit, true)

            this.gui.Add("Text", "x20 y78 w120 h20 BackgroundTrans", "显示名称:")
            nameInput := AddCenteredSingleLineEdit(this.gui,
                20, 102, 410, 26, displayConfig.Name, "Limit120", "333333")
            this.nameEdit := nameInput.Edit
            this.defaultNameButton := this.gui.Add("Text",
                "x440 y102 w80 h26 Center 0x200 Background333333 cWhite", "使用默认")

            this.gui.Add("Text", "x20 y142 w120 h20 BackgroundTrans", "图标来源:")
            iconInput := AddCenteredSingleLineEdit(this.gui,
                20, 166, 330, 26, displayConfig.IconPath, "", "333333")
            this.iconEdit := iconInput.Edit
            btnBrowse := this.gui.Add("Text",
                "x360 y166 w70 h26 Center 0x200 Background333333 cWhite", "浏览")
            this.defaultIconButton := this.gui.Add("Text",
                "x440 y166 w80 h26 Center 0x200 Background333333 cWhite", "使用默认")

            btnSave := this.gui.Add("Text",
                "x185 y212 w80 h28 Center 0x200 Background0078D7 cWhite", "保存")
            btnCancel := this.gui.Add("Text",
                "x275 y212 w80 h28 Center 0x200 Background333333 cWhite", "取消")

            for editControl in [targetInput.Edit, this.nameEdit, this.iconEdit]
                SetDarkControl(editControl.Hwnd)
            for button in [this.defaultNameButton, btnBrowse,
                this.defaultIconButton, btnCancel]
                RegisterHoverButton(button, "333333")
            RegisterHoverButton(btnSave, "0078D7")
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
            this.gui.Show("w540 h260")
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
        this.SetDefaultButtonEnabled(this.defaultNameButton,
            Trim(this.nameEdit.Value) != "")
        this.SetDefaultButtonEnabled(this.defaultIconButton,
            Trim(this.iconEdit.Value) != "")
    }

    SetDefaultButtonEnabled(button, enabled) {
        if !button
            return
        try buttonHwnd := button.Hwnd
        catch
            return
        try button.Enabled := !!enabled
        if !enabled && App.uiInteractions.HasButton(buttonHwnd) {
            buttonState := App.uiInteractions.GetButton(buttonHwnd)
            buttonState.current := buttonState.normal
            App.uiInteractions.ClearHoveredButton(buttonHwnd)
        }
        RedrawRoundedButton(buttonHwnd)
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
            "选择主窗口图标", "支持的图标与图片",
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
        if !this.IsOpen() || !this.state
            return
        nextDisplay := App.displayConfigCodec.Normalize({
            Name: this.nameEdit.Value,
            IconPath: this.iconEdit.Value
        })
        if (nextDisplay.IconPath != ""
            && !CustomIconSourceExists(nextDisplay.IconPath)) {
            ShowDarkMsgBox("请选择现有的图标、程序、资源库或快捷方式文件。",
                "图标来源无效", "Error", this.gui)
            return
        }
        if (nextDisplay.IconPath != ""
            && !IsSupportedCustomIconSource(nextDisplay.IconPath)) {
            ShowDarkMsgBox("该文件不是受支持的图标或图片格式。`n`n"
                . "支持 ICO、EXE、DLL、CPL、LNK、PNG、JPG、JPEG、JPE、"
                . "JFIF、BMP、GIF、TIF、TIFF、WebP、SVG 和 ANI。",
                "不支持的图标格式", "Error", this.gui)
            return
        }
        priorDisplay := this.state.HasOwnProp("DisplayConfig")
            ? App.displayConfigCodec.Normalize(this.state.DisplayConfig)
            : App.displayConfigCodec.CreateDefault()
        if App.displayConfigCodec.Equals(priorDisplay, nextDisplay) {
            if App.appsDirty && !SaveAppsToIni() {
                ShowDarkMsgBox("保存显示设置失败，请查看运行日志。",
                    "保存失败", "Error", this.gui)
                return
            }
            this.Close()
            return
        }

        undoState := CaptureAppConfigState()
        this.state.DisplayConfig := nextDisplay
        RefreshMainListDisplay(this.path)
        CommitUndoState(undoState)
        if !SaveAppsToIni() {
            ShowDarkMsgBox("保存显示设置失败，请查看运行日志。",
                "保存失败", "Error", this.gui)
            return
        }
        path := this.path
        this.Close()
        LogMsg("已更新主窗口显示设置: " path)
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
