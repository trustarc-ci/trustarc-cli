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
    print_menu_option "1" "Integrate SDK into project"
    print_menu_option "2" "Download sample application"
    print_menu_option "3" "Clean up (remove token and config)"
    print_menu_option "4" "Exit"
    echo ""
    read -p $'\033[0;34mEnter your choice (1-4): \033[0m' main_choice

    case "$main_choice" in
        1)
            integrate_sdk
            ;;
        2)
            download_sample_menu
            ;;
        3)
            cleanup_trustarc
            ;;
        4)
            echo ""
            print_info "Configuration saved to: $CONFIG_FILE"
            print_substep "Run option 3 to clean up when you no longer need it"
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

# Integrate SDK
integrate_sdk() {
    print_header "SDK Integration"

    # Step 1: Ask for project location
    read -p "Enter project path (Press Enter for current directory): " project_path
    project_path=${project_path:-.}

    # Expand ~ to home directory if present
    project_path="${project_path/#\~/$HOME}"

    # Check if directory exists
    if [ ! -d "$project_path" ]; then
        print_error "Directory does not exist: $project_path"
        echo ""
        read -p "Press enter to return to main menu..."
        show_main_menu
        return
    fi

    echo ""
    print_info "Checking git status..."

    # Step 2: Check for pending git changes
    if [ -d "$project_path/.git" ]; then
        # Check for uncommitted changes (use -C to run git in target directory without cd)
        if ! git -C "$project_path" diff-index --quiet HEAD -- 2>/dev/null; then
            echo ""
            print_error "You have uncommitted changes. Please commit or stash them before continuing."
            echo ""
            git -C "$project_path" status --short
            echo ""
            print_info "Please run one of the following:"
            echo "  cd $project_path"
            echo "  git commit -am \"Your commit message\""
            echo "  git stash"
            echo ""
            read -p "Press enter to return to main menu..."
            show_main_menu
            return
        fi

        # Check for untracked files
        if [ -n "$(git -C "$project_path" ls-files --others --exclude-standard)" ]; then
            echo ""
            print_warning "You have untracked files:"
            echo ""
            git -C "$project_path" ls-files --others --exclude-standard
            echo ""
            read -p "Do you want to continue anyway? (y/n): " continue_choice
            if [ "$continue_choice" != "y" ] && [ "$continue_choice" != "Y" ]; then
                echo ""
                read -p "Press enter to return to main menu..."
                show_main_menu
                return
            fi
        fi

        print_success "Git status is clean"
    else
        print_warning "Not a git repository. Consider initializing git for better change tracking."
        echo ""
        read -p "Do you want to continue anyway? (y/n): " continue_choice
        if [ "$continue_choice" != "y" ] && [ "$continue_choice" != "Y" ]; then
            echo ""
            read -p "Press enter to return to main menu..."
            show_main_menu
            return
        fi
    fi

    # Step 3: Detect platform
    echo ""
    print_info "Detecting platform..."

    platform=$(detect_platform "$project_path")

    if [ $? -eq 0 ]; then
        echo ""
        print_success "Platform detected: $platform"

        # Call platform-specific integration
        case "$platform" in
            ios)
                integrate_ios_sdk "$project_path"
                ;;
            android)
                integrate_android_sdk "$project_path"
                ;;
            react-native)
                integrate_react_native_sdk "$project_path"
                ;;
            flutter)
                integrate_flutter_sdk "$project_path"
                ;;
            *)
                print_error "Unknown platform: $platform"
                ;;
        esac

        echo ""
        read -p "Press enter to return to main menu..."
        show_main_menu
    else
        echo ""
        print_error "Could not detect platform type"
        print_info "Supported platforms (integration requires GitHub token with repo + read:package scopes):"
        echo "  - iOS (Swift Package Manager / CocoaPods)"
        echo "  - Android"
        echo "  - React Native"
        echo "  - Flutter"
        echo ""
        read -p "Do you want to return to the main menu? (y/n): " retry

        if [ "$retry" = "y" ] || [ "$retry" = "Y" ]; then
            show_main_menu
        else
            print_info "Configuration saved to: $CONFIG_FILE"
            print_warning "You can delete this file when you no longer need it"
            exit 0
        fi
    fi
}

# Download sample application menu
download_sample_menu() {
    print_header "Download Sample Application"

    echo "Select platform:"
    echo ""
    echo "  ${BOLD}1${NC}) iOS (Swift Package Manager / CocoaPods)"
    echo "  ${BOLD}2${NC}) Android"
    echo "  ${BOLD}3${NC}) React Native (Expo)"
    echo "  ${BOLD}4${NC}) Flutter"
    echo "  ${BOLD}5${NC}) Back to main menu"
    echo ""
    read -p "Enter your choice (1-5): " platform_choice

    local platform=""
    case "$platform_choice" in
        1) platform="ios" ;;
        2) platform="android" ;;
        3) platform="react-native" ;;
        4) platform="flutter" ;;
        5) show_main_menu; return ;;
        *) print_error "Invalid choice"; download_sample_menu; return ;;
    esac

    save_config "LAST_PLATFORM" "$platform"

    # Ask for MAC Domain
    echo ""
    if [ -n "$MAC_DOMAIN" ]; then
        read -p "Enter MAC Domain (default: $MAC_DOMAIN): " domain
        domain=${domain:-$MAC_DOMAIN}
    else
        read -p "Enter MAC Domain (default: mac_trustarc.com): " domain
        domain=${domain:-mac_trustarc.com}
    fi
    save_config "MAC_DOMAIN" "$domain"

    # Ask for website
    echo ""
    if [ -n "$WEBSITE" ]; then
        read -p "Enter website to load (default: $WEBSITE): " website
        website=${website:-$WEBSITE}
    else
        read -p "Enter website to load (default: trustarc.com): " website
        website=${website:-trustarc.com}
    fi
    save_config "WEBSITE" "$website"

    # Download
    download_sample_app "$platform" "$domain" "$website"

    echo ""
    read -p "Press enter to return to main menu..."
    show_main_menu
}
