#!/bin/bash

# TrustArc CLI Installation Script
# Usage: sh -c "$(curl -fsSL https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/install.sh)"
#    or: sh -c "$(wget https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/install.sh -O -)"

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration file
CONFIG_FILE="$HOME/.trustarc-cli-config"

# Print colored output
print_info() {
    printf "${BLUE}ℹ${NC} %s\n" "$1"
}

print_success() {
    printf "${GREEN}✓${NC} %s\n" "$1"
}

print_warning() {
    printf "${YELLOW}⚠${NC} %s\n" "$1"
}

print_error() {
    printf "${RED}✗${NC} %s\n" "$1"
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

# Detect platform type in current directory
detect_platform() {
    local dir=${1:-.}

    # Check for iOS (Swift Package Manager or CocoaPods)
    if [ -f "$dir/Package.swift" ] && grep -q "platforms" "$dir/Package.swift" 2>/dev/null; then
        echo "ios"
        return 0
    fi

    if [ -f "$dir/Podfile" ] && grep -q "platform :ios" "$dir/Podfile" 2>/dev/null; then
        echo "ios"
        return 0
    fi

    # Check for Android
    if [ -f "$dir/build.gradle" ] || [ -f "$dir/build.gradle.kts" ] || [ -f "$dir/app/build.gradle" ]; then
        if grep -r "com.android" "$dir" 2>/dev/null | grep -q "application\|library"; then
            echo "android"
            return 0
        fi
    fi

    # Check for React Native (both Expo and non-Expo)
    if [ -f "$dir/app.json" ] && [ -f "$dir/package.json" ]; then
        if grep -q "expo" "$dir/package.json" 2>/dev/null; then
            echo "react-native"
            return 0
        fi
    fi

    if [ -f "$dir/package.json" ] && grep -q "react-native" "$dir/package.json" 2>/dev/null; then
        if [ -d "$dir/android" ] && [ -d "$dir/ios" ]; then
            echo "react-native"
            return 0
        fi
    fi

    # Check for Flutter
    if [ -f "$dir/pubspec.yaml" ] && grep -q "flutter:" "$dir/pubspec.yaml" 2>/dev/null; then
        echo "flutter"
        return 0
    fi

    return 1
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
}

# Save token to .netrc
save_to_netrc() {
    local token=$1
    local netrc_file="$HOME/.netrc"

    # Create or update .netrc
    if [ -f "$netrc_file" ]; then
        # Remove existing github.com entry if present
        sed -i.bak '/machine github.com/,/^$/d' "$netrc_file" 2>/dev/null || true
    fi

    echo "" >> "$netrc_file"
    echo "machine github.com" >> "$netrc_file"
    echo "  login $token" >> "$netrc_file"
    echo "  password x-oauth-basic" >> "$netrc_file"
    echo "" >> "$netrc_file"

    # Set proper permissions
    chmod 600 "$netrc_file"

    print_success "Token added to $netrc_file"
    save_config "TRUSTARC_TOKEN" "$token"
}

# Update configuration files in extracted sample app
update_config_files() {
    local platform=$1
    local extract_dir=$2
    local domain=$3
    local website=$4

    echo ""
    print_info "Updating configuration files..."

    # The extract_dir itself is the app directory (no need to go deeper)
    local app_dir="$extract_dir"

    case "$platform" in
        "ios")
            # Update iOS AppConfig.swift - find it in the app directory
            local ios_config=$(find "$app_dir" -name "AppConfig.swift" 2>/dev/null | head -1)

            if [ -f "$ios_config" ]; then
                # Update macDomain
                sed -i.bak "s/let macDomain: String = \".*\"/let macDomain: String = \"$domain\"/" "$ios_config"
                # Update testWebsiteUrl
                sed -i.bak "s|let testWebsiteUrl: String = \".*\"|let testWebsiteUrl: String = \"$website\"|" "$ios_config"
                rm -f "${ios_config}.bak"
                print_success "Updated iOS AppConfig.swift"
            else
                print_warning "iOS AppConfig.swift not found in $app_dir"
            fi

            # Update iOS Podfile with token
            local ios_podfile=$(find "$app_dir" -name "Podfile" -maxdepth 2 2>/dev/null | head -1)
            if [ -f "$ios_podfile" ] && [ -n "$TRUSTARC_TOKEN" ]; then
                sed -i.bak "s|YOUR_TRUSTARC_TOKEN|$TRUSTARC_TOKEN|g" "$ios_podfile"
                rm -f "${ios_podfile}.bak"
                print_success "Updated iOS Podfile with authentication token"
            fi
            ;;

        "android")
            # Update Android AppConfig.kt
            local android_config="$app_dir/app/src/main/java/com/example/trustarcmobileapp/config/AppConfig.kt"
            if [ -f "$android_config" ]; then
                # Update MAC_DOMAIN
                sed -i.bak "s/const val MAC_DOMAIN: String = \".*\"/const val MAC_DOMAIN: String = \"$domain\"/" "$android_config"
                # Update TEST_WEBSITE_URL
                sed -i.bak "s|const val TEST_WEBSITE_URL: String = \".*\"|const val TEST_WEBSITE_URL: String = \"$website\"|" "$android_config"
                rm -f "${android_config}.bak"
                print_success "Updated Android AppConfig.kt"
            else
                print_warning "Android config file not found at: $android_config"
            fi

            # Update Android settings.gradle with token
            local android_settings="$app_dir/settings.gradle"
            if [ -f "$android_settings" ] && [ -n "$TRUSTARC_TOKEN" ]; then
                sed -i.bak "s|your-token-here|$TRUSTARC_TOKEN|g" "$android_settings"
                rm -f "${android_settings}.bak"
                print_success "Updated Android settings.gradle with authentication token"
            fi
            ;;

        "react-native")
            # Update React Native app.config.ts
            local rn_config="$app_dir/config/app.config.ts"
            if [ -f "$rn_config" ]; then
                # Update macDomain
                sed -i.bak "s/macDomain: \".*\"/macDomain: \"$domain\"/" "$rn_config"
                # Update testWebsiteUrl
                sed -i.bak "s|testWebsiteUrl: \".*\"|testWebsiteUrl: \"$website\"|" "$rn_config"
                rm -f "${rn_config}.bak"
                print_success "Updated React Native app.config.ts"
            else
                print_warning "React Native config file not found at: $rn_config"
            fi

            # Update React Native .npmrc with token (if it doesn't already use env var)
            local rn_npmrc="$app_dir/.npmrc"
            if [ -f "$rn_npmrc" ]; then
                print_info "React Native .npmrc already configured to use TRUSTARC_TOKEN environment variable"
            fi

            # Update React Native iOS Podfile with token
            local rn_podfile="$app_dir/ios/Podfile"
            if [ -f "$rn_podfile" ] && [ -n "$TRUSTARC_TOKEN" ]; then
                sed -i.bak "s|YOUR_TRUSTARC_TOKEN|$TRUSTARC_TOKEN|g" "$rn_podfile"
                rm -f "${rn_podfile}.bak"
                print_success "Updated React Native iOS Podfile with authentication token"
            fi
            ;;

        "flutter")
            # Update Flutter main.dart
            local flutter_config="$app_dir/lib/main.dart"
            if [ -f "$flutter_config" ]; then
                # Update kDefaultDomainName
                sed -i.bak "s/const String kDefaultDomainName = \".*\"/const String kDefaultDomainName = \"$domain\"/" "$flutter_config"
                rm -f "${flutter_config}.bak"
                print_success "Updated Flutter main.dart (domain)"
            else
                print_warning "Flutter config file not found at: $flutter_config"
            fi

            # Update Flutter consentWebTestPage.dart for website URL
            local flutter_web_test="$app_dir/lib/consentWebTestPage.dart"
            if [ -f "$flutter_web_test" ]; then
                # Update the test website URL in consentWebTestPage.dart
                sed -i.bak "s|https://trustarc.com|$website|g" "$flutter_web_test"
                rm -f "${flutter_web_test}.bak"
                print_success "Updated Flutter consentWebTestPage.dart (website)"
            fi

            # Update Flutter pubspec.yaml with token
            local flutter_pubspec="$app_dir/pubspec.yaml"
            if [ -f "$flutter_pubspec" ] && [ -n "$TRUSTARC_TOKEN" ]; then
                sed -i.bak "s|YOUR_TRUSTARC_TOKEN|$TRUSTARC_TOKEN|g" "$flutter_pubspec"
                rm -f "${flutter_pubspec}.bak"
                print_success "Updated Flutter pubspec.yaml with authentication token"
            fi

            # Update Flutter iOS Podfile with token
            local flutter_podfile="$app_dir/ios/Podfile"
            if [ -f "$flutter_podfile" ] && [ -n "$TRUSTARC_TOKEN" ]; then
                # Flutter's Podfile might reference the SDK indirectly, check if token replacement is needed
                if grep -q "YOUR_TRUSTARC_TOKEN" "$flutter_podfile" 2>/dev/null; then
                    sed -i.bak "s|YOUR_TRUSTARC_TOKEN|$TRUSTARC_TOKEN|g" "$flutter_podfile"
                    rm -f "${flutter_podfile}.bak"
                    print_success "Updated Flutter iOS Podfile with authentication token"
                fi
            fi
            ;;
    esac

    echo ""
    print_success "Configuration updated successfully!"
    print_info "Domain: $domain"
    print_info "Website: $website"
}

