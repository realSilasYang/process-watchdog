# 发行 EXE 的规范编译边界。
# 无论外层工作流由 PowerShell 7 还是 Windows PowerShell 5.1 编排，都由本脚本在
# Windows PowerShell 5.1 中以完全相同的参数和工作目录启动 Ahk2Exe。

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CompilerPath,
    [Parameter(Mandatory)][string]$SourcePath,
    [Parameter(Mandatory)][string]$OutputPath,
    [Parameter(Mandatory)][string]$IconPath,
    [Parameter(Mandatory)][string]$BasePath,
    [Parameter(Mandatory)][string]$WorkingDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$compilerArguments = @(
    '/in', $SourcePath,
    '/out', $OutputPath,
    '/icon', $IconPath,
    '/base', $BasePath,
    '/silent', 'verbose'
)
foreach ($argument in $compilerArguments) {
    if ([string]$argument -match '"') {
        throw 'Ahk2Exe arguments must not contain quotation marks.'
    }
}
$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $CompilerPath
$startInfo.Arguments = ($compilerArguments | ForEach-Object {
    '"' + [string]$_ + '"'
}) -join ' '
$startInfo.WorkingDirectory = $WorkingDirectory
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$process = $null
try {
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $standardOutputTask = $process.StandardOutput.ReadToEndAsync()
    $standardErrorTask = $process.StandardError.ReadToEndAsync()
    # 独立启动器会嵌入完整便携 ZIP。低负载 CI 主机写入大型 PE 资源可能超过
    # 两分钟，但仍需有明确上限，避免编译器挂起无限占用发布任务。
    if (-not $process.WaitForExit(600000)) {
        try { $process.Kill() } catch {}
        throw 'Ahk2Exe timed out after 600 seconds.'
    }
    $process.WaitForExit()
    $standardOutput = $standardOutputTask.GetAwaiter().GetResult()
    $standardError = $standardErrorTask.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0 -or
        -not (Test-Path -LiteralPath $OutputPath -PathType Leaf)) {
        $diagnostics = @($standardError, $standardOutput) -join "`n"
        throw ("Ahk2Exe failed with exit code {0}.{1}" -f `
            $process.ExitCode,
            $(if ($diagnostics.Trim()) {
                "`n$($diagnostics.Trim())"
            } else { '' }))
    }
    & (Join-Path $PSScriptRoot 'normalize-version-resource.ps1') `
        -ExecutablePath $OutputPath
} finally {
    if ($process) { $process.Dispose() }
}
