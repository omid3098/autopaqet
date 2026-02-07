#!/bin/bash
# AutoPaqet Configuration Management
# YAML configuration file handling (shared across Bash platforms)

# Default configuration paths
DEFAULT_SERVER_CONFIG="/etc/autopaqet/server.yaml"
DEFAULT_CLIENT_CONFIG="$HOME/.autopaqet/client.yaml"

# Create server configuration content
# Usage: content=$(create_server_config "$INTERFACE" "$SERVER_IP" "$ROUTER_MAC" "$PORT" "$SECRET_KEY" "$LOCAL_FLAG" "$KCP_MODE" "$CONN")
create_server_config() {
    local interface="$1"
    local server_ip="$2"
    local router_mac="$3"
    local port="${4:-9999}"
    local secret_key="$5"
    local local_flag="${6:-PA}"
    local kcp_mode="${7:-fast}"
    local conn="${8:-1}"

    # Validate local_flag
    case "$local_flag" in
        S|PA|A) ;;
        *) echo "Error: Invalid local_flag '$local_flag'. Must be S, PA, or A." >&2; return 1 ;;
    esac

    # Validate kcp_mode
    case "$kcp_mode" in
        normal|fast|fast2|fast3|manual) ;;
        *) echo "Error: Invalid kcp_mode '$kcp_mode'. Must be normal, fast, fast2, fast3, or manual." >&2; return 1 ;;
    esac

    cat << EOF
# AutoPaqet Server Configuration
# Generated on $(date -u '+%Y-%m-%d %H:%M:%S UTC')
role: "server"

log:
  level: "info"

listen:
  addr: ":${port}"

network:
  interface: "${interface}"
  ipv4:
    addr: "${server_ip}:${port}"
    router_mac: "${router_mac}"
  tcp:
    local_flag: ["${local_flag}"]

transport:
  protocol: "kcp"
  conn: ${conn}
  kcp:
    mode: "${kcp_mode}"
    key: "${secret_key}"
    block: "aes"
EOF
}

# Create client configuration content
# Usage: content=$(create_client_config "$INTERFACE" "$LOCAL_IP" "$ROUTER_MAC" "$SERVER_ADDR" "$SECRET_KEY" "$LOCAL_PORT" "$LOCAL_FLAG" "$REMOTE_FLAG" "$KCP_MODE" "$CONN")
create_client_config() {
    local interface="$1"
    local local_ip="$2"
    local router_mac="$3"
    local server_addr="$4"
    local secret_key="$5"
    local local_port="${6:-0}"  # 0 means random
    local local_flag="${7:-PA}"
    local remote_flag="${8:-PA}"
    local kcp_mode="${9:-fast}"
    local conn="${10:-1}"

    # Validate flags
    case "$local_flag" in
        S|PA|A) ;;
        *) echo "Error: Invalid local_flag '$local_flag'. Must be S, PA, or A." >&2; return 1 ;;
    esac
    case "$remote_flag" in
        S|PA|A) ;;
        *) echo "Error: Invalid remote_flag '$remote_flag'. Must be S, PA, or A." >&2; return 1 ;;
    esac
    case "$kcp_mode" in
        normal|fast|fast2|fast3|manual) ;;
        *) echo "Error: Invalid kcp_mode '$kcp_mode'. Must be normal, fast, fast2, fast3, or manual." >&2; return 1 ;;
    esac

    # Generate random port if not specified
    if [[ "$local_port" == "0" ]]; then
        local_port=$((RANDOM % 55000 + 10000))
    fi

    cat << EOF
role: "client"

log:
  level: "info"

socks5:
  - listen: "127.0.0.1:1080"

network:
  interface: "${interface}"
  ipv4:
    addr: "${local_ip}:${local_port}"
    router_mac: "${router_mac}"
  tcp:
    local_flag: ["${local_flag}"]
    remote_flag: ["${remote_flag}"]

server:
  addr: "${server_addr}"

transport:
  protocol: "kcp"
  conn: ${conn}
  kcp:
    mode: "${kcp_mode}"
    key: "${secret_key}"
    block: "aes"
EOF
}

