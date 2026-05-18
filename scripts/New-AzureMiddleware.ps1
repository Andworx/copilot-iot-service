<#
.SYNOPSIS
    Provisions the Azure middleware layer for AgenticIoT: SignalR Service, Function App, and Logic App.

.DESCRIPTION
    Creates or verifies (idempotent) the following resources in rg-aw-azcom-iot-copilot:

      - Azure SignalR Service  : signalr-aw-iot-copilot  (Free tier, Serverless mode)
      - Azure Function App     : func-aw-iot-copilot      (Consumption, Node.js 24)
      - App Service Plan       : plan-func-aw-iot-copilot (Y1 Consumption)
      - Storage Account        : stfuncawiotcopilot        (LRS, required by Functions)
      - Logic App              : la-aw-iot-copilot         (Consumption, polls Event Hub → HTTP POST to Function)

    After provisioning:
      - Function App source is deployed from azure-functions/iot-signalr-func/
      - Logic App is configured with the Function App URL and key automatically
      - IoT Hub route for device 'raspberry-pi-iotpanel' → built-in Event Hub endpoint is verified

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
    - Function key (copy to Logic App or store in Key Vault)
    - SignalR connection string (copy to Function App settings)
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
$LogicAppName    = 'la-aw-iot-copilot'
$DeviceId        = 'raspberry-pi-iotpanel'

$FuncSrcPath     = Join-Path $PSScriptRoot '..\azure-functions\iot-signalr-func'

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

# ─── 4. Function App (Consumption, Node.js 20) ────────────────────────────────
Write-Step "Function App: $FuncAppName"
$fa = az functionapp show --name $FuncAppName --resource-group $ResourceGroup 2>$null
if ($fa) {
    Write-Skip "Already exists"
} else {
    Invoke-Az @(
        'functionapp','create',
        '--name',$FuncAppName,
        '--resource-group',$ResourceGroup,
        '--consumption-plan-location',$Location,
        '--runtime','node',
        '--runtime-version','24',
        '--functions-version','4',
        '--storage-account',$StorageName,
        '--os-type','Linux'
    ) | Out-Null
    Write-Ok "Created"
}

Write-Step "Configuring Function App settings (SignalR connection string)"
Invoke-Az @(
    'functionapp','config','appsettings','set',
    '--name',$FuncAppName,
    '--resource-group',$ResourceGroup,
    '--settings',"AzureSignalRConnectionString=$signalRConnStr"
) | Out-Null
Write-Ok "AzureSignalRConnectionString set"

# CORS — allow Power Pages origins
Write-Step "Setting CORS on Function App"
Invoke-Az @(
    'functionapp','cors','add',
    '--name',$FuncAppName,
    '--resource-group',$ResourceGroup,
    '--allowed-origins','https://*.powerappsportals.com','https://*.microsoftcrmportals.com','http://localhost:3000'
) | Out-Null
Write-Ok "CORS configured"

