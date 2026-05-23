# Azure Infrastructure

## Purpose

This directory contains the source-controlled Azure resource definitions, configuration, and code for all AgenticIoT Azure components. Each component has a dedicated subfolder with its own `README.md` and `config.json` — resource names, SKUs, and other non-secret settings live in those files, not in deployment scripts.

## Components

| Component | Folder | Script | Purpose |
|-----------|--------|--------|---------|
| IoT Hub | [`iot-hub/`](./iot-hub/) | `New-AzureIotInfrastructure.ps1` | Cloud gateway for Raspberry Pi MQTT telemetry |
| Device Provisioning Service | [`device-provisioning-service/`](./device-provisioning-service/) | `New-AzureIotInfrastructure.ps1` | Zero-touch device provisioning via symmetric key group enrollment |
| Event Hub | [`event-hub/`](./event-hub/) | `New-AzureMiddleware.ps1` | Dedicated event stream receiving IoT Hub telemetry for the Function App |
| Azure Function App | [`azure-functions/`](./azure-functions/) | `New-AzureMiddleware.ps1` | SignalR broadcast endpoint; Event Hub trigger → browser clients |
| SignalR Service | [`signalr/`](./signalr/) | `New-AzureMiddleware.ps1` | Real-time WebSocket push from Function App to browser dashboard |
| Storage Account | [`storage-account/`](./storage-account/) | `New-AzureMiddleware.ps1` | Mandatory backing store for the Consumption Function App |
| Logic App *(deprecated)* | [`azure-logic apps/`](./azure-logic%20apps/) | — | Replaced by Event Hub trigger; retained for reference only |

## Shared Configuration

[`config.json`](./config.json) holds values shared across all components:

```json
{
  "resourceGroup": "rg-aw-azcom-iot-copilot",
  "defaultLocation": "eastus",
  "tags": "project=iot-copilot owner=andworx"
}
```

## Structure

```
azure infrastructure/
├── config.json                             ← shared: resource group, location, tags
├── iot-hub/
│   ├── README.md
│   └── config.json
├── device-provisioning-service/
│   ├── README.md
│   └── config.json
├── event-hub/
│   ├── README.md
│   └── config.json
├── azure-functions/
│   ├── README.md
│   ├── config.json
│   └── iot-signalr-func/                   ← Function App source code
│       ├── src/app.js
│       ├── host.json
│       ├── local.settings.json.template
│       └── package.json
├── signalr/
│   ├── README.md
│   └── config.json
├── storage-account/
│   ├── README.md
│   └── config.json
└── azure-logic apps/                       ← deprecated; retained for reference
    └── la-aw-iot-copilot/
        └── workflow.json
```

## Deployment

### IoT Core Infrastructure (IoT Hub + DPS)

```powershell
.\scripts\New-AzureIotInfrastructure.ps1 -Environment dev
```

### Middleware (Function App, SignalR, Event Hub, Storage)

```powershell
.\scripts\New-AzureMiddleware.ps1 -Environment dev
```

Both scripts read configuration from component folders under this directory. Secrets (connection strings, keys) are retrieved at deploy time via Azure CLI and written to Function App settings — never stored in config files or source control.

## Updating This README

Update this file when:
- A new Azure component is added or removed
- A component folder is renamed
- The deployment script layout changes