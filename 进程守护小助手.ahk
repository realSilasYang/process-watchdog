/*
================================================================================
    进程守护小助手
    开发语言：AutoHotkey v2
    主要功能：后台进程、脚本、启动项守护与定时保活。
    【核心特性说明】
    1. 多态守护：支持原生应用、解释型脚本、批处理文件和快捷方式等常见启动入口。
    2. 进程探活：优先使用原生快照与已核验 PID，命令行证据由后台 WMI 快照补充。
    3. 深色界面：通过 Windows 原生窗口、主题和 Shell 接口统一适配标题栏、控件与图标。
    4. 异常处理：快速重试耗尽后改为间隔自动重试，避免连续崩溃造成资源过度占用。
================================================================================
*/

;@Ahk2Exe-SetName 进程守护小助手
;@Ahk2Exe-SetDescription 进程、脚本和快捷方式守护工具
;@Ahk2Exe-SetVersion 2.0.5.0
;@Ahk2Exe-SetCopyright Copyright (c) 2026 进程守护小助手 contributors
;@Ahk2Exe-SetMainIcon assets\app\watchdog.ico

#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut ; 严格警告写入诊断输出，避免后台启动被不可见对话框阻塞

#Include src\Platform\Win32.ahk
#Include src\Localization\EnglishStrings.ahk
#Include src\Localization\TraditionalHongKongStrings.ahk
#Include src\Localization\TraditionalTaiwanStrings.ahk
#Include src\Localization\JapaneseStrings.ahk
#Include src\Localization\VietnameseStrings.ahk
#Include src\Localization\KoreanStrings.ahk
#Include src\Localization\SpanishStrings.ahk
#Include src\Localization\FrenchStrings.ahk
#Include src\Localization\PortugueseBrazilStrings.ahk
#Include src\Localization\RussianStrings.ahk
#Include src\Localization\GermanStrings.ahk
#Include src\Localization\ItalianStrings.ahk
#Include src\Localization\LocalizationService.ahk
#Include src\UI\UiThemeService.ahk
#Include src\Config\IniFieldCodec.ahk
#Include src\Config\DisplayConfigCodec.ahk
#Include src\Config\MaintenanceConfigCodec.ahk
#Include src\Config\AppConfigSnapshotService.ahk
#Include src\Config\RuntimeSettingsService.ahk
#Include src\Config\WindowLayoutService.ahk
#Include src\Config\WatchlistPersistenceService.ahk
#Include src\Config\WatchdogConfigRepository.ahk
#Include src\Update\ApplicationVersionInfo.ahk
#Include src\Update\ApplicationUpdateService.ahk
#Include src\Core\GuardTypes.ahk
#Include src\Core\GuardStateMachine.ahk
#Include src\Maintenance\MaintenanceStateMachine.ahk
#Include src\Core\GuardWorkGate.ahk
#Include src\Core\GuardMutationQueue.ahk
#Include src\Core\WatchdogScheduler.ahk
#Include src\Core\RestartPolicy.ahk
#Include src\Core\TargetSupervisor.ahk
#Include src\Core\TargetSpecs.ahk
#Include src\Core\TargetSpecsService.ahk
#Include src\Core\TargetIdentityService.ahk
#Include src\Core\AppConfigHistoryService.ahk
#Include src\Execution\TargetLauncher.ahk
#Include src\Execution\TargetStopper.ahk
#Include src\Execution\EverythingRuntimeService.ahk
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
#Include src\Core\TargetContentRelocationService.ahk
#Include src\Inspection\FileScanService.ahk
#Include src\Diagnostics\DiagnosticBundleService.ahk
#Include src\UI\IconResourceRegistry.ahk
#Include src\UI\SvgRenderLibrary.ahk
#Include src\UI\UiInteractionRegistry.ahk
#Include src\UI\ControlAccessibilityService.ahk
#Include src\UI\MainListProjection.ahk
#Include src\UI\ListViewPseudoHeader.ahk
#Include src\UI\WindowHierarchy.ahk
#Include src\UI\ManagedWindow.ahk
#Include app\UI\InteractionPresenter.ahk
#Include app\UI\ListViewSelectionPresenter.ahk
#Include app\UI\ContextMenuPresenter.ahk
#Include app\UI\StatusBarPresenter.ahk
#Include app\UI\MainVisualPipeline.ahk
#Include app\UI\DarkInlineEditThemeRegistry.ahk
#Include app\UI\DarkMessageBox.ahk
#Include app\RuntimeAdapters.ahk
#Include app\WatchlistCommands.ahk
#Include app\ApplicationTelemetry.ahk
#Include app\SystemIntegration.ahk
#Include app\ApplicationState.ahk
#Include app\MainWindowState.ahk
#Include app\MainWindowController.ahk
#Include app\GuiModuleRegistry.ahk
#Include app\Windows\CustomDisplayDialog.ahk
#Include app\Windows\MaintenanceSettingsDialog.ahk
#Include app\Windows\EnvironmentSettingsDialog.ahk
#Include app\Windows\AddItemDialog.ahk
#Include app\Windows\SettingsWindow.ahk
#Include app\Windows\LogWindow.ahk
#Include app\Windows\HelpWindow.ahk
#Include app\Windows\BatchOutputLogNoticeWindow.ahk
#Include app\Windows\SupportInfoWindow.ahk
#Include app\Windows\DonationWindow.ahk
#Include app\Windows\ApplicationSearchDialog.ahk
#Include app\Windows\DarkTooltipWindow.ahk
#Include app\Windows\HistoryToastWindow.ahk
#Include app\Windows\TargetRelocationPrompt.ahk
#Include src\Core\GuardRuntime.ahk
; 业务运行态只有一个稳定根对象；函数只修改实例属性，不再重新绑定全局变量。
LocalizationService.Configure(LocalizationService.ReadConfiguredLanguage(
    A_ScriptDir "\watchdog.ini"))
LocalizationService.ConfigureUiFont(LocalizationService.ReadConfiguredUiFont(
    A_ScriptDir "\watchdog.ini"))
UiThemeService.Configure(UiThemeService.ReadConfiguredTheme(
    A_ScriptDir "\watchdog.ini"))
global App := ApplicationState()

; 按钮绘制与鼠标分发必须早于权限提示框安装，确保启动失败界面同样可操作。
OnMessage(Win32.WM_MEASUREITEM, OnMeasureApplicationControl)
OnMessage(Win32.WM_DRAWITEM, OnDrawApplicationControl)
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
OnMessage(Win32.WM_SETTINGCHANGE, OnSystemSettingChange)
OnMessage(Win32.AHK_NOTIFYICON, OnTrayNotification)
OnExit(ShutdownApplication)

if ProcessMaintenanceCommandClient()
    ExitApp()

OnSystemSettingChange(*) {
    if UiThemeService.GetRequestedTheme() != "auto"
        return
    ; Windows 会在一次主题切换中连续发送多条设置消息，合并为一次重建，
    ; 避免主列表和下级窗口被重复销毁、创建。
    SetTimer(ApplySystemThemeChange, -250)
}

ApplySystemThemeChange(*) {
    global GuiModules
    if !IsSet(Main) || !UiThemeService.HandleSystemSettingChange()
        return
    RefreshMainWindowTheme()
    if IsSet(GuiModules) {
        GuiModules.Shutdown()
        GuiModules := GuiModuleRegistry(Main.gui)
    }
}
/*
 * 守护进程检查、计划任务和按管理员身份启动目标都需要提升权限。
 * 当前实例未提升时，只负责用相同参数请求 UAC 后退出，不继续创建运行态资源。
 */
