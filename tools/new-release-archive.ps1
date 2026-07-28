# Store 模式的规范 ZIP 写入器。
# 固定使用 Windows PowerShell 5.1 的 .NET Framework ZIP 实现、Ordinal 路径顺序和
# 1980 时间戳，消除外层 PowerShell、系统区域与现代 .NET Deflate 实现的差异。

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourceDirectory,
    [Parameter(Mandatory)][string]$ArchivePath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$sourceRoot = [System.IO.Path]::GetFullPath($SourceDirectory).TrimEnd('\')
$archiveFile = [System.IO.Path]::GetFullPath($ArchivePath)
if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
    throw "Archive source directory does not exist: $sourceRoot"
}
if (Test-Path -LiteralPath $archiveFile) {
    throw "Archive output already exists: $archiveFile"
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$filesByPath = @{}
$relativePaths = @(
    foreach ($file in Get-ChildItem -LiteralPath $sourceRoot -Recurse -File) {
        $relativePath = $file.FullName.Substring($sourceRoot.Length + 1)
        $relativePath = $relativePath.Replace('\', '/')
        $filesByPath[$relativePath] = $file.FullName
        $relativePath
    }
)
[Array]::Sort([string[]]$relativePaths,
    [System.StringComparer]::Ordinal)

$archiveStream = [System.IO.File]::Open($archiveFile,
    [System.IO.FileMode]::CreateNew)
try {
    $archive = [System.IO.Compression.ZipArchive]::new($archiveStream,
        [System.IO.Compression.ZipArchiveMode]::Create, $false,
        [System.Text.Encoding]::UTF8)
    try {
        foreach ($relativePath in $relativePaths) {
            $entry = $archive.CreateEntry($relativePath,
                [System.IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = [DateTimeOffset]::new(1980, 1, 1,
                0, 0, 0, [TimeSpan]::Zero)
            $inputStream = [System.IO.File]::OpenRead(
                $filesByPath[$relativePath])
            $entryStream = $entry.Open()
            try {
                $inputStream.CopyTo($entryStream)
            } finally {
                $entryStream.Dispose()
                $inputStream.Dispose()
            }
        }
    } finally {
        $archive.Dispose()
    }
} finally {
    $archiveStream.Dispose()
}
