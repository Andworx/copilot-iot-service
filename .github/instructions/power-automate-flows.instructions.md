---
description: "Use when creating or modifying Power Automate cloud flows in the flows/ directory. Covers ALM, naming, trigger optimization, and verification requirements after deployment."
applyTo: "flows/**/*.json"
---
# Power Automate Flow Conventions

## Scope

These conventions apply to exported cloud flow definitions in `flows/` and any change that is imported or deployed back to Dataverse/Power Automate.

## Mandatory Plan Re-Verification After Push/Import

When a flow is pushed back to the platform (for example via solution import, flow import, pipeline deployment, or `scripts/Import-Flows.ps1`), the matching item(s) in the project plan must be set to `⬜ Verify` until post-deployment validation is completed.

- Do not mark a flow-related plan item as `✅ Done` immediately after push/import.
- Add a short note indicating what changed, where it was deployed, and what still needs verification.
- After verification passes in the target environment, update status to `✅ Done` and record verification evidence.

## Build Flows As Solution-Aware Components

- Keep flows in solutions (not standalone/non-solution flows) to support repeatable ALM.
- Use connection references, not hard-wired per-action connections.
- Use environment variables for environment-specific values (IDs, URLs, mailbox addresses, thresholds).
- Promote dev → test → prod through managed solution deployment.
- Edit flow logic only in development environments.

## Naming And Readability

- Use descriptive, functional flow names; avoid ambiguous names like `Flow1`.
- Use consistent naming patterns for actions, variables, and scopes.
- Prefer prefixes/tags when helpful to classify action purpose (Trigger, Data, Notify, Guard, etc.).
- Add comments/notes for complex logic, branching, retries, or workarounds.

## Trigger And Data Efficiency

- Configure trigger conditions so runs occur only when needed.
- For Dataverse update triggers, set **Select columns** to the specific columns that should trigger execution.
- Use **Filter rows** (OData) at trigger/action level to reduce unnecessary runs and data payload.
- Avoid broad queries; use Select columns, Filter rows, and Top/Row count where applicable.

## Reliability And Ownership

- Prefer service principal ownership for production solution-aware flows where possible.
- Keep parent/child flows that share connection references in the same solution.
- Use run-only sharing for operational users when edit access is not required.
- Ensure retry/error paths are explicit for external calls and notification actions.

## Flow JSON Structure — Canonical Format (Required)

Every flow JSON file in `flows/andy_*.json` must conform exactly to this top-level shape:

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
- Use `flowName` and `flowDescription` — NOT `name` / `description`. The import script (`Import-Flows.ps1`) reads `$flowDef.flowName` and `$flowDef.flowDescription` by name.
- `connectionReferences` must be a **string array** of solution connection reference logical names (with publisher prefix, e.g. `andy_shared_commondataserviceforapps`). Not an object.
- `solutionAware: true` is required for all flows in this project.
- File must be named `andy_<FlowName>.json` directly in `flows/` root — the import script does not scan subdirectories.

---

## OpenApiConnection Action Format (Critical)

All Dataverse actions (`ListRecords`, `GetRecord`, `CreateRecord`, `UpdateRecord`) and triggers use the `OpenApiConnectionWebhook` / `OpenApiConnection` types. The host block and authentication must follow the exact format below.

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
      "subscriptionRequest/entityname": "andy_mytable",
      "subscriptionRequest/scope": 4,
      "subscriptionRequest/filterexpression": "andy_myfield eq true"
    },
    "authentication": "@parameters('$authentication')"
  }
}
```

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
      "item/andy_name": "Some value",
      "item/andy_status": 756150000,
      "item/andy_lookup_id@odata.bind": "@concat('/andy_othertables(', variables('Var_RecordId'), ')')"
    },
    "authentication": "@parameters('$authentication')"
  },
  "runAfter": { "PreviousAction": ["Succeeded"] }
}
```

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

**Rules for all OpenApiConnection actions:**

| Rule | Correct | Wrong |
|---|---|---|
| `host.connectionName` | `"shared_commondataserviceforapps"` (no prefix) | `"andy_shared_commondataserviceforapps"` |
| `authentication` present on ALL actions | ✅ Required | Omitting it causes designer bind errors |
| Entity set name (plural) | `andy_mytables` (add `s`) | `andy_mytable` (singular) |
| Record fields in CreateRecord/UpdateRecord | Flat `"item/andy_fieldname"` keys | Nested `"item": { "andy_fieldname": ... }` object |
| Lookup binding | `"item/andy_lookup@odata.bind": "/andy_set(guid)"` | `"item/andy_lookup": "guid"` |
| `connectionReferenceName` in host | ❌ Never use this | Use `connectionName` always |

