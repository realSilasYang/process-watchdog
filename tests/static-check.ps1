$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Get-ChildItem -LiteralPath $projectRoot -Filter '*.ahk' -File |
    Where-Object { $_.Name -notlike '_*' } |
    Select-Object -First 1 -ExpandProperty FullName
$iniPath = Join-Path $projectRoot 'watchdog.example.ini'
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
$source = $mainSource + "`n" + $appModuleSource
$iniFieldCodecSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Config\IniFieldCodec.ahk') -Raw -Encoding UTF8
$displayConfigCodecSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Config\DisplayConfigCodec.ahk') -Raw -Encoding UTF8
$maintenanceConfigCodecSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Config\MaintenanceConfigCodec.ahk') -Raw -Encoding UTF8
$appConfigSnapshotServiceSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Config\AppConfigSnapshotService.ahk') -Raw -Encoding UTF8
$runtimeSettingsServiceSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Config\RuntimeSettingsService.ahk') -Raw -Encoding UTF8
$windowLayoutServiceSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Config\WindowLayoutService.ahk') -Raw -Encoding UTF8
$watchlistPersistenceServiceSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Config\WatchlistPersistenceService.ahk') -Raw -Encoding UTF8
$configRepositorySource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Config\WatchdogConfigRepository.ahk') -Raw -Encoding UTF8
$guardTypesSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Core\GuardTypes.ahk') -Raw -Encoding UTF8
$guardStateMachineSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Core\GuardStateMachine.ahk') -Raw -Encoding UTF8
$guardWorkGateSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Core\GuardWorkGate.ahk') -Raw -Encoding UTF8
$schedulerSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Core\WatchdogScheduler.ahk') -Raw -Encoding UTF8
$restartPolicySource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Core\RestartPolicy.ahk') -Raw -Encoding UTF8
$targetSupervisorSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Core\TargetSupervisor.ahk') -Raw -Encoding UTF8
$targetSpecsSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Core\TargetSpecs.ahk') -Raw -Encoding UTF8
$targetSpecsServiceSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Core\TargetSpecsService.ahk') -Raw -Encoding UTF8
$targetIdentityServiceSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Core\TargetIdentityService.ahk') -Raw -Encoding UTF8
$appConfigHistoryServiceSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Core\AppConfigHistoryService.ahk') -Raw -Encoding UTF8
$guardRuntimeSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Core\GuardRuntime.ahk') -Raw -Encoding UTF8
$targetLauncherSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\Execution\TargetLauncher.ahk') -Raw -Encoding UTF8
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
$mainListProjectionSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\UI\MainListProjection.ahk') -Raw -Encoding UTF8
$windowHierarchySource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\UI\WindowHierarchy.ahk') -Raw -Encoding UTF8
$managedWindowSource = Get-Content -LiteralPath (Join-Path $projectRoot 'src\UI\ManagedWindow.ahk') -Raw -Encoding UTF8
$coreTestRunnerSource = Get-Content -LiteralPath (Join-Path $projectRoot 'tests\run-core-tests.ps1') -Raw -Encoding UTF8
$readmeSource = Get-Content -LiteralPath (Join-Path $projectRoot 'README.md') -Raw -Encoding UTF8
$allModuleSource = (Get-ChildItem -LiteralPath (Join-Path $projectRoot 'src') -Recurse -Filter '*.ahk' -File |
    ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 }) -join "`n"
$iniText = Get-Content -LiteralPath $iniPath -Raw -Encoding Unicode
$iniLines = Get-Content -LiteralPath $iniPath -Encoding Unicode

$failures = New-Object 'System.Collections.Generic.List[string]'

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
        ForEach-Object { $_.Value }) -join ' | '
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
if ($source -notmatch 'SetCurrentProcessExplicitAppUserModelID",\s*"WStr",\s*"\u8FDB\u7A0B\u5B88\u62A4\u5C0F\u52A9\u624B"') {
    $failures.Add('Notification AppUserModelID must use the stable Chinese application name')
}
if ($source -match 'ProcessWatchdog_\s*"?\s*\.\s*A_ScriptHwnd') {
    $failures.Add('Notification AppUserModelID must not contain a per-process window handle')
}

