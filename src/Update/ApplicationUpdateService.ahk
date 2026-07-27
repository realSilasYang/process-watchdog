; 小助手自身更新的异步协调服务。
; 网络请求、JSON 解析、压缩包校验与文件替换全部交给独立 PowerShell 进程；主 GUI
; 只低频查看结果文件，因此断网、GitHub 延迟或大文件下载不会阻塞悬浮和滚动交互。

class ApplicationUpdateService {
    static ResultPublicationGraceMs := 1500

    __New(options) {
        if !IsObject(options)
            throw TypeError("应用更新参数无效")
        this.Repository := options.Repository
        this.CurrentVersion := options.CurrentVersion
        this.HelperPath := options.HelperPath
        if options.HasOwnProp("HelperLocalizationPath")
            this.HelperLocalizationPath := options.HelperLocalizationPath
        else {
            helperDirectory := ""
            SplitPath(this.HelperPath, , &helperDirectory)
            this.HelperLocalizationPath := helperDirectory
                . "\application-update.strings.json"
        }
        this.InstallRoot := options.InstallRoot
        this.EntryPath := options.EntryPath
        this.InterpreterPath := options.InterpreterPath
        this.Compiled := !!options.Compiled
        this.UiLanguage := options.UiLanguage
        this.Log := options.Log
        this.Localize := options.Localize
        this.OnResult := options.OnResult
        this.Now := options.Now
        this.Quote := options.Quote
        this.PowerShellPath := A_WinDir
            . "\System32\WindowsPowerShell\v1.0\powershell.exe"
        this.WorkerPid := 0
        this.WorkerHandle := 0
        this.WorkDirectory := ""
        this.ResultPath := ""
        this.StartedTicks := 0
        this.WorkerExitObserved := false
        this.WorkerExitObservedTicks := 0
        this.Interactive := false
        this.OwnerGui := ""
        this.PollTimer := ObjBindMethod(this, "Poll")
        this.LastResult := ""
        this.ShuttingDown := false
    }

    IsChecking() {
        return this.WorkerPid != 0
    }

    BeginCheck(interactive := false, ownerGui := "") {
        if this.ShuttingDown || this.IsChecking()
            return false
        if !FileExist(this.HelperPath)
            throw Error("应用更新助手不存在")
        if !FileExist(this.HelperLocalizationPath)
            throw Error("应用更新本地化资源不存在")
        if !FileExist(this.PowerShellPath)
            throw Error("系统 PowerShell 不可用")
        if !ApplicationUpdateService.IsCanonicalVersion(this.CurrentVersion)
            throw Error("当前应用版本无效")

        processId := DllCall("kernel32\GetCurrentProcessId", "UInt")
        this.WorkDirectory := A_Temp "\ProcessWatchdogUpdateCheck-"
            . processId "-" this.Now.Call()
        DirCreate(this.WorkDirectory)
        this.ResultPath := this.WorkDirectory "\result.ini"
        command := this.BuildPowerShellCommand(this.HelperPath, [
            "-Mode", "Check",
            "-Repository", this.Repository,
            "-CurrentVersion", this.CurrentVersion,
            "-PackageKind", this.GetPackageKind(),
            "-UiLanguage", this.UiLanguage,
            "-ResultPath", this.ResultPath
        ])
        try Run(command, this.InstallRoot, "Hide", &workerPid)
        catch as runError {
            this.CleanupCheck()
            throw runError
        }
        if !workerPid {
            this.CleanupCheck()
            throw Error("应用更新检查进程未返回 PID")
        }
        this.WorkerPid := workerPid
        ; 进程句柄绑定到本次启动的具体进程对象；单看 PID 会在极端情况下把系统
        ; 随后复用的同号进程误认为仍在运行，甚至在超时清理时误结束它。
        this.WorkerHandle := DllCall("kernel32\OpenProcess", "UInt",
            0x00100001, "Int", false, "UInt", workerPid, "Ptr")
        if !this.WorkerHandle {
            ; 没有句柄就无法区分原进程与稍后复用同一 PID 的无关进程。本次检查
            ; 宁可明确失败，也不退回仅凭 PID 轮询或结束其它进程。
            this.CleanupCheck()
            throw Error(this.Text("更新检查未返回结果"))
        }
        this.StartedTicks := this.Now.Call()
        this.WorkerExitObserved := false
        this.WorkerExitObservedTicks := 0
        this.Interactive := !!interactive
        this.OwnerGui := ownerGui
        SetTimer(this.PollTimer, 250)
        return true
    }

