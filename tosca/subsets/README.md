# Tosca subsets

Place exported `.tce` or `.tsu` subsets in this directory after reviewing them for credentials,
internal endpoints, personal data, and generated execution logs.

Recommended export scope:

```text
QAItest SAP
|-- Modules
|   |-- SAP GUI
|   `-- SAP Fiori
|-- TestCases
|   |-- Reusable
|   `-- Smoke
`-- Execution
    `-- SAP Smoke
```

Export the `SAP Smoke` ExecutionList when you want Tosca to include its referenced TestCases and
Modules automatically. Test Configuration Parameters created on the project root must be recreated
from `config/test-configuration-parameters.example.csv` after import.

Large binary subsets can be managed with Git LFS if required by the project.
