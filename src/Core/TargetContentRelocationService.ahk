; 直接文件目标的内容迁移识别服务。
; 目标消失后在独立工作进程中按扩展名和文件大小筛选候选，再以 SHA-256
; 确认内容完全一致。路径、文件名、卷和文件系统身份都不参与匹配。

class TargetRelocationService {
    static PollIntervalMs := 500
    static CandidateDelayMs := 1500
    static DeliveryRetryIntervalMs := 3000
    static IgnoreCooldownMs := 600000
    static BaselineRefreshIntervalMs := 60000
    static FullHashRefreshIntervalMs := 600000
    static ScanRetryIntervalMs := 30000
    static ScanTimeoutSeconds := 60
    static DiagnosticRepeatIntervalMs := 30000

    __New(runtime, callbacks) {
        this.Runtime := runtime
        this.Callbacks := callbacks
        this.Targets := Map()
        this.Targets.CaseSense := "Off"
        this.PendingCandidates := Map()
        this.PendingCandidates.CaseSense := "Off"
        this.IgnoredCandidates := Map()
        this.IgnoredCandidates.CaseSense := "Off"
        this.NextToken := 1
        this.Running := false
        this.Stopped := false
        this.PollTimer := ObjBindMethod(this, "PollTick")
    }

    Start() {
        if this.Stopped || this.Running
            return false
        this.SyncTargets()
        try SetTimer(this.PollTimer, TargetRelocationService.PollIntervalMs)
        catch
            return false
        this.Running := true
        return true
    }

    Shutdown(*) {
        if this.Stopped
            return
        this.Stopped := true
        this.Running := false
        try SetTimer(this.PollTimer, 0)
        for _, record in this.Targets
            this.CancelScan(record)
        for _, candidate in this.PendingCandidates {
            stateObj := candidate.State
            if IsObject(stateObj) && stateObj.HasOwnProp("RelocationPending")
                stateObj.RelocationPending := false
        }
        this.PendingCandidates.Clear()
        this.Targets.Clear()
        this.IgnoredCandidates.Clear()
    }

    SyncTargets() {
        if this.Stopped
            return 0
        desired := Map()
        desired.CaseSense := "Off"
        for path, stateObj in this.Runtime.appStates {
            path := this.NormalizePath(path)
            if this.IsEligiblePath(path)
                desired[path] := stateObj
        }
        stalePaths := []
        for path, record in this.Targets {
            if !desired.Has(path) || desired[path] != record.State
                stalePaths.Push(path)
        }
        for path in stalePaths
            this.RemoveTarget(path, false)
        for path, stateObj in desired {
            if this.Targets.Has(path)
                continue
            contentHash := stateObj.HasOwnProp("ContentHash")
                && this.IsContentHash(stateObj.ContentHash)
                ? StrUpper(stateObj.ContentHash) : ""
            contentSize := stateObj.HasOwnProp("ContentSize")
                ? Max(0, stateObj.ContentSize) : 0
            signature := this.GetContentSignature(path)
            if signature.Available {
                contentHash := signature.ContentHash
                contentSize := signature.FileSize
                stateObj.ContentHash := contentHash
                stateObj.ContentSize := contentSize
            }
            nowTicks := this.Now()
            this.Targets[path] := {
                Path: path,
                State: stateObj,
                ContentHash: contentHash,
                ContentSize: contentSize,
                MetadataKey: signature.Available
                    ? this.MetadataKey(signature) : "",
                MissingObservedTicks: 0,
                LastBaselineTicks: signature.Available ? nowTicks : 0,
                LastHashTicks: signature.Available ? nowTicks : 0,
                ScanJob: "",
                SearchRoots: [],
                SearchRootIndex: 1,
                ActiveRootIndex: 0,
                MatchedPaths: [],
                NextScanTicks: 0,
                LastDiagnosticKey: "",
                LastDiagnosticTicks: 0
            }
        }
        return this.Targets.Count
    }

