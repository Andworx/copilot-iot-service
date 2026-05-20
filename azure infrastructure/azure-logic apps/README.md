# Azure Logic Apps

## Purpose

This directory stores source-controlled Logic App workflow definitions used by the AgenticIoT Azure middleware.

## Structure

```
azure-logic apps/
└── la-aw-iot-copilot/
    ├── README.md
    └── workflow.json
```

## Workflow Source

`la-aw-iot-copilot/workflow.json` contains the Workflow Definition Language payload for the Event Hubs trigger and HTTP handoff to the Function App. `scripts/New-AzureMiddleware.ps1` replaces deploy-time placeholders before wrapping the workflow in the ARM template used for provisioning.

## Updating This README

Update this file when a Logic App workflow is added, removed, renamed, or its deployment pattern changes.