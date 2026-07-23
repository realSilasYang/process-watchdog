#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\..\src\Diagnostics\DiagnosticBundleService.ahk

AssertDiagnosticBundle(condition, message) {
    if !condition
        throw Error(message)
}

DiagnosticStateProvider() {
    return "TargetCount=2`r`nGuardPhase.Running=1`r`n"
}

DiagnosticLogProvider() {
    return "2026-07-23 12:00:00 test log`r`n"
}

class DiagnosticArchiveProbe {
    __New() {
        this.SourceDirectory := ""
        this.ManifestText := ""
        this.StateText := ""
        this.LogText := ""
        this.SupportText := ""
    }

    Create(sourceDirectory, archivePath) {
        this.SourceDirectory := sourceDirectory
        this.ManifestText := FileRead(sourceDirectory "\environment.txt",
            "UTF-8")
        this.StateText := FileRead(sourceDirectory "\runtime-state.txt",
            "UTF-8")
        this.LogText := FileRead(sourceDirectory "\runtime-log.txt", "UTF-8")
        this.SupportText := FileRead(sourceDirectory "\support.txt", "UTF-8")
        FileAppend("PK`x03`x04diagnostic-test", archivePath, "UTF-8-RAW")
    }
}

RunDiagnosticBundleTests() {
    testRoot := A_Temp "\watchdog-diagnostic-test-"
        DllCall("kernel32\GetCurrentProcessId", "UInt")
    try DirDelete(testRoot, true)
    DirCreate(testRoot)
    try {
        supportPath := testRoot "\support.txt"
        FileAppend("support-data", supportPath, "UTF-8")
        probe := DiagnosticArchiveProbe()
        service := DiagnosticBundleService("9.8.7", {
            State: DiagnosticStateProvider,
            Logs: DiagnosticLogProvider
        }, [supportPath], ObjBindMethod(probe, "Create"))

        archivePath := service.Export(testRoot)
        AssertDiagnosticBundle(FileExist(archivePath),
            "诊断服务没有生成压缩包")
        AssertDiagnosticBundle(InStr(probe.ManifestText, "Version=9.8.7")
            && InStr(probe.ManifestText, "PointerBits=64"),
            "诊断环境清单缺少版本或架构")
        AssertDiagnosticBundle(InStr(probe.StateText, "TargetCount=2")
            && InStr(probe.LogText, "test log")
            && probe.SupportText == "support-data",
            "诊断包没有完整收集状态、日志或支持文件")
        AssertDiagnosticBundle(!DirExist(probe.SourceDirectory),
            "诊断包完成后遗留了临时目录")

        occupiedPath := testRoot "\process-watchdog-diagnostics-"
            FormatTime(, "yyyyMMdd-HHmmss") ".zip"
        if occupiedPath != archivePath
            FileAppend("occupied", occupiedPath)
        secondArchive := service.Export(testRoot)
        AssertDiagnosticBundle(secondArchive != archivePath
            && FileExist(secondArchive),
            "同秒重复导出覆盖了已有诊断包")

        realService := DiagnosticBundleService("9.8.7", {
            State: DiagnosticStateProvider,
            Logs: DiagnosticLogProvider
        }, [supportPath])
        realArchive := realService.Export(testRoot)
        archiveFile := FileOpen(realArchive, "r")
        signature := archiveFile.Read(2)
        archiveFile.Close()
        AssertDiagnosticBundle(FileGetSize(realArchive) > 100
            && signature == "PK",
            "系统压缩集成没有生成有效 ZIP 诊断包")
    } finally {
        try DirDelete(testRoot, true)
    }
}

try {
    RunDiagnosticBundleTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
