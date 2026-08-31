# 正式构建工具链解析器。
# 每次正式发布都从上游 Release 重新选择 AutoHotkey 最新稳定版和 Ahk2Exe 最新发布版，
# 下载后计算完整哈希，并把本次构建实际使用的不可变快照写入临时解析文件。

[CmdletBinding()]
param(
    [string]$OutputPath = "",
    [string]$Destination = "",
    [string]$GitHubToken = $env:GITHUB_TOKEN
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$toolsRoot = if ($Destination) {
    [System.IO.Path]::GetFullPath($Destination)
} else {
    Join-Path $projectRoot '.tools'
}
$cacheRoot = Join-Path $toolsRoot 'cache'
$resolvedPath = if ($OutputPath) {
    [System.IO.Path]::GetFullPath($OutputPath)
} else {
    Join-Path $toolsRoot 'toolchain.resolved.json'
}
New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null
New-Item -ItemType Directory -Force `
    -Path (Split-Path -Parent $resolvedPath) | Out-Null

function Invoke-GitHubApi {
    param([string]$Uri)

    $headers = @{
        Accept = 'application/vnd.github+json'
        'User-Agent' = 'process-watchdog-release-resolver'
        'X-GitHub-Api-Version' = '2022-11-28'
    }
    if ($GitHubToken) {
        $headers.Authorization = "Bearer $GitHubToken"
    }
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            $response = Invoke-RestMethod -UseBasicParsing -Headers $headers `
                -Uri $Uri -TimeoutSec 60
            return $response
        } catch {
            if ($attempt -eq 3) {
                throw
            }
            Start-Sleep -Seconds $attempt
        }
    }
}

function Get-UpstreamRelease {
    param(
        [string]$Repository,
        [switch]$StableOnly
    )

    if ($StableOnly) {
        # GitHub 的 /releases/latest 明确定义为最新非草稿、非预发布版本，避免稳定版
        # 被大量较新的预发布记录挤出列表分页后误报“找不到”。
        $stableRelease = Invoke-GitHubApi `
            "https://api.github.com/repos/$Repository/releases/latest"
        if ($stableRelease.draft -or $stableRelease.prerelease) {
            throw "GitHub returned a non-stable latest release for $Repository."
        }
        return $stableRelease
    }

    # Ahk2Exe 的“最新发布版”允许预发布，但不允许草稿；按发布时间而不是标签文本
    # 排序，能够正确处理其带字母后缀的版本号。
    $releases = @(Invoke-GitHubApi `
        "https://api.github.com/repos/$Repository/releases?per_page=100")
    $eligible = @($releases | Where-Object {
        -not $_.draft
    } | Sort-Object { [DateTimeOffset]$_.published_at } -Descending)
    if ($eligible.Count -eq 0) {
        throw "No eligible upstream release was found for $Repository."
    }
    return $eligible[0]
}

function Get-ReleaseAsset {
    param(
        [object]$Release,
        [string]$NamePattern,
        [string]$DisplayName
    )

    $matches = @($Release.assets | Where-Object {
        [string]$_.name -match $NamePattern
    })
    if ($matches.Count -ne 1) {
        throw "$DisplayName release asset selection was ambiguous: $($matches.Count) matches."
    }
    return $matches[0]
}

function Save-RemoteFile {
    param(
        [string]$Uri,
        [string]$Path,
        [string]$DisplayName
    )

    $downloadPath = "$Path.download"
    foreach ($candidatePath in @($Path, $downloadPath)) {
        if (Test-Path -LiteralPath $candidatePath) {
            Remove-Item -LiteralPath $candidatePath -Force
        }
    }
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            Write-Host "Downloading $DisplayName (attempt $attempt/3)..."
            Invoke-WebRequest -UseBasicParsing -Uri $Uri `
                -OutFile $downloadPath -TimeoutSec 180
            if (-not (Test-Path -LiteralPath $downloadPath -PathType Leaf)) {
                throw "$DisplayName download did not create a file."
            }
            Move-Item -LiteralPath $downloadPath -Destination $Path -Force
            return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
        } catch {
            Remove-Item -LiteralPath $downloadPath -Force `
                -ErrorAction SilentlyContinue
            if ($attempt -eq 3) {
                throw
            }
            Start-Sleep -Seconds $attempt
        }
    }
}

