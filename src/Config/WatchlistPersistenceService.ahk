; 守护列表与升级、展示配置的持久化服务。
; 加载时保留 INI 中的守护对象顺序，损坏记录进入恢复区而不是静默丢弃；
; 保存时把启动、升级和展示配置作为一个一致快照提交，并原样保留仍无法解析的恢复记录。

class WatchlistPersistenceService {
    __New(repository, fieldCodec, maintenanceConfigCodec, displayConfigCodec,
        snapshotService) {
        this.Repository := repository
        this.FieldCodec := fieldCodec
        this.MaintenanceConfigCodec := maintenanceConfigCodec
        this.DisplayConfigCodec := displayConfigCodec
        this.SnapshotService := snapshotService
    }

    Load(registerCallback) {
        if !IsObject(registerCallback)
            throw TypeError("守护对象注册回调无效")
        result := {
            Warnings: [],
            RecoveryEntries: this.ReadRecoveryEntries(),
            RegisteredCount: 0
        }
        maintenanceValues := this.Repository.ReadSectionMap("Maintenance")
        displayValues := this.Repository.ReadSectionMap("Display")
        launchValues := this.Repository.ReadSectionMap("Launch")
        for appEntry in this.Repository.ReadSectionEntries("Apps") {
            recoveryEntry := this.CreateRecoveryEntry(appEntry,
                maintenanceValues, displayValues, launchValues)
            try {
                record := this.ParseRecord(appEntry, maintenanceValues,
                    displayValues, launchValues)
                if !registerCallback.Call(record)
                    throw this.CreateLoadError("Apps", "目标路径",
                        "与已加载守护对象重复，或目标格式无效")
                result.RegisteredCount++
            } catch as loadError {
                result.Warnings.Push(this.CreateLoadWarning(appEntry,
                    loadError))
                result.RecoveryEntries.Push(recoveryEntry)
            }
        }
        return result
    }

    Save(appOrder, appStates, recoveryEntries) {
        if Type(appOrder) != "Array" || !IsObject(appStates)
            throw TypeError("守护对象保存状态无效")
        if Type(recoveryEntries) != "Array"
            throw TypeError("恢复记录列表无效")
        orderedPaths := this.BuildOrderedPaths(appOrder, appStates)
        appEntries := []
        maintenanceEntries := []
        displayEntries := []
        launchEntries := []
        for index, savePath in orderedPaths {
            snapshot := this.SnapshotService.CreateSnapshot(savePath,
                appStates[savePath])
            if !snapshot
                throw Error("无法生成守护对象快照: " savePath)
            value := snapshot.Enabled "|" snapshot.RunAsAdmin "|"
                . snapshot.Path "|" this.FieldCodec.Encode(snapshot.WorkDir)
            value .= "|" this.FieldCodec.Encode(snapshot.Args)
            value .= "|" this.FieldCodec.Encode(snapshot.EnvVars)
            value .= "|" this.FieldCodec.Encode(snapshot.ResolvedTarget)
            value .= "|" (snapshot.ResolvedTargetManual ? 1 : 0)
            value .= "|" this.FieldCodec.Encode(snapshot.ShortcutArgs)
            appEntries.Push({Key: "App" index, Value: value})
            maintenanceEntries.Push({Key: "App" index,
                Value: this.MaintenanceConfigCodec.Serialize(
                    snapshot.Maintenance, snapshot.Path)})
            if !this.DisplayConfigCodec.IsDefault(snapshot.Display) {
                displayEntries.Push({Key: "App" index,
                    Value: this.DisplayConfigCodec.Serialize(snapshot.Display)})
            }
            if (snapshot.RuntimePath != "" || snapshot.RuntimeArgs != "") {
                launchEntries.Push({Key: "App" index,
                    Value: this.FieldCodec.Encode(snapshot.RuntimePath) "|"
                        . this.FieldCodec.Encode(snapshot.RuntimeArgs)})
            }
        }
        serializedRecovery := this.SerializeRecoveryEntries(recoveryEntries)
        this.Repository.ReplaceSections([
            {Name: "Apps", Entries: appEntries},
            {Name: "Maintenance", Entries: maintenanceEntries},
            {Name: "Display", Entries: displayEntries},
            {Name: "Launch", Entries: launchEntries},
            {Name: "Recovery", Entries: serializedRecovery}
        ])
        return {OrderedPaths: orderedPaths, SavedCount: appEntries.Length}
    }