if not A_IsAdmin {
    try {
        relaunchArguments := ""
        for relaunchArgument in A_Args
            relaunchArguments .= " " QuoteCommandLineArgument(relaunchArgument)
        Run('*RunAs "' A_ScriptFullPath '"' relaunchArguments)
    } catch {
        ShowDarkMsgBox(Tr("守护监控操作必须具备高级别系统读写权限，请以管理员身份运行此程序！"),
            Tr("系统权限拦截"), "Error")
    }
    ExitApp()
}

/*
 * 命名互斥锁是唯一的单实例裁决依据。普通重复启动只激活现有主窗口；重载接班和
 * 后台维护命令则先把请求交给原实例，避免两个守护循环短暂并行。
 */
startupHandoffPid := GetReloadHandoffPid()
if startupHandoffPid
    try ProcessWaitClose(startupHandoffPid, 60)
startupMutexExists := false
App.mutexHandle := AcquireApplicationMutex(&startupMutexExists)
if !App.mutexHandle {
    ShowDarkMsgBox(Tr("无法建立单实例运行锁，小助手将退出。"), Tr("启动失败"), "Error")
    ExitApp()
}
if startupMutexExists {
    DetectHiddenWindows(True)
    existingWindow := FindRunningApplicationWindow()
    if (!existingWindow
        && App.maintenanceCoordinator.PendingCommands.Length) {
        Loop 30 {
            Sleep(100)
            existingWindow := FindRunningApplicationWindow()
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
        existingWindowSelector := "ahk_id " existingWindow
        if WinExist(existingWindowSelector) {
            ; 窗口可能在每一步之间因重载而退出，因此显式指定 HWND 并分别容错。
            try WinShow(existingWindowSelector)
            try WinRestore(existingWindowSelector)
            try WinActivate(existingWindowSelector)
        }
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
try DllCall("shell32\SetCurrentProcessExplicitAppUserModelID", "WStr", Tr("进程守护小助手"))

applicationIconPath := GetApplicationIconPath()
if FileExist(applicationIconPath) {
    TraySetIcon(applicationIconPath)
    SetWindowIcon(A_ScriptHwnd, applicationIconPath)
}

; 主窗口在共享服务之后创建；控件安装前先建立唯一的长期窗口所有者。
global Main := MainWindow()

; 管理员进程默认会被 UIPI（用户界面特权隔离）阻止接收普通资源管理器的拖放消息。
; 这里只放行文件拖放所需的三类消息，不改变其它跨权限窗口消息的过滤规则。
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

; 首次运行只创建带就地注释的设置分区，不预设任何守护对象。
App.runtimeSettingsService.EnsureExists()
App.runtimeSettingsService.Apply(App, App.runtimeSettingsService.Load())
CleanupBatchLogs()

; 先读取持久化布局再创建控件，避免首次显示时从默认尺寸跳变到用户保存的尺寸。
App.windowLayoutService.Apply(App, App.windowLayoutService.Load())
; 托盘菜单是主窗口隐藏后的应用级入口；显示设置热切换时会调用同一函数原位重建。
ConfigureTrayMenu() {
    A_IconTip := Tr("进程守护小助手")
    A_TrayMenu.Delete()
    A_TrayMenu.Add(Tr("显示主界面"), ShowMainGui)
    A_TrayMenu.Add(Tr("重新加载"), ReloadScript)
    A_TrayMenu.Add(Tr("退出程序"), ExitProgram)
    A_TrayMenu.Default := Tr("显示主界面")
    A_TrayMenu.ClickCount := 1
}

ConfigureTrayMenu()

ConfigureMainCommandButtonMetrics() {
    compactLayout := LocalizationService.UsesCompactLayout()
    Main.settingsButtonWidth := compactLayout ? 70 : 80
    Main.supportButtonWidth := compactLayout ? 100 : 110
    Main.donateButtonWidth := compactLayout ? 70 : 80
    Main.commandButtonGap := 10
    Main.commandButtonRightMargin := 10
}

GetMainCommandButtonPositions(clientWidth) {
    donateX := clientWidth - Main.commandButtonRightMargin
        - Main.donateButtonWidth
    supportX := donateX - Main.commandButtonGap
        - Main.supportButtonWidth
    settingsX := supportX - Main.commandButtonGap
        - Main.settingsButtonWidth
    return {Settings: settingsX, Support: supportX, Donate: donateX}
}

GetControlRectInParentClient(control, parentHwnd) {
    try controlHwnd := control.Hwnd
    catch
        return false
    if !controlHwnd || !DllCall("user32\IsWindow", "Ptr", controlHwnd, "Int")
        return false
    rect := Buffer(16, 0)
    if !DllCall("user32\GetWindowRect", "Ptr", controlHwnd, "Ptr", rect, "Int")
        return false
    DllCall("user32\MapWindowPoints", "Ptr", 0, "Ptr", parentHwnd,
        "Ptr", rect, "UInt", 2, "Int")
    return {
        Left: NumGet(rect, 0, "Int"),
        Top: NumGet(rect, 4, "Int"),
        Right: NumGet(rect, 8, "Int"),
        Bottom: NumGet(rect, 12, "Int")
    }
}

GetMainCommandButtonBounds() {
    bounds := false
    for button in [Main.btnSet, Main.btnSupport, Main.btnDonate] {
        rect := GetControlRectInParentClient(button, Main.gui.Hwnd)
        if !rect
            continue
        if !bounds {
            bounds := rect
            continue
        }
        bounds.Left := Min(bounds.Left, rect.Left)
        bounds.Top := Min(bounds.Top, rect.Top)
        bounds.Right := Max(bounds.Right, rect.Right)
        bounds.Bottom := Max(bounds.Bottom, rect.Bottom)
    }
    return bounds
}

RedrawMainCommandButtonLayout(oldBounds, newBounds) {
    if !oldBounds && !newBounds
        return
    bounds := oldBounds ? oldBounds : newBounds
    if oldBounds && newBounds {
        bounds.Left := Min(bounds.Left, newBounds.Left)
        bounds.Top := Min(bounds.Top, newBounds.Top)
        bounds.Right := Max(bounds.Right, newBounds.Right)
        bounds.Bottom := Max(bounds.Bottom, newBounds.Bottom)
    }
    ; 扩大两个物理像素，完整擦除圆角抗锯齿边缘，再只重绘命令栏受影响区域。
    redrawRect := Buffer(16, 0)
    NumPut("Int", Max(0, bounds.Left - 2), redrawRect, 0)
    NumPut("Int", Max(0, bounds.Top - 2), redrawRect, 4)
    NumPut("Int", bounds.Right + 2, redrawRect, 8)
    NumPut("Int", bounds.Bottom + 2, redrawRect, 12)
    DllCall("user32\RedrawWindow", "Ptr", Main.gui.Hwnd, "Ptr", redrawRect,
        "Ptr", 0, "UInt", Win32.RDW_LAYOUT_REFRESH, "Int")
}

PositionMainCommandButtons(clientWidth) {
    oldBounds := GetMainCommandButtonBounds()
    positions := GetMainCommandButtonPositions(clientWidth)
    Main.btnSet.Move(positions.Settings, 15,
        Main.settingsButtonWidth, 30)
    Main.btnSupport.Move(positions.Support, 15,
        Main.supportButtonWidth, 30)
    Main.btnDonate.Move(positions.Donate, 15,
        Main.donateButtonWidth, 30)
    RedrawMainCommandButtonLayout(oldBounds, GetMainCommandButtonBounds())
}

; 主界面使用可多选、可拖动排序且支持标签编辑的 ListView 展示守护对象。
InitializeApplicationWindow(Main.gui)

; 命令栏保持固定按钮高度；宽度只按文案需要分配，剩余空间留给窗口拖动和缩放。
Main.btnAdd  := Main.gui.Add("Text", "x10 y15 w80 h30 Center 0x200 Background"
    UiThemeService.Color("Add") " c" UiThemeService.Color("ButtonText"),
    Tr("➕ 添加"))



Main.btnPause:= Main.gui.Add("Text", "x+10 y15 w80 h30 Center 0x200 Background"
    UiThemeService.Color("PauseDisabled") " c"
        UiThemeService.Color("DisabledButtonText"),
    Tr("⏸️ 暂停"))
Main.btnDel  := Main.gui.Add("Text", "x+10 y15 w80 h30 Center 0x200 Background"
    UiThemeService.Color("DeleteDisabled") " c"
        UiThemeService.Color("DisabledButtonText"),
    Tr("🗑️ 删除"))

ConfigureMainCommandButtonMetrics()
buttonPositions := GetMainCommandButtonPositions(App.savedWidth)
Main.btnSet  := Main.gui.Add("Text", "x" buttonPositions.Settings " y15 w" Main.settingsButtonWidth " h30 Center 0x200 Background" UiThemeService.Color("Toolbar") " c" UiThemeService.Color("ToolbarText"), Tr("设置"))
Main.btnSupport := Main.gui.Add("Text", "x" buttonPositions.Support " y15 w" Main.supportButtonWidth " h30 Center 0x200 Background" UiThemeService.Color("Toolbar") " c" UiThemeService.Color("ToolbarText"), Tr("帮助信息"))
Main.btnDonate := Main.gui.Add("Text", "x" buttonPositions.Donate " y15 w" Main.donateButtonWidth " h30 Center 0x200 Background" UiThemeService.Color("Toolbar") " c" UiThemeService.Color("ToolbarText"), Tr("捐赠"))
RegisterHoverButton(Main.btnAdd, UiThemeService.Color("Add"))
SetButtonLeadingTextSlot(Main.btnAdd, 20, 4)
RegisterHoverButton(Main.btnPause, UiThemeService.Color("PauseDisabled"),
    UiThemeService.Color("PauseDisabled"), "",
    UiThemeService.Color("DisabledButtonText"))
SetButtonLeadingTextSlot(Main.btnPause, 20, 4)
RegisterHoverButton(Main.btnDel, UiThemeService.Color("DeleteDisabled"),
    UiThemeService.Color("DeleteDisabled"), "",
    UiThemeService.Color("DisabledButtonText"))
SetButtonLeadingTextSlot(Main.btnDel, 20, 4)
RegisterHoverButton(Main.btnSet, UiThemeService.Color("Toolbar"))
RegisterHoverButton(Main.btnSupport, UiThemeService.Color("Toolbar"))
RegisterHoverButton(Main.btnDonate, UiThemeService.Color("Toolbar"))
SetButtonLucideIcon(Main.btnSet, "settings.svg", 15, 6)
SetButtonLucideIcon(Main.btnSupport, "circle-question-mark.svg", 15, 6)
SetButtonLucideIcon(Main.btnDonate, "heart.svg", 15, 6)
; 主列表统一使用 28px 逻辑尺寸，并按窗口 DPI 缩放。
Main.appIcons := CreateMainImageList(Main.statusIconIndices)

Main.gui.SetFont("s12 c" UiThemeService.Color("Text"),
    LocalizationService.GetUiFontName()) ; 列表单独使用较大字号，便于连续扫描名称和状态。

; 内部列保持名称、状态、路径、序号和状态语义排序键，显示顺序另设为
; 序号、名称、状态。两个隐藏列分别承担稳定身份和本地化无关的状态排序。
Main.lv := Main.gui.Add("ListView", "x10 y88 w" (App.savedWidth - 20)
    " h" (App.savedHeight - 113) " Background"
    UiThemeService.Color("Surface") " c" UiThemeService.Color("Text")
    " Report +LV0x10002 -E0x200 +ReadOnly -HScroll -Hdr",
    [Tr("守护对象"), Tr("状态"), Tr("完整路径"), Tr("序号"), ""])
; 报表视图从小图标槽读取图像；显式传入槽位 1，避免系统附着到不会显示的大图标槽。
Main.lv.SetImageList(Main.appIcons, 1)
Main.lv.IL := Main.appIcons

Main.gui.SetFont("s10 c" UiThemeService.Color("Text"),
    LocalizationService.GetUiFontName()) ; 恢复主窗口默认字号，避免后续控件继承列表字体。

Main.lv.ModifyCol(1, App.savedColumn1)
statusColumnWidth := LocalizationService.UsesCompactLayout()
    ? 180
    : Min(Max(App.savedColumn2, 200), 220)
Main.lv.ModifyCol(2, statusColumnWidth)
Main.lv.ModifyCol(3, 0) ; 隐藏路径辅助列
Main.lv.ModifyCol(4, "Center 48")
Main.lv.ModifyCol(5, 0) ; 隐藏状态语义排序键
Main.listProjection.ApplyColumnOrder(Main.lv)
Main.listSelectionPresenter := ListViewSelectionPresenter(Main.lv)
Main.listHeader := ListViewPseudoHeader(Main.gui, Main.lv, [
    {Column: 4, Label: Tr("序号"), Align: "Center", SortOptions: "Integer",
        SkipAscending: true},
    {Column: 1, Label: Tr("守护对象"), SortOptions: "Logical"},
    {Column: 5, Label: Tr("状态"), SortOptions: "Logical"}
], {
    BackgroundColor: UiThemeService.Color("Toolbar"),
    TextColor: UiThemeService.Color("MutedText"),
    FontName: LocalizationService.GetLanguageSystemUiFontName(),
    CursorRegistrar: RegisterHandCursorControl,
    RestoreColumn: 4,
    RestoreSortOptions: "Integer Center",
    OnBeforeSort: PrepareMainListTemporarySort,
    OnSortChanged: OnMainListTemporarySortChanged
})
LayoutMainListHeader(App.savedWidth)

SetDarkListView(Main.lv.Hwnd)

Main.statsText := Main.gui.Add("Text", "x10 y" (App.savedHeight - 20)
    " w" (App.savedWidth - 20)
    " h20 c" UiThemeService.Color("MutedText") " Background"
    UiThemeService.Color("Window") " +0xD", Tr("载入中..."))
Main.statsText.SetFont("s10 bold",
    LocalizationService.GetLanguageSystemUiFontName())
Main.statsPresenter := SvgStatusBarPresenter(Main.statsText)

RegisterButtonClick(Main.btnAdd, AddItem)
RegisterButtonClick(Main.btnPause, ToggleItemPause)
RegisterButtonClick(Main.btnDel, DelItem)
    RegisterButtonClick(Main.btnSet, ShowSettings)
    RegisterButtonClick(Main.btnSupport, ShowSupportInfo)
    RegisterButtonClick(Main.btnDonate, ShowDonation)

; 选择变化只刷新命令状态，不重新投影列表或触发守护对象初始化。
Main.lv.OnEvent("ItemSelect", OnLVSelectChange)
Main.lv.OnEvent("ItemFocus", OnLVSelectChange)

OnLVSelectChange(*) {
    RefreshMainCommandState()
}

RefreshMainCommandState(forceRefresh := false) {
    static lastState := ""
    themeStatePrefix := UiThemeService.GetActualTheme() "_"

    row := 0
    selCount := 0
    firstState := -1 ; 用来记录第一个选中的状态
    allSameState := true

    Loop {
        row := Main.lv.GetNext(row)
        if (row == 0)
            break

        chkPath := Main.lv.GetText(row, 3)
        if App.appStates.Has(chkPath) {
            selCount++
            currentState := App.appStates[chkPath].Enabled
            if (firstState == -1) {
                firstState := currentState
            } else if (firstState != currentState) {
                allSameState := false
            }
        }
    }

    if (selCount > 0) {
        newState := themeStatePrefix "active_"
            . (allSameState && firstState != -1
                ? (firstState ? "pause" : "resume") : "reverse")
        if (!forceRefresh && lastState == newState)
            return
        lastState := newState

        SetButtonTextColor(Main.btnDel, UiThemeService.Color("ButtonText"))
        SetButtonTextColor(Main.btnPause, UiThemeService.Color("ButtonText"))
        SetHoverButtonColors(Main.btnDel, UiThemeService.Color("Delete"))
        SetHoverButtonColors(Main.btnPause, UiThemeService.Color("Pause"))
        SetButtonBackground(Main.btnDel, UiThemeService.Color("Delete"))
        SetButtonBackground(Main.btnPause, UiThemeService.Color("Pause"))
        if (allSameState && firstState != -1) {
            if (firstState) {
                Main.btnPause.Text := Tr("⏸️ 暂停")
            } else {
                Main.btnPause.Text := Tr("▶️ 恢复")
            }
        } else {
            ; 选中的守护对象里既有运行中的，也有暂停的，统一显示「反转状态」
            Main.btnPause.Text := Tr("🔄 反转状态")
        }

        Main.btnDel.Redraw()
        Main.btnPause.Redraw()
        return
    }

    newState := themeStatePrefix "inactive"
    if (!forceRefresh && lastState == newState)
        return
    lastState := newState

    SetButtonTextColor(Main.btnDel,
        UiThemeService.Color("DisabledButtonText"))
    SetButtonTextColor(Main.btnPause,
        UiThemeService.Color("DisabledButtonText"))
    SetHoverButtonColors(Main.btnDel, UiThemeService.Color("DeleteDisabled"),
        UiThemeService.Color("DeleteDisabled"))
    SetHoverButtonColors(Main.btnPause, UiThemeService.Color("PauseDisabled"),
        UiThemeService.Color("PauseDisabled"))
    SetButtonBackground(Main.btnDel, UiThemeService.Color("DeleteDisabled"))
    SetButtonBackground(Main.btnPause, UiThemeService.Color("PauseDisabled"))
    Main.btnPause.Text := Tr("⏸️ 暂停")
    Main.btnDel.Redraw()
    Main.btnPause.Redraw()
}

/*  * ========================================================================
 * ListView 拖拽排序逻辑
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
        targetRow := SendMessage(0x1012, 0, hitInfo.Ptr, ctrl.Hwnd) ; LVM_HITTEST：按客户区坐标定位列表行。

        insertMark := Buffer(16, 0)
        NumPut("UInt", 16, insertMark, 0)
        if (targetRow >= 0) {
            NumPut("UInt", 0, insertMark, 4)
            NumPut("Int", targetRow, insertMark, 8)
        } else {
            NumPut("Int", -1, insertMark, 8)
        }
        SendMessage(0x10A6, 0, insertMark.Ptr, ctrl.Hwnd) ; LVM_SETINSERTMARK：更新拖拽插入标记。

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

    ; 只捕获稳定路径和目标锚点。真正的顺序、列表和配置更新由共享工作门
    ; 串行提交，避免拖拽与暂停、删除、监控回调同时改写运行态。
    selectedPaths := []
    selectedRows := Map()
    row := 0
    Loop {
        row := ctrl.GetNext(row)
        if (row == 0)
            break
        selectedPath := ctrl.GetText(row, 3)
        ; 列表投影可能因异步刷新短暂滞后于运行态；遇到失效行时放弃重排，
        ; 避免把不完整的顺序写回配置。
        if !App.appStates.Has(selectedPath)
            return
        selectedRows[row] := true
        selectedPaths.Push(selectedPath)
    }

    if (selectedPaths.Length == 0)
        return

    ; 拖回选中对象自身时应保持原顺序；否则移除后再插入会把守护对象意外移到列表顶部。
    if selectedRows.Has(targetRow)
        return

    appendToEnd := targetRow > ctrl.GetCount()
    anchorCandidates := []
    if !appendToEnd {
        Loop ctrl.GetCount() - targetRow + 1 {
            candidateRow := targetRow + A_Index - 1
            if !selectedRows.Has(candidateRow)
                anchorCandidates.Push(ctrl.GetText(candidateRow, 3))
        }
    }
    QueueGuardMutation(ApplyMainListReorder.Bind(selectedPaths,
        anchorCandidates, appendToEnd), "主列表拖拽排序")
}

; 双击名称进入原生标签编辑；其它列仍由完整路径身份保持只读。
Main.lv.OnEvent("DoubleClick", OnDoubleClick)

; 将开关状态放入菜单最右侧的快捷键栏；不同长度的正文不会再让勾号左右漂移。
FormatContextMenuToggleLabel(label, checked) {
    return checked ? label "`t✓" : label
}

SuppressNativeMenuCheckGutter(menuObj) {
    structureSize := A_PtrSize == 8 ? 40 : 28
    menuInfo := Buffer(structureSize, 0)
    NumPut("UInt", structureSize, menuInfo, 0)
    NumPut("UInt", Win32.MIM_STYLE, menuInfo, 4)
    if !DllCall("user32\GetMenuInfo", "Ptr", menuObj.Handle,
            "Ptr", menuInfo, "Int")
        return false
    currentStyle := NumGet(menuInfo, 8, "UInt")
    if currentStyle & Win32.MNS_NOCHECK
        return true
    NumPut("UInt", currentStyle | Win32.MNS_NOCHECK, menuInfo, 8)
    return DllCall("user32\SetMenuInfo", "Ptr", menuObj.Handle,
        "Ptr", menuInfo, "Int") != 0
}

; 右键菜单在打开前根据当前行和展示配置动态刷新；语言切换仍复用同一原生句柄，
; 避免反复销毁带主题样式的菜单时累积 GDI 资源。
ConfigureMainContextMenu(isAdmin := false, maintenanceEnabled := false,
    maintenanceSupported := true, batchLogSupported := false) {
    if Main.contextMenu is Menu {
        contextMenu := Main.contextMenu
        ContextMenuPresenter.Detach(contextMenu.Handle)
        contextMenu.Delete()
    } else
        contextMenu := Menu()
    contextMenu.Add(Tr("📂 打开所在位置"), OpenFileLocation)
    contextMenu.Add(Tr("⏹️ 结束运行"), EndSelectedApp)
    contextMenu.Add(Tr("✒️ 编辑完整路径（F2）"),
        (*) => TriggerEdit(Main.lv, Main.contextTargetRow))
    contextMenu.Add(Tr("🎨 自定义名称和图标"), OpenDisplaySettings)
    adminLabel := FormatContextMenuToggleLabel(
        Tr("🛡️ 以管理员身份运行"), isAdmin)
    contextMenu.Add(adminLabel, ToggleRunAsAdmin)
    contextMenu.Add(Tr("⚙️ 进程识别与启动设置"), OpenEnvSettings)
    maintenanceLabel := FormatContextMenuToggleLabel(
        Tr("🔄 软件升级保护"), maintenanceEnabled)
    contextMenu.Add(maintenanceLabel, OpenMaintenanceSettings)
    if !maintenanceSupported
        contextMenu.Disable(maintenanceLabel)
    if batchLogSupported {
        contextMenu.Add()
        contextMenu.Add(Tr("📄 查看批处理输出日志"), OpenProcessLog)
    }
    ; 所有开关状态都显示在右侧，不再为原生左侧勾选栏预留空白。
    SuppressNativeMenuCheckGutter(contextMenu)
    ContextMenuPresenter.Attach(contextMenu, Main.gui.Hwnd)
    if !(Main.contextMenu is Menu)
        Main.contextMenu := contextMenu
    return contextMenu
}

ConfigureMainContextMenu()
Main.lv.OnEvent("ContextMenu", ShowContextMenu)

CaptureMainStateTexts() {
    stateTexts := Map()
    stateTexts.CaseSense := "Off"
    for path, stateObj in App.appStates
        stateTexts[path] := stateObj.State
    return stateTexts
}

RestoreMainStateTexts(stateTexts) {
    for path, stateText in stateTexts {
        if App.appStates.Has(path)
            App.appStates[path].State := stateText
    }
}

TranslateMainStateTexts(fromLanguage, toLanguage) {
    for _, stateObj in App.appStates {
        stateObj.State := LocalizationService
            .TranslateRenderedTextBetweenLanguages(stateObj.State,
                fromLanguage, toLanguage)
    }
}

RefreshMainWindowDisplay() {
    fontName := LocalizationService.GetUiFontName()
    systemFontName := LocalizationService.GetLanguageSystemUiFontName()
    Main.gui.Title := Tr("进程守护小助手")
    Main.gui.SetFont("s10 c" UiThemeService.Color("Text"), fontName)

    for button in [Main.btnAdd, Main.btnDel, Main.btnPause,
            Main.btnSet, Main.btnSupport, Main.btnDonate]
        button.SetFont("s10 bold", systemFontName)
    Main.lv.SetFont("s12 c" UiThemeService.Color("Text"), fontName)
    RefreshMainStatusIconAlignment()
    if Main.HasOwnProp("listHeader") && IsObject(Main.listHeader)
        Main.listHeader.SetLabels([Tr("序号"), Tr("守护对象"), Tr("状态")])
    Main.statsText.SetFont("s10 bold c"
        UiThemeService.Color("MutedText"), systemFontName)

    Main.btnAdd.Text := Tr("➕ 添加")
    Main.btnDel.Text := Tr("🗑️ 删除")
    Main.btnSet.Text := Tr("设置")
    Main.btnSupport.Text := Tr("帮助信息")
    Main.btnDonate.Text := Tr("捐赠")

    ConfigureMainCommandButtonMetrics()
    Main.gui.GetClientPos(,, &clientWidth)
    PositionMainCommandButtons(clientWidth)

    RefreshMainWindowTheme()

    ; 用户可能已在当前会话拖动列宽。语言或字体切换只更新显示内容，
    ; 不把尚未隐藏窗口落盘的列宽重置为上一次保存值。

    Main.lv.Opt("-Redraw")
    try {
        Loop Main.lv.GetCount() {
            path := NormalizeTargetPath(Main.lv.GetText(A_Index, 3))
            if App.appStates.Has(path)
                SetMainListStatus(A_Index, App.appStates[path].State)
        }
    } finally Main.lv.Opt("+Redraw")

    UpdateStatsUI()
    ConfigureMainContextMenu()
    ConfigureTrayMenu()
    for button in [Main.btnAdd, Main.btnDel, Main.btnPause,
            Main.btnSet, Main.btnSupport, Main.btnDonate]
        button.Redraw()
}

RefreshMainWindowTheme() {
    UiThemeService.ApplyProcessPreference()
    ApplyNativeWindowTheme(Main.gui.Hwnd)
    Main.gui.BackColor := UiThemeService.Color("Window")

    SetHoverButtonColors(Main.btnAdd, UiThemeService.Color("Add"))
    SetButtonBackground(Main.btnAdd, UiThemeService.Color("Add"))
    SetButtonTextColor(Main.btnAdd, UiThemeService.Color("ButtonText"))
    for button in [Main.btnSet, Main.btnSupport, Main.btnDonate] {
        SetHoverButtonColors(button, UiThemeService.Color("Toolbar"))
        SetButtonBackground(button, UiThemeService.Color("Toolbar"))
        SetButtonTextColor(button, UiThemeService.Color("ToolbarText"))
    }
    ; 暂停和删除取决于列表选择状态，不能像固定工具按钮那样直接套一种颜色。
    ; 把同步放在主题刷新边界内，确保手动切换、跟随系统切换和失败回滚都覆盖。
    RefreshMainCommandState(true)

    Main.lv.Opt("Background" UiThemeService.Color("Surface")
        " c" UiThemeService.Color("Text"))
    Main.lv.SetFont("c" UiThemeService.Color("Text"))
    SetDarkListView(Main.lv.Hwnd)
    if App.activeInlineEditHwnd
        DarkInlineEditThemeRegistry.Refresh(App.activeInlineEditHwnd)
    if Main.HasOwnProp("listHeader") && IsObject(Main.listHeader) {
        Main.listHeader.ApplyAppearance(UiThemeService.Color("Toolbar"),
            UiThemeService.Color("MutedText"),
            LocalizationService.GetLanguageSystemUiFontName())
    }
    Main.statsText.Opt("Background" UiThemeService.Color("Window"))
    Main.statsText.SetFont("c" UiThemeService.Color("MutedText"))
    try DllCall("user32\RedrawWindow", "Ptr", Main.gui.Hwnd, "Ptr", 0,
        "Ptr", 0, "UInt", 0x485, "Int")
}

ApplyDisplaySettingsHot(requestedLanguage, requestedFont,
    requestedTheme := "") {
    global GuiModules

    oldRequestedLanguage := LocalizationService.GetRequestedLanguage()
    oldActualLanguage := LocalizationService.GetLanguage()
    oldRequestedFont := LocalizationService.GetRequestedUiFont()
    oldRequestedTheme := UiThemeService.GetRequestedTheme()
    oldStateTexts := CaptureMainStateTexts()
    oldModules := GuiModules
    modulesReplaced := false
    previousCritical := A_IsCritical
    Critical("On")
    try {
        LocalizationService.Configure(requestedLanguage)
        LocalizationService.ConfigureUiFont(requestedFont)
        UiThemeService.Configure(requestedTheme == ""
            ? oldRequestedTheme : requestedTheme)
        newActualLanguage := LocalizationService.GetLanguage()
        App.uiLanguage := LocalizationService.GetRequestedLanguage()
        App.uiFont := LocalizationService.GetRequestedUiFont()
        App.uiTheme := UiThemeService.GetRequestedTheme()
        App.applicationUpdateService.UiLanguage := newActualLanguage

        TranslateMainStateTexts(oldActualLanguage, newActualLanguage)
        RefreshMainWindowDisplay()

        ; 下级窗口按当前语言在每次打开时创建。关闭旧注册表并立即换成新实例，
        ; 不触碰应用状态、守护运行时、调度器或主窗口的任何长期对象。
        oldModules.Shutdown()
        GuiModules := GuiModuleRegistry(Main.gui)
        modulesReplaced := true

        ; 设置值已由调用方原子保存；空写入只让仓储用新语言替换就地注释。
        try App.configRepository.WriteValues("Settings", [])
        catch as commentError
            LogMsg(Tr("更新配置注释语言失败：{1}",
                TrDiagnostic(commentError.Message)))
        return true
    } catch as displayError {
        rollbackError := ""
        try {
            LocalizationService.Configure(oldRequestedLanguage)
            LocalizationService.ConfigureUiFont(oldRequestedFont)
            UiThemeService.Configure(oldRequestedTheme)
            App.uiLanguage := oldRequestedLanguage
            App.uiFont := oldRequestedFont
            App.uiTheme := oldRequestedTheme
            App.applicationUpdateService.UiLanguage := oldActualLanguage
            RestoreMainStateTexts(oldStateTexts)
            RefreshMainWindowDisplay()
            if modulesReplaced
                try GuiModules.Shutdown()
            if oldModules.stopped || modulesReplaced
                GuiModules := GuiModuleRegistry(Main.gui)
        } catch as rollbackFailure {
            rollbackError := rollbackFailure.Message
        }
        if rollbackError != ""
            throw Error(displayError.Message " | " rollbackError)
        throw displayError
    } finally Critical(previousCritical ? previousCritical : "Off")
}

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
        path := Main.lv.GetText(Main.contextTargetRow, 3)
        if !App.appStates.Has(path)
            return
        stateObj := App.appStates[path]
        try selectedTargetSpecs := App.targetSpecsService.Get(path, stateObj)
        catch
            return
        if selectedTargetSpecs.Launch.Kind != TargetLaunchKind.Batch
            return
        logPath := GetLogFilePath(path)
        if FileExist(logPath)
            Run('notepad.exe "' logPath '"')
        else if IsSet(GuiModules)
            GuiModules.batchOutputLogNotice.Show(logPath)
    }
}

ToggleRunAsAdmin(*) {
    paths := CaptureSelectedWatchPaths(true)
    if !paths.Length
        return
    QueueGuardMutation(ToggleRunAsAdminCore.Bind(paths))
}

ToggleRunAsAdminCore(paths) {
    undoState := CaptureAppConfigState()
    changedAny := false

    for path in paths {
        if App.appStates.Has(path) {
            stateObj := App.appStates[path]
            priorPhase := stateObj.Phase
            stateObj.CancelScheduledTasks()
            stateObj.RunAsAdmin := !(stateObj.HasOwnProp("RunAsAdmin") ? stateObj.RunAsAdmin : 0)
            if (stateObj.Enabled
                && !App.maintenanceCoordinator.IsBlocking(stateObj)) {
                stateObj.ResetGuardAttemptState()
                if StateProcessIdentityIsValid(path, stateObj) {
                    UpdateRunningState(path, stateObj,
                        stateObj.Generation)
                } else if !(stateObj.OneShot
                    && priorPhase == GuardPhase.Running) {
                    stateObj.TransitionTo(GuardPhase.Initializing)
                    UpdateState(path, Tr("初始化..."), stateObj,
                        stateObj.Generation)
                }
            }
            displayName := GetMainDisplayName(path, stateObj)
            row := FindRow(path)
            if row > 0 {
                Main.lv.Modify(row, "Col1", FormatMainListLabel(
                    displayName, stateObj.RunAsAdmin))
                SetMainListAdminOverlay(row, stateObj.RunAsAdmin)
            }
            if StateProcessIdentityIsValid(path, stateObj)
                UpdateRunningState(path, stateObj)
            LogMsg(stateObj.RunAsAdmin
                ? Tr("已启用以管理员身份运行：{1}", displayName)
                : Tr("已关闭以管理员身份运行：{1}", displayName))
            changedAny := true
        }
    }
    if changedAny {
        CommitUndoState(undoState,
            CreateAppHistoryAction("run-as-admin", paths))
        SaveAppsToIni()
    }
}

EndSelectedApp(*) {
    paths := CaptureSelectedWatchPaths(true)
    if !paths.Length
        return
    QueueGuardMutation(BeginManualStopRequests.Bind(paths))
}

BeginManualStopRequests(paths) {
    App.editSessionId++
    changedPaths := []
    requests := []
    blockedAny := false
    undoState := ""
    for path in paths {
        if !App.appStates.Has(path)
            continue
        stateObj := App.appStates[path]
        if App.maintenanceCoordinator.IsBlocking(stateObj) {
            blockedAny := true
            continue
        }
        if stateObj.ManualStopRequested
            continue
        wasEnabled := !!stateObj.Enabled
        if wasEnabled {
            if Type(undoState) != "Array"
                undoState := CaptureAppConfigState()
            changedPaths.Push(path)
        }
        stateObj.Enabled := 0
        stateObj.CancelScheduledTasks()
        stateObj.ResetGuardAttemptState()
        try App.maintenanceCoordinator.CleanupTarget(path, stateObj, false)
        operationGeneration := stateObj.Generation
        stateObj.ManualStopRequested := true
        stateObj.Pending := true
        stateObj.TargetStartTicks := 0
        stateObj.TransitionTo(GuardPhase.Paused)
        UpdateState(path, Tr("⏳ 正在结束运行..."), stateObj,
            operationGeneration, true, GuardStatusKind.Paused)
        requests.Push({Path: path, State: stateObj,
            Generation: operationGeneration})
    }

    if changedPaths.Length {
        App.maintenanceCoordinator.SaveJournal()
        CommitUndoState(undoState,
            CreateAppHistoryAction("toggle-pause", changedPaths))
        SaveAppsToIni()
    }
    for request in requests {
        try {
            SetTimer(PerformManualStop.Bind(request.Path, request.State,
                request.Generation, 0), -1)
        }
        catch {
            FinalizeManualStopFailure(request.Path, request.State,
                request.Generation,
                Tr("结束运行失败，目标进程未能停止：{1}", request.Path))
        }
    }

    if blockedAny {
        ShowDarkMsgBoxDeferred(Tr("该软件正在升级保护中。请等待升级完成，或在“软件升级保护”中结束等待后再结束运行。"),
            Tr("暂时无法结束运行"), "Info", Main.gui)
    }
    if (paths.Length > 0) {
        OnLVSelectChange()
    }
}

PerformManualStop(path, expectedSupervisor, expectedGeneration,
    attempt) {
    if !App.guardRuntime.IsSupervisorCurrent(path, expectedSupervisor,
            expectedGeneration) {
        if App.appStates.Has(path)
            && App.appStates[path] == expectedSupervisor {
            expectedSupervisor.ManualStopRequested := false
        }
        return
    }
    if App.maintenanceCoordinator.IsBlocking(expectedSupervisor) {
        FinalizeManualStopFailure(path, expectedSupervisor,
            expectedGeneration,
            Tr("结束运行失败，目标进程未能停止：{1}", path))
        return
    }
    if !App.guardWorkGate.TryEnter() {
        retryCallback := PerformManualStop.Bind(path,
            expectedSupervisor, expectedGeneration, attempt)
        if !TryScheduleManualStopCallback(retryCallback, path,
            expectedSupervisor, expectedGeneration)
            return
        return
    }

    operationGeneration := expectedGeneration
    gateHeld := true
    try {
        if !App.guardRuntime.IsSupervisorCurrent(path, expectedSupervisor,
            expectedGeneration)
            return
        stateObj := expectedSupervisor
        stateObj.CancelScheduledTasks()
        operationGeneration := stateObj.Generation
        stateObj.Pending := true
        stateObj.TargetStartTicks := 0
        stateObj.TransitionTo(GuardPhase.Paused)
        UpdateState(path, Tr("⏳ 正在结束运行..."), stateObj,
            operationGeneration, false, GuardStatusKind.Paused)
        observation := ObserveTarget(path, "", 1000)
        if !App.guardRuntime.IsSupervisorCurrent(path, stateObj,
            operationGeneration)
            return
        if observation.IsUnknown() {
            ScheduleManualStopRetry(path, stateObj,
                operationGeneration, attempt)
            return
        }
        if observation.IsRunning() {
            pid := observation.PID
            creationIdentity := observation.CreationIdentity
            if creationIdentity == ""
                creationIdentity := App.processInspector
                    .GetCreationIdentity(pid)
            if creationIdentity == "" {
                ScheduleManualStopRetry(path, stateObj,
                    operationGeneration, attempt)
                return
            }
            ; 正常关闭和 Ctrl+C 等待可能持续数秒。目标身份和事务代际已经在
            ; 门内冻结，耗时停止放到门外执行，避免阻塞其它守护对象与配置操作。
            App.guardWorkGate.Leave()
            gateHeld := false
            try stopResult := StopTargetProcess(pid, creationIdentity)
            catch as stopError {
                errorDetail := TrDiagnostic(stopError.Message)
                LogMsg(Tr("无法停止进程 PID：{1}{2}", pid,
                    Tr("（{1}）", errorDetail)))
                stopResult := TargetStopResult(false,
                    TargetStopStage.Failed, errorDetail)
            }
            completionCallback := CompleteManualStopAfterStop.Bind(path,
                stateObj, operationGeneration, pid, creationIdentity,
                stopResult)
            try SetTimer(completionCallback, -1)
            catch
                completionCallback.Call()
            return
        }

        FinalizeManualStop(path, stateObj, operationGeneration)
    } finally {
        if App.appStates.Has(path)
            && App.appStates[path] == expectedSupervisor
            && expectedSupervisor.ManualStopRequested
            && expectedSupervisor.Generation != operationGeneration {
            expectedSupervisor.ManualStopRequested := false
        }
        if gateHeld
            App.guardWorkGate.Leave()
    }
}

CompleteManualStopAfterStop(path, expectedSupervisor,
    expectedGeneration, pid, creationIdentity, stopResult) {
    if !App.guardRuntime.IsSupervisorCurrent(path, expectedSupervisor,
        expectedGeneration) {
        if App.appStates.Has(path)
            && App.appStates[path] == expectedSupervisor {
            expectedSupervisor.ManualStopRequested := false
        }
        return
    }
    if !App.guardWorkGate.TryEnter() {
        retryCallback := CompleteManualStopAfterStop.Bind(path,
            expectedSupervisor, expectedGeneration, pid,
            creationIdentity, stopResult)
        if !TryScheduleManualStopCallback(retryCallback, path,
            expectedSupervisor, expectedGeneration)
            return
        return
    }
    try {
        if !App.guardRuntime.IsSupervisorCurrent(path, expectedSupervisor,
            expectedGeneration)
            return
        stateObj := expectedSupervisor
        if App.maintenanceCoordinator.IsBlocking(stateObj) {
            FinalizeManualStopFailure(path, stateObj,
                expectedGeneration,
                Tr("结束运行失败，目标进程未能停止：{1}", path))
            return
        }
        if !stopResult.Stopped {
            identityStatus := App.targetStopper.GetIdentityStatus(pid,
                creationIdentity)
            if identityStatus == 0
                ClearStateProcessIdentity(stateObj)
            else
                SetStateProcessIdentity(stateObj, pid, creationIdentity)
            FinalizeManualStopFailure(path, stateObj, expectedGeneration,
                Tr("结束运行失败，目标进程未能停止：{1}", path))
            return
        }
        FinalizeManualStop(path, stateObj, expectedGeneration)
    } finally App.guardWorkGate.Leave()
}

FinalizeManualStop(path, stateObj, expectedGeneration) {
    if !App.guardRuntime.IsSupervisorCurrent(path, stateObj,
            expectedGeneration) || stateObj.Enabled
        || App.maintenanceCoordinator.IsBlocking(stateObj) {
        stateObj.ManualStopRequested := false
        stateObj.Pending := false
        stateObj.TargetStartTicks := 0
        return false
    }
    stateObj.Pending := false
    stateObj.TargetStartTicks := 0
    stateObj.FailCount := 0
    stateObj.ManualStopRequested := false
    ClearStateProcessIdentity(stateObj)
    stateObj.TransitionTo(GuardPhase.Paused)
    UpdateState(path, Tr("⏸️ 已暂停"), stateObj, expectedGeneration,
        true, GuardStatusKind.Paused)
    LogMsg(Tr("已结束运行：{1}", path))
    return true
}

FinalizeManualStopFailure(path, stateObj, expectedGeneration, logMessage) {
    if !App.guardRuntime.IsSupervisorCurrent(path, stateObj,
            expectedGeneration)
        return false
    stateObj.ManualStopRequested := false
    stateObj.Pending := false
    stateObj.TargetStartTicks := 0
    stateObj.TransitionTo(GuardPhase.Paused)
    UpdateState(path, Tr("❌ 无法结束运行"), stateObj,
        expectedGeneration, true, GuardStatusKind.Paused)
    LogMsg(logMessage)
    return true
}

ScheduleManualStopRetry(path, stateObj, operationGeneration, attempt) {
    if attempt >= 4 {
        FinalizeManualStopFailure(path, stateObj, operationGeneration,
            Tr("结束运行失败，目标进程未能停止：{1}", path))
        return false
    }
    UpdateState(path, Tr("⏳ 等待进程状态..."), stateObj,
        operationGeneration, false, GuardStatusKind.Paused)
    if attempt == 0
        LogMsg(Tr("暂时无法查询进程状态，稍后重试结束运行：{1}", path))
    retryCallback := PerformManualStop.Bind(path, stateObj,
        operationGeneration, attempt + 1)
    return TryScheduleManualStopCallback(retryCallback, path, stateObj,
        operationGeneration, 2000)
}

TryScheduleManualStopCallback(callback, path, stateObj,
    expectedGeneration, delayMs := 100) {
    try {
        SetTimer(callback, -Max(1, delayMs))
        return true
    } catch as timerError {
        if App.guardRuntime.IsSupervisorCurrent(path, stateObj,
            expectedGeneration) {
            stateObj.ManualStopRequested := false
            stateObj.Pending := false
            stateObj.TargetStartTicks := 0
            stateObj.TransitionTo(GuardPhase.Paused)
            UpdateState(path, Tr("❌ 无法结束运行"), stateObj,
                expectedGeneration, true, GuardStatusKind.Paused)
        }
        LogMsg(Tr("后台调度任务异常（{1}）：{2}", path,
            TrDiagnostic(timerError.Message)))
        return false
    }
}

/*  * ========================================================================
 * 全局界面的按键拦截钩子
 * ========================================================================
 * 使用 OnMessage 监听 WM_KEYDOWN 消息实现快捷键，
 * 如撤销、重做和列表操作功能。
 */
OnMessage(Win32.WM_KEYDOWN, Global_KeyDown)
OnMessage(Win32.WM_MOVE, MainWindowMoved)
OnMessage(Win32.WM_DPICHANGED, MainDpiChanged)
OnMessage(Win32.WM_COPYDATA, ReceiveMaintenanceCopyData)
OnMessage(Win32.WM_SYSCOMMAND, OnManagedWindowSystemCommand)

ShouldToggleMainListPause(wParam, lParam, ctrlDown, shiftDown, altDown) {
    ; lParam 第 30 位表示按键在本次消息前已经处于按下状态。长按空格时
    ; 只接受首次按下，避免一次操作在暂停与恢复之间反复切换。
    return wParam == 32 && !(lParam & 0x40000000)
        && !ctrlDown && !shiftDown && !altDown
}

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
            ; 自绘 Text 按钮不会可靠地产生原生 BN_CLICKED／AHK Click 事件；键盘
            ; 激活直接进入与鼠标抬起相同的已注册回调，避免屏幕阅读器用户按
            ; Enter 或 Space 后只看到焦点变化而实际功能没有执行。
            if buttonState.HasOwnProp("clickCallback") {
                try buttonState.clickCallback.Call(buttonState.ctrl)
            } else {
                try ControlClick(, "ahk_id " hwnd)
            }
            return 0
        }
    }
    rootHwnd := DllCall("user32\GetAncestor", "Ptr", hwnd, "UInt", 2,
        "Ptr")
    rootClass := ""
    try rootClass := WinGetClass("ahk_id " rootHwnd)
    ; OnMessage 只接收本进程窗口的消息；根窗口为 AutoHotkeyGUI 即可确认
    ; 来源属于小助手。这样所有下级窗口都共享应用历史，同时文本框仍保留
    ; 自身的字符级撤销与重做。
    if (rootClass == "AutoHotkeyGUI") {
        if (wParam == 90 && GetKeyState("Ctrl", "P")) { ; Ctrl+Z 撤销，Ctrl+Shift+Z 重做。
            if GetKeyState("Shift", "P")
                PerformRedo()
            else
                PerformUndo()
            return 0
        }
        if (wParam == 89 && GetKeyState("Ctrl", "P")) { ; Ctrl+Y 使用另一组常见按键执行重做。
            PerformRedo()
            return 0
        }
    }

    ; 标签编辑框拥有自己的文本快捷键，主窗口不能截获其中的按键。
    if (wParam == 27) {
        hEdit := SendMessage(0x1018, 0, 0, Main.lv.Hwnd) ; LVM_GETEDITCONTROL：取得当前标签编辑框。
        if (hEdit && hEdit == hwnd) {
            SendMessage(0x0100, 27, 0, hEdit) ; 传给编辑框取消编辑
            return
        }
    }

    ; 只有列表本身持有焦点时，才把按键解释为列表级选择、删除或关闭操作。
    if (hwnd == Main.lv.Hwnd) {
        ctrlDown := GetKeyState("Ctrl", "P")
        shiftDown := GetKeyState("Shift", "P")
        altDown := GetKeyState("Alt", "P")
        if (wParam == 32 && !ctrlDown && !shiftDown && !altDown) {
            if ShouldToggleMainListPause(wParam, lParam, ctrlDown,
                    shiftDown, altDown) && Main.lv.GetNext(0) > 0
                ToggleItemPause()
            ; 普通空格由小助手完整接管，包括长按产生的重复消息；否则
            ; ListView 还会改变选择状态，使本次命令作用到意外条目。
            return 0
        }
        if (wParam == 113) { ; F2 编辑当前守护对象的完整路径。
            row := Main.lv.GetNext(0, "Focused")
            if (row > 0)
                TriggerEdit(Main.lv, row)
            ; 已由应用启动完整路径编辑，必须阻止 ListView 再处理同一个
            ; F2，否则它会销毁已主题化的 Edit 并创建第二个亮色 Edit。
            return 0
        }
        if (wParam == 65 && ctrlDown) { ; Ctrl+A 选择列表中的全部守护对象。
            Main.lv.Modify(0, "Select")
            return
        }
        if (wParam == 46) { ; Delete 删除当前选中的守护对象。
            if (Main.lv.GetNext(0) > 0)
                DelItem()
            return
        }
        if (wParam == 27) { ; Esc 先清除选择，再在无选择时隐藏主窗口。
            if (Main.lv.GetNext(0) > 0) {
                Main.lv.Modify(0, "-Select") ; 第一次按下只清除当前选择。
            } else {
                OnMainGuiClose()        ; 已无选择时把主窗口隐藏到托盘。
            }
            return
        }
    }

    ; 焦点位于主窗口其它控件时，Esc 同样隐藏主窗口；下级窗口会自行处理关闭。
    ; 参数 2（GA_ROOT）用于找到主 GUI 框架。
    if (wParam == 27 && DllCall("user32\GetAncestor", "Ptr", hwnd, "UInt", 2) == Main.gui.Hwnd) {
        OnMainGuiClose()
    }
}

