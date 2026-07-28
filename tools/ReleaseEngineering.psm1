# 发布状态、附件白名单与 GitHub Release 记录的共享校验能力。
# 本模块中的决策函数不访问网络，工作流脚本只负责采集外部状态并传入，因此所有
# 冲突分支都能在本地单元测试中稳定复现。

Set-StrictMode -Version Latest

function Test-CanonicalReleaseVersion {
    [CmdletBinding()]
    param([AllowEmptyString()][string]$Version)

    return $Version -match `
        '^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$'
}

function Get-ReleaseArtifactNames {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Version)

    if (-not (Test-CanonicalReleaseVersion $Version)) {
        throw "VERSION 不是规范的三段语义化版本：$Version"
    }
    return @(
        "process-watchdog-$Version-windows-x64.exe"
        "process-watchdog-$Version-windows-x64.zip"
        "process-watchdog-$Version-source.zip"
    )
}

function Get-ReleaseRecordValue {
    param(
        [AllowNull()][object]$Record,
        [Parameter(Mandatory)][string]$Name,
        [AllowNull()][object]$Default = $null
    )

    if ($null -eq $Record) {
        return $Default
    }
    if ($Record -is [System.Collections.IDictionary]) {
        if ($Record.Contains($Name)) {
            return $Record[$Name]
        }
        return $Default
    }
    $property = $Record.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $Default
    }
    return $property.Value
}

function Assert-ReleaseArtifactInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$Assets,
        [Parameter(Mandatory)][string]$Version,
        [string]$LocalArtifactDirectory = "",
        [switch]$RequireDigest
    )

    $expectedNames = @(Get-ReleaseArtifactNames $Version | Sort-Object)
    $assetRecords = @($Assets)
    $actualNames = @(
        foreach ($asset in $assetRecords) {
            $name = if ($asset -is [string]) {
                [string]$asset
            } else {
                [string](Get-ReleaseRecordValue $asset 'name' '')
            }
            if ([string]::IsNullOrWhiteSpace($name)) {
                throw 'Release 包含没有文件名的附件。'
            }
            $name
        }
    )
    $duplicates = @($actualNames | Group-Object -CaseSensitive |
        Where-Object Count -gt 1 | ForEach-Object Name)
    if ($duplicates.Count -ne 0) {
        throw "Release 包含重名附件：$($duplicates -join '、')"
    }
    $sortedActualNames = @($actualNames | Sort-Object)
    $difference = @(Compare-Object -CaseSensitive `
        -ReferenceObject $expectedNames -DifferenceObject $sortedActualNames)
    if ($difference.Count -ne 0 -or
        $sortedActualNames.Count -ne $expectedNames.Count) {
        throw "Release 附件必须且只能是三种用户版本；实际为：$($sortedActualNames -join '、')"
    }

    $localRoot = ""
    if ($LocalArtifactDirectory) {
        $localRoot = [System.IO.Path]::GetFullPath($LocalArtifactDirectory)
        if (-not (Test-Path -LiteralPath $localRoot -PathType Container)) {
            throw "本地发行目录不存在：$localRoot"
        }
    }
    foreach ($asset in $assetRecords) {
        if ($asset -is [string]) {
            if ($RequireDigest -or $localRoot) {
                throw '需要校验摘要时，附件必须包含 GitHub API 元数据。'
            }
            continue
        }
        $name = [string](Get-ReleaseRecordValue $asset 'name' '')
        $digest = [string](Get-ReleaseRecordValue $asset 'digest' '')
        if (($RequireDigest -or $localRoot) -and
            $digest -notmatch '^sha256:[0-9A-Fa-f]{64}$') {
            throw "Release 附件缺少规范的 SHA-256 摘要：$name"
        }
        if (-not $localRoot) {
            continue
        }
        $localPath = Join-Path $localRoot $name
        if (-not (Test-Path -LiteralPath $localPath -PathType Leaf)) {
            throw "本地发行附件不存在：$name"
        }
        $localHash = (Get-FileHash -Algorithm SHA256 `
            -LiteralPath $localPath).Hash
        if ($localHash -cne $digest.Substring(7).ToUpperInvariant()) {
            throw "GitHub 附件摘要与本地构建不一致：$name"
        }
        $remoteSize = Get-ReleaseRecordValue $asset 'size' $null
        if ($null -ne $remoteSize -and [long]$remoteSize -ne
            (Get-Item -LiteralPath $localPath).Length) {
            throw "GitHub 附件大小与本地构建不一致：$name"
        }
    }
    return $expectedNames
}

function Resolve-ReleaseState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$CommitSha,
        [object[]]$Tags = @(),
        [object[]]$Releases = @()
    )

    if (-not (Test-CanonicalReleaseVersion $Version)) {
        throw "VERSION 不是规范的三段语义化版本：$Version"
    }
    if ($CommitSha -notmatch '^[0-9A-Fa-f]{40}$') {
        throw "发布提交不是完整的 Git SHA：$CommitSha"
    }
    $commit = $CommitSha.ToLowerInvariant()
    $tagName = "v$Version"
    $matchingTags = @($Tags | Where-Object {
        [string](Get-ReleaseRecordValue $_ 'Name' '') -ceq $tagName
    })
    $matchingReleases = @($Releases | Where-Object {
        [string](Get-ReleaseRecordValue $_ 'tag_name' '') -ceq $tagName
    })
    if ($matchingTags.Count -gt 1) {
        throw "远程存在多个同名标签记录：$tagName"
    }
    if ($matchingReleases.Count -gt 1) {
        throw "GitHub 存在多个同版本 Release：$tagName"
    }

    $tag = if ($matchingTags.Count -eq 1) { $matchingTags[0] } else { $null }
    $release = if ($matchingReleases.Count -eq 1) {
        $matchingReleases[0]
    } else {
        $null
    }
    if ($null -ne $tag) {
        $tagCommit = [string](Get-ReleaseRecordValue $tag 'CommitSha' '')
        if ($tagCommit -notmatch '^[0-9A-Fa-f]{40}$' -or
            $tagCommit.ToLowerInvariant() -cne $commit) {
            throw "标签 $tagName 已指向其他提交：$tagCommit"
        }
    }
    if ($null -ne $release) {
        if (-not [bool](Get-ReleaseRecordValue $release 'draft' $false)) {
            throw "Release $tagName 已公开，禁止覆盖或修改。"
        }
        $target = [string](Get-ReleaseRecordValue $release `
            'target_commitish' '')
        if ($target.ToLowerInvariant() -cne $commit) {
            throw "草稿 Release $tagName 属于其他提交：$target"
        }
    }

    $state = if ($null -ne $release) {
        'resume-draft'
    } elseif ($null -ne $tag) {
        'recover-tag'
    } else {
        'new'
    }
    return [pscustomobject]@{
        Version = $Version
        Tag = $tagName
        CommitSha = $commit
        State = $state
        ReleaseId = if ($null -ne $release) {
            [long](Get-ReleaseRecordValue $release 'id' 0)
        } else {
            0
        }
        HasTag = $null -ne $tag
    }
}