    Poll(*) {
        if !this.WorkerPid
            return
        elapsed := this.Now.Call() - this.StartedTicks
        ; 助手使用临时文件加原子改名发布结果。结果一旦出现便可读取，不必再等待
        ; PowerShell 完成最后几条退出指令。
        if FileExist(this.ResultPath) {
            try result := this.ValidateCheckResult(this.ReadResult(
                this.ResultPath))
            catch as resultError {
                result := this.ErrorResult(resultError.Message)
            }
            this.FinishCheck(result)
            return
        }
        workerAlive := this.IsWorkerAlive()
        if workerAlive {
            this.ShouldWaitForResultPublication(true, this.Now.Call())
            if elapsed < 60000
                return
        }
        if workerAlive {
            if this.WorkerHandle
                try DllCall("kernel32\TerminateProcess", "Ptr",
                    this.WorkerHandle, "UInt", 1)
            result := this.ErrorResult(this.Text("检查更新超时"))
        } else {
            ; PowerShell 可能已经退出，而杀毒软件或文件系统仍在完成结果文件的
            ; 原子改名。保留短暂宽限期，避免把正常完成误报成“未返回结果”。
            nowTicks := this.Now.Call()
            if this.ShouldWaitForResultPublication(false, nowTicks)
                return
            if FileExist(this.ResultPath)
                return this.Poll()
            result := this.ErrorResult(this.Text("更新检查未返回结果"))
        }
        this.FinishCheck(result)
    }

    ShouldWaitForResultPublication(workerAlive, nowTicks) {
        if workerAlive {
            this.WorkerExitObserved := false
            this.WorkerExitObservedTicks := 0
            return false
        }
        if !this.WorkerExitObserved {
            this.WorkerExitObserved := true
            this.WorkerExitObservedTicks := nowTicks
            return true
        }
        return nowTicks - this.WorkerExitObservedTicks
            < ApplicationUpdateService.ResultPublicationGraceMs
    }

    FinishCheck(result) {
        interactive := this.Interactive
        ownerGui := this.OwnerGui
        this.LastResult := result
        this.CleanupCheck()
        try this.OnResult.Call(result, interactive, ownerGui)
        catch as callbackError
            this.Log.Call(this.Text("处理应用更新结果失败：{1}",
                callbackError.Message))
    }

    IsWorkerAlive() {
        return this.WorkerHandle && DllCall("kernel32\WaitForSingleObject",
            "Ptr", this.WorkerHandle, "UInt", 0, "UInt") == 0x00000102
    }

    ErrorResult(message) {
        return {Status: "error", CurrentVersion: this.CurrentVersion,
            Version: "", Tag: "", ReleaseUrl: "", BinaryUrl: "",
            SourceUrl: "", BinarySha256: "", SourceSha256: "",
            ChecksumsUrl: "", Error: message}
    }

    CurrentResult() {
        return {Status: "current", CurrentVersion: this.CurrentVersion,
            Version: this.CurrentVersion, Tag: "v" this.CurrentVersion,
            ReleaseUrl: "", BinaryUrl: "", SourceUrl: "",
            BinarySha256: "", SourceSha256: "", ChecksumsUrl: "", Error: ""}
    }

    ReadResult(resultPath) {
        readValue := (key) => IniRead(resultPath, "Update", key, "")
        return {
            Status: readValue("Status"),
            CurrentVersion: readValue("CurrentVersion"),
            Version: readValue("Version"),
            Tag: readValue("Tag"),
            ReleaseUrl: readValue("ReleaseUrl"),
            BinaryUrl: readValue("BinaryUrl"),
            SourceUrl: readValue("SourceUrl"),
            BinarySha256: readValue("BinarySha256"),
            SourceSha256: readValue("SourceSha256"),
            ChecksumsUrl: readValue("ChecksumsUrl"),
            Error: readValue("Error")
        }
    }

    BeginInstall(result) {
        result := this.ValidateCheckResult(result, true)
        if !FileExist(this.HelperPath)
            throw Error("应用更新助手不存在")
        if !FileExist(this.HelperLocalizationPath)
            throw Error("应用更新本地化资源不存在")
        processId := DllCall("kernel32\GetCurrentProcessId", "UInt")
        helperDirectory := A_Temp "\ProcessWatchdogUpdateApply-"
            . processId "-" this.Now.Call()
        DirCreate(helperDirectory)
        temporaryHelper := helperDirectory "\application-update.ps1"
        FileCopy(this.HelperPath, temporaryHelper, true)
        FileCopy(this.HelperLocalizationPath,
            helperDirectory "\application-update.strings.json", true)
        packageKind := this.GetPackageKind()
        command := this.BuildPowerShellCommand(temporaryHelper, [
            "-Mode", "Apply",
            "-Repository", this.Repository,
            "-PackageKind", packageKind,
            "-ParentPid", processId,
            "-InstallRoot", this.InstallRoot,
            "-EntryPath", this.EntryPath,
            "-InterpreterPath", this.InterpreterPath,
            "-CurrentVersion", this.CurrentVersion,
            "-Version", result.Version,
            "-Tag", result.Tag,
            "-BinaryUrl", result.BinaryUrl,
            "-SourceUrl", result.SourceUrl,
            "-BinarySha256", result.BinarySha256,
            "-SourceSha256", result.SourceSha256,
            "-ChecksumsUrl", result.ChecksumsUrl,
            "-UiLanguage", this.UiLanguage
        ])
        try Run(command, this.InstallRoot, "Hide", &workerPid)
        catch as runError {
            try DirDelete(helperDirectory, true)
            throw runError
        }
        if !workerPid {
            try DirDelete(helperDirectory, true)
            throw Error("应用更新安装进程未返回 PID")
        }
        return workerPid
    }

