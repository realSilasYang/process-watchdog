[CmdletBinding()]
param(
    [string]$AutoHotkeyPath = "",
    [string]$CompilerPath = "",
    [string]$AutoHotkeySourcePath = "",
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
    -AutoHotkeyPath $AutoHotkeyPath -CompilerPath $CompilerPath `
    -AutoHotkeySourcePath $AutoHotkeySourcePath
$firstHash = $first.Sha256
$firstSbomHash = $first.SbomSha256
$second = & $buildScript -OutputDirectory $outputRoot `
    -AutoHotkeyPath $AutoHotkeyPath -CompilerPath $CompilerPath `
    -AutoHotkeySourcePath $AutoHotkeySourcePath
$secondHash = $second.Sha256
$secondSbomHash = $second.SbomSha256
if ($firstHash -ne $secondHash) {
    throw "Release build is not reproducible: $firstHash != $secondHash"
}
if ($firstSbomHash -ne $secondSbomHash) {
    throw "Release SBOM is not reproducible: $firstSbomHash != $secondSbomHash"
}
$expectedChecksums = @{
    ([System.IO.Path]::GetFileName($second.ZipPath)) = $secondHash
    ([System.IO.Path]::GetFileName($second.SbomPath)) = $secondSbomHash
}
$checksumLines = @(Get-Content -LiteralPath $second.ChecksumsPath `
    -Encoding ASCII | Where-Object { $_ -ne '' })
if ($checksumLines.Count -ne $expectedChecksums.Count) {
    throw 'SHA256SUMS.txt does not contain the complete release inventory.'
}
foreach ($checksumLine in $checksumLines) {
    if ($checksumLine -notmatch '^([0-9A-F]{64})  (.+)$') {
        throw "Invalid SHA256SUMS.txt record: $checksumLine"
    }
    $fileName = $Matches[2]
    if (-not $expectedChecksums.ContainsKey($fileName) -or
        $expectedChecksums[$fileName] -ne $Matches[1]) {
        throw "SHA256SUMS.txt does not match the release artifact: $fileName"
    }
}
& (Join-Path $projectRoot 'tools\verify-release.ps1') `
    -PackageDirectory $second.PackageDirectory

Write-Host "Reproducible release ZIP hash: $secondHash"
Write-Host "Reproducible release SBOM hash: $secondSbomHash"
