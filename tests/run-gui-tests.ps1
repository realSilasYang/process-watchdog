[CmdletBinding()]
param(
    [string]$AutoHotkeyPath = "",
    [ValidateRange(1, 3600)]
    [int]$SoakSeconds = 10
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$candidates = @(
    $AutoHotkeyPath,
    $env:AUTOHOTKEY_EXE,
    (Join-Path $projectRoot '.tools\AutoHotkey-2.0.26\AutoHotkey64.exe'),
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
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $timedOut = -not $process.WaitForExit($TimeoutMilliseconds)
    if ($timedOut) {
        try {
            $process.Kill()
            [void]$process.WaitForExit(5000)
        } catch {}
    }
    $stdout = $process.StandardOutput.ReadToEnd().Trim()
    $stderr = $process.StandardError.ReadToEnd().Trim()
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
        Write-Warning $stderr
    }
}

Write-Host 'Running GUI smoke test...'
Invoke-GuiTest (Join-Path $PSScriptRoot 'gui\gui-smoke-tests.ahk')
Write-Host 'Running log-window and diagnostic smoke test...'
Invoke-GuiTest (Join-Path $PSScriptRoot 'gui\log-window-smoke-tests.ahk')
Write-Host "Running GUI resource soak for $SoakSeconds seconds..."
Invoke-GuiTest (Join-Path $PSScriptRoot 'gui\resource-soak-tests.ahk') `
    -Arguments $SoakSeconds `
    -TimeoutMilliseconds (($SoakSeconds + 30) * 1000)

Write-Host 'GUI smoke and resource soak tests passed.'
