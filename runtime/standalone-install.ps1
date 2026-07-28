# 独立 EXE 的本地载荷安装器。
# 启动器先把内嵌便携包释放到临时目录，再由本脚本校验归档、版本和更新清单，
# 最后以可回滚事务更新稳定安装目录。个人配置和维护会话始终留在原位。

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ArchivePath,
    [Parameter(Mandatory = $true)][string]$InstallRoot,
    [Parameter(Mandatory = $true)][string]$ExpectedVersion,
    [Parameter(Mandatory = $true)][string]$ExpectedSha256,
    [Parameter(Mandatory = $true)][string]$PayloadMarker
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-SafeRelativePath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    if ([string]::IsNullOrWhiteSpace($RelativePath) -or
        [System.IO.Path]::IsPathRooted($RelativePath) -or
        $RelativePath -match '(^|[\\/])\.\.([\\/]|$)') {
        throw "Unsafe managed path: $RelativePath"
    }
    if ($RelativePath -in @('watchdog.ini', 'watchdog.maintenance.ini')) {
        throw "Personal state cannot be managed by the standalone payload: $RelativePath"
    }
}

function Resolve-PathUnderRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    Assert-SafeRelativePath $RelativePath
    $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $Root $RelativePath))
    if (-not $fullPath.StartsWith($fullRoot,
            [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Managed path escapes the standalone root: $RelativePath"
    }
    return $fullPath
}

function ConvertTo-StandaloneVersion {
    param([Parameter(Mandatory = $true)][string]$Value)

    if ($Value -notmatch '^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$') {
        throw "Invalid standalone semantic version: $Value"
    }
    try {
        return [Version]("$Value.0")
    } catch {
        throw "Unsupported standalone semantic version: $Value"
    }
}

function Get-StandaloneSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)

    # 独立启动器可能继承裁剪过的 PSModulePath；直接使用 .NET，避免哈希校验
    # 依赖 Microsoft.PowerShell.Utility 模块能否自动发现。
    $stream = [System.IO.File]::OpenRead($Path)
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $algorithm.ComputeHash($stream)
        return [System.BitConverter]::ToString($hashBytes).Replace('-', '')
    } finally {
        $algorithm.Dispose()
        $stream.Dispose()
    }
}

