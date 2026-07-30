; 应用文本地化服务。
; 中文原文既是默认文本也是稳定键；用户可选择跟随系统或固定语言。显示设置在进程内
; 原位切换，既有守护对象和调度任务保持不变，只刷新窗口、菜单、托盘与动态状态文案。

class LocalizationService {
    static RequestedLanguage := "auto"
    static Language := ""
    static Catalogs := ""
    static RequestedUiFont := "auto"
    static UiFont := ""
    static InstalledUiFonts := ""
    static FontEnumerationTarget := ""
    static LoadedPrivateUiFonts := ""
    static LoadedPrivateUiFontPaths := ""
    static FailedPrivateUiFonts := ""
    static RenderedSourceSpecCache := ""

    static Configure(language := "auto") {
        requested := Trim(String(language))
        if requested == ""
            requested := "auto"
        this.RequestedLanguage := this.NormalizeRequestedLanguage(requested,
            "auto")
        this.Language := this.RequestedLanguage == "auto"
            ? this.DetectSystemLanguage() : this.RequestedLanguage
        this.GetCatalog(this.Language)
        ; 语言在同一进程内重新配置时，也要同步刷新“跟随语言默认”的实际字体；
        ; 用户明确选择的字体则保持不变。热切换事务随后把结果应用到既有控件。
        if this.UiFont != "" && this.RequestedUiFont == "auto"
            this.UiFont := this.GetLanguageDefaultUiFontName(this.Language)
        return this.Language
    }

    static ReadConfiguredLanguage(configPath) {
        configured := "auto"
        try configured := IniRead(configPath, "Settings", "UiLanguage",
            "auto")
        return this.NormalizeRequestedLanguage(configured, "auto")
    }

    static ReadConfiguredUiFont(configPath) {
        configured := "auto"
        try configured := IniRead(configPath, "Settings", "UiFont", "auto")
        return this.NormalizeRequestedUiFont(configured, "auto")
    }

    static DetectSystemLanguage() {
        languageId := 0
        try languageId := DllCall("kernel32\GetUserDefaultUILanguage",
            "UShort")
        if !languageId {
            try languageId := Integer("0x" A_Language)
        }
        ; 中文必须使用完整语言 ID 区分简体、港繁、台繁与澳门繁体；仅查看
        ; 主语言 ID 时，这些环境都会被错误归入同一种中文。
        switch languageId {
            case 0x0404: return "zh-TW"
            case 0x0C04, 0x1404: return "zh-HK"
            case 0x0804, 0x1004: return "zh-CN"
        }
        primaryLanguage := languageId ? languageId & 0x03FF : 0
        switch primaryLanguage {
            case 0x04: return "zh-CN"
            case 0x09: return "en-US"
            case 0x11: return "ja-JP"
            case 0x12: return "ko-KR"
            case 0x0A: return "es-ES"
            case 0x0C: return "fr-FR"
            case 0x16: return "pt-BR"
            case 0x07: return "de-DE"
            case 0x19: return "ru-RU"
            case 0x2A: return "vi-VN"
            case 0x10: return "it-IT"
            default: return "en-US"
        }
    }

    static NormalizeRequestedLanguage(language, fallback := "auto") {
        if this.TryNormalizeRequestedLanguage(language, &normalized)
            return normalized
        return fallback
    }

    static TryNormalizeRequestedLanguage(language, &normalized) {
        normalized := ""
        try languageText := StrLower(Trim(String(language)))
        catch
            return false
        if languageText == "auto" {
            normalized := "auto"
            return true
        }
        languageText := StrReplace(languageText, "_", "-")
        if RegExMatch(languageText,
                "^zh-(?:hant-)?(?:hk|mo)(?:-|$)")
            normalized := "zh-HK"
        else if languageText == "zh-hant"
            || RegExMatch(languageText, "^zh-(?:hant-)?tw(?:-|$)")
            normalized := "zh-TW"
        else if RegExMatch(languageText, "^zh(?:-|$)")
            normalized := "zh-CN"
        else if RegExMatch(languageText, "^en(?:-|$)")
            normalized := "en-US"
        else if RegExMatch(languageText, "^ja(?:-|$)")
            normalized := "ja-JP"
        else if RegExMatch(languageText, "^ko(?:-|$)")
            normalized := "ko-KR"
        else if RegExMatch(languageText, "^es(?:-|$)")
            normalized := "es-ES"
        else if RegExMatch(languageText, "^fr(?:-|$)")
            normalized := "fr-FR"
        else if RegExMatch(languageText, "^pt(?:-|$)")
            normalized := "pt-BR"
        else if RegExMatch(languageText, "^de(?:-|$)")
            normalized := "de-DE"
        else if RegExMatch(languageText, "^ru(?:-|$)")
            normalized := "ru-RU"
        else if RegExMatch(languageText, "^vi(?:-|$)")
            normalized := "vi-VN"
        else if RegExMatch(languageText, "^it(?:-|$)")
            normalized := "it-IT"
        else
            return false
        return true
    }

