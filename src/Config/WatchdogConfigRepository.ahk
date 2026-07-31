; watchdog.ini 的原子读写仓库。
; 所有修改先写入同目录临时文件，再按界面语言补齐就地说明并原子替换正式文件；
; 事务期间保留调用方临界区状态，失败时删除临时文件且不污染原配置。

class WatchdogConfigRepository {
    __New(path, clock := "", localize := "", commentTranslations := "") {
        this.Path := path
        this.Clock := clock
        this.Localize := IsObject(localize) ? localize : ""
        this.CommentAliases := Map()
        this.CommentAliases.CaseSense := "On"
        this.BuildCommentAliases(commentTranslations)
        this.Writing := false
    }

    BuildCommentAliases(commentTranslations) {
        if !IsObject(commentTranslations)
            return
        catalogs := Type(commentTranslations) == "Array"
            ? commentTranslations : [commentTranslations]
        groups := Map()
        groups.CaseSense := "On"
        for catalog in catalogs {
            if !IsObject(catalog)
                continue
            for sourceText, translatedText in catalog {
                if SubStr(sourceText, 1, 1) != ";"
                    continue
                if !groups.Has(sourceText)
                    groups[sourceText] := [sourceText]
                aliases := groups[sourceText]
                if translatedText != sourceText {
                    found := false
                    for alias in aliases {
                        if alias == translatedText {
                            found := true
                            break
                        }
                    }
                    if !found
                        aliases.Push(translatedText)
                }
            }
        }
        for sourceText, aliases in groups {
            for alias in aliases
                this.CommentAliases[alias] := aliases
        }
    }

    EnsureExists(defaultSections) {
        if FileExist(this.Path)
            return false
        this.ReplaceSections(defaultSections)
        return true
    }

    Read(sectionName, key, defaultValue := "") {
        try return IniRead(this.Path, sectionName, key, defaultValue)
        catch
            return defaultValue
    }

    ReadBool(sectionName, key, defaultValue) {
        try return Integer(this.Read(sectionName, key,
            defaultValue ? 1 : 0)) != 0
        catch
            return defaultValue
    }

    ReadBoundedInt(sectionName, key, defaultValue, minimum, maximum) {
        try value := Integer(this.Read(sectionName, key, defaultValue))
        catch
            return defaultValue
        return value >= minimum && value <= maximum
            ? value : defaultValue
    }

    ReadSectionEntries(sectionName) {
        entries := []
        try sectionText := IniRead(this.Path, sectionName)
        catch
            return entries
        Loop Parse, sectionText, "`n", "`r" {
            separator := InStr(A_LoopField, "=")
            if !separator
                continue
            entries.Push({Key: SubStr(A_LoopField, 1, separator - 1),
                Value: SubStr(A_LoopField, separator + 1)})
        }
        return entries
    }

    ReadSectionMap(sectionName) {
        values := Map()
        values.CaseSense := "Off"
        for entry in this.ReadSectionEntries(sectionName)
            values[entry.Key] := entry.Value
        return values
    }

    WriteValue(sectionName, key, value) {
        return this.WriteValues(sectionName, [{Key: key, Value: value}])
    }

    WriteValues(sectionName, entries) {
        return this.Transact(ObjBindMethod(this, "ApplyValues",
            sectionName, entries))
    }

    ReplaceSections(sections) {
        return this.Transact(ObjBindMethod(this, "ApplySections", sections))
    }

    Transact(writer) {
        if !IsObject(writer)
            throw TypeError("配置写入器无效")

        previousCritical := A_IsCritical
        Critical("On")
        ownsTransaction := false
        tempPath := ""
        try {
            if this.Writing
                throw Error("配置文件写入事务正在进行")
            this.Writing := true
            ownsTransaction := true
            tempPath := this.Path ".tmp." this.Now() "_" A_ScriptHwnd
            try FileDelete(tempPath)
            if FileExist(this.Path)
                FileCopy(this.Path, tempPath, 1)
            else
                FileAppend("", tempPath, "UTF-16")
            writer.Call(tempPath)
            this.EnsureDocumentation(tempPath)
            FileMove(tempPath, this.Path, 1)
            return true
        } catch {
            if tempPath != ""
                try FileDelete(tempPath)
            throw
        } finally {
            if ownsTransaction
                this.Writing := false
            Critical(previousCritical ? previousCritical : "Off")
        }
    }

    ApplyValues(sectionName, entries, tempPath) {
        for entry in entries {
            if !IsObject(entry) || !entry.HasOwnProp("Key")
                continue
            IniWrite(entry.HasOwnProp("Value") ? entry.Value : "",
                tempPath, sectionName, entry.Key)
        }
    }

    ApplySections(sections, tempPath) {
        for section in sections {
            if !IsObject(section) || !section.HasOwnProp("Name")
                continue
            try IniDelete(tempPath, section.Name)
            entries := section.HasOwnProp("Entries") ? section.Entries : []
            this.ApplyValues(section.Name, entries, tempPath)
        }
    }

