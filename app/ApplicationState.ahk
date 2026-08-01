; 应用级根状态与依赖装配入口。
; 这里集中持有配置、守护、升级保护、进程检查和界面资源服务，避免业务模块
; 通过零散全局变量找回依赖；关闭时也能沿同一所有权关系释放后台任务和原生资源。

class ApplicationState {
    __New() {
        this.mutexHandle := 0
        this.configRepository := WatchdogConfigRepository(
            A_ScriptDir "\watchdog.ini", "", Tr,
            LocalizationService.GetAllTranslationCatalogs())
        this.runtimeSettingsService := RuntimeSettingsService(
            this.configRepository, ParseRetrySequence,
            A_Temp "\ProcessWatchdogLogs")
        this.windowLayoutService := WindowLayoutService(this.configRepository)
        this.maintenanceJournalPath := A_ScriptDir "\watchdog.maintenance.ini"
        this.uiLanguage := LocalizationService.GetRequestedLanguage()
        this.uiFont := LocalizationService.GetRequestedUiFont()
        this.uiTheme := UiThemeService.GetRequestedTheme()
        this.checkInterval := 2000
        this.retrySequence := "1, 10, 60"
        this.retryDelayArray := []
        this.showAtStartup := false
        this.checkUpdatesOnStartup := true
        this.recursiveBatchImport := true
        this.logMaxEntries := 500
        this.logDirectory := A_Temp "\ProcessWatchdogLogs"
        this.logRetentionDays := 30
        this.clearLogsOnStartup := false
        this.gracefulStopSeconds := 3
        this.ctrlCWaitSeconds := 2
        this.allowForceTerminate := true
        this.applicationUpdateService := ApplicationUpdateService({
            Repository: "realSilasYang/process-watchdog",
            CurrentVersion: ReadApplicationVersion(),
            HelperPath: A_ScriptDir "\runtime\application-update.ps1",
            HelperLocalizationPath: A_ScriptDir
                "\runtime\application-update.strings.json",
            InstallRoot: A_ScriptDir,
            EntryPath: A_ScriptFullPath,
            InterpreterPath: A_AhkPath,
            Compiled: A_IsCompiled,
            UiLanguage: LocalizationService.GetLanguage(),
            Log: LogMsg,
            Localize: Tr,
            OnResult: HandleApplicationUpdateCheckResult,
            Now: GetTickCount64,
            Quote: QuoteCommandLineArgument
        })
        this.maintenancePollInterval := 1000
        this.maintenanceProcessInterval := 1000
        this.maintenanceFingerprintInterval := 30000
        this.maintenanceFingerprintRetryInterval := 5000
        this.guardWorkGate := GuardWorkGate()
        this.guardMutationQueue := GuardMutationQueue(this.guardWorkGate,
            HandleGuardMutationError)
        this.appStates := Map()
        this.appStates.CaseSense := "Off"
        this.scheduler := WatchdogScheduler("", true, "")
        this.targetLauncher := TargetLauncher()
        this.processInspector := ProcessInspector()
        this.targetStopper := TargetStopper(ObjBindMethod(
            this.processInspector, "GetCreationIdentity"))
        this.fileScanner := FileScanService({
            CanonicalPath: GetCanonicalPath,
            ComputeContentHash: ObjBindMethod(TargetFileInspector,
                "ComputeContentHash"),
            GetCreationIdentity: ObjBindMethod(this.processInspector,
                "GetCreationIdentity"),
            Localize: Tr,
            LocalizeDiagnostic: TrDiagnostic,
            Log: LogMsg,
            Now: GetTickCount64
        }, {
            ScriptPath: A_ScriptFullPath,
            ScriptDirectory: A_ScriptDir,
            InterpreterPath: A_AhkPath,
            Compiled: A_IsCompiled,
            ScriptWindow: A_ScriptHwnd,
            TempDirectory: A_Temp
        })
        this.processSnapshots := ProcessSnapshotService(
            ObjBindMethod(this.processInspector, "GetCreationIdentity"),
            CreateProcessSnapshotIndex, "",
            ObjBindMethod(IniFieldCodec, "Encode"),
            ObjBindMethod(IniFieldCodec, "Decode"), LogMsg)
        this.processSnapshots.Localizer := Tr
        this.processSnapshots.DiagnosticLocalizer := TrDiagnostic
        this.maintenanceActorMatcher := MaintenanceActorMatcher(
            ObjBindMethod(this.processInspector, "GetCreationIdentity"))
        this.displayConfigCodec := DisplayConfigCodec(NormalizeTargetPath,
            PathsEquivalent)
        this.maintenanceConfigCodec := MaintenanceConfigCodec({
            GetDefaultRoot: GetDefaultMaintenanceRoot,
            IsSupportedTarget: IsMaintenanceSupportedTarget,
            NormalizeRoot: NormalizeMaintenanceRoot,
            ParseBoundedInteger: ParseBoundedInteger,
            PathsEquivalent: PathsEquivalent
        }, this.maintenanceActorMatcher)
        this.appConfigSnapshotService := AppConfigSnapshotService(
            this.maintenanceConfigCodec, this.displayConfigCodec,
            NormalizeTargetPath, PathsEquivalent)
        this.appConfigHistoryService := AppConfigHistoryService(
            this.appConfigSnapshotService, 20)
        this.watchlistPersistenceService := WatchlistPersistenceService(
            this.configRepository, IniFieldCodec, this.maintenanceConfigCodec,
            this.displayConfigCodec, this.appConfigSnapshotService)
        this.maintenanceSessionCodec := MaintenanceSessionCodec()
        this.targetIdentityService := TargetIdentityService(this, {
            InvalidateRuntimeIdentity: InvalidateShortcutRuntimeIdentity,
            Localize: Tr,
            Log: LogMsg,
            NormalizeRoot: NormalizeMaintenanceRoot,
            Now: GetTickCount64,
            PathsEquivalent: PathsEquivalent
        })
        this.targetFileInspector := TargetFileInspector({
            CanonicalPath: GetCanonicalPath,
            GetSubjectPath: ObjBindMethod(this.targetIdentityService,
                "GetMaintenanceSubjectPath"),
            IsSupportedTarget: IsMaintenanceSupportedTarget
        })
        this.shortcutTargetResolver := ShortcutTargetResolver(
            this.processSnapshots, {
                CanonicalPath: GetCanonicalPath,
                GetFileFingerprint: ObjBindMethod(this.targetFileInspector,
                    "GetFingerprint"),
                NormalizeTargetPath: NormalizeTargetPath,
                ReadShortcut: ObjBindMethod(ShortcutResolver, "Read")
            })
        this.targetSpecsService := TargetSpecsService(
            this.shortcutTargetResolver, NormalizeTargetPath)
        this.targetProbe := TargetProbe(
            ObjBindMethod(this.processSnapshots, "GetIndex"),
            ObjBindMethod(this.processInspector, "CaptureNativeSnapshot"),
            ObjBindMethod(this.processInspector, "GetImagePath"),
            ObjBindMethod(this.processInspector, "GetCreationIdentity"),
            GetCanonicalPath,
            ObjBindMethod(this.processInspector,
                "CaptureAutoHotkeyScriptSnapshot"))
        this.maintenanceCoordinator := MaintenanceCoordinator(this, {
            CanonicalPath: GetCanonicalPath,
            ClearProcessIdentity: ClearStateProcessIdentity,
            DeserializeSession: ObjBindMethod(this.maintenanceSessionCodec,
                "Deserialize"),
            GetFingerprint: ObjBindMethod(this.targetFileInspector,
                "GetFingerprint"),
            GetMaintenanceSubjectPath: ObjBindMethod(
                this.targetIdentityService, "GetMaintenanceSubjectPath"),
            HashPath: HashPath,
            IsSupportedTarget: IsMaintenanceSupportedTarget,
            IsTargetFileReady: ObjBindMethod(this.targetFileInspector,
                "IsReady"),
            Localize: Tr,
            LocalizeDiagnostic: TrDiagnostic,
            Log: LogMsg,
            LogSlow: LogSlowBackgroundOperation,
            NormalizeRoot: NormalizeMaintenanceRoot,
            NormalizeTargetPath: NormalizeTargetPath,
            ObserveTarget: ObserveTarget,
            RefreshShortcutIdentity: ObjBindMethod(
                this.targetIdentityService, "RefreshShortcut"),
            SaveApps: SaveAppsToIni,
            SerializeSession: ObjBindMethod(this.maintenanceSessionCodec,
                "Serialize"),
            ScheduleRestart: "",
            SetProcessIdentity: SetStateProcessIdentity,
            TargetReferenceExists: ObjBindMethod(this.targetIdentityService,
                "TargetReferenceExists"),
            TargetSubjectExists: ObjBindMethod(this.targetIdentityService,
                "TargetSubjectExists"),
            UpdateRunningState: UpdateRunningState,
            UpdateState: UpdateState,
            WatcherFactory: DirectoryChangeWatcher
        })
        this.targetRelocationService := TargetRelocationService(this, {
            CanonicalPath: GetCanonicalPath,
            FindConflict: ObjBindMethod(this.targetIdentityService,
                "FindConflict"),
            GetContentMetadata: ObjBindMethod(this.targetFileInspector,
                "GetContentMetadata"),
            GetContentSignature: ObjBindMethod(this.targetFileInspector,
                "GetContentSignature"),
            GetSearchRoots: ObjBindMethod(this.targetFileInspector,
                "GetRelocationSearchRoots"),
            HasRecentMaintenanceSignal: ObjBindMethod(
                this.maintenanceCoordinator, "HasRecentSignal"),
            IsMaintenanceBlocking: ObjBindMethod(
                this.maintenanceCoordinator, "IsBlocking"),
            IsMaintenanceProtectionEnabled: ObjBindMethod(
                this.maintenanceCoordinator, "IsProtectionEnabled"),
            Localize: Tr,
            LocalizeDiagnostic: TrDiagnostic,
            Log: LogMsg,
            NormalizePath: NormalizeTargetPath,
            Now: GetTickCount64,
            OnBaselineChanged: (path, stateObj) => SaveAppsToIni(),
            OnCandidate: QueueTargetRelocationPrompt,
            OnCandidateInvalidated: InvalidateTargetRelocationPrompt,
            PathsEquivalent: PathsEquivalent,
            PollContentScan: ObjBindMethod(this.fileScanner,
                "PollContentMatch"),
            ResetState: ResetTargetRelocationState,
            StartContentScan: ObjBindMethod(this.fileScanner,
                "StartContentMatch"),
            StopContentScan: ObjBindMethod(this.fileScanner,
                "StopContentMatch"),
            TargetExists: (path) => !!FileExist(path) && !DirExist(path),
            UpdateState: UpdateState
        })
        this.guardRuntime := GuardRuntime(this, {
            ClearProcessIdentity: ClearStateProcessIdentity,
            GetLogFilePath: GetLogFilePath,
            GetTargetSpecs: ObjBindMethod(this.targetSpecsService, "Get"),
            Localize: Tr,
            LocalizeDiagnostic: TrDiagnostic,
            Log: LogMsg,
            LogSlow: LogSlowBackgroundOperation,
            NormalizeTargetPath: NormalizeTargetPath,
            ObserveTarget: ObserveTarget,
            RefreshShortcutIdentity: ObjBindMethod(
                this.targetIdentityService, "RefreshShortcut"),
            SaveApps: SaveAppsToIni,
            SetProcessIdentity: SetStateProcessIdentity,
            StateProcessIdentityIsValid: StateProcessIdentityIsValid,
            TargetReferenceExists: ObjBindMethod(this.targetIdentityService,
                "TargetReferenceExists"),
            UpdateRunningState: UpdateRunningState,
            UpdateState: UpdateState
        })
        this.scheduler.ErrorHandler := ObjBindMethod(this.guardRuntime,
            "HandleTaskError")
        this.maintenanceCoordinator.Callbacks.ScheduleRestart := ObjBindMethod(
            this.guardRuntime, "ScheduleRestartFor")
        this.processSnapshots.SnapshotPublishedCallback := ObjBindMethod(
            this, "OnProcessSnapshotPublished")
        this.pendingProcessSnapshot := ""
        this.pendingProcessSnapshotIndex := ""
        this.processSnapshotDeliveryTimer := ObjBindMethod(this,
            "DeliverPendingProcessSnapshot")
        this.appOrder := []
        this.configLoadWarnings := []
        this.configRecoveryEntries := []
        this.appsDirty := false
        this.appConfigSaveRevision := 0
        this.appConfigPersistedRevision := 0
        this.appConfigSaveInProgress := false
        this.lastSaveWarningTicks := 0
        this.configSaveRetryDelayMs := 5000
        this.configSaveRetryTimer := ObjBindMethod(this,
            "RetryDirtyAppConfig")
        this.logMessages := []
        this.logRevision := 0
        this.diagnosticBundleService := DiagnosticBundleService(
            ReadApplicationVersion(), {
                State: BuildDiagnosticStateSummary,
                Logs: GetLogText
            }, [
                A_ScriptDir "\VERSION",
                A_ScriptDir "\third_party\dependencies.lock.json",
                A_ScriptDir "\third_party\resvg\VERSION.txt",
                A_ScriptDir "\third_party\everything\VERSION.txt"
            ], "", Tr, TrDiagnostic)
        this.iconResources := IconResourceRegistry()
        this.svgRenderer := SvgRenderLibrary(
            GetApplicationRootFilePath("third_party\resvg\resvg.dll"))
        this.uiInteractions := UiInteractionRegistry()
        this.reloadInProgress := false
        this.shutdownStarted := false
        this.shutdownCompleted := false
        this.isReloadedMode := false
        this.editMonitorItem := 0
        this.activeInlineEditHwnd := 0
        this.batchEditRows := []
        this.editSessionId := 0
        this.savedWidth := 730
        this.savedHeight := 520
        this.savedColumn1 := 500
        this.savedColumn2 := 200
        this.batchImportMaxResults := 2000
    }

