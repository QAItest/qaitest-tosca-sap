[CmdletBinding()]
param(
    [string[]]$Keys,
    [string]$OutputDirectory = "features",
    [string]$BaseUrl = $env:XRAY_BASE_URL,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "XrayCloud.ps1")

if (-not $Keys -or $Keys.Count -eq 0) {
    $Keys = @($env:XRAY_TEST_KEYS -split '[,;\s]+' | Where-Object { $_ })
}
if (-not $Keys -or $Keys.Count -eq 0) {
    throw "Provide -Keys or set XRAY_TEST_KEYS."
}

foreach ($key in $Keys) {
    if ($key -notmatch '^[A-Z][A-Z0-9_]+-\d+$') {
        throw "'$key' is not a valid Jira issue key."
    }
}

$apiBaseUrl = Get-XrayCloudBaseUrl -BaseUrl $BaseUrl
$encodedKeys = [System.Uri]::EscapeDataString(($Keys -join ";"))
$endpoint = "$apiBaseUrl/export/cucumber?keys=$encodedKeys"

if ($DryRun) {
    Write-Host "Xray feature export validated for $($Keys.Count) key(s): $endpoint"
    return
}

$token = Get-XrayCloudToken -BaseUrl $apiBaseUrl
$resolvedOutput = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    [System.IO.Path]::GetFullPath($OutputDirectory)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $OutputDirectory))
}

New-Item -ItemType Directory -Path $resolvedOutput -Force | Out-Null
$archive = Join-Path ([System.IO.Path]::GetTempPath()) "xray-features-$([guid]::NewGuid()).zip"

try {
    Invoke-WebRequest `
        -Uri $endpoint `
        -Method Get `
        -Headers @{ Authorization = "Bearer $token"; Accept = "application/zip" } `
        -OutFile $archive
    Expand-Archive -LiteralPath $archive -DestinationPath $resolvedOutput -Force
} finally {
    if (Test-Path -LiteralPath $archive) {
        Remove-Item -LiteralPath $archive -Force
    }
}

$exportedFeatures = @(Get-ChildItem -LiteralPath $resolvedOutput -Recurse -Filter "*.feature")
if ($exportedFeatures.Count -eq 0) {
    throw "Xray returned no .feature files."
}

Write-Host "Exported $($exportedFeatures.Count) Xray feature file(s) to '$resolvedOutput'."
