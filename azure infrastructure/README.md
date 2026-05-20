# Azure Infrastructure

## Purpose

This directory contains the source-controlled Azure middleware assets for AgenticIoT: the SignalR-backed Function App, the Logic App workflow definition, and the documentation that explains how the Azure middleware is provisioned.

## Structure

```
azure infrastructure/
├── azure-functions/
│   ├── README.md
│   └── iot-signalr-func/
│       ├── src/
│       ├── host.json
│       ├── local.settings.json.template
│       └── package.json
└── azure-logic apps/
    ├── README.md
    └── la-aw-iot-copilot/
        ├── README.md
        └── workflow.json
```

## Usage

Provision and redeploy the Azure middleware from the repo root:

```powershell
.\scripts\New-AzureMiddleware.ps1 -Environment dev
```

The deployment script reads:
- `azure infrastructure/azure-functions/iot-signalr-func/` for the Function App package
- `azure infrastructure/azure-logic apps/la-aw-iot-copilot/workflow.json` for the Logic App workflow definition

## Updating This README

Update this file when the Azure infrastructure layout changes, when a new Azure middleware component is added, or when the deployment flow changes.