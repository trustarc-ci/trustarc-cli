#!/bin/bash

# Flutter integration functions for TrustArc CLI
# This file contains logic for Flutter SDK integration
#
# SDK Requirements (from ccm-flutter-mobile-consent-sdk):
# - Dart SDK: >= 3.4.1 < 4.0.0
# - Flutter: >= 3.3.0

# Detect if directory is a Flutter project
is_flutter_project() {
    local project_path=$1

    # Check for pubspec.yaml (required for Flutter)
    if [ ! -f "$project_path/pubspec.yaml" ]; then
        return 1
    fi

    # Check for lib/ directory (standard Flutter structure)
    if [ ! -d "$project_path/lib" ]; then
        return 1
    fi

    # Check if pubspec.yaml contains flutter dependency
    if ! grep -q "flutter:" "$project_path/pubspec.yaml"; then
        return 1
    fi

    return 0
}

# Check if TrustArc SDK exists in pubspec.yaml
flutter_check_trustarc_package() {
    local project_path=$1
    local pubspec="$project_path/pubspec.yaml"

    if grep -q "flutter_trustarc_mobile_consent_sdk" "$pubspec"; then
        # Extract version/ref if it's a git dependency
        local ref=$(grep -A5 "flutter_trustarc_mobile_consent_sdk" "$pubspec" | grep "ref:" | sed 's/.*ref:[[:space:]]*\([^[:space:]]*\).*/\1/')
        if [ -n "$ref" ]; then
            echo "$ref"
        else
            echo "present"
        fi
        return 0
    else
        return 1
    fi
}

# Add TrustArc SDK to pubspec.yaml
add_trustarc_to_pubspec() {
    local project_path=$1
    local version=$2
    local pubspec="$project_path/pubspec.yaml"

    # Backup pubspec.yaml
    cp "$pubspec" "$pubspec.backup"

    # Check if SDK already exists
    if grep -q "flutter_trustarc_mobile_consent_sdk" "$pubspec"; then
        print_info "TrustArc SDK already exists in pubspec.yaml"

        # Update the ref version if different
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "/flutter_trustarc_mobile_consent_sdk/,/path: flutter/ {
                s/ref:.*/ref: $version/
            }" "$pubspec"
        else
            sed -i "/flutter_trustarc_mobile_consent_sdk/,/path: flutter/ {
                s/ref:.*/ref: $version/
            }" "$pubspec"
        fi

        rm -f "$pubspec.backup"
        return 0
    fi

    # Find dependencies section
    local deps_line=$(grep -n "^dependencies:" "$pubspec" | head -1 | cut -d: -f1)

    if [ -z "$deps_line" ]; then
        print_error "Could not find dependencies section in pubspec.yaml"
        mv "$pubspec.backup" "$pubspec"
        return 1
    fi

    # Decide git URL based on whether .netrc was skipped
    local git_url="https://github.com/trustarc/trustarc-mobile-consent.git"
    if [ "${TRUSTARC_SKIP_NETRC:-0}" = "1" ]; then
        if [ -n "$TRUSTARC_TOKEN" ]; then
            git_url="https://${TRUSTARC_TOKEN}@github.com/trustarc/trustarc-mobile-consent.git"
            print_warning "Using token-embedded Git URL for Flutter because .netrc update was skipped."
            print_substep "Git URL: $git_url"
        else
            print_warning "TRUSTARC_SKIP_NETRC set but TRUSTARC_TOKEN is empty; keeping default URL (may fail without .netrc)."
            print_substep "Git URL: $git_url"
        fi
    else
        print_substep "Git URL: $git_url (expects credentials via ~/.netrc)"
    fi

    # Create the dependency entry (using HTTPS - either .netrc or embedded token)
    local sdk_entry="  flutter_trustarc_mobile_consent_sdk:
    git:
      url: $git_url
      ref: $version
      path: flutter"

    # Insert after dependencies line
    local insert_line=$((deps_line + 1))
    local temp_file="$pubspec.tmp"

    # Split file and insert new content
    head -n $deps_line "$pubspec" > "$temp_file"
    echo "$sdk_entry" >> "$temp_file"
    tail -n +$((insert_line)) "$pubspec" >> "$temp_file"
    mv "$temp_file" "$pubspec"

    # Clean up backup
    rm -f "$pubspec.backup"
    return 0
}

# Run flutter pub get
run_flutter_pub_get() {
    local project_path=$1

    echo ""
    print_step "Running flutter pub get..."
    echo ""
    print_divider
    echo ""

    cd "$project_path"

    # Check if flutter is available
    if ! command -v flutter >/dev/null 2>&1; then
        echo ""
        print_error "Flutter CLI not found"
        print_info "Please ensure Flutter is installed and in your PATH"
        print_info "Visit: https://flutter.dev/docs/get-started/install"
        return 1
    fi

    if flutter pub get 2>&1; then
        echo ""
        print_success "Dependencies installed successfully"
        return 0
    else
        echo ""
        print_error "flutter pub get failed"
        return 1
    fi
}

