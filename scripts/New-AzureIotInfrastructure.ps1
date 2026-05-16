<#
.SYNOPSIS
    Provisions all Azure IoT infrastructure for the AgenticIoT copilot-iot-service project.

.DESCRIPTION
    Creates or verifies all Azure resources in the resource group rg-aw-azcom-iot-copilot:

      - Resource Group   : rg-aw-azcom-iot-copilot
      - IoT Hub          : iothub-aw-iot-copilot  (Free tier for dev, S1 for prod)
      - Device Provisioning Service : dps-aw-iot-copilot
      - DPS → IoT Hub link
      - DPS Group Enrollment: iotpanel-fleet (symmetric key)

    All operations are idempotent — safe to re-run. Existing resources are not modified.
    Use -DryRun to preview what would be created without making changes.

.PARAMETER Environment
    Target environment: dev, test, or prod.
    Drives the IoT Hub SKU (Free for dev/test, S1 for prod).

.PARAMETER Location
    Azure region for all resources. Defaults to "eastus".

.PARAMETER DryRun
    Preview mode — shows what would be created without making any Azure API calls.

.PARAMETER SkipDpsEnrollment
    Skip creating the DPS group enrollment. Useful if you want to create enrollments
    with custom settings manually after provisioning.

.EXAMPLE
    .\New-AzureIotInfrastructure.ps1 -Environment dev
    # Provisions all resources in eastus (free IoT Hub tier)

.EXAMPLE
    .\New-AzureIotInfrastructure.ps1 -Environment prod -Location westus2
    # Provisions production resources in westus2 (S1 IoT Hub tier)

.EXAMPLE
    .\New-AzureIotInfrastructure.ps1 -Environment dev -DryRun
    # Preview what would be created without making changes

.NOTES
    PREREQUISITES:
    - Azure CLI installed and logged in: az login
    - Azure IoT extension installed: az extension add --name azure-iot
    - Sufficient permissions: Contributor or Owner on the subscription

    OUTPUTS (printed at end):
    - DPS ID Scope     — needed for New-PiBootConfig.ps1 -IdScope
    - DPS Group Key    — needed for New-PiBootConfig.ps1 -GroupKey
    These are NOT written to any file. Copy them to your secrets manager.

    SECURITY:
    - The DPS group enrollment key is printed once at the end of this script.
    - Store it in Azure Key Vault or a secrets manager immediately.
    - Never commit the key to source control.
    - Individual device keys are derived from the group key using HMAC-SHA256.
    - Compromise of one device key does NOT expose the group key.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet('dev', 'test', 'prod')]
    [string] $Environment,

    [string] $Location = "eastus",

    [switch] $DryRun,

    [switch] $SkipDpsEnrollment
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─── Resource names (fixed, not per-environment) ─────────────────────────────
$resourceGroup   = "rg-aw-azcom-iot-copilot"
$iotHubName      = "iothub-aw-iot-copilot"
$dpsName         = "dps-aw-iot-copilot"
$enrollmentId    = "iotpanel-fleet"

# IoT Hub SKU: Free tier for dev/test (1 per subscription), S1 for prod
$iotHubSku = if ($Environment -eq 'prod') { 'S1' } else { 'F1' }
$iotHubUnits = 1

$tags = "project=iot-copilot env=$Environment owner=andworx"

# ─── Header ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "AgenticIoT — Azure IoT Infrastructure" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Environment     : $Environment" -ForegroundColor Gray
Write-Host "  Resource Group  : $resourceGroup" -ForegroundColor Gray
Write-Host "  IoT Hub         : $iotHubName  (SKU: $iotHubSku)" -ForegroundColor Gray
Write-Host "  DPS             : $dpsName" -ForegroundColor Gray
Write-Host "  Location        : $Location" -ForegroundColor Gray
if ($DryRun) {
    Write-Host ""
    Write-Host "  [DRY RUN — no changes will be made]" -ForegroundColor Yellow
}
Write-Host ""

