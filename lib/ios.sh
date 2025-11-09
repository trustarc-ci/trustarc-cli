#!/bin/bash

# iOS integration functions for TrustArc CLI
# This file contains logic for iOS SDK integration

# Detect iOS dependency manager (SPM or CocoaPods)
detect_ios_dependency_manager() {
    local project_path=$1

    # Check for CocoaPods
    if [ -f "$project_path/Podfile" ]; then
        echo "cocoapods"
        return 0
    fi

    # Default to Swift Package Manager if no Podfile
    echo "spm"
    return 0
}

# Verify iOS project compatibility
verify_ios_compatibility() {
    local project_path=$1

    print_info "Verifying project compatibility..."

    # Find .xcodeproj file
    local xcodeproj=$(find "$project_path" -maxdepth 1 -name "*.xcodeproj" -print -quit)

    if [ -z "$xcodeproj" ]; then
        print_error "No .xcodeproj file found"
        return 1
    fi

    # Check project.pbxproj for deployment target and Swift version
    local pbxproj="$xcodeproj/project.pbxproj"

    if [ ! -f "$pbxproj" ]; then
        print_error "project.pbxproj not found"
        return 1
    fi

    # Extract iOS deployment target
    local ios_target=$(grep -o "IPHONEOS_DEPLOYMENT_TARGET = [0-9.]*" "$pbxproj" | head -1 | awk '{print $3}' | tr -d ';')

    # Extract Swift version
    local swift_version=$(grep -o "SWIFT_VERSION = [0-9.]*" "$pbxproj" | head -1 | awk '{print $3}' | tr -d ';')

    echo ""
    print_info "Project Configuration:"
    echo "  iOS Deployment Target: ${ios_target:-Not found}"
    echo "  Swift Version: ${swift_version:-Not found}"
    echo ""

    # Verify iOS version (must be >= 12.0)
    if [ -n "$ios_target" ]; then
        local major_version=$(echo "$ios_target" | cut -d. -f1)
        if [ "$major_version" -lt 12 ]; then
            print_error "iOS deployment target must be 12.0 or higher (current: $ios_target)"
            print_info "TrustArc SDK requires iOS 12.0+"
            return 1
        fi
        print_success "iOS deployment target is compatible ✓"
    else
        print_warning "Could not detect iOS deployment target"
        read -p "Continue anyway? (y/n): " continue_choice
        if [ "$continue_choice" != "y" ] && [ "$continue_choice" != "Y" ]; then
            return 1
        fi
    fi

    # Verify Swift version (must be >= 5.0)
    if [ -n "$swift_version" ]; then
        local major_version=$(echo "$swift_version" | cut -d. -f1)
        if [ "$major_version" -lt 5 ]; then
            print_error "Swift version must be 5.0 or higher (current: $swift_version)"
            print_info "TrustArc SDK requires Swift 5.0+ (compatible with Swift 6)"
            return 1
        fi
        print_success "Swift version is compatible ✓"
    else
        print_warning "Could not detect Swift version"
        read -p "Continue anyway? (y/n): " continue_choice
        if [ "$continue_choice" != "y" ] && [ "$continue_choice" != "Y" ]; then
            return 1
        fi
    fi

    return 0
}

