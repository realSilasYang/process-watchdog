# Windows x64 发行包构建脚本。
# 从本次发布解析出的工具链快照编译主程序，整理运行依赖、许可证、源码归档、
# 可更新源码包、校验和、SBOM 与构建溯源。

[CmdletBinding()]
param(
    [string]$OutputDirectory = "",
    [string]$AutoHotkeyPath = "",
    [string]$CompilerPath = "",
    [string]$AutoHotkeySourcePath = "",
    [string]$ResolvedToolchainPath = "",
    [switch]$SkipStartupValidation
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Windows PowerShell 5.1 与 PowerShell 7 对 -Encoding UTF8 和 ConvertTo-Json
# 的默认字节输出不同。发行构建必须显式控制 BOM、换行和 JSON 空白，避免同一源码
# 仅因宿主版本不同而产生不同 EXE、SBOM 或 ZIP。
$script:utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$script:utf8WithBom = [System.Text.UTF8Encoding]::new($true)
function Write-CanonicalJson {
    param(
        [object]$InputObject,
        [string]$Path,
        [int]$Depth
    )

    $json = $InputObject | ConvertTo-Json -Depth $Depth -Compress
    [System.IO.File]::WriteAllText($Path, $json + "`r`n",
        $script:utf8NoBom)
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$outputRoot = if ($OutputDirectory) {
    [System.IO.Path]::GetFullPath($OutputDirectory)
} else {
    Join-Path $projectRoot 'dist'
}
$version = (Get-Content -LiteralPath (Join-Path $projectRoot 'VERSION') `
    -Raw -Encoding UTF8).Trim()
if ($version -notmatch `
    '^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$') {
    throw "Invalid VERSION value: $version"
}

if (-not $AutoHotkeyPath -or -not $CompilerPath -or
    -not $AutoHotkeySourcePath -or -not $ResolvedToolchainPath) {
    $bootstrapArguments = @{}
    if ($ResolvedToolchainPath) {
        $bootstrapArguments.ResolvedToolchainPath = $ResolvedToolchainPath
    }
    $toolchain = & (Join-Path $PSScriptRoot 'bootstrap-toolchain.ps1') `
        @bootstrapArguments
    if (-not $AutoHotkeyPath) {
        $AutoHotkeyPath = $toolchain.AutoHotkeyPath
    }
    if (-not $CompilerPath) {
        $CompilerPath = $toolchain.CompilerPath
    }
    if (-not $AutoHotkeySourcePath) {
        $AutoHotkeySourcePath = $toolchain.AutoHotkeySourcePath
    }
    if (-not $ResolvedToolchainPath) {
        $ResolvedToolchainPath = $toolchain.ResolvedToolchainPath
    }
}
foreach ($toolPath in @($AutoHotkeyPath, $CompilerPath)) {
    if (-not (Test-Path -LiteralPath $toolPath -PathType Leaf)) {
        throw "Required build tool is missing: $toolPath"
    }
}

$resolvedToolchainPath = [System.IO.Path]::GetFullPath(
    $ResolvedToolchainPath)
if (-not (Test-Path -LiteralPath $resolvedToolchainPath -PathType Leaf)) {
    throw "Resolved toolchain snapshot is missing: $resolvedToolchainPath"
}
$toolLock = Get-Content -LiteralPath $resolvedToolchainPath -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json
if ($toolLock.schemaVersion -ne 2) {
    throw 'Resolved toolchain snapshot schema is invalid.'
}
function Assert-ResolvedBuildTool {
    param(
        [string]$Name,
        [string]$Path,
        [pscustomobject]$Definition
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $actualHash = (Get-FileHash -Algorithm SHA256 `
        -LiteralPath $fullPath).Hash
    if ($actualHash -ne $Definition.executableSha256) {
        throw "$Name executable does not match the resolved toolchain: $actualHash"
    }
    return $fullPath
}
$AutoHotkeyPath = Assert-ResolvedBuildTool 'AutoHotkey' $AutoHotkeyPath `
    $toolLock.tools.autoHotkey
$CompilerPath = Assert-ResolvedBuildTool 'Ahk2Exe' $CompilerPath `
    $toolLock.tools.ahk2Exe
$autoHotkeyLicensePath = Join-Path (Split-Path -Parent $AutoHotkeyPath) `
    $toolLock.tools.autoHotkey.licenseFile
if (-not (Test-Path -LiteralPath $autoHotkeyLicensePath -PathType Leaf)) {
    throw "Resolved AutoHotkey license is missing: $autoHotkeyLicensePath"
}
$autoHotkeyLicenseHash = (Get-FileHash -Algorithm SHA256 `
    -LiteralPath $autoHotkeyLicensePath).Hash
