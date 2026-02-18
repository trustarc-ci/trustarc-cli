#!/bin/bash

# GitHub-related functions for TrustArc CLI
# This file contains token validation and storage functions

# Remove existing TrustArc token lines from a shell config file.
remove_token_lines_from_shell_rc() {
    local shell_rc=$1

    [ -f "$shell_rc" ] || return 0

    # Remove old managed block (if present)
    sed -i.bak '/^# >>> TrustArc GitHub Token >>>$/,/^# <<< TrustArc GitHub Token <<<$/d' "$shell_rc" 2>/dev/null || \
        sed -i '/^# >>> TrustArc GitHub Token >>>$/,/^# <<< TrustArc GitHub Token <<<$/d' "$shell_rc"

    # Remove legacy comment/export formats from previous versions
    sed -i.bak '/# TrustArc GitHub Token/d' "$shell_rc" 2>/dev/null || sed -i '/# TrustArc GitHub Token/d' "$shell_rc"
    sed -i.bak '/^[[:space:]]*export[[:space:]]\+TRUSTARC_TOKEN=/d' "$shell_rc" 2>/dev/null || \
        sed -i '/^[[:space:]]*export[[:space:]]\+TRUSTARC_TOKEN=/d' "$shell_rc"
    sed -i.bak '/^[[:space:]]*TRUSTARC_TOKEN=/d' "$shell_rc" 2>/dev/null || \
        sed -i '/^[[:space:]]*TRUSTARC_TOKEN=/d' "$shell_rc"

    rm -f "$shell_rc.bak"
}

# Remove machine github.com from .netrc while preserving all other entries.
remove_github_from_netrc() {
    local netrc_file=$1
    local tmp_file="${netrc_file}.tmp"

    [ -f "$netrc_file" ] || return 0

    awk '
BEGIN {
    in_github = 0
}
/^[[:space:]]*machine[[:space:]]+github\.com([[:space:]].*)?$/ {
    in_github = 1
    next
}
/^[[:space:]]*machine[[:space:]]+/ {
    in_github = 0
}
{
    if (!in_github) print
}
' "$netrc_file" > "$tmp_file" && mv "$tmp_file" "$netrc_file"
}

# Validate GitHub token
validate_github_token() {
    local token=$1
    local repo_url="https://api.github.com/repos/trustarc/trustarc-mobile-consent"

    echo ""
    print_info "Validating GitHub token..."
    print_info "Repository: trustarc/trustarc-mobile-consent"
    print_info "API Endpoint: $repo_url"

    # Try with curl first, fallback to wget
    if command -v curl >/dev/null 2>&1; then
        print_info "Using curl for validation..."
        response=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token $token" "$repo_url")
        response=$(printf "%s" "$response" | tr -cd '0-9')
        print_info "Response code: $response"
    elif command -v wget >/dev/null 2>&1; then
        print_info "Using wget for validation..."
        response=$(wget --no-config --server-response --spider --header="Authorization: token $token" "$repo_url" 2>&1 | awk '/^  HTTP\/|^HTTP\// { code=$2 } END { print code }')
        response=$(printf "%s" "$response" | tr -cd '0-9')
        print_info "Response code: $response"
    else
        print_error "Neither curl nor wget is available. Please install one of them."
        exit 1
    fi

    if [ "$response" = "200" ]; then
        print_success "Token validation successful!"
        echo ""
        return 0
    else
        echo ""
        print_error "Token validation failed (HTTP $response)"
        case "$response" in
            401)
                print_error "Authentication failed - token is invalid or expired"
                ;;
            403)
                print_error "Access forbidden - token may lack required permissions"
                ;;
            404)
                print_error "Repository not found - token may not have access to private repo"
                ;;
            *)
                print_error "Unexpected response code"
                ;;
        esac
        echo ""
        return 1
    fi
}

# Save token to environment file
save_to_env() {
    local token=$1
    local shell_rc=""
    local shell_rc_files=()

    # Detect shell config file(s) based on user's default shell
    case "$SHELL" in
        */zsh)
            shell_rc_files+=("$HOME/.zshrc")
            ;;
        */bash)
            # Keep both in sync for bash users.
            shell_rc_files+=("$HOME/.bashrc" "$HOME/.bash_profile")
            ;;
        */fish)
            shell_rc_files+=("$HOME/.config/fish/config.fish")
            ;;
        *)
            # Fallback: check what exists
            if [ -f "$HOME/.zshrc" ]; then
                shell_rc_files+=("$HOME/.zshrc")
            elif [ -f "$HOME/.bashrc" ]; then
                shell_rc_files+=("$HOME/.bashrc")
            elif [ -f "$HOME/.bash_profile" ]; then
                shell_rc_files+=("$HOME/.bash_profile")
            else
                shell_rc_files+=("$HOME/.profile")
            fi
            ;;
    esac

    for shell_rc in "${shell_rc_files[@]}"; do
        # Ensure parent directory and file exist before editing.
        mkdir -p "$(dirname "$shell_rc")" 2>/dev/null || true
        touch "$shell_rc" 2>/dev/null || true

        # Always replace existing token entries to avoid retaining old values.
        remove_token_lines_from_shell_rc "$shell_rc"

        echo "" >> "$shell_rc"
        echo "# >>> TrustArc GitHub Token >>>" >> "$shell_rc"
        echo "export TRUSTARC_TOKEN=\"$token\"" >> "$shell_rc"
        echo "# <<< TrustArc GitHub Token <<<" >> "$shell_rc"
        print_success "Token saved to $shell_rc"
    done
    print_warning "Please run: source ${shell_rc_files[0]} (or restart your terminal)"

    save_config "TRUSTARC_TOKEN" "$token"
    save_to_netrc "$token"
}

