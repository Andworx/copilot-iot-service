# SignalR Service — AgenticIoT

## Purpose

Azure SignalR Service provides persistent WebSocket connections between the Azure Function App and browser clients (the Power Pages IoT Dashboard). When the Function App receives telemetry from the Event Hub, it broadcasts it to all connected browser clients in real time via SignalR — eliminating polling and delivering sub-second updates to the dashboard.

## Resource Type & SKU

| Property | Value |
|----------|-------|
| Resource type | `Microsoft.SignalRService/SignalR` |
| Name | `signalr-aw-iot-copilot` |
| SKU | Free_F1 |
| Service mode | Serverless |
| Max concurrent connections | 20 (Free tier) |
| Resource group | `rg-aw-azcom-iot-copilot` |

## Configuration

Key settings are stored in [`config.json`](./config.json). Do not hardcode these values in scripts.

```json
{
  "name": "signalr-aw-iot-copilot",
  "sku": "Free_F1",
  "serviceMode": "Serverless",
  "corsAllowedOrigins": ["*"]
}
```

CORS is set to `*` for development. Restrict to the Power Pages portal hostname in production.

## Connections

| Component | Direction | How |
|-----------|-----------|-----|
| Azure Function App (`func-aw-iot-copilot`) | → SignalR | Uses `AzureSignalRConnectionString` app setting; Function App calls `negotiate` and broadcasts messages |
| Power Pages browser client | ↔ SignalR | Connects to `/api/negotiate`, then listens for `SendTelemetryUpdate` and `TriggerAgentHelp` messages |

## Deployment

Provisioned by:

```powershell
.\scripts\New-AzureMiddleware.ps1 -Environment dev
```

The script:
1. Creates the SignalR Service with Free_F1 SKU in Serverless mode
2. Sets CORS origins
3. Retrieves the primary connection string and injects it into the Function App app settings as `AzureSignalRConnectionString`

Config is read from `azure infrastructure/signalr/config.json`.

> **Secret:** The SignalR connection string contains an access key and must not be committed to source control. The script reads it at deploy time and writes it directly to Function App settings.

## Updating

- **SKU upgrade** (Free → Standard): Change `sku` in `config.json` and re-run `New-AzureMiddleware.ps1`. Note: Free tier limited to 20 concurrent connections.
- **CORS origins**: Update `corsAllowedOrigins` in `config.json` before re-running the script.
- **Rotating keys**: Use `az signalr key renew` and re-run the script to push the new connection string.

## Updating This README

Update when:
- Resource name or SKU changes
- CORS policy changes
- SignalR message contracts change (see `azure-functions/README.md` for message schemas)
