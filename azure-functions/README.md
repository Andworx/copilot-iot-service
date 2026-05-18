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
Azure Logic App (la-aw-iot-copilot)
    │  polls every 5s → HTTP POST
    ▼
Azure Function App (func-aw-iot-copilot)  ◄── this directory
    │  /api/telemetry
    ▼
Azure SignalR Service (signalr-aw-iot-copilot)
    │  WebSocket broadcast → SendTelemetryUpdate / TriggerAgentHelp
    ▼
Power Pages Browser Dashboard
```

## Structure

```
azure-functions/
└── iot-signalr-func/
    ├── src/
    │   └── app.js                     # All function handlers (negotiate, telemetry, test, health)
    ├── host.json                      # Functions runtime config (v4, extension bundle 4.x)
    ├── package.json                   # Node.js dependencies
    ├── local.settings.json.template   # Copy → local.settings.json for local dev
    └── .gitignore                     # Excludes node_modules, local.settings.json
```

## Endpoints

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| `GET`  | `/api/negotiate` | Function key | SignalR connection info for browser clients |
| `POST` | `/api/telemetry` | Function key | Receive telemetry from Logic App, broadcast via SignalR |
| `GET`  | `/api/test-signalr` | Anonymous | Manually push a test message to SignalR |
| `GET`  | `/api/health` | Anonymous | Health check |

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
# From repo root — provisions SignalR, Function App, Logic App, then deploys code
.\scripts\New-AzureMiddleware.ps1 -Environment dev
```

### Deploy code only (after infrastructure exists)

```bash
# From azure-functions/iot-signalr-func
npm install --omit=dev
# Zip and deploy via az CLI (no func CLI required)
Compress-Archive -Path * -DestinationPath "$env:TEMP\func-deploy.zip" -Force
az functionapp deployment source config-zip --name func-aw-iot-copilot --resource-group rg-aw-azcom-iot-copilot --src "$env:TEMP\func-deploy.zip" --build-remote true
```

### Local development

```bash
cd azure-functions/iot-signalr-func
cp local.settings.json.template local.settings.json
# Edit local.settings.json — add AzureSignalRConnectionString
npm install
npm start
```

## Logic App — Event Hub Connection

After `New-AzureMiddleware.ps1` runs, the Logic App needs a manual connection step in the portal (first time only):

1. Open **la-aw-iot-copilot** in Azure Portal
2. Open **Logic App Designer**
3. Click the trigger → **Add new connection**
4. Connection string: IoT Hub built-in Event Hub endpoint
   ```powershell
   az iot hub connection-string show --hub-name iothub-aw-iot-copilot --resource-group rg-aw-azcom-iot-copilot --default-eventhub --query connectionString -o tsv
   ```
5. Consumer group: `$Default`
6. **Save**

> **Why Logic App?** Event Hub triggers on Consumption Function Apps suffer cold-start issues. Logic App provides reliable 5-second polling with built-in retry and run history for debugging.

## Azure Resources

| Resource | Name | SKU | Notes |
|----------|------|-----|-------|
| Function App | `func-aw-iot-copilot` | Consumption Y1 | Node.js 24, Linux |
| SignalR Service | `signalr-aw-iot-copilot` | Free_F1 | Serverless mode, 20 concurrent connections |
| Logic App | `la-aw-iot-copilot` | Consumption | Polls Event Hub every 5s |
| Storage Account | `stfuncawiotcopilot` | Standard LRS | Required by Function App |

## Verify End-to-End

```bash
# 1. Health check
curl https://func-aw-iot-copilot.azurewebsites.net/api/health

# 2. Push a test SignalR message
curl https://func-aw-iot-copilot.azurewebsites.net/api/test-signalr

# 3. Press a switch on the Pi — check Logic App run history in portal
# 4. Connect a browser SignalR client to /api/negotiate and watch for SendTelemetryUpdate
```

## Updating This README

Update when:
- New function endpoints are added to `app.js`
- SignalR message contracts change
- Azure resource names or SKUs change
- Deployment process changes
