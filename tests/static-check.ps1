# 源码结构、架构边界和高风险回归的静态门禁。
# 检查结果基于明确语义钩子而非格式化风格，新增规则应说明它保护的真实故障模式。

[CmdletBinding()]
param([switch]$SkipPackagedFontContentValidation)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Get-ChildItem -LiteralPath $projectRoot -Filter '*.ahk' -File |
    Where-Object { $_.Name -notlike '_*' } |
    Select-Object -First 1 -ExpandProperty FullName
$iniPath = Join-Path $projectRoot 'config\watchdog.example.ini'
$mainSource = Get-Content -LiteralPath $sourcePath -Raw -Encoding UTF8
$appModuleFiles = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'app') `
    -Recurse -Filter '*.ahk' -File | Sort-Object {
        $relativePath = $_.FullName.Substring($projectRoot.Length + 1)
        $mainSource.IndexOf("#Include $relativePath",
            [System.StringComparison]::OrdinalIgnoreCase)
    }
$appModuleSource = ($appModuleFiles | ForEach-Object {
        Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
    }) -join "`n"
# app 模块在组合根的包含指令处展开，位置早于主脚本中的可执行语句。
# 必须保留这个顺序，否则组合根里的函数调用可能被误判为随后模块中的函数定义。
$source = $appModuleSource + "`n" + $mainSource
$applicationTelemetrySource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'app\ApplicationTelemetry.ahk') -Raw -Encoding UTF8
$mainVisualPipelineSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'app\UI\MainVisualPipeline.ahk') -Raw -Encoding UTF8
$interactionPresenterSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'app\UI\InteractionPresenter.ahk') `
    -Raw -Encoding UTF8
$darkInlineEditThemeRegistrySource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'app\UI\DarkInlineEditThemeRegistry.ahk') `
    -Raw -Encoding UTF8
$iniFieldCodecSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Config\IniFieldCodec.ahk') -Raw -Encoding UTF8
$displayConfigCodecSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Config\DisplayConfigCodec.ahk') -Raw -Encoding UTF8
$maintenanceConfigCodecSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Config\MaintenanceConfigCodec.ahk') -Raw -Encoding UTF8
$appConfigSnapshotServiceSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Config\AppConfigSnapshotService.ahk') -Raw -Encoding UTF8
$runtimeSettingsServiceSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Config\RuntimeSettingsService.ahk') -Raw -Encoding UTF8
$applicationUpdateSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Update\ApplicationUpdateService.ahk') -Raw -Encoding UTF8
$applicationUpdateHelperSource = Get-Content -LiteralPath (Join-Path $projectRoot 'runtime\application-update.ps1') -Raw -Encoding UTF8
$windowLayoutServiceSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Config\WindowLayoutService.ahk') -Raw -Encoding UTF8
$watchlistPersistenceServiceSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Config\WatchlistPersistenceService.ahk') -Raw -Encoding UTF8
$configRepositorySource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Config\WatchdogConfigRepository.ahk') -Raw -Encoding UTF8
$guardTypesSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Core\GuardTypes.ahk') -Raw -Encoding UTF8
$guardStateMachineSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Core\GuardStateMachine.ahk') -Raw -Encoding UTF8
$guardWorkGateSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Core\GuardWorkGate.ahk') -Raw -Encoding UTF8
$guardMutationQueueSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Core\GuardMutationQueue.ahk') -Raw -Encoding UTF8
$schedulerSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Core\WatchdogScheduler.ahk') -Raw -Encoding UTF8
$restartPolicySource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Core\RestartPolicy.ahk') -Raw -Encoding UTF8
$targetSupervisorSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Core\TargetSupervisor.ahk') -Raw -Encoding UTF8
$targetSpecsSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Core\TargetSpecs.ahk') -Raw -Encoding UTF8
$targetSpecsServiceSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Core\TargetSpecsService.ahk') -Raw -Encoding UTF8
$targetIdentityServiceSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Core\TargetIdentityService.ahk') -Raw -Encoding UTF8
$targetRelocationServiceSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'src\Core\TargetContentRelocationService.ahk') `
    -Raw -Encoding UTF8
$appConfigHistoryServiceSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Core\AppConfigHistoryService.ahk') -Raw -Encoding UTF8
$historyToastSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'app\Windows\HistoryToastWindow.ahk') -Raw -Encoding UTF8
$targetRelocationPromptSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'app\Windows\TargetRelocationPrompt.ahk') `
    -Raw -Encoding UTF8
$guardRuntimeSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Core\GuardRuntime.ahk') -Raw -Encoding UTF8
$targetLauncherSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Execution\TargetLauncher.ahk') -Raw -Encoding UTF8
$everythingRuntimeServiceSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'src\Execution\EverythingRuntimeService.ahk') `
    -Raw -Encoding UTF8
$targetStopperSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Execution\TargetStopper.ahk') -Raw -Encoding UTF8
$maintenanceStateMachineSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Maintenance\MaintenanceStateMachine.ahk') -Raw -Encoding UTF8
$maintenanceActorMatcherSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Maintenance\MaintenanceActorMatcher.ahk') -Raw -Encoding UTF8
$maintenanceSessionCodecSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Maintenance\MaintenanceSessionCodec.ahk') -Raw -Encoding UTF8
$maintenanceCoordinatorSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Maintenance\MaintenanceCoordinator.ahk') -Raw -Encoding UTF8
$processInspectorSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Inspection\ProcessInspector.ahk') -Raw -Encoding UTF8
$snapshotIndexSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Inspection\ProcessSnapshotIndex.ahk') -Raw -Encoding UTF8
$snapshotServiceSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Inspection\ProcessSnapshotService.ahk') -Raw -Encoding UTF8
$targetProbeSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Inspection\TargetProbe.ahk') -Raw -Encoding UTF8
$targetFileInspectorSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Inspection\TargetFileInspector.ahk') -Raw -Encoding UTF8
$shortcutResolverSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Inspection\ShortcutResolver.ahk') -Raw -Encoding UTF8
$shortcutTargetResolverSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Inspection\ShortcutTargetResolver.ahk') -Raw -Encoding UTF8
$directoryChangeWatcherSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Inspection\DirectoryChangeWatcher.ahk') -Raw -Encoding UTF8
$fileScanServiceSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Inspection\FileScanService.ahk') -Raw -Encoding UTF8
$iconResourceRegistrySource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\UI\IconResourceRegistry.ahk') -Raw -Encoding UTF8
$svgRenderLibrarySource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\UI\SvgRenderLibrary.ahk') -Raw -Encoding UTF8
$uiInteractionRegistrySource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\UI\UiInteractionRegistry.ahk') -Raw -Encoding UTF8
$controlAccessibilitySource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\UI\ControlAccessibilityService.ahk') -Raw -Encoding UTF8
$mainListProjectionSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\UI\MainListProjection.ahk') -Raw -Encoding UTF8
$listViewFocusServiceSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'src\UI\ListViewFocusService.ahk') `
    -Raw -Encoding UTF8
$listViewPseudoHeaderSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'src\UI\ListViewPseudoHeader.ahk') -Raw -Encoding UTF8
$atomicControlLayoutSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'src\UI\AtomicControlLayout.ahk') -Raw -Encoding UTF8
$windowHierarchySource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\UI\WindowHierarchy.ahk') -Raw -Encoding UTF8
$managedWindowSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\UI\ManagedWindow.ahk') -Raw -Encoding UTF8
$uiThemeServiceSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'src\UI\UiThemeService.ahk') -Raw -Encoding UTF8
$localizationServiceSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'src\Localization\LocalizationService.ahk') `
    -Raw -Encoding UTF8
$settingsWindowSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'app\Windows\SettingsWindow.ahk') `
    -Raw -Encoding UTF8
$aboutWindowSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'app\Windows\AboutWindow.ahk') `
    -Raw -Encoding UTF8
$customDisplayDialogSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'app\Windows\CustomDisplayDialog.ahk') `
    -Raw -Encoding UTF8
$environmentSettingsDialogSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'app\Windows\EnvironmentSettingsDialog.ahk') `
    -Raw -Encoding UTF8
$maintenanceSettingsDialogSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'app\Windows\MaintenanceSettingsDialog.ahk') `
    -Raw -Encoding UTF8
$darkMessageBoxSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'app\UI\DarkMessageBox.ahk') `
    -Raw -Encoding UTF8
$interactionPresenterSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'app\UI\InteractionPresenter.ahk') `
    -Raw -Encoding UTF8
$mainWindowControllerSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'app\MainWindowController.ahk') `
    -Raw -Encoding UTF8
$mainWindowStateSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'app\MainWindowState.ahk') `
    -Raw -Encoding UTF8
$win32Source = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'src\Platform\Win32.ahk') `
    -Raw -Encoding UTF8
$contextMenuPresenterSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'app\UI\ContextMenuPresenter.ahk') `
    -Raw -Encoding UTF8
$mainContextPopupWindowSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'app\Windows\MainContextPopupWindow.ahk') `
    -Raw -Encoding UTF8
$listViewSelectionPresenterSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'app\UI\ListViewSelectionPresenter.ahk') `
    -Raw -Encoding UTF8
$coreTestRunnerSource = Get-Content -LiteralPath (Join-Path $projectRoot 'tests\run-core-tests.ps1') -Raw -Encoding UTF8
$guiTestRunnerSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'tests\run-gui-tests.ps1') -Raw -Encoding UTF8
$displayHotSwitchTestSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'tests\gui\display-hot-switch-tests.ahk') `
    -Raw -Encoding UTF8
$inlineEditThemeTestSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'tests\gui\inline-edit-theme-tests.ahk') `
    -Raw -Encoding UTF8
$resourceSoakTestSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'tests\gui\resource-soak-tests.ahk') `
    -Raw -Encoding UTF8
$targetContentRelocationTestSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot `
        'tests\core\target-content-relocation-service-tests.ahk') `
    -Raw -Encoding UTF8
$fileScanServiceTestSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'tests\core\file-scan-service-tests.ahk') `
    -Raw -Encoding UTF8
$readmeSource = Get-Content -LiteralPath (Join-Path $projectRoot 'README.md') -Raw -Encoding UTF8
$documentationSource = $readmeSource + "`n" + ((Get-ChildItem -LiteralPath `
    (Join-Path $projectRoot 'docs') -Recurse -Filter '*.md' -File |
    ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 }) `
    -join "`n")
$allModuleSource = (Get-ChildItem -LiteralPath (Join-Path $projectRoot 'src') -Recurse -Filter '*.ahk' -File |
    ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 }) -join "`n"
$iniText = Get-Content -LiteralPath $iniPath -Raw -Encoding Unicode

$productionSource = $source + $allModuleSource
$temporaryPreviewPatterns = @(
    'ApplyTemporaryPreviewStates',
    '\u3010\u72B6\u6001\u6D4B\u8BD5\u3011',
    '\u3010\u56FE\u6807\u683C\u5F0F\u6D4B\u8BD5\u3011',
    'ProcessWatchdogPreview-'
)
foreach ($temporaryPreviewPattern in $temporaryPreviewPatterns) {
    if ($productionSource -match $temporaryPreviewPattern) {
        throw "Temporary preview fixture remains in production source: $temporaryPreviewPattern"
    }
}

$iniLines = Get-Content -LiteralPath $iniPath -Encoding Unicode

$failures = New-Object 'System.Collections.Generic.List[string]'

# 两个布尔状态不能退回 Windows 原生左侧勾选位；主列表右键菜单必须使用
# 不激活浮层，避免原生 Menu.Show 抢走 ListView 焦点。浮层菜单项必须由单个
# owner-draw 行控件绘制，避免拆成文字/勾选/背景多层控件后留下方角残影。
if (-not $source.Contains('FormatContextMenuToggleLabel(label, checked)') -or
    -not $source.Contains('return checked ? label "`t✓" : label') -or
    -not $source.Contains('BuildMainContextPopupItems(isAdmin := false, maintenanceEnabled := false,') -or
    -not $source.Contains('maintenanceSupported := true, batchLogSupported := false)') -or
    -not $source.Contains('if batchLogSupported {') -or
    -not $source.Contains('Tr("📄 查看批处理输出日志")') -or
    -not $source.Contains('GuiModules.batchOutputLogNotice.Show(logPath)') -or
    -not $source.Contains('this.batchOutputLogNotice := BatchOutputLogNoticeWindow(mainGui)') -or
    -not $mainSource.Contains('#Include app\Windows\BatchOutputLogNoticeWindow.ahk') -or
    -not $source.Contains('Tr("🛡️ 以管理员身份运行")') -or
    -not $source.Contains('SuppressNativeMenuCheckGutter(contextMenu)') -or
    -not $source.Contains('ContextMenuPresenter.Detach(contextMenu.Handle)') -or
    -not $source.Contains('ContextMenuPresenter.Attach(contextMenu, Main.gui.Hwnd)') -or
    -not $mainSource.Contains('#Include app\Windows\MainContextPopupWindow.ahk') -or
    -not $mainWindowStateSource.Contains('this.contextPopup := MainContextPopupWindow(this.gui)') -or
    -not $source.Contains('Main.contextPopup.Show(popupItems)') -or
    -not $source.Contains('Main.contextPopup.Dispose()') -or
    -not $mainContextPopupWindowSource.Contains('+E0x08000000') -or
    -not $mainContextPopupWindowSource.Contains('NoActivate') -or
    -not $mainContextPopupWindowSource.Contains('OnMessage(Win32.WM_RBUTTONDOWN, this.PointerDownCallback)') -or
    -not $mainContextPopupWindowSource.Contains('RegisterHoverButton(rowButton, menuColor, hoverColor,') -or
    -not $mainContextPopupWindowSource.Contains('RegisterButtonClick(rowButton,') -or
    -not $mainContextPopupWindowSource.Contains('ButtonFeedbackMode.Dismissive') -or
    -not $mainContextPopupWindowSource.Contains('buttonState.parentColor := menuColor') -or
    -not $mainContextPopupWindowSource.Contains('buttonState.rightTextInsetDip :=') -or
    -not $mainContextPopupWindowSource.Contains('SetRegisteredButtonEnabled(rowButton, false)') -or
    $mainContextPopupWindowSource.Contains('checkCtrl :=') -or
    $mainContextPopupWindowSource.Contains('rowBg :=') -or
    -not $mainContextPopupWindowSource.Contains('SetWindowRgn') -or
    -not $mainContextPopupWindowSource.Contains('SetWindowPos') -or
    $source.Contains('ContextMenuPresenter.Show(Main.contextMenu)') -or
    -not $mainSource.Contains('OnMessage(Win32.WM_MEASUREITEM, OnMeasureApplicationControl)') -or
    -not $contextMenuPresenterSource.Contains('static FontSizePt := 10') -or
    -not $contextMenuPresenterSource.Contains('static ItemHeightDip := 30') -or
    -not $contextMenuPresenterSource.Contains('static OuterVerticalPaddingDip := 5') -or
    -not $contextMenuPresenterSource.Contains('static SeparatorHeightDip := 10') -or
    -not $contextMenuPresenterSource.Contains('Win32.MFT_OWNERDRAW') -or
    -not $contextMenuPresenterSource.Contains('HandleMeasure(lParam)') -or
    -not $contextMenuPresenterSource.Contains('HandleDraw(lParam)') -or
    -not $contextMenuPresenterSource.Contains('SetWinEventHook') -or
    -not $contextMenuPresenterSource.Contains('EVENT_OBJECT_SHOW') -or
    -not $contextMenuPresenterSource.Contains('CreateRoundedWindowRegion(width, height, dpi)') -or
    -not $contextMenuPresenterSource.Contains('SetWindowRgn') -or
    -not $contextMenuPresenterSource.Contains('FillRoundedRectangle(hdc,') -or
    -not $contextMenuPresenterSource.Contains('static Show(menuObj, coordinates*)') -or
    -not $contextMenuPresenterSource.Contains('StopPopupWindowHook()') -or
    -not $source.Contains('if Main.contextMenu is Menu') -or
    -not $source.Contains('contextMenu.Delete()') -or
    -not $source.Contains('if currentStyle & Win32.MNS_NOCHECK') -or
    -not $source.Contains('currentStyle | Win32.MNS_NOCHECK') -or
    -not $source.Contains('contextMenu.Disable(maintenanceLabel)') -or
    $source -match '\.contextMenu\.(?:Check|Uncheck)\(' -or
    $source.Contains('SetWindowsStockMenuIcon(')) {
    $failures.Add('Main context menu must use a no-activate rounded popup without triggering native Menu.Show focus loss')
}
if (-not $mainSource.Contains('#Include app\UI\ListViewSelectionPresenter.ahk') -or
    -not $mainSource.Contains('Main.listSelectionPresenter := ListViewSelectionPresenter(Main.lv)') -or
    -not $listViewSelectionPresenterSource.Contains('Win32.NM_CUSTOMDRAW') -or
    -not $listViewSelectionPresenterSource.Contains('Win32.CDDS_ITEMPREPAINT') -or
    -not $listViewSelectionPresenterSource.Contains('Win32.CDDS_ITEMPOSTPAINT') -or
    -not $listViewSelectionPresenterSource.Contains('Win32.CDRF_NOTIFYPOSTPAINT') -or
    -not $listViewSelectionPresenterSource.Contains('Win32.LVM_GETITEMSTATE') -or
    -not $listViewSelectionPresenterSource.Contains('Win32.LVIS_SELECTED') -or
    -not $listViewSelectionPresenterSource.Contains('ScheduleNativeSurfaceRefresh(delayMs := 15)') -or
    -not $listViewSelectionPresenterSource.Contains('Win32.RDW_CONTROL_REFRESH') -or
    -not $listViewSelectionPresenterSource.Contains('Win32.LVM_REDRAWITEMS') -or
    -not $listViewSelectionPresenterSource.Contains('DllCall("user32\UpdateWindow"') -or
    -not $listViewSelectionPresenterSource.Contains('MaskOutsideRoundedRectangle(hdc,') -or
    $listViewSelectionPresenterSource.Contains('DrawColumnSeparators') -or
    $listViewSelectionPresenterSource.Contains('SetDCBrushColor') -or
    -not $mainVisualPipelineSource.Contains('ScheduleMainListNativeSurfaceRefresh(delayMs := 15)') -or
    -not $source.Contains('Main.listSelectionPresenter.RefreshItem(Item)') -or
    -not $source.Contains('Main.lv.Modify(Item, "Select Focus Vis")') -or
    -not $source.Contains('Main.lv.Modify(Item, "Focus Vis")') -or
    $source.Contains('PrepareMainListContextPointerDown') -or
    $source.Contains('ShowPreparedMainListContextMenu') -or
    $source.Contains('Main.listSelectionPresenter.ScheduleNativeSurfaceRefresh(35)') -or
    -not $source.Contains('Main.listSelectionPresenter.Dispose()')) {
    $failures.Add('Main ListView selection must use a DPI-aware rounded background while preserving native item content and cleanup')
}
if (-not $mainWindowControllerSource.Contains('IsExplorerDefaultFileManager()') -or
    -not $mainWindowControllerSource.Contains('OpenFileSelectionWithExplorer(locationPath)') -or
    -not $mainWindowControllerSource.Contains('OpenDirectoryWithDefaultFileManager(directoryPath)') -or
    -not $mainWindowControllerSource.Contains('explorer.exe /select,"') -or
    $mainWindowControllerSource.Contains('explorer.exe "') ) {
    $failures.Add('Open File Location must use Explorer selection only when Explorer is the default file manager, otherwise open the directory through the default handler')
}
foreach ($obsoleteContextMenuText in @(
    '🎨 自定义名称和图标…',
    '🔄 软件升级保护…'
)) {
    if ($productionSource.Contains($obsoleteContextMenuText)) {
        $failures.Add("Obsolete context-menu ellipsis remains: $obsoleteContextMenuText")
    }
}

# 语言和字体必须在当前进程内事务式刷新；设置保存不得再走脚本重载，也不能借
# 显示切换停止核心守护。真实 GUI 回归同时锁定长期对象身份、动态状态和资源增量。
$hotDisplayStart = $mainSource.IndexOf('ApplyDisplaySettingsHot(requestedLanguage, requestedFont,',
    [System.StringComparison]::Ordinal)
$hotDisplayEnd = if ($hotDisplayStart -ge 0) {
    $mainSource.IndexOf('OpenEnvSettings(*) {', $hotDisplayStart,
        [System.StringComparison]::Ordinal)
} else {
    -1
}
$hotDisplaySource = if ($hotDisplayStart -ge 0 -and
    $hotDisplayEnd -gt $hotDisplayStart) {
    $mainSource.Substring($hotDisplayStart,
        $hotDisplayEnd - $hotDisplayStart)
} else {
    ''
}
foreach ($hotDisplayHook in @(
        'oldActualLanguage := LocalizationService.GetLanguage()',
        'oldRequestedTheme := UiThemeService.GetRequestedTheme()',
        'oldStateTexts := CaptureMainStateTexts()',
        'TranslateMainStateTexts(oldActualLanguage, newActualLanguage)',
        'RefreshMainWindowDisplay()',
        'oldModules.Shutdown()',
        'GuiModules := GuiModuleRegistry(Main.gui)',
        'RestoreMainStateTexts(oldStateTexts)',
        'LocalizationService.Configure(oldRequestedLanguage)',
        'UiThemeService.Configure(oldRequestedTheme)',
        'Critical("On")')) {
    if (-not $hotDisplaySource.Contains($hotDisplayHook)) {
        $failures.Add("Missing transactional display hot-switch hook: $hotDisplayHook")
    }
}
if ($hotDisplaySource -match 'guardRuntime\.(?:Start|Shutdown|RestartMonitorTimer)' -or
    $hotDisplaySource -match '\b(?:ReloadScript|ExitApp)\s*\(') {
    $failures.Add('Display hot-switch must not restart the script or mutate the guard runtime')
}
if ($settingsWindowSource -match '\bReloadScript\s*\(' -or
    -not $settingsWindowSource.Contains(
        'ApplyDisplaySettingsHot(savedSettings.UiLanguage,') -or
    $settingsWindowSource -notmatch 'if\s+App\.checkInterval\s*!=\s*priorCheckInterval\s*[\r\n]+\s*App\.guardRuntime\.RestartMonitorTimer\(\)') {
    $failures.Add('Settings save must hot-apply display changes and only reset the monitor timer when its interval changes')
}
if ($localizationServiceSource -notmatch
        'TranslateRenderedTextBetweenLanguages\(renderedText,[\s\S]{0,5000}BuildRenderedTemplatePattern\(template\)' -or
    -not $guiTestRunnerSource.Contains('gui\display-hot-switch-tests.ahk') -or
    $displayHotSwitchTestSource -notmatch 'AssertDisplayHotSwitchIdentity\(expected\)' -or
    $displayHotSwitchTestSource -notmatch 'GetDisplayHotSwitchResourceCount\(0\)' -or
    $displayHotSwitchTestSource -notmatch 'LocalizationService\.GetSupportedLanguageCodes\(\)') {
    $failures.Add('Display hot-switch must retain rendered-state conversion and full-language real-GUI identity/resource coverage')
}
foreach ($fontLifecycleHook in @(
        'GetLanguageUiFontSpec(language := "")',
        'GetLanguageSystemUiFontName(language := "")',
        'GetInstalledUiFontNames()',
        'RefreshInstalledUiFontNames()',
        'FindInstalledUiFontName(fontName)')) {
    if (-not $localizationServiceSource.Contains($fontLifecycleHook)) {
        $failures.Add("Missing installed-font resolution hook: $fontLifecycleHook")
    }
}
if ($localizationServiceSource -match 'AddFontResourceExW|RemoveFontResourceExW|FR_PRIVATE|GetUiFontAssetDirectory|GetLoadedPrivateUiFontResourceCount' -or
    $source -match 'LocalizationService.ShutdownUiFonts()') {
    $failures.Add('Runtime UI fonts must come only from Windows-installed families; private font loading and cleanup must not return')
}

# 用户选择的内容字体不得重新覆盖界面骨架。所有交互按钮都从统一注册入口取得
# 当前语言的系统 UI 粗体；主窗口热切换则分别刷新按钮、列表和底部状态栏。
if ($interactionPresenterSource -notmatch
        'RegisterHoverButton\(ctrl,[\s\S]{0,1000}ctrl\.SetFont\("norm bold",\s*LocalizationService\.GetLanguageSystemUiFontName\(\)\)') {
    $failures.Add('All registered buttons must use the language-specific Windows UI font in bold')
}
if ($mainSource -notmatch
        'RefreshMainWindowDisplay\(\)\s*\{[\s\S]{0,1200}button\.SetFont\("s10 bold", systemFontName\)[\s\S]{0,500}Main\.lv\.SetFont\("s12 c" UiThemeService\.Color\("Text"\), fontName\)[\s\S]{0,500}Main\.statsText\.SetFont\("s10 bold c"') {
    $failures.Add('Main display refresh must keep buttons and status bold-system-font while the ListView follows content font')
}
if ($mainSource -notmatch
        'Main\.btnPause\s*:=\s*Main\.gui\.Add\([\s\S]{0,180}UiThemeService\.Color\("PauseDisabled"\)[\s\S]{0,180}DisabledButtonText' -or
    $mainSource -notmatch
        'Main\.btnDel\s*:=\s*Main\.gui\.Add\([\s\S]{0,180}UiThemeService\.Color\("DeleteDisabled"\)[\s\S]{0,180}DisabledButtonText' -or
    $mainSource -notmatch
        'LoadWatchlistFromConfig\(\)[\s\S]{0,260}RefreshMainCommandState\(true\)') {
    $failures.Add('Main pause/delete commands must start disabled and synchronize once after watchlist loading')
}
if ($mainSource -notmatch
        'RefreshMainWindowTheme\(\)\s*\{[\s\S]{0,1000}RefreshMainCommandState\(true\)' -or
    $mainSource -notmatch
        'themeStatePrefix\s*:=\s*UiThemeService\.GetActualTheme\(\)') {
    $failures.Add('Every main theme refresh must resynchronize theme-aware pause/delete command state')
}
# 主窗口首次 Show 会先映射原生控件和非客户区；深色主题重申完成前若已进入
# DWM 合成，就会提交一帧默认浅色表面。隐藏启动不能消耗首次揭示状态，首次
# 可见 Show 必须在 cloak 内同步刷新完整控件树，之后才能解除 cloak。
$firstPresentationSource = [regex]::Match($mainWindowControllerSource,
    '(?ms)^ShowMainGuiWithOptions\(showOptions := ""\)\s*\{.*?(?=^ShowMainGui\()').Value
$atomicPresenterSource = [regex]::Match($win32Source,
    '(?ms)^class FirstVisibleWindowPresenter\s*\{.*\z').Value
$cloakIndex = $atomicPresenterSource.IndexOf(
    'this.SetCloaked(guiObj.Hwnd, true)')
$visibleShowIndex = if ($cloakIndex -ge 0) {
    $atomicPresenterSource.IndexOf('guiObj.Show(showOptions)', $cloakIndex)
} else { -1 }
$prepareIndex = $atomicPresenterSource.IndexOf(
    'prepareVisibleSurface.Call()', [Math]::Max(0, $visibleShowIndex))
$flushIndex = $atomicPresenterSource.IndexOf(
    'this.FlushComposition()', [Math]::Max(0, $prepareIndex))
$uncloakIndex = $atomicPresenterSource.IndexOf(
    'this.SetCloaked(guiObj.Hwnd, false)', [Math]::Max(0, $flushIndex))
$completionIndex = $atomicPresenterSource.IndexOf(
    'FirstVisibleCompleted: surfacePrepared', [Math]::Max(0, $uncloakIndex))
$firstSurfaceSource = [regex]::Match($mainWindowControllerSource,
    '(?ms)^PrepareMainWindowFirstVisibleSurface\(\)\s*\{.*?(?=^ShowMainGuiWithOptions\()').Value
if (-not $firstPresentationSource -or
    $mainSource -match 'Main\.gui\.Show\(' -or
    $mainSource -notmatch 'ShowMainGuiWithOptions\("w" App\.savedWidth " h" App\.savedHeight\)' -or
    $mainSource -notmatch 'ShowMainGuiWithOptions\("w" App\.savedWidth " h" App\.savedHeight[\s\S]{0,80}" Hide"\)' -or
    $mainWindowStateSource -notmatch 'this\.firstVisiblePresentationCompleted\s*:=\s*false' -or
    $win32Source -notmatch 'static DWMWA_CLOAK\s*:=\s*13' -or
    $win32Source -notmatch 'static DWMWA_CLOAKED\s*:=\s*14' -or
    $atomicPresenterSource -notmatch 'SetCloaked\(hWnd, cloaked\)[\s\S]{0,500}DwmSetWindowAttribute[\s\S]{0,160}Win32\.DWMWA_CLOAK' -or
    $atomicPresenterSource -notmatch 'GetCloakState\(hWnd\)[\s\S]{0,500}DwmGetWindowAttribute[\s\S]{0,160}Win32\.DWMWA_CLOAKED' -or
    $atomicPresenterSource -notmatch 'OptionsKeepWindowHidden\(showOptions\)[\s\S]{0,160}\(\^\|\\s\)Hide' -or
    $atomicPresenterSource -notmatch 'if keepHidden \|\| firstVisibleCompleted\s*\{[\s\S]{0,160}guiObj\.Show\(showOptions\)' -or
    $cloakIndex -lt 0 -or $visibleShowIndex -lt $cloakIndex -or
    $prepareIndex -lt $visibleShowIndex -or $flushIndex -lt $prepareIndex -or
    $uncloakIndex -lt $flushIndex -or $completionIndex -lt $uncloakIndex -or
    $firstSurfaceSource -notmatch 'UiThemeService\.ApplyProcessPreference\(\)[\s\S]{0,180}ApplyNativeWindowTheme\(Main\.gui\.Hwnd\)' -or
    $firstSurfaceSource -notmatch 'ApplyDarkListViewTheme\(Main\.lv\.Hwnd\)[\s\S]{0,500}listHeader\.ApplyAppearance' -or
    $firstSurfaceSource -notmatch 'statsPresenter\.Redraw\(\)[\s\S]{0,300}RefreshMainCommandButtonsAfterShow\(\)[\s\S]{0,260}Win32\.RDW_LAYOUT_REFRESH' -or
    $firstPresentationSource -notmatch 'FirstVisibleWindowPresenter\.Show\(Main\.gui, showOptions,[\s\S]{0,260}PrepareMainWindowFirstVisibleSurface,[\s\S]{0,120}RefreshMainCommandButtonsAfterShow\)[\s\S]{0,180}Main\.firstVisiblePresentationCompleted\s*:=\s*result\.FirstVisibleCompleted' -or
    $mainWindowControllerSource -notmatch 'RefreshMainCommandButtonsAfterShow\(\)\s*\{[\s\S]{0,500}RedrawVisibleRoundedButtons\(\[[\s\S]{0,120}Main\.btnAdd, Main\.btnPause, Main\.btnDel,[\s\S]{0,120}Main\.btnSet, Main\.btnSupport, Main\.btnAbout' -or
    $interactionPresenterSource -notmatch 'RedrawVisibleRoundedButtons\(controls\)[\s\S]{0,500}IsWindowVisible[\s\S]{0,300}RedrawRoundedButton\(controlHwnd\)' -or
    $mainWindowControllerSource -notmatch 'ShowMainGui\(\*\)\s*\{\s*ShowMainGuiWithOptions\(\)' -or
    $resourceSoakTestSource -notmatch 'VerifyAtomicMainWindowFirstPresentation\(\)[\s\S]{0,4200}hidden startup consumed the first visible presentation' -or
    $resourceSoakTestSource -notmatch 'first visible presentation did not acquire DWM cloak' -or
    $resourceSoakTestSource -notmatch 'first visible presentation did not remove DWM cloak' -or
    $resourceSoakTestSource -notmatch 'AssertWindowPixelColor\(Main\.lv\.Hwnd,[\s\S]{0,120}"Surface", "ListView"\)' -or
    $resourceSoakTestSource -notmatch 'normal restore left the main window cloaked') {
    $failures.Add('The first visible main-window frame must be fully dark-painted under DWM cloak before atomic reveal')
}
if ($mainSource -notmatch
        'ShouldToggleMainListPause\(wParam, lParam, ctrlDown, shiftDown, altDown\)[\s\S]{0,260}0x40000000' -or
    $mainSource -notmatch
        'if \(hwnd == Main\.lv\.Hwnd\)[\s\S]{0,700}wParam == 32[\s\S]{0,260}ToggleItemPause\(\)[\s\S]{0,260}return 0') {
    $failures.Add('Main ListView Space must toggle selected targets once while preserving modified-space selection behavior')
}
if ($settingsWindowSource -notmatch
        'CreateTabButton\(index,[\s\S]{0,500}RegisterHoverButton\(button,') {
    $failures.Add('Settings tabs must pass through the centralized system-font button registration')
}

