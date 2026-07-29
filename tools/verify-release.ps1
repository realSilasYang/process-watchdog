# 已生成发行目录的离线验收脚本。
# 校验文件清单、哈希、签名材料、SBOM、许可证和启动结构，确保压缩前的包内容自洽。

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PackageDirectory,
    [Parameter(Mandatory = $true)]
    [string]$StandaloneExecutablePath,
    [Parameter(Mandatory = $true)]
    [string]$SourcePackageDirectory,
    [Parameter(Mandatory = $true)]
    [string]$ResolvedToolchainPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $PSScriptRoot 'ReleaseEngineering.psm1') -Force
$packageRoot = [System.IO.Path]::GetFullPath($PackageDirectory)
if (-not (Test-Path -LiteralPath $packageRoot -PathType Container)) {
    throw "Release package directory does not exist: $packageRoot"
}
$version = (Get-Content -LiteralPath (Join-Path $projectRoot 'VERSION') `
    -Raw -Encoding UTF8).Trim()
$sourceToolLock = Get-Content -LiteralPath $ResolvedToolchainPath `
    -Raw -Encoding UTF8 | ConvertFrom-Json
$autoHotkeySourceRelativePath = "licenses\sources\AutoHotkey-$($sourceToolLock.tools.autoHotkey.version)-source.zip"
$mainScript = Get-ChildItem -LiteralPath $projectRoot -Filter '*.ahk' -File |
    Where-Object { $_.Name -notlike '_*' } |
    Select-Object -First 1
if (-not $mainScript) {
    throw 'Main AutoHotkey source was not found.'
}
$requiredPaths = @(
    'VERSION',
    'LICENSE',
    'README.md',
    'docs\README.en.md',
    'CHANGELOG.md',
    'docs\CHANGELOG.en.md',
    'SBOM.spdx.json',
    'build-manifest.json',
    'build-metadata\toolchain.resolved.json',
    'update-manifest.json',
    'runtime\application-update.ps1',
    'runtime\application-update.strings.json',
    'runtime\standalone-install.ps1',
    'runtime\standalone-launcher.ahk',
    'licenses\AutoHotkey-LICENSE.txt',
    $autoHotkeySourceRelativePath,
    '.github\CONTRIBUTING.md',
    '.github\CONTRIBUTING.en.md',
    '.github\CODE_OF_CONDUCT.md',
    '.github\CODE_OF_CONDUCT.en.md',
    '.github\SECURITY.md',
    '.github\SECURITY.en.md',
    '.github\SUPPORT.md',
    '.github\SUPPORT.en.md',
    'config\watchdog.example.ini',
    'assets\app\watchdog.ico',
    'assets\app\watchdog-logo.png',
    'assets\donate\微信个人收款码.png',
    'assets\donate\微信个人收款码-界面.png',
    'assets\donate\支付宝个人收款码.png',
    'assets\donate\支付宝个人收款码-界面.png',
    'assets\ui-icons\README.md',
    'assets\ui-icons\external-link.svg',
    'assets\ui-icons\lucide\LICENSE.txt',
    'assets\ui-icons\lucide\README.md',
    'assets\ui-icons\lucide\VERSION.txt',
    'assets\ui-icons\lucide\activity.svg',
    'assets\ui-icons\lucide\ban.svg',
    'assets\ui-icons\lucide\book-open.svg',
    'assets\ui-icons\lucide\circle-check-big.svg',
    'assets\ui-icons\lucide\circle-info-unknown.svg',
    'assets\ui-icons\lucide\circle-info.svg',
    'assets\ui-icons\lucide\circle-pause.svg',
    'assets\ui-icons\lucide\circle-question-mark.svg',
    'assets\ui-icons\lucide\circle-x.svg',
    'assets\ui-icons\lucide\file-clock.svg',
    'assets\ui-icons\lucide\file-code-2.svg',
    'assets\ui-icons\lucide\file-x-2.svg',
    'assets\ui-icons\lucide\folder-open.svg',
    'assets\ui-icons\lucide\heart.svg',
    'assets\ui-icons\lucide\hourglass.svg',
    'assets\ui-icons\lucide\logs.svg',
    'assets\ui-icons\lucide\loader-circle.svg',
    'assets\ui-icons\lucide\message-square-text.svg',
    'assets\ui-icons\lucide\octagon-x.svg',
    'assets\ui-icons\lucide\package-open.svg',
    'assets\ui-icons\lucide\play.svg',
    'assets\ui-icons\lucide\power.svg',
    'assets\ui-icons\lucide\refresh-cw-action.svg',
    'assets\ui-icons\lucide\refresh-cw.svg',
    'assets\ui-icons\lucide\repeat-2.svg',
    'assets\ui-icons\lucide\rocket.svg',
    'assets\ui-icons\lucide\rotate-ccw.svg',
    'assets\ui-icons\lucide\scan-search.svg',
    'assets\ui-icons\lucide\search.svg',
    'assets\ui-icons\lucide\settings.svg',
    'assets\ui-icons\lucide\shield-alert.svg',
    'assets\ui-icons\lucide\shield-ellipsis.svg',
    'assets\ui-icons\lucide\sliders-horizontal.svg',
    'assets\ui-icons\lucide\square-plus.svg',
    'assets\ui-icons\lucide\target.svg',
    'assets\ui-icons\lucide\timer.svg',
    'assets\ui-icons\lucide\trash-2.svg',
    'assets\ui-icons\lucide\triangle-alert-red.svg',
    'assets\ui-icons\lucide\triangle-alert-timeout.svg',
    'assets\ui-icons\lucide\triangle-alert.svg',
    'assets\ui-icons\lucide\undo-2.svg',
    'assets\ui-icons\lucide\wand-sparkles.svg',
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
    'third_party\dependencies.lock.json',
    'third_party\resvg\resvg.dll',
    'third_party\everything\Everything64.dll',
    'docs\README.md',
    'docs\quick-start.md',
    'docs\versioning.md',
    'docs\project\GOVERNANCE.md',
    'docs\project\GOVERNANCE.en.md',
    'docs\project\THIRD_PARTY_NOTICES.md',
    'docs\project\THIRD_PARTY_NOTICES.en.md',
    'docs\images\process-watchdog-overview.png',
    'docs\en\quick-start.md',
    'docs\en\versioning.md',
    'docs\en\installation.md',
    'docs\en\configuration.md',
    'docs\en\compatibility.md',
    'docs\en\diagnostics.md',
    'docs\en\troubleshooting.md',
    'docs\en\architecture.md',
    'docs\en\changelog-template.md',
    'docs\en\release-process.md',
    'docs\en\publication-checklist.md',
    'docs\troubleshooting.md',
    'docs\architecture.md',
    'docs\changelog-template.md',
    'docs\release-process.md',
    'docs\publication-checklist.md',
    'tests\gui\MANUAL-REGRESSION.md'
    'tests\gui\MANUAL-REGRESSION.en.md'
    'tests\gui\VALIDATION-EVIDENCE.md'
    'tests\gui\VALIDATION-EVIDENCE.en.md'
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
foreach ($obsoletePath in @(
        'README.en.md', 'CHANGELOG.en.md', 'watchdog.ico',
        'watchdog.example.ini', 'docs\development')) {
    if (Test-Path -LiteralPath (Join-Path $packageRoot $obsoletePath)) {
        throw "Release package contains an obsolete layout path: $obsoletePath"
    }
}

function Test-FontMetadataFamilies {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,
        [Parameter(Mandatory = $true)]
        [object]$Font
    )

    $fontPath = Join-Path $Root ([string]$Font.path -replace '/', '\')
    $declaredFamilies = @($Font.families | ForEach-Object { [string]$_ })
    if ($declaredFamilies.Count -eq 0) {
        throw "Packaged font declares no usable family names: $($Font.name)"
    }
    $actualFamilies = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)
    foreach ($familyName in (Get-OpenTypeFamilyNames -FontPath $fontPath)) {
        [void]$actualFamilies.Add([string]$familyName)
    }
    foreach ($declaredFamily in $declaredFamilies) {
        if (-not $actualFamilies.Contains($declaredFamily)) {
            throw "Packaged font family mismatch: $($Font.name) does not expose $declaredFamily"
        }
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
$standaloneExecutable = Get-Item -LiteralPath `
    ([System.IO.Path]::GetFullPath($StandaloneExecutablePath))
$expectedStandaloneName = "process-watchdog-$version-windows-x64.exe"
if (-not $standaloneExecutable.PSIsContainer -and
    $standaloneExecutable.Name -cne $expectedStandaloneName) {
    throw "Standalone executable name is not stable: $($standaloneExecutable.Name)"
}
if ($standaloneExecutable.PSIsContainer) {
    throw "Standalone executable path is not a file: $StandaloneExecutablePath"
}
if ($standaloneExecutable.VersionInfo.FileVersion -ne "$version.0" -or
    $standaloneExecutable.VersionInfo.ProductVersion -ne "$version.0") {
    throw "Standalone executable version metadata does not match VERSION $version."
}
$portableZipPath = [System.IO.Path]::ChangeExtension(
    $standaloneExecutable.FullName, '.zip')
if (-not (Test-Path -LiteralPath $portableZipPath -PathType Leaf)) {
    throw 'Standalone executable verification requires the portable ZIP beside it.'
}
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $executable.FullName).Hash `
        -eq (Get-FileHash -Algorithm SHA256 `
            -LiteralPath $standaloneExecutable.FullName).Hash) {
    throw 'Standalone executable is still the resource-dependent portable executable.'
}
if ($standaloneExecutable.Length -le
        (Get-Item -LiteralPath $portableZipPath).Length) {
    throw 'Standalone executable does not appear to contain the complete portable payload.'
}

# 只把独立 EXE 复制进空目录，并把 LOCALAPPDATA 指向隔离沙箱。成功启动校验
# 证明它没有暗中依赖发布目录旁的 assets、runtime 或 third_party；第二次启动
# 同时确认启动器不会覆盖已经存在的个人配置。
$standaloneSandbox = Join-Path $env:TEMP `
    ('ProcessWatchdogStandaloneReleaseTest-' +
        [Guid]::NewGuid().ToString('N'))
$standaloneEmptyDirectory = Join-Path $standaloneSandbox 'empty'
$standaloneLocalAppData = Join-Path $standaloneSandbox 'local-app-data'
New-Item -ItemType Directory -Force `
    -Path $standaloneEmptyDirectory, $standaloneLocalAppData | Out-Null
$isolatedStandalone = Join-Path $standaloneEmptyDirectory `
    $standaloneExecutable.Name
Copy-Item -LiteralPath $standaloneExecutable.FullName `
    -Destination $isolatedStandalone
try {
    foreach ($validationPass in 1..2) {
        if ($validationPass -eq 2) {
            $extractedRoot = Join-Path $standaloneLocalAppData `
                'ProcessWatchdog\Standalone'
            $personalConfigPath = Join-Path $extractedRoot 'watchdog.ini'
            $personalConfigContent = "[Settings]`r`nSentinel=preserve`r`n"
            [System.IO.File]::WriteAllText($personalConfigPath, $personalConfigContent, [System.Text.Encoding]::Unicode)
            $personalConfigHash = (Get-FileHash -Algorithm SHA256 `
                -LiteralPath $personalConfigPath).Hash
        }
        & (Join-Path $PSScriptRoot 'invoke-startup-validation.ps1') `
            -ExecutablePath $isolatedStandalone `
            -WorkingDirectory $standaloneEmptyDirectory `
            -LocalAppData $standaloneLocalAppData `
            -TimeoutSeconds 180 `
            -FailureLabel 'Standalone empty-directory validation'
    }
    $extractedRoot = Join-Path $standaloneLocalAppData `
        'ProcessWatchdog\Standalone'
    foreach ($requiredExtractedPath in @('VERSION', 'assets', 'runtime',
            'third_party', '.standalone-payload.sha256')) {
        if (-not (Test-Path -LiteralPath `
                (Join-Path $extractedRoot $requiredExtractedPath))) {
            throw "Standalone payload did not extract: $requiredExtractedPath"
        }
    }
    if ((Get-FileHash -Algorithm SHA256 `
            -LiteralPath (Join-Path $extractedRoot 'watchdog.ini')).Hash `
            -ne $personalConfigHash) {
        throw 'Standalone relaunch overwrote personal configuration.'
    }

    # 模拟自动更新已把稳定目录推进到更高版本，但其中一个资源随后损坏。
    # 当前较旧启动器可以报错，却绝不能用自己的旧载荷覆盖该安装。
    [System.IO.File]::WriteAllText((Join-Path $extractedRoot 'VERSION'),
        "999.0.0`r`n", [System.Text.UTF8Encoding]::new($false))
    Remove-Item -LiteralPath (Join-Path $extractedRoot 'assets') `
        -Recurse -Force
    try {
        & (Join-Path $PSScriptRoot 'invoke-startup-validation.ps1') `
            -ExecutablePath $isolatedStandalone `
            -WorkingDirectory $standaloneEmptyDirectory `
            -LocalAppData $standaloneLocalAppData `
            -TimeoutSeconds 180 `
            -FailureLabel 'Standalone downgrade protection validation'
    } catch {
        # 较新安装缺少资源时内层启动校验可以失败；这里只验证旧启动器没有降级。
    }
    if ((Get-Content -LiteralPath (Join-Path $extractedRoot 'VERSION') `
            -Raw -Encoding UTF8).Trim() -cne '999.0.0' -or
        (Test-Path -LiteralPath (Join-Path $extractedRoot 'assets'))) {
        throw 'Standalone launcher downgraded a newer incomplete installation.'
    }
} finally {
    if (Test-Path -LiteralPath $standaloneSandbox) {
        Remove-Item -LiteralPath $standaloneSandbox -Recurse -Force `
            -ErrorAction SilentlyContinue
    }
}
$manifest = Get-Content -LiteralPath `
    (Join-Path $packageRoot 'build-manifest.json') -Raw -Encoding UTF8 |
    ConvertFrom-Json
$packagedToolLockPath = Join-Path $packageRoot `
    'build-metadata\toolchain.resolved.json'
$projectToolLockPath = [System.IO.Path]::GetFullPath(
    $ResolvedToolchainPath)
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $packagedToolLockPath).Hash `
        -ne (Get-FileHash -Algorithm SHA256 `
            -LiteralPath $projectToolLockPath).Hash) {
    throw 'Packaged resolved toolchain does not match the build snapshot.'
}
$toolLock = Get-Content -LiteralPath $packagedToolLockPath -Raw `
    -Encoding UTF8 | ConvertFrom-Json
if ($manifest.schemaVersion -ne 4 -or
    $manifest.packageKind -ne 'compiled' -or
    $manifest.version -ne $version -or
    $manifest.platform -ne 'windows-x64' -or
    $manifest.autoHotkey -ne $toolLock.tools.autoHotkey.version -or
    $manifest.autoHotkeyExecutableSha256 -ne `
        $toolLock.tools.autoHotkey.executableSha256 -or
    $manifest.autoHotkeySourceCommit -ne `
        $toolLock.tools.autoHotkey.sourceCommit -or
    $manifest.autoHotkeySourceSha256 -ne `
        $toolLock.tools.autoHotkey.sourceSha256 -or
    $manifest.ahk2Exe -ne $toolLock.tools.ahk2Exe.version -or
    $manifest.ahk2ExeExecutableSha256 -ne `
        $toolLock.tools.ahk2Exe.executableSha256 -or
    $manifest.sourceEntry -cne $mainScript.Name -or
    $executable.BaseName -cne $mainScript.BaseName) {
    throw 'Release build manifest is inconsistent.'
}
$updateManifest = Get-Content -LiteralPath `
    (Join-Path $packageRoot 'update-manifest.json') -Raw -Encoding UTF8 |
    ConvertFrom-Json
