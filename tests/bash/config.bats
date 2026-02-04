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
