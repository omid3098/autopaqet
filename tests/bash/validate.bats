#!/usr/bin/env bats
# bats-core tests for validate.sh

setup() {
    # Load the module being tested
    source "$BATS_TEST_DIRNAME/../../lib/bash/validate.sh"
}

# =============================================================================
# validate_ip tests
# =============================================================================

@test "validate_ip accepts valid IP" {
    run validate_ip "192.168.1.1"
    [ "$status" -eq 0 ]
}

@test "validate_ip accepts boundary values 0.0.0.0" {
    run validate_ip "0.0.0.0"
    [ "$status" -eq 0 ]
}

@test "validate_ip accepts boundary values 255.255.255.255" {
    run validate_ip "255.255.255.255"
    [ "$status" -eq 0 ]
}

@test "validate_ip accepts localhost" {
    run validate_ip "127.0.0.1"
    [ "$status" -eq 0 ]
}

@test "validate_ip rejects octet over 255" {
    run validate_ip "256.1.1.1"
    [ "$status" -eq 1 ]
}

@test "validate_ip rejects too many octets" {
    run validate_ip "1.1.1.1.1"
    [ "$status" -eq 1 ]
}

@test "validate_ip rejects too few octets" {
    run validate_ip "1.1.1"
    [ "$status" -eq 1 ]
}

@test "validate_ip rejects non-numeric" {
    run validate_ip "a.b.c.d"
    [ "$status" -eq 1 ]
}

@test "validate_ip rejects empty string" {
    run validate_ip ""
    [ "$status" -eq 1 ]
}

# =============================================================================
# validate_port tests
# =============================================================================

@test "validate_port accepts valid port 80" {
    run validate_port "80"
    [ "$status" -eq 0 ]
}

@test "validate_port accepts minimum port 1" {
    run validate_port "1"
    [ "$status" -eq 0 ]
}

@test "validate_port accepts maximum port 65535" {
    run validate_port "65535"
    [ "$status" -eq 0 ]
}

@test "validate_port rejects port 0" {
    run validate_port "0"
    [ "$status" -eq 1 ]
}

@test "validate_port rejects port over 65535" {
    run validate_port "65536"
    [ "$status" -eq 1 ]
}

@test "validate_port rejects non-numeric" {
    run validate_port "abc"
    [ "$status" -eq 1 ]
}

@test "validate_port rejects empty string" {
    run validate_port ""
    [ "$status" -eq 1 ]
}

# =============================================================================
# validate_server_address tests
# =============================================================================

@test "validate_server_address accepts valid address" {
    run validate_server_address "192.168.1.1:9999"
    [ "$status" -eq 0 ]
}

@test "validate_server_address accepts common addresses" {
    run validate_server_address "10.0.0.1:8080"
    [ "$status" -eq 0 ]
}

@test "validate_server_address rejects missing port" {
    run validate_server_address "192.168.1.1"
    [ "$status" -eq 1 ]
}

@test "validate_server_address rejects missing IP" {
    run validate_server_address ":9999"
    [ "$status" -eq 1 ]
}

@test "validate_server_address rejects invalid IP" {
    run validate_server_address "999.168.1.1:9999"
    [ "$status" -eq 1 ]
}

@test "validate_server_address rejects invalid port" {
    run validate_server_address "192.168.1.1:99999"
    [ "$status" -eq 1 ]
}

@test "validate_server_address rejects hostname" {
    run validate_server_address "localhost:9999"
    [ "$status" -eq 1 ]
}

@test "validate_server_address warns on localhost but succeeds" {
    run validate_server_address "127.0.0.1:9999"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning"* ]]
}

# =============================================================================
# validate_secret_key tests
# =============================================================================

@test "validate_secret_key accepts valid key" {
    run validate_secret_key "mysecretkey"
    [ "$status" -eq 0 ]
}

@test "validate_secret_key accepts long key" {
    run validate_secret_key "this-is-a-very-long-secret-key"
    [ "$status" -eq 0 ]
}

@test "validate_secret_key rejects empty key" {
    run validate_secret_key ""
    [ "$status" -eq 1 ]
}

@test "validate_secret_key respects minimum length" {
    run validate_secret_key "short" 10
    [ "$status" -eq 1 ]
}

@test "validate_secret_key warns on short key but succeeds" {
    run validate_secret_key "abc"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Warning"* ]]
}

# =============================================================================
# validate_mac tests
# =============================================================================

@test "validate_mac accepts colon-separated lowercase" {
    run validate_mac "aa:bb:cc:dd:ee:ff"
    [ "$status" -eq 0 ]
}

@test "validate_mac accepts colon-separated uppercase" {
    run validate_mac "AA:BB:CC:DD:EE:FF"
    [ "$status" -eq 0 ]
}

@test "validate_mac accepts hyphen-separated" {
    run validate_mac "aa-bb-cc-dd-ee-ff"
    [ "$status" -eq 0 ]
}

@test "validate_mac rejects wrong length" {
    run validate_mac "aa:bb:cc:dd:ee"
    [ "$status" -eq 1 ]
}

@test "validate_mac rejects invalid characters" {
    run validate_mac "gg:hh:ii:jj:kk:ll"
    [ "$status" -eq 1 ]
}

@test "validate_mac rejects no separator" {
    run validate_mac "aabbccddeeff"
    [ "$status" -eq 1 ]
}

@test "validate_mac rejects empty string" {
    run validate_mac ""
    [ "$status" -eq 1 ]
}
