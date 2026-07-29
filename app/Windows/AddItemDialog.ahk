; 添加守护对象窗口。
; 支持直接选择目标、批量导入和应用搜索；异步扫描以会话代际隔离，窗口关闭后
; 迟到的工作器结果只能被丢弃，不能继续写入控件或重复提交撤销记录。

class AddItemDialog extends ManagedWindow {
    __New(mainGui) {
        this.owner := mainGui
        this.edit := ""
        this.pathHint := ""
        this.search := ApplicationSearchDialog(this)
        this.searchButton := ""
        this.browseButton := ""
        this.okButton := ""
        this.cancelButton := ""
        this.batchStatus := ""
        this.normalActionButtonY := 0
        this.batchActionButtonY := 0
        this.normalWindowHeight := 0
        this.batchWindowHeight := 0
        this.batchWorkerPid := 0
        this.batchWorkerCreationIdentity := ""
        this.batchWorkerDeadlineTicks := 0
        this.batchOutputPath := ""
        this.batchRootQueue := []
        this.batchPendingPaths := []
        this.batchPendingIndex := 0
        this.batchAddedCount := 0
        this.batchUndoState := ""
        this.batchAddedPaths := []
        this.batchTruncated := false
        this.batchSessionId := 0
        this.batchPollTimer := ObjBindMethod(this, "PollBatchImport")
        this.batchConsumeTimer := ObjBindMethod(this, "ConsumeBatchImport")
    }

    HideTransientWindows() {
        this.search.tooltip.Hide()
    }

    Show(positionPointer := true, *) {
        if this.ShowExisting() {
            if positionPointer
                this.PositionPointerOnSearchButton()
            return
        }

        if !this.CreateOwnedGui(this.owner, "-MinimizeBox -MaximizeBox", Tr("添加守护对象"))
            return
        try {
        this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
        this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
        InitializeApplicationWindow(this.gui)
        isCompact := LocalizationService.UsesCompactLayout()
        windowWidth := isCompact ? 520 : 650
        contentWidth := windowWidth - 40

        utilityWidth := isCompact ? 72 : 92
        utilityGap := 8
        utilityGroupWidth := utilityWidth * 2 + utilityGap
        utilityGroupX := Round((windowWidth - utilityGroupWidth) / 2)
        this.searchButton := this.gui.Add("Text", "x" utilityGroupX
            " y15 w" utilityWidth
            " h26 Center 0x200 Background" UiThemeService.Color("Toolbar")
            " c" UiThemeService.Color("ToolbarText"), Tr("搜索..."))
        this.browseButton := this.gui.Add("Text", "x"
            (utilityGroupX + utilityWidth + utilityGap)
            " y15 w" utilityWidth " h26 Center 0x200 Background"
            UiThemeService.Color("Toolbar") " c"
            UiThemeService.Color("ToolbarText"), Tr("选择..."))

        ; 工具按钮与说明之间留出明确层次，说明到输入框则保持紧凑。
        ; 两处增减相互抵消，使输入框位置稳定，不影响不同语言的既有高度。
        hintY := 53
        hintHeight := isCompact ? 42 : 62
        inputY := hintY + hintHeight + 4
        batchStatusY := inputY + 29
        this.normalActionButtonY := inputY + 36
        this.batchActionButtonY := batchStatusY + 20
        this.normalWindowHeight := this.normalActionButtonY + 41
        this.batchWindowHeight := this.batchActionButtonY + 41
        this.pathHint := this.gui.Add("Text", "x20 y" hintY " w" contentWidth
            " h" hintHeight " Center BackgroundTrans",
            Tr("请通过上方按钮搜索或选择，或在下方填写进程名或目标路径：`n【支持程序、脚本、快捷方式，以及文件夹批量导入】"))

        inputControl := AddCenteredSingleLineEdit(this.gui, 20, inputY,
            contentWidth, 26)
        this.edit := inputControl.Edit
        SetDarkControl(this.edit.Hwnd)

        this.batchStatus := this.gui.Add("Text", "x20 y" batchStatusY " w"
            contentWidth
            " h18 Center BackgroundTrans c" UiThemeService.Color("HintText")
            " Hidden", Tr("正在扫描..."))
        actionButtonWidth := 68
        actionButtonGap := 8
        actionGroupWidth := actionButtonWidth * 2 + actionButtonGap
        actionGroupX := Round((windowWidth - actionGroupWidth) / 2)
        this.okButton := this.gui.Add("Text", "x" actionGroupX
            " y" this.normalActionButtonY " w" actionButtonWidth
            " h26 Center 0x200 Background"
            UiThemeService.Color("Primary") " c"
            UiThemeService.Color("ButtonText"), Tr("确 定"))
        this.cancelButton := this.gui.Add("Text", "x"
            (actionGroupX + actionButtonWidth + actionButtonGap)
            " y" this.normalActionButtonY " w" actionButtonWidth
            " h26 Center 0x200 Background"
            UiThemeService.Color("Toolbar") " c"
            UiThemeService.Color("ToolbarText"), Tr("取 消"))
        RegisterHoverButton(this.searchButton, UiThemeService.Color("Toolbar"))
        RegisterHoverButton(this.browseButton, UiThemeService.Color("Toolbar"))
        RegisterHoverButton(this.okButton, UiThemeService.Color("Primary"))
        RegisterHoverButton(this.cancelButton, UiThemeService.Color("Toolbar"))
        SetButtonLucideIcon(this.searchButton, "search.svg", 14, 6)
        SetButtonLucideIcon(this.browseButton, "folder-open.svg", 14, 6)
        RegisterButtonClick(this.searchButton, ObjBindMethod(this.search, "Show"))
        RegisterButtonClick(this.browseButton, ObjBindMethod(this, "ShowBrowseMenu"))
        RegisterButtonClick(this.okButton, ObjBindMethod(this, "Confirm"), ButtonFeedbackMode.Dismissive)
        RegisterButtonClick(this.cancelButton, ObjBindMethod(this, "Close"), ButtonFeedbackMode.Dismissive)
        ShowApplicationWindow(this.gui,
            "w" windowWidth " h" this.normalWindowHeight)
        if positionPointer
            this.PositionPointerOnSearchButton()
        } catch as openErr {
            this.Close()
            throw openErr
        }
    }

