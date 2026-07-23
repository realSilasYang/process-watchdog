[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PackageDirectory
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$packageRoot = [System.IO.Path]::GetFullPath($PackageDirectory)
if (-not (Test-Path -LiteralPath $packageRoot -PathType Container)) {
    throw "Release package directory does not exist: $packageRoot"
}
$version = (Get-Content -LiteralPath (Join-Path $projectRoot 'VERSION') `
    -Raw -Encoding UTF8).Trim()
$mainScript = Get-ChildItem -LiteralPath $projectRoot -Filter '*.ahk' -File |
    Where-Object { $_.Name -notlike '_*' } |
    Select-Object -First 1
if (-not $mainScript) {
    throw 'Main AutoHotkey source was not found.'
}
$requiredPaths = @(
    'VERSION',
    'LICENSE',
    'THIRD_PARTY_NOTICES.md',
    'SBOM.spdx.json',
    'build-manifest.json',
    'build-metadata\toolchain.lock.json',
    'licenses\AutoHotkey-LICENSE.txt',
    'SUPPORT.md',
    'watchdog.example.ini',
    'assets\status-icons\running.svg',
    'third_party\dependencies.lock.json',
    'third_party\resvg\resvg.dll',
    'third_party\everything\Everything64.dll',
    'docs\quick-start.md',
    'docs\troubleshooting.md',
    'tests\gui\MANUAL-REGRESSION.md'
)
foreach ($relativePath in $requiredPaths) {
    if (-not (Test-Path -LiteralPath (Join-Path $packageRoot $relativePath))) {
        throw "Release package is missing: $relativePath"
    }
}
foreach ($forbiddenPath in @('watchdog.ini', 'watchdog.maintenance.ini')) {
    if (Test-Path -LiteralPath (Join-Path $packageRoot $forbiddenPath)) {
        throw "Release package contains local runtime state: $forbiddenPath"
    }
}

$executables = @(Get-ChildItem -LiteralPath $packageRoot -File -Filter '*.exe')
if ($executables.Count -ne 1) {
    throw "Release package must contain exactly one root executable; found $($executables.Count)."
}
$executable = $executables[0]
if ($executable.VersionInfo.FileVersion -ne "$version.0" -or
    $executable.VersionInfo.ProductVersion -ne "$version.0") {
    throw "Executable version metadata does not match VERSION $version."
}
$manifest = Get-Content -LiteralPath `
    (Join-Path $packageRoot 'build-manifest.json') -Raw -Encoding UTF8 |
    ConvertFrom-Json
$packagedToolLockPath = Join-Path $packageRoot `
    'build-metadata\toolchain.lock.json'
$projectToolLockPath = Join-Path $projectRoot 'tools\toolchain.lock.json'
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $packagedToolLockPath).Hash `
        -ne (Get-FileHash -Algorithm SHA256 `
            -LiteralPath $projectToolLockPath).Hash) {
    throw 'Packaged toolchain lock does not match the source lock.'
}
$toolLock = Get-Content -LiteralPath $packagedToolLockPath -Raw `
    -Encoding UTF8 | ConvertFrom-Json
if ($manifest.schemaVersion -ne 2 -or
    $manifest.version -ne $version -or
    $manifest.platform -ne 'windows-x64' -or
    $manifest.autoHotkey -ne $toolLock.tools.autoHotkey.version -or
    $manifest.autoHotkeyExecutableSha256 -ne `
        $toolLock.tools.autoHotkey.executableSha256 -or
    $manifest.ahk2Exe -ne $toolLock.tools.ahk2Exe.version -or
    $manifest.ahk2ExeExecutableSha256 -ne `
        $toolLock.tools.ahk2Exe.executableSha256 -or
    $manifest.sourceEntry -cne $mainScript.Name -or
    $executable.BaseName -cne $mainScript.BaseName) {
    throw 'Release build manifest is inconsistent.'
}
$sbom = Get-Content -LiteralPath (Join-Path $packageRoot 'SBOM.spdx.json') `
    -Raw -Encoding UTF8 | ConvertFrom-Json
if ($sbom.spdxVersion -ne 'SPDX-2.3') {
    throw 'Release SPDX SBOM is invalid or incomplete.'
}
$expectedPackageNames = @(
    'process-watchdog',
    'resvg C API',
    'Everything SDK DLL',
    'AutoHotkey',
    'Ahk2Exe',
    'actionlint',
    'Google Material Symbols Rounded'
)
$actualPackageNames = @($sbom.packages | ForEach-Object { $_.name })
$packageDifference = @(Compare-Object -ReferenceObject $expectedPackageNames `
    -DifferenceObject $actualPackageNames)
if ($packageDifference.Count -ne 0 -or
    $actualPackageNames.Count -ne $expectedPackageNames.Count) {
    throw 'Release SPDX SBOM package inventory is incomplete.'
}
$autoHotkeyPackage = $sbom.packages |
    Where-Object { $_.name -eq 'AutoHotkey' } | Select-Object -First 1
$ahk2ExePackage = $sbom.packages |
    Where-Object { $_.name -eq 'Ahk2Exe' } | Select-Object -First 1
$actionlintPackage = $sbom.packages |
    Where-Object { $_.name -eq 'actionlint' } | Select-Object -First 1
if ($autoHotkeyPackage.licenseDeclared -ne `
        'GPL-2.0-only AND BSD-3-Clause' -or
    $autoHotkeyPackage.checksums[0].checksumValue -ne `
        $toolLock.tools.autoHotkey.sha256 -or
    $ahk2ExePackage.licenseDeclared -ne 'WTFPL' -or
    $ahk2ExePackage.checksums[0].checksumValue -ne `
        $toolLock.tools.ahk2Exe.sha256 -or
    $actionlintPackage.licenseDeclared -ne 'MIT' -or
    $actionlintPackage.checksums[0].checksumValue -ne `
        $toolLock.tools.actionlint.sha256) {
    throw 'Release SPDX SBOM toolchain provenance is inconsistent.'
}
$autoHotkeyLicensePath = Join-Path $packageRoot `
    'licenses\AutoHotkey-LICENSE.txt'
if ((Get-FileHash -Algorithm SHA256 `
        -LiteralPath $autoHotkeyLicensePath).Hash -ne `
        $toolLock.tools.autoHotkey.licenseSha256) {
    throw 'Packaged AutoHotkey license hash is inconsistent.'
}

$dependencyLock = Get-Content -LiteralPath `
    (Join-Path $packageRoot 'third_party\dependencies.lock.json') `
    -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($dependency in $dependencyLock.dependencies) {
    $path = Join-Path $packageRoot `
        ([string]$dependency.path -replace '/', '\')
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
    if ($hash -ne $dependency.sha256) {
        throw "Packaged dependency hash mismatch: $($dependency.name)"
    }
}

$packageRootPrefix = $packageRoot.TrimEnd('\') + '\'
foreach ($markdownFile in Get-ChildItem -LiteralPath $packageRoot `
        -Recurse -File -Filter '*.md') {
    $markdown = Get-Content -LiteralPath $markdownFile.FullName `
        -Raw -Encoding UTF8
    foreach ($linkMatch in [regex]::Matches($markdown,
            '\[[^\]]+\]\(([^)]+)\)')) {
        $linkTarget = $linkMatch.Groups[1].Value.Trim()
        if ($linkTarget -match '^(?:[a-z][a-z0-9+.-]*:|#)') {
            continue
        }
        $linkTarget = ($linkTarget -split '#', 2)[0]
        if ($linkTarget -eq '') {
            continue
        }
        $decodedTarget = [Uri]::UnescapeDataString($linkTarget) `
            -replace '/', '\'
        $resolvedTarget = [System.IO.Path]::GetFullPath((Join-Path `
            $markdownFile.DirectoryName $decodedTarget))
        if (-not $resolvedTarget.StartsWith($packageRootPrefix,
                [System.StringComparison]::OrdinalIgnoreCase) -or
            -not (Test-Path -LiteralPath $resolvedTarget)) {
            $relativeMarkdownPath = $markdownFile.FullName.Substring(
                $packageRootPrefix.Length)
            throw "Packaged Markdown link is broken: $relativeMarkdownPath -> $linkTarget"
        }
    }
}

Write-Host "Release package verification passed for $version."
