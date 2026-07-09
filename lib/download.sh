#!/bin/bash

# Download and configuration functions for TrustArc CLI
# This file contains sample app download and config update logic

SAMPLE_REPO_OWNER="trustarc"
SAMPLE_REPO_NAME="ccm-mobile-consent-test-apps"
# Sample app ref selection priority:
# 1) APP_VERSION (explicit override for sample app ref)
# 2) TRUSTARC_REF (shared ref)
# 3) REPO_REF when explicitly provided
# 4) "release" (default)
if [ -n "${APP_VERSION:-}" ]; then
    SAMPLE_REPO_BRANCH="$APP_VERSION"
elif [ -n "${TRUSTARC_REF:-}" ]; then
    SAMPLE_REPO_BRANCH="$TRUSTARC_REF"
elif [ -n "${REPO_REF:-}" ] && [ "${REPO_REF_IS_DEFAULT:-0}" != "1" ]; then
    SAMPLE_REPO_BRANCH="$REPO_REF"
else
    SAMPLE_REPO_BRANCH="release"
fi

sample_repo_archive_url() {
    local ref="$1"
    local ref_kind="$2"

    case "$ref_kind" in
        "branch")
            echo "https://github.com/${SAMPLE_REPO_OWNER}/${SAMPLE_REPO_NAME}/archive/refs/heads/${ref}.zip"
            ;;
        "tag")
            echo "https://github.com/${SAMPLE_REPO_OWNER}/${SAMPLE_REPO_NAME}/archive/refs/tags/${ref}.zip"
            ;;
        "commit")
            echo "https://github.com/${SAMPLE_REPO_OWNER}/${SAMPLE_REPO_NAME}/archive/${ref}.zip"
            ;;
        *)
            return 1
            ;;
    esac
}

sample_repo_source_url() {
    local ref="$1"
    local ref_kind="$2"

    case "$ref_kind" in
        "branch"|"tag")
            echo "https://github.com/${SAMPLE_REPO_OWNER}/${SAMPLE_REPO_NAME}/tree/${ref}"
            ;;
        "commit")
            echo "https://github.com/${SAMPLE_REPO_OWNER}/${SAMPLE_REPO_NAME}/commit/${ref}"
            ;;
        *)
            return 1
            ;;
    esac
}

download_archive_for_ref() {
    local ref="$1"
    local token="$2"
    local output_zip="$3"
    local ref_kind=""
    local archive_url=""

    for ref_kind in "branch" "tag" "commit"; do
        archive_url=$(sample_repo_archive_url "$ref" "$ref_kind") || continue

        if command -v curl >/dev/null 2>&1; then
            if curl -fsSL -H "Authorization: token $token" "$archive_url" -o "$output_zip"; then
                echo "$ref_kind"
                return 0
            fi
        elif command -v wget >/dev/null 2>&1; then
            if wget -q --header="Authorization: token $token" "$archive_url" -O "$output_zip"; then
                echo "$ref_kind"
                return 0
            fi
        else
            print_error "Neither curl nor wget is available"
            return 2
        fi
    done

    return 1
}

# Dependency checks for sample app platforms
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

is_macos() {
    [[ "$OSTYPE" == "darwin"* ]]
}

# Escape text for safe sed replacement values.
sed_escape_replacement() {
    printf '%s' "$1" | sed -e 's/[\\|&]/\\&/g'
}

sample_stream_to_env() {
    local stream=$1

    case "$stream" in
        current) echo "prod" ;;
        stable) echo "stable" ;;
        stage) echo "staging" ;;
        qa) echo "qa" ;;
        dev) echo "dev" ;;
        *) return 1 ;;
    esac
}

sample_stream_label() {
    local stream=$1

    case "$stream" in
        current) echo "Current" ;;
        stable) echo "Stable" ;;
        stage) echo "Stage" ;;
        qa) echo "QA" ;;
        dev) echo "Dev" ;;
        *) echo "$stream" ;;
    esac
}

android_artifact_for_stream() {
    local stream=$1

    case "$stream" in
        current) echo "trustarc-consent-sdk" ;;
        stable) echo "trustarc-consent-sdk-stable" ;;
        stage) echo "trustarc-consent-sdk-staging" ;;
        qa) echo "trustarc-consent-sdk-qa" ;;
        dev) echo "trustarc-consent-sdk-dev" ;;
        *) return 1 ;;
    esac
}