    ShowBrowseMenu(*) {
        browseMenu := Menu()
        browseMenu.Add(Tr("📄 浏览文件..."), ObjBindMethod(this, "BrowseFile"))
        browseMenu.Add(Tr("📂 浏览文件夹..."), ObjBindMethod(this, "BrowseDir"))
        browseMenu.Show()
    }

    BrowseFile(*) {
        selected := this.SelectFile(Tr("选择要监控的文件"))
        if selected && this.IsOpen()
            this.edit.Value := selected
    }

    BrowseDir(*) {
        selected := this.SelectDirectory(Tr("选择要监控的文件夹"))
        if selected && this.IsOpen()
            this.edit.Value := selected
    }

    SelectFile(prompt := "") {
        if prompt == ""
            prompt := Tr("选择文件")
        hwndOwner := this.IsOpen() ? this.gui.Hwnd : 0
        return SelectFileWithNamedFilter(hwndOwner, "", prompt,
            Tr("支持的程序、脚本与快捷方式"),
            "*.exe;*.com;*.msc;*.ahk;*.py;*.pyw;*.js;*.vbs;*.vbe;*.wsf;*.ps1;*.bat;*.cmd;*.rb;*.pl;*.php;*.lua;*.jar;*.sh;*.bash;*.lnk;*.url;*.appref-ms")
    }

    SelectDirectory(prompt := "") {
        if prompt == ""
            prompt := Tr("选择文件夹")
        hwndOwner := this.IsOpen() ? this.gui.Hwnd : 0
        return SelectDirectoryWithModernDialog(hwndOwner, "", prompt)
    }

    PositionPointerOnSearchButton(*) {
        if !this.IsOpen() || !this.searchButton
            return
        MovePointerToControlCenter(this.searchButton)
        ; 窗口首次激活时，Windows 可能在 Show 返回后完成最后一次前景切换并恢复
        ; 原指针位置。延迟确认一次可保证用户最终看到的指针仍落在搜索按钮上。
        SetTimer(ObjBindMethod(this, "ConfirmPointerOnSearchButton"), -25)
    }

    ConfirmPointerOnSearchButton(*) {
        if this.IsOpen() && this.searchButton
            MovePointerToControlCenter(this.searchButton)
    }

