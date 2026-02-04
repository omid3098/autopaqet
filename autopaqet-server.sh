#!/bin/bash
# AutoPaqet Server Installer for Linux
# Usage (one-liner): curl -sSL <url> | sudo bash
# Usage (interactive): sudo bash autopaqet-server.sh

set -e

# =============================================================================
# Configuration
# =============================================================================
AUTOPAQET_PORT="${AUTOPAQET_PORT:-9999}"
AUTOPAQET_REPO="https://github.com/hanselime/paqet.git"
AUTOPAQET_SCRIPTS_REPO="https://raw.githubusercontent.com/omid3098/autopaqet/main"
GO_VERSION="1.23.5"
INSTALL_DIR="/opt/autopaqet"
CONFIG_DIR="/etc/autopaqet"
CONFIG_PATH="${CONFIG_DIR}/server.yaml"
BINARY_PATH="/usr/local/bin/autopaqet"
SERVICE_NAME="autopaqet"

# =============================================================================
# Colors for output
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# =============================================================================
# Source modules if available, otherwise define inline
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try to source modules
if [[ -f "${SCRIPT_DIR}/lib/bash/validate.sh" ]]; then
    source "${SCRIPT_DIR}/lib/bash/validate.sh"
    source "${SCRIPT_DIR}/lib/bash/config.sh"
    source "${SCRIPT_DIR}/lib/bash/service.sh"
    source "${SCRIPT_DIR}/lib/bash/install.sh"
    source "${SCRIPT_DIR}/lib/bash/menu.sh"
    MODULES_LOADED=true
else
    MODULES_LOADED=false
fi

# =============================================================================
# Core Functions (inline for one-liner compatibility)
# =============================================================================

# Output functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check root
check_root() {
    [[ $EUID -eq 0 ]]
}

# Detect architecture
detect_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64) echo "amd64" ;;
        aarch64) echo "arm64" ;;
        *) echo "" ;;
    esac
}

# Detect network configuration
detect_network() {
    # Get default interface
    INTERFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -1)
    [[ -z "$INTERFACE" ]] && return 1

    # Get server IP
    SERVER_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -1)
    [[ -z "$SERVER_IP" ]] && return 1

    # Get gateway IP
    GATEWAY_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="via") print $(i+1)}' | head -1)
    [[ -z "$GATEWAY_IP" ]] && return 1

    # Get gateway MAC (ping first to populate ARP)
    ping -c 1 -W 1 "$GATEWAY_IP" >/dev/null 2>&1 || true
    ROUTER_MAC=$(ip neigh show "$GATEWAY_IP" 2>/dev/null | awk '{print $5}' | head -1)
    [[ -z "$ROUTER_MAC" || "$ROUTER_MAC" == "FAILED" ]] && return 1

    return 0
}

# =============================================================================
# Installation Functions
# =============================================================================

