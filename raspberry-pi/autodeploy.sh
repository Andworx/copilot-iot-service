#!/bin/bash
# Auto-deploy service for AgenticIoT IoT Monitor
# Runs on boot: pulls latest code from GitHub, installs dependencies,
# and starts the iot-monitor service.
#
# SECURITY: No secrets are stored in this script.
# IoT Hub credentials and GITHUB_TOKEN live in /opt/iot-monitor/.env
# (not committed to git).
#
# GitHub access uses HTTPS + Personal Access Token (read:contents scope).
# Add GITHUB_TOKEN=ghp_xxx to /opt/iot-monitor/.env — no SSH keys needed.

set -e

# ─── Configuration ────────────────────────────────────────────────────────────
REPO_HTTPS="https://github.com/Andworx/copilot-iot-service.git"
PROJECT_DIR="/opt/iot-monitor"
SERVICE_NAME="iot-monitor"
LOG_FILE="/var/log/iot-monitor/autodeploy.log"
BRANCH="main"
ENV_FILE="/opt/iot-monitor/.env"

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

# Load GITHUB_TOKEN from .env if present
GITHUB_TOKEN=""
if [ -f "$ENV_FILE" ]; then
    GITHUB_TOKEN=$(grep -E '^GITHUB_TOKEN=' "$ENV_FILE" | cut -d= -f2- | tr -d '"' | tr -d "'" | tr -d '[:space:]')
fi

# Configure git to use the token via Authorization header (avoids URL encoding issues)
configure_git_auth() {
    if [ -n "$GITHUB_TOKEN" ]; then
        # Write to an explicit path so HOME env ambiguity (systemd/sudo) doesn't matter.
        # --replace-all prevents duplicate entries on repeated runs.
        local gitconfig="/home/${SERVICE_USER}/.gitconfig"
        sudo -u "$SERVICE_USER" git config --file "$gitconfig" --replace-all \
            http.https://github.com/.extraHeader \
            "Authorization: token ${GITHUB_TOKEN}"
        # Also disable interactive credential prompting system-wide for this user
        sudo -u "$SERVICE_USER" git config --file "$gitconfig" core.askPass ""
    fi
}

# Wrapper: run git as SERVICE_USER with explicit HOME and no terminal prompts
git_as_user() {
    sudo -u "$SERVICE_USER" \
        env HOME="/home/${SERVICE_USER}" GIT_TERMINAL_PROMPT=0 \
        git "$@"
}

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

# ─── GitHub access ────────────────────────────────────────────────────────────
check_github_access() {
    if [ -z "$GITHUB_TOKEN" ]; then
        log_message "ERROR: GITHUB_TOKEN not set in $ENV_FILE"
        log_message "Add GITHUB_TOKEN=ghp_xxx (read:contents scope) to $ENV_FILE"
        return 1
    fi
    configure_git_auth
    log_message "GitHub HTTPS access configured"
    return 0
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
        git_as_user init
        git_as_user remote add origin "$REPO_HTTPS"
        git_as_user sparse-checkout init --cone
        git_as_user sparse-checkout set raspberry-pi
        git_as_user fetch origin "$BRANCH"
        git_as_user checkout "$BRANCH"
        log_message "Repository cloned"
    else
        # Ensure remote uses plain HTTPS (auth handled via extraHeader)
        git_as_user remote set-url origin "$REPO_HTTPS"
        if ! git_as_user sparse-checkout list 2>/dev/null | grep -q "raspberry-pi"; then
            log_message "Configuring sparse-checkout on existing repo"
            git_as_user sparse-checkout init --cone
            git_as_user sparse-checkout set raspberry-pi
        fi
    fi
}

pull_updates() {
    log_message "Checking for updates..."
    cd "$PROJECT_DIR"

    git_as_user fetch origin "$BRANCH" 2>&1 | tee -a "$LOG_FILE"

    LOCAL=$(git_as_user rev-parse HEAD)
    REMOTE=$(git_as_user rev-parse "origin/$BRANCH")

    if [ "$LOCAL" != "$REMOTE" ]; then
        log_message "Updates found: $LOCAL -> $REMOTE"
        git_as_user reset --hard "origin/$BRANCH" 2>&1 | tee -a "$LOG_FILE"
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
        # --ignore-installed avoids attempting to uninstall system-managed packages (e.g. urllib3)
        sudo pip3 install --break-system-packages --ignore-installed -r raspberry-pi/requirements.txt
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

    check_internet  || { log_message "FATAL: No internet"; exit 1; }
    check_github_access || { log_message "FATAL: GitHub access failed"; exit 1; }

    setup_repository

    if pull_updates; then
        log_message "Updates applied — reinstalling dependencies"
        install_dependencies
    else
        dependencies_need_update && install_dependencies
    fi

    # Self-update: copy script AFTER pulling so we get the latest version
    if [ -f "raspberry-pi/autodeploy.sh" ] && \
       ! cmp -s "raspberry-pi/autodeploy.sh" "/usr/local/bin/auto-deploy.sh"; then
        log_message "Updating /usr/local/bin/auto-deploy.sh"
        sudo cp raspberry-pi/autodeploy.sh /usr/local/bin/auto-deploy.sh
        sudo chmod +x /usr/local/bin/auto-deploy.sh
    fi

    setup_configuration
    setup_service

    log_message "=== Auto-deploy completed ==="
}

main "$@"