    SetBatchUi(active, statusText := "") {
        if !this.IsOpen()
            return
        if this.edit
            try this.edit.Enabled := !active
        for button in [this.searchButton, this.browseButton, this.okButton]
            SetRegisteredButtonEnabled(button, !active)
        if this.batchStatus {
            try this.batchStatus.Text := statusText
            try this.batchStatus.Visible := active
        }
        ; 常态不为空的批量状态行预留大块空白；仅在扫描期间下移操作按钮并
        ; 增高窗口，结束后立即恢复紧凑布局。
        actionButtonY := active
            ? this.batchActionButtonY : this.normalActionButtonY
        for button in [this.okButton, this.cancelButton] {
            if button
                try button.Move(, actionButtonY)
        }
        windowHeight := active
            ? this.batchWindowHeight : this.normalWindowHeight
        if windowHeight > 0
            try ShowApplicationWindow(this.gui,
                "NoActivate h" windowHeight)
    }

    StartBatchImport(rootPaths, directPaths := "") {
        this.Show(false)
        if !this.IsOpen()
            return
        sessionId := this.CancelBatchImport(false)
        try {
            this.batchRootQueue := []
            seenRoots := Map()
            seenRoots.CaseSense := "Off"
            for rootPath in rootPaths {
                canonicalRoot := GetCanonicalPath(rootPath)
                if DirExist(rootPath) && !seenRoots.Has(canonicalRoot) {
                    seenRoots[canonicalRoot] := true
                    this.batchRootQueue.Push(rootPath)
                }
            }
            this.batchPendingPaths := []
            this.batchTruncated := false
            seen := Map()
            seen.CaseSense := "Off"
            if (directPaths && Type(directPaths) == "Array") {
                for filePath in directPaths {
                    if (this.batchPendingPaths.Length
                        >= App.batchImportMaxResults) {
                        this.batchTruncated := true
                        break
                    }
                    canonicalPath := GetCanonicalPath(filePath)
                    if App.fileScanner.IsSupported(filePath)
                        && !seen.Has(canonicalPath) {
                        seen[canonicalPath] := true
                        this.batchPendingPaths.Push(filePath)
                    }
                }
            }
            this.batchPendingIndex := 0
            this.batchAddedCount := 0
            this.batchUndoState := ""
            this.batchAddedPaths := []
            this.SetBatchUi(true, Tr("正在扫描文件夹，可点击取消停止"))
            this.StartNextBatchRoot(sessionId)
        } catch as batchStartErr {
            this.FailBatchImport(Tr("启动批量导入失败"), batchStartErr,
                sessionId)
        }
    }

    IsBatchSessionCurrent(sessionId) {
        return sessionId == this.batchSessionId && this.IsOpen()
    }

    StartNextBatchRoot(sessionId) {
        if !this.IsBatchSessionCurrent(sessionId)
            return
        if (this.batchPendingPaths.Length >= App.batchImportMaxResults) {
            if this.batchRootQueue.Length
                this.batchTruncated := true
            this.batchRootQueue := []
        }
        while this.batchRootQueue.Length {
            rootPath := this.batchRootQueue.RemoveAt(1)
            remaining := App.batchImportMaxResults - this.batchPendingPaths.Length
            ; 批量导入只扫描用户选中的目录，固定超时避免再暴露与程序搜索耦合的设置。
            timeoutSeconds := 60
            scanWorker := App.fileScanner.Start(rootPath,
                App.recursiveBatchImport, remaining, timeoutSeconds)
            if scanWorker {
                accepted := false
                previousCritical := A_IsCritical
                Critical("On")
                try {
                    if this.IsBatchSessionCurrent(sessionId) {
                        this.batchWorkerPid := scanWorker.Pid
                        this.batchWorkerCreationIdentity :=
                            scanWorker.CreationIdentity
                        this.batchWorkerDeadlineTicks := scanWorker.DeadlineTicks
                        this.batchOutputPath := scanWorker.Path
                        this.batchStatus.Text := Tr("正在扫描：{1}", rootPath)
                        SetTimer(this.batchPollTimer, 100)
                        accepted := true
                    }
                } finally {
                    Critical(previousCritical ? previousCritical : "Off")
                }
                if !accepted
                    App.fileScanner.Stop(scanWorker.Pid, scanWorker.Path,
                        scanWorker.CreationIdentity)
                return
            }
            if !this.IsBatchSessionCurrent(sessionId)
                return
            this.batchTruncated := true
        }
        this.BeginBatchConsume(sessionId)
    }

