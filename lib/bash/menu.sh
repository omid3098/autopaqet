#!/bin/bash
# AutoPaqet Menu System
# Terminal-based interactive menu (shared across Bash platforms)

# Source logging if available
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/logging.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"
fi

# Show a menu and return the selection
# Usage: choice=$(show_menu "Title" "Option 1" "Option 2" "Option 3")
show_menu() {
    local title="$1"
    shift
    local options=("$@")

    clear
    echo -e "${CYAN:-}=============================================${NC:-}"
    echo -e "${CYAN:-}         $title${NC:-}"
    echo -e "${CYAN:-}=============================================${NC:-}"
    echo ""

    local i=1
    for opt in "${options[@]}"; do
        echo "  [$i] $opt"
        ((i++))
    done

    echo ""
    echo -e "  ${YELLOW:-}[0] Exit${NC:-}"
    echo ""

    read -p "Select option: " choice

    # Validate input
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        if [[ $choice -ge 0 && $choice -le ${#options[@]} ]]; then
            echo "$choice"
            return 0
        fi
    fi

    echo "-1"
    return 1
}

# Show a submenu (same as show_menu but with "Back" instead of "Exit")
# Usage: choice=$(show_submenu "Title" "Option 1" "Option 2")
show_submenu() {
    local title="$1"
    shift
    local options=("$@")

    clear
    echo -e "${CYAN:-}=============================================${NC:-}"
    echo -e "${CYAN:-}         $title${NC:-}"
    echo -e "${CYAN:-}=============================================${NC:-}"
    echo ""

    local i=1
    for opt in "${options[@]}"; do
        echo "  [$i] $opt"
        ((i++))
    done

    echo ""
    echo -e "  ${YELLOW:-}[0] Back${NC:-}"
    echo ""

    read -p "Select option: " choice

    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        if [[ $choice -ge 0 && $choice -le ${#options[@]} ]]; then
            echo "$choice"
            return 0
        fi
    fi

    echo "-1"
    return 1
}

# Show a Y/n confirmation prompt
# Usage: if confirm "Continue?"; then echo "yes"; fi
# Usage: if confirm "Continue?" false; then echo "yes"; fi  # default No
confirm() {
    local message="$1"
    local default_yes="${2:-true}"

    local prompt
    if [[ "$default_yes" == "true" ]]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi

    read -p "$message $prompt " response

    if [[ -z "$response" ]]; then
        if [[ "$default_yes" == "true" ]]; then
            return 0
        else
            return 1
        fi
    fi

    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    fi

    return 1
}

# Show an input prompt with optional default
# Usage: value=$(input_prompt "Enter value" "default")
input_prompt() {
    local message="$1"
    local default="$2"
    local required="${3:-false}"

    local prompt="$message"
    if [[ -n "$default" ]]; then
        prompt="$prompt [Default: $default]"
    fi

    while true; do
        read -p "$prompt: " value

        if [[ -z "$value" ]]; then
            if [[ -n "$default" ]]; then
                echo "$default"
                return 0
            fi
            if [[ "$required" == "true" ]]; then
                echo "This field is required." >&2
                continue
            fi
        fi

        echo "$value"
        return 0
    done
}

# Show a password input prompt (hidden input)
# Usage: password=$(password_prompt "Enter password")
password_prompt() {
    local message="$1"

    read -s -p "$message: " value
    echo ""  # New line after hidden input

    echo "$value"
}

# Display a banner
# Usage: show_banner "AUTOPAQET SERVER"
show_banner() {
    local title="$1"

    echo -e "${CYAN:-}=============================================${NC:-}"
    echo -e "${CYAN:-}         $title${NC:-}"
    echo -e "${CYAN:-}=============================================${NC:-}"
}

# Wait for user to press Enter
# Usage: wait_for_keypress
wait_for_keypress() {
    echo ""
    read -p "Press Enter to continue..."
}

# Check if running interactively (not piped)
# Usage: if is_interactive; then show_menu; else do_install; fi
is_interactive() {
    [[ -t 0 ]]
}

# Display a progress indicator
# Usage: show_progress "Installing..." 5
show_progress() {
    local message="$1"
    local seconds="${2:-3}"

    echo -n "$message "
    for ((i=0; i<seconds; i++)); do
        echo -n "."
        sleep 1
    done
    echo " done"
}

# Display a spinner while a command runs
# Usage: run_with_spinner "Installing packages" apt-get install -y package
run_with_spinner() {
    local message="$1"
    shift
    local cmd=("$@")

    local spin='-\|/'
    local i=0

    echo -n "$message "

    "${cmd[@]}" &>/dev/null &
    local pid=$!

    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % 4 ))
        printf "\b${spin:$i:1}"
        sleep 0.1
    done

    wait $pid
    local status=$?

    printf "\b"
    if [[ $status -eq 0 ]]; then
        echo -e "${GREEN:-}done${NC:-}"
    else
        echo -e "${RED:-}failed${NC:-}"
    fi

    return $status
}

# Run main menu loop with handlers
# Usage: run_main_menu "handler1" "handler2" "handler3"
# Handlers are function names that will be called
run_main_menu() {
    local -n handlers_ref=$1

    local options=(
        "Fresh Install"
        "Update AutoPaqet (download latest)"
        "Update Paqet (git pull + rebuild)"
        "Uninstall"
        "Service Management"
        "Configuration"
        "View Logs"
    )

    while true; do
        local choice=$(show_menu "AUTOPAQET SERVER" "${options[@]}")

        case $choice in
            0) return ;;
            1) [[ -n "${handlers_ref[fresh_install]}" ]] && ${handlers_ref[fresh_install]} ;;
            2) [[ -n "${handlers_ref[update_autopaqet]}" ]] && ${handlers_ref[update_autopaqet]} ;;
            3) [[ -n "${handlers_ref[update_paqet]}" ]] && ${handlers_ref[update_paqet]} ;;
            4) [[ -n "${handlers_ref[uninstall]}" ]] && ${handlers_ref[uninstall]} ;;
            5) [[ -n "${handlers_ref[service_menu]}" ]] && ${handlers_ref[service_menu]} ;;
            6) [[ -n "${handlers_ref[config_menu]}" ]] && ${handlers_ref[config_menu]} ;;
            7) [[ -n "${handlers_ref[view_logs]}" ]] && ${handlers_ref[view_logs]} ;;
            -1)
                echo -e "${RED:-}Invalid option. Please try again.${NC:-}"
                sleep 1
                ;;
        esac
    done
}

