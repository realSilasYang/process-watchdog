# 开源发布历史与敏感信息检查。
# 同时扫描提交历史和当前待发布快照，验证工具锁定来源并避免凭据或本机数据进入发行内容。

[CmdletBinding()]
param(
    [string]$GitleaksPath = ""
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$toolLock = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'tools\toolchain.lock.json') `
    -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $GitleaksPath) {
    $toolchain = & (Join-Path $projectRoot `
        'tools\bootstrap-toolchain.ps1')
    $GitleaksPath = $toolchain.GitleaksPath
}
if (-not (Test-Path -LiteralPath $GitleaksPath -PathType Leaf)) {
    throw "gitleaks is missing: $GitleaksPath"
}
$gitleaksHash = (Get-FileHash -Algorithm SHA256 `
    -LiteralPath $GitleaksPath).Hash
if ($gitleaksHash -ne $toolLock.tools.gitleaks.executableSha256) {
    throw "gitleaks does not match the pinned executable: $gitleaksHash"
}

$insideWorkTree = git -C $projectRoot rev-parse --is-inside-work-tree
if ($LASTEXITCODE -ne 0 -or $insideWorkTree.Trim() -ne 'true') {
    throw 'Publication verification requires a Git worktree.'
}
$isShallow = git -C $projectRoot rev-parse --is-shallow-repository
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to determine whether the Git history is shallow.'
}
if ($isShallow.Trim() -ne 'false') {
    throw 'Publication verification refuses a shallow Git history.'
}

$historicalPaths = @(git -C $projectRoot log --all --name-only `
    --pretty=format: | Where-Object { $_ -ne '' } | Sort-Object -Unique)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to enumerate paths from the complete Git history.'
}
$forbiddenHistoryPatterns = @(
    '(^|/)watchdog\.ini$'
    '(^|/)_codex_[^/]*$'
)
foreach ($historicalPath in $historicalPaths) {
    foreach ($pattern in $forbiddenHistoryPatterns) {
        if ($historicalPath -match $pattern) {
            throw "Private runtime or probe path exists in Git history: $historicalPath"
        }
    }
}

$textExtensions = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase)
foreach ($extension in @('.ahk', '.ini', '.json', '.md', '.ps1', '.txt',
        '.yml', '.yaml')) {
    [void]$textExtensions.Add($extension)
}
$textNames = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase)
foreach ($name in @('.editorconfig', '.gitattributes', '.gitignore',
        '.mailmap', 'LICENSE', 'VERSION')) {
    [void]$textNames.Add($name)
}
$candidatePaths = @(git -C $projectRoot ls-files --cached --others `
    --exclude-standard)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to enumerate publication input files.'
}
$separator = [System.IO.Path]::DirectorySeparatorChar
$privateTextMarkers = @(
    ('C:' + $separator + 'Users' + $separator)
    ('D:' + $separator + 'My' + 'PC' + $separator)
    ('App' + 'Data' + $separator + 'Local' + $separator + 'Temp')
    ('codex' + '-clipboard')
)
$strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
foreach ($relativePath in $candidatePaths) {
    $leafName = [System.IO.Path]::GetFileName($relativePath)
    $extension = [System.IO.Path]::GetExtension($relativePath)
    if (-not $textExtensions.Contains($extension) -and
        -not $textNames.Contains($leafName)) {
        continue
    }
    $fullPath = Join-Path $projectRoot ($relativePath -replace '/', '\')
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        continue
    }
    $bytes = [System.IO.File]::ReadAllBytes($fullPath)
    try {
        if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and
            $bytes[1] -eq 0xFE) {
            $text = [System.Text.Encoding]::Unicode.GetString($bytes, 2,
                $bytes.Length - 2)
        } else {
            $offset = if ($bytes.Length -ge 3 -and
                $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and
                $bytes[2] -eq 0xBF) { 3 } else { 0 }
            $text = $strictUtf8.GetString($bytes, $offset,
                $bytes.Length - $offset)
        }
    } catch {
        continue
    }
    foreach ($privateTextMarker in $privateTextMarkers) {
        if ($text.IndexOf($privateTextMarker,
                [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            throw "Tracked publication text exposes a local path or probe: $relativePath"
        }
    }
}

Push-Location $projectRoot
try {
    & $GitleaksPath git --no-banner --no-color --redact `
        '--log-opts=--all' .
    if ($LASTEXITCODE -ne 0) {
        throw "gitleaks failed with exit code $LASTEXITCODE."
    }
} finally {
    Pop-Location
}

$scanRoot = Join-Path $projectRoot `
    ('.build\publication-index-' + [Guid]::NewGuid().ToString('N'))
$fullProjectRoot = [System.IO.Path]::GetFullPath($projectRoot).TrimEnd('\') + '\'
$fullScanRoot = [System.IO.Path]::GetFullPath($scanRoot)
if (-not $fullScanRoot.StartsWith($fullProjectRoot,
        [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Publication scan directory escaped the project root: $fullScanRoot"
}
New-Item -ItemType Directory -Force -Path $fullScanRoot | Out-Null
try {
    $checkoutPrefix = $fullScanRoot.Replace('\', '/') + '/'
    $previousSkipSmudge = $env:GIT_LFS_SKIP_SMUDGE
    try {
        $env:GIT_LFS_SKIP_SMUDGE = '1'
        git -C $projectRoot checkout-index --all --force `
            "--prefix=$checkoutPrefix"
    } finally {
        $env:GIT_LFS_SKIP_SMUDGE = $previousSkipSmudge
    }
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to export the staged publication snapshot.'
    }
    & $GitleaksPath dir --no-banner --no-color --redact $fullScanRoot
    if ($LASTEXITCODE -ne 0) {
        throw "gitleaks staged snapshot scan failed with exit code $LASTEXITCODE."
    }
} finally {
    if (Test-Path -LiteralPath $fullScanRoot) {
        Remove-Item -LiteralPath $fullScanRoot -Recurse -Force
    }
}

Write-Host "Publication history and staged snapshot checks passed with gitleaks $($toolLock.tools.gitleaks.version)."