do_fresh_install() {
    check_root || error "This script must be run as root"

    local arch=$(detect_arch)
    [[ -z "$arch" ]] && error "Unsupported architecture: $(uname -m)"

    echo ""
    echo -e "${CYAN}=============================================${NC}"
    echo -e "${CYAN}    AUTOPAQET SERVER INSTALLATION${NC}"
    echo -e "${CYAN}=============================================${NC}"
    echo ""

    # Step 1: Update system
    info "Updating system packages..."
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq
    success "System updated"

    # Step 2: Install packages
    info "Installing required packages..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        git curl wget nano vim htop net-tools unzip zip \
        software-properties-common build-essential \
        libpcap-dev iptables-persistent
    success "Packages installed"

    # Step 3: Configure UFW
    info "Configuring firewall..."
    if command -v ufw &>/dev/null; then
        ufw allow 443/tcp >/dev/null 2>&1 || true
        ufw allow ${AUTOPAQET_PORT}/tcp >/dev/null 2>&1 || true
        success "UFW configured"
    else
        warn "UFW not found, skipping"
    fi

    # Step 4: Install Go
    info "Installing Go ${GO_VERSION}..."
    local go_tar="go${GO_VERSION}.linux-${arch}.tar.gz"
    wget -q "https://go.dev/dl/${go_tar}" -O /tmp/go.tar.gz
    rm -rf /usr/local/go
    tar -C /usr/local -xzf /tmp/go.tar.gz
    rm /tmp/go.tar.gz
    export PATH=/usr/local/go/bin:$PATH
    echo 'export PATH=/usr/local/go/bin:$PATH' > /etc/profile.d/go.sh
    success "Go $(go version | awk '{print $3}') installed"

    # Step 5: Clone repository
    info "Cloning repository..."
    rm -rf "$INSTALL_DIR"
    git clone --depth 1 "$AUTOPAQET_REPO" "$INSTALL_DIR" 2>/dev/null
    success "Repository cloned"

    # Step 6: Build binary
    info "Building binary..."
    cd "$INSTALL_DIR"
    local git_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    local build_time=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
    CGO_ENABLED=1 go build -v -a -trimpath \
        -ldflags "-s -w -X 'paqet/cmd/version.GitCommit=${git_commit}' -X 'paqet/cmd/version.BuildTime=${build_time}'" \
        -o autopaqet ./cmd/main.go 2>/dev/null

    # Stop existing service before copying binary (prevents "Text file busy" error)
    if systemctl is-active --quiet ${SERVICE_NAME} 2>/dev/null; then
        systemctl stop ${SERVICE_NAME}
    fi
    cp autopaqet "$BINARY_PATH"
    chmod +x "$BINARY_PATH"
    success "Binary built: $BINARY_PATH"

    # Step 7: Detect network
    info "Detecting network configuration..."
    detect_network || error "Could not detect network configuration"
    success "Network: interface=$INTERFACE, ip=$SERVER_IP, gateway_mac=$ROUTER_MAC"

    # Step 8: Generate secret key
    SECRET_KEY=$("$BINARY_PATH" secret)

    # Step 9: Create configuration
    info "Creating configuration..."
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_PATH" << EOF
# AutoPaqet Server Configuration
# Generated on $(date -u '+%Y-%m-%d %H:%M:%S UTC')
role: "server"

log:
  level: "info"

listen:
  addr: ":${AUTOPAQET_PORT}"

network:
  interface: "${INTERFACE}"
  ipv4:
    addr: "${SERVER_IP}:${AUTOPAQET_PORT}"
    router_mac: "${ROUTER_MAC}"
  tcp:
    local_flag: ["PA"]

transport:
  protocol: "kcp"
  conn: 1
  kcp:
    mode: "fast"
    key: "${SECRET_KEY}"
    block: "aes"
EOF
    success "Configuration created: $CONFIG_PATH"

    # Step 10: Configure iptables
    info "Configuring iptables..."
    iptables -t raw -C PREROUTING -p tcp --dport ${AUTOPAQET_PORT} -j NOTRACK 2>/dev/null || \
        iptables -t raw -I PREROUTING -p tcp --dport ${AUTOPAQET_PORT} -j NOTRACK
    iptables -t raw -C OUTPUT -p tcp --sport ${AUTOPAQET_PORT} -j NOTRACK 2>/dev/null || \
        iptables -t raw -I OUTPUT -p tcp --sport ${AUTOPAQET_PORT} -j NOTRACK
    iptables -t mangle -C OUTPUT -p tcp --sport ${AUTOPAQET_PORT} --tcp-flags RST RST -j DROP 2>/dev/null || \
        iptables -t mangle -I OUTPUT -p tcp --sport ${AUTOPAQET_PORT} --tcp-flags RST RST -j DROP
    netfilter-persistent save >/dev/null 2>&1 || iptables-save > /etc/iptables/rules.v4
    success "Iptables configured"

    # Step 11: Create systemd service
    info "Creating systemd service..."
    cat > /etc/systemd/system/${SERVICE_NAME}.service << 'EOF'
[Unit]
Description=AutoPaqet Packet-level Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/autopaqet run -c /etc/autopaqet/server.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable ${SERVICE_NAME} >/dev/null 2>&1
    systemctl start ${SERVICE_NAME}
    success "Service created and started"

    # Step 12: Verify
    sleep 2
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        success "AutoPaqet is running!"
    else
        error "Service failed to start. Check: journalctl -u ${SERVICE_NAME}"
    fi

    # Save management script for later use
    save_management_script

    # Show completion info
    show_install_complete
}

save_management_script() {
    info "Saving management script..."
    local script_url="${AUTOPAQET_SCRIPTS_REPO}/autopaqet-server.sh"
    local script_path="/usr/local/bin/autopaqet-manage"

    # Download latest script
    if wget -q "$script_url" -O "$script_path" 2>/dev/null; then
        chmod +x "$script_path"
        success "Management script saved: $script_path"
    else
        # Fallback: if we can read ourselves, copy
        if [[ -f "${BASH_SOURCE[0]}" ]]; then
            cp "${BASH_SOURCE[0]}" "$script_path"
            chmod +x "$script_path"
            success "Management script saved: $script_path"
        else
            warn "Could not save management script"
        fi
    fi
}

