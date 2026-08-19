# 小助手自身更新的后台助手。
# 检查模式只写入原子结果文件；应用模式等待主进程完整退出后再替换受管文件并重启。
# 个人配置从不进入更新清单，因此 EXE 与源码更新都不会覆盖用户状态。

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Check', 'Apply')]
    [string]$Mode,
    [string]$Repository = 'realSilasYang/process-watchdog',
    [string]$CurrentVersion = '',
    [string]$ResultPath = '',
    [ValidateSet('', 'compiled', 'source', 'source-git')]
    [string]$PackageKind = '',
    [ValidateSet('zh-CN', 'zh-HK', 'zh-TW', 'en-US', 'ja-JP', 'vi-VN',
        'ko-KR', 'es-ES', 'fr-FR', 'pt-BR', 'ru-RU', 'de-DE', 'it-IT')]
    [string]$UiLanguage = 'zh-CN',
    [string]$LocalizationPath = '',
    [int]$ParentPid = 0,
    [string]$InstallRoot = '',
    [string]$EntryPath = '',
    [string]$InterpreterPath = '',
    [string]$Version = '',
    [string]$Tag = '',
    [string]$BinaryUrl = '',
    [string]$SourceUrl = '',
    [string]$BinarySha256 = '',
    [string]$SourceSha256 = '',
    [string]$ChecksumsUrl = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Windows PowerShell 5.1 可能仍继承旧版 .NET 的 TLS 默认值；显式加入 TLS 1.2，
