; 隐藏原生表头后的可点击伪表头。
; 排序直接委托给 ListView 的原生排序器，按升序、降序、稳定来源顺序循环；
; 只改变当前行投影，业务顺序及持久化仍由调用方持有。

class ListViewPseudoHeader {
    static DefaultHeight := 28
    static InputGuardSubclassId := 0x4C565048 ; "LVPH"：伪表头输入保护标识
    static InputGuardCallback := 0
    static PressedCellHwnd := 0

    static EnsureInputGuardCallback() {
        if this.InputGuardCallback
            return true
        try this.InputGuardCallback := CallbackCreate(
            ListViewPseudoHeaderCellProc, "", 6)
        catch
            this.InputGuardCallback := 0
        return this.InputGuardCallback != 0
    }

    static AttachInputGuard(cellHwnd, listHwnd) {
        if !cellHwnd || !listHwnd || !this.EnsureInputGuardCallback()
            return false
        return !!DllCall("comctl32\SetWindowSubclass", "Ptr", cellHwnd,
            "Ptr", this.InputGuardCallback, "UPtr", this.InputGuardSubclassId,
            "UPtr", listHwnd, "Int")
    }

    __New(guiObj, listView, columns, options := "") {
        if !guiObj || Type(guiObj) != "Gui"
            throw TypeError("伪表头所属 GUI 无效")
        if !IsObject(listView) || Type(columns) != "Array" || !columns.Length
            throw TypeError("伪表头缺少 ListView 或列定义")

        this.Gui := guiObj
        this.List := listView
        this.Columns := []
        this.Cells := []
        this.SortDisplayColumn := 0
        this.SortDescending := false
        this.OnBeforeSort := this.GetOption(options, "OnBeforeSort", "")
        this.OnSortChanged := this.GetOption(options, "OnSortChanged", "")
        try this.RestoreColumn := Max(0, Integer(this.GetOption(options,
            "RestoreColumn", 0)))
        catch
            throw ValueError("伪表头恢复顺序列无效")
        this.RestoreSortOptions := Trim(String(this.GetOption(options,
            "RestoreSortOptions", "Integer")))
        this.CursorRegistrar := this.GetOption(options, "CursorRegistrar", "")
        this.BackgroundColor := this.GetOption(options, "BackgroundColor", "333333")
        this.TextColor := this.GetOption(options, "TextColor", "B8BAB9")
        this.FontName := this.GetOption(options, "FontName", "Microsoft YaHei UI")
        this.FontSize := this.GetOption(options, "FontSize", 9)
        this.Height := Max(1, Integer(this.GetOption(options, "Height",
            ListViewPseudoHeader.DefaultHeight)))

        this.Background := guiObj.Add("Text", "x0 y0 w1 h" this.Height
            " Background" this.BackgroundColor)
        for displayColumn, columnSpec in columns {
            if !IsObject(columnSpec) || !columnSpec.HasOwnProp("Column")
                throw TypeError("伪表头列定义无效")
            columnIndex := Integer(columnSpec.Column)
            if columnIndex < 1
                throw ValueError("伪表头列索引无效")
            alignment := columnSpec.HasOwnProp("Align")
                ? String(columnSpec.Align) : "Left"
            headerAlignment := columnSpec.HasOwnProp("HeaderAlign")
                ? String(columnSpec.HeaderAlign) : "Center"
            padding := columnSpec.HasOwnProp("Padding")
                ? String(columnSpec.Padding) : ""
            sortOptions := columnSpec.HasOwnProp("SortOptions")
                ? Trim(String(columnSpec.SortOptions)) : ""
            skipAscending := columnSpec.HasOwnProp("SkipAscending")
                && !!columnSpec.SkipAscending
            this.Columns.Push({
                Column: columnIndex,
                Label: columnSpec.HasOwnProp("Label")
                    ? String(columnSpec.Label) : "",
                Align: alignment,
                HeaderAlign: headerAlignment,
                Padding: padding,
                SortOptions: sortOptions,
                SkipAscending: skipAscending
            })
            alignOption := StrLower(headerAlignment) == "center" ? " Center"
                : (StrLower(headerAlignment) == "right" ? " Right" : "")
            cell := guiObj.Add("Text", "x0 y0 w1 h" this.Height
                " -Tabstop"
                " 0x200" alignOption " Background" this.BackgroundColor
                " c" this.TextColor, "")
            if !ListViewPseudoHeader.AttachInputGuard(cell.Hwnd, listView.Hwnd)
                throw Error("伪表头输入保护安装失败")
            sortCallback := ObjBindMethod(this, "SortByDisplayColumn",
                displayColumn)
            cell.OnEvent("Click", sortCallback)
            ; Windows 会把间隔较短的第二次完整单击报告为 DoubleClick，而不是
            ; 第二个 Click。两类通知都推进一次，快速连续点击才不会漏掉一态。
            cell.OnEvent("DoubleClick", sortCallback)
            if IsObject(this.CursorRegistrar)
                this.CursorRegistrar.Call(cell)
            this.Cells.Push(cell)
        }
        this.ApplyAppearance(this.BackgroundColor, this.TextColor,
            this.FontName, this.FontSize)
        this.RefreshLabels()
    }

