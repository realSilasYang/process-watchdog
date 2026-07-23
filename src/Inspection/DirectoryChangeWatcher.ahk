class DirectoryChangeWatcher {
    __New(rootPath) {
        this.Root := StrLen(rootPath) > 3 ? RTrim(rootPath, "\") : rootPath
        this.DirectoryHandle := 0
        this.EventHandle := 0
        this.NotificationBuffer := Buffer(65536, 0)
        this.Overlapped := Buffer(A_PtrSize == 8 ? 32 : 20, 0)
        this.Active := false
        this.Open()
    }

    __Delete() {
        this.Close()
    }

    Open() {
        this.Close()
        if !DirExist(this.Root)
            return false
        flags := Win32.FILE_FLAG_BACKUP_SEMANTICS | Win32.FILE_FLAG_OVERLAPPED
        directoryHandle := DllCall("kernel32\CreateFileW", "WStr", this.Root,
            "UInt", Win32.FILE_LIST_DIRECTORY, "UInt", Win32.FILE_SHARE_ALL,
            "Ptr", 0, "UInt", Win32.OPEN_EXISTING, "UInt", flags, "Ptr", 0, "Ptr")
        if (!directoryHandle || directoryHandle == -1)
            return false
        eventHandle := DllCall("kernel32\CreateEventW", "Ptr", 0, "Int", true,
            "Int", false, "Ptr", 0, "Ptr")
        if !eventHandle {
            DllCall("kernel32\CloseHandle", "Ptr", directoryHandle)
            return false
        }
        this.DirectoryHandle := directoryHandle
        this.EventHandle := eventHandle
        this.Active := this.Rearm()
        if !this.Active
            this.Close()
        return this.Active
    }

    Rearm() {
        if !this.DirectoryHandle || !this.EventHandle
            return false
        DllCall("kernel32\ResetEvent", "Ptr", this.EventHandle)
        DllCall("ntdll\RtlZeroMemory", "Ptr", this.Overlapped.Ptr,
            "UPtr", this.Overlapped.Size)
        eventOffset := A_PtrSize == 8 ? 24 : 16
        NumPut("Ptr", this.EventHandle, this.Overlapped, eventOffset)
        started := DllCall("kernel32\ReadDirectoryChangesW",
            "Ptr", this.DirectoryHandle, "Ptr", this.NotificationBuffer.Ptr,
            "UInt", this.NotificationBuffer.Size, "Int", true,
            "UInt", Win32.FILE_NOTIFY_FILTER, "Ptr", 0,
            "Ptr", this.Overlapped.Ptr, "Ptr", 0, "Int")
        if started
            return true
        return DllCall("kernel32\GetLastError", "UInt")
            == Win32.ERROR_IO_PENDING
    }

    Poll() {
        if !this.Active || !this.EventHandle
            return []
        if (DllCall("kernel32\WaitForSingleObject", "Ptr", this.EventHandle,
            "UInt", 0, "UInt") != Win32.WAIT_OBJECT_0)
            return []
        bytesReturned := 0
        completed := DllCall("kernel32\GetOverlappedResult",
            "Ptr", this.DirectoryHandle, "Ptr", this.Overlapped.Ptr,
            "UInt*", &bytesReturned, "Int", false, "Int")
        if !completed {
            this.RearmOrClose()
            return []
        }
        try return DirectoryChangeWatcher.ParseNotificationBuffer(
            this.NotificationBuffer, bytesReturned)
        finally this.RearmOrClose()
    }

    RearmOrClose() {
        this.Active := this.Rearm()
        if !this.Active
            this.Close()
        return this.Active
    }

    Close() {
        this.Active := false
        if this.DirectoryHandle {
            try DllCall("kernel32\CancelIoEx", "Ptr", this.DirectoryHandle,
                "Ptr", 0)
            try DllCall("kernel32\CloseHandle", "Ptr", this.DirectoryHandle)
        }
        if this.EventHandle
            try DllCall("kernel32\CloseHandle", "Ptr", this.EventHandle)
        this.DirectoryHandle := 0
        this.EventHandle := 0
    }

    static ParseNotificationBuffer(notificationBuffer, bytesReturned) {
        changes := []
        safeBytes := Min(Max(Integer(bytesReturned), 0),
            notificationBuffer.Size)
        if safeBytes == 0 {
            changes.Push({Action: 0, RelativePath: "*"})
            return changes
        }
        offset := 0
        while (offset + 12 <= safeBytes) {
            nextOffset := NumGet(notificationBuffer, offset, "UInt")
            action := NumGet(notificationBuffer, offset + 4, "UInt")
            nameBytes := NumGet(notificationBuffer, offset + 8, "UInt")
            nameEnd := offset + 12 + nameBytes
            if (nameBytes > 0 && !(nameBytes & 1) && nameEnd <= safeBytes) {
                relativePath := StrGet(notificationBuffer.Ptr + offset + 12,
                    nameBytes // 2, "UTF-16")
                changes.Push({Action: action, RelativePath: relativePath})
            }
            if !nextOffset
                break
            nextEntry := offset + nextOffset
            if (nextOffset < 12 || Mod(nextOffset, 4)
                || nextEntry > safeBytes)
                break
            offset := nextEntry
        }
        return changes
    }
}
