#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证本地化词条的完整性、占位符契约和中英文切换。
; 测试直接扫描生产源码中的字面量模板，新增可见文案却忘记补英文时会立即失败。

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
#Include ..\..\src\Update\ApplicationVersionInfo.ahk

AssertLocalization(value, message) {
    if !value
        throw Error(message)
}

DecodeAhkStringLiteral(rawText) {
    decoded := ""
    index := 1
    while index <= StrLen(rawText) {
        character := SubStr(rawText, index, 1)
        if character != "``" {
            decoded .= character
            index++
            continue
        }
        index++
        if index > StrLen(rawText) {
            decoded .= "``"
            break
        }
        escaped := SubStr(rawText, index, 1)
        switch escaped {
            case "n": decoded .= "`n"
            case "r": decoded .= "`r"
            case "t": decoded .= "`t"
            case "b": decoded .= "`b"
            case "v": decoded .= "`v"
            case "a": decoded .= "`a"
            case "f": decoded .= "`f"
            default: decoded .= escaped
        }
        index++
    }
    return decoded
}

CollectLiteralLocalizationTemplates(sourceText, templates) {
    searchPosition := 1
    callPattern := 'i)\b(?:Tr|this\.Text)\s*\(\s*"'
    while RegExMatch(sourceText, callPattern, &callMatch,
        searchPosition) {
        contentStart := callMatch.Pos(0) + callMatch.Len(0)
        cursor := contentStart
        rawText := ""
        closed := false
        while cursor <= StrLen(sourceText) {
            character := SubStr(sourceText, cursor, 1)
            if character == '"' {
                closed := true
                break
            }
            if character == "``" && cursor < StrLen(sourceText) {
                rawText .= character SubStr(sourceText, cursor + 1, 1)
                cursor += 2
                continue
            }
            rawText .= character
            cursor++
        }
        if !closed
            throw Error("本地化调用中存在未闭合的字符串")
        template := DecodeAhkStringLiteral(rawText)
        if template != ""
            templates[template] := true
        searchPosition := cursor + 1
    }
}

CollectDynamicLocalizationExpressions(sourceText, expressions) {
    searchPosition := 1
    callPattern := 'i)\b(?:Tr|this\.Text)\s*\(\s*([A-Za-z_][A-Za-z0-9_.]*)'
    while RegExMatch(sourceText, callPattern, &callMatch,
        searchPosition) {
        expressions[callMatch[1]] := true
        searchPosition := callMatch.Pos(0) + callMatch.Len(0)
    }
}

CollectProductionLocalizationTemplates(projectRoot) {
    templates := Map()
    templates.CaseSense := "On"
    mainScript := projectRoot "\进程守护小助手.ahk"
    CollectLiteralLocalizationTemplates(FileRead(mainScript, "UTF-8"),
        templates)
    for sourceRoot in [projectRoot "\app", projectRoot "\src"] {
        Loop Files, sourceRoot "\*.ahk", "FR" {
            if A_LoopFileName == "EnglishStrings.ahk"
                continue
            CollectLiteralLocalizationTemplates(
                FileRead(A_LoopFileFullPath, "UTF-8"), templates)
        }
    }
    return templates
}

CollectProductionDynamicLocalizationExpressions(projectRoot) {
    expressions := Map()
    expressions.CaseSense := "On"
    mainScript := projectRoot "\进程守护小助手.ahk"
    CollectDynamicLocalizationExpressions(FileRead(mainScript, "UTF-8"),
        expressions)
    for sourceRoot in [projectRoot "\app", projectRoot "\src"] {
        Loop Files, sourceRoot "\*.ahk", "FR" {
            if A_LoopFileName == "EnglishStrings.ahk"
                continue
            CollectDynamicLocalizationExpressions(
                FileRead(A_LoopFileFullPath, "UTF-8"), expressions)
        }
    }
    return expressions
}

PlaceholderCounts(template) {
    counts := Map()
    position := 1
    while RegExMatch(template, '\{(\d+)(?::[^}]*)?\}', &match,
        position) {
        placeholder := match[1]
        counts[placeholder] := counts.Has(placeholder)
            ? counts[placeholder] + 1 : 1
        position := match.Pos(0) + match.Len(0)
    }
    return counts
}

