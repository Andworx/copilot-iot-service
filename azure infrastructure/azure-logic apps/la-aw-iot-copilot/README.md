# la-aw-iot-copilot

> ⚠️ **DEPRECATED** — This Logic App has been superseded by a direct Event Hub trigger on the Azure Function App.
> See `azure infrastructure/azure-functions/iot-signalr-func/` for the current implementation.
> This folder is retained for reference and rollback purposes only.
> Issue: [#101](https://github.com/Andworx/copilot-iot-service/issues/101) · Closes: [#95](https://github.com/Andworx/copilot-iot-service/issues/95)

## Previous Purpose

This folder contained the source-controlled workflow definition for the `la-aw-iot-copilot` Logic App that polled Event Hubs and forwarded telemetry to the SignalR Function App.

## Why Deprecated

The Logic App polled the Event Hub every **5 seconds**, adding up to 5s of latency to every switch-state update. It was also deployed to the wrong resource group (`la-aw-com-iot-agent` instead of `rg-aw-azcom-iot-copilot`) and was disabled.

The replacement is a native Azure Functions Event Hub trigger that fires within milliseconds of the Pi sending a message — eliminating the poll cycle entirely.

## Files

| File | Purpose |
|------|---------|
| `workflow.json` | **Deprecated** Logic App Workflow Definition Language source |

## Updating This README

Update this file if the Logic App is formally removed from Azure or if the deprecation decision is reversed.
