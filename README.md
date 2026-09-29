# qaitest-tosca-sap

Reusable Tricentis Tosca template for SAP GUI and SAP Fiori test automation.

The repository keeps the reviewable parts of a Tosca project in Git and uses Tosca subsets for the
objects that must be created or scanned in Tosca Commander. It contains no licensed Tricentis
software, SAP application, internal endpoint, or credential.

## Included

- SAP login, smoke, business-flow, and logout blueprints
- SAP GUI and Fiori module design guidance
- environment and Test Configuration Parameter examples
- a Tosca CI execution filter and PowerShell runner
- Xray Cloud feature synchronization and JUnit result publication
- validation that runs without a Tosca license
- GitHub Actions, GitLab CI, and Jenkins examples
- folders for versioned `.tce` or `.tsu` subsets and JUnit results

## Repository layout

```text
qaitest-tosca-sap/
|-- .github/workflows/       GitHub Actions validation and execution
|-- ci/                      Tosca CI execution selection
|-- config/                  environment and TCP examples
|-- docs/                    Tosca Commander implementation guide
|-- features/                business-readable scenarios
|-- pipelines/               GitLab and Jenkins examples
|-- reports/                 generated JUnit results
|-- scripts/                 validation and Tosca CI launcher
|-- tests/                   integration-test fixtures
`-- tosca/
    |-- blueprints/          reviewable TestCase step definitions
    `-- subsets/             exported Tosca subsets
```

## Prerequisites

- Tricentis Tosca Commander and a valid license
- SAP GUI with the required client-side options for SAP GUI testing
- a browser and the appropriate XBrowser configuration for SAP Fiori
- access to a Tosca workspace and the SAP test environment
- a Windows execution agent with Tosca CI Client for automated execution

## Start a Tosca workspace

1. Create or open the target Tosca workspace.
2. Import the project subset from `tosca/subsets/` when one is available.
3. Follow [the workspace guide](docs/workspace-setup.md) to create or scan the Modules.
4. Create the Test Configuration Parameters listed in
   `config/test-configuration-parameters.example.csv`.
5. Build the TestCases from `tosca/blueprints/` and add them to an ExecutionList named
   `SAP Smoke`.
6. Set `ContinuousIntegration=True` and `SAPSmoke=True` on that ExecutionList.

Tosca subsets can contain TestCases, referenced Modules, and ExecutionLists. Project-root Test
Configuration Parameters are not included in a subset, which is why this repository documents them
separately.

## Login and logout

The example flow is intentionally parameterized:

- `{CP[SAP_CONNECTION]}` selects the SAP Logon connection.
- `{CP[SAP_CLIENT]}` and `{CP[SAP_LANGUAGE]}` select the client and language.
- `{CP[SAP_USERNAME]}` supplies the technical test user.
- `{SECRET[kv/sap/qa][password]}` represents a password resolved from a supported key vault.
- `{CP[SAP_FIORI_URL]}` supplies the Fiori Launchpad URL.

Never put a real password in a subset, CSV file, test result, or pipeline definition. Adapt the
secret path to the key vault configured on the execution agent.

## Validate the template

Validation does not require Tosca:

```powershell
pwsh -File scripts/Test-Template.ps1
```

It checks the execution-filter XML, blueprint columns, required configuration parameters, feature
tags, and secret hygiene.

## Run with Tosca CI Client

On a Windows agent where Tosca is installed:

```powershell
$env:TOSCA_CI_CLIENT_PATH = "C:\Program Files (x86)\TRICENTIS\Tosca Testsuite\ToscaCI\Client\ToscaCIClient.exe"

pwsh -File scripts/Invoke-ToscaTests.ps1 `
  -Mode distributed `
  -Endpoint "https://tosca-execution.example.test/TOSCARemoteExecutionService/"
```

For execution on the build agent, use `-Mode local` and omit `-Endpoint`. The wrapper passes the
execution filter, writes JUnit to `reports/tosca-results.xml`, and enables result-based exit codes.

