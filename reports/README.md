# Power BI Reports

This folder contains source-controlled Power BI report templates and report projects using PBIP format.

## Why PBIP

PBIP keeps report assets in text files that work well with Git reviews, branching, and merges.

- Use `.pbip` projects for all report source.
- Avoid committing `.pbix` binaries unless explicitly needed for distribution.
- Keep DAX and Power Query logic in companion files for easier review.

## Structure

```text
reports/
├── CLAUDE.md
├── starter-pbip-template/
│   ├── README.md
│   ├── BUILD_GUIDE.md
│   ├── report-template.pbip
│   ├── report-template.Report/
│   ├── report-template.SemanticModel/
│   ├── dax-measures.dax
│   ├── power-query.m
│   ├── theme-template.json
│   └── assets/
```

## Usage

1. Copy `starter-pbip-template/` to a new folder in `reports/`.
2. Rename files and folders from `report-template` to your report name.
3. Replace placeholders such as `YOUR_ORG_URL`, table names, and measure names.
4. Open the `.pbip` file in Power BI Desktop and refresh connections.
5. Commit source files (PBIP/TMDL/JSON/DAX/M), not local cache artifacts.

## Naming

- Use lowercase folder names under `reports/`.
- Use descriptive report folders such as `service-requests-operations`.
- Keep one report project per folder.