    RemoveTarget(path, resetState := true) {
        path := this.NormalizePath(path)
        if !this.Targets.Has(path)
            return false
        record := this.Targets[path]
        this.CancelScan(record)
        this.Targets.Delete(path)
        if this.PendingCandidates.Has(path) {
            candidate := this.PendingCandidates[path]
            this.PendingCandidates.Delete(path)
            this.NotifyInvalidated(candidate)
            if resetState
                this.ReleaseState(candidate)
        }
        return true
    }

    IsEligiblePath(path) {
        path := this.NormalizePath(path)
        if path == "" || !InStr(path, "\")
            return false
        SplitPath(path, , , &extension)
        return RegExMatch(extension,
            "i)^(exe|com|msc|ahk|py|pyw|js|vbs|vbe|wsf|ps1|bat|cmd|rb|pl|php|lua|jar|sh|bash)$") != 0
    }

    ExtensionsCompatible(previousPath, candidatePath) {
        SplitPath(previousPath, , , &previousExtension)
        SplitPath(candidatePath, , , &candidateExtension)
        previousExtension := StrLower(previousExtension)
        candidateExtension := StrLower(candidateExtension)
        if RegExMatch(previousExtension, "i)^(exe|com)$")
            return RegExMatch(candidateExtension, "i)^(exe|com)$") != 0
        return previousExtension != ""
            && previousExtension == candidateExtension
    }

    ObserveAvailable(path, stateObj, force := false) {
        path := this.NormalizePath(path)
        if !this.IsCurrent(path, stateObj)
            return false
        if !this.Targets.Has(path)
            this.SyncTargets()
        if !this.Targets.Has(path)
            return false
        record := this.Targets[path]
        record.MissingObservedTicks := 0
        this.CancelScan(record)
        if this.IsMaintenanceBusy(path, stateObj)
            return false
        nowTicks := this.Now()
        if !force && record.LastBaselineTicks
            && nowTicks - record.LastBaselineTicks
                < TargetRelocationService.BaselineRefreshIntervalMs
            return false
        metadata := this.GetContentMetadata(path)
        if !metadata.Available
            return false
        metadataKey := this.MetadataKey(metadata)
        if !force && metadataKey == record.MetadataKey
            && record.LastHashTicks
            && nowTicks - record.LastHashTicks
                < TargetRelocationService.FullHashRefreshIntervalMs {
            record.LastBaselineTicks := nowTicks
            return false
        }
        signature := this.GetContentSignature(path)
        if !signature.Available
            return false
        changed := record.ContentHash != signature.ContentHash
            || record.ContentSize != signature.FileSize
        record.ContentHash := signature.ContentHash
        record.ContentSize := signature.FileSize
        record.MetadataKey := this.MetadataKey(signature)
        record.LastBaselineTicks := nowTicks
        record.LastHashTicks := nowTicks
        if changed {
            stateObj.ContentHash := signature.ContentHash
            stateObj.ContentSize := signature.FileSize
            this.ClearIgnoredForPath(path)
            this.PersistBaseline(path, stateObj)
        }
        return changed
    }

    TryDetect(path, stateObj) {
        path := this.NormalizePath(path)
        if !this.IsCurrent(path, stateObj) || !stateObj.Enabled
            || !this.IsEligiblePath(path)
            return false
        if stateObj.HasOwnProp("RelocationPending")
            && stateObj.RelocationPending
            return true
        if this.TargetExists(path) {
            this.ObserveAvailable(path, stateObj)
            return false
        }
        if this.PendingCandidates.Has(path)
            return true
        if !this.Targets.Has(path)
            this.SyncTargets()
        if !this.Targets.Has(path)
            return false
        record := this.Targets[path]
        if !this.IsContentHash(record.ContentHash) {
            this.NoteDiagnostic(record, "NoBaseline",
                this.Text("无法执行内容迁移：缺少旧文件的完整内容指纹：{1}",
                    record.Path))
            return false
        }
        nowTicks := this.Now()
        if !record.MissingObservedTicks {
            record.MissingObservedTicks := nowTicks
            this.NoteDiagnostic(record, "MissingObserved",
                this.Text("监测到目标文件缺失，内容迁移将在缺失状态稳定后开始扫描：{1}",
                    record.Path))
            return false
        }
        if nowTicks - record.MissingObservedTicks
            < TargetRelocationService.CandidateDelayMs
            return false
        if this.IsMaintenanceBusy(path, stateObj) {
            this.NoteDiagnostic(record, "MaintenanceBusy",
                this.Text("内容迁移暂缓：目标正处于升级保护、维护恢复或近期启动信号保护中：{1}",
                    record.Path))
            return false
        }
        candidateInfo := this.ResolveCandidate(record)
        if !candidateInfo
            return false
        candidatePath := this.NormalizePath(candidateInfo.Path)
        if !this.IsCandidatePathValid(path, candidatePath) {
            this.NoteDiagnostic(record, "InvalidCandidate|" candidatePath,
                this.Text("内容迁移候选已被拒绝：{1} -> {2}（候选不存在、扩展名不兼容、已被守护或与现有目标冲突）",
                    path, candidatePath))
            return false
        }
        candidateSignature := this.CandidateSignature(path, candidatePath,
            record.ContentHash)
        if this.IgnoredCandidates.Has(candidateSignature)
            && this.IgnoredCandidates[candidateSignature] > nowTicks {
            this.NoteDiagnostic(record, "Ignored|" candidatePath,
                this.Text("内容迁移候选仍在本次忽略冷却期内：{1} -> {2}",
                    path, candidatePath))
            return false
        }
        if this.IgnoredCandidates.Has(candidateSignature)
            this.IgnoredCandidates.Delete(candidateSignature)
        return this.PublishCandidate(path, candidatePath, stateObj,
            "ContentHash", record.ContentHash, record.ContentSize,
            candidateSignature)
    }

    ResolveCandidate(record) {
        if !this.IsContentHash(record.ContentHash) {
            this.NoteDiagnostic(record, "NoBaseline",
                this.Text("无法执行内容迁移：缺少旧文件的完整内容指纹：{1}",
                    record.Path))
            return ""
        }
        if IsObject(record.ScanJob) {
            completedRootIndex := record.ActiveRootIndex
            completedRoot := this.DescribeSearchRoot(record,
                completedRootIndex)
            scanResult := this.PollContentScan(record.ScanJob)
            if !scanResult.Ready
                return ""
            record.ScanJob := ""
            record.ActiveRootIndex := 0
            if scanResult.Failed || scanResult.Truncated {
                reason := scanResult.Failed
                    ? this.Text("后台扫描失败或超时")
                    : this.Text("扫描未能在时限内完整核对")
                this.NoteDiagnostic(record,
                    "ScanIncomplete|" completedRootIndex,
                    this.Text("内容迁移扫描未完成，将稍后重试：{1}（搜索根：{2}；原因：{3}）",
                        record.Path, completedRoot, reason))
                this.ResetScanCycle(record,
                    TargetRelocationService.ScanRetryIntervalMs)
                return ""
            }
            for candidatePath in scanResult.Paths {
                if !this.IsCandidatePathValid(record.Path, candidatePath)
                    continue
                signature := this.GetContentSignature(candidatePath)
                if signature.Available
                    && signature.FileSize == record.ContentSize
                    && signature.ContentHash == record.ContentHash
                    this.AddMatchedPath(record, candidatePath)
            }
            if record.MatchedPaths.Length > 1 {
                this.Log(this.Text(
                    "发现多个内容完全相同的迁移候选，已暂停自动迁移：{1}（候选：{2}）",
                    record.Path, this.DescribeMatchedPaths(record)))
                this.ResetScanCycle(record,
                    TargetRelocationService.ScanRetryIntervalMs)
                return ""
            }
            ; 第一个搜索根是旧路径仍存在的最近祖先。这里的唯一内容匹配
            ; 比全盘缓存或历史副本更接近原目标，应立即采用；本地没有结果
            ; 时才把后续盘符根的匹配汇总起来做全局歧义检查。
            if completedRootIndex == 1 {
                if record.MatchedPaths.Length == 1 {
                    candidatePath := record.MatchedPaths[1]
                    this.ResetScanCycle(record, 0)
                    return {Path: candidatePath}
                }
                record.MatchedPaths := []
            }
        }
        if this.Now() < record.NextScanTicks
            return ""
        if !record.SearchRoots.Length {
            record.SearchRoots := this.GetSearchRoots(record.Path)
            record.SearchRootIndex := 1
        }
        while record.SearchRootIndex <= record.SearchRoots.Length {
            currentRootIndex := record.SearchRootIndex
            rootPath := record.SearchRoots[record.SearchRootIndex]
            record.SearchRootIndex++
            ; 最近目录直接递归扫描，避免全局索引把编辑器历史混入本地层；
            ; 扩大到盘符根后才使用受根目录约束的 Everything 查询。
            useEverything := currentRootIndex > 1
            scanJob := this.StartContentScan(rootPath, record.Path,
                record.ContentSize, record.ContentHash,
                useEverything,
                TargetRelocationService.ScanTimeoutSeconds)
            if IsObject(scanJob) {
                record.ScanJob := scanJob
                record.ActiveRootIndex := currentRootIndex
                scanMethod := useEverything
                    ? this.Text("Everything 索引预筛选")
                    : this.Text("直接递归扫描")
                this.NoteDiagnostic(record, "ScanStarted|" currentRootIndex,
                    this.Text("正在扫描内容迁移候选：{1}（搜索根：{2}；方式：{3}）",
                        record.Path, rootPath, scanMethod))
                return ""
            }
            scanMethod := useEverything
                ? this.Text("Everything 索引预筛选")
                : this.Text("直接递归扫描")
            this.NoteDiagnostic(record, "ScanStartFailed|" currentRootIndex,
                this.Text("无法启动内容迁移扫描，已尝试下一个搜索根：{1}（搜索根：{2}；方式：{3}）",
                    record.Path, rootPath, scanMethod))
        }
        if record.MatchedPaths.Length == 1 {
            candidatePath := record.MatchedPaths[1]
            this.ResetScanCycle(record, 0)
            return {Path: candidatePath}
        }
        this.NoteDiagnostic(record, "NoMatch",
            this.Text("尚未找到内容完全一致的迁移候选，将稍后重试：{1}（已按扩展名、大小和 SHA-256 完整内容指纹核对）",
                record.Path))
        this.ResetScanCycle(record,
            TargetRelocationService.ScanRetryIntervalMs)
        return ""
    }

    PublishCandidate(oldPath, newPath, stateObj, evidence, contentHash,
        contentSize, candidateSignature) {
        if !this.IsCurrent(oldPath, stateObj)
            return false
        stateObj.CancelScheduledTasks()
        stateObj.RelocationPending := true
        candidate := {
            Token: this.NextToken,
            OldPath: oldPath,
            NewPath: newPath,
            Evidence: evidence,
            ContentHash: contentHash,
            ContentSize: contentSize,
            Signature: candidateSignature,
            State: stateObj,
            Generation: stateObj.Generation,
            DetectedTicks: this.Now(),
            LastDeliveryTicks: 0,
            DeliveryFailures: 0
        }
        this.NextToken++
        this.PendingCandidates[oldPath] := candidate
        this.UpdatePendingState(candidate)
        this.Log(this.Text(
            "检测到内容一致的守护目标新位置，等待用户确认：{1} -> {2}",
            oldPath, newPath))
        this.DeliverCandidate(candidate)
        return true
    }

    ValidateCandidate(candidate) {
        if !IsObject(candidate) || !candidate.HasOwnProp("OldPath")
            || !candidate.HasOwnProp("Token")
            return false
        oldPath := this.NormalizePath(candidate.OldPath)
        if !this.PendingCandidates.Has(oldPath)
            return false
        currentCandidate := this.PendingCandidates[oldPath]
        stateObj := currentCandidate.State
        if currentCandidate.Token != candidate.Token
            || !this.IsCurrent(oldPath, stateObj)
            || stateObj.Generation != currentCandidate.Generation
            || !stateObj.HasOwnProp("RelocationPending")
            || !stateObj.RelocationPending
            || this.TargetExists(oldPath)
            || !this.IsCandidatePathValid(oldPath,
                currentCandidate.NewPath)
            || this.IsMaintenanceBusy(oldPath, stateObj)
            return false
        signature := this.GetContentSignature(currentCandidate.NewPath)
        return signature.Available
            && signature.FileSize == currentCandidate.ContentSize
            && signature.ContentHash == currentCandidate.ContentHash
    }

    Complete(candidate) {
        if !IsObject(candidate) || !candidate.HasOwnProp("OldPath")
            return false
        oldPath := this.NormalizePath(candidate.OldPath)
        if !this.PendingCandidates.Has(oldPath)
            return false
        currentCandidate := this.PendingCandidates[oldPath]
        if currentCandidate.Token != candidate.Token
            return false
        this.PendingCandidates.Delete(oldPath)
        if this.Targets.Has(oldPath)
            this.RemoveTarget(oldPath, false)
        return true
    }

    Ignore(candidate) {
        if !IsObject(candidate) || !candidate.HasOwnProp("OldPath")
            return false
        oldPath := this.NormalizePath(candidate.OldPath)
        if !this.PendingCandidates.Has(oldPath)
            return false
        currentCandidate := this.PendingCandidates[oldPath]
        if currentCandidate.Token != candidate.Token
            return false
        this.IgnoredCandidates[currentCandidate.Signature] := this.Now()
            + TargetRelocationService.IgnoreCooldownMs
        this.PendingCandidates.Delete(oldPath)
        this.ReleaseState(currentCandidate)
        return true
    }

    Invalidate(candidate) {
        if !IsObject(candidate) || !candidate.HasOwnProp("OldPath")
            return false
        oldPath := this.NormalizePath(candidate.OldPath)
        if !this.PendingCandidates.Has(oldPath)
            return false
        currentCandidate := this.PendingCandidates[oldPath]
        if currentCandidate.Token != candidate.Token
            return false
        this.PendingCandidates.Delete(oldPath)
        this.ReleaseState(currentCandidate)
        this.NotifyInvalidated(currentCandidate)
        return true
    }

    RedeliverPending(*) {
        if this.Stopped
            return 0
        delivered := 0
        for _, candidate in this.PendingCandidates {
            if this.ValidateCandidate(candidate)
                && this.DeliverCandidate(candidate)
                delivered++
        }
        return delivered
    }

    RetryPendingDeliveries() {
        nowTicks := this.Now()
        delivered := 0
        for _, candidate in this.PendingCandidates {
            if !this.ValidateCandidate(candidate)
                continue
            if candidate.LastDeliveryTicks
                && nowTicks - candidate.LastDeliveryTicks
                    < TargetRelocationService.DeliveryRetryIntervalMs
                continue
            if this.DeliverCandidate(candidate)
                delivered++
        }
        return delivered
    }

    PollTick(*) {
        if this.Stopped || !this.Running
            return
        if !this.Runtime.guardWorkGate.TryEnter()
            return
        try {
            this.SyncTargets()
            invalidCandidates := []
            for _, candidate in this.PendingCandidates {
                if !this.ValidateCandidate(candidate)
                    invalidCandidates.Push(candidate)
            }
            for candidate in invalidCandidates
                this.Invalidate(candidate)
            this.RetryPendingDeliveries()
            this.PurgeExpiredState()
        } catch as pollError {
            this.Log(this.Text("守护目标内容迁移识别异常：{1}",
                this.DiagnosticText(pollError.Message)))
        } finally this.Runtime.guardWorkGate.Leave()
    }

    IsCandidatePathValid(oldPath, newPath) {
        if newPath == "" || this.PathsEquivalent(oldPath, newPath)
            || !this.TargetExists(newPath)
            || !this.ExtensionsCompatible(oldPath, newPath)
            || this.Runtime.appStates.Has(newPath)
            return false
        return this.Callbacks.FindConflict.Call(newPath, oldPath) == ""
    }

    IsMaintenanceBusy(path, stateObj) {
        return this.Callbacks.IsMaintenanceBlocking.Call(stateObj)
            || (this.Callbacks.IsMaintenanceProtectionEnabled.Call(path,
                    stateObj)
                && this.Callbacks.HasRecentMaintenanceSignal.Call(stateObj))
    }

    CandidateSignature(oldPath, newPath, contentHash) {
        return this.CanonicalPath(oldPath) "|" StrUpper(contentHash) "|"
            . this.CanonicalPath(newPath)
    }

    ClearIgnoredForPath(path) {
        prefix := this.CanonicalPath(path) "|"
        staleKeys := []
        for key in this.IgnoredCandidates {
            if InStr(key, prefix) == 1
                staleKeys.Push(key)
        }
        for key in staleKeys
            this.IgnoredCandidates.Delete(key)
    }

    PurgeExpiredState() {
        nowTicks := this.Now()
        expiredIgnores := []
        for key, expiresTicks in this.IgnoredCandidates {
            if expiresTicks <= nowTicks
                expiredIgnores.Push(key)
        }
        for key in expiredIgnores
            this.IgnoredCandidates.Delete(key)
    }

    ResetScanCycle(record, delayMs) {
        this.CancelScan(record)
        record.SearchRoots := []
        record.SearchRootIndex := 1
        record.ActiveRootIndex := 0
        record.MatchedPaths := []
        record.NextScanTicks := this.Now() + Max(0, delayMs)
    }

    NoteDiagnostic(record, key, message) {
        if !IsObject(record)
            return false
        nowTicks := this.Now()
        if record.HasOwnProp("LastDiagnosticKey")
            && record.LastDiagnosticKey == key
            && record.HasOwnProp("LastDiagnosticTicks")
            && nowTicks - record.LastDiagnosticTicks
                < TargetRelocationService.DiagnosticRepeatIntervalMs {
            return false
        }
        record.LastDiagnosticKey := key
        record.LastDiagnosticTicks := nowTicks
        this.Log(message)
        return true
    }

    DescribeSearchRoot(record, rootIndex) {
        try {
            if rootIndex >= 1 && rootIndex <= record.SearchRoots.Length
                return record.SearchRoots[rootIndex]
        }
        return this.Text("未知")
    }

    DescribeMatchedPaths(record) {
        if !IsObject(record) || !record.HasOwnProp("MatchedPaths")
            || !record.MatchedPaths.Length
            return this.Text("无")
        text := ""
        for index, matchedPath in record.MatchedPaths {
            if index > 3 {
                text .= this.Text("，另有 {1} 个", record.MatchedPaths.Length - 3)
                break
            }
            text .= (text == "" ? "" : "；") matchedPath
        }
        return text
    }

    AddMatchedPath(record, candidatePath) {
        candidatePath := this.NormalizePath(candidatePath)
        for existingPath in record.MatchedPaths {
            if this.PathsEquivalent(existingPath, candidatePath)
                return false
        }
        record.MatchedPaths.Push(candidatePath)
        return true
    }

    CancelScan(record) {
        if !IsObject(record) || !record.HasOwnProp("ScanJob")
            || !IsObject(record.ScanJob)
            return false
        try this.Callbacks.StopContentScan.Call(record.ScanJob)
        record.ScanJob := ""
        return true
    }

    ReleaseState(candidate) {
        stateObj := candidate.State
        if !this.IsCurrent(candidate.OldPath, stateObj)
            return false
        stateObj.RelocationPending := false
        this.Callbacks.ResetState.Call(candidate.OldPath, stateObj)
        return true
    }

    UpdatePendingState(candidate) {
        this.Callbacks.UpdateState.Call(candidate.OldPath,
            this.Text("等待确认目标新位置"), candidate.State,
            candidate.Generation, true, GuardStatusKind.RelocationPending)
    }

    DeliverCandidate(candidate) {
        candidate.LastDeliveryTicks := this.Now()
        try {
            deliveryResult := this.Callbacks.OnCandidate.Call(candidate)
            if Type(deliveryResult) == "Integer" && !deliveryResult {
                candidate.DeliveryFailures++
                this.Log(this.Text("守护目标内容迁移识别异常：{1}",
                    this.Text("确认窗口暂时无法显示，将稍后重试")))
                return false
            }
            candidate.DeliveryFailures := 0
            return true
        } catch as deliveryError {
            candidate.DeliveryFailures++
            this.Log(this.Text("守护目标内容迁移识别异常：{1}",
                this.DiagnosticText(deliveryError.Message)))
            return false
        }
    }

    PersistBaseline(path, stateObj) {
        if this.Callbacks.HasOwnProp("OnBaselineChanged")
            try this.Callbacks.OnBaselineChanged.Call(path, stateObj)
    }

    NotifyInvalidated(candidate) {
        try this.Callbacks.OnCandidateInvalidated.Call(candidate)
    }

    IsCurrent(path, stateObj) {
        return IsObject(stateObj) && this.Runtime.appStates.Has(path)
            && this.Runtime.appStates[path] == stateObj
    }

    IsContentHash(value) {
        return RegExMatch(String(value), "i)^[0-9a-f]{64}$") != 0
    }

    MetadataKey(signature) {
        return signature.FileSize "|" signature.ModifiedTime
    }

    GetContentMetadata(path) {
        try return this.Callbacks.GetContentMetadata.Call(path)
        catch
            return {Available: false, FileSize: 0, ModifiedTime: ""}
    }

    GetContentSignature(path) {
        try return this.Callbacks.GetContentSignature.Call(path)
        catch
            return {Available: false, FileSize: 0, ModifiedTime: "",
                ContentHash: ""}
    }

    GetSearchRoots(path) {
        try return this.Callbacks.GetSearchRoots.Call(path)
        catch
            return []
    }

    StartContentScan(rootPath, previousPath, expectedSize, expectedHash,
        useEverything, timeoutSeconds) {
        try return this.Callbacks.StartContentScan.Call(rootPath,
            previousPath, expectedSize, expectedHash, useEverything,
            timeoutSeconds)
        catch
            return ""
    }

    PollContentScan(job) {
        try return this.Callbacks.PollContentScan.Call(job)
        catch
            return {Ready: true, Paths: [], Truncated: false, Failed: true}
    }

    TargetExists(path) {
        try return !!this.Callbacks.TargetExists.Call(path)
        catch
            return false
    }

    NormalizePath(path) {
        return this.Callbacks.NormalizePath.Call(path)
    }

    CanonicalPath(path) {
        return this.Callbacks.CanonicalPath.Call(path)
    }

    PathsEquivalent(firstPath, secondPath) {
        return this.Callbacks.PathsEquivalent.Call(firstPath, secondPath)
    }

    Now() {
        return this.Callbacks.Now.Call()
    }

    Log(message) {
        try this.Callbacks.Log.Call(message)
    }

    Text(template, values*) {
        if this.Callbacks.HasOwnProp("Localize")
            && IsObject(this.Callbacks.Localize)
            return this.Callbacks.Localize.Call(template, values*)
        return values.Length ? Format(template, values*) : template
    }

    DiagnosticText(text) {
        if this.Callbacks.HasOwnProp("LocalizeDiagnostic")
            && IsObject(this.Callbacks.LocalizeDiagnostic)
            return this.Callbacks.LocalizeDiagnostic.Call(text)
        return text
    }
}