Tosca CI Client is marked as a legacy feature in current Tricentis documentation. The wrapper keeps
that dependency isolated so it can be replaced by the execution service adopted by your Tosca
installation.

## Xray for Jira integration

The integration targets Xray Cloud REST API v2 and keeps credentials in environment variables or CI
secret stores.

Export Cucumber scenarios from existing Xray Test issues:

```powershell
$env:XRAY_CLIENT_ID = "..."
$env:XRAY_CLIENT_SECRET = "..."
pwsh -File scripts/Export-XrayFeatures.ps1 -Keys SAP-001,SAP-002
```

Synchronize the repository's feature definitions back to Xray:

```powershell
$env:XRAY_PROJECT_KEY = "SAP"
pwsh -File scripts/Import-XrayFeatures.ps1 -InputPath features
```

Publish the JUnit report created by Tosca CI Client:

```powershell
$env:XRAY_PROJECT_KEY = "SAP"
pwsh -File scripts/Publish-XrayResults.ps1
```

Before upload, `Convert-ToscaJUnitForXray.ps1` extracts Jira keys such as `SAP-001` from Tosca
TestCase names and adds Xray's `test_key` property. Name Tosca TestCases with the issue key in square
brackets, for example `[SAP-001] Login and logout`, to map results to existing Xray Tests.

Optional variables associate the run with existing Xray entities:

| Variable | Purpose |
| --- | --- |
| `XRAY_TEST_PLAN_KEY` | Link the Test Execution to a Test Plan |
| `XRAY_TEST_EXECUTION_KEY` | Update an existing Test Execution |
| `XRAY_TEST_ENVIRONMENT` | Assign a Test Environment |
| `XRAY_FIX_VERSION` | Assign a Jira fix version |
| `XRAY_REVISION` | Record the tested revision |
| `XRAY_TEST_KEYS` | Keys used by feature export |
| `XRAY_BASE_URL` | Override the default Cloud API v2 URL |

Use `-DryRun` on the export, import, or publish scripts to validate paths, keys, XML, and generated
URLs without contacting Xray.

## CI secrets and variables

Configure these outside Git:

| Variable | Required | Purpose |
| --- | --- | --- |
| `TOSCA_CI_CLIENT_PATH` | yes | Absolute path to `ToscaCIClient.exe` |
| `TOSCA_EXECUTION_ENDPOINT` | distributed mode | Remote Execution Service or DEX endpoint |
| SAP/key-vault credentials | yes | Resolved on the Tosca execution agent |
| `XRAY_CLIENT_ID` | Xray publishing | Xray Cloud API client ID |
| `XRAY_CLIENT_SECRET` | Xray publishing | Xray Cloud API client secret |
| `XRAY_PROJECT_KEY` | Xray publishing | Jira project key |

Use a self-hosted Windows runner with Tosca and SAP client software installed. The hosted validation
job only validates repository files; it cannot execute Tosca tests.

## Official documentation

- [Create SAP Modules with XScan](https://docs.tricentis.com/tosca-2026.1/en-us/content/engines_3.0/sap/sap_modules.htm)
- [Import and export Tosca subsets](https://docs.tricentis.com/tosca-2026.1/en-us/content/tosca_commander/import_export_subsets.htm)
- [Run Tosca CI tests through Remote Service](https://docs.tricentis.com/tosca-2026.1/en-us/content/continuous_integration/execution_remote.htm)
- [Use key-vault secrets](https://docs.tricentis.com/tosca-2026.1/en-us/content/tbox/key_vault_integration.htm)
- [Xray automation result import examples](https://github.com/Xray-App/xray-code-snippets/tree/main/use_cases/import_automation_results)
- [Xray Cucumber feature export example](https://github.com/Xray-App/tutorial-java-cucumber/blob/main/export_features_cloud.sh)

## License

MIT. Tricentis, Tosca, SAP, SAP GUI, and SAP Fiori are trademarks of their respective owners. This
project is an independent template and does not redistribute their software.