# 避免同一更新在不同 Windows 补丁级别上出现 GitHub 握手结果不一致。
[System.Net.ServicePointManager]::SecurityProtocol =
    [System.Net.ServicePointManager]::SecurityProtocol -bor
    [System.Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Net.Http

if (-not $LocalizationPath) {
    $LocalizationPath = Join-Path $PSScriptRoot 'application-update.strings.json'
}
function Import-UpdateTextCatalog {
    param([string]$Language, [string]$Path)

    if ($Language -eq 'zh-CN' -or
        -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    try {
        $localizationData = Get-Content -LiteralPath $Path -Raw `
            -Encoding UTF8 | ConvertFrom-Json
        if ($localizationData.schemaVersion -ne 1 -or
            -not $localizationData.languages) {
            return $null
        }
        $languageProperty = $localizationData.languages.PSObject.Properties[
            $Language]
        return $(if ($null -ne $languageProperty) {
            $languageProperty.Value
        } else {
            $null
        })
    } catch {
        # 独立更新助手仍可使用英文报告错误；正式构建会验证多语言资源完整存在。
        return $null
    }
}
$script:UpdateTextCatalog = Import-UpdateTextCatalog $UiLanguage `
    $LocalizationPath

function Get-UpdateText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Chinese,
        [Parameter(Mandatory = $true)]
        [string]$English,
        [object[]]$Arguments = @()
    )

    if ($UiLanguage -eq 'zh-CN') {
        $template = $Chinese
    } elseif ($UiLanguage -eq 'en-US' -or
        $null -eq $script:UpdateTextCatalog) {
        $template = $English
    } else {
        $translationProperty = $script:UpdateTextCatalog.PSObject.Properties[
            $Chinese]
        $template = if ($null -ne $translationProperty) {
            [string]$translationProperty.Value
        } else {
            $English
        }
    }
    if ($Arguments.Count -gt 0) {
        # 显式选择 IFormatProvider + object[] 重载；PowerShell 5.1 否则可能把整个
        # 数组当作单个参数，遇到 {1}、{2} 时反而抛出格式化异常。
        return [string]::Format(
            [System.Globalization.CultureInfo]::InvariantCulture,
            $template, [object[]]$Arguments)
    }
    return $template
}

function ConvertTo-SingleLine {
    param([object]$Value)

    return ([string]$Value).Replace("`r", ' ').Replace("`n", ' ').Trim()
}

function Write-CheckResult {
    param([hashtable]$Values)

    if (-not $ResultPath) {
        throw (Get-UpdateText '检查更新缺少结果文件路径。' `
            'Check mode requires ResultPath.')
    }
    $fullResultPath = [System.IO.Path]::GetFullPath($ResultPath)
    $parent = Split-Path -Parent $fullResultPath
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    $temporaryPath = "$fullResultPath.tmp.$PID"
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('[Update]')
    foreach ($key in @('Status', 'CurrentVersion', 'Version', 'Tag',
            'ReleaseUrl', 'BinaryUrl', 'SourceUrl', 'BinarySha256',
            'SourceSha256', 'ChecksumsUrl', 'Error')) {
        $value = if ($Values.ContainsKey($key)) { $Values[$key] } else { '' }
        $lines.Add("$key=$(ConvertTo-SingleLine $value)")
    }
    [System.IO.File]::WriteAllLines($temporaryPath, $lines,
        [System.Text.Encoding]::Unicode)
    Move-Item -LiteralPath $temporaryPath -Destination $fullResultPath -Force
}

function Test-RetryableNetworkException {
    param([System.Exception]$Exception)

    if ($null -eq $Exception) {
        return $false
    }
    if ($Exception.Data.Contains('Retryable')) {
        return [bool]$Exception.Data['Retryable']
    }
    if ($Exception -is [System.Net.WebException]) {
        if ($Exception.Status -eq
            [System.Net.WebExceptionStatus]::ProtocolError -and
            $null -ne $Exception.Response) {
            $statusCode = [int]$Exception.Response.StatusCode
            return $statusCode -in @(408, 425, 429, 500, 502, 503, 504)
        }
        return $Exception.Status -in @(
            [System.Net.WebExceptionStatus]::ConnectFailure,
            [System.Net.WebExceptionStatus]::ConnectionClosed,
            [System.Net.WebExceptionStatus]::KeepAliveFailure,
            [System.Net.WebExceptionStatus]::NameResolutionFailure,
            [System.Net.WebExceptionStatus]::PipelineFailure,
            [System.Net.WebExceptionStatus]::ProxyNameResolutionFailure,
            [System.Net.WebExceptionStatus]::ReceiveFailure,
            [System.Net.WebExceptionStatus]::RequestCanceled,
            [System.Net.WebExceptionStatus]::SendFailure,
            [System.Net.WebExceptionStatus]::Timeout)
    }
    if ($Exception -is [System.Net.Http.HttpRequestException] -or
        $Exception -is [System.IO.IOException] -or
        $Exception -is [System.Threading.Tasks.TaskCanceledException] -or
        $Exception -is [System.TimeoutException]) {
        return $true
    }
    return Test-RetryableNetworkException $Exception.InnerException
}

function Get-NetworkRetryDelayMilliseconds {
    param([int]$FailedAttempt)

    $exponent = [Math]::Max(0, [Math]::Min(4, $FailedAttempt - 1))
    return [int][Math]::Min(8000, 500 * [Math]::Pow(2, $exponent))
}

function Invoke-WithRetry {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Operation,
        [string]$OperationName = 'network operation',
        [ValidateRange(1, 10)]
        [int]$MaximumAttempts = 4,
        [scriptblock]$DelayAction = {
            param([int]$Milliseconds)
            Start-Sleep -Milliseconds $Milliseconds
        }
    )

    for ($attempt = 1; $attempt -le $MaximumAttempts; $attempt++) {
        try {
            return & $Operation
        } catch {
            if ($attempt -ge $MaximumAttempts -or
                -not (Test-RetryableNetworkException $_.Exception)) {
                throw
            }
            & $DelayAction (Get-NetworkRetryDelayMilliseconds $attempt)
        }
    }
    throw "Unreachable retry state: $OperationName"
}

function Invoke-GitHubApi {
    param([string]$Uri)

    $headers = @{
        Accept = 'application/vnd.github+json'
        'User-Agent' = 'process-watchdog-updater'
        'X-GitHub-Api-Version' = '2022-11-28'
    }
    return Invoke-WithRetry -OperationName 'GitHub API' -MaximumAttempts 4 `
        -Operation {
            Invoke-RestMethod -UseBasicParsing -Headers $headers -Uri $Uri `
                -TimeoutSec 30
        }
}

function Invoke-HttpDownloadAttempt {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [Parameter(Mandatory = $true)]
        [string]$PartialPath,
        [ValidateRange(1, 3600)]
        [int]$TimeoutSeconds = 300
    )

    Add-Type -AssemblyName System.Net.Http
    $existingLength = if (Test-Path -LiteralPath $PartialPath -PathType Leaf) {
        (Get-Item -LiteralPath $PartialPath).Length
    } else { 0 }
    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.AllowAutoRedirect = $true
    $client = [System.Net.Http.HttpClient]::new($handler)
    $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSeconds)
    $request = [System.Net.Http.HttpRequestMessage]::new(
        [System.Net.Http.HttpMethod]::Get, $Uri)
    [void]$request.Headers.UserAgent.ParseAdd('process-watchdog-updater')
    if ($existingLength -gt 0) {
        $request.Headers.Range =
            [System.Net.Http.Headers.RangeHeaderValue]::new(
                [long]$existingLength, $null)
    }
    $response = $null
    $networkStream = $null
    $fileStream = $null
    try {
        $responseTask = $client.SendAsync($request,
            [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead)
        $response = $responseTask.GetAwaiter().GetResult()
        $statusCode = [int]$response.StatusCode
        if ($statusCode -notin @(200, 206)) {
            $statusError = [System.Net.Http.HttpRequestException]::new(
                "HTTP $statusCode while downloading $Uri")
            $rangeCannotResume = $statusCode -eq 416 -and $existingLength -gt 0
            $statusError.Data['Retryable'] = $rangeCannotResume -or `
                $statusCode -in @(408, 425, 429, 500, 502, 503, 504)
            $statusError.Data['ResetPartial'] = $rangeCannotResume
            throw $statusError
        }
        $append = $existingLength -gt 0 -and $statusCode -eq 206
        $fileMode = if ($append) {
            [System.IO.FileMode]::Append
        } else {
            # 服务端忽略 Range 并返回 200 时必须从头覆盖，不能把完整响应
            # 追加到旧片段后面形成一个哈希必然错误的文件。
            [System.IO.FileMode]::Create
        }
        $networkStreamTask = $response.Content.ReadAsStreamAsync()
        $networkStream = $networkStreamTask.GetAwaiter().GetResult()
        $fileStream = [System.IO.File]::Open($PartialPath, $fileMode,
            [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        $networkStream.CopyToAsync($fileStream).GetAwaiter().GetResult()
        $fileStream.Flush($true)
    } finally {
        if ($fileStream) { $fileStream.Dispose() }
        if ($networkStream) { $networkStream.Dispose() }
        if ($response) { $response.Dispose() }
        $request.Dispose()
        $client.Dispose()
        $handler.Dispose()
    }
}

function Invoke-ResilientDownload {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,
        [string]$ExpectedSha256 = '',
        [ValidateRange(1, 10)]
        [int]$MaximumAttempts = 4,
        [ValidateRange(1, 3600)]
        [int]$TimeoutSeconds = 300,
        [scriptblock]$DelayAction = {
            param([int]$Milliseconds)
            Start-Sleep -Milliseconds $Milliseconds
        }
    )

    $fullDestinationPath = [System.IO.Path]::GetFullPath($DestinationPath)
    $partialPath = $fullDestinationPath + '.partial'
    $destinationParent = Split-Path -Parent $fullDestinationPath
    New-Item -ItemType Directory -Force -Path $destinationParent | Out-Null
    if ($ExpectedSha256 -and $ExpectedSha256 -notmatch '^[0-9A-Fa-f]{64}$') {
        throw (Get-UpdateText '更新包 SHA-256 校验失败：{0}' `
            'Update package hash mismatch: {0}' @($ExpectedSha256))
    }
    $normalizedExpectedHash = $ExpectedSha256.ToUpperInvariant()
    $hashFailures = 0
    for ($attempt = 1; $attempt -le $MaximumAttempts; $attempt++) {
        try {
            if ($normalizedExpectedHash -and
                (Test-Path -LiteralPath $partialPath -PathType Leaf) -and
                (Get-FileHash -Algorithm SHA256 -LiteralPath $partialPath).Hash `
                    -ceq $normalizedExpectedHash) {
                # 上一进程可能在完整下载后、正式改名之前退出；直接复用已校验片段。
            } else {
                Invoke-HttpDownloadAttempt -Uri $Uri -PartialPath $partialPath `
                    -TimeoutSeconds $TimeoutSeconds
            }
            if ($normalizedExpectedHash) {
                $actualHash = (Get-FileHash -Algorithm SHA256 `
                    -LiteralPath $partialPath).Hash
                if ($actualHash -cne $normalizedExpectedHash) {
                    $hashFailures++
                    Remove-Item -LiteralPath $partialPath -Force `
                        -ErrorAction SilentlyContinue
                    if ($hashFailures -ge 2 -or
                        $attempt -ge $MaximumAttempts) {
                        throw (Get-UpdateText '更新包 SHA-256 校验失败：{0}' `
                            'Update package hash mismatch: {0}' @($actualHash))
                    }
                    & $DelayAction `
                        (Get-NetworkRetryDelayMilliseconds $attempt)
                    continue
                }
            }
            if (Test-Path -LiteralPath $fullDestinationPath) {
                Remove-Item -LiteralPath $fullDestinationPath -Force
            }
            Move-Item -LiteralPath $partialPath `
                -Destination $fullDestinationPath
            return $fullDestinationPath
        } catch {
            if ($_.Exception.Data.Contains('ResetPartial') -and
                [bool]$_.Exception.Data['ResetPartial']) {
                Remove-Item -LiteralPath $partialPath -Force `
                    -ErrorAction SilentlyContinue
            }
            if ($attempt -ge $MaximumAttempts -or
                -not (Test-RetryableNetworkException $_.Exception)) {
                throw
            }
            & $DelayAction (Get-NetworkRetryDelayMilliseconds $attempt)
        }
    }
}

function Get-UniqueReleaseAsset {
    param(
        [object]$Release,
        [string]$ExpectedName,
        [switch]$Optional
    )

    $matches = @($Release.assets | Where-Object {
        [string]$_.name -ceq $ExpectedName
    })
    if ($matches.Count -eq 0 -and $Optional) {
        return $null
    }
    if ($matches.Count -ne 1) {
        throw (Get-UpdateText `
            '发行附件 {0} 的匹配数量为 {1}，应当恰好为 1。' `
            'Release asset {0} has {1} matches.' `
            @($ExpectedName, $matches.Count))
    }
    return $matches[0]
}

function Get-ReleaseAssetUrl {
    param([object]$Asset)

    if ($null -eq $Asset) {
        return ''
    }
    return [string]$Asset.browser_download_url
}

function Get-ReleaseAssetSha256 {
    param([object]$Asset)

    if ($null -eq $Asset) {
        return ''
    }
    $digestProperty = $Asset.PSObject.Properties['digest']
    if ($null -eq $digestProperty -or
        [string]$digestProperty.Value -notmatch '^sha256:([0-9A-Fa-f]{64})$') {
        return ''
    }
    return $Matches[1].ToUpperInvariant()
}

function Invoke-Check {
    if (-not (Test-CanonicalVersion $CurrentVersion)) {
        throw (Get-UpdateText '当前小助手版本无效：{0}' `
            'Current application version is invalid: {0}' @($CurrentVersion))
    }
    $release = Invoke-GitHubApi `
        "https://api.github.com/repos/$Repository/releases/latest"
    if ($release.draft -or $release.prerelease) {
        throw (Get-UpdateText `
            'GitHub 返回的最新稳定版本是草稿或预发布版本。' `
            'GitHub returned a draft or prerelease as the latest stable release.')
    }
    $releaseTag = [string]$release.tag_name
    $latestVersion = if ($releaseTag.StartsWith('v')) {
        $releaseTag.Substring(1)
    } else { '' }
    if ($releaseTag -cne "v$latestVersion" -or
        -not (Test-CanonicalVersion $latestVersion)) {
        throw (Get-UpdateText '最新发行标签无效：{0}' `
            'Latest release tag is invalid: {0}' @($release.tag_name))
    }
    $current = [Version]$CurrentVersion
    $latest = [Version]$latestVersion
    $status = if ($latest -gt $current) { 'available' } else { 'current' }
    $binaryName = "process-watchdog-$latestVersion-windows-x64.zip"
    $sourceName = "process-watchdog-$latestVersion-source.zip"
    $binaryAsset = Get-UniqueReleaseAsset $release $binaryName -Optional
    $sourceAsset = Get-UniqueReleaseAsset $release $sourceName -Optional
    $checksumsAsset = Get-UniqueReleaseAsset $release 'SHA256SUMS.txt' -Optional
    $values = @{
        Status = $status
        CurrentVersion = $CurrentVersion
        Version = $latestVersion
        Tag = [string]$release.tag_name
        ReleaseUrl = [string]$release.html_url
        BinaryUrl = Get-ReleaseAssetUrl $binaryAsset
        SourceUrl = Get-ReleaseAssetUrl $sourceAsset
        BinarySha256 = Get-ReleaseAssetSha256 $binaryAsset
        SourceSha256 = Get-ReleaseAssetSha256 $sourceAsset
        ChecksumsUrl = Get-ReleaseAssetUrl $checksumsAsset
        Error = ''
    }
    $missingRequiredAsset = $status -eq 'available' -and (
        ($PackageKind -eq 'compiled' -and (-not $values.BinaryUrl -or
            (-not $values.BinarySha256 -and -not $values.ChecksumsUrl))) -or
        ($PackageKind -eq 'source' -and (-not $values.SourceUrl -or
            (-not $values.SourceSha256 -and -not $values.ChecksumsUrl))) -or
        ($PackageKind -eq '' -and
            (-not $values.BinaryUrl -or -not $values.SourceUrl -or
             (-not $values.BinarySha256 -and -not $values.ChecksumsUrl) -or
             (-not $values.SourceSha256 -and -not $values.ChecksumsUrl))))
    if ($missingRequiredAsset) {
        throw (Get-UpdateText '最新版本缺少一个或多个自动更新附件。' `
            'The latest release is missing one or more automatic-update assets.')
    }
    Write-CheckResult $values
}

function Test-CanonicalVersion {
    param([string]$Value)

    return $Value -cmatch `
        '^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$'
}

function Wait-ForParentExit {
    if ($ParentPid -le 0) {
        throw (Get-UpdateText '安装更新需要有效的主进程 ID。' `
            'Apply mode requires a valid parent process ID.')
    }
    try {
        $parent = Get-Process -Id $ParentPid -ErrorAction Stop
        if (-not $parent.WaitForExit(120000)) {
            throw (Get-UpdateText '小助手未能在 120 秒内退出，更新已取消。' `
                'The running application did not exit within 120 seconds.')
        }
    } catch [Microsoft.PowerShell.Commands.ProcessCommandException] {
        # 主进程可能已经在更新助手启动和查询之间退出，这属于正常交接。
    }
}

function Invoke-Git {
    param([string[]]$Arguments, [switch]$AllowFailure)

    $output = & git @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0 -and -not $AllowFailure) {
        throw (Get-UpdateText 'Git 命令执行失败：git {0}；{1}' `
            'Git command failed: git {0}; {1}' `
            @(($Arguments -join ' '), ($output -join ' ')))
    }
    return [pscustomobject]@{ ExitCode = $exitCode; Output = @($output) }
}

function Invoke-GitSourceUpdate {
    $root = [System.IO.Path]::GetFullPath($InstallRoot)
    if (-not (Test-Path -LiteralPath (Join-Path $root '.git'))) {
        throw (Get-UpdateText 'Git 源码更新要求安装目录是仓库根目录。' `
            'Source Git update requires a repository root.')
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw (Get-UpdateText '系统 PATH 中找不到 Git。' `
            'Git is not available on PATH.')
    }
    $repositoryRoot = Invoke-Git @('-C', $root, 'rev-parse',
        '--show-toplevel')
    $resolvedRepositoryRoot = [System.IO.Path]::GetFullPath(
        [string]$repositoryRoot.Output[0])
    if ($resolvedRepositoryRoot.TrimEnd('\') -ne $root.TrimEnd('\')) {
        throw (Get-UpdateText '安装目录不是当前 Git 工作区的根目录。' `
            'The installation directory is not the current Git worktree root.')
    }
    $entryRelativePath = Split-Path -Leaf `
        ([System.IO.Path]::GetFullPath($EntryPath))
    $trackedEntry = Invoke-Git @('-C', $root, 'ls-files',
        '--error-unmatch', '--', $entryRelativePath) -AllowFailure
    if ($trackedEntry.ExitCode -ne 0) {
        throw (Get-UpdateText `
            '当前启动脚本不受 Git 跟踪，无法确认更新后重启的是新版本。请改用仓库中的正式入口脚本，或下载源码发行包更新。' `
            'The running script is not tracked by Git, so the updater cannot guarantee that the restarted entry is current. Run the repository entry script or update from a source release package.')
    }
    $dirty = Invoke-Git @('-C', $root, 'status', '--porcelain',
        '--untracked-files=no')
    if ($dirty.Output.Count -gt 0) {
        throw (Get-UpdateText '受 Git 跟踪的源码含有本地修改，自动更新已取消。' `
            'Tracked source files contain local changes; automatic update was cancelled.')
    }
    $previousCommitResult = Invoke-Git @('-C', $root, 'rev-parse', 'HEAD')
    $previousCommit = ([string]$previousCommitResult.Output[0]).Trim()
    if ($previousCommit -notmatch '^(?:[0-9A-Fa-f]{40}|[0-9A-Fa-f]{64})$') {
        throw (Get-UpdateText 'Git 命令执行失败：git {0}；{1}' `
            'Git command failed: git {0}; {1}' `
            @('rev-parse HEAD', 'invalid commit identifier'))
    }
    $officialRepository = "https://github.com/$Repository.git"
    $shallowResult = Invoke-Git @('-C', $root, 'rev-parse',
        '--is-shallow-repository')
    $fetchArguments = [System.Collections.Generic.List[string]]::new()
    foreach ($fetchArgument in @('-C', $root, 'fetch', '--no-tags')) {
        $fetchArguments.Add($fetchArgument)
    }
    if (([string]$shallowResult.Output[0]).Trim() -ceq 'true') {
        $fetchArguments.Add('--unshallow')
    }
    $fetchArguments.Add($officialRepository)
    $fetchArguments.Add("refs/tags/$Tag`:refs/tags/$Tag")
    Invoke-Git @($fetchArguments) | Out-Null
    $ancestor = Invoke-Git @('-C', $root, 'merge-base', '--is-ancestor',
        'HEAD', $Tag) -AllowFailure
    if ($ancestor.ExitCode -ne 0) {
        throw (Get-UpdateText '当前源码提交无法快速前进到正式发行标签。' `
            'The current source commit cannot be fast-forwarded to the release tag.')
    }
    try {
        Invoke-Git @('-C', $root, 'merge', '--ff-only', '--no-verify', $Tag) |
            Out-Null
        $updatedCommit = Invoke-Git @('-C', $root, 'rev-parse', 'HEAD')
        $targetCommit = Invoke-Git @('-C', $root, 'rev-parse', "$Tag^{commit}")
        if (([string]$updatedCommit.Output[0]).Trim() -cne
            ([string]$targetCommit.Output[0]).Trim()) {
            throw (Get-UpdateText '当前源码提交无法快速前进到正式发行标签。' `
                'The current source commit cannot be fast-forwarded to the release tag.')
        }
    } catch {
        $mergeError = $_
        Invoke-Git @('-C', $root, 'reset', '--hard', $previousCommit) |
            Out-Null
        throw $mergeError
    }
    return [pscustomobject]@{
        Root = $root
        PreviousCommit = $previousCommit
    }
}

function Get-ExpectedChecksum {
    param(
        [string]$ChecksumsPath,
        [string]$FileName
    )

    $escapedName = [regex]::Escape($FileName)
    # -f 会把正则量词也视为格式占位符，双写花括号后再插入文件名。
    $checksumPattern = '^([0-9A-Fa-f]{{64}})  {0}$' -f $escapedName
    foreach ($line in Get-Content -LiteralPath $ChecksumsPath -Encoding ASCII) {
        if ($line -match $checksumPattern) {
            return $Matches[1].ToUpperInvariant()
        }
    }
    throw (Get-UpdateText 'SHA256SUMS.txt 中找不到 {0}。' `
        'SHA256SUMS.txt does not contain {0}.' @($FileName))
}

function Assert-ManagedRelativePath {
    param([string]$RelativePath)

    if ([string]::IsNullOrWhiteSpace($RelativePath) -or
        [System.IO.Path]::IsPathRooted($RelativePath) -or
        $RelativePath -match '(^|[\\/])\.\.([\\/]|$)') {
        throw (Get-UpdateText '更新清单包含不安全路径：{0}' `
            'Unsafe update path: {0}' @($RelativePath))
    }
    if ($RelativePath -eq 'watchdog.ini') {
        throw (Get-UpdateText '更新清单试图覆盖个人配置：{0}' `
            'Update manifest attempted to manage personal state: {0}' `
            @($RelativePath))
    }
}