; 从 INI 读取守护对象及对应的升级保护配置。
LoadWatchlistFromConfig()
; 控件从创建起采用不可用配色；列表载入后再按真实选择状态强制同步，
; 避免首次启动没有 ItemSelect 事件时仍残留可用色。
RefreshMainCommandState(true)
if !App.maintenanceCoordinator.Initialize()
    LogMsg(Tr("升级保护协调器未能初始化，核心守护不会启动。"))

UpdateTaskButtonStatus()

Main.gui.OnEvent("Size", GuiResized)
Main.gui.OnEvent("Close", OnMainGuiClose)
Main.gui.OnEvent("Escape", OnMainGuiClose)
Main.gui.OnEvent("DropFiles", OnGuiDropFiles)

; 底部统计栏是 owner-draw 控件，Presenter 在 SetItems 前只会绘制空背景。
; 在任何 Show 分支之前同步建立首帧投影，不能等一秒倒计时器首次刷新。
UpdateStatsUI()

; 检查是否是通过“重新加载”触发的启动，决定显示界面还是静默系统托盘
try {
    if (App.configRepository.Read(
        "Settings", "ShowAfterReload", 0) == "1") {
        App.configRepository.WriteValue(
            "Settings", "ShowAfterReload", 0)
        ShowMainGuiWithOptions("w" App.savedWidth " h" App.savedHeight)
        App.isReloadedMode := true
    }
}

