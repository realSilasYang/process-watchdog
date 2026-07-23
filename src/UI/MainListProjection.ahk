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
