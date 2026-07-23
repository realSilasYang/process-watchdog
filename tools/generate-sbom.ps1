[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$version = (Get-Content -LiteralPath (Join-Path $projectRoot 'VERSION') `
    -Raw -Encoding UTF8).Trim()
$dependencyLock = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'third_party\dependencies.lock.json') `
    -Raw -Encoding UTF8 | ConvertFrom-Json
$toolchainLock = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'tools\toolchain.lock.json') `
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
    name = 'Google Material Symbols Rounded'
    versionInfo = 'NOASSERTION'
    downloadLocation = 'https://github.com/google/material-design-icons'
    filesAnalyzed = $false
    licenseConcluded = 'Apache-2.0'
    licenseDeclared = 'Apache-2.0'
    copyrightText = 'Copyright Google LLC'
    comment = 'Status icon geometry was redrawn for this project; the exact upstream revision is not embedded.'
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
}

$parentDirectory = Split-Path -Parent ([System.IO.Path]::GetFullPath($OutputPath))
if ($parentDirectory) {
    New-Item -ItemType Directory -Force -Path $parentDirectory | Out-Null
}
$document | ConvertTo-Json -Depth 8 |
    Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host "SPDX SBOM: $OutputPath"
