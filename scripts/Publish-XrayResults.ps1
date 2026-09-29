[CmdletBinding()]
param(
    [string]$ResultPath = "reports/tosca-results.xml",
    [string]$ProjectKey = $env:XRAY_PROJECT_KEY,
    [string]$TestPlanKey = $env:XRAY_TEST_PLAN_KEY,
    [string]$TestExecutionKey = $env:XRAY_TEST_EXECUTION_KEY,
    [string]$TestEnvironment = $env:XRAY_TEST_ENVIRONMENT,
    [string]$FixVersion = $env:XRAY_FIX_VERSION,
    [string]$Revision = $env:XRAY_REVISION,
    [string]$BaseUrl = $env:XRAY_BASE_URL,
    [switch]$SkipKeyEnrichment,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "XrayCloud.ps1")

if ([string]::IsNullOrWhiteSpace($ProjectKey) -or $ProjectKey -notmatch '^[A-Z][A-Z0-9_]+$') {
    throw "Set XRAY_PROJECT_KEY or provide a valid -ProjectKey."
}

$resolvedResult = if ([System.IO.Path]::IsPathRooted($ResultPath)) {
    [System.IO.Path]::GetFullPath($ResultPath)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $ResultPath))
}
if (-not (Test-Path -LiteralPath $resolvedResult -PathType Leaf)) {
    throw "JUnit report was not found at '$resolvedResult'."
}

try {
    [xml](Get-Content -LiteralPath $resolvedResult -Raw) | Out-Null
} catch {
    throw "JUnit report '$resolvedResult' is not valid XML: $($_.Exception.Message)"
}

$uploadPath = $resolvedResult
if (-not $SkipKeyEnrichment) {
    $uploadPath = Join-Path (Split-Path -Parent $resolvedResult) "xray-tosca-results.xml"
    & (Join-Path $PSScriptRoot "Convert-ToscaJUnitForXray.ps1") `
        -InputPath $resolvedResult `
        -OutputPath $uploadPath
}

$query = ConvertTo-XrayQueryString -Parameters @{
    projectKey = $ProjectKey
    testPlanKey = $TestPlanKey
    testExecKey = $TestExecutionKey
    testEnvironment = $TestEnvironment
    fixVersion = $FixVersion
    revision = $Revision
}
$apiBaseUrl = Get-XrayCloudBaseUrl -BaseUrl $BaseUrl
$endpoint = "$apiBaseUrl/import/execution/junit?$query"

if ($DryRun) {
    Write-Host "Xray JUnit publication validated: $endpoint"
    return
}

$token = Get-XrayCloudToken -BaseUrl $apiBaseUrl
$response = Invoke-RestMethod `
    -Uri $endpoint `
    -Method Post `
    -Headers @{ Authorization = "Bearer $token"; Accept = "application/json" } `
    -ContentType "application/xml" `
    -InFile $uploadPath

$responsePath = Join-Path (Split-Path -Parent $resolvedResult) "xray-response.json"
$response | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $responsePath -Encoding utf8

$executionKey = "unknown"
if ($response.PSObject.Properties["key"]) {
    $executionKey = $response.key
} elseif (
    $response.PSObject.Properties["testExecIssue"] -and
    $response.testExecIssue.PSObject.Properties["key"]
) {
    $executionKey = $response.testExecIssue.key
}
Write-Host "Published Tosca results to Xray Test Execution '$executionKey'."
