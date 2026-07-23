[CmdletBinding()]
param(
    [string]$AutoHotkeyPath = "",
    [string]$ActionlintPath = ""
)

$ErrorActionPreference = 'Stop'

& (Join-Path $PSScriptRoot '..\tools\verify-dependencies.ps1')
& (Join-Path $PSScriptRoot 'static-check.ps1')
& (Join-Path $PSScriptRoot 'run-core-tests.ps1') `
    -AutoHotkeyPath $AutoHotkeyPath
& (Join-Path $PSScriptRoot 'repository-check.ps1')
& (Join-Path $PSScriptRoot 'verify-workflows.ps1') `
    -ActionlintPath $ActionlintPath

Write-Host 'All required verification suites passed.'
