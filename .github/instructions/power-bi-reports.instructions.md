---
description: "Use when creating or modifying Power BI report projects under reports/. Covers PBIP structure, DAX and Power Query organization, design quality, accessibility, and source control conventions."
applyTo: "reports/**"
---

# Power BI Reports Conventions

## Scope

Apply these rules for all report assets under `reports/`, including PBIP project files, report definitions, semantic model files, DAX, M queries, and report documentation.

## Required Project Structure

Each report project should include:

- `<report-name>.pbip`
- `<report-name>.Report/`
- `<report-name>.SemanticModel/`
- `dax-measures.dax`
- `power-query.m`
- `theme-*.json`
- `README.md`

Recommended parent structure:

```text
reports/
└── <report-folder>/
    ├── <report-name>.pbip
    ├── <report-name>.Report/
    ├── <report-name>.SemanticModel/
    ├── dax-measures.dax
    ├── power-query.m
    ├── theme-*.json
    └── README.md
```

## Source Control Rules (Mandatory)

- Use PBIP as source of truth for report projects.
- Commit text-based source files (PBIP/TMDL/JSON/DAX/M).
- Do not commit local Power BI generated cache/state files (`.pbi/`, cache artifacts, machine-local settings).
- Do not commit secrets, tenant-specific credentials, or hardcoded sensitive identifiers.
- Keep environment values tokenized when practical (`YOUR_ORG_URL`, `YOUR_ORG_NAME`, and related placeholders).

## DAX Authoring Guidance

- Prefer variables (`VAR`/`RETURN`) in non-trivial measures.
- Use `DIVIDE()` instead of `/` for safe division.
- Fully qualify columns (for example, `Table[Column]`) and keep measure references unqualified.
- Keep measure names business-readable and consistent.
- Group reusable measures in a dedicated measures table (`_Measures`) in the semantic model.

Example:

```dax
Closure Rate % =
VAR TotalCount = [Total Requests]
VAR ClosedCount = [Closed Requests]
RETURN
    DIVIDE(ClosedCount, TotalCount)
```

## Power Query (M) Guidance

- Keep source connection and transformation steps readable and named.
- Select only required columns early.
- Use environment placeholders in URLs and environment-specific values.
- Avoid embedding secrets or user-specific paths.

## Report Design Guidance

- Use clear visual hierarchy: KPI summary first, details second, controls third.
- Keep each page focused; avoid clutter and unnecessary visuals.
- Use meaningful page and visual titles.
- Prefer accessibility-safe color contrast and avoid color-only encoding.
- Validate mobile readability for key pages if mobile consumption is expected.

## Performance Guidance

- Limit visuals per page to practical levels.
- Reduce expensive calculations in visuals where possible.
- Push filtering upstream (query and model) before adding heavy visual interactions.
- Use star schema patterns when possible for large models.

## Required Review Checklist

1. Report opens from `.pbip` without machine-specific path dependencies.
2. No `.pbi/` or local artifacts are included in the change.
3. DAX and M are readable, organized, and use safe patterns.
4. Visual and page naming is clear and business meaningful.
5. No secrets or environment-specific sensitive values are committed.
6. README or build notes are updated when structure or setup changes.

## Anti-Patterns To Avoid

- Committing only `.pbix` binary without PBIP source.
- Hardcoding production tenant URLs or credentials in query code.
- Large monolithic measures without variables.
- Excessive visuals on one page that reduce readability and performance.
- Using color alone to communicate status.
