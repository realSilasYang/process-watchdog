#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\..\src\Config\IniFieldCodec.ahk
#Include ..\..\src\Config\DisplayConfigCodec.ahk
#Include ..\..\src\Config\MaintenanceConfigCodec.ahk
#Include ..\..\src\Maintenance\MaintenanceActorMatcher.ahk

AssertConfigCodec(value, message) {
    if !value
        throw Error(message)
}

ConfigCodecNormalizePath(path) {
    path := Trim(String(path))
    if (StrLen(path) >= 2 && SubStr(path, 1, 1) == '"'
        && SubStr(path, -1) == '"')
        path := Trim(SubStr(path, 2, -1))
    return StrReplace(path, "/", "\")
}

ConfigCodecCanonicalPath(path) {
    path := StrLower(ConfigCodecNormalizePath(path))
    return StrLen(path) > 3 ? RTrim(path, "\") : path
}

ConfigCodecPathsEquivalent(firstPath, secondPath) {
    if (firstPath == "" || secondPath == "")
        return firstPath == secondPath
    return ConfigCodecCanonicalPath(firstPath)
        == ConfigCodecCanonicalPath(secondPath)
}

ConfigCodecIsSupportedTarget(path) {
    if !InStr(path, "\")
        return false
    SplitPath(path, , , &extension)
    return RegExMatch(extension, "i)^(exe|ahk|lnk)$") != 0
}

ConfigCodecGetDefaultRoot(path) {
    if !ConfigCodecIsSupportedTarget(path)
        return ""
    SplitPath(path, , , &extension)
    if (StrLower(extension) == "lnk")
        return "C:\ShortcutDefault"
    SplitPath(path, , &directory)
    return ConfigCodecNormalizeRoot(directory)
}

ConfigCodecNormalizeRoot(rootPath, targetPath := "") {
    rootPath := Trim(String(rootPath))
    if (rootPath == "" && targetPath != "")
        rootPath := ConfigCodecGetDefaultRoot(targetPath)
    rootPath := StrReplace(rootPath, "/", "\")
    return StrLen(rootPath) > 3 ? RTrim(rootPath, "\") : rootPath
}

ConfigCodecParseBoundedInteger(value, minValue, maxValue) {
    value := Trim(String(value))
    if !RegExMatch(value, "^\d+$")
        return false
    try parsed := Integer(value)
    catch
        return false
    return parsed >= minValue && parsed <= maxValue ? parsed : false
}

ConfigCodecResolveCreation(*) {
    return ""
}

CreateMaintenanceCodecForTest() {
    matcher := MaintenanceActorMatcher(ConfigCodecResolveCreation)
    return MaintenanceConfigCodec({
        GetDefaultRoot: ConfigCodecGetDefaultRoot,
        IsSupportedTarget: ConfigCodecIsSupportedTarget,
        NormalizeRoot: ConfigCodecNormalizeRoot,
        ParseBoundedInteger: ConfigCodecParseBoundedInteger,
        PathsEquivalent: ConfigCodecPathsEquivalent
    }, matcher)
}

RunDisplayConfigCodecTests() {
    codec := DisplayConfigCodec(ConfigCodecNormalizePath,
        ConfigCodecPathsEquivalent)
    defaultConfig := codec.CreateDefault()
    AssertConfigCodec(defaultConfig.Name == ""
        && defaultConfig.IconPath == "" && codec.IsDefault(defaultConfig),
        "显示配置默认值错误")

    longName := ""
    Loop 130
        longName .= "名"
    normalized := codec.Normalize({
        Name: "  " longName "  ",
        IconPath: '"C:/图标/应用|新版.ico"'
    })
    AssertConfigCodec(StrLen(normalized.Name) == 120,
        "自定义名称没有裁剪到 120 个字符")
    AssertConfigCodec(normalized.IconPath == "C:\图标\应用|新版.ico",
        "显示图标路径没有规范化")

    display := {Name: "中文|名称", IconPath: "C:\图标\新版|应用.ico"}
    encoded := codec.Serialize(display)
    decoded := codec.Deserialize(encoded)
    AssertConfigCodec(decoded.Name == display.Name
        && decoded.IconPath == display.IconPath,
        "包含 Unicode 或竖线的显示配置没有无损往返")
    AssertConfigCodec(codec.Equals(display, {
        Name: "中文|名称", IconPath: "c:/图标/新版|应用.ico"}),
        "显示配置没有按等价路径比较")
    AssertConfigCodec(!codec.Equals(display, {
        Name: "其他名称", IconPath: display.IconPath}),
        "不同自定义名称被错误视为相等")

    clone := codec.Clone(display)
    clone.Name := "已修改"
    AssertConfigCodec(display.Name == "中文|名称",
        "显示配置克隆仍与源对象共享状态")
    damaged := codec.Deserialize("one|two|three")
    AssertConfigCodec(codec.IsDefault(damaged),
        "字段数量损坏的显示配置没有回退默认值")
}

RunMaintenanceConfigCodecTests() {
    codec := CreateMaintenanceCodecForTest()
    targetPath := "C:\Apps\示例\App.exe"
    defaultConfig := codec.CreateDefault(targetPath)
    AssertConfigCodec(!defaultConfig.Enabled
        && defaultConfig.InstallRoot == "C:\Apps\示例"
        && defaultConfig.DetectionSeconds == 10
        && defaultConfig.StableSeconds == 8
        && defaultConfig.MaxWaitSeconds == 1800,
        "升级保护默认值错误或默认状态不是关闭")

    bounded := codec.Normalize({
        Enabled: true,
        DetectionSeconds: 2,
        StableSeconds: 300,
        MaxWaitSeconds: 86400
    }, targetPath)
    AssertConfigCodec(bounded.Enabled && bounded.DetectionSeconds == 2
        && bounded.StableSeconds == 300
        && bounded.MaxWaitSeconds == 86400,
        "升级保护数值边界没有被接受")
    invalidNumbers := codec.Normalize({
        DetectionSeconds: 121,
        StableSeconds: "无效",
        MaxWaitSeconds: 59
    }, targetPath)
    AssertConfigCodec(invalidNumbers.DetectionSeconds == 10
        && invalidNumbers.StableSeconds == 8
        && invalidNumbers.MaxWaitSeconds == 1800,
        "越界或无效数值没有回退默认值")
    unsupported := codec.Normalize({Enabled: true}, "C:\Documents\demo.txt")
    AssertConfigCodec(!unsupported.Enabled,
        "不支持的目标错误启用了升级保护")

    defaultRoot := codec.Normalize({
        RootIsCustom: false,
        InstallRoot: "D:\Ignored"
    }, targetPath)
    customRoot := codec.Normalize({
        RootIsCustom: true,
        InstallRoot: "D:/软件/自定义根目录/"
    }, targetPath)
    AssertConfigCodec(defaultRoot.InstallRoot == "C:\Apps\示例"
        && customRoot.InstallRoot == "D:\软件\自定义根目录",
        "默认安装目录与自定义安装目录没有正确区分")

    actorOne := "P:C:\Apps\示例\UPDATER.EXE|R:C:\Apps\示例"
    actorDuplicate := "P:c:\apps\示例\updater.exe|R:c:\apps\示例"
    actorWrongRoot := "P:C:\Other\bad.exe|R:C:\Other"
    withActors := codec.Normalize({
        LearnedActors: [actorOne, actorDuplicate, actorWrongRoot]
    }, targetPath)
    AssertConfigCodec(withActors.LearnedActors.Length == 1
        && withActors.LearnedActors[1]
            == "P:c:\apps\示例\updater.exe|R:c:\apps\示例",
        "升级程序特征没有规范化、去重或按目录过滤")

    customConfig := {
        Enabled: true,
        RootIsCustom: true,
        InstallRoot: "D:\软件|测试",
        DetectionSeconds: 12,
        StableSeconds: 9,
        MaxWaitSeconds: 3600,
        LearnedActors: [
            "P:D:\软件|测试\更新器.exe|R:D:\软件|测试"]
    }
    decoded := codec.Deserialize(codec.Serialize(customConfig, targetPath),
        targetPath)
    expected := codec.Normalize(customConfig, targetPath)
    AssertConfigCodec(codec.Equals(decoded, expected),
        "包含 Unicode 或竖线的升级保护配置没有无损往返")

    damagedPayload := "Enabled=1`nRootIsCustom=0"
        . "`nDetectionSeconds=not-a-number`nStableSeconds=1"
        . "`nMaxWaitSeconds=999999`nMalformedLine`nUnknown=value"
    damaged := codec.Deserialize(IniFieldCodec.Encode(damagedPayload),
        targetPath)
    AssertConfigCodec(damaged.Enabled
        && damaged.DetectionSeconds == 10
        && damaged.StableSeconds == 8
        && damaged.MaxWaitSeconds == 1800,
        "损坏或越界的升级保护字段没有安全回退")

    shortcutConfig := {
        Enabled: true,
        RootIsCustom: false,
        InstallRoot: "C:\SavedRoot",
        LearnedActors: [
            "P:C:\Resolved\Updater.exe|R:C:\Resolved"]
    }
    shortcutSnapshot := codec.NormalizeSnapshot(shortcutConfig,
        "C:\Links\App.lnk", "C:\Resolved\App.exe")
    AssertConfigCodec(shortcutSnapshot.Enabled
        && shortcutSnapshot.InstallRoot == "C:\Resolved"
        && shortcutSnapshot.LearnedActors.Length == 1,
        "快捷方式快照没有使用已解析目标及其升级程序特征")
    unresolvedSnapshot := codec.NormalizeSnapshot(shortcutConfig,
        "C:\Links\App.lnk")
    AssertConfigCodec(!unresolvedSnapshot.Enabled
        && unresolvedSnapshot.InstallRoot == "C:\SavedRoot",
        "未解析快捷方式没有禁用保护或保留已保存目录")

    equivalent := codec.Clone(expected, targetPath)
    equivalent.InstallRoot := StrLower(expected.InstallRoot)
    for index, actor in equivalent.LearnedActors
        equivalent.LearnedActors[index] := StrUpper(actor)
    AssertConfigCodec(codec.Equals(expected, equivalent),
        "升级保护配置没有按路径和特征大小写等价比较")
    equivalent.MaxWaitSeconds += 1
    AssertConfigCodec(!codec.Equals(expected, equivalent),
        "不同升级保护数值被错误视为相等")

    clone := codec.Clone(withActors, targetPath)
    clone.LearnedActors.Push("extra")
    AssertConfigCodec(withActors.LearnedActors.Length == 1,
        "升级保护配置克隆仍与源特征数组共享状态")
}

try {
    RunDisplayConfigCodecTests()
    RunMaintenanceConfigCodecTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