function Resolve-PathUnderRoot {
    param(
        [string]$Root,
        [string]$RelativePath
    )

    Assert-ManagedRelativePath $RelativePath
    $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $Root $RelativePath))
    if (-not $fullPath.StartsWith($fullRoot,
            [System.StringComparison]::OrdinalIgnoreCase)) {
        throw (Get-UpdateText '更新路径超出允许目录：{0}' `
            'Update path escapes the allowed directory: {0}' @($RelativePath))
    }
    return $fullPath
}

function Assert-NoOverlappingPaths {
    param([string[]]$RelativePaths)

    $normalized = @($RelativePaths | ForEach-Object {
        ([string]$_).Replace('/', '\').TrimEnd('\')
    } | Sort-Object { $_.Length })
    for ($index = 0; $index -lt $normalized.Count; $index++) {
        for ($otherIndex = $index + 1;
            $otherIndex -lt $normalized.Count; $otherIndex++) {
            if ($normalized[$otherIndex].StartsWith(
                    $normalized[$index] + '\',
                    [System.StringComparison]::OrdinalIgnoreCase)) {
                throw (Get-UpdateText '更新清单包含重叠路径：{0} 与 {1}' `
                    'Update manifest contains overlapping paths: {0} and {1}' `
                    @($normalized[$index], $normalized[$otherIndex]))
            }
        }
    }
}

function Get-MinimalManagedPaths {
    param([string[]]$RelativePaths)

    $ordered = @($RelativePaths | ForEach-Object {
        ([string]$_).Replace('/', '\').TrimEnd('\')
    } | Sort-Object @{ Expression = { $_.Length } },
        @{ Expression = { $_ } })
    $result = [System.Collections.Generic.List[string]]::new()
    foreach ($candidate in $ordered) {
        $covered = $false
        foreach ($parent in $result) {
            if ($candidate -ieq $parent -or $candidate.StartsWith(
                    $parent + '\',
                    [System.StringComparison]::OrdinalIgnoreCase)) {
                $covered = $true
                break
            }
        }
        if (-not $covered) {
            $result.Add($candidate)
        }
    }
    return @($result)
}

function Restore-ArchiveTransaction {
    param(
        [object]$Transaction,
        [object]$OriginalError
    )

    $rollbackErrors = [System.Collections.Generic.List[string]]::new()
    $installedReverse = @($Transaction.Installed)
    [array]::Reverse($installedReverse)
    foreach ($relativePath in $installedReverse) {
        try {
            $destination = Resolve-PathUnderRoot $Transaction.Root $relativePath
            if (Test-Path -LiteralPath $destination) {
                Remove-Item -LiteralPath $destination -Recurse -Force
            }
        } catch {
            $rollbackErrors.Add($_.Exception.Message)
        }
    }
    $backedUpReverse = @($Transaction.BackedUp)
    [array]::Reverse($backedUpReverse)
    foreach ($relativePath in $backedUpReverse) {
        try {
            $backup = Resolve-PathUnderRoot $Transaction.BackupRoot $relativePath
            $destination = Resolve-PathUnderRoot $Transaction.Root $relativePath
            if (Test-Path -LiteralPath $destination) {
                Remove-Item -LiteralPath $destination -Recurse -Force
            }
            New-Item -ItemType Directory -Force `
                -Path (Split-Path -Parent $destination) | Out-Null
            Move-Item -LiteralPath $backup -Destination $destination
        } catch {
            $rollbackErrors.Add($_.Exception.Message)
        }
    }
    if ($rollbackErrors.Count -gt 0) {
        throw (Get-UpdateText `
            '更新替换失败，且自动回滚未完全成功。备份保留在：{0}。原始错误：{1}；回滚错误：{2}' `
            'Update replacement failed and automatic rollback was incomplete. The backup remains at: {0}. Original error: {1}; rollback error: {2}' `
            @($Transaction.BackupRoot, $OriginalError.Exception.Message,
                ($rollbackErrors -join '；')))
    }
    if (Test-Path -LiteralPath $Transaction.BackupRoot) {
        Remove-Item -LiteralPath $Transaction.BackupRoot -Recurse -Force
    }
}

function Complete-ArchiveTransaction {
    param([object]$Transaction)

    # 新版本已经通过启动校验并成功创建正式进程后，备份只剩清理用途。清理失败
    # 不得反向拆除一个已经启动的新版本；残留目录可由用户或后续维护删除。
    if ($Transaction -and
        (Test-Path -LiteralPath $Transaction.BackupRoot)) {
        Remove-Item -LiteralPath $Transaction.BackupRoot -Recurse -Force `
            -ErrorAction SilentlyContinue
    }
}

