/*
================================================================================
    进程守护小助手 (Process Watchdog)
    开发语言：AutoHotkey v2
    主要功能：后台进程、脚本、启动项守护与定时保活。
    【核心特性说明】
    1. 多态守护：全面支持原生应用(.exe)、解释型脚本(.py/.ahk/.js)、文件(.bat/.cmd)和快捷方式。
    2. 进程探活：优先使用原生快照与已核验 PID，命令行证据由后台 WMI 快照补充。
    3. UI 界面动态适配：通过调用 dwmapi, uxtheme, shell32 等系统 API 适配深色模式。
    4. 异常处理：快速重试耗尽后改为间隔自动重试，避免连续崩溃造成资源过度占用。
================================================================================
*/

;@Ahk2Exe-SetName 进程守护小助手
;@Ahk2Exe-SetDescription 进程、脚本和快捷方式守护工具
;@Ahk2Exe-SetVersion 0.1.0.0
;@Ahk2Exe-SetCopyright Copyright (c) 2026 进程守护小助手 contributors
;@Ahk2Exe-SetMainIcon watchdog.ico

#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut ; 严格警告写入诊断输出，避免后台启动被不可见对话框阻塞

#Include src\Platform\Win32.ahk
#Include src\Config\IniFieldCodec.ahk
#Include src\Config\DisplayConfigCodec.ahk
#Include src\Config\MaintenanceConfigCodec.ahk
#Include src\Config\AppConfigSnapshotService.ahk
#Include src\Config\RuntimeSettingsService.ahk
#Include src\Config\WindowLayoutService.ahk
#Include src\Config\WatchlistPersistenceService.ahk
#Include src\Config\WatchdogConfigRepository.ahk
#Include src\Core\GuardTypes.ahk
#Include src\Core\GuardStateMachine.ahk
#Include src\Maintenance\MaintenanceStateMachine.ahk
#Include src\Core\GuardWorkGate.ahk
#Include src\Core\WatchdogScheduler.ahk
#Include src\Core\RestartPolicy.ahk
#Include src\Core\TargetSupervisor.ahk
#Include src\Core\TargetSpecs.ahk
#Include src\Core\TargetSpecsService.ahk
#Include src\Core\TargetIdentityService.ahk
#Include src\Core\AppConfigHistoryService.ahk
#Include src\Execution\TargetLauncher.ahk
#Include src\Execution\TargetStopper.ahk
#Include src\Maintenance\MaintenanceActorMatcher.ahk
#Include src\Maintenance\MaintenanceSessionCodec.ahk
#Include src\Maintenance\MaintenanceCoordinator.ahk
#Include src\Inspection\ProcessInspector.ahk
#Include src\Inspection\ProcessSnapshotIndex.ahk
#Include src\Inspection\ProcessSnapshotService.ahk
#Include src\Inspection\TargetProbe.ahk
#Include src\Inspection\TargetFileInspector.ahk
#Include src\Inspection\ShortcutResolver.ahk
#Include src\Inspection\ShortcutTargetResolver.ahk
#Include src\Inspection\DirectoryChangeWatcher.ahk
#Include src\Inspection\FileScanService.ahk
#Include src\Diagnostics\DiagnosticBundleService.ahk
#Include src\UI\IconResourceRegistry.ahk
#Include src\UI\SvgRenderLibrary.ahk
#Include src\UI\UiInteractionRegistry.ahk
#Include src\UI\MainListProjection.ahk
#Include src\UI\WindowHierarchy.ahk
#Include src\UI\ManagedWindow.ahk
#Include app\GuiModuleRegistry.ahk
#Include app\Windows\CustomDisplayDialog.ahk
#Include app\Windows\MaintenanceSettingsDialog.ahk
#Include app\Windows\EnvironmentSettingsDialog.ahk
#Include app\Windows\AddItemDialog.ahk
#Include app\Windows\SettingsWindow.ahk
#Include app\Windows\LogWindow.ahk
#Include app\Windows\HelpWindow.ahk
#Include app\Windows\ApplicationSearchDialog.ahk
#Include app\Windows\DarkTooltipWindow.ahk
#Include src\Core\GuardRuntime.ahk

class ButtonFeedbackMode {
    static Persistent := 0
    static Dismissive := 1
}

class ButtonFeedbackTiming {
    static ReleaseResetMs := 50
}

class RoundedButtonRenderer {
    static RadiusDip := 6
    static ParentColor := "1E1E1E"
    static token := 0

    static EnsureStarted() {
        if this.token
            return true
        startupInput := Buffer(A_PtrSize == 8 ? 24 : 16, 0)
        NumPut("UInt", 1, startupInput, 0)
        token := 0
        status := DllCall("gdiplus\GdiplusStartup", "UPtr*", &token,
            "Ptr", startupInput, "Ptr", 0, "UInt")
        if status || !token
            return false
        this.token := token
        return true
    }

    static Shutdown(*) {
        if !this.token
            return
        DllCall("gdiplus\GdiplusShutdown", "UPtr", this.token)
        this.token := 0
    }

    static ColorToArgb(color, alpha := 255) {
        colorValue := ParseButtonColorValue(color)
        if (colorValue < 0)
            colorValue := ParseButtonColorValue(this.ParentColor)
        return ((alpha & 0xFF) << 24) | colorValue
    }

    static ColorToBgr(color) {
        colorValue := ParseButtonColorValue(color)
        if (colorValue < 0)
            colorValue := 0xFFFFFF
        return ((colorValue & 0xFF) << 16)
            | (colorValue & 0x00FF00)
            | ((colorValue >> 16) & 0xFF)
    }

    static MixColor(foreground, background, foregroundWeight) {
        foregroundValue := ParseButtonColorValue(foreground)
        backgroundValue := ParseButtonColorValue(background)
        if (foregroundValue < 0 || backgroundValue < 0)
            return foreground
        foregroundWeight := Max(0, Min(1, foregroundWeight))
        backgroundWeight := 1 - foregroundWeight
        red := Round(((foregroundValue >> 16) & 0xFF) * foregroundWeight
            + ((backgroundValue >> 16) & 0xFF) * backgroundWeight)
        green := Round(((foregroundValue >> 8) & 0xFF) * foregroundWeight
            + ((backgroundValue >> 8) & 0xFF) * backgroundWeight)
        blue := Round((foregroundValue & 0xFF) * foregroundWeight
            + (backgroundValue & 0xFF) * backgroundWeight)
        return Format("{:02X}{:02X}{:02X}", red, green, blue)
    }

    static CreateRoundedPath(width, height, radius, inset := 0.5) {
        path := 0
        if DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &path, "UInt") || !path
            return 0
        pathWidth := Max(1.0, width - inset * 2)
        pathHeight := Max(1.0, height - inset * 2)
        diameter := Max(2.0, Min(radius * 2.0, pathWidth, pathHeight))
        try {
            DllCall("gdiplus\GdipAddPathArc", "Ptr", path,
                "Float", inset, "Float", inset, "Float", diameter, "Float", diameter,
                "Float", 180.0, "Float", 90.0)
            DllCall("gdiplus\GdipAddPathArc", "Ptr", path,
                "Float", inset + pathWidth - diameter, "Float", inset,
                "Float", diameter, "Float", diameter, "Float", 270.0, "Float", 90.0)
            DllCall("gdiplus\GdipAddPathArc", "Ptr", path,
                "Float", inset + pathWidth - diameter, "Float", inset + pathHeight - diameter,
                "Float", diameter, "Float", diameter, "Float", 0.0, "Float", 90.0)
            DllCall("gdiplus\GdipAddPathArc", "Ptr", path,
                "Float", inset, "Float", inset + pathHeight - diameter,
                "Float", diameter, "Float", diameter, "Float", 90.0, "Float", 90.0)
            DllCall("gdiplus\GdipClosePathFigure", "Ptr", path)
            return path
        } catch {
            DllCall("gdiplus\GdipDeletePath", "Ptr", path)
            return 0
        }
    }

    static IsDisabled(state) {
        ; 下级窗口打开时，上级 GUI 会被临时禁用，但可见按钮不应因此改变配色。
        ; 这里只读取控件自身的 WS_DISABLED；交互可用性仍由 IsControlEffectivelyEnabled 判断。
        try return !DllCall("user32\IsWindowEnabled", "Ptr", state.ctrl.Hwnd, "Int")
        catch
            return true
    }

    static DrawSurface(hdc, width, height, state) {
        graphics := 0
        path := 0
        brush := 0
        if DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdc, "Ptr*", &graphics, "UInt") || !graphics
            return false
        try {
            DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics, "Int", 4)
            DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", graphics, "Int", 4)
            DllCall("gdiplus\GdipSetCompositingQuality", "Ptr", graphics, "Int", 2)
            DllCall("gdiplus\GdipGraphicsClear", "Ptr", graphics,
                "UInt", this.ColorToArgb(this.ParentColor))

            dpi := DllCall("user32\GetDpiForWindow", "Ptr", state.ctrl.Hwnd, "UInt")
            if !dpi
                dpi := 96
            radius := Max(3, Round(this.RadiusDip * dpi / 96))
            path := this.CreateRoundedPath(width, height, radius)
            if !path
                return false

            backgroundColor := state.HasOwnProp("current") ? state.current : state.normal
            if this.IsDisabled(state)
                backgroundColor := this.MixColor(state.normal, this.ParentColor, 0.58)
            if DllCall("gdiplus\GdipCreateSolidFill", "UInt", this.ColorToArgb(backgroundColor),
                "Ptr*", &brush, "UInt") || !brush
                return false
            if DllCall("gdiplus\GdipFillPath", "Ptr", graphics, "Ptr", brush,
                "Ptr", path, "UInt")
                return false
            return true
        } finally {
            if brush
                DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
            if path
                DllCall("gdiplus\GdipDeletePath", "Ptr", path)
            if graphics
                DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
        }
    }

    static DrawText(hdc, width, height, state) {
        hFont := DllCall("user32\SendMessageW", "Ptr", state.ctrl.Hwnd,
            "UInt", Win32.WM_GETFONT, "Ptr", 0, "Ptr", 0, "Ptr")
        if !hFont
            hFont := DllCall("gdi32\GetStockObject", "Int", 17, "Ptr") ; DEFAULT_GUI_FONT
        previousFont := hFont ? DllCall("gdi32\SelectObject", "Ptr", hdc,
            "Ptr", hFont, "Ptr") : 0
        try {
            DllCall("gdi32\SetBkMode", "Ptr", hdc, "Int", 1) ; TRANSPARENT
            textColor := state.HasOwnProp("textColor") ? state.textColor : "FFFFFF"
            if this.IsDisabled(state)
                textColor := this.MixColor(textColor, this.ParentColor, 0.58)
            DllCall("gdi32\SetTextColor", "Ptr", hdc, "UInt", this.ColorToBgr(textColor))
            dpi := DllCall("user32\GetDpiForWindow", "Ptr", state.ctrl.Hwnd, "UInt")
            if !dpi
                dpi := 96
            horizontalInset := Max(3, Round(4 * dpi / 96))
            textRect := Buffer(16, 0)
            NumPut("Int", horizontalInset, "Int", 0, "Int", width - horizontalInset,
                "Int", height, textRect)
            text := ""
            try text := state.ctrl.Text
            DllCall("user32\DrawTextW", "Ptr", hdc, "Str", text, "Int", -1,
                "Ptr", textRect, "UInt", 0x00008825, "Int")
        } finally {
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", previousFont, "Ptr")
        }
    }

    static Draw(hdc, width, height, state) {
        if !this.EnsureStarted() || width <= 0 || height <= 0
            return false
        memoryDc := DllCall("gdi32\CreateCompatibleDC", "Ptr", hdc, "Ptr")
        if !memoryDc
            return false
        bitmap := DllCall("gdi32\CreateCompatibleBitmap", "Ptr", hdc,
            "Int", width, "Int", height, "Ptr")
        if !bitmap {
            DllCall("gdi32\DeleteDC", "Ptr", memoryDc)
            return false
        }
        previousBitmap := DllCall("gdi32\SelectObject", "Ptr", memoryDc,
            "Ptr", bitmap, "Ptr")
        drawn := false
        try {
            if !this.DrawSurface(memoryDc, width, height, state)
                return false
            this.DrawText(memoryDc, width, height, state)
            drawn := !!DllCall("gdi32\BitBlt", "Ptr", hdc, "Int", 0, "Int", 0,
                "Int", width, "Int", height, "Ptr", memoryDc, "Int", 0, "Int", 0,
                "UInt", 0x00CC0020, "Int") ; SRCCOPY
            return drawn
        } finally {
            if previousBitmap
                DllCall("gdi32\SelectObject", "Ptr", memoryDc, "Ptr", previousBitmap, "Ptr")
            DllCall("gdi32\DeleteObject", "Ptr", bitmap)
            DllCall("gdi32\DeleteDC", "Ptr", memoryDc)
        }
    }
}

class RoundedButtonInputRouter {
    static SubclassId := 0x52424E ; "RBN"
    static callbackPtr := 0

    static EnsureCallback() {
        if this.callbackPtr
            return true
        try this.callbackPtr := CallbackCreate(ButtonControlSubclassProc, "", 6)
        catch
            this.callbackPtr := 0
        return this.callbackPtr != 0
    }

    static Attach(hWnd) {
        if !hWnd || !this.EnsureCallback()
            return false
        return !!DllCall("comctl32\SetWindowSubclass", "Ptr", hWnd,
            "Ptr", this.callbackPtr, "UPtr", this.SubclassId, "UPtr", 0, "Int")
    }

    static Detach(hWnd) {
        if hWnd && this.callbackPtr && DllCall("user32\IsWindow", "Ptr", hWnd, "Int")
            DllCall("comctl32\RemoveWindowSubclass", "Ptr", hWnd,
                "Ptr", this.callbackPtr, "UPtr", this.SubclassId, "Int")
    }

    static Shutdown() {
        if !this.callbackPtr
            return
        if IsSet(App) {
            for hWnd, state in App.uiInteractions.Buttons {
                if state.HasOwnProp("roundedOwnerDraw") && state.roundedOwnerDraw
                    this.Detach(hWnd)
            }
        }
        CallbackFree(this.callbackPtr)
        this.callbackPtr := 0
    }
}

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

; 业务运行态只有一个稳定根对象；函数只修改实例属性，不再重新绑定全局变量。
global App := ApplicationState()

; 按钮绘制与鼠标分发必须早于权限提示框安装，确保启动失败界面同样可操作。
OnMessage(Win32.WM_DRAWITEM, OnDrawRoundedButton)
OnMessage(Win32.WM_SETFOCUS, OnRoundedButtonFocusChanged)
OnMessage(Win32.WM_KILLFOCUS, OnRoundedButtonFocusChanged)
OnMessage(Win32.WM_SETCURSOR, OnSetCursor)
OnMessage(Win32.WM_LBUTTONDOWN, OnGlobalPointerDown)
OnMessage(Win32.WM_LBUTTONUP, OnGlobalPointerUp)
OnMessage(Win32.WM_NCLBUTTONDOWN, OnGlobalPointerDown)
OnMessage(Win32.WM_CANCELMODE, OnButtonPressCancelled)
OnMessage(Win32.WM_CAPTURECHANGED, OnButtonCaptureChanged)
OnMessage(Win32.WM_MOUSEMOVE, OnMouseMove_Tooltip)
OnMessage(Win32.WM_MOUSELEAVE, OnMouseLeave_Hover)
OnMessage(Win32.AHK_NOTIFYICON, OnTrayNotification)
OnExit(ShutdownApplication)

if ProcessMaintenanceCommandClient()
    ExitApp()

class MainWindow {
    __New() {
        this.gui := Gui("+Resize +MinSize730x530", "进程守护小助手")
        this.lv := ""
        this.btnAdd := ""
        this.btnDel := ""
        this.btnPause := ""
        this.btnSet := ""
        this.btnLog := ""
        this.btnHelp := ""
        this.appIcons := 0
        this.statusIconIndices := Map()
        this.statsText := ""
        this.contextMenu := ""
        this.contextTargetRow := 0
        this.listProjection := MainListProjection(NormalizeTargetPath)
    }
}

/*  * ========================================================================
 * 1. 自动提升管理员权限 (UAC)
 * 由于程序需要操作定时任务与检测进程，启动时若缺乏权限则自动提升。
 * ========================================================================
 */
if not A_IsAdmin {
    try {
        relaunchArguments := ""
        for relaunchArgument in A_Args
            relaunchArguments .= " " QuoteCommandLineArgument(relaunchArgument)
        Run('*RunAs "' A_ScriptFullPath '"' relaunchArguments)
    } catch {
        ShowDarkMsgBox("守护监控操作必须具备高级别系统读写权限，请以管理员身份运行此程序！", "系统权限拦截", "Error")
    }
    ExitApp()
}

/*  * ========================================================================
 * 2. 程序单实例互斥锁 (Mutex Single Instance)
 * 运用系统内核级的 Mutex 锁定机制，确保全局只存在一个工具实例。
 * 如果检测到程序已在运行，则主动弹出原有窗口，然后退出当前进程。
 * ========================================================================
 */
startupHandoffPid := GetReloadHandoffPid()
if startupHandoffPid
    try ProcessWaitClose(startupHandoffPid, 60)
startupMutexExists := false
App.mutexHandle := AcquireApplicationMutex(&startupMutexExists)
if !App.mutexHandle {
    ShowDarkMsgBox("无法建立单实例运行锁，小助手将退出。", "启动失败", "Error")
    ExitApp()
}
if startupMutexExists {
    DetectHiddenWindows(True)
    existingWindow := WinExist("进程守护小助手 ahk_class AutoHotkeyGUI")
    if (!existingWindow
        && App.maintenanceCoordinator.PendingCommands.Length) {
        Loop 30 {
            Sleep(100)
            existingWindow := WinExist("进程守护小助手 ahk_class AutoHotkeyGUI")
            if existingWindow
                break
        }
    }
    if existingWindow {
        if App.maintenanceCoordinator.PendingCommands.Length {
            while App.maintenanceCoordinator.PendingCommands.Length {
                SendMaintenanceCopyData(existingWindow,
                    App.maintenanceCoordinator.PendingCommands.RemoveAt(1))
            }
            ExitApp()
        }
        WinShow()       ; 从托盘盲区强制释放展示
        WinRestore()    ; 复原可能存在的最小化压栈操作
        WinActivate()   ; 置前获取软硬件焦点
    }
    ExitApp()
}

; 单实例与权限确认完成后再等待 Explorer，避免竞争实例都阻塞启动数秒。
shellPid := ProcessWait("explorer.exe", 10)
shellReady := shellPid && WinWait("ahk_class Shell_TrayWnd", , 10)
if shellReady
    Sleep(2000)

A_IconHidden := true
Sleep(50)
A_IconHidden := false
; Windows 会把未注册的 AppUserModelID 直接显示为通知来源名称；必须稳定且可读。
try DllCall("shell32\SetCurrentProcessExplicitAppUserModelID", "WStr", "进程守护小助手")

if FileExist(A_ScriptDir "\watchdog.ico") {
    TraySetIcon(A_ScriptDir "\watchdog.ico")
    SetWindowIcon(A_ScriptHwnd, A_ScriptDir "\watchdog.ico")
}

/*  * ========================================================================
 * 3. 应用程序全局深色上下文设置
 * 动态判断操作系统版本，通过 uxtheme 接口挂载深色基底。
 * ========================================================================
 */
if (VerCompare(A_OSVersion, "10.0.18362") >= 0) {
    try DllCall("uxtheme\135", "Int", 2) ; Windows 10/11 极夜模式
} else if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
    try DllCall("uxtheme\135", "Int", 1) ; 早期深色实现指令
}

; ==========================================
; 4. 主窗口与 INI 配置文件初始化
; ==========================================
global Main := MainWindow()

; ==========================================
; 修复：解除 UAC 管理员权限下的 UIPI（用户界面特权隔离）限制
; 允许接收来自低权限进程（如普通资源管理器/桌面）的文件拖放
; ==========================================
try {
    DllCall("user32\ChangeWindowMessageFilterEx", "Ptr", Main.gui.Hwnd, "UInt", Win32.WM_DROPFILES, "UInt", 1, "Ptr", 0)
    DllCall("user32\ChangeWindowMessageFilterEx", "Ptr", Main.gui.Hwnd, "UInt", Win32.WM_COPYGLOBALDATA, "UInt", 1, "Ptr", 0)
    DllCall("user32\ChangeWindowMessageFilterEx", "Ptr", Main.gui.Hwnd, "UInt", Win32.WM_COPYDATA, "UInt", 1, "Ptr", 0)
}

HideManagedWindowTransientWindows(*) {
    if IsSet(GuiModules)
        try GuiModules.HideTransientWindows()
}

; 先配置托管窗口生命周期，再公开模块注册表，避免消息回调命中尚未配置的窗口对象。
ManagedWindow.ConfigureLifecycle(ManagedWindowLifecycle({
    RestoreInteractions: RestoreHoveredButton,
    HideTransientWindows: HideManagedWindowTransientWindows,
    UnregisterControls: UnregisterGuiControls,
    ReleaseIcons: ReleaseWindowIcons
}, WindowHierarchy))
; 所有短生命周期 GUI 都由模块实例持有，窗口销毁后由类负责清空引用。
global GuiModules := GuiModuleRegistry(Main.gui)

; 首次运行只创建带就地注释的设置分区，不预设任何守护项。
App.runtimeSettingsService.EnsureExists()
App.runtimeSettingsService.Apply(App, App.runtimeSettingsService.Load())
CleanupBatchLogs()

; 读取布局设定
App.windowLayoutService.Apply(App, App.windowLayoutService.Load())

/*  * ========================================================================
 * 5. 系统底层原生 UI 接口调用集
 * 通过 DWM 和 UxTheme 等组件，调整界面的深色及原生组件适配。
 * ========================================================================
 */
SetDarkTitleBar(hWnd) {
    ; 修改 DWM 窗口属性以调用深色层级的标题栏
    if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
        attr := VerCompare(A_OSVersion, "10.0.18985") >= 0 ? 20 : 19
        try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hWnd, "Int", attr, "Int*", 1, "Int", 4)

        ; 开启进程级别的暗黑模式支持及当前窗口暗黑，以适配滚动条和右键菜单 (Ordinal 135 & 133)
        try {
            uxtheme := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
            if (uxtheme) {
                SetPreferredAppMode := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 135, "Ptr")
                if SetPreferredAppMode
                    DllCall(SetPreferredAppMode, "Int", 1) ; 1 = AllowDark

                AllowDarkModeForWindow := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 133, "Ptr")
                if AllowDarkModeForWindow
                    DllCall(AllowDarkModeForWindow, "Ptr", hWnd, "Int", 1)
            }
        }
    }
}

SetWindowIcon(hWnd, iconPath) {
    if !hWnd || !DllCall("user32\IsWindow", "Ptr", hWnd, "Int")
        || !FileExist(iconPath)
        return false

    hIconSmall := 0
    hIconBig := 0
    try {
        ; 两个尺寸必须都加载成功后才替换，避免窗口继续引用已被释放的旧图标。
        hIconSmall := DllCall("user32\LoadImage", "Ptr", 0, "Str", iconPath,
            "UInt", 1, "Int", SysGet(49), "Int", SysGet(50),
            "UInt", 0x00000010, "Ptr")
        hIconBig := DllCall("user32\LoadImage", "Ptr", 0, "Str", iconPath,
            "UInt", 1, "Int", SysGet(11), "Int", SysGet(12),
            "UInt", 0x00000010, "Ptr")
    } catch {
        DestroyIconHandles([hIconSmall, hIconBig])
        return false
    }
    if !hIconSmall || !hIconBig {
        DestroyIconHandles([hIconSmall, hIconBig])
        return false
    }

    previousSmall := 0
    smallAssigned := false
    try {
        previousSmall := SendMessage(Win32.WM_SETICON, Win32.ICON_SMALL,
            hIconSmall, , hWnd)
        smallAssigned := true
        SendMessage(Win32.WM_SETICON, Win32.ICON_BIG, hIconBig, , hWnd)
    } catch {
        if smallAssigned && DllCall("user32\IsWindow", "Ptr", hWnd, "Int")
            try SendMessage(Win32.WM_SETICON, Win32.ICON_SMALL,
                previousSmall, , hWnd)
        DestroyIconHandles([hIconSmall, hIconBig])
        return false
    }

    oldHandles := App.iconResources.ReplaceWindowIcons(hWnd,
        [hIconSmall, hIconBig])
    DestroyIconHandles(oldHandles, hIconSmall, hIconBig)
    return true
}

SetDarkListView(hLV) {
    if !hLV
        return
    ; 控件首次显示时可能被系统重新套用主题，因此显示前后各应用一次。
    ApplyDarkListViewTheme(hLV)
    SetTimer(ApplyDarkListViewTheme.Bind(hLV), -100)
}

CreateMainImageList(statusIconIndices) {
    statusIconIndices.Clear()
    imageList := IL_Create(10, 10, 1)
    if !imageList
        return imageList
    iconResources := App.iconResources
    previousMetrics := iconResources.GetMainIconMetrics()
    dpi := 96
    try dpi := DllCall("user32\GetDpiForWindow", "Ptr", Main.gui.Hwnd, "UInt")
    if !dpi
        dpi := 96
    iconResources.UpdateMainIconMetrics(dpi)
    try DllCall("comctl32\ImageList_SetIconSize", "Ptr", imageList,
        "Int", iconResources.MainIconCellPixelSize,
        "Int", iconResources.MainIconCellPixelSize)
    try AddMainStatusIcons(imageList, statusIconIndices)
    catch {
        try IL_Destroy(imageList)
        statusIconIndices.Clear()
        iconResources.RestoreMainIconMetrics(previousMetrics)
        return 0
    }
    return imageList
}

GetShellImageListIcon(filePath, imageListKind) {
    sfi := Buffer(A_PtrSize + 688, 0)
    flags := Win32.SHGFI_SYSICONINDEX
    attributes := 0
    if !FileExist(filePath) {
        flags |= Win32.SHGFI_USEFILEATTRIBUTES
        attributes := Win32.FILE_ATTRIBUTE_NORMAL
    }
    if !DllCall("shell32\SHGetFileInfoW", "WStr", filePath, "UInt", attributes,
        "Ptr", sfi, "UInt", sfi.Size, "UInt", flags, "UPtr")
        return 0

    systemIconIndex := NumGet(sfi, A_PtrSize, "Int")
    imageListIid := Buffer(16, 0)
    if DllCall("ole32\CLSIDFromString", "WStr", "{46EB5926-582E-4017-9FDF-E8998DAA0950}",
        "Ptr", imageListIid, "Int") < 0
        return 0

    shellImageList := 0
    hIcon := 0
    try {
        if DllCall("shell32\SHGetImageList", "Int", imageListKind,
            "Ptr", imageListIid, "Ptr*", &shellImageList, "Int") < 0
            || !shellImageList
            return 0
        vtable := NumGet(shellImageList, 0, "Ptr")
        getIcon := NumGet(vtable, 10 * A_PtrSize, "Ptr")
        if DllCall(getIcon, "Ptr", shellImageList,
            "Int", systemIconIndex, "UInt", Win32.ILD_TRANSPARENT,
            "Ptr*", &hIcon, "Int") == 0 {
            resultIcon := hIcon
            hIcon := 0
            return resultIcon
        }
    } catch {
        return 0
    } finally {
        if hIcon
            try DllCall("user32\DestroyIcon", "Ptr", hIcon)
        if shellImageList
            try ReleaseIconComObject(shellImageList)
    }
    return 0
}

GetPreferredMainIcon(filePath, &useHighQualityResampling := false) {
    useHighQualityResampling := false
    iconSource := ParseCustomIconSource(filePath)
    sourcePath := iconSource.Path
    if !FileExist(sourcePath) || DirExist(sourcePath)
        return 0
    SplitPath(sourcePath, , , &extension)
    extension := StrLower(extension)
    if extension == "exe" || extension == "ico"
        || extension == "dll" || extension == "cpl" {
        sourceSize := SelectClosestIconSourceSize(
            App.iconResources.MainIconPixelSize)
        hIcon := 0
        iconResourceId := 0
        extractedCount := 0
        try extractedCount := DllCall("user32\PrivateExtractIconsW",
            "WStr", sourcePath, "Int", iconSource.Index,
            "Int", sourceSize, "Int", sourceSize,
            "Ptr*", &hIcon, "UInt*", &iconResourceId,
            "UInt", 1, "UInt", 0, "UInt")
        if extractedCount && hIcon {
            useHighQualityResampling := true
            return hIcon
        }
        if hIcon
            DllCall("user32\DestroyIcon", "Ptr", hIcon)
    }
    return GetShellImageListIcon(sourcePath, Win32.SHIL_EXTRALARGE)
}

SelectClosestIconSourceSize(targetSize) {
    for candidateSize in [16, 20, 24, 32, 40, 48, 64, 96, 128, 256] {
        if candidateSize >= targetSize
            return candidateSize
    }
    return 256
}

EnsureIconResampler() {
    iconResources := App.iconResources
    if iconResources.GetResamplerFactory()
        return true
    factoryClsid := Buffer(16, 0)
    factoryIid := Buffer(16, 0)
    if DllCall("ole32\CLSIDFromString", "WStr", "{CACAF262-9370-4615-A13B-9F5539DA4C0A}",
        "Ptr", factoryClsid, "Int") < 0
        return false
    if DllCall("ole32\CLSIDFromString", "WStr", "{EC5EC8A9-C395-4314-9C77-54D7A935FF70}",
        "Ptr", factoryIid, "Int") < 0
        return false
    factory := 0
    if DllCall("ole32\CoCreateInstance", "Ptr", factoryClsid, "Ptr", 0,
        "UInt", 1, "Ptr", factoryIid, "Ptr*", &factory, "Int") < 0
        || !factory
        return false
    if iconResources.InstallResamplerFactory(factory)
        return true
    ; 若可重入调用已先安装工厂，释放本次多创建的 COM 引用。
    try ReleaseIconComObject(factory)
    return iconResources.GetResamplerFactory() != 0
}

IsIconResourceContainerExtension(extension) {
    extension := StrLower(Trim(extension))
    return InStr("|exe|dll|cpl|", "|" extension "|") != 0
}

