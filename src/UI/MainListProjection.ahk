; 主列表路径身份到可变行号的投影索引。
; 隐藏的完整路径列是稳定身份，删除、插入和拖动后可重建索引；
; 序号仅用于展示，并通过原生列顺序保持名称列的图标与 F2 标签编辑能力。

class MainListProjection {
    __New(pathNormalizer := "") {
        this.PathNormalizer := pathNormalizer
        this.RowByPath := this.CreateIndex()
    }

    Find(listView, path) {
        key := this.Key(path)
        if key == "" || !IsObject(listView)
            return 0
        if this.RowByPath.Has(key) {
            row := this.RowByPath[key]
            try {
                if (row >= 1 && row <= listView.GetCount()
                    && this.Key(listView.GetText(row, 3)) == key)
                    return row
            }
        }
        this.Rebuild(listView)
        return this.RowByPath.Has(key) ? this.RowByPath[key] : 0
    }

    Remember(path, row) {
        key := this.Key(path)
        if key == "" || row < 1
            return false
        this.RowByPath[key] := row
        return true
    }

    Rebuild(listView) {
        nextIndex := this.CreateIndex()
        if IsObject(listView) {
            Loop listView.GetCount() {
                key := this.Key(listView.GetText(A_Index, 3))
                if key != "" && !nextIndex.Has(key)
                    nextIndex[key] := A_Index
            }
        }
        this.RowByPath := nextIndex
        return nextIndex.Count
    }

    Reset() {
        this.RowByPath := this.CreateIndex()
    }

    ApplyColumnOrder(listView) {
        if !IsObject(listView)
            || !DllCall("user32\IsWindow", "Ptr", listView.Hwnd, "Int")
            return false
        ; 序号是内部第 4 列，但显示在最左侧；第 5 列只保存状态语义排序键。
        ; 名称仍是原生标签列，保留图标和 F2 编辑。
        displayOrder := [3, 0, 1, 2, 4]
        orderBuffer := Buffer(displayOrder.Length * 4, 0)
        for orderPosition, columnIndex in displayOrder
            NumPut("Int", columnIndex, orderBuffer, (orderPosition - 1) * 4)
        return SendMessage(Win32.LVM_SETCOLUMNORDERARRAY,
            displayOrder.Length, orderBuffer.Ptr, listView.Hwnd) != 0
    }

    RefreshSequence(listView, startRow := 1) {
        if !IsObject(listView)
            return 0
        rowCount := listView.GetCount()
        try startRow := Max(1, Integer(startRow))
        catch
            return 0
        if (startRow > rowCount)
            return 0
        Loop rowCount - startRow + 1 {
            row := startRow + A_Index - 1
            listView.Modify(row, "Col4", String(row))
        }
        return rowCount - startRow + 1
    }

    RefreshSequenceFromOrder(listView, orderedPaths) {
        if !IsObject(listView) || Type(orderedPaths) != "Array"
            return 0
        sequenceByPath := this.CreateIndex()
        for sequence, path in orderedPaths {
            key := this.Key(path)
            if key != "" && !sequenceByPath.Has(key)
                sequenceByPath[key] := sequence
        }
        rowCount := listView.GetCount()
        Loop rowCount {
            key := this.Key(listView.GetText(A_Index, 3))
            sequence := sequenceByPath.Has(key)
                ? sequenceByPath[key] : A_Index
            listView.Modify(A_Index, "Col4", String(sequence))
        }
        return rowCount
    }

    Key(path) {
        normalizedPath := String(path)
        if this.PathNormalizer {
            try normalizedPath := this.PathNormalizer.Call(normalizedPath)
        }
        return StrLower(Trim(normalizedPath))
    }

    CreateIndex() {
        index := Map()
        index.CaseSense := "Off"
        return index
    }
}