# ─── 5. Deploy Function App source ────────────────────────────────────────────
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
            $items = Get-ChildItem -Path . | Where-Object { $_.Name -notin @('.git') }
            Compress-Archive -Path $items.FullName -DestinationPath $zipPath -Force
            Write-Info "Zip created: $zipPath ($([math]::Round((Get-Item $zipPath).Length/1KB))KB)"
        } finally {
            Pop-Location
        }

        # Deploy via Kudu REST API — avoids az CLI SCM JSON parse bug with --build-remote
        Write-Info "Deploying via Kudu zip deploy API..."
        # Run az separately and filter out non-JSON warning lines before parsing
        $rawCreds = az webapp deployment list-publishing-credentials `
            --name $FuncAppName `
            --resource-group $ResourceGroup `
            --query '{user:publishingUserName,pass:publishingPassword}' `
            -o json 2>$null
        if ($LASTEXITCODE -ne 0) { throw "Failed to get publishing credentials" }
        $publishProfile = $rawCreds | ConvertFrom-Json
        $kuduBase64 = [Convert]::ToBase64String(
            [Text.Encoding]::ASCII.GetBytes("$($publishProfile.user):$($publishProfile.pass)")
        )
        $kuduUri = "https://$FuncAppName.scm.azurewebsites.net/api/zipdeploy"

        # Wait for Kudu SCM to be ready (fresh apps can return 503 for up to ~60s)
        Write-Info "Waiting for Kudu SCM site to be ready..."
        $kuduReady = $false
        for ($w = 0; $w -lt 12; $w++) {
            try {
                $ping = Invoke-RestMethod `
                    -Uri "https://$FuncAppName.scm.azurewebsites.net/api/settings" `
                    -Method GET `
                    -Headers @{ Authorization = "Basic $kuduBase64" } `
                    -ErrorAction Stop
                $kuduReady = $true
                break
            } catch {
                Write-Info "  SCM not ready yet ($($w*10)s)..."
                Start-Sleep -Seconds 10
            }
        }
        if (-not $kuduReady) { throw "Kudu SCM site did not become ready after 120s" }

        Write-Info "POST $kuduUri"
        $null = Invoke-RestMethod `
            -Uri $kuduUri `
            -Method POST `
            -Headers @{ Authorization = "Basic $kuduBase64" } `
            -ContentType 'application/zip' `
            -InFile $zipPath
        Write-Ok "Function App deployed (Kudu)"
    } else {
        Write-Host "  [DRY RUN] Would npm install + Kudu zip deploy from $FuncSrcPath" -ForegroundColor DarkGray
    }
}

# ─── 6. Get Function key ──────────────────────────────────────────────────────
Write-Step "Retrieving Function App key"
if (-not $DryRun) {
    # Allow up to 60s for keys to be available after fresh deploy
    $funcKey = $null
    for ($i = 0; $i -lt 6; $i++) {
        $funcKey = (az functionapp keys list `
            --name $FuncAppName `
            --resource-group $ResourceGroup `
            --query 'functionKeys.default' -o tsv 2>$null)
        if ($funcKey) { break }
        Write-Info "Waiting for function key... ($($i*10)s)"
        Start-Sleep -Seconds 10
    }
    if (-not $funcKey) { throw "Could not retrieve function key after 60s" }
    $FuncUrl = "https://$FuncAppName.azurewebsites.net"
    $TelemetryUrl = "$FuncUrl/api/telemetry?code=$funcKey"
    Write-Ok "Function key retrieved"
} else {
    $funcKey = 'placeholder-key'
    $FuncUrl = "https://$FuncAppName.azurewebsites.net"
    $TelemetryUrl = "$FuncUrl/api/telemetry?code=$funcKey"
}

# ─── 7. Logic App ─────────────────────────────────────────────────────────────
Write-Step "Logic App: $LogicAppName (Consumption)"

# Get IoT Hub built-in Event Hub connection string
Write-Info "Retrieving IoT Hub Event Hub-compatible endpoint..."
if (-not $DryRun) {
    $ehConnStr = (az iot hub connection-string show `
        --hub-name $IotHubName `
        --resource-group $ResourceGroup `
        --default-eventhub `
        --query 'connectionString' -o tsv 2>&1)
    if ($LASTEXITCODE -ne 0) {
        # Fallback: get from IoT Hub properties
        $ehConnStr = (az iot hub show `
            --name $IotHubName `
            --resource-group $ResourceGroup `
            --query 'properties.eventHubEndpoints.events.endpoint' -o tsv)
        Write-Info "Using Event Hub endpoint: $ehConnStr"
    }
} else {
    $ehConnStr = 'Endpoint=sb://placeholder.servicebus.windows.net/;SharedAccessKeyName=iothubowner;SharedAccessKey=placeholder'
}

# Logic App ARM template (inline — Consumption, Event Hub trigger → HTTP POST)
$laDefinition = @{
    '$schema'     = 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
    contentVersion = '1.0.0.0'
    parameters    = @{
        '$connections' = @{ defaultValue = @{}; type = 'Object' }
    }
    triggers      = @{
        'When_events_are_available_in_Event_Hub' = @{
            recurrence   = @{ frequency = 'Second'; interval = 5 }
            splitOn      = '@triggerBody()'
            type         = 'ApiConnection'
            inputs       = @{
                host       = @{ connection = @{ name = "@parameters('`$connections')['eventhubs']['connectionId']" } }
                method     = 'get'
                path       = "/@{encodeURIComponent('messages/events')}/content"
                queries    = @{ consumerGroupName = '$Default'; contentType = 'application/octet-stream'; maximumEventsCount = 10 }
            }
        }
    }
    actions       = @{
        'Post_telemetry_to_Function' = @{
            runAfter = @{}
            type     = 'Http'
            inputs   = @{
                method  = 'POST'
                uri     = $TelemetryUrl
                headers = @{ 'Content-Type' = 'application/json' }
                body    = '@triggerBody()'
            }
        }
    }
}