if ($autoHotkeyLicenseHash -ne $toolLock.tools.autoHotkey.licenseSha256) {
    throw "AutoHotkey license hash mismatch: $autoHotkeyLicenseHash"
}
$AutoHotkeySourcePath = [System.IO.Path]::GetFullPath(
    $AutoHotkeySourcePath)
if (-not (Test-Path -LiteralPath $AutoHotkeySourcePath -PathType Leaf)) {
    throw "Resolved AutoHotkey source archive is missing: $AutoHotkeySourcePath"
}
$autoHotkeySourceHash = (Get-FileHash -Algorithm SHA256 `
    -LiteralPath $AutoHotkeySourcePath).Hash
if ($autoHotkeySourceHash -ne $toolLock.tools.autoHotkey.sourceSha256) {
    throw "AutoHotkey source archive hash mismatch: $autoHotkeySourceHash"
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
$standaloneExecutablePath = Assert-OutputPath `
    (Join-Path $outputRoot "$packageName.exe")
$sourcePackageName = "process-watchdog-$version-source"
$sourcePackageDirectory = Assert-OutputPath `
    (Join-Path $outputRoot $sourcePackageName)
$sourceZipPath = Assert-OutputPath `
    (Join-Path $outputRoot "$sourcePackageName.zip")
$standaloneSbomPath = Assert-OutputPath `
    (Join-Path $outputRoot "$packageName.spdx.json")
$checksumsPath = Assert-OutputPath (Join-Path $outputRoot 'SHA256SUMS.txt')
foreach ($path in @($packageDirectory, $zipPath, $standaloneExecutablePath,
        $sourcePackageDirectory, $sourceZipPath, $standaloneSbomPath,
        $checksumsPath)) {
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
$scratchAppAssetDirectory = Join-Path $scratchRoot 'assets\app'
New-Item -ItemType Directory -Force -Path $scratchAppAssetDirectory | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets\app\watchdog.ico') `
    -Destination $scratchAppAssetDirectory
$mainScript = Get-ChildItem -LiteralPath $projectRoot -Filter '*.ahk' -File |
    Where-Object { $_.Name -notlike '_*' } |
    Select-Object -First 1
if (-not $mainScript) {
    throw 'Main AutoHotkey source was not found.'
}
$asciiSourcePath = Join-Path $scratchRoot 'ProcessWatchdog.ahk'
Copy-Item -LiteralPath $mainScript.FullName `
    -Destination $asciiSourcePath
# Ahk2Exe 的 SetVersion 是源码编译指令而不是命令行参数。构建副本在这里直接从
# VERSION 注入，既兼容最新上游编译器，也避免发行元数据依赖开发者手工改写。
$stagedSource = Get-Content -LiteralPath $asciiSourcePath -Raw -Encoding UTF8
$versionDirectivePattern = '(?m)^;@Ahk2Exe-SetVersion\s+[^\r\n]+(?=\r?$)'
if ([regex]::Matches($stagedSource, $versionDirectivePattern).Count -ne 1) {
    throw 'The main source must contain exactly one Ahk2Exe SetVersion directive.'
}
$stagedSource = [regex]::Replace($stagedSource, $versionDirectivePattern,
    ";@Ahk2Exe-SetVersion $version.0")
[System.IO.File]::WriteAllText($asciiSourcePath, $stagedSource,
    $script:utf8WithBom)
$scratchExecutablePath = Join-Path $scratchRoot 'ProcessWatchdog.exe'

$buildDriveLetter = 'R'
$occupiedDrives = @(Get-PSDrive -PSProvider FileSystem |
    ForEach-Object { $_.Name.ToUpperInvariant() })
if ($buildDriveLetter -in $occupiedDrives) {
    throw "Deterministic build drive $buildDriveLetter`: is already in use."
}
$substituteProcess = Start-Process -FilePath 'subst.exe' `
    -ArgumentList "$buildDriveLetter`:", $projectRoot -PassThru -Wait `
    -WindowStyle Hidden
