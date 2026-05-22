# andy_iot_sensor — IoT Sensor

## Purpose

Registry of IoT sensor devices. Stores fixed metadata (device ID, site, location, type) for each device. When an error payload arrives from IoT Hub, the dispatch agent looks up the sensor record here to get coordinates and site context for nearest-tech selection.

## Key Columns

| Column | Type | Notes |
|--------|------|-------|
| `andy_device_id` | Text | **Primary name** — matches IoT Hub device ID (e.g. `raspberry-pi-iotpanel`) |
| `andy_site_name` | Text | Facility/site name |
| `andy_device_type` | Choice | `Power Panel` / `Temperature` / `Pressure` / `Humidity` / `Motion` |
| `andy_status` | Choice | `Online` / `Error` / `Offline` / `Maintenance` |
| `andy_latitude` | Decimal | Fixed GPS latitude of installation site |
| `andy_longitude` | Decimal | Fixed GPS longitude of installation site |
| `andy_last_seen` | DateTime | Last telemetry heartbeat |
| `andy_active_assignment_id` | Lookup → `andy_dispatch_history` | Current open dispatch record; null when no fault active |

## Choices Used

- `andy_iot_sensor_device_type` — `tables/choices/andy_iot_sensor_device_type.json`
- `andy_iot_sensor_status` — `tables/choices/andy_iot_sensor_status.json`

## Relationships

| Relationship | Type | Notes |
|---|---|---|
| `andy_iotsensor_dispatchhistory` | 1:N | One sensor → many dispatch history records |
| `andy_dispatchhistory_iotsensor_active` | N:1 | Active assignment lookup back to dispatch history |

## Deployment Order

Must deploy after `andy_dispatch_history` (for the `andy_active_assignment_id` relationship). Relationships are added after both tables exist.

```powershell
.\Deploy-Project.ps1 -Job Import-Tables        -Environment dev
.\Deploy-Project.ps1 -Job Import-Relationships -Environment dev
```

## Seed Data

12 simulated IoT sensors across US East. Run after table deployment:

```powershell
.\scripts\Seed-TechnicianData.ps1 -Environment dev
```

## Updating This README

Update when: columns are added/removed, relationships change, seed data is modified, or the device ID naming convention changes.
