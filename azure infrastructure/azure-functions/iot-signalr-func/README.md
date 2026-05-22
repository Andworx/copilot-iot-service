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
| HTTP GET | `/api/negotiate` | function | SignalR connection info for browser clients |
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
| `DATAVERSE_URL` | Dataverse environment URL e.g. `https://orgdec501b8.crm.dynamics.com` — set as an **Environment variable** on the Function App (see Dataverse Auth below) |

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

**Step 3 — Set the `DATAVERSE_URL` environment variable**

Set `DATAVERSE_URL` as an **environment variable** on the Function App (Azure Portal → Function App → **Environment variables** blade, _not_ Configuration/Application settings):

```bash
az functionapp config appsettings set \
  --resource-group rg-aw-azcom-iot-copilot \
  --name func-aw-iot-copilot \
  --settings DATAVERSE_URL=https://orgdec501b8.crm.dynamics.com
```

> **Note:** In Azure Functions, App Settings and Environment Variables are both surfaced as `process.env` inside the function. Either location works — Environment variables is preferred for non-connection-string config.

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
    "DATAVERSE_URL": "https://orgdec501b8.crm.dynamics.com",
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
  "https://iot-agents.crm.dynamics.com/api/data/v9.2/andy_iottelemetryevents?\$top=5&\$orderby=createdon desc"
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

Deployed via `scripts/New-AzureMiddleware.ps1 -Environment dev`.
The script zips the source, runs `npm install --production`, and publishes to `func-aw-iot-copilot`.

## Updating This README

Update this file when:
- A new trigger or endpoint is added or removed
- Required app settings change
- The pipeline architecture changes
- Dataverse auth setup steps change
