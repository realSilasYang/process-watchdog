# 独立 EXE 载荷安装事务测试。
# 使用最小临时便携包验证版本与哈希校验、旧受管文件清理、个人配置保留，
# 并确认入口被占用时会在修改任何资源前停止。

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-StandaloneInstaller {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$installerPath = Join-Path $projectRoot 'runtime\standalone-install.ps1'
$testRoot = Join-Path $env:TEMP `
    ('ProcessWatchdogStandaloneInstallerTest-' +
        [Guid]::NewGuid().ToString('N'))
$packageRoot = Join-Path $testRoot 'package'
$installRoot = Join-Path $testRoot 'local\ProcessWatchdog\Standalone'
$archivePath = Join-Path $testRoot 'payload.zip'
New-Item -ItemType Directory -Force -Path $packageRoot, $installRoot | Out-Null
try {
    foreach ($directory in @('assets', 'runtime', 'third_party')) {
        New-Item -ItemType Directory -Force `
            -Path (Join-Path $packageRoot $directory) | Out-Null
        Set-Content -LiteralPath (Join-Path $packageRoot `
            ($directory + '\resource.txt')) -Encoding UTF8 -Value 'new'
    }
    Set-Content -LiteralPath (Join-Path $packageRoot 'Watchdog.exe') `
        -Encoding UTF8 -Value 'new entry'
    Set-Content -LiteralPath (Join-Path $packageRoot 'VERSION') `
        -Encoding UTF8 -Value '9.0.0'
    $newManifest = [ordered]@{
        schemaVersion = 1
        packageKind = 'compiled'
        version = '9.0.0'
        entry = 'Watchdog.exe'
        managedPaths = @('Watchdog.exe', 'VERSION', 'assets', 'runtime',
            'third_party', 'update-manifest.json')
    }
    $newManifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath `
        (Join-Path $packageRoot 'update-manifest.json') -Encoding UTF8
    Compress-Archive -Path (Join-Path $packageRoot '*') `
        -DestinationPath $archivePath
    $archiveHash = (Get-FileHash -Algorithm SHA256 `
        -LiteralPath $archivePath).Hash

    Set-Content -LiteralPath (Join-Path $installRoot 'OldWatchdog.exe') `
        -Encoding UTF8 -Value 'old entry'
    New-Item -ItemType Directory -Force `
        -Path (Join-Path $installRoot 'legacy') | Out-Null
    Set-Content -LiteralPath (Join-Path $installRoot 'legacy\old.txt') `
        -Encoding UTF8 -Value 'old resource'
    Set-Content -LiteralPath (Join-Path $installRoot 'watchdog.ini') `
        -Encoding Unicode -Value '[Settings]'
    Set-Content -LiteralPath `
        (Join-Path $installRoot 'watchdog.maintenance.ini') `
        -Encoding Unicode -Value '[Sessions]'
    $oldManifest = [ordered]@{
        schemaVersion = 1
        packageKind = 'compiled'
        version = '8.0.0'
        entry = 'OldWatchdog.exe'
        managedPaths = @('OldWatchdog.exe', 'legacy',
            'update-manifest.json')
    }
    $oldManifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath `
        (Join-Path $installRoot 'update-manifest.json') -Encoding UTF8

    & $installerPath -ArchivePath $archivePath -InstallRoot $installRoot `
        -ExpectedVersion '9.0.0' -ExpectedSha256 $archiveHash `
        -PayloadMarker $archiveHash
    Assert-StandaloneInstaller `
        (Test-Path -LiteralPath (Join-Path $installRoot 'Watchdog.exe')) `
        '独立载荷没有安装新版入口。'
    Assert-StandaloneInstaller `
        (-not (Test-Path -LiteralPath `
            (Join-Path $installRoot 'OldWatchdog.exe')) -and
         -not (Test-Path -LiteralPath (Join-Path $installRoot 'legacy'))) `
        '旧清单中已经移除的受管文件仍然残留。'
    Assert-StandaloneInstaller `
        ((Get-Content -LiteralPath (Join-Path $installRoot 'watchdog.ini') `
            -Raw -Encoding Unicode).Trim() -ceq '[Settings]' -and
         (Get-Content -LiteralPath `
            (Join-Path $installRoot 'watchdog.maintenance.ini') `
            -Raw -Encoding Unicode).Trim() -ceq '[Sessions]') `
        '独立载荷安装覆盖了个人配置或维护会话。'
    Assert-StandaloneInstaller `
        ((Get-Content -LiteralPath `
            (Join-Path $installRoot '.standalone-payload.sha256') `
            -Raw -Encoding ASCII).Trim() -ceq $archiveHash) `
        '独立载荷安装没有在事务完成后写入校验标记。'

    $downgradeRejected = $false
    try {
        & $installerPath -ArchivePath $archivePath -InstallRoot $installRoot `
            -ExpectedVersion '8.0.0' -ExpectedSha256 $archiveHash `
            -PayloadMarker $archiveHash
    } catch {
        $downgradeRejected = $_.Exception.Message -like `
            'A newer standalone installation*'
    }
    Assert-StandaloneInstaller $downgradeRejected `
        '独立安装器没有在读取载荷前拒绝版本降级。'
    Assert-StandaloneInstaller `
        ((Get-Content -LiteralPath (Join-Path $installRoot 'VERSION') `
            -Raw -Encoding UTF8).Trim() -ceq '9.0.0') `
        '拒绝降级后既有安装版本发生变化。'

    $entryStream = [System.IO.File]::Open(
        (Join-Path $installRoot 'Watchdog.exe'),
        [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::Read)
    try {
        $lockedInstallRejected = $false
        try {
            & $installerPath -ArchivePath $archivePath `
                -InstallRoot $installRoot -ExpectedVersion '9.0.0' `
                -ExpectedSha256 $archiveHash -PayloadMarker $archiveHash
        } catch {
            $lockedInstallRejected = $true
        }
        Assert-StandaloneInstaller $lockedInstallRejected `
            '入口被占用时独立安装仍开始替换资源。'
        Assert-StandaloneInstaller `
            (Test-Path -LiteralPath (Join-Path $installRoot `
                'runtime\resource.txt')) `
            '入口占用失败破坏了既有完整安装。'
    } finally {
        $entryStream.Dispose()
    }
} finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force `
        -ErrorAction SilentlyContinue
}

Write-Host 'Standalone installer tests passed.'
