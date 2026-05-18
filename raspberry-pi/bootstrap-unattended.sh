#!/bin/bash
# AgenticIoT — Unattended Bootstrap
# Non-interactive installer for zero-touch Pi provisioning.
# Triggered by firstrun.sh on first boot — do NOT run manually.
#
# Reads DPS_ID_SCOPE + DPS_GROUP_KEY from the environment (set by firstrun.sh).
# Derives a per-device key, registers with Azure DPS, and writes the returned
# IoT Hub connection string to /opt/iot-monitor/.env.
#
# Uses HTTPS clone (no SSH key / GitHub account needed on the Pi).

set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ─── Validate inputs ──────────────────────────────────────────────────────────
if [ -z "$DPS_ID_SCOPE" ]; then
    log_error "DPS_ID_SCOPE is not set — cannot provision device"
    exit 1
fi
if [ -z "$DPS_GROUP_KEY" ]; then
    log_error "DPS_GROUP_KEY is not set — cannot provision device"
    exit 1
fi
DEVICE_ID="${DEVICE_ID:-raspberry-pi-iotpanel}"

log_info "AgenticIoT — Unattended Bootstrap (DPS)"
log_info "========================================"
log_info "Device ID : $DEVICE_ID"
log_info "ID Scope  : $DPS_ID_SCOPE"

# Support private repo clone via GITHUB_TOKEN env var
if [ -n "$GITHUB_TOKEN" ]; then
    REPO_URL="https://${GITHUB_TOKEN}@github.com/Andworx/copilot-iot-service.git"
else
    REPO_URL="https://github.com/Andworx/copilot-iot-service.git"
fi
PROJECT_DIR="/opt/iot-monitor"
ENV_FILE="$PROJECT_DIR/.env"

# Detect non-root user
if [ -n "$SUDO_USER" ]; then
    SERVICE_USER="$SUDO_USER"
elif [ -d "/home/pi" ]; then
    SERVICE_USER="pi"
else
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

# ─── Step 1: DPS provisioning ─────────────────────────────────────────────────
log_info "Step 1: Registering device with Azure DPS..."

# Derive per-device symmetric key: HMAC-SHA256(base64_decode(GROUP_KEY), DEVICE_ID), then base64 encode
DERIVED_KEY=$(python3 - <<EOF
import hmac, hashlib, base64
group_key = base64.b64decode("${DPS_GROUP_KEY}")
derived = hmac.new(group_key, "${DEVICE_ID}".encode(), hashlib.sha256).digest()
print(base64.b64encode(derived).decode())
EOF
)
log_info "  Per-device key derived"

# Build SAS token for DPS registration endpoint (valid 1 hour)
EXPIRY=$(( $(date +%s) + 3600 ))
RESOURCE="${DPS_ID_SCOPE}%2Fregistrations%2F${DEVICE_ID}"

SIG=$(python3 - <<EOF
import hmac, hashlib, base64, urllib.parse
key = base64.b64decode("${DERIVED_KEY}")
msg = "${RESOURCE}\n${EXPIRY}".encode()
sig = hmac.new(key, msg, hashlib.sha256).digest()
print(urllib.parse.quote(base64.b64encode(sig).decode(), safe=''))
EOF
)

SAS_TOKEN="SharedAccessSignature sr=${RESOURCE}&sig=${SIG}&se=${EXPIRY}&skn=registration"

# PUT registration request — DPS may return 200 (assigned) or 202 (assigning)
DPS_URL="https://global.azure-devices-provisioning.net/${DPS_ID_SCOPE}/registrations/${DEVICE_ID}/register?api-version=2021-06-01"

log_info "  Calling DPS endpoint..."
REG_RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT "$DPS_URL" \
    -H "Content-Type: application/json; charset=utf-8" \
    -H "Authorization: $SAS_TOKEN" \
    -d "{\"registrationId\":\"${DEVICE_ID}\"}")

HTTP_CODE=$(echo "$REG_RESPONSE" | tail -1)
BODY=$(echo "$REG_RESPONSE" | head -n -1)