show_install_complete() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}              INSTALLATION COMPLETE${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}CLIENT CONFIGURATION:${NC}"
    echo ""
    echo "  Server Address:  ${SERVER_IP}:${AUTOPAQET_PORT}"
    echo "  Secret Key:      ${SECRET_KEY}"
    echo ""
    echo -e "${YELLOW}MANAGEMENT:${NC}"
    echo "  Menu:     sudo autopaqet-manage"
    echo ""
    echo -e "${YELLOW}QUICK COMMANDS:${NC}"
    echo "  Status:   systemctl status ${SERVICE_NAME}"
    echo "  Logs:     journalctl -u ${SERVICE_NAME} -f"
    echo "  Restart:  systemctl restart ${SERVICE_NAME}"
    echo ""
}

# =============================================================================
# Update Functions
# =============================================================================

do_update_autopaqet() {
    check_root || error "This script must be run as root"

    info "Downloading latest AutoPaqet scripts..."

    local tmp_dir=$(mktemp -d)
    local files=("autopaqet-server.sh" "autopaqet-uninstall.sh")

    for file in "${files[@]}"; do
        local url="${AUTOPAQET_SCRIPTS_REPO}/${file}"
        if wget -q "$url" -O "${tmp_dir}/${file}"; then
            success "Downloaded: $file"
        else
            warn "Failed to download: $file"
        fi
    done

    # Copy to script directory
    for file in "${files[@]}"; do
        if [[ -f "${tmp_dir}/${file}" ]]; then
            cp "${tmp_dir}/${file}" "${SCRIPT_DIR}/${file}"
            chmod +x "${SCRIPT_DIR}/${file}"
        fi
    done

    rm -rf "$tmp_dir"
    success "AutoPaqet scripts updated"

    echo ""
    read -p "Press Enter to continue..."
}

do_update_paqet() {
    check_root || error "This script must be run as root"

    if [[ ! -d "$INSTALL_DIR" ]]; then
        error "Paqet not installed. Run Fresh Install first."
    fi

    # Stop service
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        info "Stopping service..."
        systemctl stop ${SERVICE_NAME}
    fi

    # Update source
    info "Pulling latest changes..."
    cd "$INSTALL_DIR"
    git pull

    # Rebuild
    info "Rebuilding binary..."
    export PATH=/usr/local/go/bin:$PATH
    local git_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    local build_time=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
    CGO_ENABLED=1 go build -v -a -trimpath \
        -ldflags "-s -w -X 'paqet/cmd/version.GitCommit=${git_commit}' -X 'paqet/cmd/version.BuildTime=${build_time}'" \
        -o autopaqet ./cmd/main.go 2>/dev/null
    cp autopaqet "$BINARY_PATH"
    chmod +x "$BINARY_PATH"
    success "Binary rebuilt"

    # Restart service
    info "Starting service..."
    systemctl start ${SERVICE_NAME}
    success "Service restarted"

    echo ""
    read -p "Press Enter to continue..."
}

do_uninstall() {
    check_root || error "This script must be run as root"

    echo ""
    echo -e "${YELLOW}This will remove AutoPaqet from this system.${NC}"
    echo ""
    read -p "Continue with uninstall? [y/N] " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Cancelled."
        return
    fi

    # Stop service
    if systemctl is-active --quiet ${SERVICE_NAME} 2>/dev/null; then
        info "Stopping service..."
        systemctl stop ${SERVICE_NAME}
    fi

    # Disable service
    if systemctl is-enabled --quiet ${SERVICE_NAME} 2>/dev/null; then
        info "Disabling service..."
        systemctl disable ${SERVICE_NAME} 2>/dev/null
    fi

    # Remove service file
    if [[ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]]; then
        info "Removing service file..."
        rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
        systemctl daemon-reload
    fi

    # Remove binary
    if [[ -f "$BINARY_PATH" ]]; then
        info "Removing binary..."
        rm -f "$BINARY_PATH"
    fi

    # Backup and remove config
    if [[ -d "$CONFIG_DIR" ]]; then
        read -p "Backup configuration before removing? [Y/n] " backup
        if [[ "$backup" != "n" && "$backup" != "N" ]]; then
            local backup_file="/tmp/autopaqet-config-$(date +%Y%m%d-%H%M%S).tar.gz"
            tar -czf "$backup_file" -C /etc autopaqet 2>/dev/null || true
            success "Backed up to: $backup_file"
        fi
        info "Removing configuration..."
        rm -rf "$CONFIG_DIR"
    fi

    # Remove source
    if [[ -d "$INSTALL_DIR" ]]; then
        info "Removing source directory..."
        rm -rf "$INSTALL_DIR"
    fi

    success "AutoPaqet uninstalled"
    echo ""
    echo "Note: iptables rules and Go were NOT removed."
    echo ""
    read -p "Press Enter to continue..."
}