# 表单确认／取消操作保持纯文字，普通功能动作使用共享 Lucide SVG 管线。
# 主窗口添加、暂停／恢复、删除是既有产品视觉的明确例外，保留彩色字符图标。
foreach ($retiredButtonEmoji in @(
    'Tr("✔️ 确 定")',
    'Tr("❌ 取 消")',
    'Tr("🔍 搜索...")',
    'Tr("📂 选择...")'
)) {
    if ($source.Contains($retiredButtonEmoji)) {
        $failures.Add("Retired Emoji button text remains: $retiredButtonEmoji")
    }
}
foreach ($requiredMainCommandText in @(
    'Tr("➕ 添加")',
    'Tr("🗑️ 删除")',
    'Tr("⏸️ 暂停")',
    'Tr("▶️ 恢复")',
    'Tr("🔄 反转状态")'
)) {
    if (-not $mainSource.Contains($requiredMainCommandText)) {
        $failures.Add("Missing main command character icon contract: $requiredMainCommandText")
    }
}
if ($mainSource -match
        'SetButtonLucideIcon\(Main\.btn(?:Add|Pause|Del)\s*,') {
    $failures.Add('Main add/pause/delete commands must not be rebound to Lucide SVG icons')
}
if (-not $mainSource.Contains('SetButtonLeadingTextSlot(Main.btnAdd, 20, 4)') -or
    -not $mainSource.Contains('SetButtonLeadingTextSlot(Main.btnPause, 20, 4)') -or
    -not $mainSource.Contains('SetButtonLeadingTextSlot(Main.btnDel, 20, 4)') -or
    -not $interactionPresenterSource.Contains('DrawLeadingCommandSymbol(hdc, symbol, left, top, right, bottom,') -or
    -not $interactionPresenterSource.Contains('state.leadingTextVisualSizeDip * dpi / 96') -or
    -not $interactionPresenterSource.Contains('CreateRasterCenteredTextRect(hdc, text, left, top, right,') -or
    -not $interactionPresenterSource.Contains('RasterInkBoundsCache') -or
    -not $interactionPresenterSource.Contains('"Ptr", leadingRect, "UInt", 0x00000825')) {
    $failures.Add('Main add/pause/delete symbols must use one fixed icon slot and text layout')
}
if ($interactionPresenterSource -notmatch
        'SetButtonLucideIcon\(ctrl, iconName,[\s\S]{0,500}GetApplicationAssetPath\([\s\S]{0,160}ui-icons\\lucide\\') {
    $failures.Add('Functional buttons must resolve Lucide assets through one shared helper')
}
foreach ($requiredFunctionalIcon in @(
    'SetButtonLucideIcon(this.searchButton, "search.svg"',
    'SetButtonLucideIcon(this.browseButton, "folder-open.svg"',
    'SetButtonLucideIcon(btnBrowseWorkDir, "folder-open.svg"',
    'SetButtonLucideIcon(this.exportButton, "package-open.svg"',
    'SetButtonLucideIcon(btnAutoRoot, "wand-sparkles.svg"',
    'SetButtonLucideIcon(btnClearLearned, "trash-2.svg"',
    'SetButtonLucideIcon(this.checkUpdateButton,',
    '"refresh-cw-action.svg"'
)) {
    if (-not $source.Contains($requiredFunctionalIcon)) {
        $failures.Add("Missing semantic SVG button hook: $requiredFunctionalIcon")
    }
}
if ($customDisplayDialogSource -match
        'SetButton(?:Lucide|Svg)Icon\(this\.default(?:Name|Icon)Button') {
    $failures.Add('Custom display restore-default buttons must remain text-only')
}

# 小助手自身更新必须保持在独立进程中，并把个人配置、入口重命名和失败回滚作为
# 显式边界；这些钩子缺失时，最容易退化为阻塞 GUI 或覆盖用户状态。
foreach ($updateHook in @(
        'Run(command, this.InstallRoot, "Hide", &workerPid)',
        'SetTimer(this.PollTimer, 250)',
        'this.WorkerHandle',
        '"-PackageKind", this.GetPackageKind()',
        '"-UiLanguage", this.UiLanguage',
        'application-update.strings.json',
        'ProcessWatchdogUpdateApply-',
        'DirDelete(helperDirectory, true)')) {
    if (-not $applicationUpdateSource.Contains($updateHook)) {
        $failures.Add("Missing asynchronous application-update hook: $updateHook")
    }
}
foreach ($helperHook in @(
        'Wait-ForParentExit',
        'Get-ExpectedChecksum',
        'Get-FileHash -Algorithm SHA256',
        'Assert-NoOverlappingPaths',
        'Get-MinimalManagedPaths',
        'Restore-ArchiveTransaction',
        'New-PersonalStateSnapshot',
        'Restore-PersonalStateSnapshot',
        'Complete-PersonalStateSnapshot',
        '[System.IO.File]::Replace',
        'Test-UpdatedApplication',
        'Wait-ForUpdatedApplicationReady',
        "'--unshallow'",
        'update-manifest.json',
        "@('watchdog.ini', 'watchdog.maintenance.ini')",
        "'--error-unmatch'",
        "'merge-base'",
        "'--ff-only'",
        'Remove-ApplyHelperDirectory')) {
    if (-not $applicationUpdateHelperSource.Contains($helperHook)) {
        $failures.Add("Missing application-update helper boundary: $helperHook")
    }
}
if ($applicationUpdateSource -notmatch
        'if\s+!this\.WorkerHandle[\s\S]{0,260}this\.CleanupCheck\(\)' -or
    $applicationUpdateSource -match
        'IsWorkerAlive\(\)[\s\S]{0,220}ProcessExist\(this\.WorkerPid\)') {
    $failures.Add('Application update checks must require a real process handle instead of falling back to a reusable PID')
}
if ($source -notmatch
        'guardRuntimeStarted\s*:=\s*App\.guardRuntime\.Start\(\)' -or
    $source -notmatch
        'if\s+applicationUpdateReadyPath\s*\{[\s\S]{0,320}if\s+!guardRuntimeStarted[\s\S]{0,180}WriteApplicationUpdateReadySignal') {
    $failures.Add('Application update readiness must require the core guard runtime to start successfully')
}
if ($applicationUpdateSource -match 'Invoke-(?:WebRequest|RestMethod)' -or
    $applicationUpdateSource -match 'Expand-Archive|Get-FileHash') {
    $failures.Add('Application update network, archive, and hash work must not run in the AHK GUI process')
}

# 运行时仓库和示例配置必须共用同一套中文就地说明。否则源码新增或修改字段后，
# 用户查看示例得到的约束会与程序实际生成的 watchdog.ini 不一致。
foreach ($commentMatch in [regex]::Matches($configRepositorySource,
        'this\.Text\("(;(?:``.|[^"\r\n])*)"\)')) {
    $managedComment = $commentMatch.Groups[1].Value -replace '``"', '"'
    if (-not $iniText.Contains($managedComment)) {
        $failures.Add("config/watchdog.example.ini is missing managed comment: $managedComment")
    }
}

# 中文用户界面字符串不允许保留英文排版的“空格 + 半角左括号”。
# 逐行提取 AHK 字符串字面量，避免把函数调用和正则表达式误判为文案。
$userTextViolations = New-Object 'System.Collections.Generic.List[string]'
foreach ($line in ($source + "`n" + $allModuleSource) -split "`r?`n") {
    foreach ($literalMatch in [regex]::Matches(
        $line, '"[^"\r\n]*"|''[^''\r\n]*''')) {
        $literal = $literalMatch.Value
        if ($literal -match '[\u3400-\u9fff]' -and
            $literal.Contains(' (')) {
            $userTextViolations.Add($literal)
        }
    }
}
if ($userTextViolations.Count -gt 0) {
    $samples = ($userTextViolations | Select-Object -First 3 |
        ForEach-Object { $_ }) -join ' | '
    $failures.Add("User-visible Chinese text uses space plus half-width parenthesis: $samples")
}
if ($readmeSource -match '(?m)[\u3400-\u9fff][^\r\n]* \(') {
    $failures.Add('README uses space plus half-width parenthesis in Chinese text')
}

$dependencyLockPath = Join-Path $projectRoot 'third_party\dependencies.lock.json'
try {
    $dependencyLock = Get-Content -LiteralPath $dependencyLockPath -Raw `
        -Encoding UTF8 | ConvertFrom-Json
    if ($dependencyLock.schemaVersion -ne 1 -or
        $dependencyLock.dependencies.Count -ne 2) {
        $failures.Add('Third-party dependency lock must contain the two runtime DLLs')
    }
    foreach ($dependency in $dependencyLock.dependencies) {
        $dependencyPath = Join-Path $projectRoot `
            ([string]$dependency.path -replace '/', '\')
        if (-not (Test-Path -LiteralPath $dependencyPath -PathType Leaf)) {
            $failures.Add("Missing pinned dependency: $($dependency.name)")
            continue
        }
        $actualHash = (Get-FileHash -Algorithm SHA256 `
            -LiteralPath $dependencyPath).Hash
        if ($actualHash -ne $dependency.sha256) {
            $failures.Add("Pinned dependency hash mismatch: $($dependency.name) ($actualHash)")
        }
    }
} catch {
    $failures.Add("Third-party dependency lock is unreadable: $($_.Exception.Message)")
}
# 独立可选字体包属于发行输入资源，而不是程序运行前提；仓库门禁仍必须验证固定
# 数量、哈希和授权，确保用户安装到 Windows 的资源可追溯且未被替换。
$fontMetadataPath = Join-Path $projectRoot 'assets\fonts\metadata.json'
try {
    $fontMetadata = Get-Content -LiteralPath $fontMetadataPath -Raw `
        -Encoding UTF8 | ConvertFrom-Json
    if ($fontMetadata.schemaVersion -ne 1 -or $fontMetadata.fonts.Count -ne 7) {
        $failures.Add('Packaged font metadata must contain the preferred and fallback resources')
    }
    foreach ($font in $fontMetadata.fonts) {
        $fontPath = Join-Path $projectRoot `
            ([string]$font.path -replace '/', '\')
        if (-not (Test-Path -LiteralPath $fontPath -PathType Leaf)) {
            $failures.Add("Missing packaged font: $($font.name)")
            continue
        }
        $fontLicense = [string]$font.license
        $metadataInvalid = $fontLicense -notin @('OFL-1.1',
                'LicenseRef-Commercial-Apple-Fonts') -or
            ($fontLicense -eq 'LicenseRef-Commercial-Apple-Fonts' -and
                [string]::IsNullOrWhiteSpace([string]$font.authorization))
        if (-not $SkipPackagedFontContentValidation) {
            $fontHash = (Get-FileHash -Algorithm SHA256 `
                -LiteralPath $fontPath).Hash
            $metadataInvalid = $metadataInvalid -or
                $fontHash -ne [string]$font.sha256
        }
        if ($metadataInvalid) {
            $failures.Add("Packaged font metadata mismatch: $($font.name)")
        }
    }
} catch {
    $failures.Add("Packaged font metadata is unreadable: $($_.Exception.Message)")
}
foreach ($fontDocument in @(
        'assets\fonts\COMMERCIAL-LICENSE-NOTICE.md',
        'assets\fonts\COMMERCIAL-LICENSE-NOTICE.en.md',
        'assets\fonts\OFL-1.1.txt',
        'assets\fonts\README.md',
        'assets\fonts\README.en.md')) {
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $fontDocument) `
            -PathType Leaf)) {
        $failures.Add("Missing packaged font provenance file: $fontDocument")
    }
}
$expectedFontAssetNames = @(
    'AppleSDGothicNeo-Regular.ttf',
    'COMMERCIAL-LICENSE-NOTICE.en.md',
    'COMMERCIAL-LICENSE-NOTICE.md',
    'HaranoAjiGothic-Regular.otf',
    'NotoSans-Variable.ttf',
    'NotoSansCJK.ttc',
    'PingFang.ttc',
    'SF-Pro-Text-Bold.otf',
    'SF-Pro-Text-Regular.otf',
    'metadata.json',
    'OFL-1.1.txt',
    'README.en.md',
    'README.md'
)
$actualFontAssetNames = @(Get-ChildItem -LiteralPath `
    (Join-Path $projectRoot 'assets\fonts') -File | ForEach-Object Name |
    Sort-Object)
$fontAssetDifference = @(Compare-Object -CaseSensitive `
    -ReferenceObject ($expectedFontAssetNames | Sort-Object) `
    -DifferenceObject $actualFontAssetNames)
if ($fontAssetDifference.Count -ne 0 -or
    $actualFontAssetNames.Count -ne $expectedFontAssetNames.Count) {
    $failures.Add('Packaged font directory contains a missing or unapproved file')
}
if (Test-Path -LiteralPath (Join-Path $projectRoot 'Everything64.dll')) {
    $failures.Add('Everything64.dll must not remain at the project root')
}
foreach ($dependencyDocument in @(
    'third_party\README.md',
    'third_party\resvg\VERSION.txt',
    'third_party\resvg\resvg.h',
    'third_party\resvg\LICENSE-MIT',
    'third_party\resvg\LICENSE-APACHE',
    'third_party\everything\VERSION.txt',
    'third_party\everything\LICENSE.txt'
)) {
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $dependencyDocument) `
        -PathType Leaf)) {
        $failures.Add("Missing third-party provenance file: $dependencyDocument")
    }
}

foreach ($notificationRequirement in @(
    'OnMessage(Win32.AHK_NOTIFYICON, OnTrayNotification)',
    'SetCurrentProcessExplicitAppUserModelID", "WStr"',
    '(lParam & 0xFFFF) == Win32.NIN_BALLOONUSERCLICK',
    'SetTimer(OpenNotificationWindows, -1)',
    'ShowMainGui()',
    'ShowLog()',
    'WinActivate("ahk_id " logHwnd)'
)) {
    if (-not $source.Contains($notificationRequirement)) {
        $failures.Add("Missing actionable notification behavior: $notificationRequirement")
    }
}
if ($source -notmatch 'SetCurrentProcessExplicitAppUserModelID",\s*"WStr",\s*Tr\("\u8FDB\u7A0B\u5B88\u62A4\u5C0F\u52A9\u624B"\)') {
    $failures.Add('Notification AppUserModelID must use the localized stable application name')
}
if ($source -match 'ProcessWatchdog_\s*"?\s*\.\s*A_ScriptHwnd') {
    $failures.Add('Notification AppUserModelID must not contain a per-process window handle')
}

if ($iniLines.Count -eq 0 -or $iniLines[0] -ne '[Settings]') {
    $failures.Add('config/watchdog.example.ini documentation must stay with its sections instead of a top-level block')
}

$rootGlobals = [regex]::Matches($source, '(?m)^global\s+([A-Za-z_][A-Za-z0-9_]*)\s*:=' ) |
    ForEach-Object { $_.Groups[1].Value }
$expectedGlobals = @('App', 'Main', 'GuiModules')
if (($rootGlobals -join ',') -ne ($expectedGlobals -join ',')) {
    $failures.Add("Root globals must be App, Main, GuiModules; found: $($rootGlobals -join ', ')")
}
$moduleFiles = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'src') `
    -Recurse -Filter '*.ahk' -File
$moduleRelativePaths = $moduleFiles | ForEach-Object {
    $_.FullName.Substring($projectRoot.Length + 1)
}
$sourceModuleIncludes = [regex]::Matches($source,
    '(?m)^#Include\s+(src\\[^\r\n]+\.ahk)\s*$') |
    ForEach-Object { $_.Groups[1].Value.Trim() }
foreach ($moduleRelativePath in $moduleRelativePaths) {
    $includeCount = @($sourceModuleIncludes | Where-Object {
        $_ -eq $moduleRelativePath
    }).Count
    if ($includeCount -ne 1) {
        $failures.Add("Source module must be included exactly once: $moduleRelativePath ($includeCount)")
    }
}
foreach ($includedModule in $sourceModuleIncludes) {
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $includedModule))) {
        $failures.Add("Main script includes a missing source module: $includedModule")
    }
}
$appRelativePaths = $appModuleFiles | ForEach-Object {
    $_.FullName.Substring($projectRoot.Length + 1)
}
$appModuleIncludes = [regex]::Matches($mainSource,
    '(?m)^#Include\s+(app\\[^\r\n]+\.ahk)\s*$') |
    ForEach-Object { $_.Groups[1].Value.Trim() }
foreach ($appRelativePath in $appRelativePaths) {
    $includeCount = @($appModuleIncludes | Where-Object {
        $_ -eq $appRelativePath
    }).Count
    if ($includeCount -ne 1) {
        $failures.Add("Application module must be included exactly once: $appRelativePath ($includeCount)")
    }
}
if ($appModuleSource -match '(?m)^\s*#Include\s+') {
    $failures.Add('Application modules must be included only by the composition root')
}
if ($allModuleSource -match '(?m)^\s*#Include\s+') {
    $failures.Add('Source modules must not recover dependencies through nested includes')
}
if ($allModuleSource -match '(?m)^\s*global\s+' -or
    $allModuleSource -match '\b(?:App|Main|GuiModules)\.') {
    $failures.Add('src modules must receive dependencies explicitly instead of reading root globals')
}

foreach ($svgLibraryHook in @(
    'class SvgRenderLibrary',
    'LoadLibraryExW',
    'GetProcAddress',
    'resvg_options_load_system_fonts',
    'resvg_parse_tree_from_data',
    'resvg_get_image_size',
    'resvg_render',
    'resvg_tree_destroy',
    'sourceSize > SvgRenderLibrary.MaximumInputBytes',
    'this.Rendering := true',
    'this.Rendering := false',
    'FreeLibrary'
)) {
    if (-not $svgRenderLibrarySource.Contains($svgLibraryHook)) {
        $failures.Add("Missing resvg ownership or render boundary: $svgLibraryHook")
    }
}
if ($source -notmatch '#Include src\\UI\\SvgRenderLibrary\.ahk' -or
    $source -notmatch 'this\.svgRenderer\s*:=\s*SvgRenderLibrary\([\s\S]{0,120}third_party\\resvg\\resvg\.dll' -or
    $source -notmatch 'CreateSvgPaddedIcon\([\s\S]{0,500}svgRenderer\.RenderFile\([\s\S]{0,500}CreateShellSvgPaddedIcon\(' -or
    $source -notmatch 'ShutdownApplicationResources\(\*\)[\s\S]{0,360}App\.svgRenderer\.Shutdown\(\)') {
    $failures.Add('ApplicationState must own resvg and preserve Shell fallback plus explicit shutdown')
}
if (($source + "`n" + $allModuleSource) -match
    'FindSvgBrowserRasterizer|EnsureSvgBrowserRaster|GetSvgRasterCachePath|BuildSvgBrowserCommand|CleanupSvgBrowserProfile|--headless=new|edge-profile-|msedge\.exe') {
    $failures.Add('Retired browser-based SVG rendering code remains')
}

foreach ($sectionName in @('Settings', 'Layout', 'Apps', 'Maintenance')) {
    $headerIndex = [Array]::IndexOf($iniLines, "[$sectionName]")
    if ($headerIndex -lt 0 -or $headerIndex + 1 -ge $iniLines.Count -or
        -not $iniLines[$headerIndex + 1].StartsWith(';')) {
        $failures.Add("config/watchdog.example.ini section $sectionName must begin with documentation comments")
    }
}
$displayHeaderIndex = [Array]::IndexOf($iniLines, '[Display]')
if ($displayHeaderIndex -ge 0 -and
    ($displayHeaderIndex + 1 -ge $iniLines.Count -or
        -not $iniLines[$displayHeaderIndex + 1].StartsWith(';'))) {
    $failures.Add('config/watchdog.example.ini section Display must begin with documentation comments when present')
}

if ($configRepositorySource -notmatch 'EnsureDocumentation\(iniPath\)') {
    $failures.Add('Configuration transactions must restore in-place documentation')
}

$documentedKeySections = @('Settings', 'Layout')
$currentIniSection = ''
for ($lineIndex = 0; $lineIndex -lt $iniLines.Count; $lineIndex++) {
    $line = $iniLines[$lineIndex]
    if ($line -match '^\[(.+)\]$') {
        $currentIniSection = $Matches[1]
        continue
    }
    if ($currentIniSection -in $documentedKeySections -and $line -match '^[^;=]+=' -and
        ($lineIndex -eq 0 -or -not $iniLines[$lineIndex - 1].StartsWith(';'))) {
        $failures.Add("config/watchdog.example.ini key $currentIniSection/$($line.Split('=', 2)[0]) must have an adjacent comment")
    }
}

$forbiddenSymbols = @(
    'SmoothScroll',
    'ScrollListViewByWheel',
    'WM_PRINTCLIENT',
    'MaintenanceBeforeFingerprint',
    'MaintenanceStableSince',
    'AutoSuspendReason',
    'pendingMaintenanceCommand(?!s)',
    'CachedWMICmdLines',
    'wmiCacheList',
    'GetReferencedProcessSnapshotIndex',
    'CommandLineContainsTarget',
    'CommandTokenMatchesTarget',
    'TEMP_UI_TEST',
    'CODEX_UI_TEST',
    'ProcessWatchdogCodexUi',
    'ProcessLoopBusy',
    'EventLoopBusy'
)
foreach ($symbol in $forbiddenSymbols) {
    if ($source -match $symbol) {
        $failures.Add("Deprecated symbol remains: $symbol")
    }
}

$requiredButtonReleaseHooks = @(
    'OnMessage(Win32.WM_LBUTTONDOWN, OnGlobalPointerDown)',
    'OnMessage(Win32.WM_LBUTTONUP, OnGlobalPointerUp)',
    'OnMessage(Win32.WM_CANCELMODE, OnButtonPressCancelled)',
    'OnMessage(Win32.WM_CAPTURECHANGED, OnButtonCaptureChanged)',
    'ctrl.OnEvent("Click", HandleRegisteredButtonClick)',
    'SetTimer(RunDeferredButtonClick.Bind(pressedHwnd, pendingClick), -1)'
)
foreach ($requiredHook in $requiredButtonReleaseHooks) {
    if (-not $source.Contains($requiredHook)) {
        $failures.Add("Missing button release-dispatch hook: $requiredHook")
    }
}

