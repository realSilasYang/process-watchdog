# 真实 GUI 冒烟与资源循环测试调度器。
# 为每个测试设置独立超时并收集标准输出，避免无响应窗口或后台定时器让持续集成永久等待。

[CmdletBinding()]
param(
    [string]$AutoHotkeyPath = "",
    [ValidateRange(1, 3600)]
    [int]$SoakSeconds = 10
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$resolvedLocalAhk = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot '.tools') `
    -Recurse -File -Filter 'AutoHotkey64.exe' -ErrorAction SilentlyContinue |
    Sort-Object { try { [Version]$_.VersionInfo.FileVersion } catch { [Version]'0.0' } } `
        -Descending | ForEach-Object { $_.FullName })
$candidates = @(
    $AutoHotkeyPath,
    $env:AUTOHOTKEY_EXE,
    $resolvedLocalAhk,
    'D:\Program Files\AutoHotkey\v2\AutoHotkey64.exe',
    "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe"
) | Where-Object { $_ }
$ahkPath = $candidates | Where-Object {
    Test-Path -LiteralPath $_ -PathType Leaf
} | Select-Object -First 1
if (-not $ahkPath) {
    throw 'AutoHotkey v2 x64 interpreter was not found.'
}

function Invoke-GuiTest {
    param(
        [string]$ScriptPath,
        [string]$Arguments = "",
        [int]$TimeoutMilliseconds = 30000
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $ahkPath
    $startInfo.Arguments = "/ErrorStdOut `"$ScriptPath`" $Arguments"
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.StandardOutputEncoding = [System.Text.Encoding]::Default
    $startInfo.StandardErrorEncoding = [System.Text.Encoding]::Default
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $standardOutputTask = $process.StandardOutput.ReadToEndAsync()
    $standardErrorTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutMilliseconds)
    if ($timedOut) {
        try {
            $process.Kill()
            [void]$process.WaitForExit(5000)
        } catch {}
    }
    $stdout = $standardOutputTask.GetAwaiter().GetResult().Trim()
    $stderr = $standardErrorTask.GetAwaiter().GetResult().Trim()
    if ($stdout) {
        Write-Host $stdout
    }
    if ($timedOut) {
        throw "GUI test timed out: $ScriptPath`n$stdout`n$stderr"
    }
    if ($process.ExitCode -ne 0) {
        throw "GUI test failed with exit code $($process.ExitCode): " +
            "$ScriptPath`nSTDOUT:`n$stdout`nSTDERR:`n$stderr"
    }
    if ($stderr) {
        throw "GUI test wrote to standard error: $ScriptPath`n$stderr"
    }
}

Write-Host 'Running GUI smoke test...'
Invoke-GuiTest (Join-Path $PSScriptRoot 'gui\gui-smoke-tests.ahk')
Write-Host 'Running log-window and diagnostic smoke test...'
Invoke-GuiTest (Join-Path $PSScriptRoot 'gui\log-window-smoke-tests.ahk')
Write-Host 'Running 13-language production-window smoke test...'
Invoke-GuiTest (Join-Path $PSScriptRoot `
    'gui\localized-window-smoke-tests.ahk') -TimeoutMilliseconds 300000
Write-Host 'Running in-process language and font hot-switch test...'
Invoke-GuiTest (Join-Path $PSScriptRoot `
    'gui\display-hot-switch-tests.ahk') -TimeoutMilliseconds 180000
Write-Host "Running GUI resource soak for $SoakSeconds seconds..."
Invoke-GuiTest (Join-Path $PSScriptRoot 'gui\resource-soak-tests.ahk') `
    -Arguments $SoakSeconds `
    -TimeoutMilliseconds (($SoakSeconds + 30) * 1000)

Write-Host 'GUI smoke and resource soak tests passed.'
