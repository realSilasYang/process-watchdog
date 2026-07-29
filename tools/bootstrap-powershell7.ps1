# 为本地发布预检准备官方便携 PowerShell 7。
# 只写入被 Git 忽略的 .tools 目录，并使用同一 GitHub Release 提供的 SHA-256
# 清单验证 ZIP；不会安装系统组件、修改 PATH 或覆盖仓库文件。

[CmdletBinding()]
param([string]$Destination = "")

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$toolsRoot = if ($Destination) {
    [System.IO.Path]::GetFullPath($Destination)
} else {
    Join-Path $projectRoot '.tools'
}
$toolsRootWithSeparator = $toolsRoot.TrimEnd('\') + '\'

function Assert-PowerShellToolPath {
    param([Parameter(Mandatory)][string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not $fullPath.StartsWith($toolsRootWithSeparator,
            [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "拒绝修改 PowerShell 工具目录之外的路径：$fullPath"
    }
    return $fullPath
}

[Net.ServicePointManager]::SecurityProtocol =
    [Net.ServicePointManager]::SecurityProtocol -bor
    [Net.SecurityProtocolType]::Tls12
$headers = @{
    Accept = 'application/vnd.github+json'
    'User-Agent' = 'process-watchdog-release-preflight'
    'X-GitHub-Api-Version' = '2022-11-28'
}
$release = Invoke-RestMethod -UseBasicParsing -Headers $headers `
    -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest' `
    -TimeoutSec 60
$version = ([string]$release.tag_name).TrimStart('v')
if ($version -notmatch '^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$') {
    throw "PowerShell 上游返回了无效稳定版本：$($release.tag_name)"
}
$archiveName = "PowerShell-$version-win-x64.zip"
$archiveAsset = @($release.assets | Where-Object name -ceq $archiveName)
$hashAsset = @($release.assets | Where-Object name -ceq 'hashes.sha256')
if ($archiveAsset.Count -ne 1 -or $hashAsset.Count -ne 1) {
    throw "PowerShell $version Release 缺少唯一的 x64 ZIP 或摘要清单。"
}

$cacheRoot = Assert-PowerShellToolPath (Join-Path $toolsRoot 'cache\PowerShell')
$installRoot = Assert-PowerShellToolPath `
    (Join-Path $toolsRoot "PowerShell-$version")
New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null
$archivePath = Assert-PowerShellToolPath (Join-Path $cacheRoot $archiveName)
$hashPath = Assert-PowerShellToolPath `
    (Join-Path $cacheRoot "PowerShell-$version-hashes.sha256")

if (-not (Test-Path -LiteralPath $hashPath -PathType Leaf)) {
    Invoke-WebRequest -UseBasicParsing -Headers $headers `
        -Uri ([string]$hashAsset[0].browser_download_url) `
        -OutFile $hashPath -TimeoutSec 180
}
$hashLine = Get-Content -LiteralPath $hashPath -Encoding UTF8 |
    Where-Object { $_ -match [regex]::Escape($archiveName) } |
    Select-Object -First 1
if (-not $hashLine -or $hashLine -notmatch '^([0-9A-Fa-f]{64})\s+') {
    throw "无法从 PowerShell 官方摘要清单解析：$archiveName"
}
$expectedHash = $Matches[1].ToUpperInvariant()
$archiveIsValid = (Test-Path -LiteralPath $archivePath -PathType Leaf) -and
    ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash -ceq
        $expectedHash)
if (-not $archiveIsValid) {
    if (Test-Path -LiteralPath $archivePath) {
        Remove-Item -LiteralPath $archivePath -Force
    }
    Write-Host "正在下载官方便携 PowerShell $version……"
    Invoke-WebRequest -UseBasicParsing -Headers $headers `
        -Uri ([string]$archiveAsset[0].browser_download_url) `
        -OutFile $archivePath -TimeoutSec 300
    $actualHash = (Get-FileHash -LiteralPath $archivePath `
        -Algorithm SHA256).Hash
    if ($actualHash -cne $expectedHash) {
        Remove-Item -LiteralPath $archivePath -Force
        throw "PowerShell ZIP 摘要不匹配：$actualHash"
    }
}

$executablePath = Join-Path $installRoot 'pwsh.exe'
if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
    if (Test-Path -LiteralPath $installRoot) {
        [void](Assert-PowerShellToolPath $installRoot)
        Remove-Item -LiteralPath $installRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Path $installRoot | Out-Null
    Expand-Archive -LiteralPath $archivePath -DestinationPath $installRoot
}
& $executablePath -NoLogo -NoProfile -Command `
    'if ($PSVersionTable.PSVersion.Major -lt 7) { exit 1 }'
if ($LASTEXITCODE -ne 0) {
    throw "便携 PowerShell 7 无法启动：$executablePath"
}
return $executablePath
