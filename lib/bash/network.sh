#!/bin/bash
# AutoPaqet Network Detection Functions
# Linux-specific network auto-detection

# Detect the default network interface
# Usage: IFACE=$(detect_interface)
detect_interface() {
    ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -1
}

# Detect the server/local IP address
# Usage: IP=$(detect_local_ip)
detect_local_ip() {
    ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -1
}

# Detect the gateway IP address
# Usage: GATEWAY=$(detect_gateway_ip)
detect_gateway_ip() {
    ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="via") print $(i+1)}' | head -1
}

# Detect the gateway MAC address (pings first to populate ARP)
# Usage: MAC=$(detect_gateway_mac "$GATEWAY_IP")
detect_gateway_mac() {
    local gateway_ip="$1"

    if [[ -z "$gateway_ip" ]]; then
        return 1
    fi

    # Ping to populate ARP cache
    ping -c 1 -W 1 "$gateway_ip" >/dev/null 2>&1 || true

    # Get MAC from neighbor table
    local mac=$(ip neigh show "$gateway_ip" 2>/dev/null | awk '{print $5}' | head -1)

    if [[ -z "$mac" || "$mac" == "FAILED" ]]; then
        return 1
    fi

    echo "$mac"
}

# Get complete network configuration
# Usage: eval "$(get_network_config)" && echo $INTERFACE $LOCAL_IP $GATEWAY_IP $GATEWAY_MAC
get_network_config() {
    local interface=$(detect_interface)
    local local_ip=$(detect_local_ip)
    local gateway_ip=$(detect_gateway_ip)
    local gateway_mac=""

    if [[ -n "$gateway_ip" ]]; then
        gateway_mac=$(detect_gateway_mac "$gateway_ip")
    fi

    cat << EOF
INTERFACE="$interface"
LOCAL_IP="$local_ip"
GATEWAY_IP="$gateway_ip"
GATEWAY_MAC="$gateway_mac"
EOF
}

# Validate network configuration is complete
# Usage: validate_network_config && echo "ready"
validate_network_config() {
    local interface=$(detect_interface)
    local local_ip=$(detect_local_ip)
    local gateway_ip=$(detect_gateway_ip)

    [[ -z "$interface" ]] && return 1
    [[ -z "$local_ip" ]] && return 1
    [[ -z "$gateway_ip" ]] && return 1

    local gateway_mac=$(detect_gateway_mac "$gateway_ip")
    [[ -z "$gateway_mac" || "$gateway_mac" == "FAILED" ]] && return 1

    return 0
}

# Format network info for display
# Usage: format_network_info "$INTERFACE" "$LOCAL_IP" "$GATEWAY_IP" "$GATEWAY_MAC"
format_network_info() {
    local interface="$1"
    local local_ip="$2"
    local gateway_ip="$3"
    local gateway_mac="$4"

    echo "Interface:   $interface"
    echo "Local IP:    $local_ip"
    echo "Gateway IP:  $gateway_ip"
    echo "Gateway MAC: $gateway_mac"
}

# Check if libpcap is installed
# Usage: check_libpcap && echo "installed"
check_libpcap() {
    if [[ -f /usr/lib/x86_64-linux-gnu/libpcap.so ]] || \
       [[ -f /usr/lib/libpcap.so ]] || \
       dpkg -l libpcap-dev &>/dev/null; then
        return 0
    fi
    return 1
}