# Scan project for potential boilerplate locations
scan_boilerplate_locations() {
    local project_path=$1
    local locations=()

    # Always include lib/ as it's required in Flutter
    if [ -d "$project_path/lib" ]; then
        locations+=("lib")
    fi

    # Check for common subdirectories
    local common_dirs=("lib/services" "lib/utils" "lib/core" "lib/config" "lib/helpers")
    for dir in "${common_dirs[@]}"; do
        if [ -d "$project_path/$dir" ]; then
            locations+=("$dir")
        fi
    done

    # Return up to 3 locations
    printf '%s\n' "${locations[@]}" | head -3
}

# Create Flutter boilerplate implementation
create_flutter_boilerplate() {
    local project_path=$1
    local domain=$2

    echo ""
    print_step "Creating boilerplate implementation file"
    echo ""

    # Scan for existing directories
    local available_locations=($(scan_boilerplate_locations "$project_path"))

    echo "Where would you like to create TrustArcConsentImpl.dart?"
    echo ""
    echo "Available locations:"

    local choice_num=1
    for loc in "${available_locations[@]}"; do
        echo "  ${BOLD}$choice_num${NC}) $loc/"
        ((choice_num++))
    done
    echo "  ${BOLD}$choice_num${NC}) Custom path"
    echo ""

    read -p "Enter choice (1-$choice_num): " location_choice

    local target_dir=""
    local max_choice=$((${#available_locations[@]} + 1))

    if [ "$location_choice" -ge 1 ] && [ "$location_choice" -lt "$max_choice" ]; then
        local idx=$((location_choice - 1))
        target_dir="$project_path/${available_locations[$idx]}"
    elif [ "$location_choice" -eq "$max_choice" ]; then
        echo ""
        read -p "Enter custom path (relative to project root): " custom_path
        target_dir="$project_path/$custom_path"
    else
        print_error "Invalid choice"
        return 1
    fi

    # Create directory if it doesn't exist
    if [ ! -d "$target_dir" ]; then
        mkdir -p "$target_dir"
        if [ $? -ne 0 ]; then
            print_error "Failed to create directory: $target_dir"
            return 1
        fi
    fi

    local target_file="$target_dir/TrustArcConsentImpl.dart"

    # Download boilerplate from GitHub
    local boilerplate_url="https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/testing/TrustArcConsentImpl.dart"
    local temp_boilerplate="/tmp/trustarc-boilerplate-$$.dart"

    echo ""
    print_info "Downloading boilerplate from GitHub..."

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$boilerplate_url" -o "$temp_boilerplate" || {
            print_error "Failed to download boilerplate from GitHub"
            return 1
        }
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$boilerplate_url" -O "$temp_boilerplate" || {
            print_error "Failed to download boilerplate from GitHub"
            return 1
        }
    else
        print_error "Neither curl nor wget is available"
        return 1
    fi

    # Copy to target location
    cp "$temp_boilerplate" "$target_file"

    # Replace domain placeholder
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/__TRUSTARC_DOMAIN_PLACEHOLDER__/$domain/g" "$target_file"
    else
        sed -i "s/__TRUSTARC_DOMAIN_PLACEHOLDER__/$domain/g" "$target_file"
    fi

    # Clean up temp file
    rm -f "$temp_boilerplate"

    local relative_path="${target_file#$project_path/}"

    echo ""
    print_success "Boilerplate created at: $relative_path"
    echo ""
    print_substep "Domain configured: $domain"
    echo ""
    print_divider
    echo ""
    print_step "Usage Examples"
    echo ""

    echo "${BOLD}In your main.dart or app initialization:${NC}"
    echo ""
    echo "  ${DIM}import 'package:your_app/$relative_path';${NC}"
    echo ""
    echo "  ${DIM}class MyApp extends StatelessWidget {${NC}"
    echo "      ${DIM}@override${NC}"
    echo "      ${DIM}Widget build(BuildContext context) {${NC}"
    echo "          ${DIM}// Initialize after first frame${NC}"
    echo "          ${DIM}WidgetsBinding.instance.addPostFrameCallback((_) {${NC}"
    echo "              ${GREEN}TrustArcConsentImpl.initialize(context);${NC}"
    echo "          ${DIM}});${NC}"
    echo "          ${DIM}return MaterialApp(...);${NC}"
    echo "      ${DIM}}${NC}"
    echo "  ${DIM}}${NC}"
    echo ""
    echo "${BOLD}To show the consent dialog:${NC}"
    echo ""
    echo "  ${DIM}ElevatedButton(${NC}"
    echo "      ${DIM}onPressed: () async {${NC}"
    echo "          ${DIM}await ${GREEN}TrustArcConsentImpl.openCm()${NC}${DIM};${NC}"
    echo "      ${DIM}},${NC}"
    echo "      ${DIM}child: Text('Manage Privacy'),${NC}"
    echo "  ${DIM})${NC}"
    echo ""
    echo "${BOLD}To listen for consent changes:${NC}"
    echo ""
    echo "  ${GREEN}TrustArcConsentImpl.onConsentChange${NC}${DIM}(() async {${NC}"
    echo "      ${DIM}print('Consent changed');${NC}"
    echo "      ${DIM}final hasAnalytics = await ${GREEN}TrustArcConsentImpl.hasConsent${NC}${DIM}('Analytics');${NC}"
    echo "      ${DIM}if (hasAnalytics) {${NC}"
    echo "          ${DIM}// Enable analytics${NC}"
    echo "      ${DIM}}${NC}"
    echo "  ${DIM}});${NC}"
    echo ""
    print_divider
    echo ""

    return 0
}

# Main Flutter integration flow
integrate_flutter_sdk() {
    local project_path=$1

    # Verify TRUSTARC_TOKEN is set
    if [ -z "$TRUSTARC_TOKEN" ]; then
        print_error "TRUSTARC_TOKEN environment variable is not set"
        print_info "This should have been configured during CLI setup"
        return 1
    fi

    print_header "Flutter SDK Integration"

    # Step 1: Verify Flutter project
    print_info "Verifying Flutter project..."

    if ! is_flutter_project "$project_path"; then
        echo ""
        print_error "Not a valid Flutter project"
        print_info "Requirements:"
        print_substep "• pubspec.yaml file"
        print_substep "• lib/ directory"
        print_substep "• flutter dependency in pubspec.yaml"
        return 1
    fi

    print_success "Flutter project detected"

    # Check Flutter version
    if command -v flutter >/dev/null 2>&1; then
        local flutter_version=$(flutter --version | head -1)
        print_substep "Flutter: $flutter_version"
    else
        print_warning "Flutter CLI not found in PATH"
    fi

    echo ""
    print_divider
    echo ""
    read -p "Press Enter to continue..."

    # Step 2: Check for existing TrustArc SDK
    echo ""
    print_step "Checking TrustArc SDK package..."

    local existing_version=$(flutter_check_trustarc_package "$project_path")
    local install_package=false
    local target_version="release"

    if [ -n "$existing_version" ]; then
        echo ""
        print_success "TrustArc SDK already installed"
        print_substep "Current version: $existing_version"
        echo ""
        read -p "Would you like to update to a different version? (y/n): " update_choice

        if [ "$update_choice" = "y" ] || [ "$update_choice" = "Y" ]; then
            echo ""
            read -p "Enter version/ref (default: release): " target_version
            target_version=${target_version:-release}
            install_package=true
        fi
    else
        echo ""
        print_warning "TrustArc SDK not found in pubspec.yaml"
        echo ""
        read -p "Would you like to add it now? (y/n): " add_choice

        if [ "$add_choice" = "y" ] || [ "$add_choice" = "Y" ]; then
            echo ""
            read -p "Enter version/ref (default: release): " target_version
            target_version=${target_version:-release}
            install_package=true
        else
            print_info "Integration cancelled"
            return 1
        fi
    fi

    # Step 3: Add/update package
    if [ "$install_package" = true ]; then
        echo ""
        print_step "Updating pubspec.yaml..."

        if add_trustarc_to_pubspec "$project_path" "$target_version"; then
            print_success "Added flutter_trustarc_mobile_consent_sdk: $target_version"
        else
            print_error "Failed to update pubspec.yaml"
            return 1
        fi

        # Step 4: Run flutter pub get
        echo ""
        read -p "Run flutter pub get now? (y/n): " install_choice

        if [ "$install_choice" = "y" ] || [ "$install_choice" = "Y" ]; then
            if ! run_flutter_pub_get "$project_path"; then
                print_warning "Failed to run flutter pub get"
                print_info "Please run 'flutter pub get' manually when ready"
            fi
        else
            echo ""
            print_warning "Skipping dependency installation"
            print_info "Please run 'flutter pub get' manually"
        fi
    fi

    # Step 5: Boilerplate creation
    echo ""
    print_divider
    echo ""
    read -p "Would you like to create TrustArcConsentImpl.dart? (y/n): " boilerplate_choice

    if [ "$boilerplate_choice" = "y" ] || [ "$boilerplate_choice" = "Y" ]; then
        # Ask for domain
        echo ""
        if [ -n "$MAC_DOMAIN" ]; then
            read -p "Enter your TrustArc domain (default: $MAC_DOMAIN): " domain
            domain=${domain:-$MAC_DOMAIN}
        else
            read -p "Enter your TrustArc domain (default: mac_trustarc.com): " domain
            domain=${domain:-mac_trustarc.com}
        fi
        save_config "MAC_DOMAIN" "$domain"

        create_flutter_boilerplate "$project_path" "$domain"
    fi

    # Step 6: Completion
    echo ""
    print_divider
    echo ""
    print_success "✓ Flutter SDK Integration Completed"
    echo ""
    print_step "Next steps:"
    echo ""
    print_substep "1. Import TrustArcConsentImpl in your app"
    print_substep "2. Initialize in main.dart or app widget"
    print_substep "3. Test the SDK with:"
    print_substep "   • flutter run"
    print_substep "   • Call TrustArcConsentImpl.openCm() to show consent dialog"
    echo ""
    print_info "Documentation:"
    print_substep "• Flutter SDK: https://docs.trustarc.com/mobile/flutter"
    print_substep "• API Reference: Check TrustArcConsentImpl.dart for available methods"
    echo ""

    return 0
}
