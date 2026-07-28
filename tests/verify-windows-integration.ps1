# 需要真实 Windows 进程、控件和完整 LFS 字体资源的集成门禁。

[CmdletBinding()]
param(
    [string]$AutoHotkeyPath = "",
    [ValidateRange(1, 3600)][int]$SoakSeconds = 10
)

$ErrorActionPreference = 'Stop'

& (Join-Path $PSScriptRoot '..\tools\verify-dependencies.ps1')
& (Join-Path $PSScriptRoot 'static-check.ps1')
& (Join-Path $PSScriptRoot 'run-core-tests.ps1') `
    -AutoHotkeyPath $AutoHotkeyPath
& (Join-Path $PSScriptRoot 'run-gui-tests.ps1') `
    -AutoHotkeyPath $AutoHotkeyPath -SoakSeconds $SoakSeconds

Write-Host 'Windows process and GUI integration verification passed.'
