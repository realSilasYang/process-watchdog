; 单个守护对象的进程身份与启动环境设置窗口。
; 快捷方式继续作为稳定的启动入口，解析后的真实进程只负责运行状态判断；直接脚本
; 可交给任意可执行运行时启动，工作目录、两级参数与环境变量均不改变探活身份。

class EnvironmentSettingsDialog extends ManagedWindow {
    __New(mainGui) {
        this.owner := mainGui
        this.path := ""
        this.state := ""
        this.isShortcut := false
        this.supportsCustomRuntime := false
        this.runtimePathEdit := ""
        this.runtimeArgsEdit := ""
        this.workDirEdit := ""
        this.argsEdit := ""
        this.envEdit := ""
        this.envScrollVisible := false
        this.autoResolveRadio := ""
        this.autoResolveLabel := ""
        this.manualResolveRadio := ""
        this.manualResolveLabel := ""
        this.identitySectionTitle := ""
        this.launchSectionTitle := ""
        this.resolvedTargetBackground := ""
        this.resolvedTargetEdit := ""
        this.resolutionSourceText := ""
        this.resolutionStatusText := ""
        this.resolutionActionButton := ""
        this.currentResolutionSource := ""
    }

    Show(path, stateObj) {
        if this.ShowExisting()
            return

        this.path := path
        this.state := stateObj
        SplitPath(path, , , &pathExtension)
        this.isShortcut := StrLower(pathExtension) == "lnk"
        this.supportsCustomRuntime := TargetSpecFactory
            .SupportsCustomRuntime(path)

        isCompact := LocalizationService.UsesCompactLayout()
        windowWidth := isCompact ? 680 : 820
        contentX := 20
        contentWidth := windowWidth - contentX * 2
        columnGap := 27
        leftWidth := Floor((contentWidth - columnGap) / 2)
        rightX := contentX + leftWidth + columnGap
        rightWidth := contentWidth - leftWidth - columnGap
        fieldButtonWidth := isCompact ? 94 : 126
        fieldInputWidth := rightWidth - fieldButtonWidth - 10
        contentBottomY := this.supportsCustomRuntime ? 674 : 466
        actionY := contentBottomY + 14
        windowHeight := contentBottomY + 59

        if !this.CreateOwnedGui(this.owner, "-MinimizeBox -MaximizeBox",
            Tr("进程识别与启动设置"))
            return
        try {
            InitializeApplicationWindow(this.gui, "norm s10")

            this.gui.Add("Text", "x" contentX " y14 w" contentWidth
                " h20 BackgroundTrans", Tr("守护对象："))
            targetInput := AddCenteredSingleLineEdit(this.gui, contentX, 36,
                contentWidth, 26, path, "ReadOnly",
                UiThemeService.Color("Surface"))
            RegisterTextInputControl(targetInput.Edit, true)
            SetDarkControl(targetInput.Edit.Hwnd)
            this.gui.Add("Text", "x" contentX " y75 w" contentWidth
                " h1 Background" UiThemeService.Color("Divider"))

            this.identitySectionTitle := this.AddSectionTitle(contentX, 88,
                leftWidth, Tr("进程识别"))
            this.launchSectionTitle := this.AddSectionTitle(rightX, 88,
                rightWidth, Tr("启动环境"))
            dividerX := contentX + leftWidth + Floor(columnGap / 2)
            this.gui.Add("Text", "x" dividerX " y88 w1 h"
                (contentBottomY - 97) " Background"
                UiThemeService.Color("Divider"))

            if this.isShortcut
                this.BuildShortcutIdentitySection(contentX, leftWidth,
                    fieldButtonWidth, stateObj)
            else
                this.BuildDirectIdentitySection(contentX, leftWidth, path)
            this.BuildLaunchEnvironmentSection(rightX, rightWidth,
                fieldInputWidth, fieldButtonWidth, stateObj)

            this.gui.Add("Text", "x" contentX " y" contentBottomY " w"
                contentWidth
                " h1 Background" UiThemeService.Color("Divider"))
            actionStartX := Round((windowWidth - 170) / 2)
            btnSave := this.gui.Add("Text", "x" actionStartX
                " y" actionY " w80 h28 Center 0x200 Background"
                    UiThemeService.Color("Primary") " c"
                    UiThemeService.Color("ButtonText"), Tr("保存"))
            btnCancel := this.gui.Add("Text", "x" (actionStartX + 90)
                " y" actionY " w80 h28 Center 0x200 Background"
                    UiThemeService.Color("Toolbar") " c"
                    UiThemeService.Color("ToolbarText"), Tr("取消"))
            RegisterHoverButton(btnSave, UiThemeService.Color("Primary"))
            RegisterHoverButton(btnCancel, UiThemeService.Color("Toolbar"))
            RegisterButtonClick(btnSave, ObjBindMethod(this, "Save"),
                ButtonFeedbackMode.Dismissive)
            RegisterButtonClick(btnCancel, ObjBindMethod(this, "Close"),
                ButtonFeedbackMode.Dismissive)

            this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
            this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
            ShowApplicationWindow(this.gui, "w" windowWidth " h"
                windowHeight)
            ShowSingleLineEditFromStart(targetInput.Edit)
            if this.resolvedTargetEdit
                ShowSingleLineEditFromStart(this.resolvedTargetEdit)
            this.UpdateEnvironmentScrollBar()
        } catch as openErr {
            this.Close()
            throw openErr
        }
    }

