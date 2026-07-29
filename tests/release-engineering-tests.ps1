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

function Add-TestUInt16BigEndian {
    param(
        [System.Collections.Generic.List[byte]]$Bytes,
        [int]$Value
    )
    $Bytes.Add([byte](($Value -shr 8) -band 0xFF))
    $Bytes.Add([byte]($Value -band 0xFF))
}

function Add-TestUInt32BigEndian {
    param(
        [System.Collections.Generic.List[byte]]$Bytes,
        [uint32]$Value
    )
    $Bytes.Add([byte](($Value -shr 24) -band 0xFF))
    $Bytes.Add([byte](($Value -shr 16) -band 0xFF))
    $Bytes.Add([byte](($Value -shr 8) -band 0xFF))
    $Bytes.Add([byte]($Value -band 0xFF))
}

function Add-TestBytes {
    param(
        [System.Collections.Generic.List[byte]]$Bytes,
        [byte[]]$Value
    )
    foreach ($byteValue in $Value) { $Bytes.Add($byteValue) }
}

function New-TestNameTable {
    param([string[]]$Families)

    $encodedFamilies = @($Families | ForEach-Object {
        ,([System.Text.Encoding]::BigEndianUnicode.GetBytes($_))
    })
    $bytes = [System.Collections.Generic.List[byte]]::new()
    Add-TestUInt16BigEndian $bytes 0
    Add-TestUInt16BigEndian $bytes $encodedFamilies.Count
    Add-TestUInt16BigEndian $bytes (6 + (12 * $encodedFamilies.Count))
    $stringOffset = 0
    foreach ($encodedFamily in $encodedFamilies) {
        Add-TestUInt16BigEndian $bytes 3
        Add-TestUInt16BigEndian $bytes 1
        Add-TestUInt16BigEndian $bytes 0x0409
        Add-TestUInt16BigEndian $bytes 1
        Add-TestUInt16BigEndian $bytes $encodedFamily.Length
        Add-TestUInt16BigEndian $bytes $stringOffset
        $stringOffset += $encodedFamily.Length
    }
    foreach ($encodedFamily in $encodedFamilies) {
        Add-TestBytes $bytes $encodedFamily
    }
    return $bytes.ToArray()
}

function Add-TestFontDirectory {
    param(
        [System.Collections.Generic.List[byte]]$Bytes,
        [int]$NameTableOffset,
        [int]$NameTableLength
    )
    Add-TestBytes $Bytes ([byte[]](0, 1, 0, 0))
    Add-TestUInt16BigEndian $Bytes 1
    Add-TestUInt16BigEndian $Bytes 0
    Add-TestUInt16BigEndian $Bytes 0
    Add-TestUInt16BigEndian $Bytes 0
    Add-TestBytes $Bytes ([System.Text.Encoding]::ASCII.GetBytes('name'))
    Add-TestUInt32BigEndian $Bytes 0
    Add-TestUInt32BigEndian $Bytes $NameTableOffset
    Add-TestUInt32BigEndian $Bytes $NameTableLength
}

function New-TestOpenTypeCollection {
    $firstNameTable = New-TestNameTable @('Primary Family', '稳定字体')
    $secondNameTable = New-TestNameTable @('Second Family')
    $firstFontOffset = 20
    $secondFontOffset = $firstFontOffset + 28
    $firstNameOffset = $secondFontOffset + 28
    $secondNameOffset = $firstNameOffset + $firstNameTable.Length
    $bytes = [System.Collections.Generic.List[byte]]::new()
    Add-TestBytes $bytes ([System.Text.Encoding]::ASCII.GetBytes('ttcf'))
    Add-TestUInt32BigEndian $bytes 0x00010000
    Add-TestUInt32BigEndian $bytes 2
    Add-TestUInt32BigEndian $bytes $firstFontOffset
    Add-TestUInt32BigEndian $bytes $secondFontOffset
    Add-TestFontDirectory $bytes $firstNameOffset $firstNameTable.Length
    Add-TestFontDirectory $bytes $secondNameOffset $secondNameTable.Length
    Add-TestBytes $bytes $firstNameTable
    Add-TestBytes $bytes $secondNameTable
    return $bytes.ToArray()
}

$commit = '1' * 40
$otherCommit = '2' * 40
Assert-ReleaseTest (Test-CanonicalReleaseVersion '2.0.0') `
    '规范版本被错误拒绝。'
Assert-ReleaseTest (-not (Test-CanonicalReleaseVersion '02.0.0')) `
    '带前导零的版本被错误接受。'