if ($substituteProcess.ExitCode -ne 0) {
    throw "Unable to allocate deterministic build drive $buildDriveLetter`: ."
}
$substituteDrive = "$buildDriveLetter`:"
$mappedProjectRoot = "$substituteDrive\"

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
$compilerIconPath = ConvertTo-CompilerPath `
    (Join-Path $scratchAppAssetDirectory 'watchdog.ico')
$compilerBasePath = ConvertTo-CompilerPath $AutoHotkeyPath
$compilerExecutablePath = ConvertTo-CompilerPath $CompilerPath
if (-not (Test-Path -LiteralPath $asciiSourcePath -PathType Leaf)) {
    throw "ASCII staging source was not created: $asciiSourcePath"
}
Write-Verbose "Ahk2Exe source: $compilerSourcePath"
Write-Verbose "Ahk2Exe output: $compilerOutputPath"
Write-Verbose "Ahk2Exe base: $compilerBasePath"
$executablePath = Join-Path $packageDirectory ($mainScript.BaseName + '.exe')
$canonicalPowerShell = Join-Path $env:SystemRoot `
    'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $canonicalPowerShell -PathType Leaf)) {
    throw "Canonical release host is missing: $canonicalPowerShell"
}
try {
    & $canonicalPowerShell -NoLogo -NoProfile -NonInteractive `
        -ExecutionPolicy Bypass -File `
        (Join-Path $PSScriptRoot 'invoke-release-compiler.ps1') `
        -CompilerPath $compilerExecutablePath `
        -SourcePath $compilerSourcePath -OutputPath $compilerOutputPath `
        -IconPath $compilerIconPath -BasePath $compilerBasePath `
        -WorkingDirectory $mappedProjectRoot
    if ($LASTEXITCODE -ne 0) {
        throw "Canonical compiler host failed with exit code $LASTEXITCODE."
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
    # 编译中间目录不属于交付物；无论成功还是失败都立即清理，避免根目录长期堆积
    # 已经过时的源码副本和 EXE。
    if (Test-Path -LiteralPath $scratchRoot) {
        Remove-Item -LiteralPath $scratchRoot -Recurse -Force
    }
    $scratchParent = Split-Path -Parent $scratchRoot
    if ((Test-Path -LiteralPath $scratchParent -PathType Container) -and
        -not (Get-ChildItem -LiteralPath $scratchParent -Force)) {
        Remove-Item -LiteralPath $scratchParent -Force
    }
}

foreach ($file in @(
    'README.md',
    'CHANGELOG.md',
    'LICENSE',
    'VERSION'
)) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $file) `
        -Destination $packageDirectory
}
$licenseDirectory = Join-Path $packageDirectory 'licenses'
New-Item -ItemType Directory -Force -Path $licenseDirectory | Out-Null
Copy-Item -LiteralPath $autoHotkeyLicensePath `
    -Destination (Join-Path $licenseDirectory 'AutoHotkey-LICENSE.txt')
$sourceDirectory = Join-Path $licenseDirectory 'sources'
New-Item -ItemType Directory -Force -Path $sourceDirectory | Out-Null
$packagedAutoHotkeySource = "AutoHotkey-$($toolLock.tools.autoHotkey.version)-source.zip"
Copy-Item -LiteralPath $AutoHotkeySourcePath `
    -Destination (Join-Path $sourceDirectory $packagedAutoHotkeySource)
$buildMetadataDirectory = Join-Path $packageDirectory 'build-metadata'
New-Item -ItemType Directory -Force -Path $buildMetadataDirectory | Out-Null
Copy-Item -LiteralPath $resolvedToolchainPath `
    -Destination (Join-Path $buildMetadataDirectory 'toolchain.resolved.json')
