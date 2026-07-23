class AddItemDialog extends ManagedWindow {
    __New(mainGui) {
        this.owner := mainGui
        this.edit := ""
        this.search := ApplicationSearchDialog(this)
        this.searchButton := ""
        this.browseButton := ""
        this.okButton := ""
        this.cancelButton := ""
        this.batchStatus := ""
        this.batchWorkerPid := 0
        this.batchWorkerCreationIdentity := ""
        this.batchWorkerDeadlineTicks := 0
        this.batchOutputPath := ""
        this.batchRootQueue := []
        this.batchPendingPaths := []
        this.batchPendingIndex := 0
        this.batchAddedCount := 0
        this.batchTruncated := false
        this.batchSessionId := 0
        this.batchPollTimer := ObjBindMethod(this, "PollBatchImport")
        this.batchConsumeTimer := ObjBindMethod(this, "ConsumeBatchImport")
    }

    HideTransientWindows() {
        this.search.tooltip.Hide()
    }

    Show(*) {
        if this.ShowExisting()
            return

        if !this.CreateOwnedGui(this.owner, "-MinimizeBox -MaximizeBox", "添加监控项")
            return
        try {
        this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
        this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
        SetDarkTitleBar(this.gui.Hwnd)
        SetWindowIcon(this.gui.Hwnd, A_ScriptDir "\watchdog.ico")
        this.gui.BackColor := "1E1E1E"
        this.gui.SetFont("s10 cWhite", "Microsoft YaHei")

        this.gui.Add("Text", "x20 y15 w480 BackgroundTrans", "请输入进程名或目标路径，或通过下方菜单选择:`n（支持程序、脚本、快捷方式，以及文件夹批量导入）")
        inputControl := AddCenteredSingleLineEdit(this.gui, 20, 65, 480, 26)
        this.edit := inputControl.Edit
        SetDarkControl(this.edit.Hwnd)

        this.batchStatus := this.gui.Add("Text", "x20 y94 w480 h18 Center BackgroundTrans cAFAFAF Hidden", "正在扫描...")
        this.searchButton := this.gui.Add("Text", "x20 y114 w70 h26 Center 0x200 Background333333 cWhite", "🔍 搜索...")
        this.browseButton := this.gui.Add("Text", "x98 y114 w72 h26 Center 0x200 Background333333 cWhite", "📂 选择...")
        this.okButton := this.gui.Add("Text", "x356 y114 w68 h26 Center 0x200 Background0078D7 cWhite", "✔️ 确 定")
        this.cancelButton := this.gui.Add("Text", "x432 y114 w68 h26 Center 0x200 Background333333 cWhite", "❌ 取 消")
        RegisterHoverButton(this.searchButton, "333333")
        RegisterHoverButton(this.browseButton, "333333")
        RegisterHoverButton(this.okButton, "0078D7")
        RegisterHoverButton(this.cancelButton, "333333")
        RegisterButtonClick(this.searchButton, ObjBindMethod(this.search, "Show"))
        RegisterButtonClick(this.browseButton, ObjBindMethod(this, "ShowBrowseMenu"))
        RegisterButtonClick(this.okButton, ObjBindMethod(this, "Confirm"), ButtonFeedbackMode.Dismissive)
        RegisterButtonClick(this.cancelButton, ObjBindMethod(this, "Close"), ButtonFeedbackMode.Dismissive)
        this.gui.Show("w520 h155")
        } catch as openErr {
            this.Close()
            throw openErr
        }
    }

    ShowBrowseMenu(*) {
        browseMenu := Menu()
        browseMenu.Add("📄 浏览文件...", ObjBindMethod(this, "BrowseFile"))
        browseMenu.Add("📂 浏览文件夹...", ObjBindMethod(this, "BrowseDir"))
        browseMenu.Show()
    }

    BrowseFile(*) {
        selected := this.SelectFile("选择要监控的文件")
        if selected && this.IsOpen()
            this.edit.Value := selected
    }

    BrowseDir(*) {
        selected := this.SelectDirectory("选择要监控的文件夹")
        if selected && this.IsOpen()
            this.edit.Value := selected
    }

    SelectFile(prompt := "选择文件") {
        hwndOwner := this.IsOpen() ? this.gui.Hwnd : 0
        return SelectFileWithNamedFilter(hwndOwner, "", prompt,
            "支持的程序、脚本与快捷方式",
            "*.exe;*.com;*.msc;*.ahk;*.py;*.pyw;*.js;*.vbs;*.vbe;*.wsf;*.ps1;*.bat;*.cmd;*.rb;*.pl;*.php;*.lua;*.jar;*.sh;*.bash;*.lnk;*.url;*.appref-ms")
    }

    SelectDirectory(prompt := "选择文件夹") {
        try {
            fbd := ComObject("{DC1C5A9C-E88A-4DDE-A5A1-60F82A20AEF7}", "{d57c7288-d4ad-4768-be02-9d969532d960}")
            ComCall(9, fbd, "UInt", 0x60)
            ComCall(17, fbd, "Str", prompt)
            hwndOwner := this.IsOpen() ? this.gui.Hwnd : 0
            return this.ReadFileDialogPath(fbd, hwndOwner)
        } catch {
            return ""
        }
    }

    ReadFileDialogPath(fileDialog, hwndOwner) {
        if (ComCall(3, fileDialog, "Ptr", hwndOwner, "Int") != 0)
            return ""
        shellItem := 0
        pathBuffer := 0
        try {
            ComCall(20, fileDialog, "Ptr*", &shellItem)
            ComCall(5, shellItem, "UInt", 0x80058000, "Ptr*", &pathBuffer)
            return pathBuffer ? StrGet(pathBuffer, "UTF-16") : ""
        } finally {
            if pathBuffer
                try DllCall("ole32\CoTaskMemFree", "Ptr", pathBuffer)
            if shellItem
                try ObjRelease(shellItem)
        }
    }

    SetBatchUi(active, statusText := "") {
        if !this.IsOpen()
            return
        for control in [this.edit, this.searchButton, this.browseButton, this.okButton] {
            if control
                try control.Enabled := !active
        }
        if this.batchStatus {
            try this.batchStatus.Text := statusText
            try this.batchStatus.Visible := active
        }
    }

    StartBatchImport(rootPaths, directPaths := "") {
        this.Show()
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
            this.SetBatchUi(true, "正在扫描文件夹，可点击取消停止")
            this.StartNextBatchRoot(sessionId)
        } catch as batchStartErr {
            this.FailBatchImport("启动批量导入失败", batchStartErr,
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
            timeoutSeconds := Max(30, Min(300, App.nativeScanTimeoutSeconds * 4))
            scanWorker := App.fileScanner.Start("batch", rootPath,
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
                        this.batchStatus.Text := "正在扫描：" rootPath
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
            if (workerPid
                && (!ProcessExist(workerPid)
                    || (workerCreationIdentity != ""
                        && App.processInspector.GetCreationIdentity(
                            workerPid) != workerCreationIdentity)
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
            this.FailBatchImport("读取后台扫描结果失败", batchPollErr,
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
                this.batchTruncated := false
                this.batchSessionId++
                completedSessionId := this.batchSessionId
                this.SetBatchUi(false)
            } finally {
                Critical(previousCritical ? previousCritical : "Off")
            }
            if this.IsBatchSessionCurrent(completedSessionId)
                try ShowDarkMsgBox("所选文件夹内未找到支持的程序、脚本或快捷方式。",
                    "未找到目标", "Info", this.gui)
            return
        }
        this.batchPendingIndex := 0
        this.batchStatus.Text := "正在添加扫描结果..."
        SetTimer(this.batchConsumeTimer, 15)
    }

    ConsumeBatchImport(*) {
        if !this.IsOpen() {
            this.Close()
            return
        }
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
                    firstSuccessfulSnapshot := this.batchAddedCount
                        ? "" : CaptureAppConfigState()
                    if RegisterApp(resolvedPath, 1, 0, resolvedWorkDir,
                        "", "", "", "", false, shortcutArgs) {
                        if !this.batchAddedCount
                            CommitUndoState(firstSuccessfulSnapshot)
                        this.batchAddedCount++
                    }
                } finally {
                    Critical(previousCritical ? previousCritical : "Off")
                }
            }
            this.batchStatus.Text := "正在添加：" this.batchPendingIndex " / "
                . this.batchPendingPaths.Length
            if (this.batchPendingIndex < this.batchPendingPaths.Length)
                return
            this.CompleteBatchImport(sessionId)
        } catch as batchConsumeErr {
            this.FailBatchImport("添加扫描结果失败", batchConsumeErr,
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
            wasTruncated := this.batchTruncated
            this.batchPendingPaths := []
            this.batchPendingIndex := 0
            this.batchAddedCount := 0
            this.batchTruncated := false
            this.batchSessionId++
            completedSessionId := this.batchSessionId
            this.SetBatchUi(false)
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        if addedCount
            SaveAppsToIni()
        message := "已添加 " addedCount " 个监控项。"
        if wasTruncated
            message .= " 扫描达到时间或数量上限，结果已截断。"
        LogMsg(message)
        if this.IsBatchSessionCurrent(completedSessionId)
            try ShowDarkMsgBox(message, "批量导入完成", "Info", this.gui)
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
            this.batchWorkerPid := 0
            this.batchWorkerCreationIdentity := ""
            this.batchWorkerDeadlineTicks := 0
            this.batchOutputPath := ""
            this.batchRootQueue := []
            this.batchPendingPaths := []
            this.batchPendingIndex := 0
            this.batchAddedCount := 0
            this.batchTruncated := false
            this.SetBatchUi(false)
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        try App.fileScanner.Stop(workerPid, outputPath,
            workerCreationIdentity)
        if addedCount
            SaveAppsToIni()
        failureText := failure is Error ? failure.Message : String(failure)
        LogMsg(context ": " failureText)
        if this.IsBatchSessionCurrent(failureSessionId) {
            message := context "。"
            if addedCount
                message .= " 已保留并保存此前添加的 " addedCount " 个监控项。"
            try ShowDarkMsgBox(message, "批量导入中断", "Error", this.gui)
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
            this.batchWorkerPid := 0
            this.batchWorkerCreationIdentity := ""
            this.batchWorkerDeadlineTicks := 0
            this.batchOutputPath := ""
            this.batchRootQueue := []
            this.batchPendingPaths := []
            this.batchPendingIndex := 0
            this.batchAddedCount := 0
            this.batchTruncated := false
            if updateUi && this.IsOpen()
                this.SetBatchUi(false)
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        try App.fileScanner.Stop(workerPid, outputPath,
            workerCreationIdentity)
        if addedCount {
            SaveAppsToIni()
            LogMsg("批量导入已取消，已保留并保存此前添加的 " addedCount " 个监控项。")
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
                ShowDarkMsgBox("该目标已存在、无效或指向目录。", "未添加", "Info", this.gui)
            } else {
                undoState := CaptureAppConfigState()
                if RegisterApp(normalizedPath, 1, 0, resolvedWorkDir, "", "", "", "", false, shortcutArgs) {
                    CommitUndoState(undoState)
                    SaveAppsToIni()
                    LogMsg("手动添加监控: " normalizedPath)
                } else {
                    ShowDarkMsgBox("该目标已存在、无效或指向目录。", "未添加", "Info", this.gui)
                }
            }
        }
        this.Close()
    }

    Close(*) {
        this.CancelBatchImport(false)
        try this.search.Close()
        this.DestroyGui()
        this.edit := ""
        this.searchButton := ""
        this.browseButton := ""
        this.okButton := ""
        this.cancelButton := ""
        this.batchStatus := ""
    }

    Shutdown(*) {
        try this.Close()
        try this.search.Shutdown()
    }
}