$fontFixtureRoot = Join-Path $env:TEMP `
    ('ProcessWatchdogOpenTypeTest-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fontFixtureRoot | Out-Null
try {
    $collectionPath = Join-Path $fontFixtureRoot 'families.ttc'
    [System.IO.File]::WriteAllBytes($collectionPath,
        (New-TestOpenTypeCollection))
    $familyNames = @(Get-OpenTypeFamilyNames -FontPath $collectionPath)
    Assert-ReleaseTest ($familyNames.Count -eq 3 -and
        $familyNames -contains 'Primary Family' -and
        $familyNames -contains 'Second Family' -and
        $familyNames -contains '稳定字体') `
        'OpenType 集合未稳定解析所有语言的字体族名。'
    $invalidPath = Join-Path $fontFixtureRoot 'invalid.ttf'
    [System.IO.File]::WriteAllBytes($invalidPath, [byte[]](0, 1, 2, 3))
    Assert-ReleaseFailure {
        Get-OpenTypeFamilyNames -FontPath $invalidPath
    } '截断的 OpenType 字体未被拒绝。'
} finally {
    Remove-Item -LiteralPath $fontFixtureRoot -Recurse -Force `
        -ErrorAction SilentlyContinue
}

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
    $validBody = @"
# 🎉 进程守护小助手 v2.0.0

## ✨ 新增

- 测试正文

---

## 📦 发布物说明

- **`process-watchdog-2.0.0-windows-x64.exe`（独立可执行版）**：无需安装 AutoHotkey，下载后即可运行，适合快速体验或只需要单个程序文件的用户。
- **`process-watchdog-2.0.0-windows-x64.zip`（完整便携版，推荐）**：包含 EXE、说明文档、许可证、字体及运行所需资源，适合完整解压后长期使用或手动部署。
- **`process-watchdog-2.0.0-source.zip`（完整源码版）**：包含 AHK 源码、模块、测试、文档和字体资源，适合审阅、开发或从源码运行；本机需要 AutoHotkey v2 x64。
"@
    Set-Content -LiteralPath $bodyPath -Encoding UTF8 `
        -Value $validBody
    Assert-ReleaseNotesContent -Version '2.0.0' -BodyPath $bodyPath
    $validationScopeBody = $validBody -replace '## 📦 发布物说明', @"
## ✅ 验证范围

- 通过核心测试、GUI 冒烟和可复现构建。

---

## 📦 发布物说明
"@
    Set-Content -LiteralPath $bodyPath -Encoding UTF8 `
        -Value $validationScopeBody
    Assert-ReleaseFailure {
        Assert-ReleaseNotesContent -Version '2.0.0' -BodyPath $bodyPath
    } '发行说明中的验证范围章节未被拒绝。'
    $validWarningBody = $validBody -replace '## ✨ 新增', @"
## ⚠️ 重要说明

- 旧版无法自动更新，升级前必须退出旧实例并完整替换发行包。

---

## ✨ 新增
"@
    Set-Content -LiteralPath $bodyPath -Encoding UTF8 `
        -Value $validWarningBody
    Assert-ReleaseNotesContent -Version '2.0.0' -BodyPath $bodyPath
    $ordinaryImportantBody = $validBody -replace '## ✨ 新增', @"
## ⚠️ 重要说明

- 本版本配置保持兼容，可以直接升级。

---

## ✨ 新增
"@
    Set-Content -LiteralPath $bodyPath -Encoding UTF8 `
        -Value $ordinaryImportantBody
    Assert-ReleaseFailure {
        Assert-ReleaseNotesContent -Version '2.0.0' -BodyPath $bodyPath
    } '普通兼容性说明被错误接受为重要说明。'
    $emptyImportantBody = $validBody -replace '## ✨ 新增', @"
## ⚠️ 重要说明

---

## ✨ 新增
"@
    Set-Content -LiteralPath $bodyPath -Encoding UTF8 `
        -Value $emptyImportantBody
    Assert-ReleaseFailure {
        Assert-ReleaseNotesContent -Version '2.0.0' -BodyPath $bodyPath
    } '空的重要说明章节未被拒绝。'
    $placeholderImportantBody = $validBody -replace '## ✨ 新增', @"
## ⚠️ 重要说明

- 仅在存在不兼容变化时保留本节，并补充迁移方法。

---

## ✨ 新增
"@
    Set-Content -LiteralPath $bodyPath -Encoding UTF8 `
        -Value $placeholderImportantBody
    Assert-ReleaseFailure {
        Assert-ReleaseNotesContent -Version '2.0.0' -BodyPath $bodyPath
    } '重要说明模板占位文本未被拒绝。'
    $lateImportantBody = $validBody -replace '## 📦 发布物说明', @"
## ⚠️ 重要说明

- 旧版无法自动更新，升级前必须完整替换发行包。

---

## 📦 发布物说明
"@
    Set-Content -LiteralPath $bodyPath -Encoding UTF8 `
        -Value $lateImportantBody
    Assert-ReleaseFailure {
        Assert-ReleaseNotesContent -Version '2.0.0' -BodyPath $bodyPath
    } '位于常规章节之后的重要说明未被拒绝。'
    Set-Content -LiteralPath $bodyPath -Encoding UTF8 `
        -Value ($validBody -replace '# 🎉', '#')
    Assert-ReleaseFailure {
        Assert-ReleaseNotesContent -Version '2.0.0' -BodyPath $bodyPath
    } '发行说明标题缺少 Emoji 时未被拒绝。'
    Set-Content -LiteralPath $bodyPath -Encoding UTF8 `
        -Value ($validBody -replace '无需安装 AutoHotkey', '下载后直接运行')
    Assert-ReleaseFailure {
        Assert-ReleaseNotesContent -Version '2.0.0' -BodyPath $bodyPath
    } '独立可执行版缺少 AutoHotkey 要求时未被拒绝。'
    Set-Content -LiteralPath $bodyPath -Encoding UTF8 `
        -Value ($validBody + "`r`n`r`n## 🐛 修复`r`n`r`n- 错误顺序")
    Assert-ReleaseFailure {
        Assert-ReleaseNotesContent -Version '2.0.0' -BodyPath $bodyPath
    } '发布物说明后仍有其他章节时未被拒绝。'
    Set-Content -LiteralPath $bodyPath -Encoding UTF8 -Value $validBody
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
        body = $validBody
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
