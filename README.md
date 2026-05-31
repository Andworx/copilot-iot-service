# AgenticIoT — Copilot IoT Service

![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)

An end-to-end IoT demonstration connecting physical hardware to Microsoft Power Platform, Azure cloud services, and Copilot Studio AI agents. A Raspberry Pi reads physical GPIO switches, sends telemetry to Azure, and the data surfaces in a real-time Power Pages portal with an AI troubleshooting agent.

---

## 🏗️ Architecture

> 📐 **Interactive diagram:** Open [`architecture.drawio`](./architecture.drawio) on GitHub for a pannable, zoomable version — rendered natively in the browser, no plugin needed.

```mermaid
flowchart TD
    Pi["🍓 Raspberry Pi\n(GPIO switches + LEDs)"]
    Hub["☁️ Azure IoT Hub"]
    EH["📨 Azure Event Hub"]
    Func["⚡ Azure Function App\n(Node.js)"]
    SR["🔁 Azure SignalR Service\n(Serverless)"]
    Browser["🌐 Power Pages Portal\n(Live dashboard)"]
    DV["🗄️ Dataverse"]
    Agent["🤖 Copilot Studio Agent\n(Troubleshooting)"]

    Pi -- "MQTT / TLS" --> Hub
    Hub -- "Device routing" --> EH
    EH -- "Event Hub trigger" --> Func
    Func -- "WebSocket broadcast" --> SR
    SR -- "Real-time update" --> Browser
    Func -- "Write telemetry" --> DV
    DV -- "Query live state" --> Agent
    Agent -- "Embedded in portal" --> Browser
```

**Data flow:** Physical switch toggle → IoT Hub → Event Hub → Azure Function → SignalR → live dashboard update in ~10 seconds.

---

## 🧩 Components

| Layer | Technology | Purpose |
|-------|-----------|----------|
| **Hardware** | Raspberry Pi + GPIO | 4 toggle switches, 4 LEDs, configurable logic map |
| **Device connectivity** | Azure IoT Hub (Standard S1) | MQTT device-to-cloud messaging |
| **Message buffer** | Azure Event Hub | Decouples IoT Hub from the processing pipeline |
| **Real-time backend** | Azure Function App (Node.js 24) | Receives Event Hub messages, broadcasts via SignalR |
| **Real-time transport** | Azure SignalR Service (Serverless) | WebSocket push to browser |
| **Data store** | Dataverse | IoT devices, telemetry events, panel state tables |
| **Portal** | Power Pages | Live dashboard + historical event log |
| **AI agent** | Copilot Studio | Panel Troubleshooting Agent — queries live state, walks through diagnostics |

---