foreach ($feedbackSymbol in @(
    'ButtonFeedbackMode.Persistent',
    'ButtonFeedbackMode.Dismissive',
    'ButtonFeedbackTiming.ReleaseResetMs',
    'ResolvePersistentButtonPressedColor',
    'ResolveButtonFeedbackPressedColor',
    'ScheduleButtonReleaseReset',
    'ResetButtonAfterRelease',
    'Win32.WM_SETREDRAW',
    'Win32.RDW_BUTTON_REFRESH',
    'RoundedButtonRenderer.Draw',
    'static IsDisabled(state)',
    'EnableRoundedButtonRendering',
    'OnDrawRoundedButton',
    'RoundedButtonInputRouter.Attach',
    'ButtonControlSubclassProc',
    'IsRoundedButtonInputRouted',
    'HandleButtonMouseLeave',
    'HandleButtonCaptureChanged',
    'GdipSetSmoothingMode',
    'CreateCompatibleBitmap',
    'SetButtonTextColor'
)) {
    if (-not $source.Contains($feedbackSymbol)) {
        $failures.Add("Missing lifecycle-aware button feedback: $feedbackSymbol")
    }
}
if ($source -notmatch 'static\s+ReleaseResetMs\s*:=\s*50') {
    $failures.Add('Button release feedback must remain at 50 ms')
}
if ($source -match 'Main\.btn(?:Del|Pause)\.Opt\([^\r\n]*Background') {
    $failures.Add('Dynamic main button backgrounds must respect release feedback timing')
}
if ($source -match 'Main\.btn(?:Del|Pause)\.Opt\([^\r\n]*c(?:White|[0-9A-Fa-f]{6})') {
    $failures.Add('Dynamic main button text colors must use the rounded button state layer')
}
if ($source -notmatch 'state\.roundedOwnerDraw\s*:=\s*EnableRoundedButtonRendering\(ctrl\)') {
    $failures.Add('Registered buttons must enable the shared rounded owner-draw renderer')
}
if ($source -notmatch 'if\s+!pendingClick\s+&&\s+state\.HasOwnProp\("clickCallback"\)') {
    $failures.Add('Owner-drawn static buttons must dispatch from validated mouse release')
}
if ($source -match 'itemState\s*&\s*0x0004|ODS_DISABLED') {
    $failures.Add('Rounded buttons must not trust the false ODS_DISABLED flag from owner-drawn AHK Text controls')
}
if ([regex]::Matches($source, 'if\s+this\.IsDisabled\(state\)').Count -lt 2) {
    $failures.Add('Rounded button background and text must use the real control enabled state')
}
if ($source -notmatch 'static\s+IsDisabled\(state\)[\s\S]{0,400}IsWindowEnabled[\s\S]{0,120}state\.ctrl\.Hwnd') {
    $failures.Add('Rounded button visuals must inspect only the control enabled state')
}
if ($source -match 'static\s+IsDisabled\(state\)[\s\S]{0,400}try\s+return\s+!IsControlEffectivelyEnabled\(') {
    $failures.Add('Owner-window modality must not dim visible rounded buttons')
}
if ($source -match 'GdipCreatePen1|GdipDrawPath|borderPen|focusPen|focusPath') {
    $failures.Add('Rounded buttons must remain borderless in every interaction state')
}
if ($source -notmatch 'OnMouseMove_Tooltip\([^)]*\)\s*\{\s*if\s+!IsRoundedButtonInputRouted\(hwnd\)') {
    $failures.Add('Global mouse-move routing must skip subclassed rounded buttons')
}
if ($source -notmatch 'OnGlobalPointerDown\([^)]*\)\s*\{\s*if\s+App\.uiInteractions\.HasButton\(hwnd\)\s*&&\s*!IsRoundedButtonInputRouted\(hwnd\)') {
    $failures.Add('Global pointer-down routing must skip subclassed rounded buttons')
}
if ($interactionPresenterSource -notmatch
    'HandleBlankPointerDown\(\s*Main\.lv,\s*Main\.gui\.Hwnd,\s*hwnd,\s*lParam,\s*msg,\s*passiveSurfaces\)' -or
    $listViewFocusServiceSource -notmatch
    'HandleBlankPointerDown\([^)]*pointerMessage[^)]*\)[\s\S]{0,500}if\s+pointerMessage\s*!=\s*Win32\.WM_LBUTTONDOWN\s*\r?\n\s*return\s+this\.NoAction') {
    $failures.Add('ListView blur routing must reject non-client pointer messages before handling the root window')
}
if ($source -notmatch 'OnGlobalPointerUp\([^)]*\)\s*\{\s*if\s+!IsRoundedButtonInputRouted\(hwnd\)') {
    $failures.Add('Global pointer-up routing must skip subclassed rounded buttons')
}
if ($source -notmatch 'case\s+Win32\.WM_MOUSELEAVE:\s*HandleButtonMouseLeave\(hWnd\)') {
    $failures.Add('Rounded button subclass must own mouse-leave routing')
}
if ($source -notmatch 'case\s+Win32\.WM_CAPTURECHANGED:\s*HandleButtonCaptureChanged\(hWnd\)') {
    $failures.Add('Rounded button subclass must own capture-change routing')
}
foreach ($uiInteractionHook in @(
    'class UiCursorKind',
    'class UiInteractionRegistry',
    'RegisterButton(hwnd, state)',
    'RemoveButton(hwnd)',
    'SetPressedButton(hwnd)',
    'ClearPressedButton(expectedHwnd := 0)',
    'SetHoveredButton(hwnd)',
    'ClearHoveredButton(expectedHwnd := 0)',
    'ShouldPruneButtons(nowTicks, intervalMs := 1000)',
    'RegisterTextInput(targetHwnd, state)',
    'RemoveTextInput(targetHwnd)',
    'GetCursor(kind, cursorId)'
)) {
    if (-not $uiInteractionRegistrySource.Contains($uiInteractionHook)) {
        $failures.Add("Missing UI interaction registry boundary: $uiInteractionHook")
    }
}
if ($source -notmatch '#Include src\\UI\\UiInteractionRegistry\.ahk' -or
    $source -notmatch 'this\.uiInteractions\s*:=\s*UiInteractionRegistry\(\)') {
    $failures.Add('ApplicationState must own one UI interaction registry')
}
foreach ($legacyUiInteractionField in @(
    'buttonHoverStates',
    'hoveredButtonHwnd',
    'pressedButtonHwnd',
    'hoverPruneTicks',
    'textInputCursorStates',
    'handCursor',
    'arrowCursor',
    'textCursor'
)) {
    if ($source -match "\b(?:App\.|this\.)$legacyUiInteractionField\b") {
        $failures.Add("Legacy UI interaction field remains: $legacyUiInteractionField")
    }
}
if ($source -notmatch 'UpdateButtonHover\(hWnd\)[\s\S]{0,240}uiInteractions[\s\S]{0,240}ShouldPruneButtons\(nowTicks\)' -or
    $source -notmatch 'SetHandCursor\(\)[\s\S]{0,180}uiInteractions\.GetCursor\(UiCursorKind\.Hand') {
    $failures.Add('Button hover pruning and system cursor caching must delegate to UiInteractionRegistry')
}
if ($source -notmatch 'ToggleItemPause\(\*\)[\s\S]{0,2500}ControlFocus\(Main\.lv\)') {
    $failures.Add('Pause or resume must restore ListView focus without changing its selection')
}
if ($maintenanceConfigCodecSource -notmatch 'CreateDefault\(path\)[\s\S]{0,180}Enabled:\s*false') {
    $failures.Add('New monitoring targets must keep software update protection disabled by default')
}
if ($source -match 'requestedMaintenance\s*:=\s*true') {
    $failures.Add('Resolved shortcuts must not enable software update protection implicitly')
}
foreach ($processInspectorHook in @(
    'class ProcessInspector',
    'CaptureNativeSnapshot()',
    'CaptureAutoHotkeyScriptSnapshot(maximumAgeMs := 0)',
    'GetImagePath(pid)',
    'GetCreationIdentity(pid)',
    'GetElevationState(pid)',
    'kernel32\CreateToolhelp32Snapshot',
    'Win32.PROCESS_QUERY_LIMITED_INFORMATION',
    'psapi\GetProcessImageFileNameW',
    'kernel32\QueryDosDeviceW',
    'Win32.TOKEN_QUERY',
    'Win32.TOKEN_ELEVATION',
    'advapi32\OpenProcessToken',
    'advapi32\GetTokenInformation'
)) {
    if (-not $processInspectorSource.Contains($processInspectorHook)) {
        $failures.Add("Missing native process inspector hook: $processInspectorHook")
    }
}
if ($processInspectorSource -match
        'SeDebugPrivilege|AdjustTokenPrivileges|EnsureDebugPrivilege|OpenQueryHandle') {
    $failures.Add('Process inspection must not enable debug privilege or retry access-denied queries with elevated rights')
}
foreach ($fieldCodecHook in @(
    'class IniFieldCodec',
    'static Encode(value)',
    'static Decode(value)',
    'return "<HEX>" hex'
)) {
    if (-not $iniFieldCodecSource.Contains($fieldCodecHook)) {
        $failures.Add("Missing INI field codec hook: $fieldCodecHook")
    }
}
if ($iniFieldCodecSource -notmatch 'StrGet\(decodedBuffer, byteCount, "UTF-8"\)[\s\S]{0,220}IniFieldCodec\.Encode\(decodedValue\)\s*==\s*"<HEX>" StrUpper\(hex\)') {
    $failures.Add('INI field decoding must reject non-round-trippable UTF-8')
}
foreach ($configRepositoryHook in @(
    'class WatchdogConfigRepository',
    'EnsureExists(defaultSections)',
    'ReadSectionEntries(sectionName)',
    'ReadSectionMap(sectionName)',
    'WriteValues(sectionName, entries)',
    'ReplaceSections(sections)',
    'Transact(writer)',
    'FileCopy(this.Path, tempPath, 1)',
    'FileMove(tempPath, this.Path, 1)',
    'this.EnsureDocumentation(tempPath)',
    'static InsertSectionComment(',
    'static InsertKeyComment('
)) {
    if (-not $configRepositorySource.Contains($configRepositoryHook)) {
        $failures.Add("Missing configuration repository hook: $configRepositoryHook")
    }
}
if ($configRepositorySource -match '\bApp\.') {
    $failures.Add('Configuration repository must not recover dependencies from global App state')
}
if ($configRepositorySource -notmatch 'Transact\(writer\)[\s\S]{0,500}previousCritical\s*:=\s*A_IsCritical[\s\S]{0,1200}if ownsTransaction[\s\S]{0,160}Critical\(previousCritical') {
    $failures.Add('Configuration transactions must atomically restore ownership and caller critical state')
}
if ($source -notmatch 'this\.configRepository\s*:=\s*WatchdogConfigRepository\(') {
    $failures.Add('ApplicationState must own the main configuration repository')
}
if ($source -notmatch 'SetConfigRepository\(repository\)[\s\S]{0,500}runtimeSettingsService[\s\S]{0,120}windowLayoutService[\s\S]{0,120}watchlistPersistenceService') {
    $failures.Add('Replacing the configuration repository must update every owned persistence service atomically')
}
if ($source -notmatch 'this\.displayConfigCodec\s*:=\s*DisplayConfigCodec\(' -or
    $source -notmatch 'this\.maintenanceConfigCodec\s*:=\s*MaintenanceConfigCodec\(') {
    $failures.Add('ApplicationState must own display and maintenance configuration codecs')
}
foreach ($applicationConfigService in @(
    @{Name = 'runtime settings'; Source = $runtimeSettingsServiceSource; Class = 'RuntimeSettingsService'},
    @{Name = 'window layout'; Source = $windowLayoutServiceSource; Class = 'WindowLayoutService'},
    @{Name = 'watchlist persistence'; Source = $watchlistPersistenceServiceSource; Class = 'WatchlistPersistenceService'}
)) {
    if ($applicationConfigService.Source -notmatch "class\s+$($applicationConfigService.Class)" -or
        $applicationConfigService.Source -match '\b(?:App|Main|GuiModules)\.') {
        $failures.Add("The $($applicationConfigService.Name) service must use injected dependencies without root globals")
    }
}
if ($source -notmatch 'this\.maintenanceSessionCodec\s*:=\s*MaintenanceSessionCodec\(' -or
    $source -notmatch 'DeserializeSession:\s*ObjBindMethod\(this\.maintenanceSessionCodec,' -or
    $source -notmatch 'SerializeSession:\s*ObjBindMethod\(this\.maintenanceSessionCodec,') {
    $failures.Add('ApplicationState must own and inject the maintenance session codec')
}
if ($maintenanceSessionCodecSource -notmatch 'class\s+MaintenanceSessionCodec' -or
    $maintenanceSessionCodecSource -match '\bApp\.') {
    $failures.Add('Maintenance session serialization must be an injected module without global App access')
}
foreach ($configCodecCheck in @(
    @{Name = 'display'; Source = $displayConfigCodecSource; Class = 'DisplayConfigCodec'},
    @{Name = 'maintenance'; Source = $maintenanceConfigCodecSource; Class = 'MaintenanceConfigCodec'}
)) {
    if ($configCodecCheck.Source -notmatch "class\s+$($configCodecCheck.Class)" -or
        $configCodecCheck.Source -match '\bApp\.') {
        $failures.Add("The $($configCodecCheck.Name) configuration codec must be an injected module without global App access")
    }
}
$legacyConfigModelFunctions = @(
    'CreateDefaultMaintenanceConfig',
    'NormalizeMaintenanceConfig',
    'CloneMaintenanceConfig',
    'MaintenanceConfigsEqual',
    'NormalizeSnapshotMaintenanceConfig',
    'SerializeMaintenanceConfig',
    'DeserializeMaintenanceConfig',
    'CreateDefaultDisplayConfig',
    'NormalizeDisplayConfig',
    'CloneDisplayConfig',
    'DisplayConfigsEqual',
    'DisplayConfigIsDefault',
    'SerializeDisplayConfig',
    'DeserializeDisplayConfig',
    'SerializeMaintenanceSession',
    'DeserializeMaintenanceSession'
)
foreach ($legacyConfigModelFunction in $legacyConfigModelFunctions) {
    if ($source -match "(?m)^$legacyConfigModelFunction\(") {
        $failures.Add("Legacy main-script configuration function remains: $legacyConfigModelFunction")
    }
}
# 保存期间二次修改、最新修订追赶和失败重试由 main-integration-tests.ahk
# 通过真实仓库写入验证，避免在这里固化局部变量名和语句顺序。
foreach ($legacyConfigSymbol in @(
    'App\.iniPath',
    'EncodeIniField\s*\(',
    'DecodeIniField\s*\(',
    'ReadIniBool\s*\(',
    'ReadIniBoundedInt\s*\(',
    'ReadIniSectionEntries\s*\(',
    'ReadIniSectionMap\s*\(',
    'EnsureManagedIniSectionComments\s*\(',
    'InsertIniSectionComment\s*\('
)) {
    if ($source -match $legacyConfigSymbol) {
        $failures.Add("Legacy main-configuration ownership remains: $legacyConfigSymbol")
    }
}
if ($source -notmatch 'SaveAppsToIni\(markChanged := true\)[\s\S]{0,1800}watchlistPersistenceService\.Save\(' -or
    $watchlistPersistenceServiceSource -notmatch 'Repository\.ReplaceSections\(') {
    $failures.Add('Monitoring configuration must commit through the repository')
}
if ($source -notmatch '#Include src\\UI\\ControlAccessibilityService\.ahk' -or
    $controlAccessibilitySource -notmatch 'class ControlAccessibilityService' -or
    $interactionPresenterSource -notmatch 'ControlAccessibilityService\.RegisterButton' -or
    $interactionPresenterSource -notmatch 'ControlAccessibilityService\.ClearButton') {
    $failures.Add('Owner-drawn buttons must retain shared MSAA button semantics and symmetric cleanup')
}
foreach ($launchPersistenceHook in @(
    'ReadSectionMap("Launch")',
    '{Name: "Launch", Entries: launchEntries}',
    'RuntimePath: runtimePath',
    'RuntimeArgs: runtimeArguments',
    'Launch: launchValues.Has(appEntry.Key)',
    '"Launch"]'
)) {
    if (-not $watchlistPersistenceServiceSource.Contains($launchPersistenceHook)) {
        $failures.Add("Launch configuration is missing from watchlist persistence: $launchPersistenceHook")
    }
}
foreach ($launchSnapshotHook in @(
    'RuntimePath: stateObj.HasOwnProp("RuntimePath")',
    'RuntimeArgs: stateObj.HasOwnProp("RuntimeArgs")',
    'RuntimePath: item.HasOwnProp("RuntimePath")',
    'RuntimeArgs: item.HasOwnProp("RuntimeArgs")',
    'this.PathsEquivalent.Call(first.RuntimePath,',
    'first.RuntimeArgs == second.RuntimeArgs'
)) {
    if (-not $appConfigSnapshotServiceSource.Contains($launchSnapshotHook)) {
        $failures.Add("Launch configuration is missing from ordered snapshots or history equality: $launchSnapshotHook")
    }
}
foreach ($launchRuntimeHook in @(
    'this.RuntimePath := ""',
    'this.RuntimeArgs := ""'
)) {
    if (-not $targetSupervisorSource.Contains($launchRuntimeHook)) {
        $failures.Add("Target supervisor is missing launch configuration state: $launchRuntimeHook")
    }
}
foreach ($launchRegistrationHook in @(
    'RuntimePath: runtimePath, RuntimeArgs: runtimeArguments',
    'record.ShortcutArgs, record.Display, record.RuntimePath,',
    'item.RuntimePath, item.RuntimeArgs, item.ContentHash,',
    '"RuntimePath", "RuntimeArgs"]'
)) {
    if (-not $source.Contains($launchRegistrationHook)) {
        $failures.Add("Launch configuration is missing from registration or undo/redo restoration: $launchRegistrationHook")
    }
}
if ($targetSpecsServiceSource -notmatch 'StateValue\(stateObj, "RuntimePath"[\s\S]{0,120}StateValue\(stateObj, "RuntimeArgs"' -or
    $targetSpecsServiceSource -notmatch 'RuntimePath:\s*this\.StateValue\(stateObj, "RuntimePath"[\s\S]{0,160}RuntimeArguments:\s*this\.StateValue\(stateObj, "RuntimeArgs"') {
    $failures.Add('Runtime path and arguments must invalidate target-spec caches and rebuild LaunchSpec')
}
if ($configRepositorySource -notmatch '\{Name:\s*"Launch",\s*Lines:' -or
    $iniText -notmatch '(?m)^\[Launch\]\r?$' -or
    $iniText -notmatch 'AppN 与 \[Apps\] 中同名的守护对象一一对应，依次保存启动程序或解释器路径及其参数') {
    $failures.Add('The repository and UTF-16 example configuration must document the Launch section in place')
}
if ($documentationSource.Contains('Python 虚拟环境变量不能可靠替换 .py 文件关联所用的解释器')) {
    $failures.Add('Obsolete Python-specific shortcut workaround returned to user documentation')
}
if ($source -notmatch 'SaveAppsToIni\(markChanged := true\)[\s\S]{0,220}previousCritical\s*:=\s*A_IsCritical[\s\S]{0,100}Critical\("On"\)' -or
    $source -notmatch 'App\.appConfigSaveInProgress[\s\S]{0,6500}finally[\s\S]{0,180}App\.appConfigSaveInProgress\s*:=\s*false') {
    $failures.Add('Monitoring configuration saves must serialize revision ownership and restore caller critical state')
}
if ($runtimeSettingsServiceSource -notmatch 'Save\(settings\)[\s\S]{0,300}Repository\.WriteValues\("Settings"' -or
    $source -notmatch 'runtimeSettingsService\.Apply\(App, savedSettings\)') {
    $failures.Add('Runtime settings must commit through the repository')
}
if ($windowLayoutServiceSource -notmatch 'Save\(layout\)[\s\S]{0,300}Repository\.WriteValues\("Layout"' -or
    $source -notmatch 'HideMainGui\(force := false\)[\s\S]{0,1200}windowLayoutService\.Save\(') {
    $failures.Add('Window layout must commit through the repository')
}
if ([regex]::Matches($source, '\bIniWrite\(').Count -ne 0 -or
    [regex]::Matches($source, '\bIniRead\(').Count -ne 0 -or
    [regex]::Matches($maintenanceCoordinatorSource, '\bIniWrite\(').Count -ne 1 -or
    [regex]::Matches($maintenanceCoordinatorSource, '\bIniRead\(').Count -ne 1 -or
    $maintenanceCoordinatorSource -notmatch 'IniWrite\(this\.Callbacks\.SerializeSession\.Call' -or
    $maintenanceCoordinatorSource -notmatch 'IniRead\(journalPath, "Sessions"') {
    $failures.Add('Only MaintenanceCoordinator may directly persist the independent maintenance journal')
}
foreach ($elevationHook in @(
    'PIDElevationState: -1',
    'PIDElevationChecked: false',
    'EnsureStateProcessElevation(stateObj)',
    'IsRunAsAdminMismatch(stateObj)',
    'UpdateRunningState(path, stateObj)'
)) {
    if (-not $source.Contains($elevationHook)) {
        $failures.Add("Missing process elevation check: $elevationHook")
    }
}
foreach ($architectureHook in @(
    '#Include src\Platform\Win32.ahk',
    '#Include src\UI\AtomicControlLayout.ahk',
    '#Include src\Config\IniFieldCodec.ahk',
    '#Include src\Config\DisplayConfigCodec.ahk',
    '#Include src\Config\MaintenanceConfigCodec.ahk',
    '#Include src\Config\AppConfigSnapshotService.ahk',
    '#Include src\Config\RuntimeSettingsService.ahk',
    '#Include src\Config\WindowLayoutService.ahk',
    '#Include src\Config\WatchlistPersistenceService.ahk',
    '#Include src\Config\WatchdogConfigRepository.ahk',
    '#Include src\Core\GuardTypes.ahk',
    '#Include src\Core\GuardStateMachine.ahk',
    '#Include src\Core\GuardWorkGate.ahk',
    '#Include src\Core\GuardMutationQueue.ahk',
    '#Include src\Core\WatchdogScheduler.ahk',
    '#Include src\Core\RestartPolicy.ahk',
    '#Include src\Core\TargetSupervisor.ahk',
    '#Include src\Core\TargetSpecs.ahk',
    '#Include src\Core\TargetSpecsService.ahk',
    '#Include src\Core\TargetIdentityService.ahk',
    '#Include src\Core\AppConfigHistoryService.ahk',
    '#Include src\Core\GuardRuntime.ahk',
    '#Include src\Execution\TargetLauncher.ahk',
    '#Include src\Execution\TargetStopper.ahk',
    '#Include src\Maintenance\MaintenanceStateMachine.ahk',
    '#Include src\Maintenance\MaintenanceActorMatcher.ahk',
    '#Include src\Maintenance\MaintenanceSessionCodec.ahk',
    '#Include src\Maintenance\MaintenanceCoordinator.ahk',
    '#Include src\Inspection\ProcessInspector.ahk',
    '#Include src\Inspection\ProcessSnapshotIndex.ahk',
    '#Include src\Inspection\ProcessSnapshotService.ahk',
    '#Include src\Inspection\TargetProbe.ahk',
    '#Include src\Inspection\TargetFileInspector.ahk',
    '#Include src\Inspection\ShortcutResolver.ahk',
    '#Include src\Inspection\ShortcutTargetResolver.ahk',
    '#Include src\Inspection\DirectoryChangeWatcher.ahk',
    '#Include src\Inspection\FileScanService.ahk',
    '#Include src\UI\MainListProjection.ahk',
    'this.processInspector := ProcessInspector()',
    'this.targetFileInspector := TargetFileInspector(',
    'this.shortcutTargetResolver := ShortcutTargetResolver(',
    'this.targetSpecsService := TargetSpecsService(',
    'this.targetIdentityService := TargetIdentityService(',
    'this.appConfigSnapshotService := AppConfigSnapshotService(',
    'this.appConfigHistoryService := AppConfigHistoryService(',
    'this.runtimeSettingsService := RuntimeSettingsService(',
    'this.windowLayoutService := WindowLayoutService(',
    'this.watchlistPersistenceService := WatchlistPersistenceService(',
    'this.fileScanner := FileScanService(',
    'this.processSnapshots := ProcessSnapshotService(',
    'this.guardMutationQueue := GuardMutationQueue(this.guardWorkGate,',
    'App.processInspector.GetCreationIdentity(pid)'
)) {
    if (-not $source.Contains($architectureHook)) {
        $failures.Add("Missing architecture boundary: $architectureHook")
    }
}
if ($source -match '(?m)^class DirectoryChangeWatcher\b' -or
    $directoryChangeWatcherSource -notmatch 'class DirectoryChangeWatcher' -or
    $directoryChangeWatcherSource -notmatch '__Delete\(\)[\s\S]{0,80}this\.Close\(\)' -or
    $directoryChangeWatcherSource -notmatch 'Poll\(\)[\s\S]{0,900}finally this\.RearmOrClose\(\)' -or
    $directoryChangeWatcherSource -notmatch 'ParseNotificationBuffer\(notificationBuffer, bytesReturned\)') {
    $failures.Add('Directory change watching must be an owned, rearmed inspection service')
}
if ($source -match '(?m)^(?:GetTargetFileFingerprint|IsTargetFileReady|PathIsWithinRoot)\(' -or
    $targetFileInspectorSource -notmatch 'class TargetFileInspector' -or
    $targetFileInspectorSource -notmatch 'GetFingerprint\(path\)' -or
    $targetFileInspectorSource -notmatch 'IsReady\(path\)' -or
    $targetFileInspectorSource -notmatch 'IsWithinRoot\(candidatePath, rootPath\)' -or
    $source -notmatch 'GetFingerprint:\s*ObjBindMethod\(this\.targetFileInspector,' -or
    $source -notmatch 'IsTargetFileReady:\s*ObjBindMethod\(this\.targetFileInspector,') {
    $failures.Add('Target file fingerprinting, readiness, and root checks must use the owned inspection service')
}
if ($source -match '(?m)^(?:IsSupportedMonitorFile|AddScannedFile|ScanDirectoryToDepth|ScanDirectoryRecursive|WriteFileScanWorker|StartFileScanWorker|StopFileScanWorker|ReadFileScanResult)\(' -or
    $fileScanServiceSource -notmatch 'class FileScanService' -or
    $source -notmatch 'App\.fileScanner\.WriteWorkerFile\(' -or
    $source -notmatch 'App\.fileScanner\.Start\(' -or
    $source -notmatch 'App\.fileScanner\.Stop\(' -or
    $source -notmatch 'App\.fileScanner\.ReadResult\(' -or
    $source -notmatch 'App\.fileScanner\.IsSupported\(') {
    $failures.Add('File scanning must be owned by the injected FileScanService boundary')
}
if ($coreTestRunnerSource -notmatch '\$configurationHashBefore\s*=\s*if' -or
    $coreTestRunnerSource -notmatch 'finally\s*\{[\s\S]{0,500}\$configurationHashAfter\s*=\s*if[\s\S]{0,500}\$configurationHashAfter\s*-ne\s*\$configurationHashBefore') {
    $failures.Add('Core test execution must prove that watchdog.ini is unchanged on every exit path')
}
foreach ($targetSpecHook in @(
    'class TargetLaunchKind',
    'class TargetProbeKind',
    'class LaunchSpec',
    'class ProbeSpec',
    'class TargetSpecs',
    'class TargetSpecFactory',
    'UsesShortcutEntry',
    'CreatePathProbe(targetPath, reason := "")'
)) {
    if (-not $targetSpecsSource.Contains($targetSpecHook)) {
        $failures.Add("Missing target specification module hook: $targetSpecHook")
    }
}
if ($targetSpecsServiceSource -notmatch 'class TargetSpecsService' -or
    $targetSpecsServiceSource -match '\bApp\.' -or
    $targetSpecsServiceSource -notmatch 'Fingerprint\(path, stateObj := ""\)' -or
    $targetSpecsServiceSource -notmatch 'Build\(path, stateObj := ""\)' -or
    $targetSpecsServiceSource -notmatch 'Get\(path, stateObj := "", forceRefresh := false\)' -or
    $source -notmatch 'this\.targetSpecsService\s*:=\s*TargetSpecsService\(' -or
    $source -notmatch 'GetTargetSpecs:\s*ObjBindMethod\(this\.targetSpecsService, "Get"\)') {
    $failures.Add('Target specification caching and construction must use the owned service')
}
foreach ($legacyTargetSpecsFunction in @(
    'GetTargetStateValue',
    'GetTargetSpecsFingerprint',
    'BuildTargetSpecs',
    'GetTargetSpecs'
)) {
    if ($source -match "(?m)^$legacyTargetSpecsFunction\(") {
        $failures.Add("Legacy main-script target specification function remains: $legacyTargetSpecsFunction")
    }
}
if ($targetSpecsServiceSource -match 'ShortcutResolveCheckedTicks') {
    $failures.Add('Shortcut inspection timestamps must not invalidate unchanged target specification caches')
}
if ($targetIdentityServiceSource -notmatch 'class TargetIdentityService' -or
    $targetIdentityServiceSource -match '\bApp\.' -or
    $targetIdentityServiceSource -notmatch '__New\(runtime, callbacks\)' -or
    $targetIdentityServiceSource -notmatch 'RefreshShortcut\(path, stateObj, force := false\)' -or
    $targetIdentityServiceSource -notmatch 'FindConflict\(candidateTarget, excludedPath := ""\)' -or
    $source -notmatch 'this\.targetIdentityService\s*:=\s*TargetIdentityService\(' -or
    $source -notmatch 'RefreshShortcutIdentity:\s*ObjBindMethod\([\s\S]{0,100}targetIdentityService, "RefreshShortcut"\)' -or
    $source -notmatch 'TargetReferenceExists:\s*ObjBindMethod\(this\.targetIdentityService,') {
    $failures.Add('Target identity conflict detection and shortcut refresh must use the owned service')
}
foreach ($legacyTargetIdentityFunction in @(
    'GetMonitoredTargetPath',
    'GetStateIdentityTarget',
    'FindIdentityConflict',
    'RefreshShortcutIdentity',
    'TargetReferenceExists',
    'GetMaintenanceSubjectPath'
)) {
    if ($source -match "(?m)^$legacyTargetIdentityFunction\(") {
        $failures.Add("Legacy main-script target identity function remains: $legacyTargetIdentityFunction")
    }
}
if ($targetIdentityServiceSource -notmatch 'ResolveEffective\([\s\S]{0,600}if \(freshTarget == "" \|\| !this\.IsCurrent' -or
    $targetIdentityServiceSource -notmatch 'conflictPath\s*:=\s*this\.FindConflict\([\s\S]{0,2500}stateObj\.ResolvedTarget\s*:=\s*freshTarget') {
    $failures.Add('Shortcut refresh must revalidate controller ownership and reject conflicts before mutation')
}
foreach ($shortcutHook in @(
    'class ShortcutDescriptor',
    'class ShortcutResolver',
    'static Read(path)',
    'FileGetShortcut(path,'
)) {
    if (-not $shortcutResolverSource.Contains($shortcutHook)) {
        $failures.Add("Missing shortcut resolver module hook: $shortcutHook")
    }
}
if ($shortcutTargetResolverSource -notmatch 'class ShortcutTargetResolver' -or
    $shortcutTargetResolverSource -match '\bApp\.' -or
    $shortcutTargetResolverSource -notmatch '__New\(processSnapshots, callbacks\)' -or
    $shortcutTargetResolverSource -notmatch 'MaximumCandidateCount\s*:=\s*200' -or
    $shortcutTargetResolverSource -notmatch 'ResolveEffective\(path, allowMissing := false,' -or
    $shortcutTargetResolverSource -notmatch 'ResolveForState\(path, savedTarget := "",' -or
    $source -notmatch 'this\.shortcutTargetResolver\s*:=\s*ShortcutTargetResolver\(') {
    $failures.Add('Shortcut target discovery must use the owned resolver with explicit snapshot and path dependencies')
}
$legacyShortcutTargetFunctions = @(
    'ReadShortcutData',
    'GetShortcutWorkingDirectory',
    'GetShortcutTargetPath',
    'IsValidExecutableFile',
    'IsUsableShortcutTarget',
    'IsGenericLauncherTarget',
    'ExtractShortcutArgumentTarget',
    'IsPotentialShortcutProcessTarget',
    'ResolveMsiShortcutTarget',
    'GetExecutableVersionValues',
    'NormalizeIdentityText',
    'ScoreIdentityText',
    'IsObservedProcessPath',
    'ScoreShortcutExecutableCandidate',
    'FindShortcutExecutableCandidate',
    'GetShortcutEffectiveTargetPath',
    'ResolveShortcutTargetForState'
)
foreach ($legacyShortcutTargetFunction in $legacyShortcutTargetFunctions) {
    if ($source -match "(?m)^$legacyShortcutTargetFunction\(") {
        $failures.Add("Legacy main-script shortcut target function remains: $legacyShortcutTargetFunction")
    }
}
foreach ($guardTypeHook in @(
    'class ProcessObservationStatus',
    'static Unknown := "Unknown"',
    'class ProcessObservation',
    'class GuardPhase'
)) {
    if (-not $guardTypesSource.Contains($guardTypeHook)) {
        $failures.Add("Missing guard type module hook: $guardTypeHook")
    }
}
foreach ($stateMachineHook in @(
    'class GuardStateMachine',
    'static ValidPhases := Map(',
    'Transition(nextPhase)',
    'throw ValueError('
)) {
    if (-not $guardStateMachineSource.Contains($stateMachineHook)) {
        $failures.Add("Missing guard state machine hook: $stateMachineHook")
    }
}
foreach ($supervisorHook in @(
    'class TargetScheduledTask',
    'class TargetSupervisor',
    'CancelScheduledTasks(invalidateGeneration := true)',
    'ScheduleRestart(path, restartCallback, delayMs, nowTicks,',
    'ScheduleVerification(path, verifyCallback, delayMs)',
    'IsScheduledTaskCurrent(task, expectedKind)',
    'ConsumeScheduledTask(task, expectedKind)',
    'restartCallback.Bind(path, this, task)',
    'verifyCallback.Bind(path, this, task)'
)) {
    if (-not $targetSupervisorSource.Contains($supervisorHook)) {
        $failures.Add("Missing target supervisor hook: $supervisorHook")
    }
}
foreach ($schedulerHook in @(
    'class WatchdogScheduler',
    'Schedule(task, taskCallback, dueTicks)',
    'RunDue(nowTicks := "")',
    'HeapPush(item)',
    'HeapPop()',
    'IsEarlier(first, second)',
    'this.TimerCallback := ObjBindMethod(this, "OnTimer")'
)) {
    if (-not $schedulerSource.Contains($schedulerHook)) {
        $failures.Add("Missing watchdog scheduler hook: $schedulerHook")
    }
}
foreach ($restartPolicyHook in @(
    'class RestartPolicy',
    'NextAfterFailure(failureCount, retryDelays)',
    'CoolingDown: true'
)) {
    if (-not $restartPolicySource.Contains($restartPolicyHook)) {
        $failures.Add("Missing restart policy hook: $restartPolicyHook")
    }
}
foreach ($launcherHook in @(
    'class TargetLaunchInvocation',
    'class TargetLaunchResult',
    'class TargetLauncher',
    'BuildInvocation(spec, ahkPath := "", isCompiled := false,',
    'Launch(spec, ahkPath := "", isCompiled := false,',
    'spec.RuntimePath',
    'spec.RuntimeArguments',
    'ExpandEnvironmentValue(variableValue)',
    'ParseEnvironment(environmentText)',
    'Run(invocation.Command, invocation.WorkingDirectory,',
    'kernel32\SetEnvironmentVariableW'
)) {
    if (-not $targetLauncherSource.Contains($launcherHook)) {
        $failures.Add("Missing target launcher hook: $launcherHook")
    }
}
if ($targetLauncherSource -notmatch 'if\s+!customEnvironment\.Count[\s\S]{0,220}Run\(' -or
    $targetLauncherSource -notmatch 'previousCritical\s*:=\s*A_IsCritical[\s\S]{0,100}Critical\("On"\)[\s\S]{0,1100}Critical\(previousCritical \? previousCritical : "Off"\)' -or
    $targetLauncherSource -notmatch 'CaptureEnvironment\(variableName\)[\s\S]{0,700}GetEnvironmentVariableW') {
    $failures.Add('Custom launch environments must be isolated and restored without slowing ordinary launches')
}
foreach ($everythingRuntimeHook in @(
    'class EverythingRuntimeService',
    'static DownloadUrl := "https://www.voidtools.com/downloads/"',
    'FindExecutable(forceRefresh := false)',
    'StartSilently()',
    '"-startup", "Hide"',
    'AddRegistryCandidates(candidates)',
    'AddKnownPathCandidates(candidates)',
    'AddEnvironmentPathCandidates(candidates)',
    'AddShortcutCandidates(candidates)'
)) {
    if (-not $everythingRuntimeServiceSource.Contains($everythingRuntimeHook)) {
        $failures.Add("Everything runtime discovery lost a bounded startup hook: $everythingRuntimeHook")
    }
}
if (-not $mainSource.Contains('#Include src\Execution\EverythingRuntimeService.ahk') -or
    $source -notmatch 'everythingRuntimeService\s*:=\s*EverythingRuntimeService\(\)[\s\S]{0,26000}everythingRuntimeService\.StartSilently\(\)' -or
    $source -notmatch 'EverythingRuntimeService\.DownloadUrl') {
    $failures.Add('Application search must use the shared Everything discovery service and official download URL')
}
foreach ($stopperHook in @(
    'class TargetStopStage',
    'class TargetStopResult',
    'class TargetStopper',
    'Stop(pid, gracefulWaitSeconds, ctrlCWaitSeconds, allowForceTerminate,',
    'WaitUntilStopped(pid, timeoutSeconds, expectedCreationIdentity := "")',
    'return !ProcessWaitClose(pid, Max(0, timeoutSeconds))',
    'RequestWindowClose(pid, expectedCreationIdentity := "")',
    'TerminateVerifiedProcess(pid, expectedCreationIdentity,'
)) {
    if (-not $targetStopperSource.Contains($stopperHook)) {
        $failures.Add("Missing target stopper hook: $stopperHook")
    }
}
foreach ($executionOwnerHook in @(
    'this.targetLauncher := TargetLauncher()',
    'this.targetStopper := TargetStopper(ObjBindMethod('
)) {
    if (-not $source.Contains($executionOwnerHook)) {
        $failures.Add("ApplicationState must own execution service: $executionOwnerHook")
    }
}
foreach ($maintenanceStateHook in @(
    'class MaintenancePhase',
    'class MaintenanceStateMachine',
    'static AllowedTransitions := Map(',
    'Transition(nextPhase)',
    'Restore(restoredPhase)',
    'IsBlocking()'
)) {
    if (-not $maintenanceStateMachineSource.Contains($maintenanceStateHook)) {
        $failures.Add("Missing maintenance state machine hook: $maintenanceStateHook")
    }
}
foreach ($maintenanceActorHook in @(
    'class MaintenanceActorIdentity',
    'this.Key := this.PID ":" this.CreationIdentity',
    'class MaintenanceActorMatchResult',
    'class MaintenanceActorMatcher',
    'CreateIdentity(processInfo, rootPath, processMap := "")',
    'IsIdentityAlive(identity)',
    'IsDescendantOfTarget(processInfo, targetPid, targetCreationIdentity,',
    'NormalizeLearnedSignature(signature, rootPath := "")',
    'return "P:" executablePath "|R:" rootPath',
    'BuildParentChain(processInfo, processMap := "")'
)) {
    if (-not $maintenanceActorMatcherSource.Contains($maintenanceActorHook)) {
        $failures.Add("Missing maintenance actor matcher hook: $maintenanceActorHook")
    }
}
if ($maintenanceActorMatcherSource -notmatch 'NormalizeLearnedSignature\(signature, rootPath := ""\)[\s\S]{0,900}!this\.PathIsWithinRoot\(executablePath, signatureRoot\)' -or
    $maintenanceActorMatcherSource -notmatch 'BuildLearningSignature\(processInfo, rootPath\)[\s\S]{0,500}!this\.CanonicalPathIsWithinRoot\(executablePath, rootPath\)') {
    $failures.Add('Persistent maintenance actors must be scoped to executables inside their installation root')
}
if (-not $maintenanceActorMatcherSource.Contains('CreateMatchContext(') -or
    -not $maintenanceActorMatcherSource.Contains('MatchPrepared(processInfo, context)') -or
    $maintenanceActorMatcherSource -notmatch 'CanonicalCommandPaths\(processInfo\)[\s\S]{0,180}maintenanceCommandPaths' -or
    $maintenanceCoordinatorSource -notmatch 'actorCandidates\s*:=\s*maintenanceBlocking[\s\S]{0,220}\?\s*snapshot\s*:\s*commonActorCandidates') {
    $failures.Add('Maintenance actor matching must cache process parsing and scope full snapshots to each confirmed target')
}
if ($source -notmatch 'this\.maintenanceActorMatcher\s*:=\s*MaintenanceActorMatcher\([\s\S]{0,160}ObjBindMethod\(this\.processInspector,\s*"GetCreationIdentity"\)') {
    $failures.Add('Maintenance actor identity checks must use the shared ProcessInspector')
}
foreach ($maintenanceCoordinatorHook in @(
    'class MaintenanceCoordinator',
    'Initialize()',
    'StartTimers()',
    'Shutdown(*)',
    'ProcessTick()',
    'EventTick()',
    'BeginArbitration(path, stateObj)',
    'Enter(path, stateObj, reason := "")',
    'Advance(path, stateObj)',
    'Complete(path, stateObj)',
    'ResetSession(path, stateObj, saveJournal := true)',
    'CanSafelyLaunch(path, stateObj, &reason := "")',
    'this.Watchers := Map()',
    'this.PendingCommands := []'
)) {
    if (-not $maintenanceCoordinatorSource.Contains($maintenanceCoordinatorHook)) {
        $failures.Add("Missing maintenance coordinator hook: $maintenanceCoordinatorHook")
    }
}
if ($maintenanceCoordinatorSource -match '\bApp\.') {
    $failures.Add('MaintenanceCoordinator must not recover dependencies from global App state')
}
if ($source -notmatch 'this\.maintenanceCoordinator\s*:=\s*MaintenanceCoordinator\(this,' -or
    $source -notmatch 'this\.processSnapshots\.SnapshotPublishedCallback\s*:=\s*ObjBindMethod\([\s\S]{0,100}this,\s*"OnProcessSnapshotPublished"\)' -or
    $source -notmatch 'OnProcessSnapshotPublished\(snapshot, snapshotIndex\)[\s\S]{0,1800}maintenanceCoordinator[\s\S]{0,100}OnSnapshotPublished[\s\S]{0,500}guardRuntime\.OnSnapshotPublished') {
    $failures.Add('ApplicationState must own and connect one maintenance coordinator')
}
foreach ($legacyMaintenanceOwner in @(
    'this\.processBaselineReady',
    'this\.maintenanceSnapshotSupportsCommandLine',
    'this\.processLoopBusy',
    'this\.maintenanceLoopBusy',
    'this\.pendingMaintenanceCommands',
    'this\.maintenanceInitialized',
    'this\.maintenanceWatchers',
    '(?m)^InitializeMaintenanceSubsystem\(',
    '(?m)^CleanupMaintenanceSubsystem\(',
    '(?m)^MaintenanceProcessLoop\(',
    '(?m)^MaintenanceEventLoop\(',
    '(?m)^BeginMaintenanceArbitration\(',
    '(?m)^EnterMaintenance\(',
    '(?m)^AdvanceMaintenanceState\(',
    '(?m)^CompleteMaintenance\(',
    '(?m)^ResetMaintenanceSession\('
)) {
    if ($source -match $legacyMaintenanceOwner) {
        $failures.Add("Legacy maintenance coordinator ownership remains: $legacyMaintenanceOwner")
    }
}
if ($guardWorkGateSource -notmatch 'class GuardWorkGate' -or
    $guardWorkGateSource -notmatch 'TryEnter\(owner := "Unspecified"\)[\s\S]{0,1200}Critical\("On"\)[\s\S]{0,1200}this\.Busy\s*:=\s*true' -or
    $guardWorkGateSource -notmatch 'finally[\s\S]{0,100}Critical\(previousCritical \? previousCritical : "Off"\)' -or
    $guardWorkGateSource -notmatch 'BuildDiagnosticText\(prefix := "GuardWorkGate"\)' -or
    $guardWorkGateSource -notmatch 'this\.ContentionCount\+\+' -or
    $source -notmatch 'this\.guardWorkGate\s*:=\s*GuardWorkGate\(GetTickCount64, LogMsg\)' -or
    $guardRuntimeSource -notmatch 'MonitorTick\(\)[\s\S]{0,220}this\.Runtime\.guardWorkGate\.TryEnter\("GuardMonitorTick"\)' -or
    $guardRuntimeSource -notmatch 'MonitorTick\(\)[\s\S]{0,18000}this\.Runtime\.guardWorkGate\.Leave\(\)' -or
    [regex]::Matches($maintenanceCoordinatorSource,
        'this\.Runtime\.guardWorkGate\.TryEnter\("Maintenance[^"\r\n]+"\)').Count -lt 2 -or
    [regex]::Matches($maintenanceCoordinatorSource,
        'this\.Runtime\.guardWorkGate\.Leave\(\)').Count -lt 2) {
    $failures.Add('Main monitoring and both maintenance loops must share the explicit guard work gate')
}
if ($applicationTelemetrySource -notmatch 'BuildDiagnosticStateSummary\(\)[\s\S]{0,1800}guardWorkGate\.BuildDiagnosticText\(\)[\s\S]{0,220}processSnapshots\.BuildDiagnosticText\(\)[\s\S]{0,220}fileScanner\.BuildDiagnosticText\(\)') {
    $failures.Add('Runtime diagnostics must include guard-gate and background-worker state')
}
if ($guardMutationQueueSource -notmatch 'class GuardMutationQueue' -or
    $guardMutationQueueSource -notmatch 'Drain\(\*\)[\s\S]{0,700}this\.WorkGate\.TryEnter\("GuardMutationQueue"\)' -or
    $guardMutationQueueSource -notmatch 'finally[\s\S]{0,180}this\.WorkGate\.Leave\(\)' -or
    $guardMutationQueueSource -match '\bSleep\(' -or
    $source -notmatch 'QueueGuardMutation\(ApplyMainListReorder\.Bind\(' -or
    $source -notmatch 'ApplyMainListReorder\(selectedPaths, anchorCandidates,[\s\S]{0,2600}SaveAppsToIni\(\)') {
    $failures.Add('User configuration changes and drag ordering must drain asynchronously through the shared guard work gate')
}
if ($maintenanceCoordinatorSource -match 'TryEnterGuardGate|LeaveGuardGate') {
    $failures.Add('Maintenance coordinator must not wrap the shared guard work gate')
}
if ($maintenanceCoordinatorSource -match 'fallbackDecisionMs|fastDecisionMs' -or
    $maintenanceCoordinatorSource -notmatch 'if \(elapsedMs >= detectionMs\)') {
    $failures.Add('Maintenance arbitration must observe the full configured detection window before resuming ordinary restart')
}
foreach ($guardRuntimeHook in @(
    'class GuardRuntime',
    'Start()',
    'RestartMonitorTimer()',
    'Shutdown(*)',
    'MonitorTick()',
    'IsSupervisorCurrent(path, expectedSupervisor,',
    'IsScheduledTaskCurrent(path, expectedSupervisor, task,',
    'ScheduleRestart(path, delayMs, phase := "",',
    'ScheduleRestartFor(path, expectedSupervisor, delayMs,',
    'ScheduleVerificationFor(path, expectedSupervisor, delayMs)',
    'ScheduleVerification(path, delayMs, expectedSupervisor := "")',
    'OnSnapshotPublished(snapshot, snapshotIndex)',
    'BeginSnapshotWait(path, stateObj, purpose)',
    'ScheduleRestartPreservingSnapshot(path, stateObj, delayMs)',
    'Restart(path, expectedSupervisor := "", scheduledTask := "")',
    'RestartCore(path, expectedSupervisor := "", scheduledTask := "")',
    'Verify(path, expectedSupervisor := "", scheduledTask := "")',
    'VerifyCore(path, expectedSupervisor := "", scheduledTask := "")',
    'ProcessRestartFailure(path, targetName, maxAttempts, errorMessage,',
    'this.MonitorTimer := ObjBindMethod(this, "MonitorTick")'
)) {
    if (-not $guardRuntimeSource.Contains($guardRuntimeHook)) {
        $failures.Add("Missing guard runtime hook: $guardRuntimeHook")
    }
}
if ($guardRuntimeSource -notmatch 'Restart\(path,[\s\S]{0,900}guardWorkGate\.TryEnter\("GuardRestart"\)[\s\S]{0,800}ScheduleRestartPreservingSnapshot\(path,[\s\S]{0,180}expectedSupervisor, 100\)[\s\S]{0,700}RestartCore\(' -or
    $guardRuntimeSource -notmatch 'Verify\(path,[\s\S]{0,900}guardWorkGate\.TryEnter\("GuardVerify"\)[\s\S]{0,600}ScheduleVerificationFor\(path, expectedSupervisor, 100\)[\s\S]{0,600}VerifyCore\(' -or
    $guardRuntimeSource -notmatch 'MonitorTick\(\)[\s\S]{0,9000}this\.RestartCore\(path\)') {
    $failures.Add('Restart and verification must participate in the shared guard work gate')
}
if ($guardRuntimeSource -notmatch '(?ms)^    MonitorTick\(\).*?^        } catch as monitorError \{.*?^        } finally \{.*?guardWorkGate\.Leave\(\)' -or
    $maintenanceCoordinatorSource -notmatch '(?ms)^    ProcessTick\(\).*?^        } catch as processError \{.*?^        } finally \{.*?guardWorkGate\.Leave\(\)' -or
    $maintenanceCoordinatorSource -notmatch '(?ms)^    EventTick\(\).*?^        } catch as eventError \{.*?^        } finally \{.*?guardWorkGate\.Leave\(\)') {
    $failures.Add('Background guard loops must log callback failures and release the shared work gate')
}
if ($guardRuntimeSource -notmatch 'ScheduleRestart\(path, delayMs, phase := "",[\s\S]{0,800}IsBlocking\(stateObj\)[\s\S]{0,180}stateObj\.CancelScheduledTasks\(\)' -or
    $guardRuntimeSource -notmatch 'ScheduleVerification\(path, delayMs, expectedSupervisor := ""\)[\s\S]{0,800}IsBlocking\(stateObj\)[\s\S]{0,180}stateObj\.CancelScheduledTasks\(\)') {
    $failures.Add('Maintenance blocking must invalidate ordinary scheduled task slots')
}
if ($guardRuntimeSource -match '\bApp\.') {
    $failures.Add('GuardRuntime must not recover dependencies from global App state')
}
if ($guardRuntimeSource -notmatch 'ScheduleRestart\(path,[\s\S]{0,900}if\s+!stateObj\.Enabled[\s\S]{0,120}return\s+""' -or
    $guardRuntimeSource -notmatch 'ScheduleVerification\(path,[\s\S]{0,900}if\s+!stateObj\.Enabled[\s\S]{0,120}return\s+""') {
    $failures.Add('Paused supervisors must be rejected by restart and verification scheduling')
}
if ($source -notmatch 'this\.guardRuntime\s*:=\s*GuardRuntime\(this,' -or
    $source -notmatch 'this\.scheduler\.ErrorHandler\s*:=\s*ObjBindMethod\(this\.guardRuntime,\s*"HandleTaskError"\)' -or
    $source -notmatch 'this\.maintenanceCoordinator\.Callbacks\.ScheduleRestart\s*:=\s*ObjBindMethod\([\s\S]{0,100}this\.guardRuntime,\s*"ScheduleRestartFor"\)') {
    $failures.Add('ApplicationState must own and connect one guard runtime')
}
foreach ($legacyGuardRuntimeEntry in @(
    '(?m)^MonitorLoop\(',
    '(?m)^IsTargetSupervisorCurrent\(',
    '(?m)^IsCurrentTargetScheduledTask\(',
    '(?m)^ScheduleRestart\(',
    '(?m)^ScheduleVerify\(',
    '(?m)^CanTargetOperationContinue\(',
    '(?m)^DoRestart\(',
    '(?m)^ProcessRestartFailure\(',
    '(?m)^VerifyStart\(',
    'SetTimer\(MonitorLoop'
)) {
    if ($source -match $legacyGuardRuntimeEntry) {
        $failures.Add("Legacy main guard runtime entry remains: $legacyGuardRuntimeEntry")
    }
}
if ($source -notmatch
        'guardRuntimeStarted\s*:=\s*App\.guardRuntime\.Start\(\)' -or
    $source -notmatch 'App\.guardRuntime\.RestartMonitorTimer\(\)') {
    $failures.Add('Guard runtime must own monitor startup, shutdown and interval changes')
}
if ($guardRuntimeSource -notmatch
        'observation\s*:=\s*this\.Callbacks\.ObserveTarget\.Call\(path,[\s\S]{0,320}if\s+!this\.IsSupervisorCurrent\(path,\s*stateObj,\s*observationGeneration\)' -or
    $guardRuntimeSource -notmatch
        'targetObservation\s*:=\s*hasLiveIdentity[\s\S]{0,320}this\.Callbacks\.ObserveTarget\.Call\(path,[\s\S]{0,320}if\s+!this\.IsSupervisorCurrent\(path,\s*stateObj,\s*observationGeneration\)' -or
    $guardRuntimeSource -notmatch
        'targetObservation\s*:=\s*this\.Callbacks\.ObserveTarget\.Call\([\s\S]{0,320}if\s+!this\.IsSupervisorCurrent\(path,\s*stateObj,\s*observationGeneration\)') {
    $failures.Add('Monitor observations must revalidate controller ownership before mutation')
}
if ($guardRuntimeSource -match
        'CachedNativeFallbackIndex|ObserveTargetWithNativeFallback') {
    $failures.Add('Published WMI Unknown results must not trigger a second speculative native snapshot')
}
if ($targetSupervisorSource -notmatch 'this\.MaintenanceStateMachine\s*:=\s*MaintenanceStateMachine\(\)[\s\S]{0,2600}MaintenanceMode\s*\{[\s\S]{0,220}MaintenanceStateMachine\.Transition\(value\)') {
    $failures.Add('TargetSupervisor must own maintenance phase transitions')
}
foreach ($legacyMaintenanceSymbol in @(
    'KnownActorPids',
    'TransientActorPids',
    '"N:"',
    'MaintenanceMode\s*(?:==|!=|:=)\s*"(?:Normal|Arbitrating|Updating|Stabilizing|Recovering|TimedOut)"'
)) {
    if ($source -match $legacyMaintenanceSymbol -or
        $maintenanceActorMatcherSource -match $legacyMaintenanceSymbol) {
        $failures.Add("Legacy maintenance identity or phase logic remains: $legacyMaintenanceSymbol")
    }
}
foreach ($maintenanceIntegrationPattern in @(
    'matcher\.MatchPrepared\(processInfo,',
    'activeKnown\[identityKey\]\s*:=\s*actorRecord',
    'activeTransient\[identityKey\]\s*:=\s*actorRecord',
    'HasActiveActors\(stateObj\)[\s\S]{0,900}GetIdentityStatus\(',
    'Normalize\(config, path\)[\s\S]{0,1800}NormalizeActors\(config,'
)) {
    if ($source -notmatch $maintenanceIntegrationPattern -and
        $maintenanceCoordinatorSource -notmatch $maintenanceIntegrationPattern -and
        $maintenanceConfigCodecSource -notmatch $maintenanceIntegrationPattern) {
        $failures.Add("Missing creation-aware maintenance integration: $maintenanceIntegrationPattern")
    }
}
if ($maintenanceCoordinatorSource -notmatch 'EnsureWatcher\(path, stateObj\)[\s\S]{0,500}Runtime\.appStates\[path\]\s*!=\s*stateObj' -or
    $maintenanceCoordinatorSource -notmatch 'CloseWatcher\(stateObj\)[\s\S]{0,700}entry\.subscribers\[path\]\s*==\s*stateObj[\s\S]{0,100}entry\.subscribers\.Delete\(path\)') {
    $failures.Add('Maintenance watcher subscriptions must validate supervisor ownership')
}
if ($maintenanceCoordinatorSource -notmatch 'EventTick\(\)[\s\S]{0,120}this\.Stopped\s*\|\|\s*!this\.Initialized' -or
    $maintenanceCoordinatorSource -notmatch 'catch\s+as\s+watcherError[\s\S]{0,180}entry\.watcher\.Close\(\)[\s\S]{0,220}continue') {
    $failures.Add('Maintenance watcher failures must be isolated and stopped callbacks must not reopen watchers')
}
if ($maintenanceCoordinatorSource -notmatch 'EventTick\(\)[\s\S]{0,1800}fingerprintRequests[\s\S]{0,5000}forcedFingerprintCheck' -or
    $maintenanceCoordinatorSource -notmatch 'IsRelevantFootprintChange\(path, stateObj, relativePath,[\s\S]{0,260}FootprintChangeRequiresFingerprint' -or
    $maintenanceCoordinatorSource -notmatch 'FootprintChangeRequiresFingerprint\(path, stateObj, relativePath,[\s\S]{0,240}relativePath == "\*"' -or
    $maintenanceCoordinatorSource -notmatch '!InStr\(relativePath, "\\"\) && !InStr\(subjectRelative, "\\"\)') {
    $failures.Add('Ambiguous maintenance file notifications must require a target fingerprint check outside active upgrade sessions')
}
if ($targetLauncherSource -match '(?i)BuildInvocation\(launchSpec') {
    $failures.Add('TargetLauncher parameter names must not shadow the LaunchSpec class')
}
if ($source -match '(?m)\b(?:EnvSet|SetEnvironmentVariableW?)\s*\(') {
    $failures.Add('Main script must not reimplement target environment overrides')
}
$doRestartMatch = [regex]::Match($guardRuntimeSource,
    '(?ms)^    Restart\(.*?(?=^    ProcessRestartFailure\()')
