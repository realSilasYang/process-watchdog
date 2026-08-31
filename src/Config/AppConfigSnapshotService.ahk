; 守护对象配置快照与差量合并服务。
; 快照只保存可持久化的业务字段，不复制控件和运行中任务。

class AppConfigSnapshotService {
    __New(displayConfigCodec, normalizePath,
        pathsEquivalent) {
        this.DisplayConfigCodec := displayConfigCodec
        this.NormalizePath := normalizePath
        this.PathsEquivalent := pathsEquivalent
    }

    CreateSnapshot(path, stateObj := "") {
        path := this.NormalizePath.Call(path)
        if (path == "")
            return ""
        if !IsObject(stateObj) {
            return {
                Path: path,
                Enabled: 1,
                RunAsAdmin: 0,
                AskBeforeRestart: false,
                WorkDir: "",
                Args: "",
                ShortcutArgs: "",
                EnvVars: "",
                RuntimePath: "",
                RuntimeArgs: "",
                ResolvedTarget: "",
                ResolvedTargetManual: false,
                ContentHash: "",
                ContentSize: 0,
                Display: this.DisplayConfigCodec.CreateDefault()
            }
        }

        resolvedTarget := stateObj.HasOwnProp("ResolvedTarget")
            ? this.NormalizePath.Call(stateObj.ResolvedTarget) : ""
        displayConfig := stateObj.HasOwnProp("DisplayConfig")
            ? stateObj.DisplayConfig : ""
        return {
            Path: path,
            Enabled: !stateObj.HasOwnProp("Enabled") || stateObj.Enabled ? 1 : 0,
            RunAsAdmin: stateObj.HasOwnProp("RunAsAdmin")
                && stateObj.RunAsAdmin ? 1 : 0,
            AskBeforeRestart: stateObj.HasOwnProp("AskBeforeRestart")
                && stateObj.AskBeforeRestart ? 1 : 0,
            WorkDir: stateObj.HasOwnProp("WorkDir") ? stateObj.WorkDir : "",
            Args: stateObj.HasOwnProp("Args") ? stateObj.Args : "",
            ShortcutArgs: stateObj.HasOwnProp("ShortcutArgs")
                ? stateObj.ShortcutArgs : "",
            EnvVars: stateObj.HasOwnProp("EnvVars") ? stateObj.EnvVars : "",
            RuntimePath: stateObj.HasOwnProp("RuntimePath")
                ? stateObj.RuntimePath : "",
            RuntimeArgs: stateObj.HasOwnProp("RuntimeArgs")
                ? stateObj.RuntimeArgs : "",
            ResolvedTarget: resolvedTarget,
            ResolvedTargetManual: stateObj.HasOwnProp("ResolvedTargetManual")
                && stateObj.ResolvedTargetManual,
            ContentHash: stateObj.HasOwnProp("ContentHash")
                ? stateObj.ContentHash : "",
            ContentSize: stateObj.HasOwnProp("ContentSize")
                ? stateObj.ContentSize : 0,
            Display: this.DisplayConfigCodec.Clone(displayConfig)
        }
    }

    NormalizeSnapshot(item) {
        if !IsObject(item) || !item.HasOwnProp("Path")
            return ""
        path := this.NormalizePath.Call(item.Path)
        if (path == "")
            return ""
        resolvedTarget := item.HasOwnProp("ResolvedTarget")
            ? this.NormalizePath.Call(item.ResolvedTarget) : ""
        displayConfig := item.HasOwnProp("Display") ? item.Display
            : this.DisplayConfigCodec.CreateDefault()
        return {
            Path: path,
            Enabled: !item.HasOwnProp("Enabled") || item.Enabled ? 1 : 0,
            RunAsAdmin: item.HasOwnProp("RunAsAdmin") && item.RunAsAdmin ? 1 : 0,
            AskBeforeRestart: item.HasOwnProp("AskBeforeRestart")
                && item.AskBeforeRestart ? 1 : 0,
            WorkDir: item.HasOwnProp("WorkDir") ? item.WorkDir : "",
            Args: item.HasOwnProp("Args") ? item.Args : "",
            ShortcutArgs: item.HasOwnProp("ShortcutArgs")
                ? item.ShortcutArgs : "",
            EnvVars: item.HasOwnProp("EnvVars") ? item.EnvVars : "",
            RuntimePath: item.HasOwnProp("RuntimePath")
                ? item.RuntimePath : "",
            RuntimeArgs: item.HasOwnProp("RuntimeArgs")
                ? item.RuntimeArgs : "",
            ResolvedTarget: resolvedTarget,
            ResolvedTargetManual: item.HasOwnProp("ResolvedTargetManual")
                && item.ResolvedTargetManual,
            ContentHash: item.HasOwnProp("ContentHash")
                ? item.ContentHash : "",
            ContentSize: item.HasOwnProp("ContentSize")
                ? item.ContentSize : 0,
            Display: this.DisplayConfigCodec.Normalize(displayConfig)
        }
    }

