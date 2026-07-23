class TargetFileInspector {
    __New(callbacks) {
        this.Callbacks := callbacks
    }

    GetFingerprint(path) {
        if !this.Callbacks.IsSupportedTarget.Call(path)
            return "MISSING"
        path := this.Callbacks.GetSubjectPath.Call(path)
        if !FileExist(path) || DirExist(path)
            return "MISSING"
        try fileSize := FileGetSize(path)
        catch
            return "MISSING"
        try modifiedTime := FileGetTime(path, "M")
        catch
            return "MISSING"
        volumeSerial := 0
        fileIndexHigh := 0
        fileIndexLow := 0
        fileHandle := DllCall("kernel32\CreateFileW", "WStr", path,
            "UInt", 0, "UInt", Win32.FILE_SHARE_ALL, "Ptr", 0,
            "UInt", Win32.OPEN_EXISTING, "UInt", Win32.FILE_ATTRIBUTE_NORMAL,
            "Ptr", 0, "Ptr")
        if (fileHandle && fileHandle != -1) {
            try {
                fileInfo := Buffer(52, 0)
                if DllCall("kernel32\GetFileInformationByHandle", "Ptr",
                    fileHandle, "Ptr", fileInfo.Ptr, "Int") {
                    modifiedTime := Format("{:08X}{:08X}",
                        NumGet(fileInfo, 24, "UInt"),
                        NumGet(fileInfo, 20, "UInt"))
                    volumeSerial := NumGet(fileInfo, 28, "UInt")
                    fileIndexHigh := NumGet(fileInfo, 44, "UInt")
                    fileIndexLow := NumGet(fileInfo, 48, "UInt")
                }
            } finally {
                DllCall("kernel32\CloseHandle", "Ptr", fileHandle)
            }
        }
        return fileSize "|" modifiedTime "||"
            . Format("{:08X}{:08X}{:08X}", volumeSerial, fileIndexHigh,
                fileIndexLow)
    }

    IsReady(path) {
        if !this.Callbacks.IsSupportedTarget.Call(path)
            return true
        path := this.Callbacks.GetSubjectPath.Call(path)
        if !FileExist(path) || DirExist(path)
            return false
        SplitPath(path, , , &extension)
        extension := StrLower(extension)
        fileHandle := DllCall("kernel32\CreateFileW", "WStr", path,
            "UInt", 0x80000000, "UInt", 0x00000005, "Ptr", 0,
            "UInt", Win32.OPEN_EXISTING, "UInt", Win32.FILE_ATTRIBUTE_NORMAL,
            "Ptr", 0, "Ptr")
        if (!fileHandle || fileHandle == -1)
            return false
        try {
            header := Buffer(64, 0)
            bytesRead := 0
            if !DllCall("kernel32\ReadFile", "Ptr", fileHandle,
                "Ptr", header.Ptr, "UInt", header.Size, "UInt*", &bytesRead,
                "Ptr", 0, "Int")
                return false
            if (extension != "exe" && extension != "com")
                return bytesRead > 0
            if (bytesRead < 64 || NumGet(header, 0, "UShort") != 0x5A4D)
                return false
            peOffset := NumGet(header, 60, "UInt")
            if (peOffset < 64 || peOffset > 0x40000000)
                return false
            newPosition := 0
            if !DllCall("kernel32\SetFilePointerEx", "Ptr", fileHandle,
                "Int64", peOffset, "Int64*", &newPosition, "UInt", 0, "Int")
                return false
            signature := Buffer(4, 0)
            signatureBytes := 0
            if !DllCall("kernel32\ReadFile", "Ptr", fileHandle,
                "Ptr", signature.Ptr, "UInt", 4, "UInt*", &signatureBytes,
                "Ptr", 0, "Int")
                return false
            return signatureBytes == 4
                && NumGet(signature, 0, "UInt") == 0x00004550
        } finally {
            DllCall("kernel32\CloseHandle", "Ptr", fileHandle)
        }
    }

    IsWithinRoot(candidatePath, rootPath) {
        if (candidatePath == "" || rootPath == "")
            return false
        candidate := this.Callbacks.CanonicalPath.Call(candidatePath)
        root := RTrim(this.Callbacks.CanonicalPath.Call(rootPath), "\")
        if (candidate == "" || root == "")
            return false
        return candidate == root || InStr(candidate, root "\") == 1
    }
}
