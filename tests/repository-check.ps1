[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$requiredFiles = @(
    'LICENSE',
    'CHANGELOG.md',
    'CONTRIBUTING.md',
    'CODE_OF_CONDUCT.md',
    'SECURITY.md',
    'SUPPORT.md',
    'GOVERNANCE.md',
    'THIRD_PARTY_NOTICES.md',
    'VERSION',
    'watchdog.example.ini',
    '.editorconfig',
    '.mailmap',
    '.github\CODEOWNERS',
    'app\ApplicationState.ahk',
    'app\RuntimeAdapters.ahk',
    'app\WatchlistCommands.ahk',
    'app\UI\InteractionPresenter.ahk',
    'app\UI\MainVisualPipeline.ahk',
    '.github\workflows\ci.yml',
    '.github\workflows\release.yml',
    '.github\workflows\soak.yml',
    'third_party\dependencies.lock.json',
    'tools\toolchain.lock.json',
    'tools\generate-sbom.ps1',
    'tools\verify-release.ps1',
    'tests\verify-workflows.ps1'
    'tests\verify-publication.ps1'
    'docs\publication-checklist.md'
)
foreach ($relativePath in $requiredFiles) {
    $path = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required repository file is missing: $relativePath"
    }
}

$trackedFiles = @(git -C $projectRoot ls-files)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to inspect tracked repository files.'
}
$trackedNormalized = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase)
foreach ($trackedFile in $trackedFiles) {
    [void]$trackedNormalized.Add(($trackedFile -replace '/', '\'))
}
foreach ($relativePath in $requiredFiles) {
    if (-not $trackedNormalized.Contains($relativePath)) {
        throw "Required repository file is not tracked: $relativePath"
    }
}
foreach ($prefix in @('src\', 'app\', 'tests\core\', 'assets\', 'third_party\')) {
    $diskFiles = Get-ChildItem -LiteralPath (Join-Path $projectRoot `
        $prefix.TrimEnd('\')) -Recurse -File
    foreach ($file in $diskFiles) {
        $relativePath = $file.FullName.Substring($projectRoot.Length + 1)
        if (-not $trackedNormalized.Contains($relativePath)) {
            throw "Project input is not tracked: $relativePath"
        }
    }
}
if ($trackedNormalized.Contains('watchdog.ini')) {
    throw 'The local runtime watchdog.ini must not be tracked.'
}
if (Test-Path -LiteralPath (Join-Path $projectRoot 'Everything64.dll')) {
    throw 'Everything64.dll must only exist under third_party.'
}
if (Get-ChildItem -LiteralPath $projectRoot -File -Filter '_codex_*') {
    throw 'Temporary Codex probe files must not remain at the repository root.'
}

$version = (Get-Content -LiteralPath (Join-Path $projectRoot 'VERSION') `
    -Raw -Encoding UTF8).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') {
    throw "VERSION is not semantic version text: $version"
}
$mainScripts = @(Get-ChildItem -LiteralPath $projectRoot -File `
    -Filter '*.ahk' | Where-Object { $_.Name -notlike '_*' })
if ($mainScripts.Count -ne 1) {
    throw "Repository must contain exactly one root entry script; found $($mainScripts.Count)."
}
$mainScript = $mainScripts[0]
$source = Get-Content -LiteralPath $mainScript.FullName -Raw -Encoding UTF8
$applicationTelemetrySource = Get-Content -LiteralPath (Join-Path `
    $projectRoot 'app\ApplicationTelemetry.ahk') -Raw -Encoding UTF8
$mainLineCount = (Get-Content -LiteralPath $mainScript.FullName `
    -Encoding UTF8).Count
if ($mainLineCount -gt 1600) {
    throw "Composition root grew beyond 1600 lines: $mainLineCount"
}
foreach ($appModule in Get-ChildItem -LiteralPath (Join-Path $projectRoot 'app') `
    -Recurse -File -Filter '*.ahk') {
    $relativePath = $appModule.FullName.Substring($projectRoot.Length + 1)
    if (-not $source.Contains("#Include $relativePath")) {
        throw "Application module is not included by the composition root: $relativePath"
    }
}
$fileVersion = "$version.0"
if ($source -notmatch ('(?m)^;@Ahk2Exe-SetVersion\s+' +
        [regex]::Escape($fileVersion) + '$')) {
    throw "Compiled file version does not match VERSION: $fileVersion"
}
if ($applicationTelemetrySource -notmatch
        'FileGetVersion\(A_ScriptFullPath\)' -or
    $applicationTelemetrySource -notmatch 'return "unknown"' -or
    $applicationTelemetrySource -match 'return "\d+\.\d+\.\d+"') {
    throw 'Runtime version fallback must use compiled metadata without a duplicated release literal.'
}

$examplePath = Join-Path $projectRoot 'watchdog.example.ini'
$exampleBytes = [System.IO.File]::ReadAllBytes($examplePath)
if ($exampleBytes.Length -lt 2 -or $exampleBytes[0] -ne 0xFF -or
    $exampleBytes[1] -ne 0xFE) {
    throw 'watchdog.example.ini must be UTF-16 LE with BOM.'
}

$allText = Get-ChildItem -LiteralPath $projectRoot -Recurse -File |
    Where-Object {
        $_.FullName -notmatch '\\.git\\|\\third_party\\.*\.(dll|h)$' -and
        $_.Extension -in @('.md', '.ps1', '.yml', '.yaml', '.json', '.ahk')
    } | ForEach-Object {
        try { Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 }
        catch { '' }
    }
$repositoryPlaceholder = 'OWNER' + '/REPOSITORY'
if (($allText -join "`n").Contains($repositoryPlaceholder)) {
    throw 'Repository documentation contains an unresolved hosting placeholder.'
}

$toolLockPath = Join-Path $projectRoot 'tools\toolchain.lock.json'
$toolLock = Get-Content -LiteralPath $toolLockPath -Raw -Encoding UTF8 |
    ConvertFrom-Json
if ($toolLock.schemaVersion -ne 1) {
    throw 'Toolchain lock schema is invalid.'
}
foreach ($toolName in @('autoHotkey', 'ahk2Exe', 'actionlint', 'gitleaks')) {
    $definition = $toolLock.tools.$toolName
    foreach ($propertyName in @('version', 'archive', 'url', 'sha256',
            'executable', 'executableSha256', 'licenseExpression',
            'sbomRelationship')) {
        if ($definition.PSObject.Properties.Name -notcontains $propertyName -or
            -not $definition.$propertyName) {
            throw "Toolchain lock is missing $toolName.$propertyName."
        }
    }
    foreach ($hashProperty in @('sha256', 'executableSha256')) {
        if ($definition.$hashProperty -notmatch '^[0-9A-F]{64}$') {
            throw "Toolchain lock hash is invalid: $toolName.$hashProperty"
        }
    }
    if ($definition.PSObject.Properties.Name -contains 'licenseFile') {
        foreach ($propertyName in @('licenseFile', 'licenseSha256')) {
            if ($definition.PSObject.Properties.Name `
                    -notcontains $propertyName -or
                -not $definition.$propertyName) {
                throw "Toolchain lock is missing $toolName.$propertyName."
            }
        }
        if ($definition.licenseSha256 -notmatch '^[0-9A-F]{64}$') {
            throw "Toolchain license hash is invalid: $toolName"
        }
    }
}
$autoHotkeyDefinition = $toolLock.tools.autoHotkey
if ($autoHotkeyDefinition.sbomRelationship -ne 'DEPENDS_ON') {
    throw 'AutoHotkey must be recorded as an application runtime dependency.'
}
foreach ($propertyName in @('sourceCommit', 'sourceArchive', 'sourceUrl',
        'sourceSha256')) {
    if ($autoHotkeyDefinition.PSObject.Properties.Name `
            -notcontains $propertyName -or
        -not $autoHotkeyDefinition.$propertyName) {
        throw "Toolchain lock is missing autoHotkey.$propertyName."
    }
}
if ($autoHotkeyDefinition.sourceCommit -notmatch '^[0-9a-f]{40}$' -or
    $autoHotkeyDefinition.sourceSha256 -notmatch '^[0-9A-F]{64}$') {
    throw 'Pinned AutoHotkey source provenance is invalid.'
}

$workflowFiles = Get-ChildItem -LiteralPath `
    (Join-Path $projectRoot '.github\workflows') -File -Filter '*.yml'
foreach ($workflowFile in $workflowFiles) {
    $workflowLines = Get-Content -LiteralPath $workflowFile.FullName `
        -Encoding UTF8
    foreach ($workflowLine in $workflowLines) {
        if ($workflowLine -notmatch '^\s*uses:\s*([^\s#]+)') {
            continue
        }
        $actionReference = $Matches[1]
        if ($actionReference.StartsWith('./')) {
            continue
        }
        if ($actionReference -notmatch '@[0-9a-f]{40}$') {
            throw "Workflow action is not pinned to a commit SHA: $actionReference"
        }
    }
}

$releaseWorkflow = Get-Content -LiteralPath `
    (Join-Path $projectRoot '.github\workflows\release.yml') `
    -Raw -Encoding UTF8
foreach ($releaseRequirement in @(
        '.\tests\run-gui-tests.ps1',
        '.\tests\reproducible-build.ps1',
        '-GitleaksPath',
        '-AutoHotkeySourcePath',
        'actions/attest-build-provenance@',
        'artifacts/release/*.spdx.json')) {
    if (-not $releaseWorkflow.Contains($releaseRequirement)) {
        throw "Release workflow is missing: $releaseRequirement"
    }
}

foreach ($workflowName in @('ci.yml', 'release.yml')) {
    $workflowText = Get-Content -LiteralPath (Join-Path $projectRoot `
        ".github\workflows\$workflowName") -Raw -Encoding UTF8
    if ($workflowText -notmatch '(?m)^\s+fetch-depth:\s+0\s*$') {
        throw "$workflowName must fetch the complete Git history."
    }
}

Write-Host "Repository checks passed for version $version."
