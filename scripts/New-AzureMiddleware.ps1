<#
.SYNOPSIS
    Provisions the Azure middleware layer for AgenticIoT: SignalR Service and Function App.

.DESCRIPTION
    Creates or verifies (idempotent) the Azure middleware layer for AgenticIoT.
    Resource names, SKUs, and settings are read from component config files under
    azure infrastructure/ — see that folder for the full component list.

    Components provisioned:
      - Azure SignalR Service  (config: azure infrastructure/signalr/config.json)
      - Azure Function App     (config: azure infrastructure/azure-functions/config.json)
      - App Service Plan       (Consumption Y1 — auto-created with Function App)
      - Storage Account        (config: azure infrastructure/storage-account/config.json)
      - Event Hub Namespace + Event Hub (config: azure infrastructure/event-hub/config.json)

    After provisioning:
      - Function App source is deployed from azure infrastructure/azure-functions/iot-signalr-func/
      - Function App is configured with IoTHubEventHubConnectionString so the Event Hub trigger
        reads directly from the dedicated Event Hub namespace.
      - IoT Hub route for the configured device → dedicated Event Hub (see event-hub/config.json)

.PARAMETER Environment
    Target environment: dev, test, or prod.

.PARAMETER Location
    Azure region. Defaults to eastus.

.PARAMETER DryRun
    Preview mode — no Azure calls made.

.NOTES
    PREREQUISITES:
    - Azure CLI installed and logged in: az login
    - Azure IoT extension: az extension add --name azure-iot

    FUNCTION APP CODE DEPLOYMENT:
    Function App code is deployed automatically via GitHub Actions (deploy-function-app.yml)
    on every push to main. Run this script only to provision infrastructure; code deployment
    is handled by CI/CD.

    OUTPUTS (printed at end):
    - Function App URL
    - SignalR connection string (copy to Function App settings if needed)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('dev','test','prod')] [string]$Environment,
    [string]$Location     = 'eastus',
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─── Load config from component folders ───────────────────────────────────────
$AzureInfraPath  = Join-Path $PSScriptRoot '..\azure infrastructure'
$sharedConfig    = Get-Content (Join-Path $AzureInfraPath 'config.json') | ConvertFrom-Json
$iotHubConfig    = Get-Content (Join-Path $AzureInfraPath 'iot-hub\config.json') | ConvertFrom-Json
$signalRConfig   = Get-Content (Join-Path $AzureInfraPath 'signalr\config.json') | ConvertFrom-Json
$funcConfig      = Get-Content (Join-Path $AzureInfraPath 'azure-functions\config.json') | ConvertFrom-Json
$storageConfig   = Get-Content (Join-Path $AzureInfraPath 'storage-account\config.json') | ConvertFrom-Json
$evhConfig       = Get-Content (Join-Path $AzureInfraPath 'event-hub\config.json') | ConvertFrom-Json

$ResourceGroup   = $sharedConfig.resourceGroup
$IotHubName      = $iotHubConfig.name
$SignalRName      = $signalRConfig.name
$FuncAppName     = $funcConfig.name
$StorageName     = $storageConfig.name
$EvhNsName       = $evhConfig.namespaceName
$EvhName         = $evhConfig.eventHubName
$DeviceId        = $iotHubConfig.deviceId

# ─── Helpers ──────────────────────────────────────────────────────────────────

function Write-Step([string]$msg) { Write-Host "`n▶ $msg" -ForegroundColor Cyan }
function Write-Ok([string]$msg)   { Write-Host "  ✅ $msg" -ForegroundColor Green }
function Write-Skip([string]$msg) { Write-Host "  ⏭  $msg" -ForegroundColor Yellow }
function Write-Info([string]$msg) { Write-Host "  ℹ  $msg" }

function Invoke-Az {
    param([string[]]$AzArgs)
    if ($DryRun) {
        Write-Host "  [DRY RUN] az $($AzArgs -join ' ')" -ForegroundColor DarkGray
        return $null
    }
    $result = az @AzArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ❌ az $($AzArgs[0..1] -join ' ') failed (exit $LASTEXITCODE):" -ForegroundColor Red
        $result | ForEach-Object { Write-Host "     $_" -ForegroundColor Red }
        throw "az $($AzArgs[0..1] -join ' ') failed — see output above"
    }
    return $result
}

