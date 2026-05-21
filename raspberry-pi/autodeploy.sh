#!/bin/bash
# Auto-deploy service for AgenticIoT IoT Monitor
# Runs on boot: pulls latest code from GitHub, installs dependencies,
# and starts the iot-monitor service.
#
# SECURITY: No secrets are stored in this script.
# IoT Hub credentials live in /opt/iot-monitor/.env (not committed to git).

set -e

# ─── Configuration ────────────────────────────────────────────────────────────
REPO_URL="git@github.com:Andworx/copilot-iot-service.git"
PROJECT_DIR="/opt/iot-monitor"
SERVICE_NAME="iot-monitor"
LOG_FILE="/var/log/iot-monitor/autodeploy.log"
BRANCH="main"

# Detect the non-root user who owns the repository
if [ -d "$PROJECT_DIR/raspberry-pi" ]; then
    SERVICE_USER=$(stat -c '%U' "$PROJECT_DIR/raspberry-pi")
else
    SERVICE_USER=$(stat -c '%U' .)
fi

# ─── Helpers ──────────────────────────────────────────────────────────────────
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

mkdir -p "$(dirname "$LOG_FILE")"
log_message "Starting auto-deploy service"

# ─── Network ──────────────────────────────────────────────────────────────────
check_internet() {
    log_message "Checking internet connectivity..."
    for i in {1..30}; do
        if ping -c 1 github.com >/dev/null 2>&1; then
            log_message "Internet connection established"
            return 0
        fi
        log_message "Waiting for internet... attempt $i/30"
        sleep 10
    done
    log_message "ERROR: No internet after 5 minutes"
    return 1
}

# ─── GitHub SSH ───────────────────────────────────────────────────────────────
check_github_access() {
    log_message "Checking GitHub SSH access..."
    if sudo -u "$SERVICE_USER" ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -T git@github.com 2>&1 \
        | grep -q "successfully authenticated"; then
        log_message "GitHub SSH access confirmed"
        return 0
    else
        log_message "ERROR: Cannot authenticate with GitHub via SSH"
        log_message "See raspberry-pi/SSH_SETUP.md for configuration instructions"
        return 1
    fi
}

# ─── Repository ───────────────────────────────────────────────────────────────
setup_repository() {
    log_message "Setting up repository at $PROJECT_DIR"

    if [ ! -d "$PROJECT_DIR" ]; then
        sudo mkdir -p "$PROJECT_DIR"
        sudo chown "$SERVICE_USER:$SERVICE_USER" "$PROJECT_DIR"
    fi

    cd "$PROJECT_DIR"

    if [ ! -d ".git" ]; then
        log_message "Cloning repository (sparse-checkout: raspberry-pi/ only)"
        sudo -u "$SERVICE_USER" git init
        sudo -u "$SERVICE_USER" git remote add origin "$REPO_URL"
        sudo -u "$SERVICE_USER" git sparse-checkout init --cone
        sudo -u "$SERVICE_USER" git sparse-checkout set raspberry-pi
        sudo -u "$SERVICE_USER" git fetch origin "$BRANCH"
        sudo -u "$SERVICE_USER" git checkout "$BRANCH"
        log_message "Repository cloned"
    else
        if ! sudo -u "$SERVICE_USER" git sparse-checkout list 2>/dev/null | grep -q "raspberry-pi"; then
            log_message "Configuring sparse-checkout on existing repo"
            sudo -u "$SERVICE_USER" git sparse-checkout init --cone
            sudo -u "$SERVICE_USER" git sparse-checkout set raspberry-pi
        fi
    fi
}