    GetOption(options, name, defaultValue) {
        return IsObject(options) && options.HasOwnProp(name)
            ? options.%name% : defaultValue
    }

    SetBounds(x, y, columnWidths, totalWidth := "") {
        if Type(columnWidths) != "Array"
            || columnWidths.Length != this.Cells.Length
            return false
        widths := []
        summedWidth := 0
        for width in columnWidths {
            try width := Max(0, Integer(width))
            catch
                return false
            widths.Push(width)
            summedWidth += width
        }
        if totalWidth == ""
            totalWidth := summedWidth
        try totalWidth := Max(summedWidth, Integer(totalWidth))
        catch
            return false

        entries := [{Control: this.Background, X: x, Y: y,
            Width: totalWidth, Height: this.Height}]
        cellX := x
        for displayColumn, cell in this.Cells {
            entries.Push({Control: cell, X: cellX, Y: y,
                Width: widths[displayColumn], Height: this.Height})
            cellX += widths[displayColumn]
        }
        result := AtomicControlLayout.Apply(this.Gui, entries, {
            ParentColor: this.Gui.BackColor
        })
        return result.Status == AtomicControlLayout.Applied
            || result.Status == AtomicControlLayout.Unchanged
    }

    SetLabels(labels) {
        if Type(labels) != "Array" || labels.Length != this.Columns.Length
            return false
        for displayColumn, label in labels
            this.Columns[displayColumn].Label := String(label)
        this.RefreshLabels()
        return true
    }

    ApplyAppearance(backgroundColor, textColor, fontName := "",
        fontSize := "") {
        this.BackgroundColor := String(backgroundColor)
        this.TextColor := String(textColor)
        if fontName != ""
            this.FontName := String(fontName)
        if fontSize != ""
            this.FontSize := fontSize
        this.Background.Opt("Background" this.BackgroundColor)
        this.Background.Redraw()
        for cell in this.Cells {
            cell.Opt("Background" this.BackgroundColor)
            cell.SetFont("s" this.FontSize " bold c" this.TextColor,
                this.FontName)
            cell.Redraw()
        }
    }

    SortByDisplayColumn(displayColumn, *) {
        if displayColumn < 1 || displayColumn > this.Columns.Length
            return false
        previousDisplayColumn := this.SortDisplayColumn
        if previousDisplayColumn == displayColumn {
            if this.SortDescending
                return this.RestoreOrder()
            this.SortDescending := true
            column := this.Columns[displayColumn].Column
            this.List.ModifyCol(column, "NoSort")
        } else {
            if previousDisplayColumn {
                previousColumn := this.Columns[previousDisplayColumn].Column
                try this.List.ModifyCol(previousColumn, "NoSort")
            }
            this.SortDisplayColumn := displayColumn
            this.SortDescending := this.Columns[displayColumn].SkipAscending
        }
        this.NotifyBeforeSort()
        if !this.ApplyCurrentSort()
            return false
        this.RefreshLabels()
        column := this.Columns[this.SortDisplayColumn].Column
        this.NotifySortChanged(column, this.SortDescending)
        return true
    }

