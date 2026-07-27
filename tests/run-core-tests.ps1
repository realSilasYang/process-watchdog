# AHK 核心测试调度器。
# 先验证主入口和快照工作器可独立退出，再逐项运行核心测试，并保证测试前后用户配置哈希不变。

[CmdletBinding()]
param(
    [string]$AutoHotkeyPath = ""
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$resolvedLocalAhk = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot '.tools') `
    -Recurse -File -Filter 'AutoHotkey64.exe' -ErrorAction SilentlyContinue |
    Sort-Object { try { [Version]$_.VersionInfo.FileVersion } catch { [Version]'0.0' } } `
        -Descending | ForEach-Object { $_.FullName })
$ahkCandidates = @(
    $AutoHotkeyPath,
    $env:AUTOHOTKEY_EXE,
    $resolvedLocalAhk,
    'D:\Program Files\AutoHotkey\v2\AutoHotkey64.exe',
    "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe"
) | Where-Object { $_ }
$ahkPath = $ahkCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $ahkPath) {
    throw 'AutoHotkey v2 64-bit interpreter was not found.'
}

function Invoke-AutoHotkeyTest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Arguments,
        [Parameter(Mandatory = $true)]
        [string]$FailureMessage,
        [int]$TimeoutMilliseconds = 30000
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $ahkPath
    $startInfo.Arguments = $Arguments
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.StandardOutputEncoding = [System.Text.Encoding]::Default
    $startInfo.StandardErrorEncoding = [System.Text.Encoding]::Default
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $standardOutputTask = $process.StandardOutput.ReadToEndAsync()
    $standardErrorTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutMilliseconds)) {
        try {
            $process.Kill()
            $process.WaitForExit(5000) | Out-Null
        } catch {
        }
        throw "$FailureMessage AutoHotkey process timed out after $TimeoutMilliseconds ms."
    }
    $standardOutput = $standardOutputTask.GetAwaiter().GetResult()
    $standardError = $standardErrorTask.GetAwaiter().GetResult()
    if ($standardOutput) {
        Write-Host $standardOutput.TrimEnd()
    }
    if ($process.ExitCode -ne 0) {
        throw "$FailureMessage`n$($standardError.TrimEnd())"
    }
    if ($standardError) {
        throw "$FailureMessage AutoHotkey wrote to standard error:`n$($standardError.TrimEnd())"
    }
}

$configurationPath = Join-Path $projectRoot 'watchdog.ini'
$configurationHashBefore = if (Test-Path -LiteralPath $configurationPath) {
    (Get-FileHash -Algorithm SHA256 -LiteralPath $configurationPath).Hash
} else {
    $null
}

try {
    $mainScript = Get-ChildItem -LiteralPath $projectRoot -Filter '*.ahk' -File |
        Where-Object { $_.Name -notlike '_*' } |
        Select-Object -First 1
    if (-not $mainScript) {
        throw 'The main AutoHotkey script was not found.'
    }
    Invoke-AutoHotkeyTest "/ErrorStdOut `"$($mainScript.FullName)`" --startup-validation" `
        'Main-script startup validation failed.'
    Write-Host 'Main-script startup validation passed.'

    $workerOutputPath = Join-Path $env:TEMP `
        ("watchdog-worker-exit-validation-{0}.tmp" -f [guid]::NewGuid().ToString('N'))
    try {
        Invoke-AutoHotkeyTest `
            "/ErrorStdOut `"$($mainScript.FullName)`" --process-snapshot-worker `"$workerOutputPath`"" `
            'Process-snapshot worker exit validation failed.'
        if (-not (Test-Path -LiteralPath $workerOutputPath)) {
            throw 'Process-snapshot worker did not publish its result file.'
        }
        $workerHeader = Get-Content -LiteralPath $workerOutputPath `
            -Encoding Unicode -TotalCount 1
        if ($workerHeader -notmatch '^SNAPSHOT\|\d+\|\d+$') {
            throw 'Process-snapshot worker published an invalid result header.'
        }
        Write-Host 'Process-snapshot worker exit validation passed.'
    } finally {
        Remove-Item -LiteralPath $workerOutputPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath ($workerOutputPath + '.writing') -Force `
            -ErrorAction SilentlyContinue
    }

    $testScripts = Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'core') -Filter '*-tests.ahk' -File
    if (-not $testScripts.Count) {
        throw 'No core AHK tests were found.'
    }

    foreach ($testScript in $testScripts) {
        $testTimeoutMilliseconds = if ($testScript.Name -eq
            'live-command-target-tests.ahk') { 120000 } else { 30000 }
        Invoke-AutoHotkeyTest "/ErrorStdOut `"$($testScript.FullName)`"" `
            "Core test failed: $($testScript.Name)" `
            -TimeoutMilliseconds $testTimeoutMilliseconds
    }

    Write-Host "Core tests passed: $($testScripts.Count) scripts."
} finally {
    $configurationHashAfter = if (Test-Path -LiteralPath $configurationPath) {
        (Get-FileHash -Algorithm SHA256 -LiteralPath $configurationPath).Hash
    } else {
        $null
    }
    if ($configurationHashAfter -ne $configurationHashBefore) {
        throw 'Core tests modified the project watchdog.ini configuration.'
    }
}
