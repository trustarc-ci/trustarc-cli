#!/bin/bash

# Build functions for TrustArc CLI (v2 sample apps)
#
# The v2 demos ship the SDK baked in (Android: app/libs/*.aar, iOS: Frameworks/*.xcframework via
# a local podspec), so they can be built straight from the downloaded sample without any SDK
# publishing step. This module builds each platform's artifact SEPARATELY:
#   - Android -> debug APK   (./gradlew :app:assembleDebug)
#   - iOS     -> simulator .app, or a device .xcarchive/.ipa when signing is available.

# Resolve the on-disk directory for a downloaded v2 sample app.
# Prefers the CLI's own extract dir (trustarc-sample-<platform>), then the source repo layout
# (platforms/v2/<android|ios>), then prompts for a path.
find_v2_app_dir() {
    local platform=$1   # android-v2 | ios-v2
    local repo_sub=""
    local extract_dir=""
    local candidate=""
    local answer=""

    case "$platform" in
        android-v2) extract_dir="trustarc-sample-android-v2"; repo_sub="platforms/v2/android" ;;
        ios-v2)     extract_dir="trustarc-sample-ios-v2";     repo_sub="platforms/v2/ios" ;;
        *) return 1 ;;
    esac

    for candidate in "$extract_dir" "$repo_sub" "./$extract_dir"; do
        if [ -d "$candidate" ]; then
            FOUND_V2_APP_DIR="$candidate"
            return 0
        fi
    done

    echo ""
    print_warning "Could not find a downloaded v2 app for '$platform'."
    print_info "Expected '$extract_dir/' in the current directory (run 'Download sample application' first)."
    read -p "Enter the path to the v2 app directory (or press Enter to cancel): " answer
    answer="${answer/#\~/$HOME}"
    if [ -n "$answer" ] && [ -d "$answer" ]; then
        FOUND_V2_APP_DIR="$answer"
        return 0
    fi

    print_error "No valid v2 app directory provided."
    return 1
}

# Build the Android v2 demo into a debug APK.
build_v2_android() {
    local app_dir=""

    print_header "Build v2 Android (APK)"

    if ! check_platform_dependencies "android-v2"; then
        return 1
    fi

    if ! find_v2_app_dir "android-v2"; then
        return 1
    fi
    app_dir="$FOUND_V2_APP_DIR"

    if [ ! -x "$app_dir/gradlew" ] && [ ! -f "$app_dir/gradlew" ]; then
        print_error "gradlew not found in $app_dir"
        return 1
    fi

    # The v2 app resolves the TrustArc SDK from GitHub Packages, and settings.gradle fails fast
    # without a token. Warn early so the build failure isn't a surprise.
    if [ -z "${TRUSTARC_TOKEN:-}" ]; then
        print_warning "TRUSTARC_TOKEN is not set. The v2 app resolves the TrustArc SDK from GitHub"
        print_substep "Packages (settings.gradle requires the token). Export it before building."
        read -p "Continue anyway? (y/n): " cont
        if [ "$cont" != "y" ] && [ "$cont" != "Y" ]; then
            print_info "Build canceled."
            return 1
        fi
    fi

    echo ""
    print_info "Building debug APK in: $app_dir"
    print_substep "./gradlew :app:assembleDebug"
    echo ""

    if ( cd "$app_dir" && chmod +x ./gradlew 2>/dev/null; ./gradlew :app:assembleDebug ); then
        local apk
        apk=$(find "$app_dir/app/build/outputs/apk/debug" -name "*.apk" 2>/dev/null | head -1)
        echo ""
        print_success "Android v2 build complete"
        if [ -n "$apk" ]; then
            print_info "APK: $apk"
            print_substep "Install with: adb install -r \"$apk\""
        else
            print_warning "Build reported success but no APK was found under app/build/outputs/apk/debug"
        fi
        return 0
    fi

    echo ""
    print_error "Android v2 build failed. See the Gradle output above."
    return 1
}

