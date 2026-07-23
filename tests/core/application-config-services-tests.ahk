#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\..\src\Config\IniFieldCodec.ahk
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
            && repository.Read("Settings", "RecursiveBatchImport", "") == "1",
            "首次运行设置没有通过服务完整创建")

        repository.WriteValues("Settings", [
            {Key: "CheckInterval", Value: 10},
            {Key: "RetrySequence", Value: "broken"},
            {Key: "LogDirectory", Value: "   "},
            {Key: "GracefulStopSeconds", Value: 999},
            {Key: "ShowAtStartup", Value: "invalid"}
        ])
        loaded := settingsService.Load()
        AssertApplicationConfig(loaded.CheckInterval == 2000
            && loaded.RetrySequence == "1, 10, 60"
            && loaded.RetryDelayArray.Length == 3
            && loaded.LogDirectory == defaultLogDirectory
            && loaded.GracefulStopSeconds == 3
            && !loaded.ShowAtStartup,
            "损坏或越界的运行参数没有逐字段回退默认值")

        candidate := settingsService.CreateDefaults()
        candidate.CheckInterval := 750
        candidate.RetrySequence := "1, 2"
        candidate.ShowAtStartup := true
        candidate.LogDirectory := " D:\Logs "
        candidate.EverythingMaxResults := 120
        saved := settingsService.Save(candidate)
        runtime := {}
        settingsService.Apply(runtime, saved)
        AssertApplicationConfig(runtime.checkInterval == 750
            && runtime.retryDelayArray.Length == 2
            && runtime.retryDelayArray[2] == 2000
            && runtime.showAtStartup
            && runtime.logDirectory == "D:\Logs"
            && repository.Read("Settings", "EverythingMaxResults", "")
                == "120",
            "有效运行参数没有统一校验、保存并应用到运行态")

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
        AssertApplicationConfig(layout.Width == 730 && layout.Height == 530
            && layout.Column1 == 500 && layout.Column2 == 250,
            "损坏布局没有逐字段限制到安全默认值")
        savedLayout := layoutService.Save({Width: 900, Height: 640,
            Column1: 610, Column2: 240})
        layoutRuntime := {}
        layoutService.Apply(layoutRuntime, savedLayout)
        AssertApplicationConfig(layoutRuntime.savedWidth == 900
            && layoutRuntime.savedHeight == 640
            && layoutRuntime.savedColumn1 == 610
            && layoutRuntime.savedColumn2 == 240,
            "有效布局没有统一保存并应用")
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
