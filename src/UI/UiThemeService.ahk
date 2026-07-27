; 界面主题服务。
; 主题分为用户请求值和当前实际值：auto 始终读取 Windows 的应用主题，
; light／dark 则固定使用对应配色。所有窗口只从这里取得颜色和原生主题参数，
; 因而热切换时不会残留某个窗口私有的深色常量。

class UiThemeService {
    static RequestedTheme := "auto"
    static ActualTheme := "light"

    static ReadConfiguredTheme(configPath) {
        configured := "auto"
        try configured := IniRead(configPath, "Settings", "Theme", "auto")
        return this.NormalizeRequestedTheme(configured, "auto")
    }

    static Configure(theme := "auto") {
        this.RequestedTheme := this.NormalizeRequestedTheme(theme, "auto")
        this.ActualTheme := this.ResolveActualTheme(this.RequestedTheme)
        this.ApplyProcessPreference()
        return this.ActualTheme
    }

    static GetRequestedTheme() {
        return this.RequestedTheme
    }

    static GetActualTheme() {
        return this.ActualTheme
    }

    static IsDark() {
        return this.GetActualTheme() == "dark"
    }

    static NormalizeRequestedTheme(theme, fallback := "auto") {
        if this.TryNormalizeRequestedTheme(theme, &normalized)
            return normalized
        return fallback
    }

    static TryNormalizeRequestedTheme(theme, &normalized) {
        normalized := ""
        try themeText := StrLower(Trim(String(theme)))
        catch
            return false
        switch themeText {
            case "", "auto", "system", "follow-system":
                normalized := "auto"
            case "light", "白", "浅色":
                normalized := "light"
            case "dark", "黑", "深色":
                normalized := "dark"
            default:
                return false
        }
        return true
    }

    static ResolveActualTheme(requestedTheme := "") {
        requestedTheme := this.NormalizeRequestedTheme(
            requestedTheme == "" ? this.RequestedTheme : requestedTheme,
            "auto")
        if requestedTheme != "auto"
            return requestedTheme
        return this.ReadSystemTheme()
    }

    static ReadSystemTheme() {
        ; AppsUseLightTheme 是 Windows 10／11 的应用主题开关；读取失败时
        ; 采用浅色作为保守回退，避免在新系统上突然显示为纯黑界面。
        try value := Integer(RegRead(
            "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize",
            "AppsUseLightTheme", 1))
        catch
            return "light"
        return value == 0 ? "dark" : "light"
    }

    static HandleSystemSettingChange() {
        if this.RequestedTheme != "auto"
            return false
        newTheme := this.ReadSystemTheme()
        if newTheme == this.ActualTheme
            return false
        this.ActualTheme := newTheme
        this.ApplyProcessPreference()
        return true
    }

    static ApplyProcessPreference() {
        if VerCompare(A_OSVersion, "10.0.17763") < 0
            return false
        preferredAppMode := this.GetUxThemeFunction(135)
        if !preferredAppMode
            return false
        ; 1903+：PreferredAppMode 中 2 是强制深色，3 是强制浅色。
        ; 1809：同一序号是 AllowDarkModeForApp(bool)，只传递是否深色。
        mode := VerCompare(A_OSVersion, "10.0.18362") >= 0
            ? (this.IsDark() ? 2 : 3) : (this.IsDark() ? 1 : 0)
        try DllCall(preferredAppMode, "Int", mode)
        catch
            return false
        return true
    }

    static GetUxThemeFunction(ordinal) {
        ; UxTheme 的深浅模式接口没有公开名称，只能按序号解析。模块句柄和
        ; 回调地址在进程内稳定，集中缓存可避免每个窗口、列表和选择器重复
        ; GetModuleHandle／GetProcAddress，也让不可用系统统一安全回退。
        static moduleHandle := 0
        static callbacks := Map()
        try ordinal := Integer(ordinal)
        catch
            return 0
        if callbacks.Has(ordinal)
            return callbacks[ordinal]
        if !moduleHandle {
            try moduleHandle := DllCall("kernel32\GetModuleHandleW",
                "WStr", "uxtheme.dll", "Ptr")
            if !moduleHandle {
                ; 缓存的 LoadLibrary 引用随进程退出释放；这里只会执行一次，
                ; 不会随窗口反复打开产生模块引用泄漏。
                try moduleHandle := DllCall("kernel32\LoadLibraryW",
                    "WStr", "uxtheme.dll", "Ptr")
            }
        }
        callback := 0
        if moduleHandle {
            try callback := DllCall("kernel32\GetProcAddress",
                "Ptr", moduleHandle, "Ptr", ordinal, "Ptr")
        }
        callbacks[ordinal] := callback
        return callback
    }

