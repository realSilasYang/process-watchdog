; 独立 EXE 启动器模板。构建脚本会注入版本、载荷哈希和正式入口名称，
; 再把便携 ZIP 与安装器作为资源嵌入；本文件不作为源码版运行入口。

;@Ahk2Exe-SetName 进程守护小助手
;@Ahk2Exe-SetDescription 进程、脚本和快捷方式守护工具
;@Ahk2Exe-SetVersion __PAYLOAD_VERSION__.0
;@Ahk2Exe-SetCopyright Copyright (c) 2026 进程守护小助手 contributors
;@Ahk2Exe-SetMainIcon watchdog.ico

#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

payloadVersion := "__PAYLOAD_VERSION__"
payloadSha256 := "__PAYLOAD_SHA256__"
payloadEntry := "__PAYLOAD_ENTRY__"
localAppData := EnvGet("LOCALAPPDATA")
if localAppData == ""
    localAppData := A_AppData
installRoot := localAppData "\ProcessWatchdog\Standalone"
entryPath := installRoot "\" payloadEntry
markerPath := installRoot "\.standalone-payload.sha256"

installMutex := DllCall("kernel32\CreateMutexW", "Ptr", 0, "Int", false,
    "WStr", "Local\ProcessWatchdogStandaloneInstall", "Ptr")
if !installMutex
    StandaloneFail("无法建立独立版安装锁。", "Could not create the standalone installation lock.")
waitResult := DllCall("kernel32\WaitForSingleObject", "Ptr", installMutex,
    "UInt", 120000, "UInt")
if waitResult != 0 && waitResult != 0x80 {
    DllCall("kernel32\CloseHandle", "Ptr", installMutex)
    StandaloneFail("等待独立版安装锁超时。", "Timed out waiting for the standalone installation lock.")
}

try {
    if StandaloneNeedsInstall(installRoot, entryPath, markerPath,
        payloadVersion, payloadSha256) {
        ; 内层程序仍在运行时不替换它正在使用的资源。启动现有入口即可让主程序
        ; 激活已有窗口；它自己的自动更新仍会在退出交接后安全完成升级。
        runningMutex := DllCall("kernel32\OpenMutexW", "UInt", 0x00100000,
            "Int", false, "WStr", "Global\Watchdog_Mutex_Strict", "Ptr")
        if runningMutex {
            DllCall("kernel32\CloseHandle", "Ptr", runningMutex)
            ; 构建验收把 LOCALAPPDATA 指向隔离目录，允许它在不触碰用户实例的
            ; 情况下验证单文件载荷。普通启动仍绝不替换正在运行的正式安装。
            if !StandaloneHasArgument("--startup-validation") {
                if FileExist(entryPath)
                    StandaloneLaunch(entryPath, installRoot)
                StandaloneFail("正在运行的小助手缺少完整安装文件，请先退出后重试。",
                    "The running application has an incomplete installation. Exit it and try again.")
            }
        }
        StandaloneInstall(installRoot, payloadVersion, payloadSha256)
    }
} finally {
    DllCall("kernel32\ReleaseMutex", "Ptr", installMutex)
    DllCall("kernel32\CloseHandle", "Ptr", installMutex)
}

if !FileExist(entryPath)
    StandaloneFail("独立版安装完成后仍找不到程序入口。",
        "The application entry is missing after standalone installation.")
StandaloneLaunch(entryPath, installRoot)

StandaloneNeedsInstall(root, entry, marker, embeddedVersion, embeddedHash) {
    try installedVersion := Trim(FileRead(root "\VERSION", "UTF-8"))
    catch
        return true
    comparison := CompareStandaloneVersions(installedVersion, embeddedVersion)
    ; 先判版本，再检查资源完整性。较新的内层安装即使损坏也不能由旧启动器
    ; “修复”为旧版；后续入口检查会明确失败并提示用户使用新版重新安装。
    if comparison > 0
        return false
    for requiredPath in [entry, root "\assets", root "\runtime",
        root "\third_party"] {
        if !FileExist(requiredPath)
            return true
    }
    if comparison < 0
        return true
    try installedMarker := Trim(FileRead(marker, "UTF-8"))
    catch
        return true
    return installedMarker != embeddedHash
}