    static GetSupportedLanguageCodes(includeAuto := false) {
        ; 前四项固定；其余先按亚洲、欧洲分组，再按 Ethnologue 2026 的
        ; 全球总使用人口由多到少排列。
        codes := ["zh-CN", "zh-HK", "zh-TW", "en-US", "ja-JP",
            "vi-VN", "ko-KR", "es-ES", "fr-FR", "pt-BR", "ru-RU",
            "de-DE", "it-IT"]
        if includeAuto
            codes.InsertAt(1, "auto")
        return codes
    }

    static GetLanguageChoices() {
        return [
            {Code: "auto", Label: this.Translate("跟随系统")},
            {Code: "zh-CN", Label: "简体中文"},
            {Code: "zh-HK", Label: "繁體中文（香港）"},
            {Code: "zh-TW", Label: "繁體中文（台灣）"},
            {Code: "en-US", Label: "English"},
            {Code: "ja-JP", Label: "日本語"},
            {Code: "vi-VN", Label: "Tiếng Việt"},
            {Code: "ko-KR", Label: "한국어"},
            {Code: "es-ES", Label: "Español"},
            {Code: "fr-FR", Label: "Français"},
            {Code: "pt-BR", Label: "Português（Brasil）"},
            {Code: "ru-RU", Label: "Русский"},
            {Code: "de-DE", Label: "Deutsch"},
            {Code: "it-IT", Label: "Italiano"}
        ]
    }

    static GetLanguage() {
        if this.Language == ""
            this.Configure()
        return this.Language
    }

    static GetRequestedLanguage() {
        if this.Language == ""
            this.Configure()
        return this.RequestedLanguage
    }

    static IsChinese() {
        return RegExMatch(this.GetLanguage(), "^zh-") != 0
    }

    static UsesCompactLayout() {
        language := this.GetLanguage()
        return RegExMatch(language, "^zh-") || language == "ja-JP"
            || language == "ko-KR"
    }

    static GetLanguageDefaultUiFontName(language := "") {
        spec := this.GetLanguageUiFontSpec(language)
        return this.ResolveUiFontSpec(spec)
    }

    static GetLanguageSystemUiFontName(language := "") {
        ; 按钮、标签和状态栏属于 Windows 界面骨架，不跟随用户选择的内容字体。
        ; 这里只解析系统自带字体，绝不触发随包字体加载。
        spec := this.GetLanguageUiFontSpec(language)
        installedName := this.FindInstalledUiFontName(spec.System)
        if installedName != ""
            return installedName
        installedName := this.FindInstalledUiFontName("Segoe UI")
        if installedName != ""
            return installedName
        installedFonts := this.GetInstalledUiFontNames()
        return installedFonts.Length ? installedFonts[1] : "Segoe UI"
    }

    static ResolveUiFontSpec(spec) {
        installedName := this.FindInstalledUiFontName(spec.Primary)
        if installedName != ""
            return installedName
        ; 首选字体可以由一个或多个文件组成，例如 SF Pro Text 的常规和粗体。
        ; 仅在系统没有安装目标家族时加载整组，避免覆盖用户自己的字体版本。
        if spec.HasOwnProp("PrimaryAssets")
            && this.EnsurePackagedUiFontAvailable(spec.Primary,
                spec.PrimaryAssets) {
            installedName := this.FindInstalledUiFontName(spec.Primary)
            if installedName != ""
                return installedName
        }
        if this.EnsurePackagedUiFontAvailable(spec.Fallback,
                spec.Asset) {
            installedName := this.FindInstalledUiFontName(spec.Fallback)
            if installedName != ""
                return installedName
        }
        installedName := this.FindInstalledUiFontName(spec.System)
        if installedName != ""
            return installedName
        installedName := this.FindInstalledUiFontName("Segoe UI")
        if installedName != ""
            return installedName
        installedFonts := this.GetInstalledUiFontNames()
        return installedFonts.Length ? installedFonts[1] : "Segoe UI"
    }

