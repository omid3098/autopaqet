#!/bin/bash
# AutoPaqet Installation Functions
# Linux-specific dependency installation and build logic

# Configuration
PAQET_REPO="https://github.com/hanselime/paqet.git"
AUTOPAQET_REPO="https://raw.githubusercontent.com/omid3098/autopaqet/main"
GO_VERSION="1.23.5"
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

# Install required packages
# Usage: install_packages
install_packages() {
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        git curl wget nano vim htop net-tools unzip zip \
        software-properties-common build-essential \
        libpcap-dev iptables-persistent
}

# Install Go
# Usage: install_go "1.23.5" "amd64"
install_go() {
    local version="${1:-$GO_VERSION}"
    local arch="${2:-$(detect_arch)}"

    if [[ -z "$arch" ]]; then
        return 1
    fi

    local tarball="go${version}.linux-${arch}.tar.gz"
    local url="https://go.dev/dl/${tarball}"

    wget -q "$url" -O /tmp/go.tar.gz || return 1
    rm -rf /usr/local/go
    tar -C /usr/local -xzf /tmp/go.tar.gz || return 1
    rm /tmp/go.tar.gz

    # Set up PATH
    export PATH=/usr/local/go/bin:$PATH
    echo 'export PATH=/usr/local/go/bin:$PATH' > /etc/profile.d/go.sh

    return 0
}

# Check if Go is installed
# Usage: if check_go; then echo "installed"; fi
check_go() {
    command -v go &>/dev/null
}

# Clone or update the repository
# Usage: clone_repo "/opt/autopaqet"
clone_repo() {
    local dest="${1:-$INSTALL_DIR}"

    if [[ -d "$dest" ]]; then
        # Update existing
        cd "$dest"
        git pull
        return $?
    else
        # Fresh clone
        git clone --depth 1 "$PAQET_REPO" "$dest" 2>/dev/null
        return $?
    fi
}

# Build the binary
# Usage: build_binary "/opt/autopaqet" "/usr/local/bin/autopaqet"
build_binary() {
    local src_dir="${1:-$INSTALL_DIR}"
    local output="${2:-$BINARY_PATH}"
    local force="${3:-false}"

    # Skip if binary exists and not forcing
    if [[ -f "$output" && "$force" != "true" ]]; then
        return 0
    fi

    cd "$src_dir" || return 1

    # Get version info
    local git_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    local build_time=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

    # Build
    CGO_ENABLED=1 go build -v -a -trimpath \
        -ldflags "-s -w -X 'paqet/cmd/version.GitCommit=${git_commit}' -X 'paqet/cmd/version.BuildTime=${build_time}'" \
        -o "$output" ./cmd/main.go 2>/dev/null

    if [[ $? -eq 0 ]]; then
        chmod +x "$output"
        return 0
    fi

    return 1
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

    echo "Installing Go ${GO_VERSION}..."
    install_go "$GO_VERSION" "$arch" || return 1

    echo "Cloning repository..."
    clone_repo "$INSTALL_DIR" || return 1

    echo "Building binary..."
    build_binary "$INSTALL_DIR" "$BINARY_PATH" || return 1

    return 0
}

# Update paqet (git pull + rebuild)
# Usage: update_paqet
update_paqet() {
    if [[ ! -d "$INSTALL_DIR" ]]; then
        echo "Error: Installation directory not found" >&2
        return 1
    fi

    echo "Pulling latest changes..."
    cd "$INSTALL_DIR"
    git pull || return 1

    echo "Rebuilding binary..."
    build_binary "$INSTALL_DIR" "$BINARY_PATH" "true" || return 1

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

    # Remove source
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
    fi

    return 0
}

# Check installation status
# Usage: status=$(check_install_status)
check_install_status() {
    local status=""

    if [[ -d "$INSTALL_DIR" ]]; then
        status="${status}Source: Installed ($INSTALL_DIR)\n"
    else
        status="${status}Source: Not installed\n"
    fi

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

    if check_go; then
        status="${status}Go: Installed ($(go version | awk '{print $3}'))\n"
    else
        status="${status}Go: Not installed\n"
    fi

    echo -e "$status"
}
