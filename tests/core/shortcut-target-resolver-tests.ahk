#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\Core\TargetSpecs.ahk
#Include ..\..\src\Inspection\ShortcutResolver.ahk
#Include ..\..\src\Inspection\ShortcutTargetResolver.ahk

AssertShortcutTargetResolver(value, message) {
    if !value
        throw Error(message)
}

class ShortcutTargetTestSnapshots {
    __New() {
        this.Fresh := false
        this.LatestSnapshot := []
    }

    HasFreshSnapshot(*) {
        return this.Fresh
    }
}

ShortcutTargetTestCanonical(path) {
    path := StrLower(StrReplace(Trim(String(path), ' `t`r`n"'), "/", "\"))
    if (path == "")
        return ""
    fullPathBuffer := Buffer(32768 * 2, 0)
    fullLength := DllCall("kernel32\GetFullPathNameW", "Str", path,
        "UInt", 32768, "Ptr", fullPathBuffer, "Ptr", 0, "UInt")
    fullPath := fullLength && fullLength < 32768
        ? StrGet(fullPathBuffer, fullLength, "UTF-16") : path
    if FileExist(fullPath) {
        longPathBuffer := Buffer(32768 * 2, 0)
        longLength := DllCall("kernel32\GetLongPathNameW", "WStr", fullPath,
            "Ptr", longPathBuffer, "UInt", 32768, "UInt")
        if longLength && longLength < 32768
            fullPath := StrGet(longPathBuffer, longLength, "UTF-16")
    }
    if SubStr(fullPath, 1, 4) == "\\?\"
        fullPath := SubStr(fullPath, 5)
    return StrLower(StrLen(fullPath) > 3 ? RTrim(fullPath, "\") : fullPath)
}

ShortcutTargetTestNormalize(path) {
    return StrReplace(Trim(String(path), ' `t`r`n"'), "/", "\")
}

ShortcutTargetTestFingerprint(path) {
    try return FileGetSize(path) "|" FileGetTime(path, "M")
    catch
        return "MISSING"
}

CreateShortcutTargetResolverForTest(snapshotService) {
    return ShortcutTargetResolver(snapshotService, {
        CanonicalPath: ShortcutTargetTestCanonical,
        GetFileFingerprint: ShortcutTargetTestFingerprint,
        NormalizeTargetPath: ShortcutTargetTestNormalize,
        ReadShortcut: ObjBindMethod(ShortcutResolver, "Read")
    })
}

RunShortcutTargetResolverTests() {
    snapshots := ShortcutTargetTestSnapshots()
    resolver := CreateShortcutTargetResolverForTest(snapshots)
    testId := DllCall("kernel32\GetCurrentProcessId", "UInt")
    testRoot := A_Temp "\watchdog-shortcut-target-" testId
    directShortcut := testRoot "\Direct.lnk"
    argumentShortcut := testRoot "\Argument.lnk"
    scriptPath := testRoot "\含空格的脚本.ahk"
    candidateRoot := testRoot "\candidates"
    auxiliaryRoot := testRoot "\auxiliary"
    ambiguousRoot := testRoot "\ambiguous"
    try {
        try DirDelete(testRoot, true)
        DirCreate(testRoot)
        DirCreate(candidateRoot)
        DirCreate(auxiliaryRoot)
        DirCreate(ambiguousRoot)
        FileAppend("#Requires AutoHotkey v2.0`n", scriptPath, "UTF-8")
        FileCreateShortcut(A_AhkPath, directShortcut, testRoot)
        FileCreateShortcut(A_AhkPath, argumentShortcut, testRoot,
            '"' scriptPath '" --inner')

        descriptor := resolver.Read(directShortcut)
        AssertShortcutTargetResolver(descriptor.Readable
            && descriptor.TargetPath == A_AhkPath
            && resolver.GetTargetPath(directShortcut) == A_AhkPath
            && resolver.GetWorkingDirectory(directShortcut) == testRoot,
            "快捷方式描述没有通过注入读取器完整返回")
        directTarget := resolver.ResolveEffective(directShortcut, false,
            &directSource)
        AssertShortcutTargetResolver(directTarget == A_AhkPath
            && directSource == "快捷方式目标",
            "普通快捷方式没有解析到直接目标")
        argumentTarget := resolver.ResolveEffective(argumentShortcut, false,
            &argumentSource)
        AssertShortcutTargetResolver(argumentTarget == scriptPath
            && argumentSource == "快捷方式参数",
            "通用启动器快捷方式没有优先解析参数中的真实目标")
        AssertShortcutTargetResolver(
            resolver.ExtractArgumentTarget('prefix="' scriptPath '" --flag')
                == scriptPath,
            "带 Unicode 和空格的参数目标没有被提取")

        AssertShortcutTargetResolver(
            resolver.IsGenericLauncher(A_AhkPath)
            && resolver.IsGenericLauncher("C:\Windows\System32\cmd.exe")
            && !resolver.IsGenericLauncher("C:\Apps\Product.exe"),
            "通用启动器分类错误")
        AssertShortcutTargetResolver(resolver.IsUsableTarget(A_AhkPath)
            && resolver.IsUsableTarget(scriptPath)
            && !resolver.IsUsableTarget(testRoot),
            "快捷方式真实目标可用性判断错误")

        missingShortcut := testRoot "\Missing.lnk"
        savedTarget := resolver.ResolveForState(missingShortcut,
            "C:/Saved/App.exe", &savedSource)
        AssertShortcutTargetResolver(savedTarget == "C:\Saved\App.exe"
            && savedSource == "已保存身份",
            "缺失快捷方式没有回退到已保存的精确进程身份：target="
                savedTarget "，source=" savedSource)
        manualTarget := resolver.ResolveForState(missingShortcut,
            "D:/Manual/应用.py", &manualSource, true)
        AssertShortcutTargetResolver(manualTarget == "D:\Manual\应用.py"
            && manualSource == "用户指定",
            "用户指定的真实目标没有优先保留")
        invalidTarget := resolver.ResolveForState(missingShortcut,
            "C:\Docs\readme.txt", &invalidSource)
        AssertShortcutTargetResolver(invalidTarget == ""
            && invalidSource == "",
            "非精确已保存目标被错误接受")

        onlyCandidate := candidateRoot "\OnlyApp.exe"
        FileCopy(A_AhkPath, onlyCandidate)
        resolvedOnlyCandidate := resolver.FindExecutableCandidate(
            testRoot "\Whatever.lnk", candidateRoot)
        AssertShortcutTargetResolver(
            ShortcutTargetTestCanonical(resolvedOnlyCandidate)
                == ShortcutTargetTestCanonical(onlyCandidate),
            "安装目录中的唯一主程序没有被选中")
        updaterCandidate := auxiliaryRoot "\ProductUpdater.exe"
        FileCopy(A_AhkPath, updaterCandidate)
        AssertShortcutTargetResolver(
            resolver.FindExecutableCandidate(testRoot "\Product.lnk",
                auxiliaryRoot) == "",
            "唯一更新辅助程序被错误选为主进程")

        widgetOne := ambiguousRoot "\WidgetOne.exe"
        widgetTwo := ambiguousRoot "\WidgetTwo.exe"
        FileCopy(A_AhkPath, widgetOne)
        FileCopy(A_AhkPath, widgetTwo)
        AssertShortcutTargetResolver(
            resolver.FindExecutableCandidate(testRoot "\Widget.lnk",
                ambiguousRoot) == "",
            "同分候选没有因证据歧义而拒绝")
        snapshots.Fresh := true
        snapshots.LatestSnapshot := [{exe: widgetTwo}]
        observedCandidate := resolver.FindExecutableCandidate(
            testRoot "\Widget.lnk", ambiguousRoot)
        AssertShortcutTargetResolver(
            ShortcutTargetTestCanonical(observedCandidate)
                == ShortcutTargetTestCanonical(widgetTwo),
            "已观察到的真实进程没有用于解除候选歧义")

        firstVersionValues := resolver.GetExecutableVersionValues(A_AhkPath)
        secondVersionValues := resolver.GetExecutableVersionValues(A_AhkPath)
        AssertShortcutTargetResolver(ObjPtr(firstVersionValues)
            == ObjPtr(secondVersionValues),
            "未变化可执行文件的版本信息缓存没有复用")
        AssertShortcutTargetResolver(
            resolver.ResolveMsiTarget(directShortcut) == "",
            "普通非 MSI 快捷方式被错误识别为广告快捷方式")
    } finally {
        try DirDelete(testRoot, true)
    }
}

try {
    RunShortcutTargetResolverTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