if (-not $doRestartMatch.Success) {
    $failures.Add('Unable to inspect the restart execution boundary')
}
else {
    $doRestartSource = $doRestartMatch.Value
    if ($doRestartSource -match '(?m)\bRun\s*\(') {
        $failures.Add('DoRestart must delegate process launches to TargetLauncher')
    }
    if ($doRestartSource -match '(?m)\b(?:EnvSet|SetEnvironmentVariableW?)\s*\(') {
        $failures.Add('DoRestart must delegate environment overrides to TargetLauncher')
    }
    if ($doRestartSource -notmatch 'CanOperationContinue\([\s\S]{0,700}this\.Runtime\.targetLauncher\.Launch\([\s\S]{0,700}CanOperationContinue\(') {
        $failures.Add('Target launch must validate controller generation immediately before and after execution')
    }
}
if ($source -notmatch 'StopTargetProcess\(pid, expectedCreationIdentity := ""\)[\s\S]{0,500}App\.targetStopper\.Stop\(') {
    $failures.Add('Process termination must delegate to TargetStopper')
}
$removedExecutionModule = Join-Path $projectRoot `
    ('src\Execution\Service' + 'Controller.ahk')
if (Test-Path -LiteralPath $removedExecutionModule) {
    $failures.Add('Removed Windows system-service execution module still exists')
}
$removedWindowsServiceMarkers = @(
    ('Service' + 'Controller'),
    ('Service' + ':'),
    ('Windows ' + [char]0x670D + [char]0x52A1),
    ('ResumePaused' + 'Services'),
    ('ServicePending' + 'TimeoutSeconds'),
    ('QueryService' + 'State'),
    ('StartWindows' + 'Service'),
    ('StopWindows' + 'Service'),
    ('EnumerateWindows' + 'Services'),
    ('TargetLaunchKind.' + 'Service'),
    ('TargetProbeKind.' + 'Service')
)
$removedFeatureSurface = $source + "`n" + $allModuleSource + "`n" +
    $readmeSource + "`n" + $iniText
foreach ($removedMarker in $removedWindowsServiceMarkers) {
    if ($removedFeatureSurface.Contains($removedMarker)) {
        $failures.Add("Removed Windows system-service marker remains: $removedMarker")
    }
}
if ($targetSupervisorSource -match 'SetTimer\s*\(') {
    $failures.Add('TargetSupervisor must submit tasks to the shared scheduler')
}
if ([regex]::Matches($schedulerSource, 'Critical\("On"\)').Count -lt 5 -or
    $schedulerSource -notmatch 'HeapPush\(item\)[\s\S]{0,180}finally[\s\S]{0,120}Critical\(previousCritical' -or
    $schedulerSource -notmatch 'item\s*:=\s*this\.HeapPop\(\)[\s\S]{0,180}finally[\s\S]{0,120}Critical\(previousCritical') {
    $failures.Add('Scheduler heap and timer mutations must use short critical sections')
}
if ($source -notmatch 'this\.scheduler\s*:=\s*WatchdogScheduler\(') {
    $failures.Add('ApplicationState must own one shared watchdog scheduler')
}
if ($guardRuntimeSource -notmatch 'ProcessRestartFailure\(path,[\s\S]{0,1400}RestartPolicy\.NextAfterFailure[\s\S]{0,700}GuardPhase\.CoolingDown') {
    $failures.Add('Exhausted restart sequences must enter scheduled cooldown recovery')
}
if ($source -match 'stateObj\.FailCount\s*<\s*maxAttempts') {
    $failures.Add('Restart exhaustion must not permanently abandon a target')
}
if ($guardRuntimeSource -notmatch 'Shutdown\(\*\)[\s\S]{0,500}this\.Runtime\.scheduler\.Shutdown\(\)') {
    $failures.Add('Application shutdown must stop the shared scheduler')
}
if ($maintenanceCoordinatorSource -notmatch 'QueueCommand\(command\)[\s\S]{0,500}guardWorkGate\.TryEnter\("MaintenanceCommand"\)[\s\S]{0,500}guardWorkGate\.Leave\(\)' -or
    $maintenanceCoordinatorSource -notmatch 'EventTick\(\)[\s\S]{0,500}DrainPendingCommands\(\)') {
    $failures.Add('Explicit maintenance commands must serialize through the shared guard work gate')
}
if ($maintenanceCoordinatorSource -notmatch 'EndExplicit\(path\)[\s\S]{0,500}MaintenancePhase\.TimedOut[\s\S]{0,160}ResetSession\(path, stateObj, false\)[\s\S]{0,220}MaintenancePhase\.Stabilizing' -or
    $maintenanceStateMachineSource -notmatch 'MaintenancePhase\.Normal, Map\([\s\S]{0,240}MaintenancePhase\.Stabilizing, true') {
    $failures.Add('Explicit maintenance timeout must recover into stabilization')
}
if ($maintenanceCoordinatorSource -notmatch 'RestoreSessions\(\)[\s\S]{0,2800}RestoreMaintenanceMode\(MaintenancePhase\.TimedOut\)[\s\S]{0,260}RestoreMaintenanceMode\(MaintenancePhase\.Recovering\)' -or
    $targetSupervisorSource -notmatch 'RestoreMaintenanceMode\(restoredPhase\)[\s\S]{0,140}MaintenanceStateMachine\.Restore\(restoredPhase\)' -or
    $maintenanceStateMachineSource -match 'MaintenancePhase\.Normal, Map\([\s\S]{0,300}MaintenancePhase\.TimedOut, true') {
    $failures.Add('Persisted maintenance sessions must restore through an explicit boundary without weakening runtime transitions')
}
if ($maintenanceCoordinatorSource -notmatch 'SaveJournal\(\)[\s\S]{0,500}previousCritical\s*:=\s*A_IsCritical[\s\S]{0,900}Critical\(previousCritical') {
    $failures.Add('Maintenance journal transactions must restore caller critical state')
}
if ($maintenanceCoordinatorSource -notmatch 'this\.JournalDirty\s*:=\s*true[\s\S]{0,300}this\.JournalRetryDelayMs\s*:=\s*Min\(' -or
    $maintenanceCoordinatorSource -notmatch 'EventTick\(\)[\s\S]{0,8000}this\.JournalDirty[\s\S]{0,180}this\.SaveJournal\(\)') {
    $failures.Add('Dirty maintenance journals must be retried by the existing event loop')
}
if ($maintenanceCoordinatorSource -notmatch 'StartTimers\(\)[\s\S]{0,500}eventTimerStarted\s*:=\s*true[\s\S]{0,260}catch[\s\S]{0,220}SetTimer\(this\.EventTimer, 0\)[\s\S]{0,140}SetTimer\(this\.ProcessTimer, 0\)' -or
    $maintenanceCoordinatorSource -notmatch 'Shutdown\(\*\)[\s\S]{0,260}try\s+SetTimer\(this\.EventTimer, 0\)[\s\S]{0,120}try\s+SetTimer\(this\.ProcessTimer, 0\)' -or
    $maintenanceCoordinatorSource -notmatch 'if\s+this\.Initialized\s*\r?\n\s*try\s+this\.SaveJournal\(\)') {
    $failures.Add('Maintenance timer startup and shutdown must be transactional and avoid uninitialized journal writes')
}
if ($source -notmatch 'stateObj\s*:=\s*TargetSupervisor\(\{[\s\S]{0,2200}App\.appStates\[path\]\s*:=\s*stateObj') {
    $failures.Add('Every registered target must be owned by TargetSupervisor')
}
foreach ($legacySupervisorPattern in @(
    'App\.isRestarting',
    'CancelTargetTimers\s*\(',
    '\.RestartTimer',
    '\.VerifyTimer',
    'DoRestart\.Bind\(',
    'VerifyStart\.Bind\(',
    'HasOwnProp\("OneShot"\)',
    'stateObj\s+is\s+TargetSupervisor',
    'obj\s+is\s+TargetSupervisor'
)) {
    if ($source -match $legacySupervisorPattern) {
        $failures.Add("Legacy target task ownership remains: $legacySupervisorPattern")
    }
}
if ($guardRuntimeSource -notmatch 'IsSupervisorCurrent\(path,[\s\S]{0,420}this\.Runtime\.appStates\[path\]\s*==\s*expectedSupervisor') {
    $failures.Add('Scheduled actions must validate the current supervisor instance')
}
if ($guardRuntimeSource -notmatch 'IsScheduledTaskCurrent\(path,[\s\S]{0,300}IsScheduledTaskCurrent\(task, expectedKind\)') {
    $failures.Add('Scheduled actions must validate the current task slot')
}
if ($guardRuntimeSource -notmatch 'UpdateState\(path, expectedSupervisor, statusText, statusKind := ""\)[\s\S]{0,360}IsSupervisorCurrent\(path,\s*expectedSupervisor,[\s\S]{0,80}expectedGeneration\)[\s\S]{0,260}Callbacks\.UpdateState\.Call\(path, statusText,[\s\S]{0,130}expectedSupervisor, expectedGeneration, false, statusKind\)' -or
    $maintenanceCoordinatorSource -notmatch 'UpdateState\(path, expectedSupervisor, statusText, statusKind := ""\)[\s\S]{0,420}Runtime\.appStates\[path\]\s*!=\s*expectedSupervisor[\s\S]{0,280}Callbacks\.UpdateState\.Call\(path, statusText,[\s\S]{0,120}expectedSupervisor, 0, false, statusKind\)' -or
    $source -notmatch 'UpdateState\(updPath, statusStr, expectedState := "",[\s\S]{0,120}expectedGeneration := 0, forceProjection := false, statusKind := ""\)[\s\S]{0,420}stateObj\s*!=\s*expectedState[\s\S]{0,180}stateObj\.Generation\s*!=\s*expectedGeneration') {
    $failures.Add('Background status writes must carry and validate supervisor ownership')
}
if ($guardRuntimeSource -notmatch 'Restart\(path, expectedSupervisor := "", scheduledTask := ""\)') {
    $failures.Add('Restart callback must carry supervisor and task ownership')
}
if ($guardRuntimeSource -notmatch 'Verify\(path, expectedSupervisor := "", scheduledTask := ""\)') {
    $failures.Add('Verification callback must carry supervisor and task ownership')
}
if ($guardRuntimeSource -notmatch 'ProcessRestartFailure\(path, targetName, maxAttempts, errorMessage,\s*expectedSupervisor, expectedGeneration\)') {
    $failures.Add('Restart failure handling must require supervisor and generation ownership')
}
if ($guardRuntimeSource -match 'ProcessRestartFailure\(path,[\s\S]{0,500}this\.Runtime\.appStates\[path\]') {
    $failures.Add('Restart failure handling must not recover ownership from the global target map')
}
if ($guardRuntimeSource -notmatch 'Shutdown\(\*\)[\s\S]{0,400}stateObj\.CancelScheduledTasks\(\)') {
    $failures.Add('Application shutdown must cancel every supervisor task')
}
if ($source -match 'if\s*\([^\r\n]*stateObj\.State[^\r\n]*\)[\s\S]{0,180}(?:ScheduleRestart|Restart)' -or
    $guardRuntimeSource -match 'if\s*\([^\r\n]*stateObj\.State[^\r\n]*\)[\s\S]{0,180}(?:ScheduleRestart|Restart)') {
    $failures.Add('Restart decisions must not branch on presentation text')
}
foreach ($snapshotIndexHook in @(
    'class ProcessSnapshotIndex',
    'ObserveImagePath(targetPath, fallbackContext := "")',
    'ObserveCommandTarget(targetPath, launcherPath := "")',
    'ObserveCustomRuntimeTarget(targetPath, launcherPath)',
    'GetLauncherMatchStatus(processInfo, launcherPath)',
    'CommandLineContainsTarget(commandLine, targetPath)',
    'ObserveExecutableInRoot(rootPath, preferredName := "")',
    'ProcessObservation.Unknown'
)) {
    if (-not $snapshotIndexSource.Contains($snapshotIndexHook)) {
        $failures.Add("Missing process snapshot index module hook: $snapshotIndexHook")
    }
}
foreach ($snapshotServiceHook in @(
    'class ProcessSnapshotService',
    'StoreSnapshot(snapshot, capturedAtTicks := 0,',
    'PublishSnapshot(snapshot, capturedAtTicks := 0,',
    'HasFreshSnapshot(maximumAgeMs := 0, nowTicks := 0)',
    'GetIndex(maximumAgeMs := 0)',
    'Start(requestTicks := 0)',
    'Pump()',
    'RequestFresh()',
    'Stop(waitForExit := true)',
    'NextWorkerOutputPath(nowTicks := 0)',
    'WriteWorkerFile(outputPath, snapshotProvider)',
    'ReadWorkerResult(outputPath, &resultReady := false,',
    'outputText := "SNAPSHOT|" snapshot.Length',
    'this.WorkerCreationIdentity',
    'this.ResetWorkerState(true)',
    'this.WorkerPollTimer := ObjBindMethod(this, "PollWorker")',
    'this.LatestSnapshotRequestTicks',
    'outputPath ".writing"'
)) {
    if (-not $snapshotServiceSource.Contains($snapshotServiceHook)) {
        $failures.Add("Missing process snapshot service hook: $snapshotServiceHook")
    }
}
if ($snapshotServiceSource -notmatch 'ReadWorkerResult\(outputPath,[\s\S]{0,2400}snapshot\.Length\s*!=\s*expectedCount[\s\S]{0,120}resultReady\s*:=\s*true') {
    $failures.Add('Process snapshot results must reject partial or corrupt worker output')
}
foreach ($workerFailureReason in @('LaunchFailed', 'ExitedWithoutResult',
    'TimedOut', 'MalformedResult', 'Cancelled')) {
    if (-not $snapshotServiceSource.Contains('"' + $workerFailureReason + '"') -or
        -not $fileScanServiceSource.Contains('"' + $workerFailureReason + '"')) {
        $failures.Add("Background workers must retain structured failure reason: $workerFailureReason")
    }
}
if (-not $snapshotServiceSource.Contains('BuildDiagnosticText(prefix := "ProcessSnapshotWorker")') -or
    -not $fileScanServiceSource.Contains('BuildDiagnosticText(prefix := "FileScanWorker")') -or
    $fileScanServiceSource -notmatch 'PollContentMatch\(job\)[\s\S]{0,900}FailureReason') {
    $failures.Add('Background worker failures must be exposed through results and diagnostic text')
}
if ($fileScanServiceSource -notmatch 'ParseResultText\(resultText, &truncated := false,[\s\S]{0,1800}paths\.Length\s*!=\s*expectedCount[\s\S]{0,180}resultReady\s*:=\s*true' -or
    $fileScanServiceSource -notmatch 'expectedCount\s*>\s*FileScanService\.MaximumResultLimit') {
    $failures.Add('File scan results must reject partial or corrupt worker output')
}
if ($source -notmatch 'this\.processSnapshots\s*:=\s*ProcessSnapshotService\(') {
    $failures.Add('ApplicationState must own the process snapshot service')
}
if ($source -notmatch 'ProcessMaintenanceCommandClient\(\)[\s\S]{0,420}App\.processSnapshots\.WriteWorkerFile') {
    $failures.Add('Snapshot worker mode must delegate result writing to ProcessSnapshotService')
}
if ($maintenanceCoordinatorSource -notmatch 'Shutdown\(\*\)[\s\S]{0,900}this\.Runtime\.processSnapshots\.Stop\(\)') {
    $failures.Add('Application shutdown must stop the owned process snapshot service')
}
if ($snapshotServiceSource -notmatch 'this\.Stopped\s*:=\s*false' -or
    $snapshotServiceSource -notmatch 'Stop\(waitForExit := true\)[\s\S]{0,180}this\.Stopped\s*:=\s*true' -or
    $snapshotServiceSource -notmatch 'Start\(requestTicks := 0\)[\s\S]{0,100}if\s+this\.Stopped[\s\S]{0,60}return\s+false') {
    $failures.Add('ProcessSnapshotService shutdown must be terminal and prevent worker restart')
}
$snapshotStartSource = [regex]::Match($snapshotServiceSource,
    '(?ms)^    Start\(requestTicks := 0\).*?(?=^    PollWorker\(\*\))').Value
