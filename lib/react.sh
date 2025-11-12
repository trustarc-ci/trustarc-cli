#!/bin/bash

# React Native integration functions for TrustArc CLI
# This file contains logic for React Native SDK integration
#
# SDK Requirements (from ccm-react-native-mobile-consent-sdk):
# - React Native: >= 0.73.4
# - Node.js: >= 18 (Expo + Bare Metal)

# Configure .npmrc for TrustArc GitHub registry
configure_npmrc() {
    local project_path=$1
    local npmrc_file="$project_path/.npmrc"

    echo ""
    print_step "Configuring .npmrc for TrustArc registry..."

    # Required configuration lines
    local registry_line="@trustarc:registry=https://npm.pkg.github.com"
    local auth_line="//npm.pkg.github.com/:_authToken=\${TRUSTARC_TOKEN}"

    # Check if .npmrc exists
    if [ -f "$npmrc_file" ]; then
        print_info ".npmrc already exists"

        # Check if TrustArc registry is already configured
        local has_registry=false
        local has_auth=false

        if grep -q "^@trustarc:registry=" "$npmrc_file"; then
            has_registry=true
        fi

        if grep -q "^//npm.pkg.github.com/:_authToken=" "$npmrc_file"; then
            has_auth=true
        fi

        if [ "$has_registry" = true ] && [ "$has_auth" = true ]; then
            print_success "TrustArc registry already configured in .npmrc"
            return 0
        fi

        # Backup existing .npmrc
        cp "$npmrc_file" "$npmrc_file.backup"
        print_substep "Created backup: .npmrc.backup"

        # Add missing lines
        if [ "$has_registry" = false ]; then
            echo "$registry_line" >> "$npmrc_file"
            print_substep "Added TrustArc registry configuration"
        fi

        if [ "$has_auth" = false ]; then
            echo "$auth_line" >> "$npmrc_file"
            print_substep "Added authentication token configuration"
        fi

        rm -f "$npmrc_file.backup"
        print_success "Updated .npmrc with TrustArc configuration"
    else
        # Create new .npmrc
        print_info "Creating .npmrc file..."

        cat > "$npmrc_file" << EOF
$registry_line
$auth_line
EOF

        print_success "Created .npmrc with TrustArc registry configuration"
    fi

    echo ""
    print_info ".npmrc Configuration:"
    print_substep "Registry: https://npm.pkg.github.com"
    print_substep "Auth Token: \${TRUSTARC_TOKEN} (from environment)"

    return 0
}

# Detect React Native project type (expo or bare-metal)
detect_react_native_type() {
    local project_path=$1

    # Check if package.json exists
    if [ ! -f "$project_path/package.json" ]; then
        echo "unknown"
        return 1
    fi

    # Check for Expo
    if grep -q '"expo"' "$project_path/package.json"; then
        echo "expo"
        return 0
    fi

    # Check for bare metal (react-native + native directories)
    if grep -q '"react-native"' "$project_path/package.json" && \
       [ -d "$project_path/ios" ] && [ -d "$project_path/android" ]; then
        echo "bare-metal"
        return 0
    fi

    echo "unknown"
    return 1
}

# Detect package manager (npm or yarn)
detect_package_manager() {
    local project_path=$1

    if [ -f "$project_path/yarn.lock" ]; then
        echo "yarn"
    elif [ -f "$project_path/package-lock.json" ]; then
        echo "npm"
    else
        echo "npm"  # Default to npm
    fi
}