    static GetLanguageUiFontSpec(language := "") {
        language := language == "" ? this.GetLanguage()
            : this.ResolveActualLanguage(language)
        switch language {
            case "zh-CN":
                return {Primary: "PingFang SC",
                    PrimaryAssets: ["PingFang.ttc"],
                    Fallback: "Noto Sans CJK SC",
                    Asset: "NotoSansCJK.ttc",
                    System: "Microsoft YaHei UI"}
            case "zh-HK":
                return {Primary: "PingFang HK",
                    PrimaryAssets: ["PingFang.ttc"],
                    Fallback: "Noto Sans CJK HK",
                    Asset: "NotoSansCJK.ttc",
                    System: "Microsoft JhengHei UI"}
            case "zh-TW":
                return {Primary: "PingFang TC",
                    PrimaryAssets: ["PingFang.ttc"],
                    Fallback: "Noto Sans CJK TC",
                    Asset: "NotoSansCJK.ttc",
                    System: "Microsoft JhengHei UI"}
            case "ja-JP":
                return {Primary: "Harano Aji Gothic",
                    PrimaryAssets: ["HaranoAjiGothic-Regular.otf"],
                    Fallback: "Noto Sans CJK JP",
                    Asset: "NotoSansCJK.ttc",
                    System: "Yu Gothic UI"}
            case "ko-KR":
                return {Primary: "AppleSDGothicNeoR00",
                    PrimaryAssets: ["AppleSDGothicNeo-Regular.ttf"],
                    Fallback: "Noto Sans CJK KR",
                    Asset: "NotoSansCJK.ttc",
                    System: "Malgun Gothic"}
            default:
                return {Primary: "SF Pro Text",
                    PrimaryAssets: ["SF-Pro-Text-Regular.otf",
                        "SF-Pro-Text-Bold.otf"],
                    Fallback: "Noto Sans",
                    Asset: "NotoSans-Variable.ttf",
                    System: "Segoe UI"}
        }
    }

    static ConfigureUiFont(fontName := "auto") {
        this.RequestedUiFont := this.NormalizeRequestedUiFont(fontName,
            "auto")
        this.UiFont := this.RequestedUiFont == "auto"
            ? this.GetLanguageDefaultUiFontName() : this.RequestedUiFont
        return this.UiFont
    }

    static GetUiFontName() {
        if this.UiFont == ""
            this.ConfigureUiFont()
        return this.UiFont
    }

    static GetRequestedUiFont() {
        if this.UiFont == ""
            this.ConfigureUiFont()
        return this.RequestedUiFont
    }

    static NormalizeRequestedUiFont(fontName, fallback := "auto") {
        if this.TryNormalizeRequestedUiFont(fontName, &normalized)
            return normalized
        return fallback
    }

    static TryNormalizeRequestedUiFont(fontName, &normalized) {
        normalized := ""
        try fontText := Trim(String(fontName))
        catch
            return false
        if fontText == "" || StrLower(fontText) == "auto" {
            normalized := "auto"
            return true
        }
        if StrLen(fontText) > 127 || InStr(fontText, "`r")
            || InStr(fontText, "`n")
            return false
        installedName := this.FindInstalledUiFontName(fontText)
        if installedName != "" {
            normalized := installedName
            return true
        }
        if this.EnsurePackagedUiFontAvailable(fontText) {
            installedName := this.FindInstalledUiFontName(fontText)
            if installedName != "" {
                normalized := installedName
                return true
            }
        }
        return false
    }

