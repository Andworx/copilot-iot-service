# AgenticIoT — Copilot IoT Service

![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)

An end-to-end IoT demonstration connecting physical hardware to Microsoft Power Platform, Azure cloud services, and Copilot Studio AI agents. A Raspberry Pi reads physical GPIO switches, sends telemetry to Azure, and the data surfaces in a real-time Power Pages portal with an AI troubleshooting agent.

---

## 🏗️ Architecture

```
Raspberry Pi (GPIO)
      │  MQTT / TLS
      ▼
Azure IoT Hub
      │  Device routing
      ▼
Azure Event Hub
      │  5-second poll
      ▼
Azure Logic App
      │  HTTP POST
      ▼
Azure Function App  ──── Azure SignalR Service ──── Browser (Power Pages)
      │                                                      │
      └─── Power Automate Flow ──── Dataverse ──── Copilot Studio Agent
```

**Data flow:** Physical switch toggle → IoT Hub → Event Hub → Logic App → Azure Function → SignalR → live dashboard update in ~10 seconds.

---

## 🧩 Components

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Hardware** | Raspberry Pi + GPIO | 4 toggle switches, 4 LEDs, configurable logic map |
| **Device connectivity** | Azure IoT Hub (Standard S1) | MQTT device-to-cloud messaging |
| **Message buffer** | Azure Event Hub | Decouples IoT Hub from the processing pipeline |
| **Message forwarder** | Azure Logic App | Polls Event Hub every 5 s, POSTs to Function |
| **Real-time backend** | Azure Function App (Node.js 24) | SignalR broadcaster + telemetry endpoint |
| **Real-time transport** | Azure SignalR Service (Serverless) | WebSocket push to browser |
| **Data store** | Dataverse | IoT devices, telemetry events, panel state tables |
| **Automation** | Power Automate | Ingests telemetry from Azure into Dataverse |
| **Portal** | Power Pages | Live dashboard + historical event log |
| **AI agent** | Copilot Studio | Panel Troubleshooting Agent — queries live state, walks through diagnostics |

---

## 📁 Repository Layout

```
copilot-iot-service/
├── raspberry-pi/               # Pi GPIO service, IoT client, auto-deploy scripts
├── azure infrastructure/       # Azure middleware source and deployment documentation
│   ├── azure-functions/        # Node.js Azure Function (SignalR broadcaster)
│   └── azure-logic apps/       # Logic App workflow definitions
├── tables/                     # Dataverse table definitions (JSON)
├── flows/                      # Power Automate flow definitions
├── power pages/                # Power Pages portal (PAC CLI v2 format)
├── copilot agents/             # Copilot Studio agent YAML files
├── scripts/                    # PowerShell deployment and export scripts
├── automations/                # Email templates and other non-flow automation assets
├── plugins/                    # Dataverse plugin projects (.NET)
├── reports/                    # Power BI PBIP report templates
├── tests/e2e/                  # Playwright end-to-end tests
├── .github/instructions/       # Copilot coding agent instructions per technology area
├── .claude/commands/           # Claude Code slash commands (/deploy, /export, etc.)
├── PAC_COMMANDS.md             # PAC CLI quick reference
└── CONTRIBUTING.md             # Branch strategy, commit conventions, PR workflow
```

---

## 🔧 Hardware

**Raspberry Pi GPIO assignments:**

| Component | GPIO Pin |
|-----------|----------|
| Switch 1 | GPIO 5 |
| Switch 2 | GPIO 6 |
| Switch 3 | GPIO 13 |
| Switch 4 | GPIO 19 |
| LED 1 (Blue) | GPIO 18 |
| LED 2 (Orange) | GPIO 24 |
| LED 3 (Green) | GPIO 25 |
| LED 4 (Yellow) | GPIO 12 |

Switch states are polled only when a switch chages postion. On any change, a telemetry message is published to Azure IoT Hub. LED behaviour is governed by `raspberry-pi/logic_map.json` — modify rules in the repo and the Pi pulls the update automatically on next boot.

---

