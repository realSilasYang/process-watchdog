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
$sourceAhkPath = $candidates | Where-Object {
    Test-Path -LiteralPath $_ -PathType Leaf
} | Select-Object -First 1
if (-not $sourceAhkPath) {
    throw 'AutoHotkey v2 x64 interpreter was not found.'
}

# 每轮 GUI 验证使用随机中性宿主，避免用户为 AutoHotkey64.exe 配置的提权、
# 兼容层或前次残留进程污染 Win32 窗口消息和超时清理。
$testHostRoot = Join-Path ([System.IO.Path]::GetTempPath()) `
    ("process-watchdog-gui-host-{0}" -f [guid]::NewGuid().ToString('N'))
$ahkPath = Join-Path $testHostRoot `
    ("WatchdogTestHost-{0}.exe" -f [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $testHostRoot -Force | Out-Null
    Copy-Item -LiteralPath $sourceAhkPath -Destination $ahkPath -Force
} catch {
    Remove-Item -LiteralPath $testHostRoot -Recurse -Force `
        -ErrorAction SilentlyContinue
    throw
}

function Stop-GuiTestTree {
    param([Parameter(Mandatory = $true)][System.Diagnostics.Process]$Process)

    if ($Process.HasExited) {
        return
    }
    try {
        & (Join-Path $env:SystemRoot 'System32\taskkill.exe') `
            /PID $Process.Id /T /F 2>$null | Out-Null
    } catch {
    }
    try {
        if (-not $Process.WaitForExit(5000)) {
            $Process.Kill()
            [void]$Process.WaitForExit(5000)
        }
    } catch {
    }
}

function Invoke-GuiTest {
    param(
        [string]$ScriptPath,
        [string]$Arguments = "",
        [int]$TimeoutMilliseconds = 60000
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
        Stop-GuiTestTree $process
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

try {
    Write-Host 'Running GUI smoke test...'
    Invoke-GuiTest (Join-Path $PSScriptRoot 'gui\gui-smoke-tests.ahk')
    Write-Host 'Running UI scale test...'
    Invoke-GuiTest (Join-Path $PSScriptRoot 'gui\ui-scale-tests.ahk')
    Write-Host 'Running history-toast interaction test...'
    Invoke-GuiTest (Join-Path $PSScriptRoot 'gui\history-toast-tests.ahk')
    Write-Host 'Running shared message-box layout test...'
    Invoke-GuiTest (Join-Path $PSScriptRoot `
        'gui\dark-message-box-layout-tests.ahk')
    Write-Host 'Running inline-edit dark-theme test...'
    Invoke-GuiTest (Join-Path $PSScriptRoot `
        'gui\inline-edit-theme-tests.ahk')
    Write-Host 'Running log-window and diagnostic smoke test...'
    Invoke-GuiTest (Join-Path $PSScriptRoot 'gui\log-window-smoke-tests.ahk')
    Write-Host "Running GUI resource soak for $SoakSeconds seconds..."
    Invoke-GuiTest (Join-Path $PSScriptRoot 'gui\resource-soak-tests.ahk') `
        -Arguments $SoakSeconds `
        -TimeoutMilliseconds (($SoakSeconds + 30) * 1000)

    Write-Host 'GUI smoke and resource soak tests passed.'
} finally {
    Remove-Item -LiteralPath $testHostRoot -Recurse -Force
}
