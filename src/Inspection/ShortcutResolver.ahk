; Windows 快捷方式的轻量读取边界。
; 将目标路径、参数和工作目录收敛为描述对象；读取失败保留“不可读”状态，
; 调用方可以继续使用原 LNK 作为启动入口，而不是猜测一个可能变化的内部 EXE。

class ShortcutDescriptor {
    __New(entryPath, readable := false, targetPath := "",
        workingDirectory := "", arguments := "", errorMessage := "") {
        this.EntryPath := entryPath
        this.Readable := !!readable
        this.TargetPath := targetPath
        this.WorkingDirectory := workingDirectory
        this.Arguments := arguments
        this.ErrorMessage := errorMessage
    }
}

class ShortcutResolver {
    static Read(path) {
        targetPath := ""
        workingDirectory := ""
        arguments := ""
        try {
            FileGetShortcut(path, &targetPath, &workingDirectory, &arguments)
            return ShortcutDescriptor(path, true, targetPath,
                workingDirectory, arguments)
        } catch as readError {
            return ShortcutDescriptor(path, false, "", "", "",
                readError.Message)
        }
    }
}
