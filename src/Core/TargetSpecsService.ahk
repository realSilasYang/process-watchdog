; 从持久化状态构建目标规格并管理缓存。
; 快捷方式元数据、手动真实目标和启动参数共同决定缓存身份；
; 只有会改变语义的证据才使缓存失效，单纯的读取时间变化不会触发重复解析。

class TargetSpecsService {
    __New(shortcutTargetResolver, normalizeTargetPath) {
        this.ShortcutTargetResolver := shortcutTargetResolver
        this.NormalizeTargetPath := normalizeTargetPath
    }

    StateValue(stateObj, propertyName, defaultValue := "") {
        return IsObject(stateObj) && stateObj.HasOwnProp(propertyName)
            ? stateObj.%propertyName% : defaultValue
    }

    Fingerprint(path, stateObj := "") {
        resolvedTarget := this.StateValue(stateObj, "ResolvedTarget", "")
        entryExists := !InStr(path, "\") || !!FileExist(path)
        resolvedExists := resolvedTarget != "" && !!FileExist(resolvedTarget)
        values := [path, entryExists ? "1" : "0", resolvedTarget,
            resolvedExists ? "1" : "0",
            this.StateValue(stateObj, "WorkDir", ""),
            this.StateValue(stateObj, "Args", ""),
            this.StateValue(stateObj, "ShortcutArgs", ""),
            this.StateValue(stateObj, "EnvVars", ""),
            this.StateValue(stateObj, "RuntimePath", ""),
            this.StateValue(stateObj, "RuntimeArgs", ""),
            this.StateValue(stateObj, "RunAsAdmin", 0) ? "1" : "0"]
        fingerprint := ""
        for index, value in values
            fingerprint .= (index > 1 ? Chr(31) : "") String(value)
        return fingerprint
    }

    Build(path, stateObj := "") {
        resolvedTarget := this.StateValue(stateObj, "ResolvedTarget", "")
        entryExists := !InStr(path, "\") || !!FileExist(path)
        shortcutInfo := ShortcutDescriptor(path)
        SplitPath(path, , , &extension)
        extension := StrLower(extension)
        if (extension == "lnk" && resolvedTarget == "" && entryExists) {
            shortcutInfo := this.ShortcutTargetResolver.Read(path)
            resolvedTarget := this.ShortcutTargetResolver.ResolveEffective(
                path, true)
        }
        shortcutArguments := this.StateValue(stateObj, "ShortcutArgs", "")
        if (shortcutArguments == "" && shortcutInfo.Readable)
            shortcutArguments := shortcutInfo.Arguments
        shortcutWorkingDirectory := shortcutInfo.Readable
            ? shortcutInfo.WorkingDirectory : ""
        workingDirectory := this.StateValue(stateObj, "WorkDir", "")
        if (workingDirectory == "")
            workingDirectory := shortcutWorkingDirectory
        options := {
            ResolvedTarget: resolvedTarget,
            EntryExists: entryExists,
            ResolvedTargetExists: resolvedTarget != ""
                && !!FileExist(resolvedTarget),
            Arguments: this.StateValue(stateObj, "Args", ""),
            ShortcutArguments: shortcutArguments,
            WorkingDirectory: workingDirectory,
            ShortcutWorkingDirectory: shortcutWorkingDirectory,
            Environment: this.StateValue(stateObj, "EnvVars", ""),
            RuntimePath: this.StateValue(stateObj, "RuntimePath", ""),
            RuntimeArguments: this.StateValue(stateObj, "RuntimeArgs", ""),
            RunAsAdmin: this.StateValue(stateObj, "RunAsAdmin", false),
            ShortcutReadable: shortcutInfo.Readable,
            ShortcutTargetsGenericLauncher: shortcutInfo.Readable
                && this.ShortcutTargetResolver.IsGenericLauncher(
                    shortcutInfo.TargetPath),
            OneShotHint: this.StateValue(stateObj, "OneShot", false)
        }
        return TargetSpecFactory.Create(path, options)
    }

    Get(path, stateObj := "", forceRefresh := false) {
        path := this.NormalizeTargetPath.Call(path)
        fingerprint := this.Fingerprint(path, stateObj)
        if (!forceRefresh && IsObject(stateObj)
            && stateObj.HasOwnProp("TargetSpecs")
            && stateObj.TargetSpecs is TargetSpecs
            && stateObj.HasOwnProp("TargetSpecsFingerprint")
            && stateObj.TargetSpecsFingerprint == fingerprint)
            return stateObj.TargetSpecs
        specs := this.Build(path, stateObj)
        if IsObject(stateObj) {
            stateObj.TargetSpecs := specs
            stateObj.TargetSpecsFingerprint := fingerprint
            stateObj.OneShot := specs.IsOneShot
        }
        return specs
    }
}
