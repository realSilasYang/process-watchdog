$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Get-ChildItem -LiteralPath $projectRoot -Filter '*.ahk' -File |
    Where-Object { $_.Name -notlike '_*' } |
    Select-Object -First 1 -ExpandProperty FullName
$iniPath = Join-Path $projectRoot 'watchdog.ini'
$source = Get-Content -LiteralPath $sourcePath -Raw -Encoding UTF8
$iniText = Get-Content -LiteralPath $iniPath -Raw -Encoding Unicode
$iniLines = Get-Content -LiteralPath $iniPath -Encoding Unicode

$failures = [System.Collections.Generic.List[string]]::new()

if ($iniLines.Count -eq 0 -or $iniLines[0] -ne '[Settings]') {
    $failures.Add('watchdog.ini documentation must stay with its sections instead of a top-level block')
}

$rootGlobals = [regex]::Matches($source, '(?m)^global\s+([A-Za-z_][A-Za-z0-9_]*)\s*:=' ) |
    ForEach-Object { $_.Groups[1].Value }
$expectedGlobals = @('App', 'Main', 'GuiModules')
if (($rootGlobals -join ',') -ne ($expectedGlobals -join ',')) {
    $failures.Add("Root globals must be App, Main, GuiModules; found: $($rootGlobals -join ', ')")
}

foreach ($sectionName in @('Settings', 'Layout', 'Apps', 'Maintenance')) {
    $headerIndex = [Array]::IndexOf($iniLines, "[$sectionName]")
    if ($headerIndex -lt 0 -or $headerIndex + 1 -ge $iniLines.Count -or
        -not $iniLines[$headerIndex + 1].StartsWith(';')) {
        $failures.Add("watchdog.ini section $sectionName must begin with documentation comments")
    }
}

if ($source -notmatch 'EnsureManagedIniSectionComments\(tempPath\)') {
    $failures.Add('Dynamic INI sections must restore their documentation after being rewritten')
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
        $failures.Add("watchdog.ini key $currentIniSection/$($line.Split('=', 2)[0]) must have an adjacent comment")
    }
}

$forbiddenSymbols = @(
    'SmoothScroll',
    'ScrollListViewByWheel',
    'WM_PRINTCLIENT',
    'MaintenanceBeforeFingerprint',
    'MaintenanceStableSince',
    'AutoSuspendReason',
    'pendingMaintenanceCommand(?!s)'
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
    'ResolvePersistentButtonPressedColor',
    'ResolveButtonFeedbackPressedColor'
)) {
    if (-not $source.Contains($feedbackSymbol)) {
        $failures.Add("Missing lifecycle-aware button feedback: $feedbackSymbol")
    }
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
        $fieldCount = ($value -split '\|', -1).Count
        if ($fieldCount -notin 8, 9) {
            $failures.Add("$key has $fieldCount fields; expected 8 (migratable) or 9 (current)")
        }
    }
    elseif ($section -eq 'Maintenance') {
        [void]$maintenanceKeys.Add($key)
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

if ($failures.Count) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "Static checks passed: $($appKeys.Count) apps, $($maintenanceKeys.Count) maintenance configurations."
