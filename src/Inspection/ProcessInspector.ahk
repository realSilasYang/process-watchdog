class ProcessInspector {
    __New(clock := "") {
        this.Clock := clock
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
        } finally {
            DllCall("kernel32\CloseHandle", "Ptr", processHandle)
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

    Now() {
        if IsObject(this.Clock) {
            try return Integer(this.Clock.Call())
        }
        return DllCall("kernel32\GetTickCount64", "UInt64")
    }
}
