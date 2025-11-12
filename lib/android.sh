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

    # Convert relative path to absolute path
    project_path=$(cd "$project_path" && pwd)

    # Debug: Show the resolved path
    echo ""
    print_info "Project path: $project_path"

    # Find app build.gradle file
    local app_build_gradle=""
    if [ -f "$project_path/app/build.gradle" ]; then
        app_build_gradle="$project_path/app/build.gradle"
        print_info "Found: app/build.gradle"
    elif [ -f "$project_path/app/build.gradle.kts" ]; then
        app_build_gradle="$project_path/app/build.gradle.kts"
        print_info "Found: app/build.gradle.kts"
    else
        print_error "No app/build.gradle or app/build.gradle.kts file found"
        print_info "Checked: $project_path/app/build.gradle"
        return 1
    fi

    print_info "Using build file: $app_build_gradle"

    # Extract minSdk version (supports: minSdk 28, minSdkVersion 28, minSdk = 28, etc.)
    local min_sdk=""
    min_sdk=$(grep -E "minSdk(Version)?[[:space:]]*(=)?[[:space:]]*[0-9]+" "$app_build_gradle" | grep -oE "[0-9]+" | tail -1)

    # Extract compileSdk version (supports: compileSdk 35, compileSdk = 35, etc.)
    local compile_sdk=""
    compile_sdk=$(grep -E "compileSdk(Version)?[[:space:]]*(=)?[[:space:]]*[0-9]+" "$app_build_gradle" | grep -oE "[0-9]+" | tail -1)

    echo ""
    print_info "Project Configuration:"
    echo "  Min SDK: ${min_sdk:-Not found}"
    echo "  Compile SDK: ${compile_sdk:-Not found}"
    echo ""

    # Verify minSdk (must be >= 28)
    if [ -n "$min_sdk" ]; then
        # Check if min_sdk is a number before comparison
        if ! [[ "$min_sdk" =~ ^[0-9]+$ ]]; then
            print_warning "minSdk was found but could not be parsed as a number: $min_sdk"
        elif [ "$min_sdk" -lt 28 ]; then
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
        if ! [[ "$compile_sdk" =~ ^[0-9]+$ ]]; then
            print_warning "compileSdk was found but could not be parsed as a number: $compile_sdk"
        elif [ "$compile_sdk" -lt 33 ]; then
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

# Compare two semantic versions (returns 0 if v1 >= v2, 1 if v1 < v2)
version_compare() {
    local v1=$1
    local v2=$2

    # Remove any non-numeric prefix/suffix (like "1.9.0-alpha")
    v1=$(echo "$v1" | grep -oE "^[0-9]+\.[0-9]+\.[0-9]+")
    v2=$(echo "$v2" | grep -oE "^[0-9]+\.[0-9]+\.[0-9]+")

    if [ "$v1" = "$v2" ]; then
        return 0
    fi

    local IFS=.
    local i ver1=($v1) ver2=($v2)

    # Fill empty positions with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done

    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]} ]]; then
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 0
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 1
        fi
    done
    return 0
}

# Extract version from dependency line
extract_dependency_version() {
    local dep_line=$1
    echo "$dep_line" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -1
}

# Convert artifact name to camelCase for version key
# Example: core-ktx → coreKtx, webkit → webkit
to_camel_case() {
    local str=$1
    echo "$str" | awk -F'-' '{
        printf "%s", $1
        for(i=2; i<=NF; i++) {
            printf "%s", toupper(substr($i,1,1)) tolower(substr($i,2))
        }
    }'
}

# Get the TOML library key for a dependency
# Returns the key (e.g., "androidx-core-ktx") or empty string if not found
get_toml_library_key() {
    local version_catalog=$1
    local group=$2
    local artifact=$3

    if [ -n "$DEBUG" ]; then
        echo "[DEBUG] get_toml_library_key: Searching for ${group}:${artifact}" >&2
    fi

    # Search for group/name format: group = "androidx.core", name = "core-ktx"
    if [ -n "$DEBUG" ]; then
        echo "[DEBUG] Trying group/name format search..." >&2
    fi

    local line=$(grep -n "group = \"${group}\"" "$version_catalog" 2>/dev/null | grep "name = \"${artifact}\"" | head -1)

    if [ -n "$DEBUG" ]; then
        echo "[DEBUG] group/name search result: '$line'" >&2
    fi

    if [ -n "$line" ]; then
        # Extract the key from the line (e.g., "androidx-core-ktx = { group ...")
        local key=$(echo "$line" | sed 's/^[0-9]*://; s/[[:space:]]*=[[:space:]]*{.*//' | xargs)
        if [ -n "$DEBUG" ]; then
            echo "[DEBUG] Extracted key: '$key'" >&2
        fi
        echo "$key"
        return 0
    fi

    # Search for module format: module = "androidx.core:core-ktx"
    if [ -n "$DEBUG" ]; then
        echo "[DEBUG] Trying module format search..." >&2
    fi

    local line=$(grep -n "module = \"${group}:${artifact}\"" "$version_catalog" 2>/dev/null | head -1)

    if [ -n "$DEBUG" ]; then
        echo "[DEBUG] module search result: '$line'" >&2
    fi

    if [ -n "$line" ]; then
        # Extract the key from the line
        local key=$(echo "$line" | sed 's/^[0-9]*://; s/[[:space:]]*=[[:space:]]*{.*//' | xargs)
        if [ -n "$DEBUG" ]; then
            echo "[DEBUG] Extracted key: '$key'" >&2
        fi
        echo "$key"
        return 0
    fi

    if [ -n "$DEBUG" ]; then
        echo "[DEBUG] Not found in TOML" >&2
    fi

    # Not found
    return 1
}

