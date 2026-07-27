; 软件升级保护配置的序列化边界。
; 将安装足迹、等待时间和已学习更新程序身份转换为当前唯一格式；
; 任何缺字段或非法数值都显式拒绝，避免兼容残留改变升级状态机含义。

class MaintenanceConfigCodec {
    __New(callbacks, maintenanceActorMatcher) {
        this.Callbacks := callbacks
        this.MaintenanceActorMatcher := maintenanceActorMatcher
    }

    CreateDefault(path) {
        return {
            Enabled: false,
            InstallRoot: this.Callbacks.GetDefaultRoot.Call(path),
            RootIsCustom: false,
            DetectionSeconds: 10,
            StableSeconds: 8,
            MaxWaitSeconds: 1800,
            LearnedActors: []
        }
    }

    Normalize(config, path) {
        normalized := this.CreateDefault(path)
        if !config || Type(config) != "Object"
            return normalized
        if config.HasOwnProp("Enabled") {
            normalized.Enabled := !!config.Enabled
                && this.Callbacks.IsSupportedTarget.Call(path)
        }
        if config.HasOwnProp("RootIsCustom")
            normalized.RootIsCustom := !!config.RootIsCustom
        if config.HasOwnProp("InstallRoot") {
            normalized.InstallRoot := this.Callbacks.NormalizeRoot.Call(
                config.InstallRoot, path)
        }
        if (!normalized.RootIsCustom || normalized.InstallRoot == "")
            normalized.InstallRoot := this.Callbacks.GetDefaultRoot.Call(path)
        this.ApplyBoundedInteger(config, normalized, "DetectionSeconds", 2, 120)
        this.ApplyBoundedInteger(config, normalized, "StableSeconds", 2, 300)
        this.ApplyBoundedInteger(config, normalized, "MaxWaitSeconds", 60, 86400)
        normalized.LearnedActors := this.NormalizeActors(config,
            normalized.InstallRoot)
        return normalized
    }

    Clone(config, path) {
        return this.Normalize(config, path)
    }

    Equals(firstConfig, secondConfig) {
        if !firstConfig || !secondConfig
            return !firstConfig && !secondConfig
        if (!!firstConfig.Enabled != !!secondConfig.Enabled
            || !!firstConfig.RootIsCustom != !!secondConfig.RootIsCustom
            || !this.Callbacks.PathsEquivalent.Call(firstConfig.InstallRoot,
                secondConfig.InstallRoot)
            || firstConfig.DetectionSeconds != secondConfig.DetectionSeconds
            || firstConfig.StableSeconds != secondConfig.StableSeconds
            || firstConfig.MaxWaitSeconds != secondConfig.MaxWaitSeconds
            || firstConfig.LearnedActors.Length
                != secondConfig.LearnedActors.Length)
            return false
        for index, actor in firstConfig.LearnedActors {
            if (StrLower(actor) != StrLower(secondConfig.LearnedActors[index]))
                return false
        }
        return true
    }

    NormalizeSnapshot(config, path, resolvedTarget := "") {
        normalized := this.Normalize(config, path)
        SplitPath(path, , , &extension)
        if (StrLower(extension) != "lnk")
            return normalized

        requestedProtection := config && Type(config) == "Object"
            && config.HasOwnProp("Enabled") && config.Enabled
        normalized.Enabled := requestedProtection && resolvedTarget != ""
            && this.Callbacks.IsSupportedTarget.Call(resolvedTarget)
        if (!normalized.RootIsCustom || normalized.InstallRoot == "") {
            if (resolvedTarget != "") {
                SplitPath(resolvedTarget, , &resolvedDirectory)
                normalized.InstallRoot := this.Callbacks.NormalizeRoot.Call(
                    resolvedDirectory)
            } else if (config && Type(config) == "Object"
                && config.HasOwnProp("InstallRoot")) {
                normalized.InstallRoot := this.Callbacks.NormalizeRoot.Call(
                    config.InstallRoot)
            }
        }
        normalized.LearnedActors := this.NormalizeActors(config,
            normalized.InstallRoot)
        return normalized
    }

    Serialize(config, path) {
        config := this.Normalize(config, path)
        payload := "Enabled=" (config.Enabled ? 1 : 0)
        payload .= "`nRootIsCustom=" (config.RootIsCustom ? 1 : 0)
        payload .= "`nDetectionSeconds=" config.DetectionSeconds
        payload .= "`nStableSeconds=" config.StableSeconds
        payload .= "`nMaxWaitSeconds=" config.MaxWaitSeconds
        payload .= "`nInstallRoot=" IniFieldCodec.Encode(config.InstallRoot)
        for actor in config.LearnedActors
            payload .= "`nActor=" IniFieldCodec.Encode(actor)
        return IniFieldCodec.Encode(payload)
    }

    Deserialize(encodedValue, path) {
        config := this.CreateDefault(path)
        if (encodedValue == "")
            return config
        payload := IniFieldCodec.Decode(encodedValue)
        actors := []
        Loop Parse, payload, "`n", "`r" {
            separator := InStr(A_LoopField, "=")
            if !separator
                continue
            key := SubStr(A_LoopField, 1, separator - 1)
            value := SubStr(A_LoopField, separator + 1)
            switch key {
                case "Enabled":
                    config.Enabled := value == "1"
                case "RootIsCustom":
                    config.RootIsCustom := value == "1"
                case "DetectionSeconds":
                    config.DetectionSeconds := value
                case "StableSeconds":
                    config.StableSeconds := value
                case "MaxWaitSeconds":
                    config.MaxWaitSeconds := value
                case "InstallRoot":
                    config.InstallRoot := IniFieldCodec.Decode(value)
                case "Actor":
                    actors.Push(IniFieldCodec.Decode(value))
            }
        }
        config.LearnedActors := actors
        return this.Normalize(config, path)
    }

    ApplyBoundedInteger(source, target, propertyName, minValue, maxValue) {
        if !source.HasOwnProp(propertyName)
            return
        parsed := this.Callbacks.ParseBoundedInteger.Call(
            source.%propertyName%, minValue, maxValue)
        if parsed
            target.%propertyName% := parsed
    }

    NormalizeActors(config, installRoot) {
        actors := []
        if (!config || Type(config) != "Object"
            || !config.HasOwnProp("LearnedActors")
            || Type(config.LearnedActors) != "Array")
            return actors
        seen := Map()
        seen.CaseSense := "Off"
        for actor in config.LearnedActors {
            normalizedActor := this.MaintenanceActorMatcher
                .NormalizeLearnedSignature(actor, installRoot)
            if (normalizedActor != "" && !seen.Has(normalizedActor)) {
                seen[normalizedActor] := true
                actors.Push(normalizedActor)
            }
        }
        return actors
    }
}
