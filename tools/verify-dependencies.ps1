[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$lockPath = Join-Path $projectRoot 'third_party\dependencies.lock.json'
$lock = Get-Content -LiteralPath $lockPath -Raw -Encoding UTF8 |
    ConvertFrom-Json
if ($lock.schemaVersion -ne 1 -or -not $lock.dependencies.Count) {
    throw 'Third-party dependency lock file is invalid or empty.'
}

foreach ($dependency in $lock.dependencies) {
    $relativePath = [string]$dependency.path
    if ([System.IO.Path]::IsPathRooted($relativePath) -or
        $relativePath.Contains('..')) {
        throw "Dependency path must stay inside the repository: $relativePath"
    }
    $path = Join-Path $projectRoot ($relativePath -replace '/', '\')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing dependency: $($dependency.name) at $relativePath"
    }
    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
    if ($actualHash -ne $dependency.sha256) {
        throw "Dependency hash mismatch: $($dependency.name) ($actualHash)"
    }
    $bytes = [System.IO.File]::ReadAllBytes($path)
    if ($bytes.Length -lt 256) {
        throw "Dependency is not a complete PE file: $($dependency.name)"
    }
    $peOffset = [BitConverter]::ToInt32($bytes, 0x3C)
    if ($peOffset -lt 0 -or $peOffset + 6 -gt $bytes.Length -or
        [BitConverter]::ToUInt16($bytes, $peOffset + 4) -ne 0x8664) {
        throw "Dependency is not x86-64: $($dependency.name)"
    }
    if (-not $dependency.source -or -not $dependency.licenses.Count) {
        throw "Dependency provenance is incomplete: $($dependency.name)"
    }
    Write-Host "Verified $($dependency.name) $($dependency.version)."
}