log_info "  DPS HTTP response: $HTTP_CODE"

if [ "$HTTP_CODE" = "202" ]; then
    # Async — poll operation status
    OPERATION_ID=$(echo "$BODY" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('operationId',''))")
    if [ -z "$OPERATION_ID" ]; then
        log_error "DPS returned 202 but no operationId — cannot continue"
        exit 1
    fi
    log_info "  Polling DPS operation: $OPERATION_ID"
    POLL_URL="https://global.azure-devices-provisioning.net/${DPS_ID_SCOPE}/registrations/${DEVICE_ID}/operations/${OPERATION_ID}?api-version=2021-06-01"
    for attempt in $(seq 1 20); do
        sleep 5
        POLL_RESP=$(curl -s -w "\n%{http_code}" -X GET "$POLL_URL" \
            -H "Authorization: $SAS_TOKEN")
        POLL_CODE=$(echo "$POLL_RESP" | tail -1)
        BODY=$(echo "$POLL_RESP" | head -n -1)
        STATUS=$(echo "$BODY" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('status','unknown'))" 2>/dev/null || echo "unknown")
        log_info "  Poll attempt $attempt: status=$STATUS (HTTP $POLL_CODE)"
        [ "$STATUS" = "assigned" ] && break
        [ "$STATUS" = "failed" ] && { log_error "DPS registration failed: $BODY"; exit 1; }
    done
fi

STATUS=$(echo "$BODY" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('status','unknown'))" 2>/dev/null || echo "unknown")
if [ "$STATUS" != "assigned" ]; then
    log_error "DPS registration did not complete (status=$STATUS)"
    log_error "Response: $BODY"
    exit 1
fi

ASSIGNED_HUB=$(echo "$BODY" | python3 -c \
    "import sys, json; d=json.load(sys.stdin); print(d['registrationState']['assignedHub'])")
log_info "  Assigned IoT Hub: $ASSIGNED_HUB"

# Build final connection string using the per-device derived key
IOT_HUB_CONNECTION_STRING="HostName=${ASSIGNED_HUB};DeviceId=${DEVICE_ID};SharedAccessKey=${DERIVED_KEY}"
log_info "  Connection string built"

# ─── Step 2: Clone repository ─────────────────────────────────────────────────
log_info "Step 2: Cloning repository..."
[ -d "$PROJECT_DIR" ] && rm -rf "$PROJECT_DIR"

mkdir -p "$PROJECT_DIR"
chown "$SERVICE_USER:$SERVICE_USER" "$PROJECT_DIR"

sudo -u "$SERVICE_USER" git clone --depth 1 \
    --filter=blob:none \
    --sparse \
    "$REPO_URL" "$PROJECT_DIR"

sudo -u "$SERVICE_USER" git -C "$PROJECT_DIR" sparse-checkout set raspberry-pi
log_info "  Repository cloned (sparse: raspberry-pi/)"

# ─── Step 3: Write credentials ────────────────────────────────────────────────
log_info "Step 3: Writing IoT Hub credentials..."
mkdir -p "$(dirname "$ENV_FILE")"

cat > "$ENV_FILE" << EOF
# AgenticIoT IoT Hub credentials — written by unattended bootstrap
# Do not commit this file. It is gitignored.
IOT_HUB_CONNECTION_STRING=${IOT_HUB_CONNECTION_STRING}
DEVICE_ID=${DEVICE_ID}
EOF

chmod 600 "$ENV_FILE"
chown "$SERVICE_USER:$SERVICE_USER" "$ENV_FILE"
log_info "  Credentials written to $ENV_FILE"

# ─── Step 4: Run installer ────────────────────────────────────────────────────
log_info "Step 4: Running installer..."
chmod +x "$PROJECT_DIR/raspberry-pi/"*.sh 2>/dev/null || true
bash "$PROJECT_DIR/raspberry-pi/install.sh"
log_info "  Installer complete"

# ─── Step 5: Enable and start service ─────────────────────────────────────────
log_info "Step 5: Enabling iot-monitor service..."
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