---

## Entity Set Names (Dataverse Pluralisation)

Dataverse OData entity set names are the logical name with `s` appended. Exceptions exist for irregular nouns — verify against `EntityDefinitions` metadata if unsure.

| Logical name | Entity set name |
|---|---|
| `andy_iottelemetryevent` | `andy_iottelemetryevents` |
| `andy_iot_sensor` | `andy_iot_sensors` |
| `andy_technician` | `andy_technicians` |
| `andy_dispatch_history` | `andy_dispatch_historys` |

> **Note:** The trigger's `subscriptionRequest/entityname` uses the **singular logical name** (no `s`). The entity set name with `s` is only for action `entityName` parameters.

---

## Parameters Block in definition

Always include `$authentication` in the flow definition parameters:

```json
"parameters": {
  "$connections": { "defaultValue": {}, "type": "Object" },
  "$authentication": { "defaultValue": {}, "type": "SecureObject" }
}
```

---

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

---

## Import Script Behaviour — Key Facts

- **Discovery**: `Import-Flows.ps1` scans `flows/` root only for `andy_*.json`. Files in subdirectories are ignored.
- **Field names read**: `flowName`, `flowDescription`, `connectionReferences` (array), `definition`.
- **Update vs Replace**: On update failures, choose `[R] Replace` only when the existing Dataverse record is corrupted. A fresh `[CREATED]` result after Replace requires re-binding connections in the maker portal.
- **After replace**: Go to make.powerautomate.com → open flow → sign in to the Dataverse connection → turn On.

---

## Flow JSON File Format (Critical — Learned from Practice)

Every flow definition file in `flows/andy_*.json` must follow this exact structure. Deviations cause API 400 errors on import.

### Top-Level File Structure

```json
{
  "flowName": "andy_MyFlow",
  "displayName": "Human Readable Name",
  "flowDescription": "What this flow does.",
  "solutionAware": true,
  "connectionReferences": [
    "andy_shared_commondataserviceforapps"
  ],
  "environmentVariables": [],
  "definition": { ... }
}
```

**Field name rules:**
- Use `flowName` and `flowDescription` — **not** `name` / `description` (Import-Flows.ps1 reads these exact keys).
- `connectionReferences` must be a **string array** of solution-level connection reference logical names (publisher-prefixed, e.g. `andy_shared_commondataserviceforapps`).

### Trigger Format — OpenApiConnectionWebhook (Dataverse row added/updated/deleted)

```json
"triggers": {
  "When_a_row_is_added": {
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
        "subscriptionRequest/filterexpression": "andy_somefield eq true"
      },
      "authentication": "@parameters('$authentication')"
    }
  }
}
```

**Rules:**
- `connectionName` in the trigger `host` block uses the **base connector name without publisher prefix**: `"shared_commondataserviceforapps"`.
- `subscriptionRequest/entityname` uses the **singular logical name** (e.g. `andy_iottelemetryevent`) — no trailing `s`.
- `authentication` is **required** on the trigger.
- `message` values: `1` = Created, `2` = Deleted, `3` = Updated.
- `scope` values: `4` = Organization.

### Action Format — OpenApiConnection (Dataverse List/Get/Create/Update/Delete)

```json
"MyAction": {
  "type": "OpenApiConnection",
  "inputs": {
    "host": {
      "connectionName": "shared_commondataserviceforapps",
      "operationId": "ListRecords",
      "apiId": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps"
    },
    "parameters": {
      "entityName": "andy_myentitys",
      "$filter": "andy_status eq 1",
      "$select": "andy_myentityid,andy_name",
      "$top": 50
    },
    "authentication": "@parameters('$authentication')"
  },
  "runAfter": { "PreviousAction": ["Succeeded"] }
}
```

**Rules:**
- `connectionName` in action `host` blocks uses the **same base connector name without publisher prefix**: `"shared_commondataserviceforapps"`. Do NOT use `connectionReferenceName` here — that is a solution manifest concept, not a WDL host property.
- `authentication` is **required** on every `OpenApiConnection` action input.
- `entityName` for ListRecords/CreateRecord/UpdateRecord/DeleteRecord uses the **OData entity set name** = logical name + `s` (e.g. `andy_iottelemetryevent` → `andy_iottelemetryevents`, `andy_technician` → `andy_technicians`).
- Exception: if the name ends in `y` Dataverse may pluralise to `ies` — verify in metadata if in doubt.

### operationId Reference

