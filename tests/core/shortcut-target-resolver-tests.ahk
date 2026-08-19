#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证标准及安装器间接快捷方式的真实目标解析。
; 多候选、循环、目标缺失和保存身份冲突时必须保持歧义，不能随意绑定某个 EXE。

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
        this.Index := ""
    }

    HasFreshSnapshot(*) {
        return this.Fresh
    }

    GetIndex(*) {
        return this.Fresh ? this.Index : ""
    }
}

class ShortcutTargetTestResidentIndex {
    __New(running := "", uncertain := "") {
        this.Running := Type(running) == "Array" ? running : []
        this.Uncertain := Type(uncertain) == "Array" ? uncertain : []
        this.Root := ""
    }

    CollectExecutablePathsInRoot(rootPath) {
        this.Root := rootPath
        return {Running: this.Running, Uncertain: this.Uncertain}
    }
}

class InstallerProxyShortcutTargetResolver extends ShortcutTargetResolver {
    __New(snapshotService, callbacks, proxyPath, workingDirectory) {
        super.__New(snapshotService, callbacks)
        this.ProxyPath := proxyPath
        this.TestWorkingDirectory := workingDirectory
    }

    ResolveMsiTarget(*) {
        return this.ProxyPath
    }

    Read(path) {
        return ShortcutDescriptor(path, true, this.ProxyPath,
            this.TestWorkingDirectory, "")
    }
}

class UnreadableMsiShortcutTargetResolver extends ShortcutTargetResolver {
    __New(snapshotService, callbacks, msiTarget) {
        super.__New(snapshotService, callbacks)
        this.MsiTarget := msiTarget
    }

    ResolveMsiTarget(*) {
        return this.MsiTarget
    }

    Read(path) {
        return ShortcutDescriptor(path, false, "", "", "",
            "测试模拟快捷方式不可读")
    }
}

class PortableShortcutTargetResolver extends ShortcutTargetResolver {
    __New(snapshotService, callbacks, versionValues) {
        super.__New(snapshotService, callbacks)
        this.TestVersionValues := versionValues
    }

