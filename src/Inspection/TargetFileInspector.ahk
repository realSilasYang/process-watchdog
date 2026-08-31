; 目标文件内容与可启动性检查器。

class TargetFileInspector {
    static ContentHashAlgorithm := "SHA256"
    static ContentHashLength := 32
    static ContentReadBufferSize := 1024 * 1024

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
        modifiedTime := ""
        fileHandle := DllCall("kernel32\CreateFileW", "WStr", path,
            "UInt", 0, "UInt", Win32.FILE_SHARE_ALL, "Ptr", 0,
            "UInt", Win32.OPEN_EXISTING, "UInt", Win32.FILE_ATTRIBUTE_NORMAL,
            "Ptr", 0, "Ptr")
        if fileHandle && fileHandle != -1 {
            try {
                fileInfo := Buffer(52, 0)
                if DllCall("kernel32\GetFileInformationByHandle", "Ptr",
                    fileHandle, "Ptr", fileInfo.Ptr, "Int") {
                    modifiedTime := Format("{:08X}{:08X}",
                        NumGet(fileInfo, 24, "UInt"),
                        NumGet(fileInfo, 20, "UInt"))
                }
            } finally DllCall("kernel32\CloseHandle", "Ptr", fileHandle)
        }
        if modifiedTime == "" {
            try modifiedTime := FileGetTime(path, "M")
            catch
                return "MISSING"
        }
        return fileSize "|" modifiedTime
    }

    GetContentSignature(path) {
        metadata := this.GetContentMetadata(path)
        if !metadata.Available
            return this.MissingContentSignature()
        contentHash := TargetFileInspector.ComputeContentHash(metadata.Path)
        if contentHash == ""
            return this.MissingContentSignature()
        return {
            Available: true,
            Path: metadata.Path,
            FileSize: metadata.FileSize,
            ModifiedTime: metadata.ModifiedTime,
            ContentHash: contentHash
        }
    }

    GetContentMetadata(path) {
        if !this.Callbacks.IsSupportedTarget.Call(path)
            return {Available: false, Path: "", FileSize: 0,
                ModifiedTime: ""}
        path := this.Callbacks.GetSubjectPath.Call(path)
        if !FileExist(path) || DirExist(path)
            return {Available: false, Path: "", FileSize: 0,
                ModifiedTime: ""}
        try fileSize := FileGetSize(path)
        catch
            return {Available: false, Path: "", FileSize: 0,
                ModifiedTime: ""}
        try modifiedTime := FileGetTime(path, "M")
        catch
            modifiedTime := ""
        return {Available: true, Path: path, FileSize: fileSize,
            ModifiedTime: modifiedTime}
    }

    GetRelocationSearchRoots(path) {
        roots := []
        seen := Map()
        seen.CaseSense := "Off"
        SplitPath(path, , &directory)
        candidate := RTrim(directory, "\")
        while candidate != "" && !DirExist(candidate) {
            SplitPath(candidate, , &parent)
            parent := RTrim(parent, "\")
            if parent == candidate
                break
            candidate := parent
        }
        if candidate != "" && DirExist(candidate) {
            canonical := this.Callbacks.CanonicalPath.Call(candidate)
            roots.Push(candidate)
            seen[canonical] := true
        }
        try driveLetters := DriveGetList()
        catch
            driveLetters := ""
        Loop Parse, driveLetters {
            driveRoot := A_LoopField ":\"
            try driveStatus := DriveGetStatus(driveRoot)
            catch
                continue
            if driveStatus != "Ready"
                continue
            try driveType := DriveGetType(driveRoot)
            catch
                continue
            if !RegExMatch(driveType, "i)^(Fixed|Removable|Network|RAMDisk)$")
                continue
            canonical := this.Callbacks.CanonicalPath.Call(driveRoot)
            if !seen.Has(canonical) {
                roots.Push(driveRoot)
                seen[canonical] := true
            }
        }
        return roots
    }

    GetContentHash(path) {
        signature := this.GetContentSignature(path)
        return signature.Available ? signature.ContentHash : ""
    }

    static ComputeContentHash(path) {
        if !FileExist(path) || DirExist(path)
            return ""
        algorithmHandle := 0
        hashHandle := 0
        fileHandle := 0
        try {
            status := DllCall("bcrypt\BCryptOpenAlgorithmProvider",
                "Ptr*", &algorithmHandle, "WStr",
                TargetFileInspector.ContentHashAlgorithm, "Ptr", 0,
                "UInt", 0, "Int")
            if status != 0 || !algorithmHandle
                return ""
            objectLength := TargetFileInspector.GetBCryptUIntProperty(
                algorithmHandle, "ObjectLength")
            hashLength := TargetFileInspector.GetBCryptUIntProperty(
                algorithmHandle, "HashDigestLength")
            if objectLength <= 0
                || hashLength != TargetFileInspector.ContentHashLength
                return ""
            hashObject := Buffer(objectLength, 0)
            status := DllCall("bcrypt\BCryptCreateHash", "Ptr",
                algorithmHandle, "Ptr*", &hashHandle, "Ptr",
                hashObject.Ptr, "UInt", hashObject.Size, "Ptr", 0,
                "UInt", 0, "UInt", 0, "Int")
            if status != 0 || !hashHandle
                return ""
            fileHandle := DllCall("kernel32\CreateFileW", "WStr", path,
                "UInt", 0x80000000, "UInt", Win32.FILE_SHARE_ALL,
                "Ptr", 0, "UInt", Win32.OPEN_EXISTING,
                "UInt", 0x08000000, "Ptr", 0,
                "Ptr")
            if !fileHandle || fileHandle == -1
                return ""
            readBuffer := Buffer(TargetFileInspector.ContentReadBufferSize,
                0)
            loop {
                bytesRead := 0
                if !DllCall("kernel32\ReadFile", "Ptr", fileHandle,
                    "Ptr", readBuffer.Ptr, "UInt", readBuffer.Size,
                    "UInt*", &bytesRead, "Ptr", 0, "Int")
                    return ""
                if !bytesRead
                    break
                status := DllCall("bcrypt\BCryptHashData", "Ptr",
                    hashHandle, "Ptr", readBuffer.Ptr, "UInt", bytesRead,
                    "UInt", 0, "Int")
                if status != 0
                    return ""
            }
            digest := Buffer(hashLength, 0)
            status := DllCall("bcrypt\BCryptFinishHash", "Ptr",
                hashHandle, "Ptr", digest.Ptr, "UInt", digest.Size,
                "UInt", 0, "Int")
            if status != 0
                return ""
            result := ""
            Loop digest.Size
                result .= Format("{:02X}", NumGet(digest, A_Index - 1,
                    "UChar"))
            return result
        } catch {
            return ""
        } finally {
            if fileHandle && fileHandle != -1
                DllCall("kernel32\CloseHandle", "Ptr", fileHandle)
            if hashHandle
                DllCall("bcrypt\BCryptDestroyHash", "Ptr", hashHandle)
            if algorithmHandle
                DllCall("bcrypt\BCryptCloseAlgorithmProvider", "Ptr",
                    algorithmHandle, "UInt", 0)
        }
    }

    static GetBCryptUIntProperty(handle, propertyName) {
        valueBuffer := Buffer(4, 0)
        copied := 0
        status := DllCall("bcrypt\BCryptGetProperty", "Ptr", handle,
            "WStr", propertyName, "Ptr", valueBuffer.Ptr, "UInt",
            valueBuffer.Size, "UInt*", &copied, "UInt", 0, "Int")
        return status == 0 && copied == 4
            ? NumGet(valueBuffer, 0, "UInt") : 0
    }

    MissingContentSignature() {
        return {
            Available: false,
            Path: "",
            FileSize: 0,
            ModifiedTime: "",
            ContentHash: ""
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