# Download sample application
download_sample_app() {
    local platform=$1
    local domain=$2
    local website=$3

    # Map platform to API format
    local platform_type=""
    case "$platform" in
        "ios")
            platform_type="ios"
            ;;
        "android")
            platform_type="android"
            ;;
        "react-native")
            platform_type="react-native"
            ;;
        "flutter")
            platform_type="flutter"
            ;;
    esac

    local download_url="https://mobile-consent-staging.trustarc.com/api/platform/${platform_type}/${domain}/download?website=${website}"
    local output_file="trustarc-sample-${platform_type}.zip"
    local extract_dir="trustarc-sample-${platform_type}"

    # Check if already extracted
    if [ -d "$extract_dir" ]; then
        echo ""
        print_warning "Found existing extracted sample application at: $extract_dir"
        read -p "Do you want to re-download and replace it? (y/n): " redownload

        if [ "$redownload" != "y" ] && [ "$redownload" != "Y" ]; then
            print_info "Skipping download, updating existing configuration..."
            update_config_files "$platform_type" "$extract_dir" "$domain" "$website"
            return 0
        else
            print_info "Removing existing directory..."
            rm -rf "$extract_dir"
            rm -f "$output_file"
        fi
    fi

    echo ""
    print_info "Download Parameters:"
    print_info "  Platform: $platform_type"
    print_info "  Domain: $domain"
    print_info "  Website: $website"
    print_info "  URL: $download_url"
    echo ""
    print_info "Downloading sample application..."

    # Download with curl or wget and capture HTTP status
    local http_code=""
    if command -v curl >/dev/null 2>&1; then
        if [ -n "$TRUSTARC_TOKEN" ]; then
            http_code=$(curl -L -w "%{http_code}" -H "Authorization: token $TRUSTARC_TOKEN" "$download_url" -o "$output_file" 2>/dev/null)
        else
            http_code=$(curl -L -w "%{http_code}" "$download_url" -o "$output_file" 2>/dev/null)
        fi
    elif command -v wget >/dev/null 2>&1; then
        if [ -n "$TRUSTARC_TOKEN" ]; then
            wget --server-response --header="Authorization: token $TRUSTARC_TOKEN" "$download_url" -O "$output_file" 2>&1 | tee /tmp/wget_output.tmp >/dev/null
        else
            wget --server-response "$download_url" -O "$output_file" 2>&1 | tee /tmp/wget_output.tmp >/dev/null
        fi
        http_code=$(grep "HTTP/" /tmp/wget_output.tmp | tail -1 | awk '{print $2}')
        rm -f /tmp/wget_output.tmp
    fi

    print_info "HTTP Response: $http_code"

    # Check if file exists and is valid
    if [ -f "$output_file" ]; then
        # Check if it's actually a zip file or an error page
        file_type=$(file -b "$output_file" 2>/dev/null || echo "unknown")

        if echo "$file_type" | grep -qi "zip\|archive"; then
            print_success "Sample application downloaded: $output_file"

            # Auto-extract the zip file
            echo ""
            print_info "Extracting sample application..."

            if unzip -q "$output_file" -d "$extract_dir" 2>/dev/null; then
                print_success "Extracted to: $extract_dir/"

                # Update configuration files with user's choices
                update_config_files "$platform_type" "$extract_dir" "$domain" "$website"

                # Clean up zip file after successful extraction
                rm -f "$output_file"
                print_info "Cleaned up download file: $output_file"
            else
                print_error "Failed to extract zip file - file may be corrupted"
            fi
        else
            # File is not a zip, likely an error page
            print_error "Download failed - received an error page instead of zip file"
            print_error "HTTP Status: $http_code"

            # Show first few lines of the error
            if grep -q "Whitelabel Error Page\|Internal Server Error" "$output_file" 2>/dev/null; then
                echo ""
                print_warning "Server Error Details:"
                head -10 "$output_file" | sed 's/^/  /'
                echo ""
                print_info "Possible issues:"
                echo "  - Invalid platform type (must be: ios, android, react-native, flutter)"
                echo "  - Invalid domain format"
                echo "  - Invalid website URL"
                echo "  - Server-side error"
            fi

            # Clean up the invalid file
            rm -f "$output_file"
        fi
    else
        print_error "Failed to download sample application"
        print_error "HTTP Status: $http_code"
    fi
}

