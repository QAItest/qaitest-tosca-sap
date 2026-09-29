[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()

function Add-Failure([string]$Message) {
    $failures.Add($Message)
}

$executionConfiguration = Join-Path $repositoryRoot "ci/CITestExecutionConfiguration.xml"
try {
    [xml]$configuration = Get-Content -LiteralPath $executionConfiguration -Raw
    $selection = @($configuration.testConfiguration.customProperties.property)
    if (-not ($selection | Where-Object { $_.name -eq "SAPSmoke" -and $_."#text" -eq "True" })) {
        Add-Failure "The CI configuration must select SAPSmoke=True."
    }
} catch {
    Add-Failure "The CI execution configuration is invalid XML: $($_.Exception.Message)"
}

$requiredBlueprintColumns = @(
    "Order", "TestCase", "Module", "Control", "ActionMode", "Value", "ExpectedResult"
)

Get-ChildItem -LiteralPath (Join-Path $repositoryRoot "tosca/blueprints") -Filter "*.csv" |
    ForEach-Object {
        $rows = @(Import-Csv -LiteralPath $_.FullName)
        if ($rows.Count -eq 0) {
            Add-Failure "Blueprint '$($_.Name)' contains no steps."
            return
        }

        $columns = @($rows[0].PSObject.Properties.Name)
        foreach ($column in $requiredBlueprintColumns) {
            if ($column -notin $columns) {
                Add-Failure "Blueprint '$($_.Name)' is missing column '$column'."
            }
        }
    }

$tcpFile = Join-Path $repositoryRoot "config/test-configuration-parameters.example.csv"
$parameters = @(Import-Csv -LiteralPath $tcpFile)
$requiredParameters = @(
    "SAP_CONNECTION", "SAP_CLIENT", "SAP_LANGUAGE", "SAP_USERNAME", "SAP_PASSWORD", "SAP_FIORI_URL"
)
foreach ($parameter in $requiredParameters) {
    if ($parameter -notin @($parameters.Name)) {
        Add-Failure "Missing Test Configuration Parameter '$parameter'."
    }
}

$passwordParameter = $parameters | Where-Object Name -eq "SAP_PASSWORD"
if (-not $passwordParameter -or $passwordParameter.Secret -ne "true" -or $passwordParameter.ExampleValue -notmatch '^\{SECRET\[') {
    Add-Failure "SAP_PASSWORD must be marked secret and use a {SECRET[...]} expression."
}

Get-ChildItem -LiteralPath (Join-Path $repositoryRoot "features") -Filter "*.feature" |
    ForEach-Object {
        $content = Get-Content -LiteralPath $_.FullName -Raw
        if ($content -notmatch '@SAP-\d+' -or $content -notmatch '@sap') {
            Add-Failure "Feature '$($_.Name)' must contain a SAP test key and the @sap tag."
        }
    }

$trackedTextFiles = Get-ChildItem -LiteralPath $repositoryRoot -Recurse -File |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' -and $_.Extension -in @(".md", ".csv", ".xml", ".feature", ".ps1", ".yml", ".yaml") }
foreach ($file in $trackedTextFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    if ($content -match '(?i)(password|passwd|pwd)\s*[=:]\s*(?!\{SECRET|change-me|example)[^\s,]+') {
        Add-Failure "Potential plaintext password found in '$($file.FullName)'."
    }
}

$temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "qaitest-tosca-xray-$([guid]::NewGuid())"
try {
    New-Item -ItemType Directory -Path $temporaryDirectory -Force | Out-Null
    $fixture = Join-Path $repositoryRoot "tests/fixtures/tosca-results.xml"
    $temporaryReport = Join-Path $temporaryDirectory "tosca-results.xml"
    Copy-Item -LiteralPath $fixture -Destination $temporaryReport

    & (Join-Path $PSScriptRoot "Publish-XrayResults.ps1") `
        -ResultPath $temporaryReport `
        -ProjectKey "SAP" `
        -DryRun
    & (Join-Path $PSScriptRoot "Export-XrayFeatures.ps1") -Keys "SAP-001" -DryRun
    & (Join-Path $PSScriptRoot "Import-XrayFeatures.ps1") `
        -InputPath (Join-Path $repositoryRoot "features") `
        -ProjectKey "SAP" `
        -DryRun

    [xml]$enrichedReport = Get-Content -LiteralPath (Join-Path $temporaryDirectory "xray-tosca-results.xml") -Raw
    $mappedKey = $enrichedReport.SelectSingleNode("//*[local-name()='property' and @name='test_key']")
    if (-not $mappedKey -or $mappedKey.value -ne "SAP-001") {
        Add-Failure "Tosca JUnit to Xray test_key conversion failed."
    }
} catch {
    Add-Failure "Xray integration validation failed: $($_.Exception.Message)"
} finally {
    if (Test-Path -LiteralPath $temporaryDirectory) {
        Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "Template validation passed."