    OnProcessSnapshotPublished(snapshot, snapshotIndex) {
        if this.shutdownStarted
            return false
        previousCritical := A_IsCritical
        Critical("On")
        try {
            this.pendingProcessSnapshot := snapshot
            this.pendingProcessSnapshotIndex := snapshotIndex
        } finally {
            Critical(previousCritical ? previousCritical : "Off")
        }
        return this.DeliverPendingProcessSnapshot()
    }

    DeliverPendingProcessSnapshot(*) {
        if this.shutdownStarted {
            this.ClearPendingProcessSnapshot()
            return false
        }
        if !this.guardWorkGate.TryEnter() {
            try SetTimer(this.processSnapshotDeliveryTimer, -25)
            return false
        }
        snapshot := ""
        snapshotIndex := ""
        maintenanceAccepted := false
        guardAccepted := false
        try {
            previousCritical := A_IsCritical
            Critical("On")
            try {
                snapshot := this.pendingProcessSnapshot
                snapshotIndex := this.pendingProcessSnapshotIndex
                this.pendingProcessSnapshot := ""
                this.pendingProcessSnapshotIndex := ""
                try SetTimer(this.processSnapshotDeliveryTimer, 0)
            } finally {
                Critical(previousCritical ? previousCritical : "Off")
            }
            if Type(snapshot) != "Array"
                || !(snapshotIndex is ProcessSnapshotIndex) {
                return false
            }
            try {
            maintenanceAccepted := this.maintenanceCoordinator
                .OnSnapshotPublished(snapshot, snapshotIndex)
            } catch as maintenanceError {
                LogMsg(Tr("处理后台进程快照时发生错误：{1}",
                    TrDiagnostic(maintenanceError.Message)))
            }
            try {
            guardAccepted := this.guardRuntime.OnSnapshotPublished(
                snapshot, snapshotIndex)
            } catch as guardError {
                LogMsg(Tr("处理后台进程快照时发生错误：{1}",
                    TrDiagnostic(guardError.Message)))
            }
        } finally {
            this.guardWorkGate.Leave()
            if Type(this.pendingProcessSnapshot) == "Array"
                try SetTimer(this.processSnapshotDeliveryTimer, -1)
        }
        return maintenanceAccepted || guardAccepted
    }

    ClearPendingProcessSnapshot() {
        try SetTimer(this.processSnapshotDeliveryTimer, 0)
        this.pendingProcessSnapshot := ""
        this.pendingProcessSnapshotIndex := ""
    }

    RetryDirtyAppConfig(*) {
        if !this.appsDirty
            return
        if !this.guardWorkGate.TryEnter() {
            this.guardMutationQueue.Enqueue(SaveAppsToIni.Bind(false))
            return
        }
        try SaveAppsToIni(false)
        finally this.guardWorkGate.Leave()
    }

    SetConfigRepository(repository) {
        if !IsObject(repository)
            throw TypeError(Tr("配置仓储无效"))
        this.configRepository := repository
        for serviceName in ["runtimeSettingsService", "windowLayoutService",
            "watchlistPersistenceService"] {
            if this.HasOwnProp(serviceName)
                this.%serviceName%.Repository := repository
        }
        return repository
    }
}
