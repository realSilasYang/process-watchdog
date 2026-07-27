# 对 GitHub 草稿或公开 Release 执行同一套强校验：唯一记录、正文、提交、标签、
# 三附件白名单及 GitHub 摘要必须全部与本次本地构建一致。

[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Draft', 'Published')]
    [string]$Stage,
    [string]$Version = "",
    [string]$CommitSha = "",
    [string]$Repository = $env:GITHUB_REPOSITORY,
    [string]$Remote = 'origin',
    [string]$ArtifactDirectory = "",
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
    $CommitSha = (git -C $projectRoot rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw '无法读取当前提交。' }
}
if (-not $Repository) { throw '缺少 GitHub 仓库名。' }
if (-not $ArtifactDirectory) { $ArtifactDirectory = Join-Path $projectRoot 'dist' }
if (-not $BodyPath) {
    $BodyPath = Join-Path $projectRoot "docs\release-notes\v$Version.md"
}

$lastError = $null
for ($attempt = 1; $attempt -le 4; $attempt++) {
    try {
        $releasePagesJson = gh api --paginate --slurp `
            "repos/$Repository/releases?per_page=100"
        if ($LASTEXITCODE -ne 0) { throw '无法读取 GitHub Release 列表。' }
        $releasePages = $releasePagesJson | ConvertFrom-Json
        $matchingReleases = @($releasePages | ForEach-Object { $_ } |
            Where-Object { [string]$_.tag_name -ceq "v$Version" })
        if ($matchingReleases.Count -ne 1) {
            throw "无法唯一识别 Release v$Version：$($matchingReleases.Count) 条。"
        }

        $tagLines = @(git -C $projectRoot ls-remote --tags $Remote `
            "refs/tags/v$Version" "refs/tags/v$Version^{}")
        if ($LASTEXITCODE -ne 0) { throw "无法读取远程标签：v$Version" }
        $tagCommit = ""
        if ($tagLines.Count -ne 0) {
            $peeledLine = $tagLines | Where-Object { $_ -match '\^\{\}$' } |
                Select-Object -First 1
            $selectedLine = if ($peeledLine) { $peeledLine } else { $tagLines[0] }
            if ($selectedLine -notmatch '^([0-9A-Fa-f]{40})\s+') {
                throw "远程标签记录无法解析：$selectedLine"
            }
            $tagCommit = $Matches[1]
        }
        Assert-ReleaseRecord -Release $matchingReleases[0] -Version $Version `
            -CommitSha $CommitSha -Stage $Stage -BodyPath $BodyPath `
            -LocalArtifactDirectory $ArtifactDirectory `
            -TagCommitSha $tagCommit
        Write-Host "GitHub $Stage Release v$Version 已通过最终审计。"
        return
    } catch {
        $lastError = $_
        if ($attempt -lt 4) {
            Write-Warning "第 $attempt 次 Release 审计尚未通过，等待 GitHub 状态收敛后重试。"
            Start-Sleep -Seconds (2 * $attempt)
        }
    }
}
throw $lastError
