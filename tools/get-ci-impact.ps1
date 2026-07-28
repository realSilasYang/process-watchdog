# 根据变更路径决定 CI 所需层级。
# 文档变更只进入快速门禁；运行时代码进入 Windows 集成；发行工程、依赖和打包
# 资源还会进入可复现构建。分类器独立于 GitHub Actions，便于本地测试和复用。

[CmdletBinding()]
param(
    [string]$BaseSha = "",
    [string]$HeadSha = 'HEAD',
    [string]$GitHubOutput = "",
    [string[]]$ChangedPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path -Parent $PSScriptRoot

function Test-DocumentationOnlyPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $normalized = $Path.Replace('\', '/')
    if ($normalized -in @('README.md', 'CHANGELOG.md', 'LICENSE',
            '.mailmap', '.github/FUNDING.yml')) {
        return $true
    }
    return $normalized -match '^(?:docs/|\.github/(?:CONTRIBUTING|CODE_OF_CONDUCT|SECURITY|SUPPORT)(?:\.en)?\.md$|\.github/ISSUE_TEMPLATE/|\.github/PULL_REQUEST_TEMPLATE(?:\.md|/))'
}

function Test-ReleaseEngineeringPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $normalized = $Path.Replace('\', '/')
    if ($normalized -in @('VERSION', '.gitattributes',
            'runtime/application-update.ps1',
            'runtime/standalone-install.ps1',
            'runtime/standalone-launcher.ahk',
            'tests/application-update-helper-tests.ps1',
            'tests/reproducible-build.ps1',
            'tests/standalone-installer-tests.ps1')) {
        return $true
    }
    return $normalized -match '^(?:tools/|third_party/|assets/fonts/|\.github/workflows/(?:ci|release|release-dry-run)\.yml$)'
}

$paths = if ($PSBoundParameters.ContainsKey('ChangedPath')) {
    @($ChangedPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
} else {
    $validCommitPattern = '^[0-9a-fA-F]{40}$'
    if ($BaseSha -notmatch $validCommitPattern -or
        ($HeadSha -ne 'HEAD' -and $HeadSha -notmatch $validCommitPattern)) {
        # 首次推送、手动运行或 GitHub 未提供比较基线时选择完整门禁。
        @('__full_validation__')
    } else {
        Push-Location $projectRoot
        try {
            & git cat-file -e "$BaseSha^{commit}" 2>$null
            if ($LASTEXITCODE -ne 0) {
                @('__full_validation__')
            } else {
                @(& git -c core.quotePath=false diff --name-only `
                    --diff-filter=ACMRD "$BaseSha...$HeadSha" --)
                if ($LASTEXITCODE -ne 0) {
                    throw 'Unable to classify changed files for CI.'
                }
            }
        } finally {
            Pop-Location
        }
    }
}
# PowerShell 会展开条件分支返回的单元素数组；统一重新装箱，避免严格模式下
# 手动触发完整门禁时字符串没有 Count 属性。
$paths = @($paths)

$integrationRequired = $false
$releaseRequired = $false
foreach ($path in $paths) {
    if ($path -eq '__full_validation__') {
        $integrationRequired = $true
        $releaseRequired = $true
        break
    }
    if (-not (Test-DocumentationOnlyPath $path)) {
        $integrationRequired = $true
    }
    if (Test-ReleaseEngineeringPath $path) {
        $releaseRequired = $true
    }
}

$impact = [pscustomobject]@{
    ChangedFiles = @($paths)
    IntegrationRequired = $integrationRequired
    ReleaseRequired = $releaseRequired
}
if ($GitHubOutput) {
    @(
        'integration=' + $integrationRequired.ToString().ToLowerInvariant()
        'release=' + $releaseRequired.ToString().ToLowerInvariant()
        'changed_count=' + $paths.Count
    ) | Add-Content -LiteralPath $GitHubOutput -Encoding ASCII
} else {
    $impact
}
