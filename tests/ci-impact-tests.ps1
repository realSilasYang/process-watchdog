# CI 变更影响分类器测试，防止文档提交重新触发大型字体、GUI 或双重打包。

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path -Parent $PSScriptRoot
$classifier = Join-Path $projectRoot 'tools\get-ci-impact.ps1'

function Assert-CiImpact {
    param(
        [string[]]$Path,
        [bool]$Integration,
        [bool]$Release,
        [string]$Scenario
    )

    $result = & $classifier -ChangedPath $Path
    if ($result.IntegrationRequired -ne $Integration -or
        $result.ReleaseRequired -ne $Release) {
        throw "CI impact classification failed for $Scenario."
    }
}

Assert-CiImpact -Path @('README.md', 'docs/architecture.md',
    '.github/ISSUE_TEMPLATE/bug_report.yml') -Integration $false `
    -Release $false -Scenario 'documentation-only changes'
Assert-CiImpact -Path @('src/Core/GuardRuntime.ahk') -Integration $true `
    -Release $false -Scenario 'runtime changes'
Assert-CiImpact -Path @('tools/build-release.ps1') -Integration $true `
    -Release $true -Scenario 'release engineering changes'
Assert-CiImpact -Path @('assets/fonts/NotoSansCJK.ttc') -Integration $true `
    -Release $true -Scenario 'packaged font changes'
Assert-CiImpact -Path @() -Integration $false -Release $false `
    -Scenario 'empty comparison'

Write-Host 'CI impact classifier tests passed.'
