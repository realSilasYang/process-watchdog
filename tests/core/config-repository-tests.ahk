#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\..\src\Config\IniFieldCodec.ahk
#Include ..\..\src\Config\WatchdogConfigRepository.ahk

AssertConfigRepository(value, message) {
    if !value
        throw Error(message)
}

ReadConfigTestClock(clockState) {
    clockState.Value += 1
    return clockState.Value
}

WriteFailingConfigTransaction(tempPath) {
    IniWrite("damaged", tempPath, "Apps", "App1")
    throw Error("模拟配置写入失败")
}

WriteNestedConfigTransaction(repository, tempPath) {
    IniWrite("outer", tempPath, "Apps", "App1")
    repository.WriteValue("Apps", "App2", "nested")
}

RunConfigRepositoryTests() {
    encoded := IniFieldCodec.Encode("中文|配置`n第二行")
    AssertConfigRepository(SubStr(encoded, 1, 5) == "<HEX>"
        && IniFieldCodec.Decode(encoded) == "中文|配置`n第二行",
        "INI 字段 UTF-8 编解码失败")
    AssertConfigRepository(IniFieldCodec.Decode("<HEX>XYZ") == "<HEX>XYZ",
        "损坏的 HEX 字段不应被部分解码")
    AssertConfigRepository(IniFieldCodec.Decode("<HEX>C328") == "<HEX>C328",
        "非法 UTF-8 字节不应被替换为乱码")

    configPath := A_Temp "\watchdog-config-repository-test-"
        DllCall("kernel32\GetCurrentProcessId", "UInt") ".ini"
    clockState := {Value: 1000}
    repository := WatchdogConfigRepository(configPath,
        ReadConfigTestClock.Bind(clockState))
    try {
        try FileDelete(configPath)
        Loop Files, configPath ".tmp.*"
            try FileDelete(A_LoopFileFullPath)

        repository.EnsureExists([
            {Name: "Settings", Entries: [
                {Key: "CheckInterval", Value: 2000},
                {Key: "ShowAtStartup", Value: 0}]},
            {Name: "Apps", Entries: [
                {Key: "App2", Value: "second"},
                {Key: "App1", Value: "first"}]}
        ])
        AssertConfigRepository(repository.Read("Settings", "CheckInterval",
            0) == "2000", "默认配置没有写入")
        AssertConfigRepository(!repository.ReadBool("Settings",
            "ShowAtStartup", true), "布尔配置读取错误")
        AssertConfigRepository(repository.ReadBoundedInt("Settings",
            "CheckInterval", 1000, 500, 5000) == 2000,
            "有界整数配置读取错误")

        appEntries := repository.ReadSectionEntries("Apps")
        AssertConfigRepository(appEntries.Length == 2
            && appEntries[1].Key == "App2"
            && appEntries[2].Key == "App1",
            "配置分区条目顺序没有保留")

        repository.WriteValues("Layout", [
            {Key: "GuiW", Value: 730}, {Key: "GuiH", Value: 530},
            {Key: "Col1W", Value: 500}, {Key: "Col2W", Value: 205}])
        repository.ReplaceSections([
            {Name: "Apps", Entries: [{Key: "App1", Value: "updated"}]},
            {Name: "Maintenance", Entries: [{Key: "App1", Value: "state"}]},
            {Name: "Display", Entries: []},
            {Name: "Recovery", Entries: []}
        ])
        AssertConfigRepository(repository.Read("Settings", "CheckInterval",
            0) == "2000", "替换动态分区时破坏了设置分区")
        AssertConfigRepository(repository.ReadSectionEntries("Apps").Length == 1
            && repository.Read("Apps", "App1", "") == "updated",
            "动态分区没有整体替换")

        iniText := FileRead(configPath, "UTF-16")
        AssertConfigRepository(InStr(iniText,
            "; CheckInterval：状态检查间隔")
            && InStr(iniText, "; GuiH：主窗口高度")
            && InStr(iniText, "; 每个 AppN 对应一个监控项"),
            "配置注释没有恢复到对应分区或键")
        repository.ReplaceSections([{Name: "Display", Entries: [
            {Key: "App1", Value: "name|icon"}]}])
        repository.ReplaceSections([{Name: "Display", Entries: []}])
        repository.ReplaceSections([{Name: "Display", Entries: [
            {Key: "App1", Value: "name|icon"}]}])
        iniText := FileRead(configPath, "UTF-16")
        displayComment := "; 仅保存主窗口显示名称和图标来源"
        AssertConfigRepository(RegExMatch(iniText,
            "m)^\[Display\]\R\Q" displayComment "\E")
            && StrSplit(iniText, displayComment).Length == 2,
            "空动态分区重建后，孤立注释没有唯一归位到所属分区")
        temporaryFiles := 0
        Loop Files, configPath ".tmp.*"
            temporaryFiles += 1
        AssertConfigRepository(temporaryFiles == 0,
            "配置事务结束后残留临时文件")

        originalText := FileRead(configPath, "UTF-16")
        transactionFailed := false
        try repository.Transact(WriteFailingConfigTransaction)
        catch as transactionError
            transactionFailed := transactionError.Message
                == "模拟配置写入失败"
        AssertConfigRepository(transactionFailed,
            "配置写入异常没有向调用方传播")
        AssertConfigRepository(!repository.Writing,
            "配置写入异常后事务占用状态没有复位")
        AssertConfigRepository(FileRead(configPath, "UTF-16") == originalText,
            "失败的配置事务污染了原配置文件")
        temporaryFiles := 0
        Loop Files, configPath ".tmp.*"
            temporaryFiles += 1
        AssertConfigRepository(temporaryFiles == 0,
            "失败的配置事务遗留了临时文件")

        nestedRejected := false
        try repository.Transact(WriteNestedConfigTransaction.Bind(repository))
        catch as nestedError
            nestedRejected := nestedError.Message
                == "配置文件写入事务正在进行"
        AssertConfigRepository(nestedRejected && !repository.Writing,
            "嵌套配置写入没有拒绝或没有释放外层事务")
        AssertConfigRepository(FileRead(configPath, "UTF-16") == originalText,
            "嵌套配置写入失败后污染了原配置文件")

        Critical("On")
        try {
            repository.WriteValue("Settings", "ShowAtStartup", 1)
            AssertConfigRepository(A_IsCritical != 0,
                "配置事务破坏了调用方的临界状态")
        } finally Critical("Off")
        AssertConfigRepository(repository.ReadBool("Settings",
            "ShowAtStartup", false),
            "异常恢复后配置仓储无法继续保存")
    } finally {
        try FileDelete(configPath)
        Loop Files, configPath ".tmp.*"
            try FileDelete(A_LoopFileFullPath)
    }
}

try {
    RunConfigRepositoryTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