function Normalize-ReleaseBody {
    param([AllowNull()][string]$Text)

    if ($null -eq $Text) {
        return ''
    }
    return ($Text -replace "`r`n", "`n").TrimEnd("`r", "`n")
}

function Assert-ReleaseNotesImportantSection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$BodyPath
    )

    if (-not (Test-Path -LiteralPath $BodyPath -PathType Leaf)) {
        throw "发行说明不存在：$BodyPath"
    }
    $body = Get-Content -LiteralPath $BodyPath -Raw -Encoding UTF8
    $headings = [regex]::Matches($body, '(?m)^## ⚠️ 重要说明\r?$')
    if ($headings.Count -gt 1) {
        throw '发行说明最多只能包含一个“⚠️ 重要说明”章节。'
    }
    if ($headings.Count -eq 0) {
        return
    }

    $heading = $headings[0]
    $regularHeading = [regex]::Match($body,
        '(?m)^## (?:✨ 新增|🚀 优化|🐛 修复|✅ 验证范围|🔒 安全)\r?$')
    if ($regularHeading.Success -and $heading.Index -gt $regularHeading.Index) {
        throw '“⚠️ 重要说明”必须位于常规变更章节之前。'
    }

    $sectionStart = $heading.Index + $heading.Length
    $remaining = $body.Substring($sectionStart).TrimStart("`r", "`n")
    $boundary = [regex]::Match($remaining, '(?m)^(?:---\r?$|## )')
    $sectionText = if ($boundary.Success) {
        $remaining.Substring(0, $boundary.Index).Trim()
    } else {
        $remaining.Trim()
    }
    $items = [regex]::Matches($sectionText,
        '(?ms)^- (?<Text>.*?)(?=^- |\z)')
    if ($items.Count -eq 0) {
        throw '“⚠️ 重要说明”没有合格事项时必须连标题一起省略。'
    }

    $warningPattern = [regex]::new(
        '不兼容|无法|不再|必须|请先|请在|否则|可能(?:导致|丢失)|' +
        '会(?:导致|丢失|被(?:删除|重置|覆盖|忽略))|将被(?:删除|重置|覆盖|忽略)|' +
        '迁移|备份|最低(?:版本|要求)|停止支持|不支持|破坏性|风险|' +
        '不要(?:只|直接)|需要(?:先|重新|手动|额外|迁移|备份|卸载|安装|更新|升级|替换|配置)')
    $placeholderPattern = [regex]::new(
        '仅在存在|保留本节|待补充|TODO|TBD|示例')
    foreach ($item in $items) {
        $text = $item.Groups['Text'].Value.Trim()
        if ($placeholderPattern.IsMatch($text)) {
            throw '“⚠️ 重要说明”不能保留模板提示或占位文本。'
        }
        if (-not $warningPattern.IsMatch($text)) {
            throw ('“⚠️ 重要说明”中的每一项都必须描述不兼容、数据风险、' +
                '破坏性变化或用户必须执行的升级操作：' + $text)
        }
    }
}