react_package_for_stream() {
    local stream=$1

    case "$stream" in
        current|stable) echo "@trustarc/trustarc-react-native-consent-sdk" ;;
        stage) echo "@trustarc/trustarc-react-native-consent-sdk-staging" ;;
        qa) echo "@trustarc/trustarc-react-native-consent-sdk-qa" ;;
        dev) echo "@trustarc/trustarc-react-native-consent-sdk-dev" ;;
        *) return 1 ;;
    esac
}

filter_stable_2026_01_versions() {
    if command -v python3 >/dev/null 2>&1; then
        python3 -c '
import re
import sys

matches = []
for raw in sys.stdin:
    value = raw.strip()
    match = re.search(r"2026\.0?1\.(\d+)$", value)
    if match and int(match.group(1)) > 3:
        matches.append(value)

for value in matches:
    print(value)
'
    else
        awk '
            match($0, /2026\.0?1\.([0-9]+)$/, m) {
                if (m[1] + 0 > 3) print
            }
        '
    fi
}

filter_tags_for_platform_stream() {
    local platform=$1
    local stream=$2
    local platform_key=""
    local env_key=""

    case "$platform" in
        ios|ios-spm) platform_key="ios" ;;
        flutter) platform_key="flutter" ;;
        *) cat; return 0 ;;
    esac

    case "$stream" in
        current)
            grep -v -- "-dev" | grep -v -- "-qa" | grep -v -- "-staging" | grep -v -- "-stage"
            ;;
        stable)
            filter_stable_2026_01_versions
            ;;
        dev|qa)
            env_key="$stream"
            grep -- "-${platform_key}-${env_key}"
            ;;
        stage)
            env_key="staging"
            grep -- "-${platform_key}-${env_key}"
            ;;
        *)
            cat
            ;;
    esac
}

list_sample_sdk_versions() {
    local platform=$1
    local stream=$2
    local env
    local artifact
    local package_name

    env=$(sample_stream_to_env "$stream") || return 1

    case "$platform" in
        android)
            artifact=$(android_artifact_for_stream "$stream") || return 1
            fetch_android_sdk_versions_for_artifact "$artifact" | head -20
            ;;
        react-native|react-native-baremetal)
            package_name=$(react_package_for_stream "$stream") || return 1
            if [ "$stream" = "stable" ]; then
                fetch_npm_package_versions "$package_name" | filter_stable_2026_01_versions | sort -Vr | head -20
            else
                fetch_npm_package_versions "$package_name" | sort -Vr | head -20
            fi
            ;;
        ios|ios-spm|flutter)
            fetch_repo_tags "trustarc/trustarc-mobile-consent" | filter_tags_for_platform_stream "$platform" "$stream" | sort -Vr | head -20
            ;;
        *)
            return 1
            ;;
    esac
}

select_from_numbered_list() {
    local prompt=$1
    shift
    local values=("$@")
    local choice=""
    local index=0

    [ "${#values[@]}" -gt 0 ] || return 1
    SELECTED_NUMBERED_VALUE=""

    echo ""
    print_info "$prompt"
    for index in "${!values[@]}"; do
        printf "  ${BOLD}%s${NC}) %s\n" "$((index + 1))" "${values[$index]}"
    done
    echo ""

    while true; do
        read -p "Enter your choice (1-${#values[@]}): " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#values[@]}" ]; then
            SELECTED_NUMBERED_VALUE="${values[$((choice - 1))]}"
            return 0
        fi
        print_error "Invalid choice"
    done
}

