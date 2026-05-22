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

### IoTHubEventHubConnectionString format

This is **not** the Event Hub namespace connection string. It is the IoT Hub's built-in Event Hub-compatible endpoint:

```
Endpoint=sb://<iothub-name>.servicebus.windows.net/;SharedAccessKeyName=iothubowner;SharedAccessKey=<key>;EntityPath=<iothub-name>
```

Get it from the Azure Portal: **IoT Hub → Built-in endpoints → Event Hub-compatible endpoint**.

`New-AzureMiddleware.ps1` sets this automatically during provisioning.

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
