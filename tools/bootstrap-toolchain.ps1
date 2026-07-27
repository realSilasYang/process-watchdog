# 项目工具链引导脚本。
# AutoHotkey 与 Ahk2Exe 来自一次性解析快照；测试工具仍由仓库锁文件固定。
# 正式发布必须传入 RefreshBuildTools，使每次人工发布都重新检查上游版本。

[CmdletBinding()]
param(
    [string]$Destination = "",
    [string]$ResolvedToolchainPath = "",
    [switch]$RefreshBuildTools
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$toolsRoot = if ($Destination) {
    [System.IO.Path]::GetFullPath($Destination)
} else {
    Join-Path $projectRoot '.tools'
}
$cacheRoot = Join-Path $toolsRoot 'cache'
$resolvedPath = if ($ResolvedToolchainPath) {
    [System.IO.Path]::GetFullPath($ResolvedToolchainPath)
} else {
    Join-Path $toolsRoot 'toolchain.resolved.json'
}
New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null

if ($RefreshBuildTools -or
    -not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
    $resolution = & (Join-Path $PSScriptRoot 'resolve-toolchain.ps1') `
        -OutputPath $resolvedPath -Destination $toolsRoot
    $resolvedPath = $resolution.ResolvedToolchainPath
}
$resolved = Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 |
    ConvertFrom-Json
if ($resolved.schemaVersion -ne 2) {
    throw "Unsupported resolved toolchain schema: $($resolved.schemaVersion)"
}
foreach ($requiredTool in @('autoHotkey', 'ahk2Exe', 'actionlint', 'gitleaks')) {
    if ($resolved.tools.PSObject.Properties.Name -notcontains $requiredTool) {
        throw "Resolved toolchain is missing $requiredTool."
    }
}

function Assert-PathUnderRoot {
    param([string]$Path, [string]$Root)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    if (-not $fullPath.StartsWith($fullRoot,
            [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to modify a path outside the tool root: $fullPath"
    }
    return $fullPath
}

function Get-UniqueInstalledFile {
    param(
        [string]$Root,
        [string]$Name,
        [string]$DisplayName
    )

    $matches = @(Get-ChildItem -LiteralPath $Root -Recurse -File `
        -Filter $Name)
    if ($matches.Count -ne 1) {
        throw "$DisplayName installation must contain exactly one $Name."
    }
    return $matches[0].FullName
}

