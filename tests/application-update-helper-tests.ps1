# 小助手自身更新 PowerShell 边界测试。
# 以点调用加载后台助手的纯函数，不访问网络、不替换项目文件；重点覆盖容易被
# PowerShell 5.1 参数绑定和 -f 格式化规则破坏的校验和、双语格式化及路径约束。

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$helperPath = Join-Path $projectRoot 'runtime\application-update.ps1'
. $helperPath -Mode Check -UiLanguage 'zh-CN'

function Assert-UpdateHelperTest {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Get-FileByteSignature {
    param([string]$Path)

    return [Convert]::ToBase64String(
        [System.IO.File]::ReadAllBytes($Path))
}

# 文件名故意包含正则特殊字符，既验证 [regex]::Escape，也验证 {64} 量词不会被
# PowerShell 的 -f 当成第 65 个格式参数。
$checksumPath = [System.IO.Path]::GetTempFileName()
try {
    $fileName = 'process-watchdog-[1.0].zip'
    $expectedHash = 'A' * 64
    [System.IO.File]::WriteAllLines($checksumPath,
        @("$expectedHash  $fileName"), [System.Text.Encoding]::ASCII)
    $actualHash = Get-ExpectedChecksum $checksumPath $fileName
    Assert-UpdateHelperTest ($actualHash -ceq $expectedHash) `
        '更新校验和解析没有返回预期哈希。'
} finally {
    Remove-Item -LiteralPath $checksumPath -Force -ErrorAction SilentlyContinue
}

$script:UiLanguage = 'zh-CN'
$chinese = Get-UpdateText '项目 {0}，数量 {1}' 'Item {0}, count {1}' `
    @('甲', 2)
Assert-UpdateHelperTest ($chinese -ceq '项目 甲，数量 2') `
    '中文更新文本多参数格式化失败。'

$script:UiLanguage = 'en-US'
$english = Get-UpdateText '项目 {0}，数量 {1}' 'Item {0}, count {1}' `
    @('A', 2)
Assert-UpdateHelperTest ($english -ceq 'Item A, count 2') `
    '英文更新文本多参数格式化失败。'

# 独立更新助手会在主程序退出后自行显示失败信息，因此其语言资源必须完整覆盖
# 每一个 Get-UpdateText 调用，不能依赖主进程内的 AHK 词条或静默回退英文。
$localizationPath = Join-Path $projectRoot `
    'runtime\application-update.strings.json'
$localizationData = Get-Content -LiteralPath $localizationPath -Raw `
    -Encoding UTF8 | ConvertFrom-Json
Assert-UpdateHelperTest ($localizationData.schemaVersion -eq 1) `
    '更新助手语言资源架构版本无效。'
$expectedLanguages = @('zh-HK', 'zh-TW', 'ja-JP', 'vi-VN', 'ko-KR',
    'es-ES', 'fr-FR', 'pt-BR', 'ru-RU', 'de-DE', 'it-IT')
$actualLanguages = @($localizationData.languages.PSObject.Properties.Name)
Assert-UpdateHelperTest (($actualLanguages -join ',') -ceq
    ($expectedLanguages -join ',')) '更新助手语言顺序或集合不完整。'

$parserTokens = $null
$parserErrors = $null
$helperAst = [System.Management.Automation.Language.Parser]::ParseFile(
    $helperPath, [ref]$parserTokens, [ref]$parserErrors)
Assert-UpdateHelperTest ($parserErrors.Count -eq 0) `
    '更新助手脚本无法通过 PowerShell AST 解析。'
$textCalls = @($helperAst.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -eq 'Get-UpdateText'
}, $true))
$chineseTemplates = @(@(
    foreach ($textCall in $textCalls) {
        $stringArguments = @($textCall.CommandElements | Where-Object {
            $_ -is [System.Management.Automation.Language.StringConstantExpressionAst]
        })
        Assert-UpdateHelperTest ($stringArguments.Count -ge 3) `
            'Get-UpdateText 调用缺少中英文常量参数。'
        [string]$stringArguments[1].Value
    }
) | Sort-Object -Unique)

function Get-UpdatePlaceholderContract {
    param([string]$Text)

    return @([regex]::Matches($Text, '\{\d+\}') |
        ForEach-Object { $_.Value } | Sort-Object -Unique) -join ','
}

