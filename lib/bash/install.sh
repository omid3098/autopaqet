#!/bin/bash
# AutoPaqet Installation Functions
# Linux-specific dependency installation and binary download logic

# Configuration
AUTOPAQET_REPO="https://raw.githubusercontent.com/omid3098/autopaqet/main"
RELEASE_BASE_URL="https://github.com/omid3098/autopaqet/releases/download"
RELEASE_TAG="v1.0.0"
INSTALL_DIR="/opt/autopaqet"
CONFIG_DIR="/etc/autopaqet"
BINARY_PATH="/usr/local/bin/autopaqet"

# Check if running as root
# Usage: if check_root; then echo "root"; fi
check_root() {
    [[ $EUID -eq 0 ]]
}

# Require root privileges
# Usage: require_root
require_root() {
    if ! check_root; then
        echo "Error: This script must be run as root" >&2
        exit 1
    fi
}

# Detect system architecture
# Usage: arch=$(detect_arch)
detect_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64) echo "amd64" ;;
        aarch64) echo "arm64" ;;
        armv7l) echo "armv6l" ;;
        *) echo "" ;;
    esac
}

# Update system packages
# Usage: update_system
update_system() {
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq
}

# Install required packages (runtime only, no build tools)
# Usage: install_packages
install_packages() {
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        curl wget nano vim htop net-tools unzip zip \
        software-properties-common \
        libpcap0.8 iptables-persistent
}

# Construct the download URL for a paqet binary
# Usage: url=$(get_binary_download_url "amd64" "v1.0.0")
get_binary_download_url() {
    local arch="${1-$(detect_arch)}"
    local tag="${2:-$RELEASE_TAG}"

    if [[ -z "$arch" ]]; then
        return 1
    fi

    echo "${RELEASE_BASE_URL}/${tag}/paqet-linux-${arch}"
    return 0
}

# Download pre-built binary from GitHub Releases
# Usage: download_binary "/usr/local/bin/autopaqet" "amd64" "v1.0.0"
download_binary() {
    local output="${1:-$BINARY_PATH}"
    local arch="${2-$(detect_arch)}"
    local tag="${3:-$RELEASE_TAG}"
    local force="${4:-false}"

    # Skip if binary exists and not forcing
    if [[ -f "$output" && "$force" != "true" ]]; then
        return 0
    fi

    if [[ -z "$arch" ]]; then
        echo "Error: Unsupported architecture: $(uname -m)" >&2
        return 1
    fi

    local url
    url=$(get_binary_download_url "$arch" "$tag")
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to construct download URL" >&2
        return 1
    fi

    local dest_dir
    dest_dir=$(dirname "$output")
    if [[ ! -d "$dest_dir" ]]; then
        mkdir -p "$dest_dir" || return 1
    fi

    if command -v curl &>/dev/null; then
        curl -fsSL "$url" -o "$output" || return 1
    elif command -v wget &>/dev/null; then
        wget -q "$url" -O "$output" || return 1
    else
        echo "Error: Neither curl nor wget found" >&2
        return 1
    fi

    chmod +x "$output"
    return 0
}

# Full installation sequence
# Usage: do_full_install
do_full_install() {
    require_root

    local arch=$(detect_arch)
    if [[ -z "$arch" ]]; then
        echo "Error: Unsupported architecture: $(uname -m)" >&2
        return 1
    fi

    echo "Updating system packages..."
    update_system || return 1

    echo "Installing required packages..."
    install_packages || return 1

    echo "Downloading pre-built binary..."
    download_binary "$BINARY_PATH" "$arch" "$RELEASE_TAG" || return 1

    return 0
}

# Update paqet (download latest binary)
# Usage: update_paqet
update_paqet() {
    echo "Downloading latest binary..."
    download_binary "$BINARY_PATH" "$(detect_arch)" "$RELEASE_TAG" "true" || return 1

    return 0
}

# Update autopaqet scripts from GitHub
# Usage: update_autopaqet "/path/to/save"
update_autopaqet() {
    local dest="${1:-.}"

    local files=(
        "autopaqet-server.sh"
        "autopaqet-uninstall.sh"
    )

    for file in "${files[@]}"; do
        local url="${AUTOPAQET_REPO}/${file}"
        wget -q "$url" -O "${dest}/${file}" || return 1
        chmod +x "${dest}/${file}"
    done

    return 0
}

# Uninstall autopaqet
# Usage: do_uninstall
do_uninstall() {
    require_root

    # Source service module if available
    local script_dir=$(dirname "${BASH_SOURCE[0]}")
    if [[ -f "${script_dir}/service.sh" ]]; then
        source "${script_dir}/service.sh"
        service_remove
    fi

    # Remove binary
    if [[ -f "$BINARY_PATH" ]]; then
        rm -f "$BINARY_PATH"
    fi

    # Remove config
    if [[ -d "$CONFIG_DIR" ]]; then
        rm -rf "$CONFIG_DIR"
    fi

    # Remove source directory if it exists
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
    fi

    return 0
}

# Check installation status
# Usage: status=$(check_install_status)
check_install_status() {
    local status=""

    if [[ -f "$BINARY_PATH" ]]; then
        status="${status}Binary: Installed ($BINARY_PATH)\n"
    else
        status="${status}Binary: Not installed\n"
    fi

    if [[ -f "${CONFIG_DIR}/server.yaml" ]]; then
        status="${status}Config: Exists (${CONFIG_DIR}/server.yaml)\n"
    else
        status="${status}Config: Not found\n"
    fi

    echo -e "$status"
}