function Expand-ResolvedTool {
    param(
        [string]$Name,
        [string]$Version,
        [string]$ArchivePath,
        [string]$ExecutableName
    )

    $installPath = Join-Path $toolsRoot "$Name-$Version"
    if (Test-Path -LiteralPath $installPath) {
        Remove-Item -LiteralPath $installPath -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $installPath | Out-Null
    Expand-Archive -LiteralPath $ArchivePath -DestinationPath $installPath
    $executables = @(Get-ChildItem -LiteralPath $installPath -Recurse -File `
        -Filter $ExecutableName)
    if ($executables.Count -ne 1) {
        throw "$Name archive must contain exactly one $ExecutableName."
    }
    return $executables[0].FullName
}

$autoHotkeyRelease = Get-UpstreamRelease 'AutoHotkey/AutoHotkey' -StableOnly
$autoHotkeyVersion = ([string]$autoHotkeyRelease.tag_name).TrimStart('v')
$autoHotkeyAsset = Get-ReleaseAsset $autoHotkeyRelease `
    ('^AutoHotkey_' + [regex]::Escape($autoHotkeyVersion) + '\.zip$') `
    'AutoHotkey'
$autoHotkeyArchive = Join-Path $cacheRoot ([string]$autoHotkeyAsset.name)
$autoHotkeyArchiveHash = Save-RemoteFile `
    $autoHotkeyAsset.browser_download_url $autoHotkeyArchive `
    "AutoHotkey $autoHotkeyVersion"
$autoHotkeyExecutable = Expand-ResolvedTool 'AutoHotkey' $autoHotkeyVersion `
    $autoHotkeyArchive 'AutoHotkey64.exe'
$autoHotkeyInstallRoot = Split-Path -Parent $autoHotkeyExecutable
$autoHotkeyLicensePath = Join-Path $autoHotkeyInstallRoot 'license.txt'
if (-not (Test-Path -LiteralPath $autoHotkeyLicensePath -PathType Leaf)) {
    throw 'AutoHotkey archive does not contain license.txt next to AutoHotkey64.exe.'
}
$autoHotkeyCommit = [string](Invoke-GitHubApi `
    "https://api.github.com/repos/AutoHotkey/AutoHotkey/commits/$($autoHotkeyRelease.tag_name)").sha
if ($autoHotkeyCommit -notmatch '^[0-9a-f]{40}$') {
    throw "AutoHotkey release tag did not resolve to a commit: $autoHotkeyCommit"
}
$autoHotkeySourceArchive = "AutoHotkey_source_$autoHotkeyCommit.zip"
$autoHotkeySourcePath = Join-Path $cacheRoot $autoHotkeySourceArchive
$autoHotkeySourceUrl = `
    "https://codeload.github.com/AutoHotkey/AutoHotkey/zip/$autoHotkeyCommit"
$autoHotkeySourceHash = Save-RemoteFile $autoHotkeySourceUrl `
    $autoHotkeySourcePath "AutoHotkey source $autoHotkeyCommit"

$ahk2ExeRelease = Get-UpstreamRelease 'AutoHotkey/Ahk2Exe'
$ahk2ExeVersion = ([string]$ahk2ExeRelease.tag_name) `
    -replace '^Ahk2Exe', ''
$ahk2ExeAsset = Get-ReleaseAsset $ahk2ExeRelease '\.zip$' 'Ahk2Exe'
$ahk2ExeArchive = Join-Path $cacheRoot ([string]$ahk2ExeAsset.name)
$ahk2ExeArchiveHash = Save-RemoteFile $ahk2ExeAsset.browser_download_url `
    $ahk2ExeArchive "Ahk2Exe $ahk2ExeVersion"
$ahk2ExeExecutable = Expand-ResolvedTool 'Ahk2Exe' $ahk2ExeVersion `
    $ahk2ExeArchive 'Ahk2Exe.exe'

$fixedToolLock = Get-Content -LiteralPath `
    (Join-Path $PSScriptRoot 'toolchain.lock.json') -Raw -Encoding UTF8 |
    ConvertFrom-Json
$resolved = [ordered]@{
    schemaVersion = 2
    selection = [ordered]@{
        autoHotkey = 'latest-stable-release'
        ahk2Exe = 'latest-published-release'
    }
    tools = [ordered]@{
        autoHotkey = [ordered]@{
            version = $autoHotkeyVersion
            tag = [string]$autoHotkeyRelease.tag_name
            releaseId = [long]$autoHotkeyRelease.id
            publishedAt = [string]$autoHotkeyRelease.published_at
            archive = [string]$autoHotkeyAsset.name
            url = [string]$autoHotkeyAsset.browser_download_url
            sha256 = $autoHotkeyArchiveHash
            executable = 'AutoHotkey64.exe'
            executableSha256 = (Get-FileHash -Algorithm SHA256 `
                -LiteralPath $autoHotkeyExecutable).Hash
            licenseExpression = 'GPL-2.0-only AND BSD-3-Clause'
            licenseFile = 'license.txt'
            licenseSha256 = (Get-FileHash -Algorithm SHA256 `
                -LiteralPath $autoHotkeyLicensePath).Hash
            sourceCommit = $autoHotkeyCommit
            sourceArchive = $autoHotkeySourceArchive
            sourceUrl = $autoHotkeySourceUrl
            sourceSha256 = $autoHotkeySourceHash
            sbomRelationship = 'DEPENDS_ON'
        }
        ahk2Exe = [ordered]@{
            version = $ahk2ExeVersion
            tag = [string]$ahk2ExeRelease.tag_name
            releaseId = [long]$ahk2ExeRelease.id
            publishedAt = [string]$ahk2ExeRelease.published_at
            archive = [string]$ahk2ExeAsset.name
            url = [string]$ahk2ExeAsset.browser_download_url
            sha256 = $ahk2ExeArchiveHash
            executable = 'Ahk2Exe.exe'
            executableSha256 = (Get-FileHash -Algorithm SHA256 `
                -LiteralPath $ahk2ExeExecutable).Hash
            licenseExpression = 'WTFPL'
            sbomRelationship = 'BUILD_TOOL_OF'
        }
        actionlint = $fixedToolLock.tools.actionlint
        gitleaks = $fixedToolLock.tools.gitleaks
    }
}
$resolvedJson = $resolved | ConvertTo-Json -Depth 8 -Compress
[System.IO.File]::WriteAllText($resolvedPath, $resolvedJson + "`r`n",
    [System.Text.UTF8Encoding]::new($false))

Write-Host "Resolved AutoHotkey $autoHotkeyVersion and Ahk2Exe $ahk2ExeVersion."
[pscustomobject]@{
    ResolvedToolchainPath = $resolvedPath
    AutoHotkeyPath = $autoHotkeyExecutable
    AutoHotkeySourcePath = $autoHotkeySourcePath
    CompilerPath = $ahk2ExeExecutable
}