$laTemplate = @{
    '`$schema'         = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
    contentVersion    = '1.0.0.0'
    resources         = @(
        @{
            type       = 'Microsoft.Logic/workflows'
            apiVersion = '2019-05-01'
            name       = $LogicAppName
            location   = $Location
            properties = @{
                state      = 'Enabled'
                definition = $laDefinition
                parameters = @{
                    '$connections' = @{ value = @{} }
                }
            }
        }
    )
}

$templateFile = Join-Path $env:TEMP 'la-template.json'
$laTemplate | ConvertTo-Json -Depth 20 | Set-Content $templateFile -Encoding UTF8

$la = az logic workflow show --name $LogicAppName --resource-group $ResourceGroup 2>$null
if ($la) {
    Write-Skip "Logic App already exists — updating definition"
    Invoke-Az @(
        'logic','workflow','update',
        '--name',$LogicAppName,
        '--resource-group',$ResourceGroup,
        '--definition',(Get-Content $templateFile -Raw)
    ) | Out-Null
    Write-Ok "Updated"
} else {
    Invoke-Az @(
        'deployment','group','create',
        '--resource-group',$ResourceGroup,
        '--template-file',$templateFile,
        '--mode','Incremental'
    ) | Out-Null
    Write-Ok "Logic App created"
}

Remove-Item $templateFile -Force -ErrorAction SilentlyContinue

# ─── 8. Verify IoT Hub route ──────────────────────────────────────────────────
Write-Step "Verifying IoT Hub route for device: $DeviceId"
if (-not $DryRun) {
    $routes = az iot hub route list --hub-name $IotHubName --resource-group $ResourceGroup 2>$null | ConvertFrom-Json
    $panelRoute = $routes | Where-Object { $_.condition -like "*$DeviceId*" -or $_.name -like '*panel*' }
    if ($panelRoute) {
        Write-Ok "Route '$($panelRoute.name)' exists — condition: $($panelRoute.condition)"
    } else {
        Write-Info "No device-specific route found — creating route for $DeviceId"
        Invoke-Az @(
            'iot','hub','route','create',
            '--hub-name',$IotHubName,
            '--resource-group',$ResourceGroup,
            '--route-name','route-iotpanel',
            '--source','DeviceMessages',
            '--endpoint-name','events',
            '--condition',"`$connectionDeviceId = `"$DeviceId`"",
            '--enabled','true'
        ) | Out-Null
        Write-Ok "Route created"
    }
}

# ─── Summary ──────────────────────────────────────────────────────────────────
Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " AgenticIoT Middleware — Provisioning Complete" -ForegroundColor Green
Write-Host "============================================================`n" -ForegroundColor Green
Write-Host "  Function App URL : $FuncUrl"
Write-Host "  Health check     : $FuncUrl/api/health"
Write-Host "  Telemetry URL    : $TelemetryUrl"
Write-Host "  Logic App        : https://portal.azure.com (search '$LogicAppName')"
Write-Host "  SignalR name     : $SignalRName"
Write-Host ""
Write-Host "  Next steps:"
Write-Host "  1. Open Logic App in portal — add Event Hub connection with IoT Hub built-in endpoint"
Write-Host "  2. Test: curl $FuncUrl/api/health"
Write-Host "  3. Press a Pi switch — check Logic App run history for messages"
Write-Host "  4. Connect Power Pages to $FuncUrl/api/negotiate"
Write-Host ""
if ($DryRun) {
    Write-Host "  (DRY RUN — no resources were created)" -ForegroundColor Yellow
}
