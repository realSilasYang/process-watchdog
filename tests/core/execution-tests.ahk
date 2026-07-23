#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\Core\TargetSpecs.ahk
#Include ..\..\src\Execution\TargetLauncher.ahk
#Include ..\..\src\Execution\TargetStopper.ahk

AssertExecution(value, message) {
    if !value
        throw Error(message)
}

AssertExecutionEqual(expected, actual, message) {
    if (expected != actual)
        throw Error(message "（预期 " expected "，实际 " actual "）")
}

AssertExecutionThrows(callback, message) {
    didThrow := false
    try callback.Call()
    catch
        didThrow := true
    if !didThrow
        throw Error(message)
}

RunExecutionTests() {
    launcher := TargetLauncher()

    batchSpec := LaunchSpec(TargetLaunchKind.Batch,
        "C:\Jobs\daily backup.cmd", "--mode=quick", "", "", false)
    batchInvocation := launcher.BuildInvocation(batchSpec, "", false,
        "C:\Logs\daily backup.log")
    AssertExecutionEqual("Hide", batchInvocation.Options,
        "批处理启动必须隐藏控制台窗口")
    AssertExecution(InStr(batchInvocation.Command,
        'cmd /d /c ""C:\Jobs\daily backup.cmd" --mode=quick'),
        "批处理命令没有保留带空格路径和参数")
    AssertExecution(InStr(batchInvocation.Command,
        '>> "C:\Logs\daily backup.log" 2>&1"'),
        "批处理命令没有重定向标准输出和错误输出")

    ahkSpec := LaunchSpec(TargetLaunchKind.AutoHotkey,
        "C:\Jobs\watch.ahk", "--once")
    ahkInvocation := launcher.BuildInvocation(ahkSpec, A_AhkPath, false)
    AssertExecutionEqual('"' A_AhkPath '" "C:\Jobs\watch.ahk" --once',
        ahkInvocation.Command, "AHK 源脚本没有通过当前解释器启动")

    compiledAhkInvocation := launcher.BuildInvocation(ahkSpec, A_AhkPath,
        true)
    AssertExecutionEqual('"C:\Jobs\watch.ahk" --once',
        compiledAhkInvocation.Command,
        "编译版不应尝试借用自身路径解释 AHK 源脚本")

    powershellSpec := LaunchSpec(TargetLaunchKind.PowerShell,
        "C:\Jobs\deploy.ps1", "-Mode Safe")
    powershellInvocation := launcher.BuildInvocation(powershellSpec)
    AssertExecutionEqual(
        'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Jobs\deploy.ps1" -Mode Safe',
        powershellInvocation.Command, "PowerShell 启动命令错误")

    elevatedSpec := LaunchSpec(TargetLaunchKind.Direct,
        "C:\Apps\Tool.exe", "--quiet", "", "", true)
    elevatedInvocation := launcher.BuildInvocation(elevatedSpec)
    AssertExecutionEqual('*RunAs "C:\Apps\Tool.exe" --quiet',
        elevatedInvocation.Command, "管理员直接启动命令错误")

    aliasSpec := LaunchSpec(TargetLaunchKind.Direct, "notepad.exe")
    AssertExecutionEqual("notepad.exe",
        launcher.BuildInvocation(aliasSpec).Command,
        "无路径进程别名不应被错误包裹")

    testRoot := A_Temp "\watchdog-execution-" A_TickCount
    targetDirectory := testRoot "\target"
    configuredDirectory := testRoot "\configured"
    DirCreate(targetDirectory)
    DirCreate(configuredDirectory)
    try {
        configuredWorkDirSpec := LaunchSpec(TargetLaunchKind.Direct,
            targetDirectory "\Tool.exe", "", configuredDirectory)
        AssertExecutionEqual(configuredDirectory,
            launcher.ResolveWorkingDirectory(configuredWorkDirSpec),
            "有效的用户工作目录没有获得优先权")

        fallbackWorkDirSpec := LaunchSpec(TargetLaunchKind.Direct,
            targetDirectory "\Tool.exe", "", testRoot "\missing")
        AssertExecutionEqual(targetDirectory,
            launcher.ResolveWorkingDirectory(fallbackWorkDirSpec),
            "无效工作目录没有回退到目标所在目录")
    } finally {
        try DirDelete(testRoot, true)
    }

    variables := launcher.ParseEnvironment(
        "WATCHDOG_ALPHA=one`nINVALID NAME=ignored`nWATCHDOG_TOKEN=a=b=c")
    AssertExecutionEqual(2, variables.Count,
        "环境变量解析没有过滤无效变量名")
    AssertExecutionEqual("one", variables["watchdog_alpha"],
        "环境变量映射应忽略名称大小写")
    AssertExecutionEqual("a=b=c", variables["WATCHDOG_TOKEN"],
        "环境变量值中的等号不应被截断")
    systemRootState := launcher.CaptureEnvironment("SystemRoot")
    AssertExecution(systemRootState.Exists && systemRootState.Value != "",
        "启动器无法捕获现有环境变量")
    missingVariableState := launcher.CaptureEnvironment(
        "WATCHDOG_TEST_MISSING_" A_TickCount)
    AssertExecution(!missingVariableState.Exists,
        "启动器把不存在的环境变量误判为已有空值")

    unavailableSpec := LaunchSpec(TargetLaunchKind.Direct, "", "", "",
        "", false, false, false, "测试目标不可用")
    AssertExecutionThrows(
        ObjBindMethod(launcher, "BuildInvocation", unavailableSpec),
        "不可用启动规格必须被执行器拒绝")

    stopper := TargetStopper()
    missingPid := 0x7FFFFFFF
    AssertExecution(!ProcessExist(missingPid), "测试使用的 PID 意外存在")
    missingResult := stopper.Stop(missingPid, 0, 0, false)
    AssertExecution(missingResult.Stopped,
        "不存在的 PID 应视为已经停止")
    AssertExecutionEqual(TargetStopStage.AlreadyStopped, missingResult.Stage,
        "不存在 PID 的停止阶段错误")
    currentPid := DllCall("kernel32\GetCurrentProcessId", "UInt")
    AssertExecution(!stopper.WaitUntilStopped(currentPid, 0),
        "停止等待超时不得误判仍在运行的进程已经退出")

}

try {
    RunExecutionTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.File " (" testError.Line "): " testError.Message
        "`n", "**")
    ExitApp(1)
}
