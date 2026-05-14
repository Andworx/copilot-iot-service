# Raspberry Pi — AgenticIoT IoT Monitor

## Purpose

This directory contains the Python service and deployment tooling that runs on a Raspberry Pi to monitor a physical IoT panel. The service reads GPIO switch states and controls LEDs, then streams telemetry to Azure IoT Hub over MQTT/TLS.

From Azure IoT Hub the data flows through Event Hub → Logic App → Azure Function → Azure SignalR Service → Power Pages browser dashboard, with Dataverse persistence via Power Automate.

## Structure

```
raspberry-pi/
├── .env.template          # Template for IoT Hub connection string (safe to commit)
├── requirements.txt       # Python package dependencies
├── system_packages.txt    # System package list for apt-get
├── autodeploy.sh          # Boot-time update script (runs via systemd)
├── iot-auto-deploy.service # systemd unit for auto-deploy oneshot
├── install.sh             # One-time installer for all services
├── setup_ssh.sh           # SSH key setup for GitHub auth (run once manually)
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

Copy `.env.template` to `/opt/iot-monitor/.env` and fill in `IOTHUB_DEVICE_CONNECTION_STRING`:

```
IOTHUB_DEVICE_CONNECTION_STRING=HostName=<hub>.azure-devices.net;DeviceId=raspberry-pi-iotpanel;SharedAccessKey=<key>
```

> **SECURITY**: Never commit `.env`. It is gitignored. Credentials are injected at runtime via systemd `EnvironmentFile`.

### Service Management

```bash
# IoT Monitor service (the Python GPIO → IoT Hub service)
sudo systemctl status iot-monitor
sudo systemctl start  iot-monitor
sudo systemctl stop   iot-monitor
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
