#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证目标启动与分级停止的规格、命令构造和环境隔离。
; 覆盖管理员启动、脚本宿主、正常关闭与超时结果，不实际终止用户进程。

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

ResolveExecutionIdentity(identityState, pid) {
    return identityState.Has(pid) ? identityState[pid] : ""
}

class RecordingTargetStopper extends TargetStopper {
    __New(identityResolver) {
        super.__New(identityResolver)
        this.WindowCloseRequests := 0
    }

    RequestWindowClose(*) {
        this.WindowCloseRequests++
        return true
    }
}

class NoWindowTargetStopper extends TargetStopper {
    __New(identityResolver) {
        super.__New(identityResolver)
        this.WaitCalls := 0
    }

    RequestWindowClose(*) {
        return false
    }

    WaitUntilStopped(*) {
        this.WaitCalls++
        return false
    }
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

    pythonRuntime := "C:\Python\python.exe"
    pythonSpec := LaunchSpec(TargetLaunchKind.Direct,
        "C:\Jobs\worker.py", "--port 8080", "", "", false, true,
        false, "", pythonRuntime, "-I -u")
    pythonInvocation := launcher.BuildInvocation(pythonSpec)
    AssertExecutionEqual(
        '"C:\Python\python.exe" -I -u "C:\Jobs\worker.py" --port 8080',
        pythonInvocation.Command,
        "自定义运行时、运行时参数、目标和目标参数的顺序错误")

    javaSpec := LaunchSpec(TargetLaunchKind.Direct,
        "C:\Jobs\service.jar", "--spring.profiles.active=prod", "", "",
        false, true, false, "", "C:\Java\bin\java.exe", "-jar")
    AssertExecutionEqual(
        '"C:\Java\bin\java.exe" -jar "C:\Jobs\service.jar" --spring.profiles.active=prod',
        launcher.BuildInvocation(javaSpec).Command,
        "JAR 没有按通用运行时链构造")

