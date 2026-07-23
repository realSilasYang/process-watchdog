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

$document = [ordered]@{
    spdxVersion = 'SPDX-2.3'
    dataLicense = 'CC0-1.0'
    SPDXID = 'SPDXRef-DOCUMENT'
    name = "process-watchdog-$version-windows-x64"
    documentNamespace = "https://spdx.org/spdxdocs/process-watchdog-$version-windows-x64"
    creationInfo = [ordered]@{
        created = '2026-07-23T00:00:00Z'
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
