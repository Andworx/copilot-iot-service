# Power Automate Flow Conventions

Applies to all files under `flows/`.

## Mandatory Plan Re-Verification After Push/Import

When a flow is pushed back to the platform (via solution import, `scripts/Import-Flows.ps1`, or pipeline deployment), set matching plan items to `⬜ Verify` until post-deployment validation is complete.

- Do not mark a flow-related plan item `✅ Done` immediately after push/import
- Add a short note indicating what changed, where it was deployed, and what still needs verification
- After verification passes, update to `✅ Done` and record verification evidence

## Build Flows As Solution-Aware Components

- Keep flows in solutions (not standalone) to support repeatable ALM
- Use connection references, not hard-wired per-action connections
- Use environment variables for environment-specific values (IDs, URLs, mailbox addresses, thresholds)
- Promote dev → test → prod through managed solution deployment
- Edit flow logic only in development environments

## Naming And Readability

- Use descriptive, functional flow names; avoid ambiguous names like `Flow1`
- Use consistent naming patterns for actions, variables, and scopes
- Prefer prefixes/tags to classify action purpose (Trigger, Data, Notify, Guard, etc.)
- Add comments/notes for complex logic, branching, retries, or workarounds

## Trigger And Data Efficiency

- Configure trigger conditions so runs occur only when needed
- For Dataverse update triggers, set **Select columns** to the specific columns that should trigger execution
- Use **Filter rows** (OData) at trigger/action level to reduce unnecessary runs and data payload
- Avoid broad queries; use Select columns, Filter rows, and Top/Row count where applicable

## Reliability And Ownership

- Prefer service principal ownership for production solution-aware flows
- Keep parent/child flows that share connection references in the same solution
- Use run-only sharing for operational users when edit access is not required
- Ensure retry/error paths are explicit for external calls and notification actions

## Flow JSON File Format (Critical)

Every flow definition file in `flows/andy_*.json` must conform exactly to this top-level shape:

```json
{
  "flowName": "andy_MyFlow",
  "displayName": "Human-readable display name",
  "flowDescription": "One-sentence description of what the flow does.",
  "solutionAware": true,
  "connectionReferences": [
    "andy_shared_commondataserviceforapps"
  ],
  "environmentVariables": [],
  "definition": { ... }
}
```

**Critical field rules:**
- Use `flowName` and `flowDescription` — NOT `name` / `description`. The import script reads `$flowDef.flowName` and `$flowDef.flowDescription` by name.
- `connectionReferences` must be a **string array** of solution connection reference logical names (with publisher prefix, e.g. `andy_shared_commondataserviceforapps`). Not an object.
- `solutionAware: true` is required for all flows in this project.
- File must be named `andy_<FlowName>.json` directly in `flows/` root — the import script does not scan subdirectories.

## connection-references.json (Required for Designer Connection Binding)

`flows/connection-references.json` **must exist** for every connector used by any flow in this project. Without it, the import script builds an empty `clientdata.connectionReferences` map, and the Power Automate designer will **never prompt you to sign in to a connector**.

```json
[
  {
    "schemaName": "andy_shared_commondataserviceforapps",
    "displayName": "AgenticIoT — Dataverse",
    "description": "Dataverse connection used by all AgenticIoT flows for triggers and data operations.",
    "connectorId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
  }
]
```

