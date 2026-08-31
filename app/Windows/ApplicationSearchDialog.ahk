; 已安装应用搜索窗口。
; 程序搜索使用随包 Everything SDK；后台实例缺失时先从有界本机来源定位并启动，
; 查询结果不设上限，并通过短批次逐步加入列表，避免图标提取长时间阻塞界面。

class ApplicationSearchDialog extends ManagedWindow {
    static SearchDebounceMilliseconds := 300
    static StartupRetryMilliseconds := 200
    static StartupTimeoutMilliseconds := 8000
    static EverythingErrorIpc := 2
    static EverythingSearchMode := "EverythingSearch"
    static RunningProcessesMode := "RunningProcesses"
    static ApplicationGroupId := 1
    static BackgroundProcessGroupId := 2

    __New(ownerDialog) {
        this.ownerDialog := ownerDialog
        this.lv := ""
        this.listHeader := ""
        this.listSelectionPresenter := ""
        this.searchLabel := ""
        this.searchLabelPresenter := ""
        this.searchInputX := 95
        this.windowWidth := 700
        this.listContentWidth := 0
        this.searchEdit := ""
        this.searchEditBackground := ""
        this.resultStatusText := ""
        this.everythingDownloadLink := ""
        this.selectButton := ""
        this.imageList := 0
        this.hoverRow := 0
        this.tooltip := DarkTooltipWindow()
        this.everythingLib := 0
        this.everythingDllPath := A_ScriptDir
            . "\third_party\everything\Everything64.dll"
        this.everythingFunctions := Map()
        this.everythingResultCount := 0
        this.everythingResultIndex := 0
        this.resultRows := []
        this.everythingSearchSessionId := 0
        this.mode := ApplicationSearchDialog.EverythingSearchMode
        this.runningProcesses := []
        this.runningProcessSource := []
        this.runningProcessPreparationIndex := 0
        this.runningProcessPreparationSeen := Map()
        this.runningProcessPreparationSeen.CaseSense := "Off"
        this.runningProcessPreparationComplete := false
        this.runningProcessIndex := 0
        this.runningProcessRows := []
        this.runningProcessSeen := Map()
        this.runningProcessSeen.CaseSense := "Off"
        this.runningProcessApplicationPids := Map()
        this.runningProcessGroupCounts := Map(
            ApplicationSearchDialog.ApplicationGroupId, 0,
            ApplicationSearchDialog.BackgroundProcessGroupId, 0)
        this.runningProcessSessionId := 0
        this.everythingUnavailableLogged := false
        this.everythingRuntimeService := EverythingRuntimeService()
        this.everythingStartupDeadline := 0
        this.everythingStartupPath := ""
        this.mouseHandler := ObjBindMethod(this, "OnMouseMove")
        this.mouseHandlerRegistered := false
        this.resultConsumeTimer := ObjBindMethod(this,
            "ConsumeEverythingResultBatch")
        this.runningProcessTimer := ObjBindMethod(this,
            "ConsumeRunningProcessBatch")
        this.searchTimer := ObjBindMethod(this, "RunDeferredSearch")
        this.everythingStartupTimer := ObjBindMethod(this,
            "RetryEverythingStartup")
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
            "Everything_SetMax",
            "Everything_QueryW",
            "Everything_GetNumResults",
            "Everything_GetResultFileNameW",
            "Everything_GetResultPathW",
            "Everything_GetLastError"
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
        previousMode := this.mode
        this.mode := ApplicationSearchDialog.EverythingSearchMode
        opened := this.ShowWindow()
        if opened && previousMode != this.mode {
            try this.searchEdit.Value := ""
            this.ResetSearchResults()
        }
        return opened
    }