# Main menu
show_main_menu() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  TrustArc Mobile Consent SDK Installer"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "What would you like to do?"
    echo ""
    echo "  1) Integrate SDK to current directory"
    echo "  2) Download sample application"
    echo "  3) Exit"
    echo ""
    read -p "Enter your choice (1-3): " main_choice

    case "$main_choice" in
        1)
            integrate_sdk
            ;;
        2)
            download_sample_menu
            ;;
        3)
            print_info "Configuration saved to: $CONFIG_FILE"
            print_warning "You can delete this file when you no longer need it"
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            show_main_menu
            ;;
    esac
}

# Integrate SDK to current directory
integrate_sdk() {
    echo ""
    print_info "Detecting platform in current directory..."

    platform=$(detect_platform ".")

    if [ $? -eq 0 ]; then
        echo ""
        print_success "Platform detected: $platform"
        echo ""
        print_info "Platform type: $platform"
        print_warning "Integration steps will be displayed here (to be implemented)"
        echo ""

        read -p "Press enter to return to main menu..."
        show_main_menu
    else
        echo ""
        print_error "Could not detect platform type in current directory"
        print_info "Supported platforms:"
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
    echo ""
    echo "Select platform for sample application:"
    echo ""
    echo "  1) iOS (Swift Package Manager / CocoaPods)"
    echo "  2) Android"
    echo "  3) React Native (Expo)"
    echo "  4) Flutter"
    echo "  5) Back to main menu"
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

# Main installation flow
main() {
    clear
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  TrustArc Mobile Consent SDK Installer"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

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
        print_info "Token Storage Options:"
        echo ""
        echo "  [1] Environment Variable (TRUSTARC_TOKEN)"
        echo "      - Stored in your shell configuration file (~/.zshrc, ~/.bashrc, etc.)"
        echo "      - Available as an environment variable in your terminal sessions"
        echo "      - Easy to use with command-line tools and scripts"
        echo "      - Can be accessed via \$TRUSTARC_TOKEN"
        echo ""
        echo "  [2] .netrc File"
        echo "      - Stored in ~/.netrc (secure file with restricted permissions)"
        echo "      - Automatically used by curl, wget, and git for authentication"
        echo "      - More secure (file permissions set to 600)"
        echo "      - Works across multiple tools without explicit configuration"
        echo ""
        read -p "Select option (1-2): " storage_choice

        case "$storage_choice" in
            1)
                save_to_env "$github_token"
                ;;
            2)
                save_to_netrc "$github_token"
                ;;
            *)
                print_warning "Invalid choice, defaulting to environment variable"
                save_to_env "$github_token"
                ;;
        esac

        # Export for current session
        export TRUSTARC_TOKEN="$github_token"
    fi

    # Step 4: Main menu
    show_main_menu
}

# Run main function
main
