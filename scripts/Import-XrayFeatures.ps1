[CmdletBinding()]
param(
    [string]$InputPath = "features",
    [string]$ProjectKey = $env:XRAY_PROJECT_KEY,
    [string]$BaseUrl = $env:XRAY_BASE_URL,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "XrayCloud.ps1")

if ([string]::IsNullOrWhiteSpace($ProjectKey) -or $ProjectKey -notmatch '^[A-Z][A-Z0-9_]+$') {
    throw "Set XRAY_PROJECT_KEY or provide a valid -ProjectKey."
}

$resolvedInput = if ([System.IO.Path]::IsPathRooted($InputPath)) {
    [System.IO.Path]::GetFullPath($InputPath)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $InputPath))
}
if (-not (Test-Path -LiteralPath $resolvedInput)) {
    throw "Feature input was not found at '$resolvedInput'."
}

$inputItem = Get-Item -LiteralPath $resolvedInput
$isArchive = -not $inputItem.PSIsContainer -and $inputItem.Extension -eq ".zip"
$featureFiles = @(
    if ($isArchive) {
        # The supplied archive is uploaded as-is.
    } elseif ($inputItem.PSIsContainer) {
        Get-ChildItem -LiteralPath $resolvedInput -Recurse -Filter "*.feature" -File
    } elseif ($inputItem.Extension -eq ".feature") {
        $inputItem
    } else {
        throw "Input must be a .feature file, a directory, or a ZIP archive."
    }
)
if (-not $isArchive -and $featureFiles.Count -eq 0) {
    throw "No .feature files were found in '$resolvedInput'."
}

$apiBaseUrl = Get-XrayCloudBaseUrl -BaseUrl $BaseUrl
$query = ConvertTo-XrayQueryString -Parameters @{ projectKey = $ProjectKey }
$endpoint = "$apiBaseUrl/import/feature?$query"

if ($DryRun) {
    $count = if ($isArchive) { "archive" } else { "$($featureFiles.Count) feature file(s)" }
    Write-Host "Xray feature import validated for $count`: $endpoint"
    return
}

$token = Get-XrayCloudToken -BaseUrl $apiBaseUrl
$temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "xray-import-$([guid]::NewGuid())"
$archive = if ($isArchive) { $resolvedInput } else { Join-Path $temporaryDirectory "features.zip" }

try {
    if (-not $isArchive) {
        $staging = Join-Path $temporaryDirectory "features"
        New-Item -ItemType Directory -Path $staging -Force | Out-Null

        foreach ($feature in $featureFiles) {
            $relativePath = if ($inputItem.PSIsContainer) {
                [System.IO.Path]::GetRelativePath($resolvedInput, $feature.FullName)
            } else {
                $feature.Name
            }
            $target = Join-Path $staging $relativePath
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            Copy-Item -LiteralPath $feature.FullName -Destination $target
        }

        Compress-Archive -Path (Join-Path $staging "*") -DestinationPath $archive -Force
    }

    $response = Invoke-RestMethod `
        -Uri $endpoint `
        -Method Post `
        -Headers @{ Authorization = "Bearer $token"; Accept = "application/json" } `
        -Form @{ file = Get-Item -LiteralPath $archive }

    $reportDirectory = Join-Path $repositoryRoot "reports"
    New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    $response | ConvertTo-Json -Depth 10 | Set-Content `
        -LiteralPath (Join-Path $reportDirectory "xray-feature-import-response.json") `
        -Encoding utf8
} finally {
    if (Test-Path -LiteralPath $temporaryDirectory) {
        Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force
    }
}

Write-Host "Imported feature definitions into Xray project '$ProjectKey'."