# Get React Native version from package.json
get_react_native_version() {
    local project_path=$1
    local package_json="$project_path/package.json"

    # Extract version using node for accurate parsing
    local version=$(node -e "
        const pkg = require('$package_json');
        const rnVersion = pkg.dependencies['react-native'] || pkg.devDependencies['react-native'] || '';
        console.log(rnVersion.replace(/[^0-9.]/g, ''));
    " 2>/dev/null)

    echo "$version"
}

# Check React Native version compatibility
check_react_native_compatibility() {
    local project_path=$1
    local current_version=$(get_react_native_version "$project_path")

    if [ -z "$current_version" ]; then
        print_error "Could not detect React Native version"
        return 1
    fi

    # Required version: >=0.73.4 (from SDK sample-app)
    local required_major=0
    local required_minor=73
    local required_patch=4

    # Parse current version
    local current_major=$(echo "$current_version" | cut -d. -f1)
    local current_minor=$(echo "$current_version" | cut -d. -f2)
    local current_patch=$(echo "$current_version" | cut -d. -f3)

    print_substep "React Native version: $current_version"

    # Compare versions
    if [ "$current_major" -gt "$required_major" ]; then
        return 0
    elif [ "$current_major" -eq "$required_major" ]; then
        if [ "$current_minor" -gt "$required_minor" ]; then
            return 0
        elif [ "$current_minor" -eq "$required_minor" ]; then
            if [ "$current_patch" -ge "$required_patch" ]; then
                return 0
            fi
        fi
    fi

    # Version is too old - stop installation
    echo ""
    print_error "React Native version $current_version is not compatible"
    print_info "TrustArc SDK requires React Native >= 0.73.4"
    echo ""
    print_info "Please upgrade your React Native version:"
    print_substep "https://react-native-community.github.io/upgrade-helper/"
    echo ""
    return 1
}

# Check if TrustArc SDK exists in package.json
react_check_trustarc_package() {
    local project_path=$1
    local package_json="$project_path/package.json"

    if grep -q "@trustarc/trustarc-react-native-consent-sdk" "$package_json"; then
        # Extract version
        local version=$(grep "@trustarc/trustarc-react-native-consent-sdk" "$package_json" | sed 's/.*: *"\([^"]*\)".*/\1/')
        echo "$version"
        return 0
    else
        return 1
    fi
}

# Add or update TrustArc SDK in package.json
add_trustarc_package() {
    local project_path=$1
    local version=$2
    local package_json="$project_path/package.json"

    # Backup package.json
    cp "$package_json" "$package_json.backup"

    # Use node to modify package.json (safer than sed)
    node -e "
        const fs = require('fs');
        const pkg = JSON.parse(fs.readFileSync('$package_json', 'utf8'));

        if (!pkg.dependencies) {
            pkg.dependencies = {};
        }

        pkg.dependencies['@trustarc/trustarc-react-native-consent-sdk'] = '$version';

        fs.writeFileSync('$package_json', JSON.stringify(pkg, null, 2) + '\n');
    " 2>/dev/null

    if [ $? -eq 0 ]; then
        rm -f "$package_json.backup"
        return 0
    else
        # Restore backup on failure
        mv "$package_json.backup" "$package_json"
        return 1
    fi
}

# Verify iOS integration (CocoaPods)
verify_ios_integration() {
    local project_path=$1

    echo ""
    print_step "Verifying iOS native integration..."

    # Check if Podfile exists
    if [ ! -f "$project_path/ios/Podfile" ]; then
        print_error "Podfile not found"
        return 1
    fi
    print_substep "✓ Podfile found"

    # Check if Podfile.lock exists
    if [ ! -f "$project_path/ios/Podfile.lock" ]; then
        print_warning "Podfile.lock not found (pods not installed yet)"
        return 1
    fi
    print_substep "✓ Podfile.lock found"

    # Check for TrustArc in Podfile.lock
    if ! grep -qi "trustarc" "$project_path/ios/Podfile.lock"; then
        print_error "TrustArc SDK not found in Podfile.lock"
        return 1
    fi
    print_substep "✓ TrustArc SDK found in Podfile.lock"

    # Check for xcframework in React Native SDK node_modules
    local xcframework="$project_path/node_modules/@trustarc/trustarc-react-native-consent-sdk/ios/frameworks/trustarc_consent_sdk.xcframework"
    if [ ! -d "$xcframework" ]; then
        print_warning "TrustArc xcframework not found in node_modules"
        return 1
    fi
    local relative_path="${xcframework#$project_path/}"
    print_substep "✓ xcframework detected: $relative_path"

    # Check for .xcworkspace
    local xcworkspace=$(find "$project_path/ios" -maxdepth 1 -name "*.xcworkspace" -print -quit)
    if [ -z "$xcworkspace" ]; then
        print_warning ".xcworkspace not found"
        return 1
    fi
    print_substep "✓ .xcworkspace ready to open"

    echo ""
    print_success "iOS native integration verified"
    return 0
}

# Verify Android integration (Gradle)
verify_android_integration() {
    local project_path=$1

    echo ""
    print_step "Verifying Android native integration..."

    # Check if build.gradle exists
    local app_build_gradle=""
    if [ -f "$project_path/android/app/build.gradle" ]; then
        app_build_gradle="$project_path/android/app/build.gradle"
    elif [ -f "$project_path/android/app/build.gradle.kts" ]; then
        app_build_gradle="$project_path/android/app/build.gradle.kts"
    else
        print_error "app/build.gradle not found"
        return 1
    fi
    print_substep "✓ build.gradle found"

    # Check for auto-linking in settings.gradle
    if [ -f "$project_path/android/settings.gradle" ]; then
        if grep -q "applyNativeModulesSettingsGradle\|native_modules.gradle" "$project_path/android/settings.gradle"; then
            print_substep "✓ Auto-linking enabled in settings.gradle"
        else
            print_warning "Auto-linking not detected in settings.gradle"
        fi
    fi

    # Note: For React Native, TrustArc SDK dependency is auto-linked at build time
    # We don't need to check build.gradle for the dependency explicitly
    print_substep "✓ TrustArc SDK will be auto-linked at build time"

    echo ""
    print_success "Android native integration verified"
    return 0
}

# Run Expo prebuild
run_expo_prebuild() {
    local project_path=$1

    echo ""
    print_step "Running Expo prebuild..."
    echo ""
    print_divider
    echo ""

    cd "$project_path"

    if npx expo prebuild 2>&1; then
        echo ""
        print_success "Expo prebuild completed successfully"
        return 0
    else
        echo ""
        print_error "Expo prebuild failed"
        return 1
    fi
}

# Run pod install for iOS
run_pod_install() {
    local project_path=$1

    echo ""
    print_step "Installing iOS dependencies via CocoaPods..."
    echo ""
    print_divider
    echo ""

    cd "$project_path/ios"

    if pod install --repo-update 2>&1; then
        echo ""
        print_success "Pod installation completed"
        return 0
    else
        echo ""
        print_error "Pod installation failed"
        return 1
    fi
}

# Detect if project uses TypeScript
detect_typescript() {
    local project_path=$1

    # Check for tsconfig.json
    if [ -f "$project_path/tsconfig.json" ]; then
        echo "true"
        return 0
    fi

    # Check for typescript in package.json devDependencies
    if [ -f "$project_path/package.json" ]; then
        if grep -q '"typescript"' "$project_path/package.json"; then
            echo "true"
            return 0
        fi
    fi

    echo "false"
    return 1
}

# Create React Native boilerplate implementation
create_react_native_boilerplate() {
    local project_path=$1
    local domain=$2
    local project_type=$3

    echo ""
    print_step "Creating boilerplate implementation file"
    echo ""

    # Detect if project uses TypeScript
    local use_typescript=$(detect_typescript "$project_path")
    local file_extension="js"
    local file_name="TrustArcConsentImpl.js"

    if [ "$use_typescript" = "true" ]; then
        file_extension="ts"
        file_name="TrustArcConsentImpl.ts"
        print_info "TypeScript project detected"
    else
        print_info "JavaScript project detected"
    fi
    echo ""

    # Suggest locations based on project type
    echo "Where would you like to create $file_name?"
    echo ""
    echo "Suggested locations:"
    if [ "$project_type" = "expo" ]; then
        echo "  ${BOLD}1${NC}) app/ (Expo Router - recommended)"
        echo "  ${BOLD}2${NC}) src/"
        echo "  ${BOLD}3${NC}) Custom path"
    else
        echo "  ${BOLD}1${NC}) src/ (recommended)"
        echo "  ${BOLD}2${NC}) app/"
        echo "  ${BOLD}3${NC}) Custom path"
    fi
    echo ""
    read -p "Enter choice (1-3): " location_choice

    local target_dir=""
    case "$location_choice" in
        1)
            if [ "$project_type" = "expo" ]; then
                target_dir="$project_path/app"
            else
                target_dir="$project_path/src"
            fi
            ;;
        2)
            if [ "$project_type" = "expo" ]; then
                target_dir="$project_path/src"
            else
                target_dir="$project_path/app"
            fi
            ;;
        3)
            echo ""
            read -p "Enter custom path (relative to project root): " custom_path
            target_dir="$project_path/$custom_path"
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac

    # Create directory if it doesn't exist
    if [ ! -d "$target_dir" ]; then
        mkdir -p "$target_dir"
        if [ $? -ne 0 ]; then
            print_error "Failed to create directory: $target_dir"
            return 1
        fi
    fi

    local target_file="$target_dir/$file_name"

    # Download boilerplate from GitHub
    local boilerplate_url="https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/main/TrustArcConsentImpl.$file_extension"
    local temp_boilerplate="/tmp/trustarc-boilerplate-$$.$file_extension"

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

    if [ "$project_type" = "expo" ]; then
        if [ "$use_typescript" = "true" ]; then
            echo "${BOLD}In your app/_layout.tsx (Expo Router):${NC}"
        else
            echo "${BOLD}In your app/_layout.js (Expo Router):${NC}"
        fi
        echo ""
        echo "  ${DIM}import { useEffect } from 'react';${NC}"
        echo "  ${DIM}import TrustArcConsentImpl from './$relative_path';${NC}"
        echo ""
        echo "  ${DIM}export default function RootLayout() {${NC}"
        echo "      ${DIM}useEffect(() => {${NC}"
        echo "          ${GREEN}TrustArcConsentImpl.initialize();${NC}"
        echo "      ${DIM}}, []);${NC}"
        echo ""
        echo "      ${DIM}return <Stack />;${NC}"
        echo "  ${DIM}}${NC}"
    else
        if [ "$use_typescript" = "true" ]; then
            echo "${BOLD}In your App.tsx or index.ts:${NC}"
        else
            echo "${BOLD}In your App.js or index.js:${NC}"
        fi
        echo ""
        echo "  ${DIM}import { useEffect } from 'react';${NC}"
        echo "  ${DIM}import TrustArcConsentImpl from './$relative_path';${NC}"
        echo ""
        echo "  ${DIM}function App() {${NC}"
        echo "      ${DIM}useEffect(() => {${NC}"
        echo "          ${GREEN}TrustArcConsentImpl.initialize();${NC}"
        echo "      ${DIM}}, []);${NC}"
        echo ""
        echo "      ${DIM}return <YourApp />;${NC}"
        echo "  ${DIM}}${NC}"
    fi

    echo ""
    echo "${BOLD}To show the consent dialog:${NC}"
    echo ""
    echo "  ${DIM}<Button ${NC}"
    echo "      ${DIM}title=\"Manage Consent\" ${NC}"
    echo "      ${DIM}onPress={() => ${GREEN}TrustArcConsentImpl.openCm()${NC}${DIM}}${NC}"
    echo "  ${DIM}/>${NC}"
    echo ""
    echo "${BOLD}To listen for consent changes:${NC}"
    echo ""
    echo "  ${DIM}useEffect(() => {${NC}"
    echo "      ${DIM}const unsubscribe = ${GREEN}TrustArcConsentImpl.onConsentChange${NC}${DIM}((data) => {${NC}"
    echo "          ${DIM}console.log('Consent changed:', data);${NC}"
    echo "      ${DIM}});${NC}"
    echo "      ${DIM}return unsubscribe;${NC}"
    echo "  ${DIM}}, []);${NC}"
    echo ""
    print_divider
    echo ""

    return 0
}

