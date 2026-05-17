#!/bin/bash
# AgenticIoT — Unattended Bootstrap
# Non-interactive installer for zero-touch Pi provisioning.
# Triggered by firstrun.sh on first boot — do NOT run manually.
#
# Reads IOT_HUB_CONNECTION_STRING from the environment (set by firstrun.sh).
# Uses HTTPS clone (no SSH key / GitHub account needed on the Pi).
#
# Usage (called automatically by firstrun.sh):
#   IOT_HUB_CONNECTION_STRING="HostName=..." bash bootstrap-unattended.sh

set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ─── Validate ─────────────────────────────────────────────────────────────────
if [ -z "$IOT_HUB_CONNECTION_STRING" ]; then
    log_error "IOT_HUB_CONNECTION_STRING is not set — cannot configure service"
    exit 1
fi

log_info "AgenticIoT — Unattended Bootstrap"
log_info "=================================="

REPO_URL="https://github.com/Andworx/copilot-iot-service.git"
PROJECT_DIR="/opt/iot-monitor"
ENV_FILE="$PROJECT_DIR/.env"

# Detect non-root user
if [ -n "$SUDO_USER" ]; then
    SERVICE_USER="$SUDO_USER"
elif [ -d "/home/pi" ]; then
    SERVICE_USER="pi"
else
    # Fall back to first non-root user with a home dir
    SERVICE_USER=$(getent passwd | awk -F: '$3 >= 1000 && $6 ~ /^\/home/ {print $1; exit}')
fi

if [ -z "$SERVICE_USER" ]; then
    log_error "Cannot detect service user — aborting"
    exit 1
fi

log_info "Service user: $SERVICE_USER"
[ "$EUID" -ne 0 ] && { log_error "Run as root (sudo)"; exit 1; }

# ─── Step 0: System packages ──────────────────────────────────────────────────
log_info "Step 0: Updating system packages..."
apt-get update -qq
apt-get install -y git curl python3 python3-pip python3-full openssh-server 2>&1 | tail -5
log_info "  System packages ready"

# ─── Step 1: Clone repository (HTTPS — no key needed for public repo) ─────────
log_info "Step 1: Cloning repository..."
[ -d "$PROJECT_DIR" ] && rm -rf "$PROJECT_DIR"

mkdir -p "$PROJECT_DIR"
chown "$SERVICE_USER:$SERVICE_USER" "$PROJECT_DIR"

sudo -u "$SERVICE_USER" git clone --depth 1 \
    --filter=blob:none \
    --sparse \
    "$REPO_URL" "$PROJECT_DIR"

sudo -u "$SERVICE_USER" git -C "$PROJECT_DIR" sparse-checkout set raspberry-pi
log_info "  Repository cloned (sparse: raspberry-pi/)"

# ─── Step 2: Write credentials ────────────────────────────────────────────────
log_info "Step 2: Writing IoT Hub credentials..."
mkdir -p "$(dirname "$ENV_FILE")"

cat > "$ENV_FILE" << EOF
# AgenticIoT IoT Hub credentials — written by unattended bootstrap
# Do not commit this file. It is gitignored.
IOT_HUB_CONNECTION_STRING=$IOT_HUB_CONNECTION_STRING
DEVICE_ID=raspberry-pi-iotpanel
EOF

chmod 600 "$ENV_FILE"
chown "$SERVICE_USER:$SERVICE_USER" "$ENV_FILE"
log_info "  Credentials written to $ENV_FILE"

# ─── Step 3: Run installer ────────────────────────────────────────────────────
log_info "Step 3: Running installer..."
chmod +x "$PROJECT_DIR/raspberry-pi/"*.sh 2>/dev/null || true
bash "$PROJECT_DIR/raspberry-pi/install.sh"
log_info "  Installer complete"

# ─── Step 4: Enable and start service ─────────────────────────────────────────
log_info "Step 4: Enabling iot-monitor service..."
systemctl daemon-reload
systemctl enable iot-monitor.service
systemctl start iot-monitor.service || log_warn "Service start deferred (will start after reboot)"
log_info "  Service enabled"

# ─── Done ─────────────────────────────────────────────────────────────────────
log_info ""
log_info "Bootstrap complete! The Pi is fully provisioned."
log_info ""
log_info "  Device will:"
log_info "    1. Start iot-monitor on next boot"
log_info "    2. Connect to IoT Hub and fetch Device Twin config"
log_info "    3. Begin GPIO monitoring"
log_info ""
log_info "  Verify after reboot:"
log_info "    sudo systemctl status iot-monitor"
log_info "    sudo journalctl -u iot-monitor -f"
log_info ""