# Check if dependency exists in TOML
# Searches for either format:
# 1. group = "androidx.core", name = "core-ktx"
# 2. module = "androidx.core:core-ktx"
check_dependency_in_toml() {
    local version_catalog=$1
    local group=$2
    local artifact=$3

    if [ -n "$DEBUG" ]; then
        echo "[DEBUG] Checking TOML for: $group:$artifact" >&2
    fi

    local key=$(get_toml_library_key "$version_catalog" "$group" "$artifact")

    if [ -n "$key" ]; then
        if [ -n "$DEBUG" ]; then
            echo "[DEBUG] Found in TOML with key: $key" >&2
        fi
        return 0
    fi

    if [ -n "$DEBUG" ]; then
        echo "[DEBUG] Not found in TOML" >&2
    fi
    return 1
}

# Simple check: does dependency exist in build.gradle or TOML?
check_dependency_exists() {
    local build_gradle=$1
    local group_artifact=$2
    local required_version=$3
    local project_path=$4

    local group=$(echo "$group_artifact" | cut -d: -f1)
    local artifact=$(echo "$group_artifact" | cut -d: -f2)

    # Check if version catalog exists
    local version_catalog="$project_path/gradle/libs.versions.toml"
    if [ -f "$version_catalog" ]; then
        # Get the actual TOML key
        local toml_key=$(get_toml_library_key "$version_catalog" "$group" "$artifact")

        if [ -n "$toml_key" ]; then
            # Found in TOML, check if referenced in build.gradle
            local lib_ref=$(echo "$toml_key" | tr '-' '.')
            if grep -qF "libs.${lib_ref}" "$build_gradle" 2>/dev/null; then
                return 0  # Exists and is used
            else
                return 1  # In TOML but not in build.gradle
            fi
        else
            return 1  # Not in TOML
        fi
    fi

    # No version catalog, check for direct dependency
    if grep -qF "${group_artifact}:" "$build_gradle" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Add dependency to version catalog (TOML)
add_dependency_to_toml() {
    local version_catalog=$1
    local group=$2
    local artifact=$3
    local version=$4

    # Create version key (camelCase from artifact)
    local version_key=$(to_camel_case "$artifact")

    # Create library key: first-segment + artifact
    # Example: androidx.core:core-ktx → androidx-core-ktx
    local first_segment=$(echo "$group" | cut -d. -f1)
    local lib_key="${first_segment}-${artifact}"

    if [ -n "$DEBUG" ]; then
        echo "[DEBUG] Adding to TOML: key=$lib_key, module=${group}:${artifact}, version=$version" >&2
    fi

    # Add version to [versions] section
    local versions_line=$(grep -n "^\[versions\]" "$version_catalog" | cut -d: -f1)
    if [ -n "$versions_line" ]; then
        # Find the last line before next section
        local next_section=$(tail -n +$((versions_line + 1)) "$version_catalog" | grep -n "^\[" | head -1 | cut -d: -f1)
        if [ -n "$next_section" ]; then
            local insert_line=$((versions_line + next_section - 1))
        else
            # Find end of [versions] section (last non-empty line before next section or EOF)
            local insert_line=$((versions_line + 1))
            while [ $insert_line -le $(wc -l < "$version_catalog") ]; do
                local line_content=$(sed -n "${insert_line}p" "$version_catalog")
                if [ -z "$line_content" ] || [[ "$line_content" =~ ^\[ ]]; then
                    break
                fi
                ((insert_line++))
            done
            ((insert_line--))
        fi

        # Insert version
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "${insert_line}a\\
${version_key} = \"${version}\"
" "$version_catalog"
        else
            sed -i "${insert_line}a\\${version_key} = \"${version}\"" "$version_catalog"
        fi
    fi

    # Add library to [libraries] section using module format
    local libraries_line=$(grep -n "^\[libraries\]" "$version_catalog" | cut -d: -f1)
    if [ -n "$libraries_line" ]; then
        # Find the last line before next section
        local next_section=$(tail -n +$((libraries_line + 1)) "$version_catalog" | grep -n "^\[" | head -1 | cut -d: -f1)
        if [ -n "$next_section" ]; then
            local insert_line=$((libraries_line + next_section - 1))
        else
            # End of file
            local insert_line=$((libraries_line + 1))
            while [ $insert_line -le $(wc -l < "$version_catalog") ]; do
                local line_content=$(sed -n "${insert_line}p" "$version_catalog")
                if [ -z "$line_content" ] || [[ "$line_content" =~ ^\[ ]]; then
                    break
                fi
                ((insert_line++))
            done
            ((insert_line--))
        fi

        # Insert library using module format
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "${insert_line}a\\
${lib_key} = { module = \"${group}:${artifact}\", version.ref = \"${version_key}\" }
" "$version_catalog"
        else
            sed -i "${insert_line}a\\${lib_key} = { module = \"${group}:${artifact}\", version.ref = \"${version_key}\" }" "$version_catalog"
        fi
    fi
}

# Add required dependencies for TrustArc SDK
add_required_dependencies() {
    local app_build_gradle=$1
    local project_path=$2

    echo ""
    print_step "Checking required dependencies..."
    echo ""

    # Required dependencies with TOML aliases
    local required_deps=(
        "androidx.core:core-ktx:1.9.0:coreKtx"
        "androidx.appcompat:appcompat:1.6.1:appcompat"
        "androidx.constraintlayout:constraintlayout:2.1.4:constraintLayout"
        "androidx.webkit:webkit:1.4.0:webkit"
        "androidx.lifecycle:lifecycle-extensions:2.2.0:lifecycleExtensions"
        "androidx.lifecycle:lifecycle-viewmodel-ktx:2.6.2:lifecycleViewmodelKtx"
        "androidx.activity:activity:1.8.0:activity"
        "com.google.android.material:material:1.9.0:material"
        "com.squareup.retrofit2:retrofit:2.9.0:retrofit"
        "com.squareup.retrofit2:converter-gson:2.9.0:retrofitConverterGson"
    )

    local version_catalog="$project_path/gradle/libs.versions.toml"
    local use_toml=false

    if [ -f "$version_catalog" ]; then
        use_toml=true
        print_info "Using version catalog with duplicate checking"

        # Ensure [versions] and [libraries] sections exist (using fixed sed syntax if needed)
        grep -q "^\[versions\]" "$version_catalog" || echo -e "\n[versions]" >> "$version_catalog"
        grep -q "^\[libraries\]" "$version_catalog" || echo -e "\n[libraries]" >> "$version_catalog"
    else
        print_info "Using direct gradle dependencies"
    fi

    local added_count=0

    for dep in "${required_deps[@]}"; do
        IFS=':' read -r group name version default_alias <<< "$dep"
        local alias=$default_alias
        local gradle_ref_alias=$(echo "$alias" | tr '-' '.')
		local toml_ref="libs.$gradle_ref_alias"

        if [ "$use_toml" = true ]; then
            # --- 0. CHECK FOR EXISTING ARTIFACT (GROUP:NAME) ---
            local existing_alias=$(awk -v GRP="$group" -v NM="$name" '
                /^\[libraries\]/{in_libraries=1; next}
                /^\[/{in_libraries=0}
                in_libraries && $0 !~ /^\s*$/ && $0 !~ /^#/ {
                    if (($0 ~ "group = \"" GRP "\"" && $0 ~ "name = \"" NM "\"") || $0 ~ "module = \"" GRP ":" NM "\"") {
                        split($0, arr, " =");
                        gsub(/^[ \t]+/, "", arr[1]);
                        print arr[1];
                        exit;
                    }
                }' "$version_catalog")

            if [ -n "$existing_alias" ]; then
                # ARTIFACT EXISTS: Use the existing alias and skip adding library/version.
                alias=$existing_alias
				gradle_ref_alias=$(echo "$alias" | tr '-' '.')
				toml_ref="libs.$gradle_ref_alias"
                print_substep "✓ $name (found as $alias in TOML)"
            else
                # ARTIFACT MISSING: Add new version and library definition using default_alias

                # 1. Check/Add version (ensures version keys are added if missing)
                if ! grep -q "^$alias[[:space:]]*=" "$version_catalog"; then
                    print_substep "+ Adding version: $alias = \"$version\""
                    local version_entry="$alias = \"$version\""
                    if [[ "$OSTYPE" == "darwin"* ]]; then
                        sed -i '' "/^\[versions\]/a\\
$version_entry
" "$version_catalog"
                    else
                        # Note: The logic for Linux sed needs adjustment if it doesn't support \n
                        sed -i "/^\[versions\]/a\\$version_entry" "$version_catalog"
                    fi
                fi

                # 2. Add library definition (ensures the definition is added if missing)
                if ! grep -q "^$alias[[:space:]]*={" "$version_catalog"; then
                    print_substep "+ Adding library: $alias"
                    local library_entry="$alias = { group = \"$group\", name = \"$name\", version.ref = \"$alias\" }"
                    if [[ "$OSTYPE" == "darwin"* ]]; then
                        sed -i '' "/^\[libraries\]/a\\
$library_entry
" "$version_catalog"
                    else
                        sed -i "/^\[libraries\]/a\\$library_entry" "$version_catalog"
                    fi
                fi
            fi

            # --- 3. CHECK/UPDATE BUILD.GRADLE ---
            # Check if the old dependency string is present in the Gradle file
            if grep -q "implementation.*$group:$name" "$app_build_gradle"; then
                # Dependency artifact found. Check if it uses the current TOML reference.
                if ! grep -q "implementation.*$toml_ref" "$app_build_gradle"; then
                    print_substep "→ Updating $name to use $toml_ref"
                    # Replace the old implementation line (Groovy/Kotlin string) with the new reference
                    # Note: Using | as delimiter for sed to avoid escaping slashes in dependency string
                    if [[ "$OSTYPE" == "darwin"* ]]; then
                        # macOS/BSD sed with fixed syntax
                        sed -i '' "s|implementation([\"']$group:$name[^\"']*[\"'])|implementation($toml_ref)|g" "$app_build_gradle"
                    else
                        # Linux/GNU sed with fixed syntax
                        sed -i "s|implementation([\"']$group:$name[^\"']*[\"'])|implementation($toml_ref)|g" "$app_build_gradle"
                    fi
                    ((added_count++))
                else
                    print_substep "✓ $name (already using $toml_ref)"
                fi
            else
                # Dependency is completely missing from the Gradle file.
                if ! grep -q "implementation.*$toml_ref" "$app_build_gradle"; then
                    print_substep "+ Adding $toml_ref to build.gradle"
                    local implementation_entry="    implementation($toml_ref)"
                    if [[ "$OSTYPE" == "darwin"* ]]; then
                        # macOS/BSD sed with fixed syntax
                        sed -i '' "/dependencies[[:space:]]*{/a\\
$implementation_entry
" "$app_build_gradle"
                    else
                        # Linux/GNU sed with fixed syntax
                        sed -i "/dependencies[[:space:]]*{/a\\$implementation_entry" "$app_build_gradle"
                    fi
                    ((added_count++))
                fi
            fi
        else
            # --- DIRECT GRADLE MODE (NO TOML) ---
            local full_dep="${group}:${name}:${version}"

            if grep -q "implementation([\"']$full_dep[\"'])" "$app_build_gradle"; then
                print_substep "✓ $name (already present)"
            elif grep -q "implementation([\"']$group:$name" "$app_build_gradle"; then
                print_substep "⚠ $name found with different version (skipping)"
            else
                print_substep "+ Adding $full_dep"
                local implementation_entry="    implementation(\"$full_dep\")"
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    sed -i '' "/dependencies[[:space:]]*{/a\\
$implementation_entry
" "$app_build_gradle"
                else
                    sed -i "/dependencies[[:space:]]*{/a\\$implementation_entry" "$app_build_gradle"
                fi
                ((added_count++))
            fi
        fi
    done

    echo ""
    if [ $added_count -eq 0 ]; then
        print_success "All required dependencies are already present"
    else
        print_success "Added/updated $added_count dependencies"
    fi

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

    # Add required dependencies
    if [ -n "$app_build_gradle" ]; then
        add_required_dependencies "$app_build_gradle" "$project_path"
    fi

    echo ""

    # Create boilerplate
    read -p "Would you like to create a sample implementation file? (y/n): " create_impl
    if [ "$create_impl" = "y" ] || [ "$create_impl" = "Y" ]; then
        create_android_boilerplate "$project_path" "$domain"
    fi

    echo ""
    print_success "Android SDK integration completed"
    echo ""
    print_info "Documentation:"
    print_substep "• Android SDK: https://trustarchelp.zendesk.com/hc/en-us/sections/32824103168019-Android"
    print_substep "• API Reference: Check TrustArcConsentImpl.kt for available methods"
    echo ""

    return 0
}

