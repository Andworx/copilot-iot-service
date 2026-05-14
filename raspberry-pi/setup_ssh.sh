#!/bin/bash
# GitHub SSH key setup for IoT Monitor
# Generates an ed25519 SSH key and configures it for GitHub access.
# Required so the Pi can pull from the private GitHub repo on boot.
#
# Usage:
#   sudo ./setup_ssh.sh            # interactive setup
#   sudo ./setup_ssh.sh --status   # show current key status
#   sudo ./setup_ssh.sh --test     # test GitHub connection only

set -e

# ─── Configuration ────────────────────────────────────────────────────────────
# Auto-detect the non-root user; override by setting SERVICE_USER env var.
if [ -n "$SUDO_USER" ]; then
    SERVICE_USER="$SUDO_USER"
elif [ -d "/home/adm" ]; then
    SERVICE_USER="adm"
elif [ -d "/home/pi" ]; then
    SERVICE_USER="pi"
else
    echo "ERROR: Cannot detect non-root user. Set SERVICE_USER env var or run via sudo."
    exit 1
fi

SSH_KEY_PATH="/home/$SERVICE_USER/.ssh/id_ed25519_github"
SSH_CONFIG_PATH="/home/$SERVICE_USER/.ssh/config"

# ─── Colour helpers ───────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "${BLUE}[STEP]${NC}  $1"; }

check_root() {
    [ "$EUID" -ne 0 ] && { log_error "Run as root: sudo ./setup_ssh.sh"; exit 1; }
}

# ─── Key generation ───────────────────────────────────────────────────────────
generate_ssh_key() {
    log_step "Generating SSH key for GitHub..."
    sudo -u "$SERVICE_USER" mkdir -p "$(dirname "$SSH_KEY_PATH")"
    sudo -u "$SERVICE_USER" ssh-keygen -t ed25519 -C "$SERVICE_USER@iot-monitor" \
        -f "$SSH_KEY_PATH" -N ""
    sudo -u "$SERVICE_USER" chmod 600 "$SSH_KEY_PATH"
    sudo -u "$SERVICE_USER" chmod 644 "$SSH_KEY_PATH.pub"
    log_info "SSH key generated"
}

setup_ssh_config() {
    log_step "Writing SSH config..."
    sudo -u "$SERVICE_USER" tee "$SSH_CONFIG_PATH" > /dev/null << EOF
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github
    IdentitiesOnly yes
EOF
    sudo -u "$SERVICE_USER" chmod 600 "$SSH_CONFIG_PATH"
    log_info "SSH config written"
}

display_public_key() {
    echo ""
    echo "📋 Public key to add to GitHub:"
    echo "──────────────────────────────────────────────────────────────────────"
    sudo -u "$SERVICE_USER" cat "$SSH_KEY_PATH.pub"
    echo "──────────────────────────────────────────────────────────────────────"
    echo ""
    echo "🔗 Add it at: https://github.com/settings/ssh/new"
    echo "   Title:    IoT Monitor Pi"
    echo "   Key type: Authentication Key"
    echo ""
}

test_github_connection() {
    log_step "Testing GitHub SSH connection..."
    if sudo -u "$SERVICE_USER" \
        ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -T git@github.com 2>&1 \
        | grep -q "successfully authenticated"; then
        log_info "✅ GitHub SSH connection successful"
        return 0
    else
        log_error "❌ GitHub SSH connection failed"
        echo "  Ensure the key was added to GitHub and retry:"
        echo "    sudo -u $SERVICE_USER ssh -T git@github.com"
        return 1
    fi
}

show_status() {
    echo ""
    echo "🔍 SSH key status (user: $SERVICE_USER)"
    if [ -f "$SSH_KEY_PATH" ]; then
        echo "  ✅ Key file:  $SSH_KEY_PATH"
        KEY_PERMS=$(sudo -u "$SERVICE_USER" stat -c "%a" "$SSH_KEY_PATH")
        [ "$KEY_PERMS" = "600" ] \
            && echo "  ✅ Permissions: 600 (correct)" \
            || echo "  ⚠️  Permissions: $KEY_PERMS (expected 600)"
        [ -f "$SSH_CONFIG_PATH" ] \
            && echo "  ✅ SSH config: present" \
            || echo "  ❌ SSH config: missing"
        sudo -u "$SERVICE_USER" \
            ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -T git@github.com 2>&1 \
            | grep -q "successfully authenticated" \
            && echo "  ✅ GitHub:      reachable" \
            || echo "  ❌ GitHub:      not reachable"
    else
        echo "  ❌ Key not found ($SSH_KEY_PATH)"
    fi
    echo ""
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo "🔑 GitHub SSH Key Setup — AgenticIoT IoT Monitor"
    echo "=================================================="
    check_root
    show_status

    if [ -f "$SSH_KEY_PATH" ]; then
        log_warn "Key already exists at $SSH_KEY_PATH"
        echo "  1) Use existing key"
        echo "  2) Generate new key (overwrites existing)"
        echo "  3) Exit"
        read -rp "  Choose (1/2/3): " choice
        case $choice in
            2) rm -f "$SSH_KEY_PATH" "$SSH_KEY_PATH.pub"; generate_ssh_key; setup_ssh_config ;;
            3) exit 0 ;;
            *) log_info "Using existing key" ;;
        esac
    else
        generate_ssh_key
        setup_ssh_config
    fi

    [ ! -f "$SSH_CONFIG_PATH" ] && setup_ssh_config

    display_public_key
    read -rp "Press Enter after adding the key to GitHub..."

    if test_github_connection; then
        echo ""
        log_info "🎉 SSH setup complete!"
        echo ""
        echo "  Next: run bootstrap.sh to clone the repo and install services."
    else
        echo ""
        log_error "SSH setup incomplete. Resolve connection issues before continuing."
    fi
}

case "${1:-}" in
    --status) show_status; exit 0 ;;
    --test)   check_root; test_github_connection; exit $? ;;
    --help)
        echo "Usage: sudo $0 [--status|--test|--help]"
        echo "  --status  Show key status"
        echo "  --test    Test GitHub SSH connection"
        exit 0 ;;
esac

main "$@"
