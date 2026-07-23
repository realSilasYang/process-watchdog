class DisplayConfigCodec {
    __New(normalizeTargetPath, pathsEquivalent) {
        this.NormalizeTargetPath := normalizeTargetPath
        this.PathsEquivalent := pathsEquivalent
    }

    CreateDefault() {
        return {Name: "", IconPath: ""}
    }

    Normalize(config) {
        normalized := this.CreateDefault()
        if !config || Type(config) != "Object"
            return normalized
        if config.HasOwnProp("Name")
            normalized.Name := SubStr(Trim(String(config.Name)), 1, 120)
        if config.HasOwnProp("IconPath")
            normalized.IconPath := this.NormalizeTargetPath.Call(config.IconPath)
        return normalized
    }

    Clone(config) {
        return this.Normalize(config)
    }

    Equals(firstConfig, secondConfig) {
        first := this.Normalize(firstConfig)
        second := this.Normalize(secondConfig)
        return first.Name == second.Name
            && this.PathsEquivalent.Call(first.IconPath, second.IconPath)
    }

    IsDefault(config) {
        normalized := this.Normalize(config)
        return normalized.Name == "" && normalized.IconPath == ""
    }

    Serialize(config) {
        normalized := this.Normalize(config)
        return IniFieldCodec.Encode(normalized.Name) "|"
            . IniFieldCodec.Encode(normalized.IconPath)
    }

    Deserialize(encodedValue) {
        config := this.CreateDefault()
        if (encodedValue == "")
            return config
        parts := StrSplit(encodedValue, "|")
        if (parts.Length != 2)
            return config
        config.Name := IniFieldCodec.Decode(parts[1])
        config.IconPath := IniFieldCodec.Decode(parts[2])
        return this.Normalize(config)
    }
}
