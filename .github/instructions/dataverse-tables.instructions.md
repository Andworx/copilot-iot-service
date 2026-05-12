---
description: "Use when creating or modifying Dataverse table definitions, columns, choices, or relationships in the tables/ directory. Covers schema naming, column types, and deployment order."
applyTo: "tables/**"
---
# Dataverse Table Conventions

## Publisher Prefix

All custom entities, columns, choices, and relationships use the `YOUR_PUBLISHER_PREFIX_` prefix. No exceptions.

## Table Definition Schema

```json
{
  "schemaName": "YOUR_PUBLISHER_PREFIX_tablename",
  "displayName": "Human Readable Name",
  "displayCollectionName": "Plural Name",
  "description": "Purpose",
  "primaryNameColumn": "YOUR_PUBLISHER_PREFIX_name",
  "ownership": "Organization",
  "isActivity": false,
  "changeTrackingEnabled": true,
  "iconSvgFile": "icon.svg",
  "iconWebResourceName": "YOUR_PUBLISHER_PREFIX_tablename_icon",
  "columns": []
}
```

- `schemaName`: singular, lowercase after prefix
- Always include `primaryNameColumn`, `ownership`, `changeTrackingEnabled`
- `iconSvgFile` and `iconWebResourceName` are optional — omit both to skip icon deployment

## Table Icon (SVG)

- Place `icon.svg` alongside `definition.json` in the table folder
- Naming convention: `YOUR_PUBLISHER_PREFIX_<logical_name_without_prefix>_icon`
  - Example: `andy_serviceidentity` → `andy_serviceidentity_icon`
- Prefer **Fluent UI** SVG icons (MIT) from Iconify: `https://api.iconify.design/fluent/{icon-name}.svg`
- `Import-Tables.ps1` handles base64 encoding, web resource upsert (type 11), publish, and `IconVectorName` assignment — all idempotent

## Column Definitions

- Required fields: `schemaName`, `displayName`, `dataType`
- `required` values: `Required`, `Recommended`, or `Optional`
- Lookup columns must include `target` pointing to the related table
- Choice columns must include `choiceName` referencing a global choice

## Canonical dataType values (enforced)

Allowed values:

- `String`
- `Memo`
- `Integer`
- `Float`
- `Decimal`
- `Money`
- `Boolean`
- `DateTime`
- `Choice`
- `File`
- `Lookup`

Prohibited legacy aliases:

- `SingleLine.Text`
- `MultiLine.Text`
- `Picklist`
- `TwoOptions`
- `WholeNumber`
- `DateAndTime`

## Auto-Number Pattern

Format: `PREFIX-{YYYY}-{SEQNUM:5}` → produces `PREFIX-2026-00001`

## Choice (Option Set) Values

- Base value: `756150000` (increments by 1)
- Always include `description` on each option
- Set `isGlobal: true` for shared choices
- Include `defaultValue`

## Deployment Order (dependency chain)

1. Choices (no dependencies)
2. Tables without lookups to other custom tables
3. Tables with lookups to step 2 tables
4. Continue down the dependency chain
5. Notes and attachment tables (depend on the main entity)
6. Relationships (after all tables are deployed)

## Relationships

- `schemaName` format: `YOUR_PUBLISHER_PREFIX_parententity_childentity`
- Always specify `cascadeDelete` — prefer `Restrict` to prevent accidental data loss
- Default other cascades to `NoCascade`
