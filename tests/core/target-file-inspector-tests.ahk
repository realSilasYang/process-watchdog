#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\Inspection\TargetFileInspector.ahk

AssertTargetFileInspector(value, message) {
    if !value
        throw Error(message)
}

TargetFileTestIsSupported(path) {
    SplitPath(path, , , &extension)
    return RegExMatch(extension, "i)^(exe|com|ahk|lnk)$") != 0
}

TargetFileTestGetSubject(path) {
    SplitPath(path, , , &extension)
    return StrLower(extension) == "lnk" ? A_AhkPath : path
}

TargetFileTestCanonical(path) {
    path := StrLower(StrReplace(Trim(String(path)), "/", "\"))
    return StrLen(path) > 3 ? RTrim(path, "\") : path
}

CreateTargetFileInspectorForTest() {
    return TargetFileInspector({
        CanonicalPath: TargetFileTestCanonical,
        GetSubjectPath: TargetFileTestGetSubject,
        IsSupportedTarget: TargetFileTestIsSupported
    })
}

RunTargetFileInspectorTests() {
    inspector := CreateTargetFileInspectorForTest()
    testId := DllCall("kernel32\GetCurrentProcessId", "UInt")
    scriptPath := A_Temp "\watchdog-target-file-" testId ".ahk"
    sameSizePath := A_Temp "\watchdog-target-same-size-" testId ".ahk"
    emptyPath := A_Temp "\watchdog-target-empty-" testId ".ahk"
    damagedExePath := A_Temp "\watchdog-target-damaged-" testId ".exe"
    missingPath := A_Temp "\watchdog-target-missing-" testId ".exe"
    directoryPath := A_Temp "\watchdog-target-directory-" testId ".exe"
    try {
        for path in [scriptPath, sameSizePath, emptyPath, damagedExePath,
            missingPath]
            try FileDelete(path)
        try DirDelete(directoryPath)
        FileAppend("#Requires AutoHotkey v2.0`n", scriptPath, "UTF-8")
        FileAppend("AAAA", sameSizePath, "UTF-8-RAW")
        FileOpen(emptyPath, "w").Close()
        FileAppend("MZ-not-a-complete-image", damagedExePath, "UTF-8-RAW")
        DirCreate(directoryPath)

        AssertTargetFileInspector(
            inspector.GetFingerprint("C:\unsupported.txt") == "MISSING"
            && inspector.GetFingerprint(missingPath) == "MISSING"
            && inspector.GetFingerprint(directoryPath) == "MISSING",
            "不支持、缺失或目录目标没有返回 MISSING 指纹")
        firstFingerprint := inspector.GetFingerprint(scriptPath)
        FileAppend("; changed`n", scriptPath, "UTF-8")
        secondFingerprint := inspector.GetFingerprint(scriptPath)
        AssertTargetFileInspector(firstFingerprint != "MISSING"
            && InStr(firstFingerprint, "||")
            && secondFingerprint != firstFingerprint,
            "文件指纹没有稳定标识文件或检测内容变化")
        sameSizeBefore := inspector.GetFingerprint(sameSizePath)
        Sleep(20)
        sameSizeFile := FileOpen(sameSizePath, "w", "UTF-8-RAW")
        sameSizeFile.Write("BBBB")
        sameSizeFile.Close()
        sameSizeAfter := inspector.GetFingerprint(sameSizePath)
        AssertTargetFileInspector(sameSizeAfter != sameSizeBefore,
            "同秒同尺寸覆盖没有被高精度文件时间识别")
        AssertTargetFileInspector(
            inspector.GetFingerprint("C:\Link\App.lnk")
                == inspector.GetFingerprint(A_AhkPath),
            "快捷方式没有使用实际维护目标计算指纹")

        AssertTargetFileInspector(inspector.IsReady(scriptPath),
            "完整的非 PE 脚本被错误识别为不可用")
        AssertTargetFileInspector(!inspector.IsReady(emptyPath),
            "空脚本被错误识别为更新完成")
        AssertTargetFileInspector(!inspector.IsReady(damagedExePath),
            "损坏的 PE 文件被错误识别为更新完成")
        AssertTargetFileInspector(!inspector.IsReady(directoryPath),
            "带可执行扩展名的目录被错误识别为更新完成")
        AssertTargetFileInspector(inspector.IsReady(A_AhkPath),
            "真实 PE 可执行文件没有通过完整性检查")
        AssertTargetFileInspector(inspector.IsReady("C:\unsupported.txt")
            && !inspector.IsReady(missingPath),
            "不支持目标与缺失支持目标的就绪语义错误")

        lockHandle := DllCall("kernel32\CreateFileW", "WStr", scriptPath,
            "UInt", 0x40000000, "UInt", 0, "Ptr", 0,
            "UInt", Win32.OPEN_EXISTING, "UInt", Win32.FILE_ATTRIBUTE_NORMAL,
            "Ptr", 0, "Ptr")
        AssertTargetFileInspector(lockHandle && lockHandle != -1,
            "测试无法建立文件独占写入锁")
        try AssertTargetFileInspector(!inspector.IsReady(scriptPath),
            "仍被写入方独占的文件被错误识别为稳定")
        finally DllCall("kernel32\CloseHandle", "Ptr", lockHandle)

        AssertTargetFileInspector(
            inspector.IsWithinRoot("C:\Product\bin\App.exe", "c:/product")
            && inspector.IsWithinRoot("C:\Product", "C:\Product\")
            && !inspector.IsWithinRoot("C:\Product2\App.exe", "C:\Product")
            && !inspector.IsWithinRoot("", "C:\Product"),
            "路径作用根边界判断错误")
    } finally {
        for path in [scriptPath, sameSizePath, emptyPath, damagedExePath,
            missingPath]
            try FileDelete(path)
        try DirDelete(directoryPath)
    }
}

try {
    RunTargetFileInspectorTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