    ShowWindow() {
        if !this.ownerDialog.IsOpen()
            return false
        if this.ShowExisting() {
            this.ApplyModeTitle()
            if this.searchEdit
                try ControlFocus(this.searchEdit)
            return true
        }

        if !this.CreateOwnedGui(this.ownerDialog.gui,
                "+Resize +MaximizeBox +MinSize500x300",
                this.GetModeTitle())
            return false
        try {
        InitializeApplicationWindow(this.gui, "s11")
        searchLabelWidth := 24
        this.searchInputX := 20 + searchLabelWidth + 8
        this.searchLabel := this.gui.Add("Text", "x20 y15 w"
            searchLabelWidth " h25 +0xD Background"
                UiThemeService.Color("Window"), Tr("搜索："))
        this.searchLabel.SetFont("s11 bold",
            LocalizationService.GetLanguageSystemUiFontName())
        this.searchLabelPresenter := SvgStatusBarPresenter(
            this.searchLabel, 17, 0, 0, "Text", "Window")
        this.searchLabelPresenter.SetItems([{
            Text: "",
            IconPath: GetApplicationAssetPath("ui-icons\lucide\search.svg"),
            IconColorRole: "SearchIcon"
        }], Tr("搜索："))
        searchInput := AddCenteredSingleLineEdit(this.gui, this.searchInputX,
            15, 700 - this.searchInputX - 20, 25, "", "",
            UiThemeService.Color("Input"))
        this.searchEditBackground := searchInput.Background
        this.searchEdit := searchInput.Edit
        SetDarkControl(this.searchEdit.Hwnd)

        this.resultStatusText := this.gui.Add("Text",
            "x20 y49 w660 h22 c" UiThemeService.Color("MutedText")
                " Background" UiThemeService.Color("Window"), "")
        this.everythingDownloadLink := this.gui.Add("Text",
            "x20 y49 w660 h22 +0x100 Hidden c"
                UiThemeService.Color("Link") " Background"
                UiThemeService.Color("Window"), "")
        this.everythingDownloadLink.SetFont("Underline")
        RegisterHandCursorControl(this.everythingDownloadLink)
        RegisterButtonClick(this.everythingDownloadLink,
            ObjBindMethod(this, "OpenEverythingDownloadPage"))
        this.lv := this.gui.Add("ListView",
            "x20 y107 w660 h228 Report Background"
                UiThemeService.Color("Surface") " c"
                UiThemeService.Color("Text") " -E0x200 -Multi -Hdr",
            [Tr("名称"), Tr("路径"), Tr("扩展名")])
        this.lv.SetFont("s12 c" UiThemeService.Color("Text"),
            LocalizationService.GetUiFontName())
        SetDarkListView(this.lv.Hwnd)
        this.listSelectionPresenter := ListViewSelectionPresenter(this.lv, 4)
        this.listHeader := ListViewPseudoHeader(this.gui, this.lv, [
            {Column: 1, Label: Tr("名称"), SortOptions: "Logical"},
            {Column: 2, Label: Tr("路径"), SortOptions: "Logical"},
            {Column: 3, Label: Tr("扩展名"), Align: "Center",
                SortOptions: "Logical"}
        ], {
            BackgroundColor: UiThemeService.Color("Toolbar"),
            TextColor: UiThemeService.Color("MutedText"),
            FontName: LocalizationService.GetLanguageSystemUiFontName(),
            CursorRegistrar: RegisterHandCursorControl,
            OnSortChanged: ObjBindMethod(this, "OnListSortChanged")
        })
        this.LayoutListHeader(700)
        this.imageList := this.CreateImageList()
        if this.imageList
            this.lv.SetImageList(this.imageList, 1)

        this.selectButton := this.gui.Add("Text",
            "x314 y357 w72 h28 Center 0x200 Background"
                UiThemeService.Color("Primary") " c"
                UiThemeService.Color("ButtonText"),
            Tr("确 定"))
        RegisterHoverButton(this.selectButton, UiThemeService.Color("Primary"))
        this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
        this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
        this.gui.OnEvent("Size", ObjBindMethod(this, "OnResize"))
        this.lv.OnEvent("DoubleClick", ObjBindMethod(this, "Select"))
        RegisterButtonClick(this.selectButton, ObjBindMethod(this, "Select"),
            ButtonFeedbackMode.Dismissive)
        OnMessage(Win32.WM_MOUSEMOVE, this.mouseHandler)
        this.mouseHandlerRegistered := true

        this.windowWidth := 700
        ShowApplicationWindow(this.gui, "w700 h400")
        ControlFocus(this.searchEdit)
        this.searchEdit.OnEvent("Change", ObjBindMethod(this,
            "OnSearchChanged"))
        } catch as openErr {
            this.Close()
            throw openErr
        }
        return true
    }

    GetModeTitle() {
        return this.mode == ApplicationSearchDialog.RunningProcessesMode
            ? Tr("正在运行的进程") : Tr("⚡️搜索⚡️")
    }

    ApplyModeTitle() {
        if !this.IsOpen()
            return false
        try WinSetTitle(this.GetModeTitle(), "ahk_id " this.gui.Hwnd)
        return true
    }

    OnResize(GuiObj, MinMax, Width, Height) {
        if (MinMax == -1 || !this.lv)
            return
        Width := Max(500, Width)
        Height := Max(300, Height)
        this.windowWidth := Width
        try this.searchEditBackground.Move(,,
            Width - this.searchInputX - 20)
        try this.searchEdit.Move(,, Width - this.searchInputX - 20)
        try MoveAndRefreshResizableText(this.resultStatusText, "", "",
            Width - 40, "")
        try MoveAndRefreshResizableText(this.everythingDownloadLink, "", "",
            Width - 40, "")
        try this.lv.Move(20, 107, Width - 40, Height - 172)
        this.LayoutListHeader(Width)
        try this.selectButton.Move(Floor((Width - 72) / 2), Height - 43)
    }

    LayoutListHeader(windowWidth) {
        if !this.lv || !IsObject(this.listHeader)
            return false
        listOuterWidth := Max(1, windowWidth - 40)
        listContentWidth := this.GetListContentWidth(listOuterWidth)
        this.listContentWidth := listContentWidth
        extensionWidth := LocalizationService.UsesCompactLayout() ? 76 : 104
        primaryColumnsWidth := Max(2, listContentWidth - extensionWidth)
        nameWidth := Integer(primaryColumnsWidth * 0.38)
        pathWidth := primaryColumnsWidth - nameWidth
        try {
            this.lv.ModifyCol(1, nameWidth)
            this.lv.ModifyCol(2, pathWidth)
            this.lv.ModifyCol(3, extensionWidth " Center")
            return this.listHeader.SetBounds(20, 75,
                [nameWidth, pathWidth, extensionWidth],
                listOuterWidth)
        } catch {
            return false
        }
    }

    GetListContentWidth(fallbackWidth) {
        if !this.lv
            return Max(1, fallbackWidth)
        clientRect := Buffer(16, 0)
        if !DllCall("user32\GetClientRect", "Ptr", this.lv.Hwnd,
                "Ptr", clientRect, "Int")
            return Max(1, fallbackWidth)
        widthPixels := NumGet(clientRect, 8, "Int")
        dpi := DllCall("user32\GetDpiForWindow", "Ptr", this.lv.Hwnd,
            "UInt")
        if !dpi
            dpi := 96
        return Max(1, Round(widthPixels * 96 / dpi))
    }