PlaceholderContractsMatch(chineseTemplate, englishTemplate) {
    chineseCounts := PlaceholderCounts(chineseTemplate)
    englishCounts := PlaceholderCounts(englishTemplate)
    if chineseCounts.Count != englishCounts.Count
        return false
    for placeholder, count in chineseCounts {
        if !englishCounts.Has(placeholder)
            || englishCounts[placeholder] != count
            return false
    }
    return true
}

RunLocalizationTests() {
    projectRoot := A_ScriptDir "\..\.."
    englishCatalog := EnglishStrings.Create()
    templates := CollectProductionLocalizationTemplates(projectRoot)
    missingTemplates := []
    for template in templates {
        if !englishCatalog.Has(template)
            missingTemplates.Push(template)
    }
    AssertLocalization(!missingTemplates.Length,
        "缺少英文词条：" (missingTemplates.Length
            ? missingTemplates[1] : ""))

    for chineseTemplate, englishTemplate in englishCatalog {
        AssertLocalization(!RegExMatch(englishTemplate,
            "[\x{3400}-\x{9FFF}]"),
            "英文词条仍含中文：" chineseTemplate)
        AssertLocalization(PlaceholderContractsMatch(chineseTemplate,
            englishTemplate), "中英文占位符不一致：" chineseTemplate)
    }

    ; 已下线的程序内置扫描不可继续藏在词条目录中，否则后续很容易被旧界面
    ; 或旧配置重新接回。批量导入使用的“后台扫描”通用文案不在此列。
    obsoleteProgramSearchKeys := [
        "`; EverythingMaxResults：程序搜索结果上限，范围 10～1000。",
        "`; NativeScanTimeoutSeconds：内置文件扫描超时秒数，范围 1～120。",
        "`; PreferEverything：搜索程序时是否优先使用 Everything。",
        "优先使用 Everything 搜索", "内置搜索最长扫描时间（秒）：",
        "后台应用扫描未生成完整结果", "启动后台应用扫描失败",
        "搜索 ⚡原生深扫引擎⚡", "搜索 ⚡原生深扫引擎⚡（刷新失败）",
        "搜索 ⚡原生深扫引擎⚡（启动失败）",
        "搜索 ⚡原生深扫引擎⚡（扫描中）",
        "搜索 ⚡原生深扫引擎⚡（扫描失败）",
        "搜索 ⚡原生深扫引擎⚡（结果已截断）", "搜索与导入",
        "搜索结果数量上限：", "显示后台应用扫描结果失败",
        "读取 Everything 搜索结果失败：{1}",
        "读取后台应用扫描结果失败"
    ]
    for obsoleteKey in obsoleteProgramSearchKeys {
        AssertLocalization(!englishCatalog.Has(obsoleteKey),
            "已下线的程序搜索词条仍然存在：" obsoleteKey)
    }

    ; 已迁移为纯文字或共享 SVG 的旧 Emoji 按钮，以及设置页改版前的旧标签，
    ; 都不应继续留在词条目录中。主窗口三个彩色字符按钮不在此列。
    obsoleteUiKeys := [
        "❌ 取消", "💾 保存", "📂 浏览", "📖 帮助", "📋 日志", "❤️ 捐赠",
        "📖 打开使用说明", "📋 打开运行日志", "💬 提交反馈", "🔁 切换",
        "🔗 创建", "🚀 开启", "🛑 关闭", "⚠️ 冲突", "ℹ️ 帮助信息", "⚙️ 设置",
        "访问 GitHub 项目主页", "请选择要打开的内容：", "启动后显示主窗口",
        "状态检查间隔（毫秒）：", "重启等待序列（秒）：",
        "批量导入文件夹时递归扫描子目录", "窗口程序关闭等待（秒）：",
        "命令行程序退出等待（秒）：", "运行日志内存上限（条）：",
        "批处理日志保留时间（天）：", "批处理日志保存目录：", "内容字体：",
        "使用默认", "自定义显示", "🎨 自定义名称和图标…",
        "🔄 软件升级保护…",
        "立即检查更新",
        "• “关于”页可控制是否在启动时后台检查新版，也可随时手动检查。检查过程不会阻塞主界面。",
        "• 工作目录（CWD）用于相对路径；留空时使用快捷方式工作目录或程序所在目录。启动参数（Args）只填写附加参数，不要重复填写程序路径。",
        "• 环境变量每行填写一个 KEY=VALUE，只覆盖列出的变量；启动完成后小助手会恢复自身环境。以上设置均不改变已经运行的目标。",
        "• Python 虚拟环境变量不能可靠替换 .py 文件关联所用的解释器。要固定解释器，请创建以虚拟环境 python.exe 为目标、以脚本路径为参数的快捷方式或启动脚本，再将它加入守护。"
    ]
    for obsoleteKey in obsoleteUiKeys {
        AssertLocalization(!englishCatalog.Has(obsoleteKey),
            "已下线的旧界面词条仍然存在：" obsoleteKey)
    }

    ; 会打开后续窗口的菜单项也不添加字面省略号。逐目录检查译文，避免只改中文键
    ; 后其它语言仍保留三个点或省略号。
    for catalog in LocalizationService.GetAllTranslationCatalogs() {
        for menuKey in ["🎨 自定义名称和图标", "🔄 软件升级保护"] {
            AssertLocalization(catalog.Has(menuKey)
                && !RegExMatch(catalog[menuKey], "(?:…|\.\.\.)$"),
                "右键菜单译文仍含末尾省略号：" menuKey)
        }
    }

    expectedLanguages := ["zh-CN", "zh-HK", "zh-TW", "en-US",
        "ja-JP", "vi-VN", "ko-KR", "es-ES", "fr-FR", "pt-BR",
        "ru-RU", "de-DE", "it-IT"]
    actualLanguages := LocalizationService.GetSupportedLanguageCodes()
    AssertLocalization(actualLanguages.Length == expectedLanguages.Length,
        "受支持语言数量错误")
    for languageIndex, expectedLanguage in expectedLanguages {
        AssertLocalization(actualLanguages[languageIndex] == expectedLanguage,
            "语言顺序错误：" expectedLanguage)
    }
    languageChoices := LocalizationService.GetLanguageChoices()
    AssertLocalization(languageChoices.Length == expectedLanguages.Length + 1
        && languageChoices[1].Code == "auto", "跟随系统必须位于语言列表首位")
    for languageIndex, expectedLanguage in expectedLanguages {
        AssertLocalization(languageChoices[languageIndex + 1].Code
            == expectedLanguage, "语言选择顺序错误：" expectedLanguage)
    }

    latinFontSpec := {Primary: "SF Pro Text", Fallback: "Noto Sans",
        System: "Segoe UI"}
    expectedFontSpecs := Map(
        "zh-CN", {Primary: "PingFang SC",
            Fallback: "Noto Sans CJK SC",
            System: "Microsoft YaHei UI"},
        "zh-HK", {Primary: "PingFang HK",
            Fallback: "Noto Sans CJK HK",
            System: "Microsoft JhengHei UI"},
        "zh-TW", {Primary: "PingFang TC",
            Fallback: "Noto Sans CJK TC",
            System: "Microsoft JhengHei UI"},
        "en-US", latinFontSpec,
        "ja-JP", {Primary: "Harano Aji Gothic",
            Fallback: "Noto Sans CJK JP",
            System: "Yu Gothic UI"},
        "vi-VN", latinFontSpec,
        "ko-KR", {Primary: "AppleSDGothicNeoR00",
            Fallback: "Noto Sans CJK KR",
            System: "Malgun Gothic"},
        "es-ES", latinFontSpec,
        "fr-FR", latinFontSpec,
        "pt-BR", latinFontSpec,
        "ru-RU", latinFontSpec,
        "de-DE", latinFontSpec,
        "it-IT", latinFontSpec)
    for language, expectedSpec in expectedFontSpecs {
        actualSpec := LocalizationService.GetLanguageUiFontSpec(language)
        AssertLocalization(actualSpec.Primary == expectedSpec.Primary
            && !actualSpec.HasOwnProp("PrimaryAssets")
            && !actualSpec.HasOwnProp("Asset")
            && actualSpec.Fallback == expectedSpec.Fallback
            && actualSpec.System == expectedSpec.System,
            language " 的字体优先级配置错误")
        expectedSystemFont := LocalizationService.FindInstalledUiFontName(
            expectedSpec.System)
        if expectedSystemFont == ""
            expectedSystemFont := LocalizationService.FindInstalledUiFontName(
                "Segoe UI")
        if expectedSystemFont == "" {
            installedSystemFallbacks := LocalizationService
                .GetInstalledUiFontNames()
            expectedSystemFont := installedSystemFallbacks.Length
                ? installedSystemFallbacks[1] : "Segoe UI"
        }
        resolvedSystemFont := LocalizationService
            .GetLanguageSystemUiFontName(language)
        AssertLocalization(resolvedSystemFont == expectedSystemFont,
            language " 的系统强调字体解析错误")
        installedPrimary := LocalizationService.FindInstalledUiFontName(
            expectedSpec.Primary)
        resolvedFont := LocalizationService
            .GetLanguageDefaultUiFontName(language)
        expectedResolvedFont := installedPrimary
        if expectedResolvedFont == ""
            expectedResolvedFont := LocalizationService.FindInstalledUiFontName(
                expectedSpec.Fallback)
        if expectedResolvedFont == ""
            expectedResolvedFont := resolvedSystemFont
        if expectedResolvedFont == ""
            expectedResolvedFont := LocalizationService.FindInstalledUiFontName(
                "Segoe UI")
        if expectedResolvedFont == ""
            expectedResolvedFont := LocalizationService.GetInstalledUiFontNames()[1]
        AssertLocalization(resolvedFont == expectedResolvedFont,
            language " 没有按已安装字体优先级解析")
    }
    forcedFallbackFont := LocalizationService.ResolveUiFontSpec({
        Primary: "__Watchdog_Missing_Primary_Font__",
        Fallback: "Segoe UI",
        System: "Yu Gothic UI"
    })
    AssertLocalization(forcedFallbackFont
        == LocalizationService.FindInstalledUiFontName("Segoe UI"),
        "首选字体缺失时没有选择已安装回退字体")
    forcedSystemFont := LocalizationService.ResolveUiFontSpec({
        Primary: "__Watchdog_Missing_Primary_Font__",
        Fallback: "__Watchdog_Missing_Fallback_Font__",
        System: "Segoe UI"
    })
    AssertLocalization(forcedSystemFont
        == LocalizationService.FindInstalledUiFontName("Segoe UI"),
        "首选和 Noto 均未安装时没有回退 Windows 界面字体")
    installedFonts := LocalizationService.GetInstalledUiFontNames()
    AssertLocalization(installedFonts.Length > 0,
        "没有枚举到任何已安装界面字体")
    refreshedFonts := LocalizationService.RefreshInstalledUiFontNames()
    AssertLocalization(refreshedFonts.Length > 0
        && refreshedFonts != installedFonts,
        "主动刷新字体列表没有重新枚举当前字体状态")
    installedFonts := refreshedFonts
    for installedFont in installedFonts {
        AssertLocalization(Trim(installedFont) != ""
            && SubStr(installedFont, 1, 1) != "@",
            "字体菜单包含空名称或竖排镜像字体")
    }
    canonicalFont := installedFonts[1]
    AssertLocalization(LocalizationService.NormalizeRequestedUiFont(
        StrUpper(canonicalFont), "") == canonicalFont,
        "已安装字体没有按系统登记名称规范化")
    AssertLocalization(LocalizationService.NormalizeRequestedUiFont(
        "__Watchdog_Missing_Font__", "auto") == "auto",
        "未安装字体没有回退为跟随语言默认")

    LocalizationService.Configure("en-US")
    LocalizationService.ConfigureUiFont("auto")
    LocalizationService.Configure("ja-JP")
    AssertLocalization(LocalizationService.GetUiFontName()
        == LocalizationService.GetLanguageDefaultUiFontName("ja-JP"),
        "跟随语言默认的字体没有随语言配置同步刷新")
    LocalizationService.ConfigureUiFont(canonicalFont)
    LocalizationService.Configure("ko-KR")
    AssertLocalization(LocalizationService.GetUiFontName() == canonicalFont,
        "明确选择的内容字体被语言配置覆盖")
    LocalizationService.ConfigureUiFont("auto")

    aliases := Map(
        "zh-Hans", "zh-CN", "zh_SG", "zh-CN",
        "zh-Hant", "zh-TW", "zh-Hant-TW", "zh-TW",
        "zh-Hant-HK", "zh-HK", "zh-MO", "zh-HK",
        "en-GB", "en-US", "ja", "ja-JP", "vi", "vi-VN",
        "ko", "ko-KR", "es-MX", "es-ES", "fr-CA", "fr-FR",
        "pt-PT", "pt-BR", "ru", "ru-RU", "de-AT", "de-DE",
        "it-CH", "it-IT")
    for alias, expectedLanguage in aliases {
        AssertLocalization(LocalizationService.NormalizeRequestedLanguage(
            alias, "") == expectedLanguage, "语言别名映射错误：" alias)
    }

    for language in expectedLanguages {
        if language == "zh-CN"
            continue
        catalog := LocalizationService.GetCatalog(language)
        AssertLocalization(catalog.CaseSense == "On",
            language " 词条目录必须在写入前启用大小写敏感键")
        AssertLocalization(catalog.Count == englishCatalog.Count,
            language " 词条数量与英文基准不一致")
        for chineseTemplate, englishTemplate in englishCatalog {
            AssertLocalization(catalog.Has(chineseTemplate),
                language " 缺少词条：" chineseTemplate)
            translatedTemplate := catalog[chineseTemplate]
            AssertLocalization(Trim(translatedTemplate) != "",
                language " 存在空译文：" chineseTemplate)
            AssertLocalization(PlaceholderContractsMatch(chineseTemplate,
                translatedTemplate), language " 占位符不一致：" chineseTemplate)
            AssertLocalization(!RegExMatch(translatedTemplate,
                "i)(?:XXQI|ZZQI|QXZ|QXZZ|T00[0-9]QXZ)"),
                language " 译文含有生成器污染标记：" chineseTemplate)
            if !RegExMatch(language, "^(?:zh-|ja-JP$)") {
                AssertLocalization(!RegExMatch(translatedTemplate,
                    "[\x{3400}-\x{9FFF}]"),
                    language " 译文仍含汉字：" chineseTemplate)
            }
        }
    }


    ; 动态本地化只允许出现在少数明确边界。生产代码若新增动态调用，
    ; 必须先证明值域有限，并在下方把所有可能值纳入英文词条契约。
    allowedDynamicExpressions := Map(
        "operationName", true,
        "context", true,
        "resolutionSource", true,
        "reason", true,
        "decisionNote", true,
        "value", true,
        "fieldKey", true,
        "chineseTemplate", true
    )
    dynamicExpressions := CollectProductionDynamicLocalizationExpressions(
        projectRoot)
    for expression in dynamicExpressions {
        AssertLocalization(allowedDynamicExpressions.Has(expression),
            "发现未经审计的动态本地化表达式：" expression)
    }

    dynamicKeys := [
        "主进程监控", "升级进程扫描", "升级文件监听",
        "Windows Installer", "快捷方式参数", "快捷方式目标",
        "安装目录特征", "用户指定", "已保存身份",
        "收到显式维护开始命令", "检测到相关安装进程",
        "检测到程序文件变化", "检测到安装目录变化",
        "目标退出时检测到升级信号", "仲裁期间捕获到升级活动",
        "后台进程快照已确认",
        "后台进程快照未及时返回，已等待完整检测窗口",
        "升级等待已超时", "升级保护仍在进行",
        "目标程序文件不存在", "程序文件刚刚发生变化",
        "程序文件尚未达到稳定等待时间",
        "程序文件正在写入或结构不完整",
        "目标路径", "整条记录", "启用状态", "管理员运行状态",
        "真实目标来源标记", "工作目录", "启动参数", "环境变量",
        "整条启动配置", "启动程序或解释器", "解释器参数",
        "快捷方式真实目标", "升级保护配置", "整条展示配置",
        "自定义名称", "自定义图标", "展示配置",
        "与已加载守护对象重复，或目标格式无效", "内容为空",
        "内容无法解析", "未知解析错误", "不是当前 <HEX> 编码格式",
        "编码损坏", "值不是 0 或 1", "快捷方式及已解析目标均不可用",
        "启动目标不存在", "启动目标不可用", "后台扫描进程未返回 PID"
    ]
    dynamicKeys.Push(
        "显示", "启动", "监控", "界面语言：", "界面内容字体：", "主题：",
        "启动时显示主窗口", "启动时检查小助手更新",
        "进程状态检查间隔（毫秒）：", "崩溃自动重启延迟序列（秒）：",
        "导入文件夹时包含子目录", "GUI 程序关闭超时（秒）：",
        "CLI 程序关闭超时（秒）：", "正常关闭超时后允许强制终止",
        "运行日志显示上限（条）：", "批处理日志保存路径：",
        "批处理日志保留天数：", "启动时清空批处理日志")
    for key in dynamicKeys {
        ; Windows Installer 本身已经是英文，允许沿用原文；其他受控值必须
        ; 有显式词条，避免某个罕见分支只在英文界面中暴露中文。
        if key != "Windows Installer" {
            AssertLocalization(englishCatalog.Has(key),
                "动态本地化值缺少英文词条：" key)
        }
    }

    LocalizationService.Configure("zh-CN")
    AssertLocalization(Tr("进程守护小助手") == "进程守护小助手",
        "中文模式改写了默认文案")
    AssertLocalization(BuildApplicationVersionSummary("1.2.3", "2.0.26",
        true) == "当前版本：1.2.3（EXE 版；内嵌 AutoHotkey 2.0.26 x64）",
        "中文 EXE 版本摘要错误")
    AssertLocalization(BuildApplicationVersionSummary("1.2.3", "2.0.26",
        false) == "当前版本：1.2.3（源码版；本机 AutoHotkey 2.0.26 x64）",
        "中文源码版本摘要错误")
    AssertLocalization(BuildApplicationEditionSummary("1.2.3", true)
        == "v1.2.3（EXE 版）", "中文 EXE 发行形态摘要错误")
    AssertLocalization(BuildApplicationEditionSummary("1.2.3", false)
        == "v1.2.3（源码版）", "中文源码发行形态摘要错误")
    AssertLocalization(BuildAutoHotkeyRuntimeSummary("2.0.26")
        == "AutoHotkey 2.0.26 x64", "中文运行环境摘要错误")
    LocalizationService.Configure("zh-HK")
    AssertLocalization(Tr("进程守护小助手") == "程序守護小助手",
        "港繁产品名称错误")
    LocalizationService.Configure("zh-TW")
    AssertLocalization(Tr("进程守护小助手") == "處理程序守護小助手",
        "台繁产品名称错误")
    LocalizationService.Configure("en-US")
    AssertLocalization(Tr("进程守护小助手")
        == "Process Watchdog Assistant", "英文模式未切换产品名称")
    AssertLocalization(Tr("⏳ 重试倒计时 {1} 秒", 7)
        == "⏳ Retry in 7 seconds", "英文占位符渲染异常")
    AssertLocalization(Tr("使用说明") == "User Guide",
        "英文使用说明标题未切换")
    AssertLocalization(BuildApplicationVersionSummary("1.2.3", "2.0.26",
        true) == "Current version: 1.2.3（EXE edition; embedded AutoHotkey 2.0.26 x64）",
        "英文 EXE 版本摘要错误")
    AssertLocalization(BuildApplicationVersionSummary("1.2.3", "2.0.26",
        false) == "Current version: 1.2.3（source edition; local AutoHotkey 2.0.26 x64）",
        "英文源码版本摘要错误")
    AssertLocalization(BuildApplicationEditionSummary("1.2.3", true)
        == "v1.2.3（EXE edition）", "英文 EXE 发行形态摘要错误")
    AssertLocalization(BuildApplicationEditionSummary("1.2.3", false)
        == "v1.2.3（source edition）", "英文源码发行形态摘要错误")
    AssertLocalization(BuildAutoHotkeyRuntimeSummary("2.0.26")
        == "AutoHotkey 2.0.26 x64", "英文运行环境摘要错误")
    AssertLocalization(TrDiagnostic("字段数量应为 9，实际为 7")
        == "Expected 9 fields, but found 7",
        "动态配置字段数量原因未本地化")
    AssertLocalization(TrDiagnostic("缺少运行参数: CheckInterval")
        == "Missing runtime setting: CheckInterval",
        "带字段名的诊断信息未本地化")
    AssertLocalization(TrDiagnostic("系统返回的未知错误")
        == "系统返回的未知错误",
        "未知系统错误不应被猜测性改写")

    AssertLocalization(
        LocalizationService.TranslateRenderedTextBetweenLanguages(
            "⏳ Retry in 7 seconds", "en-US", "zh-CN")
                == "⏳ 重试倒计时 7 秒",
        "带占位符的英文运行状态没有热切换为中文")
    AssertLocalization(
        LocalizationService.TranslateRenderedTextBetweenLanguages(
            "⏳ 重试倒计时 12 秒", "zh-CN", "ja-JP")
                == "⏳ 12 秒後に再試行",
        "带占位符的中文运行状态没有热切换为日文")
    AssertLocalization(
        LocalizationService.TranslateRenderedTextBetweenLanguages(
            "Process Watchdog Assistant", "en-US", "zh-CN")
                == "进程守护小助手",
        "无占位符的英文文案没有热切换为中文")
    AssertLocalization(
        LocalizationService.TranslateRenderedTextBetweenLanguages(
            "unmanaged operating-system detail", "en-US", "zh-CN")
                == "unmanaged operating-system detail",
        "未知运行文本不应在热切换时被猜测性改写")

    runtimeStatusTemplates := [
        "初始化...", "✅ 运行中", "⚠️ 运行中（权限不符）", "⏸️ 已暂停",
        "⚠️ 疑似停止", "❌ 目标不存在", "❌ 程序不存在", "❌ 脚本不存在",
        "⏳ 等待安全启动条件", "🚀 正在启动...", "✅ 已启动（非驻留目标）",
        "⏳ 验证运行状态...", "⏳ 启动失败，稍后自动重试",
        "⏳ 等待进程状态...", "⏳ 正在结束运行...", "❌ 无法结束运行",
        "🔄 显式升级维护中", "⏳ 确认升级文件稳定", "⚠️ 升级等待超时",
        "🔄 恢复升级保护状态", "⏳ 判断是否正在升级", "🔄 软件升级中",
        "⏳ 升级完成，准备恢复", "🔄 等待程序文件可用",
        "🔄 等待程序文件恢复"
    ]
    runtimeDynamicStatusTemplates := [
        "⏳ 稍后自动重试 {1} 秒", "⏳ 重试倒计时 {1} 秒",
        "⏳ 启动倒计时 {1} 秒", "⏳ 确认升级文件稳定 {1}s"
    ]
    for language in expectedLanguages {
        LocalizationService.Configure(language)
        for statusTemplate in runtimeStatusTemplates {
            expectedStatus := Tr(statusTemplate)
            convertedStatus := LocalizationService
                .TranslateRenderedTextBetweenLanguages(statusTemplate,
                    "zh-CN", language)
            AssertLocalization(convertedStatus == expectedStatus,
                language " 静态运行状态无法从中文热切换：" statusTemplate)
            AssertLocalization(
                LocalizationService.TranslateRenderedTextBetweenLanguages(
                    expectedStatus, language, "zh-CN") == statusTemplate,
                language " 静态运行状态无法热切换回中文：" statusTemplate)
        }
        for statusTemplate in runtimeDynamicStatusTemplates {
            expectedStatus := Tr(statusTemplate, 7)
            chineseStatus := Format(statusTemplate, 7)
            convertedStatus := LocalizationService
                .TranslateRenderedTextBetweenLanguages(chineseStatus,
                    "zh-CN", language)
            AssertLocalization(convertedStatus == expectedStatus,
                language " 动态运行状态无法从中文热切换：" statusTemplate)
            AssertLocalization(
                LocalizationService.TranslateRenderedTextBetweenLanguages(
                    expectedStatus, language, "zh-CN") == chineseStatus,
                language " 动态运行状态无法热切换回中文：" statusTemplate)
        }
    }
    AssertLocalization(IsObject(LocalizationService.RenderedSourceSpecCache)
        && LocalizationService.RenderedSourceSpecCache.Count
            <= expectedLanguages.Length,
        "动态状态模板缓存超过按源语言计算的固定上限")
}

try {
    RunLocalizationTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
