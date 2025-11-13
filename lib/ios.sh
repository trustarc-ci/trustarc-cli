#!/bin/bash

# iOS integration functions for TrustArc CLI
# This file contains logic for iOS SDK integration
#
# SDK Requirements (from ccm-ios-mobile-consent-sdk):
# - iOS Deployment Target: >= 13.0
# - Swift: >= 6.0

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
        read -p "Enter your TrustArc domain (default: mac_trustarc.com): " domain
        domain=${domain:-mac_trustarc.com}
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
        print_substep "Add TrustArcConsentSDK to Podfile with git URL and branch"
        print_substep "Run 'pod install' to install dependencies"
    else
        print_substep "Add TrustArcConsentSDK Swift Package to project"
        print_substep "Configure package with specified branch"
    fi
    print_substep "Create implementation file (TrustArcConsentImpl.swift)"
    echo ""
    print_step "What will NOT be done:"
    print_substep "No code modifications to your source files"
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
        if [ "$dep_manager" = "spm" ]; then
            print_substep "Open your Xcode project"
            print_substep "Verify TrustArcConsentSDK appears in Package Dependencies"
        else
            print_substep "Open your .xcworkspace file (NOT .xcodeproj)"
            print_substep "Verify TrustArcConsentSDK appears in Pods"
        fi
        print_substep "Import and initialize the SDK in your app"
        echo ""
        print_info "Documentation:"
        print_substep "• iOS SDK: https://trustarchelp.zendesk.com/hc/en-us/sections/32837249680787-iOS"
        print_substep "• API Reference: Check TrustArcConsentImpl.swift for available methods"
        echo ""
    fi

    return $integration_result
}

# Integrate iOS SDK via CocoaPods
integrate_ios_cocoapods() {
    local project_path=$1
    local domain=$2

    echo ""
    print_step "Adding TrustArc SDK via CocoaPods"
    echo ""

    # Find Podfile
    local podfile="$project_path/Podfile"

    if [ ! -f "$podfile" ]; then
        print_error "Podfile not found at: $podfile"
        return 1
    fi

    # Check if TrustArcConsentSDK already exists in Podfile
    if grep -q "TrustArcConsentSDK" "$podfile"; then
        print_warning "TrustArcConsentSDK already exists in Podfile"
        echo ""
        read -p "Do you want to continue anyway? (y/n): " continue_choice
        if [ "$continue_choice" != "y" ] && [ "$continue_choice" != "Y" ]; then
            print_info "Installation cancelled"
            return 1
        fi
    fi

    # Get token
    if [ -z "$TRUSTARC_TOKEN" ]; then
        print_error "TRUSTARC_TOKEN not found in environment"
        return 1
    fi

    # Ask for branch
    echo ""
    read -p "Which branch/tag should be used? (default: release): " branch_name
    branch_name=${branch_name:-release}

    # Backup Podfile
    cp "$podfile" "$podfile.backup"
    print_success "Created backup: Podfile.backup"
    echo ""

    # Prepare git URL with token placeholder
    local git_url="https://YOUR_GITHUB_TOKEN@github.com/trustarc/trustarc-mobile-consent.git"

    # Add pod to Podfile (before the final 'end')
    print_step "Adding TrustArcConsentSDK to Podfile..."

    # Use awk to add the pod before the last 'end'
    awk -v git_url="$git_url" -v branch="$branch_name" '
    /^end/ && !done {
        printf "  pod '\''TrustArcConsentSDK'\'', :git => '\''%s'\'', :branch => '\''%s'\''\n", git_url, branch
        done = 1
    }
    { print }
    ' "$podfile" > "$podfile.tmp" && mv "$podfile.tmp" "$podfile"

    print_success "Added pod 'TrustArcConsentSDK' with git URL and branch: $branch_name"
    echo ""

    # Run pod install
    print_step "Running pod install..."
    echo ""

    cd "$project_path"
    if pod install; then
        echo ""
        print_success "CocoaPods installation completed"
    else
        echo ""
        print_error "pod install failed"
        echo ""
        print_warning "Possible causes:"
        print_substep "The TrustArcConsentSDK.podspec file may not exist in the repository"
        print_substep "Try checking the repository for the correct podspec name"
        print_substep "You may need to manually edit the Podfile"
        echo ""
        print_warning "Restoring original Podfile..."
        mv "$podfile.backup" "$podfile"
        return 1
    fi

    # Clean up backup
    rm -f "$podfile.backup"

    return 0
}

# Integrate iOS SDK via Swift Package Manager
integrate_ios_spm() {
    local project_path=$1
    local domain=$2

    # Get the repository URL with placeholder (user needs to replace manually)
    local repo_url="https://YOUR_GITHUB_TOKEN@github.com/trustarc/trustarc-mobile-consent.git"

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

    # Download boilerplate from GitHub
    local boilerplate_url="https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/main/TrustArcConsentImpl.swift"
    local temp_boilerplate="/tmp/trustarc-boilerplate-$$.swift"

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

    # Append boilerplate to the file
    echo "" >> "$target_file"
    cat "$temp_boilerplate" >> "$target_file"

    # Clean up temp file
    rm -f "$temp_boilerplate"

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
    print_divider
    echo ""
    print_step "Usage Examples"
    echo ""
    echo "${BOLD}In your SwiftUI App:${NC}"
    echo ""
    echo "  ${DIM}import SwiftUI${NC}"
    echo ""
    echo "  ${DIM}@main${NC}"
    echo "  ${DIM}struct YourApp: App {${NC}"
    echo "      ${DIM}var body: some Scene {${NC}"
    echo "          ${DIM}WindowGroup {${NC}"
    echo "              ${DIM}ContentView()${NC}"
    echo "                  ${DIM}.onAppear {${NC}"
    echo "                      ${GREEN}TrustArcConsentImpl.shared.initialize()${NC}"
    echo "                  ${DIM}}${NC}"
    echo "          ${DIM}}${NC}"
    echo "      ${DIM}}${NC}"
    echo "  ${DIM}}${NC}"
    echo ""
    echo "${BOLD}To show the consent dialog:${NC}"
    echo ""
    echo "  ${DIM}Button(\"Manage Consent\") {${NC}"
    echo "      ${GREEN}TrustArcConsentImpl.shared.openCm()${NC}"
    echo "  ${DIM}}${NC}"
    echo ""
    print_divider
    echo ""

    return 0
}