if ($iniLines.Count -eq 0 -or $iniLines[0] -ne '[Settings]') {
    $failures.Add('watchdog.example.ini documentation must stay with its sections instead of a top-level block')
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
    $source -notmatch 'ShutdownApplicationResources\(\*\)[\s\S]{0,180}App\.svgRenderer\.Shutdown\(\)') {
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
        $failures.Add("watchdog.example.ini section $sectionName must begin with documentation comments")
    }
}
$displayHeaderIndex = [Array]::IndexOf($iniLines, '[Display]')
if ($displayHeaderIndex -ge 0 -and
    ($displayHeaderIndex + 1 -ge $iniLines.Count -or
        -not $iniLines[$displayHeaderIndex + 1].StartsWith(';'))) {
    $failures.Add('watchdog.example.ini section Display must begin with documentation comments when present')
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
        $failures.Add("watchdog.example.ini key $currentIniSection/$($line.Split('=', 2)[0]) must have an adjacent comment")
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
    'GetImagePath(pid)',
    'GetCreationIdentity(pid)',
    'GetElevationState(pid)',
    'kernel32\CreateToolhelp32Snapshot',
    'Win32.PROCESS_QUERY_LIMITED_INFORMATION',
    'Win32.TOKEN_QUERY',
    'Win32.TOKEN_ELEVATION',
    'advapi32\OpenProcessToken',
    'advapi32\GetTokenInformation'
)) {
    if (-not $processInspectorSource.Contains($processInspectorHook)) {
        $failures.Add("Missing native process inspector hook: $processInspectorHook")
    }
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
if ($source -notmatch 'this\.configSaveRetryTimer\s*:=\s*ObjBindMethod\(this,[\s\S]{0,100}"RetryDirtyAppConfig"\)' -or
    $source -notmatch 'SaveAppsToIni\(\)[\s\S]{0,4000}App\.appsDirty\s*:=\s*false[\s\S]{0,300}SetTimer\(App\.configSaveRetryTimer, 0\)[\s\S]{0,1000}App\.appsDirty\s*:=\s*true[\s\S]{0,700}SetTimer\(App\.configSaveRetryTimer, -retryDelayMs\)' -or
    $source -notmatch 'ShutdownApplicationResources\(\*\)[\s\S]{0,200}App\.appsDirty[\s\S]{0,120}SaveAppsToIni\(\)') {
    $failures.Add('Dirty app configuration must retry with backoff and flush during shutdown')
}
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
if ($source -notmatch 'SaveAppsToIni\(\)[\s\S]{0,600}watchlistPersistenceService\.Save\(' -or
    $watchlistPersistenceServiceSource -notmatch 'Repository\.ReplaceSections\(') {
    $failures.Add('Monitoring configuration must commit through the repository')
}
if ($source -notmatch 'SaveAppsToIni\(\)[\s\S]{0,180}previousCritical\s*:=\s*A_IsCritical[\s\S]{0,100}Critical\("On"\)[\s\S]{0,6500}Critical\(previousCritical\s*\?\s*previousCritical\s*:\s*"Off"\)') {
    $failures.Add('Monitoring configuration snapshots must be captured and committed in one critical transaction')
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
foreach ($stopperHook in @(
    'class TargetStopStage',
    'class TargetStopResult',
    'class TargetStopper',
    'Stop(pid, gracefulWaitSeconds, ctrlCWaitSeconds, allowForceTerminate,',
    'WaitUntilStopped(pid, timeoutSeconds)',
    'return !ProcessWaitClose(pid, Max(0, timeoutSeconds))',
    'RequestWindowClose(pid)',
    'ProcessClose(pid)'
)) {
    if (-not $targetStopperSource.Contains($stopperHook)) {
        $failures.Add("Missing target stopper hook: $stopperHook")
    }
}
foreach ($executionOwnerHook in @(
    'this.targetLauncher := TargetLauncher()',
    'this.targetStopper := TargetStopper()'
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
    $source -notmatch 'this\.processSnapshots\.SnapshotPublishedCallback\s*:=\s*ObjBindMethod\([\s\S]{0,120}this\.maintenanceCoordinator,\s*"OnSnapshotPublished"\)') {
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
    $guardWorkGateSource -notmatch 'TryEnter\(\)[\s\S]{0,180}Critical\("On"\)[\s\S]{0,180}this\.Busy\s*:=\s*true' -or
    $guardWorkGateSource -notmatch 'finally[\s\S]{0,100}Critical\(previousCritical \? previousCritical : "Off"\)' -or
    $source -notmatch 'this\.guardWorkGate\s*:=\s*GuardWorkGate\(\)' -or
    $guardRuntimeSource -notmatch 'MonitorTick\(\)[\s\S]{0,180}this\.Runtime\.guardWorkGate\.TryEnter\(\)' -or
    $guardRuntimeSource -notmatch 'MonitorTick\(\)[\s\S]{0,18000}this\.Runtime\.guardWorkGate\.Leave\(\)' -or
    [regex]::Matches($maintenanceCoordinatorSource,
        'this\.Runtime\.guardWorkGate\.TryEnter\(\)').Count -lt 2 -or
    [regex]::Matches($maintenanceCoordinatorSource,
        'this\.Runtime\.guardWorkGate\.Leave\(\)').Count -lt 2) {
    $failures.Add('Main monitoring and both maintenance loops must share the explicit guard work gate')
}
if ($maintenanceCoordinatorSource -match 'TryEnterGuardGate|LeaveGuardGate') {
    $failures.Add('Maintenance coordinator must not wrap the shared guard work gate')
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
if ($guardRuntimeSource -notmatch 'Restart\(path,[\s\S]{0,900}guardWorkGate\.TryEnter\(\)[\s\S]{0,600}ScheduleRestartFor\(path, expectedSupervisor, 100\)[\s\S]{0,600}RestartCore\(' -or
    $guardRuntimeSource -notmatch 'Verify\(path,[\s\S]{0,900}guardWorkGate\.TryEnter\(\)[\s\S]{0,600}ScheduleVerificationFor\(path, expectedSupervisor, 100\)[\s\S]{0,600}VerifyCore\(' -or
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
if ($source -notmatch 'if\s+!App\.guardRuntime\.Start\(\)' -or
    $source -notmatch 'App\.guardRuntime\.RestartMonitorTimer\(\)') {
    $failures.Add('Guard runtime must own monitor startup, shutdown and interval changes')
}
if ($guardRuntimeSource -notmatch 'ObserveTarget\.Call\(path,[\s\S]{0,260}IsSupervisorCurrent\(path, stateObj,\s*observationGeneration\)') {
    $failures.Add('Monitor observations must revalidate controller ownership before mutation')
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
    'matcher\.Match\(processInfo,',
    'activeKnown\[identityKey\]\s*:=\s*actorRecord',
    'activeTransient\[identityKey\]\s*:=\s*actorRecord',
    'HasActiveActors\(stateObj\)[\s\S]{0,500}IsIdentityAlive\(',
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
if ($source -notmatch 'GracefulStop\(pid\)[\s\S]{0,320}App\.targetStopper\.Stop\(') {
    $failures.Add('GracefulStop must delegate process termination to TargetStopper')
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
if ($maintenanceCoordinatorSource -notmatch 'QueueCommand\(command\)[\s\S]{0,500}guardWorkGate\.TryEnter\(\)[\s\S]{0,500}guardWorkGate\.Leave\(\)' -or
    $maintenanceCoordinatorSource -notmatch 'EventTick\(\)[\s\S]{0,500}DrainPendingCommands\(\)') {
    $failures.Add('Explicit maintenance commands must serialize through the shared guard work gate')
}
if ($maintenanceCoordinatorSource -notmatch 'EndExplicit\(path\)[\s\S]{0,500}MaintenancePhase\.TimedOut[\s\S]{0,160}ResetSession\(path, stateObj, false\)[\s\S]{0,220}MaintenancePhase\.Stabilizing' -or
    $maintenanceStateMachineSource -notmatch 'MaintenancePhase\.Normal, Map\([\s\S]{0,240}MaintenancePhase\.Stabilizing, true') {
    $failures.Add('Explicit maintenance timeout must recover into stabilization')
}
if ($maintenanceCoordinatorSource -notmatch 'SaveJournal\(\)[\s\S]{0,500}previousCritical\s*:=\s*A_IsCritical[\s\S]{0,900}Critical\(previousCritical') {
    $failures.Add('Maintenance journal transactions must restore caller critical state')
}
if ($maintenanceCoordinatorSource -notmatch 'this\.JournalDirty\s*:=\s*true[\s\S]{0,300}this\.JournalRetryDelayMs\s*:=\s*Min\(' -or
    $maintenanceCoordinatorSource -notmatch 'EventTick\(\)[\s\S]{0,6000}this\.JournalDirty[\s\S]{0,180}this\.SaveJournal\(\)') {
    $failures.Add('Dirty maintenance journals must be retried by the existing event loop')
}
if ($maintenanceCoordinatorSource -notmatch 'StartTimers\(\)[\s\S]{0,500}eventTimerStarted\s*:=\s*true[\s\S]{0,260}catch[\s\S]{0,220}SetTimer\(this\.EventTimer, 0\)[\s\S]{0,140}SetTimer\(this\.ProcessTimer, 0\)' -or
    $maintenanceCoordinatorSource -notmatch 'Shutdown\(\*\)[\s\S]{0,260}try\s+SetTimer\(this\.EventTimer, 0\)[\s\S]{0,120}try\s+SetTimer\(this\.ProcessTimer, 0\)' -or
    $maintenanceCoordinatorSource -notmatch 'if\s+this\.Initialized\s*\r?\n\s*try\s+this\.SaveJournal\(\)') {
    $failures.Add('Maintenance timer startup and shutdown must be transactional and avoid uninitialized journal writes')
}
if ($source -notmatch 'App\.appStates\[path\]\s*:=\s*TargetSupervisor\(\{') {
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
if ($guardRuntimeSource -notmatch 'UpdateState\(path, expectedSupervisor, statusText\)[\s\S]{0,360}IsSupervisorCurrent\(path,\s*expectedSupervisor,[\s\S]{0,80}expectedGeneration\)[\s\S]{0,220}Callbacks\.UpdateState\.Call\(path, statusText,[\s\S]{0,100}expectedSupervisor, expectedGeneration\)' -or
    $maintenanceCoordinatorSource -notmatch 'UpdateState\(path, expectedSupervisor, statusText\)[\s\S]{0,420}Runtime\.appStates\[path\]\s*!=\s*expectedSupervisor[\s\S]{0,240}Callbacks\.UpdateState\.Call\(path, statusText,[\s\S]{0,80}expectedSupervisor\)' -or
    $source -notmatch 'UpdateState\(updPath, statusStr, expectedState := "",[\s\S]{0,80}expectedGeneration := 0\)[\s\S]{0,360}stateObj\s*!=\s*expectedState[\s\S]{0,180}stateObj\.Generation\s*!=\s*expectedGeneration') {
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
    'ObserveImagePath(targetPath)',
    'ObserveCommandTarget(targetPath)',
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
    'Start()',
    'Pump()',
    'RequestFresh()',
    'Stop(waitForExit := true)',
    'NextWorkerOutputPath(nowTicks := 0)',
    'WriteWorkerFile(outputPath, snapshotProvider)',
    'ReadWorkerResult(outputPath, &resultReady := false)',
    'outputText := "SNAPSHOT|" snapshot.Length',
    'this.WorkerCreationIdentity',
    'this.ResetWorkerState(true)',
    'outputPath ".writing"'
)) {
    if (-not $snapshotServiceSource.Contains($snapshotServiceHook)) {
        $failures.Add("Missing process snapshot service hook: $snapshotServiceHook")
    }
}
if ($snapshotServiceSource -notmatch 'ReadWorkerResult\(outputPath,[\s\S]{0,2400}snapshot\.Length\s*!=\s*expectedCount[\s\S]{0,120}resultReady\s*:=\s*true') {
    $failures.Add('Process snapshot results must reject partial or corrupt worker output')
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
    $snapshotServiceSource -notmatch 'Start\(\)[\s\S]{0,100}if\s+this\.Stopped[\s\S]{0,60}return\s+false') {
    $failures.Add('ProcessSnapshotService shutdown must be terminal and prevent worker restart')
}
if ($snapshotServiceSource -notmatch 'StoreSnapshot\([\s\S]{0,180}if\s+this\.Stopped\s*\|\|' -or
    $snapshotServiceSource -notmatch 'StoreNativeSnapshot\([\s\S]{0,120}if\s+this\.Stopped[\s\S]{0,60}return\s+false' -or
    $snapshotServiceSource -notmatch 'Start\(\)[\s\S]{0,900}this\.WorkerStarting\s*:=\s*true[\s\S]{0,1200}if\s+!this\.Stopped[\s\S]{0,500}accepted\s*:=\s*true[\s\S]{0,900}this\.WorkerStarting\s*:=\s*false[\s\S]{0,500}if\s+!accepted') {
    $failures.Add('Snapshot startup and publication must revalidate terminal shutdown after yielding to external work')
}
if ($snapshotServiceSource -notmatch 'CanTerminateWorker\(pid, expectedCreationIdentity\)[\s\S]{0,320}expectedCreationIdentity\s*==\s*""[\s\S]{0,220}currentCreationIdentity\s*!=\s*""[\s\S]{0,100}currentCreationIdentity\s*==\s*expectedCreationIdentity' -or
    $snapshotServiceSource -match 'WorkerCreationIdentity\s*==\s*""\s*\|\||currentCreation\s*==\s*""\s*\|\|') {
    $failures.Add('Snapshot workers may be terminated only after an exact non-empty creation-identity match')
}
if ($snapshotServiceSource -notmatch 'NextWorkerOutputPath\(nowTicks := 0\)[\s\S]{0,220}this\.WorkerSequence\+\+[\s\S]{0,180}this\.WorkerSequence "\.tmp"' -or
    $snapshotServiceSource -notmatch 'Start\(\)[\s\S]{0,900}this\.NextWorkerOutputPath\(nowTicks\)') {
    $failures.Add('Concurrent process snapshot workers must never reuse an output path within the same millisecond')
}
if ($fileScanServiceSource -notmatch 'Stop\(workerPid, outputPath, creationIdentity := ""\)[\s\S]{0,500}creationIdentity\s*!=\s*""[\s\S]{0,260}currentCreation\s*!=\s*""[\s\S]{0,80}currentCreation\s*==\s*creationIdentity' -or
    $fileScanServiceSource -match 'Stop\(workerPid, outputPath, creationIdentity := ""\)[\s\S]{0,500}creationIdentity\s*==\s*""\s*\|\|') {
    $failures.Add('File-scan workers may be terminated only after an exact non-empty creation-identity match')
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
    'Observe(probeSpec, snapshotIndex := "", maximumSnapshotAgeMs := 0)',
    'ObserveProcessName(processName)',
    'ObserveImagePath(targetPath, snapshotIndex := "")',
    'ObserveCommandTarget(targetPath, snapshotIndex := ""',
    'ObserveWorkingDirectory(workingDirectory, preferredName := ""',
    'snapshotIndex.ObserveCommandTarget(targetPath)',
    'snapshotIndex.ObserveImagePath(targetPath)'
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
if ($maintenanceCoordinatorSource -notmatch 'QueryNativeSnapshot\(&snapshotReady\)[\s\S]{0,260}this\.Runtime\.processInspector\.CaptureNativeSnapshot\(\)') {
    $failures.Add('Maintenance native snapshots must come from ProcessInspector')
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
if ($guardRuntimeSource -notmatch 'existingObservation\s*:=\s*this\.Callbacks\.ObserveTarget\.Call\(path,\s*"",\s*1000\)') {
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
if ($guardRuntimeSource -notmatch 'MonitorTick\(\)[\s\S]{0,12000}targetObservation\.IsUnknown\(\)[\s\S]{0,100}continue') {
    $failures.Add('Main monitoring must defer decisions for Unknown process observations')
}
if ($guardRuntimeSource -notmatch 'Restart\(path,[\s\S]{0,3000}existingObservation\.IsUnknown\(\)') {
    $failures.Add('Restart duplicate protection must defer launch for Unknown observations')
}
$runningStateMatch = [regex]::Match($source,
    '(?ms)^UpdateRunningState\(path, stateObj, expectedGeneration := 0\)\s*\{.*?^\}')
if (-not $runningStateMatch.Success -or
    $runningStateMatch.Value -notmatch 'IsRunAsAdminMismatch\(stateObj\)') {
    $failures.Add('Running-state projection must report a confirmed elevation mismatch')
}
elseif ($runningStateMatch.Value -match 'ScheduleRestart|ProcessClose|GracefulStop|DoRestart') {
    $failures.Add('An elevation mismatch must not stop or restart a running target automatically')
}
if ($source -notmatch 'ToggleRunAsAdmin\(\*\)[\s\S]{0,2200}UpdateRunningState\(path, stateObj,[\s\S]{0,80}stateObj\.Generation\)') {
    $failures.Add('Changing the administrator requirement must refresh a live item immediately')
}
$manualRestartMatch = [regex]::Match($source,
    '(?ms)^RestartSelectedApp\(\*\)\s*\{.*?(?=^/\*)')
if (-not $manualRestartMatch.Success) {
    $failures.Add('Unable to inspect the manual restart boundary')
}
else {
    $manualRestartSource = $manualRestartMatch.Value
    foreach ($manualRestartHook in @(
        'stateObj.CancelScheduledTasks()',
        'operationGeneration := stateObj.Generation',
        'GracefulStop(pid)',
        'App.guardRuntime.Restart(path)'
    )) {
        if (-not $manualRestartSource.Contains($manualRestartHook)) {
            $failures.Add("Manual restart is missing generation-safe execution hook: $manualRestartHook")
        }
    }
    if ([regex]::Matches($manualRestartSource,
        'App\.guardRuntime\.IsSupervisorCurrent\(').Count -lt 3) {
        $failures.Add('Manual restart must revalidate controller ownership after blocking operations')
    }
    if ($manualRestartSource -notmatch 'GracefulStop\(pid\)[\s\S]{0,300}App\.guardRuntime\.IsSupervisorCurrent\(') {
        $failures.Add('Manual process stop must revalidate controller generation before state mutation')
    }
    if ($manualRestartSource -match '(?m)\bRun\s*\(') {
        $failures.Add('Manual restart must not bypass execution services')
    }
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
if ($source -notmatch 'LV_ItemDrag\(ctrl, lParam\)[\s\S]{0,4200}SyncAppOrderFromListView\(\)[\s\S]{0,120}SaveAppsToIni\(\)') {
    $failures.Add('List drag reorder must synchronize and persist the visible order')
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
foreach ($projectionMutationHook in @(
    'Main.listProjection.Remember(path, row)',
    'Main.listProjection.Rebuild(ctrl)',
    'Main.listProjection.Rebuild(GuiCtrlObj)',
    'Main.listProjection.Rebuild(Main.lv)'
)) {
    if (-not $source.Contains($projectionMutationHook)) {
        $failures.Add("Missing main-list projection mutation hook: $projectionMutationHook")
    }
}
if ($appConfigSnapshotServiceSource -notmatch 'SnapshotsEqual\(first, second\)[\s\S]{0,1200}DisplayConfigCodec\.Equals\(first\.Display, second\.Display\)') {
    $failures.Add('Display customization must participate in undo snapshots')
}
if ($source -notmatch 'RegisterApp\(item\.Path,[\s\S]{0,350}item\.ShortcutArgs, item\.Display\)') {
    $failures.Add('Undo restore must recreate deleted items with their display customization')
}
foreach ($windowIsolationHook in @(
    'OnMessage(Win32.WM_SYSCOMMAND, OnManagedWindowSystemCommand)',
    'WindowHierarchy.MinimizeChildIndependently(hwnd)',
    '#Include src\UI\WindowHierarchy.ahk'
)) {
    if (-not $source.Contains($windowIsolationHook)) {
        $failures.Add("Missing independent child-window minimize hook: $windowIsolationHook")
    }
}
$independentMinimizeMatch = [regex]::Match($windowHierarchySource,
    '(?ms)^\s*static MinimizeChildIndependently\(childHwnd\)\s*\{.*?^\s*\}')
if (-not $independentMinimizeMatch.Success -or
    $windowHierarchySource -notmatch 'SetNativeOwner\(childHwnd, 0\)[\s\S]*?MinimizeWindow\(childHwnd\)[\s\S]*?SetNativeOwner\(childHwnd, ownerHwnd\)') {
    $failures.Add('Owned child minimization must detach, minimize only the child, and restore its owner')
}
foreach ($windowHierarchyBoundary in @(
    'class WindowHierarchyPlatform',
    'class WindowHierarchyManager',
    'class WindowHierarchy',
    'OwnerLocks := Map()',
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
    ($logWindowMatch.Value -notmatch 'RegisterButtonClick\(this\.exportButton' -or
        $logWindowMatch.Value -notmatch 'diagnosticBundleService\.Export\(' -or
        $logWindowMatch.Value -notmatch 'SetHoverButtonColors\(this\.exportButton' -or
        $logWindowMatch.Value -notmatch 'this\.exportButton\.Move\(\(Width - 120\) // 2, Height - 40, 120, 30\)')) {
    $failures.Add('The log window must expose the local diagnostic bundle export')
}

$applyStateMatch = [regex]::Match($source,
    '(?ms)^ApplyState\(stateArr, sourceStateArr := ""\)\s*\{.*?^\}\r?\n\r?\nSaveAppsToIni\(')
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
        'RestoreMainListInteraction(interaction)'
    )) {
        if (-not $applyStateSource.Contains($requiredDifferentialHook)) {
            $failures.Add("Undo/redo is missing differential restore hook: $requiredDifferentialHook")
        }
    }
}
if ($appConfigHistoryServiceSource -notmatch 'class\s+AppConfigHistoryService' -or
    $appConfigHistoryServiceSource -notmatch 'UndoEntries\.Push\(\{Before: beforeItems, After: afterItems\}\)' -or
    $source -notmatch 'appConfigHistoryService\.Commit\(beforeState, afterState\)') {
    $failures.Add('Undo records must retain both sides of the transition')
}
if ($source -match 'CommitUndoState\(\)') {
    $failures.Add('Undo entries must be committed after mutation with an explicit before-state')
}
if (($appConfigHistoryServiceSource -notmatch 'applyCallback\.Call\(entry\.Before, entry\.After\)') -or
    ($appConfigHistoryServiceSource -notmatch 'applyCallback\.Call\(entry\.After, entry\.Before\)') -or
    ($source -notmatch 'appConfigHistoryService\.Undo\(') -or
    ($source -notmatch 'appConfigHistoryService\.Redo\(')) {
    $failures.Add('Undo and redo must apply explicit reverse transitions')
}
if ($appConfigHistoryServiceSource -notmatch 'applyCallback\.Call\(entry\.Before, entry\.After\)[\s\S]{0,120}UndoEntries\.Pop\(\)' -or
    $appConfigHistoryServiceSource -notmatch 'applyCallback\.Call\(entry\.After, entry\.Before\)[\s\S]{0,120}RedoEntries\.Pop\(\)') {
    $failures.Add('Failed undo/redo application must leave its history entry available for retry')
}
if ($source -match '\b(?:undoStack|redoStack)\b') {
    $failures.Add('ApplicationState must delegate undo and redo stack ownership to AppConfigHistoryService')
}
if ($appConfigSnapshotServiceSource -notmatch 'MergeMaintenanceTransition\([\s\S]{0,3000}merged\.LearnedActors') {
    $failures.Add('Undo must preserve maintenance actors learned after the recorded action')
}
if ($source -notmatch 'if\s+addedCount\s*\{\s*CommitUndoState\(undoState\)') {
    $failures.Add('Drag-and-drop must create an undo entry only after at least one target is added')
}
if ($source -notmatch 'if\s+!this\.batchAddedCount\s*\r?\n\s*CommitUndoState\(firstSuccessfulSnapshot\)') {
    $failures.Add('Batch import must create one undo entry at its first successful addition')
}
if ($source -notmatch 'maintenanceConfigCodec\.Equals\(priorMaintenance,[\s\S]{0,600}this\.Close\(\)[\s\S]{0,80}return') {
    $failures.Add('Unchanged maintenance settings must close without creating an undo entry')
}
if ($source -notmatch 'if\s+!settingsChanged\s*\{[\s\S]{0,560}this\.Close\(\)[\s\S]{0,80}return') {
    $failures.Add('Unchanged runtime settings must close without creating an undo entry')
}
$allowedDirectClickBindings = @(
    'backgroundControl.OnEvent("Click", PlaceTextCaretAtPointer.Bind(inputControl))',
    'ctrl.OnEvent("Click", HandleRegisteredButtonClick)',
    'this.autoResolveCheck.OnEvent("Click", ObjBindMethod(this, "ToggleResolvedTargetMode"))'
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
    'TrayTip(App.configLoadWarnings.Length'
)) {
    if (-not ($watchlistPersistenceServiceSource.Contains($configDiagnosticHook) -or
        $source.Contains($configDiagnosticHook))) {
        $failures.Add("Missing actionable watchlist-load diagnostic: $configDiagnosticHook")
    }
}

$addItemDialogSource = [regex]::Match($source,
    '(?ms)^class AddItemDialog extends ManagedWindow\s*\{.*?(?=^class SettingsWindow extends ManagedWindow)').Value
$logWindowSource = [regex]::Match($source,
    '(?ms)^class LogWindow extends ManagedWindow\s*\{.*?(?=^class HelpWindow extends ManagedWindow)').Value
$logRefreshSource = [regex]::Match($logWindowSource,
    '(?ms)^    RefreshContent\(\*\)\s*\{.*?(?=^    RefreshContentCore\()').Value
$applicationSearchSource = [regex]::Match($source,
    '(?ms)^class ApplicationSearchDialog extends ManagedWindow\s*\{.*?(?=^class DarkTooltipWindow extends ManagedWindow)').Value
$darkTooltipSource = [regex]::Match($source,
    '(?ms)^class DarkTooltipWindow extends ManagedWindow\s*\{.*\z').Value
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
$batchCancelSource = [regex]::Match($addItemDialogSource,
    '(?ms)^    CancelBatchImport\(.*?\)\s*\{.*?(?=^    Confirm\()').Value
$everythingSearchSource = [regex]::Match($applicationSearchSource,
    '(?ms)^    SearchEverything\(\*\)\s*\{.*?(?=^    OnSearchChanged\()').Value
$nativeFilterSource = [regex]::Match($applicationSearchSource,
    '(?ms)^    FilterNativeList\(\*\)\s*\{.*?(?=^    Select\()').Value
$nativeScanPollSource = [regex]::Match($applicationSearchSource,
    '(?ms)^    PollNativeScan\(\*\)\s*\{.*?(?=^    ConsumeNativeScanBatch\()').Value
$nativeScanConsumeSource = [regex]::Match($applicationSearchSource,
    '(?ms)^    ConsumeNativeScanBatch\(\*\)\s*\{.*?(?=^    CancelNativeScan\()').Value
$nativeScanCancelSource = [regex]::Match($applicationSearchSource,
    '(?ms)^    CancelNativeScan\([^)]*\)\s*\{.*?(?=^    FailNativeScan\()').Value
if ($applicationSearchSource -notmatch 'third_party\\everything\\Everything64\.dll' -or
    $applicationSearchSource -notmatch 'LoadEverythingLibrary\(\)[\s\S]{0,1500}GetProcAddress' -or
    $everythingSearchSource -notmatch 'this\.everythingFunctions\["Everything_QueryW"\]' -or
    $applicationSearchSource -notmatch 'if \(this\.everythingAvailable && this\.SearchEverything\(\)\)[\s\S]{0,120}this\.LoadNativeApps\(\)' -or
    $applicationSearchSource -match 'everythingDllName|A_ScriptDir\s*"\\"\s*this\.everything') {
    $failures.Add('Everything must load only the pinned DLL by full path and preserve native-scan fallback')
}
$lifecycleBoundaries = @(
    @{Source = $guardRuntimeSource; Pattern = 'Shutdown\(\*\)[\s\S]{0,500}SetTimer\(this\.MonitorTimer, 0\)'; Name = 'guard monitor timer'},
    @{Source = $guardRuntimeSource; Pattern = 'Shutdown\(\*\)[\s\S]{0,900}this\.Runtime\.scheduler\.Shutdown\(\)'; Name = 'shared scheduler'},
    @{Source = $guardRuntimeSource; Pattern = 'Shutdown\(\*\)[\s\S]{0,1100}this\.Runtime\.maintenanceCoordinator\.Shutdown\(\)'; Name = 'maintenance coordinator'},
    @{Source = $addItemDialogSource; Pattern = 'Close\(\*\)[\s\S]{0,220}this\.CancelBatchImport\(false\)'; Name = 'batch import worker'},
    @{Source = $addItemDialogSource; Pattern = 'Shutdown\(\*\)[\s\S]{0,180}this\.search\.Shutdown\(\)'; Name = 'owned add-dialog child'},
    @{Source = $logWindowSource; Pattern = 'Close\(\*\)[\s\S]{0,160}SetTimer\(this\.refreshTimer, 0\)'; Name = 'log refresh timer'},
    @{Source = $applicationSearchSource; Pattern = 'Close\(\*\)[\s\S]{0,360}SetTimer\(this\.initialSearchTimer, 0\)[\s\S]{0,180}this\.CancelNativeScan\(\)'; Name = 'application search timers'},
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
    @{Source = $nativeScanPollSource; Name = 'native scan polling'},
    @{Source = $nativeScanConsumeSource; Name = 'native scan consumption'}
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
    @{Source = $everythingSearchSource; Control = 'this\.lv'; Name = 'Everything search'},
    @{Source = $nativeFilterSource; Control = 'this\.lv'; Name = 'native search filtering'}
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
    $batchCompleteSource -notmatch 'addedCount\s*:=\s*this\.batchAddedCount[\s\S]*?this\.batchAddedCount\s*:=\s*0[\s\S]*?this\.batchSessionId\+\+[\s\S]*?SaveAppsToIni\(\)' -or
    -not $batchCancelSource -or
    $batchCancelSource -notmatch 'addedCount\s*:=\s*this\.batchAddedCount[\s\S]*?this\.batchAddedCount\s*:=\s*0[\s\S]*?App\.fileScanner\.Stop\([\s\S]*?SaveAppsToIni\(\)') {
    $failures.Add('Completed or cancelled batch imports must persist partial additions and reset batch state')
}
if (-not $nativeScanCancelSource -or
    $nativeScanCancelSource -notmatch 'SetTimer\(this\.scanPollTimer, 0\)[\s\S]{0,160}SetTimer\(this\.scanConsumeTimer, 0\)' -or
    $nativeScanCancelSource -notmatch 'App\.fileScanner\.Stop\(' -or
    $nativeScanCancelSource -notmatch 'this\.pendingScanPaths\s*:=\s*\[\]') {
    $failures.Add('Native application scanning must have one timer, worker, and pending-result cleanup boundary')
}
if ($applicationSearchSource -notmatch 'this\.scanSessionId\s*:=\s*0' -or
    $applicationSearchSource -notmatch 'IsNativeScanCurrent\(sessionId\)[\s\S]{0,160}sessionId\s*==\s*this\.scanSessionId' -or
    $applicationSearchSource -notmatch 'LoadNativeApps\(\)[\s\S]{0,2200}accepted\s*:=\s*true[\s\S]{0,300}if\s+!accepted[\s\S]{0,180}App\.fileScanner\.Stop\(' -or
    $nativeScanCancelSource -notmatch 'this\.scanSessionId\+\+') {
    $failures.Add('Native search workers and callbacks must reject results from closed GUI sessions')
}
if (-not $nativeScanPollSource -or
    $nativeScanPollSource -notmatch 'catch\s+as\s+scanPollErr[\s\S]{0,160}this\.FailNativeScan\(' -or
    -not $nativeScanConsumeSource -or
    $nativeScanConsumeSource -notmatch 'catch\s+as\s+scanConsumeErr[\s\S]{0,160}this\.FailNativeScan\(') {
    $failures.Add('Native scan timer callbacks must stop and clear their worker state after exceptions')
}
if ($fileScanServiceSource -notmatch 'Start\(mode, rootPath, recursive, maximumResults, timeoutSeconds\)[\s\S]{0,1800}DeadlineTicks:\s*startedTicks\s*\+\s*timeoutSeconds\s*\*\s*1000\s*\+\s*5000' -or
    $batchPollSource -notmatch 'workerDeadlineTicks[\s\S]{0,420}GetTickCount64\(\)\s*>=\s*workerDeadlineTicks' -or
    $nativeScanPollSource -notmatch 'workerDeadlineTicks[\s\S]{0,420}GetTickCount64\(\)\s*>=\s*workerDeadlineTicks') {
    $failures.Add('File-scan polling must have a parent-side deadline even when PID identity becomes unavailable')
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
if ($addItemDialogSource -notmatch 'ReadFileDialogPath\([\s\S]{0,700}finally[\s\S]{0,220}CoTaskMemFree[\s\S]{0,160}ObjRelease') {
    $failures.Add('File-dialog raw shell resources must be released through one finally boundary')
}
if ($fileScanServiceSource -notmatch 'Start\(mode, rootPath, recursive, maximumResults, timeoutSeconds\)[\s\S]{0,180}static workerSequence\s*:=\s*0[\s\S]{0,300}Critical\("On"\)[\s\S]{0,220}currentWorkerSequence\s*:=\s*workerSequence[\s\S]{0,650}currentWorkerSequence[\s\S]{0,1600}if this\.Stopped[\s\S]{0,120}this\.Workers\[outputPath\]\s*:=\s*job[\s\S]{0,300}if rejectedAfterLaunch[\s\S]{0,120}this\.Stop\(job\.Pid, job\.Path, job\.CreationIdentity\)' -or
    $addItemDialogSource -notmatch 'seenRoots\s*:=\s*Map\(\)[\s\S]{0,260}!seenRoots\.Has\(canonicalRoot\)') {
    $failures.Add('Concurrent file scans must use unique output paths and deduplicate batch roots')
}
if ($fileScanServiceSource -notmatch 'Stop\(workerPid, outputPath, creationIdentity := ""\)[\s\S]{0,650}finally\s*\{[\s\S]{0,180}FileDelete\(outputPath\)[\s\S]{0,100}FileDelete\(outputPath "\.writing"\)' -or
    $fileScanServiceSource -notmatch 'Shutdown\(\*\)[\s\S]{0,650}this\.Workers\.Clear\(\)[\s\S]{0,300}this\.Stop\(job\.Pid, job\.Path, job\.CreationIdentity\)') {
    $failures.Add('File-scan output cleanup must run even when worker identity inspection fails')
}
if ($source -notmatch 'AcquireMainImageListUse\(imageList\)[\s\S]{0,180}iconResources\.AcquireMainImageList\(imageList' -or
    $source -notmatch 'ReleaseMainImageListUse\(imageList\)[\s\S]{0,240}iconResources\.ReleaseMainImageList\(imageList\)[\s\S]{0,180}IL_Destroy\(imageList\)' -or
    $source -notmatch 'ShutdownApplicationUi\(\*\)[\s\S]{0,650}Main\.appIcons\s*:=\s*0[\s\S]{0,180}Main\.lv\.SetImageList\(0, 1\)[\s\S]{0,180}RetireMainImageList\(mainImageList\)' -or
    $applicationSearchSource -notmatch 'AcquireImageListUse\(\)[\s\S]{0,300}this\.activeImageListUsers\+\+' -or
    $applicationSearchSource -notmatch 'RetireImageList\(imageList\)[\s\S]{0,320}this\.activeImageListUsers[\s\S]{0,180}this\.retiredImageLists\.Push\(imageList\)' -or
    $applicationSearchSource -notmatch 'imageList\s*:=\s*this\.imageList[\s\S]{0,180}this\.DestroyGui\(\)[\s\S]{0,100}this\.RetireImageList\(imageList\)' -or
    $applicationSearchSource -notmatch 'ReleaseImageListUse\(\)[\s\S]{0,700}ClearImageListIconCache\(imageList\)[\s\S]{0,100}IL_Destroy\(imageList\)') {
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
    'AcquireMainImageList(imageList, activeImageList)',
    'ReleaseMainImageList(imageList)',
    'RetireMainImageList(imageList, activeImageList)',
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
if ([regex]::Matches($maintenanceClientSource, 'ExitApplication\(').Count -ne 4 -or
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

if ($failures.Count) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "Static checks passed: $($appKeys.Count) apps, $($maintenanceKeys.Count) maintenance configurations, $($displayKeys.Count) display customizations."
