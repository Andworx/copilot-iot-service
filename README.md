# andworx-power-platform-starter-template

Reusable baseline for Power Platform projects built with Dataverse, Power Automate, power pages, Copilot Studio, and Power BI.

## What's Included

| Area | Contents |
|------|----------|
| **Apps** | `apps/` folder for app-level assets and source folders |
| **PowerShell Scripts** | Dataverse auth, HTTP wrapper, deploy orchestrator, and full export/import suite in `scripts/` |
| **Dataverse Tables** | Schema convention docs, `tables/choices/` and `tables/relationships/` structure, and SVG icon support (Fluent UI / Iconify) with automated web resource deployment |
| **Power Automate Flows** | `flows/` folder with connection reference templates, environment variable templates, and adaptive cards |
| **power pages** | `power pages/` portal structure plus PAC CLI v2 command conventions |
| **Copilot Studio** | `copilot agents/` folder with topic authoring and operational guidance |
| **Power BI Reports** | `reports/` PBIP report templates, DAX/M starters, and build guidance |
| **Plugin Project Template** | `plugins/dataverse-plugin-template/` starter C# Dataverse plugin project |
| **Playwright Tests** | E2E test harness with contract and live test projects |
| **.github/instructions** | Copilot coding agent instructions for every layer of the stack |
| **Claude Code** | `CLAUDE.md` hierarchy + `.claude/commands/` slash commands for Claude Code users |

## Starting a New Project From This Template

1. On GitHub, click **"Use this template"** → name your new repo.
2. Clone it locally.
3. Open `project.tokens.json` and fill in the values you know right now. Leave any unknown tokens at their placeholder value — they'll be skipped until you're ready.
4. Run `.\scripts\Apply-ProjectTokens.ps1` to stamp your tokens across the repo. Re-run it any time you add or change a value in `project.tokens.json`. At the end of the run, you will be offered the option to sync remote Copilot assets (instructions/agents/skills).
5. Rename `scripts/Deploy-Project.ps1` if desired (`Deploy-{YourProject}.ps1`).
6. Add your project-specific jobs to `Deploy-Project.ps1` (`ValidateSet` and job dispatch).
7. Rename `scripts/config-dev.example.json` → `scripts/config-dev.json` and fill in your values.
8. Copy `.env.example` → `.env` (repo root) and add your client secret.
9. Run `.\scripts\Validate-DeploymentSetup.ps1` to verify your setup.

## Remote Copilot Asset Sync

`Apply-ProjectTokens.ps1` can optionally download curated Copilot **instructions**, **agents**, and **skills** from one or more upstream GitHub repos into your local project — without vendoring those files in the template itself.

### Where upstream files land

| Kind | Destination |
|------|-------------|
| Instructions | `.github/instructions/upstream/<sourceKey>/<remotePath>` |
| Agents | `.github/agents/upstream/<sourceKey>/<remotePath>` |
| Skills | `.github/skills/upstream/<sourceKey>/<remotePath>` |
| Claude commands | `.claude/commands/upstream/<sourceKey>/<remotePath>` |

Remote paths are preserved exactly (e.g. `instructions/powershell.instructions.md` → `.github/instructions/upstream/awesome-copilot/instructions/powershell.instructions.md`).

A sync-state record is written to `.github/upstream/<sourceKey>/SYNC_STATE.json` after each run.

> **Do not edit upstream files directly.** They will be overwritten on the next sync. Create local override copies elsewhere in your repo.

### Running sync manually

```powershell
# Interactive (prompts which sources to sync)
.\scripts\Sync-RemoteCopilotAssets.ps1

# Sync all enabled sources without prompting
.\scripts\Sync-RemoteCopilotAssets.ps1 -AllSources -NoPrompt

# Sync a specific source
.\scripts\Sync-RemoteCopilotAssets.ps1 -SourceKeys awesome-copilot -NoPrompt
```

### Controlling sync from Apply-ProjectTokens.ps1