    static FindInstalledUiFontName(fontName) {
        targetName := Trim(String(fontName))
        if targetName == ""
            return ""
        for installedFont in this.GetInstalledUiFontNames() {
            if StrLower(installedFont) == StrLower(targetName)
                return installedFont
        }
        return ""
    }

    static EnsurePackagedUiFontAvailable(fontName, assetName := "") {
        if this.FindInstalledUiFontName(fontName) != ""
            return true
        if assetName == ""
            assetName := this.GetPackagedUiFontAssetName(fontName)
        if assetName == ""
            return false
        if Type(assetName) == "Array" {
            if assetName.Length == 0
                return false
            for packagedAssetName in assetName {
                if !this.LoadPrivateUiFontAsset(packagedAssetName)
                    return false
            }
        } else if !this.LoadPrivateUiFontAsset(assetName) {
            return false
        }
        return this.FindInstalledUiFontName(fontName) != ""
    }

    static GetPackagedUiFontAssetName(fontName) {
        switch StrLower(Trim(String(fontName))) {
            case "pingfang sc", "pingfang hk", "pingfang tc":
                return ["PingFang.ttc"]
            case "sf pro text":
                return ["SF-Pro-Text-Regular.otf",
                    "SF-Pro-Text-Bold.otf"]
            case "applesdgothicneor00":
                return ["AppleSDGothicNeo-Regular.ttf"]
            case "harano aji gothic":
                return ["HaranoAjiGothic-Regular.otf"]
            case "noto sans": return "NotoSans-Variable.ttf"
            case "noto sans cjk sc", "noto sans cjk hk",
                "noto sans cjk tc", "noto sans cjk jp",
                "noto sans cjk kr":
                return "NotoSansCJK.ttc"
            default: return ""
        }
    }

    static LoadPrivateUiFontAsset(assetName, assetDirectory := "") {
        assetName := Trim(String(assetName))
        if !RegExMatch(assetName, "^[A-Za-z0-9._-]+$")
            return false
        if assetDirectory == ""
            assetDirectory := this.GetUiFontAssetDirectory()
        fontPath := RTrim(String(assetDirectory), "\/") "\" assetName
        return this.LoadPrivateUiFontPath(fontPath)
    }

    static GetUiFontAssetDirectory(startDirectory := "") {
        ; 正式入口的脚本目录就是项目或安装根目录；独立核心和 GUI 测试则位于
        ; tests 的下一层。逐级寻找固定资源目录，使同一生产代码无需测试专用路径。
        searchDirectory := startDirectory == "" ? A_ScriptDir
            : RTrim(String(startDirectory), "\/")
        Loop 4 {
            candidate := searchDirectory "\assets\fonts"
            if DirExist(candidate)
                return candidate
            SplitPath(searchDirectory, , &parentDirectory)
            if parentDirectory == "" || parentDirectory == searchDirectory
                break
            searchDirectory := parentDirectory
        }
        return A_ScriptDir "\assets\fonts"
    }

    static ClearFailedPrivateUiFontCache() {
        ; 失败缓存用于避免缺失外置资源在界面交互中被反复探测。用户运行期间补回
        ; assets\fonts 后，设置页字体下拉框刷新会调用这里，让补齐的文件能被重试。
        this.EnsurePrivateUiFontStores()
        this.FailedPrivateUiFonts := Map()
        this.FailedPrivateUiFonts.CaseSense := "Off"
    }

    static LoadPrivateUiFontPath(fontPath) {
        fontPath := this.NormalizeUiFontResourcePath(fontPath)
        this.EnsurePrivateUiFontStores()
        if this.LoadedPrivateUiFonts.Has(fontPath)
            return true
        if this.FailedPrivateUiFonts.Has(fontPath)
            return false

        previousCritical := A_IsCritical
        Critical("On")
        try {
            if this.LoadedPrivateUiFonts.Has(fontPath)
                return true
            if this.FailedPrivateUiFonts.Has(fontPath)
                return false
            if !FileExist(fontPath) {
                this.FailedPrivateUiFonts[fontPath] := true
                return false
            }
            loadedFaces := DllCall("gdi32\AddFontResourceExW",
                "WStr", fontPath, "UInt", 0x10, "Ptr", 0, "Int")
            if loadedFaces <= 0 {
                this.FailedPrivateUiFonts[fontPath] := true
                return false
            }
            this.LoadedPrivateUiFonts[fontPath] := true
            this.LoadedPrivateUiFontPaths.Push(fontPath)
            ; 私有字体只对本进程可见。清空枚举缓存后，后续 GUI 创建与字体菜单
            ; 会立即看到新家族，不需要安装字体、广播系统消息或重启小助手。
            this.InstalledUiFonts := ""
            return true
        } finally Critical(previousCritical ? previousCritical : "Off")
    }

