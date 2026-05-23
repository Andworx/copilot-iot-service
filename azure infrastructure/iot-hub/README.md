# IoT Hub — AgenticIoT

## Purpose

Azure IoT Hub is the cloud gateway that all IoT devices connect to. In this solution it receives MQTT telemetry from the Raspberry Pi IoT Panel, routes messages to a dedicated Event Hub for downstream processing, and manages device identity and provisioning via the linked Device Provisioning Service.

## Resource Type & SKU

| Property | Value |
|----------|-------|
| Resource type | `Microsoft.Devices/IotHubs` |
| Name | `iothub-aw-iot-copilot` |
| SKU | S1 Standard |
| Units | 1 |
| Event Hub partitions | 4 |
| Resource group | `rg-aw-azcom-iot-copilot` |

## Configuration

Key settings are stored in [`config.json`](./config.json). The script reads this file at runtime — do not hardcode these values in scripts.

```json
{
  "name": "iothub-aw-iot-copilot",
  "sku": "S1",
  "units": 1,
  "partitionCount": 4,
  "deviceId": "raspberry-pi-iotpanel"
}
```

The IoT Hub is provisioned once and shared across environments at this time. The `deviceId` is the registered device identity for the Raspberry Pi IoT Panel.

## Connections

| Component | Direction | How |
|-----------|-----------|-----|
| Raspberry Pi | → IoT Hub | MQTT/TLS on port 8883 using symmetric key auth |
| Device Provisioning Service | ↔ IoT Hub | DPS linked hub — issues credentials and routes new devices here |
| Event Hub (`evhns-aw-iot-copilot / iot-telemetry`) | IoT Hub → | Custom endpoint + message route forwards all device telemetry |
| Azure Function App | reads via | Event Hub trigger on the dedicated Event Hub |

## Deployment

Provisioned by:

```powershell
.\scripts\New-AzureIotInfrastructure.ps1 -Environment dev
```

The script:
1. Creates the resource group (if absent)
2. Creates the IoT Hub with S1 SKU
3. Registers the device identity (`raspberry-pi-iotpanel`)
4. Creates and links the Device Provisioning Service
5. Creates the DPS group enrollment

The script reads resource names and SKUs from `azure infrastructure/iot-hub/config.json` and `azure infrastructure/device-provisioning-service/config.json`.

> **Note:** Individual device connection strings are derived from the DPS group key using HMAC-SHA256. The group key is shown once at the end of the script — store it in Key Vault immediately.

## Updating

Re-run `New-AzureIotInfrastructure.ps1` after any of these changes:

- Adding new device identities
- Changing the IoT Hub SKU or unit count (requires delete/recreate)
- Adding or modifying message routes

Update `config.json` and this README for any name, SKU, or topology changes.

## Updating This README

Update when:
- Resource name or SKU changes
- A new device identity is added
- Message routing changes
- The deployment script changes
