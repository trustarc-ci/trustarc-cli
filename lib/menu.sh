#!/bin/bash

# Menu functions for TrustArc CLI
# This file contains interactive menu and workflow functions

# Print consistent menu option formatting
print_menu_option() {
    local option_number="$1"
    local option_text="$2"
    printf "  ${BLUE}${BOLD}%s${NC}) %s\n" "$option_number" "$option_text"
}

# Main menu
show_main_menu() {
    print_header "TrustArc Mobile Consent SDK 0.1-alpha"

    printf "${BLUE}What would you like to do?${NC}\n\n"
    print_menu_option "1" "Download demo applications"
    print_menu_option "2" "Clean up (remove token and config)"
    print_menu_option "3" "Exit"
    echo ""
    read -p $'\033[0;34mEnter your choice (1-3): \033[0m' main_choice

    case "$main_choice" in
        1)
            download_demo_apps
            ;;
        2)
            cleanup_trustarc
            ;;
        3)
            echo ""
            print_info "Configuration saved to: $CONFIG_FILE"
            print_substep "Run option 2 to clean up when you no longer need it"
            echo ""
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            show_main_menu
            ;;
    esac
}

# Clean up TrustArc configuration and token
cleanup_trustarc() {
    print_header "Clean Up TrustArc Configuration"

    echo "This will remove:"
    echo ""
    print_substep "TRUSTARC_TOKEN from your shell configuration"
    print_substep "Configuration file: $CONFIG_FILE"
    echo ""
    print_warning "This action cannot be undone"
    echo ""
    read -p "Are you sure you want to continue? (y/n): " confirm

    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        print_info "Cleanup cancelled"
        echo ""
        read -p "Press enter to return to main menu..."
        show_main_menu
        return
    fi

    echo ""
    print_step "Removing token from shell configuration..."

    # Detect shell config file
    local shell_rc=""
    case "$SHELL" in
        */zsh)
            shell_rc="$HOME/.zshrc"
            ;;
        */bash)
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

    # Remove TRUSTARC_TOKEN from shell config
    if [ -f "$shell_rc" ]; then
        # Create backup
        cp "$shell_rc" "$shell_rc.trustarc-backup"

        # Remove the token lines
        if grep -q "TRUSTARC_TOKEN" "$shell_rc"; then
            # Remove the comment line and export line
            sed -i.bak '/# TrustArc GitHub Token/d' "$shell_rc" 2>/dev/null || sed -i '/# TrustArc GitHub Token/d' "$shell_rc"
            sed -i.bak '/export TRUSTARC_TOKEN/d' "$shell_rc" 2>/dev/null || sed -i '/export TRUSTARC_TOKEN/d' "$shell_rc"
            # Remove backup file created by sed
            rm -f "$shell_rc.bak"
            print_success "Token removed from $shell_rc"
            print_substep "Backup created at: $shell_rc.trustarc-backup"
        else
            print_info "No TRUSTARC_TOKEN found in $shell_rc"
            rm -f "$shell_rc.trustarc-backup"
        fi
    fi

    # Remove config file
    echo ""
    print_step "Removing configuration file..."
    local config_path="$HOME/.trustarc-cli-config"
    if [ -f "$config_path" ]; then
        rm -f "$config_path"
        if [ -f "$config_path" ]; then
            print_error "Failed to remove configuration file: $config_path"
        else
            print_success "Configuration file removed: $config_path"
        fi
    else
        print_info "No configuration file found at: $config_path"
    fi

    echo ""
    print_success "Cleanup completed"
    echo ""
    print_divider
    echo ""
    print_warning "IMPORTANT: You MUST restart your terminal"
    echo ""
    print_substep "The token has been removed from: $shell_rc"
    print_substep "The config file has been deleted: $config_path"
    echo ""
    print_substep "However, your CURRENT terminal session still has the token in memory"
    print_substep "Close this terminal and open a new one for changes to take effect"
    echo ""
    print_divider
    echo ""
    read -p "Press enter to exit..."
    exit 0
}

# Download demo applications
download_demo_apps() {
    print_header "Download Demo Applications"

    if [ -z "$TRUSTARC_TOKEN" ]; then
        print_error "GitHub token not available in this session."
        print_info "Restart the installer and provide your token to download the apps."
        echo ""
        read -p "Press enter to return to main menu..."
        show_main_menu
        return
    fi

    local default_dir="${DEMO_APP_DIR:-$PWD/ccm-mobile-consent-test-apps}"
    echo ""
    read -p "Enter download location (default: $default_dir): " target_dir
    target_dir=${target_dir:-$default_dir}
    target_dir="${target_dir/#\~/$HOME}"

    if [ -z "$target_dir" ]; then
        print_error "Download location is required."
        echo ""
        read -p "Press enter to return to main menu..."
        show_main_menu
        return
    fi

    save_config "DEMO_APP_DIR" "$target_dir"

    echo ""
    if clone_demo_apps_repo "$target_dir"; then
        echo ""
        print_success "Demo applications downloaded successfully."
        print_info "Directory: $target_dir"
    else
        echo ""
        print_error "Demo application download failed."
    fi

    echo ""
    read -p "Press enter to return to main menu..."
    show_main_menu
}
