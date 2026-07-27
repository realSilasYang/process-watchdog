; 未完成升级会话的独立日志编解码器。
; 只保存跨进程恢复所需的阶段、时间和参与者身份，采用注入的字段编码器处理文本；
; 损坏会话返回明确失败，协调器据此安全回到普通守护而不是猜测升级仍在继续。

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
