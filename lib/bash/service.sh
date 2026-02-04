#!/bin/bash
# AutoPaqet Service Management
# Linux systemd service management (Linux server only)

SERVICE_NAME="autopaqet"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
BINARY_PATH="/usr/local/bin/autopaqet"
CONFIG_PATH="/etc/autopaqet/server.yaml"

# Create systemd service file
# Usage: create_service_file "/usr/local/bin/autopaqet" "/etc/autopaqet/server.yaml"
create_service_file() {
    local binary="${1:-$BINARY_PATH}"
    local config="${2:-$CONFIG_PATH}"

    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=AutoPaqet Packet-level Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=${binary} run -c ${config}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
}

# Start the service
# Usage: service_start
service_start() {
    systemctl start "$SERVICE_NAME"
    return $?
}

# Stop the service
# Usage: service_stop
service_stop() {
    systemctl stop "$SERVICE_NAME"
    return $?
}

# Restart the service
# Usage: service_restart
service_restart() {
    systemctl restart "$SERVICE_NAME"
    return $?
}

# Get service status
# Usage: service_status
service_status() {
    systemctl status "$SERVICE_NAME" --no-pager
    return $?
}

# Check if service is running
# Usage: if service_is_running; then echo "running"; fi
service_is_running() {
    systemctl is-active --quiet "$SERVICE_NAME"
}

# Check if service is enabled
# Usage: if service_is_enabled; then echo "enabled"; fi
service_is_enabled() {
    systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null
}

# Enable service auto-start
# Usage: service_enable
service_enable() {
    systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
    return $?
}

# Disable service auto-start
# Usage: service_disable
service_disable() {
    systemctl disable "$SERVICE_NAME" >/dev/null 2>&1
    return $?
}

# View service logs
# Usage: service_logs [lines]
service_logs() {
    local lines="${1:-50}"
    journalctl -u "$SERVICE_NAME" -n "$lines" --no-pager
}

# Follow service logs (live)
# Usage: service_logs_follow
service_logs_follow() {
    journalctl -u "$SERVICE_NAME" -f
}

# Remove service
# Usage: service_remove
service_remove() {
    # Stop if running
    if service_is_running; then
        service_stop
    fi

    # Disable if enabled
    if service_is_enabled; then
        service_disable
    fi

    # Remove service file
    if [[ -f "$SERVICE_FILE" ]]; then
        rm -f "$SERVICE_FILE"
        systemctl daemon-reload
    fi
}

# Get service info summary
# Usage: service_info
service_info() {
    echo "Service: $SERVICE_NAME"
    echo "Binary:  $BINARY_PATH"
    echo "Config:  $CONFIG_PATH"
    echo ""

    if service_is_running; then
        echo "Status:  Running"
    else
        echo "Status:  Stopped"
    fi

    if service_is_enabled; then
        echo "Startup: Enabled (auto-start)"
    else
        echo "Startup: Disabled"
    fi
}

# Configure iptables rules for autopaqet
# Usage: configure_iptables 9999
configure_iptables() {
    local port="${1:-9999}"

    # Add NOTRACK rules (bypass connection tracking)
    iptables -t raw -C PREROUTING -p tcp --dport ${port} -j NOTRACK 2>/dev/null || \
        iptables -t raw -I PREROUTING -p tcp --dport ${port} -j NOTRACK

    iptables -t raw -C OUTPUT -p tcp --sport ${port} -j NOTRACK 2>/dev/null || \
        iptables -t raw -I OUTPUT -p tcp --sport ${port} -j NOTRACK

    # Drop RST packets (prevent kernel from resetting connections)
    iptables -t mangle -C OUTPUT -p tcp --sport ${port} --tcp-flags RST RST -j DROP 2>/dev/null || \
        iptables -t mangle -I OUTPUT -p tcp --sport ${port} --tcp-flags RST RST -j DROP

    # Save rules
    if command -v netfilter-persistent &>/dev/null; then
        netfilter-persistent save >/dev/null 2>&1
    elif [[ -d /etc/iptables ]]; then
        iptables-save > /etc/iptables/rules.v4
    fi
}

# Remove iptables rules for autopaqet
# Usage: remove_iptables 9999
remove_iptables() {
    local port="${1:-9999}"

    # Remove rules (ignore errors if they don't exist)
    iptables -t raw -D PREROUTING -p tcp --dport ${port} -j NOTRACK 2>/dev/null || true
    iptables -t raw -D OUTPUT -p tcp --sport ${port} -j NOTRACK 2>/dev/null || true
    iptables -t mangle -D OUTPUT -p tcp --sport ${port} --tcp-flags RST RST -j DROP 2>/dev/null || true

    # Save rules
    if command -v netfilter-persistent &>/dev/null; then
        netfilter-persistent save >/dev/null 2>&1
    elif [[ -d /etc/iptables ]]; then
        iptables-save > /etc/iptables/rules.v4
    fi
}

# Configure UFW firewall
# Usage: configure_ufw 9999
configure_ufw() {
    local port="${1:-9999}"

    if ! command -v ufw &>/dev/null; then
        return 1
    fi

    ufw allow 443/tcp >/dev/null 2>&1 || true
    ufw allow ${port}/tcp >/dev/null 2>&1 || true
}
