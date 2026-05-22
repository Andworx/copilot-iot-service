<#
.SYNOPSIS
    Provisions the Azure middleware layer for AgenticIoT: SignalR Service and Function App.

.DESCRIPTION
    Creates or verifies (idempotent) the following resources in rg-aw-azcom-iot-copilot:

      - Azure SignalR Service  : signalr-aw-iot-copilot  (Free tier, Serverless mode)
      - Azure Function App     : func-aw-iot-copilot      (Consumption, Node.js 24)
      - App Service Plan       : plan-func-aw-iot-copilot (Y1 Consumption)
      - Storage Account        : stfuncawiotcopilot        (LRS, required by Functions)
      - Event Hub Namespace    : evhns-aw-iot-copilot / iot-telemetry

    After provisioning:
      - Function App source is deployed from azure infrastructure/azure-functions/iot-signalr-func/
      - Function App is configured with IoTHubEventHubConnectionString so the Event Hub trigger
        reads directly from the dedicated Event Hub namespace.
      - IoT Hub route for device 'raspberry-pi-iotpanel' → dedicated Event Hub (evhns-aw-iot-copilot / iot-telemetry)

.PARAMETER Environment
    Target environment: dev, test, or prod.

.PARAMETER Location
    Azure region. Defaults to eastus.

.PARAMETER DryRun
    Preview mode — no Azure calls made.

.PARAMETER SkipFunctionDeploy
    Skip npm install + func publish step (use if Function Core Tools not installed).

.EXAMPLE
    .\New-AzureMiddleware.ps1 -Environment dev
    # Full provision + deploy

.EXAMPLE
    .\New-AzureMiddleware.ps1 -Environment dev -DryRun
    # Preview only

.EXAMPLE
    .\New-AzureMiddleware.ps1 -Environment dev -SkipFunctionDeploy
    # Provision infrastructure only; deploy Function App manually later

.NOTES
    PREREQUISITES:
    - Azure CLI installed and logged in: az login
    - Azure IoT extension: az extension add --name azure-iot
    - Node.js + npm: for building function app deps locally before zip deploy
    - (Optional) Azure Functions Core Tools not required — zip deploy is used

    OUTPUTS (printed at end):
    - Function App URL
    - SignalR connection string (copy to Function App settings if needed)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('dev','test','prod')] [string]$Environment,
    [string]$Location     = 'eastus',
    [switch]$DryRun,
    [switch]$SkipFunctionDeploy
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─── Resource names ───────────────────────────────────────────────────────────
$ResourceGroup   = 'rg-aw-azcom-iot-copilot'
$IotHubName      = 'iothub-aw-iot-copilot'
$SignalRName      = 'signalr-aw-iot-copilot'
$FuncAppName     = 'func-aw-iot-copilot'
$StorageName     = 'stfuncawiotcopilot'   # max 24 chars, lowercase, no hyphens
$EvhNsName       = 'evhns-aw-iot-copilot'  # Event Hub namespace
$EvhName         = 'iot-telemetry'          # Event Hub inside the namespace
$DeviceId        = 'raspberry-pi-iotpanel'

$AzureInfraPath  = Join-Path $PSScriptRoot '..\azure infrastructure'
$FuncSrcPath     = Join-Path $AzureInfraPath 'azure-functions\iot-signalr-func'

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
Write-Step "SignalR Service: $SignalRName (Free, Serverless)"
$sr = az signalr show --name $SignalRName --resource-group $ResourceGroup 2>$null
if ($sr) {
    Write-Skip "Already exists"
} else {
    Invoke-Az @(
        'signalr','create',
        '--name',$SignalRName,
        '--resource-group',$ResourceGroup,
        '--location',$Location,
        '--sku','Free_F1',
        '--service-mode','Serverless'
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
        '--sku','Standard_LRS',
        '--kind','StorageV2',
        '--allow-blob-public-access','false'
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
        '--sku','Basic'
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
        '--runtime','node',
        '--runtime-version','24',
        '--functions-version','4',
        '--storage-account',$StorageName,
        '--os-type','Windows'
    ) | Out-Null
    Write-Ok "Created (Windows Consumption, Node 20)"
}

Write-Step "Configuring Function App settings (SignalR + Event Hub connection strings)"

# Use the dedicated Event Hub namespace (evhns-aw-iot-copilot / iot-telemetry) — this is where
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


