#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证主题请求值、系统跟随解析和明暗调色板保持稳定，且无效配置不会进入运行态。

#Include ..\..\src\UI\UiThemeService.ahk

AssertUiTheme(condition, message) {
    if !condition
        throw Error(message)
}

ThemeRelativeLuminance(hexColor) {
    channels := []
    Loop 3 {
        channel := Integer("0x" SubStr(hexColor, (A_Index - 1) * 2 + 1,
            2)) / 255
        channels.Push(channel <= 0.04045 ? channel / 12.92
            : ((channel + 0.055) / 1.055) ** 2.4)
    }
    return channels[1] * 0.2126 + channels[2] * 0.7152
        + channels[3] * 0.0722
}

ThemeContrastRatio(firstColor, secondColor) {
    firstLuminance := ThemeRelativeLuminance(firstColor)
    secondLuminance := ThemeRelativeLuminance(secondColor)
    return (Max(firstLuminance, secondLuminance) + 0.05)
        / (Min(firstLuminance, secondLuminance) + 0.05)
}

ThemeColorSaturation(hexColor) {
    channels := []
    Loop 3
        channels.Push(Integer("0x" SubStr(hexColor,
            (A_Index - 1) * 2 + 1, 2)) / 255)
    maximum := Max(channels*)
    minimum := Min(channels*)
    if maximum == minimum
        return 0
    return (maximum - minimum)
        / (1 - Abs(maximum + minimum - 1))
}

