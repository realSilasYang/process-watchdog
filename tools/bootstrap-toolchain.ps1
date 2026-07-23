[CmdletBinding()]
param(
    [string]$Destination = ""
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$lockPath = Join-Path $PSScriptRoot 'toolchain.lock.json'
$lock = Get-Content -LiteralPath $lockPath -Raw -Encoding UTF8 |
    ConvertFrom-Json
$toolsRoot = if ($Destination) {
    [System.IO.Path]::GetFullPath($Destination)
} else {
    Join-Path $projectRoot '.tools'
}
$cacheRoot = Join-Path $toolsRoot 'cache'
New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null

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

function Install-Tool {
    param([string]$Name, [pscustomobject]$Definition)

    $installPath = Assert-PathUnderRoot `
        (Join-Path $toolsRoot "$Name-$($Definition.version)") $toolsRoot
    $executablePath = Join-Path $installPath $Definition.executable
    $installedExecutableValid =
        (Test-Path -LiteralPath $executablePath -PathType Leaf) -and
        ((Get-FileHash -Algorithm SHA256 -LiteralPath $executablePath).Hash `
            -eq $Definition.executableSha256)
    $installedLicenseValid = $true
    if ($Definition.PSObject.Properties.Name -contains 'licenseFile') {
        $installedLicensePath = Join-Path $installPath $Definition.licenseFile
        $installedLicenseValid =
            (Test-Path -LiteralPath $installedLicensePath -PathType Leaf) -and
            ((Get-FileHash -Algorithm SHA256 `
                -LiteralPath $installedLicensePath).Hash `
                -eq $Definition.licenseSha256)
    }
    if ($installedExecutableValid -and $installedLicenseValid) {
        return $executablePath
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
            -OutFile $archivePath
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
    if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
        throw "$Name archive did not contain $($Definition.executable)."
    }
    $executableHash = (Get-FileHash -Algorithm SHA256 `
        -LiteralPath $executablePath).Hash
    if ($executableHash -ne $Definition.executableSha256) {
        Remove-Item -LiteralPath $installPath -Recurse -Force
        throw "$Name executable hash mismatch: $executableHash"
    }
    if ($Definition.PSObject.Properties.Name -contains 'licenseFile') {
        $licensePath = Join-Path $installPath $Definition.licenseFile
        if (-not (Test-Path -LiteralPath $licensePath -PathType Leaf)) {
            Remove-Item -LiteralPath $installPath -Recurse -Force
            throw "$Name archive did not contain $($Definition.licenseFile)."
        }
        $licenseHash = (Get-FileHash -Algorithm SHA256 `
            -LiteralPath $licensePath).Hash
        if ($licenseHash -ne $Definition.licenseSha256) {
            Remove-Item -LiteralPath $installPath -Recurse -Force
            throw "$Name license hash mismatch: $licenseHash"
        }
    }
    return $executablePath
}

$autoHotkeyPath = Install-Tool 'AutoHotkey' $lock.tools.autoHotkey
$compilerPath = Install-Tool 'Ahk2Exe' $lock.tools.ahk2Exe
$actionlintPath = Install-Tool 'actionlint' $lock.tools.actionlint

[pscustomobject]@{
    AutoHotkeyPath = $autoHotkeyPath
    CompilerPath = $compilerPath
    ActionlintPath = $actionlintPath
    ToolsRoot = $toolsRoot
}
