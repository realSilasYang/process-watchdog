# 仓库结构与版本一致性检查。
# 确认公开发布所需文件齐全、版本号互相一致，并阻止临时产物或本机配置进入仓库。

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$requiredFiles = @(
    'LICENSE',
    'README.md',
    'docs\README.zh-HK.md',
    'docs\README.zh-TW.md',
    'docs\README.en.md',
    'docs\README.ja.md',
    'docs\README.vi.md',
    'docs\README.ko.md',
    'docs\README.es.md',
    'docs\README.fr.md',
    'docs\README.pt-BR.md',
    'docs\README.ru.md',
    'docs\README.de.md',
    'docs\README.it.md',
    'CHANGELOG.md',
    'docs\CHANGELOG.en.md',
    '.github\CONTRIBUTING.md',
    '.github\CONTRIBUTING.en.md',
    '.github\CODE_OF_CONDUCT.md',
    '.github\CODE_OF_CONDUCT.en.md',
    '.github\SECURITY.md',
    '.github\SECURITY.en.md',
    '.github\SUPPORT.md',
    '.github\SUPPORT.en.md',
    'docs\project\GOVERNANCE.md',
    'docs\project\GOVERNANCE.en.md',
    'docs\project\THIRD_PARTY_NOTICES.md',
    'docs\project\THIRD_PARTY_NOTICES.en.md',
    'VERSION',
    'config\watchdog.example.ini',
    'assets\app\watchdog.ico',
    'assets\donate\微信个人收款码.png',
    'assets\donate\微信个人收款码-界面.png',
    'assets\donate\支付宝个人收款码.png',
    'assets\donate\支付宝个人收款码-界面.png',
    'assets\ui-icons\external-link.svg',
    'assets\fonts\AppleSDGothicNeo-Regular.ttf',
    'assets\fonts\COMMERCIAL-LICENSE-NOTICE.md',
    'assets\fonts\COMMERCIAL-LICENSE-NOTICE.en.md',
    'assets\fonts\HaranoAjiGothic-Regular.otf',
    'assets\fonts\NotoSans-Variable.ttf',
    'assets\fonts\NotoSansCJK.ttc',
    'assets\fonts\PingFang.ttc',
    'assets\fonts\SF-Pro-Text-Bold.otf',
    'assets\fonts\SF-Pro-Text-Regular.otf',
    'assets\fonts\metadata.json',
    'assets\fonts\OFL-1.1.txt',
    'assets\fonts\README.md',
    'assets\fonts\README.en.md',
    'docs\images\process-watchdog-overview.png',
    'docs\images\process-watchdog-overview-light.png',
    '.editorconfig',
    '.mailmap',
    '.github\CODEOWNERS',
    'app\ApplicationState.ahk',
    'app\RuntimeAdapters.ahk',
    'app\WatchlistCommands.ahk',
    'app\UI\InteractionPresenter.ahk',
    'app\UI\MainVisualPipeline.ahk',
    'src\Update\ApplicationUpdateService.ahk',
    'src\Update\ApplicationVersionInfo.ahk',
    'runtime\application-update.ps1',
    'runtime\application-update.strings.json',
    'tests\application-update-helper-tests.ps1',
    '.github\workflows\ci.yml',
    '.github\workflows\release.yml',
    '.github\workflows\release-dry-run.yml',
    '.github\workflows\soak.yml',
    'third_party\dependencies.lock.json',
    'tools\toolchain.lock.json',
    'tools\ci-toolchain.resolved.json',
    'tools\ReleaseEngineering.psm1',
    'tools\resolve-release-state.ps1',
    'tools\invoke-release-validation.ps1',
    'tools\verify-github-release.ps1',
    'tools\verify-release-draft.ps1',
    'tools\verify-published-release.ps1',
    'tools\resolve-toolchain.ps1',
    'tools\generate-sbom.ps1',
    'tools\verify-release.ps1',
    'tests\verify-workflows.ps1'
    'tests\release-engineering-tests.ps1'
    'tests\verify-publication.ps1'
    'docs\README.md'
    'docs\versioning.md'
    'docs\en\versioning.md'
    'docs\publication-checklist.md'
    'docs\en\publication-checklist.md'
    '.github\ISSUE_TEMPLATE\bug_report_en.yml'
    '.github\ISSUE_TEMPLATE\feature_request_en.yml'
    '.github\ISSUE_TEMPLATE\improvement_en.yml'
)
foreach ($relativePath in $requiredFiles) {
    $path = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required repository file is missing: $relativePath"
    }
}

