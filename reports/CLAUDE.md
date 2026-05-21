# AgenticIoT - Reports Conventions

## Scope

Use this folder for Power BI report source assets in PBIP format.

## Required Layout

Each report folder should include:

- `<report-name>.pbip`
- `<report-name>.Report/`
- `<report-name>.SemanticModel/`
- `dax-measures.dax`
- `power-query.m`
- `theme-*.json`
- `README.md`

## Source Control Rules

- Commit PBIP and semantic model definition files.
- Do not commit local Power BI cache/state files under `.pbi/`.
- Do not commit temporary export outputs.
- Keep organization values tokenized where practical (`iot-agents.crm.dynamics.com/`, etc.).

## DAX and M Organization

- Keep reusable measures in the semantic model and mirror key logic in `dax-measures.dax`.
- Keep Power Query source and transformation logic in `power-query.m`.
- Use descriptive naming and section headers for readability.

## Review Checklist

1. Report opens from `.pbip` without local path dependencies.
2. No secrets or tenant-specific hardcoded values are introduced.
3. DAX measures use variables and safe division patterns where applicable.
4. Visual names and page names are meaningful.
5. `.pbi/` and similar generated artifacts are not part of the commit.
