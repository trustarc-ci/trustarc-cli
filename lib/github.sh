#!/bin/bash

# GitHub-related functions for TrustArc CLI
# This file contains token validation and storage functions

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
        print_info "Response code: $response"
    elif command -v wget >/dev/null 2>&1; then
        print_info "Using wget for validation..."
        response=$(wget --server-response --header="Authorization: token $token" "$repo_url" 2>&1 | grep "HTTP/" | awk '{print $2}' | tail -1)
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

    # Detect shell config file based on user's default shell
    case "$SHELL" in
        */zsh)
            shell_rc="$HOME/.zshrc"
            ;;
        */bash)
            # Prefer .bashrc if it exists, otherwise .bash_profile
            if [ -f "$HOME/.bashrc" ]; then
                shell_rc="$HOME/.bashrc"
            else
                shell_rc="$HOME/.bash_profile"
            fi
            ;;
        */fish)
            shell_rc="$HOME/.config/fish/config.fish"
            ;;
        *)
            # Fallback: check what exists
            if [ -f "$HOME/.zshrc" ]; then
                shell_rc="$HOME/.zshrc"
            elif [ -f "$HOME/.bashrc" ]; then
                shell_rc="$HOME/.bashrc"
            elif [ -f "$HOME/.bash_profile" ]; then
                shell_rc="$HOME/.bash_profile"
            else
                shell_rc="$HOME/.profile"
            fi
            ;;
    esac

    # Add token to shell rc if not already present
    if ! grep -q "TRUSTARC_TOKEN" "$shell_rc" 2>/dev/null; then
        echo "" >> "$shell_rc"
        echo "# TrustArc GitHub Token" >> "$shell_rc"
        echo "export TRUSTARC_TOKEN=\"$token\"" >> "$shell_rc"
        print_success "Token added to $shell_rc"
        print_warning "Please run: source $shell_rc (or restart your terminal)"
    else
        print_warning "TRUSTARC_TOKEN already exists in $shell_rc"
        print_info "You may need to update it manually if you're using a different token"
    fi

    save_config "TRUSTARC_TOKEN" "$token"
    save_to_netrc "$token"
}

# Save token to .netrc for Git authentication
save_to_netrc() {
    local token=$1
    local netrc_file="$HOME/.netrc"

    # If .netrc already exists, confirm before touching it
    if [ -f "$netrc_file" ]; then
        print_warning "Existing $netrc_file detected"
        print_substep "A backup will be written to ${netrc_file}.backup if you continue."
        read -p "Update $netrc_file with TrustArc GitHub token (may replace github.com entry)? (y/n): " update_netrc
        if [ "$update_netrc" != "y" ] && [ "$update_netrc" != "Y" ]; then
            print_info "Skipping .netrc update; GitHub auth will rely on embedded URLs for Flutter."
            export TRUSTARC_SKIP_NETRC=1
            return 0
        fi
    fi

    print_info "Configuring .netrc for Git authentication..."

    # Backup existing .netrc if it exists
    if [ -f "$netrc_file" ]; then
        cp "$netrc_file" "$netrc_file.backup"
        # Remove existing github.com entry
        sed -i.tmp '/^machine github\.com$/,/^$/d' "$netrc_file" 2>/dev/null || true
        rm -f "$netrc_file.tmp"
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
