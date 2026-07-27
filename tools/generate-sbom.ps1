# SPDX 软件物料清单生成脚本。
# 汇总项目、运行时和随包第三方组件的版本、许可证、来源与哈希，生成可独立核验的 JSON。

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,
    [Parameter(Mandatory = $true)]
    [string]$ResolvedToolchainPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$version = (Get-Content -LiteralPath (Join-Path $projectRoot 'VERSION') `
    -Raw -Encoding UTF8).Trim()
$dependencyLock = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'third_party\dependencies.lock.json') `
    -Raw -Encoding UTF8 | ConvertFrom-Json
$fontMetadata = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'assets\fonts\metadata.json') `
    -Raw -Encoding UTF8 | ConvertFrom-Json
$toolchainLock = Get-Content -LiteralPath $ResolvedToolchainPath `
    -Raw -Encoding UTF8 | ConvertFrom-Json
$changeLog = Get-Content -LiteralPath (Join-Path $projectRoot 'CHANGELOG.md') `
    -Raw -Encoding UTF8
$releaseHeadingPattern = '(?m)^## \[' + [regex]::Escape($version) +
    '\] - (\d{4}-\d{2}-\d{2})\r?$'
$releaseHeading = [regex]::Match($changeLog, $releaseHeadingPattern)
if (-not $releaseHeading.Success) {
    throw "CHANGELOG.md does not declare a release date for $version."
}
$releaseTimestamp = $releaseHeading.Groups[1].Value + 'T00:00:00Z'

$packages = @()
$relationships = @()
$applicationId = 'SPDXRef-Application'
$packages += [ordered]@{
    SPDXID = $applicationId
    name = 'process-watchdog'
    versionInfo = $version
    downloadLocation = 'NOASSERTION'
    filesAnalyzed = $false
    licenseConcluded = 'MIT'
    licenseDeclared = 'MIT'
    copyrightText = 'Copyright (c) 2026 process-watchdog contributors'
}
$relationships += [ordered]@{
    spdxElementId = 'SPDXRef-DOCUMENT'
    relationshipType = 'DESCRIBES'
    relatedSpdxElement = $applicationId
}

$index = 0
foreach ($dependency in $dependencyLock.dependencies) {
    $index++
    $dependencyId = "SPDXRef-Dependency-$index"
    $licenseExpression = ($dependency.licenses -join ' OR ')
    $packages += [ordered]@{
        SPDXID = $dependencyId
        name = [string]$dependency.name
        versionInfo = [string]$dependency.version
        downloadLocation = [string]$dependency.source
        filesAnalyzed = $false
        licenseConcluded = $licenseExpression
        licenseDeclared = $licenseExpression
        copyrightText = 'NOASSERTION'
        checksums = @([ordered]@{
            algorithm = 'SHA256'
            checksumValue = [string]$dependency.sha256
        })
    }
    $relationships += [ordered]@{
        spdxElementId = $applicationId
        relationshipType = 'DEPENDS_ON'
        relatedSpdxElement = $dependencyId
    }
}

# 字体虽然位于 assets 而不是 third_party，但会随程序运行并影响界面输出，必须像
# DLL 一样进入物料清单，避免发行包只校验二进制库却遗漏大体积字体资源。
foreach ($font in $fontMetadata.fonts) {
    $index++
    $fontId = "SPDXRef-Font-$index"
    $packages += [ordered]@{
        SPDXID = $fontId
        name = [string]$font.name
        versionInfo = [string]$font.version
        downloadLocation = [string]$font.source
        filesAnalyzed = $false
        licenseConcluded = [string]$font.license
        licenseDeclared = [string]$font.license
        copyrightText = [string]$font.copyright
        comment = if ($font.PSObject.Properties.Name -contains
                'authorization') {
            [string]$font.authorization
        } else {
            'Open font distributed with its complete license text.'
        }
        checksums = @([ordered]@{
            algorithm = 'SHA256'
            checksumValue = [string]$font.sha256
        })
    }
    $relationships += [ordered]@{
        spdxElementId = $applicationId
        relationshipType = 'DEPENDS_ON'
        relatedSpdxElement = $fontId
    }
}

$toolPackages = @(
    [ordered]@{
        Definition = $toolchainLock.tools.autoHotkey
        Name = 'AutoHotkey'
        Copyright = 'Copyright AutoHotkey Foundation LLC and contributors'
    },
    [ordered]@{
        Definition = $toolchainLock.tools.ahk2Exe
        Name = 'Ahk2Exe'
        Copyright = 'Copyright Ahk2Exe contributors'
    },
    [ordered]@{
        Definition = $toolchainLock.tools.actionlint
        Name = 'actionlint'
        Copyright = 'Copyright actionlint contributors'
    },
    [ordered]@{
        Definition = $toolchainLock.tools.gitleaks
        Name = 'gitleaks'
        Copyright = 'Copyright Gitleaks contributors'
    }
)
foreach ($toolPackage in $toolPackages) {
    $index++
    $toolId = "SPDXRef-Tool-$index"
    $definition = $toolPackage.Definition
    $licenseExpression = [string]$definition.licenseExpression
    $packages += [ordered]@{
        SPDXID = $toolId
        name = $toolPackage.Name
        versionInfo = [string]$definition.version
        downloadLocation = [string]$definition.url
        filesAnalyzed = $false
        licenseConcluded = $licenseExpression
        licenseDeclared = $licenseExpression
        copyrightText = $toolPackage.Copyright
        comment = if ($toolPackage.Name -eq 'AutoHotkey') {
            "Corresponding source commit $($definition.sourceCommit) is included in the release package; source archive SHA-256 $($definition.sourceSha256)."
        } else {
            'Used only while building or verifying the project; not included in the runtime distribution.'
        }
        checksums = @([ordered]@{
            algorithm = 'SHA256'
            checksumValue = [string]$definition.sha256
        })
    }
    if ($definition.sbomRelationship -in @('BUILD_TOOL_OF',
            'TEST_TOOL_OF')) {
        $relationships += [ordered]@{
            spdxElementId = $toolId
            relationshipType = [string]$definition.sbomRelationship
            relatedSpdxElement = $applicationId
        }
    } else {
        $relationships += [ordered]@{
            spdxElementId = $applicationId
            relationshipType = [string]$definition.sbomRelationship
            relatedSpdxElement = $toolId
        }
    }
}

$iconSourceId = 'SPDXRef-IconSource'
$packages += [ordered]@{
    SPDXID = $iconSourceId
    name = 'Lucide Icons'
    versionInfo = '1.27.0'
    downloadLocation = 'https://github.com/lucide-icons/lucide/releases/tag/1.27.0'
    filesAnalyzed = $false
    licenseConcluded = 'ISC AND MIT'
    licenseDeclared = 'ISC AND MIT'
    copyrightText = 'Copyright Lucide Icons contributors and Feather contributors'
    comment = 'Selected SVG geometry is unchanged; the project applies fixed semantic colors. The administrator badge is loaded from the Windows Shell and is not packaged. Selected Feather-derived icons retain the MIT license.'
}
$relationships += [ordered]@{
    spdxElementId = $applicationId
    relationshipType = 'GENERATED_FROM'
    relatedSpdxElement = $iconSourceId
}

$document = [ordered]@{
    spdxVersion = 'SPDX-2.3'
    dataLicense = 'CC0-1.0'
    SPDXID = 'SPDXRef-DOCUMENT'
    name = "process-watchdog-$version-windows-x64"
    documentNamespace = "https://spdx.org/spdxdocs/process-watchdog-$version-windows-x64"
    creationInfo = [ordered]@{
        created = $releaseTimestamp
        creators = @('Tool: process-watchdog-generate-sbom.ps1')
    }
    packages = $packages
    relationships = $relationships
    hasExtractedLicensingInfos = @([ordered]@{
        licenseId = 'LicenseRef-Commercial-Apple-Fonts'
        name = 'Commercial Apple font redistribution authorization'
        extractedText = 'The project owner has confirmed commercial authorization to distribute the identified PingFang, SF Pro Text, and Apple SD Gothic Neo files as components of Process Watchdog. The project license does not grant recipients separate extraction, resale, sublicensing, or reuse rights for these fonts.'
        comment = 'The underlying commercial agreement contains non-public terms. Exact files and hashes are recorded in assets/fonts/metadata.json; the public boundary is documented in assets/fonts/COMMERCIAL-LICENSE-NOTICE.en.md.'
    })
}

$parentDirectory = Split-Path -Parent ([System.IO.Path]::GetFullPath($OutputPath))
if ($parentDirectory) {
    New-Item -ItemType Directory -Force -Path $parentDirectory | Out-Null
}
$json = $document | ConvertTo-Json -Depth 8 -Compress
[System.IO.File]::WriteAllText($OutputPath, $json + "`r`n",
    [System.Text.UTF8Encoding]::new($false))
Write-Host "SPDX SBOM: $OutputPath"
