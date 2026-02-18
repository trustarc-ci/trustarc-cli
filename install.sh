#!/bin/bash

# TrustArc CLI Installation Script
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/refs/heads/main/install.sh)"
#    or: bash -c "$(wget https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/refs/heads/main/install.sh -O -)"

set -e

# Clean up any old temp directories from previous runs
rm -rf /tmp/trustarc-cli-lib-* 2>/dev/null || true
rm -rf /tmp/trustarc-boilerplate-* 2>/dev/null || true

# GitHub repository base URL for raw content
REPO_REF="${TRUSTARC_REF:-main}"
REPO_BASE_URL="https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/refs/heads/${REPO_REF}"

# Temporary directory for downloaded modules
TMP_LIB_DIR="/tmp/trustarc-cli-lib-$$"

# Function to download and source a module
load_module() {
    local module_name=$1
    local module_path="lib/${module_name}.sh"
    local cache_buster
    cache_buster=$(date +%s%N)
    local module_url="${REPO_BASE_URL}/${module_path}?cb=${cache_buster}"

    # Check if running from local git repo first
    if [ -f "$(dirname "$0")/${module_path}" ]; then
        source "$(dirname "$0")/${module_path}"
        return 0
    fi

    # Create temp directory if it doesn't exist
    mkdir -p "$TMP_LIB_DIR"

    # Download module to temp directory
    local local_module="$TMP_LIB_DIR/${module_name}.sh"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -H "Cache-Control: no-cache" -H "Pragma: no-cache" "$module_url" -o "$local_module" 2>/dev/null
    elif command -v wget >/dev/null 2>&1; then
        wget -q --header="Cache-Control: no-cache" --header="Pragma: no-cache" "$module_url" -O "$local_module" 2>/dev/null
    else
        echo "Error: Neither curl nor wget is available. Please install one of them."
        exit 1
    fi

    # Source the downloaded module
    if [ -f "$local_module" ]; then
        source "$local_module"
    else
        echo "Error: Failed to download module: $module_name"
        exit 1
    fi
}

# Cleanup function
cleanup() {
    if [ -d "$TMP_LIB_DIR" ]; then
        rm -rf "$TMP_LIB_DIR"
    fi
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Load all required modules in order
load_module "utils"
load_module "platform"
load_module "github"
load_module "download"
load_module "ios"
load_module "android"
load_module "react"
load_module "flutter"
load_module "menu"

# Main installation flow
main() {
    clear
    print_header "TrustArc Mobile Consent SDK Configurator 1.2"

    # Load existing config
    load_config

    # Step 1: Get GitHub Token
    if [ -z "$TRUSTARC_TOKEN" ]; then
        print_info "GitHub authentication required"
        echo ""
        read -sp "Enter your GitHub Personal Access Token: " github_token
        echo ""
    else
        print_info "Found existing token in configuration ($CONFIG_FILE)"
        echo ""
        read -p "Use existing token? (y/n): " use_existing

        if [ "$use_existing" = "y" ] || [ "$use_existing" = "Y" ]; then
            github_token="$TRUSTARC_TOKEN"
        else
            read -sp "Enter your GitHub Personal Access Token: " github_token
            echo ""
        fi
    fi

    # Trim whitespace from token (remove leading/trailing spaces, newlines, etc.)
    github_token=$(echo "$github_token" | tr -d '[:space:]')

    # Debug: Show token info (first/last 4 chars only for security)
    if [ -n "$github_token" ]; then
        token_length=${#github_token}
        token_prefix="${github_token:0:4}"
        token_suffix="${github_token: -4}"
        print_info "Token received: ${token_prefix}...${token_suffix} (length: $token_length)"
    fi

    # Step 2: Validate token
    if ! validate_github_token "$github_token"; then
        print_error "Failed to access repository with provided token"
        print_info "Please check your token has access to: trustarc/trustarc-mobile-consent"
        exit 1
    fi

    print_success "Successfully validated GitHub token"

    # Step 3: Save token
    if [ "$TRUSTARC_TOKEN" != "$github_token" ]; then
        echo ""
        print_info "What happens next:"
        print_substep "Update your shell config with the new TRUSTARC_TOKEN (replaces older TrustArc token entries)"
        print_substep "Save TRUSTARC_TOKEN to $CONFIG_FILE for future installer runs"
        print_substep "Prompt you to optionally configure ~/.netrc for Flutter git authentication"
        print_substep "Set TRUSTARC_TOKEN in this current installer session"
        echo ""
        print_step "Saving token to environment variable"
        echo ""
        save_to_env "$github_token"

        # Export for current session
        export TRUSTARC_TOKEN="$github_token"
    fi

    # Step 4: Main menu
    show_main_menu
}

# Run main function
main