# Build the iOS v2 demo. Default artifact is an unsigned simulator .app (the demo disables code
# signing); optionally archive for a device and export an .ipa when a signing identity exists.
build_v2_ios() {
    local app_dir=""
    local workspace=""
    local scheme="TrustArcMobileApp"

    print_header "Build v2 iOS (APP / IPA)"

    if ! is_macos; then
        print_error "iOS builds require macOS."
        return 1
    fi

    if ! check_platform_dependencies "ios-v2"; then
        return 1
    fi

    if ! find_v2_app_dir "ios-v2"; then
        return 1
    fi
    app_dir="$FOUND_V2_APP_DIR"

    # The Podfile pulls TrustArcConsentSDK from the trustarc-mobile-consent git repo and raises
    # without a token, so pod install needs TRUSTARC_TOKEN.
    if [ -z "${TRUSTARC_TOKEN:-}" ]; then
        print_warning "TRUSTARC_TOKEN is not set. The v2 Podfile resolves the SDK from the"
        print_substep "trustarc-mobile-consent git repo and will fail 'pod install' without it."
        read -p "Continue anyway? (y/n): " cont
        if [ "$cont" != "y" ] && [ "$cont" != "Y" ]; then
            print_info "Build canceled."
            return 1
        fi
    fi

    # The v2 iOS demo is CocoaPods-based and MUST be built from the .xcworkspace, not the
    # .xcodeproj. Run pod install first so the SDK pod is wired up.
    if command_exists pod; then
        echo ""
        print_info "Installing pods (TrustArcConsentSDK from trustarc-mobile-consent)..."
        if ! ( cd "$app_dir" && pod install ); then
            print_error "pod install failed. See output above."
            return 1
        fi
    else
        print_warning "CocoaPods (pod) not found; skipping 'pod install'. Build may fail if Pods/ is stale."
    fi

    workspace=$(find "$app_dir" -maxdepth 1 -name "*.xcworkspace" 2>/dev/null | head -1)
    if [ -z "$workspace" ]; then
        print_error "No .xcworkspace found in $app_dir (expected TrustArcMobileApp.xcworkspace)."
        return 1
    fi

    echo ""
    echo "Select iOS artifact:"
    echo ""
    printf "  ${BOLD}1${NC}) Simulator .app (unsigned — default, no signing needed)\n"
    printf "  ${BOLD}2${NC}) Device .xcarchive + .ipa (requires a signing identity)\n"
    printf "  ${BOLD}3${NC}) Back\n"
    echo ""
    read -p "Enter your choice (1-3, default: 1): " ios_choice
    ios_choice=${ios_choice:-1}

    case "$ios_choice" in
        1)
            local derived="$app_dir/build"
            echo ""
            print_info "Building simulator .app (unsigned)..."
            print_substep "xcodebuild build -workspace $(basename "$workspace") -scheme $scheme -sdk iphonesimulator"
            echo ""
            if ( cd "$app_dir" && xcodebuild build \
                    -workspace "$(basename "$workspace")" \
                    -scheme "$scheme" \
                    -sdk iphonesimulator \
                    -destination 'generic/platform=iOS Simulator' \
                    -derivedDataPath build \
                    CODE_SIGNING_ALLOWED=NO ); then
                local app
                app=$(find "$derived/Build/Products" -maxdepth 2 -name "*.app" 2>/dev/null | head -1)
                echo ""
                print_success "iOS v2 simulator build complete"
                if [ -n "$app" ]; then
                    print_info "APP: $app"
                    print_substep "Install onto a booted sim with: xcrun simctl install booted \"$app\""
                else
                    print_warning "Build succeeded but no .app was found under $derived/Build/Products"
                fi
                return 0
            fi
            echo ""
            print_error "iOS v2 simulator build failed. See the xcodebuild output above."
            return 1
            ;;
        2)
            local archive_path="$app_dir/build/${scheme}.xcarchive"
            local export_dir="$app_dir/build/ipa"
            echo ""
            print_info "Archiving for device..."
            print_substep "xcodebuild archive -workspace $(basename "$workspace") -scheme $scheme"
            echo ""
            if ! ( cd "$app_dir" && xcodebuild archive \
                    -workspace "$(basename "$workspace")" \
                    -scheme "$scheme" \
                    -sdk iphoneos \
                    -destination 'generic/platform=iOS' \
                    -archivePath "build/${scheme}.xcarchive" ); then
                echo ""
                print_error "Archive failed. This step needs a valid signing identity / provisioning profile."
                print_info "For an unsigned build, re-run and choose option 1 (simulator .app)."
                return 1
            fi
            print_success "Archive created: $archive_path"

            echo ""
            print_info "Exporting .ipa (development)..."
            local export_plist="$app_dir/build/ExportOptions.plist"
            cat > "$export_plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
PLIST
            if ( cd "$app_dir" && xcodebuild -exportArchive \
                    -archivePath "build/${scheme}.xcarchive" \
                    -exportOptionsPlist "build/ExportOptions.plist" \
                    -exportPath "build/ipa" ); then
                local ipa
                ipa=$(find "$export_dir" -name "*.ipa" 2>/dev/null | head -1)
                echo ""
                print_success "iOS v2 device build complete"
                [ -n "$ipa" ] && print_info "IPA: $ipa"
                print_substep "Archive: $archive_path"
                return 0
            fi
            echo ""
            print_error "IPA export failed (signing required). The .xcarchive is still at: $archive_path"
            return 1
            ;;
        3|*)
            return 1
            ;;
    esac
}

# Build v2 sample application menu (invoked from the main menu).
build_v2_menu() {
    print_header "Build v2 Sample Application"

    echo "Select platform to build:"
    echo ""
    printf "  ${BOLD}1${NC}) Android (v2) — APK\n"
    printf "  ${BOLD}2${NC}) iOS (v2) — APP / IPA\n"
    printf "  ${BOLD}3${NC}) Back to main menu\n"
    echo ""
    read -p "Enter your choice (1-3): " build_choice

    case "$build_choice" in
        1) build_v2_android ;;
        2) build_v2_ios ;;
        3) show_main_menu; return ;;
        *) print_error "Invalid choice"; build_v2_menu; return ;;
    esac

    echo ""
    read -p "Press enter to return to main menu..."
    show_main_menu
}
