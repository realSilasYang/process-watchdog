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
