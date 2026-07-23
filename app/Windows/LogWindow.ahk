class LogWindow extends ManagedWindow {
    __New(mainGui) {
        this.mainOwner := mainGui
        this.owner := ""
        this.textEdit := ""
        this.exportButton := ""
        this.contentPixelWidth := 0
        this.contentPixelHeight := 0
        this.horizontalScrollbarVisible := false
        this.verticalScrollbarVisible := false
        this.refreshTimer := ObjBindMethod(this, "RefreshContent")
        this.renderedRevision := 0
    }

    Show(ownerGui := "", *) {
        if this.ShowExisting()
            return
        this.owner := ownerGui ? ownerGui : this.mainOwner
        if !this.CreateStandaloneGui("+Resize +MaximizeBox +MinSize420x280", "运行日志")
            return
        try {
        this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
        this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
        this.gui.OnEvent("Size", ObjBindMethod(this, "OnResize"))
        SetDarkTitleBar(this.gui.Hwnd)
        SetWindowIcon(this.gui.Hwnd, A_ScriptDir "\watchdog.ico")
        this.gui.BackColor := "1E1E1E"
        this.gui.SetFont("s10 cWhite", "Microsoft YaHei")
        this.textEdit := this.gui.Add("Edit", "x10 y10 w600 h260 ReadOnly Multi VScroll HScroll -Wrap Background252526 cWhite -E0x200", GetLogText())
        SetDarkControl(this.textEdit.Hwnd)
        RegisterTextInputControl(this.textEdit, true)
        this.textEdit.OnEvent("Focus", ObjBindMethod(this, "HideCaret"))
        this.renderedRevision := App.logRevision
        this.exportButton := this.gui.Add("Button", "x250 y280 w120 h30",
            "导出诊断包")
        RegisterButtonClick(this.exportButton,
            ObjBindMethod(this, "ExportDiagnostics"))
        SetHoverButtonColors(this.exportButton, "3A4656")
        SetButtonTextColor(this.exportButton, "FFFFFF")
        this.MeasureContent()
        DllCall("user32\ShowScrollBar", "Ptr", this.textEdit.Hwnd, "Int", Win32.SB_BOTH, "Int", 0)
        this.horizontalScrollbarVisible := false
        this.verticalScrollbarVisible := false
        this.gui.Show("w620 h320")
        this.UpdateScrollBars()
        SetTimer(this.refreshTimer, 500)
        } catch as openErr {
            this.Close()
            throw openErr
        }
    }

    OnResize(GuiObj, MinMax, Width, Height) {
        if (MinMax == -1 || !this.textEdit)
            return
        Width := Max(420, Width)
        Height := Max(240, Height)
        this.textEdit.Move(10, 10, Width - 20, Height - 60)
        if this.exportButton
            this.exportButton.Move((Width - 120) // 2, Height - 40, 120, 30)
        this.UpdateScrollBars()
        this.HideCaret()
    }

    MeasureContent() {
        if !this.textEdit
            return
        textEditHwnd := this.textEdit.Hwnd
        editDeviceContext := DllCall("user32\GetDC", "Ptr", textEditHwnd, "Ptr")
        if !editDeviceContext
            return
        editFont := SendMessage(Win32.WM_GETFONT, 0, 0, textEditHwnd)
        previousFont := editFont ? DllCall("gdi32\SelectObject", "Ptr", editDeviceContext, "Ptr", editFont, "Ptr") : 0
        try {
            textMetrics := Buffer(60, 0)
            if DllCall("gdi32\GetTextMetricsW", "Ptr", editDeviceContext, "Ptr", textMetrics, "Int")
                lineHeight := NumGet(textMetrics, 0, "Int") + NumGet(textMetrics, 16, "Int")
            else
                lineHeight := 16

            maximumLineWidth := 0
            for logLine in StrSplit(this.textEdit.Value, "`n", "`r") {
                if (logLine == "")
                    continue
                textExtent := Buffer(8, 0)
                if DllCall("gdi32\GetTextExtentPoint32W", "Ptr", editDeviceContext, "Str", logLine, "Int", StrLen(logLine), "Ptr", textExtent, "Int")
                    maximumLineWidth := Max(maximumLineWidth, NumGet(textExtent, 0, "Int"))
            }
            lineCount := SendMessage(Win32.EM_GETLINECOUNT, 0, 0, textEditHwnd)
            this.contentPixelWidth := maximumLineWidth
            this.contentPixelHeight := Max(1, lineCount) * Max(1, lineHeight)
        } finally {
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", editDeviceContext, "Ptr", previousFont, "Ptr")
            DllCall("user32\ReleaseDC", "Ptr", textEditHwnd, "Ptr", editDeviceContext)
        }
    }

    UpdateScrollBars(*) {
        if !this.textEdit
            return
        textEditHwnd := this.textEdit.Hwnd
        formattingRect := Buffer(16, 0)
        SendMessage(Win32.EM_GETRECT, 0, formattingRect.Ptr, textEditHwnd)
        availableWidth := NumGet(formattingRect, 8, "Int") - NumGet(formattingRect, 0, "Int")
        availableHeight := NumGet(formattingRect, 12, "Int") - NumGet(formattingRect, 4, "Int")
        if this.verticalScrollbarVisible
            availableWidth += SysGet(2) ; SM_CXVSCROLL
        if this.horizontalScrollbarVisible
            availableHeight += SysGet(3) ; SM_CYHSCROLL

        verticalBarWidth := SysGet(2)
        horizontalBarHeight := SysGet(3)
        needsVerticalScrollbar := this.contentPixelHeight > availableHeight
        needsHorizontalScrollbar := this.contentPixelWidth > availableWidth - (needsVerticalScrollbar ? verticalBarWidth : 0)
        if needsHorizontalScrollbar && !needsVerticalScrollbar
            needsVerticalScrollbar := this.contentPixelHeight > availableHeight - horizontalBarHeight
        if needsVerticalScrollbar && !needsHorizontalScrollbar
            needsHorizontalScrollbar := this.contentPixelWidth > availableWidth - verticalBarWidth

        if (needsHorizontalScrollbar != this.horizontalScrollbarVisible) {
            DllCall("user32\ShowScrollBar", "Ptr", textEditHwnd, "Int", Win32.SB_HORZ, "Int", needsHorizontalScrollbar)
            this.horizontalScrollbarVisible := needsHorizontalScrollbar
        }
        if (needsVerticalScrollbar != this.verticalScrollbarVisible) {
            DllCall("user32\ShowScrollBar", "Ptr", textEditHwnd, "Int", Win32.SB_VERT, "Int", needsVerticalScrollbar)
            this.verticalScrollbarVisible := needsVerticalScrollbar
        }
    }

    RefreshContent(*) {
        if !this.IsOpen() {
            this.Close()
            return
        }
        if !this.textEdit || this.renderedRevision == App.logRevision
            return
        try this.RefreshContentCore()
        catch as refreshErr {
            try SetTimer(this.refreshTimer, 0)
            LogMsg("刷新运行日志窗口失败，已暂停自动刷新: " refreshErr.Message)
        }
    }

    RefreshContentCore() {
        textEditHwnd := this.textEdit.Hwnd
        firstVisibleLine := SendMessage(Win32.EM_GETFIRSTVISIBLELINE, 0, 0, textEditHwnd)
        selectionStartBuffer := Buffer(4, 0)
        selectionEndBuffer := Buffer(4, 0)
        SendMessage(Win32.EM_GETSEL, selectionStartBuffer.Ptr, selectionEndBuffer.Ptr, textEditHwnd)
        selectionStart := NumGet(selectionStartBuffer, 0, "UInt")
        selectionEnd := NumGet(selectionEndBuffer, 0, "UInt")

        insertedEntries := Min(App.logMessages.Length,
            Max(0, App.logRevision - this.renderedRevision))
        insertedCharacters := 0
        Loop insertedEntries
            insertedCharacters += StrLen(App.logMessages[A_Index]) + 2
        this.textEdit.Value := GetLogText()
        if (insertedEntries > 0) {
            SendMessage(Win32.EM_SETSEL, selectionStart + insertedCharacters,
                selectionEnd + insertedCharacters, textEditHwnd)
            if (firstVisibleLine > 0)
                SendMessage(Win32.EM_LINESCROLL, 0, firstVisibleLine + insertedEntries, textEditHwnd)
        } else {
            SendMessage(Win32.EM_SETSEL, selectionStart, selectionEnd, textEditHwnd)
            if (firstVisibleLine > 0)
                SendMessage(Win32.EM_LINESCROLL, 0, firstVisibleLine, textEditHwnd)
        }
        this.renderedRevision := App.logRevision
        this.MeasureContent()
        this.UpdateScrollBars()
        this.HideCaret()
    }

    HideCaret(*) {
        if this.textEdit
            ScheduleHideTextCaret(this.textEdit.Hwnd)
    }

    ExportDiagnostics(*) {
        destinationDirectory := DirSelect(A_Desktop, 3,
            "选择诊断包保存位置")
        if destinationDirectory == ""
            return
        try {
            archivePath := App.diagnosticBundleService.Export(
                destinationDirectory)
            LogMsg("已导出本地诊断包: " archivePath)
            ShowDarkMsgBox("诊断包已导出到：`n" archivePath,
                "导出诊断包", "Info", this.gui)
        } catch as exportError {
            LogMsg("导出诊断包失败: " exportError.Message)
            ShowDarkMsgBox("无法导出诊断包：`n" exportError.Message,
                "导出诊断包", "Error", this.gui)
        }
    }

    Close(*) {
        try SetTimer(this.refreshTimer, 0)
        this.DestroyGui()
        this.textEdit := ""
        this.exportButton := ""
        this.owner := ""
        this.contentPixelWidth := 0
        this.contentPixelHeight := 0
        this.horizontalScrollbarVisible := false
        this.verticalScrollbarVisible := false
        this.renderedRevision := 0
    }
}