    PollBatchImport(*) {
        if !this.IsOpen() {
            this.Close()
            return
        }
        sessionId := this.batchSessionId
        try {
            if FileExist(this.batchOutputPath) {
                SetTimer(this.batchPollTimer, 0)
                outputPath := this.batchOutputPath
                paths := App.fileScanner.ReadResult(outputPath, &wasTruncated,
                    &resultReady)
                if !this.IsBatchSessionCurrent(sessionId) {
                    try FileDelete(outputPath)
                    return
                }
                mergedPaths := this.batchPendingPaths.Clone()
                mergedTruncated := this.batchTruncated || wasTruncated
                    || !resultReady
                seen := Map()
                seen.CaseSense := "Off"
                for existingPath in mergedPaths
                    seen[GetCanonicalPath(existingPath)] := true
                for filePath in paths {
                    if (mergedPaths.Length >= App.batchImportMaxResults) {
                        mergedTruncated := true
                        break
                    }
                    canonicalPath := GetCanonicalPath(filePath)
                    if !seen.Has(canonicalPath) {
                        seen[canonicalPath] := true
                        mergedPaths.Push(filePath)
                    }
                }
                try FileDelete(outputPath)
                previousCritical := A_IsCritical
                Critical("On")
                try {
                    if !this.IsBatchSessionCurrent(sessionId)
                        return
                    this.batchTruncated := mergedTruncated
                    this.batchPendingPaths := mergedPaths
                    this.batchWorkerPid := 0
                    this.batchWorkerCreationIdentity := ""
                    this.batchWorkerDeadlineTicks := 0
                    this.batchOutputPath := ""
                } finally {
                    Critical(previousCritical ? previousCritical : "Off")
                }
                this.StartNextBatchRoot(sessionId)
                return
            }
            workerPid := this.batchWorkerPid
            workerCreationIdentity := this.batchWorkerCreationIdentity
            workerDeadlineTicks := this.batchWorkerDeadlineTicks
            outputPath := this.batchOutputPath
            workerExists := workerPid && ProcessExist(workerPid)
            currentWorkerIdentity := ""
            if workerExists && workerCreationIdentity != ""
                currentWorkerIdentity := App.processInspector
                    .GetCreationIdentity(workerPid)
            workerReplaced := workerExists && workerCreationIdentity != ""
                && currentWorkerIdentity != ""
                && currentWorkerIdentity != workerCreationIdentity
            if (workerPid
                && (!workerExists || workerReplaced
                    || (workerDeadlineTicks
                        && GetTickCount64() >= workerDeadlineTicks))) {
                SetTimer(this.batchPollTimer, 0)
                App.fileScanner.Stop(workerPid, outputPath,
                    workerCreationIdentity)
                previousCritical := A_IsCritical
                Critical("On")
                try {
                    if !this.IsBatchSessionCurrent(sessionId)
                        return
                    this.batchWorkerPid := 0
                    this.batchWorkerCreationIdentity := ""
                    this.batchWorkerDeadlineTicks := 0
                    this.batchOutputPath := ""
                    this.batchTruncated := true
                } finally {
                    Critical(previousCritical ? previousCritical : "Off")
                }
                this.StartNextBatchRoot(sessionId)
            }
        } catch as batchPollErr {
            this.FailBatchImport(Tr("读取后台扫描结果失败"), batchPollErr,
                sessionId)
        }
    }

    BeginBatchConsume(sessionId) {
        if !this.IsBatchSessionCurrent(sessionId)
            return
        if !this.batchPendingPaths.Length {
            previousCritical := A_IsCritical
            Critical("On")
            try {
                if !this.IsBatchSessionCurrent(sessionId)
                    return
                this.batchPendingIndex := 0
                this.batchAddedCount := 0
                this.batchUndoState := ""
                this.batchAddedPaths := []
                this.batchTruncated := false
                this.batchSessionId++
                completedSessionId := this.batchSessionId
                this.SetBatchUi(false)
            } finally {
                Critical(previousCritical ? previousCritical : "Off")
            }
            if this.IsBatchSessionCurrent(completedSessionId)
                try ShowDarkMsgBox(Tr("所选文件夹内未找到支持的程序、脚本或快捷方式。"),
                    Tr("未找到目标"), "Info", this.gui)
            return
        }
        this.batchPendingIndex := 0
        this.batchUndoState := CaptureAppConfigState()
        this.batchAddedPaths := []
        this.batchStatus.Text := Tr("正在添加扫描结果...")
        SetTimer(this.batchConsumeTimer, 15)
    }

