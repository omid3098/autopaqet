#!/bin/bash
# AutoPaqet Logging Functions
# Centralized logging infrastructure for Bash scripts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Log file path (set via init_logging)
LOG_FILE=""
LOGGING_INITIALIZED=false

# Initialize logging
# Usage: init_logging "/var/log/autopaqet/setup.log"
init_logging() {
    local log_dir="$1"
    local log_name="${2:-setup.log}"

    # Create log directory if needed
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir"
    fi

    LOG_FILE="$log_dir/$log_name"

    # Clear log file for new session
    echo "" > "$LOG_FILE"

    LOGGING_INITIALIZED=true

    write_log "INFO" "========== AUTOPAQET LOG =========="
    write_log "INFO" "Session started"
    write_log "DEBUG" "Log file: $LOG_FILE"
}

# Write to log file
# Usage: write_log "INFO" "message"
write_log() {
    local level="$1"
    local message="$2"

    if [[ "$LOGGING_INITIALIZED" != "true" || -z "$LOG_FILE" ]]; then
        return
    fi

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Get log file path
get_log_file() {
    echo "$LOG_FILE"
}

# Info message (console + log)
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    write_log "INFO" "$1"
}

# Success message (console + log)
success() {
    echo -e "${GREEN}[OK]${NC} $1"
    write_log "SUCCESS" "$1"
}

# Warning message (console + log)
warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    write_log "WARN" "$1"
}

# Error message and exit (console + log)
error() {
    echo -e "${RED}[ERROR]${NC} $1"
    write_log "ERROR" "$1"
    write_log "ERROR" "Setup failed. See log for details."

    if [[ -n "$LOG_FILE" ]]; then
        echo ""
        echo -e "${YELLOW}If setup failed, please send this file:${NC}"
        echo "  $LOG_FILE"
    fi

    exit 1
}

# Error message without exit
error_noexit() {
    echo -e "${RED}[ERROR]${NC} $1"
    write_log "ERROR" "$1"
}

# Debug message (log only by default)
debug() {
    write_log "DEBUG" "$1"
}

# Command logging
log_command() {
    local cmd="$1"
    local desc="${2:-}"

    write_log "COMMAND" "Executing: $cmd"
    if [[ -n "$desc" ]]; then
        write_log "DEBUG" "Description: $desc"
    fi
}

# Log system information header
log_system_info() {
    write_log "INFO" "Hostname: $(hostname)"
    write_log "INFO" "Username: $(whoami)"
    write_log "INFO" "OS: $(uname -s) $(uname -r)"
    write_log "INFO" "Architecture: $(uname -m)"
    write_log "INFO" "Working Directory: $(pwd)"
    write_log "DEBUG" "PATH: $PATH"
}

# Print a horizontal separator
print_separator() {
    local char="${1:-=}"
    local width="${2:-60}"
    printf '%*s\n' "$width" '' | tr ' ' "$char"
}

# Print a banner
print_banner() {
    local title="$1"
    local color="${2:-$CYAN}"

    echo -e "${color}$(print_separator '=')${NC}"
    echo -e "${color}         $title${NC}"
    echo -e "${color}$(print_separator '=')${NC}"
}