    customBatchSpec := LaunchSpec(TargetLaunchKind.Batch,
        "C:\Jobs\daily backup.cmd", "--quiet", "", "", false, true,
        false, "", "C:\Tools\wrapper.exe", "--capture")
    customBatchInvocation := launcher.BuildInvocation(customBatchSpec, "",
        false, "C:\Logs\custom batch.log")
    AssertExecution(customBatchInvocation.Options == "Hide"
        && InStr(customBatchInvocation.Command,
            'cmd /d /c ""C:\Tools\wrapper.exe" --capture "C:\Jobs\daily backup.cmd" --quiet')
        && InStr(customBatchInvocation.Command,
            '>> "C:\Logs\custom batch.log" 2>&1"'),
        "自定义运行时破坏了批处理输出捕获")

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
    strictEnvironment := launcher.ValidateEnvironment(
        "WATCHDOG_ALPHA= one `nWATCHDOG_TOKEN=a=b=c")
    AssertExecution(strictEnvironment.Valid
        && strictEnvironment.Variables.Count == 2
        && strictEnvironment.Variables["WATCHDOG_ALPHA"] == " one "
        && strictEnvironment.Normalized
            == "WATCHDOG_ALPHA= one `nWATCHDOG_TOKEN=a=b=c",
        "严格环境变量解析没有保留值内容或规范化有效配置")
    missingSeparator := launcher.ValidateEnvironment(
        "WATCHDOG_ALPHA=one`nBROKEN_LINE")
    AssertExecution(!missingSeparator.Valid
        && missingSeparator.ErrorCode == "MissingSeparator"
        && missingSeparator.LineNumber == 2,
        "严格环境变量解析没有定位缺少等号的行")
    invalidVariableName := launcher.ValidateEnvironment(
        "WATCHDOG_ALPHA=one`nINVALID NAME=value")
    AssertExecution(!invalidVariableName.Valid
        && invalidVariableName.ErrorCode == "InvalidName"
        && invalidVariableName.LineNumber == 2
        && invalidVariableName.VariableName == "INVALID NAME",
        "严格环境变量解析没有拒绝非法变量名")
    duplicateVariable := launcher.ValidateEnvironment(
        "Watchdog_Token=one`nWATCHDOG_TOKEN=two")
    AssertExecution(!duplicateVariable.Valid
        && duplicateVariable.ErrorCode == "DuplicateName"
        && duplicateVariable.LineNumber == 2
        && duplicateVariable.VariableName == "WATCHDOG_TOKEN",
        "严格环境变量解析没有拒绝大小写不同的重复变量名")
    systemRootState := launcher.CaptureEnvironment("SystemRoot")
    AssertExecution(systemRootState.Exists && systemRootState.Value != "",
        "启动器无法捕获现有环境变量")
    missingVariableState := launcher.CaptureEnvironment(
        "WATCHDOG_TEST_MISSING_" A_TickCount)
    AssertExecution(!missingVariableState.Exists,
        "启动器把不存在的环境变量误判为已有空值")
    expandedEnvironment := launcher.ExpandEnvironmentValue(
        "ROOT=%SystemRoot%;LITERAL=%WATCHDOG_VARIABLE_THAT_DOES_NOT_EXIST%")
    AssertExecution(InStr(expandedEnvironment, "ROOT=" A_WinDir)
        && InStr(expandedEnvironment,
            "%WATCHDOG_VARIABLE_THAT_DOES_NOT_EXIST%"),
        "环境变量值没有按 Windows 语义展开已有变量并保留未知引用")

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
    terminateError := ""
    AssertExecution(stopper.TerminateVerifiedProcess(currentPid,
        "WRONG-INSTANCE", &terminateError) == 0 && ProcessExist(currentPid),
        "原子强制终止没有拒绝创建身份不符的现存进程")
    AssertExecution(stopper.TerminateVerifiedProcess(currentPid, "",
        &terminateError) < 0 && ProcessExist(currentPid),
        "缺少创建身份时仍允许强制终止现存进程")
    missingIdentityStopper := RecordingTargetStopper((*) => "CURRENT")
    missingIdentityResult := missingIdentityStopper.Stop(currentPid, 0, 0,
        true)
    AssertExecution(!missingIdentityResult.Stopped
        && missingIdentityResult.Stage == TargetStopStage.Failed
        && missingIdentityStopper.WindowCloseRequests == 0,
        "缺少创建身份时停止器仍向现存进程发送了关闭请求")

    identityState := Map(currentPid, "CURRENT-INSTANCE")
    identityStopper := RecordingTargetStopper(
        ResolveExecutionIdentity.Bind(identityState))
    reusedResult := identityStopper.Stop(currentPid, 0, 0, true,
        "", "", "OLD-INSTANCE")
    AssertExecution(reusedResult.Stopped
        && reusedResult.Stage == TargetStopStage.AlreadyStopped
        && identityStopper.WindowCloseRequests == 0,
        "PID 已复用时停止器仍向无关的新进程发送了关闭请求")
    identityState[currentPid] := ""
    inaccessibleResult := identityStopper.Stop(currentPid, 0, 0, true,
        "", "", "CURRENT-INSTANCE")
    AssertExecution(!inaccessibleResult.Stopped
        && inaccessibleResult.Stage == TargetStopStage.Failed
        && identityStopper.WindowCloseRequests == 0,
        "创建身份不可核对时停止器仍继续执行破坏性操作")

    identityState[currentPid] := "CURRENT-INSTANCE"
    noWindowStopper := NoWindowTargetStopper(
        ResolveExecutionIdentity.Bind(identityState))
    noWindowResult := noWindowStopper.Stop(currentPid, 30, 0, false,
        "", "", "CURRENT-INSTANCE")
    AssertExecution(!noWindowResult.Stopped
        && noWindowResult.Stage == TargetStopStage.ForceSkipped
        && noWindowStopper.WaitCalls == 0,
        "无窗口目标仍无意义等待了完整 GUI 关闭超时")

}

try {
    RunExecutionTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.File " (" testError.Line "): " testError.Message
        "`n", "**")
    ExitApp(1)
}