    ConsumeBatchImport(*) {
        if !this.IsOpen() {
            this.Close()
            return
        }
        if !App.guardWorkGate.TryEnter()
            return
        try this.ConsumeBatchImportCore()
        finally App.guardWorkGate.Leave()
    }

    ConsumeBatchImportCore(*) {
        if !this.IsOpen()
            return
        sessionId := this.batchSessionId
        try {
            batchEnd := Min(this.batchPendingPaths.Length,
                this.batchPendingIndex + 7)
            while (this.batchPendingIndex < batchEnd) {
                this.batchPendingIndex++
                filePath := this.batchPendingPaths[this.batchPendingIndex]
                shortcutArgs := "", resolvedWorkDir := ""
                resolvedPath := ResolveShortcutForAdd(filePath, &shortcutArgs,
                    &resolvedWorkDir)
                previousCritical := A_IsCritical
                Critical("On")
                try {
                    if !this.IsBatchSessionCurrent(sessionId)
                        return
                    if RegisterApp(resolvedPath, 1, 0, resolvedWorkDir,
                        "", "", "", "", false, shortcutArgs) {
                        this.batchAddedCount++
                        this.batchAddedPaths.Push(resolvedPath)
                    }
                } finally {
                    Critical(previousCritical ? previousCritical : "Off")
                }
            }
            this.batchStatus.Text := Tr("正在添加：{1} / {2}",
                this.batchPendingIndex, this.batchPendingPaths.Length)
            if (this.batchPendingIndex < this.batchPendingPaths.Length)
                return
            this.CompleteBatchImport(sessionId)
        } catch as batchConsumeErr {
            this.FailBatchImport(Tr("添加扫描结果失败"), batchConsumeErr,
                sessionId)
        }
    }

    CompleteBatchImport(sessionId) {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if !this.IsBatchSessionCurrent(sessionId)
                return
            SetTimer(this.batchConsumeTimer, 0)
            addedCount := this.batchAddedCount
            undoState := this.batchUndoState
            addedPaths := this.batchAddedPaths
            wasTruncated := this.batchTruncated
            this.batchPendingPaths := []
            this.batchPendingIndex := 0
            this.batchAddedCount := 0
            this.batchUndoState := ""
            this.batchAddedPaths := []
            this.batchTruncated := false
            this.batchSessionId++
            completedSessionId := this.batchSessionId
            this.SetBatchUi(false)
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        if addedCount {
            CommitUndoState(undoState,
                CreateAppHistoryAction("add", addedPaths))
            SaveAppsToIni()
        }
        message := Tr("已添加 {1} 个守护对象。", addedCount)
        if wasTruncated
            message .= Tr(" 扫描达到时间或数量上限，结果已截断。")
        LogMsg(message)
        if this.IsBatchSessionCurrent(completedSessionId)
            try ShowDarkMsgBox(message, Tr("批量导入完成"), "Info", this.gui)
    }

    FailBatchImport(context, failure, expectedSessionId := 0) {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if expectedSessionId && expectedSessionId != this.batchSessionId
                return
            this.batchSessionId++
            failureSessionId := this.batchSessionId
            try SetTimer(this.batchPollTimer, 0)
            try SetTimer(this.batchConsumeTimer, 0)
            workerPid := this.batchWorkerPid
            workerCreationIdentity := this.batchWorkerCreationIdentity
            outputPath := this.batchOutputPath
            addedCount := this.batchAddedCount
            undoState := this.batchUndoState
            addedPaths := this.batchAddedPaths
            this.batchWorkerPid := 0
            this.batchWorkerCreationIdentity := ""
            this.batchWorkerDeadlineTicks := 0
            this.batchOutputPath := ""
            this.batchRootQueue := []
            this.batchPendingPaths := []
            this.batchPendingIndex := 0
            this.batchAddedCount := 0
            this.batchUndoState := ""
            this.batchAddedPaths := []
            this.batchTruncated := false
            this.SetBatchUi(false)
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        try App.fileScanner.Stop(workerPid, outputPath,
            workerCreationIdentity)
        if addedCount {
            CommitUndoState(undoState,
                CreateAppHistoryAction("add", addedPaths))
            SaveAppsToIni()
        }
        failureText := TrDiagnostic(failure is Error
            ? failure.Message : String(failure))
        LogMsg(context ": " failureText)
        if this.IsBatchSessionCurrent(failureSessionId) {
            message := context Tr("。")
            if addedCount
                message .= Tr(" 已保留并保存此前添加的 {1} 个守护对象。", addedCount)
            try ShowDarkMsgBox(message, Tr("批量导入中断"), "Error", this.gui)
        }
    }