# Save token to .netrc for Git authentication
save_to_netrc() {
    local token=$1
    local netrc_file="$HOME/.netrc"

    # .netrc should be explicit opt-in (used for Flutter git dependencies only).
    print_substep ".netrc is optional and primarily needed for Flutter git dependency auth."
    read -p "Configure $netrc_file with TrustArc GitHub token? (y/n): " configure_netrc
    if [ "$configure_netrc" != "y" ] && [ "$configure_netrc" != "Y" ]; then
        print_info "Skipping .netrc setup."
        export TRUSTARC_SKIP_NETRC=1
        return 0
    fi

    # If .netrc already exists, warn and back it up before changing.
    if [ -f "$netrc_file" ]; then
        print_warning "Existing $netrc_file detected"
        print_substep "A backup will be written to ${netrc_file}.backup if you continue."
    fi

    print_info "Configuring .netrc for Git authentication..."

    # Backup existing .netrc if it exists
    if [ -f "$netrc_file" ]; then
        cp "$netrc_file" "$netrc_file.backup"
        print_substep "Backup created: ${netrc_file}.backup"
        # Remove existing github.com entry
        remove_github_from_netrc "$netrc_file"
    fi

    # Add GitHub credentials to .netrc
    cat >> "$netrc_file" << EOF

machine github.com
login trustarc-ci
password $token
EOF

    # Set proper permissions (required for Git to use .netrc)
    chmod 600 "$netrc_file"

    print_success ".netrc configured with GitHub token"
    print_substep "File: $netrc_file"
    print_substep "Permissions: 600 (owner read/write only)"
}

# Fetch latest git tag for a GitHub repository (owner/repo).
fetch_latest_repo_tag() {
    local repo=$1
    local api_url="https://api.github.com/repos/${repo}/tags?per_page=1"
    local response=""
    local tag=""

    if command -v curl >/dev/null 2>&1; then
        if [ -n "$TRUSTARC_TOKEN" ]; then
            response=$(curl -fsSL \
                -H "Accept: application/vnd.github+json" \
                -H "Authorization: Bearer $TRUSTARC_TOKEN" \
                "$api_url" 2>/dev/null) || return 1
        else
            response=$(curl -fsSL \
                -H "Accept: application/vnd.github+json" \
                "$api_url" 2>/dev/null) || return 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if [ -n "$TRUSTARC_TOKEN" ]; then
            response=$(wget -qO- \
                --header="Accept: application/vnd.github+json" \
                --header="Authorization: Bearer $TRUSTARC_TOKEN" \
                "$api_url" 2>/dev/null) || return 1
        else
            response=$(wget -qO- \
                --header="Accept: application/vnd.github+json" \
                "$api_url" 2>/dev/null) || return 1
        fi
    else
        return 1
    fi

    tag=$(printf "%s\n" "$response" | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    [ -n "$tag" ] || return 1
    printf "%s\n" "$tag"
}

# Fetch latest SDK version for Android from GitHub Maven registry.
fetch_latest_android_sdk_version() {
    local metadata_url="https://maven.pkg.github.com/trustarc/trustarc-mobile-consent/com/trustarc/trustarc-consent-sdk/maven-metadata.xml"
    local response=""
    local version=""

    # GitHub Maven registry requires auth.
    [ -n "$TRUSTARC_TOKEN" ] || return 1

    if command -v curl >/dev/null 2>&1; then
        response=$(curl -fsSL -u "trustarc-ci:$TRUSTARC_TOKEN" "$metadata_url" 2>/dev/null) || return 1
    elif command -v wget >/dev/null 2>&1; then
        response=$(wget -qO- --user="trustarc-ci" --password="$TRUSTARC_TOKEN" "$metadata_url" 2>/dev/null) || return 1
    else
        return 1
    fi

    version=$(printf "%s\n" "$response" | sed -n 's:.*<latest>\([^<]*\)</latest>.*:\1:p' | head -1)
    if [ -z "$version" ]; then
        version=$(printf "%s\n" "$response" | sed -n 's:.*<version>\([^<]*\)</version>.*:\1:p' | tail -1)
    fi

    [ -n "$version" ] || return 1
    printf "%s\n" "$version"
}

# Fetch latest React Native SDK version from GitHub npm registry.
fetch_latest_react_native_sdk_version() {
    local package_url="https://npm.pkg.github.com/@trustarc%2ftrustarc-react-native-consent-sdk"
    local response=""
    local version=""

    # GitHub npm registry requires auth.
    [ -n "$TRUSTARC_TOKEN" ] || return 1

    if command -v curl >/dev/null 2>&1; then
        response=$(curl -fsSL \
            -H "Accept: application/json" \
            -H "Authorization: Bearer $TRUSTARC_TOKEN" \
            "$package_url" 2>/dev/null) || return 1
    elif command -v wget >/dev/null 2>&1; then
        response=$(wget -qO- \
            --header="Accept: application/json" \
            --header="Authorization: Bearer $TRUSTARC_TOKEN" \
            "$package_url" 2>/dev/null) || return 1
    else
        return 1
    fi

    version=$(printf "%s\n" "$response" | sed -n 's/.*"dist-tags":[^{]*{[^}]*"latest"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    [ -n "$version" ] || return 1
    printf "%s\n" "$version"
}

# Convenience: latest tag for the shared TrustArc mobile consent repo.
fetch_latest_mobile_consent_tag() {
    fetch_latest_repo_tag "trustarc/trustarc-mobile-consent"
}
