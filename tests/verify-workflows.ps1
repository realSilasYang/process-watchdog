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
Write-Host "GitHub Actions workflows passed actionlint $($toolLock.tools.actionlint.version)."
