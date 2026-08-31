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
$sourceAhkPath = $ahkCandidates | Where-Object {
    Test-Path -LiteralPath $_ -PathType Leaf
} | Select-Object -First 1
if (-not $sourceAhkPath) {
    throw 'AutoHotkey v2 64-bit interpreter was not found.'
}

# 使用随机中性文件名隔离 Windows 针对 AutoHotkey64.exe 保存的兼容层和
# 前次失败进程身份，确保本地发布与干净 CI 使用相同的普通权限测试宿主。
$testHostRoot = Join-Path ([System.IO.Path]::GetTempPath()) `
    ("process-watchdog-core-host-{0}" -f [guid]::NewGuid().ToString('N'))
$ahkPath = Join-Path $testHostRoot `
    ("AutoHotkeyWatchdogTest-{0}.exe" -f [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $testHostRoot -Force | Out-Null
    Copy-Item -LiteralPath $sourceAhkPath -Destination $ahkPath -Force
} catch {
    Remove-Item -LiteralPath $testHostRoot -Recurse -Force `
        -ErrorAction SilentlyContinue
    throw
}

function Stop-AutoHotkeyTestTree {
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
        Stop-AutoHotkeyTestTree $process
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

    # 生产扫描器默认排除 A_Temp，夹具必须位于该排除根之外才能验证真实命中。
    $contentWorkerRoot = Join-Path $PSScriptRoot `
        ("watchdog-content-worker-validation-{0}" -f [guid]::NewGuid().ToString('N'))
    $contentWorkerOutput = Join-Path $contentWorkerRoot 'result.tmp'
    try {
        $contentCandidateDirectory = Join-Path $contentWorkerRoot 'renamed-parent'
        New-Item -ItemType Directory -Path $contentCandidateDirectory -Force |
            Out-Null
        $contentCandidatePath = Join-Path $contentCandidateDirectory `
            'completely-renamed.ahk'
        $contentBytes = [System.Text.Encoding]::UTF8.GetBytes(
            "#Requires AutoHotkey v2.0`r`nMsgBox('content identity')`r`n")
        [System.IO.File]::WriteAllBytes($contentCandidatePath, $contentBytes)
        $missingPreviousPath = Join-Path $contentWorkerRoot 'original-name.ahk'
        $contentHash = (Get-FileHash -Algorithm SHA256 -LiteralPath `
            $contentCandidatePath).Hash
        Invoke-AutoHotkeyTest `
            "/ErrorStdOut `"$($mainScript.FullName)`" --content-match-worker `"$contentWorkerOutput`" `"$contentWorkerRoot`" `"$missingPreviousPath`" $($contentBytes.Length) $contentHash 0 10" `
            'Content-match worker exit validation failed.'
        if (-not (Test-Path -LiteralPath $contentWorkerOutput)) {
            throw 'Content-match worker did not publish its result file.'
        }
        $contentWorkerHeader = Get-Content -LiteralPath $contentWorkerOutput `
            -Encoding Unicode -TotalCount 1
        if ($contentWorkerHeader -ne 'COMPLETE|1') {
            throw "Content-match worker published an invalid result header: $contentWorkerHeader"
        }
        Write-Host 'Content-match worker exit validation passed.'
    } finally {
        if (Test-Path -LiteralPath $contentWorkerRoot) {
            Remove-Item -LiteralPath $contentWorkerRoot -Recurse -Force `
                -ErrorAction SilentlyContinue
        }
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
    Remove-Item -LiteralPath $testHostRoot -Recurse -Force
    $configurationHashAfter = if (Test-Path -LiteralPath $configurationPath) {
        (Get-FileHash -Algorithm SHA256 -LiteralPath $configurationPath).Hash
    } else {
        $null
    }
    if ($configurationHashAfter -ne $configurationHashBefore) {
        throw 'Core tests modified the project watchdog.ini configuration.'
    }
}
