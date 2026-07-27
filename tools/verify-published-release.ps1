# 公开发布及远程标签最终审计入口。
[CmdletBinding()]
param(
    [string]$Version = "",
    [string]$CommitSha = "",
    [string]$Repository = $env:GITHUB_REPOSITORY,
    [string]$ArtifactDirectory = "",
    [string]$BodyPath = ""
)

$arguments = @{
    Stage = 'Published'
    Version = $Version
    CommitSha = $CommitSha
    Repository = $Repository
    ArtifactDirectory = $ArtifactDirectory
    BodyPath = $BodyPath
}
& (Join-Path $PSScriptRoot 'verify-github-release.ps1') @arguments
