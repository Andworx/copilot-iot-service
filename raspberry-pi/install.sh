#!/bin/bash
# IoT Monitor installation script
# Sets up Python dependencies, log directories, and the systemd services.
# Run as root (sudo) from the raspberry-pi/ directory after cloning.
#
# Usage:
#   sudo ./install.sh

set -e

echo "Installing AgenticIoT IoT Monitor..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="/opt/iot-monitor"

# Detect the non-root user
if [ -n "$SUDO_USER" ]; then
    SERVICE_USER="$SUDO_USER"
elif [ -d "/home/adm" ]; then
    SERVICE_USER="adm"
elif [ -d "/home/pi" ]; then
    SERVICE_USER="pi"
else
    echo "ERROR: Cannot detect non-root user. Run as: sudo -u <user> ./install.sh"
    exit 1
fi

echo "Service user: $SERVICE_USER"

[ "$EUID" -ne 0 ] && { echo "ERROR: Run as root: sudo ./install.sh"; exit 1; }

# ─── Step 1: System packages ──────────────────────────────────────────────────
echo "Step 1: Installing system packages..."
if [ -f "$SCRIPT_DIR/system_packages.txt" ]; then
    apt-get update -qq
    apt-get install -y $(cat "$SCRIPT_DIR/system_packages.txt")
    echo "  System packages installed"
else
    echo "  WARNING: system_packages.txt not found, skipping"
fi

# ─── Step 2: Python dependencies ──────────────────────────────────────────────
echo "Step 2: Installing Python dependencies..."
if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
    command -v pip3 >/dev/null 2>&1 || apt-get install -y python3-pip python3-full
    pip3 install --break-system-packages -r "$SCRIPT_DIR/requirements.txt"
    echo "  Python dependencies installed"
else
    echo "  WARNING: requirements.txt not found, skipping"
fi

# ─── Step 3: Directories ──────────────────────────────────────────────────────
echo "Step 3: Setting up directories..."
mkdir -p "$PROJECT_DIR"
mkdir -p /var/log/iot-monitor
chown -R "$SERVICE_USER:$SERVICE_USER" "$PROJECT_DIR"
chown -R "$SERVICE_USER:$SERVICE_USER" /var/log/iot-monitor
echo "  Directories created"

# ─── Step 4: Auto-deploy service ──────────────────────────────────────────────
echo "Step 4: Installing auto-deploy service..."
cp "$SCRIPT_DIR/autodeploy.sh" /usr/local/bin/auto-deploy.sh
chmod +x /usr/local/bin/auto-deploy.sh

cp "$SCRIPT_DIR/iot-auto-deploy.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable iot-auto-deploy.service
echo "  Auto-deploy service installed and enabled"

# ─── Step 5: IoT Monitor service ──────────────────────────────────────────────
echo "Step 5: Creating iot-monitor service..."
cat > /etc/systemd/system/iot-monitor.service << EOF
[Unit]
Description=AgenticIoT Digital Logic Panel Monitor
Documentation=https://github.com/Andworx/copilot-iot-service
After=network.target iot-auto-deploy.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=/opt/iot-monitor/raspberry-pi
EnvironmentFile=/opt/iot-monitor/.env
ExecStart=/usr/bin/python3 /opt/iot-monitor/raspberry-pi/main.py
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable iot-monitor.service
echo "  IoT Monitor service created and enabled"

echo ""
echo "═══════════════════════════════════════════════════"
echo " IoT Monitor installation complete!"
echo "═══════════════════════════════════════════════════"
echo ""
echo " Services installed:"
echo "   iot-auto-deploy.service  — pulls latest code on boot"
echo "   iot-monitor.service      — runs the GPIO application"
echo ""
echo " Next steps:"
echo "   1. Fill in /opt/iot-monitor/.env with your IoT Hub"
echo "      connection string (auto-deploy creates the file"
echo "      from .env.template on first run)."
echo "   2. Reboot:  sudo reboot"
echo "   3. Status:  sudo systemctl status iot-monitor"
echo "   4. Logs:    sudo journalctl -u iot-monitor -f"
echo ""
