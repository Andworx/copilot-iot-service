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

## Stuck Flow Recovery Playbook

For a flow that cannot be edited or deleted and returns `DefinitionRequestMissingFields`:

1. Restore `definition` for the existing workflow record via API PATCH
2. Re-open the flow in maker UI and test save/edit/delete
3. If delete is still blocked, retire the broken record and create a clean replacement
4. Turn on the replacement flow; set related plan items to `⬜ Verify` until runtime checks pass

## Change Checklist For Any Flow Update

1. Update flow definition in `flows/`
2. Confirm naming, comments, trigger filters, and environment variable usage meet conventions
3. Push/import via approved ALM path
4. Mark related plan items as `⬜ Verify` with deployment note
5. Execute verification (trigger test, expected side effects, no duplicate/unexpected runs)
6. Mark item `✅ Done` only after verification succeeds