    static NormalizeUiFontResourcePath(fontPath) {
        fontPath := String(fontPath)
        fullPathBuffer := Buffer(32768 * 2, 0)
        pathLength := DllCall("kernel32\GetFullPathNameW", "WStr",
            fontPath, "UInt", 32768, "Ptr", fullPathBuffer, "Ptr", 0,
            "UInt")
        if pathLength && pathLength < 32768
            return StrGet(fullPathBuffer, pathLength, "UTF-16")
        return fontPath
    }

    static EnsurePrivateUiFontStores() {
        if !IsObject(this.LoadedPrivateUiFonts) {
            this.LoadedPrivateUiFonts := Map()
            this.LoadedPrivateUiFonts.CaseSense := "Off"
        }
        if !IsObject(this.LoadedPrivateUiFontPaths)
            this.LoadedPrivateUiFontPaths := []
        if !IsObject(this.FailedPrivateUiFonts) {
            this.FailedPrivateUiFonts := Map()
            this.FailedPrivateUiFonts.CaseSense := "Off"
        }
    }

    static GetLoadedPrivateUiFontResourceCount() {
        return IsObject(this.LoadedPrivateUiFontPaths)
            ? this.LoadedPrivateUiFontPaths.Length : 0
    }

    static ShutdownUiFonts(*) {
        if !IsObject(this.LoadedPrivateUiFontPaths)
            return
        previousCritical := A_IsCritical
        Critical("On")
        try {
            Loop this.LoadedPrivateUiFontPaths.Length {
                pathIndex := this.LoadedPrivateUiFontPaths.Length
                    - A_Index + 1
                fontPath := this.LoadedPrivateUiFontPaths[pathIndex]
                try DllCall("gdi32\RemoveFontResourceExW",
                    "WStr", fontPath, "UInt", 0x10, "Ptr", 0, "Int")
            }
            this.LoadedPrivateUiFonts := ""
            this.LoadedPrivateUiFontPaths := ""
            this.FailedPrivateUiFonts := ""
            this.InstalledUiFonts := ""
        } finally Critical(previousCritical ? previousCritical : "Off")
    }