# Integrate iOS SDK
integrate_ios_sdk() {
    local project_path=$1

    print_header "iOS SDK Integration"

    # Detect dependency manager
    local dep_manager=$(detect_ios_dependency_manager "$project_path")

    print_info "Detected dependency manager: $dep_manager"
    echo ""

    # Verify compatibility
    if ! verify_ios_compatibility "$project_path"; then
        return 1
    fi

    # Ask for TrustArc domain
    echo ""
    if [ -n "$MAC_DOMAIN" ]; then
        read -p "Enter your TrustArc domain (default: $MAC_DOMAIN): " domain
        domain=${domain:-$MAC_DOMAIN}
    else
        read -p "Enter your TrustArc domain (e.g., mac_trustarc.com): " domain
        if [ -z "$domain" ]; then
            print_error "Domain is required"
            return 1
        fi
    fi
    save_config "MAC_DOMAIN" "$domain"

    # Show integration summary
    print_divider
    echo ""
    print_step "Integration Summary"
    echo ""
    print_substep "Domain: $domain"
    print_substep "Dependency Manager: $dep_manager"
    echo ""
    print_step "What will be done:"
    if [ "$dep_manager" = "cocoapods" ]; then
        print_substep "Add TrustArcConsentSDK to Podfile"
        print_substep "Run 'pod install'"
    else
        print_substep "Add TrustArcConsentSDK Swift Package to project"
        print_substep "Configure package with release branch"
    fi
    echo ""
    print_step "What will NOT be done:"
    print_substep "No code modifications"
    print_substep "No build configuration changes"
    echo ""
    print_divider
    echo ""

    read -p "Proceed with integration? (y/n): " proceed
    if [ "$proceed" != "y" ] && [ "$proceed" != "Y" ]; then
        print_info "Integration cancelled"
        return 1
    fi

    # Perform integration based on dependency manager
    if [ "$dep_manager" = "cocoapods" ]; then
        integrate_ios_cocoapods "$project_path" "$domain"
    else
        integrate_ios_spm "$project_path" "$domain"
    fi

    local integration_result=$?

    if [ $integration_result -eq 0 ]; then
        # Ask about boilerplate
        echo ""
        read -p "Would you like to create a sample implementation file? (y/n): " create_boilerplate

        if [ "$create_boilerplate" = "y" ] || [ "$create_boilerplate" = "Y" ]; then
            create_ios_boilerplate "$project_path" "$domain"
        fi

        echo ""
        print_success "iOS SDK integration completed"
        echo ""
        print_step "Next steps:"
        print_substep "Open your Xcode project"
        if [ "$dep_manager" = "spm" ]; then
            print_substep "Verify TrustArcConsentSDK appears in Package Dependencies"
        else
            print_substep "Verify TrustArcConsentSDK appears in Pods"
        fi
        print_substep "Import and initialize the SDK in your app"
        echo ""
    fi

    return $integration_result
}

# Integrate iOS SDK via CocoaPods
integrate_ios_cocoapods() {
    local project_path=$1
    local domain=$2

    echo ""
    print_info "Adding TrustArcConsentSDK to Podfile..."

    # TODO: Implement CocoaPods integration
    print_warning "CocoaPods integration not yet implemented"
    print_info "Please add the following to your Podfile manually:"
    echo ""
    echo "  pod 'TrustArcConsentSDK'"
    echo ""
    print_info "Then run: pod install"
    echo ""

    return 0
}

