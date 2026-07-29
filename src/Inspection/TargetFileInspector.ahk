; 目标文件与安装足迹检查器。
; 提供文件指纹、可启动性、稳定时间和目录归属判断，供升级保护确认文件替换完成；
; 读取失败以不确定结果返回，避免安装过程中的短暂缺失触发错误重新启动。

class TargetFileInspector {
    __New(callbacks) {
        this.Callbacks := callbacks
    }

    GetFingerprint(path) {
        identity := this.GetIdentity(path)
        return identity.Available ? identity.Fingerprint : "MISSING"
    }

    GetIdentity(path) {
        if !this.Callbacks.IsSupportedTarget.Call(path)
            return this.MissingIdentity()
        path := this.Callbacks.GetSubjectPath.Call(path)
        if !FileExist(path) || DirExist(path)
            return this.MissingIdentity()
        try fileSize := FileGetSize(path)
        catch
            return this.MissingIdentity()
        try modifiedTime := FileGetTime(path, "M")
        catch
            return this.MissingIdentity()
        volumeSerial := 0
        fileIndexHigh := 0
        fileIndexLow := 0
        nativeIdentityAvailable := false
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
                    nativeIdentityAvailable := volumeSerial
                        || fileIndexHigh || fileIndexLow
                }
            } finally {
                DllCall("kernel32\CloseHandle", "Ptr", fileHandle)
            }
        }
        fingerprint := fileSize "|" modifiedTime "||"
            . Format("{:08X}{:08X}{:08X}", volumeSerial, fileIndexHigh,
                fileIndexLow)
        return {
            Available: true,
            NativeIdentityAvailable: !!nativeIdentityAvailable,
            Path: path,
            FileSize: fileSize,
            ModifiedTime: modifiedTime,
            VolumeSerial: volumeSerial,
            FileIndexHigh: fileIndexHigh,
            FileIndexLow: fileIndexLow,
            Fingerprint: fingerprint
        }
    }

    ; 同一卷内的文件在改名或移动后仍保留文件 ID。OpenFileById 可以直接按
    ; 该身份重新打开文件并取得当前完整路径，不需要枚举目录或扫描整个磁盘。
    ResolveCurrentPath(originalPath, identity) {
        if !IsObject(identity) || !identity.HasOwnProp(
            "NativeIdentityAvailable") || !identity.NativeIdentityAvailable
            return ""
        originalPath := String(originalPath)
        if !RegExMatch(originalPath, "i)^([A-Z]:)\\", &volumeMatch)
            return ""
        volumePath := "\\.\" volumeMatch[1]
        volumeHandle := DllCall("kernel32\CreateFileW", "WStr", volumePath,
            "UInt", 0x80, "UInt", Win32.FILE_SHARE_ALL, "Ptr", 0,
            "UInt", Win32.OPEN_EXISTING,
            "UInt", Win32.FILE_FLAG_BACKUP_SEMANTICS, "Ptr", 0, "Ptr")
        if (!volumeHandle || volumeHandle == -1)
            return ""
        fileHandle := 0
        try {
            descriptor := Buffer(24, 0)
            NumPut("UInt", descriptor.Size, descriptor, 0)
            NumPut("Int", 0, descriptor, 4) ; FileIdType：使用 64 位文件编号。
            fileId := (identity.FileIndexHigh << 32)
                | identity.FileIndexLow
            NumPut("Int64", fileId, descriptor, 8)
            fileHandle := DllCall("kernel32\OpenFileById",
                "Ptr", volumeHandle, "Ptr", descriptor.Ptr,
                "UInt", 0x80, "UInt", Win32.FILE_SHARE_ALL,
                "Ptr", 0, "UInt", Win32.FILE_FLAG_BACKUP_SEMANTICS,
                "Ptr")
            if (!fileHandle || fileHandle == -1)
                return ""
            requiredLength := DllCall("kernel32\GetFinalPathNameByHandleW",
                "Ptr", fileHandle, "Ptr", 0, "UInt", 0,
                "UInt", 0, "UInt")
            if !requiredLength || requiredLength >= 32768
                return ""
            pathBuffer := Buffer((requiredLength + 1) * 2, 0)
            copiedLength := DllCall("kernel32\GetFinalPathNameByHandleW",
                "Ptr", fileHandle, "Ptr", pathBuffer.Ptr,
                "UInt", requiredLength + 1, "UInt", 0, "UInt")
            if !copiedLength || copiedLength > requiredLength
                return ""
            currentPath := StrGet(pathBuffer.Ptr, copiedLength, "UTF-16")
            if SubStr(currentPath, 1, 8) == "\\?\UNC\"
                currentPath := "\\" SubStr(currentPath, 9)
            else if SubStr(currentPath, 1, 4) == "\\?\"
                currentPath := SubStr(currentPath, 5)
            currentIdentity := this.GetIdentity(currentPath)
            if !currentIdentity.Available
                || !currentIdentity.NativeIdentityAvailable
                || currentIdentity.VolumeSerial != identity.VolumeSerial
                || currentIdentity.FileIndexHigh != identity.FileIndexHigh
                || currentIdentity.FileIndexLow != identity.FileIndexLow
                return ""
            return currentPath
        } catch {
            return ""
        } finally {
            if fileHandle && fileHandle != -1
                DllCall("kernel32\CloseHandle", "Ptr", fileHandle)
            DllCall("kernel32\CloseHandle", "Ptr", volumeHandle)
        }
    }

    MissingIdentity() {
        return {
            Available: false,
            NativeIdentityAvailable: false,
            Path: "",
            FileSize: 0,
            ModifiedTime: "",
            VolumeSerial: 0,
            FileIndexHigh: 0,
            FileIndexLow: 0,
            Fingerprint: "MISSING"
        }
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