if ($snapshotServiceSource -notmatch 'StoreSnapshot\([\s\S]{0,180}if\s+this\.Stopped\s*\|\|' -or
    $snapshotServiceSource -notmatch 'StoreNativeSnapshot\([\s\S]{0,120}if\s+this\.Stopped[\s\S]{0,60}return\s+false' -or
    -not $snapshotStartSource -or
    $snapshotStartSource -notmatch 'this\.WorkerStarting\s*:=\s*true' -or
    $snapshotStartSource -notmatch 'if\s+!this\.Stopped\s*\{' -or
    $snapshotStartSource -notmatch 'accepted\s*:=\s*true' -or
    $snapshotStartSource -notmatch 'this\.WorkerStarting\s*:=\s*false' -or
    $snapshotStartSource -notmatch 'if\s+!accepted') {
    $failures.Add('Snapshot startup and publication must revalidate terminal shutdown after yielding to external work')
}
if ($snapshotServiceSource -notmatch 'CanTerminateWorker\(pid, expectedCreationIdentity\)[\s\S]{0,320}expectedCreationIdentity\s*==\s*""[\s\S]{0,220}currentCreationIdentity\s*!=\s*""[\s\S]{0,100}currentCreationIdentity\s*==\s*expectedCreationIdentity' -or
    $snapshotServiceSource -match 'WorkerCreationIdentity\s*==\s*""\s*\|\||currentCreation\s*==\s*""\s*\|\|') {
    $failures.Add('Snapshot workers may be terminated only after an exact non-empty creation-identity match')
}
if ($snapshotServiceSource -notmatch 'this\.WorkerHandle\s*:=\s*workerHandle' -or
    $snapshotServiceSource -notmatch 'OpenWorkerHandle\(pid\)[\s\S]{0,260}OpenProcess' -or
    $snapshotServiceSource -notmatch 'StopWorker\(waitForExit := true\)[\s\S]{0,500}TerminateBoundWorker\(handle, waitForExit\)' -or
    $snapshotServiceSource -notmatch 'ResetWorkerState\(deleteFiles := false\)[\s\S]{0,220}CloseWorkerHandle\(this\.WorkerHandle\)') {
    $failures.Add('Snapshot workers must use a process handle when available and release it through the shared cleanup path')
}
if ($snapshotServiceSource -notmatch 'NextWorkerOutputPath\(nowTicks := 0\)[\s\S]{0,220}this\.WorkerSequence\+\+[\s\S]{0,180}this\.WorkerSequence "\.tmp"' -or
    $snapshotStartSource -notmatch 'this\.NextWorkerOutputPath\(nowTicks\)') {
    $failures.Add('Concurrent process snapshot workers must never reuse an output path within the same millisecond')
}
if ($fileScanServiceSource -notmatch 'Stop\(workerPid, outputPath, creationIdentity := "", workerHandle := 0\)[\s\S]{0,320}if workerHandle[\s\S]{0,160}TerminateBoundWorker\(workerHandle, true\)[\s\S]{0,260}creationIdentity\s*!=\s*""[\s\S]{0,260}currentCreation\s*!=\s*""[\s\S]{0,80}currentCreation\s*==\s*creationIdentity' -or
    $fileScanServiceSource -match 'Stop\(workerPid, outputPath, creationIdentity := "", workerHandle := 0\)[\s\S]{0,700}creationIdentity\s*==\s*""\s*\|\|') {
    $failures.Add('File-scan workers must terminate through their bound process handle or an exact non-empty creation-identity match')
}
foreach ($legacySnapshotSymbol in @(
    'StartProcessSnapshotWorker\s*\(',
    'PumpProcessSnapshotWorker\s*\(',
    'StopProcessSnapshotWorker\s*\(',
    'GetProcessSnapshotAsync\s*\(',
    'GetProcessSnapshotIndexAsync\s*\(',
    'GetProbeSnapshotIndex\s*\(',
    'RequestFreshProcessSnapshot\s*\(',
    'WriteProcessSnapshotWorker\s*\(',
    'App\.latestProcessSnapshot',
    'App\.latestNativeProcessSnapshotTicks',
    'App\.processSnapshotWorker',
    'App\.processSnapshotRetryAfterTicks',
    'App\.processSnapshotRequestTicks'
)) {
    if ($source -match $legacySnapshotSymbol) {
        $failures.Add("Legacy process snapshot ownership remains: $legacySnapshotSymbol")
    }
}
if ($snapshotServiceSource -match '\bApp\.') {
    $failures.Add('ProcessSnapshotService must not recover dependencies from global App state')
}
foreach ($targetProbeHook in @(
    'class TargetProbe',
    'Observe(probeSpec, snapshotIndex := "", maximumSnapshotAgeMs := 0,',
    'ObserveProcessName(processName)',
    'ObserveImagePath(targetPath, snapshotIndex := "", observationContext := "",',
    'ObserveCommandTarget(targetPath, snapshotIndex := ""',
    'ObserveAutoHotkeyScript(targetPath, maximumSnapshotAgeMs := 0)',
    'ObserveWorkingDirectory(workingDirectory, preferredName := ""',
    'snapshotIndex.ObserveCommandTarget(targetPath, launcherPath)',
    'snapshotIndex.ObserveImagePath(targetPath,'
)) {
    if (-not $targetProbeSource.Contains($targetProbeHook)) {
        $failures.Add("Missing target probe module hook: $targetProbeHook")
    }
}
if ($source -notmatch 'this\.targetProbe\s*:=\s*TargetProbe\(') {
    $failures.Add('ApplicationState must own the shared TargetProbe instance')
}
elseif ($source -notmatch 'this\.targetProbe\s*:=\s*TargetProbe\([\s\S]{0,180}ObjBindMethod\(this\.processSnapshots,\s*"GetIndex"\)') {
    $failures.Add('TargetProbe must obtain WMI snapshot indexes from ProcessSnapshotService')
}
elseif ($source -notmatch 'this\.targetProbe\s*:=\s*TargetProbe\([\s\S]{0,420}ObjBindMethod\(this\.processInspector,\s*"CaptureNativeSnapshot"\)[\s\S]{0,240}ObjBindMethod\(this\.processInspector,\s*"GetImagePath"\)[\s\S]{0,240}ObjBindMethod\(this\.processInspector,\s*"GetCreationIdentity"\)') {
    $failures.Add('TargetProbe must receive native process inspection through the shared instance')
}
$snapshotPumpSource = [regex]::Match($snapshotServiceSource,
    '(?ms)^    PumpWorker\(\).*?(?=^    RequestFresh\(\))').Value
$snapshotPollSource = [regex]::Match($snapshotServiceSource,
    '(?ms)^    PollWorker\(\*\).*?(?=^    ArmWorkerPoll\(\))').Value
if ($snapshotPumpSource -notmatch 'completedRequestTicks\s*:=\s*this\.RequestTicks' -or
    $snapshotPumpSource -notmatch 'PublishSnapshot\(snapshot, snapshotTicks, true,[\s\S]{0,160}completedRequestTicks\)' -or
    $snapshotPollSource -notmatch 'this\.Pump\(\)' -or
    $snapshotPollSource -notmatch 'this\.ArmWorkerPoll\(\)') {
    $failures.Add('Process snapshot publication must retain request generations and collect worker results without waiting for the monitor interval')
}
elseif ($source -notmatch 'this\.targetProbe\s*:=\s*TargetProbe\([\s\S]{0,900}ObjBindMethod\(this\.processInspector,[\s\S]{0,80}"CaptureAutoHotkeyScriptSnapshot"\)') {
    $failures.Add('TargetProbe must receive the shared AutoHotkey hidden-window snapshot provider')
}
if ($guardRuntimeSource -notmatch 'existingObservation\.IsUnknown\(\)[\s\S]{0,400}NeedsFreshSnapshot\(\)[\s\S]{0,300}BeginSnapshotWait\(path, stateObj, "Restart"\)' -or
    $guardRuntimeSource -notmatch 'verificationObservation\.IsUnknown\(\)[\s\S]{0,400}NeedsFreshSnapshot\(\)[\s\S]{0,300}BeginSnapshotWait\(path, stateObj, "Verify"\)' -or
    $guardRuntimeSource -notmatch 'snapshotIndex\.RequestTicks[\s\S]{0,120}stateObj\.SnapshotRequestTicks' -or
    $targetSupervisorSource -notmatch 'ClearSnapshotCoordination\(\)[\s\S]{0,700}SnapshotReadyIndex') {
    $failures.Add('Transient snapshot gaps must use bounded request generations while permanent unknown evidence returns to normal monitoring')
}
if ($maintenanceCoordinatorSource -notmatch 'QueryNativeSnapshot\(&snapshotReady\)[\s\S]{0,260}this\.Runtime\.processInspector\.CaptureNativeSnapshot\(\)' -or
    $maintenanceCoordinatorSource -match 'Callbacks\.QueryProcessSnapshot') {
    $failures.Add('Maintenance native snapshots must come from ProcessInspector')
}
$maintenanceProcessTickSource = [regex]::Match($maintenanceCoordinatorSource,
    '(?ms)^    ProcessTick\(\).*?(?=^    EventTick\(\))').Value
if ($maintenanceProcessTickSource -notmatch 'snapshots\.Start\(\)' -or
    $maintenanceProcessTickSource -notmatch 'QueryNativeSnapshot\(&snapshotReady\)' -or
    $maintenanceProcessTickSource -match 'Callbacks\.QueryProcessSnapshot') {
    $failures.Add('Periodic maintenance scans must request full snapshots in the worker and never run WMI on the UI thread')
}
if ($maintenanceProcessTickSource -notmatch 'if !this\.ProcessBaselineReady\s*\{[\s\S]{0,1000}QueryNativeSnapshot\([\s\S]{0,100}&baselineReady\)[\s\S]{0,500}RefreshActors\(baselineSnapshot, true,') {
    $failures.Add('Maintenance polling must rebuild a failed startup baseline with native snapshots while WMI remains asynchronous')
}
if ($maintenanceCoordinatorSource -notmatch 'RefreshActors\(snapshot,[\s\S]{0,900}this\.CreateSnapshotIndex\(snapshot,') {
    $failures.Add('Maintenance actor refresh must build at most one process snapshot index')
}
if ($guardRuntimeSource -notmatch 'if\s+needSnapshot\s*\{[\s\S]{0,220}this\.CachedSnapshotIndex\s*:=\s*this\.Runtime\.processSnapshots[\s\S]{0,100}\.GetIndex\(\)[\s\S]{0,180}is\s+ProcessSnapshotIndex') {
    $failures.Add('Main monitoring must reuse one process snapshot index per cycle')
}
if ($targetSpecsServiceSource -notmatch 'Build\(path, stateObj := ""\)[\s\S]{0,220}resolvedTarget\s*:=\s*this\.StateValue[\s\S]{0,420}resolvedTarget\s*==\s*""[\s\S]{0,140}ShortcutTargetResolver\.Read') {
    $failures.Add('Target specification building must prefer the saved shortcut identity before reading the link')
}
if ($source -notmatch 'ObserveTarget\(target,[\s\S]{0,420}targetSpecsService\.Get\(target, stateObj\)[\s\S]{0,160}App\.targetProbe\.Observe\(specs\.Probe') {
    $failures.Add('Process observations must dispatch ProbeSpec through TargetProbe')
}
if ($guardRuntimeSource -notmatch 'Restart\(path,[\s\S]{0,6500}launchPlan\s*:=\s*targetPlan\.Launch[\s\S]{0,2200}launchPlan\.Kind') {
    $failures.Add('Restart execution must dispatch through LaunchSpec')
}
if ($guardRuntimeSource -notmatch 'Run 返回的 PID[\s\S]{0,400}verificationNeedsCommandLine[\s\S]{0,260}RequestFresh\(\)' -or
    [regex]::Match($guardRuntimeSource,
        '(?ms)^    RestartCore\(.*?^    ProcessRestartFailure\(').Value -match
        'SetProcessIdentity\.Call\(stateObj, newPid\)') {
    $failures.Add('Run-returned PIDs must remain untrusted until target-specific observation verifies them')
}
if ($source -notmatch 'SetStateProcessIdentity\(stateObj, pid, observedCreationIdentity := ""\)' -or
    $source -notmatch 'PIDCreationIdentity := currentCreationIdentity != ""[\s\S]{0,180}observedCreationIdentity' -or
    $guardRuntimeSource -notmatch 'SetProcessIdentity\.Call\(stateObj,[\s\S]{0,100}\.CreationIdentity\)' -or
    $maintenanceCoordinatorSource -notmatch 'SetProcessIdentity\.Call\(stateObj,[\s\S]{0,100}observation\.CreationIdentity\)') {
    $failures.Add('Verified creation identities must flow from observations into the owned target state')
}
$manualStopSource = [regex]::Match($mainSource,
    '(?ms)^PerformManualStop\(.*?(?=^ScheduleManualStopRetry\()').Value
if (-not $manualStopSource -or $manualStopSource -match 'SaveAppsToIni\(\)' -or
    $manualStopSource -match 'stateObj\.Enabled\s*:=\s*1' -or
    $manualStopSource -notmatch 'guardWorkGate\.Leave\(\)[\s\S]{0,180}StopTargetProcess\(pid, creationIdentity\)' -or
    $manualStopSource -notmatch 'CompleteManualStopAfterStop\([\s\S]{0,900}guardWorkGate\.TryEnter\([^)]*\)' -or
    $manualStopSource -notmatch 'FinalizeManualStop\(path, stateObj, expectedGeneration\)' -or
    $manualStopSource -match 'RestartCore\(') {
    $failures.Add('Manual stop must execute outside the shared gate, revalidate ownership, and never restart the target')
}
if ($targetIdentityServiceSource -notmatch 'TargetReferenceExists\(path, stateObj := ""\)[\s\S]{0,160}targetSpecsService\.Get\(path, stateObj\)[\s\S]{0,40}\.Launch\.Available') {
    $failures.Add('Target availability must come from LaunchSpec')
}
if ($targetIdentityServiceSource -notmatch 'GetMonitoredTargetPath\(path\)[\s\S]{0,300}targetSpecsService\.Get\(path, stateObj\)[\s\S]{0,40}\.ResolvedTarget') {
    $failures.Add('Maintenance target identity must come from TargetSpecs')
}
if ($source -match '(?:CommandLineContainsTarget|CommandTokenMatchesTarget|GetLaunchTargetPath)\s*\(') {
    $failures.Add('Legacy launch or probe helpers must not bypass TargetSpecs')
}
if ($source -match 'FileGetShortcut\s*\(') {
    $failures.Add('Main script must read shortcut metadata through ShortcutResolver')
}
if ($guardRuntimeSource -notmatch 'existingObservation\s*:=\s*this\.Callbacks\.ObserveTarget\.Call\(path,[\s\S]{0,180}snapshotIndex[\s\S]{0,180}\?\s*0\s*:\s*1000\)' -or
    $guardRuntimeSource -notmatch 'existingObservation\.NeedsFreshSnapshot\(\)[\s\S]{0,220}BeginSnapshotWait\(path, stateObj, "Restart"\)') {
    $failures.Add('Restart duplicate protection must require an action-fresh process snapshot')
}
foreach ($legacyObservationBridge in @(
    'wmiError',
    'CheckIsRunning\s*\(',
    'ProcessObservationPID\s*\(',
    'ProcessMatchesTarget\s*\(',
    'FindProcessByWorkingDirectory\s*\(',
    'FindProcessByImagePath\s*\(',
    'FindProcessByCommandLine\s*\(',
    'ObserveProcessByWorkingDirectory\s*\(',
    'ObserveProcessByImagePath\s*\(',
    'ObserveProbeTarget\s*\(',
    'ObserveProcessByCommandLine\s*\(',
    'ParseWindowsCommandLine\s*\(',
    'QueryNativeProcessSnapshot\s*\(',
    'CaptureNativeProbeSnapshot\s*\(',
    'GetProcessImagePath\s*\(',
    'GetProcessCreationIdentity\s*\(',
    'GetProcessElevationState\s*\('
)) {
    if ($source -match $legacyObservationBridge) {
        $failures.Add("Legacy process-observation bridge remains: $legacyObservationBridge")
    }
}
# 快照不可用与 Unknown 投影由 guard-runtime-tests.ahk 的状态机行为断言覆盖。
if ($guardRuntimeSource -notmatch 'RestartCore\(path,[\s\S]{0,6000}existingObservation\.IsUnknown\(\)[\s\S]{0,500}(?:BeginSnapshotWait|HandleUncertainObservation)') {
    $failures.Add('Restart duplicate protection must defer launch for Unknown observations')
}
$runningStateMatch = [regex]::Match($source,
    '(?ms)^UpdateRunningState\(path, stateObj, expectedGeneration := 0\)\s*\{.*?^\}')
if (-not $runningStateMatch.Success -or
    $runningStateMatch.Value -notmatch 'IsRunAsAdminMismatch\(stateObj\)') {
    $failures.Add('Running-state projection must report a confirmed elevation mismatch')
}
elseif ($runningStateMatch.Value -match 'ScheduleRestart|ProcessClose|StopTargetProcess|DoRestart') {
    $failures.Add('An elevation mismatch must not stop or restart a running target automatically')
}
if ($source -notmatch 'ToggleRunAsAdmin\(\*\)[\s\S]{0,2200}UpdateRunningState\(path, stateObj,[\s\S]{0,80}stateObj\.Generation\)') {
    $failures.Add('Changing the administrator requirement must refresh a live item immediately')
}
$manualStopMatch = [regex]::Match($source,
    '(?ms)^EndSelectedApp\(\*\)\s*\{.*?(?=^/\*)')
if (-not $manualStopMatch.Success) {
    $failures.Add('Unable to inspect the manual stop boundary')
}
else {
    $manualStopSource = $manualStopMatch.Value
    foreach ($manualStopHook in @(
        'stateObj.Enabled := 0',
        'stateObj.CancelScheduledTasks()',
        'operationGeneration := stateObj.Generation',
        'StopTargetProcess(pid, creationIdentity)',
        'FinalizeManualStop(path, stateObj, expectedGeneration)'
    )) {
        if (-not $manualStopSource.Contains($manualStopHook)) {
            $failures.Add("Manual stop is missing generation-safe execution hook: $manualStopHook")
        }
    }
    if ([regex]::Matches($manualStopSource,
        'App\.guardRuntime\.IsSupervisorCurrent\(').Count -lt 3) {
        $failures.Add('Manual stop must revalidate controller ownership after blocking operations')
    }
    if ($manualStopSource -notmatch 'try stopResult\s*:=\s*StopTargetProcess\(pid, creationIdentity\)[\s\S]{0,900}completionCallback\s*:=\s*CompleteManualStopAfterStop\.Bind\(' -or
        $manualStopSource -notmatch 'CompleteManualStopAfterStop\([\s\S]{0,500}App\.guardRuntime\.IsSupervisorCurrent\(') {
        $failures.Add('Manual process stop must revalidate controller generation before state mutation')
    }
    if ($manualStopSource -match '(?m)\bRun\s*\(' -or
        $manualStopSource -match 'RestartCore\(') {
        $failures.Add('Manual stop must not launch or restart a target')
    }
    if ($manualStopSource -notmatch 'BeginManualStopRequests\(paths\)[\s\S]{0,900}stateObj\.Enabled\s*:=\s*0[\s\S]{0,1200}SaveAppsToIni\(\)[\s\S]{0,500}SetTimer\(PerformManualStop\.Bind\(' -or
        $mainSource -notmatch 'contextMenu\.Add\(Tr\("⏹️ 结束运行"\), EndSelectedApp\)') {
        $failures.Add('Context-menu stop must persist a paused supervisor before stopping')
    }
}
$manualRestartMatch = [regex]::Match($mainWindowControllerSource,
    '(?ms)^RestartSelectedApp\(\*\)\s*\{.*?(?=^; 托盘)')
if (-not $manualRestartMatch.Success) {
    $failures.Add('Unable to inspect the manual restart boundary')
}
else {
    $manualRestartSource = $manualRestartMatch.Value
    foreach ($manualRestartHook in @(
        'stateObj.Enabled := 1',
        'stateObj.CancelScheduledTasks()',
        'stateObj.ManualRestartRequested := true',
        'stateObj.ManualRestartGeneration := operationGeneration',
        'StopTargetProcess(pid, creationIdentity)',
        'FinalizeManualRestart(path, stateObj, expectedGeneration)',
        'App.guardRuntime.RestartCore(path, stateObj)',
        'ClearManualRestartRequest(stateObj, expectedGeneration)'
    )) {
        if (-not $manualRestartSource.Contains($manualRestartHook)) {
            $failures.Add("Manual restart is missing generation-safe execution hook: $manualRestartHook")
        }
    }
    if ([regex]::Matches($manualRestartSource,
        'App\.guardRuntime\.IsSupervisorCurrent\(').Count -lt 3) {
        $failures.Add('Manual restart must revalidate controller ownership after blocking operations')
    }
    if ($manualRestartSource -notmatch 'guardWorkGate\.Leave\(\)[\s\S]{0,220}StopTargetProcess\(pid, creationIdentity\)' -or
        $manualRestartSource -notmatch 'CompleteManualRestartAfterStop\([\s\S]{0,700}guardWorkGate\.TryEnter\([^)]*\)') {
        $failures.Add('Manual restart must stop outside the shared gate and reacquire it before launch')
    }
    if ($manualRestartSource -notmatch 'ManualRestartRequested\s*\|\|\s*stateObj\.ManualStopRequested' -or
        $manualRestartSource -notmatch 'ClearManualRestartRequest\(stateObj, expectedGeneration\)[\s\S]{0,220}ManualRestartGeneration\s*!=\s*expectedGeneration' -or
        $targetSupervisorSource -notmatch 'ResetGuardAttemptState\(\)[\s\S]{0,350}ManualRestartRequested\s*:=\s*false[\s\S]{0,100}ManualRestartGeneration\s*:=\s*0[\s\S]{0,100}ManualStopRequested\s*:=\s*false' -or
        $guardRuntimeSource -notmatch 'RecoverOrphanedPending\(path, stateObj\)[\s\S]{0,180}ManualRestartRequested') {
        $failures.Add('Manual restart must interlock with stop and reject stale generation cleanup')
    }
}
$mainContextOrderPattern =
    'contextMenu\.Add\(Tr\("🔄 重新启动"\), RestartSelectedApp\)[\s\S]{0,160}' +
    'contextMenu\.Add\(Tr\("⏹️ 结束运行"\), EndSelectedApp\)[\s\S]{0,200}' +
    'Tr\("✒️ 编辑完整路径（F2）"\)[\s\S]{0,180}' +
    'contextMenu\.Add\(Tr\("📂 打开所在位置"\), OpenFileLocation\)[\s\S]{0,220}' +
    'Tr\("🎨 自定义名称和图标"\)[\s\S]{0,180}' +
    'Tr\("⚙️ 进程识别与启动设置"\)[\s\S]{0,220}' +
    'Tr\("🛡️ 以管理员身份运行"\)[\s\S]{0,260}' +
    'Tr\("🔄 软件升级保护设置"\)'
if ($mainSource -notmatch $mainContextOrderPattern -or
    $mainSource -notmatch '\{Text: Tr\("🔄 重新启动"\), Action: RestartSelectedApp\}[\s\S]{0,140}\{Text: Tr\("⏹️ 结束运行"\), Action: EndSelectedApp\}[\s\S]{0,180}\{Text: Tr\("✒️ 编辑完整路径（F2）"\)[\s\S]{0,180}\{Text: Tr\("📂 打开所在位置"\), Action: OpenFileLocation\}') {
    $failures.Add('Main context menu must preserve the requested restart, stop, edit, location, display, launch, admin, and maintenance order')
}
if ($configRepositorySource -notmatch 'ReadSectionEntries\(sectionName\)[\s\S]{0,700}entries\.Push\(') {
    $failures.Add('INI sections must expose ordered entries for order-sensitive consumers')
}
if ($watchlistPersistenceServiceSource -notmatch 'for\s+appEntry\s+in\s+this\.Repository\.ReadSectionEntries\("Apps"\)') {
    $failures.Add('App loading must preserve the saved [Apps] entry order')
}
elseif ($watchlistPersistenceServiceSource -match 'for\s+appKey\s*,\s*appValue\s+in\s+appValues') {
    $failures.Add('App loading must not depend on Map enumeration order')
}
if ($source -notmatch 'LV_ItemDrag\(ctrl, lParam\)[\s\S]{0,3200}QueueGuardMutation\(ApplyMainListReorder\.Bind\(' -or
    $source -notmatch 'ApplyMainListReorder\(selectedPaths, anchorCandidates,[\s\S]{0,2800}SaveAppsToIni\(\)') {
    $failures.Add('List drag reorder must synchronize and persist the visible order')
}
foreach ($mainListColumnCheck in @(
    @{ Name = 'four localized columns plus hidden semantic key'; Passed = $mainSource -match '\[Tr\("\u5B88\u62A4\u5BF9\u8C61"\),\s*Tr\("\u72B6\u6001"\),\s*Tr\("\u5B8C\u6574\u8DEF\u5F84"\),\s*Tr\("\u5E8F\u53F7"\),\s*""\s*\]' },
    @{ Name = 'column-order application'; Passed = $mainSource -match 'Main\.listProjection\.ApplyColumnOrder\(Main\.lv\)' },
    @{ Name = 'sequence-first display order'; Passed = $mainListProjectionSource -match 'displayOrder\s*:=\s*\[3,\s*0,\s*1,\s*2,\s*4\]' },
    @{ Name = 'hidden semantic-key width'; Passed = $mainSource -match 'Main\.lv\.ModifyCol\(5,\s*0\)' },
    @{ Name = 'native column-order message'; Passed = $mainListProjectionSource -match 'LVM_SETCOLUMNORDERARRAY' }
)) {
    if (-not $mainListColumnCheck.Passed) {
        $failures.Add("Main ListView sequence column is missing: $($mainListColumnCheck.Name)")
    }
}
if ($mainListProjectionSource -notmatch 'RefreshSequenceFromOrder\(listView, orderedPaths\)' -or
    ([regex]::Matches($source,
        'Main\.listProjection\.RefreshSequenceFromOrder\(Main\.lv, App\.appOrder\)')).Count -lt 3) {
    $failures.Add('Main ListView sequence must follow custom order after delete, reorder and configuration projection')
}
$sequenceKeyRefreshCount = ([regex]::Matches($source,
        'Main\.listProjection\.RefreshSequenceFromOrder\(Main\.lv, App\.appOrder\)[\s\S]{0,140}RefreshMainStatusSortKeys\(\)')).Count
