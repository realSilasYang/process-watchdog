; 守护项配置快照与差量合并服务。
; 快照只保存可持久化的业务字段，不复制控件和运行中任务；恢复时按目标路径合并
; 当前运行态，确保撤销旧操作不会抹掉随后学习到的升级特征或重新引入过期控制器。

class AppConfigSnapshotService {
    __New(maintenanceConfigCodec, displayConfigCodec, normalizePath,
        pathsEquivalent) {
        this.MaintenanceConfigCodec := maintenanceConfigCodec
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
                WorkDir: "",
                Args: "",
                ShortcutArgs: "",
                EnvVars: "",
                RuntimePath: "",
                RuntimeArgs: "",
                ResolvedTarget: "",
                ResolvedTargetManual: false,
                Maintenance: this.MaintenanceConfigCodec.CreateDefault(path),
                Display: this.DisplayConfigCodec.CreateDefault()
            }
        }

        resolvedTarget := stateObj.HasOwnProp("ResolvedTarget")
            ? this.NormalizePath.Call(stateObj.ResolvedTarget) : ""
        maintenanceConfig := stateObj.HasOwnProp("MaintenanceConfig")
            ? stateObj.MaintenanceConfig
            : this.MaintenanceConfigCodec.CreateDefault(path)
        displayConfig := stateObj.HasOwnProp("DisplayConfig")
            ? stateObj.DisplayConfig : ""
        return {
            Path: path,
            Enabled: !stateObj.HasOwnProp("Enabled") || stateObj.Enabled ? 1 : 0,
            RunAsAdmin: stateObj.HasOwnProp("RunAsAdmin")
                && stateObj.RunAsAdmin ? 1 : 0,
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
            Maintenance: this.MaintenanceConfigCodec.NormalizeSnapshot(
                maintenanceConfig, path, resolvedTarget),
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
        maintenanceConfig := item.HasOwnProp("Maintenance") ? item.Maintenance
            : this.MaintenanceConfigCodec.CreateDefault(path)
        displayConfig := item.HasOwnProp("Display") ? item.Display
            : this.DisplayConfigCodec.CreateDefault()
        return {
            Path: path,
            Enabled: !item.HasOwnProp("Enabled") || item.Enabled ? 1 : 0,
            RunAsAdmin: item.HasOwnProp("RunAsAdmin") && item.RunAsAdmin ? 1 : 0,
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
            Maintenance: this.MaintenanceConfigCodec.NormalizeSnapshot(
                maintenanceConfig, path, resolvedTarget),
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
            && this.MaintenanceConfigCodec.Equals(first.Maintenance,
                second.Maintenance)
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

    MergeMaintenanceTransition(currentConfig, sourceConfig, targetConfig,
        allowRootTransition := true) {
        merged := {
            Enabled: !!currentConfig.Enabled,
            InstallRoot: currentConfig.InstallRoot,
            RootIsCustom: !!currentConfig.RootIsCustom,
            DetectionSeconds: currentConfig.DetectionSeconds,
            StableSeconds: currentConfig.StableSeconds,
            MaxWaitSeconds: currentConfig.MaxWaitSeconds,
            LearnedActors: []
        }
        for actor in currentConfig.LearnedActors
            merged.LearnedActors.Push(actor)

        if (!!sourceConfig.Enabled != !!targetConfig.Enabled
            && !!currentConfig.Enabled == !!sourceConfig.Enabled)
            merged.Enabled := !!targetConfig.Enabled
        if (!!sourceConfig.RootIsCustom != !!targetConfig.RootIsCustom
            && !!currentConfig.RootIsCustom == !!sourceConfig.RootIsCustom)
            merged.RootIsCustom := !!targetConfig.RootIsCustom
        if (allowRootTransition
            && !this.PathsEquivalent.Call(sourceConfig.InstallRoot,
                targetConfig.InstallRoot)
            && this.PathsEquivalent.Call(currentConfig.InstallRoot,
                sourceConfig.InstallRoot))
            merged.InstallRoot := targetConfig.InstallRoot
        for propertyName in ["DetectionSeconds", "StableSeconds",
            "MaxWaitSeconds"] {
            if (sourceConfig.%propertyName% != targetConfig.%propertyName%
                && currentConfig.%propertyName% == sourceConfig.%propertyName%)
                merged.%propertyName% := targetConfig.%propertyName%
        }

        if !this.ActorArraysEqual(sourceConfig.LearnedActors,
            targetConfig.LearnedActors) {
            sourceActors := this.CreateActorSet(sourceConfig.LearnedActors)
            targetActors := this.CreateActorSet(targetConfig.LearnedActors)
            filteredActors := []
            for actor in merged.LearnedActors {
                if !(sourceActors.Has(actor) && !targetActors.Has(actor))
                    filteredActors.Push(actor)
            }
            merged.LearnedActors := filteredActors
            mergedActorSet := this.CreateActorSet(merged.LearnedActors)
            for actor in targetConfig.LearnedActors {
                if !sourceActors.Has(actor) && !mergedActorSet.Has(actor) {
                    merged.LearnedActors.Push(actor)
                    mergedActorSet[actor] := true
                }
            }
        }
        return merged
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
        return merged
    }

    ActorArraysEqual(firstActors, secondActors) {
        if (firstActors.Length != secondActors.Length)
            return false
        for index, actor in firstActors {
            if (StrLower(actor) != StrLower(secondActors[index]))
                return false
        }
        return true
    }

    CreateActorSet(actors) {
        actorSet := Map()
        actorSet.CaseSense := "Off"
        for actor in actors
            actorSet[actor] := true
        return actorSet
    }
}
