; Windows 原生进程信息检查器。
; 统一读取创建时间、完整路径、父进程和令牌提升状态，并以“进程号＋创建身份”
; 区分 PID 复用；访问被拒绝属于未知证据，不自动解释为目标已经停止。

class ProcessInspector {
    __New(clock := "") {
        this.Clock := clock
        this.AutoHotkeyScriptSnapshot := ""
        this.AutoHotkeyScriptSnapshotReuseMs := 1000
    }

    CaptureNativeSnapshot() {
        capturedAtTicks := this.Now()
        processes := []
        snapshotHandle := DllCall("kernel32\CreateToolhelp32Snapshot",
            "UInt", 0x00000002, "UInt", 0, "Ptr")
        if (snapshotHandle == -1 || !snapshotHandle) {
            return {Ready: false, Processes: processes,
                CapturedAtTicks: capturedAtTicks,
                Reason: "无法创建原生进程快照"}
        }
        try {
            entrySize := A_PtrSize == 8 ? 568 : 556
            parentOffset := A_PtrSize == 8 ? 32 : 24
            nameOffset := A_PtrSize == 8 ? 44 : 36
            entry := Buffer(entrySize, 0)
            NumPut("UInt", entrySize, entry, 0)
            hasEntry := DllCall("kernel32\Process32FirstW", "Ptr",
                snapshotHandle, "Ptr", entry, "Int")
            while hasEntry {
                pid := NumGet(entry, 8, "UInt")
                parentPid := NumGet(entry, parentOffset, "UInt")
                processName := StrGet(entry.Ptr + nameOffset, 260, "UTF-16")
                if (pid && processName != "") {
                    processes.Push({pid: pid, parent: parentPid,
                        name: processName, cmd: "", exe: "", creation: "",
                        observedTicks: capturedAtTicks})
                }
                NumPut("UInt", entrySize, entry, 0)
                hasEntry := DllCall("kernel32\Process32NextW", "Ptr",
                    snapshotHandle, "Ptr", entry, "Int")
            }
            return {Ready: true, Processes: processes,
                CapturedAtTicks: capturedAtTicks, Reason: ""}
        } catch as snapshotError {
            return {Ready: false, Processes: [],
                CapturedAtTicks: capturedAtTicks,
                Reason: snapshotError.Message}
        } finally {
            DllCall("kernel32\CloseHandle", "Ptr", snapshotHandle)
        }
    }

    GetImagePath(pid) {
        if !pid
            return ""
        processHandle := DllCall("kernel32\OpenProcess", "UInt",
            Win32.PROCESS_QUERY_LIMITED_INFORMATION, "Int", false,
            "UInt", pid, "Ptr")
        if !processHandle
            return ""
        try {
            pathBuffer := Buffer(32768 * 2, 0)
            characterCount := 32767
            if DllCall("kernel32\QueryFullProcessImageNameW", "Ptr",
                processHandle, "UInt", 0, "Ptr", pathBuffer,
                "UInt*", &characterCount, "Int") {
                return StrGet(pathBuffer, characterCount, "UTF-16")
            }
            ; 某些升级器或 Qt 程序的进程句柄可以查询，但
            ; QueryFullProcessImageNameW 偶发返回失败。PSAPI 使用同一
            ; 查询权限提供设备路径回退，避免把可确认的目标降级为 Unknown。
            deviceBuffer := Buffer(32768 * 2, 0)
            deviceLength := DllCall("psapi\GetProcessImageFileNameW", "Ptr",
                processHandle, "Ptr", deviceBuffer, "UInt", 32767, "UInt")
            if deviceLength {
                devicePath := StrGet(deviceBuffer, deviceLength, "UTF-16")
                resolvedPath := this.ResolveDevicePath(devicePath)
                if resolvedPath != ""
                    return resolvedPath
            }
        } finally {
            DllCall("kernel32\CloseHandle", "Ptr", processHandle)
        }
        return ""
    }

