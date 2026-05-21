# Power BI Build Guide (Template)

## Prerequisites

- Power BI Desktop (latest version)
- Access to Dataverse environment at `https://iot-agents.crm.dynamics.com/.crm.dynamics.com`
- Permissions for source tables/views used by the report

## Build Steps

1. Copy this template folder to a new report folder under `reports/`.
2. Rename `report-template` artifacts to your report name.
3. Open `<your-report>.pbip` in Power BI Desktop.
4. Update data source references in Power Query:
   - Organization URL
   - Table names
   - Optional environment-specific filters
5. Review and update DAX measures.
6. Refresh model and verify visuals load.
7. Save and commit all PBIP source files.

## Validation Checklist

- Query refresh succeeds without local machine-only dependencies.
- Report pages render with expected visuals.
- Measure calculations are correct for sample filters.
- No `.pbi/` cache artifacts are included in source control.