```powershell
# Skip sync entirely (no prompts)
.\scripts\Apply-ProjectTokens.ps1 -Environment dev -SkipRemoteSync

# Force sync of all sources without prompting
.\scripts\Apply-ProjectTokens.ps1 -Environment dev -RemoteSync

# Force sync of specific sources only
.\scripts\Apply-ProjectTokens.ps1 -Environment dev -RemoteSyncSourceKeys awesome-copilot

# Suppress interactive prompt (sync if flags say to, otherwise skip)
.\scripts\Apply-ProjectTokens.ps1 -Environment dev -RemoteSyncNoPrompt
```

### Adding more files or sources

Edit `scripts/remote-content.sources.json`. Each source entry requires:

| Field | Description |
|-------|-------------|
| `key` | Unique identifier used in destination folder paths |
| `repo` | GitHub `owner/repo` |
| `ref` | Branch, tag, or commit SHA |
| `enabled` | Set to `false` to disable without deleting |
| `items.instructions` | Array of paths relative to the source repo root |
| `items.agents` | Array of agent file paths |
| `items.skills` | Array of skill file paths |
| `items.claudeCommands` | Array of file paths to also sync as Claude Code slash commands |

Optional: set `GITHUB_TOKEN` or `GH_TOKEN` in your environment for authenticated requests (avoids GitHub's unauthenticated rate limits).

## Day-0 Prerequisites

- PowerShell 5.1+ or PowerShell 7+
- [PAC CLI](https://learn.microsoft.com/power-platform/developer/cli/introduction) installed
- Node.js 18+ (for Playwright tests)
- Azure AD app registration with Dataverse `user_impersonation` permissions
- [GitHub CLI (`gh`)](https://cli.github.com) — required for Copilot Studio agent workflows (PR creation, branching, release tagging)

## Repository Layout

```
andworx-power-platform-starter-template/
├── .claude/
│   └── commands/                        # Claude Code slash commands (/deploy, /export, etc.)
├── .github/
│   └── instructions/                    # Copilot agent instructions by technology area
├── apps/                                # App-level assets and source folders
├── copilot agents/
│   └── README.md                        # Copilot Studio asset guidance
├── flows/
│   ├── adaptive-cards/                  # Adaptive Card payload templates
│   ├── connection-references.example.json
│   └── environment-variables.example.json
├── plugins/
│   ├── README.md
│   └── dataverse-plugin-template/       # Dataverse plugin starter project
├── reports/
│   ├── README.md                        # Power BI report template guidance
│   └── starter-pbip-template/           # Generic PBIP report starter project
├── power pages/
│   └── README.md                        # power pages folder conventions
├── scripts/
│   ├── exports/                         # Export outputs from deployment scripts
│   ├── DEPLOYMENT_GUIDE.md
│   ├── QUICK_REFERENCE.md
│   └── *.ps1                            # Deploy, import, export, and Dataverse API scripts
├── tables/
│   ├── choices/
│   ├── relationships/
│   └── README.md
├── tests/
│   └── e2e/
│       ├── pages/
│       ├── specs/
│       └── utils/
├── BASELINE_VERSION.md
├── PAC_COMMANDS.md
├── PROJECT.md
├── README.md
├── package.json
├── playwright.config.ts
├── playwright.live.config.ts
├── project.tokens.json
├── project.tokens.applied.json
└── tsconfig.json
```

## Dataverse Plugin Template Project

Use `plugins/dataverse-plugin-template/` as the starting point for new Dataverse plugin assemblies.

It provides a baseline structure, sample plugin class, and strong-name key workflow so teams can copy it, rename for their domain, and implement project-specific business logic with consistent conventions.

## Contributing Back to the Baseline

When you build something reusable in a downstream project:

1. Generalize the improvement (remove project-specific names, add tokens).
2. Open a PR against this baseline repo.
3. Create a new baseline release tag (e.g., `v1.1.0`) with release notes.
4. Cherry-pick the commit into any other active projects that benefit.

See `BASELINE_VERSION.md` for the version history.

## Updating a Downstream Repo From Baseline Tags

Use the standardized one-command script in downstream repos created from this template:

```powershell
.\scripts\Sync-BaselineUpdate.ps1 -OldTag v1.1.0 -NewTag v1.2.0 -BranchName baseline-v1.2.0
```

What it does:
- Ensures the `baseline` remote exists and fetches tags
- Creates a new branch from `main`
- Cherry-picks all commits in `OldTag..NewTag` in order

Run `-DryRun` first to preview commits without making changes.