if ($sequenceKeyRefreshCount -lt 3) {
    $failures.Add('Main status semantic keys must be refreshed whenever saved sequence values change')
}
if ($mainSource -notmatch '#Include src\\UI\\ListViewPseudoHeader\.ahk' -or
    $listViewPseudoHeaderSource -notmatch 'class\s+ListViewPseudoHeader' -or
    $listViewPseudoHeaderSource -notmatch 'SortByDisplayColumn\(displayColumn,' -or
    $listViewPseudoHeaderSource -notmatch 'OnEvent\("Click", sortCallback\)' -or
    $listViewPseudoHeaderSource -notmatch 'OnEvent\("DoubleClick", sortCallback\)' -or
    $listViewPseudoHeaderSource -notmatch 'AttachInputGuard\(cellHwnd, listHwnd\)' -or
    $listViewPseudoHeaderSource -notmatch 'SetWindowSubclass' -or
    $listViewPseudoHeaderSource -notmatch '" -Tabstop"' -or
    $listViewPseudoHeaderSource -notmatch 'headerAlignment\s*:=\s*columnSpec\.HasOwnProp\("HeaderAlign"\)[\s\S]{0,120}:\s*"Center"' -or
    $listViewPseudoHeaderSource -notmatch 'HeaderAlign:\s*headerAlignment' -or
    $listViewPseudoHeaderSource -notmatch 'alignOption\s*:=\s*StrLower\(headerAlignment\)\s*==\s*"center"' -or
    $listViewPseudoHeaderSource -notmatch 'padding\s*:=\s*columnSpec\.HasOwnProp\("Padding"\)[\s\S]{0,100}:\s*""' -or
    $listViewPseudoHeaderSource -notmatch 'case\s+0x0007:[\s\S]{0,220}SetFocus' -or
    $listViewPseudoHeaderSource -notmatch 'case\s+0x0301:[\s\S]{0,60}return 0' -or
    $listViewPseudoHeaderSource -notmatch 'case\s+0x007B:[\s\S]{0,60}return 0' -or
    $listViewPseudoHeaderSource -notmatch 'RemoveWindowSubclass' -or
    $listViewPseudoHeaderSource -notmatch 'SkipAscending' -or
    $listViewPseudoHeaderSource -notmatch 'this\.SortDescending\s*:=\s*this\.Columns\[displayColumn\]\.SkipAscending' -or
    $listViewPseudoHeaderSource -notmatch 'OnBeforeSort' -or
    $listViewPseudoHeaderSource -notmatch 'NotifyBeforeSort\(\)' -or
    $listViewPseudoHeaderSource -notmatch 'ApplyCurrentSort\(\)' -or
    $listViewPseudoHeaderSource -notmatch 'columnSpec\.SortOptions\s+" "\s+columnSpec\.Align' -or
    $listViewPseudoHeaderSource -notmatch 'RestoreOrder\(\)' -or
    $listViewPseudoHeaderSource -notmatch 'RestoreColumn' -or
    $mainSource -notmatch 'Main\.listHeader\s*:=\s*ListViewPseudoHeader\(' -or
    $mainSource -notmatch '\{Column:\s*4,\s*Label:\s*Tr\("\u5E8F\u53F7"\),\s*Align:\s*"Center",\s*SortOptions:\s*"Integer",\s*SkipAscending:\s*true\}' -or
    $mainSource -notmatch '\{Column:\s*5,\s*Label:\s*Tr\("\u72B6\u6001"\),\s*SortOptions:\s*"Logical"\}' -or
    $mainSource -notmatch 'RestoreColumn:\s*4' -or
    $mainSource -notmatch 'OnBeforeSort:\s*PrepareMainListTemporarySort' -or
    $mainSource -notmatch 'OnMainListTemporarySortChanged' -or
    $source -notmatch 'LayoutMainListHeader\(clientWidth\)[\s\S]{0,900}GetDpiForWindow[\s\S]{0,500}LVM_GETCOLUMNWIDTH[\s\S]{0,120}/\s*dpiScale') {
    $failures.Add('Main ListView must use the reusable pseudo header with temporary native sorting')
}
if ($atomicControlLayoutSource -notmatch 'class\s+AtomicControlLayout' -or
    $atomicControlLayoutSource -notmatch 'class\s+AtomicControlLayoutEraseGuard' -or
    $atomicControlLayoutSource -notmatch 'BeginDeferWindowPos' -or
    $atomicControlLayoutSource -notmatch 'DcxClipChildren' -or
    $atomicControlLayoutSource -notmatch 'finally\s*\{[\s\S]{0,260}AtomicControlLayoutEraseGuard\.End' -or
    $mainWindowControllerSource -match 'BeginDeferWindowPos|ChildEraseGuard|RedrawMainCommandButtonLayout' -or
    $listViewPseudoHeaderSource -match 'BeginDeferWindowPos|ChildEraseGuard|PaintParentClientBackground') {
    $failures.Add('Visible sibling layout must use the shared atomic control-layout transaction')
}
foreach ($statusSortHook in @(
    'GetMainStatusSemanticPriority\(statusKind\)',
    'GetMainStatusSortKey\(stateObj, sequence, descending := false\)',
    'stableSequence\s*:=\s*descending\s*\?\s*0x7FFFFFFF\s*-\s*sequence\s*:\s*sequence',
    'SetMainStatusSortKey\(row, stateObj := "", descending := ""\)',
    'RefreshMainStatusSortKeys\(descending := "", scheduleSort := true\)',
    'Main\.lv\.Modify\(row, "Col5", GetMainStatusSortKey\(stateObj, sequence,',
    'SetMainListStatus\(row, statusText\)[\s\S]{0,900}SetMainStatusSortKey\(row, stateObj\)[\s\S]{0,160}ScheduleMainListTemporarySortRefresh\(5\)'
)) {
    if ($mainVisualPipelineSource -notmatch $statusSortHook) {
        $failures.Add("Main status semantic sorting hook is missing: $statusSortHook")
    }
}
if ($source -notmatch 'PrepareMainListTemporarySort\(header, column, descending\)[\s\S]{0,140}RefreshMainStatusSortKeys\(descending, false\)') {
    $failures.Add('Main status sorting must prepare direction-stable semantic keys before invoking native sorting')
}
foreach ($displayHook in @(
    'OpenDisplaySettings)',
    'this.display := CustomDisplayDialog(mainGui)',
    'class CustomDisplayDialog extends ManagedWindow',
    'DisplayConfig: displayConfig',
    'GetMainDisplayName(path, stateObj',
    'GetMainDisplayIconSource(path, stateObj',
    '.MergeDisplayTransition(',
    'this.watchlistPersistenceService := WatchlistPersistenceService('
)) {
    if (-not $source.Contains($displayHook)) {
        $failures.Add("Missing main-window display customization hook: $displayHook")
    }
}
if ($watchlistPersistenceServiceSource -notmatch 'displayEntries\.Push\(\{Key:\s*"App" index,') {
    $failures.Add('Display customization must be persisted by the watchlist service')
}
if ($source -notmatch 'RefreshMainListDisplay\(path\)[\s\S]{0,240}row\s*:=\s*FindRow\(path\)') {
    $failures.Add('Display refresh must keep the hidden full-path column as item identity')
}
if ($mainListProjectionSource -notmatch 'class\s+MainListProjection' -or
    $mainListProjectionSource -notmatch 'RowByPath' -or
    $mainListProjectionSource -notmatch 'Rebuild\(listView\)') {
    $failures.Add('Main ListView must have a self-validating path-to-row projection index')
}
if ($source -notmatch 'FindRow\(searchPath\)\s*\{\s*return Main\.listProjection\.Find\(Main\.lv, searchPath\)') {
    $failures.Add('Main ListView row lookup must delegate to the projection index')
}
if ($source -match 'FindRow\(searchPath\)[\s\S]{0,240}Loop Main\.lv\.GetCount\(\)') {
    $failures.Add('Main ListView row lookup must not scan every row')
}
foreach ($projectionMutationCheck in @(
    @{ Name = 'single-row registration'; Passed =
        $source -match 'RegisterApp\([\s\S]{0,6000}Main\.listProjection\.Remember\(path, row\)' },
    @{ Name = 'configuration projection rebuild'; Passed =
        $source -match 'SyncMainListToConfigState\([\s\S]{0,1800}Main\.listProjection\.Rebuild\(Main\.lv\)' },
    @{ Name = 'configuration restoration projection'; Passed =
        $source -match 'ApplyState\([\s\S]{0,9000}SyncMainListToConfigState\(projectedItems\)' },
    @{ Name = 'serialized drag reorder'; Passed =
        $source -match 'ApplyMainListReorder\([\s\S]{0,2600}SyncMainListToConfigState\(projectedItems\)' }
)) {
    if (-not $projectionMutationCheck.Passed) {
        $failures.Add("Missing main-list projection maintenance path: $($projectionMutationCheck.Name)")
    }
}
if ($appConfigSnapshotServiceSource -notmatch 'SnapshotsEqual\(first, second\)[\s\S]{0,1200}DisplayConfigCodec\.Equals\(first\.Display, second\.Display\)') {
    $failures.Add('Display customization must participate in undo snapshots')
}
if ($source -notmatch 'RegisterApp\(item\.Path,[\s\S]{0,450}item\.ShortcutArgs, item\.Display,[\s\S]{0,100}item\.RuntimePath, item\.RuntimeArgs, item\.ContentHash,[\s\S]{0,80}item\.ContentSize\)') {
    $failures.Add('Undo restore must recreate deleted items with display and launch customization')
}
foreach ($windowIsolationHook in @(
    'OnMessage(Win32.WM_SYSCOMMAND, OnManagedWindowSystemCommand)',
    'WindowHierarchy.MinimizeChildIndependently(hwnd)',
    'WindowHierarchy.PrepareChildRestore(hwnd)',
    '#Include src\UI\WindowHierarchy.ahk'
)) {
    if (-not $source.Contains($windowIsolationHook)) {
        $failures.Add("Missing independent child-window minimize hook: $windowIsolationHook")
    }
}
if ($windowHierarchySource -notmatch 'MinimizeChildIndependently\(childHwnd\)[\s\S]*?SetNativeOwner\(childHwnd, 0\)[\s\S]*?PromoteToTaskbar\(childHwnd\)[\s\S]*?SuspendedChildren\[childHwnd\]\s*:=\s*\{[\s\S]*?MinimizeWindow\(childHwnd\)[\s\S]*?RegisterTaskbarTab\(childHwnd\)' -or
    $windowHierarchySource -notmatch 'PrepareChildRestore\(childHwnd\)[\s\S]*?UnregisterTaskbarTab\(childHwnd\)[\s\S]*?RestoreTaskbarStyle\(childHwnd,[\s\S]*?SetNativeOwner\(childHwnd, ownerHwnd\)[\s\S]*?SuspendedChildren\.Delete\(childHwnd\)' -or
    $windowHierarchySource -notmatch 'PromoteToTaskbar\(childHwnd\)[\s\S]*?WS_EX_APPWINDOW[\s\S]*?WS_EX_TOOLWINDOW[\s\S]*?RefreshWindowFrame\(childHwnd\)' -or
    $windowHierarchySource -notmatch 'RegisterTaskbarTab\(childHwnd\)[\s\S]*?ComCall\(4,[\s\S]*?UnregisterTaskbarTab\(childHwnd\)[\s\S]*?ComCall\(5,' -or
    $windowHierarchySource -notmatch 'IsTaskbarShellAvailable\(timeoutMs := 250\)[\s\S]*?FindWindowW[\s\S]*?SendMessageTimeoutW[\s\S]*?SMTO_ABORTIFHUNG[\s\S]*?GetTaskbarList\(\)[\s\S]*?IsTaskbarShellAvailable\(\)[\s\S]*?ComObject' -or
    $windowHierarchySource -notmatch 'MinimizeWindow\(hwnd\)[\s\S]*?SW_HIDE[\s\S]*?SW_SHOWMINNOACTIVE') {
    $failures.Add('Owned child minimization must detach its owner, enter the taskbar, and restore both styles and modal ownership')
}
if ($windowHierarchySource -match 'AppUserModelID|SHGetPropertyStoreForWindow') {
    $failures.Add('Minimized child windows must remain grouped under the assistant taskbar icon')
}
foreach ($windowHierarchyBoundary in @(
    'class WindowHierarchyPlatform',
    'class WindowHierarchyManager',
    'class WindowHierarchy',
    'OwnerLocks := Map()',
    'SuspendedChildren: Map()',
    'entry.Children[childHwnd] := entry.Children.Get(childHwnd, 0) + 1',
    'IsValidLease(lease)',
    'visited := Map()'
)) {
    if (-not $windowHierarchySource.Contains($windowHierarchyBoundary)) {
        $failures.Add("Missing modular window-hierarchy boundary: $windowHierarchyBoundary")
    }
}
if ($source -match '(?m)^class WindowHierarchy\s*\{') {
    $failures.Add('WindowHierarchy must remain owned by src/UI instead of the main script')
}
foreach ($managedWindowHook in @(
    'class ManagedWindowLifecycle',
    'class ManagedWindow',
    'static ConfigureLifecycle(lifecycle)',
    'PrepareForCreate()',
    'ReleaseStaleOwner(lifecycle)',
    'lifecycle.UnregisterControls(hwnd)',
    'lifecycle.ReleaseIcons(hwnd)',
    'lifecycle.Hierarchy.CompleteClose(closeContext)'
)) {
    if (-not $managedWindowSource.Contains($managedWindowHook)) {
        $failures.Add("Missing managed-window lifecycle boundary: $managedWindowHook")
    }
}
if ($managedWindowSource -match '\b(?:App|Main|GuiModules)\.' -or
    $managedWindowSource -match '(?m)^\s*global\s+') {
    $failures.Add('ManagedWindow must receive lifecycle dependencies without root globals')
}
if ($source -notmatch '#Include src\\UI\\ManagedWindow\.ahk' -or
    $source -notmatch 'ManagedWindow\.ConfigureLifecycle\(ManagedWindowLifecycle\(\{[\s\S]{0,500}RestoreInteractions:\s*RestoreHoveredButton[\s\S]{0,500}HideTransientWindows:[\s\S]{0,500}UnregisterControls:\s*UnregisterGuiControls[\s\S]{0,500}ReleaseIcons:\s*ReleaseWindowIcons') {
    $failures.Add('Main startup must explicitly inject every managed-window lifecycle callback')
}
if ($source -notmatch 'ManagedWindow\.ConfigureLifecycle\([\s\S]{0,900}\}\, WindowHierarchy\)\)[\s\S]{0,240}global GuiModules\s*:=\s*GuiModuleRegistry') {
    $failures.Add('ManagedWindow lifecycle must be configured before GUI modules become message-visible')
}
if ($source -match '(?m)^class ManagedWindow\s*\{') {
    $failures.Add('ManagedWindow must remain owned by src/UI instead of the main script')
}
if ($managedWindowSource -notmatch 'IsOpen\(\)[\s\S]{0,900}this\.gui\s*:=\s*""[\s\S]{0,500}UnregisterControls\(hwnd\)[\s\S]{0,300}ReleaseIcons\(hwnd\)' -or
    $managedWindowSource -notmatch 'DestroyGui\(\)[\s\S]{0,900}ReleaseOwner\(\)[\s\S]{0,700}UnregisterControls\(hwnd\)[\s\S]{0,300}guiObj\.Destroy\(\)[\s\S]{0,300}ReleaseIcons\(hwnd\)[\s\S]{0,300}CompleteClose\(closeContext\)') {
    $failures.Add('Managed windows must converge native death and explicit destruction on complete cleanup')
}
if ($source -notmatch 'UnregisterGuiControls\(guiHwnd\)[\s\S]{0,700}!DllCall\("user32\\IsWindow"[\s\S]{0,900}RemoveButton\(controlHwnd\)[\s\S]{0,900}RemoveTextInput\(controlHwnd\)') {
    $failures.Add('GUI control cleanup must remove already-destroyed button and text-input handles')
}
$logWindowMatch = [regex]::Match($source,
    '(?ms)^class LogWindow extends ManagedWindow\s*\{.*?^class HelpWindow extends ManagedWindow')
if (-not $logWindowMatch.Success -or
    -not $logWindowMatch.Value.Contains('CreateStandaloneGui("+Resize +MaximizeBox +MinSize420x280"')) {
    $failures.Add('The log window must remain a standalone modeless tool window')
}
elseif ($logWindowMatch.Value.Contains('CreateOwnedGui(')) {
    $failures.Add('The log window must not acquire or disable the main window')
}
if ($logWindowMatch.Success -and
    ($logWindowMatch.Value -notmatch 'RegisterHoverButton\(this\.exportButton,[\s\S]{0,120}RegisterButtonClick\(this\.exportButton' -or
        $logWindowMatch.Value -notmatch 'diagnosticBundleService\.Export\(' -or
        $logWindowMatch.Value -notmatch 'this\.exportButton\.Move\(\(Width - 120\) // 2, Height - 40, 120, 30\)')) {
    $failures.Add('The log window must expose the local diagnostic bundle export')
}

$applyStateMatch = [regex]::Match($source,
    '(?ms)^ApplyState\(stateArr, sourceStateArr := "", rollbackOnFailure := true,\s*preserveInlineEditSession := false\)\s*\{.*?^\}\r?\n\r?\nSaveAppsToIni\(')
if (-not $applyStateMatch.Success) {
    $failures.Add('Unable to inspect the undo/redo state application boundary')
}
else {
    $applyStateSource = $applyStateMatch.Value
    foreach ($forbiddenApplyPattern in @(
        'Main\.lv\.Delete\(\)',
        'App\.appStates\s*:=\s*Map\(\)',
        'App\.iconCache\s*:=\s*Map\(\)',
        'IL_Destroy\(Main\.appIcons\)'
    )) {
        if ($applyStateSource -match $forbiddenApplyPattern) {
            $failures.Add("Undo/redo must not perform a global reset: $forbiddenApplyPattern")
        }
    }
    foreach ($requiredDifferentialHook in @(
        'App.appConfigSnapshotService.PrepareState(stateArr)',
        'App.appConfigSnapshotService.PrepareState(sourceStateArr)',
        'ApplyAppConfigTransition(item.Path,',
        'App.appConfigSnapshotService.MergeTransitionOrder(currentState,',
        'SyncMainListToConfigState(projectedItems)',
        'if !SaveAppsToIni()',
        'ApplyState(currentState, "", false)',
        'RestoreMainListInteraction(interaction)'
    )) {
        if (-not $applyStateSource.Contains($requiredDifferentialHook)) {
            $failures.Add("Undo/redo is missing differential restore hook: $requiredDifferentialHook")
        }
    }
}
if ($appConfigHistoryServiceSource -notmatch 'class\s+AppConfigHistoryService' -or
    $appConfigHistoryServiceSource -notmatch 'Before:\s*beforeItems' -or
    $appConfigHistoryServiceSource -notmatch 'After:\s*afterItems' -or
    $appConfigHistoryServiceSource -notmatch 'ApplyCallback:\s*""' -or
    $appConfigHistoryServiceSource -notmatch 'Action:\s*this\.NormalizeAction\(action\)' -or
    $source -notmatch 'appConfigHistoryService\.Commit\(beforeState,\s*afterState,\s*action\)') {
    $failures.Add('Undo records must retain both transition states and their user-facing action')
}
if ($source -match 'CommitUndoState\(\)') {
    $failures.Add('Undo entries must be committed after mutation with an explicit before-state')
}
$unlabelledUndoCommits = [regex]::Matches($source,
    '(?m)^\s+CommitUndoState\([^,\r\n]+\)\s*$')
if ($unlabelledUndoCommits.Count -gt 0) {
    $failures.Add('Every production undo commit must include an explicit action description')
}
if (($appConfigHistoryServiceSource -notmatch 'transitionCallback\.Call\(entry\.Before, entry\.After\)') -or
    ($appConfigHistoryServiceSource -notmatch 'transitionCallback\.Call\(entry\.After, entry\.Before\)') -or
    ($source -notmatch 'appConfigHistoryService\.Undo\(') -or
    ($source -notmatch 'appConfigHistoryService\.Redo\(')) {
    $failures.Add('Undo and redo must apply explicit reverse transitions')
}
if ($appConfigHistoryServiceSource -notmatch 'transitionCallback\.Call\(entry\.Before, entry\.After\)[\s\S]{0,160}UndoEntries\.Pop\(\)' -or
    $appConfigHistoryServiceSource -notmatch 'transitionCallback\.Call\(entry\.After, entry\.Before\)[\s\S]{0,160}RedoEntries\.Pop\(\)') {
    $failures.Add('Failed undo/redo application must leave its history entry available for retry')
}
if ($appConfigHistoryServiceSource -notmatch 'CommitCustom\(' -or
    $appConfigHistoryServiceSource -notmatch 'appliedEntry\s*:=\s*entry' -or
    $source -notmatch 'CommitRuntimeSettingsUndoState\(' -or
    $source -notmatch 'ShowHistoryResult\(entry, true\)' -or
    $source -notmatch 'ShowHistoryResult\(entry, false\)') {
    $failures.Add('Shared history must cover runtime settings and return the applied action for feedback')
}
if ($source -match '\b(?:undoStack|redoStack)\b') {
    $failures.Add('ApplicationState must delegate undo and redo stack ownership to AppConfigHistoryService')
}
if ($appConfigSnapshotServiceSource -notmatch 'MergeMaintenanceTransition\([\s\S]{0,3000}merged\.LearnedActors') {
    $failures.Add('Undo must preserve maintenance actors learned after the recorded action')
}
if ($source -notmatch 'if\s+addedCount\s*\{[\s\S]{0,100}CommitUndoState\(undoState,\s*CreateAppHistoryAction\("add", addedPaths\)\)') {
    $failures.Add('Drag-and-drop must create an undo entry only after at least one target is added')
}
if ($source -match 'firstSuccessfulSnapshot' -or
    $source -match 'if\s+!this\.batchAddedCount\s*\r?\n\s*CommitUndoState') {
    $failures.Add('Batch import must not commit history before the complete batch outcome is known')
}
if ($mainSource -match '\bisMainGui\b' -or
    $mainSource -notmatch 'rootClass\s*==\s*"AutoHotkeyGUI"' -or
    $mainSource -notmatch 'isTextEditor[\s\S]{0,100}GetKeyState\("Ctrl"' -or
    $mainSource -notmatch 'PerformUndo\(\)[\s\S]{0,80}return 0' -or
    $mainSource -notmatch 'PerformRedo\(\)[\s\S]{0,80}return 0') {
    $failures.Add('Undo and redo shortcuts must cover every application GUI while preserving Edit history')
}
if ($historyToastSource -notmatch 'SetTimer\(this\.hideTimer, -3000\)' -or
    $historyToastSource -notmatch 'ClientToScreen' -or
    $historyToastSource -notmatch 'Main\.statsText\.Hwnd' -or
    $historyToastSource -notmatch 'GetWindowRect[^\r\n]*statusHwnd' -or
    $historyToastSource -notmatch 'gap\s*:=\s*Max\(1, Round\(3 \* dpi / 96\)\)' -or
    $historyToastSource -notmatch 'x\s*:=\s*NumGet\(statusRect, 0, "Int"\)' -or
    $historyToastSource -notmatch 'y\s*:=\s*NumGet\(statusRect, 4, "Int"\) - height - gap' -or
    $historyToastSource -notmatch 'CreateRoundRectRgn' -or
    $historyToastSource -notmatch '\+E0x08080000' -or
    $historyToastSource -notmatch 'w1 h1 Left Background' -or
    $historyToastSource -notmatch 'LayoutText\(text,' -or
    $historyToastSource -notmatch 'startY\s*:=\s*targetY - startOffset' -or
    $historyToastSource -notmatch 'BeginAnimation\("show"' -or
    $historyToastSource -notmatch 'BeginAnimation\("hide", fromY, this\.targetY - hideOffset' -or
    $source -notmatch 'GuiResized\([\s\S]{0,500}historyToast\.Reposition\(\)' -or
    $mainSource -notmatch 'OnMessage\(Win32\.WM_MOVE, MainWindowMoved\)' -or
    $source -notmatch 'MainWindowMoved\([\s\S]{0,220}historyToast\.Reposition\(\)' -or
    $source -notmatch 'GuiModules\.historyToast\.Show\(message\)') {
    $failures.Add('Undo and redo feedback must use a measured, left-aligned, animated, non-activating three-second toast above the status bar')
}
if ($source -notmatch 'maintenanceConfigCodec\.Equals\(priorMaintenance,[\s\S]{0,600}this\.Close\(\)[\s\S]{0,80}return') {
    $failures.Add('Unchanged maintenance settings must close without creating an undo entry')
}
if ($source -notmatch 'if\s+!settingsChanged\s*\{[\s\S]{0,560}this\.Close\(\)[\s\S]{0,80}return') {
    $failures.Add('Unchanged runtime settings must close without creating an undo entry')
}
$allowedDirectClickBindings = @(
    'ctrl.OnEvent("Click", HandleRegisteredButtonClick)',
    'this.autoResolveRadio.OnEvent("Click",',
    'this.manualResolveRadio.OnEvent("Click",'
)
$directClickBindings = $source -split "`r?`n" |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_.Contains('.OnEvent("Click"') }
foreach ($clickBinding in $directClickBindings) {
    if ($clickBinding -notin $allowedDirectClickBindings) {
        $failures.Add("Direct Click binding bypasses the button release dispatcher: $clickBinding")
    }
}

if ($source -notmatch '(?m)^#Requires AutoHotkey v2\.0 64-bit\s*$') {
    $failures.Add('Missing AutoHotkey v2 x64 runtime requirement')
}

$section = ''
$appKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$maintenanceKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$displayKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
function Test-CurrentEncodedField {
    param(
        [AllowEmptyString()]
        [string]$Value
    )
    return $Value -eq '' -or $Value -match '^<HEX>(?:[0-9A-Fa-f]{2})+$'
}
foreach ($line in Get-Content -LiteralPath $iniPath -Encoding Unicode) {
    if ($line -match '^\[(.+)\]$') {
        $section = $Matches[1]
        continue
    }
    if ($line -notmatch '^(App\d+)=(.*)$') { continue }
    $key = $Matches[1]
    $value = $Matches[2]
    if ($section -eq 'Apps') {
        [void]$appKeys.Add($key)
        $fields = $value -split '\|', -1
        $fieldCount = $fields.Count
        if ($fieldCount -ne 9) {
            $failures.Add("$key has $fieldCount fields; expected the current 9-field format")
        }
        else {
            foreach ($booleanIndex in @(0, 1, 7)) {
                if ($fields[$booleanIndex] -notin @('0', '1')) {
                    $failures.Add("$key has a non-current boolean field at index $($booleanIndex + 1)")
                }
            }
            if ([string]::IsNullOrWhiteSpace($fields[2])) {
                $failures.Add("$key has an empty target path")
            }
            foreach ($encodedIndex in @(3, 4, 5, 6, 8)) {
                if (-not (Test-CurrentEncodedField $fields[$encodedIndex])) {
                    $failures.Add("$key has a non-current encoded field at index $($encodedIndex + 1)")
                }
            }
        }
    }
    elseif ($section -eq 'Maintenance') {
        [void]$maintenanceKeys.Add($key)
        if ($value -notmatch '^<HEX>(?:[0-9A-Fa-f]{2})+$') {
            $failures.Add("Maintenance configuration $key is not in the current encoded format")
        }
    }
    elseif ($section -eq 'Display') {
        [void]$displayKeys.Add($key)
        $displayFields = $value -split '\|', -1
        if ($displayFields.Count -ne 2) {
            $failures.Add("Display configuration $key must contain name and icon fields")
        }
        elseif (-not (Test-CurrentEncodedField $displayFields[0]) -or
            -not (Test-CurrentEncodedField $displayFields[1])) {
            $failures.Add("Display configuration $key is not in the current encoded format")
        }
    }
}

foreach ($key in $appKeys) {
    if (-not $maintenanceKeys.Contains($key)) {
        $failures.Add("$key has no matching maintenance configuration")
    }
}
foreach ($key in $maintenanceKeys) {
    if (-not $appKeys.Contains($key)) {
        $failures.Add("Maintenance configuration $key has no matching app")
    }
}
foreach ($key in $displayKeys) {
    if (-not $appKeys.Contains($key)) {
        $failures.Add("Display configuration $key has no matching app")
    }
}

if ($watchlistPersistenceServiceSource -notmatch 'parts\.Length\s*!=\s*9' -or
    $watchlistPersistenceServiceSource -match 'parts\.Length\s*!=\s*8|parts\.Length\s*>=\s*9') {
    $failures.Add('Application loading must accept only the current 9-field app format')
}
if ($source -notmatch 'LoadWatchlistFromConfig\(\)[\s\S]{0,300}watchlistPersistenceService\.Load\(' -or
    $watchlistPersistenceServiceSource -notmatch 'ReadRecoveryEntries\(\)[\s\S]{0,300}ReadSectionEntries\("Recovery"\)' -or
    $watchlistPersistenceServiceSource -notmatch 'recoveryEntry\.HasOwnProp\("SerializedValue"\)[\s\S]{0,180}recoveryEntry\.SerializedValue') {
    $failures.Add('Recovery records must survive loading and subsequent configuration saves unchanged')
}
$isolatesEmptyWatchlistRecord = (
    $watchlistPersistenceServiceSource.Contains('if (appEntry.Value == "")') -and
    $watchlistPersistenceServiceSource.Contains('result.RecoveryEntries.Push(recoveryEntry)'))
$isolatesDamagedWatchlistField = (
    $watchlistPersistenceServiceSource.Contains('if (decoded == value)') -and
    $watchlistPersistenceServiceSource.Contains('throw this.CreateLoadError(sectionName, fieldName,'))
if (-not ($isolatesEmptyWatchlistRecord -and $isolatesDamagedWatchlistField)) {
    $failures.Add('Empty or damaged encoded watchlist records must be isolated into recovery instead of silently loaded or dropped')
}
foreach ($configDiagnosticHook in @(
    'CreateLoadWarning(appEntry, loadError)',
    'Section: sectionName',
    'Field: fieldName',
    'Target: this.ExtractTargetHint(appEntry.Value)',
    'BuildConfigLoadDiagnostic(App.configLoadWarnings,',
    'BuildConfigLoadDiagnostic(warnings, configPath)',
    'warning.Section',
    'warning.Target',
    'warning.Field',
    'warning.Reason',
    'App.configRepository.Path',
    'try TrayTip(Tr("{1} 条监控配置未载入'
)) {
    if (-not ($watchlistPersistenceServiceSource.Contains($configDiagnosticHook) -or
        $source.Contains($configDiagnosticHook))) {
        $failures.Add("Missing actionable watchlist-load diagnostic: $configDiagnosticHook")
    }
}

# 状态统计和图标必须依赖稳定枚举，不能在英文环境中继续匹配中文显示文案。
$statsProjection = [regex]::Match($applicationTelemetrySource,
    '(?ms)^UpdateStatsUI\(\)\s*\{.*?(?=^[A-Za-z_][A-Za-z0-9_]*\()').Value
if ($statsProjection -notmatch 'GuardPhase\.' -or
    $statsProjection -match 'InStr\([^\r\n]*(?:运行|暂停|升级|失效|停止)') {
    $failures.Add('Main statistics must classify stable guard state instead of localized status text')
}
$watchlistLoadIndex = $mainSource.IndexOf('LoadWatchlistFromConfig()')
$startupStatsIndex = if ($watchlistLoadIndex -ge 0) {
    $mainSource.IndexOf('UpdateStatsUI()', $watchlistLoadIndex)
} else { -1 }
$firstStartupShowIndex = if ($watchlistLoadIndex -ge 0) {
    $mainSource.IndexOf('ShowMainGuiWithOptions("w"', $watchlistLoadIndex)
} else { -1 }
if ($watchlistLoadIndex -lt 0 -or $startupStatsIndex -lt 0 -or
    $firstStartupShowIndex -lt 0 -or
    $startupStatsIndex -gt $firstStartupShowIndex) {
    $failures.Add('Owner-drawn main statistics must be populated after watchlist initialization and before the first window Show')
}
$statusVisualProjection = [regex]::Match($mainVisualPipelineSource,
    '(?ms)^GetMainStatusVisualKind\([^)]*\)\s*\{.*?(?=^[A-Za-z_][A-Za-z0-9_]*\()').Value
if ($statusVisualProjection -notmatch 'GuardPhase\.' -or
    $statusVisualProjection -notmatch 'MaintenancePhase\.' -or
    $statusVisualProjection -notmatch 'stateObj\.StatusKind' -or
    $statusVisualProjection -match 'InStr\([^\r\n]*(?:运行|暂停|升级|失效|停止)') {
    $failures.Add('Status icons must preserve a fine-grained stable kind and validate guard or maintenance hard state instead of localized text')
}

$addItemDialogSource = [regex]::Match($source,
    '(?ms)^class AddItemDialog extends ManagedWindow\s*\{.*?(?=^class SettingsWindow extends ManagedWindow)').Value
$logWindowSource = [regex]::Match($source,
    '(?ms)^class LogWindow extends ManagedWindow\s*\{.*?(?=^class HelpWindow extends ManagedWindow)').Value
$logRefreshSource = [regex]::Match($logWindowSource,
    '(?ms)^    RefreshContent\(\*\)\s*\{.*?(?=^    RefreshContentCore\()').Value
$applicationSearchSource = [regex]::Match($source,
    '(?ms)^class ApplicationSearchDialog extends ManagedWindow\s*\{.*?(?=^class DarkTooltipWindow extends ManagedWindow)').Value
$shutdownApplicationUiSource = [regex]::Match($source,
    '(?ms)^ShutdownApplicationUi\(\*\)\s*\{.*?(?=^AcquireApplicationMutex\()').Value
$darkTooltipSource = [regex]::Match($source,
    '(?ms)^class DarkTooltipWindow extends ManagedWindow\s*\{.*?(?=^class HistoryToastWindow)').Value
$applyStateSource = [regex]::Match($source,
    '(?ms)^ApplyState\(.*?(?=^SaveAppsToIni\()').Value
$batchStartSource = [regex]::Match($addItemDialogSource,
    '(?ms)^    StartBatchImport\([^)]*\)\s*\{.*?(?=^    IsBatchSessionCurrent\()').Value
$batchRootSource = [regex]::Match($addItemDialogSource,
    '(?ms)^    StartNextBatchRoot\([^)]*\)\s*\{.*?(?=^    PollBatchImport\()').Value
$batchPollSource = [regex]::Match($addItemDialogSource,
    '(?ms)^    PollBatchImport\(\*\)\s*\{.*?(?=^    BeginBatchConsume\()').Value
$batchConsumeSource = [regex]::Match($addItemDialogSource,
    '(?ms)^    ConsumeBatchImport\(\*\)\s*\{.*?(?=^    CompleteBatchImport\()').Value
$batchCompleteSource = [regex]::Match($addItemDialogSource,
    '(?ms)^    CompleteBatchImport\([^)]*\)\s*\{.*?(?=^    FailBatchImport\()').Value
$batchFailSource = [regex]::Match($addItemDialogSource,
    '(?ms)^    FailBatchImport\([^)]*\)\s*\{.*?(?=^    CancelBatchImport\()').Value
$batchCancelSource = [regex]::Match($addItemDialogSource,
    '(?ms)^    CancelBatchImport\(.*?\)\s*\{.*?(?=^    Confirm\()').Value
$everythingSearchSource = [regex]::Match($applicationSearchSource,
    '(?ms)^    SearchEverything\(\*\)\s*\{.*?(?=^    OnSearchChanged\()').Value
$everythingConsumeSource = [regex]::Match($applicationSearchSource,
    '(?ms)^    ConsumeEverythingResultBatch\(\*\)\s*\{.*?(?=^    OnSearchChanged\()').Value
