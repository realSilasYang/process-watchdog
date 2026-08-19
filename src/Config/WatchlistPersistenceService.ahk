; 守护列表、展示和启动配置的持久化服务。
; 加载时保留 INI 中的守护对象顺序，损坏记录进入恢复区而不是静默丢弃；
; 保存时把启动、展示和身份配置作为一个一致快照提交，并原样保留仍无法解析的恢复记录。

class WatchlistPersistenceService {
    __New(repository, fieldCodec, displayConfigCodec,
        snapshotService) {
        this.Repository := repository
        this.FieldCodec := fieldCodec
        this.DisplayConfigCodec := displayConfigCodec
        this.SnapshotService := snapshotService
    }

    Load(registerCallback) {
        if !IsObject(registerCallback)
            throw TypeError("守护对象注册回调无效")
        result := {
            Warnings: [],
            RecoveryEntries: this.ReadRecoveryEntries(),
            RegisteredCount: 0,
            NeedsIdentitySave: false
        }
        displayValues := this.Repository.ReadSectionMap("Display")
        launchValues := this.Repository.ReadSectionMap("Launch")
        identityValues := this.Repository.ReadSectionMap("Identity")
        for appEntry in this.Repository.ReadSectionEntries("Apps") {
            recoveryEntry := this.CreateRecoveryEntry(appEntry,
                displayValues, launchValues,
                identityValues)
            try {
                record := this.ParseRecord(appEntry, displayValues,
                    launchValues, identityValues)
                if !registerCallback.Call(record)
                    throw this.CreateLoadError("Apps", "目标路径",
                        "与已加载守护对象重复，或目标格式无效")
                result.RegisteredCount++
                if record.ContentHash == ""
                    result.NeedsIdentitySave := true
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
        displayEntries := []
        launchEntries := []
        identityEntries := []
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
            value .= "|" (snapshot.AskBeforeRestart ? 1 : 0)
            appEntries.Push({Key: "App" index, Value: value})
            if !this.DisplayConfigCodec.IsDefault(snapshot.Display) {
                displayEntries.Push({Key: "App" index,
                    Value: this.DisplayConfigCodec.Serialize(snapshot.Display)})
            }
            if (snapshot.RuntimePath != "" || snapshot.RuntimeArgs != "") {
                launchEntries.Push({Key: "App" index,
                    Value: this.FieldCodec.Encode(snapshot.RuntimePath) "|"
                        . this.FieldCodec.Encode(snapshot.RuntimeArgs)})
            }
            if snapshot.HasOwnProp("ContentHash")
                && RegExMatch(snapshot.ContentHash, "i)^[0-9a-f]{64}$")
                && snapshot.HasOwnProp("ContentSize")
                && snapshot.ContentSize >= 0 {
                identityEntries.Push({Key: "App" index,
                    Value: snapshot.ContentSize "|"
                        . StrUpper(snapshot.ContentHash)})
            }
        }
        serializedRecovery := this.SerializeRecoveryEntries(recoveryEntries)
        this.Repository.ReplaceSections([
            {Name: "Apps", Entries: appEntries},
            {Name: "Display", Entries: displayEntries},
            {Name: "Launch", Entries: launchEntries},
            {Name: "Identity", Entries: identityEntries},
            {Name: "Recovery", Entries: serializedRecovery}
        ])
        return {OrderedPaths: orderedPaths, SavedCount: appEntries.Length}
    }

    ParseRecord(appEntry, displayValues, launchValues,
        identityValues) {
        if (appEntry.Value == "")
            throw this.CreateLoadError("Apps", "整条记录", "内容为空")
        parts := StrSplit(appEntry.Value, "|")
        if (parts.Length != 9 && parts.Length != 10)
            throw this.CreateLoadError("Apps", "整条记录",
                "字段数量应为 9 或 10，实际为 " parts.Length)
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
        askBeforeRestart := parts.Length >= 10
            ? this.ParseBooleanField(parts[10], "停止后询问恢复") : false
        displayConfig := this.DisplayConfigCodec.CreateDefault()
        if displayValues.Has(appEntry.Key) {
            displayValue := displayValues[appEntry.Key]
            displayParts := StrSplit(displayValue, "|")
            if (displayParts.Length != 2 && displayParts.Length != 3)
                throw this.CreateLoadError("Display", "整条展示配置",
                    "字段数量应为 2 或 3，实际为 " displayParts.Length)
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
        contentHash := ""
        contentSize := 0
        if identityValues.Has(appEntry.Key) {
            identityValue := identityValues[appEntry.Key]
            identityParts := StrSplit(identityValue, "|")
            if identityParts.Length != 2
                throw this.CreateLoadError("Identity", "内容身份",
                    "字段数量应为 2，实际为 " identityParts.Length)
            try contentSize := Integer(identityParts[1])
            catch
                throw this.CreateLoadError("Identity", "文件大小",
                    "内容不是整数")
            contentHash := StrUpper(Trim(identityParts[2]))
            if contentSize < 0
                throw this.CreateLoadError("Identity", "文件大小",
                    "不能小于 0")
            if !RegExMatch(contentHash, "^[0-9A-F]{64}$")
                throw this.CreateLoadError("Identity", "内容哈希",
                    "必须是 64 位十六进制 SHA-256")
        }
        return {
            Key: appEntry.Key,
            Path: targetPath,
            Enabled: enabled,
            RunAsAdmin: runAsAdmin,
            AskBeforeRestart: askBeforeRestart,
            WorkDir: workDir,
            Args: arguments,
            EnvVars: environment,
            RuntimePath: runtimePath,
            RuntimeArgs: runtimeArguments,
            ResolvedTarget: resolvedTarget,
            ResolvedTargetManual: resolvedTargetManual,
            ShortcutArgs: shortcutArguments,
            ContentHash: contentHash,
            ContentSize: contentSize,
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

    CreateRecoveryEntry(appEntry, displayValues,
        launchValues, identityValues) {
        return {
            Key: appEntry.Key,
            Value: appEntry.Value,
            Display: displayValues.Has(appEntry.Key)
                ? displayValues[appEntry.Key] : "",
            Launch: launchValues.Has(appEntry.Key)
                ? launchValues[appEntry.Key] : "",
            Identity: identityValues.Has(appEntry.Key)
                ? identityValues[appEntry.Key] : ""
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
            for propertyName in ["Key", "Value", "Display",
                "Launch"] {
                if !recoveryEntry.HasOwnProp(propertyName)
                    throw ValueError("恢复记录缺少字段: " propertyName)
            }
            recoveryValue := "Source="
                this.FieldCodec.Encode(recoveryEntry.Key)
            recoveryValue .= "`nApp="
                this.FieldCodec.Encode(recoveryEntry.Value)
            recoveryValue .= "`nDisplay="
                this.FieldCodec.Encode(recoveryEntry.Display)
            recoveryValue .= "`nLaunch="
                this.FieldCodec.Encode(recoveryEntry.Launch)
            recoveryValue .= "`nIdentity=" this.FieldCodec.Encode(
                recoveryEntry.HasOwnProp("Identity")
                    ? recoveryEntry.Identity : "")
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