function Install-Tool {
    param([string]$Name, [pscustomobject]$Definition)

    $installPath = Assert-PathUnderRoot `
        (Join-Path $toolsRoot "$Name-$($Definition.version)") $toolsRoot
    $installedExecutable = ""
    if (Test-Path -LiteralPath $installPath -PathType Container) {
        try {
            $installedExecutable = Get-UniqueInstalledFile $installPath `
                $Definition.executable $Name
        } catch {
            $installedExecutable = ""
        }
    }
    $installationValid = $installedExecutable -and
        ((Get-FileHash -Algorithm SHA256 `
            -LiteralPath $installedExecutable).Hash `
            -eq $Definition.executableSha256)
    if ($installationValid -and
        $Definition.PSObject.Properties.Name -contains 'licenseFile') {
        try {
            $licensePath = Get-UniqueInstalledFile $installPath `
                $Definition.licenseFile "$Name license"
            $installationValid = (Get-FileHash -Algorithm SHA256 `
                -LiteralPath $licensePath).Hash -eq $Definition.licenseSha256
        } catch {
            $installationValid = $false
        }
    }
    if ($installationValid) {
        return $installedExecutable
    }

    $archivePath = Assert-PathUnderRoot `
        (Join-Path $cacheRoot $Definition.archive) $toolsRoot
    $archiveValid = (Test-Path -LiteralPath $archivePath -PathType Leaf) -and
        ((Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath).Hash `
            -eq $Definition.sha256)
    if (-not $archiveValid) {
        if (Test-Path -LiteralPath $archivePath) {
            Remove-Item -LiteralPath $archivePath -Force
        }
        Write-Host "Downloading $Name $($Definition.version)..."
        Invoke-WebRequest -UseBasicParsing -Uri $Definition.url `
            -OutFile $archivePath -TimeoutSec 180
    }
    $actualHash = (Get-FileHash -Algorithm SHA256 `
        -LiteralPath $archivePath).Hash
    if ($actualHash -ne $Definition.sha256) {
        Remove-Item -LiteralPath $archivePath -Force
        throw "$Name archive hash mismatch: $actualHash"
    }

    if (Test-Path -LiteralPath $installPath) {
        [void](Assert-PathUnderRoot $installPath $toolsRoot)
        Remove-Item -LiteralPath $installPath -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $installPath | Out-Null
    Expand-Archive -LiteralPath $archivePath -DestinationPath $installPath
    $executablePath = Get-UniqueInstalledFile $installPath `
        $Definition.executable $Name
    $executableHash = (Get-FileHash -Algorithm SHA256 `
        -LiteralPath $executablePath).Hash
    if ($executableHash -ne $Definition.executableSha256) {
        Remove-Item -LiteralPath $installPath -Recurse -Force
        throw "$Name executable hash mismatch: $executableHash"
    }
    if ($Definition.PSObject.Properties.Name -contains 'licenseFile') {
        $licensePath = Get-UniqueInstalledFile $installPath `
            $Definition.licenseFile "$Name license"
        $licenseHash = (Get-FileHash -Algorithm SHA256 `
            -LiteralPath $licensePath).Hash
        if ($licenseHash -ne $Definition.licenseSha256) {
            Remove-Item -LiteralPath $installPath -Recurse -Force
            throw "$Name license hash mismatch: $licenseHash"
        }
    }
    return $executablePath
}

function Get-ResolvedArchive {
    param(
        [string]$Name,
        [string]$Archive,
        [string]$Url,
        [string]$Sha256
    )

    $archivePath = Assert-PathUnderRoot (Join-Path $cacheRoot $Archive) `
        $toolsRoot
    $archiveValid = (Test-Path -LiteralPath $archivePath -PathType Leaf) -and
        ((Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath).Hash `
            -eq $Sha256)
    if (-not $archiveValid) {
        if (Test-Path -LiteralPath $archivePath) {
            Remove-Item -LiteralPath $archivePath -Force
        }
        Write-Host "Downloading $Name..."
        Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $archivePath `
            -TimeoutSec 180
    }
    $actualHash = (Get-FileHash -Algorithm SHA256 `
        -LiteralPath $archivePath).Hash
    if ($actualHash -ne $Sha256) {
        Remove-Item -LiteralPath $archivePath -Force
        throw "$Name archive hash mismatch: $actualHash"
    }
    return $archivePath
}

$autoHotkeyPath = Install-Tool 'AutoHotkey' $resolved.tools.autoHotkey
$compilerPath = Install-Tool 'Ahk2Exe' $resolved.tools.ahk2Exe
$actionlintPath = Install-Tool 'actionlint' $resolved.tools.actionlint
$gitleaksPath = Install-Tool 'gitleaks' $resolved.tools.gitleaks
$autoHotkeySourcePath = Get-ResolvedArchive 'AutoHotkey source' `
    $resolved.tools.autoHotkey.sourceArchive `
    $resolved.tools.autoHotkey.sourceUrl `
    $resolved.tools.autoHotkey.sourceSha256

[pscustomobject]@{
    AutoHotkeyPath = $autoHotkeyPath
    AutoHotkeySourcePath = $autoHotkeySourcePath
    CompilerPath = $compilerPath
    ActionlintPath = $actionlintPath
    GitleaksPath = $gitleaksPath
    ResolvedToolchainPath = $resolvedPath
    ToolsRoot = $toolsRoot
}
