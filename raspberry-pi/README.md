# Raspberry Pi — AgenticIoT IoT Monitor

## Purpose

This directory contains the Python service and deployment tooling that runs on a Raspberry Pi to monitor a physical IoT panel. The service reads GPIO switch states and controls LEDs, then streams telemetry to Azure IoT Hub over MQTT/TLS.

From Azure IoT Hub the data flows through Event Hub → Logic App → Azure Function → Azure SignalR Service → Power Pages browser dashboard, with Dataverse persistence via Power Automate.

## Structure

```
raspberry-pi/
├── main.py                # Entry point — monitoring loop, orchestrates all modules
├── panel_controller.py    # GPIO reads (switches) and writes (LEDs); logic rule engine
├── iot_client.py          # Azure IoT Hub client (MQTT/TLS telemetry)
├── api_server.py          # Local Flask REST API (/api/status, /api/health)
├── logic_map.json         # Switch-to-LED rules and feature flags (web_ui, iot_hub)
├── .env.template          # Template for IoT Hub connection string (safe to commit)
├── requirements.txt       # Python package dependencies
├── system_packages.txt    # System package list for apt-get
├── autodeploy.sh          # Boot-time update script (runs via systemd)
├── iot-auto-deploy.service # systemd unit for auto-deploy oneshot
├── install.sh             # One-time installer for all services
├── setup_ssh.sh           # SSH key setup for GitHub auth (run once manually)
├── docs/
│   └── wiring/
│       └── README.md      # GPIO pin map, resistor values, logic map reference
└── README.md              # This file
```

Root-level helpers:

| File | Purpose |
|------|---------|
| `bootstrap.sh` | End-to-end setup for a fresh Pi (SSH keygen + clone + install) |
| `install-auto-deploy.sh` | Installs only the auto-deploy systemd service |

## Usage / Workflow

### Fresh Pi Setup

Run this on a fresh Raspberry Pi OS installation:

```bash
curl -sSL https://raw.githubusercontent.com/Andworx/copilot-iot-service/main/bootstrap.sh | sudo bash
```

This will:

1. Install `git` and `openssh-client`
2. Generate an SSH key pair and prompt you to add the public key to GitHub
3. Clone the repository (sparse — `raspberry-pi/` directory only)
4. Run `raspberry-pi/install.sh` to install Python deps and register systemd services
5. Prompt you to add your IoT Hub connection string to `/opt/iot-monitor/.env`

### Manual Installation

If the repo is already cloned:

```bash
# Install Python packages and systemd services
sudo bash raspberry-pi/install.sh

# Set up IoT Hub credentials
sudo cp raspberry-pi/.env.template /opt/iot-monitor/.env
sudo nano /opt/iot-monitor/.env   # Add your connection string

# Reboot to activate auto-deploy service
sudo reboot
```

### Credentials

Copy `.env.template` to `/opt/iot-monitor/.env` and fill in `IOT_HUB_CONNECTION_STRING`:

```
IOT_HUB_CONNECTION_STRING=HostName=<hub>.azure-devices.net;DeviceId=raspberry-pi-iotpanel;SharedAccessKey=<key>
```

> **SECURITY**: Never commit `.env`. It is gitignored. Credentials are injected at runtime via systemd `EnvironmentFile`.

### Configuration (`logic_map.json`)

`logic_map.json` controls behaviour without code changes:

| Section | Key | Effect |
|---------|-----|--------|
| `web_ui` | `enabled: true/false` | Start/stop the local Flask REST API |
| `web_ui` | `port` | Port for `/api/status` and `/api/health` |
| `iot_hub` | `enabled: true/false` | Enable/disable Azure IoT Hub telemetry |
| `iot_hub` | `device_id` | IoT Hub device name (default `raspberry-pi-iotpanel`) |
| `false_positives` | `enabled: true/false` | Inject random LED failures for Copilot agent demos |
| `rules` | array | Switch combination → LED output mapping |

The main loop hot-reloads `logic_map.json` every 20 seconds — no restart needed.

### Service Management

```bash
# IoT Monitor service (the Python GPIO → IoT Hub service)
sudo systemctl status iot-monitor
sudo systemctl start   iot-monitor
sudo systemctl stop    iot-monitor
sudo systemctl restart iot-monitor
sudo journalctl -u iot-monitor -f

# Auto-Deploy service (runs once at boot to pull latest code)
sudo systemctl status iot-auto-deploy
sudo journalctl -u iot-auto-deploy -f
cat /var/log/iot-monitor/autodeploy.log
```

## Updating the README

Update this README when:

- New Python files are added to the `raspberry-pi/` directory
- New environment variables are added to `.env.template`
- The systemd service configuration changes
- GPIO pin assignments change (update the pin map in the root `README.md` too)
- System package requirements change (`system_packages.txt`)
