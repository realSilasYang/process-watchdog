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
    'THIRD_PARTY_NOTICES.md',
    'VERSION',
    'watchdog.example.ini',
    '.editorconfig',
    '.github\workflows\ci.yml',
    '.github\workflows\release.yml',
    '.github\workflows\soak.yml',
    'third_party\dependencies.lock.json',
    'tools\toolchain.lock.json',
    'tools\generate-sbom.ps1',
    'tools\verify-release.ps1'
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
$mainScript = Get-ChildItem -LiteralPath $projectRoot -File -Filter '*.ahk' |
    Select-Object -First 1
$source = Get-Content -LiteralPath $mainScript.FullName -Raw -Encoding UTF8
$fileVersion = "$version.0"
if ($source -notmatch ('(?m)^;@Ahk2Exe-SetVersion\s+' +
        [regex]::Escape($fileVersion) + '$')) {
    throw "Compiled file version does not match VERSION: $fileVersion"
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

Write-Host "Repository checks passed for version $version."
