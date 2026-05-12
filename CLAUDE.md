# YOUR_PROJECT_NAME — Claude Code Instructions

## Project Identity

- **Project name:** YOUR_PROJECT_NAME
- **Solution unique name:** YOUR_SOLUTION_NAME
- **Publisher prefix:** YOUR_PUBLISHER_PREFIX
- **Organisation URL:** YOUR_ORG_URL
- **Org / tenant:** YOUR_ORG_NAME
- **Cloud environment:** YOUR_CLOUD_ENV (commercial | gcc | gcch | dod)

Fill in `project.tokens.json` and run `.\scripts\Apply-ProjectTokens.ps1 -Environment dev` to stamp these values across the repo.

## Solution & Publisher

- Solution unique name: `YOUR_SOLUTION_NAME`
- Publisher prefix: `YOUR_PUBLISHER_PREFIX` — all custom entities, columns, choices, and relationships use this prefix; no exceptions
- Target environment: `YOUR_ORG_URL`

## PAC CLI

- Always use `--modelVersion 2` for all power pages commands
- Upload: `pac pages upload --path "<portal-path>\YOUR_PORTAL_SLUG" --modelVersion 2`
- Download: `pac pages download --path "<portal-parent-path>" --modelVersion 2`
- Full reference: `PAC_COMMANDS.md`

## File Organisation

```
YOUR_PROJECT_ID/
├── automations/         # Non-flow automation assets
│   └── emails/          # Managed email templates (templates.json + HTML body files)
├── power pages/         # Power Pages portal assets (PAC CLI v2 format)
├── scripts/             # PowerShell deployment & export scripts
├── tables/              # Dataverse table definitions (JSON)
│   ├── choices/         # Global option sets
│   └── relationships/   # Relationship definitions (definitions.json + individual files)
├── flows/               # Power Automate flow definitions
├── copilot agents/      # Copilot Studio agent assets
├── reports/             # Power BI PBIP report templates and model assets
├── plugins/             # Dataverse plugin projects
├── tests/e2e/           # Playwright E2E tests
└── PAC_COMMANDS.md      # PAC CLI reference
```

## JSON Files

- 2-space indentation
- Include `description` fields on tables, columns, choices, and relationships
- Each table gets its own folder under `tables/` with `definition.json` and `README.md`

## Configuration & Secrets

- Environment configs: `scripts/config-{env}.json`
- Secrets via environment variables only — never in config files
- Secret variable names: `DATAVERSE_CLIENT_SECRET_DEV`, `DATAVERSE_CLIENT_SECRET_PROD`
- API version: `v9.2`

## Export Output

Exports go to `scripts/exports/YOUR_SOLUTION_NAME/` organised by component type, each with a `_summary.json`.

## Project Plan

Maintain `requirements/PLAN.md`. Track status with: `✅ Done`, `⬜ Verify`, `⬜ TODO`, `Future`.

- After deployment, set related plan items to `⬜ Verify` until post-deployment validation passes
- Keep summary scorecard totals in sync

## Token System

`Apply-ProjectTokens.ps1` scans all `*.md`, `*.ps1`, `*.json`, `*.ts`, `*.yml`, `*.yaml`, `*.html`, `*.txt` files recursively. `YOUR_*` placeholders in this file and all subdirectory `CLAUDE.md` files are stamped automatically.

### Project-level tokens (set once in `project.tokens.json > project.required`)

| Token | Purpose |
|---|---|
| `YOUR_PROJECT_NAME` | Human-readable project name used in UI labels and documentation |
| `YOUR_PROJECT_ID` | Short identifier used in folder names and prefixes |
| `YOUR_SOLUTION_NAME` | Dataverse solution unique name |
| `YOUR_PUBLISHER_PREFIX` | Publisher prefix for all custom Dataverse components |
| `YOUR_EMAIL_TEMPLATE_PREFIX` | Prefix for all managed email templates (e.g. `MyProject`). Used by `Import-EmailTemplates.ps1` to validate template names. Set to a short identifier with no spaces. |

### Optional tokens (set in `project.tokens.json > optional` and each env's `optional`)

| Token | Purpose |
|---|---|
| `YOUR_PROJECT_NUMBER` | GitHub Projects v2 project number — enables project board automation workflows |
| `YOUR_PROJECT_LABEL` | Label that triggers board tracking (e.g. `project:my-project`) — used by issue template and workflows |

## Git Workflow

**Never commit or push directly to `main`.** See `CONTRIBUTING.md` for the full contributor guide.

- Branch naming: `feat/`, `fix/`, `chore/`, `docs/`, `refactor/`, `release/vx.x.x`
- Commits: Conventional Commits format (`feat(scope): description`)
- PRs: squash-merge to `main`; link to issue with `Fixes #N`

## Area-Specific Instructions

Each subdirectory has its own `CLAUDE.md` loaded automatically when working in that area:

| Directory | Instructions cover |
|---|---|
| [scripts/](scripts/CLAUDE.md) | PowerShell conventions, Dataverse API patterns, error handling |
| [tables/](tables/CLAUDE.md) | Dataverse schema, column types, deployment order |
| [plugins/](plugins/CLAUDE.md) | C# plugin architecture, registration docs, ALM |
| [flows/](flows/CLAUDE.md) | Power Automate ALM, payload contract, change checklist |
| [power pages/](power%20pages/CLAUDE.md) | PAC CLI v2 format, Liquid templating, portal structure |
| [copilot agents/](copilot%20agents/CLAUDE.md) | Topic authoring, agent guardrails, pull/push workflow |
| [reports/](reports/CLAUDE.md) | Power BI PBIP structure, DAX/M organization, and review checklist |

## Git Tags

- All tags must use the format `vx.x.x` — lowercase `v` followed by three dot-separated integers (e.g. `v1.0.0`, `v2.3.14`)
- No `V` (uppercase), no `release/`, no `-beta`, no other prefixes, suffixes, or qualifiers
- Example: `git tag v1.2.3`

## Custom Slash Commands

| Command | Purpose |
|---|---|
| `/deploy` | Guided deployment workflow |
| `/export` | Guided component export |
| `/copilot-studio-edit` | Copilot Studio editing workflow with guardrails |
| `/sync-baseline` | Cherry-pick baseline updates from template |
