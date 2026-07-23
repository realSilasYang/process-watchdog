#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\Inspection\DirectoryChangeWatcher.ahk

AssertDirectoryWatcher(value, message) {
    if !value
        throw Error(message)
}

BuildDirectoryNotification(entries) {
    totalBytes := 0
    offsets := []
    for entry in entries {
        nameBytes := StrLen(entry.Name) * 2
        entryBytes := 12 + nameBytes
        alignedBytes := (entryBytes + 3) & ~3
        offsets.Push({Offset: totalBytes, NameBytes: nameBytes,
            EntryBytes: entryBytes, AlignedBytes: alignedBytes})
        totalBytes += alignedBytes
    }
    notificationBuffer := Buffer(totalBytes, 0)
    for index, entry in entries {
        layout := offsets[index]
        nextOffset := index < entries.Length ? layout.AlignedBytes : 0
        NumPut("UInt", nextOffset, notificationBuffer, layout.Offset)
        NumPut("UInt", entry.Action, notificationBuffer, layout.Offset + 4)
        NumPut("UInt", layout.NameBytes, notificationBuffer,
            layout.Offset + 8)
        StrPut(entry.Name, notificationBuffer.Ptr + layout.Offset + 12,
            StrLen(entry.Name), "UTF-16")
    }
    return notificationBuffer
}

RunDirectoryChangeWatcherTests() {
    parsedBuffer := BuildDirectoryNotification([
        {Action: 1, Name: "first.exe"},
        {Action: 3, Name: "nested\second.dll"}
    ])
    parsedChanges := DirectoryChangeWatcher.ParseNotificationBuffer(
        parsedBuffer, parsedBuffer.Size)
    AssertDirectoryWatcher(parsedChanges.Length == 2
        && parsedChanges[1].Action == 1
        && parsedChanges[1].RelativePath == "first.exe"
        && parsedChanges[2].Action == 3
        && parsedChanges[2].RelativePath == "nested\second.dll",
        "目录通知缓冲区解析结果错误")

    zeroChanges := DirectoryChangeWatcher.ParseNotificationBuffer(
        Buffer(16, 0), 0)
    AssertDirectoryWatcher(zeroChanges.Length == 1
        && zeroChanges[1].RelativePath == "*",
        "通知缓冲区溢出信号没有转换为全目录变化")

    malformedBuffer := BuildDirectoryNotification([
        {Action: 1, Name: "safe.exe"}
    ])
    NumPut("UInt", 4, malformedBuffer, 0)
    malformedChanges := DirectoryChangeWatcher.ParseNotificationBuffer(
        malformedBuffer, malformedBuffer.Size + 100)
    AssertDirectoryWatcher(malformedChanges.Length == 1
        && malformedChanges[1].RelativePath == "safe.exe",
        "畸形后继偏移破坏了已经解析的有效通知")

    processId := DllCall("kernel32\GetCurrentProcessId", "UInt")
    rootPath := Format("{}\ProcessWatchdog-DirectoryWatcher-{}-{}",
        A_Temp, processId, A_TickCount)
    missingPath := rootPath "-missing"
    watcher := ""
    missingWatcher := ""
    try {
        DirCreate(rootPath "\nested")
        watcher := DirectoryChangeWatcher(rootPath "\")
        AssertDirectoryWatcher(watcher.Active && watcher.DirectoryHandle
            && watcher.EventHandle, "有效目录监听器未能启动")
        AssertDirectoryWatcher(watcher.Poll().Length == 0,
            "没有文件变化时返回了虚假通知")

        eventPath := rootPath "\nested\event.txt"
        FileAppend("event", eventPath, "UTF-8")
        eventFound := false
        deadline := A_TickCount + 3000
        while (A_TickCount < deadline && !eventFound) {
            for change in watcher.Poll() {
                if (StrLower(change.RelativePath) == "nested\event.txt") {
                    eventFound := true
                    break
                }
            }
            if !eventFound
                Sleep(20)
        }
        AssertDirectoryWatcher(eventFound,
            "递归目录中的真实文件变化未被捕获")

        watcher.Close()
        watcher.Close()
        AssertDirectoryWatcher(!watcher.Active && !watcher.DirectoryHandle
            && !watcher.EventHandle && watcher.Poll().Length == 0,
            "目录监听器关闭不是幂等终态")
        AssertDirectoryWatcher(watcher.Open() && watcher.Active,
            "关闭后的目录监听器无法重新打开")

        missingWatcher := DirectoryChangeWatcher(missingPath)
        AssertDirectoryWatcher(!missingWatcher.Active
            && !missingWatcher.DirectoryHandle && !missingWatcher.EventHandle
            && !missingWatcher.Open(),
            "不存在的目录留下了活动监听句柄")
    } finally {
        if IsObject(watcher)
            watcher.Close()
        if IsObject(missingWatcher)
            missingWatcher.Close()
        try DirDelete(rootPath, true)
    }
}

try {
    RunDirectoryChangeWatcherTests()
    ExitApp(0)
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
