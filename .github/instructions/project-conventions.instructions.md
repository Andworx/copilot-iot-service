---
description: "Use when working on AgenticIoT — general conventions for file organization, solution naming, PAC CLI usage, and deployment practices."
---
# AgenticIoT — Project Conventions

## Solution & Publisher

- Solution unique name: `AgenticIoT`
- Publisher prefix: `andy`
- Environment: `iot-agents.crm.dynamics.com/`

## PAC CLI

- Always use `--modelVersion 2` for power pages commands
- Upload command: `pac pages upload --path "<portal-path>\YOUR_PORTAL_SLUG" --modelVersion 2`
- Download command: `pac pages download --path "<portal-parent-path>" --modelVersion 2`
- See `PAC_COMMANDS.md` for full reference with paths

## File Organization

```
AgenticIoT/
├── automations/        # Non-flow automation assets
│   └── emails/          # Managed email templates (templates.json + HTML body files)
├── power pages/            # power pages portal assets (PAC CLI v2 format)
├── scripts/             # PowerShell deployment & export scripts
├── tables/              # Dataverse table definitions (JSON)
│   ├── choices/         # Global option sets
│   └── relationships/   # Relationship definitions
├── flows/               # Power Automate flow definitions
├── copilot agents/      # Copilot Studio agent assets
├── reports/             # Power BI PBIP report templates and model assets
├── tests/e2e/           # Playwright E2E tests
└── PAC_COMMANDS.md      # PAC CLI reference
```

## Folder Naming Convention

All folder names use **lowercase** — no capitalisation, no PascalCase, no camelCase.

Examples: `automations/emails/`, `tables/choices/`, `flows/`, `copilot agents/`

## JSON Files

- Use 2-space indentation
- Include `description` fields on tables, columns, choices, and relationships
- Each table gets its own folder under `tables/` with a `definition.json` and `README.md`

## Configuration

- Environment configs: `scripts/config-{env}.json`
- Secrets via environment variables, never in config files
- API version: `v9.2`

## Export Output

Exports go to `scripts/exports/AgenticIoT/` organized by component type, each with a `_summary.json`.

## README Maintenance (Required)

Every component directory must have an up-to-date `README.md`. When adding, removing, or significantly changing a component, update the directory's `README.md` in the same change set as the code change.

### README update triggers

| Change | README to update |
|--------|-----------------|
| Flow added, removed, or renamed | `flows/README.md` (Flows table) |
| New Copilot Studio agent | Create `copilot agents/<name>/README.md`; update `copilot agents/README.md` (Agents table) |
| New Dataverse table | Create `tables/<name>/README.md` describing the table's purpose and columns |
| New plugin project | Create `plugins/<name>/README.md`; update `plugins/README.md` |
| New Power BI report | Create `reports/<name>/README.md`; update `reports/README.md` (Reports table) |
| New portal added | Update `power pages/README.md` (Portals section) |
| Script added, removed, or renamed | `scripts/README.md` (Scripts tables) |
| New canvas app | Update `apps/README.md` (Apps table) |
| Test suite added | Update `tests/README.md` |

### README content minimum

Each component README must cover:
- **Purpose** — what the component does and why it exists
- **Structure** — folder layout and key files
- **Usage or workflow** — how to work with the component
- **Updating the README** — a reminder of what changes require an update

## Project Plan

Maintain a project plan in `requirements/PLAN.md` (or equivalent docs folder). Track requirements with status columns showing Done, Verify, TODO, and Future.

- Update `requirements/PLAN.md` in the same change set whenever implementation status or scope changes
- After every push that changes `tables/`, `flows/`, `copilot agents/`, `power pages/`, `plugins/`, or `reports/`, update the plan before marking the task complete
- When a flow is deployed, set related items to `⬜ Verify` until post-deployment validation passes
- After post-deployment validation passes, move items from `⬜ Verify` to `✅ Done` with a brief note/date
- Keep summary scorecard totals in sync

## Git Tags

- All repository release tags must use this exact format: `vx.x.x`
- `v` must be lowercase and followed by three dot-separated integers (for example: `v1.0.0`)
- Do not use any other syntax: no uppercase `V`, no prefixes (such as `release/`), and no suffixes (such as `-beta`, `-rc1`)
- Use `git tag v1.2.3` as the canonical command pattern

## Git Workflow

**Never commit or push directly to `main`.** All changes must go through a feature branch and a pull request. See `CONTRIBUTING.md` for the full contributor guide.

### Branch Naming

| Prefix | Use for |
|--------|---------|
| `feat/short-description` | New features |
| `fix/short-description` | Bug fixes |
| `chore/short-description` | Maintenance / config |
| `docs/short-description` | Documentation only |
| `refactor/short-description` | Restructuring without behaviour change |
| `release/vx.x.x` | Release preparation |

### Workflow

1. Always start from an up-to-date `main`: `git checkout main && git pull origin main`
2. Create a branch: `git checkout -b feat/my-feature`
3. Commit using conventional commits: `feat(scope): description`
4. Push the branch: `git push -u origin feat/my-feature`
5. Open a PR: `gh pr create --title "feat(scope): description"`
6. Wait for review and approval before merging
7. Squash-merge into `main`; delete the branch after merge

### AI Assistant Rules

- Before starting any new feature or fix, always check out a new branch from an up-to-date `main`
- Never commit or push directly to `main`
- Use `gh pr create` to open PRs — include a concise title and summary body
- When working on `main`, create a feature branch first before modifying any files