    AddSectionTitle(x, y, width, text) {
        this.gui.SetFont("norm s10 Bold c" UiThemeService.Color("Text"),
            LocalizationService.GetLanguageSystemUiFontName())
        try return this.gui.Add("Text", "x" x " y" y " w" width
            " h22 BackgroundTrans", text)
        finally this.gui.SetFont("norm s10 c" UiThemeService.Color("Text"),
            LocalizationService.GetUiFontName())
    }

    BuildShortcutIdentitySection(x, width, actionWidth, stateObj) {
        this.gui.Add("Text", "x" x " y114 w" width
            " h38 BackgroundTrans c" UiThemeService.Color("HintText"),
            Tr("快捷方式仍用于启动；真实进程用于判断程序是否正在运行。"))

        isManual := stateObj.HasOwnProp("ResolvedTargetManual")
            && stateObj.ResolvedTargetManual
        radioWidth := Floor((width - 10) / 2)
        radioMarkerWidth := 18
        radioLabelGap := 4
        radioLabelWidth := radioWidth - radioMarkerWidth - radioLabelGap
        this.autoResolveRadio := this.gui.Add("Radio", "x" x
            " y158 w" radioMarkerWidth " h24 Group c"
                UiThemeService.Color("Text"), Tr("自动识别进程"))
        this.autoResolveLabel := this.gui.Add("Text", "x"
            (x + radioMarkerWidth + radioLabelGap) " y158 w"
            radioLabelWidth " h24 0x200 BackgroundTrans c"
                UiThemeService.Color("Text"), Tr("自动识别进程"))
        manualRadioX := x + radioWidth + 10
        this.manualResolveRadio := this.gui.Add("Radio", "x"
            manualRadioX " y158 w" radioMarkerWidth " h24 c"
                UiThemeService.Color("Text"),
            Tr("用户指定"))
        this.manualResolveLabel := this.gui.Add("Text", "x"
            (manualRadioX + radioMarkerWidth + radioLabelGap) " y158 w"
            radioLabelWidth " h24 0x200 BackgroundTrans c"
                UiThemeService.Color("Text"), Tr("用户指定"))
        this.autoResolveRadio.Value := isManual ? 0 : 1
        this.manualResolveRadio.Value := isManual ? 1 : 0
        SetDarkControl(this.autoResolveRadio.Hwnd)
        SetDarkControl(this.manualResolveRadio.Hwnd)
        for radioControl in [this.autoResolveRadio, this.autoResolveLabel,
            this.manualResolveRadio, this.manualResolveLabel]
            RegisterHandCursorControl(radioControl)

        this.gui.Add("Text", "x" x " y190 w" width
            " h20 BackgroundTrans", Tr("用于判断运行状态的真实进程："))
        editWidth := width - actionWidth - 10
        savedTarget := stateObj.HasOwnProp("ResolvedTarget")
            ? stateObj.ResolvedTarget : ""
        resolutionSource := stateObj.HasOwnProp("ShortcutTargetSource")
            ? stateObj.ShortcutTargetSource : ""
        displayTarget := savedTarget
        if !isManual
            displayTarget := App.shortcutTargetResolver.ResolveForState(
                this.path, savedTarget, &resolutionSource)
        else
            resolutionSource := "用户指定"
        resolvedInput := AddCenteredSingleLineEdit(this.gui, x, 213,
            editWidth, 26, displayTarget, isManual ? "" : "ReadOnly",
            isManual ? UiThemeService.Color("Input")
                : UiThemeService.Color("Surface"))
        this.resolvedTargetBackground := resolvedInput.Background
        this.resolvedTargetEdit := resolvedInput.Edit
        SetDarkControl(this.resolvedTargetEdit.Hwnd)
        this.resolutionActionButton := this.gui.Add("Text", "x"
            (x + editWidth + 10) " y213 w" actionWidth
            " h26 Center 0x200 Background" UiThemeService.Color("Toolbar")
            " c" UiThemeService.Color("ToolbarText"),
            isManual ? Tr("选择程序") : Tr("重新识别"))
        RegisterHoverButton(this.resolutionActionButton,
            UiThemeService.Color("Toolbar"))
        SetButtonLucideIcon(this.resolutionActionButton,
            isManual ? "folder-open.svg" : "scan-search.svg", 14, 6)
        RegisterButtonClick(this.resolutionActionButton,
            ObjBindMethod(this, "HandleResolutionAction"))

        this.resolutionSourceText := this.gui.Add("Text", "x" x
            " y247 w" width " h34 BackgroundTrans c"
                UiThemeService.Color("MutedText"))
        this.resolutionStatusText := this.gui.Add("Text", "x" x
            " y286 w" width " h54 BackgroundTrans c"
                UiThemeService.Color("HintText"))
        this.currentResolutionSource := resolutionSource
        this.UpdateResolutionPresentation()

        this.autoResolveRadio.OnEvent("Click",
            ObjBindMethod(this, "SetResolvedTargetMode", false))
        RegisterButtonClick(this.autoResolveLabel,
            ObjBindMethod(this, "SetResolvedTargetMode", false))
        this.manualResolveRadio.OnEvent("Click",
            ObjBindMethod(this, "SetResolvedTargetMode", true))
        RegisterButtonClick(this.manualResolveLabel,
            ObjBindMethod(this, "SetResolvedTargetMode", true))
    }

