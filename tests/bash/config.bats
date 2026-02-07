#!/usr/bin/env bats
# bats-core tests for config.sh TCP local_flag functionality

setup() {
    # Create temp directory for test files
    TEST_DIR="$(mktemp -d)"
    TEST_CONFIG="$TEST_DIR/test-config.yaml"

    # Create a test config file
    cat > "$TEST_CONFIG" << 'EOF'
network:
  interface: "eth0"
  tcp:
    local_flag: ["S"]
    remote_flag: ["PA"]
  ipv4:
    router_mac: "aa:bb:cc:dd:ee:ff"
EOF
}

teardown() {
    rm -rf "$TEST_DIR"
}

# =============================================================================
# TCP local_flag extraction tests
# =============================================================================

@test "extract local_flag value S" {
    result=$(grep "local_flag:" "$TEST_CONFIG" | sed 's/.*\["\([^"]*\)"\].*/\1/')
    [ "$result" = "S" ]
}

@test "extract local_flag value PA" {
    sed -i 's/\(local_flag:\s*\["\)[^"]*/\1PA/' "$TEST_CONFIG"
    result=$(grep "local_flag:" "$TEST_CONFIG" | sed 's/.*\["\([^"]*\)"\].*/\1/')
    [ "$result" = "PA" ]
}

@test "extract local_flag value A" {
    sed -i 's/\(local_flag:\s*\["\)[^"]*/\1A/' "$TEST_CONFIG"
    result=$(grep "local_flag:" "$TEST_CONFIG" | sed 's/.*\["\([^"]*\)"\].*/\1/')
    [ "$result" = "A" ]
}

# =============================================================================
# TCP local_flag update tests
# =============================================================================

@test "update local_flag from S to PA" {
    sed -i 's/\(local_flag:\s*\["\)[^"]*/\1PA/' "$TEST_CONFIG"
    grep -q 'local_flag: \["PA"\]' "$TEST_CONFIG"
}

@test "update local_flag from S to A" {
    sed -i 's/\(local_flag:\s*\["\)[^"]*/\1A/' "$TEST_CONFIG"
    grep -q 'local_flag: \["A"\]' "$TEST_CONFIG"
}

@test "update local_flag from PA to S" {
    # First set to PA
    sed -i 's/\(local_flag:\s*\["\)[^"]*/\1PA/' "$TEST_CONFIG"
    # Now update to S
    sed -i 's/\(local_flag:\s*\["\)[^"]*/\1S/' "$TEST_CONFIG"
    grep -q 'local_flag: \["S"\]' "$TEST_CONFIG"
}

# =============================================================================
# Preservation tests
# =============================================================================

@test "preserve remote_flag when updating local_flag" {
    sed -i 's/\(local_flag:\s*\["\)[^"]*/\1PA/' "$TEST_CONFIG"
    grep -q 'remote_flag: \["PA"\]' "$TEST_CONFIG"
}

@test "preserve interface when updating local_flag" {
    sed -i 's/\(local_flag:\s*\["\)[^"]*/\1A/' "$TEST_CONFIG"
    grep -q 'interface: "eth0"' "$TEST_CONFIG"
}

@test "preserve router_mac when updating local_flag" {
    sed -i 's/\(local_flag:\s*\["\)[^"]*/\1PA/' "$TEST_CONFIG"
    grep -q 'router_mac: "aa:bb:cc:dd:ee:ff"' "$TEST_CONFIG"
}

# =============================================================================
# Config generation tests (sourcing lib/bash/config.sh)
# =============================================================================

@test "create_server_config uses default local_flag PA" {
    source "$BATS_TEST_DIRNAME/../../lib/bash/config.sh"
    result=$(create_server_config "eth0" "1.2.3.4" "aa:bb:cc:dd:ee:ff" "443" "secret")
    [[ "$result" == *'local_flag: ["PA"]'* ]]
}

@test "create_server_config uses default kcp mode fast3" {
    source "$BATS_TEST_DIRNAME/../../lib/bash/config.sh"
    result=$(create_server_config "eth0" "1.2.3.4" "aa:bb:cc:dd:ee:ff" "443" "secret")
    [[ "$result" == *'mode: "fast3"'* ]]
}

@test "create_server_config uses default conn 2" {
    source "$BATS_TEST_DIRNAME/../../lib/bash/config.sh"
    result=$(create_server_config "eth0" "1.2.3.4" "aa:bb:cc:dd:ee:ff" "443" "secret")
    [[ "$result" == *'conn: 2'* ]]
}

@test "create_server_config uses custom local_flag S" {
    source "$BATS_TEST_DIRNAME/../../lib/bash/config.sh"
    result=$(create_server_config "eth0" "1.2.3.4" "aa:bb:cc:dd:ee:ff" "443" "secret" "S")
    [[ "$result" == *'local_flag: ["S"]'* ]]
}

