#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证运行设置与窗口布局服务的读取、范围校验、原子保存和重新加载。
; 特别覆盖小于首次默认值但不小于最小值的窗口尺寸，防止重载后恢复默认大小。

#Include ..\..\src\Config\IniFieldCodec.ahk
#Include ..\..\src\Localization\EnglishStrings.ahk
#Include ..\..\src\Localization\JapaneseStrings.ahk
#Include ..\..\src\Localization\KoreanStrings.ahk
#Include ..\..\src\Localization\FrenchStrings.ahk
#Include ..\..\src\Localization\GermanStrings.ahk
#Include ..\..\src\Localization\RussianStrings.ahk
#Include ..\..\src\Localization\VietnameseStrings.ahk
#Include ..\..\src\Localization\LocalizationService.ahk
#Include ..\..\src\UI\UiThemeService.ahk
#Include ..\..\src\Config\WatchdogConfigRepository.ahk
#Include ..\..\src\Config\RuntimeSettingsService.ahk
#Include ..\..\src\Config\WindowLayoutService.ahk

AssertApplicationConfig(value, message) {
    if !value
        throw Error(message)
}

ParseApplicationConfigRetrySequence(sequence) {
    normalized := StrReplace(StrReplace(Trim(String(sequence)), " ", ""),
        "，", ",")
    if (normalized == "")
        return false
    result := []
    for part in StrSplit(normalized, ",") {
        if !RegExMatch(part, "^\d+$")
            return false
        seconds := Integer(part)
        if (seconds < 1 || seconds > 86400)
            return false
        result.Push(seconds * 1000)
    }
    return result.Length ? result : false
}

