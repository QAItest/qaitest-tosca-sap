[CmdletBinding()]
param(
    [ValidateSet("local", "distributed")]
    [string]$Mode = "distributed",
    [string]$Endpoint = $env:TOSCA_EXECUTION_ENDPOINT,
    [string]$ClientPath = $env:TOSCA_CI_CLIENT_PATH,
    [string]$ConfigurationPath = "ci/CITestExecutionConfiguration.xml",
    [string]$ResultPath = "reports/tosca-results.xml"
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Resolve-RepositoryPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $Path))
}

if ([string]::IsNullOrWhiteSpace($ClientPath) -and $env:COMMANDER_HOME) {
    $ClientPath = Join-Path $env:COMMANDER_HOME "ToscaCI/Client/ToscaCIClient.exe"
}

if ([string]::IsNullOrWhiteSpace($ClientPath)) {
    throw "Set TOSCA_CI_CLIENT_PATH or COMMANDER_HOME before running Tosca tests."
}

$resolvedClient = Resolve-RepositoryPath $ClientPath
$resolvedConfiguration = Resolve-RepositoryPath $ConfigurationPath
$resolvedResult = Resolve-RepositoryPath $ResultPath

if (-not (Test-Path -LiteralPath $resolvedClient -PathType Leaf)) {
    throw "Tosca CI Client was not found at '$resolvedClient'."
}

if (-not (Test-Path -LiteralPath $resolvedConfiguration -PathType Leaf)) {
    throw "Execution configuration was not found at '$resolvedConfiguration'."
}

if ($Mode -eq "distributed" -and [string]::IsNullOrWhiteSpace($Endpoint)) {
    throw "TOSCA_EXECUTION_ENDPOINT or -Endpoint is required in distributed mode."
}

$resultDirectory = Split-Path -Parent $resolvedResult
New-Item -ItemType Directory -Path $resultDirectory -Force | Out-Null

$arguments = @(
    "-m", $Mode,
    "-c", $resolvedConfiguration,
    "-r", $resolvedResult,
    "-x", "True",
    "-t", "junit"
)

if ($Mode -eq "distributed") {
    $arguments += @("-e", $Endpoint)
}

Write-Host "Running Tosca '$Mode' execution. Results: $resolvedResult"
& $resolvedClient @arguments
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    throw "Tosca CI Client exited with code $exitCode."
}

if (-not (Test-Path -LiteralPath $resolvedResult -PathType Leaf)) {
    throw "Tosca CI Client completed without creating '$resolvedResult'."
}

Write-Host "Tosca execution completed successfully."