    BuildDirectIdentitySection(x, width, path) {
        this.gui.Add("Text", "x" x " y114 w" width
            " h42 BackgroundTrans c" UiThemeService.Color("HintText"),
            Tr("该守护对象直接启动并监控同一个目标，无需额外识别真实进程。"))
        this.gui.Add("Text", "x" x " y172 w" width
            " h20 BackgroundTrans", Tr("用于判断运行状态的目标："))
        directInput := AddCenteredSingleLineEdit(this.gui, x, 195, width,
            26, path, "ReadOnly", UiThemeService.Color("Surface"))
        RegisterTextInputControl(directInput.Edit, true)
        SetDarkControl(directInput.Edit.Hwnd)
        this.gui.Add("Text", "x" x " y229 w" width
            " h40 BackgroundTrans c" UiThemeService.Color("HintText"),
            Tr("识别状态：启动入口与监控目标一致。"))
    }

    BuildLaunchEnvironmentSection(x, width, inputWidth, actionWidth,
        stateObj) {
        this.gui.Add("Text", "x" x " y114 w" width
            " h42 BackgroundTrans c" UiThemeService.Color("HintText"),
            Tr("这些设置仅在小助手下次启动目标时生效，不会重启当前进程。"))

        workDirLabelY := 163
        if this.supportsCustomRuntime {
            this.gui.Add("Text", "x" x " y157 w" width
                " h20 BackgroundTrans", Tr("启动程序或解释器："))
            runtimePathInput := AddCenteredSingleLineEdit(this.gui, x, 179,
                inputWidth, 26,
                stateObj.HasOwnProp("RuntimePath")
                    ? stateObj.RuntimePath : "", "",
                UiThemeService.Color("Input"))
            this.runtimePathEdit := runtimePathInput.Edit
            btnBrowseRuntime := this.gui.Add("Text", "x"
                (x + inputWidth + 10) " y179 w" actionWidth
                " h26 Center 0x200 Background"
                    UiThemeService.Color("Toolbar") " c"
                    UiThemeService.Color("ToolbarText"), Tr("选择程序"))
            this.gui.Add("Text", "x" x " y211 w" width
                " h48 BackgroundTrans c" UiThemeService.Color("HintText"),
                Tr("留空时按目标类型自动启动；可选择 Python、AutoHotkey、PowerShell、Node.js、Java 等运行时。"))

            this.gui.Add("Text", "x" x " y263 w" width
                " h20 BackgroundTrans", Tr("启动程序参数："))
            runtimeArgsInput := AddCenteredSingleLineEdit(this.gui, x, 285,
                width, 26,
                stateObj.HasOwnProp("RuntimeArgs")
                    ? stateObj.RuntimeArgs : "", "",
                UiThemeService.Color("Input"))
            this.runtimeArgsEdit := runtimeArgsInput.Edit
            this.gui.Add("Text", "x" x " y317 w" width
                " h48 BackgroundTrans c" UiThemeService.Color("HintText"),
                Tr("参数顺序为：启动程序参数、目标路径、目标参数；例如 Java 使用 -jar。"))
            RegisterHoverButton(btnBrowseRuntime,
                UiThemeService.Color("Toolbar"))
            SetButtonLucideIcon(btnBrowseRuntime, "folder-open.svg", 14, 6)
            RegisterButtonClick(btnBrowseRuntime,
                ObjBindMethod(this, "BrowseRuntime"))
            workDirLabelY := 371
        }

        workDirEditY := workDirLabelY + 22
        workDirHintY := workDirEditY + 32
        targetArgsLabelY := workDirHintY + 38
        targetArgsEditY := targetArgsLabelY + 22
        targetArgsHintY := targetArgsEditY + 32
        environmentLabelY := targetArgsHintY + 26
        environmentEditY := environmentLabelY + 30
        environmentHintY := environmentEditY + 73

        this.gui.Add("Text", "x" x " y" workDirLabelY " w" width
            " h20 BackgroundTrans", Tr("工作目录（CWD）："))
        workDirInput := AddCenteredSingleLineEdit(this.gui, x, workDirEditY,
            inputWidth, 26,
            stateObj.HasOwnProp("WorkDir") ? stateObj.WorkDir : "", "",
            UiThemeService.Color("Input"))
        this.workDirEdit := workDirInput.Edit
        btnBrowseWorkDir := this.gui.Add("Text", "x"
            (x + inputWidth + 10) " y" workDirEditY " w" actionWidth
            " h26 Center 0x200 Background" UiThemeService.Color("Toolbar")
            " c" UiThemeService.Color("ToolbarText"), Tr("选择文件夹"))
        this.gui.Add("Text", "x" x " y" workDirHintY " w" width
            " h32 BackgroundTrans c" UiThemeService.Color("HintText"),
            Tr("留空时使用快捷方式工作目录或程序所在目录。"))

        this.gui.Add("Text", "x" x " y" targetArgsLabelY " w" width
            " h20 BackgroundTrans", Tr("目标参数（Args）："))
        argsInput := AddCenteredSingleLineEdit(this.gui, x, targetArgsEditY,
            width,
            26, stateObj.HasOwnProp("Args") ? stateObj.Args : "", "",
            UiThemeService.Color("Input"))
        this.argsEdit := argsInput.Edit
        this.gui.Add("Text", "x" x " y" targetArgsHintY " w" width
            " h20 BackgroundTrans c" UiThemeService.Color("HintText"),
            Tr("留空时不附加额外参数。"))

        this.gui.Add("Text", "x" x " y" environmentLabelY " w" width
            " h36 BackgroundTrans", Tr("环境变量（每行一个 KEY=VALUE）："))
        this.envEdit := this.gui.Add("Edit", "x" x " y" environmentEditY
            " w" width
            " h67 Background" UiThemeService.Color("Input") " c"
                UiThemeService.Color("Text") " -E0x200 Multi -VScroll",
            stateObj.HasOwnProp("EnvVars") ? stateObj.EnvVars : "")
        RegisterTextInputControl(this.envEdit)
        this.gui.Add("Text", "x" x " y" environmentHintY " w" width
            " h20 BackgroundTrans c" UiThemeService.Color("HintText"),
            Tr("留空时继承小助手当前环境；值中可用 %变量名% 引用已有环境变量。"))

        inputControls := [this.workDirEdit, this.argsEdit, this.envEdit]
        if this.runtimePathEdit {
            inputControls.Push(this.runtimePathEdit)
            inputControls.Push(this.runtimeArgsEdit)
        }
        for inputControl in inputControls
            SetDarkControl(inputControl.Hwnd)
        RegisterHoverButton(btnBrowseWorkDir,
            UiThemeService.Color("Toolbar"))
        SetButtonLucideIcon(btnBrowseWorkDir, "folder-open.svg", 14, 6)
        RegisterButtonClick(btnBrowseWorkDir,
            ObjBindMethod(this, "BrowseWorkDir"))
        this.envEdit.OnEvent("Change",
            ObjBindMethod(this, "UpdateEnvironmentScrollBar"))
    }

