; 独立运行日志窗口。
; 日志采用增量刷新并保留用户当前选择，允许复制、调整大小和最大化，但不会显示文本光标；
; 该窗口不禁用主窗口，最小化或关闭日志也不会改变主窗口状态。

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
        this.initialLayoutTimer := ObjBindMethod(this,
            "CompleteInitialLayout")
        this.renderedRevision := 0
    }

    Show(ownerGui := "", *) {
        if this.ShowExisting()
            return
        this.owner := ownerGui ? ownerGui : this.mainOwner
        if !this.CreateStandaloneGui("+Resize +MaximizeBox +MinSize420x280",
            Tr("运行日志"))
            return
        try {
        this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
        this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
        this.gui.OnEvent("Size", ObjBindMethod(this, "OnResize"))
        InitializeApplicationWindow(this.gui)
        this.textEdit := this.gui.Add("Edit", "x10 y10 w600 h260 ReadOnly Multi VScroll HScroll -Wrap Background"
            UiThemeService.Color("Surface") " c" UiThemeService.Color("Text")
            " -E0x200", GetLogText())
        SetDarkControl(this.textEdit.Hwnd)
        RegisterTextInputControl(this.textEdit, true)
        this.textEdit.OnEvent("Focus", ObjBindMethod(this, "HideCaret"))
        this.renderedRevision := App.logRevision
        this.exportButton := this.gui.Add("Button", "x250 y280 w120 h30",
            Tr("导出诊断包"))
        RegisterHoverButton(this.exportButton, UiThemeService.Color("Toolbar"))
        SetButtonLucideIcon(this.exportButton, "package-open.svg", 14, 6)
        RegisterButtonClick(this.exportButton,
            ObjBindMethod(this, "ExportDiagnostics"))
        SetButtonTextColor(this.exportButton,
            UiThemeService.Color("ToolbarText"))
        DllCall("user32\ShowScrollBar", "Ptr", this.textEdit.Hwnd, "Int", Win32.SB_BOTH, "Int", 0)
        this.horizontalScrollbarVisible := false
        this.verticalScrollbarVisible := false
        ShowApplicationWindow(this.gui, "w620 h320")
        ; 先让窗口和日志正文进入屏幕，下一次消息循环再逐行测量滚动范围。
        SetTimer(this.initialLayoutTimer, -1)
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

    CompleteInitialLayout(*) {
        try SetTimer(this.initialLayoutTimer, 0)
        if !this.IsOpen() || !this.textEdit
            return false
        this.MeasureContent()
        this.UpdateScrollBars()
        return true
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
            availableWidth += SysGet(2) ; SM_CXVSCROLL：补回垂直滚动条占用的宽度。
        if this.horizontalScrollbarVisible
            availableHeight += SysGet(3) ; SM_CYHSCROLL：补回水平滚动条占用的高度。

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
            LogMsg(Tr("刷新运行日志窗口失败，已暂停自动刷新：{1}",
                TrDiagnostic(refreshErr.Message)))
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
        ownerHwnd := this.IsOpen() ? this.gui.Hwnd : 0
        destinationDirectory := SelectDirectoryWithModernDialog(ownerHwnd,
            A_Desktop, Tr("选择诊断包保存位置"))
        if destinationDirectory == ""
            return
        try {
            archivePath := App.diagnosticBundleService.Export(
                destinationDirectory)
            LogMsg(Tr("已导出本地诊断包：{1}", archivePath))
            ShowDarkMsgBox(Tr("诊断包已导出到：`n{1}", archivePath),
                Tr("导出诊断包"), "Info", this.gui)
        } catch as exportError {
            errorText := TrDiagnostic(exportError.Message)
            LogMsg(Tr("导出诊断包失败：{1}", errorText))
            ShowDarkMsgBox(Tr("无法导出诊断包：`n{1}", errorText),
                Tr("导出诊断包"), "Error", this.gui)
        }
    }

    Close(*) {
        try SetTimer(this.refreshTimer, 0)
        try SetTimer(this.initialLayoutTimer, 0)
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
