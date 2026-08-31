# 公开发行物的下载后验收入口。
# 从 GitHub 实际下载两个程序版本和可选字体包，核对远端摘要，再解压并复用完整
# 发行包校验，防止只验证上传前的本地 dist 而漏过托管、传输或压缩包内容问题。

[CmdletBinding()]
param(
    [string]$Version = "",
    [string]$CommitSha = "",
    [string]$Repository = $env:GITHUB_REPOSITORY,
    [string]$BodyPath = ""
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $PSScriptRoot 'ReleaseEngineering.psm1') -Force
if (-not $Version) {
    $Version = (Get-Content -LiteralPath (Join-Path $projectRoot 'VERSION') `
        -Raw -Encoding UTF8).Trim()
}
if (-not $CommitSha) {
    $CommitSha = (git -C $projectRoot rev-list -n 1 "v$Version" `
        2>$null).Trim()
    if (-not $CommitSha) {
        $CommitSha = (git -C $projectRoot rev-parse HEAD).Trim()
    }
    if ($LASTEXITCODE -ne 0 -or -not $CommitSha) {
        throw '无法读取目标版本提交。'
    }
}
if (-not $Repository) {
    $Repository = (gh repo view --json nameWithOwner `
        --jq '.nameWithOwner').Trim()
    if ($LASTEXITCODE -ne 0 -or -not $Repository) {
        throw '无法识别 GitHub 仓库，请显式传入 -Repository。'
    }
}
if (-not $BodyPath) {
    $BodyPath = Join-Path $projectRoot "docs\release-notes\v$Version.md"
}

$tempRoot = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
$auditRoot = Join-Path $tempRoot `
    ('ProcessWatchdogPublishedReleaseAudit-' + [Guid]::NewGuid().ToString('N'))
$fullAuditRoot = [System.IO.Path]::GetFullPath($auditRoot)
if (-not $fullAuditRoot.StartsWith($tempRoot,
        [System.StringComparison]::OrdinalIgnoreCase) -or
    -not ([System.IO.Path]::GetFileName($fullAuditRoot)).StartsWith(
        'ProcessWatchdogPublishedReleaseAudit-',
        [System.StringComparison]::Ordinal)) {
    throw "公开发行物审计目录不在受控临时目录中：$fullAuditRoot"
}

New-Item -ItemType Directory -Path $fullAuditRoot | Out-Null
try {
    gh release download "v$Version" --repo $Repository `
        --dir $fullAuditRoot
    if ($LASTEXITCODE -ne 0) {
        throw "无法下载 GitHub Release v$Version。"
    }

    & (Join-Path $PSScriptRoot 'verify-github-release.ps1') `
        -Stage Published -Version $Version -CommitSha $CommitSha `
        -Repository $Repository -ArtifactDirectory $fullAuditRoot `
        -BodyPath $BodyPath

    $portableArchivePath = Join-Path $fullAuditRoot `
        "process-watchdog-$Version-windows-x64.zip"
    $sourceArchivePath = Join-Path $fullAuditRoot `
        "process-watchdog-$Version-source.zip"
    $fontArchivePath = Join-Path $fullAuditRoot 'fonts.zip'
    $portableRoot = Join-Path $fullAuditRoot 'portable'
    $sourceRoot = Join-Path $fullAuditRoot 'source'
    $fontRoot = Join-Path $fullAuditRoot 'fonts'
    Expand-Archive -LiteralPath $portableArchivePath `
        -DestinationPath $portableRoot
    Expand-Archive -LiteralPath $sourceArchivePath `
        -DestinationPath $sourceRoot
    Expand-Archive -LiteralPath $fontArchivePath `
        -DestinationPath $fontRoot

    # 正式发布动态解析上游最新版；包内快照才是本次构建实际使用的事实源。
    # 仓库的 ci-toolchain.resolved.json 只服务普通 CI，不能替代这里的快照。
    $resolvedToolchainPath = Join-Path $portableRoot `
        'build-metadata\toolchain.resolved.json'
    & (Join-Path $PSScriptRoot 'verify-release.ps1') `
        -PackageDirectory $portableRoot `
        -SourcePackageDirectory $sourceRoot `
        -FontPackageDirectory $fontRoot `
        -ResolvedToolchainPath $resolvedToolchainPath

    Write-Host "GitHub 实际托管的 v$Version 两个程序版本和可选字体包已通过下载后验收。"
} finally {
    if (Test-Path -LiteralPath $fullAuditRoot) {
        Remove-Item -LiteralPath $fullAuditRoot -Recurse -Force
    }
}
