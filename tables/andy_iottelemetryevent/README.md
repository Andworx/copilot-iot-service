# andy_iottelemetryevent — IoT Telemetry Event

## Purpose

Persists each IoT telemetry message received from a Raspberry Pi device (e.g. `raspberry-pi-iotpanel`). Records are written by the Azure Function (`iot-signalr-func`) when a message arrives via IoT Hub. The Power Pages History tab (`/history`) queries this table to display a durable event log that survives page refreshes.

## Columns

| Schema name | Display name | Type | Required | Notes |
|---|---|---|---|---|
| `andy_iottelemetryeventid` | IoT Telemetry Event | Primary Key (GUID) | Auto | System-generated |
| `andy_name` | Name | String(200) | Required | Auto-generated: `{deviceId} {timestamp}` |
| `andy_deviceid` | Device ID | String(100) | Recommended | e.g. `raspberry-pi-iotpanel` |
| `andy_eventtype` | Event Type | String(100) | Recommended | e.g. `telemetry-snapshot`, `help-triggered`, `led_on`, `led_off` |
| `andy_gpiopin` | GPIO Pin | Integer | Optional | GPIO pin number (18, 24, 25, 12, 5, 6, 13, 19). Null for non-pin events |
| `andy_value` | Value | String(100) | Optional | e.g. `OK`, `MISMATCH`, `1`, `0` |
| `andy_mismatch` | Mismatch | Boolean | Optional | True when actual LED state ≠ expected state |
| `andy_switchstate` | Switch State | Memo | Optional | JSON array of switch states e.g. `[1,0,1,0]` |
| `andy_ledstate` | LED State | Memo | Optional | JSON array of actual LED states |
| `andy_expectedledstate` | Expected LED State | Memo | Optional | JSON array of expected LED states |
| `andy_activerule` | Active Rule | String(100) | Optional | Active rule name from Pi logic e.g. `all_lights_on` |
| `createdon` | Created On | DateTime | Auto | Standard audit column |

## Folder Structure

```
tables/andy_iottelemetryevent/
├── README.md         ← You are here
├── definition.json   ← Table and column definitions (consumed by Import-Tables.ps1)
└── icon.svg          ← Fluent UI history icon (fluent/history-20-regular)
```

## Deployment

This table is deployed with the standard table import script:

```powershell
# Dry-run first
.\scripts\Import-Tables.ps1 -Environment dev -DryRun

# Real deployment
.\scripts\Import-Tables.ps1 -Environment dev
```

The table has no foreign keys to other custom tables, so it can be deployed independently (deployment order step 2).

## Population

Records are written by the Azure Function `iot-signalr-func` inside the `broadcastTelemetry()` helper. Authentication uses System-Assigned Managed Identity — see [`azure infrastructure/azure-functions/iot-signalr-func/README.md`](../../azure%20infrastructure/azure-functions/iot-signalr-func/README.md) for the one-time setup steps.

## Power Pages Table Permission

> **Manual step** — table permissions cannot be managed via PAC CLI or code (see `power pages/CLAUDE.md`).

After deploying the table, configure access in the Power Pages admin center:

1. Open **Power Pages admin center** → `iot-panel-dashboard` → **Table Permissions**
2. Click **Add** and configure:
   - **Table**: `IoT Telemetry Event (andy_iottelemetryevent)`
   - **Access type / Scope**: Global
   - **Privileges**: Read
   - **Web roles**: Authenticated Users
3. Save and sync the portal

## Updating This README

Update this file when:
- A column is added, removed, or renamed
- The write source changes (e.g. Logic App instead of Azure Function)
- Table permission scope or roles change
