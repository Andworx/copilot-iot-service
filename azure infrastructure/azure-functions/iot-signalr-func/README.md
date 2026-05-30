# iot-signalr-func

## Purpose

Azure Functions app that bridges IoT Hub telemetry to the browser dashboard via Azure SignalR Service.

## Pipeline

```
Pi GPIO → IoT Hub → built-in Event Hub → iotTelemetry (EH trigger) → SignalR → Browser
```

The Event Hub trigger fires within milliseconds of the Pi sending a message — no polling, sub-500ms end-to-end latency.

A secondary HTTP endpoint (`POST /api/telemetry`) is retained for manual testing and backward compatibility.

## Endpoints

| Trigger | Name | Auth | Purpose |
|---------|------|------|---------|
| EventHub | `iotTelemetry` | — | **Primary** — reads IoT Hub built-in EH, broadcasts to SignalR |
| HTTP GET | `/api/negotiate` | anonymous | SignalR connection info for browser clients (CORS-restricted by `ALLOWED_ORIGIN`) |
| HTTP GET | `/api/directline-token` | anonymous | Issues a short-lived Direct Line token — secret stays server-side (CORS-restricted by `ALLOWED_ORIGIN`) |
| HTTP POST | `/api/telemetry` | function | **Secondary/test** — manual telemetry injection |
| HTTP GET | `/api/test-signalr` | anonymous | Smoke-test SignalR broadcast |
| HTTP GET | `/api/health` | anonymous | Health check |

## Required App Settings

| Setting | Description |
|---------|-------------|
| `AzureSignalRConnectionString` | Azure SignalR Service connection string |
| `AzureWebJobsStorage` | Storage account connection string (required by Functions runtime) |
| `IoTHubEventHubConnectionString` | IoT Hub owner connection string in Event Hub-compatible format (see below) |
| `IoTHubName` | IoT Hub name — used as the Event Hub entity path (default: `iothub-aw-iot-copilot`) |
| `DATAVERSE_URL` | Dataverse environment URL e.g. `https://<your-org>.crm.dynamics.com` |
| `DIRECTLINE_SECRET` | Copilot Studio Direct Line channel secret — **never** put this in the SPA; the `/api/directline-token` endpoint exchanges it for a short-lived token server-side |
| `ALLOWED_ORIGIN` | Power Pages portal URL used for CORS (e.g. `https://your-portal.powerappsportals.com`). Falls back to `*` if not set (local dev only) |

### IoTHubEventHubConnectionString format

This is **not** the Event Hub namespace connection string. It is the IoT Hub's built-in Event Hub-compatible endpoint:

```
Endpoint=sb://<iothub-name>.servicebus.windows.net/;SharedAccessKeyName=iothubowner;SharedAccessKey=<key>;EntityPath=<iothub-name>
```

Get it from the Azure Portal: **IoT Hub → Built-in endpoints → Event Hub-compatible endpoint**.

`New-AzureMiddleware.ps1` sets this automatically during provisioning.

## Dataverse Auth — System-Assigned Managed Identity

The function writes telemetry records to the `andy_iottelemetryevent` Dataverse table using `DefaultAzureCredential` from `@azure/identity`. In Azure this resolves to the Function App's System-Assigned Managed Identity (MSI); locally it uses your `az login` session.

### Why MSI over a Service Principal

| | MSI | Service Principal |
|---|---|---|
| Secrets | None | `client_secret` required |
| Rotation | Automatic | Manual |
| Complexity | Low | Medium |
| Works locally | No (use `az login` fallback) | Yes |

### One-time setup (run once per environment)

**Step 1 — Enable System-Assigned Identity on the Function App**

```bash
az functionapp identity assign \
  --resource-group <resource-group> \
  --name <function-app-name>
# Copy the principalId from the output
```

**Step 2 — Register the MSI as a Dataverse Application User**

1. Go to [Power Platform Admin Center](https://admin.powerplatform.microsoft.com) → **Environments** → your environment → **Settings** → **Users + permissions** → **Application users**
2. Click **New app user** → **+ Add an app** → search by the MSI's **Application (Client) ID**
   - Find this in Azure Portal → **Azure Active Directory** → **Enterprise applications** → search `func-aw-iot-copilot` → copy **Application ID**
   - ⚠️ This is NOT the Object ID shown on the Identity blade — it is the Application ID from Enterprise applications
3. Select the correct Business Unit
4. Assign a security role with **Create** access on `andy_iottelemetryevent`
   - Use the existing **System Administrator** role for initial setup, then tighten to a custom "IoT Writer" role if needed

**Step 3 — Set the `DATAVERSE_URL` app setting**

Set `DATAVERSE_URL` as an **App Setting** on the Function App (Azure Portal → Function App → **Configuration** → **Application settings**, or the **Environment variables** blade in newer portal — both are equivalent and surfaced as `process.env` inside the function):

```bash
az functionapp config appsettings set \
  --resource-group rg-aw-azcom-iot-copilot \
  --name func-aw-iot-copilot \
  --settings DATAVERSE_URL=https://<your-org>.crm.dynamics.com
```

### Local development

`DefaultAzureCredential` automatically tries `az login` credentials locally:

```bash
az login
# Ensure your account has access to the Dataverse environment
```

Add `DATAVERSE_URL` to `local.settings.json`:

```json
{
  "IsEncrypted": false,
  "Values": {
    "DATAVERSE_URL": "https://<your-org>.crm.dynamics.com",
    ...
  }
}
```

### Verification

After deployment, send a test telemetry message and check:

```bash
# Check Function logs for:
# "Dataverse record created for device: raspberry-pi-iotpanel"

# Or query Dataverse directly:
curl -H "Authorization: Bearer <token>" \
  "https://<your-org>.crm.dynamics.com/api/data/v9.2/andy_iottelemetryevents?\$top=5&\$orderby=createdon desc"
```

### Failure behaviour

The Dataverse write is fire-and-forget inside `broadcastTelemetry()`. If it fails (token error, network issue, permission denied), the error is logged but the SignalR broadcast always completes. The History tab will simply show fewer records until the issue is resolved.

---

## Local Development

1. Copy `local.settings.json.template` → `local.settings.json` and fill in real values
2. Install dependencies: `npm install`
3. Start Azurite (local storage emulator) or set `AzureWebJobsStorage` to a real connection string
4. Start the function host: `npm start` (runs `func start`)

> **Note:** The Event Hub trigger requires a real IoT Hub connection — it cannot be emulated locally without an actual IoT Hub. Use the `/api/telemetry` HTTP endpoint for local testing instead.

## Deployment

### Deploy function code only (recommended for code changes)

Use Azure Functions Core Tools to publish directly — fast and reliable:

```bash
cd "azure infrastructure/azure-functions/iot-signalr-func"
npm install
func azure functionapp publish func-aw-iot-copilot --node
```

Prerequisites: `az login`, `npm`, and Azure Functions Core Tools v4 (`func --version`).

### Full infrastructure + code deploy (first-time or reprovisioning)

```powershell
cd scripts
.\New-AzureMiddleware.ps1 -Environment dev
```

This provisions all Azure resources (Resource Group, SignalR, Storage, Event Hub, IoT Hub routing, Function App) and then deploys the function code. It is idempotent — existing resources are skipped.

To provision infrastructure **without** re-deploying code:

```powershell
.\New-AzureMiddleware.ps1 -Environment dev -SkipFunctionDeploy
```

## Updating This README

Update this file when:
- A new trigger or endpoint is added or removed
- Required app settings change
- The pipeline architecture changes
- Dataverse auth setup steps change
