#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证未完成升级会话在独立日志中的序列化和恢复。
; 损坏记录、非法时间与参与者身份必须被拒绝，合法记录需保持逐字段一致。

#Include ..\..\src\Config\IniFieldCodec.ahk
#Include ..\..\src\Maintenance\MaintenanceActorMatcher.ahk
#Include ..\..\src\Maintenance\MaintenanceSessionCodec.ahk

AssertMaintenanceSessionCodec(value, message) {
    if !value
        throw Error(message)
}

RunMaintenanceSessionCodecTests() {
    codec := MaintenanceSessionCodec()
    defaultSession := codec.CreateDefault()
    AssertMaintenanceSessionCodec(defaultSession.Path == ""
        && defaultSession.Mode == ""
        && defaultSession.StartedAt == ""
        && defaultSession.BaselineFingerprint == ""
        && !defaultSession.FileChanged && !defaultSession.Explicit
        && defaultSession.ActorRecords.Length == 0
        && defaultSession.LearningCandidates.Length == 0,
        "维护会话默认值错误")

    path := "C:\软件|测试\应用.exe"
    actorIdentity := MaintenanceActorIdentity(4321,
        "0123456789ABCDEF", "C:\Tools\Updater2026.exe",
        "C:\软件|测试", ["1234:0011223344556677"])
    actorSignature := "P:c:\tools\updater2026.exe|R:c:\软件|测试"
    actorRecord := {
        Identity: actorIdentity,
        Match: MaintenanceActorMatchResult(true,
            "installer-references-root", actorSignature)
    }
    stateObj := {
        MaintenanceMode: "Stabilizing",
        MaintenanceStartedAt: "20260723123456",
        MaintenanceBaselineFingerprint: "123|时间||ABC|中文",
        MaintenanceFileChanged: true,
        ExplicitMaintenance: true,
        TransientActorIdentities: Map(actorIdentity.Key, actorRecord),
        MaintenanceLearningCandidates: Map(actorSignature, true)
    }
    restored := codec.Deserialize(codec.Serialize(path, stateObj))
    AssertMaintenanceSessionCodec(restored.Path == path
        && restored.Mode == stateObj.MaintenanceMode
        && restored.StartedAt == stateObj.MaintenanceStartedAt
        && restored.BaselineFingerprint
            == stateObj.MaintenanceBaselineFingerprint
        && restored.FileChanged && restored.Explicit
        && restored.ActorRecords.Length == 1
        && restored.ActorRecords[1].Identity.Key == actorIdentity.Key
        && restored.ActorRecords[1].Identity.ImagePath
            == actorIdentity.ImagePath
        && restored.ActorRecords[1].Identity.RootPath
            == actorIdentity.RootPath
        && restored.ActorRecords[1].Identity.ParentChain.Length == 1
        && restored.ActorRecords[1].Match.LearnableSignature
            == actorSignature
        && restored.LearningCandidates.Length == 1
        && restored.LearningCandidates[1] == actorSignature,
        "包含 Unicode 或竖线的维护会话没有无损往返")

    damaged := codec.Deserialize(IniFieldCodec.Encode(
        "Path=" IniFieldCodec.Encode(path)
        . "`nFileChanged=yes`nExplicit=0`nUnknown=value`nMalformed"))
    AssertMaintenanceSessionCodec(damaged.Path == path
        && !damaged.FileChanged && !damaged.Explicit
        && damaged.Mode == "" && damaged.ActorRecords.Length == 0,
        "损坏的维护会话字段没有安全回退")

    malformedOuter := codec.Deserialize("<HEX>XYZ")
    AssertMaintenanceSessionCodec(malformedOuter.Path == ""
        && malformedOuter.BaselineFingerprint == "",
        "损坏的维护会话外层编码没有回退为空会话")
}

try {
    RunMaintenanceSessionCodecTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
