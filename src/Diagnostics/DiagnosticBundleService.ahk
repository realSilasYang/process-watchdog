; 本地诊断包生成服务。
; 汇总版本、Windows、DPI、资源句柄、守护阶段和日志摘要，并在写入前对敏感配置做脱敏；
; 诊断包只生成到用户选择的位置，不负责上传或向外部服务发送数据。

class DiagnosticBundleService {
    __New(version, providers, supportFiles := "", archiveCallback := "",
        localize := "", diagnosticLocalize := "") {
        this.Version := version != "" ? String(version) : "unknown"
        this.Localize := IsObject(localize) ? localize : ""
        this.DiagnosticLocalize := IsObject(diagnosticLocalize)
            ? diagnosticLocalize : ""
        this.StateProvider := this.RequireCallback(providers, "State")
        this.LogProvider := this.RequireCallback(providers, "Logs")
        this.SupportFiles := supportFiles is Array ? supportFiles : []
        this.ArchiveCallback := IsObject(archiveCallback)
            ? archiveCallback : ""
    }

    RequireCallback(providers, name) {
        if !IsObject(providers) || !providers.HasOwnProp(name)
            || !IsObject(providers.%name%)
            throw TypeError(this.Text("缺少诊断信息提供器：{1}", name))
        return providers.%name%
    }

    Export(destinationDirectory) {
        destinationDirectory := Trim(String(destinationDirectory))
        if !DirExist(destinationDirectory)
            throw Error(this.Text("诊断包保存目录不存在"))

        stamp := FormatTime(, "yyyyMMdd-HHmmss")
        baseName := "process-watchdog-diagnostics-" stamp
        scratchDirectory := A_Temp "\" baseName "-" A_ScriptHwnd
            . "-" DllCall("kernel32\GetTickCount64", "UInt64")
        if DirExist(scratchDirectory)
            throw Error(this.Text("诊断临时目录已存在"))
        archivePath := this.FindAvailableArchive(destinationDirectory,
            baseName)

        DirCreate(scratchDirectory)
        try {
            this.WriteText(scratchDirectory "\environment.txt",
                this.BuildEnvironmentText())
            this.WriteText(scratchDirectory "\runtime-state.txt",
                this.GetProviderText(this.StateProvider))
            this.WriteText(scratchDirectory "\runtime-log.txt",
                this.GetProviderText(this.LogProvider))
            this.CopySupportFiles(scratchDirectory)
            if this.ArchiveCallback
                this.ArchiveCallback.Call(scratchDirectory, archivePath)
            else
                this.CreateArchive(scratchDirectory, archivePath)
            if !FileExist(archivePath)
                throw Error(this.Text("诊断压缩包未生成"))
            return archivePath
        } catch {
            try FileDelete(archivePath)
            throw
        } finally {
            this.RemoveScratchDirectory(scratchDirectory)
        }
    }

    GetProviderText(provider) {
        try return String(provider.Call())
        catch as providerError
            return this.Text("无法收集此部分诊断信息：{1}",
                this.DiagnosticText(providerError.Message)) "`r`n"
    }

    BuildEnvironmentText() {
        processHandle := DllCall("kernel32\GetCurrentProcess", "Ptr")
        gdiObjects := DllCall("user32\GetGuiResources", "Ptr", processHandle,
            "UInt", 0, "UInt")
        userObjects := DllCall("user32\GetGuiResources", "Ptr", processHandle,
            "UInt", 1, "UInt")
        dpi := 0
        try dpi := DllCall("user32\GetDpiForWindow", "Ptr", A_ScriptHwnd,
            "UInt")
        return "Application=" this.Text("进程守护小助手") "`r`n"
            . "Version=" this.Version "`r`n"
            . "CollectedAt=" FormatTime(, "yyyy-MM-dd HH:mm:ss") "`r`n"
            . "Windows=" A_OSVersion "`r`n"
            . "AutoHotkey=" A_AhkVersion "`r`n"
            . "Compiled=" (A_IsCompiled ? 1 : 0) "`r`n"
            . "PointerBits=" (A_PtrSize * 8) "`r`n"
            . "ProcessId=" DllCall("kernel32\GetCurrentProcessId", "UInt") "`r`n"
            . "Dpi=" dpi "`r`n"
            . "GdiObjects=" gdiObjects "`r`n"
            . "UserObjects=" userObjects "`r`n"
    }

    CopySupportFiles(scratchDirectory) {
        for sourcePath in this.SupportFiles {
            try sourcePath := String(sourcePath)
            catch
                continue
            if !FileExist(sourcePath)
                continue
            SplitPath(sourcePath, &fileName)
            if fileName == ""
                continue
            try FileCopy(sourcePath, scratchDirectory "\" fileName, 1)
        }
    }

    WriteText(path, text) {
        outputFile := FileOpen(path, "w", "UTF-8")
        if !outputFile
            throw Error(this.Text("无法写入诊断文件：{1}", path))
        try outputFile.Write(text)
        finally outputFile.Close()
    }

    FindAvailableArchive(destinationDirectory, baseName) {
        Loop 100 {
            suffix := A_Index == 1 ? "" : "-" A_Index
            candidate := destinationDirectory "\" baseName suffix ".zip"
            if !FileExist(candidate)
                return candidate
        }
        throw Error(this.Text("诊断包目标文件名已被占用"))
    }

    CreateArchive(sourceDirectory, archivePath) {
        tarPath := A_WinDir "\System32\tar.exe"
        if FileExist(tarPath) {
            command := this.QuoteArgument(tarPath)
                . " -a -c -f " this.QuoteArgument(archivePath)
                . " -C " this.QuoteArgument(sourceDirectory) " ."
            if RunWait(command, , "Hide") == 0 && FileExist(archivePath)
                return true
            try FileDelete(archivePath)
        }

        powerShellCommand := "$ErrorActionPreference='Stop';"
            . "Compress-Archive -Path "
            . this.QuotePowerShell(sourceDirectory "\*")
            . " -DestinationPath " this.QuotePowerShell(archivePath)
            . " -CompressionLevel Optimal -Force"
        command := "powershell.exe -NoProfile -NonInteractive "
            . "-ExecutionPolicy Bypass -Command "
            . this.QuoteArgument(powerShellCommand)
        if RunWait(command, , "Hide") != 0 || !FileExist(archivePath)
            throw Error(this.Text("系统压缩工具未能创建诊断包"))
        return true
    }

    QuoteArgument(value) {
        value := String(value)
        return '"' StrReplace(value, '"', '\"') '"'
    }

    QuotePowerShell(value) {
        return "'" StrReplace(String(value), "'", "''") "'"
    }

    RemoveScratchDirectory(path) {
        normalizedTemp := StrLower(RTrim(A_Temp, "\") "\")
        normalizedPath := StrLower(path)
        if InStr(normalizedPath, normalizedTemp) != 1
            return false
        try DirDelete(path, true)
        return !DirExist(path)
    }

    Text(template, values*) {
        if IsObject(this.Localize)
            return this.Localize.Call(template, values*)
        return values.Length ? Format(template, values*) : template
    }

    DiagnosticText(value) {
        ; 诊断包服务自身可以独立测试；生产环境传入的本地化回调负责
        ; 把下游异常转换为当前界面语言，未注入时保留原始详情。
        if IsObject(this.DiagnosticLocalize)
            return this.DiagnosticLocalize.Call(value)
        return String(value)
    }
}
