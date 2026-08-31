# 可复现构建检查。
# 在隔离目录中连续构建两次发行物并比较哈希，定位时间戳、文件顺序或环境依赖造成的差异。

[CmdletBinding()]
param(
    [string]$AutoHotkeyPath = "",
    [string]$CompilerPath = "",
    [string]$AutoHotkeySourcePath = "",
    [string]$ResolvedToolchainPath = "",
    [string]$OutputDirectory = "",
    [string]$SecondPowerShellPath = ""
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildScript = Join-Path $projectRoot 'tools\build-release.ps1'
$removeOutputRoot = -not $OutputDirectory
$outputRoot = if (-not $removeOutputRoot) {
    [System.IO.Path]::GetFullPath($OutputDirectory)
} else {
    $tempRoot = [System.IO.Path]::GetFullPath(
        [System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    $candidate = Join-Path $tempRoot `
        ('ProcessWatchdogReproducibleBuild-' + [Guid]::NewGuid().ToString('N'))
    $fullCandidate = [System.IO.Path]::GetFullPath($candidate)
    if (-not $fullCandidate.StartsWith($tempRoot,
            [System.StringComparison]::OrdinalIgnoreCase) -or
        -not ([System.IO.Path]::GetFileName($fullCandidate)).StartsWith(
            'ProcessWatchdogReproducibleBuild-',
            [System.StringComparison]::Ordinal)) {
        throw "可复现构建目录不在受控临时目录中：$fullCandidate"
    }
    $fullCandidate
}

try {
    if (-not $AutoHotkeyPath -or -not $CompilerPath -or
        -not $AutoHotkeySourcePath -or -not $ResolvedToolchainPath) {
        $toolchain = & (Join-Path $projectRoot `
            'tools\bootstrap-toolchain.ps1')
        if (-not $AutoHotkeyPath) { $AutoHotkeyPath = $toolchain.AutoHotkeyPath }
        if (-not $CompilerPath) { $CompilerPath = $toolchain.CompilerPath }
        if (-not $AutoHotkeySourcePath) {
            $AutoHotkeySourcePath = $toolchain.AutoHotkeySourcePath
        }
        if (-not $ResolvedToolchainPath) {
            $ResolvedToolchainPath = $toolchain.ResolvedToolchainPath
        }
    }

    $first = & $buildScript -OutputDirectory $outputRoot `
    -AutoHotkeyPath $AutoHotkeyPath -CompilerPath $CompilerPath `
    -AutoHotkeySourcePath $AutoHotkeySourcePath `
    -ResolvedToolchainPath $ResolvedToolchainPath
$firstHash = $first.Sha256
$firstSourceHash = $first.SourceSha256
$firstFontHash = $first.FontSha256
$firstSbomHash = $first.SbomSha256
if ($SecondPowerShellPath) {
    $secondArguments = @(
        '-NoLogo', '-NoProfile', '-NonInteractive',
        '-ExecutionPolicy', 'Bypass', '-File', $buildScript,
        '-OutputDirectory', $outputRoot,
        '-AutoHotkeyPath', $AutoHotkeyPath,
        '-CompilerPath', $CompilerPath,
        '-AutoHotkeySourcePath', $AutoHotkeySourcePath,
        '-ResolvedToolchainPath', $ResolvedToolchainPath
    )
    & $SecondPowerShellPath @secondArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Second-runtime release build failed with exit code $LASTEXITCODE."
    }
    $version = (Get-Content -LiteralPath (Join-Path $projectRoot 'VERSION') `
        -Raw -Encoding UTF8).Trim()
    $packageName = "process-watchdog-$version-windows-x64"
    $sourceName = "process-watchdog-$version-source"
    $fontName = "fonts"
    $second = [pscustomobject]@{
        PackageDirectory = Join-Path $outputRoot $packageName
        ZipPath = Join-Path $outputRoot "$packageName.zip"
        SourcePackageDirectory = Join-Path $outputRoot $sourceName
        SourceZipPath = Join-Path $outputRoot "$sourceName.zip"
        FontPackageDirectory = Join-Path $outputRoot $fontName
        FontZipPath = Join-Path $outputRoot "$fontName.zip"
        SbomPath = Join-Path $outputRoot "$packageName.spdx.json"
        ChecksumsPath = Join-Path $outputRoot 'SHA256SUMS.txt'
    }
    $secondHash = (Get-FileHash -Algorithm SHA256 `
        -LiteralPath $second.ZipPath).Hash
    $secondSourceHash = (Get-FileHash -Algorithm SHA256 `
        -LiteralPath $second.SourceZipPath).Hash
    $secondFontHash = (Get-FileHash -Algorithm SHA256 `
        -LiteralPath $second.FontZipPath).Hash
    $secondSbomHash = (Get-FileHash -Algorithm SHA256 `
        -LiteralPath $second.SbomPath).Hash
} else {
    $second = & $buildScript -OutputDirectory $outputRoot `
        -AutoHotkeyPath $AutoHotkeyPath -CompilerPath $CompilerPath `
        -AutoHotkeySourcePath $AutoHotkeySourcePath `
        -ResolvedToolchainPath $ResolvedToolchainPath
    $secondHash = $second.Sha256
    $secondSourceHash = $second.SourceSha256
    $secondFontHash = $second.FontSha256
    $secondSbomHash = $second.SbomSha256
}
if ($firstHash -ne $secondHash) {
    throw "Release build is not reproducible: $firstHash != $secondHash"
}
if ($firstSbomHash -ne $secondSbomHash) {
    throw "Release SBOM is not reproducible: $firstSbomHash != $secondSbomHash"
}
if ($firstSourceHash -ne $secondSourceHash) {
    throw "Source release build is not reproducible: $firstSourceHash != $secondSourceHash"
}
if ($firstFontHash -ne $secondFontHash) {
    throw "Optional font package is not reproducible: $firstFontHash != $secondFontHash"
}
$obsoleteSingleFilePath = [System.IO.Path]::ChangeExtension($second.ZipPath, '.exe')
if (Test-Path -LiteralPath $obsoleteSingleFilePath) {
    throw "Obsolete one-file artifact remains after release build: $obsoleteSingleFilePath"
}
$expectedChecksums = @{
    ([System.IO.Path]::GetFileName($second.ZipPath)) = $secondHash
    ([System.IO.Path]::GetFileName($second.SourceZipPath)) = $secondSourceHash
    ([System.IO.Path]::GetFileName($second.FontZipPath)) = $secondFontHash
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
    -PackageDirectory $second.PackageDirectory `
    -SourcePackageDirectory $second.SourcePackageDirectory `
    -FontPackageDirectory $second.FontPackageDirectory `
    -ResolvedToolchainPath $ResolvedToolchainPath

Write-Host "Reproducible release ZIP hash: $secondHash"
Write-Host "Reproducible source ZIP hash: $secondSourceHash"
Write-Host "Reproducible optional font ZIP hash: $secondFontHash"
    Write-Host "Reproducible release SBOM hash: $secondSbomHash"
} finally {
    if ($removeOutputRoot -and (Test-Path -LiteralPath $outputRoot)) {
        Remove-Item -LiteralPath $outputRoot -Recurse -Force
    }
}
