#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证 Everything 本机候选选择、缓存失效和后台启动参数。
; 测试通过依赖注入隔离真实注册表与进程，不会启动或修改用户安装的 Everything。

#Include ..\..\src\Inspection\ShortcutResolver.ahk
#Include ..\..\src\Execution\EverythingRuntimeService.ahk

class FakeEverythingRuntimeHost {
    __New() {
        this.Candidates := []
        this.ExistingFiles := Map()
        this.ExistingFiles.CaseSense := "Off"
        this.Launches := []
        this.NextPID := 4321
        this.ThrowLaunch := false
    }

    CollectCandidates() {
        return this.Candidates.Clone()
    }

    FileExists(path) {
        return this.ExistingFiles.Get(path, false)
    }

    Launch(path, arguments, options) {
        this.Launches.Push({Path: path, Arguments: arguments,
            Options: options})
        if this.ThrowLaunch
            throw Error("startup denied")
        return this.NextPID
    }
}

AssertEverythingRuntime(value, message) {
    if !value
        throw Error(message)
}

RunEverythingRuntimeServiceTests() {
    host := FakeEverythingRuntimeHost()
    expectedPath := "D:\Tools\Everything\Everything.exe"
    host.Candidates := [
        "C:\Missing\Everything.exe",
        '"' expectedPath '",0',
        expectedPath
    ]
    host.ExistingFiles[expectedPath] := true
    service := EverythingRuntimeService({
        CollectCandidates: ObjBindMethod(host, "CollectCandidates"),
        FileExists: ObjBindMethod(host, "FileExists"),
        Launch: ObjBindMethod(host, "Launch")
    })

    AssertEverythingRuntime(service.FindExecutable() == expectedPath,
        "没有跳过无效候选或解析注册表 DisplayIcon 路径")
    host.Candidates := []
    AssertEverythingRuntime(service.FindExecutable() == expectedPath,
        "有效 Everything 路径没有复用缓存")

    startResult := service.StartSilently()
    AssertEverythingRuntime(startResult.Found && startResult.Started
        && startResult.Path == expectedPath && startResult.PID == 4321
        && InStr(startResult.DiscoverySummary, "采用：")
        && host.Launches.Length == 1
        && host.Launches[1].Arguments == "-startup"
        && host.Launches[1].Options == "Hide",
        "Everything 没有使用官方后台启动参数或隐藏启动选项")

    host.ExistingFiles.Delete(expectedPath)
    AssertEverythingRuntime(service.FindExecutable() == "",
        "已失效的 Everything 缓存路径没有重新验证")
    missingResult := service.StartSilently()
    AssertEverythingRuntime(!missingResult.Found && !missingResult.Started
        && InStr(missingResult.Failure, "未在注册表")
        && InStr(missingResult.DiscoverySummary, "已检查")
        && host.Launches.Length == 1,
        "未找到 Everything 时仍尝试启动进程或没有返回可读发现摘要")

    launchFailureHost := FakeEverythingRuntimeHost()
    launchFailureHost.Candidates := [expectedPath]
    launchFailureHost.ExistingFiles[expectedPath] := true
    launchFailureHost.ThrowLaunch := true
    launchFailureService := EverythingRuntimeService({
        CollectCandidates: ObjBindMethod(launchFailureHost,
            "CollectCandidates"),
        FileExists: ObjBindMethod(launchFailureHost, "FileExists"),
        Launch: ObjBindMethod(launchFailureHost, "Launch")
    })
    launchFailureResult := launchFailureService.StartSilently()
    AssertEverythingRuntime(launchFailureResult.Found
        && !launchFailureResult.Started
        && launchFailureResult.Path == expectedPath
        && launchFailureResult.Failure == "startup denied"
        && InStr(launchFailureResult.DiscoverySummary, expectedPath),
        "Everything 启动失败时没有保留路径、失败原因和发现摘要")

    AssertEverythingRuntime(
        service.NormalizeExecutableCandidate(
            "%SystemRoot%/System32/Everything.exe")
            == A_WinDir "\System32\Everything.exe",
        "候选路径没有展开环境变量或统一目录分隔符")
}

try {
    RunEverythingRuntimeServiceTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.File "（" testError.Line "）："
        testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