# ─── 0. Verify login ──────────────────────────────────────────────────────────
Write-Step "Verifying Azure CLI login"
$account = az account show 2>&1
if ($LASTEXITCODE -ne 0) { throw "Not logged in — run 'az login' first" }
$sub = ($account | ConvertFrom-Json).name
Write-Ok "Logged in — subscription: $sub"

# ─── 1. Resource group ────────────────────────────────────────────────────────
Write-Step "Resource group: $ResourceGroup"
$rg = az group show --name $ResourceGroup 2>$null
if ($rg) {
    Write-Skip "Already exists"
} else {
    Invoke-Az @('group','create','--name',$ResourceGroup,'--location',$Location) | Out-Null
    Write-Ok "Created"
}

# ─── 2. SignalR Service ───────────────────────────────────────────────────────
Write-Step "SignalR Service: $SignalRName ($($signalRConfig.sku), $($signalRConfig.serviceMode))"
$sr = az signalr show --name $SignalRName --resource-group $ResourceGroup 2>$null
if ($sr) {
    Write-Skip "Already exists"
} else {
    Invoke-Az @(
        'signalr','create',
        '--name',$SignalRName,
        '--resource-group',$ResourceGroup,
        '--location',$Location,
        '--sku',$signalRConfig.sku,
        '--service-mode',$signalRConfig.serviceMode
    ) | Out-Null
    Write-Ok "Created"
}

# Set CORS on SignalR (separate from create)
if (-not $DryRun) {
    Invoke-Az @(
        'signalr','cors','update',
        '--name',$SignalRName,
        '--resource-group',$ResourceGroup,
        '--allowed-origins','*'
    ) | Out-Null
    Write-Ok "SignalR CORS set (*)"
}

if (-not $DryRun) {
    $signalRConnStr = (Invoke-Az @(
        'signalr','key','list',
        '--name',$SignalRName,
        '--resource-group',$ResourceGroup,
        '--query','primaryConnectionString','-o','tsv'
    )).Trim()
    Write-Ok "SignalR connection string retrieved"
} else {
    $signalRConnStr = 'Endpoint=https://placeholder.service.signalr.net;AccessKey=placeholder;Version=1.0;'
}

# ─── 3. Storage account (required by Function App) ────────────────────────────
Write-Step "Storage account: $StorageName"
$st = az storage account show --name $StorageName --resource-group $ResourceGroup 2>$null
if ($st) {
    Write-Skip "Already exists"
} else {
    Invoke-Az @(
        'storage','account','create',
        '--name',$StorageName,
        '--resource-group',$ResourceGroup,
        '--location',$Location,
        '--sku',$storageConfig.sku,
        '--kind',$storageConfig.kind,
        '--allow-blob-public-access',($storageConfig.allowBlobPublicAccess ? 'true' : 'false')
    ) | Out-Null
    Write-Ok "Created"
}

# ─── 4. Event Hub Namespace + Event Hub ──────────────────────────────────────
# A dedicated Event Hub receives IoT Hub messages via a custom endpoint + route.
# The Function App reads directly from this hub using the Event Hub trigger.
Write-Step "Event Hub Namespace: $EvhNsName"
$evhns = az eventhubs namespace show --name $EvhNsName --resource-group $ResourceGroup 2>$null
if ($evhns) {
    Write-Skip "Already exists"
} else {
    Invoke-Az @(
        'eventhubs','namespace','create',
        '--name',$EvhNsName,
        '--resource-group',$ResourceGroup,
        '--location',$Location,
        '--sku',$evhConfig.sku
    ) | Out-Null
    Write-Ok "Created"
}