select_sample_sdk_stream() {
    local platform=$1
    local default_stream="${SDK_STREAM:-current}"
    local default_choice="1"
    local stream_choice=""
    local stream=""
    local stream_label=""
    local versions_raw=""
    local selected_version=""
    local env=""
    local artifact=""
    local package_name=""
    local version=""

    case "$default_stream" in
        current) default_choice="1" ;;
        stable) default_choice="2" ;;
        stage) default_choice="3" ;;
        qa) default_choice="4" ;;
        dev) default_choice="5" ;;
    esac

    echo ""
    echo "Select SDK stream:"
    echo ""
    printf "  ${BOLD}1${NC}) Current\n"
    printf "  ${BOLD}2${NC}) Stable\n"
    printf "  ${BOLD}3${NC}) Stage\n"
    printf "  ${BOLD}4${NC}) QA\n"
    printf "  ${BOLD}5${NC}) Dev\n"
    echo ""
    read -p "Enter your choice (1-5, default: $default_choice): " stream_choice
    stream_choice=${stream_choice:-$default_choice}

    case "$stream_choice" in
        1) stream="current" ;;
        2) stream="stable" ;;
        3) stream="stage" ;;
        4) stream="qa" ;;
        5) stream="dev" ;;
        *) print_error "Invalid SDK stream"; select_sample_sdk_stream "$platform"; return ;;
    esac

    save_config "SDK_STREAM" "$stream"
    SDK_STREAM="$stream"
    stream_label=$(sample_stream_label "$stream")

    print_info "Fetching $stream_label versions..."
    versions_raw=$(list_sample_sdk_versions "$platform" "$stream" 2>/dev/null || true)

    if [ -n "$versions_raw" ]; then
        local versions=()
        while IFS= read -r version; do
            [ -n "$version" ] && versions+=("$version")
        done <<< "$versions_raw"
        select_from_numbered_list "Select $stream_label SDK version:" "${versions[@]}"
        selected_version="$SELECTED_NUMBERED_VALUE"
    else
        print_warning "Could not fetch versions for $stream_label. Falling back to manual entry."
        read -p "Enter SDK version/ref: " selected_version
        while [ -z "$selected_version" ]; do
            print_error "SDK version/ref cannot be empty."
            read -p "Enter SDK version/ref: " selected_version
        done
    fi

    env=$(sample_stream_to_env "$stream")
    SAMPLE_SDK_STREAM="$stream"
    SAMPLE_SDK_VERSION="$selected_version"

    case "$platform" in
        android)
            artifact=$(android_artifact_for_stream "$stream")
            ANDROID_SAMPLE_SDK_ENV="$env"
            ANDROID_SAMPLE_SDK_MODULE="com.trustarc:${artifact}"
            ANDROID_SAMPLE_SDK_VERSION="$selected_version"
            save_config "ANDROID_SAMPLE_SDK_ENV" "$env"
            save_config "ANDROID_SAMPLE_SDK_VERSION" "$selected_version"
            ;;
        react-native|react-native-baremetal)
            package_name=$(react_package_for_stream "$stream")
            REACT_SAMPLE_SDK_ENV="$env"
            if [ "$stream" = "current" ] || [ "$stream" = "stable" ]; then
                SAMPLE_SDK_VERSION="$selected_version"
                REACT_SAMPLE_SDK_VERSION="$selected_version"
            else
                SAMPLE_SDK_VERSION="npm:${package_name}@${selected_version}"
                REACT_SAMPLE_SDK_VERSION="$SAMPLE_SDK_VERSION"
            fi
            save_config "REACT_SAMPLE_SDK_ENV" "$env"
            save_config "REACT_SAMPLE_SDK_VERSION" "$REACT_SAMPLE_SDK_VERSION"
            ;;
        ios|ios-spm)
            IOS_SAMPLE_SDK_VERSION="$selected_version"
            save_config "IOS_SAMPLE_SDK_VERSION" "$selected_version"
            ;;
        flutter)
            FLUTTER_SAMPLE_SDK_VERSION="$selected_version"
            save_config "FLUTTER_SAMPLE_SDK_VERSION" "$selected_version"
            ;;
    esac

    print_success "Selected $stream_label SDK version: $selected_version"
}

detect_android_sdk() {
    local candidates=()

    if [ -n "$ANDROID_SDK_ROOT" ]; then
        candidates+=("$ANDROID_SDK_ROOT")
    fi
    if [ -n "$ANDROID_HOME" ]; then
        candidates+=("$ANDROID_HOME")
    fi
    candidates+=("$HOME/Library/Android/sdk" "$HOME/Android/Sdk")

    local path=""
    for path in "${candidates[@]}"; do
        if [ -n "$path" ] && [ -d "$path" ]; then
            echo "$path"
            return 0
        fi
    done

    if command_exists sdkmanager; then
        echo "sdkmanager"
        return 0
    fi

    return 1
}