if ($applicationSearchSource -notmatch 'third_party\\everything\\Everything64\.dll' -or
    $applicationSearchSource -notmatch 'LoadEverythingLibrary\(\)[\s\S]{0,1500}GetProcAddress' -or
    $everythingSearchSource -notmatch 'this\.everythingFunctions\["Everything_QueryW"\]' -or
    $everythingSearchSource -notmatch 'Everything_SetMax"\][\s\S]{0,80}0xFFFFFFFF' -or
    $everythingSearchSource -match 'everythingMaxResults|Min\(resultCount' -or
    $everythingSearchSource -match 'if\s*\(keyword\s*==\s*""\)\s*\{\s*keyword\s*:=' -or
    $applicationSearchSource -match 'initialSearchTimer|BeginInitialSearch|🔍 搜索：' -or
    $applicationSearchSource -notmatch 'SvgStatusBarPresenter\([\s\S]{0,260}ui-icons\\lucide\\search\.svg' -or
    $applicationSearchSource -notmatch '\[Tr\("名称"\), Tr\("路径"\), Tr\("扩展名"\)\]' -or
    $applicationSearchSource -match 'SourceOrder|ModifyCol\(4' -or
    $applicationSearchSource -notmatch 'Column:\s*3, Label:\s*Tr\("扩展名"\)' -or
    $everythingConsumeSource -notmatch 'SplitPath\(name, , , &extension\)[\s\S]{0,420}extension\s*:=\s*StrLower\(extension\)[\s\S]{0,320}this\.lv\.Add\("Icon" iconIndex, name, fullPath, extension\)' -or
    $applicationSearchSource -notmatch 'SearchDebounceMilliseconds\s*:=\s*300' -or
    $applicationSearchSource -notmatch 'OnSearchChanged\(\*\)[\s\S]{0,420}ResetSearchResults\(\)[\s\S]{0,220}-ApplicationSearchDialog\.SearchDebounceMilliseconds' -or
    $applicationSearchSource -notmatch 'ResetSearchResults\(resetUnavailableLog := true\)[\s\S]{0,300}CancelEverythingResultLoad\(\)' -or
    $applicationSearchSource -notmatch 'ShowEmptySearchState\(\)[\s\S]{0,180}ResetSearchResults\(\)' -or
    $applicationSearchSource -notmatch 'ResetSearchResults\(resetUnavailableLog := true\)[\s\S]{0,800}SetEverythingStatus\(""\)' -or
    $applicationSearchSource -match 'LoadNativeApps|FilterNativeList|PollNativeScan|App\.fileScanner' -or
    $applicationSearchSource -notmatch 'ConsumeEverythingResultBatch\(\*\)[\s\S]{0,500}everythingResultIndex \+ 8' -or
    $applicationSearchSource -match 'everythingDllName|A_ScriptDir\s*"\\"\s*this\.everything') {
    $failures.Add('Application search must use only the pinned Everything DLL, request all results, and populate them in bounded UI batches')
}
if ($applicationSearchSource -notmatch 'this\.listHeader\s*:=\s*ListViewPseudoHeader\(' -or
    $applicationSearchSource -notmatch 'this\.listSelectionPresenter\s*:=\s*ListViewSelectionPresenter\(this\.lv, 4\)' -or
    $applicationSearchSource -notmatch 'this\.listSelectionPresenter\.Dispose\(\)[\s\S]{0,180}this\.DestroyGui\(\)' -or
    $applicationSearchSource -notmatch 'LayoutListHeader\(windowWidth\)' -or
    $applicationSearchSource -notmatch 'OnSortChanged:\s*ObjBindMethod\(this,\s*"OnListSortChanged"\)' -or
    $applicationSearchSource -notmatch 'RestoreResultOrder\(\)[\s\S]{0,900}for rowData in this\.resultRows' -or
    $everythingConsumeSource -notmatch 'this\.resultRows\.Push\(' -or
    $everythingConsumeSource -notmatch 'this\.listHeader\.ApplyCurrentSort\(\)') {
    $failures.Add('Application search ListView must use three visible columns, restore source order without a hidden column, and reapply temporary sorting after batched loading')
}
if ($settingsWindowSource -match '搜索与导入|PreferEverything|NativeScanTimeout|EverythingMaxResults|preferEverything|nativeScan|everythingMax' -or
    $runtimeSettingsServiceSource -match 'PreferEverything|NativeScanTimeout|EverythingMaxResults' -or
    $mainSource -match 'preferEverything|nativeScanTimeout|everythingMaxResults') {
    $failures.Add('Removed search choices, native-scan settings, and result-limit configuration must not remain in production state or Settings UI')
}
if ($localizationServiceSource -notmatch 'RefreshInstalledUiFontNames\(\)[\s\S]{0,260}this\.InstalledUiFonts\s*:=\s*""[\s\S]{0,160}this\.GetInstalledUiFontNames\(\)' -or
    $settingsWindowSource -notmatch 'OnFontDropDownCommand\([^)]*\)[\s\S]{0,800}CBN_DROPDOWN' -or
    $settingsWindowSource -notmatch '(?ms)^    RefreshFontDropDown\([^)]*\)\s*\{.*?RefreshInstalledUiFontNames\(\)' -or
    $settingsWindowSource -notmatch 'fontDropDownRows\s*:=\s*12[\s\S]{0,220}" r" fontDropDownRows " Choose"' -or
    $settingsWindowSource -notmatch 'CBN_CLOSEUP[\s\S]{0,180}CaptureFontDropDownTopIndex\(\)[\s\S]{0,260}RefreshFontDropDown\(\)[\s\S]{0,100}RestoreFontDropDownTopIndex\(\)' -or
    $settingsWindowSource -notmatch 'CaptureFontDropDownTopIndex\(\)[\s\S]{0,500}CB_GETTOPINDEX' -or
    $settingsWindowSource -notmatch 'RestoreFontDropDownTopIndex\(\)[\s\S]{0,500}CB_SETTOPINDEX' -or
    $settingsWindowSource -notmatch 'OnMessage\(Win32\.WM_COMMAND, this\.fontDropDownCommandHandler\)' -or
    $settingsWindowSource -notmatch 'OnMessage\(Win32\.WM_COMMAND,[\s\S]{0,80}this\.fontDropDownCommandHandler, 0\)') {
    $failures.Add('The font picker must use a fixed 12-row list, preserve manual scroll position across refreshes, and unregister its message hook on close')
}

# 设置窗口只保留五页可编辑配置；启动入口与监控参数各自独立成页。
if ($settingsWindowSource -notmatch 'Loop\s+5[\s\S]{0,280}Tr\("显示"\)[\s\S]{0,80}Tr\("启动"\)[\s\S]{0,80}Tr\("监控"\)[\s\S]{0,80}Tr\("停止策略"\)[\s\S]{0,80}Tr\("日志"\)' -or
    $settingsWindowSource -notmatch 'tabIconNames\s*:=\s*\["monitor\.svg",\s*"rocket\.svg",\s*"activity\.svg"' -or
    $settingsWindowSource -notmatch 'this\.SwitchTab\(1\)' -or
    $settingsWindowSource -notmatch 'this\.showAtStartupCheck\s*:=\s*this\.AddTabControl\(2,' -or
    $settingsWindowSource -notmatch 'this\.checkUpdatesOnStartupCheck\s*:=\s*this\.AddTabControl\(2,' -or
    $settingsWindowSource -notmatch 'this\.intervalEdit\s*:=\s*this\.AddSettingsEdit\(3,' -or
    $settingsWindowSource -notmatch 'this\.recursiveImportCheck\s*:=\s*this\.AddTabControl\(3,' -or
    $settingsWindowSource -match 'BuildAboutTab|Tr\("关于"\)|checkUpdateButton|projectButton|donationButton') {
    $failures.Add('Settings must keep five ordered Display, Startup, Monitoring, Stop Policy, and Log pages without About controls')
}
if ($interactionPresenterSource -match 'PlaceTextCaretAtPointer|RegisterTextInputHitTarget' -or
    $interactionPresenterSource -match 'RegisterTextInput\(backgroundHwnd' -or
    $interactionPresenterSource -notmatch 'class\s+TextInputDecorationRouter' -or
    $interactionPresenterSource -notmatch 'if\s+message\s*==\s*Win32\.WM_NCHITTEST\s*\r?\n\s*return\s+Win32\.HTTRANSPARENT' -or
    $interactionPresenterSource -notmatch 'EnableSiblingClipping\(backgroundHwnd\)[\s\S]{0,100}EnableSiblingClipping\(editHwnd\)' -or
    $interactionPresenterSource -notmatch 'SetWindowPos[\s\S]{0,160}"Ptr",\s*editHwnd' -or
    $interactionPresenterSource -notmatch 'TextInputDecorationRouter\.DetachGui\(guiHwnd\)' -or
    $interactionPresenterSource -notmatch 'TextInputDecorationRouter\.Shutdown\(\)' -or
    $mainVisualPipelineSource -notmatch 'RegisterTextInputDecoration\(background,\s*inputEditControl\)') {
    $failures.Add('Text input decoration must stay behind Edit, clip sibling painting, remain hit-test transparent, and clean up with its GUI')
}
if ($settingsWindowSource -notmatch 'CreateOwnedGui\([\s\S]{0,140}Tr\("进程守护小助手设置"\)' -or
    ([regex]::Matches($source,
        'Tr\("进程守护小助手更新"\)')).Count -lt 2 -or
    $source -match 'Tr\("小助手更新"\)') {
    $failures.Add('Settings and update child windows must use the full product name in their titles')
}
$stackedSettingLabels = @(
    '进程状态检查间隔（毫秒）：',
    '崩溃自动重启延迟序列（秒）：',
    'GUI 程序关闭超时（秒）：',
    'CLI 程序关闭超时（秒）：',
    '运行日志显示上限（条）：',
    '批处理日志保留天数：',
    '批处理日志保存路径：'
)
foreach ($stackedSettingLabel in $stackedSettingLabels) {
    $escapedLabel = [regex]::Escape($stackedSettingLabel)
    $stackedLabelPattern = 'AddSettingsFieldLabel\(\d,\s*\d+,\s*\r?\n\s*Tr\("' `
        + $escapedLabel + '"\),\s*fieldControls\)'
    if ($settingsWindowSource -notmatch $stackedLabelPattern) {
        $failures.Add("Settings field must use the shared stacked label layout: $stackedSettingLabel")
    }
}
if ($settingsWindowSource -notmatch 'displayFieldWidth\s*:=\s*Min\(isCompact\s*\?\s*240\s*:\s*294,[\s\S]{0,100}displayFieldX\s*:=\s*Floor\(\(windowWidth\s*-\s*displayFieldWidth\)\s*/\s*2\)' -or
    $settingsWindowSource -notmatch 'SplitFieldCaption\(caption\)[\s\S]{0,260}\(\[：:\]\)\$' -or
    $settingsWindowSource -notmatch 'AddSettingsFieldLabel\(index, y, caption, groupControls\s*:=\s*""\)[\s\S]{0,260}SplitFieldCaption\(caption\)\.Label[\s\S]{0,120}groupControls\.Push\(labelControl\)' -or
    $settingsWindowSource -notmatch 'CenterSettingsControlGroup\(controls\)[\s\S]{0,420}Floor\(\(this\.layout\.WindowWidth\s*-\s*groupWidth\)\s*/\s*2\)[\s\S]{0,120}control\.Move\(groupX\)' -or
    $settingsWindowSource -notmatch 'AddDisplayFieldHeader\(70,[\s\S]{0,80}Tr\("界面语言："\),\s*"languages\.svg"\)' -or
    $settingsWindowSource -notmatch 'AddDisplayFieldHeader\(153,[\s\S]{0,80}Tr\("界面内容字体："\),\s*"type\.svg"\)' -or
    $settingsWindowSource -notmatch 'AddDisplayFieldHeader\(236,[\s\S]{0,80}Tr\("主题："\),\s*"palette\.svg"\)' -or
    $settingsWindowSource -notmatch 'logFieldAnchorWidth\s*:=\s*layout\.IsCompact\s*\?\s*240\s*:\s*294[\s\S]{0,180}logFieldX\s*:=\s*Floor\(\(layout\.WindowWidth\s*-\s*logFieldAnchorWidth\)\s*/\s*2\)[\s\S]{0,120}logPathWidth\s*:=\s*Round\(logFieldAnchorWidth\s*\*\s*1\.5\)') {
    $failures.Add('Settings fields must use compact per-page widths, strip trailing colons, stack values below labels, and center each page by its longest control')
}
if (-not $aboutWindowSource.Contains(
        'https://github.com/realSilasYang/process-watchdog') -or
    -not $aboutWindowSource.Contains('GetApplicationEditionSummary()') -or
    -not $aboutWindowSource.Contains('GetAutoHotkeyRuntimeSummary()') -or
    $aboutWindowSource -notmatch 'Tr\("检查更新"\)[\s\S]{0,500}Tr\("打赏"\)[\s\S]{0,500}Tr\("开源地址"\)' -or
    $aboutWindowSource -notmatch 'for button in \[this\.checkUpdateButton, this\.donationButton,[\s\S]{0,100}this\.projectButton\][\s\S]{0,120}UiThemeService\.Color\("Toolbar"\)' -or
    $aboutWindowSource -match 'UiThemeService\.Color\("Primary"\)' -or
    $aboutWindowSource -notmatch 'SetButtonLucideIcon\(this\.checkUpdateButton,[\s\S]{0,100}refresh-cw-action\.svg' -or
    $aboutWindowSource -notmatch 'SetButtonLucideIcon\(this\.donationButton, "heart\.svg"' -or
    $aboutWindowSource -notmatch 'SetButtonTooltip\(this\.donationButton,[\s\S]{0,100}快揭不开锅了' -or
    $aboutWindowSource -notmatch 'SetButtonTooltip\(this\.projectButton, Tr\("点个 star 吧~"\)\)' -or
    $aboutWindowSource -notmatch 'GuiModules\.donation\.Show\(this\.gui\)') {
    $failures.Add('About window must keep its read-only information and ordinary Check Update, Donate, Open Source actions in order')
}
if (-not $settingsWindowSource.Contains(
        'this.shortcutLabel.Move(integrationGroupX)') -or
    -not $settingsWindowSource.Contains(
        'this.taskLabel.Move(integrationGroupX)') -or
    -not $settingsWindowSource.Contains(
        'integrationGroupWidth := integrationLabelWidth + integrationGap') -or
    $settingsWindowSource -notmatch 'this\.tabDivider\s*:=\s*this\.gui\.Add\("Text",\s*"x15 y46 w"[\s\S]{0,100}\(windowWidth\s*-\s*30\)' -or
    $settingsWindowSource -notmatch 'startupChecks\.Push\(this\.checkUpdatesOnStartupCheck\)[\s\S]{0,500}startupChecks\.Push\(this\.showAtStartupCheck\)[\s\S]{0,180}layout\.StartupChecks\s*:=\s*this\.CenterSettingsControlGroup' -or
    $settingsWindowSource -notmatch 'fieldControls\.Push\(this\.recursiveImportCheck\)[\s\S]{0,120}layout\.MonitoringField\s*:=\s*this\.CenterSettingsControlGroup' -or
    $settingsWindowSource -notmatch 'fieldControls\.Push\(this\.forceTerminateCheck\)[\s\S]{0,120}layout\.StopPolicyField\s*:=\s*this\.CenterSettingsControlGroup' -or
    $settingsWindowSource -notmatch 'fieldControls\.Push\(this\.clearLogsOnStartupCheck\)[\s\S]{0,420}fieldControl\.Move\(logFieldX\)[\s\S]{0,180}layout\.LogField\s*:=\s*\{X:\s*logFieldX') {
    $failures.Add('Settings integration, stacked startup checks, measured page groups, and anchored log fields must preserve their layout contracts')
}
if ($settingsWindowSource -notmatch 'this\.tabBuilt\[1\]\s*:=\s*true' -or
    $settingsWindowSource -notmatch 'EnsureTabBuilt\(index\)' -or
    $settingsWindowSource -notmatch 'SwitchTab\(index,[\s\S]{0,520}EnsureTabBuilt\(index\)' -or
    $settingsWindowSource -notmatch 'case 2: this\.BuildStartupTab\(\)' -or
    $settingsWindowSource -notmatch 'case 3: this\.BuildMonitoringTab\(\)' -or
    $settingsWindowSource -notmatch 'case 4: this\.BuildStopPolicyTab\(\)' -or
    $settingsWindowSource -notmatch 'case 5: this\.BuildLogTab\(\)') {
    $failures.Add('Settings must build only the visible Display tab initially and create other pages on first selection')
}
$settingsTabSwitchSource = [regex]::Match($settingsWindowSource,
    '(?ms)^    SuspendTabRedraw\(\)\s*\{.*?(?=^    BrowseLogDirectory\()').Value
if ([string]::IsNullOrWhiteSpace($settingsTabSwitchSource) -or
    $settingsTabSwitchSource -notmatch 'SuspendTabRedraw\(\)[\s\S]{0,700}Win32\.WM_SETREDRAW[\s\S]{0,80}"Ptr", false' -or
    $settingsTabSwitchSource -notmatch 'ResumeTabRedraw\(transaction\)[\s\S]{0,700}Win32\.WM_SETREDRAW[\s\S]{0,80}"Ptr", true[\s\S]{0,260}Win32\.RDW_LAYOUT_REFRESH' -or
    $settingsTabSwitchSource -notmatch 'SetTabButtonVisualState\(button,[\s\S]{0,700}state\.current\s*:=\s*normalColor[\s\S]{0,160}state\.textColor\s*:=\s*textColor' -or
    $settingsTabSwitchSource -notmatch 'SwitchTab\(index,[\s\S]{0,260}redrawTransaction\s*:=\s*this\.SuspendTabRedraw\(\)[\s\S]{0,180}EnsureTabBuilt\(index\)' -or
    $settingsTabSwitchSource -notmatch 'finally\s+this\.ResumeTabRedraw\(redrawTransaction\)') {
    $failures.Add('Settings tab switches must build and update the complete page inside one redraw transaction, then restore painting in finally')
}
$settingsShowSource = [regex]::Match($settingsWindowSource,
    '(?ms)^    Show\(\*\)\s*\{.*?(?=^    GetTabButtonWidths\()').Value
$settingsStartupSource = [regex]::Match($settingsWindowSource,
    '(?ms)^    BuildStartupTab\(\)\s*\{.*?(?=^    BuildMonitoringTab\()').Value
if (-not $settingsShowSource -or
    -not $settingsStartupSource -or
    $settingsStartupSource -notmatch 'SetButtonLucideIcon\(this\.taskButton, "loader-circle\.svg"[\s\S]{0,120}SetRegisteredButtonEnabled\(this\.taskButton, false\)' -or
    $settingsShowSource -match 'SetTimer\(this\.taskStatusTimer, -1\)' -or
    $settingsWindowSource -notmatch 'SwitchTab\(index,[\s\S]{0,2200}if index == 2 && this\.taskButton[\s\S]{0,100}SetTimer\(this\.taskStatusTimer, -1\)' -or
    $settingsShowSource -match 'UpdateTaskButtonStatus\(\)[\s\S]{0,180}ShowApplicationWindow\(' -or
    $settingsWindowSource -notmatch 'RefreshTaskStatusAfterTabShow\(\*\)[\s\S]{0,180}this\.UpdateTaskButtonStatus\(\)' -or
    $settingsWindowSource -notmatch 'UpdateTaskButtonStatus\(\)[\s\S]{0,900}SetRegisteredButtonEnabled\(this\.taskButton, true\)' -or
    $settingsWindowSource -notmatch 'Close\(\*\)[\s\S]{0,120}SetTimer\(this\.taskStatusTimer, 0\)') {
    $failures.Add('Settings must query Task Scheduler only after the Startup tab is shown and cancel the deferred query on close')
}
foreach ($retiredSettingsLabel in @(
        '启动后显示主窗口', '内容字体：', '状态检查间隔（毫秒）：',
        '重启等待序列（秒）：', '批量导入文件夹时递归扫描子目录',
        '窗口程序关闭等待（秒）：', '命令行程序退出等待（秒）：',
        '运行日志内存上限（条）：', '批处理日志保留时间（天）：',
        '批处理日志保存目录：')) {
    if ($settingsWindowSource.Contains('"' + $retiredSettingsLabel + '"')) {
        $failures.Add("Retired Settings label remains in production UI: $retiredSettingsLabel")
    }
}
$lifecycleBoundaries = @(
    @{Source = $guardRuntimeSource; Pattern = 'Shutdown\(\*\)[\s\S]{0,500}SetTimer\(this\.MonitorTimer, 0\)'; Name = 'guard monitor timer'},
    @{Source = $guardRuntimeSource; Pattern = 'Shutdown\(\*\)[\s\S]{0,900}this\.Runtime\.scheduler\.Shutdown\(\)'; Name = 'shared scheduler'},
    @{Source = $guardRuntimeSource; Pattern = 'Shutdown\(\*\)[\s\S]{0,1100}this\.Runtime\.maintenanceCoordinator\.Shutdown\(\)'; Name = 'maintenance coordinator'},
    @{Source = $addItemDialogSource; Pattern = 'Close\(\*\)[\s\S]{0,220}this\.CancelBatchImport\(false\)'; Name = 'batch import worker'},
    @{Source = $addItemDialogSource; Pattern = 'Shutdown\(\*\)[\s\S]{0,180}this\.search\.Shutdown\(\)'; Name = 'owned add-dialog child'},
    @{Source = $logWindowSource; Pattern = 'Close\(\*\)[\s\S]{0,160}SetTimer\(this\.refreshTimer, 0\)'; Name = 'log refresh timer'},
    @{Source = $applicationSearchSource; Pattern = 'Close\(\*\)[\s\S]{0,220}SetTimer\(this\.searchTimer, 0\)[\s\S]{0,180}this\.CancelEverythingResultLoad\(\)[\s\S]{0,500}this\.searchLabelPresenter\.Dispose\(\)'; Name = 'application search timers and SVG label'},
    @{Source = $applicationSearchSource; Pattern = 'Shutdown\(\*\)[\s\S]{0,220}FreeLibrary[\s\S]{0,120}this\.everythingLib\s*:=\s*0'; Name = 'Everything module handle'},
    @{Source = $darkTooltipSource; Pattern = 'Close\(\*\)[\s\S]{0,100}this\.Hide\(\)[\s\S]{0,100}this\.DestroyGui\(\)'; Name = 'tooltip timer and window'}
)
foreach ($boundary in $lifecycleBoundaries) {
    if ($boundary.Source -notmatch $boundary.Pattern) {
        $failures.Add("Missing owned cleanup boundary: $($boundary.Name)")
    }
}
if (-not $logRefreshSource -or
    $logRefreshSource -notmatch 'catch\s+as\s+refreshErr[\s\S]{0,140}SetTimer\(this\.refreshTimer, 0\)[\s\S]{0,180}LogMsg\(') {
    $failures.Add('Periodic log refresh failures must disable the timer before logging the error')
}
if ($source -notmatch 'UpdateCountdownUI\(\)[\s\S]{0,260}catch\s+as\s+countdownErr[\s\S]{0,140}SetTimer\(UpdateCountdownUI, 0\)[\s\S]{0,180}LogMsg\(') {
    $failures.Add('Periodic countdown UI failures must disable the timer before logging the error')
}
foreach ($deadWindowBoundary in @(
    @{Source = $batchPollSource; Name = 'batch polling'},
    @{Source = $batchConsumeSource; Name = 'batch consumption'},
    @{Source = $logRefreshSource; Name = 'log refresh'},
    @{Source = $everythingConsumeSource; Name = 'Everything result consumption'}
)) {
    if (-not $deadWindowBoundary.Source -or
        $deadWindowBoundary.Source -notmatch 'if\s+!this\.IsOpen\(\)\s*\{[\s\S]{0,100}this\.Close\(\)') {
        $failures.Add("Dead native windows must converge on owned cleanup: $($deadWindowBoundary.Name)")
    }
}
foreach ($messageWindowBoundary in @(
    @{Source = $applicationSearchSource; Name = 'application search'}
)) {
    if ($messageWindowBoundary.Source -notmatch 'OnMouseMove\([^)]*\)\s*\{[\s\S]{0,180}if\s+!this\.IsOpen\(\)\s*\{[\s\S]{0,100}this\.Close\(\)') {
        $failures.Add("Destroyed message-owner windows must unregister their handlers: $($messageWindowBoundary.Name)")
    }
}

foreach ($redrawBoundary in @(
    @{Source = $applyStateSource; Control = 'Main\.lv'; Name = 'state application'},
    @{Source = $everythingConsumeSource; Control = 'this\.lv'; Name = 'Everything result consumption'}
)) {
    $redrawPatternAfterSuspend = $redrawBoundary.Control + '\.Opt\("-Redraw"\)[\s\S]*?try\s*\{[\s\S]*?finally\s*\{[\s\S]*?' + $redrawBoundary.Control + '\.Opt\("\+Redraw"\)'
    $redrawPatternInsideTry = 'try\s*\{[\s\S]*?' + $redrawBoundary.Control + '\.Opt\("-Redraw"\)[\s\S]*?finally\s*\{[\s\S]*?' + $redrawBoundary.Control + '\.Opt\("\+Redraw"\)'
    if (-not $redrawBoundary.Source -or
        ($redrawBoundary.Source -notmatch $redrawPatternAfterSuspend -and
            $redrawBoundary.Source -notmatch $redrawPatternInsideTry)) {
        $failures.Add("ListView redraw suspension lacks a finally boundary: $($redrawBoundary.Name)")
    }
}

if (-not $batchRootSource -or
    $batchRootSource -notmatch 'while\s+this\.batchRootQueue\.Length' -or
    $batchRootSource -match 'this\.StartNextBatchRoot\(') {
    $failures.Add('Batch root startup must iterate failed roots without recursive stack growth')
}
if (-not $batchStartSource -or
    $batchStartSource -notmatch 'batchPendingPaths\.Length[\s\S]{0,100}>=\s*App\.batchImportMaxResults[\s\S]{0,120}batchTruncated\s*:=\s*true[\s\S]{0,80}break') {
    $failures.Add('Direct batch imports must honor the same bounded result count as directory scans')
}
if (-not $batchPollSource -or
    $batchPollSource -notmatch 'catch\s+as\s+batchPollErr[\s\S]{0,120}this\.FailBatchImport\(' -or
    -not $batchConsumeSource -or
    $batchConsumeSource -notmatch 'catch\s+as\s+batchConsumeErr[\s\S]{0,120}this\.FailBatchImport\(') {
    $failures.Add('Batch polling and consumption callbacks must converge on failure cleanup')
}
if ($addItemDialogSource -notmatch 'this\.batchSessionId\s*:=\s*0' -or
    $addItemDialogSource -notmatch 'IsBatchSessionCurrent\(sessionId\)[\s\S]{0,160}sessionId\s*==\s*this\.batchSessionId' -or
    $batchRootSource -notmatch 'if\s+this\.IsBatchSessionCurrent\(sessionId\)[\s\S]{0,700}accepted\s*:=\s*true[\s\S]{0,300}if\s+!accepted[\s\S]{0,180}App\.fileScanner\.Stop\(' -or
    $batchCancelSource -notmatch 'this\.batchSessionId\+\+') {
    $failures.Add('Batch import workers and callbacks must reject results from cancelled GUI sessions')
}
if (-not $batchCompleteSource -or
    $batchCompleteSource -notmatch 'undoState\s*:=\s*this\.batchUndoState[\s\S]*?addedPaths\s*:=\s*this\.batchAddedPaths[\s\S]*?CommitUndoState\(undoState,[\s\S]{0,100}CreateAppHistoryAction\("add", addedPaths\)' -or
    -not $batchFailSource -or
    $batchFailSource -notmatch 'CommitUndoState\(undoState,[\s\S]{0,100}CreateAppHistoryAction\("add", addedPaths\)' -or
    -not $batchCancelSource -or
    $batchCancelSource -notmatch 'CommitUndoState\(undoState,[\s\S]{0,100}CreateAppHistoryAction\("add", addedPaths\)') {
    $failures.Add('Every batch terminal path must commit all successful additions once and reset transaction state')
}
if ($applicationSearchSource -notmatch 'CancelEverythingResultLoad\(\)[\s\S]{0,260}SetTimer\(this\.resultConsumeTimer, 0\)[\s\S]{0,180}this\.everythingSearchSessionId\+\+' -or
    $everythingConsumeSource -notmatch 'sessionId\s*:=\s*this\.everythingSearchSessionId[\s\S]{0,2600}sessionId\s*!=\s*this\.everythingSearchSessionId') {
    $failures.Add('Everything result batches must reject work from superseded searches and stop their timer on close')
}
if ($fileScanServiceSource -notmatch 'StartPreparedWorker\(command, outputPath,[\s\S]{0,3000}DeadlineTicks:\s*startedTicks\s*\+\s*timeoutSeconds\s*\*\s*1000\s*\+\s*5000' -or
    $batchPollSource -notmatch 'workerDeadlineTicks[\s\S]{0,420}GetTickCount64\(\)\s*>=\s*workerDeadlineTicks') {
    $failures.Add('File-scan polling must have a parent-side deadline even when PID identity becomes unavailable')
}
if ($batchPollSource -notmatch 'currentWorkerIdentity\s*!=\s*""[\s\S]{0,100}currentWorkerIdentity\s*!=\s*workerCreationIdentity') {
    $failures.Add('File-scan polling must treat an unreadable creation identity as unknown rather than PID replacement')
}

$saveColorEntries = [regex]::Matches($uiThemeServiceSource,
    '\["Save",\s*"3F6B5B"\]')
if ($saveColorEntries.Count -ne 2) {
    $failures.Add('The semantic Save color must be #3F6B5B in both light and dark palettes')
}
foreach ($saveWindow in @(
        @{Source = $settingsWindowSource; Name = 'SettingsWindow'},
        @{Source = $customDisplayDialogSource; Name = 'CustomDisplayDialog'},
        @{Source = $environmentSettingsDialogSource; Name = 'EnvironmentSettingsDialog'},
        @{Source = $maintenanceSettingsDialogSource; Name = 'MaintenanceSettingsDialog'}
    )) {
    if ([regex]::Matches($saveWindow.Source,
            'UiThemeService\.Color\("Save"\)').Count -lt 2) {
        $failures.Add("$($saveWindow.Name) text-only Save action must use the semantic Save color for normal and hover registration")
    }
}

foreach ($saveWindowSource in @($settingsWindowSource,
        $customDisplayDialogSource, $environmentSettingsDialogSource,
        $maintenanceSettingsDialogSource)) {
    if ($saveWindowSource -notmatch 'Save\(\*\)[\s\S]{0,180}QueueExclusiveGuardMutation\(this, "save",[\s\S]{0,100}ObjBindMethod\(this, "SaveTransaction"\)' -or
        $saveWindowSource -match '\bsavePending\b|\bSaveCore\(') {
        $failures.Add('Settings saves must use the shared owner-and-operation exclusive guard queue')
    }
}
if ($guardMutationQueueSource -notmatch 'Enqueue\(callback, description := "", completionCallback := ""\)[\s\S]{0,800}CompletionCallback:\s*completionCallback' -or
    $guardMutationQueueSource -notmatch 'EnqueueExclusive\(owner, operationKey,[\s\S]{0,900}ExclusiveOperations\.Has\(key\)[\s\S]{0,800}ObjBindMethod\(this, "ReleaseExclusiveOperation"' -or
    $guardMutationQueueSource -notmatch 'finally this\.CompleteOperation\(operation\)' -or
    $maintenanceSettingsDialogSource -notmatch 'QueueExclusiveGuardMutation\(this, "resume-protection",[\s\S]{0,100}ObjBindMethod\(this, "ResumeProtectionTransaction"\)' -or
    $maintenanceSettingsDialogSource -match '\bresumePending\b|\bResumeProtectionCore\(') {
    $failures.Add('Exclusive guard mutations must release operation keys after success, failure, rejection and shutdown')
}

# 只修改工作目录、参数或环境变量时，当前进程身份与守护时序仍然有效。
# 取消任务、清理身份、重建维护基线和重新初始化必须全部受 identityChanged 约束。
$environmentSaveTransaction = [regex]::Match(
    $environmentSettingsDialogSource,
    '(?ms)^    SaveTransaction\(\)\s*\{.*?(?=^    GetEnvironmentValidationMessage\()').Value
if (-not $environmentSaveTransaction -or
    [regex]::Matches($environmentSaveTransaction,
        'stateObj\.CancelScheduledTasks\(\)').Count -ne 1 -or
    [regex]::Matches($environmentSaveTransaction,
        'ClearStateProcessIdentity\(stateObj\)').Count -ne 1 -or
    $environmentSaveTransaction -notmatch 'if identityChanged\s*\{[\s\S]{0,260}stateObj\.CancelScheduledTasks\(\)[\s\S]{0,180}CleanupTarget\(path, stateObj, false\)[\s\S]{0,120}ClearStateProcessIdentity\(stateObj\)' -or
    $environmentSaveTransaction -notmatch 'if identityChanged\s*\{[\s\S]{0,1800}TransitionTo\(GuardPhase\.Initializing\)') {
    $failures.Add('Launch-environment-only edits must not cancel or reinitialize the active guard')
}

# 排队配置事务持有全局守护工作门；同步模态窗口会让所有目标监控一起停住。
# 事务只能安排延迟消息框，待当前回调返回并释放工作门后再与用户交互。
if ($darkMessageBoxSource -notmatch 'ShowDarkMsgBoxDeferred\([^)]*\)[\s\S]{0,220}SetTimer\(ShowDarkMsgBox\.Bind\(') {
    $failures.Add('Deferred message boxes must yield through a one-shot timer before opening a modal window')
}
foreach ($guardTransactionSource in @(
    $settingsWindowSource,
    $customDisplayDialogSource,
    $environmentSettingsDialogSource,
    $maintenanceSettingsDialogSource
)) {
    $transactionMatches = [regex]::Matches($guardTransactionSource,
        '(?ms)^    (?:SaveTransaction|ResumeProtectionTransaction)\([^)]*\)\s*\{.*?(?=^    [A-Z][A-Za-z0-9_]*\()')
    foreach ($transactionMatch in $transactionMatches) {
        if ($transactionMatch.Value -match '\bShowDarkMsgBox\s*\(') {
            $failures.Add('Queued guard transactions must not open synchronous modal message boxes while holding the shared work gate')
        }
    }
}
foreach ($messageOwner in @(
    @{Source = $applicationSearchSource; Name = 'application search'}
)) {
    if ($messageOwner.Source -notmatch 'this\.mouseHandlerRegistered\s*:=\s*false' -or
        $messageOwner.Source -notmatch 'OnMessage\(Win32\.WM_MOUSEMOVE, this\.mouseHandler\)[\s\S]{0,100}this\.mouseHandlerRegistered\s*:=\s*true' -or
        $messageOwner.Source -notmatch 'if this\.mouseHandlerRegistered[\s\S]{0,180}OnMessage\(Win32\.WM_MOUSEMOVE, this\.mouseHandler, 0\)[\s\S]{0,100}this\.mouseHandlerRegistered\s*:=\s*false') {
        $failures.Add("$($messageOwner.Name) must unregister WM_MOUSEMOVE by explicit registration state")
    }
}

$windowIconSource = [regex]::Match($source,
    '(?ms)^SetWindowIcon\(.*?(?=^SetDarkListView\()').Value
$shellIconSource = [regex]::Match($source,
    '(?ms)^GetShellImageListIcon\(.*?(?=^GetPreferredMainIcon\()').Value
$maskPaddedIconSource = [regex]::Match($source,
    '(?ms)^CreateMaskPaddedIcon\(.*?(?=^AddIconToImageList\()').Value
if ($windowIconSource -notmatch 'if !hIconSmall \|\| !hIconBig' -or
    $windowIconSource -notmatch 'iconResources\.ReplaceWindowIcons\(hWnd,[\s\S]{0,100}\[hIconSmall, hIconBig\]\)' -or
    $windowIconSource -notmatch 'DestroyIconHandles\(oldHandles, hIconSmall, hIconBig\)' -or
    $windowIconSource -match 'ReleaseWindowIcons\(') {
    $failures.Add('Window icons must be replaced as one owned pair without releasing live fallback slots')
}
if ($shellIconSource -notmatch 'finally[\s\S]{0,220}ReleaseIconComObject\(shellImageList\)') {
    $failures.Add('Shell image-list COM interfaces must be released on every result path')
}
if ($source -notmatch 'if !maskBits\s*\{[\s\S]{0,100}DeleteObject[^\r\n]*maskBitmap' -or
    $maskPaddedIconSource -notmatch 'finally[\s\S]{0,1000}SelectObject[\s\S]{0,600}DeleteObject') {
    $failures.Add('Icon bitmap construction must release partial and selected GDI resources')
}
if ($source -notmatch 'RebuildMainImageList\(rebuildGeneration, expectedDpi,[\s\S]{0,3200}finally[\s\S]{0,180}Main\.lv\.Opt\("\+Redraw"\)[\s\S]{0,400}RetireMainImageList\(oldImageList\)[\s\S]{0,180}else\s*\{[\s\S]{0,180}IL_Destroy\(newImageList\)' -or
    $source -notmatch 'AddIconToImageList\(imageList,[\s\S]{0,700}finally[\s\S]{0,120}DestroyIcon') {
    $failures.Add('DPI image-list replacement and temporary icons must have transactional cleanup')
}
if ($mainVisualPipelineSource -notmatch 'ReadSingleFileDialogPath\([\s\S]{0,700}finally[\s\S]{0,220}CoTaskMemFree[\s\S]{0,160}ObjRelease') {
    $failures.Add('File-dialog raw shell resources must be released through one finally boundary')
}
if ($mainVisualPipelineSource -notmatch 'SelectDirectoryWithModernDialog\([\s\S]{0,220}SelectPathWithModernDialog\([^\r\n]*[\s\S]{0,80}0x868' -or
    $mainVisualPipelineSource -notmatch 'SelectPathWithModernDialog\([\s\S]{0,900}ComObject\([\s\S]{0,650}ReadSingleFileDialogPath\([\s\S]{0,300}finally[\s\S]{0,180}RestoreNativeDialogThemePreference' -or
    $mainVisualPipelineSource -notmatch 'SelectFileWithNamedFilter\([\s\S]{0,300}SelectPathWithModernDialog\(' -or
    $mainVisualPipelineSource -notmatch 'BeginNativeDialogThemePreference\([\s\S]{0,700}UiThemeService\.IsDark\(\) \? 2 : 3' -or
    $addItemDialogSource -notmatch 'SelectDirectoryWithModernDialog\(hwndOwner' -or
    $logWindowSource -notmatch 'SelectDirectoryWithModernDialog\(ownerHwnd,[\s\S]{0,100}A_Desktop' -or
    $source -match '\b(?:DirSelect|FileSelect)\s*\(\s*"D"') {
    $failures.Add('Directory selection must use the shared themed IFileOpenDialog instead of the legacy folder browser')
}

# 应用窗口不得各自复制标题栏、图标、背景和默认字体初始化；UxTheme 私有
# 序号也只能由主题服务解析，防止窗口创建时覆盖用户的进程级主题偏好。
if ($mainVisualPipelineSource -notmatch 'InitializeApplicationWindow\(guiObj,[\s\S]{0,650}ApplyNativeWindowTheme\(hwnd\)[\s\S]{0,260}SetWindowIcon\(hwnd,[\s\S]{0,260}guiObj\.BackColor[\s\S]{0,260}guiObj\.SetFont' -or
    $mainVisualPipelineSource -notmatch 'class ApplicationWindowPresenter[\s\S]{0,900}AutomationHidden[\s\S]{0,700}guiObj\.Show\(showOptions\)[\s\S]{0,300}ShowApplicationWindow\(guiObj' -or
    $source -match '\bSetDarkTitleBar\s*\(' -or
    $appModuleSource -match 'SetWindowIcon\(this\.gui\.Hwnd' -or
    $uiThemeServiceSource -notmatch 'GetUxThemeFunction\(ordinal\)[\s\S]{0,900}GetProcAddress' -or
    $mainVisualPipelineSource -match 'GetModuleHandleW?[^\r\n]*uxtheme|GetProcAddress[^\r\n]*(?:133|135)') {
    $failures.Add('Application window initialization and UxTheme callback resolution must remain centralized')
}
foreach ($windowFile in Get-ChildItem -LiteralPath `
        (Join-Path $projectRoot 'app\Windows') -Filter '*.ahk' -File) {
    $windowSource = Get-Content -LiteralPath $windowFile.FullName -Raw `
        -Encoding UTF8
    if ($windowSource -match '\bCreate(?:Owned|Standalone)Gui\(' -and
        $windowSource -notmatch '\bInitializeApplicationWindow\(this\.gui') {
        $failures.Add("Managed application window bypasses shared visual initialization: $($windowFile.Name)")
    }
    if ($windowFile.Name -notin @(
            'HistoryToastWindow.ahk',
            'MainContextPopupWindow.ahk') -and
        $windowSource -match 'this\.gui\.Show\(') {
        $failures.Add("Managed application window bypasses shared visibility policy: $($windowFile.Name)")
    }
}

$displayHotSwitchTestSource = Get-Content -LiteralPath (Join-Path $projectRoot `
    'tests\gui\display-hot-switch-tests.ahk') -Raw -Encoding UTF8
