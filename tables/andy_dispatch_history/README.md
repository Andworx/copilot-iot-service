# andy_dispatch_history — Dispatch History

## Purpose

Audit log of IoT fault dispatch assignments. Each record captures one technician assignment to one sensor fault. The dispatch agent queries this table **before every dispatch** to check for open assignments — if an open record exists for the sensor, a duplicate dispatch is suppressed.

## Key Columns

| Column | Type | Notes |
|--------|------|-------|
| `andy_name` | Text | Auto-number: `DISP-{YYYY}-{SEQNUM:5}` (e.g. `DISP-2026-00001`) |
| `andy_technician_id` | Lookup → `andy_technician` | Assigned technician |
| `andy_sensor_id` | Lookup → `andy_iot_sensor` | Sensor that triggered the dispatch |
| `andy_status` | Choice | `Open` / `Resolved` / `Cancelled` |
| `andy_dispatched_at` | DateTime | When the assignment was created |
| `andy_resolved_at` | DateTime | Null while open |
| `andy_error_code` | Text | Error code from Pi payload |
| `andy_error_message` | Memo | Full error description |

## Choices Used

- `andy_dispatch_status` — `tables/choices/andy_dispatch_status.json`

## Relationships

| Relationship | Type | Notes |
|---|---|---|
| `andy_technician_dispatchhistory` | N:1 | Many dispatch records per technician |
| `andy_iotsensor_dispatchhistory` | N:1 | Many dispatch records per sensor |

## Duplicate-Suppression Guard

Before dispatching, the agent queries:
```
andy_dispatch_historys?$filter=andy_sensor_id eq '<sensorId>' and andy_status eq 756150000
```
- **Open record found** → suppress dispatch, notify user with existing tech's name
- **No open record** → proceed with nearest-tech selection and create new record

## Deployment Order

Must deploy **after** `andy_technician` (for the technician relationship). The `andy_sensor_id` lookup is added via relationship after `andy_iot_sensor` also exists.

```powershell
.\Deploy-Project.ps1 -Job Import-Tables        -Environment dev
.\Deploy-Project.ps1 -Job Import-Relationships -Environment dev
```

## Updating This README

Update when: columns are added/removed, relationships change, or the duplicate-suppression query changes.
