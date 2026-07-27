# 发布状态机与 GitHub 附件合同测试；不访问网络，也不修改真实 Release。

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $projectRoot 'tools\ReleaseEngineering.psm1') -Force

function Assert-ReleaseTest {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-ReleaseFailure {
    param([scriptblock]$Action, [string]$Message)
    $failed = $false
    try { & $Action } catch { $failed = $true }
    Assert-ReleaseTest $failed $Message
}

function New-TestRelease {
    param(
        [bool]$Draft = $true,
        [string]$Commit = ('1' * 40),
        [string]$Tag = 'v2.0.0',
        [long]$Id = 1
    )
    return [pscustomobject]@{
        id = $Id
        tag_name = $Tag
        draft = $Draft
        prerelease = $false
        target_commitish = $Commit
    }
}

$commit = '1' * 40
$otherCommit = '2' * 40
Assert-ReleaseTest (Test-CanonicalReleaseVersion '2.0.0') `
    '规范版本被错误拒绝。'
Assert-ReleaseTest (-not (Test-CanonicalReleaseVersion '02.0.0')) `
    '带前导零的版本被错误接受。'

$state = Resolve-ReleaseState '2.0.0' $commit
Assert-ReleaseTest ($state.State -ceq 'new') '全新发布状态判断错误。'
$draft = New-TestRelease
$state = Resolve-ReleaseState '2.0.0' $commit -Releases @($draft)
Assert-ReleaseTest ($state.State -ceq 'resume-draft' -and
    -not $state.HasTag) '无标签同提交草稿不能续传。'
$tag = [pscustomobject]@{ Name = 'v2.0.0'; CommitSha = $commit }
$state = Resolve-ReleaseState '2.0.0' $commit -Tags @($tag) `
    -Releases @($draft)
Assert-ReleaseTest ($state.State -ceq 'resume-draft' -and $state.HasTag) `
    '同提交标签和草稿不能续传。'
$state = Resolve-ReleaseState '2.0.0' $commit -Tags @($tag)
Assert-ReleaseTest ($state.State -ceq 'recover-tag') `
    '同提交孤立标签不能恢复。'

Assert-ReleaseFailure {
    Resolve-ReleaseState '2.0.0' $commit -Tags @(
        [pscustomobject]@{ Name = 'v2.0.0'; CommitSha = $otherCommit })
} '指向其他提交的标签未被拒绝。'
Assert-ReleaseFailure {
    Resolve-ReleaseState '2.0.0' $commit -Releases @(
        (New-TestRelease -Commit $otherCommit))
} '属于其他提交的草稿未被拒绝。'
Assert-ReleaseFailure {
    Resolve-ReleaseState '2.0.0' $commit -Releases @(
        (New-TestRelease -Draft $false))
} '已公开版本未被拒绝。'
Assert-ReleaseFailure {
    Resolve-ReleaseState '2.0.0' $commit -Releases @(
        (New-TestRelease -Id 1), (New-TestRelease -Id 2))
} '重复 Release 未被拒绝。'
Assert-ReleaseFailure {
    Resolve-ReleaseState '2.0.0' $commit -Tags @($tag, $tag)
} '重复标签记录未被拒绝。'

$expectedNames = @(Get-ReleaseArtifactNames '2.0.0')
Assert-ReleaseTest ($expectedNames.Count -eq 3) '发行附件白名单数量错误。'
Assert-ReleaseFailure {
    Assert-ReleaseArtifactInventory -Version '2.0.0' `
        -Assets @($expectedNames[0], $expectedNames[1])
} '缺失附件未被拒绝。'
Assert-ReleaseFailure {
    Assert-ReleaseArtifactInventory -Version '2.0.0' `
        -Assets @($expectedNames + 'SHA256SUMS.txt')
} '多余附件未被拒绝。'
Assert-ReleaseFailure {
    Assert-ReleaseArtifactInventory -Version '2.0.0' `
        -Assets @($expectedNames[0], $expectedNames[0], $expectedNames[2])
} '重名附件未被拒绝。'
$invalidDigestAssets = @($expectedNames | ForEach-Object {
    [pscustomobject]@{ name = $_; digest = 'unsupported' }
})
Assert-ReleaseFailure {
    Assert-ReleaseArtifactInventory -Version '2.0.0' `
        -Assets $invalidDigestAssets -RequireDigest
} '无效摘要未被拒绝。'

# 模拟 gh api --paginate --slurp 解析出的多页嵌套数组，确保末页的重复版本不会漏检。
$pages = @(
    @((New-TestRelease -Tag 'v1.0.0' -Id 1))
    @((New-TestRelease -Id 2), (New-TestRelease -Id 3))
)
$flattened = @($pages | ForEach-Object { $_ })
Assert-ReleaseFailure {
    Resolve-ReleaseState '2.0.0' $commit -Releases $flattened
} '分页后的重复 Release 未被拒绝。'

$recordRoot = Join-Path $env:TEMP `
    ('ProcessWatchdogReleaseRecordTest-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $recordRoot | Out-Null
try {
    $bodyPath = Join-Path $recordRoot 'body.md'
    Set-Content -LiteralPath $bodyPath -Encoding UTF8 `
        -Value "# 进程守护小助手 v2.0.0`r`n`r`n测试正文"
    $assets = @(
        foreach ($name in $expectedNames) {
            $path = Join-Path $recordRoot $name
            [System.IO.File]::WriteAllText($path, "content-$name",
                [System.Text.UTF8Encoding]::new($false))
            [pscustomobject]@{
                name = $name
                digest = 'sha256:' + ((Get-FileHash -Algorithm SHA256 `
                    -LiteralPath $path).Hash.ToLowerInvariant())
                size = (Get-Item -LiteralPath $path).Length
            }
        }
    )
    $record = [pscustomobject]@{
        id = 10
        tag_name = 'v2.0.0'
        name = '进程守护小助手 v2.0.0'
        draft = $true
        prerelease = $false
        target_commitish = $commit
        body = "# 进程守护小助手 v2.0.0`n`n测试正文`n"
        assets = $assets
    }
    Assert-ReleaseRecord -Release $record -Version '2.0.0' `
        -CommitSha $commit -Stage Draft -BodyPath $bodyPath `
        -LocalArtifactDirectory $recordRoot
    $record.draft = $false
    Assert-ReleaseRecord -Release $record -Version '2.0.0' `
        -CommitSha $commit -Stage Published -BodyPath $bodyPath `
        -LocalArtifactDirectory $recordRoot -TagCommitSha $commit
    Assert-ReleaseFailure {
        Assert-ReleaseRecord -Release $record -Version '2.0.0' `
            -CommitSha $commit -Stage Published -BodyPath $bodyPath `
            -LocalArtifactDirectory $recordRoot
    } '公开 Release 缺少标签时未被拒绝。'
    $assets[0].digest = 'sha256:' + ('0' * 64)
    Assert-ReleaseFailure {
        Assert-ReleaseRecord -Release $record -Version '2.0.0' `
            -CommitSha $commit -Stage Published -BodyPath $bodyPath `
            -LocalArtifactDirectory $recordRoot -TagCommitSha $commit
    } '远程摘要与本地构建不一致时未被拒绝。'
} finally {
    Remove-Item -LiteralPath $recordRoot -Recurse -Force `
        -ErrorAction SilentlyContinue
}

Write-Host 'Release engineering tests passed.'
