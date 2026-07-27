; 守护目标启动执行边界。
; 根据目标规格选择 EXE、脚本宿主或快捷方式调用，按需隔离环境变量并保证随后恢复；
; 管理员启动、工作目录和参数在这里统一落地，核心状态机不直接调用 Run。

class TargetLaunchInvocation {
    __New(command, workingDirectory := "", options := "", outputLogPath := "") {
        this.Command := command
        this.WorkingDirectory := workingDirectory
        this.Options := options
        this.OutputLogPath := outputLogPath
    }
}

class TargetLaunchResult {
    __New(pid, invocation) {
        this.PID := pid ? Integer(pid) : 0
        this.Invocation := invocation
    }
}

class TargetLauncher {
    BuildInvocation(spec, ahkPath := "", isCompiled := false,
        outputLogPath := "") {
        if !(spec is LaunchSpec)
            throw TypeError("启动器需要 LaunchSpec")
        if !spec.Available || spec.TargetPath == ""
            throw Error(spec.UnavailableReason != ""
                ? spec.UnavailableReason : "启动目标不可用")

        targetPath := spec.TargetPath
        arguments := spec.Arguments != ""
            ? " " spec.Arguments : ""
        runVerb := spec.RunAsAdmin ? "*RunAs " : ""
        options := ""
        command := ""

        switch spec.Kind {
            case TargetLaunchKind.Batch:
                if (outputLogPath == "")
                    throw ValueError("批处理启动需要输出日志路径")
                command := runVerb . 'cmd /d /c ""' . targetPath . '"'
                    . arguments . ' >> "' . outputLogPath . '" 2>&1"'
                options := "Hide"
            case TargetLaunchKind.AutoHotkey:
                if !isCompiled && ahkPath != "" && FileExist(ahkPath) {
                    command := runVerb . '"' . ahkPath . '" "'
                        . targetPath . '"' . arguments
                } else {
                    command := runVerb . '"' . targetPath . '"' . arguments
                }
            case TargetLaunchKind.PowerShell:
                command := runVerb
                    . 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "'
                    . targetPath . '"' . arguments
            case TargetLaunchKind.Direct:
                command := !InStr(targetPath, "\")
                    ? runVerb . targetPath . arguments
                    : runVerb . '"' . targetPath . '"' . arguments
            default:
                throw ValueError("不支持的启动规格类型", -1,
                    spec.Kind)
        }

        workingDirectory := this.ResolveWorkingDirectory(spec)
        return TargetLaunchInvocation(command, workingDirectory, options,
            outputLogPath)
    }

    Launch(spec, ahkPath := "", isCompiled := false,
        outputLogPath := "") {
        invocation := this.BuildInvocation(spec, ahkPath, isCompiled,
            outputLogPath)
        customEnvironment := this.ParseEnvironment(spec.Environment)
        newPID := 0
        if !customEnvironment.Count {
            Run(invocation.Command, invocation.WorkingDirectory,
                invocation.Options, &newPID)
            return TargetLaunchResult(newPID, invocation)
        }

        originalEnvironment := Map()
        originalEnvironment.CaseSense := "Off"
        previousCritical := A_IsCritical
        Critical("On")
        try {
            for variableName, variableValue in customEnvironment {
                originalEnvironment[variableName] :=
                    this.CaptureEnvironment(variableName)
                EnvSet(variableName, variableValue)
            }
            Run(invocation.Command, invocation.WorkingDirectory,
                invocation.Options, &newPID)
        } finally {
            try {
                for variableName, originalState in originalEnvironment {
                    try {
                        if originalState.Exists
                            EnvSet(variableName, originalState.Value)
                        else
                            DllCall("kernel32\SetEnvironmentVariableW",
                                "WStr", variableName, "Ptr", 0)
                    }
                }
            } finally {
                Critical(previousCritical ? previousCritical : "Off")
            }
        }
        return TargetLaunchResult(newPID, invocation)
    }

    CaptureEnvironment(variableName) {
        DllCall("kernel32\SetLastError", "UInt", 0)
        requiredLength := DllCall("kernel32\GetEnvironmentVariableW",
            "WStr", variableName, "Ptr", 0, "UInt", 0, "UInt")
        if !requiredLength {
            exists := DllCall("kernel32\GetLastError", "UInt") != 203
            return {Exists: exists, Value: ""}
        }
        valueBuffer := Buffer(requiredLength * 2, 0)
        copiedLength := DllCall("kernel32\GetEnvironmentVariableW",
            "WStr", variableName, "Ptr", valueBuffer,
            "UInt", requiredLength, "UInt")
        return {Exists: true, Value: copiedLength
            ? StrGet(valueBuffer, copiedLength, "UTF-16") : ""}
    }

    ResolveWorkingDirectory(spec) {
        if (spec.WorkingDirectory != ""
            && DirExist(spec.WorkingDirectory))
            return spec.WorkingDirectory
        SplitPath(spec.TargetPath, , &targetDirectory)
        return DirExist(targetDirectory) ? targetDirectory : ""
    }

    ParseEnvironment(environmentText) {
        return this.ParseEnvironmentConfiguration(environmentText, false)
            .Variables
    }

    ValidateEnvironment(environmentText) {
        return this.ParseEnvironmentConfiguration(environmentText, true)
    }

    ParseEnvironmentConfiguration(environmentText, rejectInvalid) {
        variables := Map()
        variables.CaseSense := "Off"
        normalizedLines := []
        result := {
            Valid: true,
            Variables: variables,
            Normalized: "",
            ErrorCode: "",
            LineNumber: 0,
            VariableName: ""
        }
        if (environmentText == "")
            return result
        lineNumber := 0
        Loop Parse, environmentText, "`n", "`r" {
            lineNumber++
            if (Trim(A_LoopField) == "")
                continue
            separator := InStr(A_LoopField, "=")
            if !separator {
                if rejectInvalid
                    return this.InvalidEnvironmentResult(result,
                        "MissingSeparator", lineNumber)
                continue
            }
            variableName := Trim(SubStr(A_LoopField, 1, separator - 1))
            variableValue := SubStr(A_LoopField, separator + 1)
            if !RegExMatch(variableName, "i)^[a-z_][a-z0-9_]*$") {
                if rejectInvalid
                    return this.InvalidEnvironmentResult(result,
                        "InvalidName", lineNumber, variableName)
                continue
            }
            if rejectInvalid && variables.Has(variableName)
                return this.InvalidEnvironmentResult(result,
                    "DuplicateName", lineNumber, variableName)
            variables[variableName] := variableValue
            normalizedLines.Push(variableName "=" variableValue)
        }
        for index, normalizedLine in normalizedLines
            result.Normalized .= (index > 1 ? "`n" : "") normalizedLine
        return result
    }

    InvalidEnvironmentResult(result, errorCode, lineNumber,
        variableName := "") {
        result.Valid := false
        result.ErrorCode := errorCode
        result.LineNumber := lineNumber
        result.VariableName := variableName
        return result
    }
}