# =============================================================================
# Service Management
# =============================================================================

do_service_start() {
    systemctl start ${SERVICE_NAME}
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        success "Service started"
    else
        error "Failed to start service"
    fi
    echo ""
    read -p "Press Enter to continue..."
}

do_service_stop() {
    systemctl stop ${SERVICE_NAME}
    success "Service stopped"
    echo ""
    read -p "Press Enter to continue..."
}

do_service_restart() {
    systemctl restart ${SERVICE_NAME}
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        success "Service restarted"
    else
        error "Failed to restart service"
    fi
    echo ""
    read -p "Press Enter to continue..."
}

do_service_status() {
    echo ""
    systemctl status ${SERVICE_NAME} --no-pager || true
    echo ""
    read -p "Press Enter to continue..."
}

do_service_enable() {
    systemctl enable ${SERVICE_NAME} >/dev/null 2>&1
    success "Auto-start enabled"
    echo ""
    read -p "Press Enter to continue..."
}

do_service_disable() {
    systemctl disable ${SERVICE_NAME} >/dev/null 2>&1
    success "Auto-start disabled"
    echo ""
    read -p "Press Enter to continue..."
}

# =============================================================================
# Configuration Management
# =============================================================================

do_config_view() {
    echo ""
    if [[ -f "$CONFIG_PATH" ]]; then
        echo -e "${CYAN}Configuration: $CONFIG_PATH${NC}"
        echo ""
        cat "$CONFIG_PATH"
    else
        warn "Configuration file not found: $CONFIG_PATH"
    fi
    echo ""
    read -p "Press Enter to continue..."
}

do_config_edit_port() {
    echo ""
    read -p "Enter new port (current: ${AUTOPAQET_PORT}): " new_port

    if [[ ! "$new_port" =~ ^[0-9]+$ ]] || [[ $new_port -lt 1 || $new_port -gt 65535 ]]; then
        error "Invalid port number"
    fi

    if [[ -f "$CONFIG_PATH" ]]; then
        # Update listen addr
        sed -i "s/addr: \":[0-9]*\"/addr: \":${new_port}\"/" "$CONFIG_PATH"
        # Update ipv4 addr port
        sed -i "s/\(addr: \"[0-9.]*:\)[0-9]*\"/\1${new_port}\"/" "$CONFIG_PATH"
        success "Port updated to ${new_port}"
        warn "Remember to update iptables rules and restart the service!"
    else
        error "Configuration file not found"
    fi
    echo ""
    read -p "Press Enter to continue..."
}

do_config_edit_key() {
    echo ""
    echo "Current key can be found in the config file."
    read -p "Generate new key? [y/N] " gen_new

    if [[ "$gen_new" == "y" || "$gen_new" == "Y" ]]; then
        if [[ -x "$BINARY_PATH" ]]; then
            local new_key=$("$BINARY_PATH" secret)
            sed -i "s/\(key: \"\)[^\"]*/\1${new_key}/" "$CONFIG_PATH"
            success "New key generated: ${new_key}"
            warn "Update your clients with the new key!"
        else
            error "Binary not found"
        fi
    else
        read -p "Enter new secret key: " new_key
        if [[ -n "$new_key" ]]; then
            sed -i "s/\(key: \"\)[^\"]*/\1${new_key}/" "$CONFIG_PATH"
            success "Key updated"
        fi
    fi
    echo ""
    read -p "Press Enter to continue..."
}

do_config_edit_local_flag() {
    echo ""
    local current_flag="unknown"
    if [[ -f "$CONFIG_PATH" ]]; then
        current_flag=$(grep "local_flag:" "$CONFIG_PATH" | sed 's/.*\["\([^"]*\)"\].*/\1/')
    fi

    echo -e "${CYAN}Current TCP Local Flag: [${current_flag}]${NC}"
    echo ""
    echo "  [1] S   - SYN (connection setup)"
    echo "  [2] PA  - PSH+ACK (standard data)"
    echo "  [3] A   - ACK (acknowledgment)"
    echo ""
    echo -e "  ${YELLOW}[0] Cancel${NC}"
    echo ""
    read -p "Select option: " flag_choice

    local new_flag=""
    case $flag_choice in
        1) new_flag="S" ;;
        2) new_flag="PA" ;;
        3) new_flag="A" ;;
        0) return ;;
        *) error "Invalid selection"; sleep 1; return ;;
    esac

    if [[ -f "$CONFIG_PATH" ]]; then
        sed -i "s/\(local_flag:\s*\[\"\)[^\"]*/\1${new_flag}/" "$CONFIG_PATH"
        success "TCP local_flag updated to: [${new_flag}]"
        warn "Restart service for changes to take effect: sudo systemctl restart autopaqet"
    else
        error "Configuration file not found"
    fi
    echo ""
    read -p "Press Enter to continue..."
}

