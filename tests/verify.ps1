# 项目必需验证套件的统一入口。
# 依次执行依赖、静态、核心、仓库、公开发布和工作流检查，任一阶段失败都会立即停止。

[CmdletBinding()]
param(
    [string]$AutoHotkeyPath = "",
    [string]$ActionlintPath = "",
    [string]$GitleaksPath = ""
)

$ErrorActionPreference = 'Stop'

& (Join-Path $PSScriptRoot 'verify-fast.ps1') `
    -ActionlintPath $ActionlintPath -GitleaksPath $GitleaksPath
& (Join-Path $PSScriptRoot 'run-core-tests.ps1') `
    -AutoHotkeyPath $AutoHotkeyPath

Write-Host 'All required verification suites passed.'