    GetExecutableVersionValues(path) {
        SplitPath(path, &fileName)
        if this.TestVersionValues.Has(fileName)
            return this.TestVersionValues[fileName]
        return super.GetExecutableVersionValues(path)
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
    proxyRoot := testRoot "\installer-proxy"
    portableRoot := testRoot "\portable"
    portableAppRoot := portableRoot "\App\Bandicam"
    portableShortcut := testRoot "\Bandicam.lnk"
    residentRoot := testRoot "\resident"
    residentRuntimeRoot := residentRoot "\Avalonia"
    residentLauncher := residentRoot "\Product.exe"
    residentProcess := residentRuntimeRoot "\Product.Avalonia.exe"
    residentSecond := residentRuntimeRoot "\Product.Worker.exe"
    residentHelper := residentRuntimeRoot "\ProductUpdater.exe"
    residentOutsideRoot := testRoot "\resident-other"
    residentOutside := residentOutsideRoot "\Product.Avalonia.exe"
    residentShortcut := testRoot "\Resident.lnk"
    try {
        try DirDelete(testRoot, true)
        DirCreate(testRoot)
        DirCreate(candidateRoot)
        DirCreate(auxiliaryRoot)
        DirCreate(ambiguousRoot)
        DirCreate(proxyRoot)
        DirCreate(portableAppRoot)
        DirCreate(residentRuntimeRoot)
        DirCreate(residentOutsideRoot)
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

        FileCopy(A_AhkPath, residentLauncher)
        FileCopy(A_AhkPath, residentProcess)
        FileCopy(A_AhkPath, residentSecond)
        FileCopy(A_AhkPath, residentHelper)
        FileCopy(A_AhkPath, residentOutside)
        FileCreateShortcut(residentLauncher, residentShortcut, residentRoot)
        snapshots.Fresh := true
        residentIndex := ShortcutTargetTestResidentIndex([residentProcess])
        snapshots.Index := residentIndex
        resolvedResident := resolver.ResolveEffective(residentShortcut,
            true, &residentSource)
        AssertShortcutTargetResolver(
            ShortcutTargetTestCanonical(resolvedResident)
                == ShortcutTargetTestCanonical(residentProcess)
            && residentSource == "安装目录特征"
            && ShortcutTargetTestCanonical(residentIndex.Root)
                == ShortcutTargetTestCanonical(residentRoot),
            "短命启动器没有解析到安装根子目录内唯一的驻留进程")

        snapshots.Index := ShortcutTargetTestResidentIndex(
            [residentProcess, residentSecond])
        AssertShortcutTargetResolver(
            ShortcutTargetTestCanonical(resolver.ResolveEffective(
                residentShortcut, true, &multipleResidentSource))
                == ShortcutTargetTestCanonical(residentLauncher)
            && multipleResidentSource == "快捷方式目标",
            "多个驻留进程候选仍被错误猜测为真实目标")

        snapshots.Index := ShortcutTargetTestResidentIndex(
            [residentProcess], [residentSecond])
        AssertShortcutTargetResolver(
            ShortcutTargetTestCanonical(resolver.ResolveEffective(
                residentShortcut, true, &uncertainResidentSource))
                == ShortcutTargetTestCanonical(residentLauncher),
            "存在身份不可核对的第二候选时仍错误学习驻留目标")

        snapshots.Index := ShortcutTargetTestResidentIndex(
            [residentOutside])
        AssertShortcutTargetResolver(
            ShortcutTargetTestCanonical(resolver.ResolveEffective(
                residentShortcut, true, &outsideResidentSource))
                == ShortcutTargetTestCanonical(residentLauncher),
            "安装根外的同类进程被错误学习为快捷方式真实目标")

        snapshots.Index := ShortcutTargetTestResidentIndex(
            [residentLauncher, residentProcess])
        AssertShortcutTargetResolver(
            ShortcutTargetTestCanonical(resolver.ResolveEffective(
                residentShortcut, true, &liveLauncherSource))
                == ShortcutTargetTestCanonical(residentLauncher),
            "启动器仍在运行时被子目录进程错误替换")

        snapshots.Index := ShortcutTargetTestResidentIndex(
            [residentProcess, residentHelper])
        AssertShortcutTargetResolver(
            ShortcutTargetTestCanonical(resolver.ResolveEffective(
                residentShortcut, true, &helperResidentSource))
                == ShortcutTargetTestCanonical(residentProcess),
            "更新辅助进程错误阻止了唯一主驻留进程的识别")

        portableLauncher := portableRoot "\BandicamPortable.exe"
        portableResident := portableAppRoot "\bdcam.exe"
        portableHelper := portableAppRoot "\bdfix.exe"
        FileCopy(A_AhkPath, portableLauncher)
        FileCopy(A_AhkPath, portableResident)
        FileCopy(A_AhkPath, portableHelper)
        FileCreateShortcut(portableLauncher, portableShortcut, portableRoot)
        portableVersions := Map(
            "BandicamPortable.exe", Map(
                "ProductName", "Bandicam Portable",
                "FileDescription", "Bandicam Portable"),
            "bdcam.exe", Map(
                "ProductName", "Bandicam 2025",
                "FileDescription", "Bandicam - bdcam.exe"),
            "bdfix.exe", Map(
                "ProductName", "BandiFix",
                "FileDescription", "BandiFix"))
        portableResolver := PortableShortcutTargetResolver(snapshots,
            resolver.Callbacks, portableVersions)
        resolvedPortableTarget := portableResolver.ResolveEffective(
            portableShortcut, true, &portableSource)
        AssertShortcutTargetResolver(
            portableResolver.IsPortableLauncher(portableLauncher)
            && ShortcutTargetTestCanonical(resolvedPortableTarget)
                == ShortcutTargetTestCanonical(portableResident)
            && portableSource == "安装目录特征",
            "便携启动器没有解析到有强版本证据的真实常驻程序"
                . "（target=" resolvedPortableTarget "，source="
                    portableSource "）")

        installerProxy := "C:\Windows\Installer\{12345678-1234-1234-1234-1234567890AB}\_E8A816F7FAA0F313565BDA.exe"
        proxyCandidate := proxyRoot "\OneCommander.exe"
        FileCopy(A_AhkPath, proxyCandidate, true)
        proxyResolver := InstallerProxyShortcutTargetResolver(snapshots,
            resolver.Callbacks, installerProxy, proxyRoot)
        resolvedProxyTarget := proxyResolver.ResolveEffective(
            testRoot "\OneCommander.lnk", true, &proxySource)
        AssertShortcutTargetResolver(
            proxyResolver.IsInstallerCacheProxy(installerProxy)
            && !proxyResolver.IsInstallerCacheProxy(A_AhkPath),
            "Windows Installer 广告快捷方式代理分类错误")
        AssertShortcutTargetResolver(
            ShortcutTargetTestCanonical(resolvedProxyTarget)
                == ShortcutTargetTestCanonical(proxyCandidate)
            && proxySource == "安装目录特征",
            "广告快捷方式错误优先采用安装器缓存代理，而非工作目录中的真实主程序"
                . "（target=" resolvedProxyTarget "，source=" proxySource "）")
        unreadableMsiResolver := UnreadableMsiShortcutTargetResolver(
            snapshots, resolver.Callbacks, A_AhkPath)
        unreadableMsiTarget := unreadableMsiResolver.ResolveEffective(
            testRoot "\UnreadableMsi.lnk", true, &unreadableMsiSource)
        AssertShortcutTargetResolver(unreadableMsiTarget == A_AhkPath
            && unreadableMsiSource == "Windows Installer",
            "快捷方式不可读时解析到的 MSI 目标没有保留来源")
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
