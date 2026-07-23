class ApplicationSearchDialog extends ManagedWindow {
    __New(ownerDialog) {
        this.ownerDialog := ownerDialog
        this.lv := ""
        this.searchEdit := ""
        this.searchEditBackground := ""
        this.selectButton := ""
        this.imageList := 0
        this.activeImageListUsers := 0
        this.retiredImageLists := []
        this.appList := []
        this.scanSeen := Map()
        this.scanSeen.CaseSense := "Off"
        this.scanTruncated := false
        this.pendingScanPaths := []
        this.pendingScanIndex := 0
        this.hoverRow := 0
        this.tooltip := DarkTooltipWindow()
        this.everythingLib := 0
        this.everythingAvailable := false
        this.everythingDllPath := A_ScriptDir
            . "\third_party\everything\Everything64.dll"
        this.everythingFunctions := Map()
        this.mouseHandler := ObjBindMethod(this, "OnMouseMove")
        this.mouseHandlerRegistered := false
        this.scanWorkerPid := 0
        this.scanWorkerCreationIdentity := ""
        this.scanWorkerDeadlineTicks := 0
        this.scanOutputPath := ""
        this.scanSessionId := 0
        this.scanPollTimer := ObjBindMethod(this, "PollNativeScan")
        this.scanConsumeTimer := ObjBindMethod(this, "ConsumeNativeScanBatch")
        this.pendingScanPaths := []
        this.pendingScanIndex := 0
        this.searchTimer := ObjBindMethod(this, "RunDeferredSearch")
        this.initialSearchTimer := ObjBindMethod(this, "BeginInitialSearch")
    }

    LoadEverythingLibrary() {
        if this.everythingLib && this.everythingFunctions.Count
            return true
        if !FileExist(this.everythingDllPath)
            || DirExist(this.everythingDllPath)
            return false
        moduleHandle := DllCall("kernel32\LoadLibraryExW",
            "WStr", this.everythingDllPath, "Ptr", 0,
            "UInt", 0x00000900, "Ptr")
        if !moduleHandle
            moduleHandle := DllCall("kernel32\LoadLibraryW",
                "WStr", this.everythingDllPath, "Ptr")
        if !moduleHandle
            return false
        functionNames := [
            "Everything_SetSearchW",
            "Everything_SetSort",
            "Everything_QueryW",
            "Everything_GetNumResults",
            "Everything_GetResultFileNameW",
            "Everything_GetResultPathW"
        ]
        resolvedFunctions := Map()
        for functionName in functionNames {
            functionAddress := DllCall("kernel32\GetProcAddress",
                "Ptr", moduleHandle, "AStr", functionName, "Ptr")
            if !functionAddress {
                DllCall("kernel32\FreeLibrary", "Ptr", moduleHandle)
                return false
            }
            resolvedFunctions[functionName] := functionAddress
        }
        this.everythingLib := moduleHandle
        this.everythingFunctions := resolvedFunctions
        return true
    }

    Show(*) {
        if !this.ownerDialog.IsOpen()
            return
        if this.ShowExisting()
            return

        if App.preferEverything && !this.everythingLib
            this.LoadEverythingLibrary()
        title := (App.preferEverything && this.everythingLib) ? "搜索 ⚡Everything 引擎启动⚡" : "搜索 ⚡原生深扫引擎⚡"

        if !this.CreateOwnedGui(this.ownerDialog.gui, "+Resize +MaximizeBox +MinSize500x300", title)
            return
        try {
        SetDarkTitleBar(this.gui.Hwnd)
        SetWindowIcon(this.gui.Hwnd, A_ScriptDir "\watchdog.ico")
        this.gui.BackColor := "1E1E1E"
        this.gui.SetFont("s10 cWhite", "Microsoft YaHei")
        this.gui.Add("Text", "x20 y20 w60 h25 BackgroundTrans", "🔍 搜索:")
        searchInput := AddCenteredSingleLineEdit(this.gui, 80, 15, 600, 25, "", "", "333333")
        this.searchEditBackground := searchInput.Background
        this.searchEdit := searchInput.Edit
        SetDarkControl(this.searchEdit.Hwnd)

        this.lv := this.gui.Add("ListView", "x20 y55 w660 h280 Background252526 cWhite -E0x200 -Multi -Hdr", ["名称", "路径"])
        SetDarkListView(this.lv.Hwnd)
        this.lv.ModifyCol(1, 264)
        this.lv.ModifyCol(2, 396)
        this.imageList := this.CreateImageList()
        if this.imageList
            this.lv.SetImageList(this.imageList, 1)

        this.selectButton := this.gui.Add("Text", "x314 y357 w72 h28 Center 0x200 Background0078D7 cWhite", "✔️ 确 定")
        RegisterHoverButton(this.selectButton, "0078D7")
        this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
        this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
        this.gui.OnEvent("Size", ObjBindMethod(this, "OnResize"))
        this.lv.OnEvent("DoubleClick", ObjBindMethod(this, "Select"))
        RegisterButtonClick(this.selectButton, ObjBindMethod(this, "Select"), ButtonFeedbackMode.Dismissive)
        OnMessage(Win32.WM_MOUSEMOVE, this.mouseHandler)
        this.mouseHandlerRegistered := true

        this.everythingAvailable := App.preferEverything && !!this.everythingLib
        this.gui.Show("w700 h400")
        ControlFocus(this.searchEdit)
        this.searchEdit.OnEvent("Change", ObjBindMethod(this, "OnSearchChanged"))
        SetTimer(this.initialSearchTimer, -10)
        } catch as openErr {
            this.Close()
            throw openErr
        }
    }

    BeginInitialSearch(*) {
        if !this.IsOpen() {
            this.Close()
            return
        }
        if (this.everythingAvailable && this.SearchEverything())
            return
        this.everythingAvailable := false
        this.LoadNativeApps()
    }

    OnResize(GuiObj, MinMax, Width, Height) {
        if (MinMax == -1 || !this.lv)
            return
        Width := Max(500, Width)
        Height := Max(300, Height)
        try this.searchEditBackground.Move(,, Width - 100)
        try this.searchEdit.Move(,, Width - 100)
        try this.lv.Move(,, Width - 40, Height - 110)
        listWidth := Width - 65
        try this.lv.ModifyCol(1, Integer(listWidth * 0.4))
        try this.lv.ModifyCol(2, Integer(listWidth * 0.6))
        try this.selectButton.Move(Floor((Width - 72) / 2), Height - 43)
    }

    CreateImageList() {
        return IL_Create(10)
    }

    AcquireImageListUse() {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if !this.IsOpen() || !this.imageList
                return 0
            this.activeImageListUsers++
            return this.imageList
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
    }

    ReleaseImageListUse() {
        imageListsToDestroy := []
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if this.activeImageListUsers > 0
                this.activeImageListUsers--
            if !this.activeImageListUsers && this.retiredImageLists.Length {
                imageListsToDestroy := this.retiredImageLists
                this.retiredImageLists := []
            }
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        for imageList in imageListsToDestroy {
            ClearImageListIconCache(imageList)
            try IL_Destroy(imageList)
        }
    }

    RetireImageList(imageList) {
        if !imageList
            return
        destroyNow := false
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if this.activeImageListUsers
                this.retiredImageLists.Push(imageList)
            else
                destroyNow := true
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        if destroyNow {
            ClearImageListIconCache(imageList)
            try IL_Destroy(imageList)
        }
    }

    OnMouseMove(wParam, lParam, msg, hwnd) {
        if !this.IsOpen() {
            this.Close()
            return
        }
        if !this.lv {
            this.tooltip.Hide()
            this.hoverRow := 0
            return
        }
        if (hwnd != this.lv.Hwnd) {
            this.tooltip.Hide()
            this.hoverRow := 0
            return
        }
        point := Buffer(24, 0)
        NumPut("Int", SignedWord(lParam), point, 0)
        NumPut("Int", SignedWord(lParam >> 16), point, 4)
        row := SendMessage(Win32.LVM_HITTEST, 0, point.Ptr, this.lv)
        if (row >= 0) {
            row += 1
            if (row != this.hoverRow) {
                this.hoverRow := row
                this.tooltip.Show("项目名称: " this.lv.GetText(row, 1) "`n真实路径: " this.lv.GetText(row, 2))
            }
        } else if (this.hoverRow != 0) {
            this.hoverRow := 0
            this.tooltip.Hide()
        }
    }

    SearchEverything(*) {
        if !this.everythingLib || !this.everythingAvailable || !this.IsOpen()
            return false
        keyword := Trim(this.searchEdit.Value)
        if (keyword == "") {
            keyword := "ext:exe;com;msc;ahk;py;pyw;js;vbs;vbe;wsf;ps1;bat;cmd;rb;pl;php;lua;jar;sh;bash;lnk;url;appref-ms"
        } else if !InStr(keyword, "ext:") && !InStr(keyword, "\") && !InStr(keyword, ":") {
            keyword := "ext:exe;com;msc;ahk;py;pyw;js;vbs;vbe;wsf;ps1;bat;cmd;rb;pl;php;lua;jar;sh;bash;lnk;url;appref-ms " keyword
        }

        try {
            DllCall(this.everythingFunctions["Everything_SetSearchW"],
                "WStr", keyword)
            DllCall(this.everythingFunctions["Everything_SetSort"],
                "UInt", 14)
            if !DllCall(this.everythingFunctions["Everything_QueryW"],
                "Int", 1)
                return false
            resultCount := DllCall(
                this.everythingFunctions["Everything_GetNumResults"],
                "UInt")
        } catch {
            return false
        }

        imageList := this.AcquireImageListUse()
        if !imageList
            return false
        redrawSuspended := false
        try {
            this.lv.Opt("-Redraw")
            redrawSuspended := true
            this.lv.Delete()
            Loop Min(resultCount, App.everythingMaxResults) {
                index := A_Index - 1
                namePtr := DllCall(this.everythingFunctions[
                    "Everything_GetResultFileNameW"],
                    "UInt", index, "Ptr")
                pathPtr := DllCall(this.everythingFunctions[
                    "Everything_GetResultPathW"],
                    "UInt", index, "Ptr")
                if (!namePtr || !pathPtr)
                    continue
                name := StrGet(namePtr, "UTF-16")
                path := StrGet(pathPtr, "UTF-16")
                fullPath := RTrim(path, "\") "\" name
                iconIndex := GetFileIconIndex(fullPath, imageList)
                this.lv.Add("Icon" iconIndex, name, fullPath)
            }
        } catch as resultErr {
            LogMsg("读取 Everything 搜索结果失败: " resultErr.Message)
            return false
        } finally {
            if redrawSuspended
                try this.lv.Opt("+Redraw")
            this.ReleaseImageListUse()
        }
        return true
    }

    OnSearchChanged(*) {
        SetTimer(this.searchTimer, 0)
        SetTimer(this.searchTimer, -150)
    }

    RunDeferredSearch(*) {
        if !this.IsOpen() {
            this.Close()
            return
        }
        try {
            if this.everythingAvailable {
                if !this.SearchEverything() {
                    this.everythingAvailable := false
                    try WinSetTitle("搜索 ⚡原生深扫引擎⚡", this.gui.Hwnd)
                    this.LoadNativeApps()
                }
            } else {
                this.FilterNativeList()
            }
        } catch as searchErr {
            LogMsg("更新应用搜索结果失败: " searchErr.Message)
            try WinSetTitle("搜索 ⚡原生深扫引擎⚡（刷新失败）",
                this.gui.Hwnd)
        }
    }

    LoadNativeApps() {
        if !this.IsOpen() {
            this.Close()
            return
        }
        if !this.lv
            return
        sessionId := this.CancelNativeScan()
        this.appList := []
        this.scanSeen := Map()
        this.scanSeen.CaseSense := "Off"
        this.scanTruncated := false
        this.pendingScanPaths := []
        this.pendingScanIndex := 0
        this.lv.Delete()
        try WinSetTitle("搜索 ⚡原生深扫引擎⚡（扫描中）", this.gui.Hwnd)
        maximumResults := Max(1000, Min(20000, App.everythingMaxResults * 20))
        try {
            scanWorker := App.fileScanner.Start("search", "", true,
                maximumResults, App.nativeScanTimeoutSeconds)
            if scanWorker {
                accepted := false
                previousCritical := A_IsCritical
                Critical("On")
                try {
                    if this.IsNativeScanCurrent(sessionId) {
                        this.scanWorkerPid := scanWorker.Pid
                        this.scanWorkerCreationIdentity :=
                            scanWorker.CreationIdentity
                        this.scanWorkerDeadlineTicks := scanWorker.DeadlineTicks
                        this.scanOutputPath := scanWorker.Path
                        SetTimer(this.scanPollTimer, 100)
                        accepted := true
                    }
                } finally {
                    Critical(previousCritical ? previousCritical : "Off")
                }
                if !accepted
                    App.fileScanner.Stop(scanWorker.Pid, scanWorker.Path,
                        scanWorker.CreationIdentity)
            } else {
                try WinSetTitle("搜索 ⚡原生深扫引擎⚡（启动失败）",
                    this.gui.Hwnd)
            }
        } catch as scanStartErr {
            this.FailNativeScan("启动后台应用扫描失败", scanStartErr,
                sessionId)
        }
    }

    IsNativeScanCurrent(sessionId) {
        return sessionId == this.scanSessionId && this.IsOpen()
    }

    PollNativeScan(*) {
        if !this.IsOpen() {
            this.Close()
            return
        }
        sessionId := this.scanSessionId
        try {
            if FileExist(this.scanOutputPath) {
                SetTimer(this.scanPollTimer, 0)
                outputPath := this.scanOutputPath
                pendingPaths := App.fileScanner.ReadResult(outputPath,
                    &wasTruncated, &resultReady)
                try FileDelete(outputPath)
                previousCritical := A_IsCritical
                Critical("On")
                try {
                    if !this.IsNativeScanCurrent(sessionId)
                        return
                    this.pendingScanPaths := pendingPaths
                    this.scanTruncated := wasTruncated
                    this.scanWorkerPid := 0
                    this.scanWorkerCreationIdentity := ""
                    this.scanWorkerDeadlineTicks := 0
                    this.scanOutputPath := ""
                    this.pendingScanIndex := 0
                } finally {
                    Critical(previousCritical ? previousCritical : "Off")
                }
                if !resultReady {
                    if this.IsNativeScanCurrent(sessionId)
                        try WinSetTitle("搜索 ⚡原生深扫引擎⚡（扫描失败）",
                            this.gui.Hwnd)
                    return
                }
                previousCritical := A_IsCritical
                Critical("On")
                try {
                    if !this.IsNativeScanCurrent(sessionId)
                        return
                    SetTimer(this.scanConsumeTimer, 15)
                } finally {
                    Critical(previousCritical ? previousCritical : "Off")
                }
                return
            }
            workerPid := this.scanWorkerPid
            workerCreationIdentity := this.scanWorkerCreationIdentity
            workerDeadlineTicks := this.scanWorkerDeadlineTicks
            if (workerPid
                && (!ProcessExist(workerPid)
                    || (workerCreationIdentity != ""
                        && App.processInspector.GetCreationIdentity(
                            workerPid) != workerCreationIdentity)
                    || (workerDeadlineTicks
                        && GetTickCount64() >= workerDeadlineTicks))) {
                this.FailNativeScan("后台应用扫描未生成完整结果", "",
                    sessionId)
            }
        } catch as scanPollErr {
            this.FailNativeScan("读取后台应用扫描结果失败", scanPollErr,
                sessionId)
        }
    }

    ConsumeNativeScanBatch(*) {
        if !this.IsOpen() {
            this.Close()
            return
        }
        sessionId := this.scanSessionId
        try {
            batchEnd := Min(this.pendingScanPaths.Length,
                this.pendingScanIndex + 7)
            while (this.pendingScanIndex < batchEnd) {
                this.pendingScanIndex++
                this.ProcessScannedItem(
                    this.pendingScanPaths[this.pendingScanIndex], sessionId)
                if !this.IsNativeScanCurrent(sessionId)
                    return
            }
            if (this.pendingScanIndex >= this.pendingScanPaths.Length) {
                wasTruncated := this.scanTruncated
                previousCritical := A_IsCritical
                Critical("On")
                try {
                    if !this.IsNativeScanCurrent(sessionId)
                        return
                    SetTimer(this.scanConsumeTimer, 0)
                    this.pendingScanPaths := []
                    this.pendingScanIndex := 0
                } finally {
                    Critical(previousCritical ? previousCritical : "Off")
                }
                if this.IsNativeScanCurrent(sessionId)
                    try WinSetTitle(wasTruncated
                        ? "搜索 ⚡原生深扫引擎⚡（结果已截断）"
                        : "搜索 ⚡原生深扫引擎⚡", this.gui.Hwnd)
            }
        } catch as scanConsumeErr {
            this.FailNativeScan("显示后台应用扫描结果失败", scanConsumeErr,
                sessionId)
        }
    }

    CancelNativeScan(expectedSessionId := 0) {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if expectedSessionId && expectedSessionId != this.scanSessionId
                return 0
            this.scanSessionId++
            cancelledSessionId := this.scanSessionId
            try SetTimer(this.scanPollTimer, 0)
            try SetTimer(this.scanConsumeTimer, 0)
            workerPid := this.scanWorkerPid
            workerCreationIdentity := this.scanWorkerCreationIdentity
            outputPath := this.scanOutputPath
            this.scanWorkerPid := 0
            this.scanWorkerCreationIdentity := ""
            this.scanWorkerDeadlineTicks := 0
            this.scanOutputPath := ""
            this.pendingScanPaths := []
            this.pendingScanIndex := 0
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        try App.fileScanner.Stop(workerPid, outputPath,
            workerCreationIdentity)
        return cancelledSessionId
    }

    FailNativeScan(context, failure := "", expectedSessionId := 0) {
        failureSessionId := this.CancelNativeScan(expectedSessionId)
        if !failureSessionId
            return
        detail := ""
        if failure is Error
            detail := failure.Message
        else if (failure != "")
            detail := String(failure)
        LogMsg(context (detail != "" ? ": " detail : "。"))
        if this.IsNativeScanCurrent(failureSessionId)
            try WinSetTitle("搜索 ⚡原生深扫引擎⚡（扫描失败）",
                this.gui.Hwnd)
    }

    ProcessScannedItem(filePath, sessionId) {
        canonicalPath := GetCanonicalPath(filePath)
        if !App.fileScanner.IsSupported(filePath)
            return

        SplitPath(filePath, , , &extension, &nameNoExt)
        if RegExMatch(nameNoExt, "i)uninstall|卸载|help|帮助|readme|unins000")
            return
        imageList := this.AcquireImageListUse()
        if !imageList
            return
        try iconIndex := GetFileIconIndex(filePath, imageList)
        finally this.ReleaseImageListUse()
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if !this.IsNativeScanCurrent(sessionId)
                || this.imageList != imageList
                || this.scanSeen.Has(canonicalPath) {
                return
            }
            this.scanSeen[canonicalPath] := true
            item := {Name: nameNoExt, Path: filePath, IconIdx: iconIndex}
            this.appList.Push(item)
            term := StrLower(Trim(this.searchEdit.Value))
            if (term == "" || InStr(StrLower(nameNoExt), term)
                || InStr(StrLower(filePath), term)) {
                this.lv.Add("Icon" iconIndex, nameNoExt, filePath)
            }
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
    }

    FilterNativeList(*) {
        if !this.IsOpen()
            return
        this.lv.Opt("-Redraw")
        try {
            this.lv.Delete()
            term := StrLower(Trim(this.searchEdit.Value))
            for item in this.appList {
                if (term == "" || InStr(StrLower(item.Name), term) || InStr(StrLower(item.Path), term))
                    this.lv.Add("Icon" item.IconIdx, item.Name, item.Path)
            }
        } finally {
            try this.lv.Opt("+Redraw")
        }
    }

    Select(*) {
        if !this.IsOpen()
            return
        row := this.lv.GetNext(0)
        if (row > 0 && this.ownerDialog.IsOpen())
            this.ownerDialog.edit.Value := this.lv.GetText(row, 2)
        this.Close()
    }

    ClearIconCache() {
        ClearImageListIconCache(this.imageList)
    }

    Close(*) {
        try SetTimer(this.initialSearchTimer, 0)
        try SetTimer(this.searchTimer, 0)
        this.CancelNativeScan()
        if this.mouseHandlerRegistered {
            try OnMessage(Win32.WM_MOUSEMOVE, this.mouseHandler, 0)
            this.mouseHandlerRegistered := false
        }
        this.ClearIconCache()
        imageList := this.imageList
        this.imageList := 0
        this.tooltip.Hide()
        this.DestroyGui()
        this.RetireImageList(imageList)
        this.lv := ""
        this.searchEdit := ""
        this.searchEditBackground := ""
        this.selectButton := ""
        this.appList := []
        this.scanSeen := Map()
        this.scanSeen.CaseSense := "Off"
        this.scanTruncated := false
        this.pendingScanPaths := []
        this.pendingScanIndex := 0
        this.hoverRow := 0
    }

    Shutdown(*) {
        try this.Close()
        try this.tooltip.Close()
        if this.everythingLib {
            try DllCall("kernel32\FreeLibrary", "Ptr", this.everythingLib)
            this.everythingLib := 0
        }
        this.everythingFunctions := Map()
        this.everythingAvailable := false
    }
}