    static AllowDarkModeForWindow(hwnd, dark := "") {
        if !hwnd || VerCompare(A_OSVersion, "10.0.17763") < 0
            return false
        if dark == ""
            dark := this.IsDark()
        callback := this.GetUxThemeFunction(133)
        if !callback
            return false
        try return !!DllCall(callback, "Ptr", hwnd, "Int", dark ? 1 : 0,
            "Int")
        catch
            return false
    }

    static Color(name) {
        palette := this.IsDark() ? this.DarkPalette() : this.LightPalette()
        key := String(name)
        return palette.Has(key) ? palette[key] : "000000"
    }

    static DarkPalette() {
        palette := Map()
        palette.CaseSense := "On"
        for pair in [
            ["Window", "1E1E1E"], ["Surface", "252526"], ["Input", "252526"],
            ["Toolbar", "333333"], ["Divider", "3A3A3A"], ["Tab", "2D2D30"],
            ["Menu", "2B2B2B"], ["MenuHover", "414141"],
            ["TabActive", "005A9E"], ["Text", "FFFFFF"], ["MutedText", "B8BAB9"],
            ["HintText", "AFAFAF"], ["Link", "4EA1FF"], ["Primary", "0078D7"],
            ["Add", "3F6B5B"], ["Delete", "6B4B4B"], ["DeleteDisabled", "554B4B"],
            ["Pause", "6B6244"], ["PauseDisabled", "555148"],
            ["Tooltip", "202020"], ["TooltipText", "E5E5E5"], ["ReadonlyText", "D8D8D8"],
            ["DisabledText", "B8BAB9"], ["ButtonText", "FFFFFF"],
            ["ToolbarText", "FFFFFF"],
            ["DisabledButtonText", "D8D8D8"],
            ["TabText", "E5E5E5"], ["TabActiveText", "FFFFFF"]
        ]
            palette[pair[1]] := pair[2]
        return palette
    }

    static LightPalette() {
        palette := Map()
        palette.CaseSense := "On"
        ; 参考 Fluent 与 Primer 的浅色层级：冷调画布承载近白表面，输入框再用
        ; 纯白抬高一层；次要按钮使用明确的蓝灰色，而不是无倾向的中性灰。
        for pair in [
            ["Window", "F1F5F9"], ["Surface", "F8FAFC"], ["Input", "FFFFFF"],
            ["Toolbar", "D0DEEC"], ["Divider", "C9D5E3"], ["Tab", "E1EAF4"],
            ["Menu", "F8FAFC"], ["MenuHover", "DFEAF5"],
            ["TabActive", "0F6CBD"], ["Text", "1E293B"], ["MutedText", "526170"],
            ["HintText", "64748B"], ["Link", "0969DA"], ["Primary", "0F6CBD"],
            ["Add", "4B7F6B"], ["Delete", "A95F5F"], ["DeleteDisabled", "787676"],
            ["Pause", "8C7138"], ["PauseDisabled", "777671"],
            ["Tooltip", "F8FAFC"], ["TooltipText", "1E293B"], ["ReadonlyText", "334155"],
            ["DisabledText", "667085"], ["ButtonText", "FFFFFF"],
            ["ToolbarText", "334155"],
            ["DisabledButtonText", "FFFFFF"],
            ["TabText", "334155"], ["TabActiveText", "FFFFFF"]
        ]
            palette[pair[1]] := pair[2]
        return palette
    }

    static GetComboThemeName() {
        return this.IsDark() ? "DarkMode_CFD" : "CFD"
    }

    static GetExplorerThemeName() {
        return this.IsDark() ? "DarkMode_Explorer" : "Explorer"
    }

    static GetListThemeName() {
        return this.IsDark() ? "DarkMode_Explorer" : "Explorer"
    }
}
