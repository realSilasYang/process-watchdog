; 目标是否正在运行的证据聚合器。
; 先从进程快照中筛出候选，再结合完整路径、命令行、快捷方式身份和权限逐一确认；
; 无法取得关键证据时返回 Unknown，只有明确无匹配时才返回 Stopped。

class TargetProbe {
    __New(snapshotIndexProvider := "", nativeSnapshotProvider := "",
        imagePathResolver := "", creationIdentityResolver := "",
        pathCanonicalizer := "", autoHotkeySnapshotProvider := "",
        clock := "") {
        this.SnapshotIndexProvider := snapshotIndexProvider
        this.NativeSnapshotProvider := nativeSnapshotProvider
        this.ImagePathResolver := imagePathResolver
        this.CreationIdentityResolver := creationIdentityResolver
        this.PathCanonicalizer := pathCanonicalizer
        this.AutoHotkeySnapshotProvider := autoHotkeySnapshotProvider
        this.Clock := clock
    }

    Observe(probeSpec, snapshotIndex := "", maximumSnapshotAgeMs := 0) {
        if !IsObject(probeSpec) || !probeSpec.HasOwnProp("Kind") {
            return ProcessObservation.Unknown(this.Now(), "target-probe",
                "探活规格无效", ProcessObservationReason.InvalidProbe)
        }
        switch probeSpec.Kind {
            case TargetProbeKind.ProcessName:
                return this.ObserveProcessName(probeSpec.TargetPath)
            case TargetProbeKind.ImagePath:
                return this.ObserveImagePath(probeSpec.TargetPath,
                    snapshotIndex)
            case TargetProbeKind.CommandTarget:
                return this.ObserveCommandTarget(probeSpec.TargetPath,
                    snapshotIndex, maximumSnapshotAgeMs)
            case TargetProbeKind.WorkingDirectory:
                return this.ObserveWorkingDirectory(probeSpec.WorkingDirectory,
                    probeSpec.PreferredName, snapshotIndex,
                    maximumSnapshotAgeMs)
            case TargetProbeKind.Unknown:
                return ProcessObservation.Unknown(this.Now(), "target-probe",
                    "目标没有可靠的探活身份",
                    ProcessObservationReason.InvalidProbe)
            case TargetProbeKind.None:
                return ProcessObservation.Stopped(this.Now(), "target-probe",
                    "目标不需要驻留探活")
        }
        return ProcessObservation.Unknown(this.Now(), "target-probe",
            "未知探活类型", ProcessObservationReason.InvalidProbe)
    }

    ObserveProcessName(processName) {
        try pid := ProcessExist(processName)
        catch as processError {
            return ProcessObservation.Unknown(this.Now(), "process-name",
                processError.Message)
        }
        return pid
            ? ProcessObservation.Running(pid, this.ResolveCreationIdentity(pid),
                this.Now(), "process-name")
            : ProcessObservation.Stopped(this.Now(), "process-name")
    }

    ObserveImagePath(targetPath, snapshotIndex := "") {
        if snapshotIndex is ProcessSnapshotIndex
            return snapshotIndex.ObserveImagePath(targetPath)
        snapshotResult := this.CaptureNativeSnapshot()
        if !snapshotResult.Ready {
            return ProcessObservation.Unknown(snapshotResult.CapturedAtTicks,
                "process-image", snapshotResult.Reason,
                ProcessObservationReason.SnapshotUnavailable)
        }
        wantedPath := this.Canonical(targetPath)
        SplitPath(targetPath, &targetName)
        targetName := StrLower(targetName)
        inaccessibleCandidate := false
        for processInfo in snapshotResult.Processes {
            pid := this.Value(processInfo, "pid", 0)
            if !pid || !ProcessExist(pid)
                continue
            imagePath := this.ResolveImagePath(pid)
            if (imagePath != "" && this.Canonical(imagePath) == wantedPath) {
                return ProcessObservation.Running(pid,
                    this.ResolveCreationIdentity(pid),
                    snapshotResult.CapturedAtTicks, "process-image")
            }
            if (imagePath == "" && targetName != ""
                && StrLower(this.Value(processInfo, "name", "")) == targetName)
                inaccessibleCandidate := true
        }
        return inaccessibleCandidate
            ? ProcessObservation.Unknown(snapshotResult.CapturedAtTicks,
                "process-image", "同名进程的镜像路径不可用",
                ProcessObservationReason.InaccessibleImagePath)
            : ProcessObservation.Stopped(snapshotResult.CapturedAtTicks,
                "process-image")
    }

    ObserveCommandTarget(targetPath, snapshotIndex := "",
        maximumSnapshotAgeMs := 0) {
        SplitPath(targetPath, , , &targetExtension)
        if StrLower(targetExtension) == "ahk" {
            autoHotkeyObservation := this.ObserveAutoHotkeyScript(targetPath,
                maximumSnapshotAgeMs)
            if !autoHotkeyObservation.IsUnknown()
                return autoHotkeyObservation
        }
        snapshotIndex := this.ResolveSnapshotIndex(snapshotIndex,
            maximumSnapshotAgeMs)
        if !(snapshotIndex is ProcessSnapshotIndex) {
            return ProcessObservation.Unknown(this.Now(), "process-command",
                "没有足够新的进程快照",
                ProcessObservationReason.SnapshotUnavailable)
        }
        return snapshotIndex.ObserveCommandTarget(targetPath)
    }