function New-PersonalStateSnapshot {
    $root = [System.IO.Path]::GetFullPath($InstallRoot)
    $backupRoot = Join-Path $root `
        ('.process-watchdog-state-backup-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
    $items = [System.Collections.Generic.List[object]]::new()
    try {
        foreach ($name in @('watchdog.ini')) {
            $source = Join-Path $root $name
            $existed = Test-Path -LiteralPath $source -PathType Leaf
            if ($existed) {
                $backup = Join-Path $backupRoot $name
                Copy-Item -LiteralPath $source -Destination $backup
                $sha256 = (Get-FileHash -Algorithm SHA256 `
                    -LiteralPath $backup).Hash
            } else {
                $sha256 = ''
            }
            $items.Add([pscustomobject]@{
                Name = $name
                Existed = $existed
                Sha256 = $sha256
            })
        }
        return [pscustomobject]@{
            Root = $root
            BackupRoot = $backupRoot
            Items = $items
        }
    } catch {
        Remove-Item -LiteralPath $backupRoot -Recurse -Force `
            -ErrorAction SilentlyContinue
        throw
    }
}

function Restore-PersonalStateSnapshot {
    param(
        [object]$Snapshot,
        [object]$OriginalError
    )

    $restoreErrors = [System.Collections.Generic.List[string]]::new()
    foreach ($item in $Snapshot.Items) {
        try {
            $destination = Join-Path $Snapshot.Root $item.Name
            $backup = Join-Path $Snapshot.BackupRoot $item.Name
            if ($item.Existed) {
                if (-not (Test-Path -LiteralPath $backup -PathType Leaf) -or
                    (Get-FileHash -Algorithm SHA256 -LiteralPath $backup).Hash `
                        -ne $item.Sha256) {
                    throw (Get-UpdateText '个人配置备份校验失败：{0}' `
                        'Personal-state backup verification failed: {0}' `
                        @($item.Name))
                }
            }
            # 新版可能在同名位置留下文件、目录或其它对象；先完整移除，再恢复
            # 快照，避免 Copy-Item 把配置文件错误复制进同名目录。
            if (Test-Path -LiteralPath $destination) {
                Remove-Item -LiteralPath $destination -Recurse -Force
            }
            if ($item.Existed) {
                Copy-Item -LiteralPath $backup -Destination $destination
                if ((Get-FileHash -Algorithm SHA256 `
                            -LiteralPath $destination).Hash -ne $item.Sha256) {
                    throw (Get-UpdateText '个人配置恢复校验失败：{0}' `
                        'Personal-state restore verification failed: {0}' `
                        @($item.Name))
                }
            }
        } catch {
            $restoreErrors.Add($_.Exception.Message)
        }
    }
    if ($restoreErrors.Count -gt 0) {
        throw (Get-UpdateText `
            '更新替换失败，且自动回滚未完全成功。备份保留在：{0}。原始错误：{1}；回滚错误：{2}' `
            'Update replacement failed and automatic rollback was incomplete. The backup remains at: {0}. Original error: {1}; rollback error: {2}' `
            @($Snapshot.BackupRoot, $OriginalError.Exception.Message,
                ($restoreErrors -join '；')))
    }
    Complete-PersonalStateSnapshot $Snapshot
}

