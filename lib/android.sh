#!/bin/bash

# Android integration functions for TrustArc CLI
# This file contains logic for Android SDK integration

# Check if Android project has Kotlin support
has_kotlin_support() {
    local project_path=$1

    # Check for Kotlin plugin in build.gradle files
    if grep -r "kotlin-android" "$project_path" --include="build.gradle*" >/dev/null 2>&1; then
        return 0
    fi

    # Check for Kotlin files
    local kotlin_count=$(find "$project_path" -name "*.kt" -not -path "*/build/*" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$kotlin_count" -gt 0 ]; then
        return 0
    fi

    return 1
}

# Load AGP-Kotlin compatibility data from GitHub
load_agp_kotlin_compatibility() {
    local json_url="https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/main/lib/agp-kotlin-compatibility.json"
    local temp_json="/tmp/trustarc-agp-kotlin-$$.json"

    # Try to fetch from GitHub
    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL "$json_url" -o "$temp_json" 2>/dev/null; then
            cat "$temp_json"
            rm -f "$temp_json"
            return 0
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -q "$json_url" -O "$temp_json" 2>/dev/null; then
            cat "$temp_json"
            rm -f "$temp_json"
            return 0
        fi
    fi

    # Fallback: check local file if GitHub fetch fails
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local json_file="$script_dir/agp-kotlin-compatibility.json"

    if [ -f "$json_file" ]; then
        cat "$json_file"
        return 0
    fi

    # Return default if all methods fail
    echo "1.9.+"
    return 1
}

# Get recommended Kotlin version for AGP version from JSON data
get_kotlin_for_agp() {
    local agp_version=$1
    local json_data=$2

    # Extract major.minor from AGP version (e.g., "8.3.2" -> "8.3")
    local agp_major_minor=$(echo "$agp_version" | cut -d. -f1-2)

    # Use grep and sed to extract recommendedKotlin for matching agpVersion
    local recommended=$(echo "$json_data" | grep -A3 "\"agpVersion\": \"$agp_major_minor\"" | grep "recommendedKotlin" | sed 's/.*: "\([^"]*\)".*/\1/' | head -1)

    if [ -n "$recommended" ]; then
        echo "$recommended"
        return 0
    fi

    # If no exact match, try to find closest lower version
    # Extract all AGP versions and sort them
    local all_versions=$(echo "$json_data" | grep "\"agpVersion\":" | sed 's/.*: "\([^"]*\)".*/\1/')

    # Find the highest version that's lower than or equal to the given AGP version
    local closest_version=""
    while IFS= read -r version; do
        if [ "$(printf '%s\n' "$version" "$agp_major_minor" | sort -V | head -1)" = "$version" ]; then
            closest_version="$version"
        fi
    done <<< "$all_versions"

    if [ -n "$closest_version" ]; then
        recommended=$(echo "$json_data" | grep -A3 "\"agpVersion\": \"$closest_version\"" | grep "recommendedKotlin" | sed 's/.*: "\([^"]*\)".*/\1/' | head -1)
        if [ -n "$recommended" ]; then
            echo "$recommended"
            return 0
        fi
    fi

    # Fallback to default
    echo "$json_data" | grep "\"defaultRecommendation\":" | sed 's/.*: "\([^"]*\)".*/\1/'
}

# Cache for AGP-Kotlin compatibility data (avoid multiple fetches)
AGP_KOTLIN_COMPATIBILITY_CACHE=""

# Detect recommended Kotlin version for the project
detect_kotlin_version() {
    local project_path=$1

    # Check libs.versions.toml first (existing Kotlin version has priority)
    local version_catalog="$project_path/gradle/libs.versions.toml"
    if [ -f "$version_catalog" ]; then
        local kotlin_version=$(grep "^kotlin[[:space:]]*=" "$version_catalog" | sed 's/.*=[[:space:]]*"\([^"]*\)".*/\1/')
        if [ -n "$kotlin_version" ]; then
            echo "$kotlin_version"
            return 0
        fi
    fi

    # Load compatibility data (use cache if available)
    if [ -z "$AGP_KOTLIN_COMPATIBILITY_CACHE" ]; then
        AGP_KOTLIN_COMPATIBILITY_CACHE=$(load_agp_kotlin_compatibility)
        if [ $? -ne 0 ]; then
            # Failed to load, use default
            echo "1.9.+"
            return 0
        fi
    fi

    local json_data="$AGP_KOTLIN_COMPATIBILITY_CACHE"

    # Check AGP version to recommend compatible Kotlin version
    local agp_version=""

    # Try to find AGP version in libs.versions.toml
    if [ -f "$version_catalog" ]; then
        agp_version=$(grep "^agp[[:space:]]*=" "$version_catalog" | sed 's/.*=[[:space:]]*"\([^"]*\)".*/\1/')
    fi

    # If not in version catalog, check build.gradle files
    if [ -z "$agp_version" ]; then
        if [ -f "$project_path/build.gradle" ]; then
            agp_version=$(grep "com.android.tools.build:gradle:" "$project_path/build.gradle" | sed "s/.*:\([0-9.]*\).*/\1/" | head -1)
        fi
    fi

    # Get recommendation from JSON data
    if [ -n "$agp_version" ]; then
        local recommended=$(get_kotlin_for_agp "$agp_version" "$json_data")
        echo "$recommended"
    else
        # No AGP found, use default
        echo "$json_data" | grep "\"defaultRecommendation\":" | sed 's/.*: "\([^"]*\)".*/\1/'
    fi
}

# Add Kotlin support to Android project
add_kotlin_support() {
    local project_path=$1

    echo ""
    print_warning "TrustArc SDK requires Kotlin"
    print_info "Your project appears to be Java-only"
    echo ""
    read -p "Would you like to add Kotlin support to your project? (y/n): " add_kotlin

    if [ "$add_kotlin" != "y" ] && [ "$add_kotlin" != "Y" ]; then
        print_error "TrustArc SDK cannot be integrated without Kotlin support"
        return 1
    fi

    # Detect recommended Kotlin version
    local kotlin_version=$(detect_kotlin_version "$project_path")

    echo ""
    print_step "Adding Kotlin support to your project"
    echo ""
    print_info "Recommended Kotlin version: $kotlin_version"
    echo ""
    print_info "Please add the following to your project manually:"
    echo ""
    echo "${BOLD}1. In your project-level build.gradle (or settings.gradle):${NC}"
    echo ""
    echo "  plugins {"
    echo "      id 'org.jetbrains.kotlin.android' version '$kotlin_version' apply false"
    echo "  }"
    echo ""
    echo "${BOLD}2. In your app/build.gradle:${NC}"
    echo ""
    echo "  plugins {"
    echo "      id 'com.android.application'"
    echo "      id 'org.jetbrains.kotlin.android'"
    echo "  }"
    echo ""
    print_divider
    echo ""
    read -p "Press Enter after adding Kotlin support to continue..."

    return 0
}

# Verify Android project compatibility
verify_android_compatibility() {
    local project_path=$1

    print_info "Verifying project compatibility..."

    # Find app build.gradle file
    local app_build_gradle=""
    if [ -f "$project_path/app/build.gradle" ]; then
        app_build_gradle="$project_path/app/build.gradle"
    elif [ -f "$project_path/app/build.gradle.kts" ]; then
        app_build_gradle="$project_path/app/build.gradle.kts"
    else
        print_error "No app/build.gradle or app/build.gradle.kts file found"
        return 1
    fi

    # Extract minSdk version
    local min_sdk=$(grep -o "minSdk[[:space:]]*=[[:space:]]*[0-9]*" "$app_build_gradle" | head -1 | grep -o "[0-9]*" || \
                    grep -o "minSdkVersion[[:space:]]*[0-9]*" "$app_build_gradle" | head -1 | grep -o "[0-9]*")

    # Extract compileSdk version
    local compile_sdk=$(grep -o "compileSdk[[:space:]]*=[[:space:]]*[0-9]*" "$app_build_gradle" | head -1 | grep -o "[0-9]*" || \
                        grep -o "compileSdkVersion[[:space:]]*[0-9]*" "$app_build_gradle" | head -1 | grep -o "[0-9]*")

    echo ""
    print_info "Project Configuration:"
    echo "  Min SDK: ${min_sdk:-Not found}"
    echo "  Compile SDK: ${compile_sdk:-Not found}"
    echo ""

    # Verify minSdk (must be >= 28)
    if [ -n "$min_sdk" ]; then
        if [ "$min_sdk" -lt 28 ]; then
            print_error "minSdk must be 28 or higher (current: $min_sdk)"
            print_info "TrustArc SDK requires Android API 28+"
            return 1
        fi
        print_success "Min SDK is compatible ✓"
    else
        print_warning "Could not detect minSdk version"
        read -p "Continue anyway? (y/n): " continue_choice
        if [ "$continue_choice" != "y" ] && [ "$continue_choice" != "Y" ]; then
            return 1
        fi
    fi

    # Verify compileSdk (should be >= 33)
    if [ -n "$compile_sdk" ]; then
        if [ "$compile_sdk" -lt 33 ]; then
            print_warning "compileSdk is $compile_sdk (recommended: 33+)"
        else
            print_success "Compile SDK is compatible ✓"
        fi
    fi

    return 0
}

# Find repositories block in dependencyResolutionManagement
find_dependency_resolution_repositories() {
    local settings_gradle=$1

    # Find dependencyResolutionManagement block
    local drm_line=$(grep -n "dependencyResolutionManagement[[:space:]]*{" "$settings_gradle" | head -1 | cut -d: -f1)

    if [ -z "$drm_line" ]; then
        return 1
    fi

    # Find repositories block after dependencyResolutionManagement
    local repo_line=$(tail -n +$drm_line "$settings_gradle" | grep -n "repositories[[:space:]]*{" | head -1 | cut -d: -f1)

    if [ -z "$repo_line" ]; then
        return 1
    fi

    # Calculate absolute line number
    echo $((drm_line + repo_line - 1))
}

# Add Maven repository with credentials to settings.gradle
add_maven_repository() {
    local project_path=$1
    local maven_url=$2

    # Find settings.gradle or settings.gradle.kts
    local settings_gradle=""
    if [ -f "$project_path/settings.gradle" ]; then
        settings_gradle="$project_path/settings.gradle"
    elif [ -f "$project_path/settings.gradle.kts" ]; then
        settings_gradle="$project_path/settings.gradle.kts"
    else
        print_error "Could not find settings.gradle or settings.gradle.kts"
        return 1
    fi

    # Check if repository already exists
    if grep -q "maven.pkg.github.com/trustarc/trustarc-mobile-consent" "$settings_gradle"; then
        print_info "TrustArc Maven repository already exists in settings.gradle"
        return 0
    fi

    # Backup settings.gradle
    cp "$settings_gradle" "$settings_gradle.backup"

    # Find repositories block in dependencyResolutionManagement
    local repo_line=$(find_dependency_resolution_repositories "$settings_gradle")

    if [ -z "$repo_line" ]; then
        print_error "Could not find repositories block in dependencyResolutionManagement"
        print_info "Please add the repository manually to settings.gradle"
        rm "$settings_gradle.backup"
        return 1
    fi

    # Add maven repository with credentials after repositories block opening
    local insert_line=$((repo_line + 1))

    # Create the maven entry with proper formatting
    local maven_entry="        maven {
            name = \"TrustArcMobileConsent\"
            url = uri(\"$maven_url\")
            credentials {
                username = \"trustarc\"
                password = System.getenv(\"TRUSTARC_TOKEN\")
            }
        }"

    # Create temp file with the new content
    local temp_file="$settings_gradle.tmp"
    head -n $repo_line "$settings_gradle" > "$temp_file"
    echo "$maven_entry" >> "$temp_file"
    tail -n +$((repo_line + 1)) "$settings_gradle" >> "$temp_file"
    mv "$temp_file" "$settings_gradle"

    # Clean up backup on success
    rm -f "$settings_gradle.backup"

    return 0
}

# Add TrustArc dependency using version catalog (libs.versions.toml)
add_trustarc_to_version_catalog() {
    local project_path=$1
    local version=$2

    local version_catalog="$project_path/gradle/libs.versions.toml"

    if [ ! -f "$version_catalog" ]; then
        print_error "libs.versions.toml not found at: gradle/libs.versions.toml"
        return 1
    fi

    # Check if already exists
    if grep -q "trustarc-consent-sdk" "$version_catalog"; then
        print_info "TrustArc SDK already exists in libs.versions.toml"
        return 0
    fi

    # Backup version catalog
    cp "$version_catalog" "$version_catalog.backup"

    # Add version to [versions] section
    local versions_line=$(grep -n "^\[versions\]" "$version_catalog" | cut -d: -f1)
    if [ -n "$versions_line" ]; then
        local insert_line=$((versions_line + 1))
        local version_entry="trustarcConsentSdk = \"$version\""

        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "${insert_line}i\\
${version_entry}
" "$version_catalog"
        else
            sed -i "${insert_line}i\\${version_entry}" "$version_catalog"
        fi
    fi

    # Add library to [libraries] section
    local libraries_line=$(grep -n "^\[libraries\]" "$version_catalog" | cut -d: -f1)
    if [ -n "$libraries_line" ]; then
        local insert_line=$((libraries_line + 1))
        local library_entry="trustarc-consent-sdk = { module = \"com.trustarc:trustarc-consent-sdk\", version.ref = \"trustarcConsentSdk\" }"

        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "${insert_line}i\\
${library_entry}
" "$version_catalog"
        else
            sed -i "${insert_line}i\\${library_entry}" "$version_catalog"
        fi
    fi

    # Clean up backup
    rm -f "$version_catalog.backup"

    print_success "Added TrustArc SDK to version catalog"
    return 0
}

# Add TrustArc dependency to app/build.gradle
add_trustarc_dependency() {
    local app_build_gradle=$1
    local version=${2:-"+"}
    local use_version_catalog=${3:-false}

    # Check if TrustArc SDK already exists
    if grep -q "trustarc" "$app_build_gradle" | grep -q "consent"; then
        print_warning "TrustArc SDK dependency already exists in app/build.gradle"
        return 0
    fi

    # Backup app/build.gradle
    cp "$app_build_gradle" "$app_build_gradle.backup"

    # Find dependencies block
    local deps_line=$(grep -n "dependencies[[:space:]]*{" "$app_build_gradle" | head -1 | cut -d: -f1)

    if [ -z "$deps_line" ]; then
        print_error "Could not find dependencies block in app/build.gradle"
        return 1
    fi

    # Add TrustArc dependency
    local insert_line=$((deps_line + 1))
    local dependency_entry=""

    if [ "$use_version_catalog" = true ]; then
        dependency_entry="    implementation(libs.trustarc.consent.sdk)"
    else
        dependency_entry="    implementation 'com.trustarc:trustarc-consent-sdk:$version'"
    fi

    # Insert dependency
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "${insert_line}i\\
${dependency_entry}
" "$app_build_gradle"
    else
        # Linux
        sed -i "${insert_line}i\\${dependency_entry}" "$app_build_gradle"
    fi

    # Clean up backup
    rm -f "$app_build_gradle.backup"

    print_success "Added TrustArc SDK dependency"
    return 0
}

# Create Android boilerplate implementation
create_android_boilerplate() {
    local project_path=$1
    local domain=$2

    local file_name="TrustArcConsentImpl.kt"

    echo ""
    print_step "Create a new Kotlin file in Android Studio:"
    print_substep "In Android Studio: File → New → Kotlin Class/File"
    print_substep "Name it: TrustArcConsentImpl"
    print_substep "Save it to your project (any package)"
    echo ""
    read -p "Press Enter after creating $file_name..."

    # Loop until file is found
    local target_file=""
    while true; do
        echo ""
        print_info "Scanning for $file_name..."

        # Search for the file
        target_file=$(find "$project_path" -name "$file_name" -not -path "*/build/*" -not -path "*/.gradle/*" -print -quit)

        if [ -n "$target_file" ]; then
            local relative_path=${target_file#$project_path/}
            print_success "Found: $relative_path"
            break
        else
            print_warning "$file_name not found yet"
            echo ""
            print_info "Waiting for you to create the file..."
            read -p "Press Enter to scan again (or Ctrl+C to cancel)..."
        fi
    done

    # Download boilerplate from GitHub
    local boilerplate_url="https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/main/$file_name"
    local temp_boilerplate="/tmp/trustarc-boilerplate-$$.kt"

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

    # Extract package line from the existing file
    local package_line=$(grep "^package " "$target_file" | head -1)

    # Create new file with package line + boilerplate
    local temp_new_file="/tmp/trustarc-new-$$.kt"

    if [ -n "$package_line" ]; then
        # Write package line
        echo "$package_line" > "$temp_new_file"
        echo "" >> "$temp_new_file"
    fi

    # Append boilerplate
    cat "$temp_boilerplate" >> "$temp_new_file"

    # Replace domain placeholder in the new file
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/__TRUSTARC_DOMAIN_PLACEHOLDER__/$domain/g" "$temp_new_file"
    else
        # Linux
        sed -i "s/__TRUSTARC_DOMAIN_PLACEHOLDER__/$domain/g" "$temp_new_file"
    fi

    # Replace the original file with the new one
    mv "$temp_new_file" "$target_file"

    # Clean up temp files
    rm -f "$temp_boilerplate"

    echo ""
    print_success "Implementation added to $file_name"
    echo ""
    print_substep "Domain configured: $domain"
    echo ""
    print_divider
    echo ""
    print_step "Usage Examples"
    echo ""
    echo "${BOLD}In your Application class:${NC}"
    echo ""
    echo "  ${DIM}class MyApplication : Application() {${NC}"
    echo "      ${DIM}override fun onCreate() {${NC}"
    echo "          ${DIM}super.onCreate()${NC}"
    echo "          ${GREEN}TrustArcConsentImpl.initialize(this)${NC}"
    echo "      ${DIM}}${NC}"
    echo "  ${DIM}}${NC}"
    echo ""
    echo "${BOLD}To show the consent dialog:${NC}"
    echo ""
    echo "  ${DIM}Button(\"Manage Consent\") {${NC}"
    echo "      ${GREEN}TrustArcConsentImpl.openCm()${NC}"
    echo "  ${DIM}}${NC}"
    echo ""
    print_divider
    echo ""

    return 0
}

# Integrate Android SDK
integrate_android_sdk() {
    local project_path=$1

    print_header "Android SDK Integration"

    # Check for Kotlin support
    if ! has_kotlin_support "$project_path"; then
        if ! add_kotlin_support "$project_path"; then
            return 1
        fi
    else
        print_success "Kotlin support detected"
    fi

    echo ""

    # Verify compatibility
    if ! verify_android_compatibility "$project_path"; then
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

    # Find build.gradle files
    local project_build_gradle=""
    local app_build_gradle=""

    if [ -f "$project_path/build.gradle" ]; then
        project_build_gradle="$project_path/build.gradle"
    elif [ -f "$project_path/build.gradle.kts" ]; then
        project_build_gradle="$project_path/build.gradle.kts"
    fi

    if [ -f "$project_path/app/build.gradle" ]; then
        app_build_gradle="$project_path/app/build.gradle"
    elif [ -f "$project_path/app/build.gradle.kts" ]; then
        app_build_gradle="$project_path/app/build.gradle.kts"
    fi

    # Show integration summary
    print_divider
    echo ""
    print_step "Integration Summary"
    echo ""
    print_substep "Domain: $domain"
    print_substep "Language: Kotlin (required by TrustArc SDK)"
    echo ""
    print_step "What will be done:"
    print_substep "Add TrustArc Maven repository to settings.gradle (dependencyResolutionManagement)"
    print_substep "Add TrustArc SDK dependency to app/build.gradle"
    if [ -f "$project_path/gradle/libs.versions.toml" ]; then
        print_substep "Update gradle/libs.versions.toml with SDK version"
    fi
    print_substep "Create implementation file (TrustArcConsentImpl.kt)"
    echo ""
    print_step "What will NOT be done:"
    print_substep "No Application class modifications"
    print_substep "No manifest changes"
    print_substep "Gradle sync must be done manually"
    echo ""
    print_divider
    echo ""

    read -p "Proceed with integration? (y/n): " proceed
    if [ "$proceed" != "y" ] && [ "$proceed" != "Y" ]; then
        print_info "Integration cancelled"
        return 1
    fi

    echo ""
    print_step "Adding TrustArc SDK to project"
    echo ""

    # Add Maven repository to settings.gradle
    print_info "Adding Maven repository to settings.gradle..."

    if add_maven_repository "$project_path" "https://maven.pkg.github.com/trustarc/trustarc-mobile-consent"; then
        print_success "Maven repository added to dependencyResolutionManagement"
    else
        print_warning "Could not automatically add Maven repository"
        echo ""
        print_info "Please add it manually to settings.gradle in dependencyResolutionManagement:"
        echo ""
        echo "  dependencyResolutionManagement {"
        echo "      repositories {"
        echo "          maven {"
        echo "              name = \"TrustArcMobileConsent\""
        echo "              url = uri(\"https://maven.pkg.github.com/trustarc/trustarc-mobile-consent\")"
        echo "              credentials {"
        echo "                  username = \"trustarc\""
        echo "                  password = System.getenv(\"TRUSTARC_TOKEN\")"
        echo "              }"
        echo "          }"
        echo "      }"
        echo "  }"
        echo ""
    fi

    echo ""

    # Check if project uses version catalog
    local use_version_catalog=false
    if [ -f "$project_path/gradle/libs.versions.toml" ]; then
        use_version_catalog=true
        print_info "Detected version catalog (libs.versions.toml)"
    fi

    # Add dependency to app/build.gradle
    if [ -n "$app_build_gradle" ]; then
        print_info "Adding TrustArc dependency to app/build.gradle..."

        # Ask for version
        echo ""
        read -p "Which version should be used? (default: + for latest): " sdk_version
        sdk_version=${sdk_version:-+}

        if [ "$use_version_catalog" = true ]; then
            # Add to version catalog
            if add_trustarc_to_version_catalog "$project_path" "$sdk_version"; then
                # Add dependency reference to app/build.gradle
                if add_trustarc_dependency "$app_build_gradle" "$sdk_version" true; then
                    print_success "Dependency added successfully using version catalog"
                else
                    print_error "Failed to add dependency"
                    return 1
                fi
            else
                print_warning "Could not add to version catalog, falling back to direct dependency"
                if add_trustarc_dependency "$app_build_gradle" "$sdk_version" false; then
                    print_success "Dependency added successfully"
                else
                    print_error "Failed to add dependency"
                    return 1
                fi
            fi
        else
            # Direct dependency
            if add_trustarc_dependency "$app_build_gradle" "$sdk_version" false; then
                print_success "Dependency added successfully"
            else
                print_error "Failed to add dependency"
                # Restore backup if it exists
                if [ -f "$app_build_gradle.backup" ]; then
                    mv "$app_build_gradle.backup" "$app_build_gradle"
                fi
                return 1
            fi
        fi
    else
        print_error "Could not find app/build.gradle"
        return 1
    fi

    echo ""

    # Create boilerplate
    read -p "Would you like to create a sample implementation file? (y/n): " create_impl
    if [ "$create_impl" = "y" ] || [ "$create_impl" = "Y" ]; then
        create_android_boilerplate "$project_path" "$domain"
    fi

    echo ""
    print_success "Android SDK integration completed"

    return 0
}
