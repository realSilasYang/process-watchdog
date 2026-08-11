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
            Explicit: false,
            ActorRecords: [],
            LearningCandidates: []
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
        if stateObj.HasOwnProp("TransientActorIdentities")
            && Type(stateObj.TransientActorIdentities) == "Map" {
            for _, actorRecord in stateObj.TransientActorIdentities {
                encodedActor := this.SerializeActorRecord(actorRecord)
                if encodedActor != ""
                    payload .= "`nActor=" encodedActor
            }
        }
        if stateObj.HasOwnProp("MaintenanceLearningCandidates")
            && Type(stateObj.MaintenanceLearningCandidates) == "Map" {
            for signature in stateObj.MaintenanceLearningCandidates {
                signature := Trim(String(signature))
                if signature != ""
                    payload .= "`nLearningCandidate="
                        . IniFieldCodec.Encode(signature)
            }
        }
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
                case "Actor":
                    actorRecord := this.DeserializeActorRecord(value)
                    if IsObject(actorRecord)
                        result.ActorRecords.Push(actorRecord)
                case "LearningCandidate":
                    signature := IniFieldCodec.Decode(value)
                    if this.IsLearningSignature(signature)
                        result.LearningCandidates.Push(signature)
            }
        }
        return result
    }

    SerializeActorRecord(actorRecord) {
        if !IsObject(actorRecord) || !actorRecord.HasOwnProp("Identity")
            || !(actorRecord.Identity is MaintenanceActorIdentity)
            return ""
        identity := actorRecord.Identity
        if identity.PID <= 0 || !this.IsCreationIdentity(
            identity.CreationIdentity)
            return ""
        payload := "PID=" identity.PID
        payload .= "`nCreationIdentity="
            . IniFieldCodec.Encode(identity.CreationIdentity)
        payload .= "`nImagePath=" IniFieldCodec.Encode(identity.ImagePath)
        payload .= "`nRootPath=" IniFieldCodec.Encode(identity.RootPath)
        if Type(identity.ParentChain) == "Array" {
            for parentIdentity in identity.ParentChain
                payload .= "`nParent="
                    . IniFieldCodec.Encode(parentIdentity)
        }
        evidence := actorRecord.HasOwnProp("Match")
            && IsObject(actorRecord.Match)
            && actorRecord.Match.HasOwnProp("Evidence")
            ? actorRecord.Match.Evidence : ""
        signature := actorRecord.HasOwnProp("Match")
            && IsObject(actorRecord.Match)
            && actorRecord.Match.HasOwnProp("LearnableSignature")
            ? actorRecord.Match.LearnableSignature : ""
        payload .= "`nEvidence=" IniFieldCodec.Encode(evidence)
        if this.IsLearningSignature(signature)
            payload .= "`nLearnableSignature="
                . IniFieldCodec.Encode(signature)
        return IniFieldCodec.Encode(payload)
    }

    DeserializeActorRecord(encodedValue) {
        payload := IniFieldCodec.Decode(encodedValue)
        values := Map()
        parents := []
        Loop Parse, payload, "`n", "`r" {
            separator := InStr(A_LoopField, "=")
            if !separator
                continue
            key := SubStr(A_LoopField, 1, separator - 1)
            value := SubStr(A_LoopField, separator + 1)
            if key == "Parent"
                parents.Push(IniFieldCodec.Decode(value))
            else
                values[key] := value
        }
        try pid := values.Has("PID") ? Integer(values["PID"]) : 0
        catch
            return ""
        creationIdentity := values.Has("CreationIdentity")
            ? IniFieldCodec.Decode(values["CreationIdentity"]) : ""
        if pid <= 0 || !this.IsCreationIdentity(creationIdentity)
            return ""
        imagePath := values.Has("ImagePath")
            ? IniFieldCodec.Decode(values["ImagePath"]) : ""
        rootPath := values.Has("RootPath")
            ? IniFieldCodec.Decode(values["RootPath"]) : ""
        evidence := values.Has("Evidence")
            ? IniFieldCodec.Decode(values["Evidence"]) : "restored-session"
        signature := values.Has("LearnableSignature")
            ? IniFieldCodec.Decode(values["LearnableSignature"]) : ""
        if !this.IsLearningSignature(signature)
            signature := ""
        identity := MaintenanceActorIdentity(pid, creationIdentity,
            imagePath, rootPath, parents)
        return {
            Process: {pid: pid, exe: imagePath},
            Identity: identity,
            Match: MaintenanceActorMatchResult(true, evidence, signature),
            LastSeenTicks: 0
        }
    }

    IsCreationIdentity(value) {
        return RegExMatch(String(value), "i)^[0-9a-f]{16}$") != 0
    }

    IsLearningSignature(value) {
        return RegExMatch(String(value), "i)^P:.+\|R:.+$") != 0
    }
}
