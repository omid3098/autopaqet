#!/usr/bin/env bats
# bats-core tests for install.sh

setup() {
    # Create temp directory for test files
    TEST_DIR="$(mktemp -d)"

    # Load the module being tested
    source "$BATS_TEST_DIRNAME/../../lib/bash/install.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# =============================================================================
# detect_arch tests
# =============================================================================

@test "detect_arch returns a non-empty value on supported systems" {
    # On CI (x86_64 Ubuntu), this should return "amd64"
    result=$(detect_arch)
    [ -n "$result" ]
}

# =============================================================================
# get_binary_download_url tests
# =============================================================================

@test "get_binary_download_url constructs correct URL for amd64" {
    result=$(get_binary_download_url "amd64" "v1.0.0")
    [ "$result" = "https://github.com/omid3098/autopaqet/releases/download/v1.0.0/paqet-linux-amd64" ]
}

@test "get_binary_download_url constructs correct URL for arm64" {
    result=$(get_binary_download_url "arm64" "v1.0.0")
    [ "$result" = "https://github.com/omid3098/autopaqet/releases/download/v1.0.0/paqet-linux-arm64" ]
}

@test "get_binary_download_url includes release tag in URL" {
    result=$(get_binary_download_url "amd64" "v2.5.0")
    [[ "$result" == *"v2.5.0"* ]]
}

@test "get_binary_download_url uses correct base URL" {
    result=$(get_binary_download_url "amd64" "v1.0.0")
    [[ "$result" == "https://github.com/omid3098/autopaqet/releases/download/"* ]]
}

@test "get_binary_download_url fails for empty architecture" {
    run get_binary_download_url "" "v1.0.0"
    [ "$status" -eq 1 ]
}

# =============================================================================
# download_binary tests
# =============================================================================

@test "download_binary skips when binary exists and force is false" {
    local binary_path="$TEST_DIR/existing-binary"
    echo "fake binary" > "$binary_path"

    run download_binary "$binary_path" "amd64" "v1.0.0" "false"
    [ "$status" -eq 0 ]
}

@test "download_binary fails for unsupported architecture" {
    local binary_path="$TEST_DIR/binary"
    run download_binary "$binary_path" "" "v1.0.0" "true"
    [ "$status" -eq 1 ]
}

# =============================================================================
# check_install_status tests
# =============================================================================

@test "check_install_status reports binary not installed when missing" {
    BINARY_PATH="$TEST_DIR/nonexistent-binary"
    result=$(check_install_status)
    [[ "$result" == *"Binary: Not installed"* ]]
}

@test "check_install_status reports binary installed when present" {
    BINARY_PATH="$TEST_DIR/test-binary"
    echo "fake" > "$BINARY_PATH"
    result=$(check_install_status)
    [[ "$result" == *"Binary: Installed"* ]]
}

@test "check_install_status reports config not found when missing" {
    CONFIG_DIR="$TEST_DIR/nonexistent-config"
    result=$(check_install_status)
    [[ "$result" == *"Config: Not found"* ]]
}

@test "check_install_status does not reference Go" {
    BINARY_PATH="$TEST_DIR/nonexistent"
    CONFIG_DIR="$TEST_DIR/nonexistent-config"
    result=$(check_install_status)
    [[ "$result" != *"Go:"* ]]
}

# =============================================================================
# install_packages content tests
# =============================================================================

@test "install_packages function does not reference build-essential" {
    # Check that the function definition doesn't include build-essential
    func_body=$(type install_packages)
    [[ "$func_body" != *"build-essential"* ]]
}

@test "install_packages function does not reference git package" {
    func_body=$(type install_packages)
    # Check it doesn't have 'git' as a standalone package (not part of other words)
    [[ "$func_body" != *" git "* ]]
}

@test "install_packages function includes libpcap0.8" {
    func_body=$(type install_packages)
    [[ "$func_body" == *"libpcap0.8"* ]]
}

@test "install_packages function does not reference libpcap-dev" {
    func_body=$(type install_packages)
    [[ "$func_body" != *"libpcap-dev"* ]]
}
