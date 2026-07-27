; 应用配置撤销与重做历史栈。
; 每条记录同时持有变更前后快照，只有应用成功才在两个栈之间移动；
; 失败时保留原记录供再次尝试，容量上限用于阻止长期运行时无界增长。

class AppConfigHistoryService {
    __New(snapshotService, maxEntries := 20) {
        this.SnapshotService := snapshotService
        this.MaxEntries := maxEntries > 0 ? Floor(maxEntries) : 20
        this.UndoEntries := []
        this.RedoEntries := []
        this.Busy := false
    }

    Commit(beforeState, afterState, action := "") {
        if this.Busy || Type(beforeState) != "Array"
            || Type(afterState) != "Array"
            return false
        this.Busy := true
        try {
            beforeItems := this.SnapshotService.PrepareState(beforeState).Items
            afterItems := this.SnapshotService.PrepareState(afterState).Items
            if this.SnapshotService.StatesEqual(beforeItems, afterItems)
                return false
            return this.PushEntry({
                Before: beforeItems,
                After: afterItems,
                ApplyCallback: "",
                Action: this.NormalizeAction(action)
            })
        } finally this.Busy := false
    }

    CommitCustom(beforeState, afterState, applyCallback, action := "") {
        if this.Busy || !IsObject(beforeState) || !IsObject(afterState)
            || !IsObject(applyCallback)
            return false
        this.Busy := true
        try {
            return this.PushEntry({
                Before: beforeState,
                After: afterState,
                ApplyCallback: applyCallback,
                Action: this.NormalizeAction(action)
            })
        } finally this.Busy := false
    }

    PushEntry(entry) {
        this.UndoEntries.Push(entry)
        if (this.UndoEntries.Length > this.MaxEntries)
            this.UndoEntries.RemoveAt(1)
        this.RedoEntries := []
        return true
    }

    NormalizeAction(action) {
        if IsObject(action) && action.HasOwnProp("Kind")
            return action
        return {Kind: "config", Paths: [], Fields: []}
    }

    Undo(applyCallback, &appliedEntry := "") {
        appliedEntry := ""
        if this.Busy || this.UndoEntries.Length == 0
            return false
        this.Busy := true
        try {
            entry := this.UndoEntries[this.UndoEntries.Length]
            transitionCallback := IsObject(entry.ApplyCallback)
                ? entry.ApplyCallback : applyCallback
            transitionCallback.Call(entry.Before, entry.After)
            this.UndoEntries.Pop()
            this.RedoEntries.Push(entry)
            appliedEntry := entry
            return true
        } finally this.Busy := false
    }

    Redo(applyCallback, &appliedEntry := "") {
        appliedEntry := ""
        if this.Busy || this.RedoEntries.Length == 0
            return false
        this.Busy := true
        try {
            entry := this.RedoEntries[this.RedoEntries.Length]
            transitionCallback := IsObject(entry.ApplyCallback)
                ? entry.ApplyCallback : applyCallback
            transitionCallback.Call(entry.After, entry.Before)
            this.RedoEntries.Pop()
            this.UndoEntries.Push(entry)
            appliedEntry := entry
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
