#!/bin/bash
# AgenticIoT IoT Monitor — Bootstrap Script
#
# Solves the chicken-and-egg problem: sets up SSH auth to GitHub so the Pi
# can clone the private repository, then runs the full installer.
#
# Run this ONCE on a fresh Raspberry Pi OS image:
#   curl -sSL https://raw.githubusercontent.com/Andworx/copilot-iot-service/main/bootstrap.sh | sudo bash
# Or copy the file to the Pi and run:
#   sudo bash bootstrap.sh
#
# SECURITY: This script does NOT contain any secrets. IoT Hub credentials are
# configured separately in /opt/iot-monitor/.env after installation.

set -e

echo "AgenticIoT IoT Monitor — Bootstrap"
echo "===================================="

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ─── Configuration ────────────────────────────────────────────────────────────
REPO_URL="git@github.com:Andworx/copilot-iot-service.git"
PROJECT_DIR="/opt/iot-monitor"

# Detect non-root user
if [ -n "$SUDO_USER" ]; then
    SERVICE_USER="$SUDO_USER"
elif [ -d "/home/adm" ]; then
    SERVICE_USER="adm"
elif [ -d "/home/pi" ]; then
    SERVICE_USER="pi"
else
    log_error "Cannot detect non-root user. Run via sudo."
    exit 1
fi

log_info "Detected user: $SERVICE_USER"
[ "$EUID" -ne 0 ] && { log_error "Run as root: sudo bash bootstrap.sh"; exit 1; }

# ─── Step 0: Dependencies ─────────────────────────────────────────────────────
log_info "Step 0: Installing git and ssh dependencies..."
apt-get update -qq
apt-get install -y git openssh-client curl
log_info "  git $(git --version) installed"

# ─── Step 1: Generate SSH key ─────────────────────────────────────────────────
log_info "Step 1: Generating SSH key for GitHub..."
SSH_KEY_PATH="/home/$SERVICE_USER/.ssh/id_ed25519_github"

if [ ! -f "$SSH_KEY_PATH" ]; then
    sudo -u "$SERVICE_USER" mkdir -p "/home/$SERVICE_USER/.ssh"
    sudo -u "$SERVICE_USER" ssh-keygen -t ed25519 -C "$SERVICE_USER@iot-monitor" \
        -f "$SSH_KEY_PATH" -N ""
    sudo -u "$SERVICE_USER" chmod 600 "$SSH_KEY_PATH"
    sudo -u "$SERVICE_USER" chmod 644 "$SSH_KEY_PATH.pub"
    log_info "  SSH key generated"
else
    log_info "  SSH key already exists — reusing"
fi

# ─── Step 2: Configure SSH ────────────────────────────────────────────────────
log_info "Step 2: Configuring SSH for GitHub..."
sudo -u "$SERVICE_USER" tee "/home/$SERVICE_USER/.ssh/config" > /dev/null << 'EOF'
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github
    IdentitiesOnly yes
EOF
sudo -u "$SERVICE_USER" chmod 600 "/home/$SERVICE_USER/.ssh/config"

# ─── Step 3: Add key to GitHub ────────────────────────────────────────────────
echo ""
echo "ADD THIS KEY TO GITHUB:"
echo "══════════════════════════════════════════════════════════════════════════"
sudo -u "$SERVICE_USER" cat "$SSH_KEY_PATH.pub"
echo "══════════════════════════════════════════════════════════════════════════"
echo ""
echo "  1. Go to: https://github.com/settings/ssh/new"
echo "  2. Title: IoT Monitor Pi"
echo "  3. Key type: Authentication Key"
echo "  4. Paste the key above"
echo "  5. Click 'Add SSH key'"
echo ""
read -rp "⏸  Press Enter after adding the key to GitHub..."

# ─── Step 4: Test GitHub connection ───────────────────────────────────────────
log_info "Step 4: Testing GitHub SSH connection..."
for i in {1..3}; do
    if sudo -u "$SERVICE_USER" \
        ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -T git@github.com 2>&1 \
        | grep -q "successfully authenticated"; then
        log_info "  GitHub SSH connection successful"
        break
    else
        [ $i -eq 3 ] && {
            log_error "GitHub SSH connection failed after 3 attempts."
            echo "  Verify the key was added correctly, then retry:"
            echo "    sudo -u $SERVICE_USER ssh -T git@github.com"
            exit 1
        }
        log_warn "  Attempt $i failed — retrying in 5s..."
        sleep 5
    fi
done

# ─── Step 5: Clone repository ─────────────────────────────────────────────────
log_info "Step 5: Cloning repository (sparse: raspberry-pi/ only)..."
[ -d "$PROJECT_DIR" ] && { log_warn "  Removing existing $PROJECT_DIR..."; rm -rf "$PROJECT_DIR"; }

mkdir -p "$PROJECT_DIR"
chown "$SERVICE_USER:$SERVICE_USER" "$PROJECT_DIR"

sudo -u "$SERVICE_USER" git -C "$PROJECT_DIR" init
sudo -u "$SERVICE_USER" git -C "$PROJECT_DIR" remote add origin "$REPO_URL"
sudo -u "$SERVICE_USER" git -C "$PROJECT_DIR" sparse-checkout init --cone
sudo -u "$SERVICE_USER" git -C "$PROJECT_DIR" sparse-checkout set raspberry-pi
sudo -u "$SERVICE_USER" git -C "$PROJECT_DIR" fetch origin main
sudo -u "$SERVICE_USER" git -C "$PROJECT_DIR" checkout main
log_info "  Repository cloned"

# ─── Step 6: Run installer ────────────────────────────────────────────────────
log_info "Step 6: Running installer..."
chmod +x "$PROJECT_DIR/raspberry-pi/"*.sh "$PROJECT_DIR/raspberry-pi/"*.py 2>/dev/null || true
bash "$PROJECT_DIR/raspberry-pi/install.sh"

echo ""
log_info "Bootstrap complete!"
echo ""
echo "  Next steps:"
echo "  1. Fill in your IoT Hub connection string:"
echo "       sudo nano /opt/iot-monitor/.env"
echo "  2. Reboot:  sudo reboot"
echo "  3. Status:  sudo systemctl status iot-monitor"
echo "  4. Logs:    sudo journalctl -u iot-monitor -f"
echo ""
