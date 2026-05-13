# Relationship Definitions

This folder contains cross-table relationship definitions for `AgenticIoT`.

## Files

| File | Purpose |
|---|---|
| `definitions.json` | Aggregated manifest consumed by `scripts/Import-Relationships.ps1` |
| `andy_*.json` | Individual relationship definition files (one per relationship) |

## Adding a New Relationship

1. Create an individual file in this folder (e.g. `andy_account_contact.json`) with the relationship definition.
2. **Also add an entry to `definitions.json`** — `Import-Relationships.ps1` reads only from `definitions.json` and will not see standalone files that are not listed there.

> If you add an individual file but forget to add it to `definitions.json`, the relationship will never be deployed.

## definitions.json Schema

```json
{
  "relationships": [
    {
      "schemaName": "andy_account_contact",
      "description": "Links Contact to parent Account",
      "referencedEntity": "account",
      "referencingEntity": "contact",
      "referencingAttribute": "andy_accountid",
      "cascadeDelete": "RemoveLink",
      "cascadeAssign": "NoCascade",
      "cascadeReparent": "NoCascade",
      "cascadeShare": "NoCascade",
      "cascadeUnshare": "NoCascade"
    }
  ]
}
```

### Field Reference

| Field | Required | Description |
|---|---|---|
| `schemaName` | ✅ | Unique name for the relationship. Must use the `andy_` prefix. |
| `description` | recommended | Human-readable description of the relationship purpose. |
| `referencedEntity` | ✅ | Logical name of the primary (parent) table. |
| `referencingEntity` | ✅ | Logical name of the related (child) table. |
| `referencingAttribute` | ✅ | Logical name of the lookup column on the child table. |
| `cascadeDelete` | ✅ | Cascade behaviour on delete: `RemoveLink`, `Restrict`, `Cascade`, `NoCascade`. |
| `cascadeAssign` | ✅ | Cascade behaviour on assign. |
| `cascadeReparent` | ✅ | Cascade behaviour on reparent. |
| `cascadeShare` | ✅ | Cascade behaviour on share. |
| `cascadeUnshare` | ✅ | Cascade behaviour on unshare. |

## Deployment Order

Relationships must be deployed **after** both the referenced and referencing tables exist. Ensure the referenced table is deployed before running `Import-Relationships.ps1`.

See `scripts/Deploy-Project.ps1` for the standard deployment sequence.
