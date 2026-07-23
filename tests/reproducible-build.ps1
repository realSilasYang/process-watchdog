[CmdletBinding()]
param(
    [string]$AutoHotkeyPath = "",
    [string]$CompilerPath = "",
    [string]$OutputDirectory = ""
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildScript = Join-Path $projectRoot 'tools\build-release.ps1'
$outputRoot = if ($OutputDirectory) {
    [System.IO.Path]::GetFullPath($OutputDirectory)
} else {
    Join-Path $projectRoot 'artifacts\release'
}

$first = & $buildScript -OutputDirectory $outputRoot `
    -AutoHotkeyPath $AutoHotkeyPath -CompilerPath $CompilerPath
$firstHash = $first.Sha256
$second = & $buildScript -OutputDirectory $outputRoot `
    -AutoHotkeyPath $AutoHotkeyPath -CompilerPath $CompilerPath
$secondHash = $second.Sha256
if ($firstHash -ne $secondHash) {
    throw "Release build is not reproducible: $firstHash != $secondHash"
}
$checksumLine = (Get-Content -LiteralPath $second.ChecksumsPath `
    -Raw -Encoding ASCII).Trim()
if (-not $checksumLine.StartsWith($secondHash + '  ')) {
    throw 'SHA256SUMS.txt does not match the release archive.'
}
& (Join-Path $projectRoot 'tools\verify-release.ps1') `
    -PackageDirectory $second.PackageDirectory

Write-Host "Reproducible release hash: $secondHash"
