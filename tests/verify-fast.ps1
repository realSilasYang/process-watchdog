# 不依赖 Git LFS 大文件或真实 GUI 的快速必需门禁。
# 适合每个提交和纯文档拉取请求；字体这里只验证清单、授权和文件布局，字体实际
# 字节哈希由 Windows 集成与完整发行门禁验证。

[CmdletBinding()]
param(
    [string]$ActionlintPath = "",
    [string]$GitleaksPath = ""
)

$ErrorActionPreference = 'Stop'

& (Join-Path $PSScriptRoot '..\tools\verify-dependencies.ps1')
& (Join-Path $PSScriptRoot 'static-check.ps1') `
    -SkipPackagedFontContentValidation
& (Join-Path $PSScriptRoot 'application-update-helper-tests.ps1')
& (Join-Path $PSScriptRoot 'ci-impact-tests.ps1')
& (Join-Path $PSScriptRoot 'release-engineering-tests.ps1')
& (Join-Path $PSScriptRoot 'repository-check.ps1')
& (Join-Path $PSScriptRoot 'verify-publication.ps1') `
    -GitleaksPath $GitleaksPath
& (Join-Path $PSScriptRoot 'verify-workflows.ps1') `
    -ActionlintPath $ActionlintPath

Write-Host 'Fast required verification passed.'
