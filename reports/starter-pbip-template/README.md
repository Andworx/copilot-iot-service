# Starter PBIP Template

Generic Power BI report template designed for reuse across projects.

## Included Files

- `report-template.pbip`: PBIP project entrypoint.
- `report-template.Report/`: report-level metadata and page definitions.
- `report-template.SemanticModel/`: model definitions in TMDL.
- `dax-measures.dax`: starter DAX measure patterns.
- `power-query.m`: starter Dataverse query pattern.
- `theme-template.json`: reusable report theme baseline.
- `BUILD_GUIDE.md`: setup and build steps.

## First-Time Setup

1. Copy this folder and rename it for your report.
2. Rename `report-template.pbip` and matching Report/SemanticModel folders.
3. Update placeholders (`andworx-development.crm.dynamics.com/`, table names, measure names).
4. Open the copied `.pbip` file in Power BI Desktop.
5. Validate refresh and visuals, then commit source files.
