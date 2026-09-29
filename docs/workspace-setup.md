# Tosca workspace setup

## Recommended tree

```text
Modules/QAItest SAP/SAP GUI
Modules/QAItest SAP/SAP Fiori
TestCases/QAItest SAP/Reusable
TestCases/QAItest SAP/Smoke
Execution/QAItest SAP/SAP Smoke
```

## SAP GUI Modules

Use SAP Engine 3.0 and XScan. Prefer stable business properties over screen coordinates. Reuse the
Standard subset SAP Logon Module where it fits the target landscape, and scan application-specific
controls into focused Modules.

Create reusable TestCase blocks for:

- opening the configured SAP connection;
- entering client, user, secret password, and language;
- verifying the SAP home screen;
- logging off and confirming the dialog.

## SAP Fiori Modules

Use XBrowser/XScan for the browser shell and Fiori controls. Keep the login page, Launchpad shell,
and application pages in separate Modules. Identify controls through stable attributes and labels,
not generated DOM IDs.

Parameterize the localized logout text with `{CP[SAP_LOGOUT_TEXT]}` when the scanned control needs a
text value. If the environment uses SSO, replace credential entry with a reusable SSO precondition
and retain the logout verification.

## Configuration

Create the parameters from `config/test-configuration-parameters.example.csv` on the ExecutionList
or an appropriate parent. A child value overrides a parent value. Never store plaintext passwords;
use a supported key-vault expression.

For continuous execution, define and expose these ExecutionList properties:

- `ContinuousIntegration=True`
- `SAPSmoke=True`

The second property corresponds to `ci/CITestExecutionConfiguration.xml` and limits the run to this
template's smoke list.

## Export for source control

Export the ExecutionList as a subset into `tosca/subsets/`. Tosca includes referenced TestCases and
Modules. Before committing, verify that the subset contains no credentials, production endpoints,
personal data, or execution logs.