if (!App.isReloadedMode) {
    ; 根据设置决定启动后显示主窗口，或静默驻留托盘。
    if App.showAtStartup
        ShowMainGuiWithOptions("w" App.savedWidth " h" App.savedHeight)
    else
        ShowMainGuiWithOptions("w" App.savedWidth " h" App.savedHeight
            " Hide")
}

SetTimer(UpdateCountdownUI, 1000) ; 倒计时显示按整秒刷新
guardRuntimeStarted := App.guardRuntime.Start()
if !guardRuntimeStarted
    LogMsg(Tr("核心守护计时器启动失败。"))
LogMsg(App.isReloadedMode ? Tr("代码热重载完毕，界面已恢复显示。")
    : Tr("进程守护小助手已静默启动。"))
LogMsg(GetApplicationVersionSummary())
; 自动更新助手只有在新版完成配置加载、窗口装配和核心计时器启动后才会提交替换。
applicationUpdateReadyPath := GetApplicationUpdateReadyPath()
if applicationUpdateReadyPath {
    ; 更新只能在核心守护真正开始运行后提交。普通启动仍保留诊断界面，但更新
    ; 启动若无法守护目标，必须退出并让安装助手恢复旧版本与个人配置。
    if !guardRuntimeStarted
        || !WriteApplicationUpdateReadySignal(applicationUpdateReadyPath,
            ReadApplicationVersion())
        ExitApplication(1)
}
; 更新检查延后到主窗口与守护计时器均已就绪后启动；网络工作始终位于独立进程。
if App.checkUpdatesOnStartup
    SetTimer(CheckForApplicationUpdate.Bind("", false), -1500)

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
                throw Error(Tr("新脚本未通过 AutoHotkey 解析检查"))
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
        LogMsg(Tr("重新加载失败，已保留当前实例：{1}", reloadDetails))
        ShowMainGui()
        ShowDarkMsgBox(Tr("重新加载失败，当前守护仍在运行。`n`n{1}", reloadDetails),
            Tr("重新加载失败"), "Error", Main.gui)
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