    ResolveDevicePath(devicePath) {
        devicePath := Trim(String(devicePath))
        if (devicePath == "" || SubStr(devicePath, 1, 8) != "\Device\")
            return devicePath
        Loop 26 {
            drive := Chr(64 + A_Index) ":"
            targetBuffer := Buffer(1024 * 2, 0)
            targetLength := DllCall("kernel32\QueryDosDeviceW", "Str", drive,
                "Ptr", targetBuffer, "UInt", 1024, "UInt")
            if !targetLength
                continue
            deviceName := StrGet(targetBuffer, targetLength, "UTF-16")
            if (devicePath == deviceName)
                return drive
            if (SubStr(devicePath, 1, StrLen(deviceName) + 1)
                == deviceName "\")
                return drive SubStr(devicePath, StrLen(deviceName) + 1)
        }
        return ""
    }

    GetCreationIdentity(pid) {
        if !pid
            return ""
        processHandle := DllCall("kernel32\OpenProcess", "UInt",
            Win32.PROCESS_QUERY_LIMITED_INFORMATION, "Int", false,
            "UInt", pid, "Ptr")
        if !processHandle
            return ""
        try {
            creationTime := Buffer(8, 0)
            exitTime := Buffer(8, 0)
            kernelTime := Buffer(8, 0)
            userTime := Buffer(8, 0)
            if DllCall("kernel32\GetProcessTimes", "Ptr", processHandle,
                "Ptr", creationTime, "Ptr", exitTime, "Ptr", kernelTime,
                "Ptr", userTime, "Int") {
                return Format("{:016X}", NumGet(creationTime, 0, "UInt64"))
            }
        } finally {
            DllCall("kernel32\CloseHandle", "Ptr", processHandle)
        }
        return ""
    }

    GetElevationState(pid) {
        if !pid || !ProcessExist(pid)
            return -1
        processHandle := DllCall("kernel32\OpenProcess", "UInt",
            Win32.PROCESS_QUERY_LIMITED_INFORMATION, "Int", false,
            "UInt", pid, "Ptr")
        if !processHandle
            return -1
        tokenHandle := 0
        try {
            if !DllCall("advapi32\OpenProcessToken", "Ptr", processHandle,
                "UInt", Win32.TOKEN_QUERY, "Ptr*", &tokenHandle, "Int") {
                return -1
            }
            elevation := Buffer(4, 0)
            returnLength := 0
            if !DllCall("advapi32\GetTokenInformation", "Ptr", tokenHandle,
                "Int", Win32.TOKEN_ELEVATION, "Ptr", elevation,
                "UInt", elevation.Size, "UInt*", &returnLength, "Int") {
                return -1
            }
            return NumGet(elevation, 0, "UInt") ? 1 : 0
        } finally {
            if tokenHandle
                DllCall("kernel32\CloseHandle", "Ptr", tokenHandle)
            DllCall("kernel32\CloseHandle", "Ptr", processHandle)
        }
    }

    CaptureAutoHotkeyScriptSnapshot(maximumAgeMs := 0) {
        ; 提权脚本的命令行可能完全不可读，但 AHK 隐藏主窗口仍公开完整脚本路径。
        ; 只有每个解释器进程都能对应到标准主窗口时，快照才足以证明某脚本未运行。
        nowTicks := this.Now()
        maximumAgeMs := maximumAgeMs > 0 ? maximumAgeMs
            : this.AutoHotkeyScriptSnapshotReuseMs
        if IsObject(this.AutoHotkeyScriptSnapshot)
            && nowTicks >= this.AutoHotkeyScriptSnapshot.CapturedAtTicks
            && nowTicks - this.AutoHotkeyScriptSnapshot.CapturedAtTicks
                <= maximumAgeMs {
            return this.AutoHotkeyScriptSnapshot
        }

        nativeSnapshot := this.CaptureNativeSnapshot()
        result := {
            Ready: nativeSnapshot.Ready,
            Complete: false,
            Scripts: [],
            CapturedAtTicks: nativeSnapshot.CapturedAtTicks,
            Reason: nativeSnapshot.Reason
        }
        if !nativeSnapshot.Ready {
            this.AutoHotkeyScriptSnapshot := result
            return result
        }

        candidatePids := Map()
        for processInfo in nativeSnapshot.Processes {
            if processInfo.pid
                && ProcessInspector.IsAutoHotkeyInterpreterName(
                    processInfo.name) {
                candidatePids[processInfo.pid] := true
            }
        }
        identifiedPids := Map()
        hiddenWindowsBefore := A_DetectHiddenWindows
        try {
            DetectHiddenWindows(true)
            for windowHandle in WinGetList("ahk_class AutoHotkey") {
                pid := 0
                title := ""
                try pid := WinGetPID("ahk_id " windowHandle)
                if !pid || !candidatePids.Has(pid) || !ProcessExist(pid)
                    continue
                try title := WinGetTitle("ahk_id " windowHandle)
                scriptPath := ProcessInspector.ExtractAutoHotkeyScriptPath(
                    title)
                if scriptPath == ""
                    continue
                identifiedPids[pid] := true
                result.Scripts.Push({PID: pid, Path: scriptPath})
            }
        } catch as windowError {
            result.Reason := windowError.Message
        } finally DetectHiddenWindows(hiddenWindowsBefore)

        result.Complete := true
        for pid in candidatePids {
            if !identifiedPids.Has(pid) {
                result.Complete := false
                if result.Reason == ""
                    result.Reason := "存在无法识别主窗口的 AutoHotkey 进程"
                break
            }
        }
        this.AutoHotkeyScriptSnapshot := result
        return result
    }

    static IsAutoHotkeyInterpreterName(processName) {
        SplitPath(processName, &fileName)
        return RegExMatch(fileName, "i)^AutoHotkey.*\.exe$") != 0
    }

    static ExtractAutoHotkeyScriptPath(windowTitle) {
        if RegExMatch(windowTitle,
            "i)^(.*\.ahk) - AutoHotkey v[0-9]+(?:\.[0-9]+)*.*$", &match) {
            return match[1]
        }
        return ""
    }

    Now() {
        if IsObject(this.Clock) {
            try return Integer(this.Clock.Call())
        }
        return DllCall("kernel32\GetTickCount64", "UInt64")
    }
}
