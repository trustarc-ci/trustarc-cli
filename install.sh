#!/bin/bash

# TrustArc CLI Installation Script
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/refs/heads/main/install.sh)"
#    or: bash -c "$(wget https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/refs/heads/main/install.sh -O -)"

set -e

# Clean up any old temp directories from previous runs
rm -rf /tmp/trustarc-cli-lib-* 2>/dev/null || true
rm -rf /tmp/trustarc-boilerplate-* 2>/dev/null || true

# GitHub repository base URL for raw content
# CLI module ref selection priority:
# 1) REPO_REF (explicit)
# 2) TRUSTARC_CLI_REF (explicit)
# 3) CLI_VERSION (explicit)
# 4) TRUSTARC_REF (only: testing/main/release; any other value falls back to testing)
# 5) main (default)
REPO_REF_IS_DEFAULT=0
if [ -n "${REPO_REF:-}" ]; then
    REPO_REF="$REPO_REF"
elif [ -n "${TRUSTARC_CLI_REF:-}" ]; then
    REPO_REF="$TRUSTARC_CLI_REF"
elif [ -n "${CLI_VERSION:-}" ]; then
    REPO_REF="$CLI_VERSION"
elif [ -n "${TRUSTARC_REF:-}" ]; then
    case "$TRUSTARC_REF" in
        testing|main|release)
            REPO_REF="$TRUSTARC_REF"
            ;;
        *)
            REPO_REF="testing"
            ;;
    esac
else
    REPO_REF="main"
    REPO_REF_IS_DEFAULT=1
fi
REPO_BASE_URL="https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/refs/heads/${REPO_REF}"
# By default, always fetch latest remote modules.
# Set TRUSTARC_USE_LOCAL_MODULES=1 to use local files during development.
USE_LOCAL_MODULES="${TRUSTARC_USE_LOCAL_MODULES:-0}"

# Auth token for GitHub raw content (reduces rate limiting from IP-based to token-based limits).
# Uses TRUSTARC_TOKEN if set in the environment before running the installer.
_RAW_AUTH_TOKEN="${TRUSTARC_TOKEN:-}"

# Temporary directory for downloaded modules
TMP_LIB_DIR="/tmp/trustarc-cli-lib-$$"

# Function to download and source a module
load_module() {
    local module_name=$1
    local module_path="lib/${module_name}.sh"
    local module_url="${REPO_BASE_URL}/${module_path}"

    # Optional local module mode for development.
    if [ "$USE_LOCAL_MODULES" = "1" ] && [ -f "$(dirname "$0")/${module_path}" ]; then
        echo "[INFO] Using local module: ${module_path}"
        source "$(dirname "$0")/${module_path}"
        return 0
    fi

    # Create temp directory if it doesn't exist
    mkdir -p "$TMP_LIB_DIR"

    # Download module to temp directory with retry/backoff to handle GitHub rate limits
    local local_module="$TMP_LIB_DIR/${module_name}.sh"
    local max_attempts=5
    local attempt=1
    local delay=2

    while [ $attempt -le $max_attempts ]; do
        local http_status=0
        if command -v curl >/dev/null 2>&1; then
            local auth_args=()
            [ -n "$_RAW_AUTH_TOKEN" ] && auth_args=(-H "Authorization: token ${_RAW_AUTH_TOKEN}")
            http_status=$(curl -fsSL --retry 0 -w "%{http_code}" \
                "${auth_args[@]}" \
                "$module_url" -o "$local_module" 2>/dev/null)
        elif command -v wget >/dev/null 2>&1; then
            local auth_header=""
            [ -n "$_RAW_AUTH_TOKEN" ] && auth_header="--header=Authorization: token ${_RAW_AUTH_TOKEN}"
            wget -q ${auth_header:+"$auth_header"} "$module_url" -O "$local_module" 2>/dev/null
            http_status=$?
            # wget exits 0 on success; map to pseudo HTTP code for uniform handling
            [ "$http_status" = "0" ] && http_status=200 || http_status=500
        else
            echo "Error: Neither curl nor wget is available. Please install one of them."
            exit 1
        fi

        if [ -s "$local_module" ] && [ "$http_status" != "429" ]; then
            break
        fi

        if [ "$http_status" = "429" ]; then
            echo "[WARN] GitHub rate limit hit fetching ${module_name} (attempt ${attempt}/${max_attempts}). Retrying in ${delay}s..."
        else
            echo "[WARN] Failed to download ${module_name} (attempt ${attempt}/${max_attempts}). Retrying in ${delay}s..."
        fi

        rm -f "$local_module"
        attempt=$((attempt + 1))
        [ $attempt -le $max_attempts ] && sleep $delay
        delay=$((delay * 2))
    done

    # Source the downloaded module
    if [ -f "$local_module" ] && [ -s "$local_module" ]; then
        source "$local_module"
    else
        echo "Error: Failed to download module after ${max_attempts} attempts: $module_name"
        echo "Tip: set TRUSTARC_TOKEN in your environment to avoid GitHub rate limits."
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
    if [ "$USE_LOCAL_MODULES" = "1" ]; then
        print_warning "Using local modules (TRUSTARC_USE_LOCAL_MODULES=1). They may be out of date."
    else
        print_info "Using latest remote modules from: ${REPO_REF}"
    fi

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
        print_info "This script will set up your TrustArc token in your environment."
        print_info "The following changes will be made:"
        print_substep "Update your shell config with the new TRUSTARC_TOKEN (replaces older TrustArc token entries)"
        print_substep "Save TRUSTARC_TOKEN to $CONFIG_FILE for future runs"
        print_substep "Prompt optionally to configure ~/.netrc for Flutter git authentication"
        print_substep "Set TRUSTARC_TOKEN in this current installer session"
        echo ""
        read -p "Do you agree with these changes? (y/n): " confirm_token_changes
        if [ "$confirm_token_changes" != "y" ] && [ "$confirm_token_changes" != "Y" ]; then
            print_info "Token setup cancelled by user."
            exit 0
        fi
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