RunUiThemeServiceTests() {
    AssertUiTheme(UiThemeService.NormalizeRequestedTheme("AUTO") == "auto"
        && UiThemeService.NormalizeRequestedTheme("light") == "light"
        && UiThemeService.NormalizeRequestedTheme("深色") == "dark"
        && UiThemeService.NormalizeRequestedTheme("unsupported") == "auto",
        "主题请求值没有正确规范化")

    invalidAccepted := UiThemeService.TryNormalizeRequestedTheme(
        "unsupported", &invalidTheme)
    AssertUiTheme(!invalidAccepted && invalidTheme == "",
        "无效主题请求仍被接受")

    UiThemeService.Configure("light")
    lightWindow := UiThemeService.Color("Window")
    lightSurface := UiThemeService.Color("Surface")
    AssertUiTheme(UiThemeService.GetRequestedTheme() == "light"
        && UiThemeService.GetActualTheme() == "light"
        && !UiThemeService.IsDark()
        && lightWindow != lightSurface,
        "浅色主题状态或表面层级错误")
    AssertUiTheme(lightWindow != "FFFFFF" && lightSurface != "FFFFFF"
        && UiThemeService.Color("Tab") != "FFFFFF",
        "浅色主题退化为纯白背景或无层级灰色")
    for contrastPair in [
        ["Text", "Window"], ["Text", "Surface"],
        ["MutedText", "Surface"], ["HintText", "Input"],
        ["ToolbarText", "Toolbar"], ["ButtonText", "Primary"],
        ["ButtonText", "Add"], ["ButtonText", "Delete"],
        ["ButtonText", "Pause"], ["TabText", "Tab"],
        ["TabActiveText", "TabActive"],
        ["HoverPreviewText", "HoverPreview"],
        ["DisabledButtonText", "DeleteDisabled"],
        ["DisabledButtonText", "PauseDisabled"]
    ] {
        ratio := ThemeContrastRatio(UiThemeService.Color(contrastPair[1]),
            UiThemeService.Color(contrastPair[2]))
        AssertUiTheme(ratio >= 4.5,
            "浅色主题文字对比度不足：" contrastPair[1] "/"
                contrastPair[2] "=" Round(ratio, 2))
    }
    AssertUiTheme(UiThemeService.Color("Toolbar") == "D0DEEC"
        && UiThemeService.Color("ToolbarText") == "334155",
        "浅色主题的次要按钮没有使用浅蓝灰背景与深色文字")
    hoverPreviewContrast := ThemeContrastRatio(
        UiThemeService.Color("HoverPreviewText"),
        UiThemeService.Color("HoverPreview"))
    AssertUiTheme(UiThemeService.Color("HoverPreview") == "E2E8F0"
        && UiThemeService.Color("HoverPreviewText") == "0F172A"
        && Round(hoverPreviewContrast, 2) == 14.48,
        "浅色悬停预览没有使用 14.48:1 的指定灰蓝配色")
    AssertUiTheme(UiThemeService.Color("DeleteDisabled") == "787676"
        && UiThemeService.Color("PauseDisabled") == "777671"
        && ThemeColorSaturation(UiThemeService.Color("DeleteDisabled"))
            < ThemeColorSaturation(UiThemeService.Color("Delete")) * 0.1
        && ThemeColorSaturation(UiThemeService.Color("PauseDisabled"))
            < ThemeColorSaturation(UiThemeService.Color("Pause")) * 0.1,
        "浅色主题的删除／暂停不可用色没有明显灰化")
    sequenceKeys := []
    for preset in MainSequenceColorPalette.Presets() {
        sequenceKeys.Push(preset.Key)
        AssertUiTheme(MainSequenceColorPalette.NormalizeKey(
                StrUpper(preset.Key)) == preset.Key
            && RegExMatch(MainSequenceColorPalette.Color(preset.Key),
                "^[0-9A-F]{6}$"),
            "浅色序号圆点预设无效：" preset.Key)
    }
    AssertUiTheme(sequenceKeys.Length == 7
        && MainSequenceColorPalette.NormalizeKey("unknown") == "",
        "序号圆点色板数量或无效值回退错误")

    UiThemeService.Configure("dark")
    AssertUiTheme(UiThemeService.GetRequestedTheme() == "dark"
        && UiThemeService.GetActualTheme() == "dark"
        && UiThemeService.IsDark()
        && UiThemeService.Color("Window") != lightWindow
        && UiThemeService.Color("Surface") != lightSurface,
        "深色主题状态或调色板错误")
    AssertUiTheme(UiThemeService.Color("Delete") == "6B4B4B"
        && UiThemeService.Color("Pause") == "6B6244"
        && UiThemeService.Color("DeleteDisabled") == "554B4B"
        && UiThemeService.Color("PauseDisabled") == "555148"
        && UiThemeService.Color("Delete")
            != UiThemeService.Color("DeleteDisabled")
        && UiThemeService.Color("Pause")
            != UiThemeService.Color("PauseDisabled"),
        "深色主题的删除／暂停可用色与不可用色缺少明确区分")
    AssertUiTheme(UiThemeService.Color("HoverPreview")
            == UiThemeService.Color("Tooltip")
        && UiThemeService.Color("HoverPreviewText")
            == UiThemeService.Color("TooltipText"),
        "新增浅色悬停预览适配改变了深色提示配色")
    for preset in MainSequenceColorPalette.Presets()
        AssertUiTheme(RegExMatch(MainSequenceColorPalette.Color(preset.Key),
            "^[0-9A-F]{6}$"), "深色序号圆点预设无效：" preset.Key)
    AssertUiTheme(!UiThemeService.HandleSystemSettingChange(),
        "固定主题仍响应了系统主题变化")

    processId := DllCall("kernel32\GetCurrentProcessId", "UInt")
    configPath := A_Temp "\watchdog-theme-" processId ".ini"
    try {
        try FileDelete(configPath)
        IniWrite("light", configPath, "Settings", "Theme")
        AssertUiTheme(UiThemeService.ReadConfiguredTheme(configPath)
            == "light", "主题配置读取失败")
        IniWrite("invalid", configPath, "Settings", "Theme")
        AssertUiTheme(UiThemeService.ReadConfiguredTheme(configPath)
            == "auto", "无效主题配置没有回退为跟随系统")
    } finally {
        try FileDelete(configPath)
        UiThemeService.Configure("auto")
    }
}

RunUiThemeServiceTests()
FileAppend("UI_THEME_SERVICE_TESTS|PASS`n", "*")
ExitApp(0)
