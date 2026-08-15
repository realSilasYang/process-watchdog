; 主列表自定义展示配置的编解码器。
; 名称和图标路径分别使用 INI 字段编码，空值表示沿用目标自身信息；
; 解析失败返回明确的无效结果，不让损坏字段悄悄影响目标身份。

class DisplayConfigCodec {
    __New(normalizeTargetPath, pathsEquivalent) {
        this.NormalizeTargetPath := normalizeTargetPath
        this.PathsEquivalent := pathsEquivalent
    }

    CreateDefault() {
        return {Name: "", IconPath: "", SequenceColor: ""}
    }

    Normalize(config) {
        normalized := this.CreateDefault()
        if !config || Type(config) != "Object"
            return normalized
        if config.HasOwnProp("Name")
            normalized.Name := SubStr(Trim(String(config.Name)), 1, 120)
        if config.HasOwnProp("IconPath")
            normalized.IconPath := this.NormalizeTargetPath.Call(config.IconPath)
        if config.HasOwnProp("SequenceColor")
            normalized.SequenceColor := MainSequenceColorPalette.NormalizeKey(
                config.SequenceColor)
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
            && first.SequenceColor == second.SequenceColor
    }

    IsDefault(config) {
        normalized := this.Normalize(config)
        return normalized.Name == "" && normalized.IconPath == ""
            && normalized.SequenceColor == ""
    }

    Serialize(config) {
        normalized := this.Normalize(config)
        return IniFieldCodec.Encode(normalized.Name) "|"
            . IniFieldCodec.Encode(normalized.IconPath) "|"
            . normalized.SequenceColor
    }

    Deserialize(encodedValue) {
        config := this.CreateDefault()
        if (encodedValue == "")
            return config
        parts := StrSplit(encodedValue, "|")
        if (parts.Length != 2 && parts.Length != 3)
            return config
        config.Name := IniFieldCodec.Decode(parts[1])
        config.IconPath := IniFieldCodec.Decode(parts[2])
        if parts.Length == 3
            config.SequenceColor := parts[3]
        return this.Normalize(config)
    }
}