if ($updateManifest.schemaVersion -ne 1 -or
    $updateManifest.packageKind -ne 'compiled' -or
    $updateManifest.version -ne $version -or
    $updateManifest.entry -cne $executable.Name -or
    'watchdog.ini' -in $updateManifest.managedPaths -or
    'watchdog.maintenance.ini' -in $updateManifest.managedPaths) {
    throw 'Compiled update manifest is unsafe or inconsistent.'
}
$expectedCompiledManagedPaths = @(
    $executable.Name,
    'README.md', 'CHANGELOG.md', 'LICENSE', 'VERSION',
    '.github', 'assets', 'build-manifest.json', 'build-metadata', 'config',
    'docs', 'licenses', 'runtime', 'SBOM.spdx.json', 'tests', 'third_party',
    'update-manifest.json'
)
$compiledManagedDifference = @(Compare-Object -CaseSensitive `
    -ReferenceObject $expectedCompiledManagedPaths `
    -DifferenceObject @($updateManifest.managedPaths))
if ($compiledManagedDifference.Count -ne 0 -or
    @($updateManifest.managedPaths).Count -ne
        $expectedCompiledManagedPaths.Count) {
    throw 'Compiled update manifest does not manage the complete package layout.'
}
$sbom = Get-Content -LiteralPath (Join-Path $packageRoot 'SBOM.spdx.json') `
    -Raw -Encoding UTF8 | ConvertFrom-Json
if ($sbom.spdxVersion -ne 'SPDX-2.3') {
    throw 'Release SPDX SBOM is invalid or incomplete.'
}
$commercialFontLicense = $sbom.hasExtractedLicensingInfos |
    Where-Object {
        $_.licenseId -eq 'LicenseRef-Commercial-Apple-Fonts'
    } | Select-Object -First 1
if (-not $commercialFontLicense -or
    [string]::IsNullOrWhiteSpace([string]$commercialFontLicense.extractedText)) {
    throw 'Release SBOM does not define the commercial font LicenseRef.'
}
$expectedPackageNames = @(
    'process-watchdog',
    'resvg C API',
    'Everything SDK DLL',
    'Apple SD Gothic Neo',
    'Harano Aji Gothic',
    'Noto Sans',
    'Noto Sans CJK',
    'PingFang',
    'SF Pro Text Bold',
    'SF Pro Text Regular',
    'AutoHotkey',
    'Ahk2Exe',
    'actionlint',
    'gitleaks',
    'Lucide Icons'
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
$gitleaksPackage = $sbom.packages |
    Where-Object { $_.name -eq 'gitleaks' } | Select-Object -First 1
if ($autoHotkeyPackage.licenseDeclared -ne `
        'GPL-2.0-only AND BSD-3-Clause' -or
    $autoHotkeyPackage.checksums[0].checksumValue -ne `
        $toolLock.tools.autoHotkey.sha256 -or
    $ahk2ExePackage.licenseDeclared -ne 'WTFPL' -or
    $ahk2ExePackage.checksums[0].checksumValue -ne `
        $toolLock.tools.ahk2Exe.sha256 -or
    $actionlintPackage.licenseDeclared -ne 'MIT' -or
    $actionlintPackage.checksums[0].checksumValue -ne `
        $toolLock.tools.actionlint.sha256 -or
    $gitleaksPackage.licenseDeclared -ne 'MIT' -or
    $gitleaksPackage.checksums[0].checksumValue -ne `
        $toolLock.tools.gitleaks.sha256) {
    throw 'Release SPDX SBOM toolchain provenance is inconsistent.'
}
$autoHotkeyLicensePath = Join-Path $packageRoot `
    'licenses\AutoHotkey-LICENSE.txt'
if ((Get-FileHash -Algorithm SHA256 `
        -LiteralPath $autoHotkeyLicensePath).Hash -ne `
        $toolLock.tools.autoHotkey.licenseSha256) {
    throw 'Packaged AutoHotkey license hash is inconsistent.'
}
$autoHotkeySourcePath = Join-Path $packageRoot `
    $autoHotkeySourceRelativePath
