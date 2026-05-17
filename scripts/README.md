# Scripts

PowerShell deployment, provisioning, and export scripts for the AgenticIoT project.

---

## Prerequisites

- **Azure CLI** — `az login` before running any Azure scripts
- **Azure IoT extension** — `az extension add --name azure-iot`
- **Power Platform CLI** — for Dataverse/Power Platform scripts (`pac auth create`)
- **Config file** — copy `config-dev.example.json` → `config-dev.json` and fill in real values

Config files (`config-dev.json`, `config-test.json`, `config-prod.json`) are gitignored. Never commit them.

---

## Azure Infrastructure

| Script | Purpose |
|--------|---------|
| `New-AzureIotInfrastructure.ps1` | Provision resource group, IoT Hub, DPS, and group enrollment |
| `New-PiBootConfig.ps1` | Write zero-touch credentials to Raspberry Pi SD card boot partition |

### New-AzureIotInfrastructure.ps1

Idempotent — safe to re-run. Creates all Azure IoT resources in `rg-aw-azcom-iot-copilot`.

```powershell
# Dev environment (Free IoT Hub tier)
.\New-AzureIotInfrastructure.ps1 -Environment dev

# Preview without making changes
.\New-AzureIotInfrastructure.ps1 -Environment dev -DryRun

# Production (S1 IoT Hub tier, different region)
.\New-AzureIotInfrastructure.ps1 -Environment prod -Location westus2
```

**Outputs** (printed at end, not stored in files):
- DPS ID Scope — for `New-PiBootConfig.ps1 -IdScope`
- DPS Group Key — for `New-PiBootConfig.ps1 -GroupKey` *(see issue #67)*

Store these in Azure Key Vault immediately after provisioning.

### New-PiBootConfig.ps1

Writes zero-touch provisioning credentials to a Raspberry Pi SD card boot partition.

> **Note:** Currently writes `IOT_HUB_CONNECTION_STRING`. Will be updated in [issue #67](https://github.com/Andworx/copilot-iot-service/issues/67) to use DPS credentials (`-IdScope` / `-GroupKey`).

```powershell
# Current (connection string — pre-DPS)
$conn = az iot hub device-identity connection-string show `
    --hub-name iothub-aw-iot-copilot `
    --device-id raspberry-pi-iotpanel `
    --query connectionString -o tsv
.\New-PiBootConfig.ps1 -DriveLetter E -ConnectionString $conn
```

---

## Dataverse / Power Platform

| Script | Purpose |
|--------|---------|
| `Apply-ProjectTokens.ps1` | Stamp `YOUR_*` placeholders across the repo from `project.tokens.json` |
| `Connect-Dataverse.ps1` | Authenticate to Dataverse and return a connection object |
| `Deploy-Project.ps1` | Full solution deployment (tables → choices → relationships → flows) |
| `Validate-DeploymentSetup.ps1` | Pre-flight check before deploying |
| `Validate-TableDefinitions.ps1` | Validate all `tables/*/definition.json` files |

### Apply-ProjectTokens.ps1

Run this after filling in `project.tokens.json`:

```powershell
.\Apply-ProjectTokens.ps1 -Environment dev
```

### Deploy-Project.ps1

```powershell
.\Deploy-Project.ps1 -Environment dev
.\Deploy-Project.ps1 -Environment prod -DryRun
```

---

## Export Scripts

| Script | Purpose |
|--------|---------|
| `Export-Tables.ps1` | Export Dataverse table definitions |
| `Export-Flows.ps1` | Export Power Automate cloud flows |
| `Export-CanvasApps.ps1` | Export canvas apps |
| `Export-SecurityRoles.ps1` | Export security role definitions |
| `Export-Relationships.ps1` | Export table relationships |
| `Export-Views.ps1` | Export Dataverse views |
| `Export-Forms.ps1` | Export Dataverse forms |
| `Export-WebResources.ps1` | Export web resources |
| `Export-EnvironmentVariables.ps1` | Export environment variable definitions |

All exports go to `scripts/exports/AgenticIoT/` organized by component type.

---

## Import Scripts

| Script | Purpose |
|--------|---------|
| `Import-Tables.ps1` | Import Dataverse table definitions |
| `Import-Choices.ps1` | Import global option sets |
| `Import-Flows.ps1` | Import Power Automate flows |
| `Import-Relationships.ps1` | Import table relationships |
| `Import-EmailTemplates.ps1` | Import managed email templates |

---

## Utilities

| Script | Purpose |
|--------|---------|
| `Invoke-DataverseApi.ps1` | Low-level Dataverse API helper used by other scripts |
| `Migrate-TokensToEnvironments.ps1` | Migrate token config between environment files |
| `Sync-BaselineUpdate.ps1` | Cherry-pick baseline updates from template repo |
| `Sync-RemoteCopilotAssets.ps1` | Sync Copilot Studio assets from environment |

---

## Updating This README

Update this file when a script is added, removed, renamed, or its parameters change significantly.