function Complete-PersonalStateSnapshot {
    param([object]$Snapshot)

    if ($Snapshot -and (Test-Path -LiteralPath $Snapshot.BackupRoot)) {
        Remove-Item -LiteralPath $Snapshot.BackupRoot -Recurse -Force `
            -ErrorAction SilentlyContinue
    }
}

function Install-ArchivePackage {
    $root = [System.IO.Path]::GetFullPath($InstallRoot)
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        throw (Get-UpdateText '安装目录不存在：{0}' `
            'Installation directory does not exist: {0}' @($root))
    }
    if ($PackageKind -eq 'compiled' -and
        (Test-Path -LiteralPath (Join-Path $root '.git'))) {
        throw (Get-UpdateText 'Git 源码仓库内不允许用编译版自动更新覆盖。' `
            'Compiled automatic update is disabled inside a Git source repository.')
    }
    if ($PackageKind -eq 'source' -and
        (Test-Path -LiteralPath (Join-Path $root '.git'))) {
        throw (Get-UpdateText 'Git 源码仓库必须使用快速前进更新模式。' `
            'Git source repositories must use fast-forward update mode.')
    }

    $workRoot = Join-Path $env:TEMP `
        ("ProcessWatchdogUpdate-" + [Guid]::NewGuid().ToString('N'))
    $stage = Join-Path $workRoot 'stage'
    New-Item -ItemType Directory -Force -Path $stage | Out-Null
    try {
        $packageUrl = if ($PackageKind -eq 'compiled') {
            $BinaryUrl
        } else {
            $SourceUrl
        }
        if (-not $packageUrl) {
            throw (Get-UpdateText '该版本没有提供 {0} 更新包。' `
                'The release does not provide a {0} update package.' `
                @($PackageKind))
        }
        $packageName = [System.IO.Path]::GetFileName(([Uri]$packageUrl).LocalPath)
        $packagePath = Join-Path $workRoot $packageName
        $expectedHash = if ($PackageKind -eq 'compiled') {
            $BinarySha256
        } else {
            $SourceSha256
        }
        if (-not $expectedHash) {
            $checksumsPath = Join-Path $workRoot 'SHA256SUMS.txt'
            Invoke-ResilientDownload -Uri $ChecksumsUrl `
                -DestinationPath $checksumsPath -TimeoutSeconds 120 | Out-Null
            $expectedHash = Get-ExpectedChecksum $checksumsPath $packageName
        }
        Invoke-ResilientDownload -Uri $packageUrl `
            -DestinationPath $packagePath -ExpectedSha256 $expectedHash `
            -TimeoutSeconds 300 | Out-Null
        Expand-Archive -LiteralPath $packagePath -DestinationPath $stage

        $manifestPath = Join-Path $stage 'update-manifest.json'
        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
            throw (Get-UpdateText '更新包缺少 update-manifest.json。' `
                'The update package is missing update-manifest.json.')
        }
        $manifest = Get-Content -LiteralPath $manifestPath -Raw `
            -Encoding UTF8 | ConvertFrom-Json
        $expectedManifestKind = if ($PackageKind -eq 'compiled') {
            'compiled'
        } else {
            'source'
        }
        if ($manifest.schemaVersion -ne 1 -or
            $manifest.packageKind -ne $expectedManifestKind -or
            $manifest.version -ne $Version -or
            -not $manifest.entry) {
            throw (Get-UpdateText '更新包清单与请求的版本或运行形态不一致。' `
                'Update package manifest does not match the requested release.')
        }
        Assert-ManagedRelativePath ([string]$manifest.entry)
        $stagedEntryPath = Resolve-PathUnderRoot $stage `
            ([string]$manifest.entry)
        if (-not (Test-Path -LiteralPath $stagedEntryPath `
                -PathType Leaf)) {
            throw (Get-UpdateText '更新包缺少程序入口文件。' `
                'Update package entry file is missing.')
        }
        $fullEntryPath = [System.IO.Path]::GetFullPath($EntryPath)
        if ((Split-Path -Parent $fullEntryPath).TrimEnd('\') -ne
            $root.TrimEnd('\')) {
            throw (Get-UpdateText '当前运行入口不在安装目录的顶层，无法安全更新。' `
                'The running entry file is not directly inside the installation directory.')
        }
        $entryDestination = Split-Path -Leaf $fullEntryPath

        $managedPaths = @($manifest.managedPaths)
        if ($managedPaths.Count -eq 0) {
            throw (Get-UpdateText '更新包没有声明任何受管路径。' `
                'Update package does not declare any managed paths.')
        }
        $managedPathSet = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase)
        foreach ($relativePathValue in $managedPaths) {
            $relativePath = ([string]$relativePathValue).Replace('/', '\')
            Assert-ManagedRelativePath $relativePath
            if (-not $managedPathSet.Add($relativePath)) {
                throw (Get-UpdateText '更新清单包含重复路径：{0}' `
                    'Update manifest contains a duplicate path: {0}' `
                    @($relativePath))
            }
            $sourcePath = Resolve-PathUnderRoot $stage $relativePath
            if (-not (Test-Path -LiteralPath $sourcePath)) {
                throw (Get-UpdateText '更新包缺少受管路径：{0}' `
                    'Update package is missing managed path: {0}' `
                    @($relativePath))
            }
        }
        if (-not $managedPathSet.Contains([string]$manifest.entry)) {
            throw (Get-UpdateText '更新清单没有把程序入口列为受管路径。' `
                'The update manifest does not list its entry as a managed path.')
        }
        if (-not $managedPathSet.Contains('VERSION')) {
            throw (Get-UpdateText '更新包清单与请求的版本或运行形态不一致。' `
                'Update package manifest does not match the requested release.')
        }
        Assert-NoOverlappingPaths @($managedPathSet)

        $stagedVersionPath = Resolve-PathUnderRoot $stage 'VERSION'
        if (-not (Test-Path -LiteralPath $stagedVersionPath -PathType Leaf) -or
            (Get-Content -LiteralPath $stagedVersionPath -Raw `
                -Encoding UTF8).Trim() -cne $Version) {
            throw (Get-UpdateText '更新包清单与请求的版本或运行形态不一致。' `
                'Update package manifest does not match the requested release.')
        }
        if ($PackageKind -eq 'compiled') {
            $entryVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo(
                $stagedEntryPath)
            if ($entryVersion.FileVersion -cne "$Version.0" -or
                $entryVersion.ProductVersion -cne "$Version.0") {
                throw (Get-UpdateText '更新包清单与请求的版本或运行形态不一致。' `
                    'Update package manifest does not match the requested release.')
            }
        } elseif ([System.IO.Path]::GetExtension(
                [string]$manifest.entry) -ine '.ahk') {
            throw (Get-UpdateText '更新包清单与请求的版本或运行形态不一致。' `
                'Update package manifest does not match the requested release.')
        }

        $destinationMap = @{}
        $destinationPathSet = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase)
        foreach ($relativePath in $managedPathSet) {
            $destinationRelative = if ($relativePath -ieq
                [string]$manifest.entry) { $entryDestination } else {
                $relativePath
            }
            if (-not $destinationPathSet.Add($destinationRelative)) {
                throw (Get-UpdateText '更新清单包含重复路径：{0}' `
                    'Update manifest contains a duplicate path: {0}' `
                    @($destinationRelative))
            }
            $destinationMap[$relativePath] = $destinationRelative
        }

        # 同时读取旧清单，确保新版已删除的受管文件不会永远残留。旧入口也映射到
        # 当前实际文件名，因此用户重命名 EXE 或非 Git AHK 入口后仍能原位更新。
        $allDestinationSet = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase)
        foreach ($destinationRelative in $destinationMap.Values) {
            [void]$allDestinationSet.Add([string]$destinationRelative)
        }
        $existingManifestPath = Join-Path $root 'update-manifest.json'
        if (Test-Path -LiteralPath $existingManifestPath -PathType Leaf) {
            $existingManifest = Get-Content -LiteralPath $existingManifestPath `
                -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($existingManifest.schemaVersion -ne 1 -or
                $existingManifest.packageKind -ne $expectedManifestKind -or
                -not $existingManifest.entry) {
                throw (Get-UpdateText '现有安装的更新清单无效，已停止替换文件。' `
                    'The installed update manifest is invalid; file replacement was stopped.')
            }
            $existingPathSet = [System.Collections.Generic.HashSet[string]]::new(
                [System.StringComparer]::OrdinalIgnoreCase)
            $existingDestinationSet = `
                [System.Collections.Generic.HashSet[string]]::new(
                    [System.StringComparer]::OrdinalIgnoreCase)
            foreach ($existingPathValue in @($existingManifest.managedPaths)) {
                $existingPath = ([string]$existingPathValue).Replace('/', '\')
                Assert-ManagedRelativePath $existingPath
                if (-not $existingPathSet.Add($existingPath)) {
                    throw (Get-UpdateText '现有安装清单包含重复路径：{0}' `
                        'The installed update manifest contains a duplicate path: {0}' `
                        @($existingPath))
                }
                $existingDestination = if ($existingPath -ieq
                    [string]$existingManifest.entry) { $entryDestination } else {
                    $existingPath
                }
                if (-not $existingDestinationSet.Add($existingDestination)) {
                    throw (Get-UpdateText '现有安装清单包含重复路径：{0}' `
                        'The installed update manifest contains a duplicate path: {0}' `
                        @($existingDestination))
                }
                [void]$allDestinationSet.Add($existingDestination)
            }
            if (-not $existingPathSet.Contains(
                    [string]$existingManifest.entry)) {
                throw (Get-UpdateText '现有安装清单没有把程序入口列为受管路径。' `
                    'The installed update manifest does not list its entry as a managed path.')
            }
            Assert-NoOverlappingPaths @($existingPathSet)
        }
        # 新旧清单各自仍禁止父子重叠，但跨版本允许改变管理粒度，例如旧版管理
        # docs 整个目录，新版只管理 docs\README.md。备份阶段折叠到最外层路径即可。
        $backupPaths = Get-MinimalManagedPaths @($allDestinationSet)

        $backupRoot = Join-Path $root `
            ('.process-watchdog-update-backup-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
        $installed = [System.Collections.Generic.List[string]]::new()
        $backedUp = [System.Collections.Generic.List[string]]::new()
        $transaction = [pscustomobject]@{
            Root = $root
            BackupRoot = $backupRoot
            Installed = $installed
            BackedUp = $backedUp
        }
        $pendingEntryPath = Join-Path $root `
            ('.process-watchdog-entry-' + [Guid]::NewGuid().ToString('N') +
                '.tmp')
        try {
            foreach ($destinationRelative in $backupPaths) {
                $destination = Resolve-PathUnderRoot $root $destinationRelative
                $backup = Resolve-PathUnderRoot $backupRoot $destinationRelative
                if (Test-Path -LiteralPath $destination) {
                    New-Item -ItemType Directory -Force `
                        -Path (Split-Path -Parent $backup) | Out-Null
                    if ($destinationRelative -ieq $entryDestination) {
                        # 当前入口一直保留到其它路径全部就位；最终替换使用同卷文件
                        # 原子操作，更新进程意外终止时仍至少有一个可启动入口。
                        Copy-Item -LiteralPath $destination -Destination $backup
                    } else {
                        Move-Item -LiteralPath $destination -Destination $backup
                    }
                    $backedUp.Add($destinationRelative)
                }
            }
            foreach ($relativePath in $managedPathSet) {
                $destinationRelative = [string]$destinationMap[$relativePath]
                if ($destinationRelative -ieq $entryDestination) {
                    continue
                }
                $source = Resolve-PathUnderRoot $stage $relativePath
                $destination = Resolve-PathUnderRoot $root $destinationRelative
                New-Item -ItemType Directory -Force `
                    -Path (Split-Path -Parent $destination) | Out-Null
                # 先记录目标再复制；即使复制在中途失败，回滚也会删除不完整内容。
                $installed.Add($destinationRelative)
                Copy-Item -LiteralPath $source -Destination $destination `
                    -Recurse
            }
            $stagedEntrySource = Resolve-PathUnderRoot $stage `
                ([string]$manifest.entry)
            Copy-Item -LiteralPath $stagedEntrySource `
                -Destination $pendingEntryPath
            $entryTargetPath = Resolve-PathUnderRoot $root $entryDestination
            $installed.Add($entryDestination)
            if (Test-Path -LiteralPath $entryTargetPath -PathType Leaf) {
                try {
                    [System.IO.File]::Replace($pendingEntryPath,
                        $entryTargetPath, $null, $true)
                } catch {
                    # 某些非 NTFS 卷不支持 ReplaceFile；只在待安装文件仍完整存在时
                    # 退回同目录强制移动，避免掩盖已经发生的未知部分替换。
                    if (-not (Test-Path -LiteralPath $pendingEntryPath `
                            -PathType Leaf)) {
                        throw
                    }
                    Move-Item -LiteralPath $pendingEntryPath `
                        -Destination $entryTargetPath -Force
                }
            } else {
                Move-Item -LiteralPath $pendingEntryPath `
                    -Destination $entryTargetPath
            }
        } catch {
            $replacementError = $_
            if (Test-Path -LiteralPath $pendingEntryPath) {
                Remove-Item -LiteralPath $pendingEntryPath -Force `
                    -ErrorAction SilentlyContinue
            }
            Restore-ArchiveTransaction $transaction $replacementError
            throw $replacementError
        }
        return $transaction
    } finally {
        if (Test-Path -LiteralPath $workRoot) {
            Remove-Item -LiteralPath $workRoot -Recurse -Force
        }
    }
}

function Start-UpdatedApplication {
    param([string]$ReadyPath = '')

    if ($PackageKind -eq 'compiled') {
        if ($ReadyPath) {
            $arguments = @('--update-ready', ('"' + $ReadyPath + '"'))
            return Start-Process -FilePath $EntryPath `
                -ArgumentList $arguments -WorkingDirectory $InstallRoot `
                -PassThru
        }
        return Start-Process -FilePath $EntryPath `
            -WorkingDirectory $InstallRoot -PassThru
    }
    $scriptArgument = '"' + $EntryPath + '"'
    $arguments = @($scriptArgument)
    if ($ReadyPath) {
        $arguments += @('--update-ready', ('"' + $ReadyPath + '"'))
    }
    return Start-Process -FilePath $InterpreterPath -ArgumentList $arguments `
        -WorkingDirectory $InstallRoot -PassThru
}

function Test-UpdatedApplication {
    $validationProcess = $null
    try {
        if ($PackageKind -eq 'compiled') {
            $validationProcess = Start-Process -FilePath $EntryPath `
                -ArgumentList '--startup-validation' -WorkingDirectory `
                $InstallRoot -WindowStyle Hidden -PassThru
        } else {
            $scriptArgument = '"' + $EntryPath + '"'
            $validationProcess = Start-Process -FilePath $InterpreterPath `
                -ArgumentList @('/ErrorStdOut', $scriptArgument,
                    '--startup-validation') -WorkingDirectory $InstallRoot `
                -WindowStyle Hidden -PassThru
        }
        if (-not $validationProcess.WaitForExit(60000)) {
            try { $validationProcess.Kill() } catch {}
            throw (Get-UpdateText '更新后的程序启动校验超时。' `
                'The updated application startup validation timed out.')
        }
        if ($validationProcess.ExitCode -ne 0) {
            throw (Get-UpdateText `
                '更新后的程序未通过启动校验（退出代码 {0}）。' `
                'The updated application failed startup validation (exit code {0}).' `
                @($validationProcess.ExitCode))
        }
    } finally {
        if ($validationProcess) {
            $validationProcess.Dispose()
        }
    }
}

function Wait-ForUpdatedApplicationReady {
    param(
        [System.Diagnostics.Process]$Process,
        [string]$ReadyPath
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $readySucceeded = $false
    try {
        while ($stopwatch.ElapsedMilliseconds -lt 60000) {
            if (Test-Path -LiteralPath $ReadyPath -PathType Leaf) {
                $readyValue = (Get-Content -LiteralPath $ReadyPath -Raw `
                    -Encoding UTF8).Trim()
                if ($readyValue -cne "READY|$Version") {
                    throw (Get-UpdateText `
                        '更新后的程序未通过启动校验（退出代码 {0}）。' `
                        'The updated application failed startup validation (exit code {0}).' `
                        @('invalid readiness signal'))
                }
                # 信号写出后再观察一个短窗口，避免刚完成初始化便立即崩溃的进程
                # 被误判为可提交更新。
                Start-Sleep -Milliseconds 500
                $Process.Refresh()
                if ($Process.HasExited) {
                    throw (Get-UpdateText `
                        '更新后的程序未通过启动校验（退出代码 {0}）。' `
                        'The updated application failed startup validation (exit code {0}).' `
                        @($Process.ExitCode))
                }
                $readySucceeded = $true
                return
            }
            $Process.Refresh()
            if ($Process.HasExited) {
                throw (Get-UpdateText `
                    '更新后的程序未通过启动校验（退出代码 {0}）。' `
                    'The updated application failed startup validation (exit code {0}).' `
                    @($Process.ExitCode))
            }
            Start-Sleep -Milliseconds 100
        }
        try { $Process.Kill() } catch {}
        throw (Get-UpdateText '更新后的程序启动校验超时。' `
            'The updated application startup validation timed out.')
    } finally {
        $stopwatch.Stop()
        if (-not $readySucceeded) {
            try {
                $Process.Refresh()
                if (-not $Process.HasExited) {
                    $Process.Kill()
                    [void]$Process.WaitForExit(10000)
                }
            } catch {}
        }
        if (Test-Path -LiteralPath $ReadyPath -PathType Leaf) {
            Remove-Item -LiteralPath $ReadyPath -Force `
                -ErrorAction SilentlyContinue
        }
    }
}

function Show-UpdateFailure {
    param(
        [string]$Message,
        [string]$Diagnostic = ''
    )

    $failureText = ConvertTo-SingleLine $Message
    $diagnosticText = ConvertTo-SingleLine $Diagnostic
    $logPath = Join-Path $env:TEMP 'ProcessWatchdogUpdateErrors.log'
    Add-Content -LiteralPath $logPath -Encoding UTF8 -Value `
        ("{0} {1}{2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),
            $failureText, $(if ($diagnosticText) {
                " | $diagnosticText"
            } else { '' }))
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $dialogText = Get-UpdateText `
            "更新未能完成。`r`n`r`n{0}" `
            "The update could not be completed.`r`n`r`n{0}" @($failureText)
        $dialogTitle = Get-UpdateText '进程守护小助手更新' `
            'Process Watchdog Assistant Update'
        [void][System.Windows.Forms.MessageBox]::Show(
            $dialogText, $dialogTitle, 'OK', 'Error')
    } catch {
        # 无交互桌面时保留日志即可，不让提示失败掩盖原始更新异常。
    }
}

function Assert-ApplyArguments {
    if ($PackageKind -eq '' -or -not $InstallRoot -or -not $EntryPath -or
        -not $Version -or -not $Tag) {
        throw (Get-UpdateText '安装更新缺少必要参数。' `
            'Apply mode is missing required arguments.')
    }
    if (-not (Test-CanonicalVersion $CurrentVersion) -or
        -not (Test-CanonicalVersion $Version) -or $Tag -cne "v$Version" -or
        ([Version]$Version -le [Version]$CurrentVersion)) {
        throw (Get-UpdateText '更新版本与发行标签不一致。' `
            'The update version and release tag do not match.')
    }
    $root = [System.IO.Path]::GetFullPath($InstallRoot)
    $entry = [System.IO.Path]::GetFullPath($EntryPath)
    if (-not (Test-Path -LiteralPath $root -PathType Container) -or
        -not (Test-Path -LiteralPath $entry -PathType Leaf)) {
        throw (Get-UpdateText '安装目录或当前程序入口不存在。' `
            'The installation directory or running entry does not exist.')
    }
    if ((Split-Path -Parent $entry).TrimEnd('\') -ne $root.TrimEnd('\')) {
        throw (Get-UpdateText '当前运行入口不在安装目录的顶层。' `
            'The running entry is not directly inside the installation directory.')
    }
    if ($PackageKind -ne 'compiled' -and
        (-not $InterpreterPath -or
            -not (Test-Path -LiteralPath $InterpreterPath -PathType Leaf))) {
        throw (Get-UpdateText '源码版更新后重启所需的 AutoHotkey 解释器不可用。' `
            'The AutoHotkey interpreter required to restart the source edition is unavailable.')
    }
    if (($BinarySha256 -and $BinarySha256 -cnotmatch '^[0-9A-F]{64}$') -or
        ($SourceSha256 -and $SourceSha256 -cnotmatch '^[0-9A-F]{64}$')) {
        throw (Get-UpdateText '更新包 SHA-256 校验失败：{0}' `
            'Update package hash mismatch: {0}' @('invalid digest'))
    }
    if ($PackageKind -ne 'source-git' -and (
        ($PackageKind -eq 'compiled' -and (-not $BinaryUrl -or
            (-not $BinarySha256 -and -not $ChecksumsUrl))) -or
        ($PackageKind -eq 'source' -and (-not $SourceUrl -or
            (-not $SourceSha256 -and -not $ChecksumsUrl))))) {
        throw (Get-UpdateText '安装更新缺少下载地址或完整性校验值。' `
            'The update is missing a package URL or integrity value.')
    }
}