# Integrate iOS SDK via Swift Package Manager
integrate_ios_spm() {
    local project_path=$1
    local domain=$2

    # Get the repository URL with embedded token
    local repo_url=""
    if [ -n "$TRUSTARC_TOKEN" ]; then
        repo_url="https://${TRUSTARC_TOKEN}@github.com/trustarc/trustarc-mobile-consent.git"
    else
        echo ""
        print_error "TRUSTARC_TOKEN not found in environment"
        return 1
    fi

    # Ask which branch to use
    echo ""
    read -p "Which branch should be used? (default: release): " branch_name
    branch_name=${branch_name:-release}

    echo ""
    print_step "Adding TrustArc SDK via Swift Package Manager"
    echo ""
    print_divider
    echo ""
    echo "${BOLD}STEP 1:${NC} Copy this repository URL (includes your access token)"
    echo ""
    printf "  ${GREEN}%s${NC}\n" "$repo_url"
    echo ""
    print_warning "Keep this URL private - do not share or commit it"
    echo ""
    print_divider
    echo ""

    read -p "Press Enter after copying the URL..."

    echo ""
    echo "${BOLD}STEP 2:${NC} Add package in Xcode"
    echo ""
    print_substep "Open: $project_path"
    print_substep "Click project file (blue icon) → Package Dependencies tab"
    print_substep "Click '+' button"
    print_substep "Paste the URL → Press Enter"
    print_substep "Set Dependency Rule to: Branch - $branch_name"
    print_substep "Click 'Add Package' twice"
    echo ""
    print_divider
    echo ""

    read -p "Press Enter when done..."

    # Verify package was added
    echo ""
    print_info "Verifying package installation..."

    local xcodeproj=$(find "$project_path" -maxdepth 1 -name "*.xcodeproj" -print -quit)
    if [ -z "$xcodeproj" ]; then
        print_warning "Could not find .xcodeproj file for verification"
        return 0
    fi

    local pbxproj="$xcodeproj/project.pbxproj"
    if [ ! -f "$pbxproj" ]; then
        print_warning "Could not find project.pbxproj for verification"
        return 0
    fi

    # Check if TrustArc package was added
    if grep -q "trustarc-mobile-consent" "$pbxproj" && grep -q "TrustArcConsentSDK" "$pbxproj"; then
        print_success "Package successfully added to project"
        echo ""
        print_substep "Repository reference found"
        print_substep "TrustArcConsentSDK product dependency found"
    else
        print_error "Package does not appear in project.pbxproj"
        echo ""
        print_warning "Please verify manually:"
        print_substep "Check if package appears in Package Dependencies tab"
        print_substep "Try cleaning and rebuilding the project"
        return 1
    fi

    return 0
}

# Create iOS boilerplate implementation
create_ios_boilerplate() {
    local project_path=$1
    local domain=$2

    echo ""
    print_step "Create a new Swift file in Xcode:"
    print_substep "In Xcode: File → New → File → Swift File"
    print_substep "Name it: TrustArcConsentImpl.swift"
    print_substep "Save it to your project"
    echo ""
    read -p "Press Enter after creating TrustArcConsentImpl.swift..."

    # Loop until file is found
    local target_file=""
    while true; do
        echo ""
        print_info "Scanning for TrustArcConsentImpl.swift..."

        # Search for the file
        target_file=$(find "$project_path" -name "TrustArcConsentImpl.swift" -not -path "*/Pods/*" -not -path "*/.build/*" -not -path "*/DerivedData/*" -print -quit)

        if [ -n "$target_file" ]; then
            local relative_path=${target_file#$project_path/}
            print_success "Found: $relative_path"
            break
        else
            print_warning "TrustArcConsentImpl.swift not found yet"
            echo ""
            print_info "Waiting for you to create the file..."
            read -p "Press Enter to scan again (or Ctrl+C to cancel)..."
        fi
    done

    # Use BOILERPLATE_PATH if set (from install.sh), otherwise look locally
    local boilerplate_source="${BOILERPLATE_PATH}"

    if [ -z "$boilerplate_source" ]; then
        # Fallback to local file if BOILERPLATE_PATH not set
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
        boilerplate_source="$script_dir/TrustArcConsentImpl.swift"
    fi

    if [ ! -f "$boilerplate_source" ]; then
        print_error "Could not find boilerplate template at: $boilerplate_source"
        return 1
    fi

    # Append boilerplate to the file
    echo "" >> "$target_file"
    cat "$boilerplate_source" >> "$target_file"

    # Replace domain placeholder in the target file
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/__TRUSTARC_DOMAIN_PLACEHOLDER__/$domain/g" "$target_file"
    else
        # Linux
        sed -i "s/__TRUSTARC_DOMAIN_PLACEHOLDER__/$domain/g" "$target_file"
    fi

    echo ""
    print_success "Implementation added to TrustArcConsentImpl.swift"
    echo ""
    print_substep "Domain configured: $domain"
    echo ""
    print_step "Usage in your app:"
    print_substep "Initialize: TrustArcConsentImpl.shared.initialize()"
    print_substep "Show dialog: TrustArcConsentImpl.shared.openCm()"
    echo ""

    return 0
}