    RefreshListWidthIfChanged() {
        currentWidth := this.GetListContentWidth(
            Max(1, this.windowWidth - 40))
        if currentWidth == this.listContentWidth
            return false
        return this.LayoutListHeader(this.windowWidth)
    }

    OnListSortChanged(header, column, descending) {
        if column == 0
            this.RestoreResultOrder()
    }

    RestoreResultOrder() {
        if !this.IsOpen() || !this.lv
            return false
        selectedPath := ""
        selectedRow := this.lv.GetNext(0)
        if selectedRow
            selectedPath := this.lv.GetText(selectedRow, 2)
        this.lv.Opt("-Redraw")
        try {
            this.lv.Delete()
            this.ConfigureResultGroups()
            for rowData in this.resultRows {
                row := this.AddResultRow(rowData)
                if selectedPath != "" && rowData.FullPath == selectedPath
                    this.lv.Modify(row, "Select Focus")
            }
        } finally {
            this.lv.Opt("+Redraw")
        }
        this.RefreshListWidthIfChanged()
        return true
    }

    AddResultRow(rowData) {
        rowOptions := rowData.IconIndex > 0
            ? "Icon" rowData.IconIndex : ""
        row := this.lv.Add(rowOptions, rowData.Name,
            rowData.FullPath, rowData.Extension)
        if this.mode == ApplicationSearchDialog.RunningProcessesMode {
            groupId := rowData.IsApplication
                ? ApplicationSearchDialog.ApplicationGroupId
                : ApplicationSearchDialog.BackgroundProcessGroupId
            this.SetListViewItemGroup(row, groupId)
        }
        return row
    }

    ConfigureResultGroups() {
        if !this.lv
            return false
        try SendMessage(Win32.LVM_REMOVEALLGROUPS, 0, 0, this.lv.Hwnd)
        if this.mode != ApplicationSearchDialog.RunningProcessesMode {
            try SendMessage(Win32.LVM_ENABLEGROUPVIEW, 0, 0, this.lv.Hwnd)
            return true
        }
        SendMessage(Win32.LVM_ENABLEGROUPVIEW, 1, 0, this.lv.Hwnd)
        this.InsertListViewGroup(ApplicationSearchDialog.ApplicationGroupId,
            0, this.GetRunningProcessGroupHeader(
                ApplicationSearchDialog.ApplicationGroupId))
        this.InsertListViewGroup(
            ApplicationSearchDialog.BackgroundProcessGroupId, 1,
            this.GetRunningProcessGroupHeader(
                ApplicationSearchDialog.BackgroundProcessGroupId))
        return true
    }

    InsertListViewGroup(groupId, index, headerText) {
        group := this.CreateListViewGroup(groupId, headerText)
        return SendMessage(Win32.LVM_INSERTGROUP, index,
            group.Data.Ptr,
            this.lv.Hwnd) != -1
    }

    UpdateListViewGroupHeader(groupId) {
        if this.mode != ApplicationSearchDialog.RunningProcessesMode
            || !this.lv
            return false
        group := this.CreateListViewGroup(groupId,
            this.GetRunningProcessGroupHeader(groupId))
        return SendMessage(Win32.LVM_SETGROUPINFO, groupId,
            group.Data.Ptr,
            this.lv.Hwnd) != -1
    }

    CreateListViewGroup(groupId, headerText) {
        groupSize := A_PtrSize == 8 ? 152 : 96
        groupIdOffset := A_PtrSize == 8 ? 36 : 24
        group := Buffer(groupSize, 0)
        NumPut("UInt", group.Size, group, 0)
        NumPut("UInt", Win32.LVGF_HEADER | Win32.LVGF_GROUPID, group, 4)
        NumPut("Ptr", StrPtr(headerText), group, 8)
        NumPut("Int", StrLen(headerText), group, 8 + A_PtrSize)
        NumPut("Int", groupId, group, groupIdOffset)
        ; LVGROUP 只在 SendMessage 调用期间借用 pszHeader；结构体旁保留
        ; AHK 字符串，直到调用返回。
        return {Data: group, HeaderText: headerText}
    }

    SetListViewItemGroup(row, groupId) {
        groupIdOffset := A_PtrSize == 8 ? 52 : 40
        item := Buffer(groupIdOffset + 4, 0)
        NumPut("UInt", Win32.LVIF_GROUPID, item, 0)
        NumPut("Int", row - 1, item, 4)
        NumPut("Int", groupId, item, groupIdOffset)
        return SendMessage(Win32.LVM_SETITEMW, 0, item.Ptr,
            this.lv.Hwnd) != 0
    }

    GetRunningProcessGroupHeader(groupId) {
        count := this.runningProcessGroupCounts.Has(groupId)
            ? this.runningProcessGroupCounts[groupId] : 0
        label := groupId == ApplicationSearchDialog.ApplicationGroupId
            ? Tr("应用") : Tr("后台进程")
        return label " (" count ")"
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
            return App.iconResources.AcquireImageList(this.imageList,
                this.imageList)
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
    }

    ReleaseImageListUse(imageList) {
        if App.iconResources.ReleaseImageList(imageList) {
            ClearImageListIconCache(imageList)
            try IL_Destroy(imageList)
        }
    }