    SetResolvedTargetMode(manualMode, *) {
        if !this.IsOpen() || !this.resolvedTargetEdit
            return
        manualMode := !!manualMode
        this.autoResolveRadio.Value := manualMode ? 0 : 1
        this.manualResolveRadio.Value := manualMode ? 1 : 0
        if manualMode {
            this.resolvedTargetEdit.Opt("-ReadOnly Background"
                UiThemeService.Color("Input"))
            this.resolvedTargetBackground.Opt("Background"
                UiThemeService.Color("Input"))
            this.currentResolutionSource := "用户指定"
            this.resolutionActionButton.Text := Tr("选择程序")
            SetButtonLucideIcon(this.resolutionActionButton,
                "folder-open.svg", 14, 6)
            this.UpdateResolutionPresentation()
            return
        }
        this.resolvedTargetEdit.Opt("+ReadOnly Background"
            UiThemeService.Color("Surface"))
        this.resolvedTargetBackground.Opt("Background"
            UiThemeService.Color("Surface"))
        this.resolutionActionButton.Text := Tr("重新识别")
        SetButtonLucideIcon(this.resolutionActionButton,
            "scan-search.svg", 14, 6)
        this.RefreshAutomaticResolution()
    }

    HandleResolutionAction(*) {
        if !this.IsOpen()
            return
        if this.manualResolveRadio.Value
            this.BrowseResolvedTarget()
        else
            this.RefreshAutomaticResolution()
    }