CompareStandaloneVersions(leftVersion, rightVersion) {
    if !RegExMatch(leftVersion, "^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$", &left)
        return -1
    if !RegExMatch(rightVersion, "^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$", &right)
        return 1
    Loop 3 {
        leftPart := Integer(left[A_Index])
        rightPart := Integer(right[A_Index])
        if leftPart != rightPart
            return leftPart > rightPart ? 1 : -1
    }
    return 0
}

StandaloneInstall(root, version, expectedHash) {
    workRoot := A_Temp "\ProcessWatchdogStandalone-" ProcessExist()
    try DirDelete(workRoot, true)
    DirCreate(workRoot)
    archivePath := workRoot "\payload.zip"
    installerPath := workRoot "\standalone-install.ps1"
    logPath := workRoot "\install.log"
    FileInstall "payload.zip", archivePath, true
    FileInstall "standalone-install.ps1", installerPath, true
    powershellPath := A_WinDir
        . "\System32\WindowsPowerShell\v1.0\powershell.exe"
    marker := expectedHash
    command := QuoteStandaloneArgument(powershellPath)
        . " -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "
        . QuoteStandaloneArgument(installerPath)
        . " -ArchivePath " QuoteStandaloneArgument(archivePath)
        . " -InstallRoot " QuoteStandaloneArgument(root)
        . " -ExpectedVersion " QuoteStandaloneArgument(version)
        . " -ExpectedSha256 " QuoteStandaloneArgument(expectedHash)
        . " -PayloadMarker " QuoteStandaloneArgument(marker)
        . " > " QuoteStandaloneArgument(logPath) " 2>&1"
    exitCode := RunWait(A_ComSpec " /D /S /C "
        . QuoteStandaloneArgument(command), workRoot, "Hide")
    if exitCode != 0 {
        try details := Trim(FileRead(logPath, "UTF-8"))
        catch
            details := ""
        StandaloneFail("独立版资源安装失败。", "Standalone resource installation failed.", details)
    }
    try DirDelete(workRoot, true)
}

StandaloneLaunch(entryPath, workingDirectory) {
    command := QuoteStandaloneArgument(entryPath)
    for argument in A_Args
        command .= " " QuoteStandaloneArgument(argument)
    for argument in A_Args {
        if StrLower(argument) == "--startup-validation" {
            exitCode := RunWait(command, workingDirectory, "Hide")
            ExitApp(exitCode)
        }
    }
    Run(command, workingDirectory)
    ExitApp(0)
}

StandaloneHasArgument(expectedArgument) {
    for argument in A_Args {
        if StrLower(argument) == StrLower(expectedArgument)
            return true
    }
    return false
}

QuoteStandaloneArgument(value) {
    value := String(value)
    if value == ""
        return '""'
    if !RegExMatch(value, '[\s"]')
        return value
    result := '"'
    slashCount := 0
    Loop Parse value {
        character := A_LoopField
        if character == "\" {
            slashCount++
            continue
        }
        if character == '"' {
            result .= StandaloneRepeat("\", slashCount * 2 + 1) '"'
            slashCount := 0
            continue
        }
        result .= StandaloneRepeat("\", slashCount) character
        slashCount := 0
    }
    return result StandaloneRepeat("\", slashCount * 2) '"'
}

StandaloneRepeat(text, count) {
    result := ""
    Loop count
        result .= text
    return result
}

StandaloneFail(chinese, english, details := "") {
    message := SubStr(A_Language, 1, 2) == "04" ? chinese : english
    if details != ""
        message .= "`n`n" SubStr(details, 1, 3000)
    if StandaloneHasArgument("--startup-validation") {
        logPath := A_Temp "\ProcessWatchdogStandaloneValidation-"
            . ProcessExist() ".log"
        try FileAppend(message "`r`n", logPath, "UTF-8")
        ExitApp(1)
    }
    title := SubStr(A_Language, 1, 2) == "04"
        ? "进程守护小助手" : "Process Watchdog Assistant"
    try MsgBox(message, title, "Iconx")
    ExitApp(1)
}