# ─── Helpers ─────────────────────────────────────────────────────────────────
function Invoke-AzStep {
    param([string]$Label, [scriptblock]$Action, [string]$SkipIf = "")
    Write-Host "[Azure] $Label..." -ForegroundColor Yellow
    if ($DryRun) {
        Write-Host "  [DRY RUN] Would run: $Label" -ForegroundColor DarkGray
        return $null
    }
    try {
        $result = & $Action
        Write-Host "  ✅ $Label" -ForegroundColor Green
        return $result
    } catch {
        Write-Host "  ❌ $Label failed: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Test-AzResource {
    param([string]$ResourceType, [string]$Name, [string]$ResourceGroup)
    $result = az resource list `
        --resource-group $ResourceGroup `
        --resource-type $ResourceType `
        --query "[?name=='$Name'] | length(@)" `
        --output tsv 2>$null
    return ($result -and [int]$result -gt 0)
}

# ─── 0. Verify Azure CLI ──────────────────────────────────────────────────────
Write-Host "[Check] Verifying Azure CLI..." -ForegroundColor Yellow
$account = az account show --query "{name:name, id:id}" --output json 2>$null | ConvertFrom-Json
if (-not $account) {
    throw "[Auth] Not logged in to Azure CLI. Run 'az login' first."
}
Write-Host "  ✅ Logged in to: $($account.name) ($($account.id))" -ForegroundColor Green

# Check IoT extension
$iotExt = az extension list --query "[?name=='azure-iot'].name" --output tsv 2>$null
if (-not $iotExt) {
    Write-Host "[Check] Installing azure-iot extension..." -ForegroundColor Yellow
    if (-not $DryRun) {
        az extension add --name azure-iot --yes 2>&1 | Out-Null
    }
    Write-Host "  ✅ azure-iot extension ready" -ForegroundColor Green
} else {
    Write-Host "  ✅ azure-iot extension present" -ForegroundColor Green
}

# ─── 1. Resource Group ────────────────────────────────────────────────────────
$rgExists = az group exists --name $resourceGroup --output tsv 2>$null
if ($rgExists -eq 'true') {
    Write-Host "[Azure] Resource group '$resourceGroup' already exists — skipping." -ForegroundColor Gray
} else {
    Invoke-AzStep "Create resource group '$resourceGroup'" {
        az group create `
            --name $resourceGroup `
            --location $Location `
            --tags $tags `
            --output none
    }
}

# ─── 2. IoT Hub ───────────────────────────────────────────────────────────────
$hubExists = Test-AzResource -ResourceType "Microsoft.Devices/IotHubs" -Name $iotHubName -ResourceGroup $resourceGroup
if ($hubExists) {
    Write-Host "[Azure] IoT Hub '$iotHubName' already exists — skipping." -ForegroundColor Gray
} else {
    if ($iotHubSku -eq 'F1') {
        Write-Host "  ℹ Free tier selected (F1). Note: only 1 Free IoT Hub allowed per subscription." -ForegroundColor Yellow
        Write-Host "    If this fails, set Environment to 'prod' to use S1 SKU." -ForegroundColor Yellow
    }
    Invoke-AzStep "Create IoT Hub '$iotHubName' (SKU: $iotHubSku)" {
        az iot hub create `
            --name $iotHubName `
            --resource-group $resourceGroup `
            --sku $iotHubSku `
            --unit $iotHubUnits `
            --location $Location `
            --tags $tags `
            --output none
    }
}

# ─── 3. Register device (backwards compatibility) ────────────────────────────
$deviceExists = $false
if (-not $DryRun) {
    $deviceExists = az iot hub device-identity list `
        --hub-name $iotHubName `
        --query "[?deviceId=='raspberry-pi-iotpanel'] | length(@)" `
        --output tsv 2>$null
    $deviceExists = ($deviceExists -and [int]$deviceExists -gt 0)
}

if ($deviceExists) {
    Write-Host "[Azure] Device 'raspberry-pi-iotpanel' already exists — skipping." -ForegroundColor Gray
} else {
    Invoke-AzStep "Register device 'raspberry-pi-iotpanel' in IoT Hub" {
        az iot hub device-identity create `
            --hub-name $iotHubName `
            --device-id "raspberry-pi-iotpanel" `
            --output none
    }
}

# ─── 4. Device Provisioning Service ──────────────────────────────────────────
$dpsExists = Test-AzResource -ResourceType "Microsoft.Devices/ProvisioningServices" -Name $dpsName -ResourceGroup $resourceGroup
if ($dpsExists) {
    Write-Host "[Azure] DPS '$dpsName' already exists — skipping." -ForegroundColor Gray
} else {
    Invoke-AzStep "Create Device Provisioning Service '$dpsName'" {
        az iot dps create `
            --name $dpsName `
            --resource-group $resourceGroup `
            --location $Location `
            --tags $tags `
            --output none
    }
}

# ─── 5. Link DPS → IoT Hub ────────────────────────────────────────────────────
$linkedHubs = @()
if (-not $DryRun) {
    $linkedHubs = az iot dps linked-hub list `
        --dps-name $dpsName `
        --resource-group $resourceGroup `
        --query "[].name" `
        --output tsv 2>$null
}

$alreadyLinked = $linkedHubs | Where-Object { $_ -like "*$iotHubName*" }
if ($alreadyLinked) {
    Write-Host "[Azure] IoT Hub already linked to DPS — skipping." -ForegroundColor Gray
} else {
    Invoke-AzStep "Link IoT Hub '$iotHubName' to DPS '$dpsName'" {
        $hubConnectionString = az iot hub connection-string show `
            --hub-name $iotHubName `
            --policy-name iothubowner `
            --query connectionString `
            --output tsv

        az iot dps linked-hub create `
            --dps-name $dpsName `
            --resource-group $resourceGroup `
            --connection-string $hubConnectionString `
            --location $Location `
            --output none
    }
}

# ─── 6. DPS Group Enrollment ─────────────────────────────────────────────────
if ($SkipDpsEnrollment) {
    Write-Host "[Azure] Skipping DPS group enrollment (-SkipDpsEnrollment set)." -ForegroundColor Gray
} else {
    $enrollmentExists = $false
    if (-not $DryRun) {
        $enrollmentCheck = az iot dps enrollment-group list `
            --dps-name $dpsName `
            --resource-group $resourceGroup `
            --query "[?enrollmentGroupId=='$enrollmentId'] | length(@)" `
            --output tsv 2>$null
        $enrollmentExists = ($enrollmentCheck -and [int]$enrollmentCheck -gt 0)
    }

    if ($enrollmentExists) {
        Write-Host "[Azure] DPS group enrollment '$enrollmentId' already exists — skipping." -ForegroundColor Gray
    } else {
        Invoke-AzStep "Create DPS group enrollment '$enrollmentId' (symmetric key)" {
            az iot dps enrollment-group create `
                --dps-name $dpsName `
                --resource-group $resourceGroup `
                --enrollment-id $enrollmentId `
                --auth-type symmetricKey `
                --output none
        }
    }
}

# ─── 7. Collect outputs ───────────────────────────────────────────────────────
Write-Host ""
Write-Host "Collecting provisioning outputs..." -ForegroundColor Yellow

$idScope   = $null
$groupKey  = $null
$hubHost   = $null

if (-not $DryRun) {
    try {
        $idScope = az iot dps show `
            --name $dpsName `
            --resource-group $resourceGroup `
            --query properties.idScope `
            --output tsv

        if (-not $SkipDpsEnrollment) {
            $groupKey = az iot dps enrollment-group show `
                --dps-name $dpsName `
                --resource-group $resourceGroup `
                --enrollment-id $enrollmentId `
                --show-keys `
                --query attestation.symmetricKey.primaryKey `
                --output tsv
        }

        $hubHost = az iot hub show `
            --name $iotHubName `
            --query properties.hostName `
            --output tsv
    } catch {
        Write-Host "  ⚠ Could not retrieve all outputs: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# ─── Summary ──────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "✅ Azure IoT Infrastructure Ready" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Resource Group : $resourceGroup" -ForegroundColor Gray
Write-Host "  IoT Hub        : $iotHubName"    -ForegroundColor Gray
if ($hubHost)  { Write-Host "  Hub Hostname   : $hubHost"    -ForegroundColor Gray }
Write-Host "  DPS            : $dpsName"        -ForegroundColor Gray
if ($idScope)  { Write-Host "  DPS ID Scope   : $idScope"   -ForegroundColor White }
Write-Host ""

if (-not $SkipDpsEnrollment) {
    Write-Host "  DPS Group Enrollment: $enrollmentId" -ForegroundColor Gray
    if ($groupKey) {
        Write-Host ""
        Write-Host "  ┌─────────────────────────────────────────────────────┐" -ForegroundColor Yellow
        Write-Host "  │  ⚠  SAVE THIS KEY — shown only once per run         │" -ForegroundColor Yellow
        Write-Host "  ├─────────────────────────────────────────────────────┤" -ForegroundColor Yellow
        Write-Host "  │  DPS Group Key: $groupKey" -ForegroundColor Yellow
        Write-Host "  └─────────────────────────────────────────────────────┘" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Store this key in Azure Key Vault or a secrets manager." -ForegroundColor Yellow
        Write-Host "  NEVER commit it to source control." -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Store the DPS Group Key securely (Key Vault recommended)"
Write-Host "  2. Update scripts/config-dev.json with:"
Write-Host "       iotHub.name  = $iotHubName"
Write-Host "       dps.name     = $dpsName"
if ($idScope) {
    Write-Host "       dps.idScope  = $idScope"
}
Write-Host "  3. Run .\New-PiBootConfig.ps1 -IdScope <scope> -GroupKey <key>"
Write-Host "       (New-PiBootConfig.ps1 will be updated in issue #67)"
Write-Host ""
