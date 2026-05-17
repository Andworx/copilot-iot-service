# Raspberry Pi — Setup Guide

This guide covers two provisioning paths:

| Path | When to use |
|------|-------------|
| **[Zero-touch](#zero-touch-provisioning-recommended)** ⭐ | New blank Pi — runs `New-PiBootConfig.ps1` on dev machine, plug in and boot |
| **[Manual](#manual-provisioning-fallback)** | Re-provisioning existing Pi, dev/test, or troubleshooting |

After setup (either path), all config changes are made in Azure IoT Hub (Device Twin) and pushed to the Pi automatically — no SSH, no GitHub pulls needed.

---

## Prerequisites

### Hardware
- Raspberry Pi 3B+, 4, or Zero 2 W
- microSD card (8 GB+, Class 10)
- USB power supply (5V 3A for Pi 4; 5V 2.5A for Pi 3B+)
- Panel wiring (see [wiring/README.md](wiring/README.md))

### Azure / Accounts
- Azure IoT Hub provisioned (see [Issue #5](https://github.com/Andworx/copilot-iot-service/issues/5))
- Device `raspberry-pi-iotpanel` registered in IoT Hub (connection string ready)
- Device Twin `desired.logic_map` pushed (see [Step: Push Device Twin config](#push-device-twin-config))

---

## Zero-Touch Provisioning (Recommended)

Flash SD → write credentials with one script → plug in Pi → fully configured automatically.

```
Dev machine: flash SD → New-PiBootConfig.ps1 → eject
Pi: boot → firstrun.sh → downloads bootstrap → writes .env → installs service → reboots
Azure: Device Twin pushed → Pi picks up config on first connect
```

### ZT Step 1 — Flash Raspberry Pi OS

1. Download [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
2. Select **Raspberry Pi OS Lite (64-bit)**
3. Click the **⚙ gear icon** and set:

   | Setting | Value |
   |---------|-------|
   | Hostname | `iotpanel` |
   | Enable SSH | ✅ Password authentication |
   | Username | `pi` |
   | Password | *(strong password)* |
   | Wi-Fi SSID / Password | *(your network)* |
   | Wi-Fi Country | *(e.g. `US`)* |

4. Flash to SD card (do **not** eject yet)

### ZT Step 2 — Run `New-PiBootConfig.ps1`

On your Windows dev machine, find the drive letter of the SD boot partition (the small FAT32 partition — typically `E:` or `F:`):

```powershell
# Get your connection string from Azure CLI
$conn = az iot hub device-identity connection-string show `
    --hub-name <your-hub> `
    --device-id raspberry-pi-iotpanel `
    --query connectionString -o tsv

# Write zero-touch config to the SD boot partition
.\scripts\New-PiBootConfig.ps1 -DriveLetter E -ConnectionString $conn
```

**What this writes to the SD card:**
- `iot-credentials.env` — connection string (read once, then shredded by Pi)
- `firstrun.sh` — first-boot script that bootstraps everything
- `ssh` — empty file that enables SSH (if not already present)

### ZT Step 3 — Boot the Pi

1. Safely eject the SD card from Windows
2. Insert into the Raspberry Pi
3. Power on
4. Wait ~5 minutes (Pi downloads and installs everything on first boot)
5. Pi reboots automatically when done

### ZT Step 4 — Verify

```bash
# SSH in
ssh pi@iotpanel.local

# Check first-boot log
cat /var/log/iot-firstrun.log

# Check service
sudo systemctl status iot-monitor
sudo journalctl -u iot-monitor -f
```

Then [push Device Twin config](#push-device-twin-config) if not already done.

---

## Manual Provisioning (Fallback)

Use this path to re-provision an existing Pi, for dev/test machines, or when troubleshooting zero-touch issues.

### Step 1 — Flash Raspberry Pi OS

1. Download [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
2. Select **Raspberry Pi OS Lite (64-bit)** (no desktop needed)
3. Click the **⚙ gear icon** and configure:

   | Setting | Value |
   |---------|-------|
   | Hostname | `iotpanel` (or your choice) |
   | Enable SSH | ✅ Use password authentication |
   | Username | `pi` (or your choice) |
   | Password | *(strong password — stored securely)* |
   | Wi-Fi SSID | *(your network)* |
   | Wi-Fi Password | *(your network password)* |
   | Wi-Fi Country | *(your country code, e.g. `US`)* |

4. Flash to SD card
5. Insert SD card into Pi and power on

> **Tip:** For a wired connection, skip Wi-Fi config. The Pi gets an IP via DHCP on eth0.

---

### Step 2 — Find the Pi and SSH in

```bash
# Option A: check your router for the IP of hostname "iotpanel"
# Option B: scan the network
nmap -sn 192.168.1.0/24 | grep -A 1 "iotpanel"

# SSH in
ssh pi@iotpanel.local
# or
ssh pi@<ip-address>
```

---

### Step 3 — Run bootstrap.sh

Bootstrap installs all system dependencies, clones the repo, and installs the systemd service.

```bash
# On the Pi:
curl -sL https://raw.githubusercontent.com/Andworx/copilot-iot-service/main/bootstrap.sh | bash
```

> **What bootstrap.sh does:**
> - Updates system packages
> - Installs Python 3, pip, git
> - Clones the repo to `/opt/iot-monitor/`
> - Installs Python dependencies from `requirements.txt`
> - Creates the systemd service file
> - Adds the service user with GPIO group membership
> - Does **not** start the service — you must populate `.env` first

If the repo is private, clone manually:
```bash
git clone https://github.com/Andworx/copilot-iot-service /opt/iot-monitor
cd /opt/iot-monitor
bash install-auto-deploy.sh
```

---

### Step 4 — Populate the credentials file

The service reads the IoT Hub connection string from `/opt/iot-monitor/.env`.

```bash
# Copy the template
sudo cp /opt/iot-monitor/raspberry-pi/.env.template /opt/iot-monitor/.env

# Edit it — add your IoT Hub connection string
sudo nano /opt/iot-monitor/.env
```

The file should look like:
```
IOT_HUB_CONNECTION_STRING=HostName=<your-hub>.azure-devices.net;DeviceId=raspberry-pi-iotpanel;SharedAccessKey=<base64key>
```

**Where to get the connection string:**

```bash
# Azure CLI
az iot hub device-identity connection-string show \
  --hub-name <your-hub-name> \
  --device-id raspberry-pi-iotpanel \
  --query connectionString \
  --output tsv
```

Or in Azure Portal:
> IoT Hub → Devices → `raspberry-pi-iotpanel` → Primary Connection String (copy icon)

> **SECURITY**: `.env` is gitignored. Never paste it into chat, issues, or source files.

---

## Push Device Twin Config

This step applies to **both provisioning paths**. The Device Twin config must be pushed to Azure before (or shortly after) the Pi first connects.

### Option A — Azure Portal

1. Go to **IoT Hub → Devices → raspberry-pi-iotpanel → Device Twin**
2. In the `desired` block, add `logic_map`:

```json
{
  "desired": {
    "logic_map": {
      "version": 1,
      "description": "AgenticIoT demo panel config",
      "rules": [
        {
          "id": "all_lights_on",
          "switches": [1, 3],
          "leds": [0, 1, 2, 3],
          "description": "Switches 1 & 3 active: all LEDs ON (healthy state)"
        },
        {
          "id": "single_light",
          "switches": [2],
          "leds": [2],
          "description": "Switch 2 only: green LED"
        },
        {
          "id": "pattern_lights",
          "switches": [1, 2],
          "leds": [0, 2],
          "description": "Switches 1 & 2: blue + green LEDs"
        },
        {
          "id": "diagnostic_mode",
          "switches": [1, 2, 3],
          "leds": [1, 3],
          "description": "Switches 1, 2 & 3: orange + yellow LEDs"
        },
        {
          "id": "shutdown_sequence",
          "switches": [1, 2, 4],
          "leds": [],
          "description": "Switches 1, 2 & 4: all LEDs OFF"
        },
        {
          "id": "switch_4_only",
          "switches": [4],
          "leds": [3],
          "description": "Switch 4 only: yellow LED"
        }
      ],
      "fallback": {
        "leds": [0],
        "description": "Default (no rule matched): blue LED only"
      },
      "false_positives": {
        "enabled": false,
        "probability": 0.15,
        "description": "Simulate random hardware failures for Copilot agent demo"
      },
      "web_ui": {
        "enabled": true,
        "port": 8080,
        "host": "0.0.0.0"
      },
      "iot_hub": {
        "enabled": true,
        "connection_string_env": "IOT_HUB_CONNECTION_STRING",
        "device_id": "raspberry-pi-iotpanel"
      }
    }
  }
}
```

3. Click **Save**

### Option B — Azure CLI

```bash
# Set the Device Twin desired logic_map
az iot hub device-twin update \
  --hub-name <your-hub-name> \
  --device-id raspberry-pi-iotpanel \
  --desired '{
    "logic_map": {
      "version": 1,
      "rules": [...],
      "fallback": {"leds": [0]},
      "false_positives": {"enabled": false, "probability": 0.15},
      "web_ui": {"enabled": true, "port": 8080, "host": "0.0.0.0"},
      "iot_hub": {
        "enabled": true,
        "connection_string_env": "IOT_HUB_CONNECTION_STRING",
        "device_id": "raspberry-pi-iotpanel"
      }
    }
  }'
```

> **Note:** The twin config is pushed automatically to the Pi on startup and whenever it changes — no restart needed.

---

### Step 5 — Start the service

```bash
# Enable and start
sudo systemctl enable iot-monitor
sudo systemctl start iot-monitor

# Check status
sudo systemctl status iot-monitor
```

Expected output:
```
● iot-monitor.service - AgenticIoT IoT Monitor
     Loaded: loaded (/etc/systemd/system/iot-monitor.service; enabled)
     Active: active (running) since ...
```

---

## Verify (Both Paths)

### Check logs
```bash
journalctl -u iot-monitor -f
```

Look for these lines (in order):
```
Loaded environment from /opt/iot-monitor/.env
Connected to Azure IoT Hub
Config synced from Device Twin (version 1)
Reloading subsystems with Device Twin config…
Starting monitoring loop…
```

### Check local REST API
```bash
curl http://localhost:8080/api/health
# {"status": "ok", "simulation_mode": false}

curl http://localhost:8080/api/status
# {"switches": [...], "leds": [...], "active_rule": "...", ...}
```

### Monitor IoT Hub telemetry
```bash
# On your dev machine
az iot hub monitor-events \
  --hub-name <your-hub-name> \
  --device-id raspberry-pi-iotpanel
```

You should see telemetry within 30 seconds (heartbeat), or immediately when you press a switch.

---

## Step 8 — Push a config change (live test)

Update the twin to enable `false_positives`:

```bash
az iot hub device-twin update \
  --hub-name <your-hub-name> \
  --device-id raspberry-pi-iotpanel \
  --desired '{"logic_map": {"version": 2, "false_positives": {"enabled": true, "probability": 0.15}}}'
```

Within ~5 seconds the Pi log shows:
```
Device Twin patch received — updating config
Config written to /opt/iot-monitor/raspberry-pi/logic_map.json from Device Twin
Device Twin config update received — reloading…
```

No SSH, no restart.

---

## Troubleshooting

### Service fails to start
```bash
journalctl -u iot-monitor -n 50 --no-pager
```

| Symptom | Cause | Fix |
|---------|-------|-----|
| `.env not found` | `/opt/iot-monitor/.env` missing | Follow Step 4 |
| `IoT Hub connect failed` | Bad connection string | Re-check string from Azure Portal |
| `Permission denied: /dev/gpiomem` | Service user not in `gpio` group | `sudo usermod -aG gpio <service-user>` then reboot |
| `ModuleNotFoundError: RPi.GPIO` | Package not installed | `pip install RPi.GPIO` in the venv |
| Twin sync returns False | No `logic_map` in desired twin | Follow Step 5 to push config |

### Force config reload without restart
```bash
# Touch the config file — main loop detects mtime change
sudo touch /opt/iot-monitor/raspberry-pi/logic_map.json
```

### Reset service
```bash
sudo systemctl stop iot-monitor
sudo systemctl start iot-monitor
```

### Run manually (for debugging)
```bash
cd /opt/iot-monitor/raspberry-pi
source /opt/iot-monitor/.env  # or set manually
python3 main.py
```

---

## Updating the service after a code change

```bash
cd /opt/iot-monitor
git pull origin main
sudo systemctl restart iot-monitor
```

---

## Updating this README

Update this file when:
- The `.env` variable names change
- Bootstrap steps change
- New troubleshooting cases are found
- The Device Twin schema changes (bump version in examples)