Write-Step "Event Hub: $EvhName"
$evh = az eventhubs eventhub show --name $EvhName --namespace-name $EvhNsName --resource-group $ResourceGroup 2>$null
if ($evh) {
    Write-Skip "Already exists"
} else {
    Invoke-Az @(
        'eventhubs','eventhub','create',
        '--name',$EvhName,
        '--namespace-name',$EvhNsName,
        '--resource-group',$ResourceGroup,
        '--partition-count','2',
        '--retention-time','1',
        '--cleanup-policy','Delete'
    ) | Out-Null
    Write-Ok "Created"
}

# Get Event Hub connection string for IoT Hub custom endpoint
$evhConnStr = if (-not $DryRun) {
    (Invoke-Az @(
        'eventhubs','namespace','authorization-rule','keys','list',
        '--name','RootManageSharedAccessKey',
        '--namespace-name',$EvhNsName,
        '--resource-group',$ResourceGroup,
        '--query','primaryConnectionString','-o','tsv'
    )).Trim()
} else {
    'Endpoint=sb://placeholder.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=placeholder'
}
Write-Ok "Event Hub connection string retrieved"

# ─── 5. IoT Hub custom endpoint + message route → Event Hub ──────────────────
Write-Step "IoT Hub custom endpoint → $EvhName"
if (-not $DryRun) {
    $existingEp = az iot hub routing-endpoint list `
        --hub-name $IotHubName `
        --resource-group $ResourceGroup `
        --endpoint-type EventHub 2>$null | ConvertFrom-Json |
        Where-Object { $_.name -eq 'endpoint-iotpanel' }
    if ($existingEp) {
        Write-Skip "Custom endpoint 'endpoint-iotpanel' already exists"
    } else {
        $evhResourceId = (az eventhubs eventhub show `
            --name $EvhName `
            --namespace-name $EvhNsName `
            --resource-group $ResourceGroup `
            --query 'id' -o tsv 2>$null).Trim()

        Invoke-Az @(
            'iot','hub','routing-endpoint','create',
            '--hub-name',$IotHubName,
            '--resource-group',$ResourceGroup,
            '--endpoint-name','endpoint-iotpanel',
            '--endpoint-type','EventHub',
            '--endpoint-resource-group',$ResourceGroup,
            '--endpoint-subscription-id',(az account show --query id -o tsv 2>$null).Trim(),
            '--connection-string',"$evhConnStr;EntityPath=$EvhName"
        ) | Out-Null
        Write-Ok "Custom endpoint created"
    }

    $existingRoute = az iot hub route list `
        --hub-name $IotHubName `
        --resource-group $ResourceGroup 2>$null | ConvertFrom-Json |
        Where-Object { $_.name -eq 'route-iotpanel' }
    if ($existingRoute) {
        Write-Skip "Route 'route-iotpanel' already exists — endpoint: $($existingRoute.endpointNames)"
    } else {
        Invoke-Az @(
            'iot','hub','route','create',
            '--hub-name',$IotHubName,
            '--resource-group',$ResourceGroup,
            '--route-name','route-iotpanel',
            '--source','DeviceMessages',
            '--endpoint-name','endpoint-iotpanel',
            '--condition','true',
            '--enabled','true'
        ) | Out-Null
        Write-Ok "Route created (all device messages → Event Hub)"
    }
}

# ─── 6. Function App (Windows Consumption, Node.js 20) ───────────────────────
# Note: Windows Consumption is used to match the reference implementation.
# WEBSITE_RUN_FROM_PACKAGE (URL mode) is reliable on Windows; Linux Consumption
# has Kudu/host startup issues with this deploy pattern.
Write-Step "Function App: $FuncAppName"
$fa = az functionapp show --name $FuncAppName --resource-group $ResourceGroup 2>$null
if ($fa) {
    $faOs = (az functionapp show --name $FuncAppName --resource-group $ResourceGroup --query 'kind' -o tsv 2>$null)
    if ($faOs -match 'linux') {
        Write-Host "  ⚠  Existing app is Linux — deleting and recreating as Windows..." -ForegroundColor Yellow
        az functionapp delete --name $FuncAppName --resource-group $ResourceGroup --yes 2>$null | Out-Null
        Start-Sleep -Seconds 10
        # fall through to create
    } else {
        Write-Skip "Already exists (Windows)"
        $fa = $true
    }
}

if (-not $fa -or ($fa -and $faOs -match 'linux')) {
    Invoke-Az @(
        'functionapp','create',
        '--name',$FuncAppName,
        '--resource-group',$ResourceGroup,
        '--consumption-plan-location',$Location,
        '--runtime',$funcConfig.runtime,
        '--runtime-version',$funcConfig.runtimeVersion,
        '--functions-version','4',
        '--storage-account',$StorageName,
        '--os-type',$funcConfig.os
    ) | Out-Null
    Write-Ok "Created ($($funcConfig.os) Consumption, Node $($funcConfig.runtimeVersion))"
}

Write-Step "Configuring Function App settings (SignalR + Event Hub connection strings)"

# Use the dedicated Event Hub namespace ($EvhNsName / $EvhName) — this is where
# IoT Hub routes messages via the custom route 'route-iotpanel'.
# The IoT Hub built-in endpoint is NOT used because the custom route (condition: true) intercepts
# all messages before they reach the fallback/built-in endpoint.
$iotHubEhConnStr = if (-not $DryRun) {
    $rawConn = (Invoke-Az @(
        'eventhubs','namespace','authorization-rule','keys','list',
        '--name','RootManageSharedAccessKey',
        '--namespace-name',$EvhNsName,
        '--resource-group',$ResourceGroup,
        '--query','primaryConnectionString','-o','tsv'
    )).Trim()
    # Append EntityPath so the Functions Event Hub binding knows which hub to read
    "$rawConn;EntityPath=$EvhName"
} else {
    "Endpoint=sb://$EvhNsName.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=placeholder;EntityPath=$EvhName"
}
Write-Ok "Dedicated Event Hub connection string retrieved (namespace: $EvhNsName, hub: $EvhName)"

Invoke-Az @(
    'functionapp','config','appsettings','set',
    '--name',$FuncAppName,
    '--resource-group',$ResourceGroup,
    '--settings',
    "AzureSignalRConnectionString=$signalRConnStr",
    "IoTHubEventHubConnectionString=$iotHubEhConnStr",
    "IoTHubName=$EvhName"
) | Out-Null
Write-Ok "AzureSignalRConnectionString, IoTHubEventHubConnectionString, and IoTHubName set"

# CORS — allow Power Pages origins
Write-Step "Setting CORS on Function App"
Invoke-Az @(
    'functionapp','cors','add',
    '--name',$FuncAppName,
    '--resource-group',$ResourceGroup,
    '--allowed-origins','https://*.powerappsportals.com','https://*.microsoftcrmportals.com','http://localhost:3000'
) | Out-Null
Write-Ok "CORS configured"


# ─── Summary ──────────────────────────────────────────────────────────────────
Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " AgenticIoT Middleware — Provisioning Complete" -ForegroundColor Green
Write-Host "============================================================`n" -ForegroundColor Green
$FuncUrl = "https://$FuncAppName.azurewebsites.net"
Write-Host "  Function App URL  : $FuncUrl"
Write-Host "  Health check      : $FuncUrl/api/health"
Write-Host "  SignalR name      : $SignalRName"
Write-Host "  Event Hub NS      : $EvhNsName"
Write-Host "  Event Hub         : $EvhName"
Write-Host ""
Write-Host "  Function App code deployment is handled automatically by GitHub Actions." -ForegroundColor Cyan
Write-Host "  Push to main (paths: azure infrastructure/azure-functions/iot-signalr-func/**)" -ForegroundColor Cyan
Write-Host "  to trigger the deploy-function-app workflow." -ForegroundColor Cyan
Write-Host ""
Write-Host "  Expected next steps after deploy:"
Write-Host "  A. Test: curl $FuncUrl/api/health"
Write-Host "  B. Press a Pi switch — check Function App logs for 'iotTelemetry' trigger invocations"
Write-Host "  C. Connect Power Pages to $FuncUrl/api/negotiate"
Write-Host ""
if ($DryRun) {
    Write-Host "  (DRY RUN — no resources were created)" -ForegroundColor Yellow
}