    RefreshAutomaticResolution(*) {
        if !this.IsOpen() || !this.resolvedTargetEdit
            return
        savedTarget := this.state.HasOwnProp("ResolvedTarget")
            ? this.state.ResolvedTarget : ""
        resolvedTarget := App.shortcutTargetResolver.ResolveForState(
            this.path, savedTarget, &resolutionSource)
        this.resolvedTargetEdit.Value := resolvedTarget
        this.currentResolutionSource := resolutionSource
        this.UpdateResolutionPresentation()
        ShowSingleLineEditFromStart(this.resolvedTargetEdit)
    }

    UpdateResolutionPresentation(*) {
        if !this.resolutionSourceText || !this.resolutionStatusText
            return
        manualMode := this.manualResolveRadio && this.manualResolveRadio.Value
        if manualMode {
            this.resolutionSourceText.Text := Tr("识别依据：{1}",
                Tr("用户指定"))
            this.resolutionStatusText.Text :=
                Tr("识别状态：手动指定，保存时将验证路径。")
            return
        }
        if this.currentResolutionSource != "" {
            resolutionSource := this.currentResolutionSource
            this.resolutionSourceText.Text := Tr("识别依据：{1}",
                Tr(resolutionSource))
        } else
            this.resolutionSourceText.Text := Tr("识别依据：暂无可靠结果")
        targetPath := NormalizeTargetPath(this.resolvedTargetEdit.Value)
        if targetPath == "" {
            this.resolutionStatusText.Text :=
                Tr("识别状态：未找到可靠目标，请改为手动指定。")
        } else if FileExist(targetPath) {
            this.resolutionStatusText.Text := Tr("识别状态：路径有效。")
        } else if this.currentResolutionSource == "已保存身份" {
            this.resolutionStatusText.Text :=
                Tr("识别状态：路径暂时不可用，已保留上次可靠结果。")
        } else {
            this.resolutionStatusText.Text :=
                Tr("识别状态：路径暂时不可用，将保留此身份等待恢复。")
        }
    }

