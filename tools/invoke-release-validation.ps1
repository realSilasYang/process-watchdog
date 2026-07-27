# CI、发布演练与正式发布共用的完整门禁，确保三条路径不会逐渐产生不同测试范围。

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$AutoHotkeyPath,
    [Parameter(Mandatory)][string]$CompilerPath,
    [Parameter(Mandatory)][string]$AutoHotkeySourcePath,
    [Parameter(Mandatory)][string]$ResolvedToolchainPath,
    [Parameter(Mandatory)][string]$ActionlintPath,
    [Parameter(Mandatory)][string]$GitleaksPath,
    [int]$SoakSeconds = 15,
    [string]$OutputDirectory = ""
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $projectRoot 'tests\verify.ps1') `
    -AutoHotkeyPath $AutoHotkeyPath -ActionlintPath $ActionlintPath `
    -GitleaksPath $GitleaksPath
& (Join-Path $projectRoot 'tests\run-gui-tests.ps1') `
    -AutoHotkeyPath $AutoHotkeyPath -SoakSeconds $SoakSeconds
$buildArguments = @{
    AutoHotkeyPath = $AutoHotkeyPath
    CompilerPath = $CompilerPath
    AutoHotkeySourcePath = $AutoHotkeySourcePath
    ResolvedToolchainPath = $ResolvedToolchainPath
}
if ($OutputDirectory) { $buildArguments.OutputDirectory = $OutputDirectory }
& (Join-Path $projectRoot 'tests\reproducible-build.ps1') @buildArguments
Write-Host '完整发布门禁已通过。'
