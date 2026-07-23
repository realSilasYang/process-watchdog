[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PackageDirectory
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$packageRoot = [System.IO.Path]::GetFullPath($PackageDirectory)
if (-not (Test-Path -LiteralPath $packageRoot -PathType Container)) {
    throw "Release package directory does not exist: $packageRoot"
}
$version = (Get-Content -LiteralPath (Join-Path $projectRoot 'VERSION') `
    -Raw -Encoding UTF8).Trim()
$mainScript = Get-ChildItem -LiteralPath $projectRoot -Filter '*.ahk' -File |
    Where-Object { $_.Name -notlike '_*' } |
    Select-Object -First 1
if (-not $mainScript) {
    throw 'Main AutoHotkey source was not found.'
}
$requiredPaths = @(
    'VERSION',
    'LICENSE',
    'THIRD_PARTY_NOTICES.md',
    'SBOM.spdx.json',
    'build-manifest.json',
    'watchdog.example.ini',
    'assets\status-icons\running.svg',
    'third_party\dependencies.lock.json',
    'third_party\resvg\resvg.dll',
    'third_party\everything\Everything64.dll',
    'docs\quick-start.md',
    'docs\troubleshooting.md'
)
foreach ($relativePath in $requiredPaths) {
    if (-not (Test-Path -LiteralPath (Join-Path $packageRoot $relativePath))) {
        throw "Release package is missing: $relativePath"
    }
}
foreach ($forbiddenPath in @('watchdog.ini', 'watchdog.maintenance.ini')) {
    if (Test-Path -LiteralPath (Join-Path $packageRoot $forbiddenPath)) {
        throw "Release package contains local runtime state: $forbiddenPath"
    }
}

$executables = @(Get-ChildItem -LiteralPath $packageRoot -File -Filter '*.exe')
if ($executables.Count -ne 1) {
    throw "Release package must contain exactly one root executable; found $($executables.Count)."
}
$executable = $executables[0]
if ($executable.VersionInfo.FileVersion -ne "$version.0" -or
    $executable.VersionInfo.ProductVersion -ne "$version.0") {
    throw "Executable version metadata does not match VERSION $version."
}
$manifest = Get-Content -LiteralPath `
    (Join-Path $packageRoot 'build-manifest.json') -Raw -Encoding UTF8 |
    ConvertFrom-Json
if ($manifest.schemaVersion -ne 1 -or
    $manifest.version -ne $version -or
    $manifest.platform -ne 'windows-x64' -or
    $manifest.sourceEntry -cne $mainScript.Name -or
    $executable.BaseName -cne $mainScript.BaseName) {
    throw 'Release build manifest is inconsistent.'
}
$sbom = Get-Content -LiteralPath (Join-Path $packageRoot 'SBOM.spdx.json') `
    -Raw -Encoding UTF8 | ConvertFrom-Json
if ($sbom.spdxVersion -ne 'SPDX-2.3' -or $sbom.packages.Count -ne 3) {
    throw 'Release SPDX SBOM is invalid or incomplete.'
}

$dependencyLock = Get-Content -LiteralPath `
    (Join-Path $packageRoot 'third_party\dependencies.lock.json') `
    -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($dependency in $dependencyLock.dependencies) {
    $path = Join-Path $packageRoot `
        ([string]$dependency.path -replace '/', '\')
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
    if ($hash -ne $dependency.sha256) {
        throw "Packaged dependency hash mismatch: $($dependency.name)"
    }
}

Write-Host "Release package verification passed for $version."