function Get-MinimalManagedPaths {
    param([string[]]$RelativePaths)

    $ordered = @($RelativePaths | ForEach-Object {
        ([string]$_).Replace('/', '\').TrimEnd('\')
    } | Sort-Object @{Expression = {$_.Length}}, @{Expression = {$_}})
    $result = [System.Collections.Generic.List[string]]::new()
    foreach ($candidate in $ordered) {
        $covered = $false
        foreach ($parent in $result) {
            if ($candidate -ieq $parent -or $candidate.StartsWith(
                    $parent + '\',
                    [System.StringComparison]::OrdinalIgnoreCase)) {
                $covered = $true
                break
            }
        }
        if (-not $covered) {
            [void]$result.Add($candidate)
        }
    }
    return @($result)
}

function Read-ManagedManifest {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [switch]$Optional
    )

    $manifestPath = Join-Path $Root 'update-manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        if ($Optional) { return $null }
        throw 'Standalone payload is missing update-manifest.json.'
    }
    try {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw `
            -Encoding UTF8 | ConvertFrom-Json
    } catch {
        if ($Optional) { return $null }
        throw
    }
    if ($manifest.schemaVersion -ne 1 -or
        $manifest.packageKind -ne 'compiled' -or
        -not $manifest.entry -or @($manifest.managedPaths).Count -eq 0) {
        if ($Optional) { return $null }
        throw 'Standalone payload manifest is invalid.'
    }
    return $manifest
}

$archive = [System.IO.Path]::GetFullPath($ArchivePath)
$root = [System.IO.Path]::GetFullPath($InstallRoot)
if (-not (Test-Path -LiteralPath $archive -PathType Leaf)) {
    throw "Standalone payload archive does not exist: $archive"
}
if ($ExpectedSha256 -notmatch '^[0-9A-Fa-f]{64}$') {
    throw 'Standalone payload SHA-256 is invalid.'
}
$actualHash = Get-StandaloneSha256 $archive
if ($actualHash -cne $ExpectedSha256.ToUpperInvariant()) {
    throw "Standalone payload SHA-256 mismatch: $actualHash"
}
$expectedSemanticVersion = ConvertTo-StandaloneVersion $ExpectedVersion
$installedVersionPath = Join-Path $root 'VERSION'
if (Test-Path -LiteralPath $installedVersionPath -PathType Leaf) {
    $installedSemanticVersion = $null
    try {
        $installedVersionText = (Get-Content -LiteralPath $installedVersionPath -Raw -Encoding UTF8).Trim()
        $installedSemanticVersion = ConvertTo-StandaloneVersion $installedVersionText
    } catch {
        # 无法解析的旧 VERSION 视为损坏安装，允许经过完整载荷校验后修复。
    }
    if ($null -ne $installedSemanticVersion -and
        $installedSemanticVersion -gt $expectedSemanticVersion) {
        throw "A newer standalone installation ($installedVersionText) refuses payload downgrade to $ExpectedVersion."
    }
}

$parentRoot = Split-Path -Parent $root
New-Item -ItemType Directory -Force -Path $parentRoot | Out-Null
$transactionId = [Guid]::NewGuid().ToString('N')
$stage = Join-Path $parentRoot ('.standalone-stage-' + $transactionId)
$backup = Join-Path $parentRoot ('.standalone-backup-' + $transactionId)
$installedPaths = [System.Collections.Generic.List[string]]::new()
$backedUpPaths = [System.Collections.Generic.List[string]]::new()
try {
    New-Item -ItemType Directory -Force -Path $stage, $backup | Out-Null
    Expand-Archive -LiteralPath $archive -DestinationPath $stage
    $stagedVersionPath = Join-Path $stage 'VERSION'
    if (-not (Test-Path -LiteralPath $stagedVersionPath -PathType Leaf) -or
        (Get-Content -LiteralPath $stagedVersionPath -Raw `
            -Encoding UTF8).Trim() -cne $ExpectedVersion) {
        throw 'Standalone payload VERSION does not match the launcher.'
    }
    $newManifest = Read-ManagedManifest -Root $stage
    if ($newManifest.version -cne $ExpectedVersion) {
        throw 'Standalone payload manifest version does not match the launcher.'
    }
    $entryRelativePath = [string]$newManifest.entry
    $newManaged = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)
    foreach ($pathValue in @($newManifest.managedPaths)) {
        $relativePath = ([string]$pathValue).Replace('/', '\')
        Assert-SafeRelativePath $relativePath
        if (-not $newManaged.Add($relativePath)) {
            throw "Standalone payload contains a duplicate path: $relativePath"
        }
        if (-not (Test-Path -LiteralPath `
                (Resolve-PathUnderRoot $stage $relativePath))) {
            throw "Standalone payload is missing a managed path: $relativePath"
        }
    }
    foreach ($requiredPath in @([string]$newManifest.entry, 'VERSION',
            'assets', 'runtime', 'third_party', 'update-manifest.json')) {
        if (-not $newManaged.Contains($requiredPath)) {
            throw "Standalone payload does not manage required path: $requiredPath"
        }
    }

    $allManaged = [System.Collections.Generic.List[string]]::new()
    foreach ($managedPath in $newManaged) { $allManaged.Add($managedPath) }
    $oldManifest = Read-ManagedManifest -Root $root -Optional
    if ($null -ne $oldManifest) {
        foreach ($oldPathValue in @($oldManifest.managedPaths)) {
            $oldPath = ([string]$oldPathValue).Replace('/', '\')
            Assert-SafeRelativePath $oldPath
            $allManaged.Add($oldPath)
        }
    }
    # 标记虽然不属于便携包清单，也必须与受管文件处于同一回滚事务中。
    $allManaged.Add('.standalone-payload.sha256')
    if ($allManaged.Count -eq 0) {
        throw 'Standalone payload has no managed paths to install.'
    }
    [string[]]$allManagedArray = $allManaged
    $backupPaths = @(Get-MinimalManagedPaths -RelativePaths $allManagedArray)

    # 在移动任何资源前先验证旧入口未被运行中的内层程序锁定，避免形成一半新、
    # 一半旧的安装。运行中的实例应先由自身自动更新，或退出后再运行新启动器。
    if (Test-Path -LiteralPath ($root + '\' + $entryRelativePath) -PathType Leaf) {
        $entryProbe = [System.IO.File]::Open(($root + '\' + $entryRelativePath), [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        $entryProbe.Dispose()
    }

    New-Item -ItemType Directory -Force -Path $root | Out-Null
    try {
        foreach ($relativePath in $backupPaths) {
            $source = Resolve-PathUnderRoot $root $relativePath
            if (-not (Test-Path -LiteralPath $source)) { continue }
            $backupPath = Resolve-PathUnderRoot $backup $relativePath
            New-Item -ItemType Directory -Force `
                -Path (Split-Path -Parent $backupPath) | Out-Null
            Move-Item -LiteralPath $source -Destination $backupPath
            $backedUpPaths.Add($relativePath)
        }

        $installOrder = @($newManaged | Sort-Object {
            if ($_ -ieq $entryRelativePath) { 1 } else { 0 }
        }, { $_ })
        foreach ($relativePath in $installOrder) {
            $source = Resolve-PathUnderRoot $stage $relativePath
            $destination = Resolve-PathUnderRoot $root $relativePath
            New-Item -ItemType Directory -Force `
                -Path (Split-Path -Parent $destination) | Out-Null
            $installedPaths.Add($relativePath)
            Copy-Item -LiteralPath $source -Destination $destination -Recurse
        }

        $markerPath = Join-Path $root '.standalone-payload.sha256'
        $markerTemporaryPath = $markerPath + '.tmp.' + $PID
        [System.IO.File]::WriteAllText($markerTemporaryPath, $PayloadMarker + "`r`n", [System.Text.Encoding]::ASCII)
        Move-Item -LiteralPath $markerTemporaryPath `
            -Destination $markerPath -Force
    } catch {
        $installError = $_
        $installedReverse = @($installedPaths)
        [array]::Reverse($installedReverse)
        foreach ($relativePath in $installedReverse) {
            $destination = Resolve-PathUnderRoot $root $relativePath
            if (Test-Path -LiteralPath $destination) {
                Remove-Item -LiteralPath $destination -Recurse -Force `
                    -ErrorAction SilentlyContinue
            }
        }
        $backupReverse = @($backedUpPaths)
        [array]::Reverse($backupReverse)
        foreach ($relativePath in $backupReverse) {
            $backupPath = Resolve-PathUnderRoot $backup $relativePath
            $destination = Resolve-PathUnderRoot $root $relativePath
            if (Test-Path -LiteralPath $backupPath) {
                New-Item -ItemType Directory -Force `
                    -Path (Split-Path -Parent $destination) | Out-Null
                Move-Item -LiteralPath $backupPath -Destination $destination
            }
        }
        throw $installError
    }
} finally {
    foreach ($temporaryRoot in @($stage, $backup)) {
        if (Test-Path -LiteralPath $temporaryRoot) {
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force `
                -ErrorAction SilentlyContinue
        }
    }
}