do_config_edit_file() {
    if [[ -f "$CONFIG_PATH" ]]; then
        nano "$CONFIG_PATH"
    else
        warn "Configuration file not found"
        read -p "Press Enter to continue..."
    fi
}

do_view_logs() {
    echo ""
    echo -e "${CYAN}Showing last 50 log lines (Ctrl+C to exit live view)${NC}"
    echo ""
    journalctl -u ${SERVICE_NAME} -n 50 --no-pager
    echo ""
    read -p "Follow logs in real-time? [y/N] " follow
    if [[ "$follow" == "y" || "$follow" == "Y" ]]; then
        journalctl -u ${SERVICE_NAME} -f
    fi
}

# =============================================================================
# Menu System
# =============================================================================

show_main_menu() {
    clear
    echo -e "${CYAN}=============================================${NC}"
    echo -e "${CYAN}         AUTOPAQET SERVER${NC}"
    echo -e "${CYAN}=============================================${NC}"
    echo ""
    echo "  [1] Fresh Install"
    echo "  [2] Update AutoPaqet (download latest scripts)"
    echo "  [3] Update Paqet (git pull + rebuild)"
    echo "  [4] Uninstall"
    echo "  [5] Service Management"
    echo "  [6] Configuration"
    echo "  [7] View Logs"
    echo ""
    echo -e "  ${YELLOW}[0] Exit${NC}"
    echo ""
}

show_service_menu() {
    clear
    echo -e "${CYAN}=============================================${NC}"
    echo -e "${CYAN}         SERVICE MANAGEMENT${NC}"
    echo -e "${CYAN}=============================================${NC}"
    echo ""
    echo "  [1] Start Service"
    echo "  [2] Stop Service"
    echo "  [3] Restart Service"
    echo "  [4] Check Status"
    echo "  [5] Enable Auto-Start"
    echo "  [6] Disable Auto-Start"
    echo ""
    echo -e "  ${YELLOW}[0] Back${NC}"
    echo ""
}

show_config_menu() {
    clear
    echo -e "${CYAN}=============================================${NC}"
    echo -e "${CYAN}         CONFIGURATION${NC}"
    echo -e "${CYAN}=============================================${NC}"
    echo ""
    echo "  [1] View Current Configuration"
    echo "  [2] Edit Server Port"
    echo "  [3] Edit Secret Key"
    echo "  [4] Edit TCP Local Flag"
    echo "  [5] Edit Config (nano)"
    echo ""
    echo -e "  ${YELLOW}[0] Back${NC}"
    echo ""
}

run_service_menu() {
    while true; do
        show_service_menu
        read -p "Select option: " choice
        case $choice in
            0) return ;;
            1) do_service_start ;;
            2) do_service_stop ;;
            3) do_service_restart ;;
            4) do_service_status ;;
            5) do_service_enable ;;
            6) do_service_disable ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

run_config_menu() {
    while true; do
        show_config_menu
        read -p "Select option: " choice
        case $choice in
            0) return ;;
            1) do_config_view ;;
            2) do_config_edit_port ;;
            3) do_config_edit_key ;;
            4) do_config_edit_local_flag ;;
            5) do_config_edit_file ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

run_main_menu_loop() {
    while true; do
        show_main_menu
        read -p "Select option: " choice
        case $choice in
            0)
                echo "Goodbye!"
                exit 0
                ;;
            1) do_fresh_install ;;
            2) do_update_autopaqet ;;
            3) do_update_paqet ;;
            4) do_uninstall ;;
            5) run_service_menu ;;
            6) run_config_menu ;;
            7) do_view_logs ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# =============================================================================
# Entry Point
# =============================================================================

# Check root for all operations
check_root || error "This script must be run as root"

# Detect if running interactively or piped
if [[ -t 0 ]]; then
    # Interactive mode - show menu
    run_main_menu_loop
else
    # Piped mode (one-liner) - run fresh install directly
    do_fresh_install
fi
