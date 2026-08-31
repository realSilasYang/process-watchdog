# 本地正式发布预检的单一入口。
# 该脚本自动进入 PowerShell 7，刷新本次上游构建工具快照，并依次执行与发布相关的
# 必需测试、真实 Windows/GUI 长测和 PowerShell 7/5.1 双宿主可复现构建。

[CmdletBinding()]
param(
    [ValidateRange(1, 3600)][int]$SoakSeconds = 300,
    [string]$PowerShell7Path = ""
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path -Parent $PSScriptRoot

if ($PSVersionTable.PSVersion.Major -lt 7) {
    $pwsh = if ($PowerShell7Path) {
        [System.IO.Path]::GetFullPath($PowerShell7Path)
    } else {
        & (Join-Path $PSScriptRoot 'bootstrap-powershell7.ps1')
    }
    if (-not (Test-Path -LiteralPath $pwsh -PathType Leaf)) {
        throw "本地发布预检找不到 PowerShell 7：$pwsh"
    }
    & $pwsh -NoLogo -NoProfile -File $PSCommandPath `
        -SoakSeconds $SoakSeconds -PowerShell7Path $pwsh
    if ($LASTEXITCODE -ne 0) {
        throw "PowerShell 7 发布预检失败，退出码：$LASTEXITCODE"
    }
    return
}

$windowsPowerShell = (Get-Command powershell.exe -ErrorAction Stop).Source
$toolchain = & (Join-Path $PSScriptRoot 'bootstrap-toolchain.ps1') `
    -RefreshBuildTools
Write-Host '开始执行完整必需测试……'
& (Join-Path $projectRoot 'tests\verify.ps1') `
    -AutoHotkeyPath $toolchain.AutoHotkeyPath `
    -ActionlintPath $toolchain.ActionlintPath `
    -GitleaksPath $toolchain.GitleaksPath

Write-Host "开始执行 $SoakSeconds 秒 Windows/GUI 集成验证……"
& (Join-Path $projectRoot 'tests\verify-windows-integration.ps1') `
    -AutoHotkeyPath $toolchain.AutoHotkeyPath -SoakSeconds $SoakSeconds

Write-Host '开始执行 PowerShell 7 与 Windows PowerShell 5.1 可复现构建……'
& (Join-Path $projectRoot 'tests\reproducible-build.ps1') `
    -AutoHotkeyPath $toolchain.AutoHotkeyPath `
    -CompilerPath $toolchain.CompilerPath `
    -AutoHotkeySourcePath $toolchain.AutoHotkeySourcePath `
    -ResolvedToolchainPath $toolchain.ResolvedToolchainPath `
    -SecondPowerShellPath $windowsPowerShell

Write-Host '本地正式发布预检已全部通过。'
