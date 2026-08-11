#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

; 验证内容身份迁移的跨目录、跨磁盘、离线改名、歧义拒绝和投递重试状态机。

#Include ..\..\src\Core\GuardTypes.ahk
#Include ..\..\src\Core\TargetContentRelocationService.ahk

AssertContentRelocation(value, message) {
    if !value
        throw Error(message)
}

class ContentRelocationTestGate {
    TryEnter() => true
    Leave() {
    }
}

class ContentRelocationTestState {
    __New(contentHash, contentSize) {
        this.Enabled := true
        this.Generation := 1
        this.RelocationPending := false
        this.MaintenanceBusy := false
        this.MaintenanceFileChanged := false
        this.MaintenanceProtectionEnabled := false
        this.RecentMaintenanceSignal := false
        this.ContentHash := contentHash
        this.ContentSize := contentSize
        this.State := ""
        this.StatusKind := ""
        this.ResetCount := 0
    }

    CancelScheduledTasks(*) {
        this.Generation++
    }
}

class ContentRelocationTestHarness {
    __New() {
        this.Clock := 100
        this.Files := Map()
        this.Files.CaseSense := "Off"
        this.Signatures := Map()
        this.Signatures.CaseSense := "Off"
        this.SearchRoots := []
        this.ScanResults := Map()
        this.ScanResults.CaseSense := "Off"
        this.IncompleteScanRoots := Map()
        this.IncompleteScanRoots.CaseSense := "Off"
        this.StartedScans := []
        this.StoppedScans := 0
        this.Candidates := []
        this.Invalidated := []
        this.Logs := []
        this.BaselineSaves := 0
        this.ConflictTarget := ""
        this.ThrowCandidateDelivery := false
        this.Runtime := {appStates: Map(),
            guardWorkGate: ContentRelocationTestGate()}
        this.Runtime.appStates.CaseSense := "Off"
        this.Service := TargetRelocationService(this.Runtime, {
            CanonicalPath: ObjBindMethod(this, "CanonicalPath"),
            FindConflict: ObjBindMethod(this, "FindConflict"),
            GetContentMetadata: ObjBindMethod(this, "GetContentMetadata"),
            GetContentSignature: ObjBindMethod(this, "GetContentSignature"),
            GetSearchRoots: ObjBindMethod(this, "GetSearchRoots"),
            HasRecentMaintenanceSignal: ObjBindMethod(this,
                "HasRecentMaintenanceSignal"),
            IsMaintenanceBlocking: ObjBindMethod(this,
                "IsMaintenanceBlocking"),
            IsMaintenanceProtectionEnabled: ObjBindMethod(this,
                "IsMaintenanceProtectionEnabled"),
            Localize: ObjBindMethod(this, "Localize"),
            LocalizeDiagnostic: ObjBindMethod(this, "LocalizeDiagnostic"),
            Log: ObjBindMethod(this, "Log"),
            NormalizePath: ObjBindMethod(this, "NormalizePath"),
            Now: ObjBindMethod(this, "Now"),
            OnBaselineChanged: ObjBindMethod(this, "OnBaselineChanged"),
            OnCandidate: ObjBindMethod(this, "OnCandidate"),
            OnCandidateInvalidated: ObjBindMethod(this, "OnInvalidated"),
            PathsEquivalent: ObjBindMethod(this, "PathsEquivalent"),
            PollContentScan: ObjBindMethod(this, "PollContentScan"),
            ResetState: ObjBindMethod(this, "ResetState"),
            StartContentScan: ObjBindMethod(this, "StartContentScan"),
            StopContentScan: ObjBindMethod(this, "StopContentScan"),
            TargetExists: ObjBindMethod(this, "TargetExists"),
            UpdateState: ObjBindMethod(this, "UpdateState")
        })
    }

    AddTarget(path, contentHash, contentSize := 10, exists := true) {
        stateObj := ContentRelocationTestState(contentHash, contentSize)
        this.Runtime.appStates[path] := stateObj
        this.Files[path] := exists
        if exists
            this.Signatures[path] := this.CreateSignature(contentHash,
                contentSize, "20260101010101")
        return stateObj
    }

