#!/bin/bash
# Install Auto-Deploy System for AgenticIoT IoT Monitor
#
# Run this script ONCE from the repo root after cloning, to set up the
# systemd service that pulls latest code from GitHub on every boot.
#
# Usage:
#   chmod +x install-auto-deploy.sh
#   sudo ./install-auto-deploy.sh
#
# SECURITY: No secrets are stored here. IoT Hub credentials go in
# /opt/iot-monitor/.env (gitignored, created from .env.template on first boot).

set -e

PROJECT_ROOT="/opt/iot-monitor"
CURRENT_USER="${SUDO_USER:-$USER}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[INFO]${NC}    $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC}   $1"; }

log_info "Installing AgenticIoT Auto-Deploy System"

[ "$EUID" -ne 0 ] && { log_error "Run as root (sudo $0)"; exit 1; }

# Normalise user
if [ -z "$CURRENT_USER" ] || [ "$CURRENT_USER" = "root" ]; then
    if [ -d "/home/adm" ]; then CURRENT_USER="adm"
    elif [ -d "/home/pi" ]; then CURRENT_USER="pi"
    else log_error "Could not detect user. Run: sudo -u <user> $0"; exit 1; fi
fi

log_info "User: $CURRENT_USER  |  Project root: $PROJECT_ROOT"

[ ! -f "raspberry-pi/autodeploy.sh" ] && {
    log_error "raspberry-pi/autodeploy.sh not found. Run from the repo root."
    exit 1
}

# ─── Step 1: Install auto-deploy script ───────────────────────────────────────
log_info "Installing auto-deploy script to /usr/local/bin/..."
cp raspberry-pi/autodeploy.sh /usr/local/bin/auto-deploy.sh
chmod +x /usr/local/bin/auto-deploy.sh
chown root:root /usr/local/bin/auto-deploy.sh
log_success "auto-deploy.sh installed"

# ─── Step 2: Install systemd service ──────────────────────────────────────────
log_info "Installing systemd service..."
[ ! -f "raspberry-pi/iot-auto-deploy.service" ] && {
    log_error "raspberry-pi/iot-auto-deploy.service not found."
    exit 1
}
cp raspberry-pi/iot-auto-deploy.service /etc/systemd/system/
log_success "Service unit installed"

# ─── Step 3: Enable service ───────────────────────────────────────────────────
log_info "Enabling iot-auto-deploy.service..."
systemctl daemon-reload
systemctl enable iot-auto-deploy.service
log_success "Service enabled (runs on every boot)"

# ─── Step 4: Logging ──────────────────────────────────────────────────────────
log_info "Setting up log directory..."
mkdir -p /var/log/iot-monitor
chown "$CURRENT_USER:$CURRENT_USER" /var/log/iot-monitor
log_success "Log directory: /var/log/iot-monitor/"

# ─── Step 5: Project directory ownership ──────────────────────────────────────
log_info "Configuring project directory..."
[ ! -d "$PROJECT_ROOT" ] && mkdir -p "$PROJECT_ROOT"
chown -R "$CURRENT_USER:$CURRENT_USER" "$PROJECT_ROOT"
log_success "Project directory ready: $PROJECT_ROOT"

# ─── Done ─────────────────────────────────────────────────────────────────────
echo ""
log_success "Auto-Deploy System installation complete!"
echo ""
echo "  Management:"
echo "    Manual run:   sudo /usr/local/bin/auto-deploy.sh"
echo "    Service run:  sudo systemctl start iot-auto-deploy.service"
echo "    Status:       sudo systemctl status iot-auto-deploy.service"
echo "    Logs:         sudo journalctl -u iot-auto-deploy.service -f"
echo "    Log file:     /var/log/iot-monitor/autodeploy.log"
echo ""
echo "  The Pi will now auto-update from GitHub on every boot."
echo ""