foreach ($directory in @('assets', 'config', 'docs', 'runtime',
        'third_party')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $directory) `
        -Destination $packageDirectory -Recurse
}
$packageCommunityDirectory = Join-Path $packageDirectory '.github'
New-Item -ItemType Directory -Force `
    -Path $packageCommunityDirectory | Out-Null
foreach ($communityFile in @(
    'CONTRIBUTING.md',
    'CONTRIBUTING.en.md',
    'CODE_OF_CONDUCT.md',
    'CODE_OF_CONDUCT.en.md',
    'SECURITY.md',
    'SECURITY.en.md',
    'SUPPORT.md',
    'SUPPORT.en.md'
)) {
    Copy-Item -LiteralPath (Join-Path $projectRoot `
        ('.github\' + $communityFile)) `
        -Destination $packageCommunityDirectory
}
$manualRegressionDirectory = Join-Path $packageDirectory 'tests\gui'
New-Item -ItemType Directory -Force `
    -Path $manualRegressionDirectory | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot `
    'tests\gui\MANUAL-REGRESSION.md') -Destination $manualRegressionDirectory
Copy-Item -LiteralPath (Join-Path $projectRoot `
    'tests\gui\MANUAL-REGRESSION.en.md') -Destination $manualRegressionDirectory

$buildManifest = [ordered]@{
    schemaVersion = 4
    packageKind = 'compiled'
    version = $version
    platform = 'windows-x64'
    autoHotkey = $toolLock.tools.autoHotkey.version
    autoHotkeyExecutableSha256 = `
        $toolLock.tools.autoHotkey.executableSha256
    autoHotkeySourceCommit = $toolLock.tools.autoHotkey.sourceCommit
    autoHotkeySourceSha256 = $toolLock.tools.autoHotkey.sourceSha256
    ahk2Exe = $toolLock.tools.ahk2Exe.version
    ahk2ExeExecutableSha256 = $toolLock.tools.ahk2Exe.executableSha256
    # 直接沿用前面发现并校验过的唯一入口文件名，避免在构建元数据中重复维护中文文件名。
    sourceEntry = $mainScript.Name
}
$manifestPath = Join-Path $packageDirectory 'build-manifest.json'
Write-CanonicalJson $buildManifest $manifestPath 4
$executableName = Split-Path -Leaf $executablePath
$compiledUpdateManifest = [ordered]@{
    schemaVersion = 1
    packageKind = 'compiled'
    version = $version
    entry = $executableName
    managedPaths = @(
        $executableName,
        'README.md', 'CHANGELOG.md', 'LICENSE', 'VERSION',
        '.github', 'assets', 'build-manifest.json', 'build-metadata', 'config',
        'docs', 'licenses', 'runtime', 'SBOM.spdx.json', 'tests',
        'third_party', 'update-manifest.json'
    )
}
Write-CanonicalJson $compiledUpdateManifest `
    (Join-Path $packageDirectory 'update-manifest.json') 5
$packageSbomPath = Join-Path $packageDirectory 'SBOM.spdx.json'
& (Join-Path $PSScriptRoot 'generate-sbom.ps1') `
    -OutputPath $packageSbomPath `
    -ResolvedToolchainPath $resolvedToolchainPath
Copy-Item -LiteralPath $packageSbomPath -Destination $standaloneSbomPath

# 源码发行包使用与仓库相同的可运行布局，供非 Git 源码安装执行校验更新。
New-Item -ItemType Directory -Force -Path $sourcePackageDirectory | Out-Null
foreach ($file in @('README.md', 'CHANGELOG.md', 'LICENSE', 'VERSION',
        $mainScript.Name)) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $file) `
        -Destination $sourcePackageDirectory
}
foreach ($directory in @('.github', 'app', 'assets', 'config', 'docs',
        'runtime', 'src', 'tests', 'third_party', 'tools')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $directory) `
        -Destination $sourcePackageDirectory -Recurse
}
$sourceUpdateManifest = [ordered]@{
    schemaVersion = 1
    packageKind = 'source'
    version = $version
    entry = $mainScript.Name
    managedPaths = @(
        $mainScript.Name, 'README.md', 'CHANGELOG.md', 'LICENSE', 'VERSION',
        '.github', 'app', 'assets', 'config', 'docs', 'runtime', 'src',
        'tests', 'third_party', 'tools', 'update-manifest.json'
    )
}
Write-CanonicalJson $sourceUpdateManifest `
    (Join-Path $sourcePackageDirectory 'update-manifest.json') 5

