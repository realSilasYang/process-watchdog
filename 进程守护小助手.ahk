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
#Include app\UI\InteractionPresenter.ahk
#Include app\UI\MainVisualPipeline.ahk
#Include app\UI\DarkMessageBox.ahk
#Include app\RuntimeAdapters.ahk
#Include app\WatchlistCommands.ahk
#Include app\ApplicationTelemetry.ahk
#Include app\SystemIntegration.ahk
#Include app\ApplicationState.ahk
#Include app\MainWindowState.ahk
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