ParseCustomIconSource(source) {
    sourceText := NormalizeTargetPath(String(source))
    result := {Path: sourceText, Index: 0, HasIndex: false}
    if !RegExMatch(sourceText, "s)^(.*),\s*(-?\d+)\s*$", &match)
        return result
    candidatePath := NormalizeTargetPath(Trim(match[1], " `t`r`n`""))
    SplitPath(candidatePath, , , &extension)
    if !IsIconResourceContainerExtension(extension)
        return result
    try iconIndex := Integer(match[2])
    catch
        return result
    result.Path := candidatePath
    result.Index := iconIndex
    result.HasIndex := true
    return result
}

FormatCustomIconSource(filePath, iconIndex := 0,
    includeResourceIndex := false) {
    filePath := NormalizeTargetPath(filePath)
    if filePath == "" || !includeResourceIndex
        return filePath
    try iconIndex := Integer(iconIndex)
    catch
        iconIndex := 0
    return filePath "," iconIndex
}

CustomIconSourceExists(source) {
    iconSource := ParseCustomIconSource(source)
    return iconSource.Path != "" && FileExist(iconSource.Path)
        && !DirExist(iconSource.Path)
}

ConfigureSingleFileDialogInitialPath(fileDialog, initialPath) {
    initialPath := NormalizeTargetPath(initialPath)
    if initialPath == ""
        return
    initialName := ""
    if DirExist(initialPath) {
        initialDirectory := initialPath
    } else {
        SplitPath(initialPath, &initialName, &initialDirectory)
        if !DirExist(initialDirectory)
            return
    }
    shellItemIid := Buffer(16, 0)
    if DllCall("ole32\CLSIDFromString",
        "WStr", "{43826D1E-E718-42EE-BC55-A1E261C37BFE}",
        "Ptr", shellItemIid, "Int") < 0
        return
    shellItem := 0
    try {
        if DllCall("shell32\SHCreateItemFromParsingName",
            "WStr", initialDirectory, "Ptr", 0, "Ptr", shellItemIid,
            "Ptr*", &shellItem, "Int") < 0 || !shellItem
            return
        ComCall(12, fileDialog, "Ptr", shellItem)
        if initialName != ""
            ComCall(15, fileDialog, "Str", initialName)
    } finally {
        if shellItem
            try ObjRelease(shellItem)
    }
}

ReadSingleFileDialogPath(fileDialog, ownerHwnd := 0) {
    if ComCall(3, fileDialog, "Ptr", ownerHwnd, "Int") != 0
        return ""
    shellItem := 0
    pathBuffer := 0
    try {
        ComCall(20, fileDialog, "Ptr*", &shellItem)
        ComCall(5, shellItem, "UInt", 0x80058000,
            "Ptr*", &pathBuffer)
        return pathBuffer ? StrGet(pathBuffer, "UTF-16") : ""
    } finally {
        if pathBuffer
            try DllCall("ole32\CoTaskMemFree", "Ptr", pathBuffer)
        if shellItem
            try ObjRelease(shellItem)
    }
}

SelectFileWithNamedFilter(ownerHwnd, initialPath, prompt,
    filterName, filterPattern) {
    try {
        fileDialog := ComObject(
            "{DC1C5A9C-E88A-4DDE-A5A1-60F82A20AEF7}",
            "{D57C7288-D4AD-4768-BE02-9D969532D960}")
        ; 文件类型名称和扩展名模式分开传递。界面只显示中文名称，
        ; 不再为了 FileSelect 的语法暴露空格加半角括号。
        ComCall(9, fileDialog, "UInt", 0x1840)
        filterSpec := Buffer(A_PtrSize * 2, 0)
        NumPut("Ptr", StrPtr(filterName), filterSpec, 0)
        NumPut("Ptr", StrPtr(filterPattern), filterSpec, A_PtrSize)
        ComCall(4, fileDialog, "UInt", 1, "Ptr", filterSpec)
        ComCall(17, fileDialog, "Str", prompt)
        ConfigureSingleFileDialogInitialPath(fileDialog, initialPath)
        return ReadSingleFileDialogPath(fileDialog, ownerHwnd)
    } catch {
        return ""
    }
}

PickCustomIconResource(ownerHwnd, filePath, initialIndex := 0) {
    filePath := NormalizeTargetPath(filePath)
    if filePath == "" || !FileExist(filePath) || DirExist(filePath)
        return ""
    capacity := 32768
    pathBuffer := Buffer(capacity * 2, 0)
    StrPut(filePath, pathBuffer, "UTF-16")
    try iconIndex := Integer(initialIndex)
    catch
        iconIndex := 0
    try selected := DllCall("shell32\PickIconDlg", "Ptr", ownerHwnd,
        "Ptr", pathBuffer, "UInt", capacity, "Int*", &iconIndex, "Int")
    catch
        return ""
    if !selected
        return ""
    selectedPath := NormalizeTargetPath(StrGet(pathBuffer, "UTF-16"))
    if selectedPath == "" || !FileExist(selectedPath)
        return ""
    return FormatCustomIconSource(selectedPath, iconIndex, true)
}

GetCustomIconSourceExtension(filePath) {
    iconSource := ParseCustomIconSource(filePath)
    SplitPath(iconSource.Path, , , &extension)
    return StrLower(Trim(extension))
}

IsRasterImageIconExtension(extension) {
    extension := StrLower(Trim(extension))
    return InStr("|png|jpg|jpeg|jpe|jfif|bmp|gif|tif|tiff|webp|",
        "|" extension "|") != 0
}

IsSupportedCustomIconSource(filePath) {
    extension := GetCustomIconSourceExtension(filePath)
    return IsRasterImageIconExtension(extension)
        || InStr("|ico|exe|dll|cpl|lnk|svg|ani|",
            "|" extension "|") != 0
}

CreatePaddedIconFromPremultipliedPixels(pixelBuffer, pixelWidth,
    pixelHeight, cellSize) {
    if !IsObject(pixelBuffer) || pixelWidth <= 0 || pixelHeight <= 0
        || cellSize < pixelWidth || cellSize < pixelHeight
        return 0
    screenDC := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
    colorBitmap := 0
    maskBitmap := 0
    try {
        if !screenDC
            return 0
        bitmapInfo := Buffer(40, 0)
        NumPut("UInt", 40, bitmapInfo, 0)
        NumPut("Int", cellSize, bitmapInfo, 4)
        NumPut("Int", -cellSize, bitmapInfo, 8)
        NumPut("UShort", 1, bitmapInfo, 12)
        NumPut("UShort", 32, bitmapInfo, 14)
        colorBits := 0
        colorBitmap := DllCall("gdi32\CreateDIBSection", "Ptr", screenDC,
            "Ptr", bitmapInfo, "UInt", 0, "Ptr*", &colorBits,
            "Ptr", 0, "UInt", 0, "Ptr")
        if !colorBitmap || !colorBits
            return 0

        DllCall("ntdll\RtlZeroMemory", "Ptr", colorBits,
            "UPtr", cellSize * cellSize * 4)
        offsetX := Floor((cellSize - pixelWidth) / 2)
        offsetY := Floor((cellSize - pixelHeight) / 2)
        Loop pixelHeight {
            row := A_Index - 1
            destination := colorBits
                + ((offsetY + row) * cellSize + offsetX) * 4
            source := pixelBuffer.Ptr + row * pixelWidth * 4
            DllCall("ntdll\RtlMoveMemory", "Ptr", destination,
                "Ptr", source, "UPtr", pixelWidth * 4)
        }
        maskBitmap := CreateIconMaskFromAlpha(screenDC, colorBits,
            cellSize, cellSize)
        if !maskBitmap
            return 0
        iconInfo := Buffer(A_PtrSize == 8 ? 32 : 20, 0)
        NumPut("Int", 1, iconInfo, 0)
        bitmapOffset := A_PtrSize == 8 ? 16 : 12
        NumPut("Ptr", maskBitmap, iconInfo, bitmapOffset)
        NumPut("Ptr", colorBitmap, iconInfo, bitmapOffset + A_PtrSize)
        return DllCall("user32\CreateIconIndirect", "Ptr", iconInfo, "Ptr")
    } finally {
        if maskBitmap
            try DllCall("gdi32\DeleteObject", "Ptr", maskBitmap)
        if colorBitmap
            try DllCall("gdi32\DeleteObject", "Ptr", colorBitmap)
        if screenDC
            try DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDC)
    }
}

EnqueueLightMattePixel(pixelBuffer, matteMask, queue, pixelIndex,
    backgroundBlue, backgroundGreen, backgroundRed, tolerance) {
    if pixelIndex < 0 || pixelIndex >= matteMask.Size
        || NumGet(matteMask, pixelIndex, "UChar")
        return false
    offset := pixelIndex * 4
    if NumGet(pixelBuffer, offset + 3, "UChar") < 250
        return false
    distance := Max(
        Abs(NumGet(pixelBuffer, offset, "UChar") - backgroundBlue),
        Abs(NumGet(pixelBuffer, offset + 1, "UChar") - backgroundGreen),
        Abs(NumGet(pixelBuffer, offset + 2, "UChar") - backgroundRed))
    if distance > tolerance
        return false
    NumPut("UChar", 1, matteMask, pixelIndex)
    queue.Push(pixelIndex)
    return true
}

RemoveConnectedLightMatte(pixelBuffer, width, height) {
    if !IsObject(pixelBuffer) || width <= 1 || height <= 1
        return false
    cornerOffsets := [0, (width - 1) * 4,
        (height - 1) * width * 4,
        (width * height - 1) * 4]
    blueTotal := 0
    greenTotal := 0
    redTotal := 0
    for offset in cornerOffsets {
        if NumGet(pixelBuffer, offset + 3, "UChar") < 250
            return false
        blue := NumGet(pixelBuffer, offset, "UChar")
        green := NumGet(pixelBuffer, offset + 1, "UChar")
        red := NumGet(pixelBuffer, offset + 2, "UChar")
        if Min(blue, green, red) < 245
            return false
        blueTotal += blue
        greenTotal += green
        redTotal += red
    }
    backgroundBlue := Round(blueTotal / cornerOffsets.Length)
    backgroundGreen := Round(greenTotal / cornerOffsets.Length)
    backgroundRed := Round(redTotal / cornerOffsets.Length)
    for offset in cornerOffsets {
        if Max(
            Abs(NumGet(pixelBuffer, offset, "UChar") - backgroundBlue),
            Abs(NumGet(pixelBuffer, offset + 1, "UChar") - backgroundGreen),
            Abs(NumGet(pixelBuffer, offset + 2, "UChar") - backgroundRed)) > 8
            return false
    }

    ; 只沿边缘清理近白色像素；较深的描边必须成为阻断边界，避免
    ; 洪泛进入图标内部的银白面板或高光区域。
    tolerance := 32
    matteMask := Buffer(width * height, 0)
    queue := []
    enqueue := (pixelIndex) => EnqueueLightMattePixel(pixelBuffer,
        matteMask, queue, pixelIndex, backgroundBlue, backgroundGreen,
        backgroundRed, tolerance)
    Loop width {
        x := A_Index - 1
        enqueue(x)
        enqueue((height - 1) * width + x)
    }
    Loop height {
        y := A_Index - 1
        enqueue(y * width)
        enqueue(y * width + width - 1)
    }
    queueIndex := 1
    while queueIndex <= queue.Length {
        pixelIndex := queue[queueIndex++]
        x := Mod(pixelIndex, width)
        if x > 0
            enqueue(pixelIndex - 1)
        if x + 1 < width
            enqueue(pixelIndex + 1)
        if pixelIndex >= width
            enqueue(pixelIndex - width)
        if pixelIndex + width < width * height
            enqueue(pixelIndex + width)
    }
    for pixelIndex in queue {
        offset := pixelIndex * 4
        inputBlue := NumGet(pixelBuffer, offset, "UChar")
        inputGreen := NumGet(pixelBuffer, offset + 1, "UChar")
        inputRed := NumGet(pixelBuffer, offset + 2, "UChar")
        outputAlpha := Max(
            Abs(inputBlue - backgroundBlue),
            Abs(inputGreen - backgroundGreen),
            Abs(inputRed - backgroundRed))
        inverseAlpha := 255 - outputAlpha
        outputBlue := Max(0, Min(outputAlpha,
            Round(inputBlue - backgroundBlue * inverseAlpha / 255)))
        outputGreen := Max(0, Min(outputAlpha,
            Round(inputGreen - backgroundGreen * inverseAlpha / 255)))
        outputRed := Max(0, Min(outputAlpha,
            Round(inputRed - backgroundRed * inverseAlpha / 255)))
        NumPut("UChar", outputBlue, pixelBuffer, offset)
        NumPut("UChar", outputGreen, pixelBuffer, offset + 1)
        NumPut("UChar", outputRed, pixelBuffer, offset + 2)
        NumPut("UChar", outputAlpha, pixelBuffer, offset + 3)
    }
    return queue.Length > 0
}

CreatePaddedIconFromWicSource(wicSource, sourceWidth, sourceHeight,
    iconSize, cellSize, removeLightMatte := false) {
    if !wicSource || sourceWidth <= 0 || sourceHeight <= 0
        || iconSize <= 0 || cellSize < iconSize || !EnsureIconResampler()
        return 0
    resamplerFactory := App.iconResources.GetResamplerFactory()
    if !resamplerFactory
        return 0

    scale := Min(iconSize / sourceWidth, iconSize / sourceHeight)
    scaledWidth := Max(1, Min(iconSize, Round(sourceWidth * scale)))
    scaledHeight := Max(1, Min(iconSize, Round(sourceHeight * scale)))
    wicScaler := 0
    try {
        factoryVtable := NumGet(resamplerFactory, 0, "Ptr")
        createScaler := NumGet(factoryVtable, 11 * A_PtrSize, "Ptr")
        if DllCall(createScaler, "Ptr", resamplerFactory,
            "Ptr*", &wicScaler, "Int") < 0 || !wicScaler
            return 0
        scalerVtable := NumGet(wicScaler, 0, "Ptr")
        initializeScaler := NumGet(scalerVtable, 8 * A_PtrSize, "Ptr")
        interpolationMode := (scaledWidth < sourceWidth
            || scaledHeight < sourceHeight) ? 3 : 2
        if DllCall(initializeScaler, "Ptr", wicScaler, "Ptr", wicSource,
            "UInt", scaledWidth, "UInt", scaledHeight,
            "Int", interpolationMode, "Int") < 0
            return 0
        scaledPixels := Buffer(scaledWidth * scaledHeight * 4, 0)
        copyPixels := NumGet(scalerVtable, 7 * A_PtrSize, "Ptr")
        if DllCall(copyPixels, "Ptr", wicScaler, "Ptr", 0,
            "UInt", scaledWidth * 4, "UInt", scaledPixels.Size,
            "Ptr", scaledPixels, "Int") < 0
            return 0
        if removeLightMatte
            RemoveConnectedLightMatte(scaledPixels, scaledWidth,
                scaledHeight)
        return CreatePaddedIconFromPremultipliedPixels(scaledPixels,
            scaledWidth, scaledHeight, cellSize)
    } finally {
        try ReleaseIconComObject(wicScaler)
    }
}

CreateWicDecodedPaddedIcon(filePath, iconSize, cellSize,
    removeLightMatte := false) {
    if !EnsureIconResampler()
        return 0
    resamplerFactory := App.iconResources.GetResamplerFactory()
    decoder := 0
    frame := 0
    converter := 0
    try {
        factoryVtable := NumGet(resamplerFactory, 0, "Ptr")
        createDecoderFromFilename := NumGet(factoryVtable,
            3 * A_PtrSize, "Ptr")
        if DllCall(createDecoderFromFilename, "Ptr", resamplerFactory,
            "WStr", filePath, "Ptr", 0, "UInt", Win32.GENERIC_READ,
            "Int", 1, "Ptr*", &decoder, "Int") < 0 || !decoder
            return 0
        decoderVtable := NumGet(decoder, 0, "Ptr")
        getFrame := NumGet(decoderVtable, 13 * A_PtrSize, "Ptr")
        if DllCall(getFrame, "Ptr", decoder, "UInt", 0,
            "Ptr*", &frame, "Int") < 0 || !frame
            return 0

        createFormatConverter := NumGet(factoryVtable,
            10 * A_PtrSize, "Ptr")
        if DllCall(createFormatConverter, "Ptr", resamplerFactory,
            "Ptr*", &converter, "Int") < 0 || !converter
            return 0
        pixelFormat := Buffer(16, 0)
        if DllCall("ole32\CLSIDFromString",
            "WStr", "{6FDDC324-4E03-4BFE-B185-3D77768DC910}",
            "Ptr", pixelFormat, "Int") < 0
            return 0
        converterVtable := NumGet(converter, 0, "Ptr")
        initializeConverter := NumGet(converterVtable,
            8 * A_PtrSize, "Ptr")
        if DllCall(initializeConverter, "Ptr", converter, "Ptr", frame,
            "Ptr", pixelFormat, "Int", 0, "Ptr", 0, "Double", 0.0,
            "Int", 0, "Int") < 0
            return 0
        getSize := NumGet(converterVtable, 3 * A_PtrSize, "Ptr")
        sourceWidth := 0
        sourceHeight := 0
        if DllCall(getSize, "Ptr", converter, "UInt*", &sourceWidth,
            "UInt*", &sourceHeight, "Int") < 0
            return 0
        return CreatePaddedIconFromWicSource(converter, sourceWidth,
            sourceHeight, iconSize, cellSize, removeLightMatte)
    } finally {
        try ReleaseIconComObject(converter)
        try ReleaseIconComObject(frame)
        try ReleaseIconComObject(decoder)
    }
}

RemoveShellThumbnailMatte(pixelBuffer, width, height) {
    if !IsObject(pixelBuffer) || width <= 0 || height <= 0
        return false
    cornerOffsets := [0, (width - 1) * 4,
        (height - 1) * width * 4,
        ((height - 1) * width + width - 1) * 4]
    backgroundOffset := cornerOffsets[1]
    backgroundAlpha := 255
    for cornerOffset in cornerOffsets {
        cornerAlpha := NumGet(pixelBuffer, cornerOffset + 3, "UChar")
        if cornerAlpha < backgroundAlpha {
            backgroundAlpha := cornerAlpha
            backgroundOffset := cornerOffset
        }
    }
    ; Shell 的 SVG 缩略图会合成在半透明主题底色上。四角均接近
    ; 完全不透明时应视为图像自身背景，不能误抠除。
    if backgroundAlpha >= 250
        return false
    backgroundBlue := NumGet(pixelBuffer, backgroundOffset, "UChar")
    backgroundGreen := NumGet(pixelBuffer, backgroundOffset + 1, "UChar")
    backgroundRed := NumGet(pixelBuffer, backgroundOffset + 2, "UChar")
    denominator := 255 - backgroundAlpha
    Loop width * height {
        pixelOffset := (A_Index - 1) * 4
        inputAlpha := NumGet(pixelBuffer, pixelOffset + 3, "UChar")
        outputAlpha := Max(0, Min(255,
            Round((inputAlpha - backgroundAlpha) * 255 / denominator)))
        inverseAlpha := 255 - outputAlpha
        outputBlue := Max(0, Min(outputAlpha,
            Round(NumGet(pixelBuffer, pixelOffset, "UChar")
                - backgroundBlue * inverseAlpha / 255)))
        outputGreen := Max(0, Min(outputAlpha,
            Round(NumGet(pixelBuffer, pixelOffset + 1, "UChar")
                - backgroundGreen * inverseAlpha / 255)))
        outputRed := Max(0, Min(outputAlpha,
            Round(NumGet(pixelBuffer, pixelOffset + 2, "UChar")
                - backgroundRed * inverseAlpha / 255)))
        NumPut("UChar", outputBlue, pixelBuffer, pixelOffset)
        NumPut("UChar", outputGreen, pixelBuffer, pixelOffset + 1)
        NumPut("UChar", outputRed, pixelBuffer, pixelOffset + 2)
        NumPut("UChar", outputAlpha, pixelBuffer, pixelOffset + 3)
    }
    return true
}

ConvertSvgLengthToPixels(value, unit) {
    try value := Float(value)
    catch
        return 0
    if value <= 0
        return 0
    unit := StrLower(Trim(unit))
    switch unit {
        case "", "px": return value
        case "in": return value * 96
        case "cm": return value * 96 / 2.54
        case "mm": return value * 96 / 25.4
        case "q": return value * 96 / 101.6
        case "pt": return value * 96 / 72
        case "pc": return value * 16
    }
    ; 百分比、em、rem 等长度依赖外部布局环境，不能作为独立图标尺寸。
    return 0
}

GetSvgIntrinsicAspectRatio(filePath) {
    svgFile := 0
    try {
        svgFile := FileOpen(filePath, "r", "UTF-8")
        if !svgFile
            return 1
        ; 根元素及其尺寸通常位于文件开头；设上限避免异常大文件阻塞 UI。
        svgPrefix := svgFile.Read(131072)
    } catch {
        return 1
    } finally {
        if svgFile
            try svgFile.Close()
    }
    if !RegExMatch(svgPrefix, "is)<svg\b([^>]*)>", &rootMatch)
        return 1
    rootAttributes := rootMatch[1]
    lengthPattern := "i)\b{1}\s*=\s*[\x22']\s*"
        . "([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?)"
        . "\s*([a-z%]*)"
    width := 0
    height := 0
    if RegExMatch(rootAttributes, Format(lengthPattern, "width"),
        &widthMatch)
        width := ConvertSvgLengthToPixels(widthMatch[1], widthMatch[2])
    if RegExMatch(rootAttributes, Format(lengthPattern, "height"),
        &heightMatch)
        height := ConvertSvgLengthToPixels(heightMatch[1], heightMatch[2])
    if width > 0 && height > 0
        return Max(0.01, Min(100, width / height))

    if RegExMatch(rootAttributes,
        "i)\bviewBox\s*=\s*[\x22']\s*([^\x22']+)[\x22']",
        &viewBoxMatch) {
        viewBoxText := RegExReplace(Trim(viewBoxMatch[1]), "[,\s]+", " ")
        viewBoxParts := StrSplit(viewBoxText, " ")
        if viewBoxParts.Length == 4 {
            try viewBoxWidth := Float(viewBoxParts[3])
            catch
                viewBoxWidth := 0
            try viewBoxHeight := Float(viewBoxParts[4])
            catch
                viewBoxHeight := 0
            if viewBoxWidth > 0 && viewBoxHeight > 0
                return Max(0.01, Min(100, viewBoxWidth / viewBoxHeight))
        }
    }
    return 1
}

CopyShellBitmapPixels(bitmapObject, sourceWidth, sourceHeight,
    destinationPixels) {
    sourceBitsOffset := A_PtrSize == 8 ? 24 : 20
    sourceBits := NumGet(bitmapObject, sourceBitsOffset, "Ptr")
    sourceStride := Abs(NumGet(bitmapObject, 12, "Int"))
    dibHeaderOffset := A_PtrSize == 8 ? 32 : 24
    dibHeight := NumGet(bitmapObject, dibHeaderOffset + 8, "Int")
    if !sourceBits || sourceStride < sourceWidth * 4
        return false
    sourceIsTopDown := dibHeight < 0
    Loop sourceHeight {
        destinationRow := A_Index - 1
        sourceRow := sourceIsTopDown ? destinationRow
            : sourceHeight - destinationRow - 1
        DllCall("ntdll\RtlMoveMemory",
            "Ptr", destinationPixels.Ptr + destinationRow * sourceWidth * 4,
            "Ptr", sourceBits + sourceRow * sourceStride,
            "UPtr", sourceWidth * 4)
    }
    return true
}

GetShellThumbnailPixelSnapshot(filePath, preferredSize) {
    imageFactoryIid := Buffer(16, 0)
    if DllCall("ole32\CLSIDFromString",
        "WStr", "{BCC18B79-BA16-442F-80C4-8A59C30C463B}",
        "Ptr", imageFactoryIid, "Int") < 0
        return 0
    imageFactory := 0
    thumbnailBitmap := 0
    screenDC := 0
    try {
        if DllCall("shell32\SHCreateItemFromParsingName", "WStr", filePath,
            "Ptr", 0, "Ptr", imageFactoryIid, "Ptr*", &imageFactory,
            "Int") < 0 || !imageFactory
            return 0
        sourceSize := Max(128, Min(256, preferredSize))
        packedSize := (sourceSize & 0xFFFFFFFF)
            | ((sourceSize & 0xFFFFFFFF) << 32)
        imageFactoryVtable := NumGet(imageFactory, 0, "Ptr")
        getImage := NumGet(imageFactoryVtable, 3 * A_PtrSize, "Ptr")
        flags := Win32.SIIGBF_THUMBNAILONLY
            | Win32.SIIGBF_BIGGERSIZEOK | Win32.SIIGBF_SCALEUP
        if DllCall(getImage, "Ptr", imageFactory, "Int64", packedSize,
            "UInt", flags, "Ptr*", &thumbnailBitmap, "Int") < 0
            || !thumbnailBitmap
            return 0

        ; 读取完整 DIBSECTION，优先复制原始 Alpha。GetDIBits 会在部分
        ; Shell 缩略图上把半透明背景展平为不透明像素。
        bitmapObject := Buffer(A_PtrSize == 8 ? 104 : 84, 0)
        if !DllCall("gdi32\GetObjectW", "Ptr", thumbnailBitmap,
            "Int", bitmapObject.Size, "Ptr", bitmapObject)
            return 0
        sourceWidth := NumGet(bitmapObject, 4, "Int")
        sourceHeight := Abs(NumGet(bitmapObject, 8, "Int"))
        if sourceWidth <= 0 || sourceHeight <= 0
            return 0
        sourceInfo := Buffer(40, 0)
        NumPut("UInt", 40, sourceInfo, 0)
        NumPut("Int", sourceWidth, sourceInfo, 4)
        NumPut("Int", -sourceHeight, sourceInfo, 8)
        NumPut("UShort", 1, sourceInfo, 12)
        NumPut("UShort", 32, sourceInfo, 14)
        sourcePixels := Buffer(sourceWidth * sourceHeight * 4, 0)
        if !CopyShellBitmapPixels(bitmapObject, sourceWidth, sourceHeight,
            sourcePixels) {
            screenDC := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
            if !screenDC || !DllCall("gdi32\GetDIBits", "Ptr", screenDC,
                "Ptr", thumbnailBitmap, "UInt", 0, "UInt", sourceHeight,
                "Ptr", sourcePixels, "Ptr", sourceInfo, "UInt", 0)
                return 0
        }
        return {Width: sourceWidth, Height: sourceHeight,
            Pixels: sourcePixels}
    } finally {
        if screenDC
            try DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDC)
        if thumbnailBitmap
            try DllCall("gdi32\DeleteObject", "Ptr", thumbnailBitmap)
        try ReleaseIconComObject(imageFactory)
    }
}

CreatePixelSnapshotPaddedIcon(snapshot, iconSize, cellSize,
    desiredAspectRatio := 0) {
    if !IsObject(snapshot) || !snapshot.HasOwnProp("Width")
        || !snapshot.HasOwnProp("Height") || !snapshot.HasOwnProp("Pixels")
        || snapshot.Width <= 0 || snapshot.Height <= 0
        || !EnsureIconResampler()
        return 0
    resamplerFactory := App.iconResources.GetResamplerFactory()
    pixelFormat := Buffer(16, 0)
    if DllCall("ole32\CLSIDFromString",
        "WStr", "{6FDDC324-4E03-4BFE-B185-3D77768DC910}",
        "Ptr", pixelFormat, "Int") < 0
        return 0
    wicSource := 0
    try {
        factoryVtable := NumGet(resamplerFactory, 0, "Ptr")
        createFromMemory := NumGet(factoryVtable, 20 * A_PtrSize, "Ptr")
        if DllCall(createFromMemory, "Ptr", resamplerFactory,
            "UInt", snapshot.Width, "UInt", snapshot.Height,
            "Ptr", pixelFormat, "UInt", snapshot.Width * 4,
            "UInt", snapshot.Pixels.Size, "Ptr", snapshot.Pixels,
            "Ptr*", &wicSource, "Int") < 0 || !wicSource
            return 0
        layoutWidth := snapshot.Width
        layoutHeight := snapshot.Height
        if desiredAspectRatio > 0
            layoutWidth := layoutHeight * desiredAspectRatio
        return CreatePaddedIconFromWicSource(wicSource, layoutWidth,
            layoutHeight, iconSize, cellSize)
    } finally {
        try ReleaseIconComObject(wicSource)
    }
}

CreateShellThumbnailPaddedIcon(filePath, iconSize, cellSize,
    desiredAspectRatio := 0) {
    snapshot := GetShellThumbnailPixelSnapshot(filePath,
        Max(128, Min(256, iconSize * 4)))
    if !snapshot
        return 0
    RemoveShellThumbnailMatte(snapshot.Pixels, snapshot.Width,
        snapshot.Height)
    return CreatePixelSnapshotPaddedIcon(snapshot, iconSize, cellSize,
        desiredAspectRatio)
}

CreateSvgBackdropVariant(svgText, backgroundColor) {
    background := '<rect x="-10%" y="-10%" width="120%" height="120%" '
        . 'style="fill:#' backgroundColor
        . '!important;stroke:none!important;opacity:1!important"/>'
    variant := RegExReplace(svgText, "is)(<svg\b[^>]*>)",
        "$1" background, &replacementCount, 1)
    return replacementCount == 1 ? variant : ""
}

IsShellMatteCandidate(blackPixels, whitePixels, offset,
    blackReference, whiteReference) {
    if Abs(NumGet(blackPixels, offset, "UChar") - blackReference[1]) > 10
        || Abs(NumGet(blackPixels, offset + 1, "UChar")
            - blackReference[2]) > 10
        || Abs(NumGet(blackPixels, offset + 2, "UChar")
            - blackReference[3]) > 10
        || Abs(NumGet(whitePixels, offset, "UChar")
            - whiteReference[1]) > 10
        || Abs(NumGet(whitePixels, offset + 1, "UChar")
            - whiteReference[2]) > 10
        || Abs(NumGet(whitePixels, offset + 2, "UChar")
            - whiteReference[3]) > 10
        return false
    return Abs(NumGet(whitePixels, offset, "UChar")
            - NumGet(blackPixels, offset, "UChar"))
        + Abs(NumGet(whitePixels, offset + 1, "UChar")
            - NumGet(blackPixels, offset + 1, "UChar"))
        + Abs(NumGet(whitePixels, offset + 2, "UChar")
            - NumGet(blackPixels, offset + 2, "UChar")) <= 12
}

BuildShellMatteMask(blackSnapshot, whiteSnapshot) {
    width := blackSnapshot.Width
    height := blackSnapshot.Height
    pixelCount := width * height
    matteMask := Buffer(pixelCount, 0)
    blackReference := [
        NumGet(blackSnapshot.Pixels, 0, "UChar"),
        NumGet(blackSnapshot.Pixels, 1, "UChar"),
        NumGet(blackSnapshot.Pixels, 2, "UChar")]
    whiteReference := [
        NumGet(whiteSnapshot.Pixels, 0, "UChar"),
        NumGet(whiteSnapshot.Pixels, 1, "UChar"),
        NumGet(whiteSnapshot.Pixels, 2, "UChar")]
    queue := []
    enqueueCandidate := (pixelIndex) => (
        pixelIndex >= 0 && pixelIndex < pixelCount
        && !NumGet(matteMask, pixelIndex, "UChar")
        && IsShellMatteCandidate(blackSnapshot.Pixels,
            whiteSnapshot.Pixels, pixelIndex * 4,
            blackReference, whiteReference)
        ? (NumPut("UChar", 1, matteMask, pixelIndex),
            queue.Push(pixelIndex))
        : 0)
    Loop width {
        x := A_Index - 1
        enqueueCandidate(x)
        enqueueCandidate((height - 1) * width + x)
    }
    Loop height {
        y := A_Index - 1
        enqueueCandidate(y * width)
        enqueueCandidate(y * width + width - 1)
    }
    queueIndex := 1
    while queueIndex <= queue.Length {
        pixelIndex := queue[queueIndex++]
        x := Mod(pixelIndex, width)
        if x > 0
            enqueueCandidate(pixelIndex - 1)
        if x + 1 < width
            enqueueCandidate(pixelIndex + 1)
        if pixelIndex >= width
            enqueueCandidate(pixelIndex - width)
        if pixelIndex + width < pixelCount
            enqueueCandidate(pixelIndex + width)
    }
    return matteMask
}