    RetireImageList(imageList) {
        if !imageList
            return
        if App.iconResources.RetireImageList(imageList, this.imageList) {
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
                tooltipText := Tr("名称：{1}`n真实路径：{2}",
                    this.lv.GetText(row, 1), this.lv.GetText(row, 2))
                if UiThemeService.IsDark()
                    this.tooltip.Show(tooltipText)
                else
                    this.tooltip.Schedule(tooltipText)
            }
        } else if (this.hoverRow != 0) {
            this.hoverRow := 0
            this.tooltip.Hide()
        }
    }

    SearchEverything(*) {
        if !this.IsOpen()
            return false
        this.CancelRunningProcessLoad()
        keyword := Trim(this.searchEdit.Value)
        if keyword == ""
            return this.ShowEmptySearchState()
        if !this.everythingLib
            return false
        sessionId := this.CancelEverythingResultLoad()
        if !InStr(keyword, "ext:") && !InStr(keyword, "\")
            && !InStr(keyword, ":") {
            keyword := "ext:exe;com;msc;ahk;py;pyw;js;vbs;vbe;wsf;ps1;bat;cmd;rb;pl;php;lua;jar;sh;bash;lnk;url;appref-ms " keyword
        }

        try {
            DllCall(this.everythingFunctions["Everything_SetSearchW"],
                "WStr", keyword)
            DllCall(this.everythingFunctions["Everything_SetSort"],
                "UInt", 14)
            ; Everything 的 0xFFFFFFFF 表示返回全部匹配项；应用层不再施加结果上限。
            DllCall(this.everythingFunctions["Everything_SetMax"],
                "UInt", 0xFFFFFFFF)
            if !DllCall(this.everythingFunctions["Everything_QueryW"],
                    "Int", 1) {
                this.SetEverythingStatus(this.BuildEverythingFailureText(
                    this.GetEverythingLastError()))
                return false
            }
            resultCount := DllCall(
                this.everythingFunctions["Everything_GetNumResults"],
                "UInt")
        } catch as queryError {
            LogMsg(Tr("更新应用搜索结果失败：{1}",
                TrDiagnostic(queryError.Message)))
            return false
        }

        previousCritical := A_IsCritical
        Critical("On")
        try {
            if !this.IsOpen() || sessionId != this.everythingSearchSessionId
                return false
            this.everythingResultCount := resultCount
            this.everythingResultIndex := 0
            this.resultRows := []
            this.lv.Opt("-Redraw")
            try this.lv.Delete()
            finally this.lv.Opt("+Redraw")
            this.RefreshListWidthIfChanged()
            this.everythingUnavailableLogged := false
            if resultCount {
                this.SetEverythingStatus(Tr(
                    "正在载入 Everything 搜索结果：{1}／{2}", 0,
                    resultCount))
                SetTimer(this.resultConsumeTimer, 15)
            } else {
                this.SetEverythingStatus(Tr(
                    "Everything 搜索结果：{1} 项", 0))
            }
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        return true
    }

    ConsumeEverythingResultBatch(*) {
        if !this.IsOpen() {
            this.Close()
            return
        }
        imageList := this.AcquireImageListUse()
        if !imageList
            return
        redrawSuspended := false
        previousCritical := A_IsCritical
        Critical("On")
        try {
            sessionId := this.everythingSearchSessionId
            batchEnd := Min(this.everythingResultCount,
                this.everythingResultIndex + 8)
            this.lv.Opt("-Redraw")
            redrawSuspended := true
            while this.everythingResultIndex < batchEnd {
                index := this.everythingResultIndex
                this.everythingResultIndex++
                namePtr := DllCall(this.everythingFunctions[
                    "Everything_GetResultFileNameW"], "UInt", index, "Ptr")
                pathPtr := DllCall(this.everythingFunctions[
                    "Everything_GetResultPathW"], "UInt", index, "Ptr")
                if (!namePtr || !pathPtr)
                    continue
                name := StrGet(namePtr, "UTF-16")
                path := StrGet(pathPtr, "UTF-16")
                fullPath := path == "" ? name : RTrim(path, "\") "\" name
                extension := ""
                SplitPath(name, , , &extension)
                iconIndex := GetFileIconIndex(fullPath, imageList)
                if sessionId == this.everythingSearchSessionId
                    && this.IsOpen() && this.imageList == imageList {
                    extension := StrLower(extension)
                    this.resultRows.Push({
                        Name: name,
                        FullPath: fullPath,
                        Extension: extension,
                        IconIndex: iconIndex
                    })
                    this.AddResultRow(this.resultRows[
                        this.resultRows.Length])
                }
            }
            if sessionId != this.everythingSearchSessionId
                return
            if this.everythingResultIndex >= this.everythingResultCount {
                SetTimer(this.resultConsumeTimer, 0)
                if IsObject(this.listHeader)
                    && this.listHeader.HasActiveSort()
                    this.listHeader.ApplyCurrentSort()
                this.SetEverythingStatus(Tr(
                    "Everything 搜索结果：{1} 项",
                    this.everythingResultCount))
            } else {
                this.SetEverythingStatus(Tr(
                    "正在载入 Everything 搜索结果：{1}／{2}",
                    this.everythingResultIndex, this.everythingResultCount)
                )
            }
        } catch as resultError {
            this.ShowEverythingUnavailable(resultError)
        } finally {
            if redrawSuspended
                try this.lv.Opt("+Redraw")
            if this.IsOpen()
                try this.RefreshListWidthIfChanged()
            Critical(previousCritical ? previousCritical : "Off")
            this.ReleaseImageListUse(imageList)
        }
    }

    OnSearchChanged(*) {
        SetTimer(this.searchTimer, 0)
        if !this.IsOpen()
            return
        if this.mode == ApplicationSearchDialog.RunningProcessesMode {
            if !this.runningProcessPreparationComplete
                return
            this.FilterRunningProcessRows()
            return
        }
        keyword := Trim(this.searchEdit.Value)
        ; 每次输入都立即作废旧 Everything 会话及其分批图标提取；只有输入
        ; 连续静止一个完整防抖周期后，才允许最新关键字发起一次查询。
        this.ResetSearchResults()
        if keyword == ""
            return
        SetTimer(this.searchTimer,
            -ApplicationSearchDialog.SearchDebounceMilliseconds)
    }

    RunDeferredSearch(*) {
        if !this.IsOpen() {
            this.Close()
            return
        }
        if this.mode == ApplicationSearchDialog.EverythingSearchMode
            this.RunEverythingSearch()
    }

    RunEverythingSearch() {
        if !this.IsOpen()
            return false
        if Trim(this.searchEdit.Value) == ""
            return this.ShowEmptySearchState()
        if !this.everythingLib && !this.LoadEverythingLibrary() {
            this.ShowEverythingComponentUnavailable()
            return false
        }
        if this.SearchEverything() {
            this.CancelEverythingStartup()
            return true
        }
        errorCode := this.GetEverythingLastError()
        if (errorCode == 0
            || errorCode == ApplicationSearchDialog.EverythingErrorIpc)
            return this.BeginEverythingStartup()
        this.ShowEverythingUnavailable(errorCode)
        return false
    }

    ShowEmptySearchState() {
        if !this.IsOpen()
            return false
        return this.ResetSearchResults()
    }

    ResetSearchResults(resetUnavailableLog := true) {
        if !this.IsOpen()
            return false
        this.CancelEverythingStartup()
        this.CancelEverythingResultLoad()
        this.CancelRunningProcessLoad()
        this.tooltip.Hide()
        this.hoverRow := 0
        if this.lv && this.lv.GetCount() {
            this.lv.Opt("-Redraw")
            try this.lv.Delete()
            finally this.lv.Opt("+Redraw")
        }
        this.resultRows := []
        ; 运行进程模式在路径准备完成前保持列表完全空白；候选总数确定后
        ; 再创建分组并进入图标/行渲染阶段。Everything 模式仍立即恢复其分组配置。
        if this.mode != ApplicationSearchDialog.RunningProcessesMode
            this.ConfigureResultGroups()
        this.RefreshListWidthIfChanged()
        this.SetEverythingStatus("")
        if resetUnavailableLog
            this.everythingUnavailableLogged := false
        return true
    }

    ShowRunningProcesses(*) {
        if !this.ownerDialog.IsOpen()
            return false
        this.mode := ApplicationSearchDialog.RunningProcessesMode
        if !this.ShowWindow()
            return false
        this.ApplyModeTitle()
        SetTimer(this.searchTimer, 0)
        try this.searchEdit.Value := ""
        return this.LoadRunningProcesses()
    }

    LoadRunningProcesses() {
        if !this.IsOpen()
            return false
        this.ResetSearchResults()
        sessionId := this.runningProcessSessionId
        try applicationPidMap :=
            App.processInspector.CaptureVisibleWindowTitleMap()
        catch
            applicationPidMap := Map()
        snapshot := App.processInspector.CaptureNativeSnapshot()
        if !snapshot.Ready {
            if sessionId == this.runningProcessSessionId && this.IsOpen() {
                this.SetEverythingStatus(Tr(
                    "无法读取正在运行的进程。"))
                LogMsg(Tr("无法读取正在运行的进程。") " "
                    TrDiagnostic(snapshot.Reason))
            }
            return false
        }
        if sessionId != this.runningProcessSessionId || !this.IsOpen()
            return false

        ; 原生快照包含无法查询镜像路径的受保护进程，也可能包含同一可执行文件
        ; 的多个 PID。先在独立的准备阶段完成路径解析和规范化去重；准备完成前
        ; 列表保持空白，避免把尚未稳定的半成品结果误显示给用户。
        this.runningProcessSource := snapshot.Processes
        this.runningProcessPreparationIndex := 0
        this.runningProcessPreparationSeen := Map()
        this.runningProcessPreparationSeen.CaseSense := "Off"
        this.runningProcessPreparationComplete := false
        this.runningProcesses := []
        this.runningProcessIndex := 0
        this.runningProcessRows := []
        this.runningProcessSeen := Map()
        this.runningProcessSeen.CaseSense := "Off"
        this.runningProcessApplicationPids := applicationPidMap
        this.ResetRunningProcessGroupCounts()
        processCount := this.runningProcessSource.Length
        if !processCount {
            this.SetEverythingStatus(Tr(
                "正在运行的程序：{1} 项", 0))
            return true
        }
        this.SetEverythingStatus(Tr(
            "正在读取运行进程：{1}", 0))
        SetTimer(this.runningProcessTimer, 15)
        return true
    }

    ConsumeRunningProcessPreparationBatch(*) {
        if !this.IsOpen()
            return false
        sessionId := this.runningProcessSessionId
        sourceCount := this.runningProcessSource.Length
        batchEnd := Min(sourceCount,
            this.runningProcessPreparationIndex + 12)
        try {
            while this.runningProcessPreparationIndex < batchEnd {
                this.runningProcessPreparationIndex++
                processInfo := this.runningProcessSource[
                    this.runningProcessPreparationIndex]
                fullPath := App.processInspector.GetImagePath(
                    processInfo.pid)
                canonicalPath := GetCanonicalPath(fullPath)
                if canonicalPath == ""
                    continue
                isApplication := this.runningProcessApplicationPids.Has(
                    processInfo.pid)
                if this.runningProcessPreparationSeen.Has(canonicalPath) {
                    existing := this.runningProcesses[
                        this.runningProcessPreparationSeen[canonicalPath]]
                    if isApplication && !existing.IsApplication
                        existing.IsApplication := true
                    continue
                }
                this.runningProcesses.Push({
                    PID: processInfo.pid,
                    Name: processInfo.name,
                    FullPath: fullPath,
                    CanonicalPath: canonicalPath,
                    IsApplication: isApplication
                })
                this.runningProcessPreparationSeen[canonicalPath] :=
                    this.runningProcesses.Length
            }
            if sessionId != this.runningProcessSessionId
                || !this.IsOpen()
                return false
            if this.runningProcessPreparationIndex < sourceCount {
                this.SetEverythingStatus(Tr(
                    "正在读取运行进程：{1}",
                    this.runningProcessPreparationIndex))
                return true
            }
            this.runningProcessPreparationComplete := true
            this.runningProcessSource := []
            this.runningProcessPreparationSeen := Map()
            this.runningProcessPreparationSeen.CaseSense := "Off"
            this.runningProcessIndex := 0
            this.runningProcessRows := []
            this.runningProcessSeen := Map()
            this.runningProcessSeen.CaseSense := "Off"
            this.ResetRunningProcessGroupCounts()
            this.ConfigureResultGroups()
            candidateCount := this.runningProcesses.Length
            if !candidateCount {
                SetTimer(this.runningProcessTimer, 0)
                this.SetEverythingStatus(Tr(
                    "正在运行的程序：{1} 项", 0))
                return true
            }
            ; 此时分母已经是路径可读且已去重的最终候选数；下一轮定时器
            ; 才开始提取图标和添加列表行，确保准备阶段始终不渲染列表。
            this.SetEverythingStatus(Tr(
                "正在载入运行进程：{1}／{2}", 0, candidateCount))
            return true
        } catch as preparationError {
            this.FailRunningProcessLoad(preparationError)
            return false
        }
    }

    ConsumeRunningProcessBatch(*) {
        if !this.IsOpen() {
            this.CancelRunningProcessLoad()
            return
        }
        if !this.runningProcessPreparationComplete {
            this.ConsumeRunningProcessPreparationBatch()
            return
        }
        imageList := this.AcquireImageListUse()
        if !imageList
            return
        redrawSuspended := false
        try {
            sessionId := this.runningProcessSessionId
            processCount := this.runningProcesses.Length
            batchEnd := Min(processCount, this.runningProcessIndex + 6)
            this.lv.Opt("-Redraw")
            redrawSuspended := true
            while this.runningProcessIndex < batchEnd {
                this.runningProcessIndex++
                processInfo := this.runningProcesses[
                    this.runningProcessIndex]
                fullPath := processInfo.FullPath
                canonicalPath := processInfo.CanonicalPath
                isApplication := processInfo.IsApplication
                SplitPath(fullPath, &fileName, , &extension)
                displayName := processInfo.Name != ""
                    ? processInfo.Name : fileName
                iconIndex := GetFileIconIndex(fullPath, imageList)
                if sessionId != this.runningProcessSessionId
                    || !this.IsOpen() || this.imageList != imageList
                    return
                extension := StrLower(extension)
                rowData := {
                    Name: displayName,
                    FullPath: fullPath,
                    Extension: extension,
                    IconIndex: iconIndex,
                    IsApplication: isApplication
                }
                this.runningProcessRows.Push(rowData)
                this.runningProcessSeen[canonicalPath] :=
                    this.runningProcessRows.Length
                if this.MatchesRunningProcessFilter(rowData) {
                    this.resultRows.Push(rowData)
                    this.AddResultRow(rowData)
                    groupId := isApplication
                        ? ApplicationSearchDialog.ApplicationGroupId
                        : ApplicationSearchDialog.BackgroundProcessGroupId
                    this.runningProcessGroupCounts[groupId]++
                }
            }
            if sessionId != this.runningProcessSessionId
                return
            this.UpdateListViewGroupHeader(
                ApplicationSearchDialog.ApplicationGroupId)
            this.UpdateListViewGroupHeader(
                ApplicationSearchDialog.BackgroundProcessGroupId)
            if this.runningProcessIndex >= processCount {
                SetTimer(this.runningProcessTimer, 0)
                this.FilterRunningProcessRows()
                if IsObject(this.listHeader)
                    && this.listHeader.HasActiveSort()
                    this.listHeader.ApplyCurrentSort()
            } else {
                this.SetEverythingStatus(Tr(
                    "正在载入运行进程：{1}／{2}",
                    this.runningProcessIndex, processCount))
            }
        } catch as resultError {
            this.FailRunningProcessLoad(resultError)
        } finally {
            if redrawSuspended
                try this.lv.Opt("+Redraw")
            if this.IsOpen()
                try this.RefreshListWidthIfChanged()
            this.ReleaseImageListUse(imageList)
        }
    }

    FilterRunningProcessRows(*) {
        if !this.IsOpen()
            return false
        selectedPath := ""
        selectedRow := this.lv.GetNext(0)
        if selectedRow
            selectedPath := this.lv.GetText(selectedRow, 2)
        applications := []
        backgroundProcesses := []
        for rowData in this.runningProcessRows {
            if !this.MatchesRunningProcessFilter(rowData)
                continue
            if rowData.IsApplication
                applications.Push(rowData)
            else
                backgroundProcesses.Push(rowData)
        }
        this.resultRows := []
        for rowData in applications
            this.resultRows.Push(rowData)
        for rowData in backgroundProcesses
            this.resultRows.Push(rowData)
        this.runningProcessGroupCounts[
            ApplicationSearchDialog.ApplicationGroupId] := applications.Length
        this.runningProcessGroupCounts[
            ApplicationSearchDialog.BackgroundProcessGroupId] :=
                backgroundProcesses.Length

        this.lv.Opt("-Redraw")
        try {
            this.lv.Delete()
            this.ConfigureResultGroups()
            for rowData in this.resultRows {
                row := this.AddResultRow(rowData)
                if selectedPath != "" && rowData.FullPath == selectedPath
                    this.lv.Modify(row, "Select Focus")
            }
            if IsObject(this.listHeader) && this.listHeader.HasActiveSort()
                this.listHeader.ApplyCurrentSort()
        } finally {
            this.lv.Opt("+Redraw")
        }
        this.SetEverythingStatus(Tr(
            "正在运行的程序：{1} 项", this.resultRows.Length))
        this.RefreshListWidthIfChanged()
        return true
    }

    MatchesRunningProcessFilter(rowData) {
        keyword := Trim(this.searchEdit.Value)
        return keyword == ""
            || InStr(rowData.Name, keyword, false)
            || InStr(rowData.FullPath, keyword, false)
            || InStr(rowData.Extension, keyword, false)
    }

    ResetRunningProcessGroupCounts() {
        this.runningProcessGroupCounts := Map(
            ApplicationSearchDialog.ApplicationGroupId, 0,
            ApplicationSearchDialog.BackgroundProcessGroupId, 0)
    }

    FailRunningProcessLoad(failure) {
        this.ResetSearchResults(false)
        this.SetEverythingStatus(Tr("无法读取正在运行的进程。"))
        failureText := failure is Error
            ? failure.Message : String(failure)
        LogMsg(Tr("无法读取正在运行的进程。") " "
            TrDiagnostic(failureText))
    }

    CancelRunningProcessLoad() {
        SetTimer(this.runningProcessTimer, 0)
        this.runningProcessSessionId++
        this.runningProcesses := []
        this.runningProcessSource := []
        this.runningProcessPreparationIndex := 0
        this.runningProcessPreparationSeen := Map()
        this.runningProcessPreparationSeen.CaseSense := "Off"
        this.runningProcessPreparationComplete := false
        this.runningProcessIndex := 0
        this.runningProcessRows := []
        this.runningProcessSeen := Map()
        this.runningProcessSeen.CaseSense := "Off"
        this.runningProcessApplicationPids := Map()
        this.ResetRunningProcessGroupCounts()
        return this.runningProcessSessionId
    }

    ShowEverythingUnavailable(failure := "") {
        this.ResetSearchResults(false)
        errorCode := failure is Integer ? failure : this.GetEverythingLastError()
        statusText := this.BuildEverythingFailureText(errorCode)
        this.SetEverythingStatus(statusText)
        if this.everythingUnavailableLogged
            return
        this.everythingUnavailableLogged := true
        diagnosticSuffix := ""
        if errorCode {
            errorText := this.DescribeEverythingError(errorCode)
            diagnosticSuffix := " [Everything=" errorCode " " errorText "]"
        }
        if failure is Error
            diagnosticSuffix .= " " TrDiagnostic(failure.Message)
        LogMsg(statusText diagnosticSuffix)
    }

    ShowEverythingComponentUnavailable() {
        this.ResetSearchResults(false)
        this.SetEverythingStatus(Tr(
            "Everything 搜索组件缺失或无法加载，请完整解压或重新安装小助手。"))
        if this.everythingUnavailableLogged
            return
        this.everythingUnavailableLogged := true
        LogMsg(Tr(
            "Everything 搜索组件缺失或无法加载，请完整解压或重新安装小助手。"))
    }

    BeginEverythingStartup() {
        this.ResetSearchResults(false)
        startResult := this.everythingRuntimeService.StartSilently()
        if !startResult.Found {
            this.ShowEverythingDownloadLink(startResult)
            return false
        }
        if !startResult.Started {
            this.SetEverythingStatus(Tr(
                "已找到 Everything 本体，但无法后台启动；请手动启动 Everything 后重试。"))
            if !this.everythingUnavailableLogged {
                this.everythingUnavailableLogged := true
                LogMsg(Tr("后台启动 Everything 失败：{1}（路径：{2}；发现过程：{3}）",
                    TrDiagnostic(startResult.Failure), startResult.Path,
                    startResult.DiscoverySummary))
            }
            return false
        }

        this.everythingStartupPath := startResult.Path
        this.everythingStartupDeadline := GetTickCount64()
            + ApplicationSearchDialog.StartupTimeoutMilliseconds
        this.SetEverythingStatus(Tr(
            "正在后台启动 Everything 本体并等待搜索服务就绪..."))
        SetTimer(this.everythingStartupTimer,
            ApplicationSearchDialog.StartupRetryMilliseconds)
        LogMsg(Tr("已在后台启动 Everything：{1}", startResult.Path))
        return true
    }

    RetryEverythingStartup(*) {
        if !this.IsOpen() || Trim(this.searchEdit.Value) == "" {
            this.CancelEverythingStartup()
            return
        }
        if this.SearchEverything() {
            this.CancelEverythingStartup()
            return
        }
        if GetTickCount64() < this.everythingStartupDeadline
            return
        startupPath := this.everythingStartupPath
        this.CancelEverythingStartup()
        this.SetEverythingStatus(Tr(
            "已启动 Everything，但后台搜索服务仍未响应；请确认 Everything 主程序完成启动且服务可用。"))
        LogMsg(Tr("等待 Everything 搜索服务就绪超时：{1}", startupPath))
    }

    CancelEverythingStartup() {
        try SetTimer(this.everythingStartupTimer, 0)
        this.everythingStartupDeadline := 0
        this.everythingStartupPath := ""
    }

    ShowEverythingDownloadLink(startResult := "") {
        this.ResetSearchResults(false)
        if this.resultStatusText
            this.resultStatusText.Visible := false
        if this.everythingDownloadLink {
            this.everythingDownloadLink.Text := Tr(
                "未找到 Everything 本体，点击前往官网下载最新版：{1}",
                EverythingRuntimeService.DownloadUrl)
            this.everythingDownloadLink.Visible := true
        }
        if !this.everythingUnavailableLogged {
            this.everythingUnavailableLogged := true
            discoverySummary := IsObject(startResult)
                && startResult.HasOwnProp("DiscoverySummary")
                ? startResult.DiscoverySummary : ""
            failureText := IsObject(startResult)
                && startResult.HasOwnProp("Failure")
                ? startResult.Failure : ""
            LogMsg(Tr(
                "本机未找到 Everything 本体；程序搜索需要 Everything 的索引和后台服务，随包 Everything64.dll 只是 IPC 客户端。{1}{2}",
                failureText != "" ? " " failureText : "",
                discoverySummary != "" ? " " discoverySummary : ""))
        }
    }

    SetEverythingStatus(text) {
        if this.everythingDownloadLink
            this.everythingDownloadLink.Visible := false
        if this.resultStatusText {
            this.resultStatusText.Visible := true
            this.resultStatusText.Text := text
        }
    }

    OpenEverythingDownloadPage(*) {
        try Run(EverythingRuntimeService.DownloadUrl)
    }

    GetEverythingLastError() {
        if !this.everythingLib
            return 0
        try return DllCall(
            this.everythingFunctions["Everything_GetLastError"], "UInt")
        catch
            return 0
    }

    BuildEverythingFailureText(errorCode) {
        if errorCode == ApplicationSearchDialog.EverythingErrorIpc {
            return Tr(
                "Everything64.dll 已加载，但 Everything 后台实例未响应；正在尝试定位并启动 Everything 本体。")
        }
        if errorCode {
            return Tr("Everything 查询失败：{1}",
                this.DescribeEverythingError(errorCode))
        }
        return Tr(
            "Everything 搜索暂时不可用：后台实例未返回结果，请稍后重试。")
    }

    DescribeEverythingError(errorCode) {
        switch Integer(errorCode) {
            case 1:
                return Tr("内存不足")
            case 2:
                return Tr("后台 IPC 服务不可用")
            case 3:
                return Tr("无法注册 Everything 查询窗口类")
            case 4:
                return Tr("无法创建 Everything 查询窗口")
            case 5:
                return Tr("无法创建 Everything 查询线程")
            case 6:
                return Tr("结果索引无效")
            case 7:
                return Tr("调用顺序无效")
            default:
                return Tr("未知错误码 {1}", errorCode)
        }
    }

    CancelEverythingResultLoad() {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            SetTimer(this.resultConsumeTimer, 0)
            this.everythingSearchSessionId++
            this.everythingResultCount := 0
            this.everythingResultIndex := 0
            return this.everythingSearchSessionId
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
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
        try SetTimer(this.searchTimer, 0)
        this.CancelEverythingStartup()
        this.CancelEverythingResultLoad()
        this.CancelRunningProcessLoad()
        if this.mouseHandlerRegistered {
            try OnMessage(Win32.WM_MOUSEMOVE, this.mouseHandler, 0)
            this.mouseHandlerRegistered := false
        }
        this.ClearIconCache()
        imageList := this.imageList
        this.imageList := 0
        this.tooltip.Hide()
        if this.searchLabelPresenter
            try this.searchLabelPresenter.Dispose()
        if this.listSelectionPresenter
            try this.listSelectionPresenter.Dispose()
        this.DestroyGui()
        this.RetireImageList(imageList)
        this.lv := ""
        this.listHeader := ""
        this.listSelectionPresenter := ""
        this.searchLabel := ""
        this.searchLabelPresenter := ""
        this.searchInputX := 95
        this.windowWidth := 700
        this.listContentWidth := 0
        this.searchEdit := ""
        this.searchEditBackground := ""
        this.resultStatusText := ""
        this.everythingDownloadLink := ""
        this.selectButton := ""
        this.resultRows := []
        this.runningProcesses := []
        this.runningProcessSource := []
        this.runningProcessPreparationIndex := 0
        this.runningProcessPreparationSeen := Map()
        this.runningProcessPreparationSeen.CaseSense := "Off"
        this.runningProcessPreparationComplete := false
        this.runningProcessIndex := 0
        this.hoverRow := 0
        this.everythingUnavailableLogged := false
    }

    Shutdown(*) {
        try this.Close()
        try this.tooltip.Close()
        if this.everythingLib {
            try DllCall("kernel32\FreeLibrary", "Ptr", this.everythingLib)
            this.everythingLib := 0
        }
        this.everythingFunctions := Map()
    }
}