@test "create_server_config uses custom kcp_mode normal" {
    source "$BATS_TEST_DIRNAME/../../lib/bash/config.sh"
    result=$(create_server_config "eth0" "1.2.3.4" "aa:bb:cc:dd:ee:ff" "443" "secret" "PA" "normal")
    [[ "$result" == *'mode: "normal"'* ]]
}

@test "create_server_config uses custom conn 4" {
    source "$BATS_TEST_DIRNAME/../../lib/bash/config.sh"
    result=$(create_server_config "eth0" "1.2.3.4" "aa:bb:cc:dd:ee:ff" "443" "secret" "PA" "fast3" "4")
    [[ "$result" == *'conn: 4'* ]]
}

@test "create_server_config rejects invalid local_flag" {
    source "$BATS_TEST_DIRNAME/../../lib/bash/config.sh"
    run create_server_config "eth0" "1.2.3.4" "aa:bb:cc:dd:ee:ff" "443" "secret" "INVALID"
    [ "$status" -eq 1 ]
}

@test "create_server_config rejects invalid kcp_mode" {
    source "$BATS_TEST_DIRNAME/../../lib/bash/config.sh"
    run create_server_config "eth0" "1.2.3.4" "aa:bb:cc:dd:ee:ff" "443" "secret" "PA" "turbo"
    [ "$status" -eq 1 ]
}

@test "create_client_config uses default flags PA/PA" {
    source "$BATS_TEST_DIRNAME/../../lib/bash/config.sh"
    result=$(create_client_config "eth0" "192.168.1.100" "aa:bb:cc:dd:ee:ff" "1.2.3.4:443" "secret")
    [[ "$result" == *'local_flag: ["PA"]'* ]]
    [[ "$result" == *'remote_flag: ["PA"]'* ]]
}

@test "create_client_config uses default kcp mode fast3" {
    source "$BATS_TEST_DIRNAME/../../lib/bash/config.sh"
    result=$(create_client_config "eth0" "192.168.1.100" "aa:bb:cc:dd:ee:ff" "1.2.3.4:443" "secret")
    [[ "$result" == *'mode: "fast3"'* ]]
}

@test "create_client_config uses default conn 2" {
    source "$BATS_TEST_DIRNAME/../../lib/bash/config.sh"
    result=$(create_client_config "eth0" "192.168.1.100" "aa:bb:cc:dd:ee:ff" "1.2.3.4:443" "secret")
    [[ "$result" == *'conn: 2'* ]]
}

@test "create_client_config applies custom local_flag S" {
    source "$BATS_TEST_DIRNAME/../../lib/bash/config.sh"
    result=$(create_client_config "eth0" "192.168.1.100" "aa:bb:cc:dd:ee:ff" "1.2.3.4:443" "secret" "0" "S")
    [[ "$result" == *'local_flag: ["S"]'* ]]
}

@test "create_client_config applies custom remote_flag S" {
    source "$BATS_TEST_DIRNAME/../../lib/bash/config.sh"
    result=$(create_client_config "eth0" "192.168.1.100" "aa:bb:cc:dd:ee:ff" "1.2.3.4:443" "secret" "0" "PA" "S")
    [[ "$result" == *'remote_flag: ["S"]'* ]]
}

@test "create_client_config applies custom kcp_mode normal" {
    source "$BATS_TEST_DIRNAME/../../lib/bash/config.sh"
    result=$(create_client_config "eth0" "192.168.1.100" "aa:bb:cc:dd:ee:ff" "1.2.3.4:443" "secret" "0" "PA" "PA" "normal")
    [[ "$result" == *'mode: "normal"'* ]]
}

@test "create_client_config applies custom conn 1" {
    source "$BATS_TEST_DIRNAME/../../lib/bash/config.sh"
    result=$(create_client_config "eth0" "192.168.1.100" "aa:bb:cc:dd:ee:ff" "1.2.3.4:443" "secret" "0" "PA" "PA" "fast3" "1")
    [[ "$result" == *'conn: 1'* ]]
}

@test "create_client_config rejects invalid local_flag" {
    source "$BATS_TEST_DIRNAME/../../lib/bash/config.sh"
    run create_client_config "eth0" "192.168.1.100" "aa:bb:cc:dd:ee:ff" "1.2.3.4:443" "secret" "0" "INVALID"
    [ "$status" -eq 1 ]
}

@test "create_client_config rejects invalid remote_flag" {
    source "$BATS_TEST_DIRNAME/../../lib/bash/config.sh"
    run create_client_config "eth0" "192.168.1.100" "aa:bb:cc:dd:ee:ff" "1.2.3.4:443" "secret" "0" "PA" "INVALID"
    [ "$status" -eq 1 ]
}

@test "create_client_config rejects invalid kcp_mode" {
    source "$BATS_TEST_DIRNAME/../../lib/bash/config.sh"
    run create_client_config "eth0" "192.168.1.100" "aa:bb:cc:dd:ee:ff" "1.2.3.4:443" "secret" "0" "PA" "PA" "turbo"
    [ "$status" -eq 1 ]
}