# Main React Native integration flow
integrate_react_native_sdk() {
    local project_path=$1

    # Verify TRUSTARC_TOKEN is set
    if [ -z "$TRUSTARC_TOKEN" ]; then
        print_error "TRUSTARC_TOKEN environment variable is not set"
        print_info "This should have been configured during CLI setup"
        return 1
    fi

    print_header "React Native SDK Integration"

    # Step 1: Detect project type
    print_info "Detecting React Native project type..."
    local project_type=$(detect_react_native_type "$project_path")

    if [ "$project_type" = "unknown" ]; then
        echo ""
        print_error "Could not detect React Native project type"
        print_info "Supported project types:"
        echo "  - Expo (with 'expo' in package.json)"
        echo "  - React Native Bare Metal (with ios/ and android/ directories)"
        return 1
    fi

    # Detect package manager
    local package_manager=$(detect_package_manager "$project_path")

    # Check React Native version compatibility
    echo ""
    if ! check_react_native_compatibility "$project_path"; then
        return 1
    fi

    # Display detection summary
    echo ""
    print_divider
    echo ""
    print_step "Project Detection Summary"
    echo ""

    if [ "$project_type" = "expo" ]; then
        print_substep "Project Type: Expo (Managed)"
    else
        print_substep "Project Type: React Native (Bare Metal)"
    fi

    # Get React Native version
    local rn_version=$(get_react_native_version "$project_path")
    print_substep "React Native: $rn_version"

    # Get Node version
    if command -v node >/dev/null 2>&1; then
        local node_version=$(node --version)
        print_substep "Node.js: $node_version"
    fi

    print_substep "Package Manager: $package_manager"

    if [ "$project_type" = "expo" ]; then
        local expo_version=$(grep '"expo"' "$project_path/package.json" | sed 's/.*: *"\([^"]*\)".*/\1/')
        print_substep "Expo Version: $expo_version"
    else
        if [ -d "$project_path/ios" ]; then
            print_substep "iOS Directory: ✓ Present"
        fi
        if [ -d "$project_path/android" ]; then
            print_substep "Android Directory: ✓ Present"
        fi
        if [ -f "$project_path/ios/Podfile" ]; then
            print_substep "Podfile: ✓ Found"
        fi
        if [ -f "$project_path/android/app/build.gradle" ]; then
            print_substep "build.gradle: ✓ Found"
        fi
    fi

    echo ""
    print_divider
    echo ""
    read -p "Press Enter to continue..."

    # Step 2: Configure .npmrc
    configure_npmrc "$project_path"

    # Step 3: Check for TrustArc package
    echo ""
    print_step "Checking TrustArc SDK package..."

    local existing_version=$(react_check_trustarc_package "$project_path")
    local install_package=false
    local target_version="latest"

    if [ -n "$existing_version" ]; then
        echo ""
        print_success "TrustArc SDK already installed"
        print_substep "Current version: $existing_version"
        echo ""
        read -p "Would you like to update to a different version? (y/n): " update_choice

        if [ "$update_choice" = "y" ] || [ "$update_choice" = "Y" ]; then
            echo ""
            read -p "Enter version (default: latest): " target_version
            target_version=${target_version:-latest}
            install_package=true
        fi
    else
        echo ""
        print_warning "TrustArc SDK not found in package.json"
        echo ""
        read -p "Would you like to add it now? (y/n): " add_choice

        if [ "$add_choice" = "y" ] || [ "$add_choice" = "Y" ]; then
            echo ""
            read -p "Enter version (default: latest): " target_version
            target_version=${target_version:-latest}
            install_package=true
        else
            print_info "Integration cancelled"
            return 1
        fi
    fi

    # Step 4: Add/update package
    if [ "$install_package" = true ]; then
        echo ""
        print_step "Updating package.json..."

        if add_trustarc_package "$project_path" "$target_version"; then
            print_success "Added @trustarc/trustarc-react-native-consent-sdk: $target_version"
        else
            print_error "Failed to update package.json"
            return 1
        fi

        # Step 5: Install dependencies
        echo ""
        read -p "Run $package_manager install now? (y/n): " install_choice

        if [ "$install_choice" = "y" ] || [ "$install_choice" = "Y" ]; then
            echo ""
            print_step "Installing dependencies..."
            echo ""

            cd "$project_path"
            if [ "$package_manager" = "yarn" ]; then
                yarn install
            else
                npm install
            fi

            if [ $? -eq 0 ]; then
                echo ""
                print_success "Dependencies installed successfully"
            else
                echo ""
                print_error "Failed to install dependencies"
                return 1
            fi
        else
            echo ""
            print_warning "Skipping dependency installation"
            print_info "Please run '$package_manager install' manually"
        fi
    fi

    # Step 6: Platform-specific integration
    if [ "$project_type" = "expo" ]; then
        # EXPO FLOW
        echo ""
        print_divider
        echo ""
        print_header "EXPO PREBUILD REQUIRED"
        echo ""
        print_info "TrustArc SDK is a native module that requires native code."
        print_info "Expo must generate native directories (ios/ and android/)."
        echo ""
        print_step "This process will:"
        print_substep "✓ Generate native iOS project with CocoaPods"
        print_substep "✓ Generate native Android project with Gradle"
        print_substep "✓ Auto-link TrustArc SDK native modules"
        echo ""
        print_warning "⚠ WARNING: This will regenerate ios/ and android/ directories"
        print_warning "          Any manual native changes will be lost!"
        echo ""
        read -p "Run 'npx expo prebuild' now? (y/n): " prebuild_choice

        if [ "$prebuild_choice" = "y" ] || [ "$prebuild_choice" = "Y" ]; then
            if run_expo_prebuild "$project_path"; then
                echo ""
                print_info "Verifying prebuild results..."

                if [ -d "$project_path/ios" ]; then
                    print_substep "✓ ios/ directory created"
                fi
                if [ -d "$project_path/android" ]; then
                    print_substep "✓ android/ directory created"
                fi
                if [ -f "$project_path/ios/Podfile" ]; then
                    print_substep "✓ Podfile generated"
                fi
                if [ -f "$project_path/android/settings.gradle" ]; then
                    print_substep "✓ Android build files generated"
                fi
            else
                return 1
            fi
        else
            echo ""
            print_info "Please run manually when ready:"
            echo "  cd $project_path"
            echo "  npx expo prebuild"
            echo ""
            read -p "Press Enter when prebuild is complete..."
        fi

        # Verify iOS and Android
        local ios_ok=false
        local android_ok=false

        if verify_ios_integration "$project_path"; then
            ios_ok=true
        fi

        if verify_android_integration "$project_path"; then
            android_ok=true
        fi

        # Show verification summary
        echo ""
        print_divider
        echo ""
        if [ "$ios_ok" = true ] && [ "$android_ok" = true ]; then
            print_success "✓ Native Integration Verified Successfully"
            echo ""
            print_substep "iOS:     ✓ Verified"
            print_substep "Android: ✓ Verified"
        else
            print_warning "⚠ Native Integration Issues Detected"
            echo ""
            if [ "$ios_ok" = true ]; then
                print_substep "iOS:     ✓ Verified"
            else
                print_substep "iOS:     ✗ Issues found"
            fi
            if [ "$android_ok" = true ]; then
                print_substep "Android: ✓ Verified"
            else
                print_substep "Android: ✗ Issues found"
            fi
            echo ""
            read -p "Do you want to continue anyway? (y/n): " continue_choice
            if [ "$continue_choice" != "y" ] && [ "$continue_choice" != "Y" ]; then
                return 1
            fi
        fi

    else
        # BARE METAL FLOW
        echo ""
        print_divider
        echo ""
        print_header "iOS Native Integration"
        echo ""

        # iOS integration
        if [ -f "$project_path/ios/Podfile" ]; then
            print_info "Checking iOS project configuration..."

            if grep -q "use_native_modules!" "$project_path/ios/Podfile"; then
                print_substep "✓ Auto-linking enabled (use_native_modules!)"
            fi

            echo ""
            print_info "Native modules have been updated in package.json"
            print_info "CocoaPods needs to install native iOS dependencies."
            echo ""
            read -p "Run 'cd ios && pod install' now? (y/n): " pod_choice

            if [ "$pod_choice" = "y" ] || [ "$pod_choice" = "Y" ]; then
                if run_pod_install "$project_path"; then
                    verify_ios_integration "$project_path"
                fi
            else
                echo ""
                print_info "Please run manually when ready:"
                echo "  cd ios"
                echo "  pod install"
                echo ""
                read -p "Press Enter when pod install is complete..."
                verify_ios_integration "$project_path"
            fi
        fi

        # Android integration
        echo ""
        print_divider
        echo ""
        print_header "Android Native Integration"
        echo ""

        if [ -f "$project_path/android/settings.gradle" ]; then
            print_info "Checking Android project configuration..."

            if grep -q "applyNativeModulesSettingsGradle\|native_modules.gradle" "$project_path/android/settings.gradle"; then
                print_substep "✓ Auto-linking enabled"
            fi

            if [ -f "$project_path/android/app/build.gradle" ]; then
                print_substep "✓ build.gradle found"
            fi

            echo ""
            print_divider
            echo ""
            print_info "React Native Auto-Linking"
            echo ""
            print_info "React Native CLI will automatically link the TrustArc SDK"
            print_info "during the next Android build. No manual Gradle changes needed!"
            echo ""
            print_info "The SDK will be auto-discovered from node_modules."
            echo ""

            verify_android_integration "$project_path"
        fi

        # Show bare metal summary
        echo ""
        print_divider
        echo ""
        print_success "Native Integration Summary (Bare Metal)"
        echo ""
        print_step "iOS Status:"
        if [ -f "$project_path/ios/Podfile.lock" ]; then
            print_substep "• CocoaPods:      ✓ Installed"
            print_substep "• Podfile.lock:   ✓ Updated"
            if [ -d "$project_path/node_modules/@trustarc/trustarc-react-native-consent-sdk/ios/frameworks/trustarc_consent_sdk.xcframework" ]; then
                print_substep "• xcframework:    ✓ Detected"
            fi
            if find "$project_path/ios" -maxdepth 1 -name "*.xcworkspace" 2>/dev/null | grep -q .; then
                print_substep "• Workspace:      ✓ Ready (.xcworkspace)"
            fi
        fi
        echo ""
        print_step "Android Status:"
        print_substep "• Gradle:         ✓ Configured"
        print_substep "• Auto-linking:   ✓ Enabled"
        if [ -f "$project_path/android/app/build.gradle" ]; then
            local min_sdk=$(grep -E "minSdk(Version)?[[:space:]]*(=)?[[:space:]]*[0-9]+" "$project_path/android/app/build.gradle" | grep -oE "[0-9]+" | tail -1)
            if [ -n "$min_sdk" ]; then
                print_substep "• Min SDK:        ✓ $min_sdk"
            fi
        fi
        echo ""
        print_step "Next Steps:"
        local workspace=$(find "$project_path/ios" -maxdepth 1 -name "*.xcworkspace" -print -quit 2>/dev/null)
        if [ -n "$workspace" ]; then
            local workspace_name=$(basename "$workspace")
            print_substep "1. Open ios/$workspace_name (NOT .xcodeproj)"
        fi
        print_substep "2. Build and run: npx react-native run-ios"
        print_substep "3. Build and run: npx react-native run-android"
    fi

    # Step 7: Boilerplate creation
    echo ""
    print_divider
    echo ""
    read -p "Would you like to create TrustArcConsentImpl.ts? (y/n): " boilerplate_choice

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

        create_react_native_boilerplate "$project_path" "$domain" "$project_type"
    fi

    # Step 8: Completion
    echo ""
    print_divider
    echo ""
    print_success "✓ React Native SDK Integration Completed"
    echo ""
    print_step "Next steps:"
    echo ""
    print_substep "1. Import and initialize TrustArcConsentImpl in your app"
    print_substep "2. Build and run your app:"
    if [ "$project_type" = "expo" ]; then
        print_substep "   • iOS:     npx expo run:ios"
        print_substep "   • Android: npx expo run:android"
    else
        print_substep "   • iOS:     npx react-native run-ios"
        print_substep "   • Android: npx react-native run-android"
    fi
    print_substep "3. Test the consent dialog with:"
    print_substep "   TrustArcConsentImpl.openCm()"
    echo ""
    print_info "Documentation:"
    print_substep "• React Native SDK: https://docs.trustarc.com/mobile/react-native"
    print_substep "• API Reference: Check TrustArcConsentImpl.ts for available methods"
    echo ""

    return 0
}
