# Azure Functions — AgenticIoT Middleware

## Purpose

This directory contains the Azure Function App that bridges IoT Hub telemetry to browser clients via SignalR Service.

## Pipeline

```
Raspberry Pi
    │  MQTT/TLS
    ▼
Azure IoT Hub (iothub-aw-iot-copilot)
    │  built-in Event Hub endpoint
    ▼
Azure Function App (func-aw-iot-copilot)  ◄── this directory
    │  EventHub trigger (iotTelemetry) + HTTP endpoints
    ├──► Azure SignalR Service (signalr-aw-iot-copilot)
    │       WebSocket broadcast → SendTelemetryUpdate / TriggerAgentHelp
    │       ▼
    │    Power Pages Browser Dashboard
    └──► Dataverse (andy_iottelemetryevent)
             Persisted event log — System-Assigned MSI auth
```

## Structure

```
azure infrastructure/
└── azure-functions/
    ├── config.json
    └── iot-signalr-func/
        ├── src/
        │   └── app.js                     # All function handlers
        ├── host.json                      # Functions runtime config (v4, extension bundle 4.x)
        ├── package.json                   # Node.js dependencies
        ├── local.settings.json.template   # Copy → local.settings.json for local dev
        └── .gitignore                     # Excludes node_modules, local.settings.json
```

## Endpoints

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| EventHub | `iotTelemetry` | — | **Primary** — reads IoT Hub built-in EH endpoint, broadcasts to SignalR + writes to Dataverse |
| `GET` | `/api/negotiate` | Anonymous | SignalR connection info for browser clients (CORS-restricted by `ALLOWED_ORIGIN`) |
| `GET` | `/api/directline-token` | Anonymous | Issues a short-lived Direct Line token — the channel secret stays server-side (CORS-restricted by `ALLOWED_ORIGIN`) |
| `POST` | `/api/telemetry` | Function key | **Secondary/test** — manual telemetry injection; broadcasts via SignalR + writes to Dataverse |
| `GET` | `/api/test-signalr` | Anonymous | Manually push a test `SendTelemetryUpdate` message to SignalR |
| `GET` | `/api/health` | Anonymous | Health check |

## SignalR Messages

### `SendTelemetryUpdate`
Sent on every telemetry message. Browser subscribes to this for real-time panel state.

```json
{
  "deviceId": "raspberry-pi-iotpanel",
  "timestamp": "2026-05-18T20:00:00Z",
  "data": {
    "switches": [1, 0, 1, 0],
    "actual_leds": [1, 0, 1, 0],
    "active_rule": "all_lights_on",
    "mismatch": false,
    "needs_help": false
  },
  "source": "iot-hub"
}
```

### `TriggerAgentHelp`
Sent when `needs_help === true` (mismatch detected or rule ≠ `all_lights_on`). Triggers the Copilot Studio agent.

```json
{
  "deviceId": "raspberry-pi-iotpanel",
  "timestamp": "2026-05-18T20:00:00Z",
  "active_rule": "fallback",
  "switches": [1, 0, 0, 0],
  "expected_leds": [0],
  "actual_leds": [0],
  "mismatch": false
}
```

## Deployment

### Full infrastructure + deploy (recommended)

```powershell
# From repo root — provisions SignalR, Function App, Event Hub, Storage, then deploys code
.\scripts\New-AzureMiddleware.ps1 -Environment dev
```

### Deploy code only (after infrastructure exists)

```bash
# From azure infrastructure/azure-functions/iot-signalr-func
npm install --omit=dev
# Zip and deploy via az CLI (no func CLI required)
Compress-Archive -Path * -DestinationPath "$env:TEMP\func-deploy.zip" -Force
az functionapp deployment source config-zip --name func-aw-iot-copilot --resource-group rg-aw-azcom-iot-copilot --src "$env:TEMP\func-deploy.zip" --build-remote true
```

### Local development

```bash
cd "azure infrastructure/azure-functions/iot-signalr-func"
cp local.settings.json.template local.settings.json
# Edit local.settings.json — add AzureSignalRConnectionString
npm install
npm start
```

## Verify End-to-End

```bash
# 1. Health check
curl https://func-aw-iot-copilot.azurewebsites.net/api/health

# 2. Push a test SignalR message
curl https://func-aw-iot-copilot.azurewebsites.net/api/test-signalr

# 3. Press a switch on the Pi — check Function App invocations in Azure Portal (Monitor → Invocations)
# 4. Connect a browser SignalR client to /api/negotiate and watch for SendTelemetryUpdate
```

## Configuration

Key settings for the Function App are stored in [`config.json`](./config.json). Do not hardcode these values in scripts.

```json
{
  "name": "func-aw-iot-copilot",
  "planName": "plan-func-aw-iot-copilot",
  "planSku": "Y1",
  "runtime": "node",
  "runtimeVersion": "24",
  "os": "Windows"
}
```

For other resources used by the Function App, see their dedicated config files:
- SignalR Service → [`../signalr/config.json`](../signalr/config.json)
- Storage Account → [`../storage-account/config.json`](../storage-account/config.json)
- Event Hub → [`../event-hub/config.json`](../event-hub/config.json)

## Azure Resources

| Resource | Name | SKU | Notes |
|----------|------|-----|-------|
| Function App | `func-aw-iot-copilot` | Consumption Y1 | Node.js 24, Windows |
| App Service Plan | `plan-func-aw-iot-copilot` | Y1 Consumption | Auto-created with Function App |
| SignalR Service | `signalr-aw-iot-copilot` | Free_F1 | Serverless mode — see `../signalr/` |
| Storage Account | `stfuncawiotcopilot` | Standard LRS | Required by Function App — see `../storage-account/` |
| Event Hub | `evhns-aw-iot-copilot / iot-telemetry` | Basic | Telemetry source — see `../event-hub/` |

## Updating This README

Update when:
- New function endpoints are added to `app.js`
- SignalR message contracts change
- Azure resource names or SKUs change
- Deployment process changes
