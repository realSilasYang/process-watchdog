# 当前生产结构的静态门禁。
# 升级保护已经移除；本脚本阻止其状态机、窗口、命令和配置重新进入运行时，
# 同时确认普通守护、内容迁移和小助手自身更新仍保留必要入口。

[CmdletBinding()]
param([switch]$SkipPackagedFontContentValidation)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$mainScript = Get-ChildItem -LiteralPath $projectRoot -Filter '*.ahk' -File |
    Where-Object { $_.Name -notlike '_*' } |
    Select-Object -First 1
if (-not $mainScript) {
    throw 'The main AutoHotkey script was not found.'
}

$productionFiles = @($mainScript) +
    @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'app') -Recurse `
        -Filter '*.ahk' -File) +
    @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'src') -Recurse `
        -Filter '*.ahk' -File | Where-Object {
            $_.FullName -notlike '*\src\Localization\*'
        })
$productionSource = ($productionFiles | ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
}) -join "`n"
$mainSource = Get-Content -LiteralPath $mainScript.FullName -Raw -Encoding UTF8
$guardRuntimeSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'src\Core\GuardRuntime.ahk') -Raw -Encoding UTF8
$relocationSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'src\Core\TargetContentRelocationService.ahk') `
    -Raw -Encoding UTF8
$applicationStateSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'app\ApplicationState.ahk') -Raw -Encoding UTF8
$runtimeAdaptersSource = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'app\RuntimeAdapters.ahk') -Raw -Encoding UTF8

$failures = [System.Collections.Generic.List[string]]::new()

foreach ($include in [regex]::Matches($mainSource,
        '(?m)^#Include\s+(?<Path>[^\r\n]+)$')) {
    $relativePath = $include.Groups['Path'].Value.Trim()
    $includedPath = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $includedPath -PathType Leaf)) {
        $failures.Add("Missing #Include target: $relativePath")
    }
}

$removedPaths = @(
    'src\Maintenance',
    'src\Config\MaintenanceConfigCodec.ahk',
    'app\Windows\MaintenanceSettingsDialog.ahk'
)
foreach ($relativePath in $removedPaths) {
    $removedPath = Join-Path $projectRoot $relativePath
    $hasRemovedCode = (Test-Path -LiteralPath $removedPath -PathType Leaf) -or
        ((Test-Path -LiteralPath $removedPath -PathType Container) -and
            @(Get-ChildItem -LiteralPath $removedPath -Force -File).Count -gt 0)
    if ($hasRemovedCode) {
        $failures.Add("Removed upgrade-protection path still exists: $relativePath")
    }
}

$removedRuntimePatterns = @(
    '\bMaintenance(?:Coordinator|Session|StateMachine|Reducer|Event|Evidence|EffectRunner|ObservationHub|ActorMatcher|ConfigCodec)\b',
    '\bMaintenancePhase\b',
    '\bMaintenanceMode\b',
    '\bSafeStartWait\b',
    '--maintenance-(?:begin|end)',
    '软件升级保护设置',
    '升级保护协调器'
)
foreach ($pattern in $removedRuntimePatterns) {
    if ($productionSource -match $pattern) {
        $failures.Add("Upgrade-protection runtime reference remains: $pattern")
    }
}

if ($mainSource -notmatch '(?m)^if ProcessWorkerCommandClient\(\)\s*$') {
    $failures.Add('Worker command dispatch must run before normal application startup.')
}
if ($applicationStateSource -notmatch '\bApplicationUpdateService\(' -or
    $mainSource -notmatch '#Include src\\Update\\ApplicationUpdateService\.ahk') {
    $failures.Add('The assistant self-update service must remain available.')
}
if ($relocationSource -notmatch '\bGetContentSignature\b' -or
    $relocationSource -notmatch '\bStartContentScan\b' -or
    $relocationSource -notmatch '\bContentHash\b') {
    $failures.Add('SHA-256 content relocation must remain available.')
}
if ($guardRuntimeSource -notmatch
    'ScheduleRestartFor\(path, stateObj,') {
    $failures.Add('Stopped targets must still enter the ordinary restart scheduler.')
}
if ($runtimeAdaptersSource -notmatch
    'RemoveObsoleteUpgradeState\([^)]*\)[\s\S]{0,700}watchdog\.maintenance\.ini' -or
    $runtimeAdaptersSource -notmatch '(?m)^\s*RemoveObsoleteUpgradeState\(\)\s*$') {
    $failures.Add('Legacy upgrade-state cleanup is missing.')
}

if ($productionSource -match '(?m)\bGetNext\([^\r\n]*,\s*"(?:S|Selected)"') {
    $failures.Add('Gui.ListView.GetNext uses an invalid selected-row option; omit the second parameter.')
}
if ($mainSource -notmatch 'Main\.lv\.OnNotify\(-101,\s*OnMainListItemChanged\)' -or
    $mainSource -notmatch 'ScheduleMainCommandStateRefresh\(\)' -or
    $mainSource -notmatch 'Main\.btnPause\.Text == expectedText') {
    $failures.Add('Main command state must refresh from the native ListView selection notification and repair stale pause text.')
}

$exampleConfigPath = Join-Path $projectRoot 'config\watchdog.example.ini'
if (Test-Path -LiteralPath $exampleConfigPath) {
    $exampleConfig = Get-Content -LiteralPath $exampleConfigPath -Raw `
        -Encoding Unicode
    if ($exampleConfig -match '(?im)^\[Maintenance\]\s*$') {
        $failures.Add('The example configuration still contains [Maintenance].')
    }
}

if ($failures.Count) {
    foreach ($failure in $failures) {
        Write-Error $failure
    }
    throw "Static checks failed: $($failures.Count) issue(s)."
}

Write-Host 'Static checks passed: upgrade protection is absent and core guard/update paths remain.'
