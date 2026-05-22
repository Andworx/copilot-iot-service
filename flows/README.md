# Flows

Power Automate cloud flows for the AgenticIoT solution. All flows are solution-aware and use connection references — never hard-wired connections.

## Flows

| Folder | Display Name | Trigger | Purpose |
|---|---|---|---|
| `iot-fault-dispatch/` | IoT — Auto Dispatch on Fault | Dataverse row added (`andy_iottelemetryevent`, mismatch=true) | Automatically dispatches the nearest available technician when an IoT sensor reports a mismatch fault |

## Connection References

See [`connection-references.example.json`](connection-references.example.json) for the connection references used across all flows.

| Schema name | Connector | Used by |
|---|---|---|
| `andy_shared_commondataserviceforapps` | Microsoft Dataverse | All flows |
| `andy_shared_office365` | Office 365 Outlook | Notification flows (future) |
| `andy_shared_teams` | Microsoft Teams | Notification flows (future) |

## Environment Variables

See [`environment-variables.example.json`](environment-variables.example.json) for all configurable environment variables.

## Conventions

- All flows must be solution-aware (AgenticIoT solution)
- Use connection references — never direct connections
- After import, set plan items to `⬜ Verify` until runtime validation passes
- Full conventions in [`CLAUDE.md`](CLAUDE.md)

## Updating this README

Update the Flows table when adding, removing, or renaming a flow.
