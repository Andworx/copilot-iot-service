# IoT — Auto Dispatch on Fault

| Property | Value |
|---|---|
| **Flow name** | `andy_IoTFaultDispatch` |
| **Trigger** | Dataverse — When a row is added (`andy_iottelemetryevent`, `andy_mismatch eq true`) |
| **Solution** | AgenticIoT |
| **Connection reference** | `andy_shared_commondataserviceforapps` |

## Purpose

Automates technician dispatch when the IoT panel reports a mismatch fault. When a telemetry event is written to `andy_iottelemetryevent` with `andy_mismatch = true`, this flow:

1. Looks up the sensor record in `andy_iot_sensor` by `andy_deviceid`
2. Suppresses duplicate dispatch if an Open record already exists in `andy_dispatch_history` for that sensor
3. Queries all technicians with `andy_availability = Available`
4. Selects the nearest technician using squared Euclidean GPS distance (Δlat² + Δlon²)
5. Creates a `andy_dispatch_history` record (dispatch number auto-generated as `DISP-{YYYY}-{SEQNUM:5}`)
6. Sets the sensor `andy_sensor_status` → `Error` and links the active dispatch
7. Sets the technician `andy_availability` → `On Job`

## Flow Structure

```
Trigger: andy_iottelemetryevent (andy_mismatch eq true)
│
├── [Init variables] MinDistance, NearestTechId, NearestTechName, SensorLat, SensorLon, CurrentDistance
│
├── Guard_SensorLookup         → LIST andy_iot_sensors (by device_id)
├── Condition_SensorFound      → else: Terminate (Succeeded — unknown device, skip)
├── Set_SensorLat / Set_SensorLon
│
├── Guard_DuplicateCheck       → LIST andy_dispatch_historyset (open dispatch for this sensor)
├── Condition_NoDuplicate      → else: Terminate (Succeeded — already dispatched)
│
├── Data_GetAvailableTechs     → LIST andy_technicians (andy_availability eq 756150000)
├── Condition_TechsAvailable   → else: Terminate (Failed — no techs, surfaces as error)
│
├── Loop_FindNearest [Sequential]
│   ├── Calc_Distance          → SetVariable Var_CurrentDistance (Δlat² + Δlon²)
│   └── Condition_IsNearer     → update MinDistance, NearestTechId, NearestTechName
│
├── Condition_TechSelected     → else: Terminate (Failed — no GPS data on techs)
│
├── Data_CreateDispatch        → CREATE andy_dispatch_historyset
├── Data_UpdateSensorStatus    → UPDATE andy_iot_sensors  (status=Error, link dispatch)  ┐ parallel
└── Data_UpdateTechAvailability→ UPDATE andy_technicians (availability=On Job)           ┘
```

## Key Design Decisions

| Decision | Rationale |
|---|---|
| **Flow-only (no agent call)** | Dispatch logic is deterministic — no NLU needed. Flow is more reliable and auditable. |
| **Sequential loop** | Variables used inside the Foreach require sequential mode to avoid race conditions. |
| **Squared Euclidean distance** | Sufficient for nearest-tech comparison. No trig overhead. Invalid for actual distance. |
| **Terminate Succeeded for guard skips** | Unknown device / duplicate suppression are expected conditions — no error noise in run history. |
| **Terminate Failed for no-tech** | Genuinely exceptional — surfaces in run history for investigation. |

## Error codes

| Code | Meaning |
|---|---|
| `NO_TECHS_AVAILABLE` | No technician with Availability = Available exists. |
| `NO_TECH_SELECTED` | Loop completed but no tech was selected — likely all techs have null GPS coordinates. |

## Deployment

The `Import-Flows.ps1` script discovers flow files by scanning for `andy_*.json` directly in the `flows/` root.
The canonical deployment copy lives at **`flows/andy_IoTFaultDispatch.json`** — this is what the script imports.
The copy in this subdirectory (`flows/iot-fault-dispatch/flow.json`) is the source-of-record for editing; keep both in sync when making changes.

Import via `scripts/Import-Flows.ps1`. After import:
- Ensure the `andy_shared_commondataserviceforapps` connection reference is configured
- Turn on the flow
- Verify with a test telemetry record: set `andy_mismatch = true` on an existing sensor

## Updating this README

Update this file when:
- Trigger filter expression changes
- New guard conditions are added or removed
- Dispatch logic (tech selection, record creation) changes
- New connection references are added