$trackedFiles = @(git -c core.quotePath=false -C $projectRoot ls-files)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to inspect tracked repository files.'
}
$trackedNormalized = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase)
foreach ($trackedFile in $trackedFiles) {
    [void]$trackedNormalized.Add(($trackedFile -replace '/', '\'))
}
foreach ($relativePath in $requiredFiles) {
    if (-not $trackedNormalized.Contains($relativePath)) {
        throw "Required repository file is not tracked: $relativePath"
    }
}
# 根目录只承载仓库和程序入口；新增资料必须进入职责明确的子目录，避免项目再次
# 退化成版本文件、图片、示例配置和多语言文档混排的平面结构。
$allowedRootFiles = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase)
foreach ($rootFile in @(
        '.editorconfig', '.gitattributes', '.gitignore', '.mailmap',
        'CHANGELOG.md', 'LICENSE', 'README.md', 'VERSION',
        '进程守护小助手.ahk')) {
    [void]$allowedRootFiles.Add($rootFile)
}
foreach ($trackedFile in $trackedFiles | Where-Object { $_ -notmatch '[/\\]' }) {
    if (-not $allowedRootFiles.Contains($trackedFile)) {
        throw "Tracked file does not belong at the repository root: $trackedFile"
    }
}
foreach ($prefix in @('src\', 'app\', 'tests\core\', 'assets\', 'config\',
        'third_party\')) {
    $diskFiles = Get-ChildItem -LiteralPath (Join-Path $projectRoot `
        $prefix.TrimEnd('\')) -Recurse -File
    foreach ($file in $diskFiles) {
        $relativePath = $file.FullName.Substring($projectRoot.Length + 1)
        if (-not $trackedNormalized.Contains($relativePath)) {
            throw "Project input is not tracked: $relativePath"
        }
    }
}

# 随包字体中存在超过 GitHub 普通对象单文件限制的完整 CJK 集合。字体必须统一
# 通过 Git LFS 追踪，三个会读取或打包字体的工作流也必须显式还原 LFS 对象；否则
# 本地测试看到的是完整字体，CI 和 Release 却只会得到一百多字节的指针文件。
foreach ($fontExtension in @('ttc', 'ttf', 'otf')) {
    $attributeProbe = git -C $projectRoot check-attr filter -- `
        "assets/fonts/__repository_check__.$fontExtension"
    if ($LASTEXITCODE -ne 0 -or
        $attributeProbe -notmatch ':\s*filter:\s*lfs\s*$') {
        throw "Packaged *.$fontExtension fonts must be tracked by Git LFS."
    }
}
$lfsWorkflows = @('ci.yml', 'release.yml', 'soak.yml')
foreach ($workflowName in $lfsWorkflows) {
    $workflowPath = Join-Path $projectRoot `
        ".github\workflows\$workflowName"
    $workflowText = Get-Content -LiteralPath $workflowPath -Raw -Encoding UTF8
    if ($workflowText -notmatch '(?m)^\s+lfs:\s+true\s*$') {
        throw "$workflowName must restore packaged Git LFS font assets."
    }
}
if ($trackedNormalized.Contains('watchdog.ini')) {
    throw 'The local runtime watchdog.ini must not be tracked.'
}
if (Test-Path -LiteralPath (Join-Path $projectRoot 'Everything64.dll')) {
    throw 'Everything64.dll must only exist under third_party.'
}
if (Get-ChildItem -LiteralPath $projectRoot -File -Filter '_codex_*') {
    throw 'Temporary Codex probe files must not remain at the repository root.'
}
foreach ($obsoletePath in @(
        'README.en.md', 'CHANGELOG.en.md', 'watchdog.ico',
        'watchdog.example.ini', 'docs\development')) {
    if (Test-Path -LiteralPath (Join-Path $projectRoot $obsoletePath)) {
        throw "Obsolete repository location remains: $obsoletePath"
    }
}

$version = (Get-Content -LiteralPath (Join-Path $projectRoot 'VERSION') `
    -Raw -Encoding UTF8).Trim()
if ($version -notmatch `
    '^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$') {
    throw "VERSION is not semantic version text: $version"
}
$releaseNotesPath = Join-Path $projectRoot `
    "docs\release-notes\v$version.md"
if (-not (Test-Path -LiteralPath $releaseNotesPath -PathType Leaf)) {
    throw "Current release notes are missing: docs\release-notes\v$version.md"
}
$releaseNotesRelativePath = "docs/release-notes/v$version.md"
if ($trackedFiles -notcontains $releaseNotesRelativePath) {
    throw "Current release notes are not tracked: $releaseNotesRelativePath"
}
$mainScripts = @(Get-ChildItem -LiteralPath $projectRoot -File `
    -Filter '*.ahk' | Where-Object { $_.Name -notlike '_*' })
if ($mainScripts.Count -ne 1) {
    throw "Repository must contain exactly one root entry script; found $($mainScripts.Count)."
}
$mainScript = $mainScripts[0]
$source = Get-Content -LiteralPath $mainScript.FullName -Raw -Encoding UTF8
$applicationVersionSource = Get-Content -LiteralPath (Join-Path `
    $projectRoot 'src\Update\ApplicationVersionInfo.ahk') -Raw -Encoding UTF8
$mainLineCount = (Get-Content -LiteralPath $mainScript.FullName `
    -Encoding UTF8).Count
if ($mainLineCount -gt 1600) {
    throw "Composition root grew beyond 1600 lines: $mainLineCount"
}
foreach ($appModule in Get-ChildItem -LiteralPath (Join-Path $projectRoot 'app') `
    -Recurse -File -Filter '*.ahk') {
    $relativePath = $appModule.FullName.Substring($projectRoot.Length + 1)
    if (-not $source.Contains("#Include $relativePath")) {
        throw "Application module is not included by the composition root: $relativePath"
    }
}
$fileVersion = "$version.0"
if ($source -notmatch ('(?m)^;@Ahk2Exe-SetVersion\s+' +
        [regex]::Escape($fileVersion) + '\r?$')) {
    throw "Compiled file version does not match VERSION: $fileVersion"
}
if ($applicationVersionSource -notmatch
        'FileGetVersion\(A_ScriptFullPath\)' -or
    $applicationVersionSource -notmatch 'return "unknown"' -or
    $applicationVersionSource -match 'return "\d+\.\d+\.\d+"') {
    throw 'Runtime version fallback must use compiled metadata without a duplicated release literal.'
}

$examplePath = Join-Path $projectRoot 'config\watchdog.example.ini'
$exampleBytes = [System.IO.File]::ReadAllBytes($examplePath)
if ($exampleBytes.Length -lt 2 -or $exampleBytes[0] -ne 0xFF -or
    $exampleBytes[1] -ne 0xFE) {
    throw 'config/watchdog.example.ini must be UTF-16 LE with BOM.'
}

# Windows PowerShell 5.1 会按系统代码页解释无 BOM 的脚本。项目脚本含有中文注释，
# 因此所有 PowerShell 入口都必须带 UTF-8 BOM，不能只依赖编辑器显示正确。
$powerShellScripts = @(
    Get-ChildItem -LiteralPath (Join-Path $projectRoot 'tests') -Recurse `
        -File | Where-Object Extension -in @('.ps1', '.psm1')
    Get-ChildItem -LiteralPath (Join-Path $projectRoot 'tools') -Recurse `
        -File | Where-Object Extension -in @('.ps1', '.psm1')
)
foreach ($script in $powerShellScripts) {
    $bytes = [System.IO.File]::ReadAllBytes($script.FullName)
    if ($bytes.Length -lt 3 -or $bytes[0] -ne 0xEF -or
        $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
        $relativePath = $script.FullName.Substring($projectRoot.Length + 1)
        throw "PowerShell script must use UTF-8 BOM: $relativePath"
    }
}

# 每个项目自有脚本都要在文件内说明真实职责，不能只靠目录名猜测；第三方源码、
# 生成物和数据文件不在此范围。工作流同样属于可执行自动化，因此也要求中文说明。
$commentedScripts = @($mainScript)
foreach ($scriptRoot in @('app', 'src', 'tests', 'tools',
        '.github\workflows',
        '.github\ISSUE_TEMPLATE')) {
    $commentedScripts += Get-ChildItem -LiteralPath `
        (Join-Path $projectRoot $scriptRoot) -Recurse -File |
        Where-Object { $_.Extension -in @('.ahk', '.ps1', '.yml', '.yaml') }
}
$commentedScripts += Get-Item -LiteralPath `
    (Join-Path $projectRoot '.github\dependabot.yml')

function Get-AutoHotkeyLineComment {
    param([string]$Line)

    $insideString = $false
    for ($index = 0; $index -lt $Line.Length; $index++) {
        $character = $Line[$index]
        # AutoHotkey 使用反引号转义紧随其后的字符；跳过被转义字符，避免把
        # 字符串内的分号或双引号误认成源码注释边界。
        if ($character -eq [char]0x60) {
            $index++
            continue
        }
        if ($character -eq [char]0x22) {
            $insideString = -not $insideString
            continue
        }
        if (-not $insideString -and $character -eq ';' -and
            ($index -eq 0 -or [char]::IsWhiteSpace($Line[$index - 1]))) {
            return $Line.Substring($index + 1)
        }
    }
    return $null
}

foreach ($script in $commentedScripts) {
    $scriptText = Get-Content -LiteralPath $script.FullName -Raw -Encoding UTF8
    $commentPattern = if ($script.Extension -eq '.ahk') {
        '(?m)^\s*(?:;|\*)[^\r\n]*[\u3400-\u9fff]'
    } else {
        '(?m)^\s*#[^\r\n]*[\u3400-\u9fff]'
    }
    if ($scriptText -notmatch $commentPattern) {
        $relativePath = $script.FullName.Substring($projectRoot.Length + 1)
        throw "Project script lacks a Chinese responsibility comment: $relativePath"
    }

    $lineNumber = 0
    foreach ($line in $scriptText -split "`r?`n") {
        $lineNumber++
        $commentText = if ($script.Extension -eq '.ahk') {
            Get-AutoHotkeyLineComment $line
        } elseif ($line -match '^\s*#\s*(.*)$') {
            $Matches[1]
        } else {
            $null
        }
        if ($null -eq $commentText -or $commentText.TrimStart().StartsWith('@')) {
            continue
        }
        # 官方 API、常量和快捷键名称可以保留原文以便检索，但说明句必须含中文，
        # 不能退回到只有英文标签、中文读者仍需猜测用途的注释。
        if ($commentText -match '[A-Za-z]{4}' -and
            $commentText -notmatch '[\u3400-\u9fff]') {
            $relativePath = $script.FullName.Substring($projectRoot.Length + 1)
            throw "Project script contains an English-only comment: ${relativePath}:$lineNumber"
        }
    }
    if ($script.Extension -eq '.ahk') {
        foreach ($blockMatch in [regex]::Matches($scriptText,
                '(?s)/\*(.*?)\*/')) {
            $blockStartLine = 1 + ($scriptText.Substring(0,
                $blockMatch.Index) -split "`n").Count - 1
            $blockLineOffset = 0
            foreach ($blockLine in $blockMatch.Groups[1].Value -split "`r?`n") {
                $blockLineOffset++
                if ($blockLine -match '[A-Za-z]{4}' -and
                    $blockLine -notmatch '[\u3400-\u9fff]') {
                    $relativePath = $script.FullName.Substring(
                        $projectRoot.Length + 1)
                    $blockLineNumber = $blockStartLine + $blockLineOffset - 1
                    throw "Project script contains an English-only block comment: ${relativePath}:$blockLineNumber"
                }
            }
        }
    }
}

# README 的语言入口属于公开界面的一部分。逐份构造期望标记，可同时拦截语言缺失、
# 链接指错、顺序漂移，以及把非当前语言误标成粗体等不易人工发现的退化。
$localizedReadmes = @(
    [pscustomobject]@{
        Path = 'README.md'; Label = '简体中文'
        RootHref = './README.md'; DocsHref = '../README.md'
    },
    [pscustomobject]@{
        Path = 'docs\README.zh-HK.md'; Label = '繁體中文（香港）'
        RootHref = './docs/README.zh-HK.md'; DocsHref = './README.zh-HK.md'
    },
    [pscustomobject]@{
        Path = 'docs\README.zh-TW.md'; Label = '繁體中文（台灣）'
        RootHref = './docs/README.zh-TW.md'; DocsHref = './README.zh-TW.md'
    },
    [pscustomobject]@{
        Path = 'docs\README.en.md'; Label = 'English'
        RootHref = './docs/README.en.md'; DocsHref = './README.en.md'
    },
    [pscustomobject]@{
        Path = 'docs\README.ja.md'; Label = '日本語'
        RootHref = './docs/README.ja.md'; DocsHref = './README.ja.md'
    },
    [pscustomobject]@{
        Path = 'docs\README.vi.md'; Label = 'Tiếng Việt'
        RootHref = './docs/README.vi.md'; DocsHref = './README.vi.md'
    },
    [pscustomobject]@{
        Path = 'docs\README.ko.md'; Label = '한국어'
        RootHref = './docs/README.ko.md'; DocsHref = './README.ko.md'
    },
    [pscustomobject]@{
        Path = 'docs\README.es.md'; Label = 'Español'
        RootHref = './docs/README.es.md'; DocsHref = './README.es.md'
    },
    [pscustomobject]@{
        Path = 'docs\README.fr.md'; Label = 'Français'
        RootHref = './docs/README.fr.md'; DocsHref = './README.fr.md'
    },
    [pscustomobject]@{
        Path = 'docs\README.pt-BR.md'; Label = 'Português'
        RootHref = './docs/README.pt-BR.md'; DocsHref = './README.pt-BR.md'
    },
    [pscustomobject]@{
        Path = 'docs\README.ru.md'; Label = 'Русский'
        RootHref = './docs/README.ru.md'; DocsHref = './README.ru.md'
    },
    [pscustomobject]@{
        Path = 'docs\README.de.md'; Label = 'Deutsch'
        RootHref = './docs/README.de.md'; DocsHref = './README.de.md'
    },
    [pscustomobject]@{
        Path = 'docs\README.it.md'; Label = 'Italiano'
        RootHref = './docs/README.it.md'; DocsHref = './README.it.md'
    }
)
$readmeRequiredTopics = @(
    'Running', 'Stopped', 'Unknown', 'Everything', 'watchdog.ini',
    'watchdog.maintenance.ini', 'AutoHotkey', 'Ahk2Exe',
    'third_party', 'reproducible-build.ps1'
)
foreach ($readmeDefinition in $localizedReadmes) {
    $readmePath = Join-Path $projectRoot $readmeDefinition.Path
    $readme = Get-Content -LiteralPath $readmePath -Raw -Encoding UTF8
    $languageBarMatch = [regex]::Match($readme,
        '(?s)<div align="center">\s*<p>(.*?)</p>')
    if (-not $languageBarMatch.Success) {
        throw "Localized README has no language switcher: $($readmeDefinition.Path)"
    }

    $expectedEntries = @()
    foreach ($targetDefinition in $localizedReadmes) {
        if ($targetDefinition.Path -eq $readmeDefinition.Path) {
            $expectedEntries += "<strong>$($targetDefinition.Label)</strong>"
            continue
        }
        $href = if ($readmeDefinition.Path -eq 'README.md') {
            $targetDefinition.RootHref
        } else {
            $targetDefinition.DocsHref
        }
        $expectedEntries += "<a href=`"$href`">$($targetDefinition.Label)</a>"
    }
    $expectedLanguageBar = $expectedEntries -join ' · '
    if ($languageBarMatch.Groups[1].Value.Trim() -cne $expectedLanguageBar) {
        throw "Localized README language switcher is inconsistent: $($readmeDefinition.Path)"
    }

    # 每个版本都必须是完整说明，而不是只有语言跳转的占位页。稳定的技术词同时覆盖
    # 身份探测、搜索、配置、升级状态和可复现构建等主要职责。
    if ($readme.Length -lt 9000) {
        throw "Localized README is unexpectedly short: $($readmeDefinition.Path)"
    }
    foreach ($requiredTopic in $readmeRequiredTopics) {
        if (-not $readme.Contains($requiredTopic)) {
            throw "Localized README is missing $requiredTopic`: $($readmeDefinition.Path)"
        }
    }
    foreach ($imageRequirement in @(
            'media="(prefers-color-scheme: dark)"',
            'media="(prefers-color-scheme: light)"',
            'process-watchdog-overview.png',
            'process-watchdog-overview-light.png')) {
        if (-not $readme.Contains($imageRequirement)) {
            throw "Localized README lacks theme-aware overview media: $($readmeDefinition.Path)"
        }
    }
}

# 文档迁移后最容易遗漏的是相对链接。这里按文件实际目录解析本地目标，并拒绝
# 跳出仓库的路径；网络地址和页内锚点交给对应平台处理。
$projectRootPrefix = $projectRoot.TrimEnd('\') + '\'
$markdownFiles = Get-ChildItem -LiteralPath $projectRoot -Recurse -File `
    -Filter '*.md' | Where-Object {
        $_.FullName -notmatch '\\.git\\|\\.tools\\|\\.build\\|\\dist\\'
    }
foreach ($markdownFile in $markdownFiles) {
    $markdown = Get-Content -LiteralPath $markdownFile.FullName -Raw `
        -Encoding UTF8
    foreach ($linkMatch in [regex]::Matches($markdown,
            '!?\[[^\]]*\]\(([^)]+)\)')) {
        $linkTarget = $linkMatch.Groups[1].Value.Trim()
        if ($linkTarget -match '^(?:[a-z][a-z0-9+.-]*:|#)') {
            continue
        }
        if ($linkTarget.StartsWith('<') -and $linkTarget.EndsWith('>')) {
            $linkTarget = $linkTarget.Substring(1, $linkTarget.Length - 2)
        }
        $linkTarget = ($linkTarget -split '#', 2)[0]
        if ($linkTarget -eq '') {
            continue
        }
        $decodedTarget = [Uri]::UnescapeDataString($linkTarget) `
            -replace '/', '\'
        $resolvedTarget = [System.IO.Path]::GetFullPath((Join-Path `
            $markdownFile.DirectoryName $decodedTarget))
        if (-not $resolvedTarget.StartsWith($projectRootPrefix,
                [System.StringComparison]::OrdinalIgnoreCase) -or
            -not (Test-Path -LiteralPath $resolvedTarget)) {
            $relativeMarkdownPath = $markdownFile.FullName.Substring(
                $projectRootPrefix.Length)
            throw "Repository Markdown link is broken: $relativeMarkdownPath -> $linkTarget"
        }
    }
}

$allText = Get-ChildItem -LiteralPath $projectRoot -Recurse -File |
    Where-Object {
        $_.FullName -notmatch '\\.git\\|\\third_party\\.*\.(dll|h)$' -and
        $_.Extension -in @('.md', '.ps1', '.yml', '.yaml', '.json', '.ahk')
    } | ForEach-Object {
        try { Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 }
        catch { '' }
    }
$repositoryPlaceholder = 'OWNER' + '/REPOSITORY'
if (($allText -join "`n").Contains($repositoryPlaceholder)) {
    throw 'Repository documentation contains an unresolved hosting placeholder.'
}

$toolLockPath = Join-Path $projectRoot 'tools\toolchain.lock.json'
$toolLock = Get-Content -LiteralPath $toolLockPath -Raw -Encoding UTF8 |
    ConvertFrom-Json
if ($toolLock.schemaVersion -ne 1) {
    throw 'Toolchain lock schema is invalid.'
}
foreach ($toolName in @('actionlint', 'gitleaks')) {
    $definition = $toolLock.tools.$toolName
    foreach ($propertyName in @('version', 'archive', 'url', 'sha256',
            'executable', 'executableSha256', 'licenseExpression',
            'sbomRelationship')) {
        if ($definition.PSObject.Properties.Name -notcontains $propertyName -or
            -not $definition.$propertyName) {
            throw "Toolchain lock is missing $toolName.$propertyName."
        }
    }
    foreach ($hashProperty in @('sha256', 'executableSha256')) {
        if ($definition.$hashProperty -notmatch '^[0-9A-F]{64}$') {
            throw "Toolchain lock hash is invalid: $toolName.$hashProperty"
        }
    }
    if ($definition.PSObject.Properties.Name -contains 'licenseFile') {
        foreach ($propertyName in @('licenseFile', 'licenseSha256')) {
            if ($definition.PSObject.Properties.Name `
                    -notcontains $propertyName -or
                -not $definition.$propertyName) {
                throw "Toolchain lock is missing $toolName.$propertyName."
            }
        }
        if ($definition.licenseSha256 -notmatch '^[0-9A-F]{64}$') {
            throw "Toolchain license hash is invalid: $toolName"
        }
    }
}
foreach ($dynamicTool in @('autoHotkey', 'ahk2Exe')) {
    if ($toolLock.tools.PSObject.Properties.Name -contains $dynamicTool) {
        throw "$dynamicTool must be resolved from upstream at release time, not pinned in the repository lock."
    }
}
$ciToolchainPath = Join-Path $projectRoot 'tools\ci-toolchain.resolved.json'
$ciToolchain = Get-Content -LiteralPath $ciToolchainPath -Raw `
    -Encoding UTF8 | ConvertFrom-Json
if ($ciToolchain.schemaVersion -ne 2 -or
    $ciToolchain.selection.autoHotkey -cne 'repository-ci-snapshot' -or
    $ciToolchain.selection.ahk2Exe -cne 'repository-ci-snapshot') {
    throw 'CI toolchain snapshot schema or selection policy is invalid.'
}
foreach ($toolName in @('autoHotkey', 'ahk2Exe', 'actionlint', 'gitleaks')) {
    $definition = $ciToolchain.tools.$toolName
    foreach ($propertyName in @('version', 'archive', 'url', 'sha256',
            'executable', 'executableSha256', 'licenseExpression',
            'sbomRelationship')) {
        if ($definition.PSObject.Properties.Name -notcontains $propertyName -or
            -not $definition.$propertyName) {
            throw "CI toolchain snapshot is missing $toolName.$propertyName."
        }
    }
    foreach ($hashProperty in @('sha256', 'executableSha256')) {
        if ($definition.$hashProperty -notmatch '^[0-9A-F]{64}$') {
            throw "CI toolchain snapshot hash is invalid: $toolName.$hashProperty"
        }
    }
}
foreach ($fixedTool in @('actionlint', 'gitleaks')) {
    if (($ciToolchain.tools.$fixedTool | ConvertTo-Json -Depth 8 -Compress) `
            -cne ($toolLock.tools.$fixedTool | ConvertTo-Json -Depth 8 `
                -Compress)) {
        throw "CI snapshot drifted from tools/toolchain.lock.json: $fixedTool"
    }
}

$workflowFiles = Get-ChildItem -LiteralPath `
    (Join-Path $projectRoot '.github\workflows') -File -Filter '*.yml'
foreach ($workflowFile in $workflowFiles) {
    $workflowLines = Get-Content -LiteralPath $workflowFile.FullName `
        -Encoding UTF8
    foreach ($workflowLine in $workflowLines) {
        if ($workflowLine -notmatch '^\s*uses:\s*([^\s#]+)') {
            continue
        }
        $actionReference = $Matches[1]
        if ($actionReference.StartsWith('./')) {
            continue
        }
        if ($actionReference -notmatch '@[0-9a-f]{40}$') {
            throw "Workflow action is not pinned to a commit SHA: $actionReference"
        }
    }
}

$releaseWorkflow = Get-Content -LiteralPath `
    (Join-Path $projectRoot '.github\workflows\release.yml') `
    -Raw -Encoding UTF8
foreach ($releaseRequirement in @(
        '.\tools\resolve-release-state.ps1',
        '.\tools\invoke-release-validation.ps1',
        '.\tools\verify-release-draft.ps1',
        '.\tools\verify-published-release.ps1',
        '-RefreshBuildTools',
        'workflow_dispatch:',
        'actions/attest-build-provenance@',
        'actions/upload-artifact@',
        'path: dist/**',
        'dist/process-watchdog-${{ steps.release_meta.outputs.version }}-windows-x64.exe',
        'dist/process-watchdog-${{ steps.release_meta.outputs.version }}-windows-x64.zip',
        'dist/process-watchdog-${{ steps.release_meta.outputs.version }}-source.zip',
        'draft: true',
        '--draft=false')) {
    if (-not $releaseWorkflow.Contains($releaseRequirement)) {
        throw "Release workflow is missing: $releaseRequirement"
    }
}
if ($releaseWorkflow.Contains('dist/*.spdx.json') -or
    $releaseWorkflow.Contains('dist/SHA256SUMS.txt')) {
    throw 'Release attachments must be limited to the three supported editions.'
}
$ciWorkflow = Get-Content -LiteralPath `
    (Join-Path $projectRoot '.github\workflows\ci.yml') -Raw -Encoding UTF8
if (-not $ciWorkflow.Contains('path: dist/**') -or
    -not $ciWorkflow.Contains('tools\ci-toolchain.resolved.json') -or
    -not $ciWorkflow.Contains('.\tools\invoke-release-validation.ps1')) {
    throw 'CI must use the repository toolchain snapshot and retain all build outputs.'
}

$buildScript = Get-Content -LiteralPath (Join-Path $projectRoot `
    'tools\build-release.ps1') -Raw -Encoding UTF8
if ($buildScript -match "'/setversion'" -or
    -not $buildScript.Contains(';@Ahk2Exe-SetVersion $version.0')) {
    throw 'Release build must inject the source SetVersion directive instead of passing an unsupported Ahk2Exe CLI switch.'
}
if ($releaseWorkflow -match '(?m)^\s*push:\s*$' -or
    $releaseWorkflow -match '(?m)^\s*schedule:\s*$') {
    throw 'Release workflow must only support manual workflow_dispatch execution.'
}

$updateHelper = Get-Content -LiteralPath (Join-Path $projectRoot `
    'runtime\application-update.ps1') -Raw -Encoding UTF8
foreach ($updateRequirement in @(
        "[ValidateSet('Check', 'Apply')]",
        "'zh-CN', 'zh-HK', 'zh-TW', 'en-US'",
        "'ja-JP', 'vi-VN'",
        "'ko-KR', 'es-ES', 'fr-FR', 'pt-BR'",
        "'ru-RU', 'de-DE', 'it-IT'",
        'application-update.strings.json',
        'Wait-ForParentExit',
        'Get-FileHash -Algorithm SHA256',
        'update-manifest.json',
        'Assert-ManagedRelativePath',
        'Get-MinimalManagedPaths',
        'Restore-ArchiveTransaction',
        'New-PersonalStateSnapshot',
        'Restore-PersonalStateSnapshot',
        'Complete-PersonalStateSnapshot',
        '[System.IO.File]::Replace',
        'Test-UpdatedApplication',
        'Wait-ForUpdatedApplicationReady',
        "'--unshallow'",
        "@('watchdog.ini', 'watchdog.maintenance.ini')",
        "'source-git'",
        "'--error-unmatch'",
        'merge-base',
        "'--ff-only'",
        'Remove-ApplyHelperDirectory')) {
    if (-not $updateHelper.Contains($updateRequirement)) {
        throw "Application update helper is missing: $updateRequirement"
    }
}

foreach ($workflowName in @('ci.yml', 'release.yml',
        'release-dry-run.yml')) {
    $workflowText = Get-Content -LiteralPath (Join-Path $projectRoot `
        ".github\workflows\$workflowName") -Raw -Encoding UTF8
    if ($workflowText -notmatch '(?m)^\s+fetch-depth:\s+0\s*$') {
        throw "$workflowName must fetch the complete Git history."
    }
}

Write-Host "Repository checks passed for version $version."