## 🚀 Getting Started

### Prerequisites

- Raspberry Pi (any model with GPIO) running Raspberry Pi OS
- Azure subscription (IoT Hub, Event Hub, Logic App, Function App, SignalR)
- Power Platform environment (Dataverse, Power Pages, Copilot Studio)
- PowerShell 7+, [PAC CLI](https://learn.microsoft.com/power-platform/developer/cli/introduction), Node.js 18+, [GitHub CLI](https://cli.github.com)

### 1 — Configure project tokens

```powershell
cp project.tokens.example.json project.tokens.json
# Fill in your org URL, tenant ID, client ID, etc.
.\scripts\Apply-ProjectTokens.ps1 -Environment dev
```

### 2 — Set up the Raspberry Pi

```bash
# On a fresh Raspberry Pi:
curl -sSL https://raw.githubusercontent.com/Andworx/copilot-iot-service/main/raspberry-pi/bootstrap.sh | sudo bash
```

The bootstrap script installs dependencies, sets up SSH auth to GitHub, clones the repo, and configures a systemd service that auto-pulls updates on every boot.

### 3 — Deploy Azure infrastructure

Provision in order:
1. Azure IoT Hub → register device `raspberry-pi-iotpanel`
2. Azure Event Hub → namespace + hub `andworxiotagenteventhub`
3. Azure SignalR Service → Serverless mode
4. Azure Function App → deploy from `azure infrastructure/azure-functions/iot-signalr-func/`
5. Azure Logic App → Event Hub trigger → HTTP POST to Function

See `azure infrastructure/README.md` for detailed Azure middleware configuration and source layout.

### 4 — Deploy Power Platform components

```powershell
# Deploy Dataverse tables
.\scripts\Deploy-Project.ps1 -Environment dev -Job Tables

# Upload Power Pages portal
pac pages upload --path "power pages\<portal-slug>" --modelVersion 2

# Push Copilot Studio agent
pac copilot push --bot <agent-name> --environment <env-url>
```

---

## 📊 Message Flow Detail

1. **Raspberry Pi** detects a switch state change
2. **IoT Hub** receives the MQTT message from device `raspberry-pi-iotpanel`
3. **Event Hub** (`andworxiotagenteventhub`) receives the message via IoT Hub route `routeforiotpanel`
4. **Logic App** polls Event Hub every 5 s using `$Default` consumer group
5. **Azure Function** (`/api/telemetry`) receives the HTTP POST and broadcasts via SignalR
6. **Power Pages browser** receives the WebSocket update and re-renders the dashboard
7. **Power Automate flow** (in parallel) writes the event to Dataverse for history and agent queries

**Typical end-to-end latency:** 5–10 seconds.

---

## 🤖 Copilot Studio Agent

The **IoT Panel Troubleshooting Agent** is embedded in the Power Pages portal and can:

- Report the current live switch and LED states (from Dataverse)
- Explain why a specific LED is or isn't on (logic map interpretation)
- Walk users through hardware and cloud connectivity diagnostics
- Escalate to a human engineer when it can't resolve an issue

Agent YAML files are in `copilot agents/`. Use `pac copilot push/pull` to sync with the Copilot Studio environment.

---

## 🔒 Security

This repository has been audited before public release:

- ✅ Full git history secrets scan — zero findings
- ✅ `.gitignore` hardened for certificates, credentials, and secrets
- ✅ Documentation audited — no embedded credentials or internal URLs
- ✅ GitHub Actions workflows audited for injection and token risks
- ✅ Dependabot enabled for automated dependency updates
- ✅ `SECURITY.md` and `LICENSE` present

**To report a vulnerability:** see [SECURITY.md](SECURITY.md).

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for branch naming conventions, commit format, and the PR workflow.

- Branch strategy: `feat/`, `fix/`, `chore/`, `docs/`, `refactor/`
- Commits: [Conventional Commits](https://www.conventionalcommits.org/) — `feat(scope): description`
- PRs: squash-merge to `main`; link to issue with `Fixes #N`
