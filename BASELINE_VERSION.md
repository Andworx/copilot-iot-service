# Baseline Version

This file tracks which version of `andworx-power-platform-starter-template` this
project was created from, and records any baseline improvements that have been
cherry-picked in.

## Current Baseline

**v1.13.0** — May 2026

GitHub Issues + Project Board tracking system and convention improvements:
- `.github/ISSUE_TEMPLATE/tracked-work.md` — "Tracked Work Item" issue template with label taxonomy (type, area, priority) and acceptance criteria structure
- `.github/ISSUE_TEMPLATE/config.yml` — disables blank issues; directs users to PROJECT_BOARD_GUIDE.md
- `.github/workflows/project-auto-add.yml` — auto-adds labeled issues to the org GitHub Projects v2 board
- `.github/workflows/project-auto-move.yml` — moves linked issues to "In Review" / "Done" / "In Progress" based on PR status using `leonsteinhaeuser/project-beta-automations@v2.2.1`
- `.github/workflows/project-sync.yml` — adds project label to linked issue when PR is opened
- `.github/PROJECT_BOARD_GUIDE.md` — full setup and usage guide (project creation, required labels, PAT_PROJECT secret, column configuration, troubleshooting)
- `.github/pull_request_template.md` — standard PR template with Fixes # link, type/component checklists, and reviewer notes
- `.github/copilot-instructions.md` — GitHub Copilot assistant with issue-per-request workflow pattern
- `.github/instructions/project-board-workflow.instructions.md` — board workflow instructions for AI assistants
- `CONTRIBUTING.md` — branch naming, conventional commits, PR workflow, merge strategy, and branch protection guide
- `.github/instructions/project-conventions.instructions.md` — added README Maintenance section (update triggers per component type) and Git Workflow section (branch naming, step-by-step workflow, AI assistant rules); fixed `requirements/PLAN.md` path typo; expanded Project Plan section
- `project.tokens.json` — added `YOUR_PROJECT_NUMBER` (GitHub Projects v2 project number) and `YOUR_PROJECT_LABEL` (board tracking label) to `optional` tokens across all environments

Two new optional tokens:
- `YOUR_PROJECT_NUMBER` — GitHub Projects v2 project number (integer)
- `YOUR_PROJECT_LABEL` — label that triggers board tracking (e.g., `project:my-project`)

## Previous Baselines

### v1.12.0 — May 2026

CI preflight validation for Dataverse table definitions:
- Added `scripts/Validate-TableDefinitions.ps1` — 257-line validator that checks table, column, choice, and relationship JSON definitions for schema correctness before deployment
- Updated `DEPLOYMENT_GUIDE.md` with preflight validation step
- Minor `Validate-DeploymentSetup.ps1` improvements

### v1.11.0 — April 2026

SVG icon support for Dataverse tables:
- Extended `scripts/Import-Tables.ps1` with SVG icon upload (89 additions) using Dataverse entity image API
- Added PUT method support to `scripts/Invoke-DataverseApi.ps1`
- Added `tables/CLAUDE.md` and `tables/README.md` with icon conventions and column type reference
- Added `.github/instructions/dataverse-tables.instructions.md` with schema naming guidance

### v1.10.0 — April 2026

Token and release-tag governance updates:
- `project.tokens.json` now uses a top-level `project.required` section for identity tokens (`AgenticIoT`, `AgenticIoT`, `AgenticIoT`, `andy`)
- `dev`, `test`, and `prod` now contain only environment-specific required tokens
- `scripts/Apply-ProjectTokens.ps1` now processes project-scoped and environment-scoped tokens separately and persists project values in a dedicated `project` applied-state scope
- `PROJECT.md` updated to document the new token entry-point flow
- Copilot/Claude instructions standardized to enforce release tag format `vx.x.x` (lowercase `v` only)

### v1.9.0 — April 2026

Claude Code instructions and slash commands:
- Added root `CLAUDE.md` with project identity (stamped by `Apply-ProjectTokens.ps1`), conventions, and area index
- Added subdirectory `CLAUDE.md` files mirroring GitHub Copilot `applyTo` scoping: `scripts/`, `tables/`, `plugins/`, `flows/`, `power pages/`, `copilot agents/`
- Added `.claude/commands/` slash commands: `/deploy`, `/export`, `/copilot-studio-edit` (Claude equivalent of the GitHub Copilot "Copilot Studio Author" agent), `/sync-baseline`
- Extended `scripts/Sync-RemoteCopilotAssets.ps1` with `claudeCommands` item type routing downloads to `.claude/commands/upstream/<sourceKey>/<remotePath>`
- Updated `scripts/remote-content.sources.json` with `claudeCommands` array on each source entry
- All `CLAUDE.md` and `.claude/commands/*.md` files are automatically token-stamped by `Apply-ProjectTokens.ps1` via existing `*.md` extension scan