RecoverSvgPixelsFromBackdrops(blackSnapshot, whiteSnapshot) {
    if !IsObject(blackSnapshot) || !IsObject(whiteSnapshot)
        || blackSnapshot.Width != whiteSnapshot.Width
        || blackSnapshot.Height != whiteSnapshot.Height
        return ""
    width := blackSnapshot.Width
    height := blackSnapshot.Height
    changedPixels := 0
    Loop width * height {
        offset := (A_Index - 1) * 4
        difference := Abs(NumGet(blackSnapshot.Pixels,
            offset, "UChar") - NumGet(whiteSnapshot.Pixels,
            offset, "UChar"))
            + Abs(NumGet(blackSnapshot.Pixels,
                offset + 1, "UChar") - NumGet(whiteSnapshot.Pixels,
                offset + 1, "UChar"))
            + Abs(NumGet(blackSnapshot.Pixels,
                offset + 2, "UChar") - NumGet(whiteSnapshot.Pixels,
                offset + 2, "UChar"))
        if difference >= 60
            changedPixels++
    }
    ; 有些 Shell SVG 处理器会无视文件内容，始终返回白页类型图标。
    ; 黑白底派生文件若连 5% 像素都没有明显变化，得到的不是 SVG 渲染。
    if changedPixels < Max(16, Floor(width * height * 0.05))
        return ""
    recoveredPixels := Buffer(width * height * 4, 0)
    matteMask := BuildShellMatteMask(blackSnapshot, whiteSnapshot)
    Loop width * height {
        pixelIndex := A_Index - 1
        if NumGet(matteMask, pixelIndex, "UChar")
            continue
        offset := pixelIndex * 4
        blackBlue := NumGet(blackSnapshot.Pixels, offset, "UChar")
        blackGreen := NumGet(blackSnapshot.Pixels, offset + 1, "UChar")
        blackRed := NumGet(blackSnapshot.Pixels, offset + 2, "UChar")
        whiteBlue := NumGet(whiteSnapshot.Pixels, offset, "UChar")
        whiteGreen := NumGet(whiteSnapshot.Pixels, offset + 1, "UChar")
        whiteRed := NumGet(whiteSnapshot.Pixels, offset + 2, "UChar")
        inverseAlpha := Round((Max(0, whiteBlue - blackBlue)
            + Max(0, whiteGreen - blackGreen)
            + Max(0, whiteRed - blackRed)) / 3)
        alpha := Max(0, Min(255, 255 - inverseAlpha))
        if alpha <= 3
            continue
        if alpha >= 252
            alpha := 255
        NumPut("UChar", Min(alpha, blackBlue), recoveredPixels, offset)
        NumPut("UChar", Min(alpha, blackGreen), recoveredPixels, offset + 1)
        NumPut("UChar", Min(alpha, blackRed), recoveredPixels, offset + 2)
        NumPut("UChar", alpha, recoveredPixels, offset + 3)
    }
    return {Width: width, Height: height, Pixels: recoveredPixels}
}

CreateShellSvgPaddedIcon(filePath, iconSize, cellSize) {
    try {
        if FileGetSize(filePath) > 16 * 1024 * 1024
            return 0
        svgText := FileRead(filePath, "UTF-8")
    } catch {
        return 0
    }
    ; 派生图像使用不透明黑白底渲染。两次结果的通道差可恢复原始
    ; Alpha，避免 Shell 对透明 SVG 叠加随位置变化的深色主题底纹。
    blackVariant := CreateSvgBackdropVariant(svgText, "000000")
    whiteVariant := CreateSvgBackdropVariant(svgText, "FFFFFF")
    if blackVariant == "" || whiteVariant == ""
        return 0
    uniqueSuffix := DllCall("kernel32\GetCurrentProcessId", "UInt") "-"
        . A_TickCount "-" Random(100000, 999999)
    blackPath := A_Temp "\watchdog-svg-black-" uniqueSuffix ".svg"
    whitePath := A_Temp "\watchdog-svg-white-" uniqueSuffix ".svg"
    try {
        FileAppend(blackVariant, blackPath, "UTF-8-RAW")
        FileAppend(whiteVariant, whitePath, "UTF-8-RAW")
        preferredSize := Max(128, Min(256, iconSize * 4))
        blackSnapshot := GetShellThumbnailPixelSnapshot(blackPath,
            preferredSize)
        whiteSnapshot := GetShellThumbnailPixelSnapshot(whitePath,
            preferredSize)
        recoveredSnapshot := RecoverSvgPixelsFromBackdrops(blackSnapshot,
            whiteSnapshot)
        if !recoveredSnapshot
            return 0
        return CreatePixelSnapshotPaddedIcon(recoveredSnapshot, iconSize,
            cellSize, GetSvgIntrinsicAspectRatio(filePath))
    } finally {
        try FileDelete(blackPath)
        try FileDelete(whitePath)
    }
}

CreateSvgPaddedIcon(filePath, iconSize, cellSize, useStatusQuality := false) {
    ; 状态图标使用更高的超采样倍率后再由 WIC Fant 缩小，可显著改善
    ; 小尺寸圆弧和斜边；普通自定义 SVG 保持原开销，避免大量导入时变慢。
    renderSize := useStatusQuality
        ? Max(256, Min(512, iconSize * 8))
        : Max(128, Min(256, iconSize * 4))
    snapshot := App.svgRenderer.RenderFile(filePath,
        App.iconResources.MainDpi, renderSize)
    if snapshot {
        renderedIcon := CreatePixelSnapshotPaddedIcon(snapshot,
            iconSize, cellSize)
        if renderedIcon
            return renderedIcon
    }
    ; DLL 缺失、加载失败或 SVG 无法解析时，仍允许系统缩略图处理器
    ; 提供后备结果；该路径不会启动浏览器或写入中间 PNG。
    return CreateShellSvgPaddedIcon(filePath, iconSize, cellSize)
}

CreateAnimatedCursorPaddedIcon(filePath, iconSize, cellSize) {
    cursorHandle := 0
    paddedIcon := 0
    try {
        sourceSize := SelectClosestIconSourceSize(iconSize)
        cursorHandle := DllCall("user32\LoadImageW", "Ptr", 0,
            "WStr", filePath, "UInt", Win32.IMAGE_CURSOR,
            "Int", sourceSize, "Int", sourceSize,
            "UInt", Win32.LR_LOADFROMFILE, "Ptr")
        if !cursorHandle
            cursorHandle := DllCall("user32\LoadCursorFromFileW",
                "WStr", filePath, "Ptr")
        if !cursorHandle
            return 0
        paddedIcon := CreateHighQualityPaddedIcon(cursorHandle,
            iconSize, cellSize)
        if !paddedIcon
            paddedIcon := CreateMaskPaddedIcon(cursorHandle,
                iconSize, cellSize)
        return paddedIcon
    } finally {
        if cursorHandle
            try DllCall("user32\DestroyCursor", "Ptr", cursorHandle)
    }
}

CreateCustomImagePaddedIcon(filePath, iconSize, cellSize) {
    filePath := ParseCustomIconSource(filePath).Path
    extension := GetCustomIconSourceExtension(filePath)
    if extension == "ani"
        return CreateAnimatedCursorPaddedIcon(filePath, iconSize, cellSize)
    if extension == "svg"
        return CreateSvgPaddedIcon(filePath, iconSize, cellSize)
    if IsRasterImageIconExtension(extension) {
        paddedIcon := CreateWicDecodedPaddedIcon(filePath,
            iconSize, cellSize, extension == "bmp")
        if paddedIcon
            return paddedIcon
        ; WebP 等格式依赖系统安装的 WIC 编解码器；Explorer 能生成真实
        ; 缩略图时仍可作为后备，但绝不回退为普通文件类型图标。
        return CreateShellThumbnailPaddedIcon(filePath, iconSize, cellSize)
    }
    return 0
}

ReleaseIconComObject(pointer) {
    if !pointer
        return
    vtable := NumGet(pointer, 0, "Ptr")
    release := NumGet(vtable, 2 * A_PtrSize, "Ptr")
    DllCall(release, "Ptr", pointer, "UInt")
}

ShutdownIconResampler(*) {
    factory := App.iconResources.TakeResamplerFactory()
    if !factory
        return
    try ReleaseIconComObject(factory)
}

CreateIconMaskFromAlpha(screenDC, colorBits, width, height) {
    maskStride := Floor((width + 31) / 32) * 4
    bitmapInfo := Buffer(48, 0)
    NumPut("UInt", 40, bitmapInfo, 0)
    NumPut("Int", width, bitmapInfo, 4)
    NumPut("Int", -height, bitmapInfo, 8)
    NumPut("UShort", 1, bitmapInfo, 12)
    NumPut("UShort", 1, bitmapInfo, 14)
    NumPut("UInt", 0x00000000, bitmapInfo, 40)
    NumPut("UInt", 0x00FFFFFF, bitmapInfo, 44)
    maskBits := 0
    maskBitmap := DllCall("gdi32\CreateDIBSection", "Ptr", screenDC,
        "Ptr", bitmapInfo, "UInt", 0, "Ptr*", &maskBits,
        "Ptr", 0, "UInt", 0, "Ptr")
    if !maskBitmap
        return 0
    if !maskBits {
        DllCall("gdi32\DeleteObject", "Ptr", maskBitmap)
        return 0
    }

    Loop maskStride * height
        NumPut("UChar", 0xFF, maskBits, A_Index - 1)
    Loop height {
        y := A_Index - 1
        Loop width {
            x := A_Index - 1
            alpha := NumGet(colorBits, (y * width + x) * 4 + 3, "UChar")
            if alpha > 8 {
                byteOffset := y * maskStride + (x >> 3)
                bitMask := 0x80 >> (x & 7)
                value := NumGet(maskBits, byteOffset, "UChar")
                NumPut("UChar", value & ~bitMask, maskBits, byteOffset)
            }
        }
    }
    return maskBitmap
}

StatusIconResourceFiles() {
    static resourceFiles := Map(
        "Running", "running.svg",
        "Paused", "paused.svg",
        "Warning", "warning.svg",
        "SuspectedStop", "suspected-stop.svg",
        "Error", "error.svg",
        "Pending", "pending.svg",
        "Countdown", "countdown.svg",
        "Updating", "updating.svg",
        "Idle", "idle.svg"
    )
    return resourceFiles
}

GetStatusIconResourcePath(statusKind) {
    resourceFiles := StatusIconResourceFiles()
    if !resourceFiles.Has(statusKind)
        return ""
    resourceName := resourceFiles[statusKind]
    ; A_LineFile 在主脚本被测试入口 Include 时会指向测试脚本，不能作为
    ; 资源根目录。依次覆盖正式运行、子目录入口和 tests\core 入口。
    for relativeRoot in ["", "\..", "\..\.."] {
        candidatePath := A_ScriptDir relativeRoot
            . "\assets\status-icons\" resourceName
        if FileExist(candidatePath)
            return candidatePath
    }
    return A_ScriptDir "\assets\status-icons\" resourceName
}

CreateStatusResourceIcon(statusKind, glyphSize, cellSize) {
    resourcePath := GetStatusIconResourcePath(statusKind)
    if resourcePath == "" || !FileExist(resourcePath)
        return 0
    ; 状态图标全部来自随项目分发的 SVG 资源。CreateSvgPaddedIcon 只负责
    ; 使用 resvg/WIC 解码、缩放和居中，不再在运行时计算任何图标几何。
    return CreateSvgPaddedIcon(resourcePath, glyphSize, cellSize, true)
}

StatusIconVisualScale(statusKind) {
    ; 相同最大边长下，圆形、八边形和三角形的视觉面积明显小于方形。
    ; 这里仅补偿外部容器的视觉尺寸；SVG 内部仍独立保留语义符号的安全边距。
    static visualScales := Map(
        "Running", 1.00,
        "Paused", 1.10,
        "Warning", 1.10,
        "SuspectedStop", 1.16,
        "Error", 1.10,
        "Pending", 1.10,
        "Countdown", 1.10,
        "Updating", 1.10,
        "Idle", 1.10)
    return visualScales.Has(statusKind) ? visualScales[statusKind] : 1.00
}

AddMainStatusIcons(imageList, statusIconIndices) {
    statusIconIndices.Clear()
    iconResources := App.iconResources
    glyphSize := Max(16, Round(20 * iconResources.MainDpi / 96))
    for statusKind, resourceFile in StatusIconResourceFiles() {
        visualSize := Min(iconResources.MainIconCellPixelSize - 2,
            Round(glyphSize * StatusIconVisualScale(statusKind)))
        statusIcon := CreateStatusResourceIcon(statusKind, visualSize,
            iconResources.MainIconCellPixelSize)
        try iconIndex := statusIcon
                ? IL_Add(imageList, "HICON:" statusIcon)
                : 0
        finally {
            if statusIcon
                try DllCall("user32\DestroyIcon", "Ptr", statusIcon)
        }
        statusIconIndices[statusKind] := iconIndex
    }
}

CreateHighQualityPaddedIcon(hIcon, iconSize, cellSize) {
    if !hIcon || !EnsureIconResampler()
        return 0
    resamplerFactory := App.iconResources.GetResamplerFactory()
    if !resamplerFactory
        return 0

    iconInfo := Buffer(A_PtrSize == 8 ? 32 : 20, 0)
    if !DllCall("user32\GetIconInfo", "Ptr", hIcon, "Ptr", iconInfo)
        return 0
    bitmapOffset := A_PtrSize == 8 ? 16 : 12
    sourceMaskBitmap := NumGet(iconInfo, bitmapOffset, "Ptr")
    sourceColorBitmap := NumGet(iconInfo, bitmapOffset + A_PtrSize, "Ptr")
    screenDC := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
    wicSource := 0
    wicScaler := 0
    targetColorBitmap := 0
    targetMaskBitmap := 0
    try {
        if !sourceColorBitmap || !screenDC
            return 0
        bitmapObject := Buffer(A_PtrSize == 8 ? 32 : 24, 0)
        if !DllCall("gdi32\GetObjectW", "Ptr", sourceColorBitmap,
            "Int", bitmapObject.Size, "Ptr", bitmapObject)
            return 0
        sourceWidth := NumGet(bitmapObject, 4, "Int")
        sourceHeight := Abs(NumGet(bitmapObject, 8, "Int"))
        if sourceWidth <= 0 || sourceHeight <= 0
            return 0

        sourceInfo := Buffer(40, 0)
        NumPut("UInt", 40, sourceInfo, 0)
        NumPut("Int", sourceWidth, sourceInfo, 4)
        NumPut("Int", -sourceHeight, sourceInfo, 8)
        NumPut("UShort", 1, sourceInfo, 12)
        NumPut("UShort", 32, sourceInfo, 14)
        sourcePixels := Buffer(sourceWidth * sourceHeight * 4, 0)
        if !DllCall("gdi32\GetDIBits", "Ptr", screenDC,
            "Ptr", sourceColorBitmap, "UInt", 0, "UInt", sourceHeight,
            "Ptr", sourcePixels, "Ptr", sourceInfo, "UInt", 0)
            return 0
        hasAlphaChannel := false
        Loop sourceWidth * sourceHeight {
            if NumGet(sourcePixels, (A_Index - 1) * 4 + 3, "UChar") {
                hasAlphaChannel := true
                break
            }
        }
        ; 旧式图标只用 AND mask，没有有效 Alpha；交给 mask 路径，避免透明或黑底。
        if !hasAlphaChannel
            return 0
        sourcePixelFormat := Buffer(16, 0)
        if DllCall("ole32\CLSIDFromString",
            "WStr", "{6FDDC324-4E03-4BFE-B185-3D77768DC910}",
            "Ptr", sourcePixelFormat, "Int") < 0
            return 0
        factoryVtable := NumGet(resamplerFactory, 0, "Ptr")
        createFromMemory := NumGet(factoryVtable, 20 * A_PtrSize, "Ptr")
        if DllCall(createFromMemory, "Ptr", resamplerFactory,
            "UInt", sourceWidth, "UInt", sourceHeight, "Ptr", sourcePixelFormat,
            "UInt", sourceWidth * 4, "UInt", sourcePixels.Size,
            "Ptr", sourcePixels, "Ptr*", &wicSource, "Int") < 0
            return 0
        createScaler := NumGet(factoryVtable, 11 * A_PtrSize, "Ptr")
        if DllCall(createScaler, "Ptr", resamplerFactory,
            "Ptr*", &wicScaler, "Int") < 0 || !wicScaler
            return 0
        scalerVtable := NumGet(wicScaler, 0, "Ptr")
        initializeScaler := NumGet(scalerVtable, 8 * A_PtrSize, "Ptr")
        scaledWidth := iconSize
        scaledHeight := iconSize
        if DllCall(initializeScaler, "Ptr", wicScaler, "Ptr", wicSource,
            "UInt", scaledWidth, "UInt", scaledHeight, "Int", 3, "Int") < 0
            return 0
        scaledPixels := Buffer(scaledWidth * scaledHeight * 4, 0)
        copyPixels := NumGet(scalerVtable, 7 * A_PtrSize, "Ptr")
        if DllCall(copyPixels, "Ptr", wicScaler, "Ptr", 0,
            "UInt", scaledWidth * 4, "UInt", scaledPixels.Size,
            "Ptr", scaledPixels, "Int") < 0
            return 0

        targetInfo := Buffer(40, 0)
        NumPut("UInt", 40, targetInfo, 0)
        NumPut("Int", cellSize, targetInfo, 4)
        NumPut("Int", -cellSize, targetInfo, 8)
        NumPut("UShort", 1, targetInfo, 12)
        NumPut("UShort", 32, targetInfo, 14)
        targetBits := 0
        targetColorBitmap := DllCall("gdi32\CreateDIBSection", "Ptr", screenDC,
            "Ptr", targetInfo, "UInt", 0, "Ptr*", &targetBits,
            "Ptr", 0, "UInt", 0, "Ptr")
        if !targetColorBitmap || !targetBits
            return 0
        offsetX := Floor((cellSize - scaledWidth) / 2)
        offsetY := Floor((cellSize - scaledHeight) / 2)
        Loop scaledHeight {
            row := A_Index - 1
            destination := targetBits
                + ((offsetY + row) * cellSize + offsetX) * 4
            source := scaledPixels.Ptr + row * scaledWidth * 4
            DllCall("ntdll\RtlMoveMemory", "Ptr", destination,
                "Ptr", source, "UPtr", scaledWidth * 4)
        }
        targetMaskBitmap := CreateIconMaskFromAlpha(screenDC,
            targetBits, cellSize, cellSize)
        if !targetMaskBitmap
            return 0

        outputInfo := Buffer(A_PtrSize == 8 ? 32 : 20, 0)
        NumPut("Int", 1, outputInfo, 0)
        NumPut("Ptr", targetMaskBitmap, outputInfo, bitmapOffset)
        NumPut("Ptr", targetColorBitmap, outputInfo, bitmapOffset + A_PtrSize)
        return DllCall("user32\CreateIconIndirect", "Ptr", outputInfo, "Ptr")
    } finally {
        try ReleaseIconComObject(wicScaler)
        try ReleaseIconComObject(wicSource)
        if targetMaskBitmap
            try DllCall("gdi32\DeleteObject", "Ptr", targetMaskBitmap)
        if targetColorBitmap
            try DllCall("gdi32\DeleteObject", "Ptr", targetColorBitmap)
        if sourceMaskBitmap
            try DllCall("gdi32\DeleteObject", "Ptr", sourceMaskBitmap)
        if sourceColorBitmap
            try DllCall("gdi32\DeleteObject", "Ptr", sourceColorBitmap)
        if screenDC
            try DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDC)
    }
}

CreateMaskPaddedIcon(hIcon, iconSize, cellSize) {
    if !hIcon || iconSize <= 0 || cellSize < iconSize
        return 0
    screenDC := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
    colorDC := 0
    maskDC := 0
    colorBitmap := 0
    maskBitmap := 0
    previousColorBitmap := 0
    previousMaskBitmap := 0
    try {
        colorDC := DllCall("gdi32\CreateCompatibleDC", "Ptr", screenDC, "Ptr")
        maskDC := DllCall("gdi32\CreateCompatibleDC", "Ptr", screenDC, "Ptr")
        bitmapInfo := Buffer(40, 0)
        NumPut("UInt", 40, bitmapInfo, 0)
        NumPut("Int", cellSize, bitmapInfo, 4)
        NumPut("Int", -cellSize, bitmapInfo, 8)
        NumPut("UShort", 1, bitmapInfo, 12)
        NumPut("UShort", 32, bitmapInfo, 14)
        bits := 0
        colorBitmap := DllCall("gdi32\CreateDIBSection", "Ptr", screenDC,
            "Ptr", bitmapInfo, "UInt", 0, "Ptr*", &bits,
            "Ptr", 0, "UInt", 0, "Ptr")
        maskBitmap := DllCall("gdi32\CreateBitmap", "Int", cellSize,
            "Int", cellSize, "UInt", 1, "UInt", 1, "Ptr", 0, "Ptr")
        if !colorDC || !maskDC || !colorBitmap || !maskBitmap || !bits
            return 0
        previousColorBitmap := DllCall("gdi32\SelectObject", "Ptr", colorDC,
            "Ptr", colorBitmap, "Ptr")
        previousMaskBitmap := DllCall("gdi32\SelectObject", "Ptr", maskDC,
            "Ptr", maskBitmap, "Ptr")
        DllCall("ntdll\RtlZeroMemory", "Ptr", bits,
            "UPtr", cellSize * cellSize * 4)
        DllCall("gdi32\PatBlt", "Ptr", maskDC, "Int", 0, "Int", 0,
            "Int", cellSize, "Int", cellSize, "UInt", 0x00FF0062)
        offset := Floor((cellSize - iconSize) / 2)
        DllCall("user32\DrawIconEx", "Ptr", colorDC, "Int", offset,
            "Int", offset, "Ptr", hIcon, "Int", iconSize, "Int", iconSize,
            "UInt", 0, "Ptr", 0, "UInt", 0x0003)
        DllCall("user32\DrawIconEx", "Ptr", maskDC, "Int", offset,
            "Int", offset, "Ptr", hIcon, "Int", iconSize, "Int", iconSize,
            "UInt", 0, "Ptr", 0, "UInt", 0x0001)
        iconInfo := Buffer(A_PtrSize == 8 ? 32 : 20, 0)
        NumPut("Int", 1, iconInfo, 0)
        bitmapOffset := A_PtrSize == 8 ? 16 : 12
        NumPut("Ptr", maskBitmap, iconInfo, bitmapOffset)
        NumPut("Ptr", colorBitmap, iconInfo, bitmapOffset + A_PtrSize)
        return DllCall("user32\CreateIconIndirect", "Ptr", iconInfo, "Ptr")
    } finally {
        if previousColorBitmap && previousColorBitmap != -1
            try DllCall("gdi32\SelectObject", "Ptr", colorDC,
                "Ptr", previousColorBitmap)
        if previousMaskBitmap && previousMaskBitmap != -1
            try DllCall("gdi32\SelectObject", "Ptr", maskDC,
                "Ptr", previousMaskBitmap)
        if colorBitmap
            try DllCall("gdi32\DeleteObject", "Ptr", colorBitmap)
        if maskBitmap
            try DllCall("gdi32\DeleteObject", "Ptr", maskBitmap)
        if colorDC
            try DllCall("gdi32\DeleteDC", "Ptr", colorDC)
        if maskDC
            try DllCall("gdi32\DeleteDC", "Ptr", maskDC)
        if screenDC
            try DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDC)
    }
}

AddIconToImageList(imageList, hIcon, useHighQualityResampling := false) {
    if !hIcon
        return 0
    paddedIcon := 0
    if imageList == Main.appIcons {
        iconResources := App.iconResources
        if useHighQualityResampling
            try paddedIcon := CreateHighQualityPaddedIcon(hIcon,
                iconResources.MainIconPixelSize,
                iconResources.MainIconCellPixelSize)
        if !paddedIcon
            paddedIcon := CreateMaskPaddedIcon(hIcon,
                iconResources.MainIconPixelSize,
                iconResources.MainIconCellPixelSize)
    }
    iconToAdd := paddedIcon ? paddedIcon : hIcon
    try return IL_Add(imageList, "HICON:" iconToAdd)
    finally {
        if paddedIcon
            try DllCall("user32\DestroyIcon", "Ptr", paddedIcon)
    }
}

FormatMainListLabel(name, isAdmin := false) {
    ; NBSP 不参与中西文断行规则，可稳定补充少量图文间距且保持名称左侧对齐。
    return Chr(0x00A0) name . (isAdmin ? " 🛡️" : "")
}

GetDefaultMainDisplayName(path) {
    SplitPath(path, , , , &nameNoExt)
    return nameNoExt != "" ? nameNoExt : path
}

GetMainDisplayName(path, stateObj := "") {
    if stateObj && stateObj.HasOwnProp("DisplayConfig") {
        displayName := Trim(stateObj.DisplayConfig.Name)
        if (displayName != "")
            return displayName
    }
    return GetDefaultMainDisplayName(path)
}

GetMainDisplayIconSource(path, stateObj := "") {
    if stateObj && stateObj.HasOwnProp("DisplayConfig") {
        iconPath := stateObj.DisplayConfig.IconPath
        if (iconPath != "" && CustomIconSourceExists(iconPath))
            return iconPath
    }
    return path
}

AcquireMainImageListUse(imageList) {
    return App.iconResources.AcquireMainImageList(imageList,
        Main.appIcons)
}

ReleaseMainImageListUse(imageList) {
    if App.iconResources.ReleaseMainImageList(imageList) {
        ClearImageListIconCache(imageList)
        try IL_Destroy(imageList)
    }
}

RetireMainImageList(imageList) {
    if App.iconResources.RetireMainImageList(imageList, Main.appIcons) {
        ClearImageListIconCache(imageList)
        try IL_Destroy(imageList)
    }
}

IsMainImageListTracked(imageList) {
    return App.iconResources.IsMainImageListTracked(imageList,
        Main.appIcons)
}

GetMainListIconIndex(path, stateObj, imageList) {
    imageList := AcquireMainImageListUse(imageList)
    if !imageList
        return 0
    try return GetFileIconIndex(GetMainDisplayIconSource(path, stateObj),
        imageList)
    finally ReleaseMainImageListUse(imageList)
}

RefreshMainListDisplay(path) {
    if !App.appStates.Has(path)
        return false
    row := FindRow(path)
    if !row
        return false
    stateObj := App.appStates[path]
    Main.lv.Modify(row, "Col1", FormatMainListLabel(
        GetMainDisplayName(path, stateObj), stateObj.RunAsAdmin))
    iconIndex := GetMainListIconIndex(path, stateObj, Main.lv.IL)
    if iconIndex
        Main.lv.Modify(row, "Icon" iconIndex)
    return true
}

NormalizeUserVisibleParentheses(text) {
    ; 中文界面不保留“空格 + 半角括号”的英文排版痕迹。
    return RegExReplace(String(text), "\h+\(([^()\r\n]*)\)", "（$1）")
}

FormatMainStatusLabel(statusText) {
    ; 原生 ListView 会把 Emoji 回退为单色字形，状态色改由真彩图标槽呈现。
    label := RegExReplace(statusText,
        "^(?:✅|❌|⚠|⏸|⏳|🔄|🚀)\x{FE0F}?\h*", "")
    return NormalizeUserVisibleParentheses(label)
}

GetMainStatusVisualKind(statusText) {
    label := FormatMainStatusLabel(statusText)
    if InStr(label, "不存在") || InStr(label, "失败")
        || InStr(label, "无法停止")
        return "Error"
    if InStr(label, "疑似停止")
        return "SuspectedStop"
    if InStr(label, "倒计时")
        return "Countdown"
    if InStr(label, "超时") || InStr(label, "权限不符")
        || InStr(label, "已停止")
        return "Warning"
    if InStr(label, "暂停")
        return "Paused"
    if InStr(label, "运行中") || InStr(label, "已启动")
        return "Running"
    if InStr(label, "升级") || InStr(label, "程序文件")
        return "Updating"
    if InStr(label, "初始化")
        return "Idle"
    return "Pending"
}

SetMainListSubItemIcon(row, iconIndex) {
    if (row < 1 || !Main.lv)
        return false
    listItem := Buffer(A_PtrSize == 8 ? 88 : 60, 0)
    NumPut("UInt", Win32.LVIF_IMAGE, listItem, 0)
    NumPut("Int", row - 1, listItem, 4)
    NumPut("Int", 1, listItem, 8) ; 状态列的零基子项索引
    NumPut("Int", iconIndex > 0 ? iconIndex - 1 : -1,
        listItem, A_PtrSize == 8 ? 36 : 28)
    return SendMessage(Win32.LVM_SETITEMW, 0,
        listItem.Ptr, Main.lv.Hwnd) != 0
}

SetMainListStatus(row, statusText) {
    if (row < 1 || row > Main.lv.GetCount())
        return
    Main.lv.Modify(row, "Col2", FormatMainStatusLabel(statusText))
    statusKind := GetMainStatusVisualKind(statusText)
    iconIndex := Main.HasOwnProp("statusIconIndices")
        && Main.statusIconIndices.Has(statusKind)
        ? Main.statusIconIndices[statusKind]
        : 0
    SetMainListSubItemIcon(row, iconIndex)
}

ApplyDarkListViewTheme(hLV) {
    ; 通过 SetWindowTheme 和 AllowDarkModeForWindow 将 ListView 及其滚动条设定为暗黑样式
    if !DllCall("user32\IsWindow", "Ptr", hLV, "Int")
        return
    if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
        try {
            uxtheme := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
            if (uxtheme) {
                AllowDarkModeForWindow := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 133, "Ptr")
                if AllowDarkModeForWindow
                    DllCall(AllowDarkModeForWindow, "Ptr", hLV, "Int", 1)
            }
        }
        try DllCall("uxtheme\SetWindowTheme", "Ptr", hLV, "Str", "DarkMode_Explorer", "Ptr", 0)
        hHeader := SendMessage(0x101F, 0, 0, hLV) ; 获取子组件 header 字段栏
        if (hHeader) {
            try {
                uxtheme := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
                if (uxtheme) {
                    AllowDarkModeForWindow := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 133, "Ptr")
                    if AllowDarkModeForWindow
                        DllCall(AllowDarkModeForWindow, "Ptr", hHeader, "Int", 1)
                }
            }
            try DllCall("uxtheme\SetWindowTheme", "Ptr", hHeader, "Str", "DarkMode_ItemsView", "Ptr", 0)
            try DllCall("user32\InvalidateRect", "Ptr", hHeader, "Ptr", 0, "Int", 1)
        }
    }
    try DllCall("user32\InvalidateRect", "Ptr", hLV, "Ptr", 0, "Int", 1)
}