    EnsureDocumentation(iniPath) {
        iniText := FileRead(iniPath, "UTF-16")
        newline := InStr(iniText, "`r`n") ? "`r`n" : "`n"
        for definition in this.SectionComments() {
            iniText := WatchdogConfigRepository.InsertSectionComment(iniText,
                definition.Name, definition.Lines, newline,
                this.KnownCommentLines(definition.Lines))
        }
        for definition in this.KeyComments() {
            iniText := WatchdogConfigRepository.InsertKeyComment(iniText,
                definition.Section, definition.Key, definition.Lines, newline,
                this.KnownCommentLines(definition.Lines))
        }
        currentText := FileRead(iniPath, "UTF-16")
        if iniText == currentText
            return false
        FileDelete(iniPath)
        FileAppend(iniText, iniPath, "UTF-16")
        return true
    }

    static InsertSectionComment(iniText, sectionName, commentLines, newline,
        knownCommentLines := "") {
        pattern := "m)^\[" sectionName "\][ `t]*(?:\r\n|\n|$)"
        if !RegExMatch(iniText, pattern, &headerMatch)
            return iniText
        ; IniDelete 会删除空节标题和键，却把前导注释留在上一节末尾。
        ; 先移除中英文的已知文档行，再按当前语言归位到真正的节标题下。
        linesToRemove := IsObject(knownCommentLines)
            ? knownCommentLines : commentLines
        for line in linesToRemove {
            linePattern := "m)^\Q" line "\E[ `t]*(?:\r\n|\n|$)"
            iniText := RegExReplace(iniText, linePattern, "")
        }
        if !RegExMatch(iniText, pattern, &headerMatch)
            return iniText
        headerText := headerMatch[0]
        if !InStr(headerText, "`n")
            headerText .= newline
        commentText := ""
        for line in commentLines
            commentText .= line newline
        return SubStr(iniText, 1, headerMatch.Pos[0] - 1)
            . headerText commentText
            . SubStr(iniText, headerMatch.Pos[0] + headerMatch.Len[0])
    }

    static InsertKeyComment(iniText, sectionName, key, commentLines, newline,
        knownCommentLines := "") {
        sectionPattern := "m)^\[" sectionName "\][ `t]*(?:\r\n|\n|$)"
        if !RegExMatch(iniText, sectionPattern, &sectionMatch)
            return iniText
        linesToRemove := IsObject(knownCommentLines)
            ? knownCommentLines : commentLines
        for line in linesToRemove {
            linePattern := "m)^\Q" line "\E[ `t]*(?:\r\n|\n|$)"
            iniText := RegExReplace(iniText, linePattern, "")
        }
        if !RegExMatch(iniText, sectionPattern, &sectionMatch)
            return iniText
        bodyStart := sectionMatch.Pos[0] + sectionMatch.Len[0]
        tail := SubStr(iniText, bodyStart)
        nextSectionOffset := RegExMatch(tail, "m)^\[[^\]`r`n]+\]",
            &nextSection)
        bodyLength := nextSectionOffset ? nextSectionOffset - 1 : StrLen(tail)
        sectionBody := SubStr(tail, 1, bodyLength)
        keyPattern := "m)^\Q" key "\E=.*(?:\r\n|\n|$)"
        if !RegExMatch(sectionBody, keyPattern, &keyMatch)
            return iniText
        commentText := ""
        for line in commentLines
            commentText .= line newline
        keyPosition := bodyStart + keyMatch.Pos[0] - 1
        return SubStr(iniText, 1, keyPosition - 1)
            . commentText SubStr(iniText, keyPosition)
    }

    SectionComments() {
        return [
            {Name: "Settings", Lines: [
                this.Text("; 本区保存运行参数；以分号开头的注释不会参与软件读取。"),
                this.Text("; 布尔值使用 1 表示开启、0 表示关闭，建议优先通过设置界面修改。")]},
            {Name: "Apps", Lines: [
                this.Text("; 每个 AppN 对应一个守护对象，九个字段使用竖线分隔。"),
                this.Text("; 格式：启用状态｜管理员运行｜目标路径｜工作目录｜启动参数｜环境变量｜快捷方式真实目标｜手动目标标记｜快捷方式参数。"),
                this.Text("; 布尔值使用 1 表示开启、0 表示关闭；<HEX> 内容由软件自动编码和解码。")]},
            {Name: "Maintenance", Lines: [
                this.Text("; AppN 与 [Apps] 中同名的守护对象一一对应，值为软件升级保护的 <HEX> 编码结构。"),
                this.Text("; 内部字段包括 Enabled、RootIsCustom、DetectionSeconds、StableSeconds、MaxWaitSeconds、InstallRoot 和 Actor。"),
                this.Text("; 建议通过“软件升级保护”界面修改，不要直接编辑编码内容。")]},
            {Name: "Display", Lines: [
                this.Text("; 仅保存主窗口显示名称和图标来源，不参与进程识别、启动或升级保护。"),
                this.Text("; AppN 与 [Apps] 中同名的守护对象一一对应；留空时使用目标自身的名称和图标。")]},
            {Name: "Launch", Lines: [
                this.Text("; AppN 与 [Apps] 中同名的守护对象一一对应，依次保存启动程序或解释器路径及其参数。"),
                this.Text("; 两个字段均为 <HEX> 编码；留空时由小助手按目标类型使用默认启动方式。")]},
            {Name: "Identity", Lines: [
                this.Text("; AppN 与 [Apps] 中同名的直接文件目标一一对应，依次保存文件大小和 SHA-256 内容哈希。"),
                this.Text("; 此节由小助手自动维护，用于在文件或目录改名、跨目录或跨磁盘移动后确认内容未变；请勿手动编辑。")]},
            {Name: "Recovery", Lines: [
                this.Text("; 无法安全解析的监控记录会暂存于此，避免静默丢失；正常情况下无需手动修改。")]}
        ]
    }

