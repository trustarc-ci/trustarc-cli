#!/bin/bash

# Utility functions for TrustArc CLI
# This file contains color codes, print functions, and configuration management

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Configuration file
CONFIG_FILE="$HOME/.trustarc-cli-config"

# Print colored output with boxes and formatting
print_info() {
    printf "${CYAN}[INFO]${NC} %s\n" "$1"
}

print_success() {
    printf "${GREEN}[OK]${NC}   %s\n" "$1"
}

print_warning() {
    printf "${YELLOW}[WARN]${NC} %s\n" "$1"
}

print_error() {
    printf "${RED}[ERR]${NC}  %s\n" "$1"
}

print_step() {
    printf "${BOLD}${BLUE}=>${NC} %s\n" "$1"
}

print_substep() {
    printf "  ${DIM}•${NC} %s\n" "$1"
}

print_header() {
    local title="$1"
    local width=60
    local padding=$(( (width - ${#title} - 2) / 2 ))

    echo ""
    printf "${BOLD}${BLUE}"
    printf '╭'
    printf '─%.0s' $(seq 1 $((width - 2)))
    printf '╮\n'
    printf '│'
    printf ' %.0s' $(seq 1 $padding)
    printf "%s" "$title"
    printf ' %.0s' $(seq 1 $((width - ${#title} - padding - 2)))
    printf '│\n'
    printf '╰'
    printf '─%.0s' $(seq 1 $((width - 2)))
    printf '╯\n'
    printf "${NC}"
    echo ""
}

print_divider() {
    printf "${DIM}"
    printf '─%.0s' $(seq 1 60)
    printf "${NC}\n"
}

# Save configuration
save_config() {
    local key=$1
    local value=$2

    # Create or update config file
    if [ -f "$CONFIG_FILE" ]; then
        # Remove existing key if present
        sed -i.bak "/^$key=/d" "$CONFIG_FILE" 2>/dev/null || true
    fi

    echo "$key=$value" >> "$CONFIG_FILE"
}

# Load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

# Normalize user-entered domain/website values.
# Adds https:// when no scheme is provided.
normalize_https_url() {
    local value="$1"

    # Trim leading/trailing whitespace
    value=$(printf "%s" "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    if [ -z "$value" ]; then
        echo ""
        return 0
    fi

    case "$value" in
        http://*|https://*)
            echo "$value"
            ;;
        *://*)
            # Preserve non-http schemes if explicitly provided.
            echo "$value"
            ;;
        *)
            echo "https://$value"
            ;;
    esac
}