    NotifyBeforeSort() {
        if !this.HasActiveSort() || !IsObject(this.OnBeforeSort)
            return
        column := this.Columns[this.SortDisplayColumn].Column
        this.OnBeforeSort.Call(this, column, this.SortDescending)
    }

    ApplyCurrentSort() {
        if !this.HasActiveSort()
            return false
        columnSpec := this.Columns[this.SortDisplayColumn]
        direction := this.SortDescending ? "SortDesc" : "Sort"
        ; Integer 会默认把原生数据列改为右对齐；每次排序都重申数据列定义的
        ; 对齐方式。表头拥有独立 HeaderAlign，排序不会把数据对齐改成表头对齐。
        options := Trim(columnSpec.SortOptions " " columnSpec.Align
            " " direction)
        this.List.ModifyCol(columnSpec.Column, options)
        return true
    }

    ClearSort() {
        if this.HasActiveSort() {
            column := this.Columns[this.SortDisplayColumn].Column
            try this.List.ModifyCol(column, "NoSort")
        }
        this.SortDisplayColumn := 0
        this.SortDescending := false
        this.RefreshLabels()
    }

    RestoreOrder() {
        previousDisplayColumn := this.SortDisplayColumn
        previousDescending := this.SortDescending
        this.ClearSort()
        if this.RestoreColumn {
            try {
                options := Trim(this.RestoreSortOptions " Sort")
                this.List.ModifyCol(this.RestoreColumn, options)
                this.List.ModifyCol(this.RestoreColumn, "NoSort")
            } catch {
                this.SortDisplayColumn := previousDisplayColumn
                this.SortDescending := previousDescending
                try this.ApplyCurrentSort()
                this.RefreshLabels()
                return false
            }
        }
        this.NotifySortChanged(0, false)
        return true
    }

    NotifySortChanged(column, descending) {
        if IsObject(this.OnSortChanged)
            this.OnSortChanged.Call(this, column, descending)
    }

    HasActiveSort() {
        return this.SortDisplayColumn >= 1
            && this.SortDisplayColumn <= this.Columns.Length
    }

    GetSortColumn() {
        return this.HasActiveSort()
            ? this.Columns[this.SortDisplayColumn].Column : 0
    }

    RefreshLabels() {
        for displayColumn, cell in this.Cells {
            columnSpec := this.Columns[displayColumn]
            indicator := displayColumn == this.SortDisplayColumn
                ? (this.SortDescending ? " ↓" : " ↑") : ""
            this.SetCellTextNoErase(cell,
                columnSpec.Padding columnSpec.Label indicator)
        }
    }

    SetCellTextNoErase(cell, text) {
        text := String(text)
        if cell.Text == text
            return false
        ; WM_SETTEXT 本身可能先擦除旧背景再绘制新文字。先暂停该单元格
        ; 的绘制，更新完成后只做一次不擦除背景的同步重绘，快速点击时
        ; 不会在旧、新排序箭头之间露出父窗口背景。
        DllCall("user32\SendMessageW", "Ptr", cell.Hwnd,
            "UInt", 0x000B, "UPtr", 0, "Ptr", 0, "Ptr") ; WM_SETREDRAW：暂停单元格重绘
        try cell.Text := text
        finally DllCall("user32\SendMessageW", "Ptr", cell.Hwnd,
            "UInt", 0x000B, "UPtr", 1, "Ptr", 0, "Ptr")
        DllCall("user32\RedrawWindow", "Ptr", cell.Hwnd,
            "Ptr", 0, "Ptr", 0, "UInt", 0x0121, "Int")
        return true
    }
}