    KeyComments() {
        return [
            {Section: "Settings", Key: "UiLanguage", Lines: [
                this.Text("; UiLanguage：界面语言；auto 表示跟随系统，也可填写受支持的语言代码。")]},
            {Section: "Settings", Key: "UiFont", Lines: [
                this.Text("; UiFont：界面字体；auto 表示使用当前语言的默认字体，也可填写本机已安装字体名称。")]},
            {Section: "Settings", Key: "Theme", Lines: [
                this.Text("; Theme：界面主题；auto 表示跟随 Windows 系统，light 表示浅色，dark 表示深色。")]},
            {Section: "Settings", Key: "CheckInterval", Lines: [
                this.Text("; CheckInterval：状态检查间隔，单位为毫秒，范围 500～86400000。")]},
            {Section: "Settings", Key: "CheckUpdatesOnStartup", Lines: [
                this.Text("; CheckUpdatesOnStartup：启动后是否在后台检查小助手新版。")]},
            {Section: "Settings", Key: "RetrySequence", Lines: [
                this.Text("; RetrySequence：重启等待秒数，逗号分隔，最多 10 项，每项范围 1～86400。")]},
            {Section: "Settings", Key: "ShowAfterReload", Lines: [
                this.Text("; ShowAfterReload：内部重载标记，重载完成后会自动恢复为 0。")]},
            {Section: "Settings", Key: "AllowForceTerminate", Lines: [
                this.Text("; AllowForceTerminate：正常退出超时后是否允许强制结束进程。")]},
            {Section: "Settings", Key: "ClearLogsOnStartup", Lines: [
                this.Text("; ClearLogsOnStartup：启动时是否清空历史日志。")]},
            {Section: "Settings", Key: "CtrlCWaitSeconds", Lines: [
                this.Text("; CtrlCWaitSeconds：命令行程序接收 Ctrl+C 后最长等待秒数，范围 1～60。")]},
            {Section: "Settings", Key: "GracefulStopSeconds", Lines: [
                this.Text("; GracefulStopSeconds：窗口程序正常退出最长等待秒数，范围 1～300。")]},
            {Section: "Settings", Key: "LogDirectory", Lines: [
                this.Text("; LogDirectory：留空时使用系统临时目录下的 ProcessWatchdogLogs。")]},
            {Section: "Settings", Key: "LogMaxEntries", Lines: [
                this.Text("; LogMaxEntries：日志界面保留条数，范围 50～10000。")]},
            {Section: "Settings", Key: "LogRetentionDays", Lines: [
                this.Text("; LogRetentionDays：日志文件保留天数，范围 1～3650。")]},
            {Section: "Settings", Key: "RecursiveBatchImport", Lines: [
                this.Text("; RecursiveBatchImport：批量导入文件夹时是否递归扫描子目录。")]},
            {Section: "Settings", Key: "ShowAtStartup", Lines: [
                this.Text("; ShowAtStartup：启动后是否显示主窗口。")]},
            {Section: "Layout", Key: "GuiH", Lines: [
                this.Text("; GuiH：主窗口高度，按 96 DPI 逻辑像素保存。")]},
            {Section: "Layout", Key: "Col1W", Lines: [
                this.Text("; Col1W：主列表第一列宽度，按 96 DPI 逻辑像素保存。")]},
            {Section: "Layout", Key: "Col2W", Lines: [
                this.Text("; Col2W：主列表第二列宽度，按 96 DPI 逻辑像素保存。")]},
            {Section: "Layout", Key: "GuiW", Lines: [
                this.Text("; GuiW：主窗口宽度，按 96 DPI 逻辑像素保存。")]}
        ]
    }

    KnownCommentLines(currentLines) {
        known := Map()
        known.CaseSense := "On"
        for line in currentLines {
            known[line] := true
            if this.CommentAliases.Has(line) {
                for alias in this.CommentAliases[line]
                    known[alias] := true
            }
        }
        result := []
        for line in known
            result.Push(line)
        return result
    }

    Now() {
        if IsObject(this.Clock) {
            try return Integer(this.Clock.Call())
        }
        return DllCall("kernel32\GetTickCount64", "UInt64")
    }

    Text(template, values*) {
        if IsObject(this.Localize)
            return this.Localize.Call(template, values*)
        return values.Length ? Format(template, values*) : template
    }
}
