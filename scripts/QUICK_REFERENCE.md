# AgenticIoT — Quick Reference

## Baseline Template Sync (Downstream Repos)

```powershell
# Standardized template update flow (old tag + new tag + branch name)
.\Sync-BaselineUpdate.ps1 -OldTag v1.1.0 -NewTag v1.2.0 -BranchName baseline-v1.2.0

# Preview only
.\Sync-BaselineUpdate.ps1 -OldTag v1.1.0 -NewTag v1.2.0 -BranchName baseline-v1.2.0 -DryRun
```

## 30-Second Setup

```powershell
# Run from repo root:
# 1. Copy .env.example → .env (repo root) and set DATAVERSE_CLIENT_SECRET_DEV=<your-secret>
# 2. Copy scripts/config-dev.example.json → scripts/config-dev.json and fill in values
cd scripts
.\Validate-DeploymentSetup.ps1
.\Deploy-Project.ps1 -Job Export-All -Environment dev
```

## Common Commands

```powershell
# Interactive mode (menus)
.\Deploy-Project.ps1

# Export everything
.\Deploy-Project.ps1 -Job Export-All -Environment dev

# Export specific components
.\Deploy-Project.ps1 -Job Export-Tables -Environment dev
.\Deploy-Project.ps1 -Job Export-Flows -Environment dev
.\Deploy-Project.ps1 -Job Export-Relationships -Environment dev
.\Deploy-Project.ps1 -Job Export-Forms -Environment dev
.\Deploy-Project.ps1 -Job Export-Views -Environment dev
.\Deploy-Project.ps1 -Job Export-WebResources -Environment dev
.\Deploy-Project.ps1 -Job Export-SecurityRoles -Environment dev
.\Deploy-Project.ps1 -Job Export-CanvasApps -Environment dev
.\Deploy-Project.ps1 -Job Export-EnvironmentVariables -Environment dev

# Import (full bootstrap sequence)
.\Deploy-Project.ps1 -Job Import-All -Environment dev

# Import specific components
.\Deploy-Project.ps1 -Job Import-Choices -Environment dev
.\Deploy-Project.ps1 -Job Import-Tables -Environment dev
.\Deploy-Project.ps1 -Job Import-Relationships -Environment dev
.\Deploy-Project.ps1 -Job Import-Flows -Environment dev

# Validate setup
.\Validate-DeploymentSetup.ps1
.\Validate-DeploymentSetup.ps1 -TestConnection

# Production (requires YES confirmation)
.\Deploy-Project.ps1 -Job Export-All -Environment prod
```

## Secrets Setup

| Variable | Purpose |
|----------|---------|
| `DATAVERSE_CLIENT_SECRET_DEV` | Dev environment secret |
| `DATAVERSE_CLIENT_SECRET_STAGING` | Staging secret |
| `DATAVERSE_CLIENT_SECRET_PROD` | Production secret |

## Jobs Reference

| # | Job | What it does |
|---|-----|-----------------|
| 1 | `Export-All` | Everything below |
| 2 | `Export-Tables` | Tables, columns, keys |
| 3 | `Export-Flows` | Cloud flow definitions |
| 4 | `Export-Relationships` | 1:N, N:1, N:N relationships |
| 5 | `Export-Forms` | Model-driven forms (XML) |
| 6 | `Export-Views` | Views (FetchXML) |
| 7 | `Export-WebResources` | JS, CSS, HTML, images |
| 8 | `Export-SecurityRoles` | Roles + privileges |
| 9 | `Export-CanvasApps` | Canvas app metadata |
| 10 | `Export-EnvironmentVariables` | Env variable defs + values |
| 11 | `Import-All` | Choices → Tables → Email Templates → Relationships → Flows |
| 12 | `Import-Choices` | Global option sets |
| 13 | `Import-Tables` | Tables + columns |
| 14 | `Import-EmailTemplates` | Managed email templates |
| 15 | `Import-Relationships` | Cross-table relationships |
| 16 | `Import-Flows` | Cloud flow definitions |

## Output

All exports → `scripts/exports/AgenticIoT/{component-type}/`

Each run generates an HTML report that auto-opens in your browser.

## Project Tokens (Environment-Scoped)

Project tokens support dev, test, and prod environments with environment-specific values.