    static GetInstalledUiFontNames() {
        if IsObject(this.InstalledUiFonts)
            return this.InstalledUiFonts
        fontSet := Map()
        fontSet.CaseSense := "Off"
        screenDc := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
        if screenDc {
            logFont := Buffer(92, 0) ; LOGFONTW：名称字段从第 28 字节开始。
            NumPut("UChar", 1, logFont, 23) ; DEFAULT_CHARSET：枚举全部常规字体族。
            this.FontEnumerationTarget := fontSet
            enumCallback := CallbackCreate(
                ObjBindMethod(this, "CollectInstalledUiFont"), "Fast", 4)
            try DllCall("gdi32\EnumFontFamiliesExW", "Ptr", screenDc,
                "Ptr", logFont, "Ptr", enumCallback, "Ptr", 0,
                "UInt", 0, "Int")
            finally {
                CallbackFree(enumCallback)
                this.FontEnumerationTarget := ""
                DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDc)
            }
        }
        ; 部分从 macOS 字体文件安装到 Windows 的苹方家族不会被
        ; EnumFontFamiliesExW 完整列出。逐个创建并反查实际字体面，只有没有
        ; 被 GDI 替换成系统兜底的家族才加入可用集合。
        for knownFontName in ["PingFang SC", "PingFang HK", "PingFang TC",
            "Harano Aji Gothic", "AppleSDGothicNeoR00", "SF Pro Text"] {
            if this.ProbeUiFontFamily(knownFontName)
                fontSet[knownFontName] := true
        }
        namesText := ""
        for fontName in fontSet
            namesText .= fontName "`n"
        namesText := RTrim(namesText, "`n")
        names := namesText == "" ? []
            : StrSplit(Sort(namesText, "D`n"), "`n")
        this.InstalledUiFonts := names
        return names
    }

    static RefreshInstalledUiFontNames() {
        ; 字体可能在设置窗口保持打开期间被安装或卸载。这里显式丢弃枚举缓存，
        ; 并允许之前缺失的随包字体重试，然后重新查询 GDI 当前对本进程可见的
        ; 系统字体与随包私有字体。
        this.ClearFailedPrivateUiFontCache()
        this.InstalledUiFonts := ""
        return this.GetInstalledUiFontNames()
    }

    static ProbeUiFontFamily(fontName) {
        logFont := Buffer(92, 0)
        NumPut("Int", -16, logFont, 0)
        NumPut("Int", 400, logFont, 16)
        NumPut("UChar", 1, logFont, 23) ; DEFAULT_CHARSET：按字体自身字符集建立字体面。
        StrPut(String(fontName), logFont.Ptr + 28, 32, "UTF-16")
        fontHandle := DllCall("gdi32\CreateFontIndirectW", "Ptr", logFont,
            "Ptr")
        if !fontHandle
            return false
        deviceContext := DllCall("gdi32\CreateCompatibleDC", "Ptr", 0,
            "Ptr")
        if !deviceContext {
            DllCall("gdi32\DeleteObject", "Ptr", fontHandle)
            return false
        }
        previousFont := DllCall("gdi32\SelectObject", "Ptr", deviceContext,
            "Ptr", fontHandle, "Ptr")
        try {
            faceBuffer := Buffer(128 * 2, 0)
            faceLength := DllCall("gdi32\GetTextFaceW", "Ptr", deviceContext,
                "Int", 128, "Ptr", faceBuffer, "Int")
            if faceLength <= 0
                return false
            resolvedName := StrGet(faceBuffer, "UTF-16")
            if StrLower(resolvedName) == StrLower(String(fontName))
                return true
            ; 苹方在 Windows GDI 中返回本地化家族名，英文家族名仍能正确创建
            ; 同一个字体面。只接受这三个已核验别名，避免把普通字体替换误判为可用。
            switch StrLower(String(fontName)) {
                case "pingfang sc": return resolvedName == "苹方-简"
                case "pingfang hk": return resolvedName == "苹方-港"
                case "pingfang tc": return resolvedName == "苹方-繁"
                default: return false
            }
        } finally {
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", deviceContext,
                    "Ptr", previousFont, "Ptr")
            DllCall("gdi32\DeleteDC", "Ptr", deviceContext)
            DllCall("gdi32\DeleteObject", "Ptr", fontHandle)
        }
    }

    static CollectInstalledUiFont(enumLogFontPtr, textMetricPtr,
        fontType, userData) {
        if !IsObject(this.FontEnumerationTarget)
            return 0
        try fontName := Trim(StrGet(enumLogFontPtr + 28, 32, "UTF-16"))
        catch
            return 1
        ; 名称以 @ 开头的是为竖排排版注册的镜像字体，不应出现在普通界面菜单。
        if fontName != "" && SubStr(fontName, 1, 1) != "@"
            this.FontEnumerationTarget[fontName] := true
        return 1
    }

    static EnsureCatalogStore() {
        if IsObject(this.Catalogs)
            return
        this.Catalogs := Map()
        this.Catalogs.CaseSense := "On"
    }

    static GetCatalog(language := "") {
        this.EnsureCatalogStore()
        language := language == "" ? this.GetLanguage()
            : this.NormalizeRequestedLanguage(language, "en-US")
        if language == "auto"
            language := this.DetectSystemLanguage()
        if this.Catalogs.Has(language)
            return this.Catalogs[language]
        if language == "zh-CN"
            catalog := Map()
        else {
            switch language {
                case "zh-HK": className := "TraditionalHongKongStrings"
                case "zh-TW": className := "TraditionalTaiwanStrings"
                case "en-US": className := "EnglishStrings"
                case "ja-JP": className := "JapaneseStrings"
                case "vi-VN": className := "VietnameseStrings"
                case "ko-KR": className := "KoreanStrings"
                case "es-ES": className := "SpanishStrings"
                case "fr-FR": className := "FrenchStrings"
                case "pt-BR": className := "PortugueseBrazilStrings"
                case "ru-RU": className := "RussianStrings"
                case "de-DE": className := "GermanStrings"
                case "it-IT": className := "ItalianStrings"
                default: className := "EnglishStrings"
            }
            catalog := this.CreateCatalogFromClassName(className)
        }
        this.Catalogs[language] := catalog
        return catalog
    }

    static CreateCatalogFromClassName(className) {
        ; 目录文件由不同入口按需包含。通过类名动态解析，避免未使用的
        ; 语言在 #Warn 下产生“从未赋值”警告；真正请求缺失目录时仍会报错。
        catalogClass := %className%
        return catalogClass.Create()
    }

    static GetAllTranslationCatalogs() {
        catalogs := []
        for language in this.GetSupportedLanguageCodes() {
            if language != "zh-CN"
                catalogs.Push(this.GetCatalog(language))
        }
        return catalogs
    }

    static Translate(chineseTemplate, values*) {
        template := String(chineseTemplate)
        catalog := this.GetCatalog()
        if catalog.Has(template)
            template := catalog[template]
        return values.Length ? Format(template, values*) : template
    }

    static TranslateRenderedTextBetweenLanguages(renderedText,
        fromLanguage, toLanguage) {
        text := String(renderedText)
        fromLanguage := this.ResolveActualLanguage(fromLanguage)
        toLanguage := this.ResolveActualLanguage(toLanguage)
        if text == "" || fromLanguage == toLanguage
            return text

        spec := this.GetRenderedTranslationSourceSpec(fromLanguage)
        if spec.Exact.Has(text) {
            translated := ""
            for sourceTemplate in spec.Exact[text] {
                candidate := this.GetTemplateForLanguage(sourceTemplate,
                    toLanguage)
                if translated == ""
                    translated := candidate
                else if translated != candidate
                    return text
            }
            return translated != "" ? translated : text
        }
        for patternSpec in spec.Patterns {
            if !RegExMatch(text, patternSpec.Pattern, &match)
                continue
            values := []
            for captureIndex, placeholderIndex in patternSpec.Placeholders {
                while values.Length < placeholderIndex
                    values.Push("")
                values[placeholderIndex] := match[captureIndex]
            }
            targetTemplate := this.GetTemplateForLanguage(
                patternSpec.Source, toLanguage)
            try return Format(targetTemplate, values*)
            catch
                return text
        }
        return text
    }

    static ResolveActualLanguage(language) {
        normalized := this.NormalizeRequestedLanguage(language, "en-US")
        return normalized == "auto" ? this.DetectSystemLanguage() : normalized
    }

    static GetTemplateForLanguage(sourceTemplate, language) {
        if language == "zh-CN"
            return sourceTemplate
        catalog := this.GetCatalog(language)
        return catalog.Has(sourceTemplate)
            ? catalog[sourceTemplate] : sourceTemplate
    }

    static GetRenderedTranslationSourceSpec(fromLanguage) {
        if !IsObject(this.RenderedSourceSpecCache) {
            this.RenderedSourceSpecCache := Map()
            this.RenderedSourceSpecCache.CaseSense := "On"
        }
        if this.RenderedSourceSpecCache.Has(fromLanguage)
            return this.RenderedSourceSpecCache[fromLanguage]

        sourceCatalog := this.GetEnglishCatalog()
        fromCatalog := fromLanguage == "zh-CN"
            ? "" : this.GetCatalog(fromLanguage)
        exact := Map()
        exact.CaseSense := "On"
        patterns := []
        for sourceTemplate, _ in sourceCatalog {
            fromTemplate := IsObject(fromCatalog)
                && fromCatalog.Has(sourceTemplate)
                ? fromCatalog[sourceTemplate] : sourceTemplate
            placeholderInfo := this.BuildRenderedTemplatePattern(fromTemplate)
            if !placeholderInfo.Placeholders.Length {
                if !exact.Has(fromTemplate)
                    exact[fromTemplate] := []
                sourceTemplates := exact[fromTemplate]
                found := false
                for existingTemplate in sourceTemplates {
                    if existingTemplate == sourceTemplate {
                        found := true
                        break
                    }
                }
                if !found
                    sourceTemplates.Push(sourceTemplate)
                continue
            }
            patterns.Push({
                Pattern: placeholderInfo.Pattern,
                Placeholders: placeholderInfo.Placeholders,
                Source: sourceTemplate
            })
        }
        spec := {Exact: exact, Patterns: patterns}
        this.RenderedSourceSpecCache[fromLanguage] := spec
        return spec
    }

    static BuildRenderedTemplatePattern(template) {
        pattern := "s)^"
        placeholderIndexes := []
        cursor := 1
        while RegExMatch(template, "\{(\d+)(?::[^}]*)?\}", &match,
            cursor) {
            pattern .= this.EscapeRegexLiteral(SubStr(template, cursor,
                match.Pos[0] - cursor)) "(.*?)"
            placeholderIndexes.Push(Integer(match[1]))
            cursor := match.Pos[0] + match.Len[0]
        }
        pattern .= this.EscapeRegexLiteral(SubStr(template, cursor)) "$"
        return {Pattern: pattern, Placeholders: placeholderIndexes}
    }

    static EscapeRegexLiteral(text) {
        ; \Q...\E 能一次保护标点、括号和 Emoji；极少出现的字面量 \E
        ; 需先结束引用、转义自身，再重新进入引用区。
        return "\Q" StrReplace(String(text), "\E", "\E\\E\Q") "\E"
    }

    static HasTranslation(chineseTemplate, language := "") {
        return this.GetCatalog(language).Has(String(chineseTemplate))
    }

    static GetEnglishCatalog() {
        return this.GetCatalog("en-US")
    }

    static TranslateDiagnostic(value) {
        text := String(value)
        if this.IsChinese() || text == ""
            return text
        ; 核心层保留稳定的中文语义值，到日志和对话框边界再按当前语言翻译。
        if this.HasTranslation(text)
            return this.Translate(text)
        fieldCountPattern := "^字段数量应为 " "(\d+)" "，实际为 "
            . "(\d+)$"
        if RegExMatch(text, fieldCountPattern, &fieldCountMatch) {
            return this.Translate("字段数量应为 {1}，实际为 {2}",
                fieldCountMatch[1], fieldCountMatch[2])
        }
        static prefixedDiagnostics := [
            ["缺少窗口布局字段", "缺少窗口布局字段：{1}"],
            ["窗口布局字段不是整数", "窗口布局字段不是整数：{1}"],
            ["窗口布局字段超出范围", "窗口布局字段超出范围：{1}"],
            ["缺少运行参数", "缺少运行参数：{1}"],
            ["运行参数不是整数", "运行参数不是整数：{1}"],
            ["运行参数超出范围", "运行参数超出范围：{1}"],
            ["运行参数不能为空", "运行参数不能为空：{1}"],
            ["运行参数不是支持的界面语言", "运行参数不是支持的界面语言：{1}"],
            ["运行参数不是支持的界面主题", "运行参数不是支持的界面主题：{1}"],
            ["无法生成守护对象快照", "无法生成守护对象快照：{1}"],
            ["恢复记录缺少字段", "恢复记录缺少字段：{1}"],
            ["缺少窗口生命周期回调", "缺少窗口生命周期回调：{1}"],
            ["不允许的升级保护阶段转换", "不允许的升级保护阶段转换：{1}"],
            ["缺少诊断信息提供器", "缺少诊断信息提供器：{1}"],
            ["无法写入诊断文件", "无法写入诊断文件：{1}"],
            ["无法收集此部分诊断信息", "无法收集此部分诊断信息：{1}"]
        ]
        for diagnostic in prefixedDiagnostics {
            prefix := diagnostic[1]
            if RegExMatch(text, "^" prefix "[：:]\s*(.*)$", &match)
                return this.Translate(diagnostic[2], match[1])
        }
        ; Windows、COM 与第三方组件的原始错误原样保留，便于搜索错误码。
        return text
    }
}

Tr(chineseTemplate, values*) {
    return LocalizationService.Translate(chineseTemplate, values*)
}

TrDiagnostic(value) {
    return LocalizationService.TranslateDiagnostic(value)
}
