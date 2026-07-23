[CmdletBinding()]
param(
    [string]$AutoHotkeyPath = ""
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$ahkCandidates = @(
    $AutoHotkeyPath,
    $env:AUTOHOTKEY_EXE,
    (Join-Path $projectRoot '.tools\AutoHotkey-2.0.26\AutoHotkey64.exe'),
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
    $process = [System.Diagnostics.Process]::Start($startInfo)
    if (-not $process.WaitForExit($TimeoutMilliseconds)) {
        try {
            $process.Kill()
            $process.WaitForExit(5000) | Out-Null
        } catch {
        }
        throw "$FailureMessage AutoHotkey process timed out after $TimeoutMilliseconds ms."
    }
    $standardOutput = $process.StandardOutput.ReadToEnd()
    $standardError = $process.StandardError.ReadToEnd()
    if ($standardOutput) {
        Write-Host $standardOutput.TrimEnd()
    }
    if ($standardError) {
        Write-Error $standardError.TrimEnd()
    }
    if ($process.ExitCode -ne 0) {
        throw $FailureMessage
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
        if ($workerHeader -notmatch '^SNAPSHOT\|\d+$') {
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
        Invoke-AutoHotkeyTest "/ErrorStdOut `"$($testScript.FullName)`"" `
            "Core test failed: $($testScript.Name)"
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