    AddCandidate(path, contentHash, contentSize := 10) {
        this.Files[path] := true
        this.Signatures[path] := this.CreateSignature(contentHash,
            contentSize, "20260102020202")
    }

    CreateSignature(contentHash, contentSize, modifiedTime) {
        return {Available: true, FileSize: contentSize,
            ModifiedTime: modifiedTime, ContentHash: contentHash}
    }

    NormalizePath(path) => StrReplace(Trim(String(path)), "/", "\")
    CanonicalPath(path) => StrLower(this.NormalizePath(path))
    PathsEquivalent(firstPath, secondPath) =>
        this.CanonicalPath(firstPath) == this.CanonicalPath(secondPath)
    TargetExists(path) => this.Files.Has(path) && this.Files[path]

    GetContentMetadata(path) {
        signature := this.GetContentSignature(path)
        return signature.Available
            ? {Available: true, FileSize: signature.FileSize,
                ModifiedTime: signature.ModifiedTime}
            : {Available: false, FileSize: 0, ModifiedTime: ""}
    }

    GetContentSignature(path) {
        if this.TargetExists(path) && this.Signatures.Has(path)
            return this.Signatures[path]
        return {Available: false, FileSize: 0, ModifiedTime: "",
            ContentHash: ""}
    }

    GetSearchRoots(*) => this.SearchRoots.Clone()

    StartContentScan(rootPath, previousPath, expectedSize, expectedHash,
        useEverything, timeoutSeconds) {
        job := {Root: rootPath, PreviousPath: previousPath,
            ExpectedSize: expectedSize, ExpectedHash: expectedHash,
            UseEverything: useEverything, TimeoutSeconds: timeoutSeconds,
            Stopped: false}
        this.StartedScans.Push(job)
        return job
    }

    PollContentScan(job) {
        paths := this.ScanResults.Has(job.Root)
            ? this.ScanResults[job.Root].Clone() : []
        truncated := this.IncompleteScanRoots.Has(job.Root)
        return {Ready: true, Paths: paths, Truncated: truncated,
            Failed: false}
    }

    StopContentScan(job) {
        job.Stopped := true
        this.StoppedScans++
        return true
    }

    FindConflict(*) => this.ConflictTarget
    IsMaintenanceBlocking(stateObj) => stateObj.MaintenanceBusy
    IsMaintenanceProtectionEnabled(path, stateObj) =>
        stateObj.MaintenanceProtectionEnabled
    HasRecentMaintenanceSignal(stateObj) =>
        stateObj.RecentMaintenanceSignal

    UpdateState(path, statusText, stateObj, generation,
        forceProjection, statusKind) {
        if stateObj.Generation != generation
            return false
        stateObj.State := statusText
        stateObj.StatusKind := statusKind
        return true
    }

    ResetState(path, stateObj) {
        stateObj.RelocationPending := false
        stateObj.ResetCount++
        return true
    }

    OnCandidate(candidate) {
        if this.ThrowCandidateDelivery
            throw Error("模拟确认窗口投递失败")
        this.Candidates.Push(candidate)
        return true
    }

    OnInvalidated(candidate) => this.Invalidated.Push(candidate)
    OnBaselineChanged(*) => this.BaselineSaves++
    Now() => this.Clock
    Advance(milliseconds) => this.Clock += milliseconds
    Localize(template, values*) =>
        values.Length ? Format(template, values*) : template
    LocalizeDiagnostic(text) => text
    Log(message) => this.Logs.Push(message)
}

DetectContentRelocation(harness, oldPath, stateObj) {
    AssertContentRelocation(!harness.Service.TryDetect(oldPath, stateObj),
        "首次缺失观察跳过了稳定延迟")
    harness.Advance(TargetRelocationService.CandidateDelayMs + 1)
    AssertContentRelocation(!harness.Service.TryDetect(oldPath, stateObj)
        && harness.StartedScans.Length == 1,
        "稳定延迟后没有启动后台内容扫描")
    return harness.Service.TryDetect(oldPath, stateObj)
}

CreateContentRelocationTestDirectory(rootPath, directoryName) {
    directoryPath := rootPath "\" directoryName
    DirCreate(directoryPath)
    ; GitHub runner 的 A_Temp 可能是 8.3 短路径，而目录枚举会返回长路径。
    ; 测试夹具必须采用与生产扫描相同的路径表示，避免 Map 模拟产生假阴性。
    Loop Files, rootPath "\*", "D" {
        if A_LoopFileName == directoryName
            return A_LoopFileFullPath
    }
    throw Error("无法解析测试版本目录的规范路径：" directoryPath)
}

RunTargetContentRelocationServiceTests() {
    hashA := "A" . Format("{:063}", 0)
    hashB := "B" . Format("{:063}", 0)

    renameHarness := ContentRelocationTestHarness()
    oldPath := "C:\Scripts\Bandicam窗口管理.ahk"
    renamedPath := "C:\Scripts\完全不同的文件名.ahk"
    renameState := renameHarness.AddTarget(oldPath, hashA, 128)
    renameHarness.Service.SyncTargets()
    renameHarness.Files[oldPath] := false
    renameHarness.AddCandidate(renamedPath, hashA, 128)
    renameHarness.SearchRoots := ["C:\Scripts"]
    renameHarness.ScanResults["C:\Scripts"] := [renamedPath]
    AssertContentRelocation(DetectContentRelocation(renameHarness, oldPath,
            renameState)
            && renameHarness.Candidates.Length == 1
            && renameHarness.StartedScans.Length == 1
            && !renameHarness.StartedScans[1].UseEverything
            && renameHarness.Candidates[1].Evidence == "ContentHash"
            && renameHarness.Candidates[1].NewPath == renamedPath
            && renameHarness.Service.ValidateCandidate(
                renameHarness.Candidates[1]),
        "文件本身改名后没有按内容身份识别")

    AssertContentRelocation(renameHarness.Service.Ignore(
            renameHarness.Candidates[1])
            && !renameState.RelocationPending
            && renameState.ResetCount == 1,
        "忽略内容候选没有释放控制器")

    AssertContentRelocation(
        TargetRelocationService.IsVersionedInstallDirectory("app-1.2.3")
            && TargetRelocationService.IsVersionedInstallDirectory("v2.0.0-beta.1")
            && !TargetRelocationService.IsVersionedInstallDirectory("release"),
        "版本目录名称识别规则错误")

    testRunId := DllCall("kernel32\GetCurrentProcessId", "UInt")
        . "-" A_TickCount
    versionRoot := A_Temp "\watchdog-version-relocation-" testRunId
    versionOldDir := CreateContentRelocationTestDirectory(versionRoot,
        "app-1.0.0")
    versionNewDir := CreateContentRelocationTestDirectory(versionRoot,
        "app-1.1.0")
    versionOld := versionOldDir "\Product.exe"
    versionNew := versionNewDir "\Product.exe"
    versionHarness := ContentRelocationTestHarness()
    versionState := versionHarness.AddTarget(versionOld, hashA, 128)
    versionHarness.Service.SyncTargets()
    versionHarness.Files[versionOld] := false
    versionHarness.AddCandidate(versionNew, hashB, 256)
    AssertContentRelocation(!versionHarness.Service.TryDetect(versionOld,
            versionState), "版本目录迁移首次缺失观察没有等待稳定延迟")
    versionHarness.Advance(TargetRelocationService.CandidateDelayMs + 1)
    versionPublished := versionHarness.Service.TryDetect(versionOld,
        versionState)
    versionValid := versionHarness.Candidates.Length == 1
        ? versionHarness.Service.ValidateCandidate(
            versionHarness.Candidates[1]) : false
    AssertContentRelocation(versionPublished
            && versionHarness.Candidates.Length == 1
            && versionHarness.Candidates[1].Evidence
                == "VersionedEntryUnique"
            && versionHarness.Candidates[1].NewContentHash == hashB
            && versionHarness.Candidates[1].NewContentSize == 256
            && versionHarness.Logs.Length
            && InStr(versionHarness.Logs[-1], "唯一同名新版本入口")
            && versionValid,
        "版本目录中唯一同名新入口没有进入确认迁移流程"
            "（published=" versionPublished
            "，count=" versionHarness.Candidates.Length
            "，valid=" versionValid
            "，logs=" (versionHarness.Logs.Length
                ? versionHarness.Logs[-1] : "") "）")
    versionHarness.Signatures[versionNew] := versionHarness.CreateSignature(
        hashA, 256, "20260103030303")
    AssertContentRelocation(!versionHarness.Service.ValidateCandidate(
            versionHarness.Candidates[1]),
        "确认期间被替换的版本目录候选仍被视为有效")

    liveVersionRoot := A_Temp "\watchdog-version-live-" testRunId
    liveOldDir := CreateContentRelocationTestDirectory(liveVersionRoot,
        "app-2.0.0")
    liveNewDir := CreateContentRelocationTestDirectory(liveVersionRoot,
        "app-2.1.0")
    liveOld := liveOldDir "\Product.exe"
    liveNew := liveNewDir "\Product.exe"
    liveVersionHarness := ContentRelocationTestHarness()
    liveVersionState := liveVersionHarness.AddTarget(liveOld, hashA, 128)
    liveVersionState.MaintenanceBusy := true
    liveVersionState.MaintenanceFileChanged := true
    liveVersionHarness.Service.SyncTargets()
    liveVersionHarness.AddCandidate(liveNew, hashB, 256)
    AssertContentRelocation(!liveVersionHarness.Service
            .TryDetectVersionedUpgrade(liveOld, liveVersionState),
        "旧版本仍存在时的首次版本候选观察没有等待稳定延迟")
    liveVersionHarness.Advance(TargetRelocationService.CandidateDelayMs + 1)
    AssertContentRelocation(liveVersionHarness.Service
            .TryDetectVersionedUpgrade(liveOld, liveVersionState)
            && liveVersionHarness.Candidates.Length == 1
            && liveVersionHarness.Service.ValidateCandidate(
                liveVersionHarness.Candidates[1]),
        "旧版本入口仍存在时没有发布唯一新版本确认候选")

    ambiguousRoot := A_Temp "\watchdog-version-ambiguous-" testRunId
    ambiguousOldDir := CreateContentRelocationTestDirectory(ambiguousRoot,
        "app-1.0.0")
    ambiguousNewOneDir := CreateContentRelocationTestDirectory(ambiguousRoot,
        "app-1.1.0")
    ambiguousNewTwoDir := CreateContentRelocationTestDirectory(ambiguousRoot,
        "app-1.2.0")
    ambiguousOld := ambiguousOldDir "\Product.exe"
    ambiguousOne := ambiguousNewOneDir "\Product.exe"
    ambiguousTwo := ambiguousNewTwoDir "\Product.exe"
    ambiguousHarness := ContentRelocationTestHarness()
    ambiguousState := ambiguousHarness.AddTarget(ambiguousOld, hashA, 128)
    ambiguousHarness.Service.SyncTargets()
    ambiguousHarness.Files[ambiguousOld] := false
    ambiguousHarness.AddCandidate(ambiguousOne, hashB, 256)
    ambiguousHarness.AddCandidate(ambiguousTwo, hashB, 256)
    AssertContentRelocation(!ambiguousHarness.Service.TryDetect(ambiguousOld,
            ambiguousState), "多个版本目录首次缺失观察没有等待稳定延迟")
    ambiguousHarness.Advance(TargetRelocationService.CandidateDelayMs + 1)
    AssertContentRelocation(!ambiguousHarness.Service.TryDetect(ambiguousOld,
            ambiguousState)
            && ambiguousHarness.Candidates.Length == 0
            && ambiguousHarness.Logs.Length
            && InStr(ambiguousHarness.Logs[-1], "多个版本目录"),
        "多个同名版本入口没有暂停自动迁移")
    try DirDelete(versionRoot, true)
    try DirDelete(liveVersionRoot, true)
    try DirDelete(ambiguousRoot, true)

    directoryHarness := ContentRelocationTestHarness()
    directoryOld := "D:\Projects\Windows\后台常驻\worker.ahk"
    directoryNew := "D:\Projects\AHK\后台常驻\worker.ahk"
    directoryState := directoryHarness.AddTarget(directoryOld, hashA, 64)
    directoryHarness.Service.SyncTargets()
    directoryHarness.Files[directoryOld] := false
    directoryHarness.AddCandidate(directoryNew, hashA, 64)
    directoryHarness.SearchRoots := ["D:\Projects"]
    directoryHarness.ScanResults["D:\Projects"] := [directoryNew]
    AssertContentRelocation(DetectContentRelocation(directoryHarness,
            directoryOld, directoryState)
            && directoryHarness.Candidates[1].NewPath == directoryNew,
        "父目录整体改名后没有找回内容相同的脚本")

    restartHarness := ContentRelocationTestHarness()
    restartOld := "C:\Old\offline.py"
    restartNew := "E:\Moved\offline-renamed.py"
    restartState := restartHarness.AddTarget(restartOld, hashA, 32, false)
    restartHarness.AddCandidate(restartNew, hashA, 32)
    restartHarness.SearchRoots := ["C:\", "E:\"]
    restartHarness.ScanResults["C:\"] := []
    restartHarness.ScanResults["E:\"] := [restartNew]
    restartHarness.Service.SyncTargets()
    AssertContentRelocation(!restartHarness.Service.TryDetect(restartOld,
        restartState), "离线迁移首次观察跳过了稳定延迟")
    restartHarness.Advance(TargetRelocationService.CandidateDelayMs + 1)
    restartHarness.Service.TryDetect(restartOld, restartState)
    restartHarness.Service.TryDetect(restartOld, restartState)
    restartHarness.Service.TryDetect(restartOld, restartState)
    AssertContentRelocation(restartHarness.Candidates.Length == 1
            && restartHarness.Candidates[1].NewPath == restartNew
            && restartHarness.StartedScans.Length == 2
            && !restartHarness.StartedScans[1].UseEverything
            && restartHarness.StartedScans[2].UseEverything,
        "关闭期间跨盘并改名后没有使用已保存内容身份迁移")

    changedHarness := ContentRelocationTestHarness()
    changedState := changedHarness.AddTarget(oldPath, hashA, 128)
    changedHarness.Service.SyncTargets()
    changedHarness.Files[oldPath] := false
    changedHarness.AddCandidate(renamedPath, hashB, 128)
    changedHarness.SearchRoots := ["C:\Scripts"]
    changedHarness.ScanResults["C:\Scripts"] := [renamedPath]
    AssertContentRelocation(!DetectContentRelocation(changedHarness,
            oldPath, changedState)
            && changedHarness.Candidates.Length == 0,
        "内容已经变化的同尺寸文件被错误迁移")

    duplicateHarness := ContentRelocationTestHarness()
    duplicateState := duplicateHarness.AddTarget(oldPath, hashA, 128)
    duplicateHarness.Service.SyncTargets()
    duplicateHarness.Files[oldPath] := false
    duplicateOne := "C:\Scripts\copy-one.ahk"
    duplicateTwo := "C:\Scripts\copy-two.ahk"
    duplicateHarness.AddCandidate(duplicateOne, hashA, 128)
    duplicateHarness.AddCandidate(duplicateTwo, hashA, 128)
    duplicateHarness.SearchRoots := ["C:\Scripts"]
    duplicateHarness.ScanResults["C:\Scripts"] := [duplicateOne,
        duplicateTwo]
    AssertContentRelocation(!DetectContentRelocation(duplicateHarness,
            oldPath, duplicateState)
            && duplicateHarness.Candidates.Length == 0
            && duplicateHarness.Logs.Length
            && InStr(duplicateHarness.Logs[-1], "多个内容完全相同"),
        "多个完全相同副本没有阻止不确定迁移")

    nearestRootHarness := ContentRelocationTestHarness()
    nearestRootState := nearestRootHarness.AddTarget(oldPath,
        hashA, 128)
    nearestRootHarness.Service.SyncTargets()
    nearestRootHarness.Files[oldPath] := false
    crossRootOne := "C:\Scripts\copy.ahk"
    crossRootTwo := "E:\Archive\renamed-copy.ahk"
    nearestRootHarness.AddCandidate(crossRootOne, hashA, 128)
    nearestRootHarness.AddCandidate(crossRootTwo, hashA, 128)
    nearestRootHarness.SearchRoots := ["C:\Scripts", "E:\"]
    nearestRootHarness.ScanResults["C:\Scripts"] := [crossRootOne]
    nearestRootHarness.ScanResults["E:\"] := [crossRootTwo]
    AssertContentRelocation(DetectContentRelocation(nearestRootHarness,
            oldPath, nearestRootState)
            && nearestRootHarness.Candidates.Length == 1
            && nearestRootHarness.Candidates[1].NewPath == crossRootOne
            && nearestRootHarness.StartedScans.Length == 1
            && !nearestRootHarness.StartedScans[1].UseEverything,
        "最近有效目录中的唯一内容候选没有优先于远端相同副本")

    incompleteHarness := ContentRelocationTestHarness()
    incompleteState := incompleteHarness.AddTarget(oldPath, hashA, 128)
    incompleteHarness.Service.SyncTargets()
    incompleteHarness.Files[oldPath] := false
    incompleteHarness.AddCandidate(renamedPath, hashA, 128)
    incompleteHarness.SearchRoots := ["C:\Scripts"]
    incompleteHarness.ScanResults["C:\Scripts"] := [renamedPath]
    incompleteHarness.IncompleteScanRoots["C:\Scripts"] := true
    AssertContentRelocation(!DetectContentRelocation(incompleteHarness,
            oldPath, incompleteState)
            && incompleteHarness.Candidates.Length == 0,
        "未完整扫描搜索根时错误发布了迁移候选")

    baselineHarness := ContentRelocationTestHarness()
    baselineState := baselineHarness.AddTarget(oldPath, hashA, 128)
    baselineHarness.Service.SyncTargets()
    baselineHarness.Signatures[oldPath] := baselineHarness.CreateSignature(
        hashB, 256, "20260202020202")
    baselineHarness.Advance(
        TargetRelocationService.BaselineRefreshIntervalMs + 1)
    AssertContentRelocation(baselineHarness.Service.ObserveAvailable(oldPath,
            baselineState)
            && baselineState.ContentHash == hashB
            && baselineState.ContentSize == 256
            && baselineHarness.BaselineSaves == 1,
        "原路径内容变化后没有刷新并持久化内容基线")

    maintenanceHarness := ContentRelocationTestHarness()
    maintenanceState := maintenanceHarness.AddTarget(oldPath, hashA, 128)
    maintenanceState.MaintenanceProtectionEnabled := true
    maintenanceState.RecentMaintenanceSignal := true
    maintenanceHarness.Service.SyncTargets()
    AssertContentRelocation(
        maintenanceHarness.Service.IsMaintenanceBusy(oldPath,
            maintenanceState)
            && !maintenanceHarness.Service.ObserveAvailable(oldPath,
                maintenanceState, true),
        "升级保护近期信号检查的回调参数契约错误")

    deliveryHarness := ContentRelocationTestHarness()
    deliveryState := deliveryHarness.AddTarget(oldPath, hashA, 128)
    deliveryHarness.Service.SyncTargets()
    deliveryHarness.Files[oldPath] := false
    deliveryHarness.AddCandidate(renamedPath, hashA, 128)
    deliveryHarness.SearchRoots := ["C:\Scripts"]
    deliveryHarness.ScanResults["C:\Scripts"] := [renamedPath]
    deliveryHarness.ThrowCandidateDelivery := true
    AssertContentRelocation(DetectContentRelocation(deliveryHarness,
            oldPath, deliveryState)
            && deliveryState.RelocationPending
            && deliveryHarness.Candidates.Length == 0,
        "确认窗口投递失败后没有保留内容候选")
    deliveryHarness.ThrowCandidateDelivery := false
    deliveryHarness.Advance(
        TargetRelocationService.DeliveryRetryIntervalMs + 1)
    AssertContentRelocation(
        deliveryHarness.Service.RetryPendingDeliveries() == 1
            && deliveryHarness.Candidates.Length == 1,
        "确认窗口恢复后没有重新投递内容候选")
}

try {
    RunTargetContentRelocationServiceTests()
    ExitApp(0)
} catch as testError {
    try FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