    BrowseWorkDir(*) {
        if !this.IsOpen()
            return
        this.gui.Opt("+OwnDialogs")
        selected := SelectDirectoryWithModernDialog(this.gui.Hwnd,
            this.workDirEdit.Value, Tr("选择工作目录"))
        if selected && this.IsOpen()
            this.workDirEdit.Value := selected
    }

    BrowseRuntime(*) {
        if !this.IsOpen() || !this.runtimePathEdit
            return
        this.gui.Opt("+OwnDialogs")
        selected := SelectFileWithNamedFilter(this.gui.Hwnd,
            this.runtimePathEdit.Value, Tr("选择启动程序或解释器"),
            Tr("可执行程序"), "*.exe;*.com")
        if selected && this.IsOpen() {
            this.runtimePathEdit.Value := selected
            ShowSingleLineEditFromStart(this.runtimePathEdit)
        }
    }

    BrowseResolvedTarget(*) {
        if !this.IsOpen()
            return
        this.gui.Opt("+OwnDialogs")
        selected := SelectFileWithNamedFilter(this.gui.Hwnd,
            this.resolvedTargetEdit.Value,
            Tr("选择快捷方式对应的真实进程"), Tr("支持的程序与脚本"),
            "*.exe;*.com;*.ahk;*.py;*.pyw;*.js;*.vbs;*.ps1;*.bat;*.cmd")
        if selected && this.IsOpen() {
            this.resolvedTargetEdit.Value := selected
            this.currentResolutionSource := "用户指定"
            this.UpdateResolutionPresentation()
            ShowSingleLineEditFromStart(this.resolvedTargetEdit)
        }
    }