if ((Get-FileHash -Algorithm SHA256 `
        -LiteralPath $autoHotkeySourcePath).Hash -ne `
        $toolLock.tools.autoHotkey.sourceSha256) {
    throw 'Packaged AutoHotkey source archive hash is inconsistent.'
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
# 同时核对文件、来源元数据和 SBOM 三个视角，防止只替换字体文件却忘记更新
# 哈希或许可证声明。
$fontMetadata = Get-Content -LiteralPath `
    (Join-Path $packageRoot 'assets\fonts\metadata.json') `
    -Raw -Encoding UTF8 | ConvertFrom-Json
if ($fontMetadata.schemaVersion -ne 1 -or $fontMetadata.fonts.Count -ne 7) {
    throw 'Packaged font metadata is invalid or incomplete.'
}
foreach ($font in $fontMetadata.fonts) {
    $fontPath = Join-Path $packageRoot `
        ([string]$font.path -replace '/', '\')
    $fontLicense = [string]$font.license
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $fontPath).Hash -ne `
            [string]$font.sha256 -or
        $fontLicense -notin @('OFL-1.1',
            'LicenseRef-Commercial-Apple-Fonts') -or
        ($fontLicense -eq 'LicenseRef-Commercial-Apple-Fonts' -and
            [string]::IsNullOrWhiteSpace([string]$font.authorization))) {
        throw "Packaged font provenance mismatch: $($font.name)"
    }
    $fontPackage = $sbom.packages |
        Where-Object { $_.name -eq [string]$font.name } |
        Select-Object -First 1
    if (-not $fontPackage -or
        $fontPackage.checksums[0].checksumValue -ne [string]$font.sha256 -or
        $fontPackage.licenseDeclared -ne $fontLicense) {
        throw "Packaged font SBOM entry mismatch: $($font.name)"
    }
    Test-FontMetadataFamilies -Root $packageRoot -Font $font
}
$expectedFontAssetNames = @(
    'AppleSDGothicNeo-Regular.ttf',
    'COMMERCIAL-LICENSE-NOTICE.en.md',
    'COMMERCIAL-LICENSE-NOTICE.md',
    'HaranoAjiGothic-Regular.otf',
    'NotoSans-Variable.ttf',
    'NotoSansCJK.ttc',
    'PingFang.ttc',
    'SF-Pro-Text-Bold.otf',
    'SF-Pro-Text-Regular.otf',
    'metadata.json',
    'OFL-1.1.txt',
    'README.en.md',
    'README.md'
)
$actualFontAssetNames = @(Get-ChildItem -LiteralPath `
    (Join-Path $packageRoot 'assets\fonts') -File | ForEach-Object Name |
    Sort-Object)
$fontAssetDifference = @(Compare-Object -CaseSensitive `
    -ReferenceObject ($expectedFontAssetNames | Sort-Object) `
    -DifferenceObject $actualFontAssetNames)
if ($fontAssetDifference.Count -ne 0 -or
    $actualFontAssetNames.Count -ne $expectedFontAssetNames.Count) {
    throw 'Release package contains a missing or unapproved font asset.'
}

$sourceRoot = [System.IO.Path]::GetFullPath($SourcePackageDirectory)
if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
    throw "Source release directory does not exist: $sourceRoot"
}
foreach ($relativePath in @(
        $mainScript.Name, 'VERSION', 'LICENSE', 'README.md',
        'app\ApplicationState.ahk', 'src\Core\GuardRuntime.ahk',
        'src\Update\ApplicationVersionInfo.ahk',
        'runtime\application-update.ps1',
        'runtime\application-update.strings.json',
        'runtime\standalone-install.ps1',
        'runtime\standalone-launcher.ahk',
        'tools\build-release.ps1',
        'tools\invoke-startup-validation.ps1',
        'third_party\resvg\resvg.dll', 'update-manifest.json')) {
    if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot $relativePath))) {
        throw "Source release package is missing: $relativePath"
    }
}
if (Get-ChildItem -LiteralPath $sourceRoot -File -Filter '*.exe') {
    throw 'Source release package contains a root executable.'
}
$sourceFontDirectory = Join-Path $sourceRoot 'assets\fonts'
$sourceFontMetadataPath = Join-Path $sourceFontDirectory 'metadata.json'
$sourceFontAssetNames = @(Get-ChildItem -LiteralPath $sourceFontDirectory -File |
    ForEach-Object Name | Sort-Object)
$sourceFontAssetDifference = @(Compare-Object -CaseSensitive `
    -ReferenceObject ($expectedFontAssetNames | Sort-Object) `
    -DifferenceObject $sourceFontAssetNames)
if ($sourceFontAssetDifference.Count -ne 0 -or
    $sourceFontAssetNames.Count -ne $expectedFontAssetNames.Count) {
    throw 'Source release package contains a missing or unapproved font asset.'
}
$sourceFontMetadata = Get-Content -LiteralPath $sourceFontMetadataPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($sourceFontMetadata.schemaVersion -ne 1 -or
    $sourceFontMetadata.fonts.Count -ne 7) {
    throw 'Source font metadata is invalid or incomplete.'
}
foreach ($font in $sourceFontMetadata.fonts) {
    $sourceFontPath = Join-Path $sourceRoot ([string]$font.path -replace '/', '\')
    $sourceFontHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourceFontPath).Hash
    if ($sourceFontHash -ne [string]$font.sha256) {
        throw "Source font provenance mismatch: $($font.name)"
    }
    Test-FontMetadataFamilies -Root $sourceRoot -Font $font
}
foreach ($forbiddenPath in @('watchdog.ini', 'watchdog.maintenance.ini',
        '.git', '.tools', 'dist')) {
    if (Test-Path -LiteralPath (Join-Path $sourceRoot $forbiddenPath)) {
        throw "Source release contains local or generated state: $forbiddenPath"
    }
}
$sourceVersion = (Get-Content -LiteralPath `
    (Join-Path $sourceRoot 'VERSION') -Raw -Encoding UTF8).Trim()
$sourceUpdateManifest = Get-Content -LiteralPath `
    (Join-Path $sourceRoot 'update-manifest.json') -Raw -Encoding UTF8 |
    ConvertFrom-Json
if ($sourceVersion -ne $version -or
    $sourceUpdateManifest.schemaVersion -ne 1 -or
    $sourceUpdateManifest.packageKind -ne 'source' -or
    $sourceUpdateManifest.version -ne $version -or
    $sourceUpdateManifest.entry -cne $mainScript.Name -or
    'watchdog.ini' -in $sourceUpdateManifest.managedPaths -or
    'watchdog.maintenance.ini' -in $sourceUpdateManifest.managedPaths) {
    throw 'Source update manifest is unsafe or inconsistent.'
}
$expectedSourceManagedPaths = @(
    $mainScript.Name, 'README.md', 'CHANGELOG.md', 'LICENSE', 'VERSION',
    '.github', 'app', 'assets', 'config', 'docs', 'runtime', 'src', 'tests',
    'third_party', 'tools', 'update-manifest.json'
)
$sourceManagedDifference = @(Compare-Object -CaseSensitive `
    -ReferenceObject $expectedSourceManagedPaths `
    -DifferenceObject @($sourceUpdateManifest.managedPaths))
if ($sourceManagedDifference.Count -ne 0 -or
    @($sourceUpdateManifest.managedPaths).Count -ne
        $expectedSourceManagedPaths.Count) {
    throw 'Source update manifest does not manage the complete package layout.'
}

Write-Host "Release package verification passed for $version."
