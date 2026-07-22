/*
================================================================================
    进程守护小助手 (Process Watchdog)
    开发语言：AutoHotkey v2
    主要功能：后台进程、脚本、启动项守护与定时保活。
    【核心特性说明】
    1. 多态守护：全面支持原生应用(.exe)、解释型脚本(.py/.ahk/.js)、文件(.bat/.cmd)和快捷方式。
    2. 进程轮询机制：采用 WMI(Win32_Process) 结合缓存比对，旨在降低循环检测带来的 CPU 占用。
    3. UI 界面动态适配：通过调用 dwmapi, uxtheme, shell32 等系统 API 适配深色模式。
    4. 异常处理：支持递增延迟重试（Exponential Backoff），防止连续崩溃导致的资源过度占用。
================================================================================
*/

#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off 
#Warn All, StdOut ; 严格警告写入诊断输出，避免后台启动被不可见对话框阻塞

; ==========================================
; Win32 常量定义 (Magic Constants)
; 常量集中在静态类中，避免与可变的应用状态混杂。
; ==========================================
class Win32 {
    static WM_CLOSE := 0x0010
    static WM_GETFONT := 0x0031
    static WM_CANCELMODE := 0x001F
    static WM_SETICON := 0x0080
    static WM_NCLBUTTONDOWN := 0x00A1
    static WM_KEYDOWN := 0x0100
    static WM_SETCURSOR := 0x0020
    static WM_MOUSEMOVE := 0x0200
    static WM_LBUTTONDOWN := 0x0201
    static WM_LBUTTONUP := 0x0202
    static WM_CAPTURECHANGED := 0x0215
    static WM_MOUSELEAVE := 0x02A3
    static WM_DPICHANGED := 0x02E0
    static WM_DROPFILES := 0x0233
    static WM_COPYGLOBALDATA := 0x0049
    static WM_COPYDATA := 0x004A
    static EM_SETSEL := 0x00B1
    static EM_GETSEL := 0x00B0
    static EM_LINESCROLL := 0x00B6
    static EM_GETFIRSTVISIBLELINE := 0x00CE
    static EM_GETRECT := 0x00B2
    static EM_GETLINECOUNT := 0x00BA
    static EM_CHARFROMPOS := 0x00D7
    static LVM_GETCOLUMNWIDTH := 0x101D
    static LVM_GETHEADER := 0x101F
    static LVM_HITTEST := 0x1012
    static LVM_SETITEMW := 0x104C
    static LVIF_IMAGE := 0x00000002
    static ICON_SMALL := 0
    static ICON_BIG := 1
    static LR_LOADFROMFILE := 0x00000010
    static IMAGE_ICON := 1
    static SHGFI_ICON := 0x000000100
    static SHGFI_SMALLICON := 0x000000001
    static SHGFI_LARGEICON := 0x000000000
    static SHGFI_USEFILEATTRIBUTES := 0x000000010
    static SHGFI_SYSICONINDEX := 0x000004000
    static FILE_ATTRIBUTE_NORMAL := 0x00000080
    static SHIL_EXTRALARGE := 2
    static ILD_TRANSPARENT := 1
    static CTRL_C_EVENT := 0
    static IDC_IBEAM := 32513
    static SB_HORZ := 0
    static SB_VERT := 1
    static SB_BOTH := 3
    static WAIT_OBJECT_0 := 0
    static FILE_LIST_DIRECTORY := 0x0001
    static FILE_SHARE_ALL := 0x00000007
    static OPEN_EXISTING := 3
    static FILE_FLAG_BACKUP_SEMANTICS := 0x02000000
    static FILE_FLAG_OVERLAPPED := 0x40000000
    static FILE_NOTIFY_FILTER := 0x0000005B
    static ERROR_IO_PENDING := 997
    static ERROR_SERVICE_DOES_NOT_EXIST := 1060
    static ERROR_MORE_DATA := 234
    static SC_MANAGER_CONNECT := 0x0001
    static SC_MANAGER_ENUMERATE_SERVICE := 0x0004
    static SERVICE_QUERY_STATUS := 0x0004
    static SERVICE_START := 0x0010
    static SERVICE_STOP := 0x0020
    static SERVICE_PAUSE_CONTINUE := 0x0040
    static SERVICE_CONTROL_STOP := 0x00000001
    static SERVICE_CONTROL_CONTINUE := 0x00000003
    static SERVICE_STOPPED := 0x00000001
    static SERVICE_START_PENDING := 0x00000002
    static SERVICE_STOP_PENDING := 0x00000003
    static SERVICE_RUNNING := 0x00000004
    static SERVICE_CONTINUE_PENDING := 0x00000005
    static SERVICE_PAUSE_PENDING := 0x00000006
    static SERVICE_PAUSED := 0x00000007
}

class ButtonFeedbackMode {
    static Persistent := 0
    static Dismissive := 1
}

class DirectoryChangeWatcher {
    __New(rootPath) {
        this.Root := StrLen(rootPath) > 3 ? RTrim(rootPath, "\") : rootPath
        this.DirectoryHandle := 0
        this.EventHandle := 0
        this.NotificationBuffer := Buffer(65536, 0)
        this.Overlapped := Buffer(A_PtrSize == 8 ? 32 : 20, 0)
        this.Active := false
        this.Open()
    }

    Open() {
        this.Close()
        if !DirExist(this.Root)
            return false
        flags := Win32.FILE_FLAG_BACKUP_SEMANTICS | Win32.FILE_FLAG_OVERLAPPED
        directoryHandle := DllCall("kernel32\CreateFileW", "WStr", this.Root,
            "UInt", Win32.FILE_LIST_DIRECTORY, "UInt", Win32.FILE_SHARE_ALL,
            "Ptr", 0, "UInt", Win32.OPEN_EXISTING, "UInt", flags, "Ptr", 0, "Ptr")
        if (!directoryHandle || directoryHandle == -1)
            return false
        eventHandle := DllCall("kernel32\CreateEventW", "Ptr", 0, "Int", true, "Int", false, "Ptr", 0, "Ptr")
        if !eventHandle {
            DllCall("kernel32\CloseHandle", "Ptr", directoryHandle)
            return false
        }
        this.DirectoryHandle := directoryHandle
        this.EventHandle := eventHandle
        this.Active := this.Rearm()
        if !this.Active
            this.Close()
        return this.Active
    }

    Rearm() {
        if !this.DirectoryHandle || !this.EventHandle
            return false
        DllCall("kernel32\ResetEvent", "Ptr", this.EventHandle)
        DllCall("ntdll\RtlZeroMemory", "Ptr", this.Overlapped.Ptr, "UPtr", this.Overlapped.Size)
        eventOffset := A_PtrSize == 8 ? 24 : 16
        NumPut("Ptr", this.EventHandle, this.Overlapped, eventOffset)
        started := DllCall("kernel32\ReadDirectoryChangesW", "Ptr", this.DirectoryHandle,
            "Ptr", this.NotificationBuffer.Ptr, "UInt", this.NotificationBuffer.Size,
            "Int", true, "UInt", Win32.FILE_NOTIFY_FILTER, "Ptr", 0,
            "Ptr", this.Overlapped.Ptr, "Ptr", 0, "Int")
        if started
            return true
        return DllCall("kernel32\GetLastError", "UInt") == Win32.ERROR_IO_PENDING
    }

    Poll() {
        changes := []
        if !this.Active || !this.EventHandle
            return changes
        if (DllCall("kernel32\WaitForSingleObject", "Ptr", this.EventHandle, "UInt", 0, "UInt") != Win32.WAIT_OBJECT_0)
            return changes
        bytesReturned := 0
        completed := DllCall("kernel32\GetOverlappedResult", "Ptr", this.DirectoryHandle,
            "Ptr", this.Overlapped.Ptr, "UInt*", &bytesReturned, "Int", false, "Int")
        if !completed {
            this.Active := this.Rearm()
            return changes
        }
        if (bytesReturned == 0) {
            changes.Push({Action: 0, RelativePath: "*"})
        } else {
            offset := 0
            while (offset + 12 <= bytesReturned) {
                nextOffset := NumGet(this.NotificationBuffer, offset, "UInt")
                action := NumGet(this.NotificationBuffer, offset + 4, "UInt")
                nameBytes := NumGet(this.NotificationBuffer, offset + 8, "UInt")
                if (nameBytes > 0 && offset + 12 + nameBytes <= bytesReturned) {
                    relativePath := StrGet(this.NotificationBuffer.Ptr + offset + 12, nameBytes // 2, "UTF-16")
                    changes.Push({Action: action, RelativePath: relativePath})
                }
                if !nextOffset
                    break
                offset += nextOffset
            }
        }
        this.Active := this.Rearm()
        return changes
    }

    Close() {
        if this.DirectoryHandle {
            try DllCall("kernel32\CancelIoEx", "Ptr", this.DirectoryHandle, "Ptr", 0)
            try DllCall("kernel32\CloseHandle", "Ptr", this.DirectoryHandle)
        }
        if this.EventHandle
            try DllCall("kernel32\CloseHandle", "Ptr", this.EventHandle)
        this.DirectoryHandle := 0
        this.EventHandle := 0
        this.Active := false
    }
}

class ApplicationState {
    __New() {
        this.mutexHandle := 0
        this.iniPath := A_ScriptDir "\watchdog.ini"
        this.maintenanceJournalPath := A_ScriptDir "\watchdog.maintenance.ini"
        this.checkInterval := 2000
        this.retrySequence := "5, 30, 60"
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
        this.servicePendingTimeoutSeconds := 30
        this.resumePausedServices := true
        this.preferEverything := true
        this.nativeScanTimeoutSeconds := 15
        this.everythingMaxResults := 80
        this.maintenancePollInterval := 1000
        this.maintenanceProcessInterval := 1000
        this.maintenanceFingerprintInterval := 30000
        this.maintenanceFingerprintRetryInterval := 5000
        this.processSnapshotReuseInterval := 5000
        this.processBaselineReady := false
        this.latestProcessSnapshot := []
        this.latestProcessSnapshotTicks := 0
        this.latestProcessSnapshotSupportsCommandLine := true
        this.latestNativeProcessSnapshotTicks := 0
        this.maintenanceSnapshotSupportsCommandLine := false
        this.processSnapshotRetryAfterTicks := 0
        this.processSnapshotRequestTicks := 0
        this.processLoopBusy := false
        this.maintenanceLoopBusy := false
        this.pendingMaintenanceCommands := []
        this.maintenanceInitialized := false
        this.maintenanceWatchers := Map()
        this.maintenanceWatchers.CaseSense := "Off"
        this.appStates := Map()
        this.appStates.CaseSense := "Off"
        this.appOrder := []
        this.configLoadWarnings := []
        this.configRecoveryEntries := []
        this.appsDirty := false
        this.lastSaveWarningTicks := 0
        this.logMessages := []
        this.logRevision := 0
        this.wmiError := false
        this.isRestarting := false
        this.processSnapshotWorkerPid := 0
        this.processSnapshotWorkerCreationIdentity := ""
        this.processSnapshotWorkerPath := ""
        this.processSnapshotWorkerStartedTicks := 0
        this.processSnapshotMaxAge := 30000
        this.scmHandle := 0
        this.iconCache := Map()
        this.iconHandles := Map()
        this.iconResamplerFactory := 0
        this.mainIconPixelSize := 28
        this.mainIconCellPixelSize := 36
        this.mainDpi := 96
        this.dpiRebuildTimer := 0
        this.buttonHoverStates := Map()
        this.hoveredButtonHwnd := 0
        this.pressedButtonHwnd := 0
        this.hoverPruneTicks := 0
        this.handCursor := 0
        this.textInputCursorStates := Map()
        this.textCursor := 0
        this.undoStack := []
        this.redoStack := []
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
}

; 业务运行态只有一个稳定根对象；函数只修改实例属性，不再重新绑定全局变量。
global App := ApplicationState()

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
App.mutexHandle := DllCall("kernel32\CreateMutex", "Ptr", 0, "Int", False, "Str", "Global\Watchdog_Mutex_Strict")
if (DllCall("kernel32\GetLastError") == 183) { ; ERROR_ALREADY_EXISTS = 183
    DetectHiddenWindows(True)
    existingWindow := WinExist("进程守护小助手 ahk_class AutoHotkeyGUI")
    if (!existingWindow && App.pendingMaintenanceCommands.Length) {
        Loop 30 {
            Sleep(100)
            existingWindow := WinExist("进程守护小助手 ahk_class AutoHotkeyGUI")
            if existingWindow
                break
        }
    }
    if existingWindow {
        if App.pendingMaintenanceCommands.Length {
            while App.pendingMaintenanceCommands.Length
                SendMaintenanceCopyData(existingWindow, App.pendingMaintenanceCommands.RemoveAt(1))
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
try DllCall("shell32\SetCurrentProcessExplicitAppUserModelID", "WStr", "ProcessWatchdog_" . A_ScriptHwnd)

if FileExist(A_ScriptDir "\watchdog.ico") {
    TraySetIcon(A_ScriptDir "\watchdog.ico")
    try {
        smallIconWidth := SysGet(49), smallIconHeight := SysGet(50)
        iconWidth := SysGet(11), iconHeight := SysGet(12)
        smallIconHandle := DllCall("user32\LoadImage", "Ptr", 0, "Str", A_ScriptDir "\watchdog.ico",
            "UInt", 1, "Int", smallIconWidth, "Int", smallIconHeight, "UInt", 0x00000010, "Ptr")
        largeIconHandle := DllCall("user32\LoadImage", "Ptr", 0, "Str", A_ScriptDir "\watchdog.ico",
            "UInt", 1, "Int", iconWidth, "Int", iconHeight, "UInt", 0x00000010, "Ptr")
        if smallIconHandle
            SendMessage(Win32.WM_SETICON, Win32.ICON_SMALL, smallIconHandle, , A_ScriptHwnd)
        if largeIconHandle
            SendMessage(Win32.WM_SETICON, Win32.ICON_BIG, largeIconHandle, , A_ScriptHwnd)
    }
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

; 所有短生命周期 GUI 都由模块实例持有，窗口销毁后由类负责清空引用。
global GuiModules := GuiModuleRegistry(Main.gui)

; 如果 INI 文件不存在，则写入默认配置
if !FileExist(App.iniPath) {
    IniWrite(2000, App.iniPath, "Settings", "CheckInterval")
    IniWrite("5, 30, 60", App.iniPath, "Settings", "RetrySequence")
    IniWrite(0, App.iniPath, "Settings", "ShowAtStartup")
    IniWrite(1, App.iniPath, "Settings", "RecursiveBatchImport")
    IniWrite(500, App.iniPath, "Settings", "LogMaxEntries")
    IniWrite(A_Temp "\ProcessWatchdogLogs", App.iniPath, "Settings", "LogDirectory")
    IniWrite(30, App.iniPath, "Settings", "LogRetentionDays")
    IniWrite(0, App.iniPath, "Settings", "ClearLogsOnStartup")
    IniWrite(3, App.iniPath, "Settings", "GracefulStopSeconds")
    IniWrite(2, App.iniPath, "Settings", "CtrlCWaitSeconds")
    IniWrite(1, App.iniPath, "Settings", "AllowForceTerminate")
    IniWrite(30, App.iniPath, "Settings", "ServicePendingTimeoutSeconds")
    IniWrite(1, App.iniPath, "Settings", "ResumePausedServices")
    IniWrite(1, App.iniPath, "Settings", "PreferEverything")
    IniWrite(15, App.iniPath, "Settings", "NativeScanTimeoutSeconds")
    IniWrite(80, App.iniPath, "Settings", "EverythingMaxResults")
    
    ; 首次运行不预设任何应用，用户可自行添加
}

; 从 INI 读取设置参数
try App.checkInterval := Integer(IniRead(App.iniPath, "Settings", "CheckInterval", 2000))
catch
    App.checkInterval := 2000
if !IsValidCheckInterval(App.checkInterval)
    App.checkInterval := 2000

try App.retrySequence := IniRead(App.iniPath, "Settings", "RetrySequence", "5, 30, 60")
catch
    App.retrySequence := "5, 30, 60"

parsedRetry := ParseRetrySequence(App.retrySequence)
if !parsedRetry {
    App.retrySequence := "5, 30, 60"
    App.retryDelayArray := [5000, 30000, 60000]
} else {
    App.retryDelayArray := parsedRetry
}

App.showAtStartup := ReadIniBool("Settings", "ShowAtStartup", false)
App.recursiveBatchImport := ReadIniBool("Settings", "RecursiveBatchImport", true)
App.logMaxEntries := ReadIniBoundedInt("Settings", "LogMaxEntries", 500, 50, 10000)
try App.logDirectory := Trim(IniRead(App.iniPath, "Settings", "LogDirectory", A_Temp "\ProcessWatchdogLogs"))
catch
    App.logDirectory := A_Temp "\ProcessWatchdogLogs"
if (App.logDirectory == "")
    App.logDirectory := A_Temp "\ProcessWatchdogLogs"
App.logRetentionDays := ReadIniBoundedInt("Settings", "LogRetentionDays", 30, 1, 3650)
App.clearLogsOnStartup := ReadIniBool("Settings", "ClearLogsOnStartup", false)
App.gracefulStopSeconds := ReadIniBoundedInt("Settings", "GracefulStopSeconds", 3, 1, 300)
App.ctrlCWaitSeconds := ReadIniBoundedInt("Settings", "CtrlCWaitSeconds", 2, 1, 60)
App.allowForceTerminate := ReadIniBool("Settings", "AllowForceTerminate", true)
App.servicePendingTimeoutSeconds := ReadIniBoundedInt("Settings", "ServicePendingTimeoutSeconds", 30, 5, 600)
App.resumePausedServices := ReadIniBool("Settings", "ResumePausedServices", true)
App.preferEverything := ReadIniBool("Settings", "PreferEverything", true)
App.nativeScanTimeoutSeconds := ReadIniBoundedInt("Settings", "NativeScanTimeoutSeconds", 15, 1, 120)
App.everythingMaxResults := ReadIniBoundedInt("Settings", "EverythingMaxResults", 80, 10, 1000)
CleanupBatchLogs()

; 读取布局设定
App.savedWidth := IniRead(App.iniPath, "Layout", "GuiW", 730)
App.savedHeight := IniRead(App.iniPath, "Layout", "GuiH", 530)

if (App.savedWidth < 730)
    App.savedWidth := 730
if (App.savedHeight < 530)
    App.savedHeight := 530

App.savedColumn1 := IniRead(App.iniPath, "Layout", "Col1W", 500)
App.savedColumn2 := IniRead(App.iniPath, "Layout", "Col2W", 205)

if (App.savedColumn1 < 450)
    App.savedColumn1 := 450
if (App.savedColumn2 < 205)
    App.savedColumn2 := 205

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
    if FileExist(iconPath) {
        try {
            ; 通过系统 LoadImage API 提取指定尺寸及色深的图标，保留 Alpha 通道并避免内置函数可能引发的缩放模糊问题
            cxSm := SysGet(49), cySm := SysGet(50) ; 小图标尺寸常量 (SM_CXSMICON)
            cx := SysGet(11), cy := SysGet(12)     ; 大图标尺寸常量 (SM_CXICON)
            
            hIconSmall := DllCall("user32\LoadImage", "Ptr", 0, "Str", iconPath, "UInt", 1, "Int", cxSm, "Int", cySm, "UInt", 0x00000010, "Ptr")
            hIconBig   := DllCall("user32\LoadImage", "Ptr", 0, "Str", iconPath, "UInt", 1, "Int", cx, "Int", cy, "UInt", 0x00000010, "Ptr")
            
            if hIconSmall
                SendMessage(0x0080, 0, hIconSmall, , hWnd) ; WM_SETICON = 0x80, ICON_SMALL = 0
            if hIconBig
                SendMessage(0x0080, 1, hIconBig, , hWnd)   ; ICON_BIG = 1
            if App.iconHandles.Has(hWnd)
                ReleaseWindowIcons(hWnd)
            App.iconHandles[hWnd] := [hIconSmall, hIconBig]
        }
    }
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
    dpi := 96
    try dpi := DllCall("user32\GetDpiForWindow", "Ptr", Main.gui.Hwnd, "UInt")
    App.mainDpi := dpi
    App.mainIconPixelSize := Max(20, Round(28 * dpi / 96))
    App.mainIconCellPixelSize := Max(App.mainIconPixelSize + 2, Round(36 * dpi / 96))
    try DllCall("comctl32\ImageList_SetIconSize", "Ptr", imageList,
        "Int", App.mainIconCellPixelSize, "Int", App.mainIconCellPixelSize)
    AddMainStatusIcons(imageList, statusIconIndices)
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
    if DllCall("shell32\SHGetImageList", "Int", imageListKind,
        "Ptr", imageListIid, "Ptr*", &shellImageList, "Int") < 0 || !shellImageList
        return 0

    hIcon := 0
    getIconResult := -1
    vtable := NumGet(shellImageList, 0, "Ptr")
    getIcon := NumGet(vtable, 10 * A_PtrSize, "Ptr")
    release := NumGet(vtable, 2 * A_PtrSize, "Ptr")
    try getIconResult := DllCall(getIcon, "Ptr", shellImageList,
        "Int", systemIconIndex, "UInt", Win32.ILD_TRANSPARENT,
        "Ptr*", &hIcon, "Int")
    finally DllCall(release, "Ptr", shellImageList, "UInt")
    if getIconResult == 0
        return hIcon
    if hIcon
        DllCall("user32\DestroyIcon", "Ptr", hIcon)
    return 0
}

GetPreferredMainIcon(filePath, &useHighQualityResampling := false) {
    useHighQualityResampling := false
    if !FileExist(filePath)
        return 0
    SplitPath(filePath, , , &extension)
    extension := StrLower(extension)
    if extension == "exe" || extension == "ico" {
        sourceSize := SelectClosestIconSourceSize(App.mainIconPixelSize)
        hIcon := 0
        iconResourceId := 0
        extractedCount := 0
        try extractedCount := DllCall("user32\PrivateExtractIconsW",
            "WStr", filePath, "Int", 0,
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
    return GetShellImageListIcon(filePath, Win32.SHIL_EXTRALARGE)
}

SelectClosestIconSourceSize(targetSize) {
    for candidateSize in [16, 20, 24, 32, 40, 48, 64, 96, 128, 256] {
        if candidateSize >= targetSize
            return candidateSize
    }
    return 256
}

EnsureIconResampler() {
    if App.iconResamplerFactory
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
        return false
    App.iconResamplerFactory := factory
    return true
}

ReleaseIconComObject(pointer) {
    if !pointer
        return
    vtable := NumGet(pointer, 0, "Ptr")
    release := NumGet(vtable, 2 * A_PtrSize, "Ptr")
    DllCall(release, "Ptr", pointer, "UInt")
}

ShutdownIconResampler(*) {
    if !App.iconResamplerFactory
        return
    try ReleaseIconComObject(App.iconResamplerFactory)
    App.iconResamplerFactory := 0
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
    if !maskBitmap || !maskBits
        return 0

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

StatusPointNearSegment(x, y, startX, startY, endX, endY, thickness) {
    deltaX := endX - startX
    deltaY := endY - startY
    lengthSquared := deltaX * deltaX + deltaY * deltaY
    if (lengthSquared <= 0)
        return false
    projection := Max(0, Min(1,
        ((x - startX) * deltaX + (y - startY) * deltaY) / lengthSquared))
    nearestX := startX + projection * deltaX
    nearestY := startY + projection * deltaY
    return (x - nearestX) ** 2 + (y - nearestY) ** 2 <= thickness ** 2
}

StatusShapeContains(statusKind, x, y) {
    absX := Abs(x)
    absY := Abs(y)
    switch statusKind {
        case "Running":
            cornerX := Max(absX - 0.70, 0)
            cornerY := Max(absY - 0.70, 0)
            return absX <= 0.94 && absY <= 0.94
                && cornerX * cornerX + cornerY * cornerY <= 0.24 ** 2
        case "Paused":
            return absX + absY <= 0.98
        case "Pending":
            return x * x + y * y <= 0.95 ** 2
        case "Warning":
            if (y < -0.92 || y > 0.82)
                return false
            halfWidth := (y + 0.92) / 1.74 * 0.92
            return absX <= halfWidth
        case "Error":
            return absX <= 0.92 && absY <= 0.92
                && absX + absY <= 1.30
        case "Updating":
            return absX <= 0.88 && absY <= 0.92 - 0.46 * absX
        case "Idle":
            cornerX := Max(absX - 0.70, 0)
            cornerY := Max(absY - 0.50, 0)
            return absX <= 0.94 && absY <= 0.74
                && cornerX * cornerX + cornerY * cornerY <= 0.24 ** 2
    }
    return false
}

StatusGlyphContains(statusKind, x, y) {
    switch statusKind {
        case "Running":
            return StatusPointNearSegment(x, y,
                -0.50, 0.02, -0.16, 0.36, 0.12)
                || StatusPointNearSegment(x, y,
                    -0.16, 0.36, 0.52, -0.38, 0.12)
        case "Paused":
            return (Abs(x - 0.27) <= 0.11 || Abs(x + 0.27) <= 0.11)
                && Abs(y) <= 0.53
        case "Warning":
            insideInnerTriangle := y >= -0.62 && y <= 0.57
                && Abs(x) <= (y + 0.62) / 1.19 * 0.63
            return !insideInnerTriangle
                || (Abs(x) <= 0.09 && y >= -0.35 && y <= 0.18)
                || x * x + (y - 0.42) ** 2 <= 0.11 ** 2
        case "Error":
            return StatusPointNearSegment(x, y,
                -0.43, -0.43, 0.43, 0.43, 0.11)
                || StatusPointNearSegment(x, y,
                    -0.43, 0.43, 0.43, -0.43, 0.11)
        case "Pending":
            radiusSquared := x * x + y * y
            return (radiusSquared >= 0.56 ** 2 && radiusSquared <= 0.73 ** 2)
                || StatusPointNearSegment(x, y,
                    0, 0.04, 0, -0.40, 0.085)
                || StatusPointNearSegment(x, y,
                    0, 0.04, 0.35, 0.23, 0.085)
                || radiusSquared <= 0.10 ** 2
        case "Updating":
            upperShaft := x >= -0.48 && x <= 0.36 && Abs(y + 0.24) <= 0.09
            upperHead := x >= 0.26 && x <= 0.60
                && Abs(y + 0.24) <= (0.60 - x) * 0.78
            lowerShaft := x >= -0.36 && x <= 0.48 && Abs(y - 0.24) <= 0.09
            lowerHead := x >= -0.60 && x <= -0.26
                && Abs(y - 0.24) <= (x + 0.60) * 0.78
            return upperShaft || upperHead || lowerShaft || lowerHead
        case "Idle":
            return (x + 0.38) ** 2 + y * y <= 0.105 ** 2
                || x * x + y * y <= 0.105 ** 2
                || (x - 0.38) ** 2 + y * y <= 0.105 ** 2
    }
    return false
}

CreateStatusGlyphIcon(statusKind, rgb, glyphSize, cellSize) {
    screenDC := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
    colorBitmap := 0
    maskBitmap := 0
    try {
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

        center := (cellSize - 1) / 2
        halfSize := glyphSize / 2
        red := (rgb >> 16) & 0xFF
        green := (rgb >> 8) & 0xFF
        blue := rgb & 0xFF
        foregroundRgb := (statusKind == "Paused" || statusKind == "Warning")
            ? 0x141414
            : 0xFFFFFF
        foregroundRed := (foregroundRgb >> 16) & 0xFF
        foregroundGreen := (foregroundRgb >> 8) & 0xFF
        foregroundBlue := foregroundRgb & 0xFF
        sampleCount := 4
        totalSamples := sampleCount ** 2
        Loop cellSize {
            y := A_Index - 1
            Loop cellSize {
                x := A_Index - 1
                backgroundSamples := 0
                foregroundSamples := 0
                Loop sampleCount {
                    sampleY := A_Index - 1
                    Loop sampleCount {
                        sampleX := A_Index - 1
                        normalizedX := (x + (sampleX + 0.5) / sampleCount - center) / halfSize
                        normalizedY := (y + (sampleY + 0.5) / sampleCount - center) / halfSize
                        if !StatusShapeContains(statusKind, normalizedX, normalizedY)
                            continue
                        backgroundSamples++
                        if StatusGlyphContains(statusKind, normalizedX, normalizedY)
                            foregroundSamples++
                    }
                }
                alpha := Round(255 * backgroundSamples / totalSamples)
                backgroundOnlySamples := backgroundSamples - foregroundSamples
                pixelRed := Round((red * backgroundOnlySamples
                    + foregroundRed * foregroundSamples) / totalSamples)
                pixelGreen := Round((green * backgroundOnlySamples
                    + foregroundGreen * foregroundSamples) / totalSamples)
                pixelBlue := Round((blue * backgroundOnlySamples
                    + foregroundBlue * foregroundSamples) / totalSamples)
                pixel := (alpha << 24) | (pixelRed << 16)
                    | (pixelGreen << 8) | pixelBlue
                NumPut("UInt", pixel, colorBits, (y * cellSize + x) * 4)
            }
        }

        maskBitmap := CreateIconMaskFromAlpha(screenDC,
            colorBits, cellSize, cellSize)
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
            DllCall("gdi32\DeleteObject", "Ptr", maskBitmap)
        if colorBitmap
            DllCall("gdi32\DeleteObject", "Ptr", colorBitmap)
        if screenDC
            DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDC)
    }
}

AddMainStatusIcons(imageList, statusIconIndices) {
    statusIconIndices.Clear()
    glyphSize := Max(16, Round(20 * App.mainDpi / 96))
    statusColors := Map(
        "Running", 0x00B050,
        "Paused", 0xFFAA00,
        "Warning", 0xFFD400,
        "Error", 0xE11937,
        "Pending", 0x0066D6,
        "Updating", 0x7A36D8,
        "Idle", 0x00A6C8
    )
    for statusKind, color in statusColors {
        statusIcon := CreateStatusGlyphIcon(statusKind, color,
            glyphSize, App.mainIconCellPixelSize)
        iconIndex := statusIcon
            ? IL_Add(imageList, "HICON:" statusIcon)
            : 0
        if statusIcon
            DllCall("user32\DestroyIcon", "Ptr", statusIcon)
        statusIconIndices[statusKind] := iconIndex
    }
}

CreateHighQualityPaddedIcon(hIcon, iconSize, cellSize) {
    if !hIcon || !EnsureIconResampler()
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
        factoryVtable := NumGet(App.iconResamplerFactory, 0, "Ptr")
        createFromMemory := NumGet(factoryVtable, 20 * A_PtrSize, "Ptr")
        if DllCall(createFromMemory, "Ptr", App.iconResamplerFactory,
            "UInt", sourceWidth, "UInt", sourceHeight, "Ptr", sourcePixelFormat,
            "UInt", sourceWidth * 4, "UInt", sourcePixels.Size,
            "Ptr", sourcePixels, "Ptr*", &wicSource, "Int") < 0
            return 0
        createScaler := NumGet(factoryVtable, 11 * A_PtrSize, "Ptr")
        if DllCall(createScaler, "Ptr", App.iconResamplerFactory,
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
        ReleaseIconComObject(wicScaler)
        ReleaseIconComObject(wicSource)
        if targetMaskBitmap
            DllCall("gdi32\DeleteObject", "Ptr", targetMaskBitmap)
        if targetColorBitmap
            DllCall("gdi32\DeleteObject", "Ptr", targetColorBitmap)
        if sourceMaskBitmap
            DllCall("gdi32\DeleteObject", "Ptr", sourceMaskBitmap)
        if sourceColorBitmap
            DllCall("gdi32\DeleteObject", "Ptr", sourceColorBitmap)
        if screenDC
            DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDC)
    }
}

CreateMaskPaddedIcon(hIcon, iconSize, cellSize) {
    if !hIcon || iconSize <= 0 || cellSize < iconSize
        return 0
    screenDC := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
    colorDC := DllCall("gdi32\CreateCompatibleDC", "Ptr", screenDC, "Ptr")
    maskDC := DllCall("gdi32\CreateCompatibleDC", "Ptr", screenDC, "Ptr")
    bitmapInfo := Buffer(40, 0)
    NumPut("UInt", 40, bitmapInfo, 0)
    NumPut("Int", cellSize, bitmapInfo, 4)
    NumPut("Int", -cellSize, bitmapInfo, 8)
    NumPut("UShort", 1, bitmapInfo, 12)
    NumPut("UShort", 32, bitmapInfo, 14)
    bits := 0
    colorBitmap := DllCall("gdi32\CreateDIBSection", "Ptr", screenDC, "Ptr", bitmapInfo, "UInt", 0, "Ptr*", &bits, "Ptr", 0, "UInt", 0, "Ptr")
    maskBitmap := DllCall("gdi32\CreateBitmap", "Int", cellSize, "Int", cellSize, "UInt", 1, "UInt", 1, "Ptr", 0, "Ptr")
    paddedIcon := 0
    if colorDC && maskDC && colorBitmap && maskBitmap {
        previousColorBitmap := DllCall("gdi32\SelectObject", "Ptr", colorDC, "Ptr", colorBitmap, "Ptr")
        previousMaskBitmap := DllCall("gdi32\SelectObject", "Ptr", maskDC, "Ptr", maskBitmap, "Ptr")
        if bits
            DllCall("ntdll\RtlZeroMemory", "Ptr", bits, "UPtr", cellSize * cellSize * 4)
        DllCall("gdi32\PatBlt", "Ptr", maskDC, "Int", 0, "Int", 0, "Int", cellSize, "Int", cellSize, "UInt", 0x00FF0062)
        offset := Floor((cellSize - iconSize) / 2)
        DllCall("user32\DrawIconEx", "Ptr", colorDC, "Int", offset, "Int", offset, "Ptr", hIcon, "Int", iconSize, "Int", iconSize, "UInt", 0, "Ptr", 0, "UInt", 0x0003)
        DllCall("user32\DrawIconEx", "Ptr", maskDC, "Int", offset, "Int", offset, "Ptr", hIcon, "Int", iconSize, "Int", iconSize, "UInt", 0, "Ptr", 0, "UInt", 0x0001)
        DllCall("gdi32\SelectObject", "Ptr", colorDC, "Ptr", previousColorBitmap)
        DllCall("gdi32\SelectObject", "Ptr", maskDC, "Ptr", previousMaskBitmap)
        iconInfo := Buffer(A_PtrSize == 8 ? 32 : 20, 0)
        NumPut("Int", 1, iconInfo, 0)
        bitmapOffset := A_PtrSize == 8 ? 16 : 12
        NumPut("Ptr", maskBitmap, iconInfo, bitmapOffset)
        NumPut("Ptr", colorBitmap, iconInfo, bitmapOffset + A_PtrSize)
        paddedIcon := DllCall("user32\CreateIconIndirect", "Ptr", iconInfo, "Ptr")
    }
    if colorBitmap
        DllCall("gdi32\DeleteObject", "Ptr", colorBitmap)
    if maskBitmap
        DllCall("gdi32\DeleteObject", "Ptr", maskBitmap)
    if colorDC
        DllCall("gdi32\DeleteDC", "Ptr", colorDC)
    if maskDC
        DllCall("gdi32\DeleteDC", "Ptr", maskDC)
    if screenDC
        DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDC)
    return paddedIcon
}

AddIconToImageList(imageList, hIcon, useHighQualityResampling := false) {
    if !hIcon
        return 0
    paddedIcon := 0
    if imageList == Main.appIcons {
        if useHighQualityResampling
            try paddedIcon := CreateHighQualityPaddedIcon(hIcon,
                App.mainIconPixelSize, App.mainIconCellPixelSize)
        if !paddedIcon
            paddedIcon := CreateMaskPaddedIcon(hIcon,
                App.mainIconPixelSize, App.mainIconCellPixelSize)
    }
    iconToAdd := paddedIcon ? paddedIcon : hIcon
    index := IL_Add(imageList, "HICON:" iconToAdd)
    if paddedIcon
        DllCall("user32\DestroyIcon", "Ptr", paddedIcon)
    return index
}

FormatMainListLabel(name, isAdmin := false) {
    ; NBSP 不参与中西文断行规则，可稳定补充少量图文间距且保持名称左侧对齐。
    return Chr(0x00A0) name . (isAdmin ? " 🛡️" : "")
}

FormatMainStatusLabel(statusText) {
    ; 原生 ListView 会把 Emoji 回退为单色字形，状态色改由真彩图标槽呈现。
    return RegExReplace(statusText,
        "^(?:✅|❌|⚠|⏸|⏳|🔄|🚀)\x{FE0F}?\h*", "")
}

GetMainStatusVisualKind(statusText) {
    label := FormatMainStatusLabel(statusText)
    if InStr(label, "不存在") || InStr(label, "失败")
        || InStr(label, "无法停止")
        return "Error"
    if InStr(label, "疑似停止") || InStr(label, "超时")
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
RegisterHoverButton(Main.btnDel, "4C4A4A", "4C4A4A")
RegisterHoverButton(Main.btnPause, "4C4B49", "4C4B49")
RegisterHoverButton(Main.btnSet, "333333")
RegisterHoverButton(Main.btnHelp, "333333")
RegisterHoverButton(Main.btnLog, "333333")
; 主列表统一使用 28px 逻辑尺寸，并按窗口 DPI 缩放。
Main.appIcons := CreateMainImageList(Main.statusIconIndices)
OnExit(ShutdownIconResampler)

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
        
        Main.btnDel.Opt("cWhite Background6B4B4B")
        Main.btnPause.Opt("cWhite Background6B6244")
        SetHoverButtonColors(Main.btnDel, "6B4B4B")
        SetHoverButtonColors(Main.btnPause, "6B6244")
        
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
    
    Main.btnDel.Opt("cB8BAB9 Background554B4B")
    Main.btnPause.Opt("cB8BAB9 Background555148")
    SetHoverButtonColors(Main.btnDel, "554B4B", "554B4B")
    SetHoverButtonColors(Main.btnPause, "555148", "555148")
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
    CommitUndoState()

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
        iconIdx := GetFileIconIndex(data.path, ctrl.IL)
        insertedRow := ctrl.Insert(shiftedTarget, "Icon" iconIdx " Select",
            data.name, data.status, data.path)
        persistedStatus := App.appStates.Has(data.path)
            ? App.appStates[data.path].State
            : data.status
        SetMainListStatus(insertedRow, persistedStatus)
        shiftedTarget++
    }

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

ReleaseWindowIcons(hWnd) {
    if !App.iconHandles.Has(hWnd)
        return
    for hIcon in App.iconHandles[hWnd] {
        if hIcon
            try DllCall("user32\DestroyIcon", "Ptr", hIcon)
    }
    App.iconHandles.Delete(hWnd)
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

    if (rows.Length > 0)
        CommitUndoState()
        
    for row in rows {
        path := Main.lv.GetText(row, 3)
        if App.appStates.Has(path) {
            stateObj := App.appStates[path]
            stateObj.RunAsAdmin := !(stateObj.HasOwnProp("RunAsAdmin") ? stateObj.RunAsAdmin : 0)
            SplitPath(path, , , , &nameNoExt)
            Main.lv.Modify(row, "Col1", FormatMainListLabel(nameNoExt, stateObj.RunAsAdmin))
            LogMsg((stateObj.RunAsAdmin ? "启用" : "关闭") . "了以管理员身份运行: " . nameNoExt)
        }
    }
    if (rows.Length > 0)
        SaveAppsToIni()
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
        if App.appStates.Has(path) {
            stateObj := App.appStates[path]
            if IsMaintenanceBlocking(stateObj) {
                ShowDarkMsgBox("该软件正在升级保护中。请等待升级完成，或在“软件升级保护”中结束等待后再重新启动。", "暂时无法重新启动", "Info", Main.gui)
                continue
            }
            
            UpdateState(path, "⏳ 停止原进程...")
            if SubStr(path, 1, 8) == "Service:" {
                serviceName := SubStr(path, 9)
                isAdmin := stateObj.HasOwnProp("RunAsAdmin") && stateObj.RunAsAdmin
                stateObj.ServiceRestartRequested := true
                if (!StopWindowsService(serviceName)) {
                    runVerb := isAdmin ? "*RunAs " : ""
                    Run(runVerb 'net stop "' serviceName '"', , "Hide")
                }
            } else {
                App.wmiError := false
                pid := CheckIsRunning(path)
                if App.wmiError {
                    stateObj.Pending := true
                    UpdateState(path, "⏳ 等待进程状态...")
                    ScheduleRestart(path, 2000)
                    LogMsg("暂时无法查询进程状态，稍后重试手动重启: " path)
                    continue
                }
                if (pid && !GracefulStop(pid)) {
                    SetStateProcessIdentity(stateObj, pid)
                    stateObj.Pending := false
                    UpdateState(path, "❌ 无法停止原进程")
                    LogMsg("手动重启已取消，原进程未能停止: " path)
                    continue
                }
            }
            
            stateObj.Enabled := 1
            stateObj.Pending := true
            stateObj.TargetStartTicks := 0
            stateObj.FailCount := 0
            ClearStateProcessIdentity(stateObj)
            
            DoRestart(path)
            LogMsg("手动触发了重新启动: " path)
        }
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
OnMessage(Win32.WM_SETCURSOR, OnSetCursor)
OnMessage(Win32.WM_LBUTTONDOWN, OnGlobalPointerDown)
OnMessage(Win32.WM_LBUTTONUP, OnGlobalPointerUp)
OnMessage(Win32.WM_NCLBUTTONDOWN, OnGlobalPointerDown)
OnMessage(Win32.WM_CANCELMODE, OnButtonPressCancelled)
OnMessage(Win32.WM_CAPTURECHANGED, OnButtonCaptureChanged)
OnMessage(Win32.WM_MOUSEMOVE, OnMouseMove_Tooltip)
OnMessage(Win32.WM_MOUSELEAVE, OnMouseLeave_Hover)

Global_KeyDown(wParam, lParam, msg, hwnd) {
    controlClass := ""
    try controlClass := WinGetClass("ahk_id " hwnd)
    isTextEditor := RegExMatch(controlClass, "i)^Edit$") != 0
    ; 文本框保留自身的撤销、重做和编辑快捷键，不能被主窗口历史栈抢占。
    if (isTextEditor && GetKeyState("Ctrl", "P"))
        return
    if ((wParam == 13 || wParam == 32) && App.buttonHoverStates.Has(hwnd)) {
        buttonState := App.buttonHoverStates[hwnd]
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
LoadAppsFromIni()
RestoreMaintenanceSessions()
InitializeMaintenanceSubsystem()

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
        targetPath := ""
        ReadShortcutData(path, &targetPath, &resolvedWorkDir, &shortcutArguments)
    }
    ; 快捷方式始终作为启动入口保存；真实进程身份由 ResolvedTarget 独立维护。
    return path
}

MainDpiChanged(wParam, lParam, msg, hwnd) {
    if (hwnd != Main.gui.Hwnd)
        return
    newDpi := wParam & 0xFFFF
    if (!newDpi || newDpi == App.mainDpi)
        return
    if App.dpiRebuildTimer
        SetTimer(App.dpiRebuildTimer, 0)
    App.dpiRebuildTimer := RebuildMainImageList.Bind(newDpi)
    SetTimer(App.dpiRebuildTimer, -250)
}

RebuildMainImageList(expectedDpi, *) {
    App.dpiRebuildTimer := 0
    if !DllCall("user32\IsWindow", "Ptr", Main.gui.Hwnd, "Int")
        return
    currentDpi := DllCall("user32\GetDpiForWindow", "Ptr", Main.gui.Hwnd, "UInt")
    if (currentDpi != expectedDpi)
        return
    oldImageList := Main.appIcons
    newStatusIconIndices := Map()
    newImageList := CreateMainImageList(newStatusIconIndices)
    if !newImageList
        return
    Main.lv.Opt("-Redraw")
    Main.appIcons := newImageList
    Main.statusIconIndices := newStatusIconIndices
    Main.lv.SetImageList(newImageList, 1)
    Main.lv.IL := newImageList
    Loop Main.lv.GetCount() {
        path := Main.lv.GetText(A_Index, 3)
        iconIndex := GetFileIconIndex(path, newImageList)
        if iconIndex
            Main.lv.Modify(A_Index, "Icon" iconIndex)
        statusText := App.appStates.Has(path)
            ? App.appStates[path].State
            : Main.lv.GetText(A_Index, 2)
        SetMainListStatus(A_Index, statusText)
    }
    Main.lv.Opt("+Redraw")
    if oldImageList {
        prefix := String(oldImageList) "_"
        staleKeys := []
        for cacheKey, _ in App.iconCache
            if InStr(cacheKey, prefix) == 1
                staleKeys.Push(cacheKey)
        for cacheKey in staleKeys
            App.iconCache.Delete(cacheKey)
        IL_Destroy(oldImageList)
    }
}

OnGuiDropFiles(GuiObj, CtrlObj, FileArray, X, Y) {
    directories := []
    files := []
    for dropPath in FileArray {
        if DirExist(dropPath)
            directories.Push(dropPath)
        else if IsSupportedMonitorFile(dropPath)
            files.Push(dropPath)
    }
    if directories.Length {
        GuiModules.addItem.StartBatchImport(directories, files)
        return
    }
    if files.Length {
        CommitUndoState()
        addedCount := 0
        for filePath in files {
            shortcutArgs := "", resolvedWorkDir := ""
            resolvedPath := ResolveShortcutForAdd(filePath, &shortcutArgs, &resolvedWorkDir)
            if RegisterApp(resolvedPath, 1, 0, resolvedWorkDir,
                "", "", "", "", false, shortcutArgs)
                addedCount++
        }
        if addedCount
            SaveAppsToIni()
        LogMsg("通过拖拽添加了 " addedCount " 个监控项。")
    }
}

; 检查是否是通过“重新加载”触发的启动，决定显示界面还是静默系统托盘
try {
    if (IniRead(App.iniPath, "Settings", "ShowAfterReload", 0) == "1") {
        IniWrite(0, App.iniPath, "Settings", "ShowAfterReload")
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

SetTimer(MonitorLoop, App.checkInterval)
SetTimer(UpdateCountdownUI, 1000) ; 倒计时显示按整秒刷新
SetTimer(MaintenanceEventLoop, App.maintenancePollInterval)
SetTimer(MaintenanceProcessLoop, App.maintenanceProcessInterval)
OnExit(CleanupMaintenanceSubsystem)
LogMsg(App.isReloadedMode ? "代码热重载完毕，界面已恢复显示。" : "进程守护小助手已静默启动。")

OnMainGuiClose(*) {
    HideMainGui()
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
        Critical("On")
        try {
        c1 := SendMessage(Win32.LVM_GETCOLUMNWIDTH, 0, 0, Main.lv.Hwnd)
        c2 := SendMessage(Win32.LVM_GETCOLUMNWIDTH, 1, 0, Main.lv.Hwnd)
        windowDpi := DllCall("user32\GetDpiForWindow", "Ptr", Main.gui.Hwnd, "UInt")
        dpiScale := (windowDpi ? windowDpi : 96) / 96
        IniWrite(gW, App.iniPath, "Layout", "GuiW")
        IniWrite(gH, App.iniPath, "Layout", "GuiH")
        IniWrite(Round(c1 / dpiScale), App.iniPath, "Layout", "Col1W")
        IniWrite(Round(c2 / dpiScale), App.iniPath, "Layout", "Col2W")
        } catch as layoutErr {
            LogMsg("保存窗口布局失败: " layoutErr.Message)
        } finally {
            Critical("Off")
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
        locationPath := FileExist(path) ? path : GetMonitoredTargetPath(path)
        SplitPath(locationPath, , &dir)
        if FileExist(locationPath)
            Run('explorer.exe /select,"' locationPath '"')
        else if FileExist(dir)
            Run('explorer.exe "' dir '"')
    }}

; ==========================================
; 9. 托盘与窗口控制
; ==========================================
ShowMainGui(*) {
    Main.gui.Show()
    if WindowHierarchy.IsOwnerLocked(Main.gui)
        WindowHierarchy.ActivateTopOwned(Main.gui)
}
ReloadScript(*) {
    HideMainGui(true)
    ; 向配置文件注入重载标记，以便在新进程中直接弹出主窗口
    try {
        Critical("On")
        try IniWrite(1, App.iniPath, "Settings", "ShowAfterReload")
        finally Critical("Off")
    } catch as reloadErr {
        LogMsg("保存重载标记失败: " reloadErr.Message)
    }
    
    ; 释放内核级 Mutex 单实例锁，否则 Reload 产生的新进程会因为判定已存在旧锁而主动退出
    if App.mutexHandle
        DllCall("kernel32\CloseHandle", "Ptr", App.mutexHandle)
    Reload()
}
ExitProgram(*) {
    HideMainGui(true)
    ExitApp()
}

; ==========================================
; 10. 核心监控与重试逻辑 (无冗余 Global 声明)
; ==========================================
ReadIniBool(section, key, defaultValue) {
    try return Integer(IniRead(App.iniPath, section, key, defaultValue ? 1 : 0)) != 0
    catch
        return defaultValue
}

ReadIniBoundedInt(section, key, defaultValue, minValue, maxValue) {
    try value := Integer(IniRead(App.iniPath, section, key, defaultValue))
    catch
        return defaultValue
    return (value >= minValue && value <= maxValue) ? value : defaultValue
}

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
    if (SubStr(path, 1, 8) == "Service:")
        return "Service:" StrLower(Trim(SubStr(path, 9)))
    return StrReplace(path, "/", "\")
}

ReadShortcutData(path, &targetPath := "", &workingDir := "", &arguments := "") {
    targetPath := ""
    workingDir := ""
    arguments := ""
    try {
        FileGetShortcut(path, &targetPath, &workingDir, &arguments)
        return true
    } catch {
        return false
    }
}

GetShortcutWorkingDirectory(path) {
    targetPath := ""
    workingDir := ""
    if ReadShortcutData(path, &targetPath, &workingDir)
        return workingDir
    return ""
}

GetShortcutTargetPath(path) {
    targetPath := ""
    if ReadShortcutData(path, &targetPath)
        return targetPath
    return ""
}

IsValidExecutableFile(path) {
    if !FileExist(path)
        return false
    fileHandle := DllCall("kernel32\CreateFileW", "WStr", path, "UInt", 0x80000000,
        "UInt", Win32.FILE_SHARE_ALL, "Ptr", 0, "UInt", Win32.OPEN_EXISTING,
        "UInt", 0x00000080, "Ptr", 0, "Ptr")
    if (!fileHandle || fileHandle == -1)
        return false
    header := Buffer(2, 0)
    bytesRead := 0
    try {
        DllCall("kernel32\ReadFile", "Ptr", fileHandle, "Ptr", header,
            "UInt", 2, "UInt*", &bytesRead, "Ptr", 0, "Int")
    } finally {
        DllCall("kernel32\CloseHandle", "Ptr", fileHandle)
    }
    return bytesRead == 2 && NumGet(header, 0, "UShort") == 0x5A4D
}

IsUsableShortcutTarget(path) {
    if !FileExist(path) || DirExist(path)
        return false
    SplitPath(path, , , &extension)
    extension := StrLower(extension)
    if !RegExMatch(extension, "i)^(exe|com|msc|ahk|py|pyw|js|vbs|vbe|wsf|ps1|bat|cmd|rb|pl|php|lua|jar|sh|bash)$")
        return false
    return extension != "exe" && extension != "com" || IsValidExecutableFile(path)
}

IsGenericLauncherTarget(path) {
    SplitPath(path, &fileName)
    return RegExMatch(fileName,
        "i)^(explorer|cmd|powershell|pwsh|wscript|cscript|rundll32|regsvr32|msiexec|pythonw?|node|javaw?|dotnet|autohotkey.*)\.exe$") != 0
}

ExtractShortcutArgumentTarget(arguments) {
    if (arguments == "")
        return ""
    extensions := "exe|com|msc|ahk|py|pyw|js|vbs|vbe|wsf|ps1|bat|cmd|rb|pl|php|lua|jar|sh|bash"
    matched := RegExMatch(arguments,
        "i)\x22([a-z]:\\[^\x22]+\.(?:" extensions "))\x22", &match)
    if !matched
        matched := RegExMatch(arguments,
            "i)(?:^|\s|=)([a-z]:\\.+?\.(?:" extensions "))(?=\s|$)", &match)
    if matched {
        candidatePath := Trim(match[1])
        if IsUsableShortcutTarget(candidatePath)
            return candidatePath
    }
    return ""
}

IsPotentialShortcutProcessTarget(path) {
    if (path == "" || !InStr(path, "\"))
        return false
    SplitPath(path, , , &extension)
    return RegExMatch(extension, "i)^(exe|com|msc|ahk|py|pyw|js|vbs|vbe|wsf|ps1|bat|cmd|rb|pl|php|lua|jar|sh|bash)$") != 0
}

ResolveMsiShortcutTarget(path) {
    productCode := Buffer(39 * 2, 0)
    featureId := Buffer(256 * 2, 0)
    componentCode := Buffer(39 * 2, 0)
    try result := DllCall("msi\MsiGetShortcutTargetW", "WStr", path,
        "Ptr", productCode.Ptr, "Ptr", featureId.Ptr, "Ptr", componentCode.Ptr, "UInt")
    catch
        return ""
    if result != 0
        return ""

    pathLength := 32767
    pathBuffer := Buffer((pathLength + 1) * 2, 0)
    try installState := DllCall("msi\MsiGetComponentPathW", "Ptr", productCode.Ptr,
        "Ptr", componentCode.Ptr, "Ptr", pathBuffer.Ptr, "UInt*", &pathLength, "Int")
    catch
        return ""
    if (installState < 0 || pathLength == 0)
        return ""
    resolvedPath := StrGet(pathBuffer.Ptr, pathLength, "UTF-16")
    return IsPotentialShortcutProcessTarget(resolvedPath) ? resolvedPath : ""
}

GetExecutableVersionValues(path) {
    static versionCache := Map()
    values := Map()
    values.CaseSense := "Off"
    try cacheKey := GetCanonicalPath(path) "|" FileGetSize(path) "|" FileGetTime(path, "M")
    catch
        return values
    if versionCache.Has(cacheKey)
        return versionCache[cacheKey]

    ignoredHandle := 0
    try infoSize := DllCall("version\GetFileVersionInfoSizeW", "WStr", path,
        "UInt*", &ignoredHandle, "UInt")
    catch
        return values
    if !infoSize
        return values
    infoBuffer := Buffer(infoSize, 0)
    try {
        if !DllCall("version\GetFileVersionInfoW", "WStr", path, "UInt", 0,
            "UInt", infoSize, "Ptr", infoBuffer.Ptr, "Int")
            return values
    } catch {
        return values
    }

    translations := []
    translationPtr := 0
    translationBytes := 0
    try {
        if DllCall("version\VerQueryValueW", "Ptr", infoBuffer.Ptr,
            "WStr", "\VarFileInfo\Translation", "Ptr*", &translationPtr,
            "UInt*", &translationBytes, "Int") {
            Loop translationBytes // 4 {
                offset := (A_Index - 1) * 4
                language := NumGet(translationPtr, offset, "UShort")
                codePage := NumGet(translationPtr, offset + 2, "UShort")
                translations.Push(Format("{:04X}{:04X}", language, codePage))
            }
        }
    }
    for fieldName in ["ProductName", "FileDescription", "InternalName", "OriginalFilename"] {
        values[fieldName] := ""
        for translation in translations {
            valuePtr := 0
            valueLength := 0
            queryPath := "\StringFileInfo\" translation "\" fieldName
            try {
                if DllCall("version\VerQueryValueW", "Ptr", infoBuffer.Ptr,
                    "WStr", queryPath, "Ptr*", &valuePtr, "UInt*", &valueLength, "Int")
                    && valuePtr && valueLength {
                    values[fieldName] := Trim(StrGet(valuePtr, "UTF-16"))
                    break
                }
            }
        }
    }
    if (versionCache.Count >= 1000)
        versionCache.Clear()
    versionCache[cacheKey] := values
    return values
}

NormalizeIdentityText(value) {
    return RegExReplace(StrLower(Trim(value)), "[^\p{L}\p{N}]+")
}

ScoreIdentityText(wanted, candidate) {
    wanted := NormalizeIdentityText(wanted)
    candidate := NormalizeIdentityText(candidate)
    if (wanted == "" || candidate == "")
        return 0
    if (wanted == candidate)
        return 120
    if (StrLen(wanted) >= 4 && StrLen(candidate) >= 4
        && (InStr(candidate, wanted) || InStr(wanted, candidate)))
        return 55
    return 0
}

IsObservedProcessPath(path) {
    if (!App.latestProcessSnapshotTicks
        || GetTickCount64() - App.latestProcessSnapshotTicks > 30000)
        return false
    wanted := GetCanonicalPath(path)
    for processInfo in App.latestProcessSnapshot {
        if (processInfo.exe != "" && GetCanonicalPath(processInfo.exe) == wanted)
            return true
    }
    return false
}

ScoreShortcutExecutableCandidate(shortcutName, workingDir, candidatePath) {
    SplitPath(candidatePath, &candidateName, , , &candidateBase)
    SplitPath(RTrim(workingDir, "\"), , , , &directoryName)
    score := ScoreIdentityText(shortcutName, candidateBase)
    score += ScoreIdentityText(directoryName, candidateBase) // 3
    versionValues := GetExecutableVersionValues(candidatePath)
    for fieldName in ["ProductName", "FileDescription", "InternalName", "OriginalFilename"] {
        identityValue := versionValues.Has(fieldName) ? versionValues[fieldName] : ""
        score += ScoreIdentityText(shortcutName, identityValue)
        score += ScoreIdentityText(directoryName, identityValue) // 4
    }
    if IsObservedProcessPath(candidatePath)
        score += 45
    if RegExMatch(candidateName,
        "i)(^|[._ -])(update|updater|upgrade|patch|setup|install|unins|uninstall|repair|helper|service|connector|crash|report|telemetry)([._ -]|$)")
        score -= 90
    return score
}

FindShortcutExecutableCandidate(path, workingDir) {
    if !DirExist(workingDir)
        return ""
    shortcutName := ""
    SplitPath(path, , , , &shortcutName)
    candidates := []
    try {
        Loop Files, RTrim(workingDir, "\") "\*.exe", "F" {
            if IsValidExecutableFile(A_LoopFileFullPath)
                candidates.Push(A_LoopFileFullPath)
            if (candidates.Length >= 200)
                break
        }
        if (candidates.Length >= 200)
            return ""
        Loop Files, RTrim(workingDir, "\") "\*.com", "F" {
            if IsValidExecutableFile(A_LoopFileFullPath)
                candidates.Push(A_LoopFileFullPath)
            if (candidates.Length >= 200)
                break
        }
    }
    if (candidates.Length == 1) {
        SplitPath(candidates[1], &onlyName)
        return RegExMatch(onlyName,
            "i)(^|[._ -])(update|updater|upgrade|patch|setup|install|unins|uninstall|repair|helper|service|connector|crash|report|telemetry)([._ -]|$)")
            ? "" : candidates[1]
    }
    if (candidates.Length == 0)
        return ""

    bestPath := ""
    bestScore := -100000
    secondScore := -100000
    for candidatePath in candidates {
        score := ScoreShortcutExecutableCandidate(shortcutName, workingDir, candidatePath)
        if (score > bestScore) {
            secondScore := bestScore
            bestScore := score
            bestPath := candidatePath
        } else if (score > secondScore) {
            secondScore := score
        }
    }
    return bestScore >= 100 && bestScore - secondScore >= 20 ? bestPath : ""
}

GetShortcutEffectiveTargetPath(path, allowMissing := false, &resolutionSource := "") {
    resolutionSource := ""
    msiTarget := ResolveMsiShortcutTarget(path)
    if (msiTarget != "" && (allowMissing || IsUsableShortcutTarget(msiTarget))) {
        resolutionSource := "Windows Installer"
        return msiTarget
    }

    targetPath := ""
    workingDir := ""
    arguments := ""
    if !ReadShortcutData(path, &targetPath, &workingDir, &arguments)
        return ""
    argumentTarget := ExtractShortcutArgumentTarget(arguments)
    if (argumentTarget != "") {
        resolutionSource := "快捷方式参数"
        return argumentTarget
    }
    if (targetPath != "" && IsUsableShortcutTarget(targetPath)
        && (arguments == "" || !IsGenericLauncherTarget(targetPath))) {
        resolutionSource := "快捷方式目标"
        return targetPath
    }
    if (workingDir == "")
        return ""

    candidatePath := FindShortcutExecutableCandidate(path, workingDir)
    if (candidatePath != "") {
        resolutionSource := "安装目录特征"
        return candidatePath
    }
    return ""
}

ResolveShortcutTargetForState(path, savedTarget := "", &resolutionSource := "", manualOverride := false) {
    if (manualOverride && IsPotentialShortcutProcessTarget(savedTarget)) {
        resolutionSource := "用户指定"
        return NormalizeTargetPath(savedTarget)
    }
    freshTarget := GetShortcutEffectiveTargetPath(path, true, &resolutionSource)
    if (freshTarget != "")
        return freshTarget
    if IsPotentialShortcutProcessTarget(savedTarget) {
        resolutionSource := "已保存身份"
        return NormalizeTargetPath(savedTarget)
    }
    return ""
}

GetMonitoredTargetPath(path) {
    SplitPath(path, , , &extension)
    if (StrLower(extension) != "lnk")
        return path
    if App.appStates.Has(path) {
        stateObj := App.appStates[path]
        if (stateObj.HasOwnProp("ResolvedTarget") && stateObj.ResolvedTarget != "")
            return stateObj.ResolvedTarget
    }
    return GetShortcutEffectiveTargetPath(path, true)
}

GetStateIdentityTarget(path, stateObj := "") {
    if (stateObj && stateObj.HasOwnProp("ResolvedTarget") && stateObj.ResolvedTarget != "")
        return stateObj.ResolvedTarget
    return IsPotentialShortcutProcessTarget(path) ? path : ""
}

FindIdentityConflict(candidateTarget, excludedPath := "") {
    if (candidateTarget == "")
        return ""
    for existingPath, existingState in App.appStates {
        if (excludedPath != "" && PathsEquivalent(existingPath, excludedPath))
            continue
        existingTarget := GetStateIdentityTarget(existingPath, existingState)
        if (existingTarget != "" && PathsEquivalent(candidateTarget, existingTarget))
            return existingPath
    }
    return ""
}

RefreshShortcutIdentity(path, stateObj, force := false) {
    SplitPath(path, , , &extension)
    if (StrLower(extension) != "lnk" || !stateObj)
        return false
    if (stateObj.HasOwnProp("ResolvedTargetManual") && stateObj.ResolvedTargetManual)
        return false
    nowTicks := GetTickCount64()
    if (!force && stateObj.HasOwnProp("ShortcutResolveCheckedTicks")
        && nowTicks - stateObj.ShortcutResolveCheckedTicks < 30000)
        return false
    stateObj.ShortcutResolveCheckedTicks := nowTicks
    freshTarget := GetShortcutEffectiveTargetPath(path, true, &resolutionSource)
    if (freshTarget == "")
        return false
    priorResolvedTarget := stateObj.HasOwnProp("ResolvedTarget") ? stateObj.ResolvedTarget : ""
    stateObj.ShortcutTargetSource := resolutionSource
    shortcutTarget := "", shortcutWorkingDirectory := "", shortcutArguments := ""
    shortcutArgsChanged := false
    if ReadShortcutData(path, &shortcutTarget, &shortcutWorkingDirectory, &shortcutArguments) {
        priorShortcutArguments := stateObj.HasOwnProp("ShortcutArgs") ? stateObj.ShortcutArgs : ""
        shortcutArgsChanged := priorShortcutArguments != shortcutArguments
        stateObj.ShortcutArgs := shortcutArguments
    }
    if PathsEquivalent(priorResolvedTarget, freshTarget) {
        if shortcutArgsChanged
            LogMsg("已刷新快捷方式内置参数: " path)
        return shortcutArgsChanged
    }
    conflictPath := FindIdentityConflict(freshTarget, path)
    if (conflictPath != "") {
        LogMsg("快捷方式真实进程刷新被拒绝，目标已由其它项目守护: " path " -> " conflictPath)
        return false
    }

    priorInstallRoot := stateObj.HasOwnProp("MaintenanceConfig")
        ? stateObj.MaintenanceConfig.InstallRoot : ""
    stateObj.ResolvedTarget := freshTarget
    if (stateObj.HasOwnProp("MaintenanceConfig") && !stateObj.MaintenanceConfig.RootIsCustom) {
        SplitPath(freshTarget, , &freshDirectory)
        if (freshDirectory != "")
            stateObj.MaintenanceConfig.InstallRoot := NormalizeMaintenanceRoot(freshDirectory)
        if !PathsEquivalent(priorInstallRoot, stateObj.MaintenanceConfig.InstallRoot) {
            CloseMaintenanceWatcher(stateObj)
            EnsureMaintenanceWatcher(path, stateObj)
        }
    }
    refreshedFingerprint := GetTargetFileFingerprint(freshTarget)
    if stateObj.HasOwnProp("SafetyFingerprint") {
        stateObj.SafetyFingerprint := refreshedFingerprint
        stateObj.MaintenanceBaselineFingerprint := refreshedFingerprint
        stateObj.SafetyStableSince := nowTicks
        stateObj.MaintenanceFingerprintCheckedTicks := nowTicks
        stateObj.MaintenanceReadyCheckedTicks := 0
    }
    LogMsg("已刷新快捷方式真实进程（" resolutionSource "）: " path " -> " freshTarget)
    return true
}

TargetReferenceExists(path, stateObj := "") {
    if !InStr(path, "\")
        return true
    if FileExist(path)
        return true
    SplitPath(path, , , &extension)
    if (StrLower(extension) != "lnk")
        return false
    effectiveTarget := ""
    if (stateObj && stateObj.HasOwnProp("ResolvedTarget"))
        effectiveTarget := stateObj.ResolvedTarget
    if (effectiveTarget == "")
        effectiveTarget := GetMonitoredTargetPath(path)
    return effectiveTarget != "" && FileExist(effectiveTarget)
}

GetLaunchTargetPath(path, stateObj) {
    if FileExist(path)
        return path
    SplitPath(path, , , &extension)
    if (StrLower(extension) != "lnk")
        return ""
    effectiveTarget := stateObj.HasOwnProp("ResolvedTarget") ? stateObj.ResolvedTarget : ""
    return effectiveTarget != "" && FileExist(effectiveTarget) ? effectiveTarget : ""
}

GetMaintenanceSubjectPath(path) {
    SplitPath(path, , , &extension)
    if (StrLower(extension) != "lnk")
        return path
    effectiveTarget := GetMonitoredTargetPath(path)
    return effectiveTarget != "" ? effectiveTarget : path
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
    if !InStr(path, "\") || SubStr(path, 1, 8) == "Service:"
        return false
    SplitPath(path, , , &extension)
    extension := StrLower(extension)
    if (extension == "lnk") {
        effectiveTarget := GetMonitoredTargetPath(path)
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
        effectiveTarget := GetMonitoredTargetPath(path)
        if (effectiveTarget != "") {
            SplitPath(effectiveTarget, , &effectiveDirectory)
            if (effectiveDirectory != "")
                return effectiveDirectory
        }
        workingDir := GetShortcutWorkingDirectory(path)
        if (workingDir != "")
            return StrLen(workingDir) > 3 ? RTrim(workingDir, "\") : workingDir
        targetPath := GetShortcutTargetPath(path)
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

CreateDefaultMaintenanceConfig(path) {
    return {
        Enabled: IsMaintenanceSupportedTarget(path),
        InstallRoot: GetDefaultMaintenanceRoot(path),
        RootIsCustom: false,
        DetectionSeconds: 10,
        StableSeconds: 8,
        MaxWaitSeconds: 1800,
        LearnedActors: []
    }
}

NormalizeMaintenanceConfig(config, path) {
    normalized := CreateDefaultMaintenanceConfig(path)
    if !config || Type(config) != "Object"
        return normalized
    if config.HasOwnProp("Enabled")
        normalized.Enabled := !!config.Enabled && IsMaintenanceSupportedTarget(path)
    if config.HasOwnProp("RootIsCustom")
        normalized.RootIsCustom := !!config.RootIsCustom
    if config.HasOwnProp("InstallRoot")
        normalized.InstallRoot := NormalizeMaintenanceRoot(config.InstallRoot, path)
    if (!normalized.RootIsCustom || normalized.InstallRoot == "")
        normalized.InstallRoot := GetDefaultMaintenanceRoot(path)
    if config.HasOwnProp("DetectionSeconds") {
        parsed := ParseBoundedInteger(config.DetectionSeconds, 2, 120)
        if parsed
            normalized.DetectionSeconds := parsed
    }
    if config.HasOwnProp("StableSeconds") {
        parsed := ParseBoundedInteger(config.StableSeconds, 2, 300)
        if parsed
            normalized.StableSeconds := parsed
    }
    if config.HasOwnProp("MaxWaitSeconds") {
        parsed := ParseBoundedInteger(config.MaxWaitSeconds, 60, 86400)
        if parsed
            normalized.MaxWaitSeconds := parsed
    }
    if config.HasOwnProp("LearnedActors") && Type(config.LearnedActors) == "Array" {
        seen := Map()
        seen.CaseSense := "Off"
        for actor in config.LearnedActors {
            actor := Trim(String(actor))
            if (actor != "" && !seen.Has(actor)) {
                seen[actor] := true
                normalized.LearnedActors.Push(actor)
            }
        }
    }
    return normalized
}

CloneMaintenanceConfig(config, path) {
    return NormalizeMaintenanceConfig(config, path)
}

SerializeMaintenanceConfig(config, path) {
    config := NormalizeMaintenanceConfig(config, path)
    payload := "Enabled=" (config.Enabled ? 1 : 0)
    payload .= "`nRootIsCustom=" (config.RootIsCustom ? 1 : 0)
    payload .= "`nDetectionSeconds=" config.DetectionSeconds
    payload .= "`nStableSeconds=" config.StableSeconds
    payload .= "`nMaxWaitSeconds=" config.MaxWaitSeconds
    payload .= "`nInstallRoot=" EncodeIniField(config.InstallRoot)
    for actor in config.LearnedActors
        payload .= "`nActor=" EncodeIniField(actor)
    return EncodeIniField(payload)
}

DeserializeMaintenanceConfig(encodedValue, path) {
    config := CreateDefaultMaintenanceConfig(path)
    if (encodedValue == "")
        return config
    payload := DecodeIniField(encodedValue)
    actors := []
    Loop Parse, payload, "`n", "`r" {
        separator := InStr(A_LoopField, "=")
        if !separator
            continue
        key := SubStr(A_LoopField, 1, separator - 1)
        value := SubStr(A_LoopField, separator + 1)
        switch key {
            case "Enabled":
                config.Enabled := value == "1"
            case "RootIsCustom":
                config.RootIsCustom := value == "1"
            case "DetectionSeconds":
                config.DetectionSeconds := value
            case "StableSeconds":
                config.StableSeconds := value
            case "MaxWaitSeconds":
                config.MaxWaitSeconds := value
            case "InstallRoot":
                config.InstallRoot := DecodeIniField(value)
            case "Actor":
                actors.Push(DecodeIniField(value))
        }
    }
    config.LearnedActors := actors
    return NormalizeMaintenanceConfig(config, path)
}

ReadIniSectionMap(sectionName) {
    values := Map()
    values.CaseSense := "Off"
    try sectionText := IniRead(App.iniPath, sectionName)
    catch
        return values
    Loop Parse, sectionText, "`n", "`r" {
        separator := InStr(A_LoopField, "=")
        if !separator
            continue
        values[SubStr(A_LoopField, 1, separator - 1)] := SubStr(A_LoopField, separator + 1)
    }
    return values
}

LoadAppsFromIni() {
    appValues := ReadIniSectionMap("Apps")
    maintenanceValues := ReadIniSectionMap("Maintenance")
    for appKey, appValue in appValues {
        if (appValue == "")
            continue
        try {
            parts := StrSplit(appValue, "|")
            if (parts.Length != 8 && parts.Length != 9) {
                App.configLoadWarnings.Push(appKey " 的字段数量无效")
                App.configRecoveryEntries.Push({Key: appKey, Value: appValue,
                    Maintenance: maintenanceValues.Has(appKey) ? maintenanceValues[appKey] : ""})
                continue
            }
            enabled := Integer(parts[1]) != 0
            runAsAdmin := Integer(parts[2]) != 0
            targetPath := parts[3]
            workDir := DecodeIniField(parts[4])
            arguments := DecodeIniField(parts[5])
            environment := DecodeIniField(parts[6])
            storedResolvedTarget := DecodeIniField(parts[7])
            resolvedTargetManual := Integer(parts[8]) != 0
            shortcutArguments := parts.Length >= 9 ? DecodeIniField(parts[9]) : ""
            maintenanceConfig := maintenanceValues.Has(appKey)
                ? DeserializeMaintenanceConfig(maintenanceValues[appKey], targetPath)
                : CreateDefaultMaintenanceConfig(targetPath)
            if (targetPath != "") {
                if !RegisterApp(targetPath, enabled, runAsAdmin, workDir,
                    arguments, environment, maintenanceConfig, storedResolvedTarget,
                    resolvedTargetManual, shortcutArguments) {
                    App.configLoadWarnings.Push(appKey " 与现有监控目标重复或无效")
                    App.configRecoveryEntries.Push({Key: appKey, Value: appValue,
                        Maintenance: maintenanceValues.Has(appKey) ? maintenanceValues[appKey] : ""})
                }
            } else {
                App.configLoadWarnings.Push(appKey " 的目标路径为空")
                App.configRecoveryEntries.Push({Key: appKey, Value: appValue,
                    Maintenance: maintenanceValues.Has(appKey) ? maintenanceValues[appKey] : ""})
            }
        } catch as loadErr {
            App.configLoadWarnings.Push(appKey ": " loadErr.Message)
            App.configRecoveryEntries.Push({Key: appKey, Value: appValue,
                Maintenance: maintenanceValues.Has(appKey) ? maintenanceValues[appKey] : ""})
        }
    }
    if App.configLoadWarnings.Length {
        LogMsg("发现 " App.configLoadWarnings.Length " 条无法加载的监控配置；原始内容将在保存时保留到 [Recovery]。")
        try TrayTip("发现无法加载的监控配置，原始内容不会被静默删除。请查看运行日志。", "进程守护小助手", 2)
    }
}

GetTargetFileFingerprint(path) {
    if !IsMaintenanceSupportedTarget(path)
        return "MISSING"
    path := GetMaintenanceSubjectPath(path)
    if !FileExist(path)
        return "MISSING"
    try fileSize := FileGetSize(path)
    catch
        fileSize := -1
    try modifiedTime := FileGetTime(path, "M")
    catch
        modifiedTime := ""
    volumeSerial := 0
    fileIndexHigh := 0
    fileIndexLow := 0
    fileHandle := DllCall("kernel32\CreateFileW", "WStr", path, "UInt", 0,
        "UInt", Win32.FILE_SHARE_ALL, "Ptr", 0, "UInt", Win32.OPEN_EXISTING,
        "UInt", 0x00000080, "Ptr", 0, "Ptr")
    if (fileHandle && fileHandle != -1) {
        fileInfo := Buffer(52, 0)
        if DllCall("kernel32\GetFileInformationByHandle", "Ptr", fileHandle, "Ptr", fileInfo.Ptr, "Int") {
            volumeSerial := NumGet(fileInfo, 28, "UInt")
            fileIndexHigh := NumGet(fileInfo, 44, "UInt")
            fileIndexLow := NumGet(fileInfo, 48, "UInt")
        }
        DllCall("kernel32\CloseHandle", "Ptr", fileHandle)
    }
    return fileSize "|" modifiedTime "||" Format("{:08X}{:08X}{:08X}", volumeSerial, fileIndexHigh, fileIndexLow)
}

IsTargetFileReady(path) {
    if !IsMaintenanceSupportedTarget(path)
        return true
    path := GetMaintenanceSubjectPath(path)
    if !FileExist(path)
        return false
    SplitPath(path, , , &extension)
    extension := StrLower(extension)
    fileHandle := DllCall("kernel32\CreateFileW", "WStr", path, "UInt", 0x80000000,
        "UInt", 0x00000005, "Ptr", 0, "UInt", Win32.OPEN_EXISTING,
        "UInt", 0x00000080, "Ptr", 0, "Ptr")
    if (!fileHandle || fileHandle == -1)
        return false
    ready := false
    try {
        header := Buffer(64, 0)
        bytesRead := 0
        if !DllCall("kernel32\ReadFile", "Ptr", fileHandle, "Ptr", header.Ptr,
            "UInt", header.Size, "UInt*", &bytesRead, "Ptr", 0, "Int")
            return false
        if (extension != "exe" && extension != "com")
            return bytesRead > 0
        if (bytesRead < 64 || NumGet(header, 0, "UShort") != 0x5A4D)
            return false
        peOffset := NumGet(header, 60, "UInt")
        if (peOffset < 64 || peOffset > 0x40000000)
            return false
        newPosition := 0
        if !DllCall("kernel32\SetFilePointerEx", "Ptr", fileHandle, "Int64", peOffset,
            "Int64*", &newPosition, "UInt", 0, "Int")
            return false
        signature := Buffer(4, 0)
        signatureBytes := 0
        if !DllCall("kernel32\ReadFile", "Ptr", fileHandle, "Ptr", signature.Ptr,
            "UInt", 4, "UInt*", &signatureBytes, "Ptr", 0, "Int")
            return false
        ready := signatureBytes == 4 && NumGet(signature, 0, "UInt") == 0x00004550
    } finally {
        DllCall("kernel32\CloseHandle", "Ptr", fileHandle)
    }
    return ready
}

PathIsWithinRoot(candidatePath, rootPath) {
    if (candidatePath == "" || rootPath == "")
        return false
    candidate := GetCanonicalPath(candidatePath)
    root := RTrim(GetCanonicalPath(rootPath), "\")
    return candidate == root || InStr(candidate, root "\") == 1
}

EnsureMaintenanceWatcher(path, stateObj) {
    if !stateObj.Enabled || !IsMaintenanceProtectionEnabled(path, stateObj) {
        CloseMaintenanceWatcher(stateObj)
        return false
    }
    rootPath := NormalizeMaintenanceRoot(stateObj.MaintenanceConfig.InstallRoot, path)
    if !DirExist(rootPath)
        return false
    rootKey := GetCanonicalPath(rootPath)
    currentRoot := stateObj.HasOwnProp("MaintenanceWatcherRoot")
        ? stateObj.MaintenanceWatcherRoot : ""
    if (currentRoot != "" && currentRoot != rootKey)
        CloseMaintenanceWatcher(stateObj)
    if !App.maintenanceWatchers.Has(rootKey) {
        try watcher := DirectoryChangeWatcher(rootPath)
        catch
            return false
        subscribers := Map()
        subscribers.CaseSense := "Off"
        App.maintenanceWatchers[rootKey] := {
            watcher: watcher, rootPath: rootPath, subscribers: subscribers
        }
    }
    entry := App.maintenanceWatchers[rootKey]
    entry.subscribers[path] := stateObj
    stateObj.MaintenanceWatcherRoot := rootKey
    stateObj.MaintenanceWatcherPath := path
    if entry.watcher.Active
        return true
    return entry.watcher.Open()
}

CloseMaintenanceWatcher(stateObj) {
    rootKey := stateObj.HasOwnProp("MaintenanceWatcherRoot")
        ? stateObj.MaintenanceWatcherRoot : ""
    path := stateObj.HasOwnProp("MaintenanceWatcherPath")
        ? stateObj.MaintenanceWatcherPath : ""
    stateObj.MaintenanceWatcherRoot := ""
    stateObj.MaintenanceWatcherPath := ""
    if (rootKey != "" && App.maintenanceWatchers.Has(rootKey)) {
        entry := App.maintenanceWatchers[rootKey]
        if (path != "" && entry.subscribers.Has(path))
            entry.subscribers.Delete(path)
        if !entry.subscribers.Count {
            try entry.watcher.Close()
            App.maintenanceWatchers.Delete(rootKey)
        }
    }
}

IsRelevantFootprintChange(path, stateObj, relativePath, watcherEntry := "") {
    if (relativePath == "*")
        return true
    relativePath := StrReplace(relativePath, "/", "\")
    SplitPath(relativePath, &changedName, , &extension)
    subjectPath := GetMaintenanceSubjectPath(path)
    rootPath := watcherEntry && watcherEntry.HasOwnProp("rootPath")
        ? watcherEntry.rootPath : stateObj.MaintenanceConfig.InstallRoot
    canonicalSubject := GetCanonicalPath(subjectPath)
    canonicalRoot := RTrim(GetCanonicalPath(rootPath), "\")
    subjectRelative := canonicalSubject == canonicalRoot ? ""
        : (InStr(canonicalSubject, canonicalRoot "\") == 1
            ? SubStr(canonicalSubject, StrLen(canonicalRoot) + 2) : "")
    if (subjectRelative != "" && StrLower(relativePath) == StrLower(subjectRelative))
        return true
    SplitPath(subjectPath, &targetName)
    if (!InStr(subjectRelative, "\") && StrLower(changedName) == StrLower(targetName))
        return true
    ; 多个目标共享同一根目录时，只接受各自目标文件变化，避免一个程序升级污染其它目标。
    if (watcherEntry && watcherEntry.subscribers.Count > 1)
        return false
    extension := StrLower(extension)
    return InStr("|exe|com|dll|sys|ocx|cpl|mui|pak|bin|dat|node|asar|jar|",
        "|" extension "|") != 0
}

SerializeMaintenanceSession(path, stateObj) {
    payload := "Path=" EncodeIniField(path)
    payload .= "`nMode=" stateObj.MaintenanceMode
    payload .= "`nStartedAt=" stateObj.MaintenanceStartedAt
    payload .= "`nBaselineFingerprint=" EncodeIniField(stateObj.MaintenanceBaselineFingerprint)
    payload .= "`nFileChanged=" (stateObj.MaintenanceFileChanged ? 1 : 0)
    payload .= "`nExplicit=" (stateObj.ExplicitMaintenance ? 1 : 0)
    return EncodeIniField(payload)
}

DeserializeMaintenanceSession(encodedValue) {
    result := {Path: "", Mode: "", StartedAt: "", BaselineFingerprint: "", FileChanged: false, Explicit: false}
    payload := DecodeIniField(encodedValue)
    Loop Parse, payload, "`n", "`r" {
        separator := InStr(A_LoopField, "=")
        if !separator
            continue
        key := SubStr(A_LoopField, 1, separator - 1)
        value := SubStr(A_LoopField, separator + 1)
        switch key {
            case "Path":
                result.Path := DecodeIniField(value)
            case "Mode":
                result.Mode := value
            case "StartedAt":
                result.StartedAt := value
            case "BaselineFingerprint":
                result.BaselineFingerprint := DecodeIniField(value)
            case "FileChanged":
                result.FileChanged := value == "1"
            case "Explicit":
                result.Explicit := value == "1"
        }
    }
    return result
}

SaveMaintenanceJournal() {
    static isSaving := false
    if isSaving
        return false
    isSaving := true
    tempPath := App.maintenanceJournalPath ".tmp." GetTickCount64() "_" A_ScriptHwnd
    Critical("On")
    try {
        FileAppend("", tempPath, "UTF-16")
        for path, stateObj in App.appStates {
            if IsMaintenanceBlocking(stateObj) && stateObj.MaintenanceMode != "Arbitrating"
                IniWrite(SerializeMaintenanceSession(path, stateObj), tempPath, "Sessions", HashPath(path))
        }
        FileMove(tempPath, App.maintenanceJournalPath, 1)
        return true
    } catch as journalErr {
        try FileDelete(tempPath)
        LogMsg("保存升级保护恢复状态失败: " journalErr.Message)
        return false
    } finally {
        Critical("Off")
        isSaving := false
    }
}

RestoreMaintenanceSessions() {
    if !FileExist(App.maintenanceJournalPath)
        return
    try sessionText := IniRead(App.maintenanceJournalPath, "Sessions")
    catch
        return
    Loop Parse, sessionText, "`n", "`r" {
        separator := InStr(A_LoopField, "=")
        if !separator
            continue
        try session := DeserializeMaintenanceSession(SubStr(A_LoopField, separator + 1))
        catch
            continue
        path := NormalizeTargetPath(session.Path)
        if (path == "" || !App.appStates.Has(path))
            continue
        stateObj := App.appStates[path]
        if !stateObj.Enabled || !IsMaintenanceProtectionEnabled(path, stateObj)
            continue
        stateObj.MaintenanceMode := "Recovering"
        stateObj.Pending := true
        stateObj.TargetStartTicks := 0
        stateObj.MaintenanceStartedAt := session.StartedAt != "" ? session.StartedAt : A_NowUTC
        elapsedSeconds := 0
        try elapsedSeconds := Max(0, DateDiff(A_NowUTC, stateObj.MaintenanceStartedAt, "Seconds"))
        stateObj.MaintenanceStartedTicks := GetTickCount64() - elapsedSeconds * 1000
        stateObj.MaintenanceLastActivityTicks := GetTickCount64()
        stateObj.MaintenanceBaselineFingerprint := session.BaselineFingerprint
        stateObj.MaintenanceFileChanged := session.FileChanged
        stateObj.ExplicitMaintenance := session.Explicit
        if (elapsedSeconds >= stateObj.MaintenanceConfig.MaxWaitSeconds) {
            stateObj.MaintenanceMode := "TimedOut"
            UpdateState(path, "⚠️ 升级等待超时")
        } else {
            UpdateState(path, "🔄 恢复升级保护状态")
        }
        LogMsg("已恢复未完成的升级保护会话: " path)
    }
    SaveMaintenanceJournal()
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
        App.processSnapshotRetryAfterTicks := 0
    } catch {
        snapshotReady := false
        snapshot := []
        App.processSnapshotRetryAfterTicks := GetTickCount64() + 3000
    }
    return snapshot
}

QueryNativeProcessSnapshot(&snapshotReady) {
    snapshotReady := false
    snapshot := []
    snapshotHandle := DllCall("kernel32\CreateToolhelp32Snapshot", "UInt", 0x00000002, "UInt", 0, "Ptr")
    if (snapshotHandle == -1 || !snapshotHandle)
        return snapshot
    try {
        entrySize := A_PtrSize == 8 ? 568 : 556
        parentOffset := A_PtrSize == 8 ? 32 : 24
        nameOffset := A_PtrSize == 8 ? 44 : 36
        entry := Buffer(entrySize, 0)
        NumPut("UInt", entrySize, entry, 0)
        hasEntry := DllCall("kernel32\Process32FirstW", "Ptr", snapshotHandle, "Ptr", entry, "Int")
        while hasEntry {
            pid := NumGet(entry, 8, "UInt")
            parentPid := NumGet(entry, parentOffset, "UInt")
            processName := StrGet(entry.Ptr + nameOffset, 260, "UTF-16")
            if (pid && processName != "")
                snapshot.Push({pid: pid, parent: parentPid, name: processName,
                    cmd: "", exe: "", creation: "", observedTicks: GetTickCount64()})
            NumPut("UInt", entrySize, entry, 0)
            hasEntry := DllCall("kernel32\Process32NextW", "Ptr", snapshotHandle, "Ptr", entry, "Int")
        }
        snapshotReady := true
    } catch {
        snapshotReady := false
        snapshot := []
    } finally {
        DllCall("kernel32\CloseHandle", "Ptr", snapshotHandle)
    }
    return snapshot
}

EnrichNativeMaintenanceProcessPaths(snapshot) {
    learnedPathNames := Map()
    learnedPathNames.CaseSense := "Off"
    targetPids := Map()
    for path, stateObj in App.appStates {
        if !stateObj.Enabled || !IsMaintenanceProtectionEnabled(path, stateObj)
            continue
        if !IsMaintenanceBlocking(stateObj) && !HasRecentMaintenanceSignal(stateObj)
            continue
        targetPid := stateObj.PID ? stateObj.PID : stateObj.LastKnownPID
        if targetPid
            targetPids[targetPid] := true
        for signature in stateObj.MaintenanceConfig.LearnedActors {
            if (SubStr(signature, 1, 2) == "P:") {
                SplitPath(SubStr(signature, 3), &actorName)
                if (actorName != "")
                    learnedPathNames[actorName] := true
            }
        }
    }
    for processInfo in snapshot {
        processInfo.maintenanceCandidate := targetPids.Has(processInfo.parent)
        if (IsInstallerLikeProcess(processInfo)
            || learnedPathNames.Has(processInfo.name))
            processInfo.exe := GetProcessImagePath(processInfo.pid)
    }
}

QueryNativeMaintenanceSnapshot(&snapshotReady) {
    App.maintenanceSnapshotSupportsCommandLine := false
    snapshot := QueryNativeProcessSnapshot(&snapshotReady)
    if !snapshotReady {
        App.maintenanceSnapshotSupportsCommandLine := true
        return QueryProcessSnapshot(&snapshotReady)
    }
    if snapshotReady
        EnrichNativeMaintenanceProcessPaths(snapshot)
    return snapshot
}

BuildProcessSnapshotMap(snapshot) {
    processMap := Map()
    for processInfo in snapshot
        processMap[processInfo.pid] := processInfo
    return processMap
}

IsInstallerLikeProcess(processInfo) {
    nameAndCommand := StrLower(processInfo.name " " processInfo.cmd)
    return RegExMatch(nameAndCommand, "(^|[^a-z])(update|updater|upgrade|patch|patcher|setup|install|installer|msiexec|winget|squirrel|mainten|unins)([^a-z]|$)") != 0
}

ProcessReferencesMaintenanceRoot(processInfo, path, rootPath) {
    for argument in ParseWindowsCommandLine(processInfo.cmd) {
        candidate := Trim(argument, " `t`r`n`"',;()")
        separator := InStr(candidate, "=")
        if (separator > 0 && separator < StrLen(candidate))
            candidate := SubStr(candidate, separator + 1)
        candidate := StrReplace(candidate, "/", "\")
        if !RegExMatch(candidate, "i)^[a-z]:\\|^\\\\")
            continue
        if PathsEquivalent(candidate, path) || PathIsWithinRoot(candidate, rootPath)
            return true
    }
    return false
}

IsProcessDescendantOfTarget(processInfo, stateObj, processMap := "") {
    targetPid := stateObj.PID ? stateObj.PID : stateObj.LastKnownPID
    if !targetPid
        return false
    if (!stateObj.PID && ProcessExist(targetPid)
        && stateObj.HasOwnProp("LastKnownPIDCreationIdentity")
        && stateObj.LastKnownPIDCreationIdentity != "") {
        currentCreation := GetProcessCreationIdentity(targetPid)
        if (currentCreation != "" && currentCreation != stateObj.LastKnownPIDCreationIdentity)
            return false
    }
    parentPid := processInfo.parent
    Loop 16 {
        if !parentPid
            return false
        if (parentPid == targetPid)
            return true
        if (processMap != "" && Type(processMap) == "Map" && processMap.Has(parentPid)) {
            parentPid := processMap[parentPid].parent
            continue
        }
        return false
    }
    return false
}

IsLearnedMaintenanceActor(processInfo, stateObj) {
    processName := StrLower(processInfo.name)
    canonicalExe := processInfo.exe != "" ? GetCanonicalPath(processInfo.exe) : ""
    for signature in stateObj.MaintenanceConfig.LearnedActors {
        if (SubStr(signature, 1, 2) == "P:" && canonicalExe != ""
            && canonicalExe == StrLower(SubStr(signature, 3)))
            return true
        if (SubStr(signature, 1, 2) == "N:" && processName == StrLower(SubStr(signature, 3)))
            return true
    }
    return false
}

IsMaintenanceActorProcess(processInfo, path, stateObj, processMap := "") {
    if !processInfo.pid
        return false
    if (stateObj.PID && processInfo.pid == stateObj.PID)
        return false
    if (processInfo.exe != "" && GetCanonicalPath(processInfo.exe) == GetCanonicalPath(path))
        return false
    if IsLearnedMaintenanceActor(processInfo, stateObj)
        return true
    installerLike := processInfo.HasOwnProp("installerLike")
        ? processInfo.installerLike : IsInstallerLikeProcess(processInfo)
    rootPath := stateObj.MaintenanceConfig.InstallRoot
    underRoot := processInfo.exe != "" && PathIsWithinRoot(processInfo.exe, rootPath)
    referencesRoot := ProcessReferencesMaintenanceRoot(processInfo, path, rootPath)
    descendant := IsProcessDescendantOfTarget(processInfo, stateObj, processMap)
    if (processInfo.HasOwnProp("maintenanceCandidate") && processInfo.maintenanceCandidate
        && IsMaintenanceBlocking(stateObj) && descendant)
        return true
    return installerLike && (underRoot || referencesRoot || descendant)
}

GetLearningSignature(processInfo) {
    processName := StrLower(Trim(processInfo.name))
    if (processName == "")
        return ""
    if (processInfo.exe == "")
        return "N:" processName
    canonicalExe := GetCanonicalPath(processInfo.exe)
    canonicalTemp := GetCanonicalPath(A_Temp)
    if PathIsWithinRoot(canonicalExe, canonicalTemp) || RegExMatch(processName, "\d{3,}")
        return "N:" processName
    return "P:" canonicalExe
}

RecordMaintenanceActor(path, stateObj, processInfo, isNewActor := true) {
    stateObj.KnownActorPids[processInfo.pid] := processInfo
    if !isNewActor
        return
    nowTicks := GetTickCount64()
    stateObj.TransientActorPids[processInfo.pid] := processInfo
    stateObj.LastActorSeenTicks := nowTicks
    if IsMaintenanceBlocking(stateObj) {
        stateObj.MaintenanceLastActivityTicks := nowTicks
    }
    signature := GetLearningSignature(processInfo)
    if (signature != "")
        stateObj.MaintenanceLearningCandidates[signature] := true
    if !TargetAppearsRunning(stateObj) && stateObj.Enabled
        EnterMaintenance(path, stateObj, "检测到相关安装进程")
}

BuildMaintenanceActorCandidates(snapshot) {
    learnedNames := Map()
    learnedNames.CaseSense := "Off"
    learnedPaths := Map()
    learnedPaths.CaseSense := "Off"
    for path, stateObj in App.appStates {
        if !stateObj.Enabled || !IsMaintenanceProtectionEnabled(path, stateObj)
            continue
        for signature in stateObj.MaintenanceConfig.LearnedActors {
            if (SubStr(signature, 1, 2) == "N:")
                learnedNames[SubStr(signature, 3)] := true
            else if (SubStr(signature, 1, 2) == "P:")
                learnedPaths[SubStr(signature, 3)] := true
        }
    }

    candidates := []
    for processInfo in snapshot {
        processInfo.installerLike := IsInstallerLikeProcess(processInfo)
        if (processInfo.installerLike
            || (processInfo.HasOwnProp("maintenanceCandidate") && processInfo.maintenanceCandidate)) {
            candidates.Push(processInfo)
            continue
        }
        if (processInfo.name != "" && learnedNames.Has(processInfo.name)) {
            candidates.Push(processInfo)
            continue
        }
        if (processInfo.exe != "" && learnedPaths.Count
            && learnedPaths.Has(GetCanonicalPath(processInfo.exe)))
            candidates.Push(processInfo)
    }
    return candidates
}

RefreshMaintenanceActors(snapshot, isBaseline := false, supportsCommandLine := true) {
    processMap := BuildProcessSnapshotMap(snapshot)
    actorCandidates := BuildMaintenanceActorCandidates(snapshot)
    snapshotTicks := GetTickCount64()
    if supportsCommandLine {
        App.latestProcessSnapshot := snapshot
        App.latestProcessSnapshotTicks := snapshotTicks
        App.latestProcessSnapshotSupportsCommandLine := true
    } else {
        App.latestNativeProcessSnapshotTicks := snapshotTicks
    }
    for path, stateObj in App.appStates {
        if !stateObj.Enabled || !IsMaintenanceProtectionEnabled(path, stateObj)
            continue
        knownActorPids := stateObj.KnownActorPids
        transientActorPids := stateObj.TransientActorPids
        activeKnown := Map()
        activeTransient := Map()
        for processInfo in actorCandidates {
            if !IsMaintenanceActorProcess(processInfo, path, stateObj, processMap)
                continue
            activeKnown[processInfo.pid] := processInfo
            wasKnown := knownActorPids.Has(processInfo.pid)
            shouldTrack := transientActorPids.Has(processInfo.pid)
                || (!isBaseline && !wasKnown)
                || (stateObj.MaintenanceMode == "Recovering" && !wasKnown)
                || (isBaseline && !wasKnown
                    && WasProcessStartedRecently(processInfo, stateObj.MaintenanceConfig.DetectionSeconds))
            if shouldTrack {
                activeTransient[processInfo.pid] := processInfo
                if !wasKnown
                    RecordMaintenanceActor(path, stateObj, processInfo, true)
            }
        }
        stateObj.KnownActorPids := activeKnown
        stateObj.TransientActorPids := activeTransient
        if (activeTransient.Count && IsMaintenanceBlocking(stateObj)) {
            stateObj.MaintenanceLastActivityTicks := GetTickCount64()
        }
    }
    App.processBaselineReady := true
}

WasProcessStartedRecently(processInfo, maximumAgeSeconds) {
    if (processInfo.creation == "")
        return false
    creationTime := SubStr(processInfo.creation, 1, 14)
    if !RegExMatch(creationTime, "^\d{14}$")
        return false
    try return Abs(DateDiff(A_Now, creationTime, "Seconds")) <= maximumAgeSeconds
    catch
        return false
}

InitializeMaintenanceSubsystem() {
    for path, stateObj in App.appStates
        EnsureMaintenanceWatcher(path, stateObj)
    snapshot := QueryNativeMaintenanceSnapshot(&snapshotReady)
    if snapshotReady {
        for path, stateObj in App.appStates {
            if !stateObj.Enabled || !InStr(path, "\")
                continue
            observedPid := CheckIsRunning(path, &snapshot, false)
            if observedPid
                SetStateProcessIdentity(stateObj, observedPid)
        }
        RefreshMaintenanceActors(snapshot, true)
    } else {
        LogMsg("升级保护初始化时无法建立进程基线，将在下一轮重试。")
    }
    StartProcessSnapshotWorker()
    App.maintenanceInitialized := true
    while App.pendingMaintenanceCommands.Length
        ApplyMaintenanceCommand(App.pendingMaintenanceCommands.RemoveAt(1))
}

CleanupMaintenanceSubsystem(*) {
    SetTimer(MaintenanceEventLoop, 0)
    SetTimer(MaintenanceProcessLoop, 0)
    for _, stateObj in App.appStates
        CloseMaintenanceWatcher(stateObj)
    for _, entry in App.maintenanceWatchers
        try entry.watcher.Close()
    App.maintenanceWatchers.Clear()
    StopProcessSnapshotWorker()
    CleanupServiceManager()
    SaveMaintenanceJournal()
}

MaintenanceProcessLoop() {
    if !App.processBaselineReady
        return
    if App.processLoopBusy
        return
    App.processLoopBusy := true
    loopStartedTicks := GetTickCount64()
    try {
        nowTicks := GetTickCount64()
        if (App.latestProcessSnapshotTicks
            && nowTicks - App.latestProcessSnapshotTicks < App.processSnapshotReuseInterval)
            return
        if (App.latestNativeProcessSnapshotTicks
            && nowTicks - App.latestNativeProcessSnapshotTicks < App.processSnapshotReuseInterval)
            return
        shouldRefreshActors := false
        for path, stateObj in App.appStates {
            maintenanceActive := IsMaintenanceBlocking(stateObj)
                && stateObj.MaintenanceMode != "TimedOut"
            if (stateObj.Enabled && IsMaintenanceProtectionEnabled(path, stateObj)
                && (maintenanceActive || HasRecentMaintenanceSignal(stateObj))) {
                shouldRefreshActors := true
                break
            }
        }
        if !shouldRefreshActors
            return
        if (App.processSnapshotRetryAfterTicks
            && nowTicks < App.processSnapshotRetryAfterTicks)
            return
        PumpProcessSnapshotWorker()
        snapshot := QueryNativeMaintenanceSnapshot(&snapshotReady)
        if snapshotReady {
            RefreshMaintenanceActors(snapshot, false, App.maintenanceSnapshotSupportsCommandLine)
        }
    } finally {
        LogSlowBackgroundOperation("升级进程扫描", loopStartedTicks)
        App.processLoopBusy := false
    }
}

QuoteCommandLineArgument(argument) {
    return '"' String(argument) '"'
}

ProcessMaintenanceCommandClient() {
    if (A_Args.Length < 1)
        return false
    option := StrLower(A_Args[1])
    if (option == "--process-snapshot-worker" && A_Args.Length >= 2) {
        succeeded := WriteProcessSnapshotWorker(A_Args[2])
        ExitApp(succeeded ? 0 : 1)
    }
    if (option == "--send-ctrl-c" && A_Args.Length >= 2) {
        succeeded := SendConsoleCtrlCWorker(Integer(A_Args[2]))
        ExitApp(succeeded ? 0 : 1)
    }
    if (option == "--file-scan-worker" && A_Args.Length >= 6) {
        succeeded := WriteFileScanWorker(A_Args[2], A_Args[3], A_Args[4],
            Integer(A_Args[5]) != 0, Integer(A_Args[6]),
            A_Args.Length >= 7 ? Integer(A_Args[7]) : 15)
        ExitApp(succeeded ? 0 : 1)
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
    App.pendingMaintenanceCommands.Push(command)
    return false
}

WriteProcessSnapshotWorker(outputPath) {
    snapshot := QueryProcessSnapshot(&snapshotReady)
    if !snapshotReady
        return false
    outputText := ""
    for processInfo in snapshot {
        outputText .= processInfo.pid "|" processInfo.parent
        outputText .= "|" EncodeIniField(processInfo.name)
        outputText .= "|" EncodeIniField(processInfo.cmd)
        outputText .= "|" EncodeIniField(processInfo.exe)
        outputText .= "|" EncodeIniField(processInfo.creation) "`r`n"
    }
    tempPath := outputPath ".writing"
    try {
        FileAppend(outputText, tempPath, "UTF-16")
        FileMove(tempPath, outputPath, 1)
        return true
    } catch {
        try FileDelete(tempPath)
        return false
    }
}

IsSupportedMonitorFile(filePath) {
    if !FileExist(filePath) || DirExist(filePath)
        return false
    SplitPath(filePath, &fileName, , &extension, &nameNoExt)
    if !RegExMatch(extension, "i)^(exe|com|msc|ahk|py|pyw|js|vbs|vbe|wsf|ps1|bat|cmd|rb|pl|php|lua|jar|sh|bash|lnk|url|appref-ms)$")
        return false
    if (GetCanonicalPath(filePath) == GetCanonicalPath(A_ScriptFullPath)
        || RegExMatch(fileName, "i)^_codex_.*\.ahk$"))
        return false
    return true
}

AddScannedFile(filePath, deadlineTicks, maximumResults, seen, results) {
    if (GetTickCount64() >= deadlineTicks || results.Length >= maximumResults)
        return false
    if !IsSupportedMonitorFile(filePath)
        return true
    canonicalPath := GetCanonicalPath(filePath)
    if !seen.Has(canonicalPath) {
        seen[canonicalPath] := true
        results.Push(filePath)
    }
    return results.Length < maximumResults
}

ScanDirectoryToDepth(rootPath, depth, deadlineTicks, maximumResults, seen, results) {
    if (depth < 0 || !DirExist(rootPath))
        return true
    try {
        Loop Files, RTrim(rootPath, "\") "\*.*", "FD" {
            if (GetTickCount64() >= deadlineTicks || results.Length >= maximumResults)
                return false
            if InStr(A_LoopFileAttrib, "H") || InStr(A_LoopFileAttrib, "S")
                continue
            if InStr(A_LoopFileAttrib, "D") {
                if (depth > 0 && !ScanDirectoryToDepth(A_LoopFileFullPath, depth - 1,
                    deadlineTicks, maximumResults, seen, results))
                    return false
            } else if !AddScannedFile(A_LoopFileFullPath, deadlineTicks,
                maximumResults, seen, results) {
                return false
            }
        }
    }
    return true
}

ScanDirectoryRecursive(rootPath, deadlineTicks, maximumResults, seen, results) {
    if !DirExist(rootPath)
        return true
    try {
        Loop Files, RTrim(rootPath, "\") "\*.*", "FR" {
            if !AddScannedFile(A_LoopFileFullPath, deadlineTicks, maximumResults,
                seen, results)
                return false
        }
    }
    return GetTickCount64() < deadlineTicks && results.Length < maximumResults
}

WriteFileScanWorker(outputPath, mode, rootPath, recursive, maximumResults, timeoutSeconds) {
    maximumResults := Max(1, Min(maximumResults, 20000))
    deadlineTicks := GetTickCount64() + Max(1, timeoutSeconds) * 1000
    seen := Map()
    seen.CaseSense := "Off"
    results := []
    completed := true
    if (StrLower(mode) == "batch") {
        completed := recursive
            ? ScanDirectoryRecursive(rootPath, deadlineTicks, maximumResults, seen, results)
            : ScanDirectoryToDepth(rootPath, 0, deadlineTicks, maximumResults, seen, results)
    } else {
        for scanPath in [A_Programs, A_ProgramsCommon, A_Desktop, A_DesktopCommon] {
            if !ScanDirectoryRecursive(scanPath, deadlineTicks, maximumResults, seen, results) {
                completed := false
                break
            }
        }
        if completed {
            for scanPath in [EnvGet("ProgramFiles"), EnvGet("ProgramFiles(x86)"), A_MyDocuments] {
                if !ScanDirectoryToDepth(scanPath, 2, deadlineTicks, maximumResults, seen, results) {
                    completed := false
                    break
                }
            }
        }
        if completed {
            Loop Parse, DriveGetList() {
                if !ScanDirectoryToDepth(A_LoopField ":\", 1, deadlineTicks,
                    maximumResults, seen, results) {
                    completed := false
                    break
                }
            }
        }
    }
    outputText := (completed ? "COMPLETE" : "TRUNCATED") "|" results.Length "`r`n"
    for filePath in results
        outputText .= EncodeIniField(filePath) "`r`n"
    tempPath := outputPath ".writing"
    try {
        FileAppend(outputText, tempPath, "UTF-16")
        FileMove(tempPath, outputPath, 1)
        return true
    } catch {
        try FileDelete(tempPath)
        return false
    }
}

StartFileScanWorker(mode, rootPath, recursive, maximumResults, timeoutSeconds) {
    workerPid := 0
    outputPath := A_Temp "\watchdog-scan-" A_ScriptHwnd "-" GetTickCount64() ".tmp"
    workerPrefix := A_IsCompiled
        ? '"' A_ScriptFullPath '"'
        : '"' A_AhkPath '" "' A_ScriptFullPath '"'
    command := workerPrefix ' --file-scan-worker "' outputPath '" "' mode '" "'
        rootPath '" ' (recursive ? 1 : 0) ' ' maximumResults ' ' timeoutSeconds
    try {
        Run(command, A_ScriptDir, "Hide", &workerPid)
        return {Pid: workerPid, Path: outputPath,
            CreationIdentity: GetProcessCreationIdentity(workerPid)}
    } catch as scanErr {
        LogMsg("无法启动后台文件扫描: " scanErr.Message)
        return ""
    }
}

StopFileScanWorker(workerPid, outputPath, creationIdentity := "") {
    if workerPid {
        currentCreation := GetProcessCreationIdentity(workerPid)
        if (creationIdentity == "" || currentCreation == ""
            || currentCreation == creationIdentity) {
            try ProcessClose(workerPid)
            try ProcessWaitClose(workerPid, 1)
        }
    }
    if outputPath {
        try FileDelete(outputPath)
        try FileDelete(outputPath ".writing")
    }
}

ReadFileScanResult(outputPath, &truncated := false) {
    paths := []
    truncated := false
    try resultText := FileRead(outputPath, "UTF-16")
    catch
        return paths
    isHeader := true
    Loop Parse, resultText, "`n", "`r" {
        if isHeader {
            truncated := InStr(A_LoopField, "TRUNCATED|") == 1
            isHeader := false
            continue
        }
        if (A_LoopField != "")
            paths.Push(DecodeIniField(A_LoopField))
    }
    return paths
}

StartProcessSnapshotWorker() {
    PumpProcessSnapshotWorker()
    if App.processSnapshotWorkerPid
        return false
    nowTicks := GetTickCount64()
    if (App.processSnapshotRetryAfterTicks && nowTicks < App.processSnapshotRetryAfterTicks)
        return false
    outputPath := A_Temp "\watchdog-processes-" A_ScriptHwnd "-" nowTicks ".tmp"
    try {
        workerCommand := A_IsCompiled
            ? '"' A_ScriptFullPath '" --process-snapshot-worker "' outputPath '"'
            : '"' A_AhkPath '" "' A_ScriptFullPath '" --process-snapshot-worker "' outputPath '"'
        Run(workerCommand, A_ScriptDir, "Hide", &workerPid)
        App.processSnapshotWorkerPid := workerPid
        App.processSnapshotWorkerCreationIdentity := GetProcessCreationIdentity(workerPid)
        App.processSnapshotWorkerPath := outputPath
        App.processSnapshotWorkerStartedTicks := nowTicks
        App.processSnapshotRequestTicks := nowTicks
        return true
    } catch as workerErr {
        App.processSnapshotRetryAfterTicks := nowTicks + 5000
        LogMsg("无法启动后台进程快照任务: " workerErr.Message)
        return false
    }
}

PumpProcessSnapshotWorker() {
    if !App.processSnapshotWorkerPid
        return false
    outputPath := App.processSnapshotWorkerPath
    if FileExist(outputPath) {
        snapshot := []
        try snapshotText := FileRead(outputPath, "UTF-16")
        catch
            snapshotText := ""
        Loop Parse, snapshotText, "`n", "`r" {
            if (A_LoopField == "")
                continue
            parts := StrSplit(A_LoopField, "|")
            if (parts.Length != 6)
                continue
            try processId := Integer(parts[1])
            catch
                continue
            try parentId := Integer(parts[2])
            catch
                parentId := 0
            snapshot.Push({
                pid: processId, parent: parentId,
                name: DecodeIniField(parts[3]), cmd: DecodeIniField(parts[4]),
                exe: DecodeIniField(parts[5]), creation: DecodeIniField(parts[6]),
                observedTicks: GetTickCount64()
            })
        }
        try FileDelete(outputPath)
        App.processSnapshotWorkerPid := 0
        App.processSnapshotWorkerCreationIdentity := ""
        App.processSnapshotWorkerPath := ""
        App.processSnapshotWorkerStartedTicks := 0
        App.processSnapshotRetryAfterTicks := 0
        App.latestProcessSnapshot := snapshot
        App.latestProcessSnapshotTicks := GetTickCount64()
        App.latestProcessSnapshotSupportsCommandLine := true
        if snapshot.Length
            RefreshMaintenanceActors(snapshot, !App.processBaselineReady, true)
        return true
    }
    if (!ProcessExist(App.processSnapshotWorkerPid)
        || (App.processSnapshotWorkerCreationIdentity != ""
            && GetProcessCreationIdentity(App.processSnapshotWorkerPid)
                != App.processSnapshotWorkerCreationIdentity)) {
        App.processSnapshotWorkerPid := 0
        App.processSnapshotWorkerCreationIdentity := ""
        App.processSnapshotWorkerPath := ""
        App.processSnapshotWorkerStartedTicks := 0
        App.processSnapshotRetryAfterTicks := GetTickCount64() + 3000
        return false
    }
    if (GetTickCount64() - App.processSnapshotWorkerStartedTicks > 30000) {
        StopProcessSnapshotWorker()
        App.processSnapshotRetryAfterTicks := GetTickCount64() + 5000
    }
    return false
}

StopProcessSnapshotWorker(waitForExit := true) {
    if App.processSnapshotWorkerPid {
        currentCreation := GetProcessCreationIdentity(App.processSnapshotWorkerPid)
        if (App.processSnapshotWorkerCreationIdentity == "" || currentCreation == ""
            || currentCreation == App.processSnapshotWorkerCreationIdentity) {
            try ProcessClose(App.processSnapshotWorkerPid)
            if waitForExit
                try ProcessWaitClose(App.processSnapshotWorkerPid, 1)
        }
    }
    if App.processSnapshotWorkerPath {
        try FileDelete(App.processSnapshotWorkerPath)
        try FileDelete(App.processSnapshotWorkerPath ".writing")
    }
    App.processSnapshotWorkerPid := 0
    App.processSnapshotWorkerCreationIdentity := ""
    App.processSnapshotWorkerPath := ""
    App.processSnapshotWorkerStartedTicks := 0
}

GetProcessSnapshotAsync(&snapshotReady, allowStale := true) {
    PumpProcessSnapshotWorker()
    nowTicks := GetTickCount64()
    age := App.latestProcessSnapshotTicks ? nowTicks - App.latestProcessSnapshotTicks : 0
    snapshotReady := App.latestProcessSnapshotTicks
        && age <= (allowStale ? App.processSnapshotMaxAge : App.processSnapshotReuseInterval)
    if (!App.processSnapshotWorkerPid
        && (!App.latestProcessSnapshotTicks || age >= App.processSnapshotReuseInterval))
        StartProcessSnapshotWorker()
    return snapshotReady ? App.latestProcessSnapshot : []
}

RequestFreshProcessSnapshot() {
    PumpProcessSnapshotWorker()
    nowTicks := GetTickCount64()
    ; 同一轮监控中多个目标可能连续退出，复用刚启动的工作进程以避免反复重建。
    if (App.processSnapshotWorkerPid
        && nowTicks - App.processSnapshotWorkerStartedTicks <= 250) {
        requestTicks := App.processSnapshotRequestTicks
            ? App.processSnapshotRequestTicks : App.processSnapshotWorkerStartedTicks
    } else {
        if App.processSnapshotWorkerPid
            StopProcessSnapshotWorker(false)
        App.processSnapshotRetryAfterTicks := 0
        requestTicks := GetTickCount64()
        if StartProcessSnapshotWorker()
            requestTicks := App.processSnapshotRequestTicks
    }
    App.latestProcessSnapshot := []
    App.latestProcessSnapshotTicks := 0
    App.latestProcessSnapshotSupportsCommandLine := true
    App.latestNativeProcessSnapshotTicks := 0
    App.processSnapshotRequestTicks := requestTicks
    return requestTicks
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
    if !App.maintenanceInitialized {
        App.pendingMaintenanceCommands.Push(command)
        return 1
    }
    return ApplyMaintenanceCommand(command) ? 1 : 0
}

ApplyMaintenanceCommand(command) {
    separator := InStr(command, "|")
    if !separator
        return false
    action := SubStr(command, 1, separator - 1)
    path := NormalizeTargetPath(SubStr(command, separator + 1))
    if !App.appStates.Has(path) {
        LogMsg("显式升级维护命令未找到监控目标: " path)
        return false
    }
    if (action == "BEGIN")
        return BeginExplicitMaintenance(path)
    if (action == "END")
        return EndExplicitMaintenance(path)
    return false
}

BeginExplicitMaintenance(path) {
    if !App.appStates.Has(path)
        return false
    stateObj := App.appStates[path]
    if !stateObj.Enabled || !IsMaintenanceProtectionEnabled(path, stateObj) {
        LogMsg("显式升级维护命令被忽略，目标未启用升级保护: " path)
        return false
    }
    if (stateObj.MaintenanceMode == "TimedOut")
        ResetMaintenanceSession(path, stateObj, false)
    stateObj.ExplicitMaintenance := true
    EnterMaintenance(path, stateObj, "收到显式维护开始命令")
    UpdateState(path, "🔄 显式升级维护中")
    SaveMaintenanceJournal()
    return true
}

EndExplicitMaintenance(path) {
    if !App.appStates.Has(path)
        return false
    stateObj := App.appStates[path]
    if !stateObj.ExplicitMaintenance
        return false
    stateObj.ExplicitMaintenance := false
    stateObj.MaintenanceMode := "Stabilizing"
    stateObj.Pending := true
    stateObj.MaintenanceLastActivityTicks := GetTickCount64()
    if !stateObj.MaintenanceStartedTicks {
        stateObj.MaintenanceStartedTicks := GetTickCount64()
        stateObj.MaintenanceStartedAt := A_NowUTC
    }
    UpdateState(path, "⏳ 确认升级文件稳定")
    SaveMaintenanceJournal()
    LogMsg("收到显式维护结束命令，开始执行安全恢复检查: " path)
    return true
}

IsMaintenanceProtectionEnabled(path, stateObj) {
    return IsMaintenanceSupportedTarget(path)
        && stateObj.HasOwnProp("MaintenanceConfig")
        && stateObj.MaintenanceConfig.Enabled
}

IsMaintenanceBlocking(stateObj) {
    return stateObj.HasOwnProp("MaintenanceMode")
        && stateObj.MaintenanceMode != "Normal"
}

TargetAppearsRunning(stateObj) {
    if !stateObj.HasOwnProp("PID") || !stateObj.PID || !ProcessExist(stateObj.PID)
        return false
    if (stateObj.HasOwnProp("PIDCreationIdentity") && stateObj.PIDCreationIdentity != "") {
        currentCreation := GetProcessCreationIdentity(stateObj.PID)
        return currentCreation == "" || currentCreation == stateObj.PIDCreationIdentity
    }
    return true
}

HasActiveMaintenanceActors(stateObj) {
    stalePids := []
    for processId, _ in stateObj.TransientActorPids {
        if !ProcessExist(processId)
            stalePids.Push(processId)
    }
    for processId in stalePids
        stateObj.TransientActorPids.Delete(processId)
    return stateObj.TransientActorPids.Count > 0
}

HasRecentMaintenanceSignal(stateObj) {
    nowTicks := GetTickCount64()
    windowMs := stateObj.MaintenanceConfig.DetectionSeconds * 1000
    return HasActiveMaintenanceActors(stateObj)
        || (stateObj.LastActorSeenTicks && nowTicks - stateObj.LastActorSeenTicks <= windowMs)
        || (stateObj.LastFileActivityTicks && nowTicks - stateObj.LastFileActivityTicks <= windowMs)
}

ResetMaintenanceSession(path, stateObj, saveJournal := true) {
    stateObj.MaintenanceMode := "Normal"
    stateObj.Pending := false
    stateObj.TargetStartTicks := 0
    stateObj.MaintenanceStartedTicks := 0
    stateObj.MaintenanceStartedAt := ""
    stateObj.MaintenanceLastActivityTicks := 0
    stateObj.MaintenanceRestartDueTicks := 0
    stateObj.ArbitrationSnapshotRequestTicks := 0
    stateObj.ArbitrationSignalBaselineTicks := 0
    stateObj.MaintenanceBaselineFingerprint := GetTargetFileFingerprint(path)
    stateObj.MaintenanceFileChanged := false
    stateObj.ExplicitMaintenance := false
    stateObj.TransientActorPids := Map()
    stateObj.LastActorSeenTicks := 0
    stateObj.MaintenanceLearningCandidates := Map()
    if saveJournal
        SaveMaintenanceJournal()
}

CleanupTargetMaintenance(path, stateObj, saveJournal := true) {
    CloseMaintenanceWatcher(stateObj)
    ResetMaintenanceSession(path, stateObj, false)
    if saveJournal
        SaveMaintenanceJournal()
}

RecordFootprintActivity(path, stateObj, relativePath := "") {
    nowTicks := GetTickCount64()
    stateObj.LastFileActivityTicks := nowTicks
    stateObj.SafetyStableSince := 0
    stateObj.MaintenanceLastActivityTicks := nowTicks
    stateObj.MaintenanceFileChanged := true
    stateObj.MaintenanceReadyCheckedTicks := 0
    if (IsMaintenanceBlocking(stateObj) && stateObj.MaintenanceMode != "TimedOut") {
        if (stateObj.MaintenanceMode != "Arbitrating")
            stateObj.MaintenanceMode := "Updating"
    } else if !TargetAppearsRunning(stateObj) && stateObj.Enabled {
        if TargetReferenceExists(path, stateObj)
            EnterMaintenance(path, stateObj, relativePath == "" ? "检测到程序文件变化" : "检测到安装目录变化")
        else
            BeginMaintenanceArbitration(path, stateObj)
    }
}

BeginMaintenanceArbitration(path, stateObj) {
    if !IsMaintenanceProtectionEnabled(path, stateObj)
        return false
    if IsMaintenanceBlocking(stateObj)
        return true
    targetExists := TargetReferenceExists(path, stateObj)
    if HasActiveMaintenanceActors(stateObj)
        || (targetExists && HasRecentMaintenanceSignal(stateObj)) {
        EnterMaintenance(path, stateObj, "目标退出时检测到升级信号")
        return true
    }
    nowTicks := GetTickCount64()
    CancelTargetTimers(stateObj)
    stateObj.MaintenanceMode := "Arbitrating"
    stateObj.Pending := true
    stateObj.TargetStartTicks := 0
    stateObj.MaintenanceStartedTicks := nowTicks
    stateObj.MaintenanceStartedAt := A_NowUTC
    stateObj.MaintenanceLastActivityTicks := nowTicks
    stateObj.MaintenanceRestartDueTicks := nowTicks + App.retryDelayArray[1]
    stateObj.MaintenanceBaselineFingerprint := GetTargetFileFingerprint(path)
    stateObj.MaintenanceFileChanged := false
    stateObj.ArbitrationSignalBaselineTicks := Max(stateObj.LastActorSeenTicks,
        stateObj.LastFileActivityTicks)
    snapshotRequestTicks := RequestFreshProcessSnapshot()
    ; Pump 快照时可能已捕获更新程序并切换到升级保护，不能再覆盖其状态。
    if (stateObj.MaintenanceMode != "Arbitrating")
        return true
    stateObj.ArbitrationSnapshotRequestTicks := snapshotRequestTicks
    UpdateState(path, "⏳ 判断是否正在升级")
    SaveMaintenanceJournal()
    return true
}

MarkTargetMissing(path, stateObj, statusText) {
    wasBlocking := IsMaintenanceBlocking(stateObj)
    firstMissingObservation := !stateObj.MissingSinceTicks
    if (firstMissingObservation || wasBlocking)
        CancelTargetTimers(stateObj)
    if wasBlocking
        ResetMaintenanceSession(path, stateObj, false)
    stateObj.Pending := false
    stateObj.TargetStartTicks := 0
    ClearStateProcessIdentity(stateObj)
    if firstMissingObservation
        stateObj.MissingSinceTicks := GetTickCount64()
    if (stateObj.State != statusText) {
        UpdateState(path, statusText)
        LogMsg("监测到目标文件已不存在，守护进入缺失状态，文件恢复后将自动复核: " path)
    }
    if (firstMissingObservation || wasBlocking)
        SaveMaintenanceJournal()
}

ClearTargetMissingState(path, stateObj) {
    if !stateObj.MissingSinceTicks
        return false
    stateObj.MissingSinceTicks := 0
    stateObj.SafetyFingerprint := GetTargetFileFingerprint(path)
    stateObj.SafetyStableSince := GetTickCount64()
    stateObj.MaintenanceFingerprintCheckedTicks := 0
    stateObj.MaintenanceReadyCheckedTicks := 0
    UpdateState(path, "初始化...")
    LogMsg("目标文件已恢复，重新核对运行状态: " path)
    return true
}

EnterMaintenance(path, stateObj, reason := "") {
    if !stateObj.Enabled || !IsMaintenanceProtectionEnabled(path, stateObj)
        return false
    if (stateObj.MaintenanceMode == "TimedOut")
        return true
    nowTicks := GetTickCount64()
    firstEntry := !IsMaintenanceBlocking(stateObj) || stateObj.MaintenanceMode == "Arbitrating"
    if firstEntry {
        CancelTargetTimers(stateObj)
        stateObj.MaintenanceMode := "Updating"
        stateObj.Pending := true
        stateObj.TargetStartTicks := 0
        stateObj.ArbitrationSnapshotRequestTicks := 0
        stateObj.ArbitrationSignalBaselineTicks := 0
        stateObj.MaintenanceStartedTicks := nowTicks
        stateObj.MaintenanceStartedAt := A_NowUTC
        if !stateObj.MaintenanceFileChanged
            stateObj.MaintenanceBaselineFingerprint := GetTargetFileFingerprint(path)
        LogMsg("已进入软件升级保护: " path (reason != "" ? "（" reason "）" : ""))
    }
    stateObj.MaintenanceLastActivityTicks := nowTicks
    stateObj.MaintenanceMode := "Updating"
    stateObj.Pending := true
    UpdateState(path, "🔄 软件升级中")
    if firstEntry
        SaveMaintenanceJournal()
    return true
}

LearnMaintenanceActors(path, stateObj) {
    if !stateObj.MaintenanceFileChanged || !stateObj.MaintenanceLearningCandidates.Count
        return false
    known := Map()
    known.CaseSense := "Off"
    for signature in stateObj.MaintenanceConfig.LearnedActors
        known[signature] := true
    changed := false
    for signature in stateObj.MaintenanceLearningCandidates {
        if !known.Has(signature) {
            stateObj.MaintenanceConfig.LearnedActors.Push(signature)
            known[signature] := true
            changed := true
        }
    }
    if changed
        LogMsg("已从本次升级过程学习更新程序特征: " path)
    return changed
}

CompleteMaintenance(path, stateObj) {
    learnedChanged := LearnMaintenanceActors(path, stateObj)
    identityChanged := RefreshShortcutIdentity(path, stateObj, true)
    currentFingerprint := GetTargetFileFingerprint(path)
    stableMs := stateObj.MaintenanceConfig.StableSeconds * 1000
    stateObj.SafetyFingerprint := currentFingerprint
    stateObj.SafetyStableSince := GetTickCount64() - stableMs
    ResetMaintenanceSession(path, stateObj, false)
    SaveMaintenanceJournal()
    if (learnedChanged || identityChanged)
        SaveAppsToIni()
    App.wmiError := false
    runningPid := CheckIsRunning(path)
    if runningPid {
        SetStateProcessIdentity(stateObj, runningPid)
        stateObj.FailCount := 0
        UpdateState(path, "✅ 运行中")
        LogMsg("软件升级完成，已恢复正常守护: " path)
        return
    }
    if App.wmiError {
        stateObj.Pending := true
        UpdateState(path, "⏳ 等待进程状态...")
        ScheduleRestart(path, 2000)
        return
    }
    UpdateState(path, "⏳ 升级完成，准备恢复")
    ScheduleRestart(path, 200)
    LogMsg("软件升级完成，准备恢复启动: " path)
}

MarkMaintenanceTimedOut(path, stateObj) {
    CancelTargetTimers(stateObj)
    stateObj.MaintenanceMode := "TimedOut"
    stateObj.Pending := true
    stateObj.TargetStartTicks := 0
    UpdateState(path, "⚠️ 升级等待超时")
    SaveMaintenanceJournal()
    LogMsg("软件升级保护超过最长等待时间，需要用户确认后恢复: " path)
}

AdvanceMaintenanceState(path, stateObj) {
    mode := stateObj.MaintenanceMode
    if (mode == "Normal" || mode == "TimedOut")
        return
    if !stateObj.Enabled || !IsMaintenanceProtectionEnabled(path, stateObj) {
        ResetMaintenanceSession(path, stateObj)
        return
    }
    nowTicks := GetTickCount64()
    if (mode == "Arbitrating") {
        if TargetAppearsRunning(stateObj) {
            ResetMaintenanceSession(path, stateObj)
            UpdateState(path, "✅ 运行中")
            return
        }
        targetExists := TargetReferenceExists(path, stateObj)
        arbitrationBaseline := stateObj.ArbitrationSignalBaselineTicks
        hasNewSignal := (stateObj.LastActorSeenTicks
                && stateObj.LastActorSeenTicks > arbitrationBaseline)
            || (stateObj.LastFileActivityTicks
                && stateObj.LastFileActivityTicks > arbitrationBaseline)
        if HasActiveMaintenanceActors(stateObj)
            || hasNewSignal {
            EnterMaintenance(path, stateObj, "仲裁期间捕获到升级活动")
            return
        }
        elapsedMs := nowTicks - stateObj.MaintenanceStartedTicks
        detectionMs := stateObj.MaintenanceConfig.DetectionSeconds * 1000
        fastDecisionMs := Min(2000, detectionMs)
        fallbackDecisionMs := Min(3500, detectionMs)
        freshSnapshotReady := stateObj.ArbitrationSnapshotRequestTicks
            && App.latestProcessSnapshotTicks >= stateObj.ArbitrationSnapshotRequestTicks
        if ((freshSnapshotReady && elapsedMs >= fastDecisionMs)
            || elapsedMs >= fallbackDecisionMs) {
            elapsedSeconds := Format("{:.1f}", elapsedMs / 1000)
            decisionNote := freshSnapshotReady
                ? "后台进程快照已确认"
                : "后台进程快照未及时返回，已使用快速兜底"
            if !targetExists {
                SplitPath(path, , , &missingExtension)
                missingStatus := RegExMatch(missingExtension,
                    "i)^(ahk|py|pyw|js|vbs|vbe|wsf|ps1|bat|cmd|rb|pl|php|lua|jar|sh|bash)$")
                    ? "❌ 脚本不存在" : "❌ 程序不存在"
                LogMsg("未发现升级活动（" decisionNote "，耗时 " elapsedSeconds " 秒），目标仍不存在: " path)
                MarkTargetMissing(path, stateObj, missingStatus)
                return
            }
            remainingDelay := Max(100, stateObj.MaintenanceRestartDueTicks - nowTicks)
            ResetMaintenanceSession(path, stateObj, false)
            SaveMaintenanceJournal()
            LogMsg("未发现升级活动（" decisionNote "，耗时 " elapsedSeconds " 秒），恢复普通重启流程: " path)
            ScheduleRestart(path, remainingDelay)
        }
        return
    }
    if (nowTicks - stateObj.MaintenanceStartedTicks >= stateObj.MaintenanceConfig.MaxWaitSeconds * 1000) {
        MarkMaintenanceTimedOut(path, stateObj)
        return
    }
    if stateObj.ExplicitMaintenance {
        stateObj.MaintenanceLastActivityTicks := nowTicks
        stateObj.MaintenanceMode := "Updating"
        UpdateState(path, "🔄 显式升级维护中")
        return
    }
    if RefreshShortcutIdentity(path, stateObj) {
        stateObj.MaintenanceReadyCheckedTicks := 0
        SaveAppsToIni()
    }
    activeActors := HasActiveMaintenanceActors(stateObj)
    if (!stateObj.MaintenanceReadyCheckedTicks
        || nowTicks - stateObj.MaintenanceReadyCheckedTicks >= 1000) {
        stateObj.MaintenanceLastReady := IsTargetFileReady(path)
        stateObj.MaintenanceReadyCheckedTicks := nowTicks
    }
    fileReady := stateObj.MaintenanceLastReady
    quietMs := nowTicks - Max(stateObj.MaintenanceLastActivityTicks, stateObj.LastFileActivityTicks)
    stableMs := stateObj.MaintenanceConfig.StableSeconds * 1000
    if activeActors {
        stateObj.MaintenanceLastActivityTicks := nowTicks
        stateObj.MaintenanceMode := "Updating"
        UpdateState(path, "🔄 软件升级中")
        return
    }
    if !fileReady {
        stateObj.MaintenanceMode := "Updating"
        UpdateState(path, FileExist(path) ? "🔄 等待程序文件可用" : "🔄 等待程序文件恢复")
        return
    }
    if (quietMs < stableMs) {
        stateObj.MaintenanceMode := "Stabilizing"
        remaining := Max(1, Ceil((stableMs - quietMs) / 1000))
        UpdateState(path, "⏳ 确认升级文件稳定 " remaining "s")
        return
    }
    CompleteMaintenance(path, stateObj)
}

CanSafelyLaunch(path, stateObj, &reason := "") {
    reason := ""
    if !IsMaintenanceProtectionEnabled(path, stateObj)
        return true
    if IsMaintenanceBlocking(stateObj) {
        reason := stateObj.MaintenanceMode == "TimedOut" ? "升级等待已超时" : "升级保护仍在进行"
        return false
    }
    if HasActiveMaintenanceActors(stateObj) {
        reason := "检测到相关安装进程"
        EnterMaintenance(path, stateObj, reason)
        return false
    }
    maintenanceSubject := GetMaintenanceSubjectPath(path)
    if !FileExist(maintenanceSubject) {
        reason := "目标程序文件不存在"
        return false
    }
    currentFingerprint := GetTargetFileFingerprint(path)
    nowTicks := GetTickCount64()
    if (currentFingerprint != stateObj.SafetyFingerprint) {
        stateObj.SafetyFingerprint := currentFingerprint
        stateObj.SafetyStableSince := nowTicks
        RecordFootprintActivity(path, stateObj)
        reason := "程序文件刚刚发生变化"
        EnterMaintenance(path, stateObj, reason)
        return false
    }
    stableMs := stateObj.MaintenanceConfig.StableSeconds * 1000
    if !stateObj.SafetyStableSince
        stateObj.SafetyStableSince := nowTicks
    if (nowTicks - stateObj.SafetyStableSince < stableMs
        || (stateObj.LastFileActivityTicks && nowTicks - stateObj.LastFileActivityTicks < stableMs)) {
        reason := "程序文件尚未达到稳定等待时间"
        EnterMaintenance(path, stateObj, reason)
        return false
    }
    if !IsTargetFileReady(path) {
        reason := "程序文件正在写入或结构不完整"
        EnterMaintenance(path, stateObj, reason)
        return false
    }
    return true
}

MaintenanceEventLoop() {
    if App.maintenanceLoopBusy
        return
    App.maintenanceLoopBusy := true
    loopStartedTicks := GetTickCount64()
    try {
        nowTicks := GetTickCount64()
        ; 每个规范化根目录只轮询一次，再按订阅目标分发变化。
        staleRoots := []
        for rootKey, entry in App.maintenanceWatchers {
            if !entry.subscribers.Count {
                staleRoots.Push(rootKey)
                continue
            }
            if !entry.watcher.Active
                try entry.watcher.Open()
            if !entry.watcher.Active
                continue
            changes := entry.watcher.Poll()
            for change in changes {
                for path, stateObj in entry.subscribers {
                    if (App.appStates.Has(path) && App.appStates[path] == stateObj
                        && stateObj.Enabled && IsMaintenanceProtectionEnabled(path, stateObj)
                        && IsRelevantFootprintChange(path, stateObj, change.RelativePath, entry))
                        RecordFootprintActivity(path, stateObj, change.RelativePath)
                }
            }
        }
        for rootKey in staleRoots {
            if App.maintenanceWatchers.Has(rootKey) {
                try App.maintenanceWatchers[rootKey].watcher.Close()
                App.maintenanceWatchers.Delete(rootKey)
            }
        }
        normalFingerprintChecks := 0
        normalFingerprintBudget := Max(1,
            Ceil(App.appStates.Count * App.maintenancePollInterval
                / App.maintenanceFingerprintRetryInterval))
        for path, stateObj in App.appStates {
            if !stateObj.Enabled || !IsMaintenanceProtectionEnabled(path, stateObj) {
                CloseMaintenanceWatcher(stateObj)
                continue
            }
            EnsureMaintenanceWatcher(path, stateObj)
            watcherActive := stateObj.MaintenanceWatcherRoot != ""
                && App.maintenanceWatchers.Has(stateObj.MaintenanceWatcherRoot)
                && App.maintenanceWatchers[stateObj.MaintenanceWatcherRoot].watcher.Active
            fingerprintInterval := stateObj.MaintenanceMode == "Normal"
                ? (watcherActive
                    ? App.maintenanceFingerprintInterval
                    : App.maintenanceFingerprintRetryInterval)
                : 1000
            shouldCheckFingerprint := stateObj.MaintenanceMode != "TimedOut"
                && (!stateObj.MaintenanceFingerprintCheckedTicks
                    || nowTicks - stateObj.MaintenanceFingerprintCheckedTicks >= fingerprintInterval)
            if (shouldCheckFingerprint && stateObj.MaintenanceMode == "Normal") {
                if (normalFingerprintChecks >= normalFingerprintBudget)
                    shouldCheckFingerprint := false
                else
                    normalFingerprintChecks++
            }
            fingerprint := stateObj.SafetyFingerprint
            if shouldCheckFingerprint {
                fingerprint := GetTargetFileFingerprint(path)
                stateObj.MaintenanceFingerprintCheckedTicks := nowTicks
                if (fingerprint != stateObj.SafetyFingerprint) {
                    priorFingerprint := stateObj.SafetyFingerprint
                    stateObj.SafetyFingerprint := fingerprint
                    stateObj.SafetyStableSince := nowTicks
                    stateObj.MaintenanceReadyCheckedTicks := 0
                    if (priorFingerprint != "")
                        RecordFootprintActivity(path, stateObj)
                } else if !stateObj.SafetyStableSince {
                    stateObj.SafetyStableSince := nowTicks
                }
                if (stateObj.MaintenanceMode == "Normal"
                    && nowTicks - stateObj.SafetyStableSince >= stateObj.MaintenanceConfig.StableSeconds * 1000) {
                    stateObj.MaintenanceBaselineFingerprint := fingerprint
                    detectionMs := stateObj.MaintenanceConfig.DetectionSeconds * 1000
                    if ((!stateObj.LastFileActivityTicks || nowTicks - stateObj.LastFileActivityTicks > detectionMs)
                        && (!stateObj.LastActorSeenTicks || nowTicks - stateObj.LastActorSeenTicks > detectionMs)) {
                        stateObj.MaintenanceFileChanged := false
                        stateObj.MaintenanceLearningCandidates := Map()
                    }
                }
            }
            AdvanceMaintenanceState(path, stateObj)
        }
    } finally {
        LogSlowBackgroundOperation("升级文件监听", loopStartedTicks)
        App.maintenanceLoopBusy := false
    }
}

GetProcessImagePath(pid) {
    if !pid
        return ""
    processHandle := DllCall("kernel32\OpenProcess", "UInt", 0x1000,
        "Int", false, "UInt", pid, "Ptr") ; PROCESS_QUERY_LIMITED_INFORMATION
    if !processHandle
        return ""
    try {
        pathBuffer := Buffer(32768 * 2, 0)
        characterCount := 32767
        if DllCall("kernel32\QueryFullProcessImageNameW", "Ptr", processHandle,
            "UInt", 0, "Ptr", pathBuffer, "UInt*", &characterCount, "Int")
            return StrGet(pathBuffer, characterCount, "UTF-16")
    } finally {
        DllCall("kernel32\CloseHandle", "Ptr", processHandle)
    }
    return ""
}

GetProcessCreationIdentity(pid) {
    if !pid
        return ""
    processHandle := DllCall("kernel32\OpenProcess", "UInt", 0x1000,
        "Int", false, "UInt", pid, "Ptr")
    if !processHandle
        return ""
    try {
        creationTime := Buffer(8, 0)
        exitTime := Buffer(8, 0)
        kernelTime := Buffer(8, 0)
        userTime := Buffer(8, 0)
        if DllCall("kernel32\GetProcessTimes", "Ptr", processHandle,
            "Ptr", creationTime, "Ptr", exitTime, "Ptr", kernelTime, "Ptr", userTime, "Int")
            return Format("{:016X}", NumGet(creationTime, 0, "UInt64"))
    } finally {
        DllCall("kernel32\CloseHandle", "Ptr", processHandle)
    }
    return ""
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
}

SetStateProcessIdentity(stateObj, pid) {
    pid := pid ? Integer(pid) : 0
    if !pid {
        ClearStateProcessIdentity(stateObj)
        return false
    }
    if (stateObj.PID == pid && stateObj.HasOwnProp("PIDCreationIdentity")
        && stateObj.PIDCreationIdentity != "" && ProcessExist(pid))
        return true
    stateObj.PID := pid
    stateObj.LastKnownPID := pid
    stateObj.PIDCreationIdentity := GetProcessCreationIdentity(pid)
    stateObj.PIDImagePath := GetProcessImagePath(pid)
    stateObj.LastKnownPIDCreationIdentity := stateObj.PIDCreationIdentity
    return true
}

DoesProcessMatchTarget(pid, targetPath, stateObj := "") {
    if !pid || !ProcessExist(pid)
        return false
    if stateObj && stateObj.HasOwnProp("PIDCreationIdentity")
        && stateObj.PIDCreationIdentity != "" {
        currentCreation := GetProcessCreationIdentity(pid)
        if (currentCreation != "" && currentCreation != stateObj.PIDCreationIdentity)
            return false
    }
    if !InStr(targetPath, "\")
        return true
    SplitPath(targetPath, , , &extension)
    extension := StrLower(extension)
    if (extension == "lnk") {
        effectiveTarget := GetMonitoredTargetPath(targetPath)
        if (effectiveTarget == "")
            return true
        targetPath := effectiveTarget
        SplitPath(targetPath, , , &extension)
        extension := StrLower(extension)
    }
    if (extension != "exe" && extension != "com")
        return true
    imagePath := GetProcessImagePath(pid)
    if (imagePath == "" && stateObj && stateObj.HasOwnProp("PIDImagePath"))
        imagePath := stateObj.PIDImagePath
    ; 访问受限且没有任何已知镜像路径时保留同一创建身份，避免把查询失败误判为停止。
    return imagePath == "" || PathsEquivalent(imagePath, targetPath)
}

StateProcessIdentityIsValid(path, stateObj) {
    return stateObj && stateObj.PID
        && DoesProcessMatchTarget(stateObj.PID, path, stateObj)
}

FindProcessByWorkingDirectory(workingDir, wmiCacheList := "", preferredName := "") {
    if (workingDir == "")
        return 0
    preferredName := StrLower(preferredName)
    uniqueCandidatePid := 0
    matchingCount := 0
    if (wmiCacheList != "" && Type(wmiCacheList) == "VarRef") {
        processes := %wmiCacheList%
        for processInfo in processes {
            if (processInfo.exe == "" || !PathIsWithinRoot(processInfo.exe, workingDir))
                continue
            if (preferredName != "" && StrLower(processInfo.name) == preferredName)
                return processInfo.pid
            uniqueCandidatePid := processInfo.pid
            matchingCount++
        }
        return preferredName == "" && matchingCount == 1 ? uniqueCandidatePid : 0
    }
    processes := GetProcessSnapshotAsync(&snapshotReady)
    if !snapshotReady {
        App.wmiError := true
        return 0
    }
    for processInfo in processes {
        if (processInfo.exe == "" || !PathIsWithinRoot(processInfo.exe, workingDir))
            continue
        if (preferredName != "" && StrLower(processInfo.name) == preferredName)
            return processInfo.pid
        uniqueCandidatePid := processInfo.pid
        matchingCount++
    }
    return preferredName == "" && matchingCount == 1 ? uniqueCandidatePid : 0
}

FindProcessByImagePath(targetPath, wmiCacheList := "") {
    wanted := GetCanonicalPath(targetPath)
    if (wmiCacheList != "" && Type(wmiCacheList) == "VarRef") {
        processes := %wmiCacheList%
        for process in processes
            if (process.exe != "" && GetCanonicalPath(process.exe) == wanted)
                return process.pid
        return 0
    }
    snapshot := QueryNativeProcessSnapshot(&snapshotReady)
    if snapshotReady {
        for processInfo in snapshot {
            imagePath := GetProcessImagePath(processInfo.pid)
            if (imagePath != "" && GetCanonicalPath(imagePath) == wanted)
                return processInfo.pid
        }
        return 0
    }
    App.wmiError := true
    return 0
}

ProcessMatchesTarget(pid, targetPath, wmiCacheList := "") {
    if (SubStr(targetPath, 1, 8) == "Service:")
        return false
    SplitPath(targetPath, , , &extension)
    extension := StrLower(extension)
    if (extension == "lnk") {
        effectiveTarget := GetMonitoredTargetPath(targetPath)
        if (effectiveTarget != "")
            return ProcessMatchesTarget(pid, effectiveTarget, wmiCacheList)
        shortcutName := ""
        SplitPath(targetPath, , , , &shortcutName)
        workingDir := GetShortcutWorkingDirectory(targetPath)
        return FindProcessByWorkingDirectory(workingDir, wmiCacheList,
            shortcutName != "" ? shortcutName ".exe" : "") == pid
    }
    if (extension == "exe" || extension == "com")
        return FindProcessByImagePath(targetPath, wmiCacheList) == pid
    return FindProcessByCommandLine(targetPath, wmiCacheList) == pid
}

ParseWindowsCommandLine(commandLine) {
    arguments := []
    if (Trim(commandLine) == "")
        return arguments
    argumentCount := 0
    argumentVector := DllCall("shell32\CommandLineToArgvW", "WStr", commandLine,
        "Int*", &argumentCount, "Ptr")
    if !argumentVector
        return arguments
    try {
        Loop argumentCount {
            argumentPointer := NumGet(argumentVector, (A_Index - 1) * A_PtrSize, "Ptr")
            arguments.Push(argumentPointer ? StrGet(argumentPointer, "UTF-16") : "")
        }
    } finally {
        DllCall("kernel32\LocalFree", "Ptr", argumentVector, "Ptr")
    }
    return arguments
}

CommandTokenMatchesTarget(token, targetPath) {
    token := Trim(String(token), " `t`r`n`"")
    if (token == "")
        return false
    ; 支持 --file=C:\app\target.py、-File:C:\app\target.ps1 等参数形式。
    separator := InStr(token, "=")
    colon := InStr(token, ":")
    if (separator > 0 && separator < StrLen(token))
        token := SubStr(token, separator + 1)
    else if (SubStr(token, 1, 1) == "-" && colon > 1 && colon < StrLen(token))
        token := SubStr(token, colon + 1)
    token := Trim(token, " `t`r`n`"',;()")
    token := StrReplace(token, "/", "\")
    if RegExMatch(token, "i)^[a-z]:\\|^\\\\")
        return PathsEquivalent(token, targetPath)
    SplitPath(token, &tokenName)
    SplitPath(targetPath, &targetName)
    ; 相对脚本路径只能在已识别的解释器参数位使用；此处要求完整文件名一致。
    return tokenName != "" && StrLower(tokenName) == StrLower(targetName)
}

CommandLineContainsTarget(commandLine, targetPath) {
    arguments := ParseWindowsCommandLine(commandLine)
    if (arguments.Length < 2)
        return false
    SplitPath(arguments[1], &launcherName)
    launcherName := StrLower(launcherName)

    if RegExMatch(launcherName, "i)^powershell(?:_ise)?\.exe$|^pwsh\.exe$") {
        for index, argument in arguments {
            if (index > 1 && RegExMatch(argument, "i)^-(file|f)$"))
                return (index < arguments.Length
                    && CommandTokenMatchesTarget(arguments[index + 1], targetPath))
        }
        return false
    }
    if RegExMatch(launcherName, "i)^javaw?\.exe$") {
        for index, argument in arguments {
            if (index > 1 && StrLower(argument) == "-jar")
                return (index < arguments.Length
                    && CommandTokenMatchesTarget(arguments[index + 1], targetPath))
        }
        return false
    }
    if RegExMatch(launcherName, "i)^cmd\.exe$") {
        for index, argument in arguments {
            if (index > 1 && RegExMatch(argument, "i)^/[ck]$")) {
                Loop arguments.Length - index {
                    if CommandTokenMatchesTarget(arguments[index + A_Index], targetPath)
                        return true
                }
                return false
            }
        }
        return false
    }
    if !RegExMatch(launcherName,
        "i)^(autohotkey.*|pythonw?|node|wscript|cscript|ruby|perl|php|lua|bash|sh)\.exe$")
        return false

    for index, argument in arguments {
        if (index == 1 || argument == "" || SubStr(argument, 1, 1) == "-"
            || SubStr(argument, 1, 1) == "/")
            continue
        if CommandTokenMatchesTarget(argument, targetPath)
            return true
        SplitPath(argument, , , &argumentExtension)
        if RegExMatch(argumentExtension,
            "i)^(msc|ahk|py|pyw|js|vbs|vbe|wsf|ps1|bat|cmd|rb|pl|php|lua|jar|sh|bash)$")
            return false
    }
    return false
}

FindProcessByCommandLine(targetPath, wmiCacheList := "") {
    if (wmiCacheList != "" && Type(wmiCacheList) == "VarRef") {
        processes := %wmiCacheList%
        for item in processes
            if CommandLineContainsTarget(item.cmd, targetPath)
                return item.pid
        return 0
    }
    processes := GetProcessSnapshotAsync(&snapshotReady)
    if !snapshotReady {
        App.wmiError := true
        return 0
    }
    for processInfo in processes
        if CommandLineContainsTarget(processInfo.cmd, targetPath)
            return processInfo.pid
    return 0
}

IsOneShotTarget(path, resolvedTarget := "") {
    SplitPath(path, , , &extension)
    extension := StrLower(extension)
    if (extension == "url" || extension == "appref-ms")
        return true
    if (extension != "lnk" || resolvedTarget != "")
        return false
    targetPath := ""
    arguments := ""
    return ReadShortcutData(path, &targetPath, , &arguments)
        && arguments != "" && IsGenericLauncherTarget(targetPath)
}

CancelTargetTimers(stateObj) {
    if !stateObj
        return
    if (stateObj.HasOwnProp("RestartTimer") && stateObj.RestartTimer) {
        SetTimer(stateObj.RestartTimer, 0)
        stateObj.RestartTimer := 0
    }
    if (stateObj.HasOwnProp("VerifyTimer") && stateObj.VerifyTimer) {
        SetTimer(stateObj.VerifyTimer, 0)
        stateObj.VerifyTimer := 0
    }
    if stateObj.HasOwnProp("Generation")
        stateObj.Generation++
}

ScheduleRestart(path, delayMs) {
    path := NormalizeTargetPath(path)
    if !App.appStates.Has(path)
        return
    stateObj := App.appStates[path]
    if IsMaintenanceBlocking(stateObj) {
        stateObj.Pending := true
        stateObj.TargetStartTicks := 0
        return
    }
    CancelTargetTimers(stateObj)
    stateObj.Pending := true
    stateObj.TargetStartTicks := GetTickCount64() + delayMs
    generation := stateObj.Generation
    timer := DoRestart.Bind(path, generation)
    stateObj.RestartTimer := timer
    SetTimer(timer, -delayMs)
}

ScheduleVerify(path, delayMs) {
    path := NormalizeTargetPath(path)
    if !App.appStates.Has(path)
        return
    stateObj := App.appStates[path]
    if IsMaintenanceBlocking(stateObj) {
        stateObj.Pending := true
        stateObj.TargetStartTicks := 0
        return
    }
    if (stateObj.HasOwnProp("VerifyTimer") && stateObj.VerifyTimer)
        SetTimer(stateObj.VerifyTimer, 0)
    generation := stateObj.Generation
    timer := VerifyStart.Bind(path, generation)
    stateObj.VerifyTimer := timer
    SetTimer(timer, -delayMs)
}

RegisterApp(path, enabled := 1, runAsAdmin := 0, workingDirectory := "", arguments := "", environment := "", maintenanceConfig := "", storedResolvedTarget := "", resolvedTargetManual := false, shortcutArguments := "") {
    path := NormalizeTargetPath(path)
    if (path == "")
        return false
    if (SubStr(path, 1, 8) == "Service:" && Trim(SubStr(path, 9)) == "")
        return false
    ; 目录仅用于批量导入，不能作为可启动/可探活的单个目标。
    if (SubStr(path, 1, 8) != "Service:" && DirExist(path))
        return false
    if App.appStates.Has(path)
        return false
    resolvedTarget := ""
    resolutionSource := ""
    SplitPath(path, , , &pathExtension)
    if (StrLower(pathExtension) == "lnk")
        resolvedTarget := ResolveShortcutTargetForState(path, storedResolvedTarget,
            &resolutionSource, resolvedTargetManual)
    if (StrLower(pathExtension) == "lnk" && FileExist(path)) {
        shortcutTarget := "", shortcutWorkingDirectory := "", currentShortcutArguments := ""
        if ReadShortcutData(path, &shortcutTarget, &shortcutWorkingDirectory, &currentShortcutArguments) {
            if (shortcutArguments == "")
                shortcutArguments := currentShortcutArguments
            if (workingDirectory == "")
                workingDirectory := shortcutWorkingDirectory
        }
    }
    identityTarget := resolvedTarget != "" ? resolvedTarget
        : (IsPotentialShortcutProcessTarget(path) ? path : "")
    if FindIdentityConflict(identityTarget)
        return false
    normalizedMaintenance := NormalizeMaintenanceConfig(maintenanceConfig, path)
    if (StrLower(pathExtension) == "lnk" && resolvedTarget != "") {
        requestedMaintenance := true
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
    currentFingerprint := GetTargetFileFingerprint(fingerprintTarget)
    App.appStates[path] := {
        State: "初始化...", FailCount: 0, Pending: false, Enabled: enabled ? 1 : 0,
        TargetStartTicks: 0, RunAsAdmin: runAsAdmin ? 1 : 0, WorkDir: workingDirectory,
        Args: arguments, ShortcutArgs: shortcutArguments, EnvVars: environment,
        PID: 0, LastKnownPID: 0, PIDCreationIdentity: "", PIDImagePath: "",
        LastKnownPIDCreationIdentity: "",
        ResolvedTarget: resolvedTarget, ShortcutTargetSource: resolutionSource,
        ResolvedTargetManual: !!resolvedTargetManual,
        ShortcutResolveCheckedTicks: GetTickCount64(),
        RestartTimer: 0, VerifyTimer: 0, VerifyAttempts: 0, ServicePendingSince: 0,
        ServiceRestartRequested: false,
        Generation: 0, OneShot: IsOneShotTarget(path, resolvedTarget), MaintenanceConfig: normalizedMaintenance,
        MaintenanceMode: "Normal", MaintenanceStartedTicks: 0,
        MaintenanceStartedAt: "", MaintenanceLastActivityTicks: 0,
        MaintenanceRestartDueTicks: 0, MaintenanceBaselineFingerprint: currentFingerprint,
        ArbitrationSnapshotRequestTicks: 0, ArbitrationSignalBaselineTicks: 0,
        MaintenanceFileChanged: false, ExplicitMaintenance: false,
        MaintenanceWatcherRoot: "", MaintenanceWatcherPath: "", KnownActorPids: Map(),
        TransientActorPids: Map(), LastActorSeenTicks: 0, LastFileActivityTicks: 0,
        MaintenanceFingerprintCheckedTicks: 0,
        MaintenanceReadyCheckedTicks: 0, MaintenanceLastReady: true,
        SafetyFingerprint: currentFingerprint, SafetyStableSince: GetTickCount64(),
        MaintenanceLearningCandidates: Map(), MissingSinceTicks: 0
    }
    App.appOrder.Push(path)
    if enabled
        EnsureMaintenanceWatcher(path, App.appStates[path])
    try {
        iconIdx := GetFileIconIndex(path, Main.lv.IL)
        SplitPath(path, , , , &nameNoExt)
        statusText := enabled ? "初始化..." : "⏸️ 已暂停"
        row := Main.lv.Add("Icon" iconIdx,
            FormatMainListLabel(nameNoExt, runAsAdmin),
            FormatMainStatusLabel(statusText), path)
        SetMainListStatus(row, statusText)
        return true
    } catch as projectionErr {
        CloseMaintenanceWatcher(App.appStates[path])
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
    CommitUndoState()
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
            App.appStates[chkPath].ServiceRestartRequested := false
            if (!newState) {
                CancelTargetTimers(App.appStates[chkPath])
                CleanupTargetMaintenance(chkPath, App.appStates[chkPath], true)
                UpdateState(chkPath, "⏸️ 已暂停")
                App.appStates[chkPath].Pending := false
                App.appStates[chkPath].TargetStartTicks := 0
                App.appStates[chkPath].FailCount := 0
                ClearStateProcessIdentity(App.appStates[chkPath])
            } else {
                CancelTargetTimers(App.appStates[chkPath])
                ResetMaintenanceSession(chkPath, App.appStates[chkPath], false)
                EnsureMaintenanceWatcher(chkPath, App.appStates[chkPath])
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
        SaveAppsToIni()
        OnLVSelectChange() ; 刷新按钮显示状态
    }
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
            if App.textInputCursorStates.Has(App.activeInlineEditHwnd)
                App.textInputCursorStates.Delete(App.activeInlineEditHwnd)
            App.activeInlineEditHwnd := 0
        }
        try GuiCtrlObj.Opt("+ReadOnly")
        return
    }
    hEdit := SendMessage(0x1018, 0, 0, GuiCtrlObj.Hwnd)
    if (!hEdit) {
        SetTimer(, 0)
        if App.activeInlineEditHwnd {
            if App.textInputCursorStates.Has(App.activeInlineEditHwnd)
                App.textInputCursorStates.Delete(App.activeInlineEditHwnd)
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
                prospectiveResolvedTarget := ResolveShortcutTargetForState(newPath, "",
                    &prospectiveResolutionSource)
                shortcutTarget := ""
                ReadShortcutData(newPath, &shortcutTarget, &prospectiveWorkingDirectory,
                    &prospectiveShortcutArgs)
            }
            prospectiveIdentity := prospectiveResolvedTarget != ""
                ? prospectiveResolvedTarget
                : (IsPotentialShortcutProcessTarget(newPath) ? newPath : "")
            identityConflict := FindIdentityConflict(prospectiveIdentity, previousPath)
            if (SubStr(newPath, 1, 8) == "Service:" && Trim(SubStr(newPath, 9)) == "") {
                newPath := previousPath
            } else if (SubStr(newPath, 1, 8) != "Service:" && DirExist(newPath)) {
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
                CommitUndoState()
                stateObj := App.appStates[previousPath]
                CancelTargetTimers(stateObj)
                CleanupTargetMaintenance(previousPath, stateObj, true)
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
                stateObj.MaintenanceConfig := NormalizeMaintenanceConfig(stateObj.MaintenanceConfig, newPath)
                fingerprintTarget := stateObj.ResolvedTarget != "" ? stateObj.ResolvedTarget : newPath
                stateObj.MaintenanceBaselineFingerprint := GetTargetFileFingerprint(fingerprintTarget)
                stateObj.SafetyFingerprint := stateObj.MaintenanceBaselineFingerprint
                stateObj.SafetyStableSince := GetTickCount64()
                stateObj.KnownActorPids := Map()
                stateObj.TransientActorPids := Map()
                stateObj.LastActorSeenTicks := 0
                stateObj.LastFileActivityTicks := 0
                stateObj.State := "初始化..."
                App.appStates.Delete(previousPath)
                App.appStates[newPath] := stateObj
                ReplaceAppOrderPath(previousPath, newPath)
                EnsureMaintenanceWatcher(newPath, stateObj)
                GuiCtrlObj.Modify(Item, "Col3", newPath)
                SetMainListStatus(Item, "初始化...")
                iconIdx := GetFileIconIndex(newPath, GuiCtrlObj.IL)
                if iconIdx
                    GuiCtrlObj.Modify(Item, "Icon" iconIdx)
                SaveAppsToIni()
                LogMsg("更新了应用程序路径。")
            }
        }
        
        realPath := GuiCtrlObj.GetText(Item, 3)
        SplitPath(realPath, , , , &nameNoExt)
        isAdmin := App.appStates.Has(realPath) && App.appStates[realPath].HasOwnProp("RunAsAdmin") ? App.appStates[realPath].RunAsAdmin : 0
        GuiCtrlObj.Modify(Item, "Col1", FormatMainListLabel(nameNoExt, isAdmin)) ; 恢复显示应用名
    } catch {
        realPath := GuiCtrlObj.GetText(Item, 3)
        SplitPath(realPath, , , , &nameNoExt)
        isAdmin := App.appStates.Has(realPath) && App.appStates[realPath].HasOwnProp("RunAsAdmin") ? App.appStates[realPath].RunAsAdmin : 0
        GuiCtrlObj.Modify(Item, "Col1", FormatMainListLabel(nameNoExt, isAdmin))
    }
    StartNextInlineEdit(GuiCtrlObj, sessionId)
}

GetAppConfig(p) {
    if !App.appStates.Has(p)
        return {Path: p, Enabled: 1, RunAsAdmin: 0, WorkDir: "", Args: "", ShortcutArgs: "", EnvVars: "", ResolvedTarget: "", ResolvedTargetManual: false, Maintenance: CreateDefaultMaintenanceConfig(p)}
    obj := App.appStates[p]
    return {
        Path: p, Enabled: obj.Enabled,
        RunAsAdmin: obj.HasOwnProp("RunAsAdmin") ? obj.RunAsAdmin : 0,
        WorkDir: obj.HasOwnProp("WorkDir") ? obj.WorkDir : "",
        Args: obj.HasOwnProp("Args") ? obj.Args : "",
        ShortcutArgs: obj.HasOwnProp("ShortcutArgs") ? obj.ShortcutArgs : "",
        EnvVars: obj.HasOwnProp("EnvVars") ? obj.EnvVars : "",
        ResolvedTarget: obj.HasOwnProp("ResolvedTarget") ? obj.ResolvedTarget : "",
        ResolvedTargetManual: obj.HasOwnProp("ResolvedTargetManual") ? obj.ResolvedTargetManual : false,
        Maintenance: CloneMaintenanceConfig(obj.MaintenanceConfig, p)
    }
}

CommitUndoState() {
    state := []
    Loop Main.lv.GetCount() {
        try {
            savePath := Main.lv.GetText(A_Index, 3)
            state.Push(GetAppConfig(savePath))
        }
    }
    App.undoStack.Push(state)
    if (App.undoStack.Length > 20)
        App.undoStack.RemoveAt(1)
    App.redoStack := []
}

PerformUndo() {
    if (App.undoStack.Length == 0)
        return
        
    currentState := []
    Loop Main.lv.GetCount() {
        try {
            p := Main.lv.GetText(A_Index, 3)
            currentState.Push(GetAppConfig(p))
        }
    }
    App.redoStack.Push(currentState)
    
    prevState := App.undoStack.Pop()
    ApplyState(prevState)
    LogMsg("已撤销上一步操作。")
}


PerformRedo() {
    if (App.redoStack.Length == 0)
        return
        
    currentState := []
    Loop Main.lv.GetCount() {
        try {
            p := Main.lv.GetText(A_Index, 3)
            currentState.Push(GetAppConfig(p))
        }
    }
    App.undoStack.Push(currentState)
    
    nextState := App.redoStack.Pop()
    ApplyState(nextState)
    LogMsg("已重做操作。")
}

ApplyState(stateArr) {
    App.editSessionId++
    App.batchEditRows := []
    App.editMonitorItem := 0
    Main.contextTargetRow := 0
    Main.lv.Opt("-Redraw")
    Main.lv.Delete()
    
    existingStates := App.appStates
    for existingPath, existingState in existingStates {
        CancelTargetTimers(existingState)
        CleanupTargetMaintenance(existingPath, existingState, false)
    }
    App.appStates := Map()
    App.appStates.CaseSense := "Off"
    App.appOrder := []
    
    App.iconCache := Map()
    IL_Destroy(Main.appIcons)
    Main.statusIconIndices := Map()
    Main.appIcons := CreateMainImageList(Main.statusIconIndices)
    Main.lv.SetImageList(Main.appIcons, 1)
    Main.lv.IL := Main.appIcons
    
    for item in stateArr {
        RegisterApp(item.Path, item.Enabled, item.RunAsAdmin, item.WorkDir, item.Args,
            item.EnvVars, item.HasOwnProp("Maintenance") ? item.Maintenance : "",
            item.HasOwnProp("ResolvedTarget") ? item.ResolvedTarget : "",
            item.HasOwnProp("ResolvedTargetManual") ? item.ResolvedTargetManual : false,
            item.HasOwnProp("ShortcutArgs") ? item.ShortcutArgs : "")
    }
    SaveMaintenanceJournal()
    Main.lv.Opt("+Redraw")
    SaveAppsToIni()
    OnLVSelectChange()
}

SaveAppsToIni() {
    static isSaving := false
    if isSaving
        return false
    isSaving := true
    tempPath := App.iniPath ".tmp." GetTickCount64() "_" A_ScriptHwnd
    Critical("On")
    try {
        if FileExist(App.iniPath)
            FileCopy(App.iniPath, tempPath, 1)
        else
            FileAppend("", tempPath, "UTF-16")
        IniDelete(tempPath, "Apps")
        IniDelete(tempPath, "Maintenance")
        IniDelete(tempPath, "Recovery")
        orderedPaths := []
        seenPaths := Map()
        seenPaths.CaseSense := "Off"
        for savePath in App.appOrder {
            if App.appStates.Has(savePath) && !seenPaths.Has(savePath) {
                orderedPaths.Push(savePath)
                seenPaths[savePath] := true
            }
        }
        for savePath, _ in App.appStates {
            if !seenPaths.Has(savePath) {
                orderedPaths.Push(savePath)
                seenPaths[savePath] := true
            }
        }
        App.appOrder := orderedPaths
        for index, savePath in orderedPaths {
            cfg := GetAppConfig(savePath)
            value := cfg.Enabled "|" cfg.RunAsAdmin "|" savePath "|" EncodeIniField(cfg.WorkDir)
            value .= "|" EncodeIniField(cfg.Args) "|" EncodeIniField(cfg.EnvVars)
            value .= "|" EncodeIniField(cfg.ResolvedTarget)
            value .= "|" (cfg.ResolvedTargetManual ? 1 : 0)
            value .= "|" EncodeIniField(cfg.ShortcutArgs)
            IniWrite(value, tempPath, "Apps", "App" index)
            IniWrite(SerializeMaintenanceConfig(cfg.Maintenance, savePath), tempPath, "Maintenance", "App" index)
        }
        for index, recoveryEntry in App.configRecoveryEntries {
            recoveryValue := "Source=" EncodeIniField(recoveryEntry.Key)
            recoveryValue .= "`nApp=" EncodeIniField(recoveryEntry.Value)
            recoveryValue .= "`nMaintenance=" EncodeIniField(recoveryEntry.Maintenance)
            IniWrite(EncodeIniField(recoveryValue), tempPath, "Recovery", "Entry" index)
        }
        try EnsureManagedIniSectionComments(tempPath)
        catch as commentErr
            LogMsg("更新配置文件注释失败，配置数据仍将正常保存: " commentErr.Message)
        FileMove(tempPath, App.iniPath, 1)
        App.appsDirty := false
        return true
    } catch as saveErr {
        try FileDelete(tempPath)
        App.appsDirty := true
        LogMsg("保存监控配置失败: " saveErr.Message)
        nowTicks := GetTickCount64()
        if (nowTicks - App.lastSaveWarningTicks > 10000) {
            try TrayTip("监控配置尚未保存，请查看运行日志。", "进程守护小助手", 3)
            App.lastSaveWarningTicks := nowTicks
        }
        return false
    } finally {
        Critical("Off")
        isSaving := false
    }
}

EnsureManagedIniSectionComments(iniPath) {
    iniText := FileRead(iniPath, "UTF-16")
    newline := InStr(iniText, "`r`n") ? "`r`n" : "`n"
    documentedText := InsertIniSectionComment(iniText, "Apps", [
        "; 每个 AppN 对应一个监控项，九个字段使用竖线分隔。",
        "; 格式：启用状态｜管理员运行｜目标路径｜工作目录｜启动参数｜环境变量｜快捷方式真实目标｜手动目标标记｜快捷方式参数。",
        "; 布尔值使用 1 表示开启、0 表示关闭；<HEX> 内容由软件自动编码和解码。"
    ], newline)
    documentedText := InsertIniSectionComment(documentedText, "Maintenance", [
        "; AppN 与 [Apps] 中同名项目一一对应，值为软件升级保护的 <HEX> 编码结构。",
        "; 内部字段包括 Enabled、RootIsCustom、DetectionSeconds、StableSeconds、MaxWaitSeconds、InstallRoot 和 Actor。",
        "; 建议通过“软件升级保护”界面修改，不要直接编辑编码内容。"
    ], newline)
    documentedText := InsertIniSectionComment(documentedText, "Recovery", [
        "; 无法安全解析的监控记录会暂存于此，避免静默丢失；正常情况下无需手动修改。"
    ], newline)
    if (documentedText == iniText)
        return false
    documentedPath := iniPath ".documented"
    try {
        try FileDelete(documentedPath)
        FileAppend(documentedText, documentedPath, "UTF-16")
        FileMove(documentedPath, iniPath, 1)
        return true
    } catch {
        try FileDelete(documentedPath)
        throw
    }
}

InsertIniSectionComment(iniText, sectionName, commentLines, newline) {
    marker := commentLines[1]
    if InStr(iniText, marker)
        return iniText
    pattern := "m)^\[" sectionName "\][ `t]*(?:\r\n|\n|$)"
    if !RegExMatch(iniText, pattern, &headerMatch)
        return iniText
    headerText := headerMatch[0]
    if !InStr(headerText, "`n")
        headerText .= newline
    commentText := ""
    for line in commentLines
        commentText .= line newline
    return SubStr(iniText, 1, headerMatch.Pos[0] - 1)
        . headerText commentText SubStr(iniText, headerMatch.Pos[0] + headerMatch.Len[0])
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

SaveSettingsToIni(intervalValue, retryValue, options) {
    static isSaving := false
    if isSaving
        return false
    isSaving := true
    tempPath := App.iniPath ".settings.tmp." GetTickCount64() "_" A_ScriptHwnd
    Critical("On")
    try {
        if FileExist(App.iniPath)
            FileCopy(App.iniPath, tempPath, 1)
        else
            FileAppend("", tempPath, "UTF-16")
        IniWrite(intervalValue, tempPath, "Settings", "CheckInterval")
        IniWrite(retryValue, tempPath, "Settings", "RetrySequence")
        IniWrite(options.ShowAtStartup ? 1 : 0, tempPath, "Settings", "ShowAtStartup")
        IniWrite(options.RecursiveBatchImport ? 1 : 0, tempPath, "Settings", "RecursiveBatchImport")
        IniWrite(options.LogMaxEntries, tempPath, "Settings", "LogMaxEntries")
        IniWrite(options.LogDirectory, tempPath, "Settings", "LogDirectory")
        IniWrite(options.LogRetentionDays, tempPath, "Settings", "LogRetentionDays")
        IniWrite(options.ClearLogsOnStartup ? 1 : 0, tempPath, "Settings", "ClearLogsOnStartup")
        IniWrite(options.GracefulStopSeconds, tempPath, "Settings", "GracefulStopSeconds")
        IniWrite(options.CtrlCWaitSeconds, tempPath, "Settings", "CtrlCWaitSeconds")
        IniWrite(options.AllowForceTerminate ? 1 : 0, tempPath, "Settings", "AllowForceTerminate")
        IniWrite(options.ServicePendingTimeoutSeconds, tempPath, "Settings", "ServicePendingTimeoutSeconds")
        IniWrite(options.ResumePausedServices ? 1 : 0, tempPath, "Settings", "ResumePausedServices")
        IniWrite(options.PreferEverything ? 1 : 0, tempPath, "Settings", "PreferEverything")
        IniWrite(options.NativeScanTimeoutSeconds, tempPath, "Settings", "NativeScanTimeoutSeconds")
        IniWrite(options.EverythingMaxResults, tempPath, "Settings", "EverythingMaxResults")
        FileMove(tempPath, App.iniPath, 1)
        return true
    } catch as saveErr {
        try FileDelete(tempPath)
        LogMsg("保存运行参数失败: " saveErr.Message)
        return false
    } finally {
        Critical("Off")
        isSaving := false
    }
}

EncodeIniField(value) {
    value := String(value)
    byteCount := StrPut(value, "UTF-8") - 1
    if (byteCount <= 0)
        return ""
    encodedBuffer := Buffer(byteCount + 1, 0)
    StrPut(value, encodedBuffer, "UTF-8")
    hex := ""
    Loop byteCount
        hex .= Format("{:02X}", NumGet(encodedBuffer, A_Index - 1, "UChar"))
    return "<HEX>" hex
}

DecodeIniField(value) {
    if (SubStr(value, 1, 5) != "<HEX>")
        return value
    hex := SubStr(value, 6)
    if (Mod(StrLen(hex), 2) || (hex != "" && !RegExMatch(hex, "i)^[0-9a-f]+$")))
        return value
    byteCount := StrLen(hex) // 2
    if (byteCount == 0)
        return ""
    decodedBuffer := Buffer(byteCount + 1, 0)
    Loop byteCount {
        byte := Integer("0x" SubStr(hex, A_Index * 2 - 1, 2))
        NumPut("UChar", byte, decodedBuffer, A_Index - 1)
    }
    return StrGet(decodedBuffer, "UTF-8")
}

/*  * ========================================================================
 * 核心后台轮询与状态调度 (Heartbeat Polling)
 * ========================================================================
 * 运行于独立时钟周期的循环池：
 * 定时执行进程检查；使用全局 WMI 快照缓存(CachedWMICmdLines)减少性能消耗。
 */
MonitorLoop() {
    static CachedWMICmdLines := []
    
    if (App.isRestarting || App.processLoopBusy)
        return
    App.processLoopBusy := true
    loopStartedTicks := GetTickCount64()
    try {
    
    ; 遍历当前列表内的所有任务程序，判定当下是否需要提前发出 WMI 统一进程命令行查询
    nowTicks := GetTickCount64()
    needWMI := false
    for chkPath in App.appOrder {
        if !App.appStates.Has(chkPath)
            continue
        stateObj := App.appStates[chkPath]
        if (!stateObj.Enabled || (stateObj.HasOwnProp("OneShot") && stateObj.OneShot))
            continue
        if (stateObj.Pending
            && (!IsMaintenanceBlocking(stateObj) || stateObj.MaintenanceMode == "TimedOut"))
            continue
        hasLivePid := StateProcessIdentityIsValid(chkPath, stateObj)
        maintenanceNeedsSnapshot := stateObj.MaintenanceMode == "Arbitrating"
            || stateObj.MaintenanceMode == "Recovering"
        if (InStr(chkPath, "\") && !hasLivePid && !maintenanceNeedsSnapshot
            && !TargetReferenceExists(chkPath, stateObj))
            continue
        if (InStr(chkPath, "\") && (!hasLivePid || maintenanceNeedsSnapshot)) {
            needWMI := true
            break
        }
    }
    
    CachedWMICmdLines := needWMI ? GetProcessSnapshotAsync(&wmiSnapshotReady) : []
    if !needWMI {
        wmiSnapshotReady := true
        PumpProcessSnapshotWorker()
    }
    canValidateWithSnapshot := needWMI && wmiSnapshotReady

    for loopPath in App.appOrder {
        if !App.appStates.Has(loopPath)
            continue
            
        stateObj := App.appStates[loopPath]
        
        if !stateObj.Enabled
            continue

        if IsMaintenanceBlocking(stateObj) {
            targetSnapshotReady := canValidateWithSnapshot
                && (stateObj.MaintenanceMode != "Arbitrating"
                    || (stateObj.ArbitrationSnapshotRequestTicks
                        && App.latestProcessSnapshotTicks
                            >= stateObj.ArbitrationSnapshotRequestTicks))
            if (InStr(loopPath, "\") && targetSnapshotReady) {
                maintenanceObservedPid := CheckIsRunning(loopPath, &CachedWMICmdLines, false)
                if maintenanceObservedPid {
                    SetStateProcessIdentity(stateObj, maintenanceObservedPid)
                    if (stateObj.MaintenanceMode == "Arbitrating") {
                        ResetMaintenanceSession(loopPath, stateObj)
                        UpdateState(loopPath, "✅ 运行中")
                    }
                } else if stateObj.PID {
                    ClearStateProcessIdentity(stateObj)
                }
            }
            continue
        }

        if stateObj.Pending
            continue

        if (stateObj.HasOwnProp("OneShot") && stateObj.OneShot) {
            if (InStr(loopPath, "\") && !TargetReferenceExists(loopPath, stateObj)) {
                UpdateState(loopPath, "❌ 目标不存在")
                stateObj.Pending := false
                continue
            }
            if (stateObj.State == "初始化..." || InStr(stateObj.State, "不存在")) {
                UpdateState(loopPath, "初始化...")
                stateObj.Pending := true
                DoRestart(loopPath)
            }
            continue
        }

        ; 没有可用快照时，只有 PID 失效的目标需要等待下一次 WMI 探活；
        ; 已运行目标走 PID 与原生镜像路径快速校验，避免每轮阻塞消息泵。
        if (InStr(loopPath, "\") && !wmiSnapshotReady
            && !StateProcessIdentityIsValid(loopPath, stateObj))
            continue

        SplitPath(loopPath, &exeName, , &ext)
        if (StrLower(ext) == "lnk"
            && (!stateObj.ResolvedTarget || !FileExist(stateObj.ResolvedTarget))
            && RefreshShortcutIdentity(loopPath, stateObj)) {
            SaveAppsToIni()
        }
        isService := (SubStr(loopPath, 1, 8) == "Service:")
        if (!isService && TargetReferenceExists(loopPath, stateObj))
            ClearTargetMissingState(loopPath, stateObj)
        serviceState := ""
        if isService {
            serviceState := QueryServiceState(SubStr(loopPath, 9))
            ; 查询失败与“服务不存在”必须区分；前者只跳过本轮，不能触发删除/重启逻辑。
            if (serviceState == "Error")
                continue
            if InStr(serviceState, "Pending") {
                stateObj.Pending := true
                stateObj.ServicePendingSince := GetTickCount64()
                UpdateState(loopPath, serviceState == "StopPending"
                    ? "⏳ 等待服务停止后恢复" : "⏳ 验证服务状态...")
                ScheduleVerify(loopPath, 500)
                continue
            }
            if (serviceState == "Paused" && !App.resumePausedServices) {
                stateObj.FailCount := 0
                stateObj.Pending := false
                UpdateState(loopPath, "⏸️ 服务已暂停")
                continue
            }
            if (serviceState == "Paused" && App.resumePausedServices) {
                stateObj.Pending := true
                stateObj.ServicePendingSince := GetTickCount64()
                StartWindowsService(SubStr(loopPath, 9))
                UpdateState(loopPath, "⏳ 正在恢复已暂停服务")
                ScheduleVerify(loopPath, 750)
                continue
            }
        }

        isRunning := isService ? (serviceState == "Running") : 0
        
        ; 极速探活通道 (Fast Path)
        if (!isService && StateProcessIdentityIsValid(loopPath, stateObj)) {
            pidMatches := canValidateWithSnapshot
                ? ProcessMatchesTarget(stateObj.PID, loopPath, &CachedWMICmdLines)
                : DoesProcessMatchTarget(stateObj.PID, loopPath, stateObj)
            if pidMatches
                isRunning := stateObj.PID
        }
        
        ; 完整探活通道（进程命令行核验）
        if (!isRunning && !isService) {
            isRunning := CheckIsRunning(loopPath, &CachedWMICmdLines)
            if (!isService && isRunning)
                SetStateProcessIdentity(stateObj, isRunning)
            else if (!isService) {
                ClearStateProcessIdentity(stateObj)
            }
        }

        ; 快捷方式可能在升级后改绑到新的组件路径。仅在探活失败时低频刷新，
        ; 成功刷新后立即用本轮快照复核，避免误启已失效的目标或进入无意义仲裁。
        if (!isRunning && StrLower(ext) == "lnk"
            && RefreshShortcutIdentity(loopPath, stateObj)) {
            SaveAppsToIni()
            isRunning := CheckIsRunning(loopPath, &CachedWMICmdLines)
            if isRunning {
                SetStateProcessIdentity(stateObj, isRunning)
            }
        }
        
        isScript := RegExMatch(ext, "i)^(ahk|py|pyw|js|vbs|vbe|wsf|ps1|bat|cmd|rb|pl|php|lua|jar|sh|bash)$")
        missingMsg := isScript ? "❌ 脚本不存在" : "❌ 程序不存在"

        if (isRunning) {
            if !isService {
                SetStateProcessIdentity(stateObj, isRunning)
            }
            UpdateState(loopPath, "✅ 运行中")
            stateObj.FailCount := 0
        } else {
            if (isService && serviceState == "Missing") {
                if (stateObj.State != "❌ 服务不存在") {
                    UpdateState(loopPath, "❌ 服务不存在")
                    LogMsg("监测到服务已不存在，挂起守护: " SubStr(loopPath, 9))
                }
                continue
            } else if (!isService && InStr(loopPath, "\")
                && !TargetReferenceExists(loopPath, stateObj)) {
                if (IsMaintenanceProtectionEnabled(loopPath, stateObj)
                    && HasRecentMaintenanceSignal(stateObj)) {
                    EnterMaintenance(loopPath, stateObj, "目标文件缺失时检测到升级活动")
                    continue
                }
                MarkTargetMissing(loopPath, stateObj, missingMsg)
                continue
            }
            
            if (stateObj.State = "✅ 运行中" || stateObj.State = "初始化..." || InStr(stateObj.State, "不存在") || InStr(stateObj.State, "等待") || InStr(stateObj.State, "验证")) {
                UpdateState(loopPath, "⚠️ 疑似停止")
            } else if (stateObj.State = "⚠️ 疑似停止") {
                UpdateState(loopPath, "⚠️ 疑似停止")
                LogMsg("检测到进程停止，准备重启: " exeName "（将在 " (App.retryDelayArray[1]/1000) " 秒后启动）")
                if !BeginMaintenanceArbitration(loopPath, stateObj)
                    ScheduleRestart(loopPath, App.retryDelayArray[1])
            }
        }
    }
    } finally {
        LogSlowBackgroundOperation("主进程监控", loopStartedTicks)
        App.processLoopBusy := false
    }
}

DoRestart(rePath, generation := 0) {
    rePath := NormalizeTargetPath(rePath)
    if !App.appStates.Has(rePath)
        return
        
    stateObj := App.appStates[rePath]
    if (generation && stateObj.Generation != generation)
        return
    stateObj.RestartTimer := 0
    if !generation
        CancelTargetTimers(stateObj)
    if App.isRestarting {
        ScheduleRestart(rePath, 1000)
        return
    }
    
    if (!stateObj.Enabled) {
        stateObj.Pending := false
        stateObj.TargetStartTicks := 0
        return
    }
    
    if (InStr(rePath, "\")) {
        SplitPath(rePath, , , &restartExtension)
        if (StrLower(restartExtension) == "lnk"
            && RefreshShortcutIdentity(rePath, stateObj, true))
            SaveAppsToIni()
        ; 带路径目标必须先做一次完整探活，即使缓存 PID 已被清空；否则 WMI
        ; 短暂失败时可能在已有实例上再启动一个副本。
        App.wmiError := false
        existingPid := CheckIsRunning(rePath)
        if existingPid {
            SetStateProcessIdentity(stateObj, existingPid)
            LogMsg("进程仍在运行，忽略重复启动: " rePath)
            stateObj.Pending := false
            stateObj.TargetStartTicks := 0
            return
        }
        if App.wmiError {
            stateObj.Pending := true
            UpdateState(rePath, "⏳ 等待进程状态...")
            LogMsg("暂时无法核对现有进程，延迟启动以避免重复实例: " rePath)
            ScheduleRestart(rePath, 2000)
            return
        }
        ClearStateProcessIdentity(stateObj)
    } else if StateProcessIdentityIsValid(rePath, stateObj) {
        ; 无路径别名只能按进程名探活；这里仍保留 PID 存活检查以避免重复拉起。
        LogMsg("进程仍在运行，忽略重复启动: " rePath)
        stateObj.Pending := false
        stateObj.TargetStartTicks := 0
        return
    }
    if IsMaintenanceBlocking(stateObj) {
        stateObj.Pending := true
        stateObj.TargetStartTicks := 0
        return
    }

    launchPath := InStr(rePath, "\") ? GetLaunchTargetPath(rePath, stateObj) : rePath
    if (IsMaintenanceSupportedTarget(rePath) && launchPath == "") {
        stateObj.Pending := false
        stateObj.TargetStartTicks := 0
        UpdateState(rePath, "❌ 程序不存在")
        LogMsg("启动前发现目标不存在，已停止重试: " rePath)
        return
    }
    safeReason := ""
    if !CanSafelyLaunch(rePath, stateObj, &safeReason) {
        stateObj.Pending := IsMaintenanceBlocking(stateObj)
        stateObj.TargetStartTicks := 0
        if !IsMaintenanceBlocking(stateObj)
            UpdateState(rePath, "⏳ 等待安全启动条件")
        LogMsg("安全启动门暂缓启动: " rePath "（" safeReason "）")
        return
    }

    App.isRestarting := true
    
    stateObj.TargetStartTicks := 0 ; 清除倒计时
    stateObj.VerifyAttempts := 0
    stateObj.ServicePendingSince := 0
    UpdateState(rePath, "🚀 正在启动...")
    SplitPath(rePath, &exeName)
    maxAttempts := App.retryDelayArray.Length

    try {
        if SubStr(rePath, 1, 8) == "Service:" {
            serviceName := SubStr(rePath, 9)
            isAdmin := stateObj.HasOwnProp("RunAsAdmin") && stateObj.RunAsAdmin

            serviceState := QueryServiceState(serviceName)
            if (serviceState == "Error") {
                stateObj.Pending := true
                stateObj.TargetStartTicks := 0
                UpdateState(rePath, "⏳ 等待服务状态...")
                LogMsg("暂时无法查询服务状态，稍后重试启动: " serviceName)
                App.isRestarting := false
                ScheduleVerify(rePath, 2000)
                return
            }
            if (stateObj.ServiceRestartRequested && serviceState == "Running") {
                StopWindowsService(serviceName)
                stateObj.Pending := true
                stateObj.TargetStartTicks := 0
                stateObj.ServicePendingSince := GetTickCount64()
                UpdateState(rePath, "⏳ 正在停止服务...")
                App.isRestarting := false
                ScheduleVerify(rePath, 500)
                return
            }
            if InStr(serviceState, "Pending") {
                stateObj.Pending := true
                stateObj.TargetStartTicks := 0
                stateObj.ServicePendingSince := GetTickCount64()
                UpdateState(rePath, serviceState == "StopPending"
                    ? "⏳ 等待服务停止后恢复" : "⏳ 等待服务状态...")
                App.isRestarting := false
                ScheduleVerify(rePath, 2000)
                return
            }
            if (serviceState == "Missing") {
                stateObj.Pending := false
                stateObj.TargetStartTicks := 0
                UpdateState(rePath, "❌ 服务不存在")
                LogMsg("启动前发现服务不存在，已停止重试: " serviceName)
                App.isRestarting := false
                return
            }
            if (serviceState == "Paused" && !App.resumePausedServices) {
                stateObj.Pending := false
                stateObj.TargetStartTicks := 0
                stateObj.ServicePendingSince := 0
                UpdateState(rePath, "⏸️ 服务已暂停")
                App.isRestarting := false
                return
            }
            
            if (!StartWindowsService(serviceName)) {
                runVerb := isAdmin ? "*RunAs " : ""
                Run(runVerb 'net start "' serviceName '"', , "Hide")
            }
            stateObj.ServiceRestartRequested := false
            LogMsg("已发送启动服务指令: " serviceName (isAdmin ? "（提权）" : ""))
            stateObj.ServicePendingSince := GetTickCount64()
            if !stateObj.Enabled {
                stateObj.Pending := false
                stateObj.TargetStartTicks := 0
                UpdateState(rePath, "⏸️ 已暂停")
                App.isRestarting := false
                return
            }
            UpdateState(rePath, "⏳ 验证状态...")
            App.isRestarting := false
            ScheduleVerify(rePath, 1500)
            return
        }
        
        if InStr(rePath, "\")
            launchPath := GetLaunchTargetPath(rePath, stateObj)
        if (InStr(rePath, "\") && launchPath == "") {
            stateObj.Pending := false
            stateObj.TargetStartTicks := 0
            UpdateState(rePath, "❌ 程序不存在")
            LogMsg("启动前发现目标不存在，已停止重试: " rePath)
            App.isRestarting := false
            return
        }

        SplitPath(launchPath, , &launchDirectory)
        runDir := stateObj.HasOwnProp("WorkDir") && stateObj.WorkDir != "" && DirExist(stateObj.WorkDir)
            ? stateObj.WorkDir : (DirExist(launchDirectory) ? launchDirectory : "")
        newPID := 0
        isAdmin := stateObj.HasOwnProp("RunAsAdmin") && stateObj.RunAsAdmin
        runVerb := isAdmin ? "*RunAs " : ""
        
        customEnvs := Map()
        customEnvs.CaseSense := "Off"
        if (stateObj.HasOwnProp("EnvVars") && stateObj.EnvVars != "") {
            Loop Parse, stateObj.EnvVars, "`n", "`r" {
                if (A_LoopField == "")
                    continue
                eqPos := InStr(A_LoopField, "=")
                if (eqPos) {
                    k := Trim(SubStr(A_LoopField, 1, eqPos - 1))
                    v := Trim(SubStr(A_LoopField, eqPos + 1))
                    if RegExMatch(k, "i)^[a-z_][a-z0-9_]*$")
                        customEnvs[k] := v
                }
            }
        }
        
        originalEnvironment := Map()
        originalEnvironment.CaseSense := "Off"
        try {
        for k, v in customEnvs {
            originalEnvironment[k] := EnvGet(k)
            EnvSet(k, v)
        }
        
        ; 按目标类型选择明确的启动器；只有批处理文件使用 cmd 重定向。
        SplitPath(launchPath, , , &ext)
        ext := StrLower(ext)
        effectiveArguments := stateObj.HasOwnProp("Args") ? Trim(stateObj.Args) : ""
        SplitPath(rePath, , , &configuredExtension)
        if (StrLower(configuredExtension) == "lnk" && !PathsEquivalent(launchPath, rePath)
            && stateObj.HasOwnProp("ShortcutArgs") && stateObj.ShortcutArgs != "")
            effectiveArguments := Trim(stateObj.ShortcutArgs " " effectiveArguments)
        argsStr := effectiveArguments != "" ? " " effectiveArguments : ""
        
            if (ext == "bat" || ext == "cmd") {
                logFile := GetLogFilePath(rePath)
                Run(runVerb . 'cmd /d /c ""' launchPath '"' argsStr ' >> "' logFile '" 2>&1"', runDir, "Hide", &newPID)
                LogMsg("已启动批处理并劫持输出到: " logFile)
            } else if (ext == "ahk" && !A_IsCompiled && FileExist(A_AhkPath)) {
                Run(runVerb . '"' A_AhkPath '" "' launchPath '"' argsStr, runDir, , &newPID)
            } else if (ext == "ps1") {
                Run(runVerb . 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' launchPath '"' argsStr, runDir, , &newPID)
            } else if (!InStr(launchPath, "\")) {
                Run(runVerb . launchPath argsStr, runDir, , &newPID)
            } else {
                Run(runVerb . '"' launchPath '"' argsStr, runDir, , &newPID)
            }
        } finally {
            for k, originalValue in originalEnvironment {
                if (originalValue == "")
                    DllCall("SetEnvironmentVariable", "Str", k, "Ptr", 0)
                else
                    EnvSet(k, originalValue)
            }
        }

        if !stateObj.Enabled {
            stateObj.Pending := false
            stateObj.TargetStartTicks := 0
            UpdateState(rePath, "⏸️ 已暂停")
            App.isRestarting := false
            return
        }

        if (stateObj.HasOwnProp("OneShot") && stateObj.OneShot) {
            ClearStateProcessIdentity(stateObj, false)
            stateObj.Pending := false
            stateObj.FailCount := 0
            UpdateState(rePath, "✅ 已启动（非驻留目标）")
            LogMsg("已启动非驻留目标: " (exeName ? exeName : rePath))
            App.isRestarting := false
            return
        }

        if (newPID && ext != "lnk")
            SetStateProcessIdentity(stateObj, newPID)
        RequestFreshProcessSnapshot()
            
        LogMsg("已发送启动指令: " (exeName ? exeName : rePath) (isAdmin ? "（管理员权限）" : ""))
        UpdateState(rePath, "⏳ 验证运行状态...")
        App.isRestarting := false
        ScheduleVerify(rePath, 1500)
    } catch as restartErr {
        App.isRestarting := false
        ProcessRestartFailure(rePath, exeName, maxAttempts, restartErr.Message)
    }
}

ProcessRestartFailure(rePath, exeName, maxAttempts, errorMsg) {
    if App.appStates.Has(rePath) && IsMaintenanceBlocking(App.appStates[rePath])
        return
    if !App.appStates.Has(rePath)
        return
    stateObj := App.appStates[rePath]
    stateObj.FailCount++
    LogMsg("启动失败 [" stateObj.FailCount "/" maxAttempts "]: " (exeName ? exeName : rePath) " - " errorMsg)
    
    if (stateObj.FailCount < maxAttempts) {
        nextDelayMs := App.retryDelayArray[stateObj.FailCount + 1]
        ScheduleRestart(rePath, nextDelayMs)
        LogMsg("等待 " (nextDelayMs/1000) " 秒后进行第 " (stateObj.FailCount + 1) " 次尝试...")
    } else {
        UpdateState(rePath, "❌ 启动失败")
        stateObj.Pending := false 
        LogMsg("达到最大重试次数，已放弃启动: " exeName)
    }
}

VerifyStart(rePath, generation := 0) {
    rePath := NormalizeTargetPath(rePath)
    if !App.appStates.Has(rePath)
        return
    stateObj := App.appStates[rePath]
    if (generation && stateObj.Generation != generation)
        return
    stateObj.VerifyTimer := 0
    if (!stateObj.Enabled)
        return
    if IsMaintenanceBlocking(stateObj) {
        stateObj.Pending := true
        stateObj.TargetStartTicks := 0
        return
    }

    if (SubStr(rePath, 1, 8) == "Service:") {
        serviceName := SubStr(rePath, 9)
        serviceState := QueryServiceState(serviceName)
        if (stateObj.ServiceRestartRequested && serviceState == "Running") {
            if !stateObj.ServicePendingSince
                stateObj.ServicePendingSince := GetTickCount64()
            if (GetTickCount64() - stateObj.ServicePendingSince >= App.servicePendingTimeoutSeconds * 1000) {
                stateObj.ServiceRestartRequested := false
                stateObj.Pending := false
                ProcessRestartFailure(rePath, serviceName, App.retryDelayArray.Length,
                    "服务未能进入停止状态")
                return
            }
            StopWindowsService(serviceName)
            stateObj.Pending := true
            UpdateState(rePath, "⏳ 正在停止服务...")
            ScheduleVerify(rePath, 500)
            return
        }
        if (serviceState == "Running") {
            UpdateState(rePath, "✅ 运行中")
            stateObj.FailCount := 0
            stateObj.VerifyAttempts := 0
            stateObj.ServicePendingSince := 0
            stateObj.Pending := false
            return
        }
        if (serviceState == "Paused" && !App.resumePausedServices) {
            stateObj.FailCount := 0
            stateObj.VerifyAttempts := 0
            stateObj.ServicePendingSince := 0
            stateObj.Pending := false
            UpdateState(rePath, "⏸️ 服务已暂停")
            return
        }
        if (serviceState == "Paused" && App.resumePausedServices) {
            if StartWindowsService(serviceName) {
                stateObj.Pending := true
                stateObj.ServicePendingSince := GetTickCount64()
                UpdateState(rePath, "⏳ 正在恢复已暂停服务")
                ScheduleVerify(rePath, 750)
                return
            }
        }
        if (serviceState == "Error") {
            stateObj.Pending := true
            UpdateState(rePath, "⏳ 等待服务状态...")
            ScheduleVerify(rePath, 2000)
            return
        }
        if InStr(serviceState, "Pending") {
            if !stateObj.HasOwnProp("ServicePendingSince") || !stateObj.ServicePendingSince
                stateObj.ServicePendingSince := GetTickCount64()
            if (GetTickCount64() - stateObj.ServicePendingSince >= App.servicePendingTimeoutSeconds * 1000) {
                stateObj.ServicePendingSince := 0
                stateObj.Pending := false
                ProcessRestartFailure(rePath, serviceName, App.retryDelayArray.Length, "服务状态切换等待超时（" serviceState "）")
                return
            }
            if (serviceState == "StopPending") {
                stateObj.Pending := true
                UpdateState(rePath, "⏳ 等待服务停止后恢复")
                ScheduleVerify(rePath, 500)
                return
            }
            stateObj.Pending := true
            UpdateState(rePath, "⏳ 验证状态...")
            ScheduleVerify(rePath, 1000)
            return
        }
        if (serviceState == "Missing") {
            stateObj.Pending := false
            stateObj.TargetStartTicks := 0
            stateObj.ServicePendingSince := 0
            UpdateState(rePath, "❌ 服务不存在")
            LogMsg("验证时发现服务不存在，已停止重试: " serviceName)
            return
        }
        if (serviceState == "Stopped") {
            if StartWindowsService(serviceName) {
                stateObj.ServiceRestartRequested := false
                stateObj.Pending := true
                stateObj.ServicePendingSince := GetTickCount64()
                UpdateState(rePath, "⏳ 验证状态...")
                ScheduleVerify(rePath, 750)
                return
            }
        }
        if (serviceState != "Missing" && stateObj.VerifyAttempts < 10) {
            stateObj.VerifyAttempts++
            UpdateState(rePath, "⏳ 验证状态...")
            ScheduleVerify(rePath, 1000)
            return
        }
    }

    SplitPath(rePath, &exeName)
    App.wmiError := false
    if (StateProcessIdentityIsValid(rePath, stateObj) || CheckIsRunning(rePath)) {
        UpdateState(rePath, "✅ 运行中")
        stateObj.FailCount := 0
        stateObj.Pending := false
        LogMsg("启动成功且运行稳定: " (exeName ? exeName : rePath))
    } else if App.wmiError {
        stateObj.Pending := true
        UpdateState(rePath, "⏳ 等待进程状态...")
        ScheduleVerify(rePath, 2000)
    } else {
        ProcessRestartFailure(rePath, exeName, App.retryDelayArray.Length, "进程启动后迅速退出或未成功常驻后台")
    }
}

UpdateCountdownUI() {
    for appPath, stateObj in App.appStates {
        if (stateObj.Pending && stateObj.TargetStartTicks > 0) {
            rem := (stateObj.TargetStartTicks - GetTickCount64()) // 1000
            if (rem > 0) {
                prefix := stateObj.FailCount > 0 ? "⏳ 重试倒计时" : "⏳ 启动倒计时"
                UpdateState(appPath, prefix " " rem "s")
            } else if !InStr(stateObj.State, "验证") {
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
        } else if IsMaintenanceBlocking(obj) {
            updating++
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

UpdateState(updPath, statusStr) {
    updPath := NormalizeTargetPath(updPath)
    if !App.appStates.Has(updPath)
        return
    stateObj := App.appStates[updPath]
    if (stateObj.State != statusStr) {
        stateObj.State := statusStr
        row := FindRow(updPath)
        if (row > 0)
            SetMainListStatus(row, statusStr)
    }
}

FindRow(searchPath) {
    searchPath := StrLower(NormalizeTargetPath(searchPath))
    Loop Main.lv.GetCount() {
        if (StrLower(NormalizeTargetPath(Main.lv.GetText(A_Index, 3))) == searchPath)
            return A_Index
    }
    return 0
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
    if (!pid || !ProcessExist(pid))
        return true
    
    ; 第一级：向目标进程的所有顶层窗口发送 WM_CLOSE（相当于点击右上角×）
    hiddenWindowsBefore := A_DetectHiddenWindows
    try {
        DetectHiddenWindows(true)
        winList := WinGetList("ahk_pid " pid)
        for hwnd in winList
            try PostMessage(Win32.WM_CLOSE, 0, 0, , hwnd)
    } finally {
        DetectHiddenWindows(hiddenWindowsBefore)
    }
    
    ; 按用户设置等待图形程序完成退出。
    if ProcessWaitClose(pid, App.gracefulStopSeconds)
        return true
    
    ; 第二级：尝试向控制台程序发送 Ctrl+C 信号
    ctrlSent := SendConsoleCtrlC(pid)
    
    ; 按用户设置等待控制台程序处理 Ctrl+C。
    if (ctrlSent && ProcessWaitClose(pid, App.ctrlCWaitSeconds))
        return true
    
    ; 第三级：暴力击杀（最终兜底）
    if !App.allowForceTerminate {
        LogMsg("温柔关闭超时，已按设置跳过强制终止 PID: " pid)
        return false
    }
    LogMsg("温柔关闭超时，强制终止进程 PID: " pid)
    ProcessClose(pid)
    ProcessWaitClose(pid, 1)
    
    ; 兜底提权击杀（解决由于管理员权限隔离导致的静默杀进程失败）
    if ProcessExist(pid) {
        LogMsg("权限不足，尝试提权击杀 PID: " pid)
        try RunWait("*RunAs taskkill /F /PID " pid, , "Hide")
    }
    
    return !ProcessExist(pid)
}

/*  * ========================================================================
 * 核心后台轮询与状态调度 (Heartbeat Polling)
 * ========================================================================
 * @param {String} target - 需执行探活的绝对路径和进程名，如 C:\test.ahk, calc.exe
 * @param {ArrayReference} wmiCacheList - （可选的）传递外层抓好所有目前进程带出启动参的 WMI 快照内存表引用
 * @return {ProcessID | Boolean} - 找到了返回实体标识或 True，丢失返回 False
 * ------------------------------------------------------------------------
 * WMI 机制解析：当它查到目标如果是 Test.ahk 时，它不可能去问系统 "有没有 Test.ahk 运行"
 * 采用分支逻辑处理 .exe、批处理与脚本等运行对象的识别机制。
 */
GetServiceManagerHandle() {
    if App.scmHandle
        return App.scmHandle
    App.scmHandle := DllCall("advapi32\OpenSCManagerW", "Ptr", 0, "Ptr", 0,
        "UInt", Win32.SC_MANAGER_CONNECT | Win32.SC_MANAGER_ENUMERATE_SERVICE, "Ptr")
    return App.scmHandle
}

CleanupServiceManager(*) {
    if App.scmHandle
        try DllCall("advapi32\CloseServiceHandle", "Ptr", App.scmHandle)
    App.scmHandle := 0
}

ServiceStateName(currentState) {
    switch currentState {
        case Win32.SERVICE_STOPPED: return "Stopped"
        case Win32.SERVICE_START_PENDING: return "StartPending"
        case Win32.SERVICE_STOP_PENDING: return "StopPending"
        case Win32.SERVICE_RUNNING: return "Running"
        case Win32.SERVICE_CONTINUE_PENDING: return "ContinuePending"
        case Win32.SERVICE_PAUSE_PENDING: return "PausePending"
        case Win32.SERVICE_PAUSED: return "Paused"
    }
    return "Error"
}

QueryServiceState(serviceName) {
    managerHandle := GetServiceManagerHandle()
    if !managerHandle
        return "Error"
    serviceHandle := DllCall("advapi32\OpenServiceW", "Ptr", managerHandle,
        "WStr", serviceName, "UInt", Win32.SERVICE_QUERY_STATUS, "Ptr")
    if !serviceHandle
        return DllCall("kernel32\GetLastError", "UInt") == Win32.ERROR_SERVICE_DOES_NOT_EXIST
            ? "Missing" : "Error"
    try {
        status := Buffer(36, 0)
        bytesNeeded := 0
        if !DllCall("advapi32\QueryServiceStatusEx", "Ptr", serviceHandle,
            "Int", 0, "Ptr", status, "UInt", status.Size, "UInt*", &bytesNeeded, "Int")
            return "Error"
        return ServiceStateName(NumGet(status, 4, "UInt"))
    } finally {
        DllCall("advapi32\CloseServiceHandle", "Ptr", serviceHandle)
    }
}

CheckServiceStatus(serviceName) {
    return QueryServiceState(serviceName) == "Running"
}

StartWindowsService(serviceName) {
    managerHandle := GetServiceManagerHandle()
    if !managerHandle
        return false
    access := Win32.SERVICE_QUERY_STATUS | Win32.SERVICE_START | Win32.SERVICE_PAUSE_CONTINUE
    serviceHandle := DllCall("advapi32\OpenServiceW", "Ptr", managerHandle,
        "WStr", serviceName, "UInt", access, "Ptr")
    if !serviceHandle
        return false
    try {
        state := QueryServiceState(serviceName)
        if (state == "Running" || state == "StartPending" || state == "ContinuePending")
            return true
        if (state == "Paused") {
            status := Buffer(28, 0)
            return !!DllCall("advapi32\ControlService", "Ptr", serviceHandle,
                "UInt", Win32.SERVICE_CONTROL_CONTINUE, "Ptr", status, "Int")
        }
        if (state != "Stopped")
            return false
        return !!DllCall("advapi32\StartServiceW", "Ptr", serviceHandle,
            "UInt", 0, "Ptr", 0, "Int")
    } finally {
        DllCall("advapi32\CloseServiceHandle", "Ptr", serviceHandle)
    }
}

StopWindowsService(serviceName) {
    managerHandle := GetServiceManagerHandle()
    if !managerHandle
        return false
    access := Win32.SERVICE_QUERY_STATUS | Win32.SERVICE_STOP
    serviceHandle := DllCall("advapi32\OpenServiceW", "Ptr", managerHandle,
        "WStr", serviceName, "UInt", access, "Ptr")
    if !serviceHandle
        return false
    try {
        state := QueryServiceState(serviceName)
        if (state == "Stopped" || state == "StopPending")
            return true
        status := Buffer(28, 0)
        return !!DllCall("advapi32\ControlService", "Ptr", serviceHandle,
            "UInt", Win32.SERVICE_CONTROL_STOP, "Ptr", status, "Int")
    } finally {
        DllCall("advapi32\CloseServiceHandle", "Ptr", serviceHandle)
    }
}

EnumerateWindowsServices() {
    result := []
    managerHandle := GetServiceManagerHandle()
    if !managerHandle
        return result
    bytesNeeded := 0
    serviceCount := 0
    resumeHandle := 0
    DllCall("advapi32\EnumServicesStatusExW", "Ptr", managerHandle,
        "Int", 0, "UInt", 0x30, "UInt", 0x03, "Ptr", 0, "UInt", 0,
        "UInt*", &bytesNeeded, "UInt*", &serviceCount, "UInt*", &resumeHandle,
        "Ptr", 0, "Int")
    if !bytesNeeded
        return result
    serviceBuffer := Buffer(bytesNeeded + 4096, 0)
    resumeHandle := 0
    if !DllCall("advapi32\EnumServicesStatusExW", "Ptr", managerHandle,
        "Int", 0, "UInt", 0x30, "UInt", 0x03, "Ptr", serviceBuffer,
        "UInt", serviceBuffer.Size, "UInt*", &bytesNeeded, "UInt*", &serviceCount,
        "UInt*", &resumeHandle, "Ptr", 0, "Int")
        return result
    structureSize := A_PtrSize == 8 ? 56 : 44
    statusOffset := A_PtrSize * 2
    Loop serviceCount {
        offset := (A_Index - 1) * structureSize
        namePointer := NumGet(serviceBuffer, offset, "Ptr")
        displayPointer := NumGet(serviceBuffer, offset + A_PtrSize, "Ptr")
        currentState := NumGet(serviceBuffer, offset + statusOffset + 4, "UInt")
        if namePointer
            result.Push({
                name: StrGet(namePointer, "UTF-16"),
                display: displayPointer ? StrGet(displayPointer, "UTF-16") : "",
                state: ServiceStateName(currentState)
            })
    }
    return result
}

CheckIsRunning(target, wmiCacheList := "", resetWmiError := true) {
    if resetWmiError
        App.wmiError := false
    if SubStr(target, 1, 8) == "Service:" {
        return CheckServiceStatus(SubStr(target, 9))
    }
    ; 1. 若目标字符串内不满足路径定义（例如内置特殊无路径应用别名），针对该对象实行无特征检查
    if (!InStr(target, "\")) {
        return ProcessExist(target)
    }

    ; 2. 分解并抽取出目标检测对象的文件扩展拓展等局部特征 
    SplitPath(target, &fileName, &dir, &ext, &nameNoExt)
    ext := StrLower(ext)

    ; 3. 针对原生标准构建（.exe 程序类）走系统 ProcessExist 底层原生检测校验
    if RegExMatch(ext, "i)^(exe|com)$") {
        return FindProcessByImagePath(target, wmiCacheList)
    } else if (ext == "msc") {
        return FindProcessByCommandLine(target, wmiCacheList)
    } 
    ; 4. 针对各类代码/扩展类型解释器或解释指令，根据内存内 WMI 抓取的命令参数值匹配运行指纹进行对比判定
    else if RegExMatch(ext, "i)^(ahk|py|pyw|js|vbs|vbe|wsf|ps1|bat|cmd|rb|pl|php|lua|jar|sh|bash)$") {
        if (wmiCacheList != "" && Type(wmiCacheList) == "VarRef") {
            return FindProcessByCommandLine(target, wmiCacheList)
        } else {
            return FindProcessByCommandLine(target)
        }
    } 
    ; 5. 针对基于 Windows 快捷访问后缀 (.lnk) 创建的对象，提取出底层关联执行路径并对真正代指物进行复发验证
    else if (ext == "lnk") {
        shortcutTarget := "", shortcutWorkingDirectory := "", shortcutArguments := ""
        if !ReadShortcutData(target, &shortcutTarget, &shortcutWorkingDirectory, &shortcutArguments)
            return 0

        ; 考虑到形如 "python.exe script.py" 的快捷方式，优先检测所传递的脚本路径参数。
        if (shortcutArguments != "" && RegExMatch(shortcutArguments, "i)([a-zA-Z]:\\[^\x22]+(\.(ahk|py|pyw|js|vbs|vbe|wsf|ps1|bat|cmd|rb|pl|php|lua|jar|sh|bash)))", &match))
            return CheckIsRunning(match[1], wmiCacheList, false)

        effectiveTarget := GetMonitoredTargetPath(target)
        if (effectiveTarget != "")
            return CheckIsRunning(effectiveTarget, wmiCacheList, false)

        ; 无法推导精确目标时，优先匹配与快捷方式同名的进程；仅当目录中
        ; 恰好只有一个运行进程时才允许兜底，避免把连接器或辅助进程当成主程序。
        return FindProcessByWorkingDirectory(shortcutWorkingDirectory, wmiCacheList,
            nameNoExt != "" ? nameNoExt ".exe" : "")
    } 
    
    ; 容错防御或其它非结构识别状态：强制提交系统同名识别器判定结果
    return ProcessExist(fileName)
}

LogMsg(msg) {
    App.logMessages.InsertAt(1, Format("{1} - {2}", FormatTime(A_Now, "HH:mm:ss"), msg))
    while (App.logMessages.Length > App.logMaxEntries)
        App.logMessages.Pop()
    App.logRevision++
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
    CommitUndoState()
    
    ; 从后往前删防止行号错乱
    Loop delList.Length {
        idx := delList.Length - A_Index + 1
        currRow := delList[idx]
        try {
            delPath := Main.lv.GetText(currRow, 3)
            if App.appStates.Has(delPath) {
                CancelTargetTimers(App.appStates[delPath])
                CleanupTargetMaintenance(delPath, App.appStates[delPath], true)
            }
            App.appStates.Delete(delPath)
            RemoveAppOrderPath(delPath)
            LogMsg("已取消监控: " delPath)
        }
        Main.lv.Delete(currRow)
    }
    
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
OnMouseMove_Tooltip(wParam, lParam, msg, hwnd) {
    UpdateButtonHover(hwnd)
    GuiModules.tooltip.HandleMouseMove(wParam, lParam, msg, hwnd)
}

OnMouseLeave_Hover(wParam, lParam, msg, hwnd) {
    if (App.pressedButtonHwnd == hwnd) {
        if App.buttonHoverStates.Has(hwnd) {
            pressedState := App.buttonHoverStates[hwnd]
            if !(pressedState.HasOwnProp("cursorOnly") && pressedState.cursorOnly)
                SetButtonBackground(pressedState.ctrl, pressedState.normal)
        }
        if (App.hoveredButtonHwnd == hwnd)
            App.hoveredButtonHwnd := 0
        return
    }
    if (App.hoveredButtonHwnd == hwnd)
        RestoreHoveredButton()
}

OnGlobalPointerDown(wParam, lParam, msg, hwnd) {
    if App.buttonHoverStates.Has(hwnd)
        BeginButtonPress(hwnd)

    PruneTextInputCursorStates()
    if App.textInputCursorStates.Has(hwnd) {
        clickedTextState := App.textInputCursorStates[hwnd]
        if (clickedTextState.HasOwnProp("hideCaret") && clickedTextState.hideCaret)
            ScheduleHideTextCaret(clickedTextState.editHwnd)
        return
    }

    focusedHwnd := DllCall("user32\GetFocus", "Ptr")
    if !focusedHwnd || !App.textInputCursorStates.Has(focusedHwnd)
        return
    rootHwnd := DllCall("user32\GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr") ; GA_ROOT
    if rootHwnd && DllCall("user32\IsWindowEnabled", "Ptr", rootHwnd, "Int")
        DllCall("user32\SetFocus", "Ptr", rootHwnd, "Ptr")
}

OnGlobalPointerUp(wParam, lParam, msg, hwnd) {
    EndButtonPress()

    if !App.textInputCursorStates.Has(hwnd)
        return
    releasedTextState := App.textInputCursorStates[hwnd]
    if (releasedTextState.HasOwnProp("hideCaret") && releasedTextState.hideCaret)
        ScheduleHideTextCaret(releasedTextState.editHwnd)
}

OnButtonPressCancelled(*) {
    CancelButtonPress()
}

OnButtonCaptureChanged(wParam, lParam, msg, hwnd) {
    if (App.pressedButtonHwnd == hwnd)
        CancelButtonPress()
}

OnSetCursor(wParam, lParam, msg, hwnd) {
    textTargetHwnd := (wParam && App.textInputCursorStates.Has(wParam)) ? wParam : (App.textInputCursorStates.Has(hwnd) ? hwnd : 0)
    if textTargetHwnd {
        textInputState := App.textInputCursorStates[textTargetHwnd]
        if DllCall("user32\IsWindow", "Ptr", textTargetHwnd, "Int")
            && DllCall("user32\IsWindow", "Ptr", textInputState.editHwnd, "Int")
            && IsControlEffectivelyEnabled(textInputState.editHwnd) {
            SetTextCursor()
            return 1
        }
        App.textInputCursorStates.Delete(textTargetHwnd)
    }

    ; WM_SETCURSOR 的 wParam 是鼠标所在子窗口句柄；部分系统版本回调 hwnd 会是父窗口，需同时检查两者。
    buttonHwnd := (wParam && App.buttonHoverStates.Has(wParam)) ? wParam : hwnd
    if App.buttonHoverStates.Has(buttonHwnd) && IsHoverButtonAvailable(App.buttonHoverStates[buttonHwnd]) {
        SetHandCursor()
        return 1
    }
}

SetHandCursor() {
    if !App.handCursor
        App.handCursor := DllCall("user32\LoadCursor", "Ptr", 0, "Ptr", 32649, "Ptr") ; IDC_HAND
    if App.handCursor
        DllCall("user32\SetCursor", "Ptr", App.handCursor)
}

SetTextCursor() {
    if !App.textCursor
        App.textCursor := DllCall("user32\LoadCursor", "Ptr", 0, "Ptr", Win32.IDC_IBEAM, "Ptr")
    if App.textCursor
        DllCall("user32\SetCursor", "Ptr", App.textCursor)
}

RegisterTextInputControl(inputControl, hideCaret := false) {
    try textEditHwnd := inputControl.Hwnd
    catch
        return
    RegisterTextInputHwnd(textEditHwnd, hideCaret)
}

RegisterTextInputHwnd(textEditHwnd, hideCaret := false) {
    if !textEditHwnd || !DllCall("user32\IsWindow", "Ptr", textEditHwnd, "Int")
        return
    PruneTextInputCursorStates()
    App.textInputCursorStates[textEditHwnd] := {editHwnd: textEditHwnd, hideCaret: hideCaret}
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
    App.textInputCursorStates[backgroundHwnd] := {editHwnd: textEditHwnd}
    backgroundControl.OnEvent("Click", PlaceTextCaretAtPointer.Bind(inputControl))
}

UnregisterGuiControls(guiHwnd) {
    if !guiHwnd
        return
    hoverHandles := []
    for controlHwnd, _ in App.buttonHoverStates {
        if (controlHwnd == guiHwnd
            || DllCall("user32\GetAncestor", "Ptr", controlHwnd, "UInt", 2, "Ptr") == guiHwnd)
            hoverHandles.Push(controlHwnd)
    }
    for controlHwnd in hoverHandles {
        if (App.pressedButtonHwnd == controlHwnd)
            CancelButtonPress()
        if (App.hoveredButtonHwnd == controlHwnd)
            App.hoveredButtonHwnd := 0
        App.buttonHoverStates.Delete(controlHwnd)
    }
    inputHandles := []
    for controlHwnd, _ in App.textInputCursorStates {
        if (controlHwnd == guiHwnd
            || DllCall("user32\GetAncestor", "Ptr", controlHwnd, "UInt", 2, "Ptr") == guiHwnd)
            inputHandles.Push(controlHwnd)
    }
    for controlHwnd in inputHandles
        App.textInputCursorStates.Delete(controlHwnd)
}

PruneTextInputCursorStates() {
    staleTextTargets := []
    for targetHwnd, textInputState in App.textInputCursorStates {
        if !DllCall("user32\IsWindow", "Ptr", targetHwnd, "Int")
            || !DllCall("user32\IsWindow", "Ptr", textInputState.editHwnd, "Int")
            staleTextTargets.Push(targetHwnd)
    }
    for targetHwnd in staleTextTargets
        App.textInputCursorStates.Delete(targetHwnd)
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

RegisterHoverButton(ctrl, normalColor := "333333", hoverColor := "", pressedColor := "") {
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
    App.buttonHoverStates[hWnd] := {
        ctrl: ctrl,
        normal: normalColor,
        hover: hoverColor,
        pressed: pressedColor,
        requestedPressed: requestedPressedColor,
        feedbackMode: ButtonFeedbackMode.Persistent
    }
}

RegisterButtonClick(ctrl, callback, feedbackMode := ButtonFeedbackMode.Persistent) {
    try hWnd := ctrl.Hwnd
    catch
        return
    if !hWnd || !App.buttonHoverStates.Has(hWnd)
        return
    state := App.buttonHoverStates[hWnd]
    state.clickCallback := callback
    state.feedbackMode := feedbackMode
    state.pressed := ResolveButtonFeedbackPressedColor(state.normal, state.hover,
        state.requestedPressed, feedbackMode)
    state.pendingClick := 0
    state.suppressClickUntil := 0
    ctrl.OnEvent("Click", HandleRegisteredButtonClick)
}

HandleRegisteredButtonClick(guiCtrlObj, eventArgs*) {
    try hWnd := guiCtrlObj.Hwnd
    catch
        return
    if !App.buttonHoverStates.Has(hWnd)
        return
    state := App.buttonHoverStates[hWnd]
    if !state.HasOwnProp("clickCallback")
        return

    if GetKeyState("LButton", "P") {
        ; Click 通知可能由 Text 伪按钮在按下阶段发出。此时只缓存回调，
        ; 没有通过 BeginButtonPress 验证的按下（例如不可用按钮）直接丢弃。
        if (App.pressedButtonHwnd != hWnd)
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
    if !App.buttonHoverStates.Has(hWnd)
        return
    state := App.buttonHoverStates[hWnd]
    if !IsHoverButtonAvailable(state)
        return
    pendingClick.callback.Call(pendingClick.args*)
}

RegisterHandCursorControl(ctrl) {
    try hWnd := ctrl.Hwnd
    catch
        return
    if hWnd
        App.buttonHoverStates[hWnd] := {ctrl: ctrl, cursorOnly: true}
}

SetHoverButtonColors(ctrl, normalColor, hoverColor := "", pressedColor := "") {
    try hWnd := ctrl.Hwnd
    catch
        return
    if !hWnd || !App.buttonHoverStates.Has(hWnd)
        return
    hoverColor := ResolveButtonHoverColor(normalColor, hoverColor)
    state := App.buttonHoverStates[hWnd]
    state.normal := normalColor
    state.hover := hoverColor
    state.requestedPressed := pressedColor
    state.pressed := ResolveButtonFeedbackPressedColor(normalColor, hoverColor,
        pressedColor, state.feedbackMode)
}

SetButtonBackground(ctrl, color) {
    try ctrl.Opt("Background" color)
    try ctrl.Redraw()
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
    pressedHwnd := App.pressedButtonHwnd
    if !pressedHwnd
        return
    App.pressedButtonHwnd := 0
    if App.buttonHoverStates.Has(pressedHwnd) {
        pressedState := App.buttonHoverStates[pressedHwnd]
        if pressedState.HasOwnProp("pendingClick")
            pressedState.pendingClick := 0
        if pressedState.HasOwnProp("suppressClickUntil")
            pressedState.suppressClickUntil := 0
        if !(pressedState.HasOwnProp("cursorOnly") && pressedState.cursorOnly)
            SetButtonBackground(pressedState.ctrl, pressedState.normal)
    }
    if (App.hoveredButtonHwnd == pressedHwnd)
        App.hoveredButtonHwnd := 0
    ReleaseButtonMouseCapture(pressedHwnd)
}

BeginButtonPress(hWnd) {
    if !App.buttonHoverStates.Has(hWnd)
        return
    state := App.buttonHoverStates[hWnd]
    if (state.HasOwnProp("cursorOnly") && state.cursorOnly)
        return
    if !IsHoverButtonAvailable(state)
        return
    if (App.pressedButtonHwnd && App.pressedButtonHwnd != hWnd)
        CancelButtonPress()
    if state.HasOwnProp("pendingClick")
        state.pendingClick := 0
    if state.HasOwnProp("suppressClickUntil")
        state.suppressClickUntil := 0
    App.pressedButtonHwnd := hWnd
    App.hoveredButtonHwnd := hWnd
    SetButtonBackground(state.ctrl, state.pressed)
    DllCall("user32\SetCapture", "Ptr", hWnd, "Ptr")
}

EndButtonPress() {
    pressedHwnd := App.pressedButtonHwnd
    if !pressedHwnd
        return
    App.pressedButtonHwnd := 0
    if !App.buttonHoverStates.Has(pressedHwnd) {
        SetTimer(ReleaseButtonMouseCapture.Bind(pressedHwnd), -1)
        if (App.hoveredButtonHwnd == pressedHwnd)
            App.hoveredButtonHwnd := 0
        return
    }
    state := App.buttonHoverStates[pressedHwnd]
    if (state.HasOwnProp("cursorOnly") && state.cursorOnly) {
        SetTimer(ReleaseButtonMouseCapture.Bind(pressedHwnd), -1)
        return
    }
    pendingClick := state.HasOwnProp("pendingClick") ? state.pendingClick : 0
    state.pendingClick := 0
    if IsPointerInsideButton(pressedHwnd) && IsHoverButtonAvailable(state) {
        App.hoveredButtonHwnd := pressedHwnd
        TrackButtonMouseLeave(pressedHwnd)
        SetButtonBackground(state.ctrl, state.hover)
        if pendingClick {
            state.suppressClickUntil := GetTickCount64() + 100
            SetTimer(RunDeferredButtonClick.Bind(pressedHwnd, pendingClick), -1)
        } else {
            SetTimer(ReleaseButtonMouseCapture.Bind(pressedHwnd), -1)
        }
        return
    }
    state.suppressClickUntil := 0
    SetTimer(ReleaseButtonMouseCapture.Bind(pressedHwnd), -1)
    if (App.hoveredButtonHwnd == pressedHwnd)
        App.hoveredButtonHwnd := 0
    SetButtonBackground(state.ctrl, state.normal)
}

CanHoverButton(state) {
    ; 删除/暂停在没有选中项目时只是灰色提示态，不显示可用按钮的悬浮反馈。
    if (state.ctrl == Main.btnDel || state.ctrl == Main.btnPause)
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
    if !App.hoveredButtonHwnd
        return
    if App.buttonHoverStates.Has(App.hoveredButtonHwnd) {
        state := App.buttonHoverStates[App.hoveredButtonHwnd]
        if !(state.HasOwnProp("cursorOnly") && state.cursorOnly)
            SetButtonBackground(state.ctrl, state.normal)
    }
    App.hoveredButtonHwnd := 0
}

UpdateButtonHover(hWnd) {
    nowTicks := GetTickCount64()
    if (!App.hoverPruneTicks || nowTicks - App.hoverPruneTicks >= 1000) {
        stale := []
        for registeredHwnd, state in App.buttonHoverStates {
            if !DllCall("user32\IsWindow", "Ptr", registeredHwnd, "Int")
                stale.Push(registeredHwnd)
        }
        for registeredHwnd in stale {
            if (App.pressedButtonHwnd == registeredHwnd)
                App.pressedButtonHwnd := 0
            if (App.hoveredButtonHwnd == registeredHwnd)
                App.hoveredButtonHwnd := 0
            App.buttonHoverStates.Delete(registeredHwnd)
        }
        App.hoverPruneTicks := nowTicks
    }

    if App.pressedButtonHwnd {
        pressedHwnd := App.pressedButtonHwnd
        if (hWnd != pressedHwnd || !App.buttonHoverStates.Has(pressedHwnd))
            return
        pressedState := App.buttonHoverStates[pressedHwnd]
        if !IsPointerInsideButton(pressedHwnd) {
            if (App.hoveredButtonHwnd == pressedHwnd) {
                App.hoveredButtonHwnd := 0
                SetButtonBackground(pressedState.ctrl, pressedState.normal)
            }
            return
        }
        if (App.hoveredButtonHwnd != pressedHwnd) {
            App.hoveredButtonHwnd := pressedHwnd
            SetButtonBackground(pressedState.ctrl, pressedState.pressed)
        }
        return
    }

    if (App.hoveredButtonHwnd == hWnd)
        return

    RestoreHoveredButton()
    if !App.buttonHoverStates.Has(hWnd)
        return
    state := App.buttonHoverStates[hWnd]
    if !IsHoverButtonAvailable(state)
        return
    SetHandCursor()
    App.hoveredButtonHwnd := hWnd
    TrackButtonMouseLeave(hWnd)
    if (state.HasOwnProp("cursorOnly") && state.cursorOnly)
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

GetFileIconIndex(filePath, IL_ID) {
    if !IL_ID
        return 0
    cacheKey := String(IL_ID) "_" filePath
    if App.iconCache.Has(cacheKey)
        return App.iconCache[cacheKey]

    if SubStr(filePath, 1, 8) == "Service:" {
        largeIcon := 0
        smallIcon := 0
        shellIconPath := A_WinDir "\System32\shell32.dll"
        try DllCall("shell32\ExtractIconExW", "WStr", shellIconPath,
            "Int", 72, "Ptr*", &largeIcon, "Ptr*", &smallIcon,
            "UInt", 1, "UInt")
        sourceIcon := largeIcon ? largeIcon : smallIcon
        idx := sourceIcon ? AddIconToImageList(IL_ID, sourceIcon) : 0
        if largeIcon
            DllCall("user32\DestroyIcon", "Ptr", largeIcon)
        if smallIcon
            DllCall("user32\DestroyIcon", "Ptr", smallIcon)
        if !idx
            idx := IL_Add(IL_ID, "shell32.dll", 72)
        if idx
            App.iconCache[cacheKey] := idx
        return idx
    }

    if IL_ID == Main.appIcons {
        useHighQuality := false
        preferredSource := GetPreferredMainIcon(filePath, &useHighQuality)
        if preferredSource {
            idx := AddIconToImageList(IL_ID, preferredSource, useHighQuality)
            DllCall("user32\DestroyIcon", "Ptr", preferredSource)
            if idx {
                App.iconCache[cacheKey] := idx
                return idx
            }
        }
    }

    sfi_size := A_PtrSize + 688
    sfi := Buffer(sfi_size)
    flags := 0x100 ; SHGFI_ICON
    attr := 0
    if !FileExist(filePath) {
        flags |= Win32.SHGFI_USEFILEATTRIBUTES
        attr := Win32.FILE_ATTRIBUTE_NORMAL
    }
    
    if DllCall("shell32\SHGetFileInfoW", "Str", filePath, "UInt", attr, "Ptr", sfi, "UInt", sfi_size, "UInt", flags) {
        hIcon := NumGet(sfi, 0, "Ptr")
        if hIcon {
            idx := AddIconToImageList(IL_ID, hIcon)
            DllCall("user32\DestroyIcon", "Ptr", hIcon)
            if idx {
                App.iconCache[cacheKey] := idx
                return idx
            }
        }
    }
    
    idx := IL_Add(IL_ID, filePath, 1)
    if idx
        App.iconCache[cacheKey] := idx
    return idx
}

; ============================================================================
; 16. GUI 模块类
; 每个短生命周期窗口只把原生 Gui/控件保存在自己的实例中，并在 Close() 中
; 统一销毁和清空，避免事件回调继续命中已经销毁的旧控件。
; ============================================================================
class GuiModuleRegistry {
    __New(mainGui) {
        this.environment := EnvironmentSettingsDialog(mainGui)
        this.maintenance := MaintenanceSettingsDialog(mainGui)
        this.log := LogWindow(mainGui)
        this.settings := SettingsWindow(mainGui)
        this.help := HelpWindow(mainGui)
        this.addItem := AddItemDialog(mainGui)
        this.tooltip := DarkTooltipWindow()
    }

    HideTransientWindows() {
        this.tooltip.Hide()
        this.addItem.serviceSelector.tooltip.Hide()
        this.addItem.search.tooltip.Hide()
    }
}

class WindowHierarchy {
    static ownerLocks := Map()

    static IsGuiAlive(guiObj) {
        if !guiObj || Type(guiObj) != "Gui"
            return false
        try return DllCall("user32\IsWindow", "Ptr", guiObj.Hwnd, "Int") != 0
        catch
            return false
    }

    static Acquire(ownerGui, childHwnd := 0) {
        if !this.IsGuiAlive(ownerGui)
            return ""
        ownerHwnd := ownerGui.Hwnd
        this.PruneOwner(ownerGui)
        if this.ownerLocks.Has(ownerHwnd) {
            entry := this.ownerLocks[ownerHwnd]
            if (entry.gui == ownerGui) {
                entry.count++
                if childHwnd
                    entry.children[childHwnd] := true
                return {ownerHwnd: ownerHwnd, childHwnd: childHwnd, released: false}
            }
            this.ownerLocks.Delete(ownerHwnd)
        }
        wasEnabled := DllCall("user32\IsWindowEnabled", "Ptr", ownerHwnd, "Int") != 0
        entry := {gui: ownerGui, count: 1, restoreEnabled: wasEnabled, children: Map()}
        if childHwnd
            entry.children[childHwnd] := true
        this.ownerLocks[ownerHwnd] := entry
        if wasEnabled {
            try ownerGui.Opt("+Disabled")
            catch {
                this.ownerLocks.Delete(ownerHwnd)
                return ""
            }
        }
        return {ownerHwnd: ownerHwnd, childHwnd: childHwnd, released: false}
    }

    static Release(lease) {
        if !lease || lease.released
            return ""
        lease.released := true
        ownerHwnd := lease.ownerHwnd
        if !this.ownerLocks.Has(ownerHwnd)
            return ""
        entry := this.ownerLocks[ownerHwnd]
        if lease.childHwnd && entry.children.Has(lease.childHwnd)
            entry.children.Delete(lease.childHwnd)
        entry.count--
        if (entry.count > 0)
            return {mode: "child", owner: entry.gui}
        this.ownerLocks.Delete(ownerHwnd)
        wasVisible := DllCall("user32\IsWindowVisible", "Ptr", ownerHwnd, "Int") != 0
        wasMinimized := DllCall("user32\IsIconic", "Ptr", ownerHwnd, "Int") != 0
        if entry.restoreEnabled && this.IsGuiAlive(entry.gui)
            try entry.gui.Opt("-Disabled")
        return {
            mode: "owner",
            owner: entry.gui,
            ownerHwnd: ownerHwnd,
            activate: entry.restoreEnabled && wasVisible && !wasMinimized
        }
    }

    static CompleteClose(closeContext) {
        if !closeContext
            return
        if (closeContext.mode == "child") {
            this.ActivateTopOwned(closeContext.owner)
            return
        }
        if (closeContext.mode != "owner" || !closeContext.activate)
            return
        if !this.IsGuiAlive(closeContext.owner)
            return
        ownerHwnd := closeContext.ownerHwnd
        if !DllCall("user32\IsWindowVisible", "Ptr", ownerHwnd, "Int")
            || DllCall("user32\IsIconic", "Ptr", ownerHwnd, "Int")
            return
        DllCall("user32\SetForegroundWindow", "Ptr", ownerHwnd, "Int")
        DllCall("user32\SetActiveWindow", "Ptr", ownerHwnd, "Ptr")
    }

    static PruneOwner(ownerGui) {
        if !ownerGui || Type(ownerGui) != "Gui"
            return false
        try ownerHwnd := ownerGui.Hwnd
        catch
            return false
        if !this.ownerLocks.Has(ownerHwnd)
            return false
        entry := this.ownerLocks[ownerHwnd]
        if (entry.gui != ownerGui || !this.IsGuiAlive(ownerGui)) {
            this.ownerLocks.Delete(ownerHwnd)
            return false
        }
        staleChildren := []
        for childHwnd in entry.children {
            if !DllCall("user32\IsWindow", "Ptr", childHwnd, "Int")
                || DllCall("user32\GetWindow", "Ptr", childHwnd, "UInt", 4, "Ptr") != ownerHwnd ; GW_OWNER
                staleChildren.Push(childHwnd)
        }
        for childHwnd in staleChildren {
            entry.children.Delete(childHwnd)
            entry.count--
        }
        if (entry.count > 0)
            return true
        this.ownerLocks.Delete(ownerHwnd)
        wasVisible := DllCall("user32\IsWindowVisible", "Ptr", ownerHwnd, "Int") != 0
        wasMinimized := DllCall("user32\IsIconic", "Ptr", ownerHwnd, "Int") != 0
        if entry.restoreEnabled && this.IsGuiAlive(entry.gui)
            try entry.gui.Opt("-Disabled")
        this.CompleteClose({
            mode: "owner",
            owner: entry.gui,
            ownerHwnd: ownerHwnd,
            activate: entry.restoreEnabled && wasVisible && !wasMinimized
        })
        return false
    }

    static IsOwnerLocked(ownerGui) {
        if !this.IsGuiAlive(ownerGui)
            return false
        return this.PruneOwner(ownerGui)
    }

    static ActivateTopOwned(ownerGui) {
        if !this.IsGuiAlive(ownerGui)
            return false
        this.PruneOwner(ownerGui)
        currentHwnd := ownerGui.Hwnd
        Loop 16 {
            if !this.ownerLocks.Has(currentHwnd)
                break
            entry := this.ownerLocks[currentHwnd]
            this.PruneOwner(entry.gui)
            if !this.ownerLocks.Has(currentHwnd)
                break
            entry := this.ownerLocks[currentHwnd]
            nextHwnd := 0
            activePopup := DllCall("user32\GetLastActivePopup", "Ptr", currentHwnd, "Ptr")
            if entry.children.Has(activePopup)
                && DllCall("user32\IsWindowVisible", "Ptr", activePopup, "Int")
                nextHwnd := activePopup
            if !nextHwnd {
                for childHwnd in entry.children {
                    if DllCall("user32\IsWindowVisible", "Ptr", childHwnd, "Int") {
                        nextHwnd := childHwnd
                        break
                    }
                }
            }
            if !nextHwnd
                break
            currentHwnd := nextHwnd
        }
        if (currentHwnd == ownerGui.Hwnd)
            return false
        if !DllCall("user32\IsWindowVisible", "Ptr", currentHwnd, "Int")
            return false
        try WinActivate("ahk_id " currentHwnd)
        return true
    }
}

class ManagedWindow {
    gui := ""
    ownerLease := ""

    IsOpen() {
        if !this.gui
            return false
        try hwnd := this.gui.Hwnd
        catch {
            hwnd := 0
        }
        if hwnd && DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
            return true
        this.gui := ""
        closeContext := this.ReleaseOwner()
        try {
            if hwnd
                try ReleaseWindowIcons(hwnd)
        } finally WindowHierarchy.CompleteClose(closeContext)
        return false
    }

    ShowExisting() {
        if !this.IsOpen()
            return false
        if WindowHierarchy.IsOwnerLocked(this.gui) {
            WindowHierarchy.ActivateTopOwned(this.gui)
            return true
        }
        this.gui.Show()
        return true
    }

    CreateOwnedGui(ownerGui, options, title) {
        try RestoreHoveredButton()
        if IsSet(GuiModules)
            try GuiModules.HideTransientWindows()
        try {
            this.gui := Gui(Trim("+Owner" ownerGui.Hwnd " " options), title)
        } catch as createErr {
            this.gui := ""
            throw createErr
        }
        this.ownerLease := WindowHierarchy.Acquire(ownerGui, this.gui.Hwnd)
        if !this.ownerLease {
            this.DestroyGui()
            return false
        }
        return true
    }

    ReleaseOwner() {
        if this.ownerLease {
            closeContext := WindowHierarchy.Release(this.ownerLease)
            this.ownerLease := ""
            return closeContext
        }
        return ""
    }

    DestroyGui() {
        ; 标准模态关闭顺序：先恢复直接上级，再销毁下级，最后交还前台焦点。
        closeContext := this.ReleaseOwner()
        try {
            if this.gui {
                guiObj := this.gui
                this.gui := ""
                try hwnd := guiObj.Hwnd
                catch {
                    hwnd := 0
                }
                if hwnd
                    UnregisterGuiControls(hwnd)
                try guiObj.Destroy()
                if hwnd
                    ReleaseWindowIcons(hwnd)
            }
        } finally WindowHierarchy.CompleteClose(closeContext)
    }
}

class MaintenanceSettingsDialog extends ManagedWindow {
    __New(mainGui) {
        this.owner := mainGui
        this.path := ""
        this.state := ""
        this.enableCheck := ""
        this.rootEdit := ""
        this.detectionEdit := ""
        this.stableEdit := ""
        this.maxWaitEdit := ""
        this.learnedEdit := ""
        this.learnedActors := []
        this.learnedActorsCleared := false
    }

    Show(path, stateObj) {
        if this.ShowExisting()
            return
        this.path := path
        this.state := stateObj
        this.learnedActors := []
        this.learnedActorsCleared := false
        for signature in stateObj.MaintenanceConfig.LearnedActors
            this.learnedActors.Push(signature)
        if !this.CreateOwnedGui(this.owner, "-MinimizeBox -MaximizeBox", "软件升级保护")
            return
        try {
            SetDarkTitleBar(this.gui.Hwnd)
            SetWindowIcon(this.gui.Hwnd, A_ScriptDir "\watchdog.ico")
            this.gui.BackColor := "1E1E1E"
            this.gui.SetFont("s10 cWhite", "Microsoft YaHei")

            this.gui.Add("Text", "x20 y14 w500 h20 BackgroundTrans", "守护目标:")
            targetInput := AddCenteredSingleLineEdit(this.gui, 20, 38, 500, 26, path, "ReadOnly", "2A2A2A")
            RegisterTextInputControl(targetInput.Edit, true)
            SetDarkControl(targetInput.Edit.Hwnd)

            this.enableCheck := this.gui.Add("CheckBox", "x20 y76 w320 h24", "自动识别升级并保护启动过程")
            this.enableCheck.Value := stateObj.MaintenanceConfig.Enabled ? 1 : 0
            SetDarkControl(this.enableCheck.Hwnd)
            RegisterHandCursorControl(this.enableCheck)

            this.gui.Add("Text", "x20 y108 w300 h20 BackgroundTrans", "安装足迹目录:")
            rootInput := AddCenteredSingleLineEdit(this.gui, 20, 132, 388, 26,
                stateObj.MaintenanceConfig.InstallRoot, "", "333333")
            this.rootEdit := rootInput.Edit
            btnBrowse := this.gui.Add("Text", "x418 y132 w48 h26 Center 0x200 Background333333 cWhite", "浏览")
            btnAutoRoot := this.gui.Add("Text", "x476 y132 w44 h26 Center 0x200 Background333333 cWhite", "自动")

            this.gui.Add("Text", "x20 y176 w145 h20 BackgroundTrans", "退出检测窗口（秒）:")
            detectionInput := AddCenteredSingleLineEdit(this.gui, 20, 200, 105, 26,
                stateObj.MaintenanceConfig.DetectionSeconds, "Number")
            this.detectionEdit := detectionInput.Edit
            this.gui.Add("Text", "x190 y176 w145 h20 BackgroundTrans", "文件稳定等待（秒）:")
            stableInput := AddCenteredSingleLineEdit(this.gui, 190, 200, 105, 26,
                stateObj.MaintenanceConfig.StableSeconds, "Number")
            this.stableEdit := stableInput.Edit
            this.gui.Add("Text", "x360 y176 w160 h20 BackgroundTrans", "最长升级等待（秒）:")
            maxWaitInput := AddCenteredSingleLineEdit(this.gui, 360, 200, 105, 26,
                stateObj.MaintenanceConfig.MaxWaitSeconds, "Number")
            this.maxWaitEdit := maxWaitInput.Edit

            this.gui.Add("Text", "x20 y246 w240 h20 BackgroundTrans", "已自动学习的更新程序特征:")
            btnClearLearned := this.gui.Add("Text", "x420 y242 w100 h26 Center 0x200 Background333333 cWhite", "清除记录")
            this.learnedEdit := this.gui.Add("Edit",
                "x20 y270 w500 h70 Background252526 cD8D8D8 -E0x200 ReadOnly Multi VScroll",
                this.GetLearnedText())
            RegisterTextInputControl(this.learnedEdit, true)
            SetDarkControl(this.learnedEdit.Hwnd)

            this.gui.Add("Text", "x20 y352 w500 h24 0x200 BackgroundTrans cAFAFAF",
                this.GetStatusText())

            btnSaveX := IsMaintenanceBlocking(stateObj) ? 282 : 185
            btnCancelX := IsMaintenanceBlocking(stateObj) ? 372 : 275
            if IsMaintenanceBlocking(stateObj) {
                btnResume := this.gui.Add("Text",
                    "x50 y390 w210 h28 Center 0x200 Background6B6244 cWhite",
                    "结束升级等待并恢复守护")
                RegisterHoverButton(btnResume, "6B6244")
                RegisterButtonClick(btnResume, ObjBindMethod(this, "ResumeProtection"),
                    ButtonFeedbackMode.Dismissive)
            }
            btnSave := this.gui.Add("Text", "x" btnSaveX " y390 w80 h28 Center 0x200 Background0078D7 cWhite", "保存")
            btnCancel := this.gui.Add("Text", "x" btnCancelX " y390 w80 h28 Center 0x200 Background333333 cWhite", "取消")

            for editControl in [this.rootEdit, this.detectionEdit, this.stableEdit, this.maxWaitEdit]
                SetDarkControl(editControl.Hwnd)
            RegisterHoverButton(btnBrowse, "333333")
            RegisterHoverButton(btnAutoRoot, "333333")
            RegisterHoverButton(btnClearLearned, "333333")
            RegisterHoverButton(btnSave, "0078D7")
            RegisterHoverButton(btnCancel, "333333")
            RegisterButtonClick(btnBrowse, ObjBindMethod(this, "BrowseRoot"))
            RegisterButtonClick(btnAutoRoot, ObjBindMethod(this, "UseAutomaticRoot"))
            RegisterButtonClick(btnClearLearned, ObjBindMethod(this, "ClearLearned"))
            RegisterButtonClick(btnSave, ObjBindMethod(this, "Save"), ButtonFeedbackMode.Dismissive)
            RegisterButtonClick(btnCancel, ObjBindMethod(this, "Close"), ButtonFeedbackMode.Dismissive)
            this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
            this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
            this.gui.Show("w540 h435")
        } catch as openErr {
            this.Close()
            throw openErr
        }
    }

    GetLearnedText() {
        if !this.learnedActors.Length
            return "尚未从真实升级过程学习到更新程序特征。"
        lines := []
        for signature in this.learnedActors {
            if (SubStr(signature, 1, 2) == "P:")
                lines.Push("完整路径：" SubStr(signature, 3))
            else if (SubStr(signature, 1, 2) == "N:")
                lines.Push("进程名称：" SubStr(signature, 3))
        }
        text := ""
        for index, line in lines
            text .= (index > 1 ? "`r`n" : "") line
        return text
    }

    GetStatusText() {
        if !this.state
            return ""
        if this.state.ExplicitMaintenance
            return "当前状态：显式升级维护已开始，正在等待结束命令"
        switch this.state.MaintenanceMode {
            case "Arbitrating":
                return "当前状态：正在判断本次退出是否由升级引起"
            case "Updating":
                return "当前状态：已暂停自动启动，正在等待升级完成"
            case "Stabilizing":
                return "当前状态：升级活动已结束，正在确认程序文件稳定"
            case "Recovering":
                return "当前状态：已从上次运行恢复未完成的升级保护"
            case "TimedOut":
                return "当前状态：升级等待超时，需要确认后恢复"
            default:
                return "当前状态：正常守护"
        }
    }

    BrowseRoot(*) {
        if !this.IsOpen()
            return
        this.gui.Opt("+OwnDialogs")
        initialRoot := DirExist(this.rootEdit.Value) ? this.rootEdit.Value : GetDefaultMaintenanceRoot(this.path)
        selected := FileSelect("D", initialRoot, "选择软件安装目录")
        if selected && this.IsOpen()
            this.rootEdit.Value := selected
    }

    UseAutomaticRoot(*) {
        if this.IsOpen()
            this.rootEdit.Value := GetDefaultMaintenanceRoot(this.path)
    }

    ClearLearned(*) {
        if !this.IsOpen()
            return
        this.learnedActors := []
        this.learnedActorsCleared := true
        this.learnedEdit.Value := this.GetLearnedText()
        ScheduleHideTextCaret(this.learnedEdit.Hwnd)
    }

    ResumeProtection(*) {
        if !this.IsOpen() || !this.state
            return
        path := this.path
        stateObj := this.state
        ResetMaintenanceSession(path, stateObj, false)
        stateObj.SafetyFingerprint := GetTargetFileFingerprint(path)
        stateObj.SafetyStableSince := 0
        stateObj.LastFileActivityTicks := GetTickCount64()
        SaveMaintenanceJournal()
        EnsureMaintenanceWatcher(path, stateObj)
        UpdateState(path, "初始化...")
        this.Close()
        ScheduleRestart(path, 200)
        LogMsg("用户结束了升级等待，重新执行安全启动检查: " path)
    }

    Save(*) {
        if !this.IsOpen() || !this.state
            return
        path := this.path
        enableProtection := this.enableCheck.Value != 0
        rootPath := NormalizeMaintenanceRoot(this.rootEdit.Value, path)
        detectionSeconds := ParseBoundedInteger(this.detectionEdit.Value, 2, 120)
        stableSeconds := ParseBoundedInteger(this.stableEdit.Value, 2, 300)
        maxWaitSeconds := ParseBoundedInteger(this.maxWaitEdit.Value, 60, 86400)
        maintenanceSubject := GetMaintenanceSubjectPath(path)
        if enableProtection && (!IsMaintenanceSupportedTarget(path) || !DirExist(rootPath)
            || !PathIsWithinRoot(maintenanceSubject, rootPath)) {
            ShowDarkMsgBox("升级保护仅支持具有有效完整路径的程序或脚本，安装足迹目录必须存在并包含目标文件。", "设置无效", "Error", this.gui)
            return
        }
        if !detectionSeconds || !stableSeconds || !maxWaitSeconds || maxWaitSeconds <= stableSeconds {
            ShowDarkMsgBox("时间设置无效。`n`n退出检测窗口：2-120 秒`n文件稳定等待：2-300 秒`n最长升级等待：60-86400 秒，且必须大于稳定等待时间", "设置无效", "Error", this.gui)
            return
        }
        stateObj := this.state
        learnedActorsToSave := []
        learnedSeen := Map()
        learnedSeen.CaseSense := "Off"
        for signature in this.learnedActors {
            if !learnedSeen.Has(signature) {
                learnedSeen[signature] := true
                learnedActorsToSave.Push(signature)
            }
        }
        ; 窗口打开期间后台可能学到新特征；除非用户明确清空，否则合并实时值。
        if !this.learnedActorsCleared {
            for signature in stateObj.MaintenanceConfig.LearnedActors {
                if !learnedSeen.Has(signature) {
                    learnedSeen[signature] := true
                    learnedActorsToSave.Push(signature)
                }
            }
        }
        priorInstallRoot := stateObj.MaintenanceConfig.InstallRoot
        defaultRoot := GetDefaultMaintenanceRoot(path)
        CommitUndoState()
        stateObj.MaintenanceConfig := NormalizeMaintenanceConfig({
            Enabled: enableProtection,
            InstallRoot: rootPath,
            RootIsCustom: GetCanonicalPath(rootPath) != GetCanonicalPath(defaultRoot),
            DetectionSeconds: detectionSeconds,
            StableSeconds: stableSeconds,
            MaxWaitSeconds: maxWaitSeconds,
            LearnedActors: learnedActorsToSave
        }, path)
        rootChanged := GetCanonicalPath(priorInstallRoot) != GetCanonicalPath(rootPath)
        if !enableProtection {
            CleanupTargetMaintenance(path, stateObj, true)
            if stateObj.Enabled {
                UpdateState(path, "初始化...")
                ScheduleRestart(path, 200)
            }
        } else {
            if rootChanged
                CloseMaintenanceWatcher(stateObj)
            stateObj.SafetyFingerprint := GetTargetFileFingerprint(path)
            stateObj.SafetyStableSince := GetTickCount64()
            EnsureMaintenanceWatcher(path, stateObj)
            SaveMaintenanceJournal()
        }
        SaveAppsToIni()
        this.Close()
        LogMsg("已更新软件升级保护设置: " path)
    }

    Close(*) {
        this.DestroyGui()
        this.path := ""
        this.state := ""
        this.enableCheck := ""
        this.rootEdit := ""
        this.detectionEdit := ""
        this.stableEdit := ""
        this.maxWaitEdit := ""
        this.learnedEdit := ""
        this.learnedActors := []
        this.learnedActorsCleared := false
    }
}

class EnvironmentSettingsDialog extends ManagedWindow {
    __New(mainGui) {
        this.owner := mainGui
        this.path := ""
        this.state := ""
        this.workDirEdit := ""
        this.argsEdit := ""
        this.envEdit := ""
        this.autoResolveCheck := ""
        this.resolvedTargetEdit := ""
        this.resolvedTargetBrowse := ""
    }

    Show(path, stateObj) {
        if this.ShowExisting()
            return

        this.path := path
        this.state := stateObj
        if !this.CreateOwnedGui(this.owner, "", "高级运行环境设置")
            return
        try {
        SetDarkTitleBar(this.gui.Hwnd)
        SetWindowIcon(this.gui.Hwnd, A_ScriptDir "\watchdog.ico")
        this.gui.BackColor := "1E1E1E"
        this.gui.SetFont("s10 cWhite", "Microsoft YaHei")

        this.gui.Add("Text", "x20 y20 w460 h20 BackgroundTrans", "目标程序: " path)
        SplitPath(path, , , &pathExtension)
        isShortcut := StrLower(pathExtension) == "lnk"
        verticalOffset := isShortcut ? 40 : 0
        if isShortcut {
            isManual := stateObj.HasOwnProp("ResolvedTargetManual") && stateObj.ResolvedTargetManual
            this.autoResolveCheck := this.gui.Add("CheckBox", "x20 y56 w120 h25", "自动识别进程")
            this.autoResolveCheck.Value := isManual ? 0 : 1
            resolvedInput := AddCenteredSingleLineEdit(this.gui, 150, 55, 280, 25,
                stateObj.HasOwnProp("ResolvedTarget") ? stateObj.ResolvedTarget : "", "", "333333")
            this.resolvedTargetEdit := resolvedInput.Edit
            this.resolvedTargetBrowse := this.gui.Add("Button", "x440 y55 w40 h25 Background555555 cWhite", "...")
            this.resolvedTargetEdit.Enabled := isManual
            this.resolvedTargetBrowse.Enabled := isManual
            SetDarkControl(this.autoResolveCheck.Hwnd)
            SetDarkControl(this.resolvedTargetEdit.Hwnd)
            SetDarkControl(this.resolvedTargetBrowse.Hwnd)
            RegisterHandCursorControl(this.autoResolveCheck)
            RegisterTextInputControl(this.resolvedTargetEdit)
            RegisterHoverButton(this.resolvedTargetBrowse, "555555")
            this.autoResolveCheck.OnEvent("Click", ObjBindMethod(this, "ToggleResolvedTargetMode"))
            RegisterButtonClick(this.resolvedTargetBrowse, ObjBindMethod(this, "BrowseResolvedTarget"))
        }

        this.gui.Add("Text", "x20 y" (60 + verticalOffset) " w120 h20 BackgroundTrans", "工作目录（CWD）:")
        workDirInput := AddCenteredSingleLineEdit(this.gui, 150, 55 + verticalOffset, 280, 25, stateObj.HasOwnProp("WorkDir") ? stateObj.WorkDir : "", "", "333333")
        this.workDirEdit := workDirInput.Edit
        btnBrowse := this.gui.Add("Button", "x440 y" (55 + verticalOffset) " w40 h25 Background555555 cWhite", "...")

        this.gui.Add("Text", "x20 y" (100 + verticalOffset) " w120 h20 BackgroundTrans", "启动参数（Args）:")
        argsInput := AddCenteredSingleLineEdit(this.gui, 150, 95 + verticalOffset, 330, 25, stateObj.HasOwnProp("Args") ? stateObj.Args : "", "", "333333")
        this.argsEdit := argsInput.Edit

        this.gui.Add("Text", "x20 y" (140 + verticalOffset) " w250 h20 BackgroundTrans", "环境变量（每行一个 KEY=VALUE）:")
        this.envEdit := this.gui.Add("Edit", "x20 y" (165 + verticalOffset) " w460 h100 Background333333 cWhite -E0x200 Multi VScroll", stateObj.HasOwnProp("EnvVars") ? stateObj.EnvVars : "")
        RegisterTextInputControl(this.envEdit)

        btnSave := this.gui.Add("Button", "x175 y" (295 + verticalOffset) " w70 h30 Background0078D7 cWhite Default", "保存")
        btnCancel := this.gui.Add("Button", "x255 y" (295 + verticalOffset) " w70 h30 Background555555 cWhite", "取消")
        RegisterHoverButton(btnBrowse, "555555")
        RegisterHoverButton(btnSave, "0078D7")
        RegisterHoverButton(btnCancel, "555555")

        SetDarkControl(this.envEdit.Hwnd)
        SetDarkControl(this.workDirEdit.Hwnd)
        SetDarkControl(this.argsEdit.Hwnd)
        SetDarkControl(btnBrowse.Hwnd)
        SetDarkControl(btnSave.Hwnd)
        SetDarkControl(btnCancel.Hwnd)
        RegisterButtonClick(btnBrowse, ObjBindMethod(this, "BrowseWorkDir"))
        RegisterButtonClick(btnSave, ObjBindMethod(this, "Save"), ButtonFeedbackMode.Dismissive)
        RegisterButtonClick(btnCancel, ObjBindMethod(this, "Close"), ButtonFeedbackMode.Dismissive)
        this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
        this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
        this.gui.Show("w500 h" (340 + verticalOffset))
        } catch as openErr {
            this.Close()
            throw openErr
        }
    }

    BrowseWorkDir(*) {
        if !this.IsOpen()
            return
        this.gui.Opt("+OwnDialogs")
        selected := FileSelect("D", this.workDirEdit.Value != "" ? this.workDirEdit.Value : "", "选择工作目录")
        if selected && this.IsOpen()
            this.workDirEdit.Value := selected
    }

    ToggleResolvedTargetMode(*) {
        if !this.IsOpen() || !this.resolvedTargetEdit
            return
        manualMode := this.autoResolveCheck.Value == 0
        this.resolvedTargetEdit.Enabled := manualMode
        this.resolvedTargetBrowse.Enabled := manualMode
        if !manualMode {
            automaticTarget := GetShortcutEffectiveTargetPath(this.path, true)
            this.resolvedTargetEdit.Value := automaticTarget
        }
    }

    BrowseResolvedTarget(*) {
        if !this.IsOpen() || !this.resolvedTargetEdit.Enabled
            return
        this.gui.Opt("+OwnDialogs")
        selected := FileSelect(1, this.resolvedTargetEdit.Value,
            "选择快捷方式对应的真实进程", "程序或脚本 (*.exe; *.com; *.ahk; *.py; *.pyw; *.js; *.vbs; *.ps1; *.bat; *.cmd)")
        if selected && this.IsOpen()
            this.resolvedTargetEdit.Value := selected
    }

    Save(*) {
        if !this.IsOpen() || !this.state
            return
        path := this.path
        resolvedTarget := this.state.HasOwnProp("ResolvedTarget") ? this.state.ResolvedTarget : ""
        resolvedTargetManual := false
        resolutionSource := this.state.HasOwnProp("ShortcutTargetSource")
            ? this.state.ShortcutTargetSource : ""
        if this.resolvedTargetEdit {
            resolvedTargetManual := this.autoResolveCheck.Value == 0
            if resolvedTargetManual {
                resolvedTarget := NormalizeTargetPath(this.resolvedTargetEdit.Value)
                if (!IsPotentialShortcutProcessTarget(resolvedTarget) || !FileExist(resolvedTarget)
                    || !IsUsableShortcutTarget(resolvedTarget)) {
                    ShowDarkMsgBox("请选择现有且可执行的真实程序或脚本路径。", "真实进程路径无效", "Error", this.gui)
                    return
                }
                resolutionSource := "用户指定"
            } else {
                resolvedTarget := ResolveShortcutTargetForState(path, "", &resolutionSource)
            }
            if (resolvedTarget != "") {
                conflictPath := FindIdentityConflict(resolvedTarget, path)
                if (conflictPath != "") {
                    ShowDarkMsgBox("该真实进程已由其他监控项守护。", "监控目标重复", "Error", this.gui)
                    return
                }
            }
        }
        CommitUndoState()
        identityChanged := !PathsEquivalent(this.state.ResolvedTarget, resolvedTarget)
            || this.state.ResolvedTargetManual != resolvedTargetManual
        this.state.WorkDir := Trim(this.workDirEdit.Value)
        this.state.Args := Trim(this.argsEdit.Value)
        this.state.EnvVars := Trim(this.envEdit.Value)
        this.state.ResolvedTarget := resolvedTarget
        this.state.ResolvedTargetManual := resolvedTargetManual
        this.state.ShortcutTargetSource := resolutionSource
        this.state.ShortcutResolveCheckedTicks := GetTickCount64()
        this.state.OneShot := IsOneShotTarget(path, resolvedTarget)
        if identityChanged {
            ClearStateProcessIdentity(this.state)
            if (!this.state.MaintenanceConfig.RootIsCustom && resolvedTarget != "") {
                SplitPath(resolvedTarget, , &resolvedDirectory)
                this.state.MaintenanceConfig.InstallRoot := NormalizeMaintenanceRoot(resolvedDirectory)
                CloseMaintenanceWatcher(this.state)
                EnsureMaintenanceWatcher(path, this.state)
            }
            refreshedFingerprint := GetTargetFileFingerprint(path)
            this.state.SafetyFingerprint := refreshedFingerprint
            this.state.MaintenanceBaselineFingerprint := refreshedFingerprint
            this.state.SafetyStableSince := GetTickCount64()
            this.state.MaintenanceReadyCheckedTicks := 0
        }
        SaveAppsToIni()
        this.Close()
        LogMsg("已更新高级运行环境设置: " path)
    }

    Close(*) {
        this.DestroyGui()
        this.workDirEdit := ""
        this.argsEdit := ""
        this.envEdit := ""
        this.autoResolveCheck := ""
        this.resolvedTargetEdit := ""
        this.resolvedTargetBrowse := ""
        this.path := ""
        this.state := ""
    }
}

class AddItemDialog extends ManagedWindow {
    __New(mainGui) {
        this.owner := mainGui
        this.edit := ""
        this.serviceSelector := ServiceSelector(this)
        this.search := ApplicationSearchDialog(this)
        this.searchButton := ""
        this.browseButton := ""
        this.okButton := ""
        this.cancelButton := ""
        this.batchStatus := ""
        this.batchWorkerPid := 0
        this.batchWorkerCreationIdentity := ""
        this.batchOutputPath := ""
        this.batchRootQueue := []
        this.batchPendingPaths := []
        this.batchPendingIndex := 0
        this.batchAddedCount := 0
        this.batchTruncated := false
        this.batchPollTimer := ObjBindMethod(this, "PollBatchImport")
        this.batchConsumeTimer := ObjBindMethod(this, "ConsumeBatchImport")
    }

    Show(*) {
        if this.ShowExisting()
            return

        if !this.CreateOwnedGui(this.owner, "-MinimizeBox -MaximizeBox", "添加监控项")
            return
        try {
        this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
        this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
        SetDarkTitleBar(this.gui.Hwnd)
        SetWindowIcon(this.gui.Hwnd, A_ScriptDir "\watchdog.ico")
        this.gui.BackColor := "1E1E1E"
        this.gui.SetFont("s10 cWhite", "Microsoft YaHei")

        this.gui.Add("Text", "x20 y15 w480 BackgroundTrans", "请输入进程名、脚本路径、服务名称，或通过下方菜单选择:`n（支持批量导入文件夹内的程序，或直接导入 Windows 后台服务）")
        inputControl := AddCenteredSingleLineEdit(this.gui, 20, 65, 480, 26)
        this.edit := inputControl.Edit
        SetDarkControl(this.edit.Hwnd)

        this.batchStatus := this.gui.Add("Text", "x20 y94 w480 h18 Center BackgroundTrans cAFAFAF Hidden", "正在扫描...")
        this.searchButton := this.gui.Add("Text", "x20 y114 w70 h26 Center 0x200 Background333333 cWhite", "🔍 搜索...")
        this.browseButton := this.gui.Add("Text", "x98 y114 w72 h26 Center 0x200 Background333333 cWhite", "📂 选择...")
        this.okButton := this.gui.Add("Text", "x356 y114 w68 h26 Center 0x200 Background0078D7 cWhite", "✔️ 确 定")
        this.cancelButton := this.gui.Add("Text", "x432 y114 w68 h26 Center 0x200 Background333333 cWhite", "❌ 取 消")
        RegisterHoverButton(this.searchButton, "333333")
        RegisterHoverButton(this.browseButton, "333333")
        RegisterHoverButton(this.okButton, "0078D7")
        RegisterHoverButton(this.cancelButton, "333333")
        RegisterButtonClick(this.searchButton, ObjBindMethod(this.search, "Show"))
        RegisterButtonClick(this.browseButton, ObjBindMethod(this, "ShowBrowseMenu"))
        RegisterButtonClick(this.okButton, ObjBindMethod(this, "Confirm"), ButtonFeedbackMode.Dismissive)
        RegisterButtonClick(this.cancelButton, ObjBindMethod(this, "Close"), ButtonFeedbackMode.Dismissive)
        this.gui.Show("w520 h155")
        } catch as openErr {
            this.Close()
            throw openErr
        }
    }

    ShowBrowseMenu(*) {
        browseMenu := Menu()
        browseMenu.Add("📄 浏览文件...", ObjBindMethod(this, "BrowseFile"))
        browseMenu.Add("📂 浏览文件夹...", ObjBindMethod(this, "BrowseDir"))
        browseMenu.Add("⚙️ 从系统服务导入...", ObjBindMethod(this.serviceSelector, "Show"))
        browseMenu.Show()
    }

    BrowseFile(*) {
        selected := this.SelectFile("选择要监控的文件")
        if selected && this.IsOpen()
            this.edit.Value := selected
    }

    BrowseDir(*) {
        selected := this.SelectDirectory("选择要监控的文件夹")
        if selected && this.IsOpen()
            this.edit.Value := selected
    }

    SelectFile(prompt := "选择文件") {
        try {
            fileDialog := ComObject("{DC1C5A9C-E88A-4DDE-A5A1-60F82A20AEF7}", "{d57c7288-d4ad-4768-be02-9d969532d960}")
            ComCall(9, fileDialog, "UInt", 0x1840) ; FOS_FORCEFILESYSTEM | FOS_PATHMUSTEXIST | FOS_FILEMUSTEXIST
            filterName := "程序/脚本/快捷方式"
            filterPattern := "*.exe;*.com;*.msc;*.ahk;*.py;*.pyw;*.js;*.vbs;*.vbe;*.wsf;*.ps1;*.bat;*.cmd;*.rb;*.pl;*.php;*.lua;*.jar;*.sh;*.bash;*.lnk;*.url;*.appref-ms"
            filterSpec := Buffer(A_PtrSize * 2, 0)
            NumPut("Ptr", StrPtr(filterName), filterSpec, 0)
            NumPut("Ptr", StrPtr(filterPattern), filterSpec, A_PtrSize)
            ComCall(4, fileDialog, "UInt", 1, "Ptr", filterSpec)
            ComCall(17, fileDialog, "Str", prompt)
            hwndOwner := this.IsOpen() ? this.gui.Hwnd : 0
            if (ComCall(3, fileDialog, "Ptr", hwndOwner, "Int") == 0) {
                ComCall(20, fileDialog, "Ptr*", &shellItem := 0)
                ComCall(5, shellItem, "UInt", 0x80058000, "Ptr*", &pszString := 0)
                path := StrGet(pszString, "UTF-16")
                DllCall("Ole32\CoTaskMemFree", "Ptr", pszString)
                ObjRelease(shellItem)
                return path
            }
        } catch {
            return ""
        }
        return ""
    }

    SelectDirectory(prompt := "选择文件夹") {
        try {
            fbd := ComObject("{DC1C5A9C-E88A-4DDE-A5A1-60F82A20AEF7}", "{d57c7288-d4ad-4768-be02-9d969532d960}")
            ComCall(9, fbd, "UInt", 0x60)
            ComCall(17, fbd, "Str", prompt)
            hwndOwner := this.IsOpen() ? this.gui.Hwnd : 0
            if (ComCall(3, fbd, "Ptr", hwndOwner, "Int") == 0) {
                ComCall(20, fbd, "Ptr*", &shellItem := 0)
                ComCall(5, shellItem, "UInt", 0x80058000, "Ptr*", &pszString := 0)
                path := StrGet(pszString, "UTF-16")
                DllCall("Ole32\CoTaskMemFree", "Ptr", pszString)
                ObjRelease(shellItem)
                return path
            }
        } catch {
            return ""
        }
        return ""
    }

    SetBatchUi(active, statusText := "") {
        if !this.IsOpen()
            return
        for control in [this.edit, this.searchButton, this.browseButton, this.okButton] {
            if control
                control.Enabled := !active
        }
        if this.batchStatus {
            this.batchStatus.Text := statusText
            this.batchStatus.Visible := active
        }
    }

    StartBatchImport(rootPaths, directPaths := "") {
        this.Show()
        if !this.IsOpen()
            return
        this.CancelBatchImport(false)
        this.batchRootQueue := []
        for rootPath in rootPaths
            if DirExist(rootPath)
                this.batchRootQueue.Push(rootPath)
        this.batchPendingPaths := []
        seen := Map()
        seen.CaseSense := "Off"
        if (directPaths && Type(directPaths) == "Array") {
            for filePath in directPaths {
                canonicalPath := GetCanonicalPath(filePath)
                if IsSupportedMonitorFile(filePath) && !seen.Has(canonicalPath) {
                    seen[canonicalPath] := true
                    this.batchPendingPaths.Push(filePath)
                }
            }
        }
        this.batchPendingIndex := 0
        this.batchAddedCount := 0
        this.batchTruncated := false
        this.SetBatchUi(true, "正在扫描文件夹，可点击取消停止")
        this.StartNextBatchRoot()
    }

    StartNextBatchRoot() {
        if !this.IsOpen()
            return
        if (this.batchPendingPaths.Length >= App.batchImportMaxResults) {
            this.batchTruncated := true
            this.batchRootQueue := []
        }
        if !this.batchRootQueue.Length {
            this.BeginBatchConsume()
            return
        }
        rootPath := this.batchRootQueue.RemoveAt(1)
        remaining := App.batchImportMaxResults - this.batchPendingPaths.Length
        timeoutSeconds := Max(30, Min(300, App.nativeScanTimeoutSeconds * 4))
        scanWorker := StartFileScanWorker("batch", rootPath, App.recursiveBatchImport,
            remaining, timeoutSeconds)
        if scanWorker {
            this.batchWorkerPid := scanWorker.Pid
            this.batchWorkerCreationIdentity := scanWorker.CreationIdentity
            this.batchOutputPath := scanWorker.Path
            this.batchStatus.Text := "正在扫描：" rootPath
            SetTimer(this.batchPollTimer, 100)
        } else {
            this.batchTruncated := true
            this.StartNextBatchRoot()
        }
    }

    PollBatchImport(*) {
        if !this.IsOpen() {
            SetTimer(this.batchPollTimer, 0)
            return
        }
        if FileExist(this.batchOutputPath) {
            SetTimer(this.batchPollTimer, 0)
            paths := ReadFileScanResult(this.batchOutputPath, &wasTruncated)
            this.batchTruncated := this.batchTruncated || wasTruncated
            try FileDelete(this.batchOutputPath)
            this.batchWorkerPid := 0
            this.batchWorkerCreationIdentity := ""
            this.batchOutputPath := ""
            seen := Map()
            seen.CaseSense := "Off"
            for existingPath in this.batchPendingPaths
                seen[GetCanonicalPath(existingPath)] := true
            for filePath in paths {
                if (this.batchPendingPaths.Length >= App.batchImportMaxResults) {
                    this.batchTruncated := true
                    break
                }
                canonicalPath := GetCanonicalPath(filePath)
                if !seen.Has(canonicalPath) {
                    seen[canonicalPath] := true
                    this.batchPendingPaths.Push(filePath)
                }
            }
            this.StartNextBatchRoot()
            return
        }
        if (this.batchWorkerPid
            && (!ProcessExist(this.batchWorkerPid)
                || (this.batchWorkerCreationIdentity != ""
                    && GetProcessCreationIdentity(this.batchWorkerPid) != this.batchWorkerCreationIdentity))) {
            SetTimer(this.batchPollTimer, 0)
            StopFileScanWorker(this.batchWorkerPid, this.batchOutputPath,
                this.batchWorkerCreationIdentity)
            this.batchWorkerPid := 0
            this.batchWorkerCreationIdentity := ""
            this.batchOutputPath := ""
            this.batchTruncated := true
            this.StartNextBatchRoot()
        }
    }

    BeginBatchConsume() {
        if !this.batchPendingPaths.Length {
            this.SetBatchUi(false)
            ShowDarkMsgBox("所选文件夹内未找到支持的程序、脚本或快捷方式。",
                "未找到目标", "Info", this.gui)
            return
        }
        CommitUndoState()
        this.batchPendingIndex := 0
        this.batchStatus.Text := "正在添加扫描结果..."
        SetTimer(this.batchConsumeTimer, 15)
    }

    ConsumeBatchImport(*) {
        if !this.IsOpen() {
            SetTimer(this.batchConsumeTimer, 0)
            return
        }
        batchEnd := Min(this.batchPendingPaths.Length, this.batchPendingIndex + 7)
        while (this.batchPendingIndex < batchEnd) {
            this.batchPendingIndex++
            filePath := this.batchPendingPaths[this.batchPendingIndex]
            shortcutArgs := "", resolvedWorkDir := ""
            resolvedPath := ResolveShortcutForAdd(filePath, &shortcutArgs, &resolvedWorkDir)
            if RegisterApp(resolvedPath, 1, 0, resolvedWorkDir,
                "", "", "", "", false, shortcutArgs)
                this.batchAddedCount++
        }
        this.batchStatus.Text := "正在添加：" this.batchPendingIndex " / " this.batchPendingPaths.Length
        if (this.batchPendingIndex < this.batchPendingPaths.Length)
            return
        SetTimer(this.batchConsumeTimer, 0)
        if this.batchAddedCount
            SaveAppsToIni()
        message := "已添加 " this.batchAddedCount " 个监控项。"
        if this.batchTruncated
            message .= " 扫描达到时间或数量上限，结果已截断。"
        LogMsg(message)
        this.batchPendingPaths := []
        this.batchPendingIndex := 0
        this.SetBatchUi(false)
        ShowDarkMsgBox(message, "批量导入完成", "Info", this.gui)
    }

    CancelBatchImport(updateUi := true) {
        SetTimer(this.batchPollTimer, 0)
        SetTimer(this.batchConsumeTimer, 0)
        StopFileScanWorker(this.batchWorkerPid, this.batchOutputPath,
            this.batchWorkerCreationIdentity)
        this.batchWorkerPid := 0
        this.batchWorkerCreationIdentity := ""
        this.batchOutputPath := ""
        this.batchRootQueue := []
        this.batchPendingPaths := []
        this.batchPendingIndex := 0
        if updateUi && this.IsOpen()
            this.SetBatchUi(false)
    }

    Confirm(*) {
        if !this.IsOpen()
            return
        path := Trim(this.edit.Value)
        if (path == "") {
            this.Close()
            return
        }

        if DirExist(path) {
            this.StartBatchImport([path])
            return
        } else {
            shortcutArgs := "", resolvedWorkDir := ""
            path := ResolveShortcutForAdd(path, &shortcutArgs, &resolvedWorkDir)
            normalizedPath := NormalizeTargetPath(path)
            if (normalizedPath == "" || App.appStates.Has(normalizedPath) || (SubStr(normalizedPath, 1, 8) != "Service:" && DirExist(normalizedPath))) {
                ShowDarkMsgBox("该目标已存在、无效或指向目录。", "未添加", "Info", this.gui)
            } else {
                CommitUndoState()
                if RegisterApp(normalizedPath, 1, 0, resolvedWorkDir, "", "", "", "", false, shortcutArgs) {
                    SaveAppsToIni()
                    LogMsg("手动添加监控: " normalizedPath)
                } else {
                    ShowDarkMsgBox("该目标已存在、无效或指向目录。", "未添加", "Info", this.gui)
                }
            }
        }
        this.Close()
    }

    Close(*) {
        this.CancelBatchImport(false)
        this.search.Close()
        this.serviceSelector.Close()
        this.DestroyGui()
        this.edit := ""
        this.searchButton := ""
        this.browseButton := ""
        this.okButton := ""
        this.cancelButton := ""
        this.batchStatus := ""
    }
}

class ServiceSelector extends ManagedWindow {
    __New(ownerDialog) {
        this.ownerDialog := ownerDialog
        this.lv := ""
        this.okButton := ""
        this.cancelButton := ""
        this.hoverRow := 0
        this.tooltip := DarkTooltipWindow()
        this.mouseHandler := ObjBindMethod(this, "OnMouseMove")
    }

    Show(*) {
        if !this.ownerDialog.IsOpen()
            return
        if this.ShowExisting()
            return

        if !this.CreateOwnedGui(this.ownerDialog.gui, "+Resize +MinSize500x350", "选择系统服务")
            return
        try {
        this.gui.BackColor := "1E1E1E"
        this.gui.SetFont("s10 cWhite", "Microsoft YaHei")
        SetDarkTitleBar(this.gui.Hwnd)
        SetWindowIcon(this.gui.Hwnd, A_ScriptDir "\watchdog.ico")

        this.lv := this.gui.Add("ListView", "x10 y10 w680 h430 +Grid -Multi -Hdr Background252526 cWhite", ["服务显示名称", "底层服务名", "状态"])
        SetDarkListView(this.lv.Hwnd)
        this.lv.ModifyCol(1, 350)
        this.lv.ModifyCol(2, 220)
        this.lv.ModifyCol(3, 80)
        this.LoadServices()

        this.okButton := this.gui.Add("Text", "x536 y462 w72 h28 Center 0x200 Background0078D7 cWhite", "✔️ 确 定")
        this.cancelButton := this.gui.Add("Text", "x618 y462 w72 h28 Center 0x200 Background333333 cWhite", "❌ 取 消")
        RegisterHoverButton(this.okButton, "0078D7")
        RegisterHoverButton(this.cancelButton, "333333")
        this.gui.OnEvent("Size", ObjBindMethod(this, "OnResize"))
        this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
        this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
        RegisterButtonClick(this.cancelButton, ObjBindMethod(this, "Close"), ButtonFeedbackMode.Dismissive)
        RegisterButtonClick(this.okButton, ObjBindMethod(this, "Confirm"), ButtonFeedbackMode.Dismissive)
        this.lv.OnEvent("DoubleClick", ObjBindMethod(this, "Confirm"))
        OnMessage(Win32.WM_MOUSEMOVE, this.mouseHandler)
        this.gui.Show("w700 h500")
        } catch as openErr {
            this.Close()
            throw openErr
        }
    }

    LoadServices() {
        this.lv.Opt("-Redraw")
        for service in EnumerateWindowsServices()
            this.lv.Add("", service.display, service.name, service.state)
        this.lv.ModifyCol(1, "Sort")
        this.lv.Opt("+Redraw")
    }

    OnResize(GuiObj, MinMax, Width, Height) {
        if (MinMax == -1 || !this.lv)
            return
        Width := Max(500, Width)
        Height := Max(350, Height)
        this.lv.Move(, , Width - 20, Height - 60)
        this.okButton.Move(Width - 164, Height - 38)
        this.cancelButton.Move(Width - 82, Height - 38)
        remainingWidth := Width - 20 - 80 - 25
        if (remainingWidth > 100) {
            this.lv.ModifyCol(1, remainingWidth * 0.6)
            this.lv.ModifyCol(2, remainingWidth * 0.4)
        }
    }

    Confirm(*) {
        if !this.IsOpen()
            return
        row := this.lv.GetNext(0)
        if !row {
            ShowDarkMsgBox("请先选择一个服务！", "提示", "Info", this.gui)
            return
        }
        if this.ownerDialog.IsOpen()
            this.ownerDialog.edit.Value := "Service:" this.lv.GetText(row, 2)
        this.Close()
    }

    OnMouseMove(wParam, lParam, msg, hwnd) {
        if !this.IsOpen() || !this.lv || hwnd != this.lv.Hwnd {
            this.hoverRow := 0
            this.tooltip.Hide()
            return
        }
        point := Buffer(24, 0)
        NumPut("Int", SignedWord(lParam), point, 0)
        NumPut("Int", SignedWord(lParam >> 16), point, 4)
        row := SendMessage(Win32.LVM_HITTEST, 0, point.Ptr, this.lv)
        if (row < 0) {
            this.hoverRow := 0
            this.tooltip.Hide()
            return
        }
        row += 1
        if (row == this.hoverRow)
            return
        this.hoverRow := row
        displayName := Trim(this.lv.GetText(row, 1))
        serviceName := this.lv.GetText(row, 2)
        state := this.lv.GetText(row, 3)
        this.tooltip.Show("显示名称: " displayName "`n底层名称: " serviceName "`n运行状态: " state)
    }

    Close(*) {
        if this.gui
            try OnMessage(Win32.WM_MOUSEMOVE, this.mouseHandler, 0)
        this.tooltip.Hide()
        this.DestroyGui()
        this.lv := ""
        this.okButton := ""
        this.cancelButton := ""
        this.hoverRow := 0
    }
}

class SettingsWindow extends ManagedWindow {
    __New(mainGui) {
        this.owner := mainGui
        this.tabButtons := []
        this.tabButtonPages := []
        this.tabControls := []
        this.activeTab := 0
        this.intervalEdit := ""
        this.retryEdit := ""
        this.showAtStartupCheck := ""
        this.recursiveImportCheck := ""
        this.gracefulStopEdit := ""
        this.ctrlCWaitEdit := ""
        this.servicePendingEdit := ""
        this.logMaxEdit := ""
        this.logDirEdit := ""
        this.logRetentionEdit := ""
        this.clearLogsOnStartupCheck := ""
        this.forceTerminateCheck := ""
        this.resumePausedServicesCheck := ""
        this.preferEverythingCheck := ""
        this.nativeScanTimeoutEdit := ""
        this.everythingMaxResultsEdit := ""
        this.taskButton := ""
    }

    Show(*) {
        if this.ShowExisting()
            return

        if !this.CreateOwnedGui(this.owner, "-MinimizeBox -MaximizeBox", "小助手设置")
            return
        try {
        this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
        this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
        SetDarkTitleBar(this.gui.Hwnd)
        SetWindowIcon(this.gui.Hwnd, A_ScriptDir "\watchdog.ico")
        this.gui.BackColor := "1E1E1E"
        this.gui.SetFont("s10 cWhite", "Microsoft YaHei")

        this.tabButtons := []
        this.tabButtonPages := []
        this.tabControls := []
        this.activeTab := 0
        Loop 5
            this.tabControls.Push([])

        this.gui.SetFont("s9 cWhite", "Microsoft YaHei")
        this.CreateTabButton(5, 15, 88, "系统集成")
        this.CreateTabButton(1, 107, 88, "监控与启动")
        this.CreateTabButton(2, 199, 88, "停止与服务")
        this.CreateTabButton(3, 291, 52, "日志")
        this.CreateTabButton(4, 347, 88, "搜索与导入")
        this.gui.Add("Text", "x15 y46 w490 h1 Background3A3A3A")
        this.gui.SetFont("s10 cWhite", "Microsoft YaHei")

        this.AddTabControl(1, this.gui.Add("Text", "x25 y60 w210 h26 0x200 BackgroundTrans", "状态检查间隔（毫秒）:"))
        this.intervalEdit := this.AddSettingsEdit(1, 245, 60, 120, App.checkInterval, "Number")
        this.AddTabControl(1, this.gui.Add("Text", "x25 y96 w210 h26 0x200 BackgroundTrans", "重启等待序列（秒）:"))
        this.retryEdit := this.AddSettingsEdit(1, 245, 96, 190, App.retrySequence)
        this.showAtStartupCheck := this.AddTabControl(1, this.gui.Add("CheckBox", "x25 y136 w320 h24", "启动后显示主窗口"))
        this.showAtStartupCheck.Value := App.showAtStartup ? 1 : 0
        this.recursiveImportCheck := this.AddTabControl(1, this.gui.Add("CheckBox", "x25 y172 w420 h24", "批量导入文件夹时递归扫描子目录"))
        this.recursiveImportCheck.Value := App.recursiveBatchImport ? 1 : 0

        this.AddTabControl(2, this.gui.Add("Text", "x25 y60 w220 h26 0x200 BackgroundTrans", "窗口程序关闭等待（秒）:"))
        this.gracefulStopEdit := this.AddSettingsEdit(2, 255, 60, 110, App.gracefulStopSeconds, "Number")
        this.AddTabControl(2, this.gui.Add("Text", "x25 y96 w220 h26 0x200 BackgroundTrans", "命令行程序退出等待（秒）:"))
        this.ctrlCWaitEdit := this.AddSettingsEdit(2, 255, 96, 110, App.ctrlCWaitSeconds, "Number")
        this.AddTabControl(2, this.gui.Add("Text", "x25 y132 w220 h26 0x200 BackgroundTrans", "服务状态切换最长等待（秒）:"))
        this.servicePendingEdit := this.AddSettingsEdit(2, 255, 132, 110, App.servicePendingTimeoutSeconds, "Number")
        this.forceTerminateCheck := this.AddTabControl(2, this.gui.Add("CheckBox", "x25 y170 w380 h24", "正常关闭超时后允许强制终止"))
        this.forceTerminateCheck.Value := App.allowForceTerminate ? 1 : 0
        this.resumePausedServicesCheck := this.AddTabControl(2, this.gui.Add("CheckBox", "x25 y204 w400 h24", "自动恢复已暂停的 Windows 服务"))
        this.resumePausedServicesCheck.Value := App.resumePausedServices ? 1 : 0

        this.AddTabControl(3, this.gui.Add("Text", "x25 y60 w220 h26 0x200 BackgroundTrans", "运行日志内存上限（条）:"))
        this.logMaxEdit := this.AddSettingsEdit(3, 255, 60, 110, App.logMaxEntries, "Number")
        this.AddTabControl(3, this.gui.Add("Text", "x25 y96 w220 h26 0x200 BackgroundTrans", "批处理日志保留时间（天）:"))
        this.logRetentionEdit := this.AddSettingsEdit(3, 255, 96, 110, App.logRetentionDays, "Number")
        this.AddTabControl(3, this.gui.Add("Text", "x25 y132 w220 h26 0x200 BackgroundTrans", "批处理日志保存目录:"))
        this.logDirEdit := this.AddSettingsEdit(3, 25, 162, 385, App.logDirectory)
        btnLogDir := this.AddTabControl(3, this.gui.Add("Text", "x427 y162 w68 h26 Center 0x200 Background333333 cWhite", "📂 浏览"))
        this.clearLogsOnStartupCheck := this.AddTabControl(3, this.gui.Add("CheckBox", "x25 y202 w350 h24", "启动时清空批处理日志"))
        this.clearLogsOnStartupCheck.Value := App.clearLogsOnStartup ? 1 : 0

        this.preferEverythingCheck := this.AddTabControl(4, this.gui.Add("CheckBox", "x25 y64 w360 h24", "优先使用 Everything 搜索"))
        this.preferEverythingCheck.Value := App.preferEverything ? 1 : 0
        this.AddTabControl(4, this.gui.Add("Text", "x25 y104 w220 h26 0x200 BackgroundTrans", "内置搜索最长扫描时间（秒）:"))
        this.nativeScanTimeoutEdit := this.AddSettingsEdit(4, 255, 104, 110, App.nativeScanTimeoutSeconds, "Number")
        this.AddTabControl(4, this.gui.Add("Text", "x25 y140 w220 h26 0x200 BackgroundTrans", "搜索结果数量上限:"))
        this.everythingMaxResultsEdit := this.AddSettingsEdit(4, 255, 140, 110, App.everythingMaxResults, "Number")

        this.AddTabControl(5, this.gui.Add("Text", "x25 y65 w300 h30 0x200 BackgroundTrans", "桌面与开始菜单快捷方式"))
        btnShortcut := this.AddTabControl(5, this.gui.Add("Text", "x423 y66 w72 h28 Center 0x200 Background333333 cWhite", "🔗 创建"))
        this.AddTabControl(5, this.gui.Add("Text", "x25 y108 w470 h1 Background333333"))
        this.AddTabControl(5, this.gui.Add("Text", "x25 y125 w300 h30 0x200 BackgroundTrans", "开机自动启动（计划任务）"))
        this.taskButton := this.AddTabControl(5, this.gui.Add("Text", "x423 y126 w72 h28 Center 0x200 Background333333 cWhite", "🚀 开启"))

        for editCtrl in [this.intervalEdit, this.retryEdit, this.gracefulStopEdit, this.ctrlCWaitEdit, this.servicePendingEdit, this.logMaxEdit, this.logRetentionEdit, this.logDirEdit, this.nativeScanTimeoutEdit, this.everythingMaxResultsEdit]
            SetDarkControl(editCtrl.Hwnd)
        for checkCtrl in [this.showAtStartupCheck, this.recursiveImportCheck, this.forceTerminateCheck, this.resumePausedServicesCheck, this.clearLogsOnStartupCheck, this.preferEverythingCheck] {
            SetDarkControl(checkCtrl.Hwnd)
            RegisterHandCursorControl(checkCtrl)
        }

        btnSave := this.gui.Add("Text", "x183 y247 w72 h28 Center 0x200 Background0078D7 cWhite", "💾 保存")
        btnCancel := this.gui.Add("Text", "x265 y247 w72 h28 Center 0x200 Background333333 cWhite", "❌ 取消")
        RegisterHoverButton(btnLogDir, "333333")
        RegisterHoverButton(btnSave, "0078D7")
        RegisterHoverButton(btnCancel, "333333")
        RegisterHoverButton(btnShortcut, "333333")
        RegisterHoverButton(this.taskButton, "333333")
        RegisterButtonClick(btnSave, ObjBindMethod(this, "Save"), ButtonFeedbackMode.Dismissive)
        RegisterButtonClick(btnCancel, ObjBindMethod(this, "Close"), ButtonFeedbackMode.Dismissive)
        RegisterButtonClick(btnShortcut, ObjBindMethod(this, "CreateShortcut"))
        RegisterButtonClick(btnLogDir, ObjBindMethod(this, "BrowseLogDirectory"))
        RegisterButtonClick(this.taskButton, ObjBindMethod(this, "ToggleTaskAction"))
        this.UpdateTaskButtonStatus()
        this.SwitchTab(5)
        this.gui.Show("w520 h290")
        } catch as openErr {
            this.Close()
            throw openErr
        }
    }

    CreateTabButton(index, x, width, text) {
        button := this.gui.Add("Text", "x" x " y12 w" width " h28 Center 0x200 Background2D2D30 cE8E8E8", text)
        this.tabButtons.Push(button)
        this.tabButtonPages.Push(index)
        RegisterHoverButton(button, "2D2D30")
        RegisterButtonClick(button, ObjBindMethod(this, "SwitchTab", index))
        return button
    }

    AddTabControl(index, control) {
        this.tabControls[index].Push(control)
        return control
    }

    AddSettingsEdit(index, x, y, width, value, extraOptions := "") {
        inputControl := AddCenteredSingleLineEdit(this.gui, x, y, width, 26, value, extraOptions)
        this.AddTabControl(index, inputControl.Background)
        return this.AddTabControl(index, inputControl.Edit)
    }

    SwitchTab(index, *) {
        if (index < 1 || index > this.tabControls.Length)
            return
        for tabIndex, controls in this.tabControls {
            isVisible := tabIndex == index
            for control in controls
                try control.Visible := isVisible
        }
        for buttonIndex, button in this.tabButtons {
            isActive := this.tabButtonPages[buttonIndex] == index
            normalColor := isActive ? "005A9E" : "2D2D30"
            SetHoverButtonColors(button, normalColor)
            SetButtonBackground(button, normalColor)
        }
        this.activeTab := index
    }

    BrowseLogDirectory(*) {
        if !this.IsOpen()
            return
        this.gui.Opt("+OwnDialogs")
        initialDir := DirExist(this.logDirEdit.Value) ? this.logDirEdit.Value : App.logDirectory
        selected := FileSelect("D", initialDir, "选择批处理日志目录")
        if selected && this.IsOpen()
            this.logDirEdit.Value := selected
    }

    CreateShortcut(*) {
        if this.IsOpen()
            CreateDesktopShortcut(this.gui)
    }

    ToggleTaskAction(*) {
        if this.IsOpen()
            ToggleTask(this.gui)
    }

    Save(*) {
        if !this.IsOpen()
            return

        sequenceText := StrReplace(StrReplace(Trim(this.retryEdit.Value), " ", ""), "，", ",")
        newDelays := ParseRetrySequence(sequenceText)
        if !newDelays {
            ShowDarkMsgBox("重试序列格式错误！必须是逗号分隔的正整数（如: 5,30,60），每项范围为 1-86400 秒。", "参数错误", "Error", this.gui)
            return
        }
        if !IsValidCheckInterval(this.intervalEdit.Value) {
            ShowDarkMsgBox("轮询间隔必须为 500-86400000 毫秒的正整数！", "参数错误", "Error", this.gui)
            return
        }
        if (newDelays.Length == 0) {
            ShowDarkMsgBox("重试序列不能为空！", "参数错误", "Error", this.gui)
            return
        }

        gracefulStopSeconds := ParseBoundedInteger(this.gracefulStopEdit.Value, 1, 300)
        ctrlCWaitSeconds := ParseBoundedInteger(this.ctrlCWaitEdit.Value, 1, 60)
        servicePendingTimeoutSeconds := ParseBoundedInteger(this.servicePendingEdit.Value, 5, 600)
        logMaxEntries := ParseBoundedInteger(this.logMaxEdit.Value, 50, 10000)
        logRetentionDays := ParseBoundedInteger(this.logRetentionEdit.Value, 1, 3650)
        nativeScanTimeoutSeconds := ParseBoundedInteger(this.nativeScanTimeoutEdit.Value, 1, 120)
        everythingMaxResults := ParseBoundedInteger(this.everythingMaxResultsEdit.Value, 10, 1000)
        logDirectory := Trim(this.logDirEdit.Value)
        if !gracefulStopSeconds || !ctrlCWaitSeconds || !servicePendingTimeoutSeconds || !logMaxEntries || !logRetentionDays || !nativeScanTimeoutSeconds || !everythingMaxResults || logDirectory == "" {
            ShowDarkMsgBox("扩展设置包含无效数值。`n`n窗口程序关闭等待: 1-300 秒`n命令行程序退出等待: 1-60 秒`n服务状态切换等待: 5-600 秒`n日志条数: 50-10000`n日志保留: 1-3650 天`n内置搜索扫描: 1-120 秒`n搜索结果: 10-1000", "参数错误", "Error", this.gui)
            return
        }

        options := {
            ShowAtStartup: this.showAtStartupCheck.Value != 0,
            RecursiveBatchImport: this.recursiveImportCheck.Value != 0,
            LogMaxEntries: logMaxEntries,
            LogDirectory: logDirectory,
            LogRetentionDays: logRetentionDays,
            ClearLogsOnStartup: this.clearLogsOnStartupCheck.Value != 0,
            GracefulStopSeconds: gracefulStopSeconds,
            CtrlCWaitSeconds: ctrlCWaitSeconds,
            AllowForceTerminate: this.forceTerminateCheck.Value != 0,
            ServicePendingTimeoutSeconds: servicePendingTimeoutSeconds,
            ResumePausedServices: this.resumePausedServicesCheck.Value != 0,
            PreferEverything: this.preferEverythingCheck.Value != 0,
            NativeScanTimeoutSeconds: nativeScanTimeoutSeconds,
            EverythingMaxResults: everythingMaxResults
        }
        newInterval := Integer(this.intervalEdit.Value)
        newRetrySequence := this.retryEdit.Value
        if !SaveSettingsToIni(newInterval, newRetrySequence, options) {
            ShowDarkMsgBox("保存设置失败，请查看运行日志。", "保存失败", "Error", this.gui)
            return
        }

        App.checkInterval := newInterval
        App.retrySequence := newRetrySequence
        App.retryDelayArray := newDelays
        App.showAtStartup := options.ShowAtStartup
        App.recursiveBatchImport := options.RecursiveBatchImport
        App.logMaxEntries := options.LogMaxEntries
        App.logDirectory := options.LogDirectory
        App.logRetentionDays := options.LogRetentionDays
        App.clearLogsOnStartup := options.ClearLogsOnStartup
        App.gracefulStopSeconds := options.GracefulStopSeconds
        App.ctrlCWaitSeconds := options.CtrlCWaitSeconds
        App.allowForceTerminate := options.AllowForceTerminate
        App.servicePendingTimeoutSeconds := options.ServicePendingTimeoutSeconds
        App.resumePausedServices := options.ResumePausedServices
        App.preferEverything := options.PreferEverything
        App.nativeScanTimeoutSeconds := options.NativeScanTimeoutSeconds
        App.everythingMaxResults := options.EverythingMaxResults
        while (App.logMessages.Length > App.logMaxEntries)
            App.logMessages.Pop()
        SetTimer(MonitorLoop, App.checkInterval)
        LogMsg("设置已更新: 轮询=" App.checkInterval "ms, 序列=[" App.retrySequence "], 日志上限=" App.logMaxEntries)
        this.Close()
    }

    UpdateTaskButtonStatus() {
        if !this.taskButton || Type(this.taskButton) != "Gui.Text"
            return
        this.taskButton.Text := CheckTaskExists() ? "🛑 关闭" : "🚀 开启"
    }

    Close(*) {
        this.DestroyGui()
        this.tabButtons := []
        this.tabButtonPages := []
        this.tabControls := []
        this.activeTab := 0
        this.intervalEdit := ""
        this.retryEdit := ""
        this.showAtStartupCheck := ""
        this.recursiveImportCheck := ""
        this.gracefulStopEdit := ""
        this.ctrlCWaitEdit := ""
        this.servicePendingEdit := ""
        this.logMaxEdit := ""
        this.logDirEdit := ""
        this.logRetentionEdit := ""
        this.clearLogsOnStartupCheck := ""
        this.forceTerminateCheck := ""
        this.resumePausedServicesCheck := ""
        this.preferEverythingCheck := ""
        this.nativeScanTimeoutEdit := ""
        this.everythingMaxResultsEdit := ""
        this.taskButton := ""
    }
}

class LogWindow extends ManagedWindow {
    __New(mainGui) {
        this.mainOwner := mainGui
        this.owner := ""
        this.textEdit := ""
        this.contentPixelWidth := 0
        this.contentPixelHeight := 0
        this.horizontalScrollbarVisible := false
        this.verticalScrollbarVisible := false
        this.refreshTimer := ObjBindMethod(this, "RefreshContent")
        this.renderedRevision := 0
    }

    Show(ownerGui := "", *) {
        if this.ShowExisting()
            return
        this.owner := ownerGui ? ownerGui : this.mainOwner
        if !this.CreateOwnedGui(this.owner, "+Resize +MaximizeBox +MinSize420x240", "运行日志")
            return
        try {
        this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
        this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
        this.gui.OnEvent("Size", ObjBindMethod(this, "OnResize"))
        SetDarkTitleBar(this.gui.Hwnd)
        SetWindowIcon(this.gui.Hwnd, A_ScriptDir "\watchdog.ico")
        this.gui.BackColor := "1E1E1E"
        this.gui.SetFont("s10 cWhite", "Microsoft YaHei")
        this.textEdit := this.gui.Add("Edit", "x10 y10 w600 h300 ReadOnly Multi VScroll HScroll -Wrap Background252526 cWhite -E0x200", GetLogText())
        SetDarkControl(this.textEdit.Hwnd)
        RegisterTextInputControl(this.textEdit, true)
        this.textEdit.OnEvent("Focus", ObjBindMethod(this, "HideCaret"))
        this.renderedRevision := App.logRevision
        this.MeasureContent()
        DllCall("user32\ShowScrollBar", "Ptr", this.textEdit.Hwnd, "Int", Win32.SB_BOTH, "Int", 0)
        this.horizontalScrollbarVisible := false
        this.verticalScrollbarVisible := false
        this.gui.Show("w620 h320")
        this.UpdateScrollBars()
        SetTimer(this.refreshTimer, 500)
        } catch as openErr {
            this.Close()
            throw openErr
        }
    }

    OnResize(GuiObj, MinMax, Width, Height) {
        if (MinMax == -1 || !this.textEdit)
            return
        Width := Max(420, Width)
        Height := Max(240, Height)
        this.textEdit.Move(10, 10, Width - 20, Height - 20)
        this.UpdateScrollBars()
        this.HideCaret()
    }

    MeasureContent() {
        if !this.textEdit
            return
        textEditHwnd := this.textEdit.Hwnd
        editDeviceContext := DllCall("user32\GetDC", "Ptr", textEditHwnd, "Ptr")
        if !editDeviceContext
            return
        editFont := SendMessage(Win32.WM_GETFONT, 0, 0, textEditHwnd)
        previousFont := editFont ? DllCall("gdi32\SelectObject", "Ptr", editDeviceContext, "Ptr", editFont, "Ptr") : 0
        try {
            textMetrics := Buffer(60, 0)
            if DllCall("gdi32\GetTextMetricsW", "Ptr", editDeviceContext, "Ptr", textMetrics, "Int")
                lineHeight := NumGet(textMetrics, 0, "Int") + NumGet(textMetrics, 16, "Int")
            else
                lineHeight := 16

            maximumLineWidth := 0
            for logLine in StrSplit(this.textEdit.Value, "`n", "`r") {
                if (logLine == "")
                    continue
                textExtent := Buffer(8, 0)
                if DllCall("gdi32\GetTextExtentPoint32W", "Ptr", editDeviceContext, "Str", logLine, "Int", StrLen(logLine), "Ptr", textExtent, "Int")
                    maximumLineWidth := Max(maximumLineWidth, NumGet(textExtent, 0, "Int"))
            }
            lineCount := SendMessage(Win32.EM_GETLINECOUNT, 0, 0, textEditHwnd)
            this.contentPixelWidth := maximumLineWidth
            this.contentPixelHeight := Max(1, lineCount) * Max(1, lineHeight)
        } finally {
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", editDeviceContext, "Ptr", previousFont, "Ptr")
            DllCall("user32\ReleaseDC", "Ptr", textEditHwnd, "Ptr", editDeviceContext)
        }
    }

    UpdateScrollBars(*) {
        if !this.textEdit
            return
        textEditHwnd := this.textEdit.Hwnd
        formattingRect := Buffer(16, 0)
        SendMessage(Win32.EM_GETRECT, 0, formattingRect.Ptr, textEditHwnd)
        availableWidth := NumGet(formattingRect, 8, "Int") - NumGet(formattingRect, 0, "Int")
        availableHeight := NumGet(formattingRect, 12, "Int") - NumGet(formattingRect, 4, "Int")
        if this.verticalScrollbarVisible
            availableWidth += SysGet(2) ; SM_CXVSCROLL
        if this.horizontalScrollbarVisible
            availableHeight += SysGet(3) ; SM_CYHSCROLL

        verticalBarWidth := SysGet(2)
        horizontalBarHeight := SysGet(3)
        needsVerticalScrollbar := this.contentPixelHeight > availableHeight
        needsHorizontalScrollbar := this.contentPixelWidth > availableWidth - (needsVerticalScrollbar ? verticalBarWidth : 0)
        if needsHorizontalScrollbar && !needsVerticalScrollbar
            needsVerticalScrollbar := this.contentPixelHeight > availableHeight - horizontalBarHeight
        if needsVerticalScrollbar && !needsHorizontalScrollbar
            needsHorizontalScrollbar := this.contentPixelWidth > availableWidth - verticalBarWidth

        if (needsHorizontalScrollbar != this.horizontalScrollbarVisible) {
            DllCall("user32\ShowScrollBar", "Ptr", textEditHwnd, "Int", Win32.SB_HORZ, "Int", needsHorizontalScrollbar)
            this.horizontalScrollbarVisible := needsHorizontalScrollbar
        }
        if (needsVerticalScrollbar != this.verticalScrollbarVisible) {
            DllCall("user32\ShowScrollBar", "Ptr", textEditHwnd, "Int", Win32.SB_VERT, "Int", needsVerticalScrollbar)
            this.verticalScrollbarVisible := needsVerticalScrollbar
        }
    }

    RefreshContent(*) {
        if !this.IsOpen() || !this.textEdit || this.renderedRevision == App.logRevision
            return
        textEditHwnd := this.textEdit.Hwnd
        firstVisibleLine := SendMessage(Win32.EM_GETFIRSTVISIBLELINE, 0, 0, textEditHwnd)
        selectionStartBuffer := Buffer(4, 0)
        selectionEndBuffer := Buffer(4, 0)
        SendMessage(Win32.EM_GETSEL, selectionStartBuffer.Ptr, selectionEndBuffer.Ptr, textEditHwnd)
        selectionStart := NumGet(selectionStartBuffer, 0, "UInt")
        selectionEnd := NumGet(selectionEndBuffer, 0, "UInt")

        insertedEntries := Min(App.logMessages.Length,
            Max(0, App.logRevision - this.renderedRevision))
        insertedCharacters := 0
        Loop insertedEntries
            insertedCharacters += StrLen(App.logMessages[A_Index]) + 2
        this.textEdit.Value := GetLogText()
        if (insertedEntries > 0) {
            SendMessage(Win32.EM_SETSEL, selectionStart + insertedCharacters,
                selectionEnd + insertedCharacters, textEditHwnd)
            if (firstVisibleLine > 0)
                SendMessage(Win32.EM_LINESCROLL, 0, firstVisibleLine + insertedEntries, textEditHwnd)
        } else {
            SendMessage(Win32.EM_SETSEL, selectionStart, selectionEnd, textEditHwnd)
            if (firstVisibleLine > 0)
                SendMessage(Win32.EM_LINESCROLL, 0, firstVisibleLine, textEditHwnd)
        }
        this.renderedRevision := App.logRevision
        this.MeasureContent()
        this.UpdateScrollBars()
        this.HideCaret()
    }

    HideCaret(*) {
        if this.textEdit
            ScheduleHideTextCaret(this.textEdit.Hwnd)
    }

    Close(*) {
        SetTimer(this.refreshTimer, 0)
        this.DestroyGui()
        this.textEdit := ""
        this.owner := ""
        this.contentPixelWidth := 0
        this.contentPixelHeight := 0
        this.horizontalScrollbarVisible := false
        this.verticalScrollbarVisible := false
        this.renderedRevision := 0
    }
}

class HelpWindow extends ManagedWindow {
    __New(mainGui) {
        this.owner := mainGui
        this.textEdit := ""
    }

    Show(*) {
        if this.ShowExisting()
            return

        if !this.CreateOwnedGui(this.owner, "", "使用说明与帮助")
            return
        try {
        this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
        this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
        SetDarkTitleBar(this.gui.Hwnd)
        SetWindowIcon(this.gui.Hwnd, A_ScriptDir "\watchdog.ico")
        this.gui.BackColor := "1E1E1E"
        this.gui.SetFont("s11 cWhite", "Microsoft YaHei")

        helpText := "=============== 【进程守护小助手】使用说明 ===============`n`n"
        helpText .= "本程序专为保障 Windows 后台进程、服务和脚本的高可用性而设计，一旦检测到任务崩溃或退出，将立即重新拉起。`n`n"
        helpText .= "【一、 支持监测的文件类型】`n"
        helpText .= "1. 普通程序：*.exe, *.com, *.msc，直接底层校验，资源占用极低。`n"
        helpText .= "2. 解释型脚本：*.ahk, *.py, *.pyw, *.js, *.vbs, *.vbe, *.wsf, *.ps1, *.bat, *.cmd, *.rb, *.pl, *.php, *.lua, *.jar, *.sh, *.bash 等。自动穿透解释器锁定真实脚本。`n"
        helpText .= "3. 快捷方式：*.lnk, *.url, *.appref-ms。深度对接，甚至支持 MSI 广告快捷方式（自动解析真实的后台EXE并监控）。`n`n"
        helpText .= "【二、 界面操作与交互】`n"
        helpText .= "1. 添加：点击顶部按钮，或【直接将文件/文件夹拖拽进窗口】完成极速导入。`n"
        helpText .= "2. 调整：双击或选定按 F2，可以直接编辑路径；按住列表鼠标拖动，即可调整位置。`n"
        helpText .= "3. 右键菜单：可以直接设定「以管理员身份运行」的独立提权策略。`n"
        helpText .= "4. 快捷键：支持 Shift/Ctrl 多选，Delete 删除。更支持【Ctrl+Z】撤销误操作，【Ctrl+Y】重做。`n"
        helpText .= "5. 状态：【全选反转 / 暂停】，一键即可停止或恢复临时不需要守护的进程。`n`n"
        helpText .= "【三、 高级守护机制配置】`n"
        helpText .= "1. ⚙️ 设置面板：`n"
        helpText .= "   - [轮询间隔]：越短恢复越快，默认2000毫秒（2秒）。`n"
        helpText .= "   - [重试指数退避]：格式如 5,30,60。程序崩溃立马等5秒重启；如目标自身存在致命BUG启动即崩，"
        helpText .= "下一次就会等30秒接着等60秒。这有效预防了死循环导致的 CPU 爆满锁死问题。`n"
        helpText .= "2. 🚀 计划任务与开机自启：`n"
        helpText .= "   - 一键注入系统任务调度！无需再忍受烦人的 UAC 弹窗即可实现高权限静默托盘自启。"
        helpText .= "`n`n【四、 软件升级保护】`n"
        helpText .= "1. EXE、COM 和脚本目标默认启用升级保护，不要求用户填写更新程序名称。小助手会监听安装目录变化、相关进程和程序文件稳定性。`n"
        helpText .= "2. 右键目标并打开【软件升级保护…】，可以调整安装足迹目录、退出检测窗口、文件稳定等待和最长升级等待。`n"
        helpText .= "3. 升级保护超时后，可在同一窗口点击【结束升级等待并恢复守护】。小助手仍会再次执行文件安全检查，不会直接绕过安全启动门。`n"
        helpText .= "4. 可控的更新脚本可以在升级前后发送维护协议：`n"
        helpText .= "   --maintenance-begin `"<目标完整路径>`"  开始维护`n"
        helpText .= "   --maintenance-end `"<目标完整路径>`"    结束维护`n"

        this.textEdit := this.gui.Add("Edit", "w660 r23 ReadOnly Background252526 cWhite -E0x200 Multi VScroll", helpText)
        SetDarkControl(this.textEdit.Hwnd)
        RegisterTextInputControl(this.textEdit, true)
        this.textEdit.OnEvent("Focus", ObjBindMethod(this, "HideCaret"))
        this.gui.Show("AutoSize")
        SendMessage(0x00B1, -1, -1, this.textEdit.Hwnd)
        lineCount := SendMessage(0x00BA, 0, 0, this.textEdit.Hwnd)
        if (lineCount <= 23)
            DllCall("ShowScrollBar", "Ptr", this.textEdit.Hwnd, "Int", 1, "Int", 0)
        } catch as openErr {
            this.Close()
            throw openErr
        }
    }

    HideCaret(*) {
        if this.textEdit
            ScheduleHideTextCaret(this.textEdit.Hwnd)
    }

    Close(*) {
        this.DestroyGui()
        this.textEdit := ""
    }
}

class ApplicationSearchDialog extends ManagedWindow {
    __New(ownerDialog) {
        this.ownerDialog := ownerDialog
        this.lv := ""
        this.searchEdit := ""
        this.searchEditBackground := ""
        this.selectButton := ""
        this.imageList := 0
        this.appList := []
        this.scanSeen := Map()
        this.scanSeen.CaseSense := "Off"
        this.scanTruncated := false
        this.pendingScanPaths := []
        this.pendingScanIndex := 0
        this.hoverRow := 0
        this.tooltip := DarkTooltipWindow()
        this.everythingLib := 0
        this.everythingAvailable := false
        this.everythingDllName := "Everything64.dll"
        this.mouseHandler := ObjBindMethod(this, "OnMouseMove")
        this.scanWorkerPid := 0
        this.scanWorkerCreationIdentity := ""
        this.scanOutputPath := ""
        this.scanPollTimer := ObjBindMethod(this, "PollNativeScan")
        this.scanConsumeTimer := ObjBindMethod(this, "ConsumeNativeScanBatch")
        this.pendingScanPaths := []
        this.pendingScanIndex := 0
        this.searchTimer := ObjBindMethod(this, "RunDeferredSearch")
        this.initialSearchTimer := ObjBindMethod(this, "BeginInitialSearch")
    }

    Show(*) {
        if !this.ownerDialog.IsOpen()
            return
        if this.ShowExisting()
            return

        if App.preferEverything && !this.everythingLib
            this.everythingLib := DllCall("LoadLibrary", "Str", A_ScriptDir "\" this.everythingDllName, "Ptr")
        title := (App.preferEverything && this.everythingLib) ? "搜索 ⚡Everything 引擎启动⚡" : "搜索 ⚡原生深扫引擎⚡"

        if !this.CreateOwnedGui(this.ownerDialog.gui, "+Resize +MaximizeBox +MinSize500x300", title)
            return
        try {
        SetDarkTitleBar(this.gui.Hwnd)
        SetWindowIcon(this.gui.Hwnd, A_ScriptDir "\watchdog.ico")
        this.gui.BackColor := "1E1E1E"
        this.gui.SetFont("s10 cWhite", "Microsoft YaHei")
        this.gui.Add("Text", "x20 y20 w60 h25 BackgroundTrans", "🔍 搜索:")
        searchInput := AddCenteredSingleLineEdit(this.gui, 80, 15, 600, 25, "", "", "333333")
        this.searchEditBackground := searchInput.Background
        this.searchEdit := searchInput.Edit
        SetDarkControl(this.searchEdit.Hwnd)

        this.lv := this.gui.Add("ListView", "x20 y55 w660 h280 Background252526 cWhite -E0x200 -Multi -Hdr", ["名称", "路径"])
        SetDarkListView(this.lv.Hwnd)
        this.lv.ModifyCol(1, 264)
        this.lv.ModifyCol(2, 396)
        this.imageList := this.CreateImageList()
        if this.imageList
            this.lv.SetImageList(this.imageList, 1)

        this.selectButton := this.gui.Add("Text", "x314 y357 w72 h28 Center 0x200 Background0078D7 cWhite", "✔️ 确 定")
        RegisterHoverButton(this.selectButton, "0078D7")
        this.gui.OnEvent("Close", ObjBindMethod(this, "Close"))
        this.gui.OnEvent("Escape", ObjBindMethod(this, "Close"))
        this.gui.OnEvent("Size", ObjBindMethod(this, "OnResize"))
        this.lv.OnEvent("DoubleClick", ObjBindMethod(this, "Select"))
        RegisterButtonClick(this.selectButton, ObjBindMethod(this, "Select"), ButtonFeedbackMode.Dismissive)
        OnMessage(Win32.WM_MOUSEMOVE, this.mouseHandler)

        this.everythingAvailable := App.preferEverything && !!this.everythingLib
        this.gui.Show("w700 h400")
        ControlFocus(this.searchEdit)
        this.searchEdit.OnEvent("Change", ObjBindMethod(this, "OnSearchChanged"))
        SetTimer(this.initialSearchTimer, -10)
        } catch as openErr {
            this.Close()
            throw openErr
        }
    }

    BeginInitialSearch(*) {
        if !this.IsOpen()
            return
        if (this.everythingAvailable && this.SearchEverything())
            return
        this.everythingAvailable := false
        this.LoadNativeApps()
    }

    OnResize(GuiObj, MinMax, Width, Height) {
        if (MinMax == -1 || !this.lv)
            return
        Width := Max(500, Width)
        Height := Max(300, Height)
        try this.searchEditBackground.Move(,, Width - 100)
        try this.searchEdit.Move(,, Width - 100)
        try this.lv.Move(,, Width - 40, Height - 110)
        listWidth := Width - 65
        try this.lv.ModifyCol(1, Integer(listWidth * 0.4))
        try this.lv.ModifyCol(2, Integer(listWidth * 0.6))
        try this.selectButton.Move(Floor((Width - 72) / 2), Height - 43)
    }

    CreateImageList() {
        return IL_Create(10)
    }

    OnMouseMove(wParam, lParam, msg, hwnd) {
        if !this.IsOpen() || !this.lv {
            this.tooltip.Hide()
            this.hoverRow := 0
            return
        }
        if (hwnd != this.lv.Hwnd) {
            this.tooltip.Hide()
            this.hoverRow := 0
            return
        }
        point := Buffer(24, 0)
        NumPut("Int", SignedWord(lParam), point, 0)
        NumPut("Int", SignedWord(lParam >> 16), point, 4)
        row := SendMessage(Win32.LVM_HITTEST, 0, point.Ptr, this.lv)
        if (row >= 0) {
            row += 1
            if (row != this.hoverRow) {
                this.hoverRow := row
                this.tooltip.Show("项目名称: " this.lv.GetText(row, 1) "`n真实路径: " this.lv.GetText(row, 2))
            }
        } else if (this.hoverRow != 0) {
            this.hoverRow := 0
            this.tooltip.Hide()
        }
    }

    SearchEverything(*) {
        if !this.everythingLib || !this.everythingAvailable || !this.IsOpen()
            return false
        keyword := Trim(this.searchEdit.Value)
        if (keyword == "") {
            keyword := "ext:exe;com;msc;ahk;py;pyw;js;vbs;vbe;wsf;ps1;bat;cmd;rb;pl;php;lua;jar;sh;bash;lnk;url;appref-ms"
        } else if !InStr(keyword, "ext:") && !InStr(keyword, "\") && !InStr(keyword, ":") {
            keyword := "ext:exe;com;msc;ahk;py;pyw;js;vbs;vbe;wsf;ps1;bat;cmd;rb;pl;php;lua;jar;sh;bash;lnk;url;appref-ms " keyword
        }

        try {
            DllCall(this.everythingDllName "\Everything_SetSearchW", "WStr", keyword)
            DllCall(this.everythingDllName "\Everything_SetSort", "UInt", 14)
            if !DllCall(this.everythingDllName "\Everything_QueryW", "Int", 1)
                return false
            resultCount := DllCall(this.everythingDllName "\Everything_GetNumResults", "UInt")
        } catch {
            return false
        }

        this.lv.Opt("-Redraw")
        this.lv.Delete()
        Loop Min(resultCount, App.everythingMaxResults) {
            index := A_Index - 1
            namePtr := DllCall(this.everythingDllName "\Everything_GetResultFileNameW", "UInt", index, "Ptr")
            pathPtr := DllCall(this.everythingDllName "\Everything_GetResultPathW", "UInt", index, "Ptr")
            if (!namePtr || !pathPtr)
                continue
            name := StrGet(namePtr, "UTF-16")
            path := StrGet(pathPtr, "UTF-16")
            fullPath := RTrim(path, "\") "\" name
            iconIndex := GetFileIconIndex(fullPath, this.imageList)
            this.lv.Add("Icon" iconIndex, name, fullPath)
        }
        this.lv.Opt("+Redraw")
        return true
    }

    OnSearchChanged(*) {
        SetTimer(this.searchTimer, 0)
        SetTimer(this.searchTimer, -150)
    }

    RunDeferredSearch(*) {
        if !this.IsOpen()
            return
        if this.everythingAvailable {
            if !this.SearchEverything() {
                this.everythingAvailable := false
                try WinSetTitle("搜索 ⚡原生深扫引擎⚡", this.gui.Hwnd)
                this.LoadNativeApps()
            }
        } else {
            this.FilterNativeList()
        }
    }

    LoadNativeApps() {
        if !this.IsOpen() || !this.lv
            return
        StopFileScanWorker(this.scanWorkerPid, this.scanOutputPath,
            this.scanWorkerCreationIdentity)
        this.scanWorkerPid := 0
        this.scanWorkerCreationIdentity := ""
        this.scanOutputPath := ""
        SetTimer(this.scanPollTimer, 0)
        SetTimer(this.scanConsumeTimer, 0)
        this.appList := []
        this.scanSeen := Map()
        this.scanSeen.CaseSense := "Off"
        this.scanTruncated := false
        this.pendingScanPaths := []
        this.pendingScanIndex := 0
        this.lv.Delete()
        try WinSetTitle("搜索 ⚡原生深扫引擎⚡（扫描中）", this.gui.Hwnd)
        maximumResults := Max(1000, Min(20000, App.everythingMaxResults * 20))
        scanWorker := StartFileScanWorker("search", "", true, maximumResults,
            App.nativeScanTimeoutSeconds)
        if scanWorker {
            this.scanWorkerPid := scanWorker.Pid
            this.scanWorkerCreationIdentity := scanWorker.CreationIdentity
            this.scanOutputPath := scanWorker.Path
            SetTimer(this.scanPollTimer, 100)
        } else
            try WinSetTitle("搜索 ⚡原生深扫引擎⚡（启动失败）", this.gui.Hwnd)
    }

    PollNativeScan(*) {
        if !this.IsOpen() {
            SetTimer(this.scanPollTimer, 0)
            return
        }
        if FileExist(this.scanOutputPath) {
            SetTimer(this.scanPollTimer, 0)
            this.pendingScanPaths := ReadFileScanResult(this.scanOutputPath, &wasTruncated)
            this.scanTruncated := wasTruncated
            try FileDelete(this.scanOutputPath)
            this.scanWorkerPid := 0
            this.scanWorkerCreationIdentity := ""
            this.scanOutputPath := ""
            this.pendingScanIndex := 0
            SetTimer(this.scanConsumeTimer, 15)
            return
        }
        if (this.scanWorkerPid
            && (!ProcessExist(this.scanWorkerPid)
                || (this.scanWorkerCreationIdentity != ""
                    && GetProcessCreationIdentity(this.scanWorkerPid) != this.scanWorkerCreationIdentity))) {
            SetTimer(this.scanPollTimer, 0)
            StopFileScanWorker(this.scanWorkerPid, this.scanOutputPath,
                this.scanWorkerCreationIdentity)
            this.scanWorkerPid := 0
            this.scanWorkerCreationIdentity := ""
            this.scanOutputPath := ""
            try WinSetTitle("搜索 ⚡原生深扫引擎⚡（扫描失败）", this.gui.Hwnd)
        }
    }

    ConsumeNativeScanBatch(*) {
        if !this.IsOpen() {
            SetTimer(this.scanConsumeTimer, 0)
            return
        }
        batchEnd := Min(this.pendingScanPaths.Length, this.pendingScanIndex + 7)
        while (this.pendingScanIndex < batchEnd) {
            this.pendingScanIndex++
            this.ProcessScannedItem(this.pendingScanPaths[this.pendingScanIndex])
        }
        if (this.pendingScanIndex >= this.pendingScanPaths.Length) {
            SetTimer(this.scanConsumeTimer, 0)
            this.pendingScanPaths := []
            this.pendingScanIndex := 0
            try WinSetTitle(this.scanTruncated
                ? "搜索 ⚡原生深扫引擎⚡（结果已截断）"
                : "搜索 ⚡原生深扫引擎⚡", this.gui.Hwnd)
        }
    }

    ProcessScannedItem(filePath) {
        canonicalPath := GetCanonicalPath(filePath)
        if this.scanSeen.Has(canonicalPath)
            return
        this.scanSeen[canonicalPath] := true
        if !IsSupportedMonitorFile(filePath)
            return

        SplitPath(filePath, , , &extension, &nameNoExt)
        if RegExMatch(nameNoExt, "i)uninstall|卸载|help|帮助|readme|unins000")
            return
        iconIndex := GetFileIconIndex(filePath, this.imageList)
        item := {Name: nameNoExt, Path: filePath, IconIdx: iconIndex}
        this.appList.Push(item)
        term := StrLower(Trim(this.searchEdit.Value))
        if (term == "" || InStr(StrLower(nameNoExt), term) || InStr(StrLower(filePath), term))
            this.lv.Add("Icon" iconIndex, nameNoExt, filePath)
    }

    FilterNativeList(*) {
        if !this.IsOpen()
            return
        this.lv.Opt("-Redraw")
        this.lv.Delete()
        term := StrLower(Trim(this.searchEdit.Value))
        for item in this.appList {
            if (term == "" || InStr(StrLower(item.Name), term) || InStr(StrLower(item.Path), term))
                this.lv.Add("Icon" item.IconIdx, item.Name, item.Path)
        }
        this.lv.Opt("+Redraw")
    }

    Select(*) {
        if !this.IsOpen()
            return
        row := this.lv.GetNext(0)
        if (row > 0 && this.ownerDialog.IsOpen())
            this.ownerDialog.edit.Value := this.lv.GetText(row, 2)
        this.Close()
    }

    ClearIconCache() {
        if !this.imageList
            return
        prefix := String(this.imageList) "_"
        keysToRemove := []
        for key in App.iconCache
            if InStr(key, prefix) == 1
                keysToRemove.Push(key)
        for key in keysToRemove
            App.iconCache.Delete(key)
    }

    Close(*) {
        SetTimer(this.initialSearchTimer, 0)
        SetTimer(this.searchTimer, 0)
        SetTimer(this.scanPollTimer, 0)
        SetTimer(this.scanConsumeTimer, 0)
        StopFileScanWorker(this.scanWorkerPid, this.scanOutputPath,
            this.scanWorkerCreationIdentity)
        this.scanWorkerPid := 0
        this.scanWorkerCreationIdentity := ""
        this.scanOutputPath := ""
        if this.gui
            try OnMessage(Win32.WM_MOUSEMOVE, this.mouseHandler, 0)
        this.ClearIconCache()
        if this.imageList {
            IL_Destroy(this.imageList)
            this.imageList := 0
        }
        this.tooltip.Hide()
        this.DestroyGui()
        this.lv := ""
        this.searchEdit := ""
        this.searchEditBackground := ""
        this.selectButton := ""
        this.appList := []
        this.scanSeen := Map()
        this.scanSeen.CaseSense := "Off"
        this.scanTruncated := false
        this.pendingScanPaths := []
        this.pendingScanIndex := 0
        this.hoverRow := 0
    }
}

class DarkTooltipWindow extends ManagedWindow {
    __New() {
        this.hoverTimer := 0
        this.lastHwnd := 0
        this.lastRow := 0
        this.textControl := ""
    }

    HandleMouseMove(wParam, lParam, msg, hwnd) {
        if (hwnd == this.lastHwnd) {
            if (hwnd != Main.lv.Hwnd)
                return
            probe := Buffer(24, 0)
            NumPut("Int", SignedWord(lParam), probe, 0)
            NumPut("Int", SignedWord(lParam >> 16), probe, 4)
            probeRow := SendMessage(Win32.LVM_HITTEST, 0, probe.Ptr, Main.lv.Hwnd)
            probeRow := probeRow >= 0 ? probeRow + 1 : 0
            if (probeRow == this.lastRow)
                return
        }
        this.lastHwnd := hwnd
        this.lastRow := 0
        this.CancelTimer()
        this.Hide()

        try {
            control := GuiCtrlFromHwnd(hwnd)
            if !control
                return
            text := ""
            if (control == Main.lv) {
                hitTestInfo := Buffer(24, 0)
                point := Buffer(8)
                DllCall("user32\GetCursorPos", "Ptr", point)
                DllCall("user32\ScreenToClient", "Ptr", Main.lv.Hwnd, "Ptr", point)
                NumPut("Int", NumGet(point, 0, "Int"), hitTestInfo, 0)
                NumPut("Int", NumGet(point, 4, "Int"), hitTestInfo, 4)
                result := SendMessage(Win32.LVM_HITTEST, 0, hitTestInfo.Ptr, Main.lv.Hwnd)
                if (result != -1) {
                    this.lastRow := result + 1
                    path := Main.lv.GetText(result + 1, 3)
                    if App.appStates.Has(path)
                        text := this.BuildEnvironmentText(App.appStates[path])
                }
            } else if (control == Main.btnAdd) {
                text := "添加应用或脚本`n支持选择文件夹批量导入，支持直接拖拽文件到列表中"
            } else if (control == Main.btnDel) {
                text := "删除列表中选中的监控项目`n（快捷键: Delete）"
            } else if (control == Main.btnPause) {
                text := "暂停或恢复指定项目的监控状态`n可多选后一键反转状态"
            } else if (control == Main.btnSet) {
                text := "调整扫描频率与失败重启延迟的等待规则"
            } else if (control == Main.btnLog) {
                text := "查看当前运行日志与批处理输出"
            } else if (control == Main.btnHelp) {
                text := "查看进程守护小助手的详细使用说明跟特性"
            }
            if (text != "") {
                this.hoverTimer := ObjBindMethod(this, "Show", text)
                SetTimer(this.hoverTimer, -500)
            }
        }
    }

    BuildEnvironmentText(state) {
        hasEnvironment := (state.HasOwnProp("WorkDir") && state.WorkDir != "")
            || (state.HasOwnProp("Args") && state.Args != "")
            || (state.HasOwnProp("EnvVars") && state.EnvVars != "")
        if !hasEnvironment
            return ""
        text := "独立环境配置 💡`n"
        if (state.HasOwnProp("WorkDir") && state.WorkDir != "")
            text .= "📁 工作目录: " state.WorkDir "`n"
        if (state.HasOwnProp("Args") && state.Args != "")
            text .= "⚙️ 启动参数: " state.Args "`n"
        if (state.HasOwnProp("EnvVars") && state.EnvVars != "") {
            count := 0
            Loop Parse, state.EnvVars, "`n", "`r" {
                if Trim(A_LoopField) != ""
                    count++
            }
            text .= "🌿 环境变量: " count " 项`n"
        }
        return text
    }

    Show(text, *) {
        this.hoverTimer := 0
        if !this.IsOpen() {
            this.gui := Gui("-Caption +ToolWindow +AlwaysOnTop +LastFound")
            this.gui.BackColor := "202020"
            this.gui.SetFont("s9 cE5E5E5", "Microsoft YaHei")
            this.gui.MarginX := 12
            this.gui.MarginY := 8
            this.textControl := this.gui.Add("Text", "Background202020", text)
            if (VerCompare(A_OSVersion, "10.0.18362") >= 0) {
                try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.gui.Hwnd, "Int", 33, "Int*", 2, "Int", 4)
                try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.gui.Hwnd, "Int", 2, "Int*", 2, "Int", 4)
            }
        } else {
            this.textControl.Text := text
        }
        this.ResizeTextControl(text)
        point := Buffer(8)
        DllCall("user32\GetCursorPos", "Ptr", point)
        mouseX := NumGet(point, 0, "Int")
        mouseY := NumGet(point, 4, "Int")
        this.gui.Show("x" (mouseX + 10) " y" (mouseY + 20) " NoActivate AutoSize")
    }

    ResizeTextControl(text) {
        deviceContext := DllCall("user32\GetDC", "Ptr", this.textControl.Hwnd, "Ptr")
        if !deviceContext
            return
        fontHandle := SendMessage(0x0031, 0, 0, this.textControl.Hwnd) ; WM_GETFONT
        previousFont := fontHandle
            ? DllCall("gdi32\SelectObject", "Ptr", deviceContext, "Ptr", fontHandle, "Ptr") : 0
        try {
            dpi := 96
            try dpi := DllCall("user32\GetDpiForWindow", "Ptr", this.gui.Hwnd, "UInt")
            if !dpi
                dpi := 96
            maxWidthPx := Round(440 * dpi / 96)
            naturalWidthPx := 1
            Loop Parse, text, "`n", "`r" {
                lineText := A_LoopField != "" ? A_LoopField : " "
                extent := Buffer(8, 0)
                if DllCall("gdi32\GetTextExtentPoint32W", "Ptr", deviceContext,
                    "Str", lineText, "Int", StrLen(lineText), "Ptr", extent, "Int")
                    naturalWidthPx := Max(naturalWidthPx, NumGet(extent, 0, "Int"))
            }
            textWidthPx := Min(naturalWidthPx, maxWidthPx)
            measureRect := Buffer(16, 0)
            NumPut("Int", textWidthPx, measureRect, 8)
            DllCall("user32\DrawTextW", "Ptr", deviceContext, "Str", text, "Int", -1,
                "Ptr", measureRect, "UInt", 0x0C50, "Int") ; CALCRECT | NOPREFIX | WORDBREAK | EXPANDTABS
            textHeightPx := Max(1, NumGet(measureRect, 12, "Int"))
            this.textControl.Move(,, Max(1, Ceil(textWidthPx * 96 / dpi)),
                Max(1, Ceil(textHeightPx * 96 / dpi)))
        } finally {
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", deviceContext, "Ptr", previousFont, "Ptr")
            DllCall("user32\ReleaseDC", "Ptr", this.textControl.Hwnd, "Ptr", deviceContext)
        }
    }

    CancelTimer() {
        if this.hoverTimer {
            SetTimer(this.hoverTimer, 0)
            this.hoverTimer := 0
        }
    }

    Hide(*) {
        this.CancelTimer()
        if this.IsOpen()
            try this.gui.Hide()
    }
}