if (-not $SkipStartupValidation) {
    & (Join-Path $PSScriptRoot 'invoke-startup-validation.ps1') `
        -ExecutablePath $executablePath
}

$archiveWriter = Join-Path $PSScriptRoot 'new-release-archive.ps1'
foreach ($archiveSpec in @(
        @($packageDirectory, $zipPath),
        @($sourcePackageDirectory, $sourceZipPath))) {
    & $canonicalPowerShell -NoLogo -NoProfile -NonInteractive `
        -ExecutionPolicy Bypass -File $archiveWriter `
        -SourceDirectory $archiveSpec[0] -ArchivePath $archiveSpec[1]
    if ($LASTEXITCODE -ne 0) {
        throw "Canonical archive host failed with exit code $LASTEXITCODE."
    }
}
# 独立 EXE 使用一个很小的 AHK 启动器内嵌完整便携 ZIP。首次运行时，启动器
# 把经过 SHA-256 校验的载荷事务安装到 LOCALAPPDATA 的稳定目录；此后内层正式
# 程序继续使用同一份个人配置和既有自动更新流程。
$payloadSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash
$standaloneScratchRoot = Join-Path $projectRoot '.build\standalone'
if (Test-Path -LiteralPath $standaloneScratchRoot) {
    Remove-Item -LiteralPath $standaloneScratchRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $standaloneScratchRoot | Out-Null
$standaloneSourcePath = Join-Path $standaloneScratchRoot 'StandaloneLauncher.ahk'
$standaloneScratchOutput = Join-Path $standaloneScratchRoot 'StandaloneLauncher.exe'
$standalonePayloadPath = Join-Path $standaloneScratchRoot 'payload.zip'
$standaloneInstallerPath = Join-Path $standaloneScratchRoot `
    'standalone-install.ps1'
$standaloneIconPath = Join-Path $standaloneScratchRoot 'watchdog.ico'
Copy-Item -LiteralPath $zipPath -Destination $standalonePayloadPath
Copy-Item -LiteralPath (Join-Path $projectRoot `
    'runtime\standalone-install.ps1') -Destination $standaloneInstallerPath
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets\app\watchdog.ico') `
    -Destination $standaloneIconPath
$standaloneTemplate = Get-Content -LiteralPath (Join-Path $projectRoot `
    'runtime\standalone-launcher.ahk') -Raw -Encoding UTF8
foreach ($placeholder in @('__PAYLOAD_VERSION__', '__PAYLOAD_SHA256__',
        '__PAYLOAD_ENTRY__')) {
    if (-not $standaloneTemplate.Contains($placeholder)) {
        throw "Standalone launcher template is missing: $placeholder"
    }
}
$standaloneSource = $standaloneTemplate.Replace('__PAYLOAD_VERSION__', $version).Replace('__PAYLOAD_SHA256__', $payloadSha256).Replace('__PAYLOAD_ENTRY__', $executableName)
[System.IO.File]::WriteAllText($standaloneSourcePath, $standaloneSource,
    $script:utf8WithBom)

$standaloneSubstituteProcess = Start-Process -FilePath 'subst.exe' `
    -ArgumentList "$buildDriveLetter`:", $projectRoot -PassThru -Wait `
    -WindowStyle Hidden
if ($standaloneSubstituteProcess.ExitCode -ne 0) {
    throw "Unable to allocate deterministic build drive $buildDriveLetter`: for standalone compilation."
}
try {
    & $canonicalPowerShell -NoLogo -NoProfile -NonInteractive `
        -ExecutionPolicy Bypass -File `
        (Join-Path $PSScriptRoot 'invoke-release-compiler.ps1') `
        -CompilerPath (ConvertTo-CompilerPath $CompilerPath) `
        -SourcePath (ConvertTo-CompilerPath $standaloneSourcePath) `
        -OutputPath (ConvertTo-CompilerPath $standaloneScratchOutput) `
        -IconPath (ConvertTo-CompilerPath $standaloneIconPath) `
        -BasePath (ConvertTo-CompilerPath $AutoHotkeyPath) `
        -WorkingDirectory (ConvertTo-CompilerPath $standaloneScratchRoot)
    if ($LASTEXITCODE -ne 0) {
        throw "Standalone compiler host failed with exit code $LASTEXITCODE."
    }
    Copy-Item -LiteralPath $standaloneScratchOutput `
        -Destination $standaloneExecutablePath
} finally {
    $removeStandaloneDrive = Start-Process -FilePath 'subst.exe' `
        -ArgumentList "$buildDriveLetter`:", '/D' -PassThru -Wait `
        -WindowStyle Hidden
    if ($removeStandaloneDrive.ExitCode -ne 0) {
        Write-Warning "Unable to remove standalone build drive $buildDriveLetter`: ."
    }
    if (Test-Path -LiteralPath $standaloneScratchRoot) {
        Remove-Item -LiteralPath $standaloneScratchRoot -Recurse -Force
    }
    $standaloneScratchParent = Split-Path -Parent $standaloneScratchRoot
    if ((Test-Path -LiteralPath $standaloneScratchParent -PathType Container) `
        -and -not (Get-ChildItem -LiteralPath $standaloneScratchParent -Force)) {
        Remove-Item -LiteralPath $standaloneScratchParent -Force
    }
}

$zipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash
$executableHash = (Get-FileHash -Algorithm SHA256 `
    -LiteralPath $standaloneExecutablePath).Hash
$sourceZipHash = (Get-FileHash -Algorithm SHA256 `
    -LiteralPath $sourceZipPath).Hash
$sbomHash = (Get-FileHash -Algorithm SHA256 `
    -LiteralPath $standaloneSbomPath).Hash
@(
    "$zipHash  $([System.IO.Path]::GetFileName($zipPath))"
    "$executableHash  $([System.IO.Path]::GetFileName($standaloneExecutablePath))"
    "$sourceZipHash  $([System.IO.Path]::GetFileName($sourceZipPath))"
    "$sbomHash  $([System.IO.Path]::GetFileName($standaloneSbomPath))"
) |
    Set-Content -LiteralPath $checksumsPath -Encoding ASCII

Write-Host "Release package: $zipPath"
Write-Host "Standalone executable: $standaloneExecutablePath"
Write-Host "Source package: $sourceZipPath"
Write-Host "Release SBOM: $standaloneSbomPath"
Write-Host "ZIP SHA-256: $zipHash"
Write-Host "EXE SHA-256: $executableHash"
Write-Host "Source ZIP SHA-256: $sourceZipHash"
Write-Host "SBOM SHA-256: $sbomHash"
[pscustomobject]@{
    Version = $version
    PackageDirectory = $packageDirectory
    ZipPath = $zipPath
    ExecutablePath = $standaloneExecutablePath
    SourcePackageDirectory = $sourcePackageDirectory
    SourceZipPath = $sourceZipPath
    SbomPath = $standaloneSbomPath
    ChecksumsPath = $checksumsPath
    Sha256 = $zipHash
    ExecutableSha256 = $executableHash
    SourceSha256 = $sourceZipHash
    SbomSha256 = $sbomHash
}
