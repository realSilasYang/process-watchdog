#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证守护列表顺序、升级配置、展示配置和恢复记录的一致持久化。
; 损坏的守护对象必须进入恢复区并在后续保存中原样保留，不能静默丢失用户数据。

#Include ..\..\src\Config\IniFieldCodec.ahk
#Include ..\..\src\Config\WatchdogConfigRepository.ahk
#Include ..\..\src\Config\WatchlistPersistenceService.ahk

AssertWatchlistPersistence(value, message) {
    if !value
        throw Error(message)
}

class WatchlistPersistenceMaintenanceCodec {
    CreateDefault(path) {
        return {Value: "DEFAULT:" path}
    }

    Deserialize(value, path) {
        return {Value: IniFieldCodec.Decode(value), Path: path}
    }

    Serialize(config, *) {
        return IniFieldCodec.Encode(config.Value)
    }
}

class WatchlistPersistenceDisplayCodec {
    CreateDefault() {
        return {Name: "", IconPath: ""}
    }

    Deserialize(value) {
        parts := StrSplit(value, "|")
        return {Name: IniFieldCodec.Decode(parts[1]),
            IconPath: IniFieldCodec.Decode(parts[2])}
    }

    Serialize(config) {
        return IniFieldCodec.Encode(config.Name) "|"
            . IniFieldCodec.Encode(config.IconPath)
    }

    IsDefault(config) {
        return config.Name == "" && config.IconPath == ""
    }
}

class WatchlistPersistenceSnapshotService {
    CreateSnapshot(path, stateObj) {
        return {
            Path: path,
            Enabled: stateObj.Enabled,
            RunAsAdmin: stateObj.RunAsAdmin,
            WorkDir: stateObj.WorkDir,
            Args: stateObj.Args,
            EnvVars: stateObj.EnvVars,
            RuntimePath: stateObj.RuntimePath,
            RuntimeArgs: stateObj.RuntimeArgs,
            ResolvedTarget: stateObj.ResolvedTarget,
            ResolvedTargetManual: stateObj.ResolvedTargetManual,
            ShortcutArgs: stateObj.ShortcutArgs,
            ContentHash: stateObj.ContentHash,
            ContentSize: stateObj.ContentSize,
            Maintenance: stateObj.Maintenance,
            Display: stateObj.Display
        }
    }
}

RegisterWatchlistPersistenceRecord(records, record) {
    if record.Path == "C:\Rejected.exe"
        return false
    records.Push(record)
    return true
}

CreateWatchlistPersistenceValue(path, arguments := "") {
    return "1|0|" path "||" IniFieldCodec.Encode(arguments)
        . "|||0|"
}

CreateWatchlistPersistenceState(path, name := "") {
    return {
        Enabled: 1,
        RunAsAdmin: 0,
        WorkDir: "C:\工作目录",
        Args: "--标签=测试",
        EnvVars: "LANG=zh_CN",
        RuntimePath: A_AhkPath,
        RuntimeArgs: "/ErrorStdOut",
        ResolvedTarget: path,
        ResolvedTargetManual: false,
        ShortcutArgs: "--shortcut",
        ContentHash: "A" . Format("{:063}", 0),
        ContentSize: 4096,
        Maintenance: {Value: "M:" path},
        Display: {Name: name, IconPath: name == "" ? "" : path}
    }
}