foreach ($language in $expectedLanguages) {
    $catalog = $localizationData.languages.PSObject.Properties[$language].Value
    $catalogKeys = @($catalog.PSObject.Properties.Name)
    Assert-UpdateHelperTest ($catalogKeys.Count -eq $chineseTemplates.Count) `
        "$language 更新助手词条数量不完整。"
    foreach ($template in $chineseTemplates) {
        $translationProperty = $catalog.PSObject.Properties[$template]
        Assert-UpdateHelperTest ($null -ne $translationProperty -and
            -not [string]::IsNullOrWhiteSpace(
                [string]$translationProperty.Value)) `
            "$language 缺少更新助手词条：$template"
        Assert-UpdateHelperTest ((Get-UpdatePlaceholderContract $template) `
            -ceq (Get-UpdatePlaceholderContract `
                ([string]$translationProperty.Value))) `
            "$language 更新助手词条占位符不一致：$template"
    }
}

$script:UiLanguage = 'ja-JP'
$script:UpdateTextCatalog = Import-UpdateTextCatalog $script:UiLanguage `
    $localizationPath
$localizedUpdateError = Get-UpdateText '当前小助手版本无效：{0}' `
    'Current application version is invalid: {0}' @('1.x')
Assert-UpdateHelperTest ($localizedUpdateError -ceq
    '現在のアシスタントのバージョンが無効です：1.x') `
    '更新助手未按所选语言读取并格式化独立词条。'
$script:UiLanguage = 'zh-CN'
$script:UpdateTextCatalog = $null