```powershell
# Edit project.tokens.json in repo root, fill in values for dev/test/prod sections
# Then apply tokens:

# Apply dev tokens interactively
.\Apply-ProjectTokens.ps1

# Apply specific environment
.\Apply-ProjectTokens.ps1 -Environment dev
.\Apply-ProjectTokens.ps1 -Environment test
.\Apply-ProjectTokens.ps1 -Environment prod

# Apply single token for specific environment
.\Apply-ProjectTokens.ps1 -Environment prod -Token iot-agents.crm.dynamics.com/

# Preview without writing files
.\Apply-ProjectTokens.ps1 -Environment prod -WhatIf

# Skip remote Copilot asset sync (no prompts)
.\Apply-ProjectTokens.ps1 -Environment dev -SkipRemoteSync

# Apply tokens and sync all remote Copilot assets without prompting
.\Apply-ProjectTokens.ps1 -Environment dev -RemoteSync

# Apply tokens and sync specific source(s) only
.\Apply-ProjectTokens.ps1 -Environment dev -RemoteSyncSourceKeys awesome-copilot

# Migrate old flat token format to environment-scoped structure
.\Migrate-TokensToEnvironments.ps1
```

## Remote Copilot Asset Sync

Downloads curated Copilot instructions, agents, and skills from upstream GitHub repos into `.github/**/upstream/`.

```powershell
# Interactive (prompts which sources to sync)
.\Sync-RemoteCopilotAssets.ps1

# Sync all enabled sources without prompting
.\Sync-RemoteCopilotAssets.ps1 -AllSources -NoPrompt

# Sync a specific source key
.\Sync-RemoteCopilotAssets.ps1 -SourceKeys awesome-copilot -NoPrompt

# Preview without writing files
.\Sync-RemoteCopilotAssets.ps1 -AllSources -WhatIf
```

**Where files land:**

| Kind | Destination |
|------|-------------|
| Instructions | `.github/instructions/upstream/<sourceKey>/<remotePath>` |
| Agents | `.github/agents/upstream/<sourceKey>/<remotePath>` |
| Skills | `.github/skills/upstream/<sourceKey>/<remotePath>` |

Sync state recorded in `.github/upstream/<sourceKey>/SYNC_STATE.json`.

To add more files or sources, edit `scripts/remote-content.sources.json`.

> Do not edit files under `upstream/` directly — they are overwritten on next sync. Create local copies elsewhere.

**Supported tokens per environment:**

| Token | Example | Environment | Scope |
|-------|---------|-------------|-------|
| `AgenticIoT` | My Project | All | Project identifier |
| `AgenticIoT` | proj-001 | All | Unique project ID |
| `iot-agents` | Andworx | All | Organization name |
| `AgenticIoT` | my_solution | All | Dataverse solution name |
| `andy` | andworx | All | Publisher prefix |
| `iot-agents.crm.dynamics.com/` | https://org.crm.dynamics.com | Env-specific | Dataverse instance |
| `7cea0515-a5e4-4e8a-8f2a-6d1ad5d6b9f8` | {guid} | Env-specific | Azure tenant |
| ` commercial` | commercial | Env-specific | Cloud authority host selector (`commercial`, `gcc`, `gcch`, `dod`) |
| `347aeaed-b2d1-4b76-a4ff-0d2b340f707e` | {guid} | Optional | Service principal |
| `YOUR_PORTAL_SLUG` | my-portal | Optional | Power Pages URL slug |
| `YOUR_WEBSITE_ID` | {guid} | Optional | Power Pages website ID |
| `YOUR_PORTAL_FOLDER` | power pages | Optional | Portal source folder |

Each run generates an HTML report that auto-opens in your browser.

## power pages (PAC CLI)

```powershell
# Download
pac pages download --overwrite \
  --path "power pages\\\YOUR_PORTAL_FOLDER" \
  --webSiteId YOUR_WEBSITE_ID \
  --modelVersion "2"

# Upload
pac pages upload \
  --path "power pages\\\YOUR_PORTAL_FOLDER\YOUR_PORTAL_SLUG" \
  --modelVersion "2"
```

## Flow Import Modes

```powershell
# Normal: update existing flow records in place (preserves history and auth)
.\Deploy-Project.ps1 -Job Import-Flows -Environment dev

# Recovery only: delete and recreate matching flows
.\Deploy-Project.ps1 -Job Import-Flows -Environment dev -ReplaceExistingFlows
```