SetDarkControl(hCtrl) {
    if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
        try {
            uxtheme := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
            if (uxtheme) {
                AllowDarkModeForWindow := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 133, "Ptr")
                if AllowDarkModeForWindow
                    DllCall(AllowDarkModeForWindow, "Ptr", hCtrl, "Int", 1)
            }
        }
        try DllCall("uxtheme\SetWindowTheme", "Ptr", hCtrl, "Str", "DarkMode_Explorer", "Ptr", 0)
    }
}

AddCenteredSingleLineEdit(guiObj, x, y, width, outerHeight, value := "", extraOptions := "", backgroundColor := "252526") {
    innerHeight := Max(18, outerHeight - 6)
    innerY := y + Floor((outerHeight - innerHeight) / 2)
    background := guiObj.Add("Text", "x" x " y" y " w" width " h" outerHeight " Background" backgroundColor)
    editOptions := "x" x " y" innerY " w" width " h" innerHeight " Background" backgroundColor " cWhite -E0x200"
    if extraOptions
        editOptions .= " " extraOptions
    inputEditControl := guiObj.Add("Edit", editOptions, value)
    RegisterTextInputControl(inputEditControl)
    RegisterTextInputHitTarget(background, inputEditControl)
    return {Background: background, Edit: inputEditControl}
}

ShowSingleLineEditFromStart(inputControl) {
    try textEditHwnd := inputControl.Hwnd
    catch
        return
    if !textEditHwnd || !DllCall("user32\IsWindow", "Ptr", textEditHwnd, "Int")
        return
    SendMessage(Win32.EM_SETSEL, 0, 0, textEditHwnd)
    SendMessage(Win32.EM_SCROLLCARET, 0, 0, textEditHwnd)
}

; ==========================================
; 6. 自定义系统托盘菜单
; ==========================================
A_IconTip := "进程守护小助手"
A_TrayMenu.Delete()
A_TrayMenu.Add("显示主界面", ShowMainGui)
A_TrayMenu.Add("重新加载", ReloadScript)
A_TrayMenu.Add("退出程序", ExitProgram)
A_TrayMenu.Default := "显示主界面"
A_TrayMenu.ClickCount := 1

; ==========================================
; 7. 构建主 GUI 界面 (支持复选框和直接编辑)
; ==========================================
SetDarkTitleBar(Main.gui.Hwnd)
SetWindowIcon(Main.gui.Hwnd, A_ScriptDir "\watchdog.ico")
Main.gui.BackColor := "1E1E1E"
Main.gui.SetFont("s10 cWhite", "Microsoft YaHei")

; 初始化主窗口界面的控制按钮并分配大小与间距
Main.btnAdd  := Main.gui.Add("Text", "x10 y15 w80 h30 Center 0x200 Background3F6B5B cWhite", "➕ 添加")



Main.btnDel  := Main.gui.Add("Text", "x+10 y15 w80 h30 Center 0x200 Background4C4A4A cB8BAB9", "🗑️ 删除")
Main.btnPause:= Main.gui.Add("Text", "x+10 y15 w80 h30 Center 0x200 Background4C4B49 cB8BAB9", "⏸️ 暂停")

    btnSetX := App.savedWidth > 730 ? App.savedWidth - 240 : 730 - 240
    btnHelpX := App.savedWidth > 730 ? App.savedWidth - 160 : 730 - 160
    btnLogX := App.savedWidth > 730 ? App.savedWidth - 80 : 730 - 80

Main.btnSet  := Main.gui.Add("Text", "x" btnSetX " y15 w70 h30 Center 0x200 Background333333 cWhite", "⚙️ 设置")
Main.btnHelp := Main.gui.Add("Text", "x" btnHelpX " y15 w70 h30 Center 0x200 Background333333 cWhite", "📖 帮助")
Main.btnLog  := Main.gui.Add("Text", "x" btnLogX " y15 w70 h30 Center 0x200 Background333333 cWhite", "📋 日志")
RegisterHoverButton(Main.btnAdd, "3F6B5B")
RegisterHoverButton(Main.btnDel, "4C4A4A", "4C4A4A", "", "B8BAB9")
RegisterHoverButton(Main.btnPause, "4C4B49", "4C4B49", "", "B8BAB9")
RegisterHoverButton(Main.btnSet, "333333")
RegisterHoverButton(Main.btnHelp, "333333")
RegisterHoverButton(Main.btnLog, "333333")
; 主列表统一使用 28px 逻辑尺寸，并按窗口 DPI 缩放。
Main.appIcons := CreateMainImageList(Main.statusIconIndices)

Main.gui.SetFont("s12 cWhite", "Microsoft YaHei") ; 将ListView专用字体字号放大为12

; 设置基础 ListView 参数，隐藏表头并添加路径辅助列 (移除 -Multi 允许支持 Ctrl/Shift 多选)
    Main.lv := Main.gui.Add("ListView", "x10 y+15 w" (App.savedWidth-20) " h" (App.savedHeight-85) " Background252526 cWhite Report +LV0x10002 -E0x200 +ReadOnly -HScroll -Hdr", ["应用程序", "状态", "完整路径"])
Main.lv.SetImageList(Main.appIcons, 1) ; 【修复】必须强制指定参数 1 (小图标槽位)，否则 32x32 列表会被底层自动错误分配给大图标视图，导致列表(Report)里隐形！
Main.lv.IL := Main.appIcons

Main.gui.SetFont("s10 cWhite", "Microsoft YaHei") ; 将Gui上下文切回10号字，防止影响后续弹窗

Main.lv.ModifyCol(1, App.savedColumn1)
Main.lv.ModifyCol(2, App.savedColumn2)
Main.lv.ModifyCol(3, 0) ; 隐藏路径辅助列

SetDarkListView(Main.lv.Hwnd)

Main.statsText := Main.gui.Add("Text", "x10 y+5 w" (App.savedWidth-20) " h20 c888888 BackgroundTrans", "载入中...")

RegisterButtonClick(Main.btnAdd, AddItem)
RegisterButtonClick(Main.btnDel, DelItem)
    RegisterButtonClick(Main.btnPause, ToggleItemPause)
    RegisterButtonClick(Main.btnSet, ShowSettings)
    RegisterButtonClick(Main.btnLog, ShowLog)
    RegisterButtonClick(Main.btnHelp, ShowHelp)

; 动态监控 Main.lv 的选中状态以刷新暂停按钮可用性及文本
Main.lv.OnEvent("ItemSelect", OnLVSelectChange)
Main.lv.OnEvent("ItemFocus", OnLVSelectChange)

OnLVSelectChange(*) {
    static lastState := ""

    row := 0
    selCount := 0
    firstState := -1 ; 用来记录第一个选中的状态
    allSameState := true

    Loop {
        row := Main.lv.GetNext(row)
        if (row == 0)
            break

        selCount++
        chkPath := Main.lv.GetText(row, 3)
        if App.appStates.Has(chkPath) {
            currentState := App.appStates[chkPath].Enabled
            if (firstState == -1) {
                firstState := currentState
            } else if (firstState != currentState) {
                allSameState := false
            }
        }
    }

    if (selCount > 0) {
        newState := "active_" . (allSameState && firstState != -1 ? (firstState ? "pause" : "resume") : "reverse")
        if (lastState == newState)
            return
        lastState := newState

        SetButtonTextColor(Main.btnDel, "FFFFFF")
        SetButtonTextColor(Main.btnPause, "FFFFFF")
        SetHoverButtonColors(Main.btnDel, "6B4B4B")
        SetHoverButtonColors(Main.btnPause, "6B6244")
        SetButtonBackground(Main.btnDel, "6B4B4B")
        SetButtonBackground(Main.btnPause, "6B6244")

        if (allSameState && firstState != -1) {
            if (firstState)
                Main.btnPause.Text := "⏸️ 暂停"
            else
                Main.btnPause.Text := "▶️ 恢复"
        } else {
            ; 选中的项目里既有运行中的，也有暂停的，统一显示「反转状态」
            Main.btnPause.Text := "🔄 反转状态"
        }

        Main.btnDel.Redraw()
        Main.btnPause.Redraw()
        return
    }

    if (lastState == "inactive")
        return
    lastState := "inactive"

    SetButtonTextColor(Main.btnDel, "B8BAB9")
    SetButtonTextColor(Main.btnPause, "B8BAB9")
    SetHoverButtonColors(Main.btnDel, "554B4B", "554B4B")
    SetHoverButtonColors(Main.btnPause, "555148", "555148")
    SetButtonBackground(Main.btnDel, "554B4B")
    SetButtonBackground(Main.btnPause, "555148")
    Main.btnPause.Text := "⏸️ 暂停"
    Main.btnDel.Redraw()
    Main.btnPause.Redraw()
}

/*  * ========================================================================
 * ListView 拖拽排序逻辑 (Drag-and-Drop Reorder)
 * ========================================================================
 * 监听 LVN_BEGINDRAG (-109) 事件处理鼠标界面的拖拽调整顺序。
 */
Main.lv.OnNotify(-109, LV_ItemDrag)

LV_ItemDrag(ctrl, lParam) {
    ; 循环等待释放鼠标左键，期间向 ListView 发送 LVM_SETINSERTMARK 消息绘制插入目标的辅助线
    Loop {
        if !GetKeyState("LButton", "P")
            break

        pt := Buffer(8)
        DllCall("user32\GetCursorPos", "Ptr", pt)
        DllCall("user32\ScreenToClient", "Ptr", ctrl.Hwnd, "Ptr", pt)

        hitInfo := Buffer(24, 0)
        NumPut("Int", NumGet(pt, 0, "Int"), hitInfo, 0)
        NumPut("Int", NumGet(pt, 4, "Int"), hitInfo, 4)
        targetRow := SendMessage(0x1012, 0, hitInfo.Ptr, ctrl.Hwnd) ; LVM_HITTEST

        insertMark := Buffer(16, 0)
        NumPut("UInt", 16, insertMark, 0)
        if (targetRow >= 0) {
            NumPut("UInt", 0, insertMark, 4)
            NumPut("Int", targetRow, insertMark, 8)
        } else {
            NumPut("Int", -1, insertMark, 8)
        }
        SendMessage(0x10A6, 0, insertMark.Ptr, ctrl.Hwnd) ; LVM_SETINSERTMARK

        Sleep 20
    }

    ; 拖拽结束：清除插入方向的辅助标记线
    insertMark := Buffer(16, 0)
    NumPut("UInt", 16, insertMark, 0)
    NumPut("Int", -1, insertMark, 8)
    SendMessage(0x10A6, 0, insertMark.Ptr, ctrl.Hwnd)

    ; 计算当前光标位置在此 ListView 中对应的行索引
    pt := Buffer(8)
    DllCall("user32\GetCursorPos", "Ptr", pt)
    DllCall("user32\ScreenToClient", "Ptr", ctrl.Hwnd, "Ptr", pt)

    hitInfo := Buffer(24, 0)
    NumPut("Int", NumGet(pt, 0, "Int"), hitInfo, 0)
    NumPut("Int", NumGet(pt, 4, "Int"), hitInfo, 4)
    rawTargetRow := SendMessage(0x1012, 0, hitInfo.Ptr, ctrl.Hwnd)
    targetRow := rawTargetRow + 1

    ; 空白区域按鼠标位置决定插入首行或末尾，避免拖到顶部却总被追加。
    if (rawTargetRow < 0)
        targetRow := NumGet(pt, 4, "Int") < 0 ? 1 : ctrl.GetCount() + 1

    ; 枚举并保存当前所有选中项的数据，以支持多选项目的整体位置移动
    selectedData := []
    row := 0
    Loop {
        row := ctrl.GetNext(row)
        if (row == 0)
            break
        selectedData.Push({row: row, name: ctrl.GetText(row, 1), status: ctrl.GetText(row, 2), path: ctrl.GetText(row, 3)})
    }

    if (selectedData.Length == 0)
        return

    ; 拖回选中项自身时应保持原顺序；否则移除后再插入会把项目意外移到列表顶部。
    for data in selectedData {
        if (data.row == targetRow)
            return
    }

    App.editSessionId++
    undoState := CaptureAppConfigState()

    ; 优先移除被选中的需要移动的原有行（使用逆序删除以规避递进造成的行号偏移）
    Loop selectedData.Length {
        idx := selectedData.Length - A_Index + 1
        ctrl.Delete(selectedData[idx].row)
    }

    ; 计算元素在旧行位移除后，新目标在当前相对状态中对应的真实序列索引
    shiftedTarget := targetRow
    Loop selectedData.Length {
        if (selectedData[A_Index].row < targetRow)
            shiftedTarget--
    }

    if (shiftedTarget > ctrl.GetCount() + 1)
        shiftedTarget := ctrl.GetCount() + 1

    ; 将保存的原有行项目插入到最终序列目标点，并落盘存储更新后的状态
    for data in selectedData {
        stateObj := App.appStates.Has(data.path) ? App.appStates[data.path] : ""
        iconIdx := GetMainListIconIndex(data.path, stateObj, ctrl.IL)
        insertedRow := ctrl.Insert(shiftedTarget, "Icon" iconIdx " Select",
            data.name, data.status, data.path)
        persistedStatus := App.appStates.Has(data.path)
            ? App.appStates[data.path].State
            : data.status
        SetMainListStatus(insertedRow, persistedStatus)
        shiftedTarget++
    }

    Main.listProjection.Rebuild(ctrl)

    if !AppConfigStateOrderMatchesCurrent(undoState)
        CommitUndoState(undoState)
    SyncAppOrderFromListView()
    SaveAppsToIni()
    OnLVSelectChange()
}

; 绑定事件：双击编辑
Main.lv.OnEvent("DoubleClick", OnDoubleClick)

; 右键菜单相关
Main.contextMenu := Menu()
Main.contextMenu.Add("📂 打开所在位置", OpenFileLocation)
Main.contextMenu.Add("🔄 重新启动", RestartSelectedApp)
Main.contextMenu.Add("✒️ 编辑完整路径（F2）", (*) => TriggerEdit(Main.lv, Main.contextTargetRow))
Main.contextMenu.Add("🎨 自定义名称和图标…", OpenDisplaySettings)
Main.contextMenu.Add("🛡️ 以管理员身份运行", ToggleRunAsAdmin)
Main.contextMenu.Add("⚙️ 高级运行环境设置", OpenEnvSettings)
Main.contextMenu.Add("🔄 软件升级保护…", OpenMaintenanceSettings)
Main.contextMenu.Add()
Main.contextMenu.Add("📄 查看运行日志", OpenProcessLog)
Main.lv.OnEvent("ContextMenu", ShowContextMenu)

OpenEnvSettings(*) {
    if (Main.contextTargetRow == 0)
        return

    path := Main.lv.GetText(Main.contextTargetRow, 3)
    if !App.appStates.Has(path)
        return
    GuiModules.environment.Show(path, App.appStates[path])
}

OpenMaintenanceSettings(*) {
    if (Main.contextTargetRow == 0)
        return
    path := Main.lv.GetText(Main.contextTargetRow, 3)
    if !App.appStates.Has(path)
        return
    GuiModules.maintenance.Show(path, App.appStates[path])
}

OpenDisplaySettings(*) {
    if (Main.contextTargetRow == 0)
        return
    path := Main.lv.GetText(Main.contextTargetRow, 3)
    if !App.appStates.Has(path)
        return
    GuiModules.display.Show(path, App.appStates[path])
}

DestroyIconHandles(iconHandles, retainedHandle1 := 0, retainedHandle2 := 0) {
    destroyedHandles := Map()
    for hIcon in iconHandles {
        if !hIcon || hIcon == retainedHandle1 || hIcon == retainedHandle2
            || destroyedHandles.Has(hIcon)
            continue
        destroyedHandles[hIcon] := true
        try DllCall("user32\DestroyIcon", "Ptr", hIcon)
    }
}

ReleaseWindowIcons(hWnd) {
    iconHandles := App.iconResources.TakeWindowIcons(hWnd)
    if !iconHandles
        return
    DestroyIconHandles(iconHandles)
}

GetLogFilePath(path) {
    logDir := App.logDirectory
    if !DirExist(logDir)
        try DirCreate(logDir)
    return logDir "\" HashPath(path) ".log"
}

CleanupBatchLogs() {
    logDir := App.logDirectory
    if !DirExist(logDir)
        return
    try {
        Loop Files, logDir "\*.log", "F" {
            shouldDelete := App.clearLogsOnStartup
            if !shouldDelete {
                try shouldDelete := DateDiff(A_Now, A_LoopFileTimeModified, "Days") >= App.logRetentionDays
                catch
                    shouldDelete := false
            }
            if shouldDelete
                try FileDelete(A_LoopFileFullPath)
        }
    }
}

HashPath(path) {
    text := StrLower(NormalizeTargetPath(path))
    provider := 0
    cryptHash := 0
    try {
        if DllCall("advapi32\CryptAcquireContextW", "UPtr*", &provider,
            "Ptr", 0, "Ptr", 0, "UInt", 24, "UInt", 0xF0000000, "Int") {
            if DllCall("advapi32\CryptCreateHash", "UPtr", provider,
                "UInt", 0x0000800C, "UPtr", 0, "UInt", 0, "UPtr*", &cryptHash, "Int") {
                byteCount := StrPut(text, "UTF-8")
                textBuffer := Buffer(byteCount, 0)
                StrPut(text, textBuffer, "UTF-8")
                if DllCall("advapi32\CryptHashData", "UPtr", cryptHash,
                    "Ptr", textBuffer, "UInt", byteCount - 1, "UInt", 0, "Int") {
                    hashLength := 32
                    hashBuffer := Buffer(hashLength, 0)
                    if DllCall("advapi32\CryptGetHashParam", "UPtr", cryptHash,
                        "UInt", 2, "Ptr", hashBuffer, "UInt*", &hashLength, "UInt", 0, "Int") {
                        result := ""
                        Loop Min(hashLength, 16)
                            result .= Format("{:02X}", NumGet(hashBuffer, A_Index - 1, "UChar"))
                        return result
                    }
                }
            }
        }
    } finally {
        if cryptHash
            DllCall("advapi32\CryptDestroyHash", "UPtr", cryptHash)
        if provider
            DllCall("advapi32\CryptReleaseContext", "UPtr", provider, "UInt", 0)
    }
    ; CryptoAPI 极少数情况下不可用，使用两个独立 32 位散列作为确定性兜底。
    firstHash := 2166136261
    secondHash := 2246822519
    Loop Parse, text {
        codePoint := Ord(A_LoopField)
        firstHash := ((firstHash ^ codePoint) * 16777619) & 0xFFFFFFFF
        secondHash := ((secondHash ^ codePoint) * 3266489917) & 0xFFFFFFFF
    }
    return Format("{:08X}{:08X}", firstHash, secondHash)
}

OpenProcessLog(*) {
    if (Main.contextTargetRow > 0) {
        logPath := GetLogFilePath(Main.lv.GetText(Main.contextTargetRow, 3))
        if FileExist(logPath)
            Run('notepad.exe "' logPath '"')
        else
            ShowDarkMsgBox("日志文件不存在: " logPath, "运行日志", "Info", Main.gui)
    }
}

ToggleRunAsAdmin(*) {
    rows := []
    row := 0
    Loop {
        row := Main.lv.GetNext(row)
        if (!row)
            break
        rows.Push(row)
    }
    if (rows.Length == 0 && Main.contextTargetRow > 0)
        rows.Push(Main.contextTargetRow)

    undoState := rows.Length > 0 ? CaptureAppConfigState() : ""
    changedAny := false

    for row in rows {
        path := Main.lv.GetText(row, 3)
        if App.appStates.Has(path) {
            stateObj := App.appStates[path]
            priorPhase := stateObj.Phase
            stateObj.CancelScheduledTasks()
            stateObj.RunAsAdmin := !(stateObj.HasOwnProp("RunAsAdmin") ? stateObj.RunAsAdmin : 0)
            if (stateObj.Enabled
                && !App.maintenanceCoordinator.IsBlocking(stateObj)) {
                stateObj.Pending := false
                stateObj.TargetStartTicks := 0
                stateObj.VerifyAttempts := 0
                if StateProcessIdentityIsValid(path, stateObj) {
                    UpdateRunningState(path, stateObj,
                        stateObj.Generation)
                } else if !(stateObj.OneShot
                    && priorPhase == GuardPhase.Running) {
                    stateObj.TransitionTo(GuardPhase.Initializing)
                    UpdateState(path, "初始化...", stateObj,
                        stateObj.Generation)
                }
            }
            displayName := GetMainDisplayName(path, stateObj)
            Main.lv.Modify(row, "Col1", FormatMainListLabel(displayName, stateObj.RunAsAdmin))
            if StateProcessIdentityIsValid(path, stateObj)
                UpdateRunningState(path, stateObj)
            LogMsg((stateObj.RunAsAdmin ? "启用" : "关闭") . "了以管理员身份运行: " . displayName)
            changedAny := true
        }
    }
    if changedAny {
        CommitUndoState(undoState)
        SaveAppsToIni()
    }
}

RestartSelectedApp(*) {
    rows := []
    row := 0
    Loop {
        row := Main.lv.GetNext(row)
        if (!row)
            break
        rows.Push(row)
    }
    if (rows.Length == 0 && Main.contextTargetRow > 0)
        rows.Push(Main.contextTargetRow)

    for row in rows {
        path := Main.lv.GetText(row, 3)
        if !App.appStates.Has(path)
            continue
        stateObj := App.appStates[path]
        if App.maintenanceCoordinator.IsBlocking(stateObj) {
            ShowDarkMsgBox("该软件正在升级保护中。请等待升级完成，或在“软件升级保护”中结束等待后再重新启动。", "暂时无法重新启动", "Info", Main.gui)
            continue
        }

        ; 手动操作先作废旧回调；等待外部进程期间，删除、暂停或撤销仍可
        ; 通过控制器实例和代际使本次操作失效。
        stateObj.CancelScheduledTasks()
        operationGeneration := stateObj.Generation
        UpdateState(path, "⏳ 停止原进程...")
        observation := ObserveTarget(path, "", 1000)
        if !App.guardRuntime.IsSupervisorCurrent(path, stateObj,
            operationGeneration)
            continue
        if observation.IsUnknown() {
            stateObj.Enabled := 1
            stateObj.Pending := true
            UpdateState(path, "⏳ 等待进程状态...")
            App.guardRuntime.ScheduleRestart(path, 2000)
            LogMsg("暂时无法查询进程状态，稍后重试手动重启: " path)
            continue
        }
        if observation.IsRunning() {
            pid := observation.PID
            stopped := GracefulStop(pid)
            if !App.guardRuntime.IsSupervisorCurrent(path, stateObj,
                operationGeneration)
                continue
            if !stopped {
                SetStateProcessIdentity(stateObj, pid)
                stateObj.Pending := false
                UpdateState(path, "❌ 无法停止原进程")
                LogMsg("手动重启已取消，原进程未能停止: " path)
                continue
            }
        }

        if !App.guardRuntime.IsSupervisorCurrent(path, stateObj,
            operationGeneration)
            || App.maintenanceCoordinator.IsBlocking(stateObj)
            continue
        stateObj.Enabled := 1
        stateObj.Pending := true
        stateObj.TargetStartTicks := 0
        stateObj.FailCount := 0
        ClearStateProcessIdentity(stateObj)

        App.guardRuntime.Restart(path)
        LogMsg("手动触发了重新启动: " path)
    }

    if (rows.Length > 0) {
        SaveAppsToIni()
        OnLVSelectChange()
    }
}

/*  * ========================================================================
 * 全局界面的按键拦截钩子 (Global Key Hook)
 * ========================================================================
 * 使用 OnMessage 监听 WM_KEYDOWN 消息实现快捷键，
 * 如撤销(Undo)、重做(Redo)和列表操作功能。
 */
OnMessage(Win32.WM_KEYDOWN, Global_KeyDown)
OnMessage(Win32.WM_DPICHANGED, MainDpiChanged)
OnMessage(Win32.WM_COPYDATA, ReceiveMaintenanceCopyData)
OnMessage(Win32.WM_SYSCOMMAND, OnManagedWindowSystemCommand)

Global_KeyDown(wParam, lParam, msg, hwnd) {
    controlClass := ""
    try controlClass := WinGetClass("ahk_id " hwnd)
    isTextEditor := RegExMatch(controlClass, "i)^Edit$") != 0
    ; 文本框保留自身的撤销、重做和编辑快捷键，不能被主窗口历史栈抢占。
    if (isTextEditor && GetKeyState("Ctrl", "P"))
        return
    if ((wParam == 13 || wParam == 32)
        && App.uiInteractions.HasButton(hwnd)) {
        buttonState := App.uiInteractions.GetButton(hwnd)
        if IsHoverButtonAvailable(buttonState) {
            try ControlClick(, "ahk_id " hwnd)
            return 0
        }
    }
    isMainGui := (DllCall("user32\GetAncestor", "Ptr", hwnd, "UInt", 2) == Main.gui.Hwnd)
    if (isMainGui) {
        if (wParam == 90 && GetKeyState("Ctrl", "P")) { ; Ctrl+Z / Ctrl+Shift+Z
            if GetKeyState("Shift", "P")
                PerformRedo()
            else
                PerformUndo()
            return
        }
        if (wParam == 89 && GetKeyState("Ctrl", "P")) { ; Ctrl+Y
            PerformRedo()
            return
        }
    }

    ; 如果在ListView编辑框内
    if (wParam == 27) {
        hEdit := SendMessage(0x1018, 0, 0, Main.lv.Hwnd) ; LVM_GETEDITCONTROL
        if (hEdit && hEdit == hwnd) {
            SendMessage(0x0100, 27, 0, hEdit) ; 传给编辑框取消编辑
            return
        }
    }

    ; 判断：若当前获取输入焦点的对象在 ListView 列表本身
    if (hwnd == Main.lv.Hwnd) {
        if (wParam == 113) { ; F2 热键深度编辑绝对路径
            row := Main.lv.GetNext(0, "Focused")
            if (row > 0)
                TriggerEdit(Main.lv, row)
            return
        }
        if (wParam == 65 && GetKeyState("Ctrl")) { ; Ctrl+A 秒全选响应
            Main.lv.Modify(0, "Select")
            return
        }
        if (wParam == 46) { ; Delete 直删选中目标
            if (Main.lv.GetNext(0) > 0)
                DelItem()
            return
        }
        if (wParam == 27) { ; ESC 交互回退降级策略
            if (Main.lv.GetNext(0) > 0) {
                Main.lv.Modify(0, "-Select") ; 层级一：撤销选择抹去高背光
            } else {
                OnMainGuiClose()        ; 层级二：若无可放弃选取的东西则视为归隐后台
            }
            return
        }
    }

    ; 补充逻辑：若当前焦点游离在父级主 GUI 中的其它控件控件，点击 Esc 收起窗口面板
    ; 参数 `2` (GA_ROOT) = 找到主 GUI 框架
    if (wParam == 27 && DllCall("user32\GetAncestor", "Ptr", hwnd, "UInt", 2) == Main.gui.Hwnd) {
        OnMainGuiClose()
    }
}

; 从 INI 读取监控项及对应的升级保护配置。
LoadWatchlistFromConfig()
if !App.maintenanceCoordinator.Initialize()
    LogMsg("升级保护协调器未能初始化，核心守护不会启动。")

UpdateTaskButtonStatus()

Main.gui.OnEvent("Size", GuiResized)
Main.gui.OnEvent("Close", OnMainGuiClose)
Main.gui.OnEvent("Escape", OnMainGuiClose)
Main.gui.OnEvent("DropFiles", OnGuiDropFiles)

ResolveShortcutForAdd(path, &shortcutArguments := "", &resolvedWorkDir := "") {
    shortcutArguments := ""
    resolvedWorkDir := ""
    SplitPath(path, , , &ext)
    if (StrLower(ext) == "lnk") {
        descriptor := App.shortcutTargetResolver.Read(path)
        if descriptor.Readable {
            resolvedWorkDir := descriptor.WorkingDirectory
            shortcutArguments := descriptor.Arguments
        }
    }
    ; 快捷方式始终作为启动入口保存；真实进程身份由 ResolvedTarget 独立维护。
    return path
}

MainDpiChanged(wParam, lParam, msg, hwnd) {
    if (hwnd != Main.gui.Hwnd)
        return
    newDpi := wParam & 0xFFFF
    iconResources := App.iconResources
    if (!newDpi || newDpi == iconResources.MainDpi)
        return
    rebuildRequest := iconResources.CreateDpiRebuildRequest(newDpi,
        RebuildMainImageList)
    if rebuildRequest.PreviousTimer
        SetTimer(rebuildRequest.PreviousTimer, 0)
    SetTimer(rebuildRequest.Timer, -250)
}

RebuildMainImageList(rebuildGeneration, expectedDpi, *) {
    iconResources := App.iconResources
    if !iconResources.AcceptDpiRebuild(rebuildGeneration)
        return
    if !DllCall("user32\IsWindow", "Ptr", Main.gui.Hwnd, "Int")
        return
    currentDpi := DllCall("user32\GetDpiForWindow", "Ptr", Main.gui.Hwnd, "UInt")
    if (currentDpi != expectedDpi)
        return
    oldImageList := Main.appIcons
    previousMetrics := iconResources.GetMainIconMetrics()
    newStatusIconIndices := Map()
    newImageList := CreateMainImageList(newStatusIconIndices)
    if !newImageList
        return
    if !iconResources.IsDpiRebuildCurrent(rebuildGeneration) {
        ClearImageListIconCache(newImageList)
        try IL_Destroy(newImageList)
        iconResources.RestoreMainIconMetrics(previousMetrics)
        return
    }
    redrawSuspended := false
    newImageListAttached := false
    try {
        Main.lv.Opt("-Redraw")
        redrawSuspended := true
        Main.lv.SetImageList(newImageList, 1)
        newImageListAttached := true
        Main.appIcons := newImageList
        Main.statusIconIndices := newStatusIconIndices
        Main.lv.IL := newImageList
        Loop Main.lv.GetCount() {
            try {
                path := Main.lv.GetText(A_Index, 3)
                stateObj := App.appStates.Has(path)
                    ? App.appStates[path] : ""
                iconIndex := GetMainListIconIndex(path, stateObj,
                    newImageList)
                if iconIndex
                    Main.lv.Modify(A_Index, "Icon" iconIndex)
                statusText := App.appStates.Has(path)
                    ? App.appStates[path].State
                    : Main.lv.GetText(A_Index, 2)
                SetMainListStatus(A_Index, statusText)
            } catch as rowIconError {
                LogMsg("DPI 变化后刷新图标失败: " rowIconError.Message)
            }
        }
    } catch as imageListError {
        LogMsg("DPI 变化后重建图标列表失败: " imageListError.Message)
    } finally {
        if redrawSuspended
            try Main.lv.Opt("+Redraw")
        if newImageListAttached {
            RetireMainImageList(oldImageList)
        } else {
            ClearImageListIconCache(newImageList)
            try IL_Destroy(newImageList)
            iconResources.RestoreMainIconMetrics(previousMetrics)
        }
    }
}

