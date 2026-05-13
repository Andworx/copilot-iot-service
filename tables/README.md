# Dataverse Table Definitions

This folder contains all custom Dataverse table, column, choice, and relationship definitions for `AgenticIoT`. These definitions are consumed by the PowerShell deployment scripts to provision schema in target environments.

## Publisher Prefix

All custom items use the **`andy_`** prefix. Set `publisherPrefix` in `scripts/config-dev.json` to match.

## Folder Structure

```
tables/
├── README.md                          ← You are here
├── choices/                           ← Global choice (option set) definitions
│   ├── README.md
│   └── andy_example.json
├── relationships/                     ← Cross-table relationships
│   ├── README.md
│   └── definitions.json
└── andy_tablename/   ← One folder per table
    ├── README.md
    ├── definition.json
    └── icon.svg                       ← Optional Fluent UI SVG icon (type-11 web resource)
```

## Table Definition Schema

```json
{
  "schemaName": "andy_tablename",
  "displayName": "Human Readable Name",
  "displayCollectionName": "Plural Name",
  "description": "Purpose of this table",
  "primaryNameColumn": "andy_name",
  "ownership": "Organization",
  "isActivity": false,
  "changeTrackingEnabled": true,
  "iconSvgFile": "icon.svg",
  "iconWebResourceName": "andy_tablename_icon",
  "columns": [
    {
      "schemaName": "andy_name",
      "displayName": "Name",
      "dataType": "String",
      "maxLength": 200,
      "required": "Required"
    }
  ]
}
```

`iconSvgFile` and `iconWebResourceName` are optional. Omit both to skip icon deployment for that table.

## Choice Definition Schema

```json
{
  "schemaName": "andy_examplechoice",
  "displayName": "Example Choice",
  "description": "Purpose of this choice",
  "isGlobal": true,
  "defaultValue": 756150000,
  "options": [
    { "value": 756150000, "label": "Option One",   "description": "First option"  },
    { "value": 756150001, "label": "Option Two",   "description": "Second option" }
  ]
}
```

Choice base value: **`756150000`** (increment by 1 per option).

## Deployment Order

Deploy in this order to satisfy foreign-key dependencies:

1. Choices (no dependencies)
2. Standalone tables (no lookups to other custom tables)
3. Tables with lookups to standalone tables
4. Tables with lookups to above
5. Notes/attachment tables that depend on the main entity
6. Relationships (after all tables are deployed)

## Table Icon (SVG)

Each table folder can contain an optional `icon.svg` file. When present, `Import-Tables.ps1` will:

1. Base64-encode the SVG file
2. Upsert a type-11 (`SVG`) web resource in Dataverse using `iconWebResourceName`
3. Publish the web resource with `PublishXml`
4. Set `IconVectorName` on the entity definition

### Naming Convention

`<publisher_prefix>_<logical_name_without_prefix>_icon`

| Table schema name | iconWebResourceName |
|---|---|
| `andy_serviceidentity` | `andy_serviceidentity_icon` |
| `andy_servicerequest` | `andy_servicerequest_icon` |

### Sourcing Icons

Prefer **Fluent UI** icons (MIT licence) from Iconify:

```
https://api.iconify.design/fluent/{icon-name}.svg
```

Example: `https://api.iconify.design/fluent/people-team-20-regular.svg`

Download the `.svg` response and save it as `icon.svg` in the table folder. Browse icons at [icon-sets.iconify.design/fluent](https://icon-sets.iconify.design/fluent/).

### Verification Checklist

#### Dry-run verification

- [ ] Run `Import-Tables.ps1 -DryRun` and confirm `[DRY-RUN] Would upsert web resource` appears for each table that has an icon
- [ ] Confirm `[DRY-RUN] Would publish` and `[DRY-RUN] Would PATCH EntityDefinitions IconVectorName` are also logged per icon
- [ ] Tables without `iconSvgFile` produce no icon log lines
- [ ] A table with `iconSvgFile` set but a missing SVG file on disk shows `[ICON-SKIP]`
- [ ] A table with `iconSvgFile` set but no `iconWebResourceName` shows `[ICON-SKIP]`

#### Real deployment verification

- [ ] `[ICON-NEW]` logged on first deploy, `[ICON-UPDATE]` on subsequent reruns — no errors
- [ ] `[ICON-PUBLISH]` logged with no errors
- [ ] `[ICON-ASSIGN]` logged with no errors
- [ ] In `make.powerapps.com` → **Solutions → Web resources**, the web resource is present and type is **SVG**
- [ ] Navigate to **Tables → \<table\> → Properties** — the icon is visible
- [ ] Rerun `Import-Tables.ps1` without `-DryRun` confirms `[ICON-UPDATE]` (idempotent, no duplicate creation)

## Relationship Definition Schema

```json
{
  "schemaName": "andy_parenttable_childtable",
  "type": "OneToMany",
  "referencingEntity": "andy_childtable",
  "referencingAttribute": "andy_parentid",
  "referencedEntity": "andy_parenttable",
  "cascadeDelete": "Restrict"
}
```

Always use `"cascadeDelete": "Restrict"` to prevent accidental data loss.
