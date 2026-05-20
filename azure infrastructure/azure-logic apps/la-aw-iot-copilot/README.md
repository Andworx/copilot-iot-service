# la-aw-iot-copilot

## Purpose

This folder contains the source-controlled workflow definition for the `la-aw-iot-copilot` Logic App that polls Event Hubs and forwards telemetry to the SignalR Function App.

## Files

| File | Purpose |
|------|---------|
| `workflow.json` | Logic App Workflow Definition Language source used by `scripts/New-AzureMiddleware.ps1` |

## Trigger Notes

The workflow uses the Event Hubs managed connector trigger with the `events/head` path and splits the trigger batch on `@triggerBody()?['Body']` so each event is forwarded to the telemetry endpoint individually.

## Updating This README

Update this file when the trigger contract, downstream action contract, or deploy-time placeholders change.