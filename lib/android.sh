#!/bin/bash

# Android integration functions for TrustArc CLI
# This file contains logic for Android SDK integration

# Detect Android project language (Kotlin or Java)
detect_android_language() {
    local project_path=$1

    # Check for Kotlin plugin in build.gradle files
    local has_kotlin_plugin=false
    if grep -r "kotlin-android" "$project_path" --include="build.gradle*" >/dev/null 2>&1; then
        has_kotlin_plugin=true
    fi

    # Count Kotlin and Java files
    local kotlin_count=$(find "$project_path" -name "*.kt" -not -path "*/build/*" 2>/dev/null | wc -l | tr -d ' ')
    local java_count=$(find "$project_path" -name "*.java" -not -path "*/build/*" 2>/dev/null | wc -l | tr -d ' ')

    # Determine primary language
    if [ "$has_kotlin_plugin" = true ] || [ "$kotlin_count" -gt "$java_count" ]; then
        echo "kotlin"
    else
        echo "java"
    fi
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

# Find gradle repositories block in build.gradle
find_repositories_block() {
    local build_gradle=$1

    # Find line number of repositories block
    grep -n "repositories[[:space:]]*{" "$build_gradle" | head -1 | cut -d: -f1
}

# Add Maven repository to build.gradle
add_maven_repository() {
    local build_gradle=$1
    local maven_url=$2

    # Check if repository already exists
    if grep -q "$maven_url" "$build_gradle"; then
        print_info "Maven repository already exists in build.gradle"
        return 0
    fi

    # Backup build.gradle
    cp "$build_gradle" "$build_gradle.backup"

    # Find repositories block
    local repo_line=$(find_repositories_block "$build_gradle")

    if [ -z "$repo_line" ]; then
        print_error "Could not find repositories block in build.gradle"
        return 1
    fi

    # Add maven repository after repositories block opening
    local insert_line=$((repo_line + 1))
    local maven_entry="        maven { url \"$maven_url\" }"

    # Insert maven repository
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "${insert_line}i\\
${maven_entry}
" "$build_gradle"
    else
        # Linux
        sed -i "${insert_line}i\\${maven_entry}" "$build_gradle"
    fi

    return 0
}

# Add TrustArc dependency to app/build.gradle
add_trustarc_dependency() {
    local app_build_gradle=$1
    local version=${2:-"latest"}

    # Check if TrustArc SDK already exists
    if grep -q "trustarc-consent-sdk" "$app_build_gradle"; then
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
    local dependency_entry="    implementation 'com.trustarc.mobile:trustarc-consent-sdk:$version'"

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

    print_success "Added TrustArc SDK dependency"
    return 0
}

# Create Android boilerplate implementation
create_android_boilerplate() {
    local project_path=$1
    local domain=$2
    local language=$3

    local file_extension
    local template_file
    local file_name

    if [ "$language" = "kotlin" ]; then
        file_extension="kt"
        template_file="TrustArcConsentImpl.kt"
        file_name="TrustArcConsentImpl.kt"
    else
        file_extension="java"
        template_file="TrustArcConsentImpl.java"
        file_name="TrustArcConsentImpl.java"
    fi

    echo ""
    print_step "Finding source directory..."

    # Find the main source directory
    local src_dir=$(find "$project_path" -path "*/src/main/$language" -type d -not -path "*/build/*" | head -1)

    if [ -z "$src_dir" ]; then
        print_warning "Could not find src/main/$language directory"
        src_dir="$project_path/app/src/main/$language"
        print_info "Using default path: $src_dir"
    else
        print_success "Found source directory: ${src_dir#$project_path/}"
    fi

    # Find the package directory
    local package_dir=$(find "$src_dir" -type d -not -path "*/build/*" | head -2 | tail -1)

    if [ -z "$package_dir" ]; then
        package_dir="$src_dir"
        print_warning "Could not detect package structure, using source root"
    fi

    local target_file="$package_dir/$file_name"

    # Check if file already exists
    if [ -f "$target_file" ]; then
        print_warning "$file_name already exists at: ${target_file#$project_path/}"
        echo ""
        read -p "Overwrite it? (y/n): " overwrite
        if [ "$overwrite" != "y" ] && [ "$overwrite" != "Y" ]; then
            print_info "Skipped creating boilerplate"
            return 0
        fi
    fi

    # Get the script directory (where android.sh is located)
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    local source_template="$script_dir/$template_file"

    # Check if template exists locally
    if [ ! -f "$source_template" ]; then
        print_error "Template file not found: $source_template"
        return 1
    fi

    # Copy template to target location
    cp "$source_template" "$target_file"

    # Replace domain placeholder
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/__TRUSTARC_DOMAIN_PLACEHOLDER__/$domain/g" "$target_file"
    else
        # Linux
        sed -i "s/__TRUSTARC_DOMAIN_PLACEHOLDER__/$domain/g" "$target_file"
    fi

    # Detect package name from directory structure
    local package_name=$(echo "$package_dir" | sed "s|$src_dir/||" | tr '/' '.')

    if [ -n "$package_name" ] && [ "$package_name" != "." ]; then
        # Add package declaration at the top of the file
        local temp_file="$target_file.tmp"
        echo "package $package_name;" > "$temp_file"
        echo "" >> "$temp_file"
        cat "$target_file" >> "$temp_file"
        mv "$temp_file" "$target_file"

        print_success "Added package declaration: $package_name"
    fi

    echo ""
    print_success "Created $file_name at: ${target_file#$project_path/}"
    echo ""
    print_substep "Domain configured: $domain"

    return 0
}

# Integrate Android SDK
integrate_android_sdk() {
    local project_path=$1

    print_header "Android SDK Integration"

    # Detect project language
    local language=$(detect_android_language "$project_path")

    print_info "Detected language: $language"
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
    print_substep "Language: $language"
    echo ""
    print_step "What will be done:"
    print_substep "Add TrustArc Maven repository to project build.gradle"
    print_substep "Add TrustArc SDK dependency to app/build.gradle"
    print_substep "Create implementation file (TrustArcConsentImpl.$([[ $language == "kotlin" ]] && echo "kt" || echo "java"))"
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

    # Add Maven repository to project build.gradle
    if [ -n "$project_build_gradle" ]; then
        print_info "Adding Maven repository..."

        # For now, we'll just inform the user to add it manually
        print_warning "Please add the TrustArc Maven repository manually to your project-level build.gradle"
        echo ""
        echo "  repositories {"
        echo "      maven { url 'https://trustarc.jfrog.io/artifactory/mobile-consent-android/' }"
        echo "  }"
        echo ""
    fi

    # Add dependency to app/build.gradle
    if [ -n "$app_build_gradle" ]; then
        print_info "Adding TrustArc dependency to app/build.gradle..."

        if add_trustarc_dependency "$app_build_gradle" "1.0.0"; then
            print_success "Dependency added successfully"
        else
            print_error "Failed to add dependency"
            return 1
        fi
    fi

    echo ""

    # Create boilerplate
    read -p "Would you like to create the implementation file? (y/n): " create_impl
    if [ "$create_impl" = "y" ] || [ "$create_impl" = "Y" ]; then
        create_android_boilerplate "$project_path" "$domain" "$language"
    fi

    echo ""
    print_success "Android SDK integration completed"
    echo ""
    print_step "Next steps:"
    print_substep "Sync your Gradle project in Android Studio"
    print_substep "Initialize TrustArc in your Application class:"
    echo ""
    if [ "$language" = "kotlin" ]; then
        echo "  ${DIM}class MyApplication : Application() {${NC}"
        echo "      ${DIM}override fun onCreate() {${NC}"
        echo "          ${DIM}super.onCreate()${NC}"
        echo "          ${GREEN}TrustArcConsentImpl.initialize(this)${NC}"
        echo "      ${DIM}}${NC}"
        echo "  ${DIM}}${NC}"
    else
        echo "  ${DIM}public class MyApplication extends Application {${NC}"
        echo "      ${DIM}@Override${NC}"
        echo "      ${DIM}public void onCreate() {${NC}"
        echo "          ${DIM}super.onCreate();${NC}"
        echo "          ${GREEN}TrustArcConsentImpl.getInstance().initialize(this);${NC}"
        echo "      ${DIM}}${NC}"
        echo "  ${DIM}}${NC}"
    fi
    echo ""
    print_substep "To show consent dialog:"
    if [ "$language" = "kotlin" ]; then
        echo "      ${GREEN}TrustArcConsentImpl.openCm()${NC}"
    else
        echo "      ${GREEN}TrustArcConsentImpl.getInstance().openCm();${NC}"
    fi
    echo ""

    return 0
}
