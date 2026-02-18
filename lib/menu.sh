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
    print_header "TrustArc Mobile Consent SDK 1.2"

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
            print_substep "Run option 4 to clean up when you no longer need it"
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
    print_substep "GitHub credentials we added in ~/.netrc (only our entry; deletes file if it was the only machine)"
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

    # Remove TRUSTARC_TOKEN from all common shell startup files.
    local shell_files=(
        "$HOME/.zshrc"
        "$HOME/.bashrc"
        "$HOME/.bash_profile"
        "$HOME/.profile"
        "$HOME/.config/fish/config.fish"
    )
    local removed_shell_files=()
    local file_with_token_found=false
    local shell_rc=""

    for shell_rc in "${shell_files[@]}"; do
        [ -f "$shell_rc" ] || continue

        if grep -q "TRUSTARC_TOKEN" "$shell_rc" 2>/dev/null; then
            file_with_token_found=true
            cp "$shell_rc" "$shell_rc.trustarc-backup"
            remove_token_lines_from_shell_rc "$shell_rc"
            removed_shell_files+=("$shell_rc")
            print_success "Token removed from $shell_rc"
            print_substep "Backup created at: $shell_rc.trustarc-backup"
        fi
    done

    if [ "$file_with_token_found" = false ]; then
        print_info "No TRUSTARC_TOKEN entries found in shell startup files"
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

    # Clean up .netrc GitHub entry (added during setup)
    echo ""
    print_step "Cleaning .netrc GitHub credentials..."
    local netrc_file="$HOME/.netrc"

    if [ -f "$netrc_file" ]; then
        local machine_count
        machine_count=$(grep -c "^machine " "$netrc_file" 2>/dev/null || true)

        if grep -q "^machine github\\.com" "$netrc_file" 2>/dev/null; then
            if [ "$machine_count" -eq 1 ]; then
                rm -f "$netrc_file"
                if [ -f "$netrc_file" ]; then
                    print_error "Failed to remove $netrc_file"
                else
                    print_success "Removed $netrc_file (it only contained the GitHub entry)"
                fi
            else
                # Remove only the GitHub block, preserving all other machine entries.
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
' "$netrc_file" > "${netrc_file}.tmp" && mv "${netrc_file}.tmp" "$netrc_file"

                if [ ! -s "$netrc_file" ]; then
                    rm -f "$netrc_file"
                    print_substep "Removed empty $netrc_file after deleting GitHub entry"
                else
                    print_success "Removed GitHub entry from $netrc_file"
                fi
            fi
        else
            print_info "No GitHub credentials found in $netrc_file"
        fi
    else
        print_info "No .netrc file found"
    fi

    # Offer to restore previous .netrc from backup if it exists
    local netrc_backup="$netrc_file.backup"
    if [ -f "$netrc_backup" ]; then
        echo ""
        read -p "Restore previous .netrc from backup at $netrc_backup? (y/n): " restore_netrc
        if [ "$restore_netrc" = "y" ] || [ "$restore_netrc" = "Y" ]; then
            cp "$netrc_backup" "$netrc_file"
            chmod 600 "$netrc_file" 2>/dev/null || true
            print_success "Restored $netrc_file from backup"
        else
            print_info "Left backup untouched at $netrc_backup"
        fi
    fi

    echo ""
    print_success "Cleanup completed"
    echo ""
    print_divider
    echo ""
    print_warning "IMPORTANT: You MUST restart your terminal"
    echo ""
    if [ ${#removed_shell_files[@]} -gt 0 ]; then
        print_substep "The token has been removed from:"
        for shell_rc in "${removed_shell_files[@]}"; do
            print_substep "$shell_rc"
        done
    else
        print_substep "No shell file updates were needed"
    fi
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
        echo "  - iOS (CocoaPods)"
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
    echo "  ${BOLD}1${NC}) iOS (CocoaPods)"
    echo "  ${BOLD}2${NC}) Android"
    echo "  ${BOLD}3${NC}) React Native (Expo)"
    echo "  ${BOLD}4${NC}) React Native (Bare Metal)"
    echo "  ${BOLD}5${NC}) Flutter"
    echo "  ${BOLD}6${NC}) Back to main menu"
    echo ""

    local default_platform_choice=""
    case "$LAST_PLATFORM" in
        ios) default_platform_choice="1" ;;
        android) default_platform_choice="2" ;;
        react-native) default_platform_choice="3" ;;
        react-native-baremetal) default_platform_choice="4" ;;
        flutter) default_platform_choice="5" ;;
    esac

    if [ -n "$default_platform_choice" ]; then
        read -p "Enter your choice (1-6, default: $default_platform_choice): " platform_choice
        platform_choice=${platform_choice:-$default_platform_choice}
    else
        read -p "Enter your choice (1-6): " platform_choice
    fi

    local platform=""
    case "$platform_choice" in
        1) platform="ios" ;;
        2) platform="android" ;;
        3) platform="react-native" ;;
        4) platform="react-native-baremetal" ;;
        5) platform="flutter" ;;
        6) show_main_menu; return ;;
        *) print_error "Invalid choice"; download_sample_menu; return ;;
    esac

    save_config "LAST_PLATFORM" "$platform"
    LAST_PLATFORM="$platform"

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
    MAC_DOMAIN="$domain"

    # Ask for website
    echo ""
    if [ -n "$WEBSITE" ]; then
        read -p "Enter website to load (default: $WEBSITE): " website
        website=${website:-$WEBSITE}
    else
        read -p "Enter website to load (default: https://trustarc.com): " website
        website=${website:-https://trustarc.com}
    fi
    website=$(normalize_https_url "$website")
    save_config "WEBSITE" "$website"
    WEBSITE="$website"

    # Download
    download_sample_app "$platform" "$domain" "$website"

    echo ""
    read -p "Press enter to return to main menu..."
    show_main_menu
}