    ParseRecord(appEntry, maintenanceValues, displayValues, launchValues) {
        if (appEntry.Value == "")
            throw this.CreateLoadError("Apps", "整条记录", "内容为空")
        parts := StrSplit(appEntry.Value, "|")
        if (parts.Length != 9)
            throw this.CreateLoadError("Apps", "整条记录",
                "字段数量应为 9，实际为 " parts.Length)
        enabled := this.ParseBooleanField(parts[1], "启用状态")
        runAsAdmin := this.ParseBooleanField(parts[2], "管理员运行状态")
        targetPath := Trim(parts[3])
        if (targetPath == "")
            throw this.CreateLoadError("Apps", "目标路径", "内容为空")
        resolvedTargetManual := this.ParseBooleanField(parts[8],
            "真实目标来源标记")

        workDir := this.DecodeField(parts[4], "工作目录")
        arguments := this.DecodeField(parts[5], "启动参数")
        environment := this.DecodeField(parts[6], "环境变量")
        resolvedTarget := this.DecodeField(parts[7], "快捷方式真实目标")
        shortcutArguments := this.DecodeField(parts[9], "快捷方式参数")
        maintenanceConfig := this.MaintenanceConfigCodec.CreateDefault(
            targetPath)
        if maintenanceValues.Has(appEntry.Key) {
            maintenanceValue := maintenanceValues[appEntry.Key]
            this.ValidateEncodedField(maintenanceValue, "升级保护配置", false,
                "Maintenance")
            try maintenanceConfig := this.MaintenanceConfigCodec.Deserialize(
                maintenanceValue, targetPath)
            catch as maintenanceError
                throw this.CreateLoadError("Maintenance", "升级保护配置",
                    this.NormalizeDiagnosticText(maintenanceError.Message,
                        "内容无法解析"))
        }
        displayConfig := this.DisplayConfigCodec.CreateDefault()
        if displayValues.Has(appEntry.Key) {
            displayValue := displayValues[appEntry.Key]
            displayParts := StrSplit(displayValue, "|")
            if (displayParts.Length != 2)
                throw this.CreateLoadError("Display", "整条展示配置",
                    "字段数量应为 2，实际为 " displayParts.Length)
            this.ValidateEncodedField(displayParts[1], "自定义名称", true,
                "Display")
            this.ValidateEncodedField(displayParts[2], "自定义图标", true,
                "Display")
            try displayConfig := this.DisplayConfigCodec.Deserialize(displayValue)
            catch as displayError
                throw this.CreateLoadError("Display", "展示配置",
                    this.NormalizeDiagnosticText(displayError.Message,
                        "内容无法解析"))
        }
        runtimePath := ""
        runtimeArguments := ""
        if launchValues.Has(appEntry.Key) {
            launchValue := launchValues[appEntry.Key]
            launchParts := StrSplit(launchValue, "|")
            if (launchParts.Length != 2)
                throw this.CreateLoadError("Launch", "整条启动配置",
                    "字段数量应为 2，实际为 " launchParts.Length)
            this.ValidateEncodedField(launchParts[1], "启动程序或解释器",
                true, "Launch")
            this.ValidateEncodedField(launchParts[2], "解释器参数",
                true, "Launch")
            runtimePath := this.FieldCodec.Decode(launchParts[1])
            runtimeArguments := this.FieldCodec.Decode(launchParts[2])
        }
        return {
            Key: appEntry.Key,
            Path: targetPath,
            Enabled: enabled,
            RunAsAdmin: runAsAdmin,
            WorkDir: workDir,
            Args: arguments,
            EnvVars: environment,
            RuntimePath: runtimePath,
            RuntimeArgs: runtimeArguments,
            Maintenance: maintenanceConfig,
            ResolvedTarget: resolvedTarget,
            ResolvedTargetManual: resolvedTargetManual,
            ShortcutArgs: shortcutArguments,
            Display: displayConfig
        }
    }

    ReadRecoveryEntries() {
        recoveryEntries := []
        for recoveryEntry in this.Repository.ReadSectionEntries("Recovery") {
            recoveryEntries.Push({SerializedValue: recoveryEntry.Value})
        }
        return recoveryEntries
    }

    CreateRecoveryEntry(appEntry, maintenanceValues, displayValues,
        launchValues) {
        return {
            Key: appEntry.Key,
            Value: appEntry.Value,
            Maintenance: maintenanceValues.Has(appEntry.Key)
                ? maintenanceValues[appEntry.Key] : "",
            Display: displayValues.Has(appEntry.Key)
                ? displayValues[appEntry.Key] : "",
            Launch: launchValues.Has(appEntry.Key)
                ? launchValues[appEntry.Key] : ""
        }
    }

