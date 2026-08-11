# 从最新正式 GitHub Release 恢复由 LFS 跟踪的完整字体资源。当前字体清单始终是
# 权威来源：只恢复清单声明的字体字节，并在写入前后验证完整 SHA-256。

[CmdletBinding()]
param(
    [string]$Repository = "",
    [string]$ReleaseTag = "",
    [string]$DestinationRoot = "",
    [string]$MetadataPath = "",
    [string]$ArchivePath = "",
    [string]$CacheDirectory = ""
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $DestinationRoot) { $DestinationRoot = $projectRoot }
if (-not $MetadataPath) {
    $MetadataPath = Join-Path $projectRoot 'assets\fonts\metadata.json'
}
if (-not $CacheDirectory) {
    $CacheDirectory = Join-Path $projectRoot '.tools\font-assets'
}
if (-not $Repository) {
    $Repository = if ($env:GITHUB_REPOSITORY) {
        $env:GITHUB_REPOSITORY
    } else {
        'realSilasYang/process-watchdog'
    }
}

$destinationRootPath = [System.IO.Path]::GetFullPath($DestinationRoot)
$metadataFullPath = [System.IO.Path]::GetFullPath($MetadataPath)
if (-not (Test-Path -LiteralPath $destinationRootPath -PathType Container)) {
    throw "Font destination root does not exist: $destinationRootPath"
}
if (-not (Test-Path -LiteralPath $metadataFullPath -PathType Leaf)) {
    throw "Font metadata does not exist: $metadataFullPath"
}
$metadata = Get-Content -LiteralPath $metadataFullPath -Raw -Encoding UTF8 |
    ConvertFrom-Json
if ($metadata.schemaVersion -ne 1 -or -not $metadata.fonts -or
    $metadata.fonts.Count -eq 0) {
    throw 'Font metadata schema is invalid or contains no fonts.'
}

$fontRecords = @()
$destinationPrefix = $destinationRootPath.TrimEnd('\') + '\'
foreach ($font in $metadata.fonts) {
    $relativePath = [string]$font.path
    $expectedHash = ([string]$font.sha256).ToUpperInvariant()
    if ($relativePath -notmatch '^assets/fonts/[^/\\]+\.(?:ttc|ttf|otf)$' -or
        $expectedHash -notmatch '^[0-9A-F]{64}$') {
        throw "Font metadata entry is invalid: $relativePath"
    }
    $destinationPath = [System.IO.Path]::GetFullPath(
        (Join-Path $destinationRootPath ($relativePath -replace '/', '\')))
    if (-not $destinationPath.StartsWith($destinationPrefix,
            [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Font destination escaped the repository root: $relativePath"
    }
    $fontRecords += [pscustomobject]@{
        RelativePath = $relativePath
        ExpectedHash = $expectedHash
        DestinationPath = $destinationPath
    }
}

function Test-FontRecordSet {
    param([object[]]$Records, [string]$RootPath)

    $rootPrefix = [System.IO.Path]::GetFullPath($RootPath).TrimEnd('\') + '\'
    foreach ($record in $Records) {
        $candidate = [System.IO.Path]::GetFullPath(
            (Join-Path $RootPath ($record.RelativePath -replace '/', '\')))
        if (-not $candidate.StartsWith($rootPrefix,
                [System.StringComparison]::OrdinalIgnoreCase) -or
            -not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $false
        }
        if ((Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash -ne
            $record.ExpectedHash) {
            return $false
        }
    }
    return $true
}

if (Test-FontRecordSet $fontRecords $destinationRootPath) {
    Write-Host 'Packaged font assets already match metadata.'
    return
}

$cachePath = [System.IO.Path]::GetFullPath($CacheDirectory)
New-Item -ItemType Directory -Force -Path $cachePath | Out-Null
$resolvedArchivePath = if ($ArchivePath) {
    [System.IO.Path]::GetFullPath($ArchivePath)
} else {
    Join-Path $cachePath 'fonts.zip'
}

function Download-FontArchive {
    if ($ArchivePath) {
        throw "Provided font archive does not match metadata: $resolvedArchivePath"
    }
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) {
        throw 'GitHub CLI is required to restore fonts from a Release.'
    }
    $arguments = @('release', 'download')
    if ($ReleaseTag) { $arguments += $ReleaseTag }
    $arguments += @('--repo', $Repository, '--pattern', 'fonts.zip',
        '--dir', $cachePath, '--clobber')
    & $gh.Source @arguments
    if ($LASTEXITCODE -ne 0 -or
        -not (Test-Path -LiteralPath $resolvedArchivePath -PathType Leaf)) {
        throw "Unable to download fonts.zip from $Repository."
    }
}

if (-not (Test-Path -LiteralPath $resolvedArchivePath -PathType Leaf)) {
    Download-FontArchive
}

$scratchRoot = Join-Path $projectRoot `
    ('.build\font-restore-' + [Guid]::NewGuid().ToString('N'))
$projectPrefix = [System.IO.Path]::GetFullPath($projectRoot).TrimEnd('\') + '\'
$scratchFullPath = [System.IO.Path]::GetFullPath($scratchRoot)
if (-not $scratchFullPath.StartsWith($projectPrefix,
        [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Font restore scratch path escaped the project root: $scratchFullPath"
}

function Expand-And-ValidateArchive {
    if (Test-Path -LiteralPath $scratchFullPath) {
        Remove-Item -LiteralPath $scratchFullPath -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $scratchFullPath | Out-Null
    try {
        Expand-Archive -LiteralPath $resolvedArchivePath `
            -DestinationPath $scratchFullPath -Force
    } catch {
        return $false
    }
    return Test-FontRecordSet $fontRecords $scratchFullPath
}

try {
    if (-not (Expand-And-ValidateArchive)) {
        Download-FontArchive
        if (-not (Expand-And-ValidateArchive)) {
            throw 'Downloaded font archive does not match current metadata.'
        }
    }
    foreach ($record in $fontRecords) {
        $sourcePath = Join-Path $scratchFullPath `
            ($record.RelativePath -replace '/', '\')
        $destinationDirectory = Split-Path -Parent $record.DestinationPath
        New-Item -ItemType Directory -Force -Path $destinationDirectory |
            Out-Null
        Copy-Item -LiteralPath $sourcePath `
            -Destination $record.DestinationPath -Force
    }
    if (-not (Test-FontRecordSet $fontRecords $destinationRootPath)) {
        throw 'Restored font assets failed final metadata verification.'
    }
} finally {
    if (Test-Path -LiteralPath $scratchFullPath) {
        Remove-Item -LiteralPath $scratchFullPath -Recurse -Force
    }
}

Write-Host "Restored and verified $($fontRecords.Count) packaged font assets from $resolvedArchivePath."