    CancelBatchImport(updateUi := true) {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            this.batchSessionId++
            cancelledSessionId := this.batchSessionId
            try SetTimer(this.batchPollTimer, 0)
            try SetTimer(this.batchConsumeTimer, 0)
            workerPid := this.batchWorkerPid
            workerCreationIdentity := this.batchWorkerCreationIdentity
            outputPath := this.batchOutputPath
            addedCount := this.batchAddedCount
            undoState := this.batchUndoState
            addedPaths := this.batchAddedPaths
            this.batchWorkerPid := 0
            this.batchWorkerCreationIdentity := ""
            this.batchWorkerDeadlineTicks := 0
            this.batchOutputPath := ""
            this.batchRootQueue := []
            this.batchPendingPaths := []
            this.batchPendingIndex := 0
            this.batchAddedCount := 0
            this.batchUndoState := ""
            this.batchAddedPaths := []
            this.batchTruncated := false
            if updateUi && this.IsOpen()
                this.SetBatchUi(false)
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        try App.fileScanner.Stop(workerPid, outputPath,
            workerCreationIdentity)
        if addedCount {
            CommitUndoState(undoState,
                CreateAppHistoryAction("add", addedPaths))
            SaveAppsToIni()
            LogMsg(Tr("批量导入已取消，已保留并保存此前添加的 {1} 个守护对象。",
                addedCount))
        }
        return cancelledSessionId
    }

    Confirm(*) {
        if !this.IsOpen()
            return
        path := Trim(this.edit.Value)
        if (path == "") {
            this.Close()
            return
        }

        if DirExist(path) {
            this.StartBatchImport([path])
            return
        } else {
            shortcutArgs := "", resolvedWorkDir := ""
            path := ResolveShortcutForAdd(path, &shortcutArgs, &resolvedWorkDir)
            normalizedPath := NormalizeTargetPath(path)
            if (normalizedPath == "" || App.appStates.Has(normalizedPath)
                || DirExist(normalizedPath)) {
                ShowDarkMsgBox(Tr("该目标已存在、无效或指向目录。"),
                    Tr("未添加"), "Info", this.gui)
            } else {
                QueueGuardMutation(ObjBindMethod(this, "AddSingleItem",
                    normalizedPath, resolvedWorkDir, shortcutArgs))
            }
        }
        this.Close()
    }

    AddSingleItem(normalizedPath, resolvedWorkDir, shortcutArgs, *) {
        if App.appStates.Has(normalizedPath) || DirExist(normalizedPath)
            return false
        undoState := CaptureAppConfigState()
        if !RegisterApp(normalizedPath, 1, 0, resolvedWorkDir, "", "", "",
            "", false, shortcutArgs) {
            LogMsg(Tr("添加守护对象失败，已回滚内存状态：{1}",
                normalizedPath))
            return false
        }
        CommitUndoState(undoState,
            CreateAppHistoryAction("add", normalizedPath))
        SaveAppsToIni()
        LogMsg(Tr("手动添加守护对象：{1}", normalizedPath))
        return true
    }

    Close(*) {
        this.CancelBatchImport(false)
        try this.search.Close()
        this.DestroyGui()
        this.edit := ""
        this.pathHint := ""
        this.searchButton := ""
        this.browseButton := ""
        this.okButton := ""
        this.cancelButton := ""
        this.batchStatus := ""
        this.normalActionButtonY := 0
        this.batchActionButtonY := 0
        this.normalWindowHeight := 0
        this.batchWindowHeight := 0
        this.batchUndoState := ""
        this.batchAddedPaths := []
    }

    Shutdown(*) {
        try this.Close()
        try this.search.Shutdown()
    }
}
