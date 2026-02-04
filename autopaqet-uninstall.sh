#!/bin/bash
# AutoPaqet Server Uninstaller for Linux
# Usage: curl -sSL <url> | sudo bash
#    or: sudo bash autopaqet-uninstall.sh

set -e

# Configuration
INSTALL_DIR="/opt/autopaqet"
CONFIG_DIR="/etc/autopaqet"
BINARY_PATH="/usr/local/bin/autopaqet"
SERVICE_FILE="/etc/systemd/system/autopaqet.service"
AUTOPAQET_PORT="${AUTOPAQET_PORT:-9999}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Output functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check root
[[ $EUID -ne 0 ]] && error "This script must be run as root"

echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}    AUTOPAQET SERVER UNINSTALLER (LINUX)    ${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""

# Check if anything is installed
installed=false
[[ -d "$INSTALL_DIR" ]] && installed=true
[[ -f "$BINARY_PATH" ]] && installed=true
[[ -d "$CONFIG_DIR" ]] && installed=true
[[ -f "$SERVICE_FILE" ]] && installed=true

if [[ "$installed" != "true" ]]; then
    warn "AutoPaqet does not appear to be installed."
    echo "Nothing to uninstall."
    exit 0
fi

# Show what will be removed
echo "This will remove:"
echo ""
[[ -d "$INSTALL_DIR" ]] && echo "  - Source directory: $INSTALL_DIR"
[[ -d "$CONFIG_DIR" ]] && echo "  - Configuration: $CONFIG_DIR"
[[ -f "$BINARY_PATH" ]] && echo "  - Binary: $BINARY_PATH"
[[ -f "$SERVICE_FILE" ]] && echo "  - Systemd service: $SERVICE_FILE"
echo ""
echo -e "${YELLOW}Note: iptables rules and Go installation will NOT be removed.${NC}"
echo ""

# Confirm
read -p "Continue with uninstall? [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

echo ""

# Step 1: Stop and disable service
if systemctl is-active --quiet autopaqet 2>/dev/null; then
    info "Stopping AutoPaqet service..."
    systemctl stop autopaqet
    success "Service stopped"
fi

if systemctl is-enabled --quiet autopaqet 2>/dev/null; then
    info "Disabling AutoPaqet service..."
    systemctl disable autopaqet 2>/dev/null
    success "Service disabled"
fi

# Step 2: Remove systemd service file
if [[ -f "$SERVICE_FILE" ]]; then
    info "Removing systemd service..."
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
    success "Removed: $SERVICE_FILE"
fi

# Step 3: Remove binary
if [[ -f "$BINARY_PATH" ]]; then
    info "Removing binary..."
    rm -f "$BINARY_PATH"
    success "Removed: $BINARY_PATH"
fi

# Step 4: Remove configuration (with backup option)
if [[ -d "$CONFIG_DIR" ]]; then
    read -p "Backup configuration before removing? [Y/n] " backup
    if [[ "$backup" != "n" && "$backup" != "N" ]]; then
        backup_file="/tmp/autopaqet-config-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
        tar -czf "$backup_file" -C /etc autopaqet 2>/dev/null || true
        success "Configuration backed up to: $backup_file"
    fi

    info "Removing configuration directory..."
    rm -rf "$CONFIG_DIR"
    success "Removed: $CONFIG_DIR"
fi

# Step 5: Remove installation directory
if [[ -d "$INSTALL_DIR" ]]; then
    info "Removing source directory..."
    rm -rf "$INSTALL_DIR"
    success "Removed: $INSTALL_DIR"
fi

echo ""
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}  AutoPaqet has been uninstalled.${NC}"
echo -e "${GREEN}=============================================${NC}"
echo ""
echo "Note: The following were NOT removed:"
echo "  - iptables rules (run: iptables -t raw -L; iptables -t mangle -L)"
echo "  - Go installation (/usr/local/go)"
echo "  - System packages installed during setup"
echo ""
echo "To remove iptables rules manually:"
echo "  iptables -t raw -D PREROUTING -p tcp --dport ${AUTOPAQET_PORT} -j NOTRACK"
echo "  iptables -t raw -D OUTPUT -p tcp --sport ${AUTOPAQET_PORT} -j NOTRACK"
echo "  iptables -t mangle -D OUTPUT -p tcp --sport ${AUTOPAQET_PORT} --tcp-flags RST RST -j DROP"
echo ""