- `schemaName`: publisher-prefixed connection reference logical name (matches the string in each flow's `connectionReferences` array)
- `connectorId`: always `/providers/Microsoft.PowerApps/apis/<connectorName>` (same as `apiId` in action host blocks, but with the publisher prefix stripped)
- After adding a new entry, re-import with `-ReplaceExistingFlows` so `clientdata.connectionReferences` is rebuilt.

## OpenApiConnection Action Format (Critical)

All Dataverse triggers and actions use `OpenApiConnectionWebhook` / `OpenApiConnection` types.

### Trigger (OpenApiConnectionWebhook)

```json
"My_Trigger": {
  "type": "OpenApiConnectionWebhook",
  "inputs": {
    "host": {
      "connectionName": "shared_commondataserviceforapps",
      "operationId": "SubscribeWebhookTrigger",
      "apiId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
    },
    "parameters": {
      "subscriptionRequest/message": 1,
      "subscriptionRequest/entityname": "andy_myentity",
      "subscriptionRequest/scope": 4,
      "subscriptionRequest/filterexpression": "andy_myfield eq true"
    },
    "authentication": "@parameters('$authentication')"
  }
}
```

- `message` values: `1` = Created, `2` = Deleted, `3` = Updated
- `scope` values: `4` = Organization
- `subscriptionRequest/entityname` uses the **singular logical name** (no trailing `s`)

### Action — ListRecords

```json
"My_ListAction": {
  "type": "OpenApiConnection",
  "inputs": {
    "host": {
      "connectionName": "shared_commondataserviceforapps",
      "operationId": "ListRecords",
      "apiId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
    },
    "parameters": {
      "entityName": "andy_mytables",
      "$filter": "andy_status eq 1",
      "$select": "andy_mytableid,andy_name",
      "$top": 10
    },
    "authentication": "@parameters('$authentication')"
  },
  "runAfter": { "PreviousAction": ["Succeeded"] }
}
```

### Action — CreateRecord

```json
"My_CreateAction": {
  "type": "OpenApiConnection",
  "inputs": {
    "host": {
      "connectionName": "shared_commondataserviceforapps",
      "operationId": "CreateRecord",
      "apiId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
    },
    "parameters": {
      "entityName": "andy_mytables",
      "item/andy_name": "",
      "item/andy_status": 756150000,
      "item/andy_lookup_id@odata.bind": "@concat('/andy_othertables(', variables('Var_RecordId'), ')')"
    },
    "authentication": "@parameters('$authentication')"
  },
  "runAfter": { "PreviousAction": ["Succeeded"] }
}
```

> ⚠️ **AutoNumber + Required fields**: If the table has an AutoNumber primary name column marked `Required`, pass an **empty string `""`** — Dataverse ignores the value and generates the autonumber.

### Action — UpdateRecord

```json
"My_UpdateAction": {
  "type": "OpenApiConnection",
  "inputs": {
    "host": {
      "connectionName": "shared_commondataserviceforapps",
      "operationId": "UpdateRecord",
      "apiId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
    },
    "parameters": {
      "entityName": "andy_mytables",
      "recordId": "@variables('Var_RecordId')",
      "item/andy_status": 756150001
    },
    "authentication": "@parameters('$authentication')"
  },
  "runAfter": { "PreviousAction": ["Succeeded"] }
}
```

### Rules for all OpenApiConnection actions

| Rule | Correct | Wrong |
|---|---|---|
| `host.connectionName` | `"shared_commondataserviceforapps"` (no prefix) | `"andy_shared_commondataserviceforapps"` |
| `authentication` on ALL actions | ✅ Required | Omitting it causes designer bind errors |
| Entity set name (plural) for actions | `andy_mytables` (add `s`) | `andy_mytable` (singular) |
| Record fields in Create/Update | Flat `"item/andy_fieldname"` keys | Nested `"item": { ... }` object |
| Lookup binding | `"item/andy_lookup@odata.bind": "/andy_set(guid)"` | `"item/andy_lookup": "guid"` |
| `connectionReferenceName` in host | ❌ Never use | Use `connectionName` always |

### operationId Reference

| Action | operationId |
|--------|-------------|
| List rows | `ListRecords` |
| Get a row by ID | `GetItem` |
| Create a row | `CreateRecord` |
| Update a row | `UpdateRecord` |
| Delete a row | `DeleteRecord` |
| Trigger: row added/updated/deleted | `SubscribeWebhookTrigger` |

## Entity Set Names (Dataverse Pluralisation)

Dataverse applies **English pluralization rules** — words ending in `-y` become `-ies`. Always verify against `EntityDefinitions` metadata before writing a flow.

Query: `GET /api/data/v9.2/EntityDefinitions?$filter=LogicalName eq 'andy_mytable'&$select=LogicalName,EntitySetName`

| Logical name | Entity set name | Rule |
|---|---|---|
| `andy_iottelemetryevent` | `andy_iottelemetryevents` | + `s` |
| `andy_iot_sensor` | `andy_iot_sensors` | + `s` |
| `andy_technician` | `andy_technicians` | + `s` |
| `andy_dispatch_history` | `andy_dispatch_histories` | `y` → `ies` ⚠️ |

> ⚠️ **`andy_dispatch_history` → `andy_dispatch_histories`**, NOT `andy_dispatch_historys`. Confirmed via `EntityDefinitions` API.

> **Note:** The trigger's `subscriptionRequest/entityname` uses the **singular logical name** (no `s`). The entity set name with `s` is only for action `entityName` parameters.

## Parameters Block in definition (Required)

Every `definition` must include:

```json
"parameters": {
  "$connections": { "defaultValue": {}, "type": "Object" },
  "$authentication": { "defaultValue": {}, "type": "SecureObject" }
}
```

## Sequential Foreach Loops

When a `Foreach` loop updates variables, add `"operationOptions": "Sequential"` to prevent race conditions:

```json
"My_Loop": {
  "type": "Foreach",
  "foreach": "@outputs('My_ListAction')?['body/value']",
  "operationOptions": "Sequential",
  "actions": { ... },
  "runAfter": { "PreviousAction": ["Succeeded"] }
}
```

## Import Script Behaviour

- **Discovery**: `Import-Flows.ps1` scans `flows/` root only for `andy_*.json`. Files in subdirectories are ignored.
- **Field names read**: `flowName`, `flowDescription`, `connectionReferences` (array), `definition`.
- **Update vs Replace**: On update failures, choose `[R] Replace` only when the existing Dataverse record is corrupted. A fresh `[CREATED]` result after Replace requires re-binding connections in the maker portal.
- **After replace**: Go to make.powerautomate.com → open flow → sign in to the Dataverse connection → turn On.

## Dataverse Workflow Payload Contract (Critical)

When updating or creating cloud flows via Dataverse `workflows` API records (category `5`):

- Always include a top-level `definition` field in `PATCH` and `POST` requests
- `definition` must be sent as a primitive JSON string value (serialized), not as a nested JSON object
- If you include `clientdata`, ensure it also embeds `properties.definition` and `properties.connectionReferences` consistent with the deployed flow
- Do not assume delete/recreate fallback will work if `definition` is missing; the platform returns `DefinitionRequestMissingFields`

## JSON Hygiene Before Import

- Validate each edited flow file with `ConvertFrom-Json` to catch syntax errors before import
- Prefer minimal, canonical WDL shape in `definition` (include `$schema`, `contentVersion`, `triggers`, `actions`, `outputs`)
- Avoid hand-escaping nested JSON strings in deployment scripts
- When overwriting a large file programmatically, use `Set-Content` rather than the edit tool to prevent old content being appended after new content

## Stuck Flow Recovery Playbook

For a flow that cannot be edited or deleted and returns `DefinitionRequestMissingFields`:

1. Restore `definition` for the existing workflow record via API PATCH
2. Re-open the flow in maker UI and test save/edit/delete
3. If delete is still blocked, retire the broken record and create a clean replacement
4. Turn on the replacement flow; set related plan items to `⬜ Verify` until runtime checks pass

For a flow that fails PATCH with `WorkflowRunActionInputsInvalidProperty` (authentication property error from a corrupted record):

1. Choose Replace (`-ReplaceExistingFlows`) to delete and recreate the flow fresh
2. The creation path (`POST`) accepts the full WDL including `authentication` on actions — the error only appears on PATCH of certain corrupted records

## Change Checklist For Any Flow Update

1. Update flow definition in `flows/`
2. Confirm naming, comments, trigger filters, and environment variable usage meet conventions
3. Push/import via approved ALM path
4. Mark related plan items as `⬜ Verify` with deployment note
5. Execute verification (trigger test, expected side effects, no duplicate/unexpected runs)
6. Mark item `✅ Done` only after verification succeeds