function Assert-ReleaseNotesContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$BodyPath
    )

    if (-not (Test-CanonicalReleaseVersion $Version)) {
        throw "发行说明使用了非规范版本号：$Version"
    }
    if (-not (Test-Path -LiteralPath $BodyPath -PathType Leaf)) {
        throw "发行说明不存在：$BodyPath"
    }
    $body = Get-Content -LiteralPath $BodyPath -Raw -Encoding UTF8
    $escapedVersion = [regex]::Escape($Version)
    if ($body -notmatch "(?m)^# 🎉 进程守护小助手 v$escapedVersion\r?$") {
        throw '发行说明必须保留带 🎉 的版本标题。'
    }
    Assert-ReleaseNotesImportantSection -BodyPath $BodyPath
    $assetHeadings = [regex]::Matches($body,
        '(?m)^## 📦 发布物说明\r?$')
    if ($assetHeadings.Count -ne 1) {
        throw '发行说明必须且只能包含一个“📦 发布物说明”章节。'
    }
    $assetHeading = $assetHeadings[0]
    $sectionText = $body.Substring(
        $assetHeading.Index + $assetHeading.Length).TrimStart("`r", "`n")
    if ($sectionText -match '(?m)^(?:## |---\r?$)') {
        throw '“📦 发布物说明”必须是发行说明的最后一个章节。'
    }

    $specifications = @(
        @{
            Name = "process-watchdog-$Version-windows-x64.exe"
            Required = @('独立可执行版', '无需安装 AutoHotkey', '快速体验')
        }
        @{
            Name = "process-watchdog-$Version-windows-x64.zip"
            Required = @('完整便携版', 'EXE', '说明文档', '许可证', '字体',
                '运行所需资源', '长期使用', '手动部署')
        }
        @{
            Name = "process-watchdog-$Version-source.zip"
            Required = @('完整源码版', 'AHK 源码', '模块', '测试', '文档',
                '字体', '审阅', '开发', 'AutoHotkey v2 x64')
        }
    )
    foreach ($specification in $specifications) {
        $name = [string]$specification.Name
        $lines = [regex]::Matches($sectionText,
            '(?m)^- [^\r\n]*' + [regex]::Escape($name) + '[^\r\n]*\r?$')
        if ($lines.Count -ne 1) {
            throw "发布物说明必须且只能逐项说明一次：$name"
        }
        foreach ($requiredText in $specification.Required) {
            if (-not $lines[0].Value.Contains([string]$requiredText)) {
                throw "发布物说明不完整：$name 缺少必要信息：$requiredText"
            }
        }
    }
}