OnGuiDropFiles(GuiObj, CtrlObj, FileArray, X, Y) {
    directories := []
    files := []
    for dropPath in FileArray {
        if DirExist(dropPath)
            directories.Push(dropPath)
        else if App.fileScanner.IsSupported(dropPath)
            files.Push(dropPath)
    }
    if directories.Length {
        GuiModules.addItem.StartBatchImport(directories, files)
        return
    }
    if files.Length {
        undoState := CaptureAppConfigState()
        addedCount := 0
        for filePath in files {
            shortcutArgs := "", resolvedWorkDir := ""
            resolvedPath := ResolveShortcutForAdd(filePath, &shortcutArgs, &resolvedWorkDir)
            if RegisterApp(resolvedPath, 1, 0, resolvedWorkDir,
                "", "", "", "", false, shortcutArgs)
                addedCount++
        }
        if addedCount {
            CommitUndoState(undoState)
            SaveAppsToIni()
        }
        LogMsg("通过拖拽添加了 " addedCount " 个监控项。")
    }
}

; 检查是否是通过“重新加载”触发的启动，决定显示界面还是静默系统托盘
try {
    if (App.configRepository.Read(
        "Settings", "ShowAfterReload", 0) == "1") {
        App.configRepository.WriteValue(
            "Settings", "ShowAfterReload", 0)
        Main.gui.Show("w" App.savedWidth " h" App.savedHeight)
        App.isReloadedMode := true
    }
}

if (!App.isReloadedMode) {
    ; 根据设置决定启动后显示主窗口，或静默驻留托盘。
    if App.showAtStartup
        Main.gui.Show("w" App.savedWidth " h" App.savedHeight)
    else
        Main.gui.Show("w" App.savedWidth " h" App.savedHeight " Hide")
}

ApplyTemporaryPreviewStates()

SetTimer(UpdateCountdownUI, 1000) ; 倒计时显示按整秒刷新
if !App.guardRuntime.Start()
    LogMsg("核心守护计时器启动失败。")
LogMsg(App.isReloadedMode ? "代码热重载完毕，界面已恢复显示。" : "进程守护小助手已静默启动。")

OnMainGuiClose(*) {
    HideMainGui()
}

ApplyTemporaryPreviewStates() {
    previewStatuses := Map(
        "【状态测试】01 初始化", "初始化...",
        "【状态测试】02 运行正常", "✅ 运行中",
        "【状态测试】03 权限不符", "⚠️ 运行中（权限不符）",
        "【状态测试】04 疑似停止", "⚠️ 疑似停止",
        "【状态测试】05 重试倒计时", "⏳ 重试倒计时 5s",
        "【状态测试】06 正在启动", "🚀 正在启动...",
        "【状态测试】07 验证运行", "⏳ 验证运行状态...",
        "【状态测试】08 状态未知", "⏳ 等待进程状态...",
        "【状态测试】09 稍后自动重试", "⏳ 稍后自动重试",
        "【状态测试】10 程序缺失", "❌ 程序不存在",
        "【状态测试】11 脚本缺失", "❌ 脚本不存在",
        "【状态测试】12 已暂停", "⏸️ 已暂停",
        "【状态测试】13 软件升级中", "🔄 软件升级中",
        "【状态测试】14 升级仲裁", "⏳ 判断是否正在升级",
        "【状态测试】15 文件稳定", "⏳ 确认升级文件稳定 3s",
        "【状态测试】16 升级超时", "⚠️ 升级等待超时",
        "【状态测试】17 非驻留目标", "✅ 已启动（非驻留目标）",
        "【状态测试】18 停止失败", "❌ 无法停止原进程")
    firstPreviewRow := 0
    for path, stateObj in App.appStates {
        if stateObj.Enabled || !stateObj.DisplayConfig
            continue
        displayName := stateObj.DisplayConfig.Name
        if displayName == "【状态测试】09 低频恢复" {
            stateObj.DisplayConfig.Name := "【状态测试】09 稍后自动重试"
            displayName := stateObj.DisplayConfig.Name
        }
        if !InStr(displayName, "【图标格式测试】")
            && !previewStatuses.Has(displayName)
            continue
        row := FindRow(path)
        if !row
            continue
        if !firstPreviewRow
            firstPreviewRow := row
        if displayName == "【状态测试】09 稍后自动重试"
            Main.lv.Modify(row, "Col1", FormatMainListLabel(displayName,
                stateObj.RunAsAdmin))
        if previewStatuses.Has(displayName) {
            stateObj.State := previewStatuses[displayName]
            SetMainListStatus(row, stateObj.State)
        }
    }
    if firstPreviewRow
        try Main.lv.Modify(firstPreviewRow, "Vis")
}

HideMainGui(force := false) {
    if !force && WindowHierarchy.IsOwnerLocked(Main.gui) {
        WindowHierarchy.ActivateTopOwned(Main.gui)
        return false
    }
    if IsSet(GuiModules)
        GuiModules.HideTransientWindows()
    Main.gui.GetClientPos(,, &gW, &gH)
    if (gW >= 730 && gH >= 530 && WinGetMinMax(Main.gui.Hwnd) != -1) {
        try {
            c1 := SendMessage(Win32.LVM_GETCOLUMNWIDTH, 0, 0, Main.lv.Hwnd)
            c2 := SendMessage(Win32.LVM_GETCOLUMNWIDTH, 1, 0, Main.lv.Hwnd)
            windowDpi := DllCall("user32\GetDpiForWindow", "Ptr",
                Main.gui.Hwnd, "UInt")
            dpiScale := (windowDpi ? windowDpi : 96) / 96
            App.windowLayoutService.Save({
                Width: Round(gW), Height: Round(gH),
                Column1: Round(c1 / dpiScale),
                Column2: Round(c2 / dpiScale)
            })
        } catch as layoutErr {
            LogMsg("保存窗口布局失败: " layoutErr.Message)
        }
    }
    Main.gui.Hide()
    return true
}

; ==========================================
; 8. 窗口尺寸自适应调整
; ==========================================
GuiResized(GuiObj, MinMax, Width, Height) {
    if (MinMax == -1)
        return
    Main.btnSet.Move(Width - 240)
    Main.btnHelp.Move(Width - 160)
    Main.btnLog.Move(Width - 80)

    Main.lv.Move(,, Width - 20, Height - 85)
    Main.statsText.Move(10, Height - 20, Width - 20, 20)

    ; 动态拉伸第一列来占用剩余空间
    rc := Buffer(16)
    DllCall("GetClientRect", "Ptr", Main.lv.Hwnd, "Ptr", rc)
    clientW := NumGet(rc, 8, "Int")

    col2W := SendMessage(Win32.LVM_GETCOLUMNWIDTH, 1, 0, Main.lv.Hwnd)

    if (clientW > col2W) {
        SendMessage(0x101E, 0, clientW - col2W, Main.lv.Hwnd) ; 自动拉伸应用程序列(索引0)
    }
    SendMessage(0x101E, 2, 0, Main.lv.Hwnd) ; LVM_SETCOLUMNWIDTH 避免拖动展示出第三列(索引2)
}

ShowContextMenu(GuiCtrlObj, Item, IsRightClick, X, Y) {
    if (Item > 0) {
        Main.contextTargetRow := Item
        ; 右键未选中的行时，将上下文目标设为唯一选中项，避免菜单操作误作用于旧选择。
        isSelected := false
        probeRow := 0
        Loop {
            probeRow := Main.lv.GetNext(probeRow)
            if (!probeRow)
                break
            if (probeRow == Item) {
                isSelected := true
                break
            }
        }
        if !isSelected {
            Main.lv.Modify(0, "-Select")
            Main.lv.Modify(Item, "Select Focus")
        }
        path := Main.lv.GetText(Item, 3)
        if App.appStates.Has(path) {
            isAdmin := App.appStates[path].HasOwnProp("RunAsAdmin") && App.appStates[path].RunAsAdmin
            if (isAdmin)
                Main.contextMenu.Check("🛡️ 以管理员身份运行")
            else
                Main.contextMenu.Uncheck("🛡️ 以管理员身份运行")
            if IsMaintenanceSupportedTarget(path) {
                Main.contextMenu.Enable("🔄 软件升级保护…")
                if App.appStates[path].MaintenanceConfig.Enabled
                    Main.contextMenu.Check("🔄 软件升级保护…")
                else
                    Main.contextMenu.Uncheck("🔄 软件升级保护…")
            } else {
                Main.contextMenu.Uncheck("🔄 软件升级保护…")
                Main.contextMenu.Disable("🔄 软件升级保护…")
            }
        }
        Main.contextMenu.Show()
    }
}

OpenFileLocation(*) {
    if (Main.contextTargetRow > 0) {
        path := Main.lv.GetText(Main.contextTargetRow, 3)
        locationPath := FileExist(path) ? path
            : App.targetIdentityService.GetMonitoredTargetPath(path)
        SplitPath(locationPath, , &dir)
        if FileExist(locationPath)
            Run('explorer.exe /select,"' locationPath '"')
        else if FileExist(dir)
            Run('explorer.exe "' dir '"')
    }}

; ==========================================
; 9. 托盘与窗口控制
; ==========================================
IsApplicationNotificationClick(lParam, hwnd) {
    return hwnd == A_ScriptHwnd
        && (lParam & 0xFFFF) == Win32.NIN_BALLOONUSERCLICK
}

OnTrayNotification(wParam, lParam, msg, hwnd) {
    if !IsApplicationNotificationClick(lParam, hwnd)
        return
    ; Windows 消息回调内不直接创建 GUI，避免通知连点造成重入与焦点竞争。
    SetTimer(OpenNotificationWindows, -1)
    return 0
}

OpenNotificationWindows(*) {
    if !IsSet(Main) || !IsSet(GuiModules)
        return
    if IsSet(App) && App.shutdownStarted
        return

    try ShowMainGui()
    try WinShow("ahk_id " Main.gui.Hwnd)
    try WinRestore("ahk_id " Main.gui.Hwnd)

    try ShowLog()
    if GuiModules.log.IsOpen() {
        logHwnd := GuiModules.log.gui.Hwnd
        try WinShow("ahk_id " logHwnd)
        try WinRestore("ahk_id " logHwnd)
        try WinActivate("ahk_id " logHwnd)
    }
}

ShowMainGui(*) {
    Main.gui.Show()
    if WindowHierarchy.IsOwnerLocked(Main.gui)
        WindowHierarchy.ActivateTopOwned(Main.gui)
}
ReloadScript(*) {
    HideMainGui(true)
    previousCritical := A_IsCritical
    reloadMarkerWritten := false
    try {
        ; 验证和交接期间禁止计时器插入当前线程，否则后台回调异常会被
        ; 误归因成重载失败，并可能让旧实例停在半清理状态。
        Critical("On")
        if !A_IsCompiled {
            validationCommand := BuildReloadValidationCommand(A_AhkPath,
                A_ScriptFullPath)
            if RunWait(validationCommand, A_ScriptDir, "Hide") != 0
                throw Error("新脚本未通过 AutoHotkey 解析检查")
        }
        ; 只有候选脚本验证通过后才写入一次性标记。
        App.configRepository.WriteValue("Settings", "ShowAfterReload", 1)
        reloadMarkerWritten := true
        App.reloadInProgress := true
        currentPid := DllCall("kernel32\GetCurrentProcessId", "UInt")
        handoffCommand := BuildReloadHandoffCommand(currentPid, A_IsCompiled,
            A_AhkPath, A_ScriptFullPath)
        Run(handoffCommand, A_ScriptDir)
    } catch as reloadErr {
        App.reloadInProgress := false
        if reloadMarkerWritten
            try App.configRepository.WriteValue("Settings", "ShowAfterReload", 0)
        Critical(previousCritical ? previousCritical : "Off")
        reloadDetails := FormatRuntimeErrorDetails(reloadErr)
        LogMsg("重新加载失败，已保留当前实例: " reloadDetails)
        ShowMainGui()
        ShowDarkMsgBox("重新加载失败，当前守护仍在运行。`n`n"
            reloadDetails, "重新加载失败", "Error", Main.gui)
        return
    }

    ; 接班进程已经创建。先在不可被计时器打断的线程中完成幂等清理，
    ; 再退出；ExitApp 必须位于上方 catch 的范围之外。
    ShutdownApplication()
    ExitApp()
}
ExitProgram(*) {
    HideMainGui(true)
    ExitApp()
}

; ==========================================
; 10. 配置校验与目标规格辅助函数
; ==========================================
ParseBoundedInteger(value, minValue, maxValue) {
    value := Trim(String(value))
    if !RegExMatch(value, "^\d+$")
        return false
    try parsed := Integer(value)
    catch
        return false
    return (parsed >= minValue && parsed <= maxValue) ? parsed : false
}

IsValidCheckInterval(value) {
    if !RegExMatch(Trim(String(value)), "^\d+$")
        return false
    try value := Integer(value)
    catch
        return false
    return value >= 500 && value <= 86400000
}

ParseRetrySequence(sequence) {
    sequence := StrReplace(StrReplace(Trim(sequence), " ", ""), "，", ",")
    if (sequence == "")
        return false
    result := []
    retryParts := StrSplit(sequence, ",")
    if (retryParts.Length > 10)
        return false
    for value in retryParts {
        if !RegExMatch(value, "^\d+$")
            return false
        try seconds := Integer(value)
        catch
            return false
        if (seconds < 1 || seconds > 86400)
            return false
        result.Push(seconds * 1000)
    }
    return result.Length ? result : false
}