    GetPackageKind() {
        return ApplicationUpdateService.DeterminePackageKind(this.Compiled,
            this.InstallRoot)
    }

    ValidateCheckResult(result, requireAvailable := false) {
        if !IsObject(result) || !result.HasOwnProp("Status")
            throw ValueError("更新检查未返回结果")
        status := result.Status
        if status == "error" {
            errorText := result.HasOwnProp("Error") ? result.Error : ""
            if !requireAvailable
                && (errorText == "没有可安装的应用更新"
                    || errorText == this.Text("没有可安装的应用更新"))
                return this.CurrentResult()
            if requireAvailable
                throw ValueError("没有可安装的应用更新")
            return result
        }
        if status != "current" && status != "available"
            throw ValueError(this.Text("更新检查返回了无法识别的状态：{1}",
                status))
        requiredFields := ["CurrentVersion", "Version", "Tag", "ReleaseUrl",
            "BinaryUrl", "SourceUrl", "BinarySha256", "SourceSha256",
            "ChecksumsUrl", "Error"]
        for fieldName in requiredFields {
            if !result.HasOwnProp(fieldName)
                throw ValueError("更新检查未返回结果")
        }
        if result.CurrentVersion != this.CurrentVersion
            || !ApplicationUpdateService.IsCanonicalVersion(result.Version)
            || result.Tag != "v" result.Version {
            throw ValueError("更新检查未返回结果")
        }
        comparison := ApplicationUpdateService.CompareVersions(result.Version,
            this.CurrentVersion)
        if (status == "available") != (comparison > 0)
            throw ValueError("更新检查未返回结果")
        if requireAvailable && status != "available"
            throw ValueError("没有可安装的应用更新")
        if status == "available" {
            for digest in [result.BinarySha256, result.SourceSha256] {
                if digest != "" && !RegExMatch(digest, "^[0-9A-F]{64}$")
                    throw ValueError("更新检查未返回结果")
            }
            packageKind := this.GetPackageKind()
            if packageKind == "compiled" && (result.BinaryUrl == ""
                || (result.BinarySha256 == "" && result.ChecksumsUrl == ""))
                throw ValueError("最新版本缺少一个或多个自动更新附件。")
            if packageKind == "source" && (result.SourceUrl == ""
                || (result.SourceSha256 == "" && result.ChecksumsUrl == ""))
                throw ValueError("最新版本缺少一个或多个自动更新附件。")
        }
        return result
    }

    BuildPowerShellCommand(helperPath, arguments) {
        command := this.Quote.Call(this.PowerShellPath)
            . " -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "
            . this.Quote.Call(helperPath)
        for argument in arguments
            command .= " " this.Quote.Call(argument)
        return command
    }

    CleanupCheck() {
        try SetTimer(this.PollTimer, 0)
        if this.WorkerHandle
            try DllCall("kernel32\CloseHandle", "Ptr", this.WorkerHandle)
        this.WorkerHandle := 0
        this.WorkerPid := 0
        this.StartedTicks := 0
        this.WorkerExitObserved := false
        this.WorkerExitObservedTicks := 0
        this.Interactive := false
        this.OwnerGui := ""
        workDirectory := this.WorkDirectory
        this.WorkDirectory := ""
        this.ResultPath := ""
        if workDirectory && DirExist(workDirectory)
            try DirDelete(workDirectory, true)
    }

    Shutdown(*) {
        this.ShuttingDown := true
        try SetTimer(this.PollTimer, 0)
        if this.WorkerHandle && this.IsWorkerAlive()
            try DllCall("kernel32\TerminateProcess", "Ptr",
                this.WorkerHandle, "UInt", 1)
        this.CleanupCheck()
    }

    Text(template, values*) {
        return this.Localize.Call(template, values*)
    }

    static CompareVersions(left, right) {
        if !this.IsCanonicalVersion(left) || !this.IsCanonicalVersion(right)
            throw ValueError("语义版本无效")
        leftParts := StrSplit(left, ".")
        rightParts := StrSplit(right, ".")
        Loop 3 {
            leftValue := Integer(leftParts[A_Index])
            rightValue := Integer(rightParts[A_Index])
            if leftValue != rightValue
                return leftValue > rightValue ? 1 : -1
        }
        return 0
    }

    static IsCanonicalVersion(version) {
        return RegExMatch(version,
            "^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$") != 0
    }

    static DeterminePackageKind(compiled, installRoot) {
        if compiled
            return "compiled"
        ; 普通克隆的 .git 是目录，git worktree 的 .git 是文本文件；二者都属于
        ; 可安全快速前进的 Git 源码形态。
        return FileExist(installRoot "\.git") ? "source-git" : "source"
    }
}
