; Root application state and service composition.

class ApplicationState {
    __New() {
        this.mutexHandle := 0
        this.configRepository := WatchdogConfigRepository(
            A_ScriptDir "\watchdog.ini")
        this.runtimeSettingsService := RuntimeSettingsService(
            this.configRepository, ParseRetrySequence,
            A_Temp "\ProcessWatchdogLogs")
        this.windowLayoutService := WindowLayoutService(this.configRepository)
        this.maintenanceJournalPath := A_ScriptDir "\watchdog.maintenance.ini"
        this.checkInterval := 2000
        this.retrySequence := "1, 10, 60"
        this.retryDelayArray := []
        this.showAtStartup := false
        this.recursiveBatchImport := true
        this.logMaxEntries := 500
        this.logDirectory := A_Temp "\ProcessWatchdogLogs"
        this.logRetentionDays := 30
        this.clearLogsOnStartup := false
        this.gracefulStopSeconds := 3
        this.ctrlCWaitSeconds := 2
        this.allowForceTerminate := true
        this.preferEverything := true
        this.nativeScanTimeoutSeconds := 15
        this.everythingMaxResults := 80
        this.maintenancePollInterval := 1000
        this.maintenanceProcessInterval := 1000
        this.maintenanceFingerprintInterval := 30000
        this.maintenanceFingerprintRetryInterval := 5000
        this.guardWorkGate := GuardWorkGate()
        this.appStates := Map()
        this.appStates.CaseSense := "Off"
        this.scheduler := WatchdogScheduler("", true, "")
        this.targetLauncher := TargetLauncher()
        this.targetStopper := TargetStopper()
        this.processInspector := ProcessInspector()
        this.fileScanner := FileScanService({
            CanonicalPath: GetCanonicalPath,
            GetCreationIdentity: ObjBindMethod(this.processInspector,
                "GetCreationIdentity"),
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
            GetCanonicalPath)
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
            Log: LogMsg,
            LogSlow: LogSlowBackgroundOperation,
            NormalizeRoot: NormalizeMaintenanceRoot,
            NormalizeTargetPath: NormalizeTargetPath,
            ObserveTarget: ObserveTarget,
            QueryProcessSnapshot: QueryProcessSnapshot,
            RefreshShortcutIdentity: ObjBindMethod(
                this.targetIdentityService, "RefreshShortcut"),
            SaveApps: SaveAppsToIni,
            SerializeSession: ObjBindMethod(this.maintenanceSessionCodec,
                "Serialize"),
            ScheduleRestart: "",
            SetProcessIdentity: SetStateProcessIdentity,
            TargetReferenceExists: ObjBindMethod(this.targetIdentityService,
                "TargetReferenceExists"),
            UpdateRunningState: UpdateRunningState,
            UpdateState: UpdateState,
            WatcherFactory: DirectoryChangeWatcher
        })
        this.guardRuntime := GuardRuntime(this, {
            ClearProcessIdentity: ClearStateProcessIdentity,
            GetLogFilePath: GetLogFilePath,
            GetTargetSpecs: ObjBindMethod(this.targetSpecsService, "Get"),
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
            this.maintenanceCoordinator, "OnSnapshotPublished")
        this.appOrder := []
        this.configLoadWarnings := []
        this.configRecoveryEntries := []
        this.appsDirty := false
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
            ])
        this.iconResources := IconResourceRegistry()
        this.svgRenderer := SvgRenderLibrary(
            A_ScriptDir "\third_party\resvg\resvg.dll")
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
        this.savedHeight := 530
        this.savedColumn1 := 500
        this.savedColumn2 := 205
        this.batchImportMaxResults := 2000
    }

    RetryDirtyAppConfig(*) {
        if this.appsDirty
            SaveAppsToIni()
    }

    SetConfigRepository(repository) {
        if !IsObject(repository)
            throw TypeError("配置仓储无效")
        this.configRepository := repository
        for serviceName in ["runtimeSettingsService", "windowLayoutService",
            "watchlistPersistenceService"] {
            if this.HasOwnProp(serviceName)
                this.%serviceName%.Repository := repository
        }
        return repository
    }
}
