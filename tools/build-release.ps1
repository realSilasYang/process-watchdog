[CmdletBinding()]
param(
    [string]$OutputDirectory = "",
    [string]$AutoHotkeyPath = "",
    [string]$CompilerPath = "",
    [switch]$SkipStartupValidation
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$outputRoot = if ($OutputDirectory) {
    [System.IO.Path]::GetFullPath($OutputDirectory)
} else {
    Join-Path $projectRoot 'artifacts\release'
}
$version = (Get-Content -LiteralPath (Join-Path $projectRoot 'VERSION') `
    -Raw -Encoding UTF8).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Invalid VERSION value: $version"
}

if (-not $AutoHotkeyPath -or -not $CompilerPath) {
    $toolchain = & (Join-Path $PSScriptRoot 'bootstrap-toolchain.ps1')
    if (-not $AutoHotkeyPath) {
        $AutoHotkeyPath = $toolchain.AutoHotkeyPath
    }
    if (-not $CompilerPath) {
        $CompilerPath = $toolchain.CompilerPath
    }
}
foreach ($toolPath in @($AutoHotkeyPath, $CompilerPath)) {
    if (-not (Test-Path -LiteralPath $toolPath -PathType Leaf)) {
        throw "Required build tool is missing: $toolPath"
    }
}

& (Join-Path $PSScriptRoot 'verify-dependencies.ps1')

function Assert-OutputPath {
    param([string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullOutputRoot = ([System.IO.Path]::GetFullPath($outputRoot)).TrimEnd('\') + '\'
    if (-not $fullPath.StartsWith($fullOutputRoot,
            [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to modify a path outside the output root: $fullPath"
    }
    return $fullPath
}

New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
$packageName = "process-watchdog-$version-windows-x64"
$packageDirectory = Assert-OutputPath (Join-Path $outputRoot $packageName)
$zipPath = Assert-OutputPath (Join-Path $outputRoot "$packageName.zip")
$checksumsPath = Assert-OutputPath (Join-Path $outputRoot 'SHA256SUMS.txt')
foreach ($path in @($packageDirectory, $zipPath, $checksumsPath)) {
    if (Test-Path -LiteralPath $path) {
        [void](Assert-OutputPath $path)
        Remove-Item -LiteralPath $path -Recurse -Force
    }
}
New-Item -ItemType Directory -Force -Path $packageDirectory | Out-Null

$scratchRoot = Join-Path $projectRoot '.build\release'
$fullProjectRoot = [System.IO.Path]::GetFullPath($projectRoot).TrimEnd('\') + '\'
$fullScratchRoot = [System.IO.Path]::GetFullPath($scratchRoot)
if (-not $fullScratchRoot.StartsWith($fullProjectRoot,
        [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Build scratch directory escaped the project root: $fullScratchRoot"
}
if (Test-Path -LiteralPath $scratchRoot) {
    Remove-Item -LiteralPath $scratchRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $scratchRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'src') `
    -Destination $scratchRoot -Recurse
Copy-Item -LiteralPath (Join-Path $projectRoot 'app') `
    -Destination $scratchRoot -Recurse
Copy-Item -LiteralPath (Join-Path $projectRoot 'watchdog.ico') `
    -Destination $scratchRoot
$mainScript = Get-ChildItem -LiteralPath $projectRoot -Filter '*.ahk' -File |
    Where-Object { $_.Name -notlike '_*' } |
    Select-Object -First 1
if (-not $mainScript) {
    throw 'Main AutoHotkey source was not found.'
}
$asciiSourcePath = Join-Path $scratchRoot 'ProcessWatchdog.ahk'
Copy-Item -LiteralPath $mainScript.FullName `
    -Destination $asciiSourcePath
$scratchExecutablePath = Join-Path $scratchRoot 'ProcessWatchdog.exe'

$substituteDrive = $null
$mappedProjectRoot = $projectRoot
if (($asciiSourcePath + $scratchExecutablePath + $AutoHotkeyPath) `
        -match '[^\x00-\x7F]') {
    $occupiedDrives = @(Get-PSDrive -PSProvider FileSystem |
        ForEach-Object { $_.Name.ToUpperInvariant() })
    foreach ($letterCode in 90..80) {
        $candidate = [char]$letterCode
        if ($candidate -in $occupiedDrives) {
            continue
        }
        $substituteProcess = Start-Process -FilePath 'subst.exe' `
            -ArgumentList "$candidate`:", $projectRoot -PassThru -Wait `
            -WindowStyle Hidden
        if ($substituteProcess.ExitCode -eq 0) {
            $substituteDrive = "$candidate`:"
            $mappedProjectRoot = "$substituteDrive\"
            break
        }
    }
    if (-not $substituteDrive) {
        throw 'Unable to allocate an ASCII build drive for Ahk2Exe.'
    }
}

function ConvertTo-CompilerPath {
    param([string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if ($substituteDrive -and $fullPath.StartsWith($fullProjectRoot,
            [System.StringComparison]::OrdinalIgnoreCase)) {
        return $mappedProjectRoot + $fullPath.Substring($fullProjectRoot.Length)
    }
    if ($fullPath -match '[^\x00-\x7F]') {
        throw "Ahk2Exe input path is not ASCII and cannot be mapped: $fullPath"
    }
    return $fullPath
}

$compilerSourcePath = ConvertTo-CompilerPath $asciiSourcePath
$compilerOutputPath = ConvertTo-CompilerPath $scratchExecutablePath
$compilerIconPath = ConvertTo-CompilerPath (Join-Path $scratchRoot 'watchdog.ico')
$compilerBasePath = ConvertTo-CompilerPath $AutoHotkeyPath
if (-not (Test-Path -LiteralPath $asciiSourcePath -PathType Leaf)) {
    throw "ASCII staging source was not created: $asciiSourcePath"
}
Write-Verbose "Ahk2Exe source: $compilerSourcePath"
Write-Verbose "Ahk2Exe output: $compilerOutputPath"
Write-Verbose "Ahk2Exe base: $compilerBasePath"
$executablePath = Join-Path $packageDirectory ($mainScript.BaseName + '.exe')
$compilerArguments = @(
    '/in', $compilerSourcePath,
    '/out', $compilerOutputPath,
    '/icon', $compilerIconPath,
    '/base', $compilerBasePath,
    '/silent', 'verbose'
)
try {
    $compilerProcess = Start-Process -FilePath $CompilerPath `
        -ArgumentList $compilerArguments -PassThru -WindowStyle Hidden
    if (-not $compilerProcess.WaitForExit(120000)) {
        try { $compilerProcess.Kill() } catch {}
        throw 'Ahk2Exe timed out after 120 seconds.'
    }
    if ($compilerProcess.ExitCode -ne 0 -or
        -not (Test-Path -LiteralPath $scratchExecutablePath -PathType Leaf)) {
        throw "Ahk2Exe failed with exit code $($compilerProcess.ExitCode)."
    }
    Copy-Item -LiteralPath $scratchExecutablePath `
        -Destination $executablePath
} finally {
    if ($substituteDrive) {
        $removeDrive = Start-Process -FilePath 'subst.exe' `
            -ArgumentList $substituteDrive, '/D' -PassThru -Wait `
            -WindowStyle Hidden
        if ($removeDrive.ExitCode -ne 0) {
            Write-Warning "Unable to remove temporary build drive $substituteDrive."
        }
    }
}

foreach ($file in @(
    'watchdog.ico',
    'watchdog.example.ini',
    'README.md',
    'CHANGELOG.md',
    'LICENSE',
    'THIRD_PARTY_NOTICES.md',
    'VERSION'
)) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $file) `
        -Destination $packageDirectory
}
foreach ($directory in @('assets', 'third_party')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $directory) `
        -Destination $packageDirectory -Recurse
}
$packageDocumentationDirectory = Join-Path $packageDirectory 'docs'
New-Item -ItemType Directory -Force `
    -Path $packageDocumentationDirectory | Out-Null
foreach ($documentationFile in @(
    'quick-start.md',
    'installation.md',
    'configuration.md',
    'troubleshooting.md',
    'compatibility.md',
    'diagnostics.md'
)) {
    Copy-Item -LiteralPath (Join-Path $projectRoot `
        ("docs\" + $documentationFile)) `
        -Destination $packageDocumentationDirectory
}

$toolLock = Get-Content -LiteralPath `
    (Join-Path $PSScriptRoot 'toolchain.lock.json') -Raw -Encoding UTF8 |
    ConvertFrom-Json
$buildManifest = [ordered]@{
    schemaVersion = 1
    version = $version
    platform = 'windows-x64'
    autoHotkey = $toolLock.tools.autoHotkey.version
    ahk2Exe = $toolLock.tools.ahk2Exe.version
    # Derive the Unicode entry name from the filesystem. Windows PowerShell
    # 5.1 parses UTF-8-without-BOM scripts through the active ANSI code page,
    # so embedding the Chinese filename here corrupts release metadata.
    sourceEntry = $mainScript.Name
}
$manifestPath = Join-Path $packageDirectory 'build-manifest.json'
$buildManifest | ConvertTo-Json -Depth 4 |
    Set-Content -LiteralPath $manifestPath -Encoding UTF8
& (Join-Path $PSScriptRoot 'generate-sbom.ps1') `
    -OutputPath (Join-Path $packageDirectory 'SBOM.spdx.json')

if (-not $SkipStartupValidation) {
    $process = Start-Process -FilePath $executablePath `
        -ArgumentList '--startup-validation' -PassThru -Wait `
        -WindowStyle Hidden
    if ($process.ExitCode -ne 0) {
        throw "Compiled startup validation failed with exit code $($process.ExitCode)."
    }
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archiveStream = [System.IO.File]::Open($zipPath,
    [System.IO.FileMode]::CreateNew)
try {
    $archive = [System.IO.Compression.ZipArchive]::new($archiveStream,
        [System.IO.Compression.ZipArchiveMode]::Create, $false,
        [System.Text.Encoding]::UTF8)
    try {
        $files = Get-ChildItem -LiteralPath $packageDirectory -Recurse -File |
            Sort-Object { $_.FullName.Substring($packageDirectory.Length + 1) }
        foreach ($file in $files) {
            $relativePath = $file.FullName.Substring(
                $packageDirectory.Length + 1).Replace('\', '/')
            $entry = $archive.CreateEntry($relativePath,
                [System.IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = [DateTimeOffset]::new(1980, 1, 1,
                0, 0, 0, [TimeSpan]::Zero)
            $inputStream = [System.IO.File]::OpenRead($file.FullName)
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

$zipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash
"$zipHash  $([System.IO.Path]::GetFileName($zipPath))" |
    Set-Content -LiteralPath $checksumsPath -Encoding ASCII

Write-Host "Release package: $zipPath"
Write-Host "SHA-256: $zipHash"
[pscustomobject]@{
    Version = $version
    PackageDirectory = $packageDirectory
    ZipPath = $zipPath
    ChecksumsPath = $checksumsPath
    Sha256 = $zipHash
}
