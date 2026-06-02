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
- Do not commit secrets, tenant-specific credentials, or hardcoded sensitive identifiers.

## DAX Authoring Guidance

- Prefer variables (`VAR`/`RETURN`) in non-trivial measures.
- Use `DIVIDE()` instead of `/` for safe division.
- Fully qualify columns (e.g. `Table[Column]`) and keep measure references unqualified.
- Keep measure names business-readable and consistent.
- Group reusable measures in a dedicated measures table (`_Measures`) in the semantic model.
- Mirror key measure logic in `dax-measures.dax` for source control readability.

```dax
Closure Rate % =
VAR TotalCount = [Total Requests]
VAR ClosedCount = [Closed Requests]
RETURN
    DIVIDE(ClosedCount, TotalCount)
```

## Power Query (M) Guidance

- Keep source connection and transformation steps readable and named.
- Select only required columns early in the query chain.
- Use environment placeholders in URLs and environment-specific values.
- Avoid embedding secrets or user-specific paths.
- Keep Power Query source and transformation logic in `power-query.m`.
- Use descriptive naming and section headers for readability.

## Report Design Guidance

- Use clear visual hierarchy: KPI summary first, details second, controls third.
- Keep each page focused; avoid clutter and unnecessary visuals.
- Use meaningful page and visual titles.
- Prefer accessibility-safe color contrast and avoid color-only encoding.
- Validate mobile readability for key pages if mobile consumption is expected.

## Performance Guidance

- Limit visuals per page to practical levels.
- Reduce expensive calculations in visuals where possible.
- Push filtering upstream (query and model level) before adding heavy visual interactions.
- Use star schema patterns when possible for large models.

## Review Checklist

1. Report opens from `.pbip` without local path dependencies.
2. No `.pbi/` or local artifacts are included in the change.
3. No secrets or tenant-specific hardcoded values are committed.
4. DAX measures use variables and safe division patterns where applicable.
5. M queries are readable, named, and use environment placeholders.
6. Visual names and page names are meaningful.
7. README or build notes are updated when structure or setup changes.

## Anti-Patterns To Avoid

- Committing only `.pbix` binary without PBIP source.
- Hardcoding production tenant URLs or credentials in query code.
- Large monolithic measures without variables.
- Excessive visuals on one page that reduce readability and performance.
- Using color alone to communicate status.
- Committing `.pbi/` generated cache/state files.