| Action | operationId |
|--------|-------------|
| List rows | `ListRecords` |
| Get a row by ID | `GetItem` |
| Create a row | `CreateRecord` |
| Update a row | `UpdateRecord` |
| Delete a row | `DeleteRecord` |
| Trigger: row added/updated/deleted | `SubscribeWebhookTrigger` |

### CreateRecord / UpdateRecord Parameter Style

Use **flat `item/fieldname` keys** — never a nested `"item": { ... }` object:

```json
"parameters": {
  "entityName": "andy_dispatch_historys",
  "item/andy_status": 756150000,
  "item/andy_dispatched_at": "@utcNow()",
  "item/andy_technician_id@odata.bind": "@concat('/andy_technicians(', variables('Var_TechId'), ')')"
}
```

For UpdateRecord also include:
```json
"recordId": "@outputs('PreviousAction')?['body/andy_myentityid']"
```

### Lookup (odata.bind) Syntax

```json
"item/andy_relatedrecord@odata.bind": "@concat('/andy_relatedentitys(', variables('Var_Guid'), ')')"
```

- Entity set name in the bind URL must also be plural (+ `s`).

### Definition Parameters Block (Required)

Every `definition` must include:

```json
"parameters": {
  "$connections": { "defaultValue": {}, "type": "Object" },
  "$authentication": { "defaultValue": {}, "type": "SecureObject" }
}
```

### Sequential Foreach (Required When Updating Variables Inside Loop)

```json
"MyLoop": {
  "type": "Foreach",
  "foreach": "@outputs('ListAction')?['body/value']",
  "operationOptions": "Sequential",
  "actions": { ... }
}
```

Without `"operationOptions": "Sequential"`, variable updates inside Foreach are non-deterministic due to parallel iteration.

## Dataverse Workflow Payload Contract (Critical)

When updating or creating cloud flows via Dataverse `workflows` API records (category `5`):

- Always include a top-level `definition` field in `PATCH` and `POST` requests.
- `definition` must be sent as a primitive JSON string value (serialized), not as a nested JSON object.
- If you include `clientdata`, ensure it also embeds `properties.definition` and `properties.connectionReferences` consistent with the deployed flow.
- Do not assume delete/recreate fallback will work if `definition` is missing; the platform can return `DefinitionRequestMissingFields`.

## Import-Flows.ps1 File Discovery Rules

- The script scans `flows/` root only — no subdirectory traversal.
- Files must be named `andy_<FlowName>.json` directly in `flows/`.
- Canonical source-of-record copies may be kept in subdirectories (e.g. `flows/my-flow/flow.json`) but the `flows/andy_*.json` root copy is what gets imported. Keep both in sync.

## JSON Hygiene Before Import (Required)

- Validate each edited flow file with `ConvertFrom-Json` to catch syntax errors before import.
- Prefer minimal, canonical WDL shape in `definition` (include `$schema`, `contentVersion`, `triggers`, `actions`, `outputs`).
- Avoid hand-escaping nested JSON strings in deployment scripts.
- When overwriting a large file programmatically, use `Set-Content` rather than the `edit` tool to prevent old content being appended after the new content.

## Stuck Flow Recovery Playbook

For a flow that cannot be edited or deleted and returns `DefinitionRequestMissingFields`:

1. Restore `definition` for the existing workflow record via API PATCH.
2. Re-open the flow in maker UI and test save/edit/delete.
3. If delete is still blocked, retire the broken record and create a clean replacement.
4. Turn on the replacement flow and set related plan items to `⬜ Verify` until runtime checks pass.

For a flow that fails PATCH with `WorkflowRunActionInputsInvalidProperty` (e.g. authentication property error from a previously corrupted record):

1. Choose Replace (`-ReplaceExistingFlows`) to delete and recreate the flow fresh.
2. The creation path (`POST`) accepts the full WDL including `authentication` on actions — the error only appears on PATCH of certain corrupted records.

## Change Checklist For Any Flow Update

1. Update flow definition in `flows/`.
2. Confirm naming, comments, trigger filters, and environment variable usage meet conventions.
3. Push/import via approved ALM path.
4. Mark related plan items as `⬜ Verify` with deployment note.
5. Execute verification (trigger test, expected side effects, no duplicate/unexpected runs).
6. Mark item `✅ Done` only after verification succeeds.

## Microsoft Learn References

- https://learn.microsoft.com/power-automate/guidance/coding-guidelines/use-consistent-naming-conventions
- https://learn.microsoft.com/power-automate/guidance/coding-guidelines/understand-benefits-solution-aware-flows
- https://learn.microsoft.com/power-automate/guidance/coding-guidelines/optimize-power-automate-triggers
- https://learn.microsoft.com/power-automate/dataverse/create-update-delete-trigger