### v1.8.0 — April 2026

Remote Copilot asset sync:
- Added `scripts/remote-content.sources.json` manifest describing upstream sources and file lists
- Added `scripts/Sync-RemoteCopilotAssets.ps1` for downloading instructions/agents/skills from remote GitHub repos
- Extended `scripts/Apply-ProjectTokens.ps1` with `-SkipRemoteSync`, `-RemoteSync`, `-RemoteSyncSourceKeys`, and `-RemoteSyncNoPrompt` switches
- After token application, users are prompted to sync remote Copilot assets; non-fatal by default
- Upstream files land under `.github/<kind>/upstream/<sourceKey>/<remotePath>` with exact path preservation
- Per-source sync state written to `.github/upstream/<sourceKey>/SYNC_STATE.json`
- Optional `GITHUB_TOKEN` / `GH_TOKEN` auth header to avoid rate limiting
- Updated `README.md` and `scripts/QUICK_REFERENCE.md` with sync guidance and manifest extension instructions

### v1.4.0 — April 2026

Copilot Studio agent editing guardrails:
- Added `## Prerequisites` section to `.github/instructions/copilot-studio-agents.instructions.md` requiring GitHub CLI (`gh`) check (recommended, warn-not-block) and mandatory invocation of the **Copilot Studio Author** agent before any edit
- Updated `## Pull/Edit/Push Workflow` in that file — Steps 0 (verify `gh`) and 1 (invoke agent) prepended; original steps renumbered 2–6
- Added `## Before You Start` callout to `copilot agents/README.md` with same requirements and link to full instructions
- Added GitHub CLI to Day-0 Prerequisites in root `README.md`

## Previous Baselines

### v1.3.0 — April 2026

Standardized downstream baseline sync:
- Added `scripts/Sync-BaselineUpdate.ps1` for one-command updates using old tag, new tag, and branch name
- Script flow: fetch baseline tags, create update branch, cherry-pick `OldTag..NewTag` in order
- Added `-DryRun` preview mode for safe planning before applying changes
- Updated `README.md`, `scripts/QUICK_REFERENCE.md`, and this file with the standardized command pattern

## Previous Baselines

### v1.2.0 — April 2026

`.env` moved to repo root:
- `.env.example` moved from `scripts/` to repo root
- `Deploy-Project.ps1` and `Validate-DeploymentSetup.ps1` resolve `.env` from repo root
- `.gitignore`, `DEPLOYMENT_GUIDE.md`, `QUICK_REFERENCE.md`, and `README.md` updated accordingly

### v1.1.0 — April 2026

Incremental token stamping:
- `project.tokens.json` as single source of truth for all token values
- `project.tokens.applied.json` tracks last-applied values to enable updates
- `scripts/Apply-ProjectTokens.ps1` for partial/incremental setup and value changes
- Optional tokens: `YOUR_CLIENT_ID`, `YOUR_PORTAL_SLUG`, `YOUR_WEBSITE_ID`, `YOUR_PORTAL_FOLDER`
- `Validate-DeploymentSetup.ps1` now checks for pending and unstamped tokens

### v1.0.0 — April 2026

Initial release. Includes:
- PowerShell deployment/export/import framework
- Dataverse table, choice, and relationship conventions
- Power Automate flow ALM conventions
- power pages PAC CLI v2 structure and conventions
- Playwright E2E test harness
- `.github/instructions` Copilot agent instruction set

## Cherry-Picks Applied

| Date | Baseline Commit / Tag | Description |
|------|----------------------|-------------|
| — | — | None yet |

## How to Apply a Baseline Update

```powershell
# Standardized one-command sync (run from repo root)
.\scripts\Sync-BaselineUpdate.ps1 -OldTag v1.2.0 -NewTag v1.3.0 -BranchName baseline-v1.3.0

# Preview mode
.\scripts\Sync-BaselineUpdate.ps1 -OldTag v1.2.0 -NewTag v1.3.0 -BranchName baseline-v1.3.0 -DryRun
```

The script standardizes this process:
- Fetches baseline tags
- Creates a dedicated update branch
- Cherry-picks commits from `OldTag..NewTag` in order

Update the table above after completing and merging the update branch.
