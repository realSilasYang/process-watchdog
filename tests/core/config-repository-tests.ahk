#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证配置仓库的原子替换、顺序读取和中文就地注释维护。
; 事务异常不能遗留临时文件、破坏原配置或改变调用方原有临界区状态。

#Include ..\..\src\Config\IniFieldCodec.ahk
#Include ..\..\src\Config\WatchdogConfigRepository.ahk
#Include ..\..\src\Localization\EnglishStrings.ahk
#Include ..\..\src\Localization\TraditionalHongKongStrings.ahk
#Include ..\..\src\Localization\TraditionalTaiwanStrings.ahk
#Include ..\..\src\Localization\JapaneseStrings.ahk
#Include ..\..\src\Localization\VietnameseStrings.ahk
#Include ..\..\src\Localization\KoreanStrings.ahk
#Include ..\..\src\Localization\SpanishStrings.ahk
#Include ..\..\src\Localization\FrenchStrings.ahk
#Include ..\..\src\Localization\PortugueseBrazilStrings.ahk
#Include ..\..\src\Localization\RussianStrings.ahk
#Include ..\..\src\Localization\GermanStrings.ahk
#Include ..\..\src\Localization\ItalianStrings.ahk
#Include ..\..\src\Localization\LocalizationService.ahk

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
    englishConfigPath := A_Temp "\watchdog-config-repository-en-test-"
        DllCall("kernel32\GetCurrentProcessId", "UInt") ".ini"
    clockState := {Value: 1000}
    repository := WatchdogConfigRepository(configPath,
        ReadConfigTestClock.Bind(clockState))
    try {
        try FileDelete(configPath)
        try FileDelete(englishConfigPath)
        Loop Files, configPath ".tmp.*"
            try FileDelete(A_LoopFileFullPath)
        Loop Files, englishConfigPath ".tmp.*"
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

        ; 系统语言切换只能替换自动生成的说明文字，不能翻译节名、键名和值；
        ; 中英文往返和重复保存也不能叠加注释或影响 IniRead 的读取结果。
        commentCatalogs := LocalizationService.GetAllTranslationCatalogs()
        LocalizationService.Configure("zh-CN")
        localizedRepository := WatchdogConfigRepository(englishConfigPath,
            ReadConfigTestClock.Bind(clockState), Tr, commentCatalogs)
        localizedRepository.EnsureExists([
            {Name: "Settings", Entries: [
                {Key: "CheckInterval", Value: 2500},
                {Key: "ShowAtStartup", Value: 1}]},
            {Name: "Layout", Entries: [
                {Key: "GuiW", Value: 730}, {Key: "GuiH", Value: 520}]},
            {Name: "Apps", Entries: [
                {Key: "App1", Value: "enabled|target|value"}]}
        ])
        chineseText := FileRead(englishConfigPath, "UTF-16")
        AssertConfigRepository(InStr(chineseText,
            "; 本区保存运行参数")
            && InStr(chineseText, "; 每个 AppN 对应一个监控项"),
            "中文环境没有生成中文配置注释")

        LocalizationService.Configure("en-US")
        englishRepository := WatchdogConfigRepository(englishConfigPath,
            ReadConfigTestClock.Bind(clockState), Tr, commentCatalogs)
        englishRepository.WriteValue("Settings", "CheckInterval", 3000)
        englishText := FileRead(englishConfigPath, "UTF-16")
        AssertConfigRepository(InStr(englishText,
            "; This section stores runtime settings.")
            && InStr(englishText,
                "; CheckInterval: status-check interval in milliseconds")
            && InStr(englishText,
                "; GuiW: main-window width, stored in logical pixels"),
            "英文环境没有生成英文配置注释")
        AssertConfigRepository(!InStr(englishText,
            "; 本区保存运行参数")
            && englishRepository.Read("Settings", "CheckInterval", 0)
                == "3000"
            && englishRepository.Read("Layout", "GuiW", 0) == "730"
            && englishRepository.Read("Apps", "App1", "")
                == "enabled|target|value",
            "英文配置注释改变了稳定节名、键名或值的读取")
        englishRepository.WriteValue("Settings", "CheckInterval", 3500)
        englishText := FileRead(englishConfigPath, "UTF-16")
        englishMarker :=
            "; CheckInterval: status-check interval in milliseconds"
        AssertConfigRepository(StrSplit(englishText,
            englishMarker).Length == 2
            && englishRepository.Read("Settings", "CheckInterval", 0)
                == "3500",
            "英文配置重复保存后注释重复或值读取异常")

        checkIntervalComment :=
            "; CheckInterval：状态检查间隔，单位为毫秒，范围 500～86400000。"
        localizedCommentLanguages := ["zh-HK", "zh-TW", "ja-JP",
            "vi-VN", "ko-KR", "es-ES", "fr-FR", "pt-BR", "ru-RU",
            "de-DE", "it-IT"]
        for languageIndex, language in localizedCommentLanguages {
            LocalizationService.Configure(language)
            languageRepository := WatchdogConfigRepository(englishConfigPath,
                ReadConfigTestClock.Bind(clockState), Tr, commentCatalogs)
            languageRepository.WriteValue("Settings", "CheckInterval",
                3500 + languageIndex)
            languageText := FileRead(englishConfigPath, "UTF-16")
            activeMarker := Tr(checkIntervalComment)
            AssertConfigRepository(StrSplit(languageText,
                activeMarker).Length == 2,
                language " 配置注释没有生成或发生重复")
            for catalog in commentCatalogs {
                if catalog.Has(checkIntervalComment)
                    && catalog[checkIntervalComment] != activeMarker {
                    AssertConfigRepository(!InStr(languageText,
                        catalog[checkIntervalComment]),
                        language " 配置仍残留其他语言的旧注释")
                }
            }
        }

        LocalizationService.Configure("zh-CN")
        chineseRepository := WatchdogConfigRepository(englishConfigPath,
            ReadConfigTestClock.Bind(clockState), Tr, commentCatalogs)
        chineseRepository.WriteValue("Settings", "CheckInterval", 3600)
        chineseText := FileRead(englishConfigPath, "UTF-16")
        chineseMarker := "; CheckInterval：状态检查间隔"
        AssertConfigRepository(!InStr(chineseText, englishMarker)
            && StrSplit(chineseText, chineseMarker).Length == 2
            && chineseRepository.Read("Settings", "CheckInterval", 0)
                == "3600",
            "配置注释从英文切回中文后重复或稳定值发生变化")
    } finally {
        LocalizationService.Configure("zh-CN")
        try FileDelete(configPath)
        try FileDelete(englishConfigPath)
        Loop Files, configPath ".tmp.*"
            try FileDelete(A_LoopFileFullPath)
        Loop Files, englishConfigPath ".tmp.*"
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
