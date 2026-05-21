# AgenticIoT — Deployment Guide

## Prerequisites

- **PowerShell 5.1+** (Windows PowerShell or PowerShell 7+)
- **Azure AD App Registration** with Dataverse API permissions (`user_impersonation`)
- **Client Secret** for the app registration
- **PAC CLI** installed for power pages (separate from these scripts)

## Quick Setup

### 1. Configure Secrets

```powershell
# Run from repo root
Copy-Item .env.example .env
# Edit .env → set DATAVERSE_CLIENT_SECRET_DEV=your-actual-secret
```

> **Security:** Never commit `.env` to source control. It is in `.gitignore`.

### 2. Create Config

```powershell
Copy-Item config-dev.example.json config-dev.json
# Edit config-dev.json → fill in iot-agents.crm.dynamics.com/, 7cea0515-a5e4-4e8a-8f2a-6d1ad5d6b9f8, 347aeaed-b2d1-4b76-a4ff-0d2b340f707e,
#  commercial, andy, AgenticIoT
```

### 3. Verify Configuration

```powershell
.\Validate-DeploymentSetup.ps1
```

### 4. Run CI-Safe Table Definition Preflight

```powershell
.\Validate-TableDefinitions.ps1
```

This validates `tables/**/definition.json` files (excluding `choices` and `relationships`) without making Dataverse API calls.

### 5. Test Connectivity

```powershell
.\Validate-DeploymentSetup.ps1 -TestConnection
```

### 6. Run Your First Export

```powershell
.\Deploy-Project.ps1 -Job Export-Tables -Environment dev
```

---

## Environment Configuration

Each environment has a `config-{name}.json` file. See `config-dev.example.json` for the full schema:

```json
{
  "environmentUrl": "https://iot-agents.crm.dynamics.com/",
  "apiVersion": "v9.2",
  "tenantId": "7cea0515-a5e4-4e8a-8f2a-6d1ad5d6b9f8",
  "clientId": "347aeaed-b2d1-4b76-a4ff-0d2b340f707e",
  "cloudEnvironment": " commercial",
  "publisherPrefix": "andy",
  "solutionUniqueName": "AgenticIoT"
}
```

### Adding a New Environment

1. Copy `config-dev.json` → `config-prod.json`
2. Change `environmentUrl` to the production URL
3. Add `DATAVERSE_CLIENT_SECRET_PROD=<secret>` to `.env`
4. Run: `.\Validate-DeploymentSetup.ps1 -Environment prod`

### Secrets Lookup Chain

Auth resolves secrets in this order:
1. `DATAVERSE_CLIENT_SECRET_{ENV}` (e.g., `DATAVERSE_CLIENT_SECRET_DEV`)
2. `DATAVERSE_CLIENT_SECRET` (generic fallback)
3. Error if neither is found

---

## Available Jobs

| Job | Description |
|-----|-------------|
| `Export-All` | Run all export jobs in sequence |
| `Export-Tables` | Tables, columns, and alternate keys |
| `Export-Flows` | Power Automate cloud flows (with full definitions) |
| `Export-Relationships` | Entity relationships (1:N, N:1, N:N) |
| `Export-Forms` | Model-driven app forms (FormXML + metadata) |
| `Export-Views` | Saved queries / views (FetchXML + layout) |
| `Export-WebResources` | Web resources (JS, CSS, HTML, images) — decoded from base64 |
| `Export-SecurityRoles` | Security roles and their privileges |
| `Export-CanvasApps` | Canvas app metadata |
| `Export-EnvironmentVariables` | Environment variable definitions and current values |
| `Import-Choices` | Create/update global option sets from `tables/choices/` |
| `Import-Tables` | Create/update Dataverse tables from `tables/` definitions |
| `Import-EmailTemplates` | Create/update managed email templates |
| `Import-Relationships` | 1:N relationships and lookup columns |
| `Import-Flows` | Import Power Automate cloud flows from `flows/` JSON |
| `Import-All` | Run choices → tables → email templates → relationships → flows in sequence |

### Adding Project-Specific Jobs

1. Add a job name to `[ValidateSet()]` in `Deploy-Project.ps1`
2. Dot-source the script in the "Source all scripts" block
3. Add an entry to `$jobMap`
4. Add to the interactive menu in `Select-JobInteractive`

