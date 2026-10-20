#!/bin/bash

# TrustArc CLI Installation Script
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/refs/heads/main/install.sh)"
#    or: bash -c "$(wget https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/refs/heads/main/install.sh -O -)"

if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This installer requires Bash. Run it with bash instead of sh." >&2
    exit 1
fi

set -e

# Clean up any old temp directories from previous runs
rm -rf /tmp/trustarc-cli-lib-* 2>/dev/null || true
rm -rf /tmp/trustarc-boilerplate-* 2>/dev/null || true

# GitHub repository base URL for raw content
# CLI module ref selection priority:
# 1) REPO_REF (explicit)
# 2) TRUSTARC_CLI_REF (explicit)
# 3) CLI_VERSION (explicit)
# 4) TRUSTARC_REF (testing/main select matching CLI branches;
#    SDK release/version refs use main)
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
        testing|main)
            REPO_REF="$TRUSTARC_REF"
            ;;
        *)
            REPO_REF="main"
            REPO_REF_IS_DEFAULT=1
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

    echo "[INFO] Downloading module: ${module_name} (CLI ref: ${REPO_REF})"
    while [ $attempt -le $max_attempts ]; do
        local http_status=0
        local download_status=0
        # CLI modules are public. An invalid SDK token can cause GitHub raw
        # content to return 404 even when the public module exists.
        if command -v curl >/dev/null 2>&1; then
            # Handle failures explicitly so set -e does not bypass retries.
            http_status=$(curl -fsSL --retry 0 -w "%{http_code}" \
                "$module_url" -o "$local_module") || download_status=$?
        elif command -v wget >/dev/null 2>&1; then
            wget -nv "$module_url" -O "$local_module" || download_status=$?
            # wget exits 0 on success; map to pseudo HTTP code for uniform handling
            [ "$download_status" = "0" ] && http_status=200 || http_status=500
        else
            echo "Error: Neither curl nor wget is available. Please install one of them."
            exit 1
        fi

        if [ "$download_status" = "0" ] && [ -s "$local_module" ] && [[ "$http_status" == 2?? ]]; then
            break
        fi

        if [ "$http_status" = "404" ]; then
            rm -f "$local_module"
            echo "Error: CLI module not found: ${module_url}" >&2
            echo "Check REPO_REF, TRUSTARC_CLI_REF, and CLI_VERSION. To use the default CLI branch, run with REPO_REF=main." >&2
            exit 1
        fi

        if [ "$http_status" = "429" ]; then
            echo "[WARN] GitHub rate limit hit fetching ${module_name} (attempt ${attempt}/${max_attempts})." >&2
        else
            echo "[WARN] Failed to download ${module_name} (attempt ${attempt}/${max_attempts}, HTTP ${http_status}, exit ${download_status})." >&2
        fi

        rm -f "$local_module"
        attempt=$((attempt + 1))
        if [ $attempt -le $max_attempts ]; then
            echo "[INFO] Retrying in ${delay}s..." >&2
            sleep $delay
        fi
        delay=$((delay * 2))
    done

    # Source the downloaded module
    if [ -f "$local_module" ] && [ -s "$local_module" ]; then
        source "$local_module"
    else
        echo "Error: Failed to download module after ${max_attempts} attempts: $module_name"
        echo "Check your network connection and CLI ref. If GitHub is rate limiting requests, try again later."
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
    clear || true
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
