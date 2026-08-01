# GitHub Actions 工作流语法与发布边界检查。
# 状态组合由 release-engineering-tests.ps1 验证；这里负责确认三个工作流调用同一套
# 已测试脚本、第三方 Action 固定提交，并且只有正式发布具有写权限。

[CmdletBinding()]
param([string]$ActionlintPath = "")

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$toolLock = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'tools\toolchain.lock.json') `
    -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $ActionlintPath) {
    $toolchain = & (Join-Path $projectRoot 'tools\bootstrap-toolchain.ps1') `
        -ResolvedToolchainPath (Join-Path $projectRoot `
            'tools\ci-toolchain.resolved.json')
    $ActionlintPath = $toolchain.ActionlintPath
}
if (-not (Test-Path -LiteralPath $ActionlintPath -PathType Leaf)) {
    throw "actionlint 不存在：$ActionlintPath"
}
$actualHash = (Get-FileHash -Algorithm SHA256 `
    -LiteralPath $ActionlintPath).Hash
if ($actualHash -ne $toolLock.tools.actionlint.executableSha256) {
    throw "actionlint 与仓库锁定的可执行文件不一致：$actualHash"
}

Push-Location $projectRoot
try {
    & $ActionlintPath -no-color
    if ($LASTEXITCODE -ne 0) {
        throw "actionlint 失败，退出码：$LASTEXITCODE"
    }
} finally {
    Pop-Location
}

function Get-WorkflowText {
    param([string]$Name)
    $path = Join-Path $projectRoot ".github\workflows\$Name"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "缺少工作流：$Name"
    }
    return Get-Content -LiteralPath $path -Raw -Encoding UTF8
}

function Assert-WorkflowContains {
    param([string]$Name, [string]$Text, [string[]]$Requirements)
    foreach ($requirement in $Requirements) {
        if (-not $Text.Contains($requirement)) {
            throw "$Name 缺少发布工程约束：$requirement"
        }
    }
}

$ci = Get-WorkflowText 'ci.yml'
Assert-WorkflowContains 'ci.yml' $ci @(
    'tools\ci-toolchain.resolved.json'
    'actions/cache@'
    '.\tools\get-ci-impact.ps1'
    '.\tests\verify-fast.ps1'
    '.\tests\verify-windows-integration.ps1'
    '.\tests\reproducible-build.ps1'
    '-OutputDirectory dist'
    '-SecondPowerShellPath powershell.exe'
    'path: dist/**'
    'include-hidden-files: true'
    'fetch-depth: 0'
    'lfs: false'
    'lfs: true'
    '  verify:'
    '    name: verify'
    '    if: always()'
    "needs['windows-integration'].result"
    "needs['release-package'].result"
    'INTEGRATION_REQUIRED:'
    'RELEASE_REQUIRED:'
    'require_result "windows-integration"'
    'require_result "release-package"'
)
if ($ci.Contains('.\tools\invoke-release-validation.ps1')) {
    throw 'CI 分层后不得在每个提交上重复执行完整发布门禁。'
}
if ($ci.Contains('"codex/**"') -or $ci.Contains("'codex/**'")) {
    throw 'CI 不应在拉取请求之外重复监听 codex 分支 push。'
}

$dryRun = Get-WorkflowText 'release-dry-run.yml'
Assert-WorkflowContains 'release-dry-run.yml' $dryRun @(
    'workflow_dispatch:'
    'contents: read'
    '.\tools\resolve-release-state.ps1'
    '-RefreshBuildTools'
    '.\tools\invoke-release-validation.ps1'
    '-OutputDirectory dist'
    '-SecondPowerShellPath powershell.exe'
    'path: dist/**'
    'include-hidden-files: true'
    'fetch-depth: 0'
)
foreach ($forbidden in @('softprops/action-gh-release@',
        'gh release edit', 'contents: write',
        'actions/attest-build-provenance@')) {
    if ($dryRun.Contains($forbidden)) {
        throw "发布演练不得修改 GitHub 状态：$forbidden"
    }
}

$release = Get-WorkflowText 'release.yml'
$versionExpression = '${{ steps.release_meta.outputs.version }}'
$commitExpression = '${{ github.sha }}'
$repositoryExpression = '${{ github.repository }}'
$userAssets = @(
    'dist/fonts.zip'
    "dist/process-watchdog-$versionExpression-source.zip"
    "dist/process-watchdog-$versionExpression-windows-x64.zip"
)
Assert-WorkflowContains 'release.yml' $release @(
    'workflow_dispatch:'
    '.\tools\resolve-release-state.ps1'
    '-RefreshBuildTools'
    '.\tools\invoke-release-validation.ps1'
    'actions/attest-build-provenance@'
    'actions/upload-artifact@'
    'path: dist/**'
    'draft: true'
    '.\tools\verify-release-draft.ps1'
    '--draft=false'
    '.\tools\verify-published-release.ps1'
    '.\tools\verify-downloaded-release.ps1'
    "-Version '$versionExpression'"
    "-CommitSha '$commitExpression'"
    "-Repository '$repositoryExpression'"
    '-OutputDirectory dist'
    '-SecondPowerShellPath powershell.exe'
    'include-hidden-files: true'
    'fetch-depth: 0'
)
foreach ($asset in $userAssets) {
    if (([regex]::Matches($release, [regex]::Escape($asset))).Count -ne 2) {
        throw "正式工作流必须且只能在溯源与上传白名单中各引用一次：$asset"
    }
}
if ($release.Contains('dist/*.spdx.json') -or
    $release.Contains('dist/SHA256SUMS.txt')) {
    throw 'GitHub Release 只能上传便携 ZIP、源码 ZIP 和可选字体 ZIP。'
}
if ($release -match '(?m)^\s*push:\s*$' -or
    $release -match '(?m)^\s*schedule:\s*$') {
    throw '正式发布只能由 workflow_dispatch 手动触发。'
}

$soak = Get-WorkflowText 'soak.yml'
Assert-WorkflowContains 'soak.yml' $soak @(
    'tools\ci-toolchain.resolved.json'
    'actions/cache@'
)

Write-Host "GitHub Actions 工作流已通过 actionlint $($toolLock.tools.actionlint.version) 与发布边界检查。"