pull_updates() {
    log_message "Checking for updates..."
    cd "$PROJECT_DIR"

    sudo -u "$SERVICE_USER" git fetch origin "$BRANCH" 2>&1 | tee -a "$LOG_FILE"

    LOCAL=$(sudo -u "$SERVICE_USER" git rev-parse HEAD)
    REMOTE=$(sudo -u "$SERVICE_USER" git rev-parse "origin/$BRANCH")

    if [ "$LOCAL" != "$REMOTE" ]; then
        log_message "Updates found: $LOCAL -> $REMOTE"
        sudo -u "$SERVICE_USER" git reset --hard "origin/$BRANCH" 2>&1 | tee -a "$LOG_FILE"
        chmod +x raspberry-pi/*.py raspberry-pi/*.sh 2>/dev/null || true
        log_message "Updates applied"
        return 0
    else
        log_message "No updates available"
        return 1
    fi
}

# ─── Configuration files ──────────────────────────────────────────────────────
setup_configuration() {
    log_message "Setting up configuration files"
    sudo mkdir -p /opt/iot-monitor

    # Ensure the writable runtime config directory exists and is owned by the
    # service user.  On installs that already have StateDirectory=iot-monitor in
    # the service unit systemd creates this automatically; this step is a
    # belt-and-braces guard for existing installs without that directive (#93).
    sudo mkdir -p /var/lib/iot-monitor
    sudo chown "$SERVICE_USER:$SERVICE_USER" /var/lib/iot-monitor

    # Create .env from template only if it doesn't already exist.
    # Existing .env is NEVER overwritten — it contains the IoT Hub secret.
    if [ ! -f "/opt/iot-monitor/.env" ]; then
        if [ -f "raspberry-pi/.env.template" ]; then
            sudo cp raspberry-pi/.env.template /opt/iot-monitor/.env
            sudo chown "$SERVICE_USER:$SERVICE_USER" /opt/iot-monitor/.env
            sudo chmod 600 /opt/iot-monitor/.env
            log_message "Created .env from template — fill in IOT_HUB_CONNECTION_STRING"
        else
            log_message "Warning: .env.template not found, skipping .env creation"
        fi
    else
        log_message "Preserving existing .env (contains IoT Hub connection string)"
    fi
}

# ─── Dependencies ─────────────────────────────────────────────────────────────
dependencies_need_update() {
    [ ! -f "raspberry-pi/requirements.txt" ] && return 1
    python3 -c "import azure.iot.device" 2>/dev/null || return 0
    return 0
}

install_dependencies() {
    log_message "Installing Python dependencies..."
    if ! command -v pip3 >/dev/null 2>&1; then
        sudo apt-get update -qq
        sudo apt-get install -y python3-pip python3-full
    fi
    if [ -f "raspberry-pi/requirements.txt" ]; then
        sudo pip3 install --break-system-packages -r raspberry-pi/requirements.txt
        log_message "Python packages installed"
    fi
}

# ─── Systemd service ──────────────────────────────────────────────────────────
setup_service() {
    log_message "Setting up $SERVICE_NAME systemd service"

    if [ -f "raspberry-pi/systemd/$SERVICE_NAME.service" ]; then
        sudo cp "raspberry-pi/systemd/$SERVICE_NAME.service" /etc/systemd/system/
        sudo systemctl daemon-reload
        log_message "Service unit updated"
    fi

    sudo systemctl enable "$SERVICE_NAME.service" 2>&1 | tee -a "$LOG_FILE"

    if sudo systemctl is-active --quiet "$SERVICE_NAME.service"; then
        log_message "Restarting $SERVICE_NAME"
        sudo systemctl restart --no-block "$SERVICE_NAME.service" 2>&1 | tee -a "$LOG_FILE"
    else
        log_message "Starting $SERVICE_NAME"
        sudo systemctl start --no-block "$SERVICE_NAME.service" 2>&1 | tee -a "$LOG_FILE"
    fi

    sleep 2
    if sudo systemctl is-active --quiet "$SERVICE_NAME.service"; then
        log_message "$SERVICE_NAME is RUNNING"
    else
        log_message "WARNING: $SERVICE_NAME failed to start (may still be initialising)"
        sudo systemctl status "$SERVICE_NAME.service" 2>&1 | tail -5 | tee -a "$LOG_FILE"
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    log_message "=== Auto-deploy started ==="

    # Self-update: keep /usr/local/bin/auto-deploy.sh current
    if [ -f "raspberry-pi/autodeploy.sh" ] && \
       ! cmp -s "raspberry-pi/autodeploy.sh" "/usr/local/bin/auto-deploy.sh"; then
        log_message "Updating /usr/local/bin/auto-deploy.sh"
        sudo cp raspberry-pi/autodeploy.sh /usr/local/bin/auto-deploy.sh
    fi

    check_internet  || { log_message "FATAL: No internet"; exit 1; }
    check_github_access || { log_message "FATAL: GitHub SSH failed"; exit 1; }

    setup_repository

    if pull_updates; then
        log_message "Updates applied — reinstalling dependencies"
        install_dependencies
    else
        dependencies_need_update && install_dependencies
    fi

    setup_configuration
    setup_service

    log_message "=== Auto-deploy completed ==="
}

main "$@"
