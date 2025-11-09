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

    local download_url="https://mobile-consent.trustarc.com/api/platform/${platform_type}/${domain}/download?website=${website}"
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