NormalizeTargetPath(path) {
    path := Trim(path)
    ; 用户经常直接粘贴资源管理器中的带引号路径；引号属于输入包装而不是路径本身。
    if (StrLen(path) >= 2 && SubStr(path, 1, 1) == '"' && SubStr(path, -1) == '"')
        path := Trim(SubStr(path, 2, -1))
    return StrReplace(path, "/", "\")
}

GetCanonicalPath(path) {
    path := Trim(String(path), " `t`r`n`"")
    if (path == "")
        return ""
    path := StrReplace(path, "/", "\")
    fullPathBuffer := Buffer(32768 * 2, 0)
    length := DllCall("kernel32\GetFullPathNameW", "Str", path, "UInt", 32768, "Ptr", fullPathBuffer, "Ptr", 0, "UInt")
    fullPath := length && length < 32768 ? StrGet(fullPathBuffer, length, "UTF-16") : path
    if FileExist(fullPath) {
        longPathBuffer := Buffer(32768 * 2, 0)
        longLength := DllCall("kernel32\GetLongPathNameW", "WStr", fullPath,
            "Ptr", longPathBuffer, "UInt", 32768, "UInt")
        if (longLength && longLength < 32768)
            fullPath := StrGet(longPathBuffer, longLength, "UTF-16")
    }
    if (SubStr(fullPath, 1, 4) == "\\?\")
        fullPath := SubStr(fullPath, 5)
    return StrLower(StrLen(fullPath) > 3 ? RTrim(fullPath, "\") : fullPath)
}

PathsEquivalent(firstPath, secondPath) {
    if (firstPath == "" || secondPath == "")
        return firstPath == secondPath
    return GetCanonicalPath(firstPath) == GetCanonicalPath(secondPath)
}

SignedWord(value) {
    value := value & 0xFFFF
    return value > 0x7FFF ? value - 0x10000 : value
}

GetTickCount64() {
    return DllCall("kernel32\GetTickCount64", "UInt64")
}

LogSlowBackgroundOperation(operationName, startedTicks, thresholdMs := 200) {
    elapsedMs := GetTickCount64() - startedTicks
    if (elapsedMs < thresholdMs)
        return
    static lastLoggedTicks := Map()
    nowTicks := GetTickCount64()
    if (lastLoggedTicks.Has(operationName)
        && nowTicks - lastLoggedTicks[operationName] < 30000)
        return
    lastLoggedTicks[operationName] := nowTicks
    LogMsg("后台任务耗时较长: " operationName "，本次 " elapsedMs " 毫秒")
}

IsMaintenanceSupportedTarget(path) {
    if !InStr(path, "\")
        return false
    SplitPath(path, , , &extension)
    extension := StrLower(extension)
    if (extension == "lnk") {
        effectiveTarget := App.targetIdentityService.GetMonitoredTargetPath(
            path)
        if (effectiveTarget == "" && IsOneShotTarget(path))
            return false
    }
    return RegExMatch(extension, "i)^(exe|com|ahk|py|pyw|js|vbs|vbe|wsf|ps1|bat|cmd|rb|pl|php|lua|jar|sh|bash|lnk)$") != 0
}

GetDefaultMaintenanceRoot(path) {
    if !IsMaintenanceSupportedTarget(path)
        return ""
    SplitPath(path, , , &extension)
    if (StrLower(extension) == "lnk") {
        effectiveTarget := App.targetIdentityService.GetMonitoredTargetPath(
            path)
        if (effectiveTarget != "") {
            SplitPath(effectiveTarget, , &effectiveDirectory)
            if (effectiveDirectory != "")
                return effectiveDirectory
        }
        workingDir := App.shortcutTargetResolver.GetWorkingDirectory(path)
        if (workingDir != "")
            return StrLen(workingDir) > 3 ? RTrim(workingDir, "\") : workingDir
        targetPath := App.shortcutTargetResolver.GetTargetPath(path)
        if (targetPath != "") {
            SplitPath(targetPath, , &targetDirectory)
            return targetDirectory
        }
    }
    SplitPath(path, , &directory)
    return directory
}

NormalizeMaintenanceRoot(rootPath, targetPath := "") {
    rootPath := Trim(rootPath)
    if (rootPath == "" && targetPath != "")
        rootPath := GetDefaultMaintenanceRoot(targetPath)
    rootPath := StrReplace(rootPath, "/", "\")
    if (StrLen(rootPath) > 3)
        rootPath := RTrim(rootPath, "\")
    return rootPath
}

RegisterPersistedWatchItem(record) {
    return RegisterApp(record.Path, record.Enabled, record.RunAsAdmin,
        record.WorkDir, record.Args, record.EnvVars, record.Maintenance,
        record.ResolvedTarget, record.ResolvedTargetManual,
        record.ShortcutArgs, record.Display)
}

LoadWatchlistFromConfig() {
    loadResult := App.watchlistPersistenceService.Load(
        RegisterPersistedWatchItem)
    App.configLoadWarnings := loadResult.Warnings
    App.configRecoveryEntries := loadResult.RecoveryEntries
    if App.configLoadWarnings.Length {
        LogMsg(BuildConfigLoadDiagnostic(App.configLoadWarnings,
            App.configRepository.Path))
        try TrayTip(App.configLoadWarnings.Length
            " 条监控配置未载入，相关项目当前不会被守护。点击查看具体位置和原因。",
            "监控配置加载异常", 2)
    }
}

BuildConfigLoadDiagnostic(warnings, configPath) {
    diagnostic := "监控配置加载异常：共 " warnings.Length
        . " 条记录未能载入。"
    for index, warning in warnings {
        targetText := warning.Target != "" ? warning.Target
            : "无法从损坏记录中提取"
        diagnostic .= "`r`n  [" index "] 位置：[" warning.Section "] "
            . warning.Key
        diagnostic .= "`r`n      目标：" targetText
        diagnostic .= "`r`n      问题：" warning.Field "：" warning.Reason
        diagnostic .= "`r`n      影响：该项目本次未加入守护列表。"
    }
    diagnostic .= "`r`n  配置文件：" configPath
    diagnostic .= "`r`n  处理建议：确认目标路径后，可在主界面重新添加该项目；"
        . "也可退出小助手后检查上述配置位置。后续保存配置时，"
        . "损坏记录会转存到 [Recovery]，不会被静默删除。"
    return diagnostic
}

QueryProcessSnapshot(&snapshotReady) {
    snapshotReady := false
    snapshot := []
    try {
        wmiService := ComObjGet("winmgmts:")
        processes := wmiService.ExecQuery("SELECT ProcessId, ParentProcessId, Name, CommandLine, ExecutablePath, CreationDate FROM Win32_Process")
        for process in processes {
            processInfo := {pid: 0, parent: 0, name: "", cmd: "", exe: "", creation: "", observedTicks: GetTickCount64()}
            try processInfo.pid := Integer(process.ProcessId)
            try processInfo.parent := Integer(process.ParentProcessId)
            try processInfo.name := process.Name
            try processInfo.cmd := process.CommandLine
            try processInfo.exe := process.ExecutablePath
            try processInfo.creation := process.CreationDate
            if processInfo.pid
                snapshot.Push(processInfo)
        }
        snapshotReady := true
    } catch {
        snapshotReady := false
        snapshot := []
    }
    return snapshot
}

CreateProcessSnapshotIndex(snapshot, capturedAtTicks := 0,
    supportsCommandLine := true) {
    if !capturedAtTicks
        capturedAtTicks := GetTickCount64()
    return ProcessSnapshotIndex(snapshot, capturedAtTicks,
        supportsCommandLine, GetCanonicalPath)
}

QuoteCommandLineArgument(argument) {
    return '"' String(argument) '"'
}

BuildReloadValidationCommand(interpreterPath, scriptPath) {
    return QuoteCommandLineArgument(interpreterPath) . " /ErrorStdOut "
        . QuoteCommandLineArgument(scriptPath) . " --startup-validation"
}

BuildReloadHandoffCommand(currentPid, compiled, interpreterPath, scriptPath) {
    currentPid := Integer(currentPid)
    if compiled {
        return QuoteCommandLineArgument(scriptPath) . " --reload-handoff "
            . currentPid
    }
    return QuoteCommandLineArgument(interpreterPath) . " "
        . QuoteCommandLineArgument(scriptPath) . " --reload-handoff "
        . currentPid
}

ProcessMaintenanceCommandClient() {
    if (A_Args.Length < 1)
        return false
    option := StrLower(A_Args[1])
    if (option == "--startup-validation")
        ExitApplication(0)
    if (option == "--process-snapshot-worker" && A_Args.Length >= 2) {
        succeeded := App.processSnapshots.WriteWorkerFile(A_Args[2],
            QueryProcessSnapshot)
        ExitApplication(succeeded ? 0 : 1)
    }
    if (option == "--send-ctrl-c" && A_Args.Length >= 2) {
        succeeded := SendConsoleCtrlCWorker(Integer(A_Args[2]))
        ExitApplication(succeeded ? 0 : 1)
    }
    if (option == "--file-scan-worker" && A_Args.Length >= 6) {
        succeeded := App.fileScanner.WriteWorkerFile(A_Args[2], A_Args[3],
            A_Args[4],
            Integer(A_Args[5]) != 0, Integer(A_Args[6]),
            A_Args.Length >= 7 ? Integer(A_Args[7]) : 15)
        ExitApplication(succeeded ? 0 : 1)
    }
    if (option != "--maintenance-begin" && option != "--maintenance-end")
        return false
    if (A_Args.Length < 2)
        return true
    command := (option == "--maintenance-begin" ? "BEGIN|" : "END|") A_Args[2]
    hiddenWindowsBefore := A_DetectHiddenWindows
    targetWindow := 0
    try {
        DetectHiddenWindows(true)
        targetWindow := WinExist("进程守护小助手 ahk_class AutoHotkeyGUI")
    } finally {
        DetectHiddenWindows(hiddenWindowsBefore)
    }
    if targetWindow {
        Loop 3 {
            if SendMaintenanceCopyData(targetWindow, command)
                break
            Sleep(200)
        }
        return true
    }
    App.maintenanceCoordinator.PendingCommands.Push(command)
    return false
}

SendMaintenanceCopyData(targetWindow, command) {
    characterCount := StrPut(command, "UTF-16")
    commandBuffer := Buffer(characterCount * 2, 0)
    StrPut(command, commandBuffer, "UTF-16")
    structureSize := A_PtrSize == 8 ? 24 : 12
    copyData := Buffer(structureSize, 0)
    NumPut("UPtr", 1, copyData, 0)
    NumPut("UInt", characterCount * 2, copyData, A_PtrSize)
    NumPut("Ptr", commandBuffer.Ptr, copyData, A_PtrSize == 8 ? 16 : 8)
    messageResult := 0
    return DllCall("user32\SendMessageTimeoutW", "Ptr", targetWindow,
        "UInt", Win32.WM_COPYDATA, "Ptr", A_ScriptHwnd, "Ptr", copyData.Ptr,
        "UInt", 0x0002, "UInt", 3000, "UPtr*", &messageResult, "Ptr")
}

ReceiveMaintenanceCopyData(wParam, lParam, msg, hwnd) {
    if !lParam
        return 0
    byteCount := NumGet(lParam, A_PtrSize, "UInt")
    dataPointer := NumGet(lParam, A_PtrSize == 8 ? 16 : 8, "Ptr")
    if !dataPointer || byteCount < 2 || Mod(byteCount, 2)
        return 0
    command := StrGet(dataPointer, byteCount // 2 - 1, "UTF-16")
    return App.maintenanceCoordinator.QueueCommand(command) ? 1 : 0
}

ClearStateProcessIdentity(stateObj, rememberLast := true) {
    if !stateObj
        return
    if rememberLast && stateObj.HasOwnProp("PID") && stateObj.PID {
        stateObj.LastKnownPID := stateObj.PID
        stateObj.LastKnownPIDCreationIdentity := stateObj.PIDCreationIdentity
    }
    stateObj.PID := 0
    stateObj.PIDCreationIdentity := ""
    stateObj.PIDImagePath := ""
    stateObj.PIDElevationState := -1
    stateObj.PIDElevationChecked := false
}

SetStateProcessIdentity(stateObj, pid) {
    pid := pid ? Integer(pid) : 0
    if !pid {
        ClearStateProcessIdentity(stateObj)
        return false
    }
    currentCreationIdentity := ""
    if (stateObj.PID == pid && stateObj.HasOwnProp("PIDCreationIdentity")
        && stateObj.PIDCreationIdentity != "" && ProcessExist(pid)) {
        currentCreationIdentity := App.processInspector.GetCreationIdentity(pid)
        if (currentCreationIdentity == ""
            || currentCreationIdentity == stateObj.PIDCreationIdentity)
            return true
    }
    stateObj.PID := pid
    stateObj.LastKnownPID := pid
    stateObj.PIDCreationIdentity := currentCreationIdentity != ""
        ? currentCreationIdentity
        : App.processInspector.GetCreationIdentity(pid)
    stateObj.PIDImagePath := App.processInspector.GetImagePath(pid)
    stateObj.LastKnownPIDCreationIdentity := stateObj.PIDCreationIdentity
    stateObj.PIDElevationState := -1
    stateObj.PIDElevationChecked := false
    return true
}

EnsureStateProcessElevation(stateObj) {
    if !stateObj || !stateObj.HasOwnProp("PID") || !stateObj.PID
        return -1
    if stateObj.HasOwnProp("PIDElevationChecked") && stateObj.PIDElevationChecked
        return stateObj.HasOwnProp("PIDElevationState")
            ? stateObj.PIDElevationState : -1
    stateObj.PIDElevationState :=
        App.processInspector.GetElevationState(stateObj.PID)
    stateObj.PIDElevationChecked := true
    return stateObj.PIDElevationState
}

IsRunAsAdminMismatch(stateObj) {
    return stateObj.RunAsAdmin
        && EnsureStateProcessElevation(stateObj) == 0
}

UpdateRunningState(path, stateObj, expectedGeneration := 0) {
    path := NormalizeTargetPath(path)
    if !App.appStates.Has(path) || App.appStates[path] != stateObj
        return false
    if !stateObj.Enabled || (expectedGeneration
        && stateObj.Generation != expectedGeneration)
        return false
    if !expectedGeneration
        expectedGeneration := stateObj.Generation
    mismatchStatus := "⚠️ 运行中（权限不符）"
    permissionMismatch := IsRunAsAdminMismatch(stateObj)
    if (!App.appStates.Has(path) || App.appStates[path] != stateObj
        || !stateObj.Enabled || stateObj.Generation != expectedGeneration)
        return false
    stateObj.TransitionTo(GuardPhase.Running)
    if permissionMismatch {
        if (stateObj.State != mismatchStatus)
            LogMsg("检测到运行中的目标未使用管理员权限: " path)
        UpdateState(path, mismatchStatus, stateObj, expectedGeneration)
        return false
    }
    UpdateState(path, "✅ 运行中", stateObj, expectedGeneration)
    return true
}

DoesProcessMatchTarget(pid, targetPath, stateObj := "") {
    if !pid || !ProcessExist(pid)
        return false
    if stateObj && stateObj.HasOwnProp("PIDCreationIdentity")
        && stateObj.PIDCreationIdentity != "" {
        currentCreation := App.processInspector.GetCreationIdentity(pid)
        if (currentCreation != "" && currentCreation != stateObj.PIDCreationIdentity)
            return false
    }
    specs := App.targetSpecsService.Get(targetPath, stateObj)
    if (specs.Probe.Kind != TargetProbeKind.ImagePath)
        return true
    imagePath := App.processInspector.GetImagePath(pid)
    if (imagePath == "" && stateObj && stateObj.HasOwnProp("PIDImagePath"))
        imagePath := stateObj.PIDImagePath
    ; 访问受限且没有任何已知镜像路径时保留同一创建身份，避免把查询失败误判为停止。
    return imagePath == "" || PathsEquivalent(imagePath,
        specs.Probe.TargetPath)
}

StateProcessIdentityIsValid(path, stateObj) {
    return stateObj && stateObj.PID
        && DoesProcessMatchTarget(stateObj.PID, path, stateObj)
}

ObserveTarget(target, snapshotIndex := "", maximumSnapshotAgeMs := 0) {
    target := NormalizeTargetPath(target)
    stateObj := App.appStates.Has(target) ? App.appStates[target] : ""
    specs := App.targetSpecsService.Get(target, stateObj)
    return App.targetProbe.Observe(specs.Probe, snapshotIndex,
        maximumSnapshotAgeMs)
}

IsOneShotTarget(path, resolvedTarget := "") {
    descriptor := ShortcutDescriptor(path)
    SplitPath(path, , , &extension)
    if (StrLower(extension) == "lnk" && FileExist(path))
        descriptor := App.shortcutTargetResolver.Read(path)
    specs := TargetSpecFactory.Create(path, {
        ResolvedTarget: resolvedTarget,
        EntryExists: !InStr(path, "\") || !!FileExist(path),
        ResolvedTargetExists: resolvedTarget != "" && !!FileExist(resolvedTarget),
        ShortcutArguments: descriptor.Arguments,
        ShortcutWorkingDirectory: descriptor.WorkingDirectory,
        ShortcutReadable: descriptor.Readable,
        ShortcutTargetsGenericLauncher: descriptor.Readable
            && App.shortcutTargetResolver.IsGenericLauncher(
                descriptor.TargetPath)
    })
    return specs.IsOneShot
}

RegisterApp(path, enabled := 1, runAsAdmin := 0, workingDirectory := "", arguments := "", environment := "", maintenanceConfig := "", storedResolvedTarget := "", resolvedTargetManual := false, shortcutArguments := "", displayConfig := "") {
    path := NormalizeTargetPath(path)
    if (path == "")
        return false
    ; 目录仅用于批量导入，不能作为可启动/可探活的单个目标。
    if DirExist(path)
        return false
    if App.appStates.Has(path)
        return false
    resolvedTarget := ""
    resolutionSource := ""
    SplitPath(path, , , &pathExtension)
    if (StrLower(pathExtension) == "lnk")
        resolvedTarget := App.shortcutTargetResolver.ResolveForState(path,
            storedResolvedTarget, &resolutionSource, resolvedTargetManual)
    if (StrLower(pathExtension) == "lnk" && FileExist(path)) {
        descriptor := App.shortcutTargetResolver.Read(path)
        if descriptor.Readable {
            if (shortcutArguments == "")
                shortcutArguments := descriptor.Arguments
            if (workingDirectory == "")
                workingDirectory := descriptor.WorkingDirectory
        }
    }
    identityTarget := resolvedTarget != "" ? resolvedTarget
        : (App.shortcutTargetResolver.IsPotentialProcessTarget(path)
            ? path : "")
    if App.targetIdentityService.FindConflict(identityTarget)
        return false
    normalizedMaintenance := App.maintenanceConfigCodec.Normalize(
        maintenanceConfig, path)
    if (StrLower(pathExtension) == "lnk" && resolvedTarget != "") {
        requestedMaintenance := false
        if (maintenanceConfig && Type(maintenanceConfig) == "Object"
            && maintenanceConfig.HasOwnProp("Enabled"))
            requestedMaintenance := !!maintenanceConfig.Enabled
        normalizedMaintenance.Enabled := requestedMaintenance
            && IsMaintenanceSupportedTarget(resolvedTarget)
        if (!normalizedMaintenance.RootIsCustom || normalizedMaintenance.InstallRoot == "") {
            SplitPath(resolvedTarget, , &resolvedDirectory)
            normalizedMaintenance.InstallRoot := NormalizeMaintenanceRoot(resolvedDirectory)
        }
    }
    fingerprintTarget := resolvedTarget != "" ? resolvedTarget : path
    currentFingerprint := App.targetFileInspector.GetFingerprint(
        fingerprintTarget)
    displayConfig := App.displayConfigCodec.Normalize(displayConfig)
    App.appStates[path] := TargetSupervisor({
        State: "初始化...", FailCount: 0, Pending: false, Enabled: enabled ? 1 : 0,
        TargetStartTicks: 0, RunAsAdmin: runAsAdmin ? 1 : 0, WorkDir: workingDirectory,
        Args: arguments, ShortcutArgs: shortcutArguments, EnvVars: environment,
        PID: 0, LastKnownPID: 0, PIDCreationIdentity: "", PIDImagePath: "",
        PIDElevationState: -1, PIDElevationChecked: false,
        LastKnownPIDCreationIdentity: "",
        ResolvedTarget: resolvedTarget, ShortcutTargetSource: resolutionSource,
        ResolvedTargetManual: !!resolvedTargetManual,
        ShortcutResolveCheckedTicks: GetTickCount64(),
        VerifyAttempts: 0,
        OneShot: IsOneShotTarget(path, resolvedTarget), MaintenanceConfig: normalizedMaintenance,
        MaintenanceMode: MaintenancePhase.Normal, MaintenanceStartedTicks: 0,
        MaintenanceStartedAt: "", MaintenanceLastActivityTicks: 0,
        MaintenanceRestartDueTicks: 0, MaintenanceBaselineFingerprint: currentFingerprint,
        ArbitrationSnapshotRequestTicks: 0, ArbitrationSignalBaselineTicks: 0,
        MaintenanceFileChanged: false, ExplicitMaintenance: false,
        MaintenanceWatcherRoot: "", MaintenanceWatcherPath: "", KnownActorIdentities: Map(),
        TransientActorIdentities: Map(), LastActorSeenTicks: 0, LastFileActivityTicks: 0,
        MaintenanceFingerprintCheckedTicks: 0,
        MaintenanceReadyCheckedTicks: 0, MaintenanceLastReady: true,
        SafetyFingerprint: currentFingerprint, SafetyStableSince: GetTickCount64(),
        MaintenanceLearningCandidates: Map(), MissingSinceTicks: 0,
        DisplayConfig: displayConfig, TargetSpecs: "", TargetSpecsFingerprint: "",
        Scheduler: App.scheduler
    })
    App.targetSpecsService.Get(path, App.appStates[path], true)
    App.appOrder.Push(path)
    if enabled
        App.maintenanceCoordinator.EnsureWatcher(path, App.appStates[path])
    try {
        stateObj := App.appStates[path]
        iconIdx := GetMainListIconIndex(path, stateObj, Main.lv.IL)
        statusText := enabled ? "初始化..." : "⏸️ 已暂停"
        row := Main.lv.Add("Icon" iconIdx,
            FormatMainListLabel(GetMainDisplayName(path, stateObj), runAsAdmin),
            FormatMainStatusLabel(statusText), path)
        Main.listProjection.Remember(path, row)
        SetMainListStatus(row, statusText)
        return true
    } catch as projectionErr {
        App.maintenanceCoordinator.CloseWatcher(App.appStates[path])
        App.appStates.Delete(path)
        RemoveAppOrderPath(path)
        LogMsg("添加监控项失败，已回滚内存状态: " projectionErr.Message)
        return false
    }
}

ToggleItemPause(*) {
    if (Main.lv.GetNext(0) == 0)
        return

    App.editSessionId++
    undoState := CaptureAppConfigState()
    row := 0
    changedAny := false

    Loop {
        row := Main.lv.GetNext(row)
        if (row == 0)
            break

        chkPath := Main.lv.GetText(row, 3)
        if App.appStates.Has(chkPath) {
            newState := !App.appStates[chkPath].Enabled
            App.appStates[chkPath].Enabled := newState
            if (!newState) {
                App.appStates[chkPath].CancelScheduledTasks()
                App.appStates[chkPath].TransitionTo(GuardPhase.Paused)
                App.maintenanceCoordinator.CleanupTarget(chkPath, App.appStates[chkPath], true)
                UpdateState(chkPath, "⏸️ 已暂停")
                App.appStates[chkPath].Pending := false
                App.appStates[chkPath].TargetStartTicks := 0
                App.appStates[chkPath].FailCount := 0
                ClearStateProcessIdentity(App.appStates[chkPath])
            } else {
                App.appStates[chkPath].CancelScheduledTasks()
                App.appStates[chkPath].TransitionTo(GuardPhase.Initializing)
                App.maintenanceCoordinator.ResetSession(chkPath, App.appStates[chkPath], false)
                App.maintenanceCoordinator.EnsureWatcher(chkPath, App.appStates[chkPath])
                App.appStates[chkPath].Pending := false
                App.appStates[chkPath].TargetStartTicks := 0
                App.appStates[chkPath].FailCount := 0
                ClearStateProcessIdentity(App.appStates[chkPath])
                UpdateState(chkPath, "初始化...")
            }
            LogMsg((newState ? "恢复" : "暂停") "守护: " chkPath)
            changedAny := true
        }
    }

    if (changedAny) {
        CommitUndoState(undoState)
        SaveAppsToIni()
        OnLVSelectChange() ; 刷新按钮显示状态
    }
    ControlFocus(Main.lv) ; 保持选中行使用活动焦点配色
}

OnDoubleClick(GuiCtrlObj, Item) {
    TriggerEdit(GuiCtrlObj, Item)
}

TriggerEdit(GuiCtrlObj, Item) {
    App.editSessionId++
    rows := []
    row := 0
    Loop {
        row := GuiCtrlObj.GetNext(row)
        if (!row)
            break
        rows.Push(row)
    }
    if (rows.Length == 0 && Item > 0)
        rows.Push(Item)

    if (rows.Length == 0)
        return

    App.batchEditRows := rows
    StartNextInlineEdit(GuiCtrlObj, App.editSessionId)
}

StartNextInlineEdit(GuiCtrlObj, sessionId := 0) {
    if (sessionId && sessionId != App.editSessionId)
        return
    if (App.batchEditRows.Length > 0) {
        Item := App.batchEditRows.RemoveAt(1)
        GuiCtrlObj.Opt("-ReadOnly")
        realPath := GuiCtrlObj.GetText(Item, 3)
        GuiCtrlObj.Modify(Item, "Col1", realPath) ; 临时变成真实路径
        SendMessage(0x1076, Item - 1, 0, GuiCtrlObj.Hwnd)

        App.editMonitorItem := Item
        hEdit := SendMessage(0x1018, 0, 0, GuiCtrlObj.Hwnd)
        if hEdit {
            SetDarkControl(hEdit)
            RegisterTextInputHwnd(hEdit)
            App.activeInlineEditHwnd := hEdit
        }
        SetTimer(CheckEditMonitor.Bind(GuiCtrlObj, sessionId), 100)
    }
}

CheckEditMonitor(GuiCtrlObj, sessionId := 0) {
    if (sessionId && sessionId != App.editSessionId) {
        SetTimer(, 0)
        hEdit := 0
        try hEdit := SendMessage(0x1018, 0, 0, GuiCtrlObj.Hwnd)
        if hEdit
            try SendMessage(0x0100, 27, 0, hEdit)
        if App.activeInlineEditHwnd {
            App.uiInteractions.RemoveTextInput(App.activeInlineEditHwnd)
            App.activeInlineEditHwnd := 0
        }
        try GuiCtrlObj.Opt("+ReadOnly")
        return
    }
    hEdit := SendMessage(0x1018, 0, 0, GuiCtrlObj.Hwnd)
    if (!hEdit) {
        SetTimer(, 0)
        if App.activeInlineEditHwnd {
            App.uiInteractions.RemoveTextInput(App.activeInlineEditHwnd)
            App.activeInlineEditHwnd := 0
        }
        GuiCtrlObj.Opt("+ReadOnly")
        SetTimer(ProcessEditFinish.Bind(GuiCtrlObj, App.editMonitorItem, sessionId), -50)
    }
}

ProcessEditFinish(GuiCtrlObj, Item, sessionId := 0) {
    if (sessionId && sessionId != App.editSessionId)
        return
    try {
        newPath := NormalizeTargetPath(GuiCtrlObj.GetText(Item, 1))
        previousPath := GuiCtrlObj.GetText(Item, 3)

        if (newPath != "" && newPath != previousPath) {
            prospectiveResolvedTarget := ""
            prospectiveResolutionSource := ""
            prospectiveShortcutArgs := ""
            prospectiveWorkingDirectory := ""
            SplitPath(newPath, , , &prospectiveExtension)
            if (StrLower(prospectiveExtension) == "lnk") {
                prospectiveResolvedTarget := App.shortcutTargetResolver
                    .ResolveForState(newPath, "", &prospectiveResolutionSource)
                descriptor := App.shortcutTargetResolver.Read(newPath)
                if descriptor.Readable {
                    prospectiveWorkingDirectory := descriptor.WorkingDirectory
                    prospectiveShortcutArgs := descriptor.Arguments
                }
            }
            prospectiveIdentity := prospectiveResolvedTarget != ""
                ? prospectiveResolvedTarget
                : (App.shortcutTargetResolver.IsPotentialProcessTarget(newPath)
                    ? newPath : "")
            identityConflict := App.targetIdentityService.FindConflict(
                prospectiveIdentity, previousPath)
            if DirExist(newPath) {
                newPath := previousPath
            } else if !App.appStates.Has(previousPath) {
                ; 状态已被其它操作移除时，不能只改 ListView 而留下无状态孤儿行。
                newPath := previousPath
            } else if App.appStates.Has(newPath) {
                LogMsg("拒绝将应用路径改为已存在的监控项: " newPath)
                newPath := previousPath
            } else if (identityConflict != "") {
                LogMsg("拒绝修改路径，真实进程已由其它项目守护: " identityConflict)
                newPath := previousPath
            } else {
                undoState := CaptureAppConfigState()
                stateObj := App.appStates[previousPath]
                stateObj.CancelScheduledTasks()
                App.maintenanceCoordinator.CleanupTarget(previousPath, stateObj, true)
                stateObj.Pending := false
                stateObj.TargetStartTicks := 0
                stateObj.FailCount := 0
                ClearStateProcessIdentity(stateObj)
                stateObj.VerifyAttempts := 0
                stateObj.ResolvedTarget := ""
                stateObj.ResolvedTargetManual := false
                stateObj.ShortcutTargetSource := ""
                stateObj.ShortcutArgs := ""
                SplitPath(newPath, , , &newExtension)
                if (StrLower(newExtension) == "lnk") {
                    stateObj.ResolvedTarget := prospectiveResolvedTarget
                    stateObj.ShortcutTargetSource := prospectiveResolutionSource
                    stateObj.ShortcutArgs := prospectiveShortcutArgs
                    if (prospectiveWorkingDirectory != "")
                        stateObj.WorkDir := prospectiveWorkingDirectory
                }
                stateObj.ShortcutResolveCheckedTicks := GetTickCount64()
                stateObj.OneShot := IsOneShotTarget(newPath, stateObj.ResolvedTarget)
                App.targetSpecsService.Get(newPath, stateObj, true)
                stateObj.MaintenanceConfig := App.maintenanceConfigCodec.Normalize(
                    stateObj.MaintenanceConfig, newPath)
                fingerprintTarget := stateObj.ResolvedTarget != "" ? stateObj.ResolvedTarget : newPath
                stateObj.MaintenanceBaselineFingerprint := App
                    .targetFileInspector.GetFingerprint(fingerprintTarget)
                stateObj.SafetyFingerprint := stateObj.MaintenanceBaselineFingerprint
                stateObj.SafetyStableSince := GetTickCount64()
                stateObj.KnownActorIdentities := Map()
                stateObj.TransientActorIdentities := Map()
                stateObj.LastActorSeenTicks := 0
                stateObj.LastFileActivityTicks := 0
                stateObj.State := "初始化..."
                stateObj.TransitionTo(GuardPhase.Initializing)
                App.appStates.Delete(previousPath)
                App.appStates[newPath] := stateObj
                ReplaceAppOrderPath(previousPath, newPath)
                App.maintenanceCoordinator.EnsureWatcher(newPath, stateObj)
                GuiCtrlObj.Modify(Item, "Col3", newPath)
                SetMainListStatus(Item, "初始化...")
                iconIdx := GetMainListIconIndex(newPath, stateObj, GuiCtrlObj.IL)
                if iconIdx
                    GuiCtrlObj.Modify(Item, "Icon" iconIdx)
                Main.listProjection.Rebuild(GuiCtrlObj)
                CommitUndoState(undoState)
                SaveAppsToIni()
                LogMsg("更新了应用程序路径。")
            }
        }

        realPath := GuiCtrlObj.GetText(Item, 3)
        stateObj := App.appStates.Has(realPath) ? App.appStates[realPath] : ""
        isAdmin := stateObj && stateObj.HasOwnProp("RunAsAdmin") ? stateObj.RunAsAdmin : 0
        GuiCtrlObj.Modify(Item, "Col1", FormatMainListLabel(
            GetMainDisplayName(realPath, stateObj), isAdmin)) ; 恢复显示应用名
    } catch {
        realPath := GuiCtrlObj.GetText(Item, 3)
        stateObj := App.appStates.Has(realPath) ? App.appStates[realPath] : ""
        isAdmin := stateObj && stateObj.HasOwnProp("RunAsAdmin") ? stateObj.RunAsAdmin : 0
        GuiCtrlObj.Modify(Item, "Col1", FormatMainListLabel(
            GetMainDisplayName(realPath, stateObj), isAdmin))
    }
    StartNextInlineEdit(GuiCtrlObj, sessionId)
}

CaptureAppConfigState() {
    state := []
    try {
        Loop Main.lv.GetCount() {
            savePath := Main.lv.GetText(A_Index, 3)
            stateObj := App.appStates.Has(savePath)
                ? App.appStates[savePath] : ""
            snapshot := App.appConfigSnapshotService.CreateSnapshot(savePath,
                stateObj)
            if !snapshot
                throw Error("监控项路径无效: " savePath)
            state.Push(snapshot)
        }
    } catch as snapshotError {
        LogMsg("捕获监控项历史失败: " snapshotError.Message)
        return ""
    }
    return state
}

AppConfigStateOrderMatchesCurrent(state) {
    if (Type(state) != "Array" || state.Length != Main.lv.GetCount())
        return false
    for index, item in state {
        if !item.HasOwnProp("Path")
            return false
        if !PathsEquivalent(item.Path, Main.lv.GetText(index, 3))
            return false
    }
    return true
}

CommitUndoState(beforeState) {
    if (Type(beforeState) != "Array")
        return false
    afterState := CaptureAppConfigState()
    return App.appConfigHistoryService.Commit(beforeState, afterState)
}

PerformUndo() {
    if App.appConfigHistoryService.Undo(
        (targetState, sourceState) => ApplyState(targetState, sourceState))
        LogMsg("已撤销上一步操作。")
}

PerformRedo() {
    if App.appConfigHistoryService.Redo(
        (targetState, sourceState) => ApplyState(targetState, sourceState))
        LogMsg("已重做操作。")
}

CaptureMainListInteraction() {
    selectedPaths := Map()
    selectedPaths.CaseSense := "Off"
    row := 0
    Loop {
        row := Main.lv.GetNext(row)
        if !row
            break
        selectedPaths[Main.lv.GetText(row, 3)] := true
    }
    focusedRow := Main.lv.GetNext(0, "Focused")
    return {
        SelectedPaths: selectedPaths,
        FocusedPath: focusedRow ? Main.lv.GetText(focusedRow, 3) : "",
        HadKeyboardFocus: DllCall("user32\GetFocus", "Ptr") == Main.lv.Hwnd
    }
}

RestoreMainListInteraction(interaction) {
    Main.lv.Modify(0, "-Select -Focus")
    focusRow := 0
    firstSelectedRow := 0
    Loop Main.lv.GetCount() {
        path := Main.lv.GetText(A_Index, 3)
        if interaction.SelectedPaths.Has(path) {
            Main.lv.Modify(A_Index, "Select")
            if !firstSelectedRow
                firstSelectedRow := A_Index
        }
        if (interaction.FocusedPath != "" && PathsEquivalent(path, interaction.FocusedPath))
            focusRow := A_Index
    }
    if !focusRow
        focusRow := firstSelectedRow
    if focusRow
        Main.lv.Modify(focusRow, "Focus")
    if interaction.HadKeyboardFocus
        ControlFocus(Main.lv)
}

ApplyAppConfigTransition(path, stateObj, sourceItem, targetItem) {
    currentResolvedTarget := NormalizeTargetPath(stateObj.ResolvedTarget)
    currentResolvedTargetManual := !!stateObj.ResolvedTargetManual
    identityTransition := !PathsEquivalent(sourceItem.ResolvedTarget,
        targetItem.ResolvedTarget)
        || !!sourceItem.ResolvedTargetManual != !!targetItem.ResolvedTargetManual
    identityChanged := identityTransition
        && PathsEquivalent(currentResolvedTarget, sourceItem.ResolvedTarget)
        && currentResolvedTargetManual == !!sourceItem.ResolvedTargetManual
    nextResolvedTarget := identityChanged ? targetItem.ResolvedTarget
        : currentResolvedTarget
    nextResolvedTargetManual := identityChanged ? !!targetItem.ResolvedTargetManual
        : currentResolvedTargetManual
    enabledChanged := !!sourceItem.Enabled != !!targetItem.Enabled
        && !!stateObj.Enabled == !!sourceItem.Enabled
    nextEnabled := enabledChanged ? !!targetItem.Enabled : !!stateObj.Enabled

    previousMaintenance := App.maintenanceConfigCodec.NormalizeSnapshot(
        stateObj.MaintenanceConfig, path, currentResolvedTarget)
    nextMaintenance := App.appConfigSnapshotService
        .MergeMaintenanceTransition(previousMaintenance,
            sourceItem.Maintenance, targetItem.Maintenance,
            !identityTransition || identityChanged)
    nextDisplay := App.appConfigSnapshotService.MergeDisplayTransition(
        stateObj.HasOwnProp("DisplayConfig") ? stateObj.DisplayConfig : "",
        sourceItem.Display, targetItem.Display)
    maintenanceChanged := !App.maintenanceConfigCodec.Equals(
        previousMaintenance, nextMaintenance)
    maintenanceRootChanged := !PathsEquivalent(previousMaintenance.InstallRoot,
        nextMaintenance.InstallRoot)
    previousProtectionEnabled := previousMaintenance.Enabled

    if (identityChanged || enabledChanged) {
        stateObj.CancelScheduledTasks()
        App.maintenanceCoordinator.CleanupTarget(path, stateObj, false)
    } else if (maintenanceChanged && previousProtectionEnabled
        && !nextMaintenance.Enabled) {
        App.maintenanceCoordinator.CleanupTarget(path, stateObj, false)
    } else if (maintenanceChanged && maintenanceRootChanged) {
        App.maintenanceCoordinator.CloseWatcher(stateObj)
    }

    if (!!sourceItem.RunAsAdmin != !!targetItem.RunAsAdmin
        && !!stateObj.RunAsAdmin == !!sourceItem.RunAsAdmin)
        stateObj.RunAsAdmin := targetItem.RunAsAdmin
    for propertyName in ["WorkDir", "Args", "ShortcutArgs", "EnvVars"] {
        if (sourceItem.%propertyName% != targetItem.%propertyName%
            && stateObj.%propertyName% == sourceItem.%propertyName%)
            stateObj.%propertyName% := targetItem.%propertyName%
    }
    stateObj.ResolvedTarget := nextResolvedTarget
    stateObj.ResolvedTargetManual := nextResolvedTargetManual
    stateObj.MaintenanceConfig := nextMaintenance
    stateObj.DisplayConfig := nextDisplay

    if identityChanged {
        stateObj.ShortcutTargetSource := nextResolvedTarget == "" ? ""
            : (nextResolvedTargetManual ? "用户指定" : "已保存身份")
        stateObj.ShortcutResolveCheckedTicks := GetTickCount64()
        stateObj.OneShot := IsOneShotTarget(path, nextResolvedTarget)
    }

    stateObj.Enabled := nextEnabled ? 1 : 0
    App.targetSpecsService.Get(path, stateObj, true)
    if (identityChanged || enabledChanged) {
        stateObj.Pending := false
        stateObj.TargetStartTicks := 0
        stateObj.FailCount := 0
        stateObj.VerifyAttempts := 0
        ClearStateProcessIdentity(stateObj)
        fingerprintTarget := nextResolvedTarget != "" ? nextResolvedTarget : path
        refreshedFingerprint := App.targetFileInspector.GetFingerprint(
            fingerprintTarget)
        stateObj.MaintenanceBaselineFingerprint := refreshedFingerprint
        stateObj.SafetyFingerprint := refreshedFingerprint
        stateObj.SafetyStableSince := GetTickCount64()
        stateObj.MaintenanceFingerprintCheckedTicks := 0
        stateObj.MaintenanceReadyCheckedTicks := 0
        stateObj.State := nextEnabled ? "初始化..." : "⏸️ 已暂停"
        stateObj.TransitionTo(nextEnabled ? GuardPhase.Initializing
            : GuardPhase.Paused)
        if nextEnabled
            App.maintenanceCoordinator.EnsureWatcher(path, stateObj)
        else
            App.maintenanceCoordinator.CloseWatcher(stateObj)
    } else if maintenanceChanged {
        if nextMaintenance.Enabled
            App.maintenanceCoordinator.EnsureWatcher(path, stateObj)
        else
            App.maintenanceCoordinator.CloseWatcher(stateObj)
        if (previousProtectionEnabled && !nextMaintenance.Enabled && stateObj.Enabled) {
            stateObj.State := "初始化..."
            stateObj.TransitionTo(GuardPhase.Initializing)
            App.guardRuntime.ScheduleRestart(path, 200)
        }
    }
    return {
        JournalChanged: identityChanged || enabledChanged
            || (maintenanceChanged && previousProtectionEnabled
                && !nextMaintenance.Enabled)
    }
}

SyncMainListToConfigState(items) {
    targetPaths := Map()
    targetPaths.CaseSense := "Off"
    for item in items
        targetPaths[item.Path] := true

    seenRows := Map()
    seenRows.CaseSense := "Off"
    row := Main.lv.GetCount()
    while (row > 0) {
        path := Main.lv.GetText(row, 3)
        if !targetPaths.Has(path) || seenRows.Has(path)
            Main.lv.Delete(row)
        else
            seenRows[path] := true
        row--
    }
    Main.listProjection.Rebuild(Main.lv)

    projectedRow := 0
    for item in items {
        if !App.appStates.Has(item.Path)
            continue
        projectedRow++
        currentRow := 0
        if (projectedRow <= Main.lv.GetCount()
            && StrLower(Main.lv.GetText(projectedRow, 3)) == StrLower(item.Path))
            currentRow := projectedRow
        else
            currentRow := FindRow(item.Path)
        stateObj := App.appStates[item.Path]
        displayName := FormatMainListLabel(
            GetMainDisplayName(item.Path, stateObj), stateObj.RunAsAdmin)
        displayStatus := FormatMainStatusLabel(stateObj.State)
        if (currentRow != projectedRow) {
            if currentRow
                Main.lv.Delete(currentRow)
            iconIndex := GetMainListIconIndex(item.Path, stateObj, Main.lv.IL)
            insertedRow := Main.lv.Insert(projectedRow, "Icon" iconIndex,
                displayName, displayStatus, item.Path)
            SetMainListStatus(insertedRow, stateObj.State)
        } else {
            if (Main.lv.GetText(currentRow, 1) != displayName)
                Main.lv.Modify(currentRow, "Col1", displayName)
            if (Main.lv.GetText(currentRow, 2) != displayStatus)
                SetMainListStatus(currentRow, stateObj.State)
            iconIndex := GetMainListIconIndex(item.Path, stateObj, Main.lv.IL)
            if iconIndex
                Main.lv.Modify(currentRow, "Icon" iconIndex)
        }
    }

    App.appOrder := []
    for item in items {
        if App.appStates.Has(item.Path)
            App.appOrder.Push(item.Path)
    }
    Main.listProjection.Rebuild(Main.lv)
}

ApplyState(stateArr, sourceStateArr := "") {
    App.editSessionId++
    App.batchEditRows := []
    App.editMonitorItem := 0
    Main.contextTargetRow := 0
    currentState := CaptureAppConfigState()
    preparedState := App.appConfigSnapshotService.PrepareState(stateArr)
    sourceState := App.appConfigSnapshotService.PrepareState(sourceStateArr)
    isTransition := Type(sourceStateArr) == "Array"
    interaction := CaptureMainListInteraction()
    Main.lv.Opt("-Redraw")
    try {
        journalChanged := false
        pathsToRemove := []
        if isTransition {
            for sourcePath, sourceItem in sourceState.Index {
                if !preparedState.Index.Has(sourcePath) && App.appStates.Has(sourcePath)
                    pathsToRemove.Push(sourcePath)
            }
        } else {
            for existingPath, existingState in App.appStates {
                if !preparedState.Index.Has(existingPath)
                    pathsToRemove.Push(existingPath)
            }
        }
        for existingPath in pathsToRemove {
            existingState := App.appStates[existingPath]
            existingState.CancelScheduledTasks()
            App.maintenanceCoordinator.CleanupTarget(existingPath, existingState, false)
            App.appStates.Delete(existingPath)
            journalChanged := true
        }

        for item in preparedState.Items {
            if !App.appStates.Has(item.Path)
                continue
            if (isTransition && sourceState.Index.Has(item.Path)) {
                sourceItem := sourceState.Index[item.Path]
                if !App.appConfigSnapshotService.SnapshotsEqual(sourceItem,
                    item) {
                    transitionResult := ApplyAppConfigTransition(item.Path,
                        App.appStates[item.Path],
                        sourceItem, item)
                    journalChanged := journalChanged || transitionResult.JournalChanged
                }
            } else if !isTransition {
                currentItem := App.appConfigSnapshotService.CreateSnapshot(
                    item.Path, App.appStates[item.Path])
                transitionResult := ApplyAppConfigTransition(item.Path,
                    App.appStates[item.Path],
                    currentItem, item)
                journalChanged := journalChanged || transitionResult.JournalChanged
            }
        }
        for item in preparedState.Items {
            shouldAdd := !App.appStates.Has(item.Path)
                && (!isTransition || !sourceState.Index.Has(item.Path))
            if shouldAdd {
                RegisterApp(item.Path, item.Enabled, item.RunAsAdmin, item.WorkDir, item.Args,
                    item.EnvVars, item.Maintenance, item.ResolvedTarget,
                    item.ResolvedTargetManual, item.ShortcutArgs, item.Display)
            }
        }
        projectedItems := isTransition
            ? App.appConfigSnapshotService.MergeTransitionOrder(currentState,
                sourceState.Items, preparedState.Items)
            : preparedState.Items
        SyncMainListToConfigState(projectedItems)
        if journalChanged
            App.maintenanceCoordinator.SaveJournal()
        SaveAppsToIni()
    } finally {
        try Main.lv.Opt("+Redraw")
        try RestoreMainListInteraction(interaction)
    }
    OnLVSelectChange()
}

SaveAppsToIni() {
    static isSaving := false
    previousCritical := A_IsCritical
    Critical("On")
    if isSaving {
        Critical(previousCritical ? previousCritical : "Off")
        return false
    }
    isSaving := true
    try {
        saveResult := App.watchlistPersistenceService.Save(App.appOrder,
            App.appStates, App.configRecoveryEntries)
        App.appOrder := saveResult.OrderedPaths
        App.appsDirty := false
        App.configSaveRetryDelayMs := 5000
        try SetTimer(App.configSaveRetryTimer, 0)
        return true
    } catch as saveErr {
        App.appsDirty := true
        LogMsg("保存监控配置失败: " saveErr.Message)
        nowTicks := GetTickCount64()
        if (nowTicks - App.lastSaveWarningTicks > 10000) {
            try TrayTip("监控配置尚未保存，请查看运行日志。", "进程守护小助手", 3)
            App.lastSaveWarningTicks := nowTicks
        }
        retryDelayMs := App.configSaveRetryDelayMs
        App.configSaveRetryDelayMs := Min(retryDelayMs * 2, 60000)
        try SetTimer(App.configSaveRetryTimer, -retryDelayMs)
        return false
    } finally {
        isSaving := false
        Critical(previousCritical ? previousCritical : "Off")
    }
}

SyncAppOrderFromListView() {
    newOrder := []
    Loop Main.lv.GetCount() {
        path := Main.lv.GetText(A_Index, 3)
        if App.appStates.Has(path)
            newOrder.Push(path)
    }
    App.appOrder := newOrder
}

RemoveAppOrderPath(path) {
    for index, existingPath in App.appOrder {
        if PathsEquivalent(existingPath, path) {
            App.appOrder.RemoveAt(index)
            return true
        }
    }
    return false
}

ReplaceAppOrderPath(previousPath, newPath) {
    for index, existingPath in App.appOrder {
        if PathsEquivalent(existingPath, previousPath) {
            App.appOrder[index] := newPath
            return true
        }
    }
    App.appOrder.Push(newPath)
    return false
}

/*  * ========================================================================
 * 核心后台轮询与状态调度 (Heartbeat Polling)
 * ========================================================================
 * 运行于独立时钟周期的循环池：
 * 定时执行进程检查；每轮复用同一个进程快照索引，避免逐项目重复查询或建索引。
 */
UpdateCountdownUI() {
    try UpdateCountdownUICore()
    catch as countdownErr {
        try SetTimer(UpdateCountdownUI, 0)
        LogMsg("刷新主窗口状态失败，已暂停界面倒计时刷新: "
            countdownErr.Message)
    }
}

UpdateCountdownUICore() {
    for appPath, stateObj in App.appStates {
        if (stateObj.Pending && stateObj.TargetStartTicks > 0) {
            rem := (stateObj.TargetStartTicks - GetTickCount64()) // 1000
            if (rem > 0) {
                prefix := stateObj.Phase == GuardPhase.CoolingDown
                    ? "⏳ 稍后自动重试"
                    : (stateObj.FailCount > 0 ? "⏳ 重试倒计时"
                        : "⏳ 启动倒计时")
                UpdateState(appPath, prefix " " rem "s")
            } else if stateObj.Phase != GuardPhase.Verifying {
                UpdateState(appPath, "🚀 正在启动...")
            }
        }
    }
    UpdateStatsUI()
}

UpdateStatsUI() {
    total := App.appStates.Count
    running := 0
    paused := 0
    stopped := 0
    pending := 0
    updating := 0
    invalid := 0

    for _, obj in App.appStates {
        st := obj.State
        if (!obj.Enabled) {
            paused++
        } else if App.maintenanceCoordinator.IsBlocking(obj) {
            updating++
        } else if obj.Phase == GuardPhase.CoolingDown {
            pending++
        } else if InStr(st, "不存在") {
            invalid++
        } else if InStr(st, "运行中") {
            running++
        } else if InStr(st, "已停止") || InStr(st, "疑似停止") || InStr(st, "启动失败") || InStr(st, "非驻留") {
            stopped++
        } else if InStr(st, "倒计时") || InStr(st, "启动") || InStr(st, "验证") || InStr(st, "初始化") {
            pending++
        }
    }

    statsStr := "✅ 运行: " running "   🚫 停止: " stopped "   ⏳ 恢复: " pending "   🔄 升级: " updating "   ⏸️ 暂停: " paused "   ❌ 失效: " invalid "   |   🎯 总计: " total
    if App.appsDirty
        statsStr .= "   ⚠️ 配置未保存"
    if (Main.statsText.Text != statsStr) {
        Main.statsText.Text := statsStr
    }
}

UpdateState(updPath, statusStr, expectedState := "",
    expectedGeneration := 0) {
    updPath := NormalizeTargetPath(updPath)
    if !App.appStates.Has(updPath)
        return
    stateObj := App.appStates[updPath]
    if (expectedState != "" && stateObj != expectedState)
        return false
    if (expectedGeneration && stateObj.Generation != expectedGeneration)
        return false
    if (stateObj.State != statusStr) {
        stateObj.State := statusStr
        row := FindRow(updPath)
        if (row > 0)
            SetMainListStatus(row, statusStr)
    }
    return true
}

FindRow(searchPath) {
    return Main.listProjection.Find(Main.lv, searchPath)
}

/*  * ========================================================================
 * 温柔关闭策略 (Graceful Shutdown)
 * ========================================================================
 * 三级梯度退出：
 * 1. WM_CLOSE → 向所有窗口发送关闭请求
 * 2. CTRL_C_EVENT → 向控制台程序发送 Ctrl+C
 * 3. TerminateProcess → 暴力击杀兆底
 */
SendConsoleCtrlCWorker(pid) {
    if !pid || !ProcessExist(pid)
        return false
    try DllCall("kernel32\FreeConsole")
    attached := DllCall("kernel32\AttachConsole", "UInt", pid, "Int")
    if !attached
        return false
    sent := false
    try {
        DllCall("kernel32\SetConsoleCtrlHandler", "Ptr", 0, "Int", 1)
        ; 工作进程只连接目标控制台，组 0 因此仅广播给该控制台内的进程。
        sent := !!DllCall("kernel32\GenerateConsoleCtrlEvent", "UInt", Win32.CTRL_C_EVENT,
            "UInt", 0, "Int")
        if sent
            Sleep(100)
    } finally {
        DllCall("kernel32\SetConsoleCtrlHandler", "Ptr", 0, "Int", 0)
        DllCall("kernel32\FreeConsole")
    }
    return sent
}

SendConsoleCtrlC(pid) {
    workerCommand := A_IsCompiled
        ? '"' A_ScriptFullPath '" --send-ctrl-c ' pid
        : '"' A_AhkPath '" "' A_ScriptFullPath '" --send-ctrl-c ' pid
    try return RunWait(workerCommand, A_ScriptDir, "Hide") == 0
    catch
        return false
}

GracefulStop(pid) {
    result := App.targetStopper.Stop(pid, App.gracefulStopSeconds,
        App.ctrlCWaitSeconds, App.allowForceTerminate, SendConsoleCtrlC,
        ElevatedKillProcess)
    switch result.Stage {
        case TargetStopStage.ForceSkipped:
            LogMsg("温和关闭超时，已按设置跳过强制终止 PID: " pid)
        case TargetStopStage.ForceTerminated:
            LogMsg("温和关闭超时，已强制终止进程 PID: " pid)
        case TargetStopStage.ElevatedKill:
            LogMsg("常规终止权限不足，已提权终止进程 PID: " pid)
        case TargetStopStage.Failed:
            errorDetail := result.ErrorMessage != ""
                ? "（" result.ErrorMessage "）" : ""
            LogMsg("无法停止进程 PID: " pid errorDetail)
    }
    return result.Stopped
}

ElevatedKillProcess(pid) {
    try return RunWait("*RunAs taskkill /F /PID " pid, , "Hide") == 0
    catch
        return false
}

LogMsg(msg) {
    msg := NormalizeUserVisibleParentheses(msg)
    App.logMessages.InsertAt(1, Format("{1} - {2}", FormatTime(A_Now, "HH:mm:ss"), msg))
    while (App.logMessages.Length > App.logMaxEntries)
        App.logMessages.Pop()
    App.logRevision++
}

ReadApplicationVersion() {
    versionPath := A_ScriptDir "\VERSION"
    try {
        version := Trim(FileRead(versionPath, "UTF-8"))
        if RegExMatch(version, "^\d+\.\d+\.\d+$")
            return version
    }
    return "0.1.0"
}

BuildDiagnosticStateSummary() {
    phaseCounts := Map()
    maintenanceCounts := Map()
    enabledCount := 0
    pausedCount := 0
    for path, stateObj in App.appStates {
        if stateObj.Enabled
            enabledCount++
        else
            pausedCount++
        try phase := String(stateObj.Phase)
        catch
            phase := "unavailable"
        phaseCounts[phase] := phaseCounts.Has(phase)
            ? phaseCounts[phase] + 1 : 1
        try maintenancePhaseValue := String(stateObj.MaintenanceMode)
        catch
            maintenancePhaseValue := "unavailable"
        maintenanceCounts[maintenancePhaseValue] := maintenanceCounts.Has(
            maintenancePhaseValue) ? maintenanceCounts[maintenancePhaseValue] + 1 : 1
    }

    text := "TargetCount=" App.appStates.Count "`r`n"
        . "EnabledCount=" enabledCount "`r`n"
        . "PausedCount=" pausedCount "`r`n"
        . "CheckIntervalMs=" App.checkInterval "`r`n"
        . "RetrySequence=" App.retrySequence "`r`n"
        . "SchedulerQueue=" App.scheduler.Queue.Length "`r`n"
        . "ConfigWarnings=" App.configLoadWarnings.Length "`r`n"
        . "RecoveryEntries=" App.configRecoveryEntries.Length "`r`n"
        . "LogEntries=" App.logMessages.Length "`r`n"
        . "LogRevision=" App.logRevision "`r`n"
    for phase, count in phaseCounts
        text .= "GuardPhase." phase "=" count "`r`n"
    for phase, count in maintenanceCounts
        text .= "MaintenancePhase." phase "=" count "`r`n"
    return text
}

GetLogText() {
    result := ""
    for entry in App.logMessages
        result .= entry . "`n"
    return result
}

; ==========================================
; 11. 界面按钮事件处理与独立 GUI
; ==========================================
; 注册新监视进程：调用文件选择器后将对象推送至检测队列并入库
AddItem(*) {
    GuiModules.addItem.Show()
}

DelItem(*) {
    row := 0
    delList := []
    Loop {
        row := Main.lv.GetNext(row)
        if (row == 0)
            break
        delList.Push(row)
    }

    if (delList.Length == 0)
        return

    App.editSessionId++
    undoState := CaptureAppConfigState()

    ; 从后往前删防止行号错乱
    Loop delList.Length {
        idx := delList.Length - A_Index + 1
        currRow := delList[idx]
        try {
            delPath := Main.lv.GetText(currRow, 3)
            if App.appStates.Has(delPath) {
                App.appStates[delPath].CancelScheduledTasks()
                App.maintenanceCoordinator.CleanupTarget(delPath, App.appStates[delPath], true)
            }
            App.appStates.Delete(delPath)
            RemoveAppOrderPath(delPath)
            LogMsg("已取消监控: " delPath)
        }
        Main.lv.Delete(currRow)
    }

    Main.listProjection.Rebuild(Main.lv)

    CommitUndoState(undoState)
    SaveAppsToIni()
    Main.contextTargetRow := 0
    OnLVSelectChange() ; 刷新按钮显示状态
}

; ==========================================
; 显示程序基础设置面板界面
; ==========================================
ShowSettings(*) {
    GuiModules.settings.Show()
}

CreateDesktopShortcut(ownerGui := "", *) {
    try {
        desktopPath := A_Desktop "\进程守护小助手.lnk"
        programsPath := A_Programs "\进程守护小助手.lnk"
        scriptPath := A_ScriptFullPath
        iconPath := A_ScriptDir "\watchdog.ico"

        if A_IsCompiled {
            FileCreateShortcut(scriptPath, desktopPath, A_ScriptDir, "", "进程守护小助手", iconPath)
            FileCreateShortcut(scriptPath, programsPath, A_ScriptDir, "", "进程守护小助手", iconPath)
        } else {
            ; 指定快捷方式链接的根目标至 A_AhkPath 原宿主解释器环境，并赋予当前看门狗对应路径的图标定义信息
            FileCreateShortcut(A_AhkPath, desktopPath, A_ScriptDir, '"' scriptPath '"', "进程守护小助手", iconPath, , , 1)
            FileCreateShortcut(A_AhkPath, programsPath, A_ScriptDir, '"' scriptPath '"', "进程守护小助手", iconPath, , , 1)
        }
        ShowDarkMsgBox("桌面与开始菜单快捷方式创建成功！", "成功", "Info", ownerGui)
        LogMsg("已创建桌面与开始菜单快捷方式。")
    } catch as shortcutErr {
        ShowDarkMsgBox("创建快捷方式失败: " shortcutErr.Message, "错误", "Error", ownerGui)
        LogMsg("创建快捷方式失败: " shortcutErr.Message)
    }
}

ShowLog(*) {
    GuiModules.log.Show()
}

ShowHelp(*) {
    GuiModules.help.Show()
}


; ==========================================
; 12. 计划任务机制 (COM 接口高级配置)
; ==========================================
CheckTaskExists() {
    task := GetWatchdogTask()
    return task && IsOwnedWatchdogTask(task)
}

GetWatchdogTask() {
    try {
        service := ComObject("Schedule.Service")
        service.Connect()
        folder := service.GetFolder("\")
        return folder.GetTask("进程守护小助手")
    } catch {
        return ""
    }
}

IsOwnedWatchdogTask(task) {
    try {
        action := task.Definition.Actions.Item(1)
        commandLine := StrLower(action.Path " " action.Arguments)
        return InStr(commandLine, StrLower(A_ScriptFullPath)) > 0
    } catch {
        return false
    }
}

UpdateTaskButtonStatus() {
    GuiModules.settings.UpdateTaskButtonStatus()
}

; 用于添加/移除该看门狗脚本在 Windows 全局的系统自动开机计划任务
ToggleTask(ownerGui := "", *) {
    try {
        service := ComObject("Schedule.Service")
        service.Connect()
        rootFolder := service.GetFolder("\")

        existingTask := GetWatchdogTask()
        if (existingTask && !IsOwnedWatchdogTask(existingTask)) {
            ShowDarkMsgBox("检测到同名计划任务，但它并非当前程序创建；为避免误删，请先在任务计划程序中处理它。", "计划任务冲突", "Error", ownerGui)
            return
        }
        if existingTask {
            ; 删除任务
            rootFolder.DeleteTask("进程守护小助手", 0)
            LogMsg("已删除自启计划任务。")
        } else {
            ; 创建新任务
            taskDef := service.NewTask(0)

            ; 1. 注册信息
            taskDef.RegistrationInfo.Description := "进程守护小助手 - 开机自启守护程序"

            ; 2. 触发器 (开机/登录时触发)
            trigger := taskDef.Triggers.Create(9) ; 9 = TASK_TRIGGER_LOGON

            ; 3. 运行设置 (核心修改区)
            settings := taskDef.Settings
            settings.Enabled := true
            settings.Hidden := false

            ; 电源策略：电池供电时仍允许任务启动，切换供电状态时不停止任务
            settings.DisallowStartIfOnBatteries := false ; 允许在仅用电池时启动
            settings.StopIfGoingOnBatteries := false     ; 拔下电源时不停止任务

            ; 时间管理选项修正：配置全局 ExecutionTimeLimit 约束条件设为关闭(即 "PT0S" 最大长期不受中断)
            settings.ExecutionTimeLimit := "PT0S"        ; PT0S 代表不限制时间

            ; 使用 Windows 10/11 任务定义
            settings.Compatibility := 6

            ; 4. 操作 (通过 cmd start 异步启动，使计划任务能立即标记为“完成”并确保托盘图标正常显示)
            action := taskDef.Actions.Create(0) ; 0 = TASK_ACTION_EXEC
            action.Path := A_ComSpec
            if A_IsCompiled {
                action.Arguments := '/c start "" "' A_ScriptFullPath '"'
            } else {
                action.Arguments := '/c start "" "' A_AhkPath '" "' A_ScriptFullPath '"'
            }
            action.WorkingDirectory := A_ScriptDir

            ; 5. 权限主体 (最高管理员权限运行)
            principal := taskDef.Principal
            principal.RunLevel := 1  ; 1 = TASK_RUNLEVEL_HIGHEST
            principal.LogonType := 3 ; 3 = TASK_LOGON_INTERACTIVE_TOKEN

            ; 6. 注册写入任务
            ; 参数 6 = TASK_CREATE_OR_UPDATE
            rootFolder.RegisterTaskDefinition("进程守护小助手", taskDef, 6, "", "", 3)

            LogMsg("已创建最高权限的开机自启计划任务（Win10配置/适配笔记本）。")
        }

        UpdateTaskButtonStatus()
        ShowDarkMsgBox("计划任务状态已更新。", "提示", "Info", ownerGui)

    } catch as taskErr {
        ShowDarkMsgBox("操作计划任务时发生错误！`n`n" taskErr.Message, "错误", "Error", ownerGui)
        LogMsg("计划任务操作失败: " taskErr.Message)
    }
}

; ==========================================
; 13. 深色自适应用户交互弹窗面板控制方法集合
; ==========================================
CloseDarkMsgBox(mb, ownerLease, &closed) {
    if closed
        return
    closed := true
    ; 先恢复所有者再销毁弹窗，避免 Windows 因所有者仍禁用而把前台切走。
    closeContext := WindowHierarchy.Release(ownerLease)
    try {
        try UnregisterGuiControls(mb.Hwnd)
        mb.Destroy()
    }
    finally WindowHierarchy.CompleteClose(closeContext)
}

ShowDarkMsgBox(Message, Title := "提示", MsgType := "Info", ownerGui := "") {
    Message := NormalizeUserVisibleParentheses(Message)
    Title := NormalizeUserVisibleParentheses(Title)
    mb := Gui("-MinimizeBox -MaximizeBox", Title)

    try RestoreHoveredButton()
    if IsSet(GuiModules)
        try GuiModules.HideTransientWindows()
    ownerLease := ""
    closed := false
    ; 检查主窗口是否存在，如果存在则将其禁用，模拟原生弹窗的“模态(Modal)”拦截效果
    dialogOwner := ownerGui
    if !dialogOwner && IsSet(Main)
        dialogOwner := Main.gui
    if dialogOwner && Type(dialogOwner) == "Gui" {
        try {
            if WinExist(dialogOwner.Hwnd) {
                mb.Opt("+Owner" dialogOwner.Hwnd)
                ownerLease := WindowHierarchy.Acquire(dialogOwner, mb.Hwnd)
            }
        }
    }

    try {
    ; 注入底层深色标题栏
    SetDarkTitleBar(mb.Hwnd)
    mb.BackColor := "1E1E1E"

    ; 图标与文字布局
    iconStr := (MsgType == "Error") ? "❌" : "ℹ️" ; <--- 同步修改这里
    mb.SetFont("s18", "Segoe UI Emoji")
    mb.Add("Text", "x20 y20 w30 h30 BackgroundTrans cWhite", iconStr)

    mb.SetFont("s10 cWhite", "Microsoft YaHei")
    mb.Add("Text", "x60 y25 w220 BackgroundTrans", Message)

    ; 扁平化深色按钮
    btnOk := mb.Add("Text", "x115 y+20 w70 h30 Center 0x200 Background0078D7 cWhite", "确 定")
    RegisterHoverButton(btnOk, "0078D7")
    mb.Add("Text", "x10 y+0 h15", "") ; 底部留白

    ; 销毁窗口并恢复主窗口交互
    closeAction := (*) => CloseDarkMsgBox(mb, ownerLease, &closed)

    RegisterButtonClick(btnOk, closeAction, ButtonFeedbackMode.Dismissive)
    mb.OnEvent("Close", closeAction)
    mb.OnEvent("Escape", closeAction)

    mb.Show("w300 AutoSize")
    WinWaitClose(mb.Hwnd) ; 挂起线程等待弹窗销毁，实现阻塞式的主线程停滞
    } catch as msgErr {
        CloseDarkMsgBox(mb, ownerLease, &closed)
        throw msgErr
    }
}

; ==========================================
; 14. 控件元素鼠标移入事件触发自绘工具说明悬浮窗组件
; ==========================================
IsRoundedButtonInputRouted(hwnd) {
    if !App.uiInteractions.HasButton(hwnd)
        return false
    state := App.uiInteractions.GetButton(hwnd)
    return state.HasOwnProp("roundedOwnerDraw") && state.roundedOwnerDraw
}

OnMouseMove_Tooltip(wParam, lParam, msg, hwnd) {
    if !IsRoundedButtonInputRouted(hwnd)
        UpdateButtonHover(hwnd)
    if IsSet(GuiModules)
        GuiModules.tooltip.HandleMouseMove(wParam, lParam, msg, hwnd)
}

OnMouseLeave_Hover(wParam, lParam, msg, hwnd) {
    if IsRoundedButtonInputRouted(hwnd)
        return
    HandleButtonMouseLeave(hwnd)
}

HandleButtonMouseLeave(hwnd) {
    if (App.uiInteractions.PressedButton == hwnd) {
        if App.uiInteractions.HasButton(hwnd) {
            pressedState := App.uiInteractions.GetButton(hwnd)
            if !(pressedState.HasOwnProp("cursorOnly") && pressedState.cursorOnly)
                SetButtonBackground(pressedState.ctrl, pressedState.normal)
        }
        App.uiInteractions.ClearHoveredButton(hwnd)
        return
    }
    if (App.uiInteractions.HoveredButton == hwnd)
        RestoreHoveredButton()
}

OnGlobalPointerDown(wParam, lParam, msg, hwnd) {
    if App.uiInteractions.HasButton(hwnd) && !IsRoundedButtonInputRouted(hwnd)
        BeginButtonPress(hwnd)

    PruneTextInputCursorStates()
    if App.uiInteractions.HasTextInput(hwnd) {
        clickedTextState := App.uiInteractions.GetTextInput(hwnd)
        if (clickedTextState.HasOwnProp("hideCaret") && clickedTextState.hideCaret)
            ScheduleHideTextCaret(clickedTextState.editHwnd)
        return
    }

    focusedHwnd := DllCall("user32\GetFocus", "Ptr")
    if !App.uiInteractions.HasTextInput(focusedHwnd)
        return
    rootHwnd := DllCall("user32\GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr") ; GA_ROOT
    if rootHwnd && DllCall("user32\IsWindowEnabled", "Ptr", rootHwnd, "Int")
        DllCall("user32\SetFocus", "Ptr", rootHwnd, "Ptr")
}

OnGlobalPointerUp(wParam, lParam, msg, hwnd) {
    if !IsRoundedButtonInputRouted(hwnd)
        EndButtonPress()

    if !App.uiInteractions.HasTextInput(hwnd)
        return
    releasedTextState := App.uiInteractions.GetTextInput(hwnd)
    if (releasedTextState.HasOwnProp("hideCaret") && releasedTextState.hideCaret)
        ScheduleHideTextCaret(releasedTextState.editHwnd)
}

OnButtonPressCancelled(wParam, lParam, msg, hwnd) {
    if IsRoundedButtonInputRouted(hwnd)
        return
    CancelButtonPress()
}

OnButtonCaptureChanged(wParam, lParam, msg, hwnd) {
    if IsRoundedButtonInputRouted(hwnd)
        return
    HandleButtonCaptureChanged(hwnd)
}

HandleButtonCaptureChanged(hwnd) {
    if (App.uiInteractions.PressedButton == hwnd)
        SetTimer(CancelButtonPressAfterCaptureLoss.Bind(hwnd), -50)
}

CancelButtonPressAfterCaptureLoss(expectedHwnd, *) {
    if (App.uiInteractions.PressedButton == expectedHwnd
        && DllCall("user32\GetCapture", "Ptr") != expectedHwnd)
        CancelButtonPress()
}

IsScrollBarHitTestCode(lParam) {
    hitTestCode := lParam & 0xFFFF
    return hitTestCode == Win32.HTHSCROLL
        || hitTestCode == Win32.HTVSCROLL
}

IsNativeScrollBarControl(hwnd) {
    if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
        return false
    classNameBuffer := Buffer(64 * 2, 0)
    classNameLength := DllCall("user32\GetClassNameW", "Ptr", hwnd,
        "Ptr", classNameBuffer, "Int", 64, "Int")
    return classNameLength > 0
        && StrLower(StrGet(classNameBuffer, classNameLength, "UTF-16"))
            == "scrollbar"
}

GetVisibleScrollBarRectangle(hwnd, objectId) {
    scrollBarInfo := Buffer(60, 0)
    NumPut("UInt", scrollBarInfo.Size, scrollBarInfo, 0)
    if !DllCall("user32\GetScrollBarInfo", "Ptr", hwnd, "Int", objectId,
        "Ptr", scrollBarInfo, "Int")
        return ""
    state := NumGet(scrollBarInfo, 36, "UInt")
    if state & (Win32.STATE_SYSTEM_INVISIBLE
        | Win32.STATE_SYSTEM_OFFSCREEN)
        return ""
    left := NumGet(scrollBarInfo, 4, "Int")
    top := NumGet(scrollBarInfo, 8, "Int")
    right := NumGet(scrollBarInfo, 12, "Int")
    bottom := NumGet(scrollBarInfo, 16, "Int")
    if right <= left || bottom <= top
        return ""
    return {Left: left, Top: top, Right: right, Bottom: bottom}
}

PointInsideScreenRectangle(x, y, rectangle) {
    return IsObject(rectangle)
        && x >= rectangle.Left && x < rectangle.Right
        && y >= rectangle.Top && y < rectangle.Bottom
}

IsPointerOverTextInputScrollBar(editHwnd) {
    if !editHwnd || !DllCall("user32\IsWindow", "Ptr", editHwnd, "Int")
        return false
    cursorPoint := Buffer(8, 0)
    if !DllCall("user32\GetCursorPos", "Ptr", cursorPoint, "Int")
        return false
    cursorX := NumGet(cursorPoint, 0, "Int")
    cursorY := NumGet(cursorPoint, 4, "Int")
    horizontalBar := GetVisibleScrollBarRectangle(editHwnd,
        Win32.OBJID_HSCROLL)
    if PointInsideScreenRectangle(cursorX, cursorY, horizontalBar)
        return true
    verticalBar := GetVisibleScrollBarRectangle(editHwnd,
        Win32.OBJID_VSCROLL)
    if PointInsideScreenRectangle(cursorX, cursorY, verticalBar)
        return true
    ; 两条滚动条同时可见时，右下角交汇区也属于滚动区域。
    if IsObject(horizontalBar) && IsObject(verticalBar) {
        cornerRectangle := {
            Left: verticalBar.Left,
            Top: horizontalBar.Top,
            Right: verticalBar.Right,
            Bottom: horizontalBar.Bottom
        }
        return PointInsideScreenRectangle(cursorX, cursorY,
            cornerRectangle)
    }
    return false
}

OnSetCursor(wParam, lParam, msg, hwnd) {
    cursorTargetHwnd := wParam
        && DllCall("user32\IsWindow", "Ptr", wParam, "Int") ? wParam : hwnd
    if IsScrollBarHitTestCode(lParam)
        || IsNativeScrollBarControl(cursorTargetHwnd) {
        SetArrowCursor()
        return 1
    }
    textTargetHwnd := App.uiInteractions.HasTextInput(wParam) ? wParam
        : (App.uiInteractions.HasTextInput(hwnd) ? hwnd : 0)
    if textTargetHwnd {
        textInputState := App.uiInteractions.GetTextInput(textTargetHwnd)
        if DllCall("user32\IsWindow", "Ptr", textTargetHwnd, "Int")
            && DllCall("user32\IsWindow", "Ptr", textInputState.editHwnd, "Int")
            && IsControlEffectivelyEnabled(textInputState.editHwnd) {
            if IsPointerOverTextInputScrollBar(textInputState.editHwnd)
                || (textInputState.HasOwnProp("useArrowCursor")
                    && textInputState.useArrowCursor)
                SetArrowCursor()
            else
                SetTextCursor()
            return 1
        }
        App.uiInteractions.RemoveTextInput(textTargetHwnd)
    }

    ; WM_SETCURSOR 的 wParam 是鼠标所在子窗口句柄；部分系统版本回调 hwnd 会是父窗口，需同时检查两者。
    buttonHwnd := App.uiInteractions.HasButton(wParam) ? wParam : hwnd
    if App.uiInteractions.HasButton(buttonHwnd)
        && !IsRoundedButtonInputRouted(buttonHwnd)
        && IsHoverButtonAvailable(App.uiInteractions.GetButton(buttonHwnd)) {
        SetHandCursor()
        return 1
    }
}

SetHandCursor() {
    cursorHandle := App.uiInteractions.GetCursor(UiCursorKind.Hand, 32649) ; IDC_HAND
    if cursorHandle
        DllCall("user32\SetCursor", "Ptr", cursorHandle)
}

SetArrowCursor() {
    cursorHandle := App.uiInteractions.GetCursor(UiCursorKind.Arrow,
        Win32.IDC_ARROW)
    if cursorHandle
        DllCall("user32\SetCursor", "Ptr", cursorHandle)
}

SetTextCursor() {
    cursorHandle := App.uiInteractions.GetCursor(UiCursorKind.Text,
        Win32.IDC_IBEAM)
    if cursorHandle
        DllCall("user32\SetCursor", "Ptr", cursorHandle)
}

RegisterTextInputControl(inputControl, hideCaret := false, useArrowCursor := false) {
    try textEditHwnd := inputControl.Hwnd
    catch
        return
    RegisterTextInputHwnd(textEditHwnd, hideCaret, useArrowCursor)
}

RegisterTextInputHwnd(textEditHwnd, hideCaret := false, useArrowCursor := false) {
    if !textEditHwnd || !DllCall("user32\IsWindow", "Ptr", textEditHwnd, "Int")
        return
    PruneTextInputCursorStates()
    App.uiInteractions.RegisterTextInput(textEditHwnd, {
        editHwnd: textEditHwnd,
        hideCaret: hideCaret,
        useArrowCursor: useArrowCursor
    })
}

RegisterTextInputHitTarget(backgroundControl, inputControl) {
    try backgroundHwnd := backgroundControl.Hwnd
    catch
        return
    try textEditHwnd := inputControl.Hwnd
    catch
        return
    if !backgroundHwnd || !textEditHwnd
        return
    PruneTextInputCursorStates()
    App.uiInteractions.RegisterTextInput(backgroundHwnd,
        {editHwnd: textEditHwnd})
    backgroundControl.OnEvent("Click", PlaceTextCaretAtPointer.Bind(inputControl))
}

UnregisterGuiControls(guiHwnd) {
    if !guiHwnd
        return
    hoverHandles := []
    for controlHwnd, _ in App.uiInteractions.Buttons {
        if (!DllCall("user32\IsWindow", "Ptr", controlHwnd, "Int")
            || controlHwnd == guiHwnd
            || DllCall("user32\GetAncestor", "Ptr", controlHwnd, "UInt", 2, "Ptr") == guiHwnd)
            hoverHandles.Push(controlHwnd)
    }
    for controlHwnd in hoverHandles {
        RoundedButtonInputRouter.Detach(controlHwnd)
        CancelButtonReleaseReset(controlHwnd)
        if (App.uiInteractions.PressedButton == controlHwnd)
            CancelButtonPress()
        App.uiInteractions.RemoveButton(controlHwnd)
    }
    inputHandles := []
    for controlHwnd, textInputState in App.uiInteractions.TextInputs {
        if (!DllCall("user32\IsWindow", "Ptr", controlHwnd, "Int")
            || !DllCall("user32\IsWindow", "Ptr", textInputState.editHwnd, "Int")
            || controlHwnd == guiHwnd
            || DllCall("user32\GetAncestor", "Ptr", controlHwnd, "UInt", 2, "Ptr") == guiHwnd)
            inputHandles.Push(controlHwnd)
    }
    for controlHwnd in inputHandles
        App.uiInteractions.RemoveTextInput(controlHwnd)
}

PruneTextInputCursorStates() {
    staleTextTargets := []
    for targetHwnd, textInputState in App.uiInteractions.TextInputs {
        if !DllCall("user32\IsWindow", "Ptr", targetHwnd, "Int")
            || !DllCall("user32\IsWindow", "Ptr", textInputState.editHwnd, "Int")
            staleTextTargets.Push(targetHwnd)
    }
    for targetHwnd in staleTextTargets
        App.uiInteractions.RemoveTextInput(targetHwnd)
}

PlaceTextCaretAtPointer(inputControl, *) {
    try textEditHwnd := inputControl.Hwnd
    catch
        return
    if !IsControlEffectivelyEnabled(textEditHwnd)
        return

    cursorPoint := Buffer(8, 0)
    editRect := Buffer(16, 0)
    if !DllCall("user32\GetCursorPos", "Ptr", cursorPoint, "Int")
        return
    if !DllCall("user32\ScreenToClient", "Ptr", textEditHwnd, "Ptr", cursorPoint, "Int")
        return
    if !DllCall("user32\GetClientRect", "Ptr", textEditHwnd, "Ptr", editRect, "Int")
        return

    clientWidth := NumGet(editRect, 8, "Int")
    clientHeight := NumGet(editRect, 12, "Int")
    if (clientWidth <= 0 || clientHeight <= 0)
        return
    pointerX := Max(0, Min(NumGet(cursorPoint, 0, "Int"), clientWidth - 1))
    pointerY := Floor(clientHeight / 2)
    packedPoint := (pointerX & 0xFFFF) | ((pointerY & 0xFFFF) << 16)

    ControlFocus(inputControl)
    characterIndex := SendMessage(Win32.EM_CHARFROMPOS, 0, packedPoint, textEditHwnd) & 0xFFFF
    SendMessage(Win32.EM_SETSEL, characterIndex, characterIndex, textEditHwnd)
}

ScheduleHideTextCaret(textEditHwnd) {
    if textEditHwnd
        SetTimer(HideTextCaret.Bind(textEditHwnd), -10)
}

HideTextCaret(textEditHwnd, *) {
    if DllCall("user32\IsWindow", "Ptr", textEditHwnd, "Int")
        && DllCall("user32\GetFocus", "Ptr") == textEditHwnd
        DllCall("user32\HideCaret", "Ptr", textEditHwnd)
}

ParseButtonColorValue(color) {
    normalizedColor := Trim(String(color))
    if (SubStr(normalizedColor, 1, 1) == "#")
        normalizedColor := SubStr(normalizedColor, 2)
    if (StrLower(SubStr(normalizedColor, 1, 2)) == "0x")
        normalizedColor := SubStr(normalizedColor, 3)
    if !RegExMatch(normalizedColor, "i)^[0-9a-f]{6}$")
        return -1
    return Integer("0x" normalizedColor)
}

GetButtonColorLuma(color) {
    colorValue := ParseButtonColorValue(color)
    if (colorValue < 0)
        return -1
    red := (colorValue >> 16) & 0xFF
    green := (colorValue >> 8) & 0xFF
    blue := colorValue & 0xFF
    return red * 299 + green * 587 + blue * 114
}

DarkenButtonColor(color, factor := 0.86) {
    colorValue := ParseButtonColorValue(color)
    if (colorValue < 0)
        return color
    red := Round(((colorValue >> 16) & 0xFF) * factor)
    green := Round(((colorValue >> 8) & 0xFF) * factor)
    blue := Round((colorValue & 0xFF) * factor)
    return Format("{:02X}{:02X}{:02X}", red, green, blue)
}

LightenButtonColor(color, ratio := 0.12) {
    colorValue := ParseButtonColorValue(color)
    if (colorValue < 0)
        return color
    red := Round(((colorValue >> 16) & 0xFF) * (1 - ratio) + 255 * ratio)
    green := Round(((colorValue >> 8) & 0xFF) * (1 - ratio) + 255 * ratio)
    blue := Round((colorValue & 0xFF) * (1 - ratio) + 255 * ratio)
    return Format("{:02X}{:02X}{:02X}", red, green, blue)
}

ResolveButtonHoverColor(normalColor, requestedHoverColor := "") {
    if (requestedHoverColor == "")
        return LightenButtonColor(normalColor)
    ; 相同颜色用于不可用按钮的无反馈状态，不强制制造悬浮变化。
    if (StrLower(normalColor) == StrLower(requestedHoverColor))
        return requestedHoverColor
    normalLuma := GetButtonColorLuma(normalColor)
    hoverLuma := GetButtonColorLuma(requestedHoverColor)
    if (normalLuma >= 0 && hoverLuma > normalLuma)
        return requestedHoverColor
    return LightenButtonColor(normalColor)
}

ResolveButtonPressedColor(normalColor, requestedPressedColor := "") {
    if (requestedPressedColor == "")
        return DarkenButtonColor(normalColor)
    normalLuma := GetButtonColorLuma(normalColor)
    pressedLuma := GetButtonColorLuma(requestedPressedColor)
    if (normalLuma >= 0 && pressedLuma >= 0 && pressedLuma < normalLuma)
        return requestedPressedColor
    return DarkenButtonColor(normalColor)
}

ResolvePersistentButtonPressedColor(hoverColor, requestedPressedColor := "") {
    if (requestedPressedColor != "") {
        hoverLuma := GetButtonColorLuma(hoverColor)
        pressedLuma := GetButtonColorLuma(requestedPressedColor)
        if (hoverLuma >= 0 && pressedLuma > hoverLuma)
            return requestedPressedColor
    }
    return LightenButtonColor(hoverColor)
}

ResolveButtonFeedbackPressedColor(normalColor, hoverColor, requestedPressedColor, feedbackMode) {
    if (feedbackMode == ButtonFeedbackMode.Dismissive)
        return ResolveButtonPressedColor(normalColor, requestedPressedColor)
    return ResolvePersistentButtonPressedColor(hoverColor, requestedPressedColor)
}

ButtonControlSubclassProc(hWnd, message, wParam, lParam, subclassId, referenceData) {
    try {
        switch message {
            case Win32.WM_MOUSEMOVE:
                UpdateButtonHover(hWnd)
            case Win32.WM_MOUSELEAVE:
                HandleButtonMouseLeave(hWnd)
            case Win32.WM_LBUTTONDOWN, Win32.WM_LBUTTONDBLCLK:
                DllCall("user32\SetFocus", "Ptr", hWnd, "Ptr")
                BeginButtonPress(hWnd)
                return 0
            case Win32.WM_LBUTTONUP:
                EndButtonPress()
                return 0
            case Win32.WM_SETCURSOR:
                if App.uiInteractions.HasButton(hWnd)
                    && IsHoverButtonAvailable(
                        App.uiInteractions.GetButton(hWnd)) {
                    SetHandCursor()
                    return 1
                }
            case Win32.WM_SETFOCUS, Win32.WM_KILLFOCUS:
                SetTimer(RedrawRoundedButton.Bind(hWnd), -1)
            case Win32.WM_CANCELMODE:
                if (App.uiInteractions.PressedButton == hWnd)
                    CancelButtonPress()
            case Win32.WM_CAPTURECHANGED:
                HandleButtonCaptureChanged(hWnd)
            case Win32.WM_NCDESTROY:
                RoundedButtonInputRouter.Detach(hWnd)
        }
    } catch {
        ; Win32 子类回调不能让 AHK 异常越过原生窗口过程边界。
    }
    return DllCall("comctl32\DefSubclassProc", "Ptr", hWnd, "UInt", message,
        "Ptr", wParam, "Ptr", lParam, "Ptr")
}

EnableRoundedButtonRendering(ctrl) {
    try hWnd := ctrl.Hwnd
    catch
        return false
    if !hWnd || !RoundedButtonRenderer.EnsureStarted()
        return false
    try className := StrLower(WinGetClass("ahk_id " hWnd))
    catch
        return false
    style := DllCall("user32\GetWindowLongW", "Ptr", hWnd, "Int", -16, "Int") ; GWL_STYLE
    if (className == "static") {
        ; SS_OWNERDRAW 保留 SS_NOTIFY、WS_TABSTOP 和垂直居中等其余样式。
        ownerDrawStyle := (style & ~0x1F) | 0x0D
    } else if (className == "button") {
        ownerDrawStyle := (style & ~0x0F) | 0x0B ; BS_OWNERDRAW
    } else {
        return false
    }
    if !RoundedButtonInputRouter.Attach(hWnd)
        return false
    if (ownerDrawStyle != style) {
        DllCall("kernel32\SetLastError", "UInt", 0)
        previousStyle := DllCall("user32\SetWindowLongW", "Ptr", hWnd,
            "Int", -16, "Int", ownerDrawStyle, "Int")
        if (!previousStyle && A_LastError) {
            RoundedButtonInputRouter.Detach(hWnd)
            return false
        }
        DllCall("user32\SetWindowPos", "Ptr", hWnd, "Ptr", 0,
            "Int", 0, "Int", 0, "Int", 0, "Int", 0,
            "UInt", 0x0037, "Int") ; FRAMECHANGED | NOACTIVATE | NOMOVE | NOSIZE | NOZORDER
    }
    return true
}

RedrawRoundedButton(hWnd) {
    if hWnd && DllCall("user32\IsWindow", "Ptr", hWnd, "Int")
        DllCall("user32\RedrawWindow", "Ptr", hWnd, "Ptr", 0, "Ptr", 0,
            "UInt", Win32.RDW_BUTTON_REFRESH, "Int")
}

OnDrawRoundedButton(wParam, lParam, msg, hwnd) {
    if !lParam
        return
    itemHwndOffset := A_PtrSize == 8 ? 24 : 20
    itemHwnd := NumGet(lParam, itemHwndOffset, "Ptr")
    if !App.uiInteractions.HasButton(itemHwnd)
        return
    state := App.uiInteractions.GetButton(itemHwnd)
    if !state.HasOwnProp("roundedOwnerDraw") || !state.roundedOwnerDraw
        return
    hdcOffset := itemHwndOffset + A_PtrSize
    rectOffset := hdcOffset + A_PtrSize
    itemHdc := NumGet(lParam, hdcOffset, "Ptr")
    left := NumGet(lParam, rectOffset, "Int")
    top := NumGet(lParam, rectOffset + 4, "Int")
    right := NumGet(lParam, rectOffset + 8, "Int")
    bottom := NumGet(lParam, rectOffset + 12, "Int")
    if RoundedButtonRenderer.Draw(itemHdc, right - left, bottom - top, state)
        return 1
}

OnRoundedButtonFocusChanged(wParam, lParam, msg, hwnd) {
    if IsRoundedButtonInputRouted(hwnd)
        return
    if App.uiInteractions.HasButton(hwnd) {
        state := App.uiInteractions.GetButton(hwnd)
        if state.HasOwnProp("roundedOwnerDraw") && state.roundedOwnerDraw
            SetTimer(RedrawRoundedButton.Bind(hwnd), -1)
    }
}

ShutdownRoundedButtonRenderer(*) {
    RoundedButtonInputRouter.Shutdown()
    RoundedButtonRenderer.Shutdown()
}

RegisterHoverButton(ctrl, normalColor := "333333", hoverColor := "", pressedColor := "",
    textColor := "FFFFFF") {
    try hWnd := ctrl.Hwnd
    catch
        return
    if !hWnd
        return
    ; Text 伪按钮补上 WS_TABSTOP，配合全局 Enter/Space 处理提供键盘操作。
    try ctrl.Opt("+0x10000")
    hoverColor := ResolveButtonHoverColor(normalColor, hoverColor)
    requestedPressedColor := pressedColor
    pressedColor := ResolvePersistentButtonPressedColor(hoverColor, pressedColor)
    state := {
        ctrl: ctrl,
        normal: normalColor,
        hover: hoverColor,
        pressed: pressedColor,
        requestedPressed: requestedPressedColor,
        feedbackMode: ButtonFeedbackMode.Persistent,
        current: normalColor,
        textColor: textColor,
        roundedOwnerDraw: false
    }
    if !App.uiInteractions.RegisterButton(hWnd, state)
        return
    state.roundedOwnerDraw := EnableRoundedButtonRendering(ctrl)
    if state.roundedOwnerDraw
        RedrawRoundedButton(hWnd)
}

RegisterButtonClick(ctrl, callback, feedbackMode := ButtonFeedbackMode.Persistent) {
    try hWnd := ctrl.Hwnd
    catch
        return
    if !App.uiInteractions.HasButton(hWnd)
        return
    state := App.uiInteractions.GetButton(hWnd)
    state.clickCallback := callback
    state.feedbackMode := feedbackMode
    state.pressed := ResolveButtonFeedbackPressedColor(state.normal, state.hover,
        state.requestedPressed, feedbackMode)
    state.pendingClick := 0
    state.suppressClickUntil := 0
    state.releaseResetTimer := 0
    ctrl.OnEvent("Click", HandleRegisteredButtonClick)
}

HandleRegisteredButtonClick(guiCtrlObj, eventArgs*) {
    try hWnd := guiCtrlObj.Hwnd
    catch
        return
    if !App.uiInteractions.HasButton(hWnd)
        return
    state := App.uiInteractions.GetButton(hWnd)
    if !state.HasOwnProp("clickCallback")
        return

    if GetKeyState("LButton", "P") {
        ; Click 通知可能由 Text 伪按钮在按下阶段发出。此时只缓存回调，
        ; 没有通过 BeginButtonPress 验证的按下（例如不可用按钮）直接丢弃。
        if (App.uiInteractions.PressedButton != hWnd)
            return
        callbackArgs := [guiCtrlObj]
        for eventArg in eventArgs
            callbackArgs.Push(eventArg)
        state.pendingClick := {
            callback: state.clickCallback,
            args: callbackArgs
        }
        return
    }

    if (state.suppressClickUntil && GetTickCount64() <= state.suppressClickUntil)
        return
    state.suppressClickUntil := 0
    state.clickCallback.Call(guiCtrlObj, eventArgs*)
}

RunDeferredButtonClick(hWnd, pendingClick, *) {
    ReleaseButtonMouseCapture(hWnd)
    if !App.uiInteractions.HasButton(hWnd)
        return
    state := App.uiInteractions.GetButton(hWnd)
    if !IsHoverButtonAvailable(state)
        return
    pendingClick.callback.Call(pendingClick.args*)
}

CancelButtonReleaseReset(hWnd) {
    if !App.uiInteractions.HasButton(hWnd)
        return
    state := App.uiInteractions.GetButton(hWnd)
    if !state.HasOwnProp("releaseResetTimer") || !state.releaseResetTimer
        return
    SetTimer(state.releaseResetTimer, 0)
    state.releaseResetTimer := 0
}

ScheduleButtonReleaseReset(hWnd) {
    if !App.uiInteractions.HasButton(hWnd)
        return
    CancelButtonReleaseReset(hWnd)
    state := App.uiInteractions.GetButton(hWnd)
    resetTimer := ResetButtonAfterRelease.Bind(hWnd)
    state.releaseResetTimer := resetTimer
    SetTimer(resetTimer, -ButtonFeedbackTiming.ReleaseResetMs)
}

ResetButtonAfterRelease(hWnd, *) {
    if !App.uiInteractions.HasButton(hWnd)
        return
    state := App.uiInteractions.GetButton(hWnd)
    state.releaseResetTimer := 0
    if (App.uiInteractions.PressedButton == hWnd)
        return
    if !DllCall("user32\IsWindow", "Ptr", hWnd, "Int")
        return
    App.uiInteractions.ClearHoveredButton(hWnd)
    SetButtonBackground(state.ctrl, state.normal)
}

RegisterHandCursorControl(ctrl) {
    try hWnd := ctrl.Hwnd
    catch
        return
    if hWnd
        App.uiInteractions.RegisterButton(hWnd,
            {ctrl: ctrl, cursorOnly: true})
}

SetHoverButtonColors(ctrl, normalColor, hoverColor := "", pressedColor := "") {
    try hWnd := ctrl.Hwnd
    catch
        return
    if !App.uiInteractions.HasButton(hWnd)
        return
    hoverColor := ResolveButtonHoverColor(normalColor, hoverColor)
    state := App.uiInteractions.GetButton(hWnd)
    state.normal := normalColor
    state.hover := hoverColor
    state.requestedPressed := pressedColor
    state.pressed := ResolveButtonFeedbackPressedColor(normalColor, hoverColor,
        pressedColor, state.feedbackMode)
}

SetButtonTextColor(ctrl, color) {
    try hWnd := ctrl.Hwnd
    catch
        return false
    if !hWnd || !DllCall("user32\IsWindow", "Ptr", hWnd, "Int")
        return false
    if App.uiInteractions.HasButton(hWnd) {
        state := App.uiInteractions.GetButton(hWnd)
        state.textColor := color
        if state.HasOwnProp("roundedOwnerDraw") && state.roundedOwnerDraw {
            RedrawRoundedButton(hWnd)
            return true
        }
    }
    try {
        ctrl.Opt("c" color)
        return true
    } catch {
        return false
    }
}

SetButtonBackground(ctrl, color) {
    try hWnd := ctrl.Hwnd
    catch
        return false
    if !hWnd || !DllCall("user32\IsWindow", "Ptr", hWnd, "Int")
        return false
    ; 业务回调可以立即更新按钮状态，但不能覆盖尚未结束的抬起反馈。
    if App.uiInteractions.HasButton(hWnd) {
        state := App.uiInteractions.GetButton(hWnd)
        if state.HasOwnProp("releaseResetTimer") && state.releaseResetTimer
            return true
        state.current := color
        if state.HasOwnProp("roundedOwnerDraw") && state.roundedOwnerDraw {
            RedrawRoundedButton(hWnd)
            return true
        }
    }

    redrawSuspended := false
    colorApplied := false
    try {
        DllCall("user32\SendMessageW", "Ptr", hWnd, "UInt", Win32.WM_SETREDRAW,
            "Ptr", false, "Ptr", 0, "Ptr")
        redrawSuspended := true
        ctrl.Opt("Background" color)
        colorApplied := true
    } catch {
        colorApplied := false
    } finally {
        if redrawSuspended && DllCall("user32\IsWindow", "Ptr", hWnd, "Int")
            DllCall("user32\SendMessageW", "Ptr", hWnd, "UInt", Win32.WM_SETREDRAW,
                "Ptr", true, "Ptr", 0, "Ptr")
    }
    if !colorApplied
        return false

    try hWnd := ctrl.Hwnd
    catch
        return false
    if !hWnd || !DllCall("user32\IsWindow", "Ptr", hWnd, "Int")
        return false
    DllCall("user32\RedrawWindow", "Ptr", hWnd, "Ptr", 0, "Ptr", 0,
        "UInt", Win32.RDW_BUTTON_REFRESH, "Int")
    return true
}

IsPointerInsideButton(hWnd) {
    if !hWnd || !DllCall("user32\IsWindow", "Ptr", hWnd, "Int")
        return false
    cursorPoint := Buffer(8, 0)
    windowRect := Buffer(16, 0)
    if !DllCall("user32\GetCursorPos", "Ptr", cursorPoint, "Int")
        || !DllCall("user32\GetWindowRect", "Ptr", hWnd, "Ptr", windowRect, "Int")
        return false
    cursorX := NumGet(cursorPoint, 0, "Int")
    cursorY := NumGet(cursorPoint, 4, "Int")
    return cursorX >= NumGet(windowRect, 0, "Int")
        && cursorX < NumGet(windowRect, 8, "Int")
        && cursorY >= NumGet(windowRect, 4, "Int")
        && cursorY < NumGet(windowRect, 12, "Int")
}

ReleaseButtonMouseCapture(expectedHwnd, *) {
    if (DllCall("user32\GetCapture", "Ptr") == expectedHwnd)
        DllCall("user32\ReleaseCapture", "Int")
}

CancelButtonPress() {
    interactions := App.uiInteractions
    pressedHwnd := interactions.PressedButton
    if !pressedHwnd
        return
    interactions.ClearPressedButton(pressedHwnd)
    if interactions.HasButton(pressedHwnd) {
        pressedState := interactions.GetButton(pressedHwnd)
        if pressedState.HasOwnProp("pendingClick")
            pressedState.pendingClick := 0
        if pressedState.HasOwnProp("suppressClickUntil")
            pressedState.suppressClickUntil := 0
        CancelButtonReleaseReset(pressedHwnd)
        if !(pressedState.HasOwnProp("cursorOnly") && pressedState.cursorOnly)
            SetButtonBackground(pressedState.ctrl, pressedState.normal)
    }
    interactions.ClearHoveredButton(pressedHwnd)
    ReleaseButtonMouseCapture(pressedHwnd)
}

BeginButtonPress(hWnd) {
    interactions := App.uiInteractions
    if !interactions.HasButton(hWnd)
        return
    state := interactions.GetButton(hWnd)
    if (state.HasOwnProp("cursorOnly") && state.cursorOnly)
        return
    if !IsHoverButtonAvailable(state)
        return
    if (interactions.PressedButton && interactions.PressedButton != hWnd)
        CancelButtonPress()
    if state.HasOwnProp("pendingClick")
        state.pendingClick := 0
    if state.HasOwnProp("suppressClickUntil")
        state.suppressClickUntil := 0
    CancelButtonReleaseReset(hWnd)
    interactions.SetPressedButton(hWnd)
    interactions.SetHoveredButton(hWnd)
    SetButtonBackground(state.ctrl, state.pressed)
    DllCall("user32\SetCapture", "Ptr", hWnd, "Ptr")
}

EndButtonPress() {
    interactions := App.uiInteractions
    pressedHwnd := interactions.PressedButton
    if !pressedHwnd
        return
    interactions.ClearPressedButton(pressedHwnd)
    if !interactions.HasButton(pressedHwnd) {
        SetTimer(ReleaseButtonMouseCapture.Bind(pressedHwnd), -1)
        interactions.ClearHoveredButton(pressedHwnd)
        return
    }
    state := interactions.GetButton(pressedHwnd)
    if (state.HasOwnProp("cursorOnly") && state.cursorOnly) {
        SetTimer(ReleaseButtonMouseCapture.Bind(pressedHwnd), -1)
        return
    }
    pendingClick := state.HasOwnProp("pendingClick") ? state.pendingClick : 0
    state.pendingClick := 0
    if IsPointerInsideButton(pressedHwnd) && IsHoverButtonAvailable(state) {
        ; SS_OWNERDRAW Static 不保证生成 STN_CLICKED；鼠标抬起验证通过后直接补齐回调任务。
        if !pendingClick && state.HasOwnProp("clickCallback") {
            pendingClick := {
                callback: state.clickCallback,
                args: [state.ctrl]
            }
        }
        interactions.SetHoveredButton(pressedHwnd)
        TrackButtonMouseLeave(pressedHwnd)
        ScheduleButtonReleaseReset(pressedHwnd)
        if pendingClick {
            state.suppressClickUntil := GetTickCount64() + 100
            SetTimer(RunDeferredButtonClick.Bind(pressedHwnd, pendingClick), -1)
        } else {
            SetTimer(ReleaseButtonMouseCapture.Bind(pressedHwnd), -1)
        }
        return
    }
    state.suppressClickUntil := 0
    CancelButtonReleaseReset(pressedHwnd)
    SetTimer(ReleaseButtonMouseCapture.Bind(pressedHwnd), -1)
    interactions.ClearHoveredButton(pressedHwnd)
    SetButtonBackground(state.ctrl, state.normal)
}

CanHoverButton(state) {
    ; 删除/暂停在没有选中项目时只是灰色提示态，不显示可用按钮的悬浮反馈。
    if IsSet(Main) && (state.ctrl == Main.btnDel || state.ctrl == Main.btnPause)
        return Main.lv.GetNext(0) > 0
    return true
}

IsHoverButtonAvailable(state) {
    try hWnd := state.ctrl.Hwnd
    catch
        return false
    return IsControlEffectivelyEnabled(hWnd) && CanHoverButton(state)
}

IsControlEffectivelyEnabled(hWnd) {
    if !hWnd
        return false
    rootHwnd := DllCall("user32\GetAncestor", "Ptr", hWnd, "UInt", 2, "Ptr") ; GA_ROOT
    currentHwnd := hWnd
    while currentHwnd {
        if !DllCall("user32\IsWindow", "Ptr", currentHwnd, "Int")
            || !DllCall("user32\IsWindowEnabled", "Ptr", currentHwnd, "Int")
            return false
        if (currentHwnd == rootHwnd)
            return true
        currentHwnd := DllCall("user32\GetParent", "Ptr", currentHwnd, "Ptr")
    }
    return false
}

RestoreHoveredButton() {
    CancelButtonPress()
    interactions := App.uiInteractions
    if !interactions.HoveredButton
        return
    hoveredHwnd := interactions.HoveredButton
    if interactions.HasButton(hoveredHwnd) {
        state := interactions.GetButton(hoveredHwnd)
        ; 抬起后的 50ms 反馈由专用定时器收尾，创建子窗口或失焦不能抢先重置。
        if state.HasOwnProp("releaseResetTimer") && state.releaseResetTimer {
            interactions.ClearHoveredButton(hoveredHwnd)
            return
        }
        if !(state.HasOwnProp("cursorOnly") && state.cursorOnly)
            SetButtonBackground(state.ctrl, state.normal)
    }
    interactions.ClearHoveredButton(hoveredHwnd)
}

UpdateButtonHover(hWnd) {
    interactions := App.uiInteractions
    nowTicks := GetTickCount64()
    if interactions.ShouldPruneButtons(nowTicks) {
        stale := []
        for registeredHwnd, state in interactions.Buttons {
            if !DllCall("user32\IsWindow", "Ptr", registeredHwnd, "Int")
                stale.Push(registeredHwnd)
        }
        for registeredHwnd in stale {
            CancelButtonReleaseReset(registeredHwnd)
            if (interactions.PressedButton == registeredHwnd)
                ReleaseButtonMouseCapture(registeredHwnd)
            interactions.RemoveButton(registeredHwnd)
        }
    }

    if interactions.PressedButton {
        pressedHwnd := interactions.PressedButton
        if (hWnd != pressedHwnd || !interactions.HasButton(pressedHwnd))
            return
        pressedState := interactions.GetButton(pressedHwnd)
        if !IsPointerInsideButton(pressedHwnd) {
            if (interactions.HoveredButton == pressedHwnd) {
                interactions.ClearHoveredButton(pressedHwnd)
                SetButtonBackground(pressedState.ctrl, pressedState.normal)
            }
            return
        }
        if (interactions.HoveredButton != pressedHwnd) {
            interactions.SetHoveredButton(pressedHwnd)
            SetButtonBackground(pressedState.ctrl, pressedState.pressed)
        }
        return
    }

    if (interactions.HoveredButton == hWnd)
        return

    RestoreHoveredButton()
    if !interactions.HasButton(hWnd)
        return
    state := interactions.GetButton(hWnd)
    if !IsHoverButtonAvailable(state)
        return
    SetHandCursor()
    interactions.SetHoveredButton(hWnd)
    TrackButtonMouseLeave(hWnd)
    if (state.HasOwnProp("cursorOnly") && state.cursorOnly)
        return
    ; 抬起后的按下色必须完整保留 50ms，期间轻微移动不能提前切换为悬浮色。
    if state.HasOwnProp("releaseResetTimer") && state.releaseResetTimer
        return
    SetButtonBackground(state.ctrl, state.hover)
}

TrackButtonMouseLeave(hWnd) {
    tmeSize := A_PtrSize == 8 ? 24 : 16
    tme := Buffer(tmeSize, 0)
    NumPut("UInt", tmeSize, tme, 0)
    NumPut("UInt", 0x00000002, tme, 4) ; TME_LEAVE
    NumPut("Ptr", hWnd, tme, 8)
    try DllCall("user32\TrackMouseEvent", "Ptr", tme)
}

; ==========================================
; 15. 系统资源文件与应用图标抓取解析支持以及资源释放容灾队列
; ==========================================

ClearImageListIconCache(imageList) {
    return App.iconResources.ClearImageListCache(imageList)
}

GetFileIconIndex(filePath, IL_ID) {
    if !IL_ID
        return 0
    iconResources := App.iconResources
    if iconResources.HasCachedIcon(IL_ID, filePath)
        return iconResources.GetCachedIcon(IL_ID, filePath)

    iconSource := ParseCustomIconSource(filePath)
    sourcePath := iconSource.Path

    if IsMainImageListTracked(IL_ID) {
        extension := GetCustomIconSourceExtension(filePath)
        if IsRasterImageIconExtension(extension)
            || extension == "svg" || extension == "ani" {
            customImageIcon := CreateCustomImagePaddedIcon(sourcePath,
                iconResources.MainIconPixelSize,
                iconResources.MainIconCellPixelSize)
            try idx := customImageIcon
                ? IL_Add(IL_ID, "HICON:" customImageIcon) : 0
            finally {
                if customImageIcon
                    try DllCall("user32\DestroyIcon", "Ptr",
                        customImageIcon)
            }
            if idx {
                iconResources.StoreCachedIcon(IL_ID, filePath, idx)
                return idx
            }
        }
        useHighQuality := false
        preferredSource := GetPreferredMainIcon(filePath, &useHighQuality)
        if preferredSource {
            try idx := AddIconToImageList(IL_ID, preferredSource,
                useHighQuality)
            finally DllCall("user32\DestroyIcon", "Ptr", preferredSource)
            if idx {
                iconResources.StoreCachedIcon(IL_ID, filePath, idx)
                return idx
            }
        }
    }

    sfi_size := A_PtrSize + 688
    sfi := Buffer(sfi_size)
    flags := 0x100 ; SHGFI_ICON
    attr := 0
    if !FileExist(sourcePath) {
        flags |= Win32.SHGFI_USEFILEATTRIBUTES
        attr := Win32.FILE_ATTRIBUTE_NORMAL
    }

    if DllCall("shell32\SHGetFileInfoW", "Str", sourcePath, "UInt", attr, "Ptr", sfi, "UInt", sfi_size, "UInt", flags) {
        hIcon := NumGet(sfi, 0, "Ptr")
        if hIcon {
            try idx := AddIconToImageList(IL_ID, hIcon)
            finally DllCall("user32\DestroyIcon", "Ptr", hIcon)
            if idx {
                iconResources.StoreCachedIcon(IL_ID, filePath, idx)
                return idx
            }
        }
    }

    fallbackIconNumber := iconSource.HasIndex && iconSource.Index >= 0
        ? iconSource.Index + 1 : 1
    idx := IL_Add(IL_ID, sourcePath, fallbackIconNumber)
    if idx
        iconResources.StoreCachedIcon(IL_ID, filePath, idx)
    return idx
}

; ============================================================================
; 16. GUI 模块类
; 每个短生命周期窗口只把原生 Gui/控件保存在自己的实例中，并在 Close() 中
; 统一销毁和清空，避免事件回调继续命中已经销毁的旧控件。
; ============================================================================
