class WatchdogConfigRepository {
    __New(path, clock := "") {
        this.Path := path
        this.Clock := clock
        this.Writing := false
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
        for definition in WatchdogConfigRepository.SectionComments() {
            iniText := WatchdogConfigRepository.InsertSectionComment(iniText,
                definition.Name, definition.Lines, newline)
        }
        for definition in WatchdogConfigRepository.KeyComments() {
            iniText := WatchdogConfigRepository.InsertKeyComment(iniText,
                definition.Section, definition.Key, definition.Lines, newline)
        }
        currentText := FileRead(iniPath, "UTF-16")
        if iniText == currentText
            return false
        FileDelete(iniPath)
        FileAppend(iniText, iniPath, "UTF-16")
        return true
    }

    static InsertSectionComment(iniText, sectionName, commentLines, newline) {
        marker := commentLines[1]
        pattern := "m)^\[" sectionName "\][ `t]*(?:\r\n|\n|$)"
        if !RegExMatch(iniText, pattern, &headerMatch)
            return iniText
        bodyStart := headerMatch.Pos[0] + headerMatch.Len[0]
        tail := SubStr(iniText, bodyStart)
        nextSectionOffset := RegExMatch(tail, "m)^\[[^\]`r`n]+\]",
            &nextSection)
        bodyLength := nextSectionOffset ? nextSectionOffset - 1
            : StrLen(tail)
        sectionBody := SubStr(tail, 1, bodyLength)
        if InStr(sectionBody, marker)
            return iniText
        ; IniDelete 会删除空节标题和键，却把前导注释留在上一节末尾。
        ; 先移除这些唯一文档行，再把它们归位到真正的节标题下。
        for line in commentLines {
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

    static InsertKeyComment(iniText, sectionName, key, commentLines, newline) {
        marker := commentLines[1]
        sectionPattern := "m)^\[" sectionName "\][ `t]*(?:\r\n|\n|$)"
        if !RegExMatch(iniText, sectionPattern, &sectionMatch)
            return iniText
        bodyStart := sectionMatch.Pos[0] + sectionMatch.Len[0]
        tail := SubStr(iniText, bodyStart)
        nextSectionOffset := RegExMatch(tail, "m)^\[[^\]`r`n]+\]", &nextSection)
        bodyLength := nextSectionOffset ? nextSectionOffset - 1 : StrLen(tail)
        sectionBody := SubStr(tail, 1, bodyLength)
        if InStr(sectionBody, marker)
            return iniText
        for line in commentLines {
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

    static SectionComments() {
        return [
            {Name: "Settings", Lines: [
                "; 本区保存运行参数；以分号开头的注释不会参与软件读取。",
                "; 布尔值使用 1 表示开启、0 表示关闭，建议优先通过设置界面修改。"]},
            {Name: "Apps", Lines: [
                "; 每个 AppN 对应一个监控项，九个字段使用竖线分隔。",
                "; 格式：启用状态｜管理员运行｜目标路径｜工作目录｜启动参数｜环境变量｜快捷方式真实目标｜手动目标标记｜快捷方式参数。",
                "; 布尔值使用 1 表示开启、0 表示关闭；<HEX> 内容由软件自动编码和解码。"]},
            {Name: "Maintenance", Lines: [
                "; AppN 与 [Apps] 中同名项目一一对应，值为软件升级保护的 <HEX> 编码结构。",
                "; 内部字段包括 Enabled、RootIsCustom、DetectionSeconds、StableSeconds、MaxWaitSeconds、InstallRoot 和 Actor。",
                "; 建议通过“软件升级保护”界面修改，不要直接编辑编码内容。"]},
            {Name: "Display", Lines: [
                "; 仅保存主窗口显示名称和图标来源，不参与进程识别、启动或升级保护。",
                "; AppN 与 [Apps] 中同名项目一一对应；留空的项目使用目标自身的名称和图标。"]},
            {Name: "Recovery", Lines: [
                "; 无法安全解析的监控记录会暂存于此，避免静默丢失；正常情况下无需手动修改。"]}
        ]
    }

    static KeyComments() {
        return [
            {Section: "Settings", Key: "CheckInterval", Lines: [
                "; CheckInterval：状态检查间隔，单位为毫秒，范围 500～86400000。"]},
            {Section: "Settings", Key: "RetrySequence", Lines: [
                "; RetrySequence：重启等待秒数，逗号分隔，最多 10 项，每项范围 1～86400。"]},
            {Section: "Settings", Key: "ShowAfterReload", Lines: [
                "; ShowAfterReload：内部重载标记，重载完成后会自动恢复为 0。"]},
            {Section: "Settings", Key: "AllowForceTerminate", Lines: [
                "; AllowForceTerminate：正常退出超时后是否允许强制结束进程。"]},
            {Section: "Settings", Key: "ClearLogsOnStartup", Lines: [
                "; ClearLogsOnStartup：启动时是否清空历史日志。"]},
            {Section: "Settings", Key: "CtrlCWaitSeconds", Lines: [
                "; CtrlCWaitSeconds：命令行程序接收 Ctrl+C 后最长等待秒数，范围 1～60。"]},
            {Section: "Settings", Key: "EverythingMaxResults", Lines: [
                "; EverythingMaxResults：程序搜索结果上限，范围 10～1000。"]},
            {Section: "Settings", Key: "GracefulStopSeconds", Lines: [
                "; GracefulStopSeconds：窗口程序正常退出最长等待秒数，范围 1～300。"]},
            {Section: "Settings", Key: "LogDirectory", Lines: [
                "; LogDirectory：日志文件保存目录。"]},
            {Section: "Settings", Key: "LogMaxEntries", Lines: [
                "; LogMaxEntries：日志界面保留条数，范围 50～10000。"]},
            {Section: "Settings", Key: "LogRetentionDays", Lines: [
                "; LogRetentionDays：日志文件保留天数，范围 1～3650。"]},
            {Section: "Settings", Key: "NativeScanTimeoutSeconds", Lines: [
                "; NativeScanTimeoutSeconds：内置文件扫描超时秒数，范围 1～120。"]},
            {Section: "Settings", Key: "PreferEverything", Lines: [
                "; PreferEverything：搜索程序时是否优先使用 Everything。"]},
            {Section: "Settings", Key: "RecursiveBatchImport", Lines: [
                "; RecursiveBatchImport：批量导入文件夹时是否递归扫描子目录。"]},
            {Section: "Settings", Key: "ShowAtStartup", Lines: [
                "; ShowAtStartup：启动后是否显示主窗口。"]},
            {Section: "Layout", Key: "GuiH", Lines: [
                "; GuiH：主窗口高度，按 96 DPI 逻辑像素保存。"]},
            {Section: "Layout", Key: "Col1W", Lines: [
                "; Col1W：主列表第一列宽度，按 96 DPI 逻辑像素保存。"]},
            {Section: "Layout", Key: "Col2W", Lines: [
                "; Col2W：主列表第二列宽度，按 96 DPI 逻辑像素保存。"]},
            {Section: "Layout", Key: "GuiW", Lines: [
                "; GuiW：主窗口宽度，按 96 DPI 逻辑像素保存。"]}
        ]
    }

    Now() {
        if IsObject(this.Clock) {
            try return Integer(this.Clock.Call())
        }
        return DllCall("kernel32\GetTickCount64", "UInt64")
    }
}