$localizedWindowTestSource = Get-Content -LiteralPath (Join-Path $projectRoot `
    'tests\gui\localized-window-smoke-tests.ahk') -Raw -Encoding UTF8
$logWindowTestSource = Get-Content -LiteralPath (Join-Path $projectRoot `
    'tests\gui\log-window-smoke-tests.ahk') -Raw -Encoding UTF8
if ($displayHotSwitchTestSource -match
        '(?:BackColor\s*:=\s*"[0-9A-Fa-f]{6}"|Background[0-9A-Fa-f]{6}|\bc(?:White|FFFFFF)\b)' -or
    $displayHotSwitchTestSource -notmatch
        'ApplicationWindowPresenter\.SetAutomationHidden\(true\)' -or
    $localizedWindowTestSource -notmatch
        'ApplicationWindowPresenter\.SetAutomationHidden\(true\)' -or
    $logWindowTestSource -notmatch
        'ApplicationWindowPresenter\.SetAutomationHidden\(true\)') {
    $failures.Add('Automated production-window tests must use the active palette and remain hidden from the user desktop')
}
if ($interactionPresenterSource -notmatch 'SetRegisteredButtonEnabled\(ctrl, enabled\)[\s\S]{0,800}ClearHoveredButton\(hWnd\)[\s\S]{0,500}ctrl\.Enabled := enabled[\s\S]{0,220}RedrawRoundedButton\(hWnd\)' -or
    $customDisplayDialogSource -notmatch 'SetRegisteredButtonEnabled\(this\.defaultNameButton' -or
    $aboutWindowSource -notmatch 'SetRegisteredButtonEnabled\(this\.checkUpdateButton' -or
    $addItemDialogSource -notmatch 'for button in \[this\.searchButton, this\.browseButton, this\.okButton\][\s\S]{0,100}SetRegisteredButtonEnabled\(button, !active\)' -or
    $customDisplayDialogSource -match 'SetDefaultButtonEnabled\(' -or
    $appModuleSource -match 'try (?:this\.)?[A-Za-z][A-Za-z0-9_]*Button\.Enabled :=') {
    $failures.Add('Registered button enabled state must use the shared interaction reset and redraw path')
}
if ($fileScanServiceSource -notmatch 'Start\(rootPath, recursive, maximumResults, timeoutSeconds\)[\s\S]{0,180}static workerSequence\s*:=\s*0[\s\S]{0,300}Critical\("On"\)[\s\S]{0,220}currentWorkerSequence\s*:=\s*workerSequence[\s\S]{0,1200}StartPreparedWorker\(command, outputPath' -or
    $fileScanServiceSource -notmatch 'StartPreparedWorker\(command, outputPath,[\s\S]{0,2600}if this\.Stopped[\s\S]{0,120}this\.Workers\[outputPath\]\s*:=\s*job[\s\S]{0,300}if rejectedAfterLaunch[\s\S]{0,160}this\.Stop\(job\.Pid, job\.Path, job\.CreationIdentity, job\.Handle\)' -or
    $addItemDialogSource -notmatch 'seenRoots\s*:=\s*Map\(\)[\s\S]{0,260}!seenRoots\.Has\(canonicalRoot\)') {
    $failures.Add('Concurrent file scans must use unique output paths and deduplicate batch roots')
}
if ($fileScanServiceSource -notmatch 'Stop\(workerPid, outputPath, creationIdentity := "", workerHandle := 0\)[\s\S]{0,900}finally\s*\{[\s\S]{0,220}this\.DeleteOutputFiles\(outputPath\)' -or
    $fileScanServiceSource -notmatch 'ReadResult\(outputPath,[\s\S]{0,1400}finally\s*\{[\s\S]{0,500}this\.DeleteOutputFiles\(outputPath\)' -or
    $fileScanServiceSource -notmatch 'DeletePathWithRetry\(path, maximumAttempts := 4\)[\s\S]{0,500}Loop maximumAttempts[\s\S]{0,300}Sleep\(10\)' -or
    $fileScanServiceSource -notmatch 'DeleteOutputFiles\(outputPath\)[\s\S]{0,300}DeletePathWithRetry\(outputPath\)[\s\S]{0,180}DeletePathWithRetry\(outputPath "\.writing"\)' -or
    $fileScanServiceSource -notmatch 'Shutdown\(\*\)[\s\S]{0,650}this\.Workers\.Clear\(\)[\s\S]{0,300}this\.Stop\(job\.Pid, job\.Path, job\.CreationIdentity, job\.Handle\)') {
    $failures.Add('File-scan output cleanup must use bounded retries even when worker identity inspection fails')
}
if ($source -notmatch 'AcquireMainImageListUse\(imageList\)[\s\S]{0,180}iconResources\.AcquireImageList\(imageList' -or
    $source -notmatch 'ReleaseMainImageListUse\(imageList\)[\s\S]{0,240}iconResources\.ReleaseImageList\(imageList\)[\s\S]{0,180}IL_Destroy\(imageList\)' -or
    $shutdownApplicationUiSource -notmatch 'mainImageList\s*:=\s*Main\.appIcons[\s\S]*Main\.appIcons\s*:=\s*0[\s\S]*Main\.lv\.SetImageList\(0, 1\)[\s\S]*RetireMainImageList\(mainImageList\)' -or
    $applicationSearchSource -notmatch 'AcquireImageListUse\(\)[\s\S]{0,420}App\.iconResources\.AcquireImageList\(this\.imageList' -or
    $applicationSearchSource -notmatch 'RetireImageList\(imageList\)[\s\S]{0,260}App\.iconResources\.RetireImageList\(imageList, this\.imageList\)' -or
    $applicationSearchSource -notmatch 'imageList\s*:=\s*this\.imageList[\s\S]{0,360}this\.DestroyGui\(\)[\s\S]{0,100}this\.RetireImageList\(imageList\)' -or
    $applicationSearchSource -notmatch 'ReleaseImageListUse\(imageList\)[\s\S]{0,300}App\.iconResources\.ReleaseImageList\(imageList\)[\s\S]{0,180}IL_Destroy\(imageList\)' -or
    $applicationSearchSource -match 'activeImageListUsers|retiredImageLists') {
    $failures.Add('Attached image lists must be detached or outlive their native ListView controls')
}
foreach ($uiShutdownHook in @(
    'ShutdownApplicationUi(*)',
    'SetTimer(UpdateCountdownUI, 0)',
    'App.iconResources.CancelDpiRebuild()',
    'GuiModules.Shutdown()',
    'App.fileScanner.Shutdown()',
    'RetireMainImageList(mainImageList)',
    'this.addItem.Shutdown()',
    'this.log.Close()',
    'this.tooltip.Close()'
)) {
    if (-not $source.Contains($uiShutdownHook)) {
        $failures.Add("Missing application UI shutdown hook: $uiShutdownHook")
    }
}
foreach ($iconRegistryHook in @(
    'class IconResourceRegistry',
    'ReplaceWindowIcons(hwnd, iconPair)',
    'TakeWindowIcons(hwnd)',
    'AcquireImageList(imageList, activeImageList)',
    'ReleaseImageList(imageList)',
    'RetireImageList(imageList, activeImageList)',
    'InstallResamplerFactory(factory)',
    'TakeResamplerFactory()',
    'UpdateMainIconMetrics(dpi)',
    'CreateDpiRebuildRequest(expectedDpi, rebuildCallback)',
    'AcceptDpiRebuild(generation)',
    'IsDpiRebuildCurrent(generation)',
    'CancelDpiRebuild()'
)) {
    if (-not $iconResourceRegistrySource.Contains($iconRegistryHook)) {
        $failures.Add("Missing icon-resource ownership boundary: $iconRegistryHook")
    }
}
if ($source -notmatch '#Include src\\UI\\IconResourceRegistry\.ahk' -or
    $source -notmatch 'this\.iconResources\s*:=\s*IconResourceRegistry\(\)') {
    $failures.Add('ApplicationState must own one icon-resource registry')
}
foreach ($legacyIconField in @(
    'iconCache',
    'mainImageListUsers',
    'retiredMainImageLists',
    'iconHandles',
    'iconResamplerFactory',
    'mainIconPixelSize',
    'mainIconCellPixelSize',
    'mainDpi',
    'dpiRebuildTimer'
)) {
    if ($source -match "\b(?:App\.|this\.)$legacyIconField\b") {
        $failures.Add("Legacy icon-resource field remains: $legacyIconField")
    }
}
if ($source -notmatch 'MainDpiChanged\([^)]*\)[\s\S]{0,600}CreateDpiRebuildRequest\(newDpi,[\s\S]{0,300}PreviousTimer[\s\S]{0,220}SetTimer\(rebuildRequest\.Timer, -250\)' -or
    $source -notmatch 'RebuildMainImageList\(rebuildGeneration, expectedDpi,[\s\S]{0,220}AcceptDpiRebuild\(rebuildGeneration\)[\s\S]{0,900}IsDpiRebuildCurrent\(rebuildGeneration\)') {
    $failures.Add('DPI icon rebuilding must reject stale delayed callbacks by generation')
}
if ($mainSource -notmatch 'RefreshMainWindowDisplay\(\)[\s\S]{0,500}Main\.lv\.SetFont\([^\r\n]+\)[\s\S]{0,120}RefreshMainStatusIconAlignment\(\)' -or
    $mainVisualPipelineSource -notmatch 'RefreshMainStatusIconAlignment\(\)[\s\S]{0,1800}ImageList_ReplaceIcon' -or
    $mainVisualPipelineSource -notmatch 'RefreshMainStatusIconAlignment\(\)[\s\S]{0,2600}Win32\.LVM_GETIMAGELIST[\s\S]{0,260}Main\.lv\.SetImageList\(imageList, 1\)' -or
    $mainVisualPipelineSource -notmatch 'CreateMainImageList\(statusIconIndices\)[\s\S]{0,1200}try AddMainStatusIcons\(imageList, statusIconIndices\)[\s\S]{0,180}catch\s*\{[\s\S]{0,120}statusIconIndices\.Clear\(\)[\s\S]{0,180}try AddMainAdminOverlayIcon\(imageList\)' -or
    $mainVisualPipelineSource -match 'throw Error\("无法创建管理员运行盾牌图标"\)' -or
    $mainSource -match 'RefreshMainWindowDisplay\(\)[\s\S]{0,700}(?:CreateMainImageList|ScheduleMainImageListRebuild)') {
    $failures.Add('Font hot-switch must preserve and repair the active image-list binding, while optional status or overlay failures keep application icons available')
}
foreach ($resourceShutdownHook in @(
    'ShutdownApplicationResources(*)',
    'AcquireApplicationMutex(&alreadyExists := false)',
    'ReleaseApplicationMutex()',
    'CloseHandle", "Ptr", App.mutexHandle',
    'App.mutexHandle := 0',
    'ReleaseWindowIcons(A_ScriptHwnd)'
)) {
    if (-not $source.Contains($resourceShutdownHook)) {
        $failures.Add("Missing application resource shutdown hook: $resourceShutdownHook")
    }
}
$reloadStart = $source.IndexOf('ReloadScript(*) {', [System.StringComparison]::Ordinal)
$reloadEnd = if ($reloadStart -ge 0) {
    $source.IndexOf('ExitProgram(*) {', $reloadStart, [System.StringComparison]::Ordinal)
} else {
    -1
}
$reloadSource = if ($reloadStart -ge 0 -and $reloadEnd -gt $reloadStart) {
    $source.Substring($reloadStart, $reloadEnd - $reloadStart)
} else {
    ''
}
$reloadValidation = $reloadSource.IndexOf('BuildReloadValidationCommand(', [System.StringComparison]::Ordinal)
$reloadWait = $reloadSource.IndexOf('RunWait(', [System.StringComparison]::Ordinal)
$reloadMarker = $reloadSource.IndexOf('WriteValue("Settings", "ShowAfterReload", 1)', [System.StringComparison]::Ordinal)
$reloadHandoff = $reloadSource.IndexOf('BuildReloadHandoffCommand(', [System.StringComparison]::Ordinal)
$reloadLaunch = $reloadSource.IndexOf('Run(handoffCommand', [System.StringComparison]::Ordinal)
$reloadCatch = $reloadSource.IndexOf('} catch as reloadErr {', [System.StringComparison]::Ordinal)
$reloadShutdown = $reloadSource.LastIndexOf('ShutdownApplication()', [System.StringComparison]::Ordinal)
$reloadExit = $reloadSource.LastIndexOf('ExitApp()', [System.StringComparison]::Ordinal)
if ($reloadValidation -lt 0 -or
    $reloadWait -le $reloadValidation -or
    $reloadMarker -le $reloadWait -or
    $reloadHandoff -le $reloadMarker -or
    $reloadLaunch -le $reloadHandoff -or
    $reloadCatch -le $reloadLaunch -or
    $reloadShutdown -le $reloadCatch -or
    $reloadExit -le $reloadShutdown -or
    -not $reloadSource.Contains('Critical("On")') -or
    -not $reloadSource.Contains('reloadMarkerWritten := false') -or
    -not $reloadSource.Contains('App.reloadInProgress := true') -or
    $reloadSource.Contains('ReleaseApplicationMutex()') -or
    $reloadSource.Contains('ShutdownApplicationResources()')) {
    $failures.Add('Reload must validate first and hand off the mutex without an unlocked live-instance window')
}
if ($source -notmatch 'BuildReloadValidationCommand\(interpreterPath, scriptPath\)\s*\{[\s\S]{0,180}QuoteCommandLineArgument\(interpreterPath\)\s*\.\s*" /ErrorStdOut "\s*\.\s*QuoteCommandLineArgument\(scriptPath\)\s*\.\s*" --startup-validation"' -or
    $source -notmatch 'BuildReloadHandoffCommand\(currentPid, compiled, interpreterPath, scriptPath\)\s*\{[\s\S]{0,420}QuoteCommandLineArgument\(interpreterPath\)\s*\.\s*" "\s*\.\s*QuoteCommandLineArgument\(scriptPath\)\s*\.\s*" --reload-handoff "\s*\.\s*currentPid') {
    $failures.Add('Reload command builders must use explicit concatenation across line breaks')
}
if ($source -notmatch 'startupHandoffPid\s*:=\s*GetReloadHandoffPid\(\)[\s\S]{0,120}ProcessWaitClose\(startupHandoffPid, 60\)[\s\S]{0,160}AcquireApplicationMutex\(&startupMutexExists\)' -or
    $source -notmatch 'ProcessMaintenanceCommandClient\(\)[\s\S]{0,180}--startup-validation[\s\S]{0,60}ExitApplication\(0\)') {
    $failures.Add('Reload receiver must wait for the prior PID and validation mode must exit before startup')
}
if ($mainSource -notmatch 'existingWindowSelector\s*:=\s*"ahk_id " existingWindow[\s\S]{0,220}try WinShow\(existingWindowSelector\)[\s\S]{0,100}try WinRestore\(existingWindowSelector\)[\s\S]{0,100}try WinActivate\(existingWindowSelector\)' -or
    $mainSource -match '(?m)^\s*(?:try\s+)?Win(?:Show|Restore|Activate)\(\)') {
    $failures.Add('Single-instance activation must target the discovered HWND explicitly and tolerate reload races')
}
$maintenanceClientStart = $source.IndexOf('ProcessMaintenanceCommandClient() {', [System.StringComparison]::Ordinal)
$maintenanceClientEnd = if ($maintenanceClientStart -ge 0) {
    $source.IndexOf('SendMaintenanceCopyData(', $maintenanceClientStart, [System.StringComparison]::Ordinal)
} else {
    -1
}
$maintenanceClientSource = if ($maintenanceClientStart -ge 0 -and
    $maintenanceClientEnd -gt $maintenanceClientStart) {
    $source.Substring($maintenanceClientStart,
        $maintenanceClientEnd - $maintenanceClientStart)
} else {
    ''
}
if ([regex]::Matches($maintenanceClientSource, 'ExitApplication\(').Count -ne 5 -or
    $maintenanceClientSource -match '\bExitApp\(' -or
    $source -notmatch 'ExitApplication\(exitCode := 0\)\s*\{[\s\S]{0,220}ShutdownApplication\(\)[\s\S]{0,80}ExitApp\(exitCode\)') {
    $failures.Add('Maintenance command modes must clean up explicitly before ExitApp')
}
if ([regex]::Matches($source, '(?m)^OnExit\s*\(').Count -ne 1 -or
    $source -notmatch '(?m)^OnExit\(ShutdownApplication\)\s*$') {
    $failures.Add('Application shutdown must use exactly one OnExit registration')
}
if ($source -notmatch 'OnExit\(ShutdownApplication\)\s*\r?\n\s*if ProcessMaintenanceCommandClient\(\)') {
    $failures.Add('Shutdown registration must execute before startup validation can exit')
}
if ($source -notmatch 'ShutdownApplication\(\*\)\s*\{[\s\S]{0,220}App\.shutdownStarted[\s\S]{0,260}App\.guardRuntime\.Shutdown\(\)[\s\S]{0,260}ShutdownApplicationUi\(\)[\s\S]{0,180}ShutdownRoundedButtonRenderer\(\)[\s\S]{0,180}ShutdownIconResampler\(\)[\s\S]{0,180}ShutdownApplicationResources\(\)[\s\S]{0,180}App\.shutdownCompleted\s*:=\s*true') {
    $failures.Add('The single shutdown coordinator must explicitly preserve cleanup order')
}
if ($source -match 'OnExit\([^\r\n]*,\s*(?:-100|50|100)\s*\)' -or
    $guardRuntimeSource -match '\bExitHandler\b') {
    $failures.Add('Legacy multi-hook shutdown priority state must not remain')
}

# 直接文件目标只能由完整内容身份触发，并必须复用可撤销的路径迁移事务。
# 文件名、目录通知和 Windows 文件 ID 都不能重新成为迁移证据。
if (-not $mainSource.Contains('#Include src\Core\TargetContentRelocationService.ahk') -or
    -not $mainSource.Contains('#Include app\Windows\TargetRelocationPrompt.ahk') -or
    -not $targetRelocationServiceSource.Contains('class TargetRelocationService') -or
    -not $targetRelocationServiceSource.Contains('"ContentHash"') -or
    -not $targetRelocationServiceSource.Contains('StartContentScan.Call(rootPath,') -or
    -not $targetRelocationServiceSource.Contains('signature.ContentHash == currentCandidate.NewContentHash') -or
    -not $targetRelocationServiceSource.Contains('"VersionedEntryUnique"') -or
    -not $targetRelocationServiceSource.Contains('升级期间检测到唯一同名新版本入口，等待用户确认：{1} -> {2}') -or
    -not $targetRelocationServiceSource.Contains('TryDetectVersionedUpgrade(path, stateObj)') -or
    -not $targetRelocationServiceSource.Contains('IsMaintenanceBusy(path, stateObj)') -or
    -not $targetRelocationServiceSource.Contains('this.Callbacks.IsMaintenanceProtectionEnabled.Call(path,') -or
    -not $source.Contains('IsMaintenanceProtectionEnabled: ObjBindMethod(') -or
    -not $targetRelocationServiceSource.Contains('stateObj.Generation != currentCandidate.Generation') -or
    -not $targetFileInspectorSource.Contains('BCryptFinishHash') -or
    -not $fileScanServiceSource.Contains('--content-match-worker') -or
    -not $fileScanServiceSource.Contains('Everything_SetSearchW') -or
    -not $fileScanServiceSource.Contains('QueryEverythingCandidates(rootPath,') -or
    -not $fileScanServiceSource.Contains('IsPathWithinRoot(candidatePath, rootPath)') -or
    -not $fileScanServiceSource.Contains('IsRelocationCandidatePathAllowed(candidatePath)') -or
    -not $fileScanServiceSource.Contains('\appdata\roaming\code\user\history\') -or
    -not $fileScanServiceSource.Contains('\$recycle.bin\') -or
    -not $fileScanServiceSource.Contains('CandidateExclusionRoots') -or
    -not $targetRelocationServiceSource.Contains('completedRootIndex == 1') -or
    -not $targetRelocationServiceSource.Contains('useEverything := currentRootIndex > 1') -or
    -not $targetContentRelocationTestSource.Contains('最近有效目录中的唯一内容候选没有优先于远端相同副本') -or
    -not $targetContentRelocationTestSource.Contains('确认期间被替换的版本目录候选仍被视为有效') -or
    -not $targetContentRelocationTestSource.Contains('多个同名版本入口没有暂停自动迁移') -or
    -not $fileScanServiceTestSource.Contains('VS Code 历史、版本库或缓存副本仍参与内容迁移候选计数') -or
    -not $source.Contains('PrepareWatchPathTransition(previousPath, requestedPath)') -or
    -not $source.Contains('PrepareWatchPathTransitionFromState(previousPath, requestedPath,') -or
    -not $source.Contains('ApplyWatchPathTransition(previousPath, requestedPath,') -or
    -not $source.Contains('ApplyWatchPathTransition(previousPath, newPath, "edit-path", true)') -or
    $source -notmatch 'ApplyWatchPathTransition\(candidate\.OldPath,\s*candidate\.NewPath,\s*"relocate-path"\)' -or
    $source -notmatch 'ApplyState\(transition\.TargetState,\s*transition\.BeforeState,\s*true,\s*preserveInlineEditSession\)\s*App\.appConfigHistoryService\.Commit' -or
    -not $source.Contains('if selectedBefore {') -or
    -not $source.Contains('migratedRow := FindRow(transition.NewPath)') -or
    -not $targetRelocationPromptSource.Contains('class TargetRelocationPrompt extends ManagedWindow') -or
    -not $targetRelocationPromptSource.Contains('内容完全一致 / SHA-256') -or
    -not $targetRelocationPromptSource.Contains('唯一同名新版本入口 / SHA-256') -or
    -not $targetRelocationPromptSource.Contains('升级期间发现唯一同名新版本入口；已记录并持续校验候选 SHA-256') -or
    -not $source.Contains('this.targetRelocation := TargetRelocationPrompt(mainGui)')) {
    $failures.Add('Moved direct targets must use SHA-256 content identity, background candidate scanning, a confirmed shared migration transaction, and managed-window lifecycle')
}
if ($source -notmatch 'ApplyState\(stateArr, sourceStateArr := "", rollbackOnFailure := true,\s*preserveInlineEditSession := false\)' -or
    $source -notmatch 'if !preserveInlineEditSession \{\s*App\.editSessionId\+\+\s*App\.batchEditRows := \[\]') {
    $failures.Add('Successful inline path edits must preserve and advance the remaining multi-selection edit session')
}
if ($source -notmatch 'hEdit\s*:=\s*SendMessage\(0x1018,[^\r\n]*\)[\s\S]{0,160}if hEdit \{[\s\S]{0,260}SetDarkControl\(hEdit\)[\s\S]{0,180}DarkInlineEditThemeRegistry\.Register\(hEdit, GuiCtrlObj\.Hwnd\)' -or
    [regex]::Matches($source, 'DarkInlineEditThemeRegistry\.Unregister\(').Count -lt 2 -or
    -not $mainSource.Contains('#Include app\UI\DarkInlineEditThemeRegistry.ahk') -or
    -not $darkInlineEditThemeRegistrySource.Contains('class DarkInlineEditThemeRegistry') -or
    -not $darkInlineEditThemeRegistrySource.Contains('CallbackCreate(') -or
    -not $darkInlineEditThemeRegistrySource.Contains('SetWindowSubclass') -or
    -not $darkInlineEditThemeRegistrySource.Contains('RemoveWindowSubclass') -or
    -not $darkInlineEditThemeRegistrySource.Contains('DefSubclassProc') -or
    -not $darkInlineEditThemeRegistrySource.Contains('case 0x0133') -or
    -not $darkInlineEditThemeRegistrySource.Contains('HandleEditColor(hListView, deviceContext, editHwnd)') -or
    $darkInlineEditThemeRegistrySource.Contains('OnMessage(0x0133') -or
    -not $darkInlineEditThemeRegistrySource.Contains('UiThemeService.Color("Input")') -or
    -not $mainSource.Contains('DarkInlineEditThemeRegistry.Refresh(App.activeInlineEditHwnd)') -or
    $mainSource -notmatch 'if \(wParam == 113\)[\s\S]{0,360}TriggerEdit\(Main\.lv, row\)[\s\S]{0,240}return 0' -or
    -not $inlineEditThemeTestSource.Contains('user32\PostMessageW') -or
    -not $inlineEditThemeTestSource.Contains('InlineEditThemeTestF2Count == 1') -or
    -not $inlineEditThemeTestSource.Contains('F2 被 ListView 重复处理并替换了已主题化的编辑框') -or
    -not $inlineEditThemeTestSource.Contains('user32\SendMessageW') -or
    -not $inlineEditThemeTestSource.Contains('"UInt", 0x0133') -or
    -not $inlineEditThemeTestSource.Contains('SetDarkControl(editHwnd)') -or
    $inlineEditThemeTestSource.Contains('DarkInlineEditThemeRegistry.HandleEditColor(') -or
    -not $inlineEditThemeTestSource.Contains('INLINE_EDIT_THEME|PASS') -or
    -not $guiTestRunnerSource.Contains('gui\inline-edit-theme-tests.ahk')) {
    $failures.Add('Native ListView path editing must use and test the active dark input palette throughout its lifecycle')
}
if ($targetRelocationServiceSource -match 'FileIdentity|ResolveIdentityPath|RenameEvent|ProcessRenameEvents' -or
    $targetRelocationServiceSource -match '(?i)similar.*name|same.*name') {
    $failures.Add('Moved-target recovery must not depend on file IDs, rename listeners, or similar file names')
}

if ($failures.Count) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "Static checks passed: $($appKeys.Count) apps, $($maintenanceKeys.Count) maintenance configurations, $($displayKeys.Count) display customizations."