function Assert-ReleaseRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Release,
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$CommitSha,
        [Parameter(Mandatory)][ValidateSet('Draft', 'Published')]
        [string]$Stage,
        [Parameter(Mandatory)][string]$BodyPath,
        [Parameter(Mandatory)][string]$LocalArtifactDirectory,
        [AllowEmptyString()][string]$TagCommitSha = ""
    )

    $tagName = "v$Version"
    if ([string](Get-ReleaseRecordValue $Release 'tag_name' '') -cne
        $tagName) {
        throw "Release 标签不是预期值：$tagName"
    }
    $expectedTitle = "进程守护小助手 v$Version"
    if ([string](Get-ReleaseRecordValue $Release 'name' '') -cne
        $expectedTitle) {
        throw "Release 标题不是预期值：$expectedTitle"
    }
    $isDraft = [bool](Get-ReleaseRecordValue $Release 'draft' $false)
    if (($Stage -ceq 'Draft') -ne $isDraft) {
        throw "Release 的草稿状态与审计阶段不一致：$Stage"
    }
    if ([bool](Get-ReleaseRecordValue $Release 'prerelease' $false)) {
        throw '正式版本不能标记为预发布。'
    }
    $target = [string](Get-ReleaseRecordValue $Release `
        'target_commitish' '')
    if ($target.ToLowerInvariant() -cne $CommitSha.ToLowerInvariant()) {
        throw "Release 指向了非预期提交：$target"
    }
    Assert-ReleaseNotesContent -Version $Version -BodyPath $BodyPath
    $expectedBody = Get-Content -LiteralPath $BodyPath -Raw -Encoding UTF8
    $actualBody = [string](Get-ReleaseRecordValue $Release 'body' '')
    if ((Normalize-ReleaseBody $actualBody) -cne
        (Normalize-ReleaseBody $expectedBody)) {
        throw 'GitHub Release 正文与仓库发行说明不一致。'
    }
    if ($TagCommitSha) {
        if ($TagCommitSha -notmatch '^[0-9A-Fa-f]{40}$' -or
            $TagCommitSha.ToLowerInvariant() -cne
            $CommitSha.ToLowerInvariant()) {
            throw "Release 标签指向了非预期提交：$TagCommitSha"
        }
    } elseif ($Stage -ceq 'Published') {
        throw '公开 Release 缺少对应的远程标签。'
    }
    [void](Assert-ReleaseArtifactInventory `
        -Assets @(Get-ReleaseRecordValue $Release 'assets' @()) `
        -Version $Version -LocalArtifactDirectory $LocalArtifactDirectory `
        -RequireDigest)
}

Export-ModuleMember -Function @(
    'Test-CanonicalReleaseVersion'
    'Get-ReleaseArtifactNames'
    'Assert-ReleaseArtifactInventory'
    'Assert-ReleaseNotesImportantSection'
    'Assert-ReleaseNotesContent'
    'Resolve-ReleaseState'
    'Assert-ReleaseRecord'
)