ListViewPseudoHeaderCellProc(hWnd, message, wParam, lParam, subclassId,
    listHwnd) {
    try {
        switch message {
            case 0x0007: ; WM_SETFOCUS：阻止伪表头取得输入焦点
                if listHwnd && DllCall("user32\IsWindow", "Ptr", listHwnd,
                        "Int")
                    DllCall("user32\SetFocus", "Ptr", listHwnd, "Ptr")
                return 0
            case 0x0201, 0x0203: ; WM_LBUTTONDOWN / WM_LBUTTONDBLCLK：按下或双击
                ; Static 默认过程会在双击时把控件文字写入剪贴板。伪表头
                ; 自己接管每次按下/抬起，既彻底绕开复制路径，也让快速的
                ; 第二次单击和普通单击一样只推进一个排序状态。
                if listHwnd && DllCall("user32\IsWindow", "Ptr", listHwnd,
                        "Int")
                    DllCall("user32\SetFocus", "Ptr", listHwnd, "Ptr")
                ListViewPseudoHeader.PressedCellHwnd := hWnd
                DllCall("user32\SetCapture", "Ptr", hWnd, "Ptr")
                return 0
            case 0x0202: ; WM_LBUTTONUP：左键抬起后提交排序
                if ListViewPseudoHeader.PressedCellHwnd != hWnd
                    return 0
                ListViewPseudoHeader.PressedCellHwnd := 0
                if DllCall("user32\GetCapture", "Ptr") == hWnd
                    DllCall("user32\ReleaseCapture", "Int")
                clientRect := Buffer(16, 0)
                if !DllCall("user32\GetClientRect", "Ptr", hWnd,
                        "Ptr", clientRect, "Int")
                    return 0
                x := lParam & 0xFFFF
                y := (lParam >> 16) & 0xFFFF
                if x & 0x8000
                    x -= 0x10000
                if y & 0x8000
                    y -= 0x10000
                if x < 0 || y < 0
                    || x >= NumGet(clientRect, 8, "Int")
                    || y >= NumGet(clientRect, 12, "Int")
                    return 0
                parentHwnd := DllCall("user32\GetParent", "Ptr", hWnd,
                    "Ptr")
                controlId := DllCall("user32\GetDlgCtrlID", "Ptr", hWnd,
                    "Int")
                if parentHwnd
                    DllCall("user32\SendMessageW", "Ptr", parentHwnd,
                        "UInt", 0x0111, "UPtr", controlId & 0xFFFF,
                        "Ptr", hWnd, "Ptr") ; WM_COMMAND / STN_CLICKED：发送静态控件点击
                return 0
            case 0x001F: ; WM_CANCELMODE：系统取消当前按压交互
                if ListViewPseudoHeader.PressedCellHwnd == hWnd {
                    ListViewPseudoHeader.PressedCellHwnd := 0
                    if DllCall("user32\GetCapture", "Ptr") == hWnd
                        DllCall("user32\ReleaseCapture", "Int")
                }
                return 0
            case 0x0215: ; WM_CAPTURECHANGED：鼠标捕获已经转移
                if ListViewPseudoHeader.PressedCellHwnd == hWnd
                    ListViewPseudoHeader.PressedCellHwnd := 0
            case 0x007B: ; WM_CONTEXTMENU：伪表头不提供右键菜单
                return 0
            case 0x0301: ; WM_COPY：禁止复制表头文字
                return 0
            case 0x0082: ; WM_NCDESTROY：窗口销毁前清理子类状态
                if ListViewPseudoHeader.PressedCellHwnd == hWnd
                    ListViewPseudoHeader.PressedCellHwnd := 0
                if ListViewPseudoHeader.InputGuardCallback
                    DllCall("comctl32\RemoveWindowSubclass", "Ptr", hWnd,
                        "Ptr", ListViewPseudoHeader.InputGuardCallback,
                        "UPtr", subclassId, "Int")
        }
    } catch {
        ; 原生子类回调不得把 AHK 异常越过窗口过程边界。
    }
    return DllCall("comctl32\DefSubclassProc", "Ptr", hWnd,
        "UInt", message, "UPtr", wParam, "Ptr", lParam, "Ptr")
}
