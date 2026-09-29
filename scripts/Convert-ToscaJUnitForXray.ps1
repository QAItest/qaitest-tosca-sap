[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$InputPath,
    [Parameter(Mandatory)]
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"
$resolvedInput = [System.IO.Path]::GetFullPath($InputPath)
$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)

if (-not (Test-Path -LiteralPath $resolvedInput -PathType Leaf)) {
    throw "JUnit report was not found at '$resolvedInput'."
}

try {
    [xml]$document = Get-Content -LiteralPath $resolvedInput -Raw
} catch {
    throw "JUnit report '$resolvedInput' is not valid XML: $($_.Exception.Message)"
}

$mapped = 0
foreach ($testCase in @($document.SelectNodes("//*[local-name()='testcase']"))) {
    $identity = "$($testCase.GetAttribute('name')) $($testCase.GetAttribute('classname'))"
    $match = [regex]::Match($identity, '(?<![A-Z0-9_])([A-Z][A-Z0-9_]+-\d+)(?!\d)')
    if (-not $match.Success) {
        continue
    }

    $properties = $testCase.SelectSingleNode("./*[local-name()='properties']")
    if (-not $properties) {
        $properties = $document.CreateElement("properties")
        if ($testCase.FirstChild) {
            [void]$testCase.InsertBefore($properties, $testCase.FirstChild)
        } else {
            [void]$testCase.AppendChild($properties)
        }
    }

    $existing = $properties.SelectSingleNode("./*[local-name()='property' and @name='test_key']")
    if (-not $existing) {
        $property = $document.CreateElement("property")
        $property.SetAttribute("name", "test_key")
        $property.SetAttribute("value", $match.Groups[1].Value)
        [void]$properties.AppendChild($property)
    } else {
        $existing.SetAttribute("value", $match.Groups[1].Value)
    }
    $mapped++
}

if ($mapped -eq 0) {
    throw "No Jira issue key was found in the JUnit testcase names or class names."
}

$outputDirectory = Split-Path -Parent $resolvedOutput
if ($outputDirectory) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}
$document.Save($resolvedOutput)
Write-Host "Mapped $mapped Tosca testcase(s) to Xray test_key properties in '$resolvedOutput'."
