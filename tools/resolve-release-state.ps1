# 读取 GitHub 的完整 Release 集合和远程标签，调用共享状态机决定能否开始或续传发布。

[CmdletBinding()]
param(
    [string]$Version = "",
    [string]$CommitSha = "",
    [string]$Repository = $env:GITHUB_REPOSITORY,
    [string]$Remote = 'origin',
    [string]$GitHubOutputPath = $env:GITHUB_OUTPUT
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
    if ($LASTEXITCODE -ne 0) {
        throw '无法读取当前提交。'
    }
}
if (-not $Repository) {
    throw '缺少 GitHub 仓库名。'
}

$releasePagesJson = gh api --paginate --slurp `
    "repos/$Repository/releases?per_page=100"
if ($LASTEXITCODE -ne 0) {
    throw '无法读取 GitHub Release 列表。'
}
$releasePages = $releasePagesJson | ConvertFrom-Json
$releases = @($releasePages | ForEach-Object { $_ })
$tagName = "v$Version"
$tagLines = @(git -C $projectRoot ls-remote --tags $Remote `
    "refs/tags/$tagName" "refs/tags/$tagName^{}")
$tagExitCode = $LASTEXITCODE
if ($tagExitCode -ne 0) {
    throw "无法读取远程标签：$tagName"
}
$tagRecords = @()
if ($tagLines.Count -ne 0) {
    $peeledLine = $tagLines | Where-Object { $_ -match '\^\{\}$' } |
        Select-Object -First 1
    $selectedLine = if ($peeledLine) { $peeledLine } else { $tagLines[0] }
    if ($selectedLine -notmatch '^([0-9A-Fa-f]{40})\s+') {
        throw "远程标签记录无法解析：$selectedLine"
    }
    $tagRecords = @([pscustomobject]@{
        Name = $tagName
        CommitSha = $Matches[1]
    })
}
$state = Resolve-ReleaseState -Version $Version -CommitSha $CommitSha `
    -Tags $tagRecords -Releases $releases
if ($GitHubOutputPath) {
    @(
        "version=$($state.Version)"
        "tag=$($state.Tag)"
        "state=$($state.State)"
        "release_id=$($state.ReleaseId)"
    ) | Add-Content -LiteralPath $GitHubOutputPath -Encoding UTF8
}
Write-Host "发布状态：$($state.State)（$($state.Tag)，$($state.CommitSha)）"
return $state
