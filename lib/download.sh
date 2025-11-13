#!/bin/bash

# Download and configuration functions for TrustArc CLI
# This file contains sample app download and config update logic

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
                sed -i.bak "s|YOUR_TRUSTARC_TOKEN|$TRUSTARC_TOKEN|g" "$android_settings"
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

            # Update React Native app.json with token (for Android Maven credentials)
            local rn_appjson="$app_dir/app.json"
            if [ -f "$rn_appjson" ] && [ -n "$TRUSTARC_TOKEN" ]; then
                sed -i.bak "s|YOUR_TRUSTARC_TOKEN|$TRUSTARC_TOKEN|g" "$rn_appjson"
                rm -f "${rn_appjson}.bak"
                print_success "Updated React Native app.json with authentication token"
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
            # Update Flutter .env file
            local flutter_env="$app_dir/.env"
            if [ -f "$flutter_env" ]; then
                # Update MAC_DOMAIN
                sed -i.bak "s/^MAC_DOMAIN=.*/MAC_DOMAIN=$domain/" "$flutter_env"
                # Update TEST_WEBSITE_URL
                sed -i.bak "s|^TEST_WEBSITE_URL=.*|TEST_WEBSITE_URL=$website|" "$flutter_env"
                rm -f "${flutter_env}.bak"
                print_success "Updated Flutter .env file"
            else
                print_warning "Flutter .env file not found at: $flutter_env"
            fi

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

    # Map platform to directory name
    local platform_type=""
    local platform_dir=""
    case "$platform" in
        "ios")
            platform_type="ios"
            platform_dir="ios"
            ;;
        "android")
            platform_type="android"
            platform_dir="android"
            ;;
        "react-native")
            platform_type="react-native"
            platform_dir="react"
            ;;
        "flutter")
            platform_type="flutter"
            platform_dir="flutter"
            ;;
    esac

    local github_repo_url="https://github.com/trustarc-ci/trustarc-cli/archive/refs/heads/main.zip"
    local temp_zip="trustarc-cli-temp-$$.zip"
    local temp_dir="trustarc-cli-temp-$$"
    local extract_dir="trustarc-sample-${platform_type}"

    # Check if already extracted
    if [ -d "$extract_dir" ]; then
        echo ""
        print_warning "Found existing sample application at: $extract_dir"
        read -p "Do you want to re-download and replace it? (y/n): " redownload

        if [ "$redownload" != "y" ] && [ "$redownload" != "Y" ]; then
            print_info "Skipping download, updating existing configuration..."
            update_config_files "$platform_type" "$extract_dir" "$domain" "$website"
            return 0
        else
            print_info "Removing existing directory..."
            rm -rf "$extract_dir"
        fi
    fi

    echo ""
    print_info "Download Parameters:"
    print_info "  Platform: $platform_type"
    print_info "  Domain: $domain"
    print_info "  Website: $website"
    print_info "  Source: GitHub Repository"
    echo ""
    print_info "Downloading sample application from GitHub..."

    # Download repo zip
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$github_repo_url" -o "$temp_zip" || {
            print_error "Failed to download from GitHub"
            return 1
        }
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$github_repo_url" -O "$temp_zip" || {
            print_error "Failed to download from GitHub"
            return 1
        }
    else
        print_error "Neither curl nor wget is available"
        return 1
    fi

    print_success "Downloaded repository archive"

    # Extract the specific platform folder
    echo ""
    print_info "Extracting $platform_type sample application..."

    # Create temp directory
    mkdir -p "$temp_dir"

    # Extract only the platforms folder we need
    if unzip -q "$temp_zip" "trustarc-cli-main/platforms/${platform_dir}/*" -d "$temp_dir" 2>/dev/null; then
        # Move the platform folder to final location
        if [ -d "$temp_dir/trustarc-cli-main/platforms/${platform_dir}" ]; then
            mv "$temp_dir/trustarc-cli-main/platforms/${platform_dir}" "$extract_dir"
            print_success "Extracted to: $extract_dir/"

            # Update configuration files with user's choices
            update_config_files "$platform_type" "$extract_dir" "$domain" "$website"
        else
            print_error "Platform directory not found in archive"
            rm -rf "$temp_dir" "$temp_zip"
            return 1
        fi
    else
        print_error "Failed to extract sample application"
        rm -rf "$temp_dir" "$temp_zip"
        return 1
    fi

    # Clean up
    rm -rf "$temp_dir" "$temp_zip"
    print_info "Cleaned up temporary files"
}
