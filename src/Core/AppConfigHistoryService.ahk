class AppConfigHistoryService {
    __New(snapshotService, maxEntries := 20) {
        this.SnapshotService := snapshotService
        this.MaxEntries := maxEntries > 0 ? Floor(maxEntries) : 20
        this.UndoEntries := []
        this.RedoEntries := []
        this.Busy := false
    }

    Commit(beforeState, afterState) {
        if this.Busy || Type(beforeState) != "Array"
            || Type(afterState) != "Array"
            return false
        this.Busy := true
        try {
            beforeItems := this.SnapshotService.PrepareState(beforeState).Items
            afterItems := this.SnapshotService.PrepareState(afterState).Items
            if this.SnapshotService.StatesEqual(beforeItems, afterItems)
                return false
            this.UndoEntries.Push({Before: beforeItems, After: afterItems})
            if (this.UndoEntries.Length > this.MaxEntries)
                this.UndoEntries.RemoveAt(1)
            this.RedoEntries := []
            return true
        } finally this.Busy := false
    }

    Undo(applyCallback) {
        if this.Busy || this.UndoEntries.Length == 0
            return false
        this.Busy := true
        try {
            entry := this.UndoEntries[this.UndoEntries.Length]
            applyCallback.Call(entry.Before, entry.After)
            this.UndoEntries.Pop()
            this.RedoEntries.Push(entry)
            return true
        } finally this.Busy := false
    }

    Redo(applyCallback) {
        if this.Busy || this.RedoEntries.Length == 0
            return false
        this.Busy := true
        try {
            entry := this.RedoEntries[this.RedoEntries.Length]
            applyCallback.Call(entry.After, entry.Before)
            this.RedoEntries.Pop()
            this.UndoEntries.Push(entry)
            return true
        } finally this.Busy := false
    }

    CanUndo() {
        return !this.Busy && this.UndoEntries.Length > 0
    }

    CanRedo() {
        return !this.Busy && this.RedoEntries.Length > 0
    }

    GetUndoCount() {
        return this.UndoEntries.Length
    }

    GetRedoCount() {
        return this.RedoEntries.Length
    }

    Clear() {
        if this.Busy
            return false
        this.UndoEntries := []
        this.RedoEntries := []
        return true
    }
}
