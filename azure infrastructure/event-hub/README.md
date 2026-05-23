# Event Hub — AgenticIoT

## Purpose

The Azure Event Hub Namespace (`evhns-aw-iot-copilot`) hosts a dedicated Event Hub (`iot-telemetry`) that receives IoT device telemetry forwarded from IoT Hub via a custom message route. The Azure Function App subscribes to this Event Hub using a native Event Hub trigger, enabling sub-millisecond latency from device message to SignalR broadcast — replacing the previous Logic App polling approach.

## Resource Type & SKU

| Property | Value |
|----------|-------|
| Resource type | `Microsoft.EventHub/namespaces` |
| Namespace name | `evhns-aw-iot-copilot` |
| Event Hub name | `iot-telemetry` |
| SKU | Basic |
| Resource group | `rg-aw-azcom-iot-copilot` |

## Configuration

Key settings are stored in [`config.json`](./config.json). Do not hardcode these values in scripts.

```json
{
  "namespaceName": "evhns-aw-iot-copilot",
  "eventHubName": "iot-telemetry",
  "sku": "Basic"
}
```

## Connections

| Component | Direction | How |
|-----------|-----------|-----|
| IoT Hub (`iothub-aw-iot-copilot`) | → Event Hub | Custom endpoint + message route: all device telemetry forwarded here |
| Azure Function App (`func-aw-iot-copilot`) | reads from | Event Hub trigger using `IoTHubEventHubConnectionString` app setting |

## Deployment

Provisioned by:

```powershell
.\scripts\New-AzureMiddleware.ps1 -Environment dev
```

The script:
1. Creates the Event Hub Namespace with Basic SKU
2. Creates the `iot-telemetry` Event Hub inside the namespace
3. Creates a `listen` authorization rule on the Event Hub
4. Retrieves the listen connection string
5. Creates a custom IoT Hub endpoint pointing to this Event Hub
6. Creates an IoT Hub message route forwarding all device telemetry to this endpoint
7. Injects the connection string into the Function App as `IoTHubEventHubConnectionString`

Config is read from `azure infrastructure/event-hub/config.json`.

> **Secret:** The Event Hub listen connection string contains an access key and must not be committed to source control. The script reads it at deploy time and writes it directly to Function App settings.

## Updating

- **SKU upgrade** (Basic → Standard): Update `sku` in `config.json` and re-run `New-AzureMiddleware.ps1`.
- **Key rotation**: Use `az eventhubs eventhub authorization-rule keys renew` then re-run the script.
- **Adding event hubs**: Add additional `eventHubName` entries and update the script to provision them.

## Updating This README

Update when:
- Namespace or Event Hub names change
- SKU changes
- Message routing from IoT Hub changes
- New Event Hubs are added to the namespace