# Run service management submenu
run_service_menu() {
    local -n handlers_ref=$1

    local options=(
        "Start Service"
        "Stop Service"
        "Restart Service"
        "Check Status"
        "Enable Auto-Start"
        "Disable Auto-Start"
    )

    while true; do
        local choice=$(show_submenu "SERVICE MANAGEMENT" "${options[@]}")

        case $choice in
            0) return ;;
            1) [[ -n "${handlers_ref[start]}" ]] && ${handlers_ref[start]} ;;
            2) [[ -n "${handlers_ref[stop]}" ]] && ${handlers_ref[stop]} ;;
            3) [[ -n "${handlers_ref[restart]}" ]] && ${handlers_ref[restart]} ;;
            4) [[ -n "${handlers_ref[status]}" ]] && ${handlers_ref[status]} ;;
            5) [[ -n "${handlers_ref[enable]}" ]] && ${handlers_ref[enable]} ;;
            6) [[ -n "${handlers_ref[disable]}" ]] && ${handlers_ref[disable]} ;;
            -1)
                echo -e "${RED:-}Invalid option. Please try again.${NC:-}"
                sleep 1
                ;;
        esac
    done
}

# Run configuration submenu
run_config_menu() {
    local -n handlers_ref=$1

    local options=(
        "View Current Configuration"
        "Edit Server Port"
        "Edit Secret Key"
        "Edit Config (nano)"
    )

    while true; do
        local choice=$(show_submenu "CONFIGURATION" "${options[@]}")

        case $choice in
            0) return ;;
            1) [[ -n "${handlers_ref[view]}" ]] && ${handlers_ref[view]} ;;
            2) [[ -n "${handlers_ref[edit_port]}" ]] && ${handlers_ref[edit_port]} ;;
            3) [[ -n "${handlers_ref[edit_key]}" ]] && ${handlers_ref[edit_key]} ;;
            4) [[ -n "${handlers_ref[edit_file]}" ]] && ${handlers_ref[edit_file]} ;;
            -1)
                echo -e "${RED:-}Invalid option. Please try again.${NC:-}"
                sleep 1
                ;;
        esac
    done
}