RunWatchlistPersistenceServiceTests() {
    processId := DllCall("kernel32\GetCurrentProcessId", "UInt")
    configPath := A_Temp "\watchdog-watchlist-persistence-" processId ".ini"
    try {
        try FileDelete(configPath)
        repository := WatchdogConfigRepository(configPath)
        repository.ReplaceSections([
            {Name: "Apps", Entries: [
                {Key: "App1", Value: CreateWatchlistPersistenceValue(
                    "C:\Valid.exe", "--中文")},
                {Key: "App2", Value: ""},
                {Key: "App3", Value: "1|0|C:\Damaged.exe||<HEX>XYZ|||0|"},
                {Key: "App4", Value: CreateWatchlistPersistenceValue(
                    "C:\Rejected.exe")},
                {Key: "App5", Value: CreateWatchlistPersistenceValue(
                    "C:\BadMaintenance.exe")},
                {Key: "App6", Value:
                    "1|0|C:\PlainLegacy.exe||plain-argument|||0|"},
                {Key: "App7", Value: CreateWatchlistPersistenceValue(
                    "C:\LegacyNoIdentity.exe")},
                {Key: "App8", Value: CreateWatchlistPersistenceValue(
                    "C:\BadIdentity.exe")}
            ]},
            {Name: "Maintenance", Entries: [
                {Key: "App1", Value: IniFieldCodec.Encode("maintenance")},
                {Key: "App2", Value: IniFieldCodec.Encode("empty")},
                {Key: "App3", Value: IniFieldCodec.Encode("damaged")},
                {Key: "App4", Value: IniFieldCodec.Encode("rejected")},
                {Key: "App5", Value: "plain-invalid"}
            ]},
            {Name: "Display", Entries: [
                {Key: "App1", Value: IniFieldCodec.Encode("自定义") "|"}
            ]},
            {Name: "Launch", Entries: [
                {Key: "App1", Value: IniFieldCodec.Encode(A_AhkPath)
                    "|" IniFieldCodec.Encode("/ErrorStdOut")}
            ]},
            {Name: "Identity", Entries: [
                {Key: "App1", Value: "128|"
                    . "B" . Format("{:063}", 0)},
                {Key: "App5", Value: "256|"
                    . "C" . Format("{:063}", 0)},
                {Key: "App8", Value: "not-a-size|invalid-hash"}
            ]},
            {Name: "Recovery", Entries: [
                {Key: "Entry1", Value: ""},
                {Key: "Entry2", Value: IniFieldCodec.Encode("old")}
            ]}
        ])
        service := WatchlistPersistenceService(repository, IniFieldCodec,
            WatchlistPersistenceMaintenanceCodec(),
            WatchlistPersistenceDisplayCodec(),
            WatchlistPersistenceSnapshotService())
        records := []
        loaded := service.Load(RegisterWatchlistPersistenceRecord.Bind(records))
        AssertWatchlistPersistence(loaded.RegisteredCount == 2
            && records.Length == 2,
            "有效守护对象注册数量错误")
        AssertWatchlistPersistence(records[1].Path == "C:\Valid.exe"
            && records[1].Args == "--中文"
            && records[1].RuntimePath == A_AhkPath
            && records[1].RuntimeArgs == "/ErrorStdOut"
            && records[1].Display.Name == "自定义",
            "有效守护对象的关联配置加载错误")
        AssertWatchlistPersistence(records[1].ContentSize == 128
            && records[1].ContentHash == "B" . Format("{:063}", 0)
            && records[2].Path == "C:\LegacyNoIdentity.exe"
            && records[2].ContentHash == ""
            && loaded.NeedsIdentitySave,
            "内容身份加载或旧配置升级标记错误")
        AssertWatchlistPersistence(loaded.Warnings.Length == 6
            && loaded.RecoveryEntries.Length == 8
            && loaded.RecoveryEntries[1].HasOwnProp("SerializedValue")
            && loaded.RecoveryEntries[1].SerializedValue == "",
            "有序加载、损坏记录隔离或既有恢复记录保留错误")
        AssertWatchlistPersistence(loaded.Warnings[2].Key == "App3"
            && loaded.Warnings[2].Section == "Apps"
            && loaded.Warnings[2].Field == "启动参数"
            && loaded.Warnings[2].Reason == "编码损坏"
            && loaded.Warnings[2].Target == "C:\Damaged.exe",
            "损坏应用字段没有生成可定位的结构化诊断")
        AssertWatchlistPersistence(loaded.Warnings[3].Key == "App4"
            && loaded.Warnings[3].Field == "目标路径"
            && InStr(loaded.Warnings[3].Reason, "重复")
            && loaded.Warnings[3].Target == "C:\Rejected.exe",
            "注册失败没有说明目标和失败原因")
        AssertWatchlistPersistence(loaded.Warnings[4].Key == "App5"
            && loaded.Warnings[4].Section == "Maintenance"
            && loaded.Warnings[4].Field == "升级保护配置"
            && loaded.Warnings[4].Target == "C:\BadMaintenance.exe",
            "关联配置损坏没有指向正确的配置节和目标")
        AssertWatchlistPersistence(loaded.Warnings[6].Key == "App8"
            && loaded.Warnings[6].Section == "Identity"
            && loaded.Warnings[6].Field == "文件大小"
            && loaded.Warnings[6].Target == "C:\BadIdentity.exe",
            "损坏内容身份没有隔离到 Recovery 或生成精确诊断")

        appStates := Map()
        appStates.CaseSense := "Off"
        firstPath := "C:\First.exe"
        secondPath := "C:\Second.exe"
        appStates[firstPath] := CreateWatchlistPersistenceState(firstPath,
            "第一项")
        appStates[secondPath] := CreateWatchlistPersistenceState(secondPath)
        saved := service.Save([firstPath, firstPath], appStates,
            loaded.RecoveryEntries)
        appEntries := repository.ReadSectionEntries("Apps")
        AssertWatchlistPersistence(saved.SavedCount == 2
            && saved.OrderedPaths.Length == 2
            && InStr(appEntries[1].Value, firstPath)
            && InStr(appEntries[2].Value, secondPath)
            && StrSplit(appEntries[1].Value, "|").Length == 9
            && repository.ReadSectionEntries("Maintenance").Length == 2
            && repository.ReadSectionEntries("Display").Length == 1
            && repository.ReadSectionEntries("Launch").Length == 2
            && repository.ReadSectionEntries("Identity").Length == 2
            && repository.ReadSectionEntries("Recovery").Length == 8
            && repository.Read("Recovery", "Entry1", "missing") == "",
            "守护对象顺序、当前九字段格式或恢复记录没有原子保存")
        recoveredMaintenanceIdentity := IniFieldCodec.Decode(
            repository.Read("Recovery", "Entry6", ""))
        AssertWatchlistPersistence(InStr(recoveredMaintenanceIdentity,
            "Identity=" IniFieldCodec.Encode("256|"
                . "C" . Format("{:063}", 0))),
            "关联配置损坏进入 Recovery 时丢失了内容身份")

        reloadedRecords := []
        reloaded := service.Load(
            RegisterWatchlistPersistenceRecord.Bind(reloadedRecords))
        AssertWatchlistPersistence(reloaded.RegisteredCount == 2
            && reloaded.Warnings.Length == 0
            && !reloaded.NeedsIdentitySave
            && reloadedRecords[1].ContentSize == 4096
            && reloadedRecords[1].ContentHash == "A" . Format("{:063}", 0)
            && reloaded.RecoveryEntries.Length == 8,
            "服务保存的当前格式无法无损重新加载")
    } finally {
        try FileDelete(configPath)
        Loop Files, configPath ".tmp.*"
            try FileDelete(A_LoopFileFullPath)
    }
}

try {
    RunWatchlistPersistenceServiceTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