    PrepareState(stateArray) {
        items := []
        index := Map()
        index.CaseSense := "Off"
        if (Type(stateArray) != "Array")
            return {Items: items, Index: index}
        for rawItem in stateArray {
            item := this.NormalizeSnapshot(rawItem)
            if !item || index.Has(item.Path)
                continue
            items.Push(item)
            index[item.Path] := item
        }
        return {Items: items, Index: index}
    }

    SnapshotsEqual(first, second) {
        if !IsObject(first) || !IsObject(second)
            return false
        return this.PathsEquivalent.Call(first.Path, second.Path)
            && !!first.Enabled == !!second.Enabled
            && !!first.RunAsAdmin == !!second.RunAsAdmin
            && !!first.AskBeforeRestart == !!second.AskBeforeRestart
            && first.WorkDir == second.WorkDir
            && first.Args == second.Args
            && first.ShortcutArgs == second.ShortcutArgs
            && first.EnvVars == second.EnvVars
            && this.PathsEquivalent.Call(first.RuntimePath,
                second.RuntimePath)
            && first.RuntimeArgs == second.RuntimeArgs
            && this.PathsEquivalent.Call(first.ResolvedTarget,
                second.ResolvedTarget)
            && !!first.ResolvedTargetManual == !!second.ResolvedTargetManual
            && this.DisplayConfigCodec.Equals(first.Display, second.Display)
    }

    StatesEqual(firstState, secondState) {
        first := this.PrepareState(firstState)
        second := this.PrepareState(secondState)
        if (first.Items.Length != second.Items.Length)
            return false
        for index, firstItem in first.Items {
            if !this.SnapshotsEqual(firstItem, second.Items[index])
                return false
        }
        return true
    }

    MergeTransitionOrder(currentState, sourceState, targetState) {
        current := this.PrepareState(currentState)
        source := this.PrepareState(sourceState)
        target := this.PrepareState(targetState)
        extrasBeforeAnchor := Map()
        extrasBeforeAnchor.CaseSense := "Off"
        trailingExtras := []

        for currentIndex, currentItem in current.Items {
            if target.Index.Has(currentItem.Path)
                || source.Index.Has(currentItem.Path)
                continue
            anchorPath := ""
            scanIndex := currentIndex + 1
            while (scanIndex <= current.Items.Length) {
                candidatePath := current.Items[scanIndex].Path
                if target.Index.Has(candidatePath) {
                    anchorPath := candidatePath
                    break
                }
                scanIndex++
            }
            if (anchorPath == "") {
                trailingExtras.Push(currentItem)
                continue
            }
            if !extrasBeforeAnchor.Has(anchorPath)
                extrasBeforeAnchor[anchorPath] := []
            extrasBeforeAnchor[anchorPath].Push(currentItem)
        }

        mergedItems := []
        for targetItem in target.Items {
            if extrasBeforeAnchor.Has(targetItem.Path) {
                for extraItem in extrasBeforeAnchor[targetItem.Path]
                    mergedItems.Push(extraItem)
            }
            mergedItems.Push(targetItem)
        }
        for extraItem in trailingExtras
            mergedItems.Push(extraItem)
        return mergedItems
    }

    MergeDisplayTransition(currentConfig, sourceConfig, targetConfig) {
        current := this.DisplayConfigCodec.Normalize(currentConfig)
        source := this.DisplayConfigCodec.Normalize(sourceConfig)
        target := this.DisplayConfigCodec.Normalize(targetConfig)
        merged := this.DisplayConfigCodec.Clone(current)
        if (source.Name != target.Name && current.Name == source.Name)
            merged.Name := target.Name
        if (!this.PathsEquivalent.Call(source.IconPath, target.IconPath)
            && this.PathsEquivalent.Call(current.IconPath, source.IconPath))
            merged.IconPath := target.IconPath
        if (source.SequenceColor != target.SequenceColor
            && current.SequenceColor == source.SequenceColor)
            merged.SequenceColor := target.SequenceColor
        return merged
    }

}