check_platform_dependencies() {
    local platform=$1
    local -a missing=()
    local -a warnings=()
    local ios_ok=0
    local android_ok=0
    local has_java=0
    local has_android_sdk=0

    print_step "Checking dependencies for $platform..."

    case "$platform" in
        "ios")
            if ! is_macos; then
                missing+=("macOS (required for iOS builds)")
            else
                command_exists xcodebuild || missing+=("Xcode Command Line Tools (xcodebuild)")
                command_exists pod || missing+=("CocoaPods (pod)")
            fi
            ;;
        "ios-spm")
            if ! is_macos; then
                missing+=("macOS (required for iOS builds)")
            else
                command_exists xcodebuild || missing+=("Xcode Command Line Tools (xcodebuild)")
            fi
            ;;
        "android")
            command_exists java || missing+=("Java (JDK)")
            if ! detect_android_sdk >/dev/null 2>&1; then
                missing+=("Android SDK (ANDROID_SDK_ROOT/ANDROID_HOME or sdkmanager)")
            fi
            ;;
        "react-native")
            command_exists node || missing+=("Node.js (node)")
            command_exists npm || missing+=("npm")
            command_exists npx || missing+=("npx")

            if is_macos; then
                command_exists xcodebuild || warnings+=("Xcode not found (required for iOS runs)")
                command_exists pod || warnings+=("CocoaPods not found (required for iOS runs)")
                if command_exists xcodebuild && command_exists pod; then
                    ios_ok=1
                fi
            else
                warnings+=("iOS builds require macOS + Xcode")
            fi

            if command_exists java; then
                has_java=1
            else
                warnings+=("Java (JDK) not found (required for Android runs)")
            fi
            if detect_android_sdk >/dev/null 2>&1; then
                has_android_sdk=1
            else
                warnings+=("Android SDK not found (required for Android runs)")
            fi
            if [ "$has_java" -eq 1 ] && [ "$has_android_sdk" -eq 1 ]; then
                android_ok=1
            fi

            if [ "$ios_ok" -eq 0 ] && [ "$android_ok" -eq 0 ]; then
                missing+=("iOS (Xcode + CocoaPods) or Android (JDK + SDK) toolchain")
            fi
            ;;
        "react-native-baremetal")
            command_exists node || missing+=("Node.js (node)")
            command_exists yarn || missing+=("Yarn (yarn)")

            if is_macos; then
                command_exists xcodebuild || warnings+=("Xcode not found (required for iOS runs)")
                command_exists pod || warnings+=("CocoaPods not found (required for iOS runs)")
                if command_exists xcodebuild && command_exists pod; then
                    ios_ok=1
                fi
            else
                warnings+=("iOS builds require macOS + Xcode")
            fi

            if command_exists java; then
                has_java=1
            else
                warnings+=("Java (JDK) not found (required for Android runs)")
            fi
            if detect_android_sdk >/dev/null 2>&1; then
                has_android_sdk=1
            else
                warnings+=("Android SDK not found (required for Android runs)")
            fi
            if [ "$has_java" -eq 1 ] && [ "$has_android_sdk" -eq 1 ]; then
                android_ok=1
            fi

            if [ "$ios_ok" -eq 0 ] && [ "$android_ok" -eq 0 ]; then
                missing+=("iOS (Xcode + CocoaPods) or Android (JDK + SDK) toolchain")
            fi
            ;;
        "flutter")
            command_exists flutter || missing+=("Flutter SDK (flutter)")

            if is_macos; then
                command_exists xcodebuild || warnings+=("Xcode not found (required for iOS runs)")
                command_exists pod || warnings+=("CocoaPods not found (required for iOS runs)")
                if command_exists xcodebuild && command_exists pod; then
                    ios_ok=1
                fi
            else
                warnings+=("iOS builds require macOS + Xcode")
            fi

            if command_exists java; then
                has_java=1
            else
                warnings+=("Java (JDK) not found (required for Android runs)")
            fi
            if detect_android_sdk >/dev/null 2>&1; then
                has_android_sdk=1
            else
                warnings+=("Android SDK not found (required for Android runs)")
            fi
            if [ "$has_java" -eq 1 ] && [ "$has_android_sdk" -eq 1 ]; then
                android_ok=1
            fi

            if [ "$ios_ok" -eq 0 ] && [ "$android_ok" -eq 0 ]; then
                missing+=("iOS (Xcode + CocoaPods) or Android (JDK + SDK) toolchain")
            fi
            ;;
    esac

    if [ ${#warnings[@]} -gt 0 ]; then
        print_warning "Optional platform tooling not detected:"
        local warning=""
        for warning in "${warnings[@]}"; do
            print_substep "$warning"
        done
        echo ""
    fi

    if [ ${#missing[@]} -eq 0 ]; then
        print_success "Dependency check passed"
        return 0
    fi

    print_error "Missing required dependencies for $platform:"
    local item=""
    for item in "${missing[@]}"; do
        print_substep "$item"
    done
    echo ""
    read -p "Continue download anyway? (y/n): " continue_download
    if [ "$continue_download" != "y" ] && [ "$continue_download" != "Y" ]; then
        print_info "Download canceled. Install the missing dependencies and try again."
        return 1
    fi

    return 0
}

# Update configuration files in extracted sample app
update_config_files() {
    local platform=$1
    local extract_dir=$2
    local domain=$3
    local website=$4
    local sdk_version=$5
    local escaped_domain
    local escaped_website
    local escaped_token

    escaped_domain=$(sed_escape_replacement "$domain")
    escaped_website=$(sed_escape_replacement "$website")
    escaped_token=$(sed_escape_replacement "$TRUSTARC_TOKEN")

    # Resolve per-platform SDK versions from the ccm-mobile-preview versions JSON
    # when sdk_version is a channel name ("release"/"stable") or empty.
    local ios_sdk_ver android_sdk_ver rn_sdk_ver flutter_sdk_ver
    if [ "$sdk_version" = "release" ] || [ "$sdk_version" = "stable" ] || [ -z "$sdk_version" ]; then
        local sdk_channel="${sdk_version:-release}"
        local _sdk_json="/tmp/trustarc-sdk-versions-$$.json"
        local _sdk_fetched=0
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL "https://ccm-mobile-preview.vercel.app/docs/sdk-versions.json" -o "$_sdk_json" 2>/dev/null && _sdk_fetched=1 || true
        elif command -v wget >/dev/null 2>&1; then
            wget -q "https://ccm-mobile-preview.vercel.app/docs/sdk-versions.json" -O "$_sdk_json" 2>/dev/null && _sdk_fetched=1 || true
        fi
        if [ "$_sdk_fetched" -eq 1 ] && [ -s "$_sdk_json" ] && command -v python3 >/dev/null 2>&1; then
            ios_sdk_ver=$(JSON_FILE="$_sdk_json" CHANNEL="$sdk_channel" FIELD="ios"         python3 -c "import json,os; d=json.load(open(os.environ['JSON_FILE'])); print(d.get(os.environ['CHANNEL'],{}).get(os.environ['FIELD'],''))" 2>/dev/null || echo "$sdk_channel")
            android_sdk_ver=$(JSON_FILE="$_sdk_json" CHANNEL="$sdk_channel" FIELD="android"     python3 -c "import json,os; d=json.load(open(os.environ['JSON_FILE'])); print(d.get(os.environ['CHANNEL'],{}).get(os.environ['FIELD'],''))" 2>/dev/null || echo "")
            rn_sdk_ver=$(JSON_FILE="$_sdk_json" CHANNEL="$sdk_channel" FIELD="reactNative"  python3 -c "import json,os; d=json.load(open(os.environ['JSON_FILE'])); print(d.get(os.environ['CHANNEL'],{}).get(os.environ['FIELD'],''))" 2>/dev/null || echo "")
            flutter_sdk_ver=$(JSON_FILE="$_sdk_json" CHANNEL="$sdk_channel" FIELD="flutter"     python3 -c "import json,os; d=json.load(open(os.environ['JSON_FILE'])); print(d.get(os.environ['CHANNEL'],{}).get(os.environ['FIELD'],''))" 2>/dev/null || echo "$sdk_channel")
            rm -f "$_sdk_json"
        else
            rm -f "$_sdk_json" 2>/dev/null
            ios_sdk_ver="$sdk_channel"
            android_sdk_ver=""
            rn_sdk_ver=""
            flutter_sdk_ver="$sdk_channel"
        fi
    else
        # Explicit version override (e.g. a specific dev tag) — iOS/Flutter use it as-is
        ios_sdk_ver="$sdk_version"
        android_sdk_ver="$sdk_version"
        rn_sdk_ver="$sdk_version"
        flutter_sdk_ver="$sdk_version"
    fi

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
                sed -i.bak "s|let macDomain: String = \".*\"|let macDomain: String = \"$escaped_domain\"|" "$ios_config"
                # Update testWebsiteUrl
                sed -i.bak "s|let testWebsiteUrl: String = \".*\"|let testWebsiteUrl: String = \"$escaped_website\"|" "$ios_config"
                rm -f "${ios_config}.bak"
                print_success "Updated iOS AppConfig.swift"
            else
                print_warning "iOS AppConfig.swift not found in $app_dir"
            fi

            # Update iOS Podfile with token
            local ios_podfile=$(find "$app_dir" -name "Podfile" -maxdepth 2 2>/dev/null | head -1)
            if [ -f "$ios_podfile" ] && [ -n "$TRUSTARC_TOKEN" ]; then
                sed -i.bak "s|YOUR_TRUSTARC_TOKEN|$escaped_token|g" "$ios_podfile"
                rm -f "${ios_podfile}.bak"
                print_success "Updated iOS Podfile with authentication token"
            fi

            # Update iOS TrustArc SDK version tag if provided
            if [ -n "$ios_sdk_ver" ] && [ -f "$ios_podfile" ]; then
                local escaped_ios_sdk_ver
                escaped_ios_sdk_ver=$(sed_escape_replacement "$ios_sdk_ver")
                sed -E -i.bak "/pod[[:space:]]+['\"]TrustArcConsentSDK['\"]/ s|:tag[[:space:]]*=>[[:space:]]*['\"][^'\"]*['\"]|:tag => '$escaped_ios_sdk_ver'|g" "$ios_podfile"
                rm -f "${ios_podfile}.bak"
                print_success "Updated iOS TrustArc SDK version tag: $ios_sdk_ver"
            fi
            ;;

        "ios-spm")
            # Update iOS SPM AppConfig.swift
            local ios_spm_config=$(find "$app_dir" -name "AppConfig.swift" 2>/dev/null | head -1)

            if [ -f "$ios_spm_config" ]; then
                # Update macDomain
                sed -i.bak "s|let macDomain: String = \".*\"|let macDomain: String = \"$escaped_domain\"|" "$ios_spm_config"
                # Update testWebsiteUrl
                sed -i.bak "s|let testWebsiteUrl: String = \".*\"|let testWebsiteUrl: String = \"$escaped_website\"|" "$ios_spm_config"
                rm -f "${ios_spm_config}.bak"
                print_success "Updated iOS (SPM) AppConfig.swift"
            else
                print_warning "iOS AppConfig.swift not found in $app_dir"
            fi

            # Update README with the SDK version/branch
            if [ -n "$ios_sdk_ver" ]; then
                local ios_spm_readme="$app_dir/README.md"
                if [ -f "$ios_spm_readme" ]; then
                    local escaped_ios_spm_ver
                    escaped_ios_spm_ver=$(sed_escape_replacement "$ios_sdk_ver")
                    sed -i.bak "s|Select the \*\*release\*\* branch|Select the **${escaped_ios_spm_ver}** branch|" "$ios_spm_readme"
                    rm -f "${ios_spm_readme}.bak"
                    print_success "Updated iOS (SPM) README with branch: $ios_sdk_ver"
                fi
            fi

            echo ""
            print_info "Next steps:"
            print_info "  1. Open TrustArcMobileApp.xcodeproj in Xcode"
            print_info "  2. Go to File > Add Package Dependencies..."
            print_info "  3. Enter: https://github.com/trustarc/trustarc-mobile-consent.git"
            print_info "  4. Select branch: ${ios_sdk_ver:-release}"
            print_info "  5. Add the package to your app target"
            ;;

        "android")
            # Update Android AppConfig.kt
            local android_config="$app_dir/app/src/main/java/com/example/trustarcmobileapp/config/AppConfig.kt"
            if [ -f "$android_config" ]; then
                # Update MAC_DOMAIN
                sed -i.bak "s|const val MAC_DOMAIN: String = \".*\"|const val MAC_DOMAIN: String = \"$escaped_domain\"|" "$android_config"
                # Update TEST_WEBSITE_URL
                sed -i.bak "s|const val TEST_WEBSITE_URL: String = \".*\"|const val TEST_WEBSITE_URL: String = \"$escaped_website\"|" "$android_config"
                rm -f "${android_config}.bak"
                print_success "Updated Android AppConfig.kt"
            else
                print_warning "Android config file not found at: $android_config"
            fi

            # Update Android settings.gradle with token
            local android_settings="$app_dir/settings.gradle"
            if [ -f "$android_settings" ] && [ -n "$TRUSTARC_TOKEN" ]; then
                sed -i.bak "s|YOUR_TRUSTARC_TOKEN|$escaped_token|g" "$android_settings"
                rm -f "${android_settings}.bak"
                print_success "Updated Android settings.gradle with authentication token"
            fi

            # Update Android TrustArc SDK module/version if provided
            if [ -n "$android_sdk_ver" ]; then
                local android_versions_toml="$app_dir/gradle/libs.versions.toml"
                if [ -f "$android_versions_toml" ]; then
                    local android_sample_env="${ANDROID_SAMPLE_SDK_ENV:-prod}"
                    local android_module="${ANDROID_SAMPLE_SDK_MODULE:-com.trustarc:trustarc-consent-sdk}"
                    if [ -z "${ANDROID_SAMPLE_SDK_MODULE:-}" ] && [ "$android_sample_env" != "prod" ]; then
                        android_module="com.trustarc:trustarc-consent-sdk-${android_sample_env}"
                    fi
                    local escaped_android_sdk_ver
                    escaped_android_sdk_ver=$(sed_escape_replacement "$android_sdk_ver")
                    sed -i.bak "s|^[[:space:]]*trustarc-consent-sdk[[:space:]]*=.*|trustarc-consent-sdk = { module = \"$android_module\", version.ref = \"trustarcConsentSdk\" }|" "$android_versions_toml"
                    sed -i.bak "s|^[[:space:]]*trustarcConsentSdk[[:space:]]*=.*|trustarcConsentSdk = \"$escaped_android_sdk_ver\"|" "$android_versions_toml"
                    rm -f "${android_versions_toml}.bak"
                    print_success "Updated Android TrustArc SDK module/version: $android_module:$android_sdk_ver"
                else
                    print_warning "Android version catalog not found; skipped SDK version override"
                fi
            fi
            ;;

        "react-native"|"react-native-baremetal")
            # Update React Native app.config.ts
            local rn_config="$app_dir/config/app.config.ts"
            if [ -f "$rn_config" ]; then
                # Update macDomain
                sed -i.bak "s|macDomain: \".*\"|macDomain: \"$domain\"|" "$rn_config"
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

            # Update React Native TrustArc SDK package version if provided
            if [ -n "$rn_sdk_ver" ]; then
                local rn_package_json="$app_dir/package.json"
                if [ -f "$rn_package_json" ]; then
                    sed -i.bak "s|\"@trustarc/trustarc-react-native-consent-sdk\"[[:space:]]*:[[:space:]]*\"[^\"]*\"|\"@trustarc/trustarc-react-native-consent-sdk\": \"$rn_sdk_ver\"|g" "$rn_package_json"
                    rm -f "${rn_package_json}.bak"
                    print_success "Updated React Native TrustArc SDK version: $rn_sdk_ver"
                else
                    print_warning "React Native package.json not found; skipped SDK version override"
                fi
            fi
            ;;

        "flutter")
            # Update Flutter .env file
            local flutter_env="$app_dir/.env"
            if [ -f "$flutter_env" ]; then
                # Update MAC_DOMAIN
                sed -i.bak "s|^MAC_DOMAIN=.*|MAC_DOMAIN=$domain|" "$flutter_env"
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
                sed -i.bak "s|const String kDefaultDomainName = \".*\"|const String kDefaultDomainName = \"$domain\"|" "$flutter_config"
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

            # Update Flutter TrustArc SDK ref tag if provided
            if [ -n "$flutter_sdk_ver" ] && [ -f "$flutter_pubspec" ]; then
                sed -i.bak "s|^[[:space:]]*ref:[[:space:]].*|      ref: $flutter_sdk_ver|g" "$flutter_pubspec"
                rm -f "${flutter_pubspec}.bak"
                print_success "Updated Flutter TrustArc SDK version tag: $flutter_sdk_ver"
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
    local sdk_version=$4
    local token="$TRUSTARC_TOKEN"

    if [ -z "$token" ]; then
        print_error "GitHub token required to download sample applications."
        print_info "Restart the installer and provide a token with repo access."
        return 1
    fi

    # Map platform to directory name
    local platform_type=""
    local platform_dir=""
    case "$platform" in
        "ios")
            platform_type="ios"
            platform_dir="ios"
            ;;
        "ios-spm")
            platform_type="ios-spm"
            platform_dir="ios-spm"
            ;;
        "android")
            platform_type="android"
            platform_dir="android"
            ;;
        "react-native")
            platform_type="react-native"
            platform_dir="react"
            ;;
        "react-native-baremetal")
            platform_type="react-native-baremetal"
            platform_dir="react-baremetal"
            ;;
        "flutter")
            platform_type="flutter"
            platform_dir="flutter"
            ;;
    esac

    local selected_ref="$SAMPLE_REPO_BRANCH"
    local selected_ref_kind=""
    local github_repo_url=""
    local temp_zip="trustarc-sample-${platform_type}-$$.zip"
    local temp_dir="trustarc-sample-${platform_type}-$$"
    local extract_dir="trustarc-sample-${platform_type}"
    local repo_root=""
    local should_redownload=false

    # Check if already extracted
    if [ -d "$extract_dir" ]; then
        echo ""
        print_warning "Found existing sample application at: $extract_dir"
        read -p "Do you want to re-download and replace it? (y/n): " redownload

        if [ "$redownload" != "y" ] && [ "$redownload" != "Y" ]; then
            print_info "Skipping download, updating existing configuration..."
            update_config_files "$platform_type" "$extract_dir" "$domain" "$website" "$sdk_version"
            return 0
        else
            should_redownload=true
        fi
    fi

    if ! check_platform_dependencies "$platform"; then
        return 1
    fi

    if [ "$should_redownload" = true ]; then
        print_info "Removing existing directory..."
        rm -rf "$extract_dir"
    fi

    echo ""
    print_info "Download Parameters:"
    print_info "  Platform: $platform_type"
    print_info "  Domain: $domain"
    print_info "  Website: $website"
    if [ "$sdk_version" = "release" ] || [ "$sdk_version" = "stable" ]; then
        print_info "  SDK Channel: $sdk_version"
    elif [ -n "$sdk_version" ]; then
        print_info "  SDK Version Override: $sdk_version"
    else
        print_info "  SDK Channel: release (default)"
    fi
    echo ""
    print_info "Downloading sample application from GitHub..."

    # Download repo zip from ref, checking in order: branch -> tag -> commit.
    selected_ref_kind=$(download_archive_for_ref "$selected_ref" "$token" "$temp_zip")
    local download_status=$?

    if [ "$download_status" -eq 2 ]; then
        return 1
    fi

    if [ "$download_status" -ne 0 ] && [ "$selected_ref" != "release" ]; then
        print_warning "Ref '${selected_ref}' was not found as a branch, tag, or commit in ${SAMPLE_REPO_NAME}. Falling back to 'release'."
        selected_ref="release"
        selected_ref_kind=$(download_archive_for_ref "$selected_ref" "$token" "$temp_zip")
        download_status=$?
    fi

    if [ "$download_status" -ne 0 ]; then
        print_error "Failed to download from GitHub"
        return 1
    fi

    github_repo_url=$(sample_repo_source_url "$selected_ref" "$selected_ref_kind")
    print_info "  Source: $github_repo_url"
    print_info "  Resolved Ref: $selected_ref (${selected_ref_kind})"

    print_success "Downloaded repository archive"

    # Extract the specific platform folder
    echo ""
    print_info "Extracting $platform_type sample application..."

    # Create temp directory
    mkdir -p "$temp_dir"

    # Resolve root folder inside downloaded archive dynamically.
    repo_root=$(unzip -Z -1 "$temp_zip" 2>/dev/null | head -1 | cut -d/ -f1)
    if [ -z "$repo_root" ]; then
        print_error "Failed to inspect downloaded archive"
        rm -rf "$temp_dir" "$temp_zip"
        return 1
    fi

    # Extract only the platforms folder we need
    if unzip -q "$temp_zip" "${repo_root}/platforms/${platform_dir}/*" -d "$temp_dir" 2>/dev/null; then
        # Move the platform folder to final location
        if [ -d "$temp_dir/${repo_root}/platforms/${platform_dir}" ]; then
            mv "$temp_dir/${repo_root}/platforms/${platform_dir}" "$extract_dir"
            print_success "Extracted to: $extract_dir/"

            # Update configuration files with user's choices
            update_config_files "$platform_type" "$extract_dir" "$domain" "$website" "$sdk_version"
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