function Remove-ApplyHelperDirectory {
    # 只清理由主程序复制到系统临时目录的独立助手；直接从仓库运行本脚本时绝不
    # 删除项目中的 runtime 目录。
    try {
        $scriptDirectory = [System.IO.Path]::GetFullPath(
            (Split-Path -Parent $PSCommandPath))
        $tempPrefix = [System.IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
        $directoryName = Split-Path -Leaf $scriptDirectory
        if ($scriptDirectory.StartsWith($tempPrefix,
                [System.StringComparison]::OrdinalIgnoreCase) -and
            $directoryName -like 'ProcessWatchdogUpdateApply-*') {
            Remove-Item -LiteralPath $scriptDirectory -Recurse -Force `
                -ErrorAction SilentlyContinue
        }
    } catch {
        # 临时助手清理失败不应掩盖更新结果；系统临时目录可由后续维护清理。
    }
}

function Invoke-Apply {
    Assert-ApplyArguments
    Wait-ForParentExit
    $archiveTransaction = $null
    $gitTransaction = $null
    $personalStateSnapshot = $null
    if ($PackageKind -eq 'source-git') {
        $gitTransaction = Invoke-GitSourceUpdate
    } else {
        $archiveTransaction = Install-ArchivePackage
    }
    try {
        $personalStateSnapshot = New-PersonalStateSnapshot
        Test-UpdatedApplication
        $readyPath = Join-Path $PSScriptRoot 'application-ready.signal'
        if (Test-Path -LiteralPath $readyPath) {
            Remove-Item -LiteralPath $readyPath -Force
        }
        $updatedProcess = Start-UpdatedApplication $readyPath
        try {
            Wait-ForUpdatedApplicationReady $updatedProcess $readyPath
        } finally {
            if ($updatedProcess) {
                $updatedProcess.Dispose()
            }
        }
    } catch {
        $startupError = $_
        $programRollbackError = $null
        $stateRollbackError = $null
        try {
            if ($archiveTransaction) {
                Restore-ArchiveTransaction $archiveTransaction $startupError
            } elseif ($gitTransaction) {
                Invoke-Git @('-C', $gitTransaction.Root, 'reset', '--hard',
                    $gitTransaction.PreviousCommit) | Out-Null
            }
        } catch {
            $programRollbackError = $_
        }
        if ($personalStateSnapshot) {
            try {
                Restore-PersonalStateSnapshot $personalStateSnapshot `
                    $startupError
            } catch {
                $stateRollbackError = $_
            }
        }
        if ($programRollbackError) {
            if ($stateRollbackError) {
                throw (Get-UpdateText `
                    '更新替换失败，且自动回滚未完全成功。备份保留在：{0}。原始错误：{1}；回滚错误：{2}' `
                    'Update replacement failed and automatic rollback was incomplete. The backup remains at: {0}. Original error: {1}; rollback error: {2}' `
                    @($personalStateSnapshot.BackupRoot,
                        $startupError.Exception.Message,
                        ($programRollbackError.Exception.Message + '；' +
                            $stateRollbackError.Exception.Message)))
            }
            throw $programRollbackError
        }
        if ($stateRollbackError) {
            throw $stateRollbackError
        }
        throw $startupError
    }
    if ($archiveTransaction) {
        Complete-ArchiveTransaction $archiveTransaction
    }
    if ($personalStateSnapshot) {
        Complete-PersonalStateSnapshot $personalStateSnapshot
    }
}

# 测试脚本以点调用方式加载这些纯函数时不执行网络检查或文件替换；正常由 AHK 使用
# -File 启动时 InvocationName 不是句点，仍会进入下面的正式入口。
if ($MyInvocation.InvocationName -eq '.') {
    return
}

if ($Mode -eq 'Check') {
    try {
        Invoke-Check
    } catch {
        Write-CheckResult @{
            Status = 'error'
            CurrentVersion = $CurrentVersion
            Error = $_.Exception.Message
        }
        exit 1
    }
    exit 0
}

$applyExitCode = 0
try {
    Invoke-Apply
} catch {
    $applyExitCode = 1
    $updateError = $_.Exception.Message
    Show-UpdateFailure $updateError $_.ScriptStackTrace
    try {
        $fallbackProcess = Start-UpdatedApplication
        if ($fallbackProcess) {
            $fallbackProcess.Dispose()
        }
    } catch {}
} finally {
    Remove-ApplyHelperDirectory
}
exit $applyExitCode