foreach ($unsafePath in @('watchdog.ini', 'watchdog.maintenance.ini',
        '..\outside.txt', 'C:\outside.txt')) {
    $rejected = $false
    try {
        Assert-ManagedRelativePath $unsafePath
    } catch {
        $rejected = $true
    }
    Assert-UpdateHelperTest $rejected `
        "更新路径约束没有拒绝：$unsafePath"
}

$overlapRejected = $false
try {
    Assert-NoOverlappingPaths @('docs', 'docs\nested.txt')
} catch {
    $overlapRejected = $true
}
Assert-UpdateHelperTest $overlapRejected '更新清单没有拒绝父子路径重叠。'

$minimalPaths = @(Get-MinimalManagedPaths @(
    'docs\README.md', 'docs', 'VERSION', 'docs\en\README.md'))
Assert-UpdateHelperTest (($minimalPaths -join '|') -ceq 'docs|VERSION') `
    '跨版本受管路径没有折叠到可回滚的最外层路径。'
Assert-UpdateHelperTest (Test-CanonicalVersion '1.20.300') `
    '规范三段版本被错误拒绝。'
Assert-UpdateHelperTest (-not (Test-CanonicalVersion '01.2.3')) `
    '带前导零的非规范版本被错误接受。'

# 检查阶段只要求当前运行形态真正需要的附件。这样编译版不会因为某个源码附件
# 暂缺而失去更新能力，Git 源码版也不需要下载包或校验清单。
$script:MockRelease = $null
$script:CapturedCheckResult = $null
function Invoke-GitHubApi {
    param([string]$Uri)
    return $script:MockRelease
}
function Write-CheckResult {
    param([hashtable]$Values)
    $script:CapturedCheckResult = $Values
}
function New-MockRelease {
    param([string]$Tag, [object[]]$Assets)
    return [pscustomobject]@{
        draft = $false
        prerelease = $false
        tag_name = $Tag
        html_url = 'https://example.invalid/release'
        assets = $Assets
    }
}
function New-MockAsset {
    param(
        [string]$Name,
        [string]$Digest = ''
    )
    if (-not $Digest) {
        $Digest = 'sha256:' + ('A' * 64)
    }
    return [pscustomobject]@{
        name = $Name
        browser_download_url = "https://example.invalid/$Name"
        digest = $Digest
    }
}

$script:CurrentVersion = '1.0.0'
$script:PackageKind = 'compiled'
$script:MockRelease = New-MockRelease 'v1.1.0' @(
    (New-MockAsset 'process-watchdog-1.1.0-windows-x64.zip'))
Invoke-Check
Assert-UpdateHelperTest ($script:CapturedCheckResult.Status -ceq 'available') `
    '编译版被缺少无关源码附件或独立校验文件的发行版错误阻断。'
Assert-UpdateHelperTest ($script:CapturedCheckResult.BinarySha256 -ceq
    ('A' * 64)) '检查阶段没有读取 GitHub 发行附件的 SHA-256 摘要。'

$script:MockRelease = New-MockRelease 'v1.1.0' @(
    (New-MockAsset 'process-watchdog-1.1.0-windows-x64.zip' 'unsupported'),
    (New-MockAsset 'SHA256SUMS.txt'))
Invoke-Check
Assert-UpdateHelperTest ($script:CapturedCheckResult.ChecksumsUrl -ceq
    'https://example.invalid/SHA256SUMS.txt') `
    '缺少 GitHub 摘要时没有保留旧版校验清单回退。'

$script:PackageKind = 'source'
$missingSourceRejected = $false
try { Invoke-Check } catch { $missingSourceRejected = $true }
Assert-UpdateHelperTest $missingSourceRejected `
    '普通源码版没有拒绝缺少源码包的可用更新。'

$script:PackageKind = 'source-git'
$script:MockRelease = New-MockRelease 'v1.1.0' @()
Invoke-Check
Assert-UpdateHelperTest ($script:CapturedCheckResult.Status -ceq 'available') `
    'Git 源码版被不需要的发行附件错误阻断。'

$script:PackageKind = 'compiled'
$script:CurrentVersion = '2.0.0'
$script:MockRelease = New-MockRelease 'v1.1.0' @()
Invoke-Check
Assert-UpdateHelperTest ($script:CapturedCheckResult.Status -ceq 'current') `
    '高于最新发行版的本地版本被错误要求安装附件。'

$invalidTagRejected = $false
$script:MockRelease = New-MockRelease 'vv2.1.0' @()
try { Invoke-Check } catch { $invalidTagRejected = $true }
Assert-UpdateHelperTest $invalidTagRejected `
    '含多个 v 前缀的非规范发行标签被错误接受。'

# 使用真实 ZIP、清单、哈希、替换与回滚操作验证普通源码版跨版本升级。网络下载
# 仅替换成临时文件复制，项目目录和用户配置都不会被触碰。
$testRoot = Join-Path $env:TEMP `
    ('ProcessWatchdogUpdateHelperTest-' + [Guid]::NewGuid().ToString('N'))
$packageRoot = Join-Path $testRoot 'package'
$installRoot = Join-Path $testRoot 'install'
$downloadRoot = Join-Path $testRoot 'downloads'
New-Item -ItemType Directory -Force -Path $packageRoot, $installRoot,
    $downloadRoot | Out-Null
try {
    $canonicalEntry = 'ProcessWatchdog.ahk'
    $customEntry = 'MyWatchdog.ahk'
    Set-Content -LiteralPath (Join-Path $installRoot $customEntry) `
        -Encoding UTF8 -Value '; old entry'
    Set-Content -LiteralPath (Join-Path $installRoot 'VERSION') `
        -Encoding UTF8 -Value '1.0.0'
    New-Item -ItemType Directory -Force `
        -Path (Join-Path $installRoot 'docs') | Out-Null
    Set-Content -LiteralPath (Join-Path $installRoot 'docs\legacy.txt') `
        -Encoding UTF8 -Value 'old documentation'
    Set-Content -LiteralPath (Join-Path $installRoot 'watchdog.ini') `
        -Encoding UTF8 -Value '[Settings]'
    Set-Content -LiteralPath (Join-Path $installRoot 'user-note.txt') `
        -Encoding UTF8 -Value 'preserve me'
    $oldManifest = [ordered]@{
        schemaVersion = 1
        packageKind = 'source'
        version = '1.0.0'
        entry = $canonicalEntry
        managedPaths = @($canonicalEntry, 'VERSION', 'docs',
            'update-manifest.json')
    }
    $oldManifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath `
        (Join-Path $installRoot 'update-manifest.json') -Encoding UTF8

    Set-Content -LiteralPath (Join-Path $packageRoot $canonicalEntry) `
        -Encoding UTF8 -Value '; new entry'
    Set-Content -LiteralPath (Join-Path $packageRoot 'VERSION') `
        -Encoding UTF8 -Value '2.0.0'
    New-Item -ItemType Directory -Force `
        -Path (Join-Path $packageRoot 'docs') | Out-Null
    Set-Content -LiteralPath (Join-Path $packageRoot 'docs\README.md') `
        -Encoding UTF8 -Value '# new documentation'
    $newManifest = [ordered]@{
        schemaVersion = 1
        packageKind = 'source'
        version = '2.0.0'
        entry = $canonicalEntry
        managedPaths = @($canonicalEntry, 'VERSION', 'docs\README.md',
            'update-manifest.json')
    }
    $newManifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath `
        (Join-Path $packageRoot 'update-manifest.json') -Encoding UTF8

    $packageName = 'process-watchdog-2.0.0-source.zip'
    $packagePath = Join-Path $downloadRoot $packageName
    Compress-Archive -Path (Join-Path $packageRoot '*') `
        -DestinationPath $packagePath
    $packageHash = (Get-FileHash -Algorithm SHA256 `
        -LiteralPath $packagePath).Hash
    $script:MockDownloads = @{
        "https://example.invalid/$packageName" = $packagePath
    }
    function Invoke-WebRequest {
        param(
            [switch]$UseBasicParsing,
            [string]$Uri,
            [string]$OutFile,
            [int]$TimeoutSec
        )
        Copy-Item -LiteralPath $script:MockDownloads[$Uri] `
            -Destination $OutFile
    }

    $script:PackageKind = 'source'
    $script:InstallRoot = $installRoot
    $script:EntryPath = Join-Path $installRoot $customEntry
    # 这里只需要一个真实存在的解释器替身来验证参数边界；当前宿主路径同时兼容
    # Windows PowerShell 的 powershell.exe 与 PowerShell 7 的 pwsh.exe。
    $script:InterpreterPath = (Get-Process -Id $PID).Path
    $script:CurrentVersion = '1.0.0'
    $script:Version = '2.0.0'
    $script:Tag = 'v2.0.0'
    $script:BinaryUrl = ''
    $script:SourceUrl = "https://example.invalid/$packageName"
    $script:BinarySha256 = ''
    $script:SourceSha256 = $packageHash
    $script:ChecksumsUrl = ''

    Assert-ApplyArguments
    $transaction = Install-ArchivePackage
    Assert-UpdateHelperTest ((Get-Content -LiteralPath `
            (Join-Path $installRoot $customEntry) -Raw -Encoding UTF8) `
            -match 'new entry') '自定义入口名称没有在升级后保留。'
    Assert-UpdateHelperTest ((Get-Content -LiteralPath `
            (Join-Path $installRoot 'VERSION') -Raw -Encoding UTF8).Trim() `
            -ceq '2.0.0') '升级后 VERSION 不正确。'
    Assert-UpdateHelperTest (-not (Test-Path -LiteralPath `
            (Join-Path $installRoot 'docs\legacy.txt'))) `
        '旧版已经移除的受管文件仍然残留。'
    Assert-UpdateHelperTest (Test-Path -LiteralPath `
            (Join-Path $installRoot 'docs\README.md')) `
        '新版改变管理粒度后的文件没有安装。'
    Assert-UpdateHelperTest (Test-Path -LiteralPath `
            (Join-Path $installRoot 'watchdog.ini')) `
        '个人配置在更新时被覆盖或删除。'
    Assert-UpdateHelperTest (Test-Path -LiteralPath `
            (Join-Path $installRoot 'user-note.txt')) `
        '不受清单管理的用户文件在更新时丢失。'

    try { throw 'simulated startup validation failure' } catch {
        $validationError = $_
    }

    # 正式新版可能在返回就绪信号前迁移两个配置。启动随后失败时，程序文件和
    # 个人状态必须作为同一个更新事务恢复，且恢复内容必须逐字节一致。
    $watchdogConfigPath = Join-Path $installRoot 'watchdog.ini'
    $maintenanceConfigPath = Join-Path $installRoot 'watchdog.maintenance.ini'
    Set-Content -LiteralPath $maintenanceConfigPath -Encoding Unicode `
        -Value "[Sessions]`r`nApp1=original"
    $originalWatchdogSignature = Get-FileByteSignature $watchdogConfigPath
    $originalMaintenanceSignature = `
        Get-FileByteSignature $maintenanceConfigPath
    $personalStateSnapshot = New-PersonalStateSnapshot
    Set-Content -LiteralPath $watchdogConfigPath -Encoding Unicode `
        -Value '[Settings] migrated=true'
    Set-Content -LiteralPath $maintenanceConfigPath -Encoding Unicode `
        -Value '[Sessions] migrated=true'
    Restore-PersonalStateSnapshot $personalStateSnapshot $validationError
    Assert-UpdateHelperTest (
        (Get-FileByteSignature $watchdogConfigPath) -ceq `
            $originalWatchdogSignature -and
        (Get-FileByteSignature $maintenanceConfigPath) -ceq `
            $originalMaintenanceSignature) `
        '启动失败后两个个人配置没有逐字节恢复。'
    Assert-UpdateHelperTest (-not (Test-Path -LiteralPath `
            $personalStateSnapshot.BackupRoot)) `
        '个人配置恢复成功后快照目录没有清理。'

    # 同时覆盖旧版没有维护配置、新版新建该文件，以及新版错误地把主配置路径
    # 变成目录的边界。恢复必须删除新增状态并重建原来的普通文件。
    Remove-Item -LiteralPath $maintenanceConfigPath -Force
    $personalStateSnapshot = New-PersonalStateSnapshot
    Remove-Item -LiteralPath $watchdogConfigPath -Force
    New-Item -ItemType Directory -Path $watchdogConfigPath | Out-Null
    Set-Content -LiteralPath (Join-Path $watchdogConfigPath 'unexpected.txt') `
        -Encoding UTF8 -Value 'new-version state'
    Set-Content -LiteralPath $maintenanceConfigPath -Encoding UTF8 `
        -Value '[Sessions] newly-created=true'
    Restore-PersonalStateSnapshot $personalStateSnapshot $validationError
    Assert-UpdateHelperTest (
        (Test-Path -LiteralPath $watchdogConfigPath -PathType Leaf) -and
        (Get-FileByteSignature $watchdogConfigPath) -ceq `
            $originalWatchdogSignature) `
        '个人配置路径类型变化后没有恢复为原文件。'
    Assert-UpdateHelperTest (-not (Test-Path -LiteralPath `
            $maintenanceConfigPath)) `
        '新版创建的个人配置在回滚后没有删除。'

    $personalStateSnapshot = New-PersonalStateSnapshot
    Assert-UpdateHelperTest (Test-Path -LiteralPath `
            $personalStateSnapshot.BackupRoot -PathType Container) `
        '个人配置快照目录没有创建。'
    Complete-PersonalStateSnapshot $personalStateSnapshot
    Assert-UpdateHelperTest (-not (Test-Path -LiteralPath `
            $personalStateSnapshot.BackupRoot)) `
        '更新成功后个人配置快照没有清理。'

    Restore-ArchiveTransaction $transaction $validationError
    Assert-UpdateHelperTest ((Get-Content -LiteralPath `
            (Join-Path $installRoot $customEntry) -Raw -Encoding UTF8) `
            -match 'old entry') '启动校验失败后旧入口没有恢复。'
    Assert-UpdateHelperTest (Test-Path -LiteralPath `
            (Join-Path $installRoot 'docs\legacy.txt')) `
        '启动校验失败后旧目录没有恢复。'
    Assert-UpdateHelperTest (-not (Test-Path -LiteralPath `
            (Join-Path $installRoot 'docs\README.md'))) `
        '启动校验失败后新版残留没有清理。'

    # 不只测试独立函数，还要经过 Invoke-Apply 的真实失败分支，证明程序事务先
    # 回滚、个人状态随后恢复，并且最终把原始启动错误返回给外层提示逻辑。
    $originalWaitForParentExit = ${function:Wait-ForParentExit}
    $originalTestUpdatedApplication = ${function:Test-UpdatedApplication}
    Set-Item -LiteralPath function:Wait-ForParentExit -Value { }
    Set-Item -LiteralPath function:Test-UpdatedApplication -Value {
        Set-Content -LiteralPath (Join-Path $script:InstallRoot `
            'watchdog.ini') -Encoding Unicode -Value '[Settings] migrated=true'
        Set-Content -LiteralPath (Join-Path $script:InstallRoot `
            'watchdog.maintenance.ini') -Encoding Unicode `
            -Value '[Sessions] newly-created=true'
        throw 'simulated full-start failure'
    }
    $integratedRollbackObserved = $false
    try {
        Invoke-Apply
    } catch {
        $integratedRollbackObserved = $_.Exception.Message -match
            'simulated full-start failure'
    } finally {
        Set-Item -LiteralPath function:Wait-ForParentExit `
            -Value $originalWaitForParentExit
        Set-Item -LiteralPath function:Test-UpdatedApplication `
            -Value $originalTestUpdatedApplication
    }
    Assert-UpdateHelperTest $integratedRollbackObserved `
        'Invoke-Apply 没有传播导致回滚的启动错误。'
    Assert-UpdateHelperTest ((Get-Content -LiteralPath `
            (Join-Path $installRoot $customEntry) -Raw -Encoding UTF8) `
            -match 'old entry') 'Invoke-Apply 失败后旧入口没有恢复。'
    Assert-UpdateHelperTest (
        (Get-FileByteSignature $watchdogConfigPath) -ceq `
            $originalWatchdogSignature -and
        -not (Test-Path -LiteralPath $maintenanceConfigPath)) `
        'Invoke-Apply 失败后个人状态没有恢复。'
    Assert-UpdateHelperTest (@(Get-ChildItem -LiteralPath $installRoot -Force |
            Where-Object { $_.Name -like '.process-watchdog-*-backup-*' }
        ).Count -eq 0) 'Invoke-Apply 成功回滚后仍残留事务备份。'

    $transaction = Install-ArchivePackage
    Complete-ArchiveTransaction $transaction
    Assert-UpdateHelperTest (-not (Test-Path -LiteralPath `
            $transaction.BackupRoot)) '成功更新后事务备份没有清理。'

    $script:CurrentVersion = '2.0.0'
    $downgradeRejected = $false
    try { Assert-ApplyArguments } catch { $downgradeRejected = $true }
    Assert-UpdateHelperTest $downgradeRejected `
        '安装参数允许重复安装或降级到非更高版本。'

    $readyPath = Join-Path $testRoot 'ready.signal'
    Set-Content -LiteralPath $readyPath -Encoding UTF8 -Value 'READY|2.0.0'
    $readyProcess = Start-Process -FilePath powershell.exe -ArgumentList `
        @('-NoLogo', '-NoProfile', '-Command', 'Start-Sleep -Seconds 10') `
        -WindowStyle Hidden -PassThru
    try {
        Wait-ForUpdatedApplicationReady $readyProcess $readyPath
        $readyProcess.Refresh()
        Assert-UpdateHelperTest (-not $readyProcess.HasExited) `
            '合法就绪信号返回后错误结束了新版进程。'
    } finally {
        try { $readyProcess.Kill() } catch {}
        try { [void]$readyProcess.WaitForExit(10000) } catch {}
        $readyProcess.Dispose()
    }

    Set-Content -LiteralPath $readyPath -Encoding UTF8 `
        -Value 'READY|9.9.9'
    $invalidReadyProcess = Start-Process -FilePath powershell.exe `
        -ArgumentList @('-NoLogo', '-NoProfile', '-Command',
            'Start-Sleep -Seconds 10') -WindowStyle Hidden -PassThru
    $invalidReadyRejected = $false
    try {
        Wait-ForUpdatedApplicationReady $invalidReadyProcess $readyPath
    } catch {
        $invalidReadyRejected = $true
    }
    try {
        $invalidReadyProcess.Refresh()
        Assert-UpdateHelperTest ($invalidReadyRejected -and
            $invalidReadyProcess.HasExited) `
            '版本不符的就绪信号没有被拒绝并结束新版进程。'
    } finally {
        try { $invalidReadyProcess.Kill() } catch {}
        $invalidReadyProcess.Dispose()
    }

    # 用可观测的 Git 命令替身覆盖 worktree、浅克隆、干净检查、快速前进和
    # 更新后提交不符时的 reset 回滚。真实 Git 命令本身由 CI 仓库操作验证，
    # 这里专门锁定更新助手的决策顺序和失败保护。
    $gitRoot = Join-Path $testRoot 'git-worktree'
    New-Item -ItemType Directory -Force -Path $gitRoot | Out-Null
    Set-Content -LiteralPath (Join-Path $gitRoot '.git') -Encoding ASCII `
        -Value 'gitdir: ..\repository\worktrees\test'
    Set-Content -LiteralPath (Join-Path $gitRoot $canonicalEntry) `
        -Encoding UTF8 -Value '; git entry'
    $oldCommit = '1' * 40
    $targetCommit = '2' * 40
    $wrongCommit = '3' * 40
    $script:GitTestRoot = $gitRoot
    $script:GitTestOldCommit = $oldCommit
    $script:GitTestTargetCommit = $targetCommit
    $script:GitTestWrongCommit = $wrongCommit
    $script:GitTestMerged = $false
    $script:GitTestDirty = $false
    $script:GitTestMismatch = $false
    $script:GitTestCalls = [System.Collections.Generic.List[string]]::new()
    $originalInvokeGit = ${function:Invoke-Git}
    Set-Item -LiteralPath function:Invoke-Git -Value {
        param([string[]]$Arguments, [switch]$AllowFailure)

        $command = $Arguments -join ' '
        $script:GitTestCalls.Add($command)
        $output = @()
        $exitCode = 0
        if ($command -match 'rev-parse --show-toplevel$') {
            $output = @($script:GitTestRoot)
        } elseif ($command -match 'ls-files --error-unmatch') {
            $output = @('ProcessWatchdog.ahk')
        } elseif ($command -match 'status --porcelain') {
            if ($script:GitTestDirty) {
                $output = @(' M app\changed.ahk')
            }
        } elseif ($command -match 'rev-parse --is-shallow-repository$') {
            $output = @('true')
        } elseif ($command -match 'merge --ff-only') {
            $script:GitTestMerged = $true
        } elseif ($command -match 'reset --hard') {
            $script:GitTestMerged = $false
        } elseif ($command -match 'rev-parse v2\.0\.0\^\{commit\}$') {
            $output = @($script:GitTestTargetCommit)
        } elseif ($command -match 'rev-parse HEAD$') {
            $output = if (-not $script:GitTestMerged) {
                @($script:GitTestOldCommit)
            } elseif ($script:GitTestMismatch) {
                @($script:GitTestWrongCommit)
            } else {
                @($script:GitTestTargetCommit)
            }
        }
        return [pscustomobject]@{ ExitCode = $exitCode; Output = @($output) }
    }
    try {
        $script:InstallRoot = $gitRoot
        $script:EntryPath = Join-Path $gitRoot $canonicalEntry
        $script:PackageKind = 'source-git'
        $script:Tag = 'v2.0.0'
        $gitTransaction = Invoke-GitSourceUpdate
        Assert-UpdateHelperTest ($gitTransaction.PreviousCommit -ceq `
                $oldCommit -and $script:GitTestMerged) `
            'Git 源码没有快速前进到目标提交。'
        Assert-UpdateHelperTest (($script:GitTestCalls -join "`n") -match
                'fetch --no-tags --unshallow') `
            '浅克隆更新没有先补齐历史。'

        $script:GitTestDirty = $true
        $script:GitTestMerged = $false
        $callCountBeforeDirty = $script:GitTestCalls.Count
        $dirtyRejected = $false
        try { Invoke-GitSourceUpdate } catch { $dirtyRejected = $true }
        $dirtyCalls = @($script:GitTestCalls)[$callCountBeforeDirty..
            ($script:GitTestCalls.Count - 1)] -join "`n"
        Assert-UpdateHelperTest ($dirtyRejected -and
                $dirtyCalls -notmatch ' fetch ') `
            '有受跟踪修改的 Git 源码仍然开始了网络更新。'

        $script:GitTestDirty = $false
        $script:GitTestMismatch = $true
        $script:GitTestMerged = $false
        $callCountBeforeMismatch = $script:GitTestCalls.Count
        $mismatchRejected = $false
        try { Invoke-GitSourceUpdate } catch { $mismatchRejected = $true }
        $mismatchCalls = @($script:GitTestCalls)[$callCountBeforeMismatch..
            ($script:GitTestCalls.Count - 1)] -join "`n"
        Assert-UpdateHelperTest ($mismatchRejected -and
                $mismatchCalls -match 'reset --hard' -and
                -not $script:GitTestMerged) `
            'Git 更新后的提交不符时没有恢复原提交。'
    } finally {
        Set-Item -LiteralPath function:Invoke-Git -Value $originalInvokeGit
    }
} finally {
    $fullTestRoot = [System.IO.Path]::GetFullPath($testRoot)
    $tempPrefix = [System.IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
    if ($fullTestRoot.StartsWith($tempPrefix,
            [System.StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $fullTestRoot) -like
            'ProcessWatchdogUpdateHelperTest-*') {
        Remove-Item -LiteralPath $fullTestRoot -Recurse -Force `
            -ErrorAction SilentlyContinue
    }
}

Write-Host 'Application update helper tests passed.'