    ObserveAutoHotkeyScript(targetPath, maximumSnapshotAgeMs := 0) {
        if !IsObject(this.AutoHotkeySnapshotProvider) {
            return ProcessObservation.Unknown(this.Now(),
                "autohotkey-window", "AutoHotkey 主窗口快照提供器不可用",
                ProcessObservationReason.SnapshotUnavailable)
        }
        try snapshot := this.AutoHotkeySnapshotProvider.Call(
            maximumSnapshotAgeMs)
        catch as snapshotError {
            return ProcessObservation.Unknown(this.Now(),
                "autohotkey-window", snapshotError.Message,
                ProcessObservationReason.SnapshotUnavailable)
        }
        if !IsObject(snapshot) || !snapshot.HasOwnProp("Ready")
            || !snapshot.Ready {
            reason := IsObject(snapshot) && snapshot.HasOwnProp("Reason")
                ? snapshot.Reason : "AutoHotkey 主窗口快照不可用"
            return ProcessObservation.Unknown(this.Now(),
                "autohotkey-window", reason,
                ProcessObservationReason.SnapshotUnavailable)
        }

        wantedPath := this.Canonical(targetPath)
        scripts := snapshot.HasOwnProp("Scripts")
            && Type(snapshot.Scripts) == "Array" ? snapshot.Scripts : []
        for scriptInfo in scripts {
            pid := this.Value(scriptInfo, "PID", 0)
            scriptPath := this.Value(scriptInfo, "Path", "")
            if pid && ProcessExist(pid)
                && this.Canonical(scriptPath) == wantedPath {
                return ProcessObservation.Running(pid,
                    this.ResolveCreationIdentity(pid),
                    this.Value(snapshot, "CapturedAtTicks", this.Now()),
                    "autohotkey-window")
            }
        }
        if this.Value(snapshot, "Complete", false) {
            return ProcessObservation.Stopped(
                this.Value(snapshot, "CapturedAtTicks", this.Now()),
                "autohotkey-window")
        }
        return ProcessObservation.Unknown(
            this.Value(snapshot, "CapturedAtTicks", this.Now()),
            "autohotkey-window",
            this.Value(snapshot, "Reason", "AutoHotkey 进程身份不完整"))
    }

    ObserveWorkingDirectory(workingDirectory, preferredName := "",
        snapshotIndex := "", maximumSnapshotAgeMs := 0) {
        if workingDirectory == "" {
            return ProcessObservation.Stopped(this.Now(),
                "process-working-directory", "工作目录为空")
        }
        snapshotIndex := this.ResolveSnapshotIndex(snapshotIndex,
            maximumSnapshotAgeMs)
        if !(snapshotIndex is ProcessSnapshotIndex) {
            return ProcessObservation.Unknown(this.Now(),
                "process-working-directory", "没有足够新的进程快照",
                ProcessObservationReason.SnapshotUnavailable)
        }
        return snapshotIndex.ObserveExecutableInRoot(workingDirectory,
            StrLower(preferredName))
    }

    ResolveSnapshotIndex(snapshotIndex, maximumSnapshotAgeMs) {
        if snapshotIndex is ProcessSnapshotIndex
            return snapshotIndex
        if !IsObject(this.SnapshotIndexProvider)
            return ""
        try candidate := this.SnapshotIndexProvider.Call(maximumSnapshotAgeMs)
        catch
            return ""
        return candidate is ProcessSnapshotIndex ? candidate : ""
    }

    CaptureNativeSnapshot() {
        capturedAtTicks := this.Now()
        if !IsObject(this.NativeSnapshotProvider) {
            return {Ready: false, Processes: [],
                CapturedAtTicks: capturedAtTicks,
                Reason: "原生进程快照提供器不可用"}
        }
        try result := this.NativeSnapshotProvider.Call()
        catch as snapshotError {
            return {Ready: false, Processes: [],
                CapturedAtTicks: capturedAtTicks,
                Reason: snapshotError.Message}
        }
        if !IsObject(result) || !result.HasOwnProp("Ready")
            || !result.Ready || !result.HasOwnProp("Processes")
            || Type(result.Processes) != "Array" {
            return {Ready: false, Processes: [],
                CapturedAtTicks: capturedAtTicks,
                Reason: "无法建立原生进程快照"}
        }
        resultTicks := result.HasOwnProp("CapturedAtTicks")
            ? result.CapturedAtTicks : capturedAtTicks
        return {Ready: true, Processes: result.Processes,
            CapturedAtTicks: resultTicks, Reason: ""}
    }

    ResolveImagePath(pid) {
        if !IsObject(this.ImagePathResolver)
            return ""
        try return String(this.ImagePathResolver.Call(pid))
        catch
            return ""
    }

    ResolveCreationIdentity(pid) {
        if !IsObject(this.CreationIdentityResolver)
            return ""
        try return String(this.CreationIdentityResolver.Call(pid))
        catch
            return ""
    }

    Canonical(path) {
        if IsObject(this.PathCanonicalizer) {
            try return this.PathCanonicalizer.Call(path)
        }
        path := Trim(String(path), " `t`r`n`"")
        path := StrReplace(path, "/", "\")
        return StrLower(StrLen(path) > 3 ? RTrim(path, "\") : path)
    }

    Now() {
        if IsObject(this.Clock) {
            try return Integer(this.Clock.Call())
        }
        return DllCall("kernel32\GetTickCount64", "UInt64")
    }

    Value(objectValue, propertyName, defaultValue := "") {
        return IsObject(objectValue) && objectValue.HasOwnProp(propertyName)
            ? objectValue.%propertyName% : defaultValue
    }
}
