class MaintenanceSessionCodec {
    CreateDefault() {
        return {
            Path: "",
            Mode: "",
            StartedAt: "",
            BaselineFingerprint: "",
            FileChanged: false,
            Explicit: false
        }
    }

    Serialize(path, stateObj) {
        payload := "Path=" IniFieldCodec.Encode(path)
        payload .= "`nMode=" stateObj.MaintenanceMode
        payload .= "`nStartedAt=" stateObj.MaintenanceStartedAt
        payload .= "`nBaselineFingerprint="
            . IniFieldCodec.Encode(stateObj.MaintenanceBaselineFingerprint)
        payload .= "`nFileChanged=" (stateObj.MaintenanceFileChanged ? 1 : 0)
        payload .= "`nExplicit=" (stateObj.ExplicitMaintenance ? 1 : 0)
        return IniFieldCodec.Encode(payload)
    }

    Deserialize(encodedValue) {
        result := this.CreateDefault()
        payload := IniFieldCodec.Decode(encodedValue)
        Loop Parse, payload, "`n", "`r" {
            separator := InStr(A_LoopField, "=")
            if !separator
                continue
            key := SubStr(A_LoopField, 1, separator - 1)
            value := SubStr(A_LoopField, separator + 1)
            switch key {
                case "Path":
                    result.Path := IniFieldCodec.Decode(value)
                case "Mode":
                    result.Mode := value
                case "StartedAt":
                    result.StartedAt := value
                case "BaselineFingerprint":
                    result.BaselineFingerprint := IniFieldCodec.Decode(value)
                case "FileChanged":
                    result.FileChanged := value == "1"
                case "Explicit":
                    result.Explicit := value == "1"
            }
        }
        return result
    }
}
