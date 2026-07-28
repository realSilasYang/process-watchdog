# 发行程序启动验收的统一进程边界。
# 为主程序和独立 EXE 提供相同的超时、隔离环境、进程树回收与诊断日志收集，
# 防止编译后的脚本错误框让无人值守的 CI 永久等待。

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ExecutablePath,
    [string]$WorkingDirectory = "",
    [string]$LocalAppData = "",
    [ValidateRange(1, 600)][int]$TimeoutSeconds = 90,
    [string]$FailureLabel = 'Compiled startup validation'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$executable = [System.IO.Path]::GetFullPath($ExecutablePath)
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    throw "Startup validation executable does not exist: $executable"
}
$workingRoot = if ($WorkingDirectory) {
    [System.IO.Path]::GetFullPath($WorkingDirectory)
} else {
    Split-Path -Parent $executable
}
if (-not (Test-Path -LiteralPath $workingRoot -PathType Container)) {
    throw "Startup validation working directory does not exist: $workingRoot"
}
if ($LocalAppData) {
    $isolatedLocalAppData = [System.IO.Path]::GetFullPath($LocalAppData)
    New-Item -ItemType Directory -Force -Path $isolatedLocalAppData |
        Out-Null
}

$startedAtUtc = [DateTime]::UtcNow.AddSeconds(-1)
$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $executable
$startInfo.Arguments = '--startup-validation'
$startInfo.WorkingDirectory = $workingRoot
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
if ($LocalAppData) {
    $startInfo.EnvironmentVariables['LOCALAPPDATA'] = $isolatedLocalAppData
}

$process = $null
try {
    $process = [System.Diagnostics.Process]::Start($startInfo)
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        # 启动器可能正等待内层程序，普通 Kill 只结束父进程。taskkill /T 仅针对
        # 本次验收创建的 PID 回收整棵进程树，避免测试进程泄漏到后续步骤。
        try {
            & (Join-Path $env:SystemRoot 'System32\taskkill.exe') `
                /PID $process.Id /T /F 2>$null | Out-Null
        } catch {
            try { $process.Kill() } catch {}
        }
        throw "$FailureLabel timed out after $TimeoutSeconds seconds."
    }
    if ($process.ExitCode -ne 0) {
        $diagnosticText = @()
        $diagnosticLogs = @(Get-ChildItem -LiteralPath `
            ([System.IO.Path]::GetTempPath()) `
            -Filter 'ProcessWatchdogStandaloneValidation-*.log' `
            -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTimeUtc -ge $startedAtUtc } |
            Sort-Object LastWriteTimeUtc)
        foreach ($diagnosticLog in $diagnosticLogs) {
            try {
                $diagnosticText += (Get-Content -LiteralPath `
                    $diagnosticLog.FullName -Raw -Encoding UTF8).Trim()
            } catch {}
        }
        $details = @($diagnosticText | Where-Object { $_ }) -join "`n"
        if ($details) {
            throw "$FailureLabel failed with exit code $($process.ExitCode).`n$details"
        }
        throw "$FailureLabel failed with exit code $($process.ExitCode)."
    }
} finally {
    if ($process) { $process.Dispose() }
}
