#!/bin/bash
# AutoPaqet Validation Functions
# Reusable input validation logic (shared across Bash platforms)

# Validates an IPv4 address
# Usage: validate_ip "192.168.1.1" && echo "valid"
validate_ip() {
    local ip="$1"

    # Check basic format
    if [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 1
    fi

    # Validate each octet
    IFS='.' read -ra octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if [[ $octet -lt 0 || $octet -gt 255 ]]; then
            return 1
        fi
    done

    return 0
}

# Validates a port number
# Usage: validate_port "9999" && echo "valid"
validate_port() {
    local port="$1"

    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        return 1
    fi

    if [[ $port -lt 1 || $port -gt 65535 ]]; then
        return 1
    fi

    return 0
}

# Validates a server address (IP:PORT format)
# Usage: validate_server_address "192.168.1.1:9999" && echo "valid"
validate_server_address() {
    local addr="$1"

    # Check format
    if [[ ! "$addr" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$ ]]; then
        return 1
    fi

    local ip="${addr%:*}"
    local port="${addr#*:}"

    validate_ip "$ip" || return 1
    validate_port "$port" || return 1

    # Warn if localhost (but still valid)
    if [[ "$ip" == "127.0.0.1" || "$ip" == "0.0.0.0" ]]; then
        echo "Warning: Using localhost/0.0.0.0 is usually incorrect for remote connections." >&2
    fi

    return 0
}

# Validates a secret key
# Usage: validate_secret_key "mykey" 8 && echo "valid"
validate_secret_key() {
    local key="$1"
    local min_length="${2:-1}"

    if [[ -z "$key" ]]; then
        return 1
    fi

    if [[ ${#key} -lt $min_length ]]; then
        return 1
    fi

    # Warn if short
    if [[ ${#key} -lt 8 ]]; then
        echo "Warning: Secret key is very short. Consider using a longer key." >&2
    fi

    return 0
}

# Validates a MAC address
# Usage: validate_mac "aa:bb:cc:dd:ee:ff" && echo "valid"
validate_mac() {
    local mac="$1"

    # Support both : and - separators
    if [[ "$mac" =~ ^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$ ]]; then
        return 0
    fi

    return 1
}

# Validates a network interface name
# Usage: validate_interface "eth0" && echo "valid"
validate_interface() {
    local iface="$1"

    if [[ -z "$iface" ]]; then
        return 1
    fi

    # Check if interface exists
    if ip link show "$iface" &>/dev/null; then
        return 0
    fi

    return 1
}
