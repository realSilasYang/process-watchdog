; 守护目标身份冲突检测与快捷方式身份刷新服务。
; 目标身份以规范化启动入口、解析后的真实目标和必要参数共同判定；
; 快捷方式变化只有在重新验证控制器所有权且不与现有目标冲突后才能提交。

class TargetIdentityService {
    static ShortcutRefreshIntervalMs := 30000

    __New(runtime, callbacks) {
        this.Runtime := runtime
        this.Callbacks := callbacks
    }

    IsCurrent(path, stateObj) {
        return stateObj && this.Runtime.appStates.Has(path)
            && this.Runtime.appStates[path] == stateObj
    }

    GetMonitoredTargetPath(path) {
        SplitPath(path, , , &extension)
        if (StrLower(extension) != "lnk")
            return path
        stateObj := this.Runtime.appStates.Has(path)
            ? this.Runtime.appStates[path] : ""
        return this.Runtime.targetSpecsService.Get(path, stateObj)
            .ResolvedTarget
    }

    GetStateIdentityTarget(path, stateObj := "") {
        specs := this.Runtime.targetSpecsService.Get(path, stateObj)
        return (specs.Probe.Kind == TargetProbeKind.ImagePath
            || specs.Probe.Kind == TargetProbeKind.CommandTarget)
            ? specs.Probe.TargetPath : ""
    }

    FindConflict(candidateTarget, excludedPath := "") {
        if (candidateTarget == "")
            return ""
        for existingPath, existingState in this.Runtime.appStates {
            if (excludedPath != ""
                && this.Callbacks.PathsEquivalent.Call(existingPath,
                    excludedPath))
                continue
            existingTarget := this.GetStateIdentityTarget(existingPath,
                existingState)
            if (existingTarget != ""
                && this.Callbacks.PathsEquivalent.Call(candidateTarget,
                    existingTarget))
                return existingPath
        }
        return ""
    }

    RefreshShortcut(path, stateObj, force := false) {
        SplitPath(path, , , &extension)
        if (StrLower(extension) != "lnk" || !this.IsCurrent(path, stateObj))
            return false
        if (stateObj.HasOwnProp("ResolvedTargetManual")
            && stateObj.ResolvedTargetManual)
            return false
        nowTicks := this.Callbacks.Now.Call()
        if (!force && stateObj.HasOwnProp("ShortcutResolveCheckedTicks")
            && nowTicks - stateObj.ShortcutResolveCheckedTicks
                < TargetIdentityService.ShortcutRefreshIntervalMs)
            return false
        stateObj.ShortcutResolveCheckedTicks := nowTicks

        freshTarget := this.Runtime.shortcutTargetResolver.ResolveEffective(
            path, true, &resolutionSource)
        if (freshTarget == "" || !this.IsCurrent(path, stateObj))
            return false
        descriptor := this.Runtime.shortcutTargetResolver.Read(path)
        if !this.IsCurrent(path, stateObj)
            return false
        priorResolvedTarget := stateObj.HasOwnProp("ResolvedTarget")
            ? stateObj.ResolvedTarget : ""
        priorShortcutArguments := stateObj.HasOwnProp("ShortcutArgs")
            ? stateObj.ShortcutArgs : ""
        shortcutArguments := descriptor.Readable
            ? descriptor.Arguments : priorShortcutArguments
        shortcutArgsChanged := priorShortcutArguments != shortcutArguments

        if this.Callbacks.PathsEquivalent.Call(priorResolvedTarget,
            freshTarget) {
            previousCritical := A_IsCritical
            Critical("On")
            try {
                if !this.IsCurrent(path, stateObj)
                    return false
                stateObj.ShortcutTargetSource := resolutionSource
                if shortcutArgsChanged
                    stateObj.ShortcutArgs := shortcutArguments
            } finally Critical(previousCritical ? previousCritical : "Off")
            if shortcutArgsChanged {
                this.Runtime.targetSpecsService.Get(path, stateObj, true)
                this.Log(this.Text("已刷新快捷方式内置参数：{1}", path))
            }
            return shortcutArgsChanged
        }

        conflictPath := this.FindConflict(freshTarget, path)
        if (conflictPath != "") {
            this.Log(this.Text("快捷方式真实进程刷新被拒绝，目标已由其它守护对象守护：{1} -> {2}",
                path, conflictPath))
            return false
        }
        if !this.IsCurrent(path, stateObj)
            return false

        ; 快捷方式可能改指向全新的可执行文件。提交新身份之前必须推进
        ; 控制器代际并清除旧 PID，避免旧目标的重启、验证或停止回调落到新目标上。
        if this.Callbacks.HasOwnProp("InvalidateRuntimeIdentity")
            && IsObject(this.Callbacks.InvalidateRuntimeIdentity) {
            if !this.Callbacks.InvalidateRuntimeIdentity.Call(path, stateObj)
                return false
            if !this.IsCurrent(path, stateObj)
                return false
        }

        previousCritical := A_IsCritical
        Critical("On")
        try {
            if !this.IsCurrent(path, stateObj)
                return false
            stateObj.ResolvedTarget := freshTarget
            stateObj.ShortcutTargetSource := resolutionSource
            if descriptor.Readable
                stateObj.ShortcutArgs := shortcutArguments
        } finally Critical(previousCritical ? previousCritical : "Off")
        this.Runtime.targetSpecsService.Get(path, stateObj, true)
        this.Log(this.Text("已刷新快捷方式真实进程（{1}）：{2} -> {3}",
            this.Text(resolutionSource), path, freshTarget))
        return true
    }

    TargetReferenceExists(path, stateObj := "") {
        return this.Runtime.targetSpecsService.Get(path, stateObj)
            .Launch.Available
    }

    TargetSubjectExists(path, stateObj := "") {
        subjectPath := this.GetTargetSubjectPath(path)
        return subjectPath != "" && FileExist(subjectPath)
            && !DirExist(subjectPath)
    }

    GetTargetSubjectPath(path) {
        SplitPath(path, , , &extension)
        if (StrLower(extension) != "lnk")
            return path
        effectiveTarget := this.GetMonitoredTargetPath(path)
        return effectiveTarget != "" ? effectiveTarget : path
    }

    Log(message) {
        try this.Callbacks.Log.Call(message)
    }

    Text(template, values*) {
        if this.Callbacks.HasOwnProp("Localize")
            && IsObject(this.Callbacks.Localize) {
            return this.Callbacks.Localize.Call(template, values*)
        }
        return values.Length ? Format(template, values*) : template
    }
}
