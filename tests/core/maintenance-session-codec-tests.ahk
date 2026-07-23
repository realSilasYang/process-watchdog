#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\..\src\Config\IniFieldCodec.ahk
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
        && !defaultSession.FileChanged && !defaultSession.Explicit,
        "维护会话默认值错误")

    path := "C:\软件|测试\应用.exe"
    stateObj := {
        MaintenanceMode: "Stabilizing",
        MaintenanceStartedAt: "20260723123456",
        MaintenanceBaselineFingerprint: "123|时间||ABC|中文",
        MaintenanceFileChanged: true,
        ExplicitMaintenance: true
    }
    restored := codec.Deserialize(codec.Serialize(path, stateObj))
    AssertMaintenanceSessionCodec(restored.Path == path
        && restored.Mode == stateObj.MaintenanceMode
        && restored.StartedAt == stateObj.MaintenanceStartedAt
        && restored.BaselineFingerprint
            == stateObj.MaintenanceBaselineFingerprint
        && restored.FileChanged && restored.Explicit,
        "包含 Unicode 或竖线的维护会话没有无损往返")

    damaged := codec.Deserialize(IniFieldCodec.Encode(
        "Path=" IniFieldCodec.Encode(path)
        . "`nFileChanged=yes`nExplicit=0`nUnknown=value`nMalformed"))
    AssertMaintenanceSessionCodec(damaged.Path == path
        && !damaged.FileChanged && !damaged.Explicit
        && damaged.Mode == "",
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
