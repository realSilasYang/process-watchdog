# GitHub Actions 工作流语法检查。
# 使用锁定版本的 actionlint 校验仓库工作流，避免本机与持续集成采用不同规则。

[CmdletBinding()]
param(
    [string]$ActionlintPath = ""
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$toolLock = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'tools\toolchain.lock.json') `
    -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $ActionlintPath) {
    $toolchain = & (Join-Path $projectRoot `
        'tools\bootstrap-toolchain.ps1')
    $ActionlintPath = $toolchain.ActionlintPath
}
if (-not (Test-Path -LiteralPath $ActionlintPath -PathType Leaf)) {
    throw "actionlint is missing: $ActionlintPath"
}
$actualHash = (Get-FileHash -Algorithm SHA256 `
    -LiteralPath $ActionlintPath).Hash
if ($actualHash -ne $toolLock.tools.actionlint.executableSha256) {
    throw "actionlint does not match the pinned executable: $actualHash"
}

Push-Location $projectRoot
try {
    & $ActionlintPath -no-color
    if ($LASTEXITCODE -ne 0) {
        throw "actionlint failed with exit code $LASTEXITCODE."
    }
} finally {
    Pop-Location
}
$releaseWorkflow = Get-Content -LiteralPath (Join-Path $projectRoot `
    '.github\workflows\release.yml') -Raw -Encoding UTF8
if ($releaseWorkflow -notmatch
        '\$tagQueryExitCode\s*=\s*\$LASTEXITCODE[\s\S]{0,120}if\s*\(\$tagQueryExitCode\s*-notin\s*@\(0,\s*2\)\)' -or
    $releaseWorkflow -notmatch
        'releases\?per_page=100' -or
    ([regex]::Matches($releaseWorkflow,
        'gh\s+api\s+--paginate\s+--slurp')).Count -lt 2 -or
    $releaseWorkflow -notmatch
        '\$matchingReleases\.Count\s*-gt\s*1' -or
    $releaseWorkflow -notmatch
        'target_commitish\s*-cne\s*\$env:GITHUB_SHA' -or
    $releaseWorkflow -notmatch
        '\$global:LASTEXITCODE\s*=\s*0') {
    throw 'Release tag detection must consume git status and validate a unique draft at the current commit.'
}
Write-Host "GitHub Actions workflows passed actionlint $($toolLock.tools.actionlint.version)."
