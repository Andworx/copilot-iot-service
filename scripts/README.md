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
| `New-AzureMiddleware.ps1` | Provision Event Hub routing, SignalR, Function App, and Logic App middleware |
| `New-PiBootConfig.ps1` | Write zero-touch credentials to Raspberry Pi SD card boot partition |
| `deploy-pi-update.ps1` | Deploy updated Pi monitor code over SCP and restart the `iot-monitor` service |

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

Writes zero-touch DPS provisioning credentials to a Raspberry Pi SD card boot partition.
The SD card gets **fleet credentials** (same for all Pis) — per-device keys are derived at first boot.

```powershell
# Fetch DPS values from Azure CLI
$scope = az iot dps show `
    --name dps-aw-iot-copilot `
    --query properties.idScope -o tsv

$key = az iot dps enrollment-group show `
    --dps-name dps-aw-iot-copilot `
    --enrollment-id iotpanel-fleet `
    --show-keys `
    --query attestation.symmetricKey.primaryKey -o tsv

# Write to SD card (E: = boot partition drive letter)
.\New-PiBootConfig.ps1 -DriveLetter E -IdScope $scope -GroupKey $key

# Custom device ID (for fleet with unique names)
.\New-PiBootConfig.ps1 -DriveLetter E -IdScope $scope -GroupKey $key -DeviceId "pi-panel-02"
```

**What gets written to the SD card:**
| File | Contents |
|------|----------|
| `iot-credentials.env` | `DPS_ID_SCOPE`, `DPS_GROUP_KEY`, `DEVICE_ID` — shredded on first boot |
| `firstrun.sh` | First-boot script (downloaded from GitHub main) |
| `ssh` | Empty file — enables SSH |

**What happens on first boot (automatic):**
1. Pi reads fleet credentials from `iot-credentials.env`
2. Derives per-device key: `HMAC-SHA256(GROUP_KEY, DEVICE_ID)`
3. Registers with Azure DPS → receives assigned IoT Hub + connection string
4. Writes connection string to `/opt/iot-monitor/.env`
5. Installs and enables `iot-monitor` service
6. Shreds credentials from SD card, reboots

### New-AzureMiddleware.ps1

Idempotent — safe to re-run. Provisions and redeploys the Azure middleware stack in `rg-aw-azcom-iot-copilot`.

```powershell
.\New-AzureMiddleware.ps1 -Environment dev
.\New-AzureMiddleware.ps1 -Environment dev -DryRun
.\New-AzureMiddleware.ps1 -Environment dev -SkipFunctionDeploy
.\New-AzureMiddleware.ps1 -Environment dev -RefreshLogicAppResources
```

**Source-controlled assets used by the script:**
- Function App code: `azure infrastructure/azure-functions/iot-signalr-func/`
- Logic App workflow: `azure infrastructure/azure-logic apps/la-aw-iot-copilot/workflow.json`

**When to use `-RefreshLogicAppResources`:**
- The portal designer shows the Event Hubs trigger as broken or disconnected
- You need to rebuild the managed Event Hubs connection instead of updating it in place
- You want to rule out stale portal metadata on an existing Logic App resource

### deploy-pi-update.ps1

Deploy updated `raspberry-pi/main.py` (or the full `raspberry-pi/` folder) to a running Pi over SSH/SCP, then restart the `iot-monitor` service and tail recent logs for quick verification.

```powershell
# Deploy only main.py (most common — quick patch)
.\deploy-pi-update.ps1

# Deploy all files under raspberry-pi/
.\deploy-pi-update.ps1 -CopyAll

# Target a specific host
.\deploy-pi-update.ps1 -SshHost pi@192.168.1.42

# Skip creating a timestamped backup of remote main.py before overwriting
.\deploy-pi-update.ps1 -SkipBackup
```

**Defaults:** SSH target `pi@iotpanel`, remote directory `/opt/iot-monitor/raspberry-pi/`. Override with `-SshHost` and `-RemoteDir`.

---

## Dataverse / Power Platform

| Script | Purpose |
|--------|---------|
| `Apply-ProjectTokens.ps1` | Stamp `YOUR_*` placeholders across the repo from `project.tokens.json` |
| `Connect-Dataverse.ps1` | Authenticate to Dataverse and return a connection object |
| `Deploy-Project.ps1` | Full solution deployment (tables → choices → relationships → flows) |
| `Seed-TechnicianData.ps1` | Seed `andy_technician` and `andy_iot_sensor` tables with realistic test data |
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

### Seed-TechnicianData.ps1

Seeds `andy_technician` (25 records) and `andy_iot_sensor` (12 records) with realistic simulated data for the US East corridor. Run after `Import-Choices`, `Import-Tables`, and `Import-Relationships`. Idempotent — skips records that already exist.

```powershell
.\Seed-TechnicianData.ps1 -Environment dev
.\Seed-TechnicianData.ps1 -Environment dev -DryRun
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