# ─── 7. Deploy Function App source ────────────────────────────────────────────
if ($SkipFunctionDeploy) {
    Write-Skip "Skipping Function App deployment (--SkipFunctionDeploy)"
} else {
    Write-Step "Deploying Function App from $FuncSrcPath"
    if (-not $DryRun) {
        $zipPath = Join-Path $env:TEMP 'func-aw-iot-copilot-deploy.zip'
        Push-Location $FuncSrcPath
        try {
            Write-Info "npm install (production deps)..."
            npm install --omit=dev 2>&1 | ForEach-Object { Write-Host "    $_" }
            if ($LASTEXITCODE -ne 0) { throw "npm install failed" }

            Write-Info "Creating deployment zip..."
            if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
            $items = Get-ChildItem -Path . | Where-Object { $_.Name -notin @('.git', '.vscode', 'tests', '*.test.js') }
            $prevPref = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'
            Compress-Archive -Path $items.FullName -DestinationPath $zipPath -Force
            $ProgressPreference = $prevPref
            Write-Info "Zip created: $zipPath ($([math]::Round((Get-Item $zipPath).Length/1KB))KB)"
        } finally {
            Pop-Location
        }

        # Deploy via WEBSITE_RUN_FROM_PACKAGE — reliable on Windows Consumption plans.
        Write-Info "Uploading zip to Storage Account for WEBSITE_RUN_FROM_PACKAGE deploy..."

        # Fetch account key once — avoids RBAC data-plane role requirement of --auth-mode login
        $stKey = (az storage account keys list `
            --account-name $StorageName `
            --resource-group $ResourceGroup `
            --query '[0].value' -o tsv 2>$null).Trim()
        if (-not $stKey) { throw "Could not retrieve storage account key for $StorageName" }

        # Ensure a deployment container exists
        $deployContainer = 'function-releases'
        $stExists = az storage container show `
            --name $deployContainer `
            --account-name $StorageName `
            --account-key $stKey 2>$null
        if (-not $stExists) {
            Invoke-Az @(
                'storage','container','create',
                '--name',$deployContainer,
                '--account-name',$StorageName,
                '--account-key',$stKey
            ) | Out-Null
            Write-Info "Created container: $deployContainer"
        }

        $blobName = "func-deploy-$(Get-Date -Format 'yyyyMMdd-HHmmss').zip"
        Invoke-Az @(
            'storage','blob','upload',
            '--container-name',$deployContainer,
            '--file',$zipPath,
            '--name',$blobName,
            '--account-name',$StorageName,
            '--account-key',$stKey,
            '--overwrite'
        ) | Out-Null
        Write-Info "Blob uploaded: $blobName"

        # Generate SAS URL valid for 1 year
        $expiry = (Get-Date).AddYears(1).ToString('yyyy-MM-ddTHH:mm:ssZ')
        $sasToken = (az storage blob generate-sas `
            --container-name $deployContainer `
            --name $blobName `
            --account-name $StorageName `
            --account-key $stKey `
            --permissions r `
            --expiry $expiry `
            -o tsv 2>$null).Trim()
        if (-not $sasToken) { throw "Failed to generate SAS token for deployment blob" }

        $blobUrl = "https://$StorageName.blob.core.windows.net/$deployContainer/${blobName}?$sasToken"
        Write-Info "SAS URL generated (expires $expiry)"

        # Point Function App at the zip via ARM REST API to avoid Windows
        # shell splitting the SAS token on '&' through the az .cmd wrapper
        Write-Host "  ℹ  Setting WEBSITE_RUN_FROM_PACKAGE via ARM API..." -ForegroundColor Cyan
        $armToken  = (az account get-access-token --query accessToken -o tsv 2>$null).Trim()
        $armSubId  = (az account show --query id -o tsv 2>$null).Trim()
        $armBase   = "https://management.azure.com/subscriptions/$armSubId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$FuncAppName"
        $armApiVer = "api-version=2022-03-01"
        $armHeaders = @{ Authorization = "Bearer $armToken"; 'Content-Type' = 'application/json' }

        # GET current settings (POST /config/appsettings/list)
        $curSettings = (Invoke-RestMethod `
            -Uri     "$armBase/config/appsettings/list?$armApiVer" `
            -Method  POST `
            -Headers $armHeaders).properties

        # Merge: preserve existing settings, set/override WEBSITE_RUN_FROM_PACKAGE
        $newProps = @{}
        if ($curSettings) {
            foreach ($prop in $curSettings.PSObject.Properties) {
                $newProps[$prop.Name] = $prop.Value
            }
        }
        $newProps['WEBSITE_RUN_FROM_PACKAGE']     = $blobUrl
        $newProps['WEBSITE_NODE_DEFAULT_VERSION'] = '~24'   # Windows Consumption Node version

        $settingsBody = ([pscustomobject]@{ properties = $newProps }) | ConvertTo-Json -Depth 5

        Invoke-RestMethod `
            -Uri     "$armBase/config/appsettings?$armApiVer" `
            -Method  PUT `
            -Headers $armHeaders `
            -Body    $settingsBody | Out-Null

        # Restart to pick up the new package
        Invoke-Az @(
            'functionapp','restart',
            '--name',$FuncAppName,
            '--resource-group',$ResourceGroup
        ) | Out-Null
        Write-Ok "Function App deployed (WEBSITE_RUN_FROM_PACKAGE)"
    } else {
        Write-Host "  [DRY RUN] Would npm install + Kudu zip deploy from $FuncSrcPath" -ForegroundColor DarkGray
    }
}

# ─── 8. Get Function key ──────────────────────────────────────────────────────
Write-Step "Retrieving Function App key"
if (-not $DryRun) {
    # Use ARM REST API to avoid az 32-bit Python warning corrupting output.
    # Allow up to 120s for a cold Consumption plan to initialise after deploy.
    $armToken  = (az account get-access-token --query accessToken -o tsv 2>$null).Trim()
    $armSubId  = (az account show --query id -o tsv 2>$null).Trim()
    $armBase   = "https://management.azure.com/subscriptions/$armSubId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$FuncAppName"
    $armApiVer = "api-version=2022-03-01"
    $armHeaders = @{ Authorization = "Bearer $armToken"; 'Content-Type' = 'application/json' }

    $funcKey = $null
    for ($i = 0; $i -lt 12; $i++) {
        try {
            $keyResult = Invoke-RestMethod `
                -Uri     "$armBase/host/default/listKeys?$armApiVer" `
                -Method  POST `
                -Headers $armHeaders `
                -ErrorAction Stop
            # Prefer the default function key; fall back to master key
            $funcKey = $keyResult.functionKeys.default
            if (-not $funcKey) { $funcKey = $keyResult.masterKey }
            if ($funcKey) { break }
        } catch { <# not ready yet #> }
        Write-Info "Waiting for function key... ($($i*10)s)"
        Start-Sleep -Seconds 10
    }
    if (-not $funcKey) { throw "Could not retrieve function key after 120s" }
    $FuncUrl = "https://$FuncAppName.azurewebsites.net"
    $TelemetryUrl = "$FuncUrl/api/telemetry?code=$funcKey"
    Write-Ok "Function key retrieved"
} else {
    $funcKey = 'placeholder-key'
    $FuncUrl = "https://$FuncAppName.azurewebsites.net"
    $TelemetryUrl = "$FuncUrl/api/telemetry?code=$funcKey"
}

# ─── Summary ──────────────────────────────────────────────────────────────────
Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " AgenticIoT Middleware — Provisioning Complete" -ForegroundColor Green
Write-Host "============================================================`n" -ForegroundColor Green
Write-Host "  Function App URL  : $FuncUrl"
Write-Host "  Health check      : $FuncUrl/api/health"
Write-Host "  Telemetry URL     : $TelemetryUrl  (secondary/test path)"
Write-Host "  SignalR name      : $SignalRName"
Write-Host "  Event Hub NS      : $EvhNsName"
Write-Host "  Event Hub         : $EvhName"
Write-Host ""
Write-Host "  Primary telemetry path  : IoT Hub → Event Hub trigger → SignalR"
Write-Host "  Secondary (test) path   : POST $FuncUrl/api/telemetry"
Write-Host ""
Write-Host "  Expected next steps after deploy:"
Write-Host "  A. Test: curl $FuncUrl/api/health"
Write-Host "  B. Press a Pi switch — check Function App logs for 'iotTelemetry' trigger invocations"
Write-Host "  C. Connect Power Pages to $FuncUrl/api/negotiate"
Write-Host ""
if ($DryRun) {
    Write-Host "  (DRY RUN — no resources were created)" -ForegroundColor Yellow
}