    CreateLoadWarning(appEntry, loadError) {
        sectionName := loadError.HasOwnProp("SectionName")
            ? loadError.SectionName : "Apps"
        fieldName := loadError.HasOwnProp("FieldName")
            ? loadError.FieldName : "整条记录"
        reason := loadError.HasOwnProp("Reason")
            ? loadError.Reason
            : this.NormalizeDiagnosticText(loadError.Message, "未知解析错误")
        return {
            Key: appEntry.Key,
            Section: sectionName,
            Field: fieldName,
            Reason: reason,
            Target: this.ExtractTargetHint(appEntry.Value)
        }
    }

    CreateLoadError(sectionName, fieldName, reason) {
        normalizedReason := this.NormalizeDiagnosticText(reason,
            "未知解析错误")
        loadError := Error(fieldName "：" normalizedReason)
        loadError.SectionName := sectionName
        loadError.FieldName := fieldName
        loadError.Reason := normalizedReason
        return loadError
    }

    ExtractTargetHint(recordValue) {
        parts := StrSplit(String(recordValue), "|")
        if (parts.Length < 3)
            return ""
        return this.NormalizeDiagnosticText(parts[3], "")
    }

    NormalizeDiagnosticText(value, fallback) {
        text := Trim(StrReplace(StrReplace(String(value), "`r", " "),
            "`n", " "))
        while InStr(text, "  ")
            text := StrReplace(text, "  ", " ")
        if (text == "")
            return fallback
        return StrLen(text) <= 500 ? text : SubStr(text, 1, 497) "..."
    }

    SerializeRecoveryEntries(recoveryEntries) {
        serialized := []
        for index, recoveryEntry in recoveryEntries {
            if !IsObject(recoveryEntry)
                throw TypeError("恢复记录无效")
            if recoveryEntry.HasOwnProp("SerializedValue") {
                serialized.Push({Key: "Entry" index,
                    Value: recoveryEntry.SerializedValue})
                continue
            }
            for propertyName in ["Key", "Value", "Maintenance", "Display",
                "Launch"] {
                if !recoveryEntry.HasOwnProp(propertyName)
                    throw ValueError("恢复记录缺少字段: " propertyName)
            }
            recoveryValue := "Source="
                this.FieldCodec.Encode(recoveryEntry.Key)
            recoveryValue .= "`nApp="
                this.FieldCodec.Encode(recoveryEntry.Value)
            recoveryValue .= "`nMaintenance="
                this.FieldCodec.Encode(recoveryEntry.Maintenance)
            recoveryValue .= "`nDisplay="
                this.FieldCodec.Encode(recoveryEntry.Display)
            recoveryValue .= "`nLaunch="
                this.FieldCodec.Encode(recoveryEntry.Launch)
            serialized.Push({Key: "Entry" index,
                Value: this.FieldCodec.Encode(recoveryValue)})
        }
        return serialized
    }

    BuildOrderedPaths(appOrder, appStates) {
        orderedPaths := []
        seen := Map()
        seen.CaseSense := "Off"
        for path in appOrder {
            key := this.PathKey(path)
            if (key != "" && appStates.Has(path) && !seen.Has(key)) {
                orderedPaths.Push(path)
                seen[key] := true
            }
        }
        for path, _ in appStates {
            key := this.PathKey(path)
            if (key != "" && !seen.Has(key)) {
                orderedPaths.Push(path)
                seen[key] := true
            }
        }
        return orderedPaths
    }

    DecodeField(value, fieldName) {
        this.ValidateEncodedField(value, fieldName, true, "Apps")
        return this.FieldCodec.Decode(value)
    }

    ValidateEncodedField(value, fieldName, allowEmpty,
        sectionName := "Apps") {
        value := String(value)
        if (value == "") {
            if allowEmpty
                return true
            throw this.CreateLoadError(sectionName, fieldName, "内容为空")
        }
        if (SubStr(value, 1, 5) != "<HEX>")
            throw this.CreateLoadError(sectionName, fieldName,
                "不是当前 <HEX> 编码格式")
        decoded := this.FieldCodec.Decode(value)
        if (decoded == value)
            throw this.CreateLoadError(sectionName, fieldName, "编码损坏")
        return true
    }

    ParseBooleanField(value, fieldName) {
        value := Trim(String(value))
        if (value == "0")
            return false
        if (value == "1")
            return true
        throw this.CreateLoadError("Apps", fieldName, "值不是 0 或 1")
    }

    PathKey(path) {
        return StrLower(StrReplace(Trim(String(path)), "/", "\"))
    }
}