RunApplicationConfigServiceTests() {
    processId := DllCall("kernel32\GetCurrentProcessId", "UInt")
    configPath := A_Temp "\watchdog-application-config-" processId ".ini"
    try {
        try FileDelete(configPath)
        repository := WatchdogConfigRepository(configPath)
        defaultLogDirectory := A_Temp "\ExpectedWatchdogLogs"
        settingsService := RuntimeSettingsService(repository,
            ParseApplicationConfigRetrySequence, defaultLogDirectory)
        AssertApplicationConfig(settingsService.EnsureExists()
            && repository.Read("Settings", "ShowAfterReload", "") == "0"
            && repository.Read("Settings", "UiLanguage", "") == "auto"
            && repository.Read("Settings", "UiFont", "") == "auto"
            && repository.Read("Settings", "Theme", "") == "auto"
            && repository.Read("Settings", "RecursiveBatchImport", "") == "1"
            && repository.Read("Settings", "CheckUpdatesOnStartup", "") == "1"
            && repository.Read("Settings", "PreferEverything", "") == ""
            && repository.Read("Settings", "NativeScanTimeoutSeconds", "") == ""
            && repository.Read("Settings", "EverythingMaxResults", "") == "",
            "首次运行设置没有通过服务完整创建")
        generatedConfig := FileRead(configPath)
        AssertApplicationConfig(InStr(generatedConfig,
            "; UiFont：界面字体；auto 表示使用当前语言的默认字体")
            && InStr(generatedConfig,
                "; Theme：界面主题；auto 表示跟随 Windows 系统")
            && repository.Read("Settings", "UiFont", "") == "auto",
            "内容字体就地注释缺失或影响了 INI 读取")

        repository.WriteValues("Settings", [
            {Key: "UiLanguage", Value: "unsupported"},
            {Key: "UiFont", Value: "__Watchdog_Missing_Font__"},
            {Key: "Theme", Value: "unsupported"},
            {Key: "CheckInterval", Value: 10},
            {Key: "RetrySequence", Value: "broken"},
            {Key: "LogDirectory", Value: "   "},
            {Key: "GracefulStopSeconds", Value: 999},
            {Key: "ShowAtStartup", Value: "invalid"}
        ])
        loaded := settingsService.Load()
        AssertApplicationConfig(loaded.UiLanguage == "auto"
            && loaded.UiFont == "auto"
            && loaded.Theme == "auto"
            && loaded.CheckInterval == 2000
            && loaded.RetrySequence == "1, 10, 60"
            && loaded.RetryDelayArray.Length == 3
            && loaded.LogDirectory == defaultLogDirectory
            && loaded.GracefulStopSeconds == 3
            && !loaded.ShowAtStartup,
            "损坏或越界的运行参数没有逐字段回退默认值")

        candidate := settingsService.CreateDefaults()
        installedFonts := LocalizationService.GetInstalledUiFontNames()
        AssertApplicationConfig(installedFonts.Length > 0,
            "配置测试没有枚举到可用字体")
        selectedFont := installedFonts[1]
        candidate.CheckInterval := 750
        candidate.UiLanguage := "ja-JP"
        candidate.UiFont := selectedFont
        candidate.Theme := "light"
        candidate.RetrySequence := "1, 2"
        candidate.ShowAtStartup := true
        candidate.CheckUpdatesOnStartup := false
        candidate.LogDirectory := " D:\Logs "
        saved := settingsService.Save(candidate)
        runtime := {}
        settingsService.Apply(runtime, saved)
        AssertApplicationConfig(runtime.uiLanguage == "ja-JP"
            && runtime.uiFont == selectedFont
            && runtime.uiTheme == "light"
            && runtime.checkInterval == 750
            && runtime.retryDelayArray.Length == 2
            && runtime.retryDelayArray[2] == 2000
            && runtime.showAtStartup
            && !runtime.checkUpdatesOnStartup
            && runtime.logDirectory == "D:\Logs"
            && repository.Read("Settings", "UiLanguage", "") == "ja-JP",
            "有效运行参数没有统一校验、保存并应用到运行态")

        originalFont := repository.Read("Settings", "UiFont", "")
        candidate.UiFont := "__Watchdog_Missing_Font__"
        invalidFontRejected := false
        try settingsService.Save(candidate)
        catch
            invalidFontRejected := true
        AssertApplicationConfig(invalidFontRejected
            && repository.Read("Settings", "UiFont", "") == originalFont,
            "未安装字体仍被保存或污染了已有配置")
        candidate.UiFont := selectedFont

        originalTheme := repository.Read("Settings", "Theme", "")
        candidate.Theme := "unsupported"
        invalidThemeRejected := false
        try settingsService.Save(candidate)
        catch
            invalidThemeRejected := true
        AssertApplicationConfig(invalidThemeRejected
            && repository.Read("Settings", "Theme", "") == originalTheme,
            "无效界面主题仍被保存或污染了已有配置")
        candidate.Theme := "light"

        originalInterval := repository.Read("Settings", "CheckInterval", "")
        candidate.CheckInterval := 1
        rejected := false
        try settingsService.Save(candidate)
        catch
            rejected := true
        AssertApplicationConfig(rejected
            && repository.Read("Settings", "CheckInterval", "")
                == originalInterval,
            "越界运行参数仍污染了已保存设置")

        repository.WriteValues("Layout", [
            {Key: "GuiW", Value: "bad"},
            {Key: "GuiH", Value: 10},
            {Key: "Col1W", Value: 99999},
            {Key: "Col2W", Value: 250}
        ])
        layoutService := WindowLayoutService(repository)
        layout := layoutService.Load()
        AssertApplicationConfig(layout.Width == 730 && layout.Height == 520
            && layout.Column1 == 500 && layout.Column2 == 250,
            "损坏布局没有逐字段限制到安全默认值")
        repository.WriteValue("Layout", "Col2W", "bad")
        AssertApplicationConfig(layoutService.Load().Column2 == 200,
            "损坏的状态列宽度没有回退到收窄后的默认值")
        layoutService.Save({Width: 580, Height: 300,
            Column1: 250, Column2: 180})
        reloadedLayout := layoutService.Load()
        layoutRuntime := {}
        layoutService.Apply(layoutRuntime, reloadedLayout)
        AssertApplicationConfig(layoutRuntime.savedWidth == 580
            && layoutRuntime.savedHeight == 300
            && layoutRuntime.savedColumn1 == 250
            && layoutRuntime.savedColumn2 == 180,
            "有效布局没有统一保存并应用")
        narrowColumnRejected := false
        try layoutService.Save({Width: 580, Height: 300,
            Column1: 250, Column2: 139})
        catch
            narrowColumnRejected := true
        AssertApplicationConfig(narrowColumnRejected
            && layoutService.Load().Column2 == 180,
            "状态列接受了低于可读下限的宽度或污染了已保存布局")
    } finally {
        try FileDelete(configPath)
        Loop Files, configPath ".tmp.*"
            try FileDelete(A_LoopFileFullPath)
    }
}

try {
    RunApplicationConfigServiceTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
