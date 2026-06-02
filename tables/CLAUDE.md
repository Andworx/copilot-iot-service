# Dataverse Table Conventions

Applies to all files under `tables/`.

## Publisher Prefix

All custom entities, columns, choices, and relationships use the `andy_` prefix. No exceptions.

## Table Definition Schema

```json
{
  "schemaName": "andy_tablename",
  "displayName": "Human Readable Name",
  "displayCollectionName": "Plural Name",
  "description": "Purpose",
  "primaryNameColumn": "andy_name",
  "ownership": "Organization",
  "isActivity": false,
  "changeTrackingEnabled": true,
  "iconSvgFile": "icon.svg",
  "iconWebResourceName": "andy_tablename_icon",
  "columns": []
}
```

- `schemaName`: singular, lowercase after prefix
- Always include `primaryNameColumn`, `ownership`, `changeTrackingEnabled`
- `iconSvgFile` and `iconWebResourceName` are optional — omit both to skip icon deployment

## Table Icon (SVG)

- Place `icon.svg` in the table folder alongside `definition.json`
- Naming convention: `andy_<logical_name_without_prefix>_icon`
  - Example: table `andy_serviceidentity` → `andy_serviceidentity_icon`
- `Import-Tables.ps1` base64-encodes the SVG and upserts it as a type-11 web resource, then sets `IconVectorName` on the entity
- Prefer **Fluent UI** SVG icons (MIT licence) from Iconify:
  `https://api.iconify.design/fluent/{icon-name}.svg`
  Example: `https://api.iconify.design/fluent/people-team-20-regular.svg`
- Download the SVG file and save it as `icon.svg` in the table folder

## Column Definitions

- Required fields: `schemaName`, `displayName`, `dataType`
- `required` values: `Required`, `Recommended`, or `Optional`
- Lookup columns must include `target` pointing to the related table
- Choice columns must include `choiceName` referencing a global choice

## Canonical dataType Values (Enforced)

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

Prohibited legacy aliases (do not use):

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

- `schemaName` format: `andy_parententity_childentity`
- Always specify `cascadeDelete` — prefer `Restrict` to prevent accidental data loss
- Default other cascades to `NoCascade`