---

## Flow Import Modes

For normal deployments, run `Import-Flows` without `-ReplaceExistingFlows` — existing flows patch in place and preserve their connector authorization and run history.

Use `-ReplaceExistingFlows` only as an explicit recovery step when you need to delete and recreate a broken workflow record.

### Connection Reference Binding

After first import, bind connection references in Power Automate:
**Solution → Connection References** → link each reference to a live connection.

---

## Common Workflows

### Interactive Mode (default)
```powershell
.\Deploy-Project.ps1
# Shows: environment menu → dry-run toggle → job menu → runs → opens HTML report
```

### Export Specific Component
```powershell
.\Deploy-Project.ps1 -Job Export-Tables -Environment dev
.\Deploy-Project.ps1 -Job Export-Flows -Environment dev
```

### Export Everything
```powershell
.\Deploy-Project.ps1 -Job Export-All -Environment dev
```

### Production (With Safety)
```powershell
# Must type YES (all caps) to confirm
.\Deploy-Project.ps1 -Job Export-All -Environment prod
```

### CI/CD (Non-Interactive)
```powershell
$env:DATAVERSE_CLIENT_SECRET_DEV = $secretFromKeyVault
.\Deploy-Project.ps1 -Job Export-All -Environment dev -SkipConfirmation
```

---

## Output Structure

All exports go to `scripts/exports/AgenticIoT/`:

```
exports/AgenticIoT/
├── tables/             # Table, column, key definitions
├── relationships/      # 1:N and N:N relationship definitions
├── flows/              # Cloud flow definitions (JSON)
├── forms/              # FormXML + metadata by table
├── views/              # FetchXML + layout by table
├── webresources/       # Decoded JS, CSS, HTML files
├── securityroles/      # Role + privilege definitions
├── canvasapps/         # Canvas app metadata
├── environmentvariables/ # All env var defs + current values
└── run-report-*.html   # Per-run HTML report
```

---

## Script Architecture

```
Deploy-Project.ps1              ← Master orchestrator (entry point)
├── Connect-Dataverse.ps1       ← OAuth2 auth (commercial/gcc/gcch/dod)
├── Invoke-DataverseApi.ps1     ← HTTP wrapper with 429 retry
├── Export-Tables.ps1           ← Tables, columns, keys
├── Export-Relationships.ps1    ← 1:N, N:1, N:N relationships
├── Export-Flows.ps1            ← Cloud flow definitions
├── Export-Forms.ps1            ← FormXML + metadata
├── Export-Views.ps1            ← FetchXML + layout
├── Export-WebResources.ps1     ← Decoded web resources
├── Export-SecurityRoles.ps1    ← Roles + privileges
├── Export-CanvasApps.ps1       ← Canvas app metadata
├── Export-EnvironmentVariables.ps1  ← Env var defs + values
├── Import-Choices.ps1          ← Global option sets
├── Import-Tables.ps1           ← Table + column schema
├── Import-EmailTemplates.ps1   ← Managed email templates
├── Import-Relationships.ps1    ← Cross-table relationships
├── Import-Flows.ps1            ← Cloud flow definitions
├── Validate-TableDefinitions.ps1  ← CI-safe table schema preflight
└── Validate-DeploymentSetup.ps1  ← Pre-flight checks
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Auth fails | Check `.env` secret value; regenerate if expired |
| Solution not found | Verify `solutionUniqueName` in config matches Dataverse |
| No components exported | Add components to the solution in the maker portal |
| Throttled (429) | Auto-retried; wait and re-run if persistent |
| `YOUR_` tokens in output | Run the find-replace script in `PROJECT.md` |

---

## power pages (PAC CLI v2)

```powershell
# Download portal files
pac pages download --overwrite \
  --path "power pages\\\YOUR_PORTAL_FOLDER" \
  --webSiteId YOUR_WEBSITE_ID \
  --modelVersion "2"

# Upload portal files
pac pages upload \
  --path "power pages\\\YOUR_PORTAL_FOLDER\YOUR_PORTAL_SLUG" \
  --modelVersion "2"
```

See `PAC_COMMANDS.md` for the full reference.