# Save configuration to file
# Usage: save_config "/etc/autopaqet/server.yaml" "$content"
save_config() {
    local path="$1"
    local content="$2"

    # Create directory if needed
    local dir=$(dirname "$path")
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
    fi

    echo "$content" > "$path"
}

# Check if configuration file exists
# Usage: if config_exists "/etc/autopaqet/server.yaml"; then echo "exists"; fi
config_exists() {
    local path="$1"
    [[ -f "$path" ]]
}

# Get a value from YAML config (simple regex-based)
# Usage: value=$(get_config_value "/path/to/config.yaml" "server.addr")
get_config_value() {
    local path="$1"
    local key="$2"

    if [[ ! -f "$path" ]]; then
        return 1
    fi

    local content=$(cat "$path")

    case "$key" in
        "server.addr")
            echo "$content" | grep -A1 "^server:" | grep "addr:" | sed 's/.*addr:\s*"\([^"]*\)".*/\1/'
            ;;
        "listen.addr")
            echo "$content" | grep -A1 "^listen:" | grep "addr:" | sed 's/.*addr:\s*"\([^"]*\)".*/\1/'
            ;;
        "transport.kcp.key")
            echo "$content" | grep "key:" | sed 's/.*key:\s*"\([^"]*\)".*/\1/'
            ;;
        "network.interface")
            echo "$content" | grep "interface:" | head -1 | sed 's/.*interface:\s*"\([^"]*\)".*/\1/'
            ;;
        "network.ipv4.router_mac")
            echo "$content" | grep "router_mac:" | sed 's/.*router_mac:\s*"\([^"]*\)".*/\1/'
            ;;
        *)
            # Generic single-line extraction
            echo "$content" | grep "${key}:" | sed "s/.*${key}:\s*\"\([^\"]*\)\".*/\1/"
            ;;
    esac
}

# Set a value in YAML config (simple sed-based)
# Usage: set_config_value "/path/to/config.yaml" "server.addr" "1.2.3.4:9999"
set_config_value() {
    local path="$1"
    local key="$2"
    local value="$3"

    if [[ ! -f "$path" ]]; then
        return 1
    fi

    case "$key" in
        "transport.kcp.key")
            sed -i "s/\(key:\s*\)\"[^\"]*\"/\1\"${value}\"/" "$path"
            ;;
        "listen.addr")
            sed -i "s/\(addr:\s*\)\"[^\"]*\"/\1\"${value}\"/" "$path"
            ;;
        *)
            # Generic replacement
            sed -i "s/\(${key}:\s*\)\"[^\"]*\"/\1\"${value}\"/" "$path"
            ;;
    esac
}

# Get configuration summary
# Usage: summary=$(get_config_summary "/etc/autopaqet/server.yaml")
get_config_summary() {
    local path="$1"

    if [[ ! -f "$path" ]]; then
        echo "Configuration file not found: $path"
        return 1
    fi

    local listen=$(get_config_value "$path" "listen.addr")
    local interface=$(get_config_value "$path" "network.interface")
    local router_mac=$(get_config_value "$path" "network.ipv4.router_mac")
    local key=$(get_config_value "$path" "transport.kcp.key")

    echo "Configuration: $path"
    echo "  Listen:      $listen"
    echo "  Interface:   $interface"
    echo "  Router MAC:  $router_mac"
    echo "  Has Key:     $(if [[ -n "$key" ]]; then echo "Yes"; else echo "No"; fi)"
}

# Generate a new secret key using the binary
# Usage: key=$(generate_secret_key "/usr/local/bin/autopaqet")
generate_secret_key() {
    local binary="$1"

    if [[ ! -x "$binary" ]]; then
        return 1
    fi

    "$binary" secret
}

# Backup configuration file
# Usage: backup_config "/etc/autopaqet/server.yaml"
backup_config() {
    local path="$1"
    local backup_dir="${2:-/tmp}"

    if [[ ! -f "$path" ]]; then
        return 1
    fi

    local filename=$(basename "$path")
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_path="${backup_dir}/${filename}.${timestamp}.bak"

    cp "$path" "$backup_path"
    echo "$backup_path"
}