    UpdateEnvironmentScrollBar(*) {
        if !this.IsOpen() || !this.envEdit
            return
        lineCount := SendMessage(Win32.EM_GETLINECOUNT, 0, 0,
            this.envEdit.Hwnd)
        editRect := Buffer(16, 0)
        SendMessage(Win32.EM_GETRECT, 0, editRect.Ptr, this.envEdit.Hwnd)
        contentHeight := Max(1, NumGet(editRect, 12, "Int")
            - NumGet(editRect, 4, "Int"))
        lineHeight := 16
        deviceContext := DllCall("user32\GetDC", "Ptr",
            this.envEdit.Hwnd, "Ptr")
        if deviceContext {
            fontHandle := SendMessage(Win32.WM_GETFONT, 0, 0,
                this.envEdit.Hwnd)
            previousFont := fontHandle
                ? DllCall("gdi32\SelectObject", "Ptr", deviceContext,
                    "Ptr", fontHandle, "Ptr") : 0
            try {
                textMetrics := Buffer(64, 0)
                if DllCall("gdi32\GetTextMetricsW", "Ptr", deviceContext,
                    "Ptr", textMetrics, "Int")
                    lineHeight := Max(1, NumGet(textMetrics, 0, "Int")
                        + NumGet(textMetrics, 16, "Int"))
            } finally {
                if previousFont
                    DllCall("gdi32\SelectObject", "Ptr", deviceContext,
                        "Ptr", previousFont, "Ptr")
                DllCall("user32\ReleaseDC", "Ptr", this.envEdit.Hwnd,
                    "Ptr", deviceContext)
            }
        }
        needsScroll := lineCount * lineHeight > contentHeight
        if needsScroll == this.envScrollVisible
            return
        this.envScrollVisible := needsScroll
        this.envEdit.Opt(needsScroll ? "+VScroll" : "-VScroll")
        SetDarkControl(this.envEdit.Hwnd)
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
        path := this.path
        resolvedTarget := this.state.HasOwnProp("ResolvedTarget")
            ? this.state.ResolvedTarget : ""
        resolvedTargetManual := false
        resolutionSource := this.state.HasOwnProp("ShortcutTargetSource")
            ? this.state.ShortcutTargetSource : ""
        if this.resolvedTargetEdit {
            resolvedTargetManual := this.manualResolveRadio.Value == 1
            if resolvedTargetManual {
                resolvedTarget := NormalizeTargetPath(
                    this.resolvedTargetEdit.Value)
                if (!App.shortcutTargetResolver.IsPotentialProcessTarget(
                    resolvedTarget) || !FileExist(resolvedTarget)
                    || !App.shortcutTargetResolver.IsUsableTarget(
                        resolvedTarget)) {
                    ShowDarkMsgBoxDeferred(Tr("请选择现有且可执行的真实程序或脚本路径。"),
                        Tr("真实进程路径无效"), "Error", this.gui)
                    return
                }
                resolutionSource := "用户指定"
            } else {
                savedTarget := this.state.HasOwnProp("ResolvedTarget")
                    ? this.state.ResolvedTarget : ""
                resolvedTarget := App.shortcutTargetResolver.ResolveForState(
                    path, savedTarget, &resolutionSource)
            }
            if (resolvedTarget != "") {
                conflictPath := App.targetIdentityService.FindConflict(
                    resolvedTarget, path)
                if (conflictPath != "") {
                    ShowDarkMsgBoxDeferred(Tr("该真实进程已由其他守护对象守护。"),
                        Tr("守护对象重复"), "Error", this.gui)
                    return
                }
            }
        }

        nextWorkDir := NormalizeTargetPath(this.workDirEdit.Value)
        if nextWorkDir != "" && !DirExist(nextWorkDir) {
            ShowDarkMsgBoxDeferred(Tr("工作目录不存在或不可访问：{1}",
                nextWorkDir), Tr("工作目录无效"), "Error", this.gui)
            return
        }
        nextArgs := Trim(this.argsEdit.Value)
        nextRuntimePath := this.runtimePathEdit
            ? NormalizeTargetPath(this.runtimePathEdit.Value) : ""
        nextRuntimeArgs := this.runtimeArgsEdit
            ? Trim(this.runtimeArgsEdit.Value) : ""
        if (nextRuntimePath == "" && nextRuntimeArgs != "") {
            ShowDarkMsgBoxDeferred(
                Tr("请先选择启动程序或解释器，再填写它的参数。"),
                Tr("启动程序未设置"), "Error", this.gui)
            return
        }
        if (nextRuntimePath != ""
            && (!FileExist(nextRuntimePath) || DirExist(nextRuntimePath))) {
            ShowDarkMsgBoxDeferred(Tr("启动程序或解释器不存在：{1}",
                nextRuntimePath), Tr("启动程序无效"), "Error", this.gui)
            return
        }
        environmentResult := App.targetLauncher.ValidateEnvironment(
            Trim(this.envEdit.Value, "`r`n"))
        if !environmentResult.Valid {
            ShowDarkMsgBoxDeferred(this.GetEnvironmentValidationMessage(
                environmentResult), Tr("环境变量配置无效"), "Error",
                this.gui)
            return
        }
        nextEnvVars := environmentResult.Normalized

        identityChanged := !PathsEquivalent(this.state.ResolvedTarget,
            resolvedTarget)
            || this.state.ResolvedTargetManual != resolvedTargetManual
        currentRuntimePath := this.state.HasOwnProp("RuntimePath")
            ? this.state.RuntimePath : ""
        currentRuntimeArgs := this.state.HasOwnProp("RuntimeArgs")
            ? this.state.RuntimeArgs : ""
        settingsChanged := identityChanged || this.state.WorkDir != nextWorkDir
            || this.state.Args != nextArgs
            || this.state.EnvVars != nextEnvVars
            || !PathsEquivalent(currentRuntimePath, nextRuntimePath)
            || currentRuntimeArgs != nextRuntimeArgs
        if !settingsChanged {
            this.state.ShortcutTargetSource := resolutionSource
            this.state.ShortcutResolveCheckedTicks := GetTickCount64()
            if App.appsDirty && !SaveAppsToIni() {
                this.ShowPersistencePending()
                return
            }
            this.Close()
            return
        }

        undoState := CaptureAppConfigState()
        stateObj := this.state
        priorPhase := stateObj.Phase
        if identityChanged {
            stateObj.CancelScheduledTasks()
            App.maintenanceCoordinator.CleanupTarget(path, stateObj, false)
            ClearStateProcessIdentity(stateObj)
            stateObj.ResetGuardAttemptState()
        }
        stateObj.WorkDir := nextWorkDir
        stateObj.Args := nextArgs
        stateObj.EnvVars := nextEnvVars
        stateObj.RuntimePath := nextRuntimePath
        stateObj.RuntimeArgs := nextRuntimeArgs
        stateObj.ResolvedTarget := resolvedTarget
        stateObj.ResolvedTargetManual := resolvedTargetManual
        stateObj.ShortcutTargetSource := resolutionSource
        stateObj.ShortcutResolveCheckedTicks := GetTickCount64()
        App.targetSpecsService.Get(path, stateObj, true)
        if identityChanged {
            stateObj.OneShot := IsOneShotTarget(path, resolvedTarget)
            stateObj.MaintenanceConfig := App.maintenanceConfigCodec
                .NormalizeSnapshot(stateObj.MaintenanceConfig, path,
                    resolvedTarget)
            fingerprintTarget := resolvedTarget != "" ? resolvedTarget : path
            refreshedFingerprint := App.targetFileInspector.GetFingerprint(
                fingerprintTarget)
            stateObj.SafetyFingerprint := refreshedFingerprint
            stateObj.MaintenanceBaselineFingerprint := refreshedFingerprint
            stateObj.SafetyStableSince := GetTickCount64()
            stateObj.MaintenanceFingerprintCheckedTicks := 0
            stateObj.MaintenanceReadyCheckedTicks := 0
            if stateObj.Enabled && stateObj.MaintenanceConfig.Enabled
                App.maintenanceCoordinator.EnsureWatcher(path, stateObj)
            App.maintenanceCoordinator.SaveJournal()

            if (stateObj.Enabled
                && !App.maintenanceCoordinator.IsBlocking(stateObj)) {
                if StateProcessIdentityIsValid(path, stateObj) {
                    UpdateRunningState(path, stateObj, stateObj.Generation)
                } else if !(stateObj.OneShot
                    && priorPhase == GuardPhase.Running) {
                    stateObj.TransitionTo(GuardPhase.Initializing)
                    UpdateState(path, Tr("初始化..."), stateObj,
                        stateObj.Generation, false,
                        GuardStatusKind.Initializing)
                }
            }
        }
        CommitUndoState(undoState,
            CreateAppHistoryAction("environment", path))
        if !SaveAppsToIni() {
            this.ShowPersistencePending()
            return
        }
        this.Close()
        LogMsg(Tr("已更新进程识别与启动设置：{1}", path))
    }

