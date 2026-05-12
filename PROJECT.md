# Project Configuration

> **This file is the single source of truth for project-specific values.**
> After creating a new project from this template, fill in every value below
> and then do a global find-and-replace across the repo using the mapping in
> the table, replacing the placeholder token with your actual value.

## Token Reference

Project identity tokens are now configured once under `project.required` in `project.tokens.json`.
Environment-specific values remain under `dev.required`, `test.required`, and `prod.required`.

| Token | Required | Description | Example |
|-------|----------|-------------|---------|
| `YOUR_PROJECT_NAME` | Yes | Human-readable project name | `Fairfax County 311` |
| `YOUR_PROJECT_ID` | Yes | Short slug, lowercase-hyphen | `fairfax-311` |
| `YOUR_ORG_NAME` | Yes | GitHub org / company name | `andworx` |
| `YOUR_SOLUTION_NAME` | Yes | Dataverse solution unique name | `311` |
| `YOUR_PUBLISHER_PREFIX` | Yes | Dataverse publisher prefix (no trailing `_`) | `andy` |
| `YOUR_ORG_URL` | Yes | Dataverse org hostname (no `https://`) | `andworx-development.crm.dynamics.com` |
| `YOUR_TENANT_ID` | Yes | Azure AD tenant GUID | `7cea0515-...` |
| `YOUR_CLOUD_ENV` | Yes | Cloud authority host selector (`commercial`, `gcc`, `gcch`, `dod`) | `commercial` |
| `YOUR_CLIENT_ID` | No* | App registration client GUID — *needed for Power Automate automations to work | `347aeaed-...` |
| `YOUR_PORTAL_SLUG` | No | PAC CLI portal subfolder name — only needed if the project includes Power Pages | `fairfax-county-311` |
| `YOUR_WEBSITE_ID` | No | Power Pages website GUID — only needed if the project includes Power Pages | `5ae8f94a-...` |
| `YOUR_PORTAL_FOLDER` | No | Parent portal folder name — only needed if the project includes Power Pages | `andworx-311-portal---311andworx` |

## Applying Tokens

Tokens are managed through two files at the repo root:

| File | Purpose |
|------|---------|
| `project.tokens.json` | Your token values — edit this file |
| `project.tokens.applied.json` | Tracks what was last applied — do not edit manually |

### Workflow

1. Open `project.tokens.json` and fill in any values you know right now.
   - Set project identity values first in `project.required` (`YOUR_PROJECT_NAME`, `YOUR_PROJECT_ID`, `YOUR_SOLUTION_NAME`, `YOUR_PUBLISHER_PREFIX`).
   - Leave a token at its placeholder value (e.g. `"YOUR_TENANT_ID"`) if you don't have it yet — it will be skipped.
   - Set optional Power Pages tokens to `null` if this project has no portal.
2. Run the apply script from the repo root:

```powershell
.\scripts\Apply-ProjectTokens.ps1
```

3. When you get a missing value later, update `project.tokens.json` and re-run the script — it will stamp only the new tokens.
4. If a previously-set value changes (e.g. the org URL changes), update it in `project.tokens.json` and re-run — the script replaces the old value with the new one everywhere.

### Useful flags

```powershell
# Preview what would be applied without writing any files
.\scripts\Apply-ProjectTokens.ps1 -WhatIf

# Apply a single token only
.\scripts\Apply-ProjectTokens.ps1 -Token YOUR_ORG_URL
```

## Baseline Version

This project was created from baseline: **v1.0.0** (April 2026)

See [BASELINE_VERSION.md](BASELINE_VERSION.md) for upgrade notes.