    GetEnvironmentValidationMessage(validationResult) {
        switch validationResult.ErrorCode {
            case "MissingSeparator":
                return Tr("环境变量第 {1} 行缺少等号（KEY=VALUE）。",
                    validationResult.LineNumber)
            case "InvalidName":
                return Tr("环境变量第 {1} 行的名称无效：{2}",
                    validationResult.LineNumber,
                    validationResult.VariableName)
            case "DuplicateName":
                return Tr("环境变量第 {1} 行重复定义了 {2}。",
                    validationResult.LineNumber,
                    validationResult.VariableName)
            default:
                return Tr("环境变量配置无法解析。")
        }
    }

    ShowPersistencePending() {
        ShowDarkMsgBoxDeferred(
            Tr("设置已应用到当前运行，但暂未写入配置文件；小助手将在后台自动重试。"),
            Tr("配置暂未写入"), "Warning", this.gui)
    }

    Close(*) {
        this.DestroyGui()
        this.path := ""
        this.state := ""
        this.isShortcut := false
        this.supportsCustomRuntime := false
        this.runtimePathEdit := ""
        this.runtimeArgsEdit := ""
        this.workDirEdit := ""
        this.argsEdit := ""
        this.envEdit := ""
        this.envScrollVisible := false
        this.autoResolveRadio := ""
        this.autoResolveLabel := ""
        this.manualResolveRadio := ""
        this.manualResolveLabel := ""
        this.identitySectionTitle := ""
        this.launchSectionTitle := ""
        this.resolvedTargetBackground := ""
        this.resolvedTargetEdit := ""
        this.resolutionSourceText := ""
        this.resolutionStatusText := ""
        this.resolutionActionButton := ""
        this.currentResolutionSource := ""
    }
}
