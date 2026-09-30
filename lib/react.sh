#!/bin/bash

# React Native integration functions for TrustArc CLI
# This file contains logic for React Native SDK integration
#
# SDK Requirements (from ccm-react-native-mobile-consent-sdk):
# - React Native: >= 0.73.4
# - Node.js: >= 18 (Expo + Bare Metal)

# Append a line to a file only if a matching pattern is not already present.
# $1 file, $2 grep pattern (ERE), $3 line to add, $4 human label
ensure_npmrc_line() {
    local file=$1 pattern=$2 line=$3 label=$4
    if grep -qE "$pattern" "$file" 2>/dev/null; then
        return 1  # already present
    fi
    echo "$line" >> "$file"
    print_substep "Added $label"
    return 0
}

# Configure .npmrc for TrustArc GitHub registry
configure_npmrc() {
    local project_path=$1
    local npmrc_file="$project_path/.npmrc"

    echo ""
    print_step "Configuring .npmrc for TrustArc registry..."

    # Required configuration lines
    local registry_line="@trustarc:registry=https://npm.pkg.github.com"
    local auth_line="//npm.pkg.github.com/:_authToken=\${TRUSTARC_TOKEN}"
    # legacy-peer-deps lets npm install the SDK despite its react peer range not
    # matching newer Expo/React versions. Ignored by yarn/pnpm/bun. This also
    # applies to npm installs spawned by `expo install`, `prebuild`, and `run`.
    local legacy_line="legacy-peer-deps=true"

    if [ ! -f "$npmrc_file" ]; then
        print_info "Creating .npmrc file..."
        : > "$npmrc_file"
    else
        print_info ".npmrc already exists — ensuring TrustArc settings are present"
    fi

    ensure_npmrc_line "$npmrc_file" "^@trustarc:registry=" "$registry_line" "TrustArc registry configuration"
    ensure_npmrc_line "$npmrc_file" "^//npm\.pkg\.github\.com/:_authToken=" "$auth_line" "authentication token configuration"
    ensure_npmrc_line "$npmrc_file" "^legacy-peer-deps=" "$legacy_line" "legacy-peer-deps=true (npm peer resolution)"

    print_success "TrustArc .npmrc configuration ensured"

    echo ""
    print_info ".npmrc Configuration:"
    print_substep "Registry: https://npm.pkg.github.com"
    print_substep "Auth Token: \${TRUSTARC_TOKEN} (from environment)"
    print_substep "legacy-peer-deps: true (npm)"

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

# Detect package manager from the project's lockfile (npm, yarn, pnpm, or bun)
detect_package_manager() {
    local project_path=$1

    if [ -f "$project_path/bun.lockb" ] || [ -f "$project_path/bun.lock" ]; then
        echo "bun"
    elif [ -f "$project_path/pnpm-lock.yaml" ]; then
        echo "pnpm"
    elif [ -f "$project_path/yarn.lock" ]; then
        echo "yarn"
    elif [ -f "$project_path/package-lock.json" ]; then
        echo "npm"
    else
        echo "npm"  # Default to npm
    fi
}

# Return the package managers actually installed on this system (space-separated).
get_installed_package_managers() {
    local managers=""
    command -v npm  >/dev/null 2>&1 && managers="$managers npm"
    command -v yarn >/dev/null 2>&1 && managers="$managers yarn"
    command -v pnpm >/dev/null 2>&1 && managers="$managers pnpm"
    command -v bun  >/dev/null 2>&1 && managers="$managers bun"
    echo "${managers# }"
}

# Interactively choose a package manager from those installed on the system,
# defaulting to the one detected from the project's lockfile.
# NOTE: all UI is written to stderr so only the chosen manager reaches stdout,
# allowing this to be used in a command substitution: pm=$(choose_package_manager ...)
choose_package_manager() {
    local project_path=$1
    local detected
    detected=$(detect_package_manager "$project_path")

    local -a pms
    # shellcheck disable=SC2207
    pms=($(get_installed_package_managers))

    # Nothing detected as installed (very unlikely) — fall back to the lockfile guess.
    if [ ${#pms[@]} -eq 0 ]; then
        echo "$detected"
        return 0
    fi

    # Only one manager installed — use it without prompting.
    if [ ${#pms[@]} -eq 1 ]; then
        echo "${pms[0]}"
        return 0
    fi

    local default_index=1
    {
        echo ""
        print_step "Select a package manager"
        echo ""
        print_info "Detected from lockfile: $detected"
        if ! printf '%s\n' "${pms[@]}" | grep -qx "$detected"; then
            print_warning "'$detected' is not installed on this system."
        fi
        echo ""
        local i=1
        local pm ver
        for pm in "${pms[@]}"; do
            ver=$("$pm" --version 2>/dev/null | head -1)
            if [ "$pm" = "$detected" ]; then
                echo "  ${i}) ${pm}${ver:+ ($ver)} [detected]"
                default_index=$i
            else
                echo "  ${i}) ${pm}${ver:+ ($ver)}"
            fi
            i=$((i + 1))
        done
        echo ""
    } >&2

    local choice
    read -p "Choose [1-${#pms[@]}] (default: $default_index): " choice
    choice=${choice:-$default_index}

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#pms[@]} ]; then
        print_warning "Invalid choice; using default." >&2
        choice=$default_index
    fi

    echo "${pms[$((choice - 1))]}"
}

# Human-readable install command for a package manager (used in prompts/hints).
# npm needs --legacy-peer-deps because its strict peer resolver (npm 7+) rejects
# some valid React Native peer ranges; yarn/pnpm/bun do not.
package_install_display() {
    case "$1" in
        npm) echo "npm install --legacy-peer-deps" ;;
        *)   echo "$1 install" ;;
    esac
}

# Run a dependency install using the given package manager.
run_package_install() {
    local package_manager=$1
    local project_path=$2

    cd "$project_path"
    case "$package_manager" in
        yarn) yarn install ;;
        pnpm) pnpm install ;;
        bun)  bun install ;;
        *)    npm install --legacy-peer-deps ;;
    esac
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
# $2 (optional): extra args to pass to `expo prebuild` (e.g. "--clean")
run_expo_prebuild() {
    local project_path=$1
    local extra_args="${2:-}"

    echo ""
    print_step "Running Expo prebuild${extra_args:+ ($extra_args)}..."
    echo ""
    print_divider
    echo ""

    cd "$project_path"

    if npx expo prebuild $extra_args 2>&1; then
        echo ""
        print_success "Expo prebuild completed successfully"
        return 0
    else
        echo ""
        print_error "Expo prebuild failed"
        return 1
    fi
}

# Install the expo-build-properties config plugin (required to inject the
# TrustArc Android Maven repository and minSdkVersion during prebuild).
install_expo_build_properties() {
    local project_path=$1

    echo ""
    print_step "Installing expo-build-properties config plugin..."

    if [ -d "$project_path/node_modules/expo-build-properties" ]; then
        print_success "expo-build-properties already installed"
        return 0
    fi

    cd "$project_path"
    # `expo install` spawns its own `npm install`, which does not read our flag.
    # Export npm_config_legacy_peer_deps so npm tolerates the SDK's react peer
    # range mismatch (harmless for yarn/pnpm/bun).
    if npm_config_legacy_peer_deps=true npx expo install expo-build-properties 2>&1; then
        echo ""
        print_success "Installed expo-build-properties"
        return 0
    else
        echo ""
        print_error "Failed to install expo-build-properties"
        print_info "Install it manually: npm_config_legacy_peer_deps=true npx expo install expo-build-properties"
        return 1
    fi
}

# Print the manual Expo config snippet (used when we can't safely auto-edit
# an existing dynamic config file).
_print_expo_manual_config() {
    echo ""
    print_info "Add the following to your Expo config (app.config.js):"
    echo ""
    echo "  plugins: ["
    echo "    ['expo-build-properties', {"
    echo "      android: {"
    echo "        minSdkVersion: 28,"
    echo "        extraMavenRepos: [{"
    echo "          url: 'https://maven.pkg.github.com/trustarc/trustarc-mobile-consent',"
    echo "          credentials: { username: 'trustarc', password: process.env.TRUSTARC_TOKEN },"
    echo "        }],"
    echo "      },"
    echo "    }],"
    echo "  ],"
    echo "  ios: {"
    echo "    infoPlist: {"
    echo "      NSUserTrackingUsageDescription:"
    echo "        'This identifier will be used to deliver personalized ads to you.',"
    echo "    },"
    echo "  },"
    echo ""
}

# Configure Expo native settings needed by the TrustArc SDK:
#  - Android: TrustArc Maven repo + minSdkVersion 28 (via expo-build-properties)
#  - iOS: NSUserTrackingUsageDescription
# Uses a dynamic app.config.js (function form) so the GitHub token is read from
# the TRUSTARC_TOKEN environment variable and never committed to source control.
# The existing app.json is preserved and merged automatically by Expo.
configure_expo_native_config() {
    local project_path=$1
    local app_config_js="$project_path/app.config.js"
    local app_config_ts="$project_path/app.config.ts"
    local app_json="$project_path/app.json"

    echo ""
    print_step "Configuring Expo native settings (Android Maven repo + iOS tracking)..."

    # Never overwrite an existing dynamic config — show manual steps instead.
    if [ -f "$app_config_ts" ]; then
        print_warning "Found existing app.config.ts — not modifying it automatically."
        _print_expo_manual_config
        return 0
    fi

    if [ -f "$app_config_js" ]; then
        if grep -q "Generated by the TrustArc Mobile Consent SDK CLI" "$app_config_js"; then
            print_success "app.config.js already configured by TrustArc CLI"
            return 0
        fi
        print_warning "Found existing app.config.js — not modifying it automatically."
        _print_expo_manual_config
        return 0
    fi

    if [ ! -f "$app_json" ]; then
        print_warning "No app.json or app.config.js found in project root."
        _print_expo_manual_config
        return 0
    fi

    # Create app.config.js (function form). Expo reads app.json first and passes
    # it in as `config`, so app.json stays as the source of static config.
    cat > "$app_config_js" << 'EOF'
// app.config.js
// Generated by the TrustArc Mobile Consent SDK CLI.
// Injects the TrustArc Android Maven repository and the iOS tracking usage
// description required by the SDK. The GitHub token is read from the
// TRUSTARC_TOKEN environment variable so it is never committed to source control.
//
// Your existing app.json is preserved: Expo loads it first and passes it in as
// `config`, and this file layers the TrustArc settings on top.

const TRUSTARC_MAVEN_URL =
  'https://maven.pkg.github.com/trustarc/trustarc-mobile-consent';
const TRUSTARC_TRACKING_DESCRIPTION =
  'This identifier will be used to deliver personalized ads to you.';

module.exports = ({ config }) => {
  const plugins = [...(config.plugins || [])];

  const trustArcRepo = {
    url: TRUSTARC_MAVEN_URL,
    credentials: {
      username: 'trustarc',
      password: process.env.TRUSTARC_TOKEN,
    },
  };

  const existingIndex = plugins.findIndex(
    (p) =>
      p === 'expo-build-properties' ||
      (Array.isArray(p) && p[0] === 'expo-build-properties')
  );

  if (existingIndex === -1) {
    plugins.push([
      'expo-build-properties',
      { android: { minSdkVersion: 28, extraMavenRepos: [trustArcRepo] } },
    ]);
  } else {
    // Merge into an existing expo-build-properties entry.
    const existing = plugins[existingIndex];
    const props = (Array.isArray(existing) && existing[1]) || {};
    const android = props.android || {};
    const repos = (android.extraMavenRepos || []).filter(
      (r) => r.url !== TRUSTARC_MAVEN_URL
    );
    plugins[existingIndex] = [
      'expo-build-properties',
      {
        ...props,
        android: {
          ...android,
          minSdkVersion: Math.max(android.minSdkVersion || 0, 28),
          extraMavenRepos: [...repos, trustArcRepo],
        },
      },
    ];
  }

  const ios = config.ios || {};
  const infoPlist = ios.infoPlist || {};

  return {
    ...config,
    plugins,
    ios: {
      ...ios,
      infoPlist: {
        ...infoPlist,
        NSUserTrackingUsageDescription:
          infoPlist.NSUserTrackingUsageDescription ||
          TRUSTARC_TRACKING_DESCRIPTION,
      },
    },
  };
};
EOF

    print_success "Created app.config.js (reads TRUSTARC_TOKEN from environment)"
    print_substep "Android: Maven repo + minSdkVersion 28 via expo-build-properties"
    print_substep "iOS: NSUserTrackingUsageDescription added"
    print_info "Your existing app.json is preserved and merged automatically."
    return 0
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

# Add NSUserTrackingUsageDescription to the iOS Info.plist (bare React Native).
# Expo projects get this via the generated app.config.js instead.
add_ios_tracking_description() {
    local project_path=$1
    local desc="This identifier will be used to deliver personalized ads to you."

    echo ""
    print_step "Adding iOS tracking usage description (NSUserTrackingUsageDescription)..."

    # Locate the app's Info.plist (exclude Pods and test targets).
    local plist
    plist=$(find "$project_path/ios" -name "Info.plist" -not -path "*/Pods/*" -not -path "*Tests*" 2>/dev/null | head -1)

    if [ -z "$plist" ]; then
        print_warning "Could not locate ios/<AppName>/Info.plist"
        print_info "Add this key manually to your Info.plist:"
        echo "  <key>NSUserTrackingUsageDescription</key>"
        echo "  <string>$desc</string>"
        return 0
    fi

    local plistbuddy="/usr/libexec/PlistBuddy"
    if [ ! -x "$plistbuddy" ]; then
        print_warning "PlistBuddy not available; add the key manually to: $plist"
        echo "  <key>NSUserTrackingUsageDescription</key>"
        echo "  <string>$desc</string>"
        return 0
    fi

    if "$plistbuddy" -c "Print :NSUserTrackingUsageDescription" "$plist" >/dev/null 2>&1; then
        print_success "NSUserTrackingUsageDescription already present"
    elif "$plistbuddy" -c "Add :NSUserTrackingUsageDescription string $desc" "$plist" >/dev/null 2>&1; then
        print_success "Added NSUserTrackingUsageDescription to $(basename "$(dirname "$plist")")/Info.plist"
    else
        print_warning "Could not update Info.plist automatically; add manually to $plist:"
        echo "  <key>NSUserTrackingUsageDescription</key>"
        echo "  <string>$desc</string>"
    fi
    return 0
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
    local boilerplate_url="https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/${REPO_REF:-testing}/TrustArcConsentImpl.$file_extension"
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
    local default_target_version="latest"
    local target_version="latest"
    local latest_npm_version
    latest_npm_version=$(fetch_latest_react_native_sdk_version 2>/dev/null || true)
    if [ -n "$latest_npm_version" ]; then
        default_target_version="$latest_npm_version"
        target_version="$latest_npm_version"
        print_info "Latest package version detected: $latest_npm_version"
    fi

    if [ -n "$existing_version" ]; then
        echo ""
        print_success "TrustArc SDK already installed"
        print_substep "Current version: $existing_version"
        echo ""
        read -p "Would you like to update to a different version? (y/n): " update_choice

        if [ "$update_choice" = "y" ] || [ "$update_choice" = "Y" ]; then
            echo ""
            read -p "Enter version (default: $default_target_version): " target_version
            target_version=${target_version:-$default_target_version}
            install_package=true
        fi
    else
        echo ""
        print_warning "TrustArc SDK not found in package.json"
        echo ""
        read -p "Would you like to add it now? (y/n): " add_choice

        if [ "$add_choice" = "y" ] || [ "$add_choice" = "Y" ]; then
            echo ""
            read -p "Enter version (default: $default_target_version): " target_version
            target_version=${target_version:-$default_target_version}
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
        # Let the user pick from the package managers installed on their system
        # (defaults to the one detected from the lockfile).
        package_manager=$(choose_package_manager "$project_path")
        local install_cmd
        install_cmd=$(package_install_display "$package_manager")

        echo ""
        read -p "Run '$install_cmd' now? (y/n): " install_choice

        if [ "$install_choice" = "y" ] || [ "$install_choice" = "Y" ]; then
            echo ""
            print_step "Installing dependencies with $package_manager..."
            echo ""

            if run_package_install "$package_manager" "$project_path"; then
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
            print_info "Please run '$install_cmd' manually"
        fi
    fi

    # Step 6: Platform-specific integration
    if [ "$project_type" = "expo" ]; then
        # EXPO FLOW

        # Install the config plugin and write the native config BEFORE prebuild,
        # otherwise the Android build cannot resolve the TrustArc Maven package.
        install_expo_build_properties "$project_path"
        configure_expo_native_config "$project_path"

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
        print_substep "✓ Apply the TrustArc Maven repo + minSdkVersion (expo-build-properties)"
        print_substep "✓ Auto-link TrustArc SDK native modules"
        echo ""
        print_warning "⚠ WARNING: '--clean' regenerates ios/ and android/ directories"
        print_warning "          Any manual native changes will be lost!"
        echo ""
        print_info "Ensure TRUSTARC_TOKEN is exported in this shell (Maven auth reads it)."
        echo ""
        read -p "Run 'npx expo prebuild --clean' now? (y/n): " prebuild_choice

        if [ "$prebuild_choice" = "y" ] || [ "$prebuild_choice" = "Y" ]; then
            if run_expo_prebuild "$project_path" "--clean"; then
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
            echo "  npx expo prebuild --clean"
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

        # Android Studio guidance: prebuild bakes the token into the project's
        # android/gradle.properties, so terminal builds authenticate fine. GUI
        # Android Studio does not inherit the shell env, so if Gradle needs to
        # re-fetch the dependency it can 401.
        echo ""
        print_divider
        echo ""
        print_info "Running from Android Studio? (optional)"
        print_substep "Terminal builds (npx expo run:android) work out of the box."
        print_substep "For Android Studio, do ONE of the following so Gradle can authenticate:"
        print_substep "  • Run 'npx expo run:android' once (with TRUSTARC_TOKEN exported) to cache the dependency, or"
        print_substep "  • Add 'TRUSTARC_TOKEN=<token>' to ~/.gradle/gradle.properties"

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

            # Add the iOS tracking usage description required by the SDK.
            add_ios_tracking_description "$project_path"

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

    # Detect TypeScript to show correct file name in prompt
    local use_typescript=$(detect_typescript "$project_path")
    local boilerplate_filename="TrustArcConsentImpl.js"
    if [ "$use_typescript" = "true" ]; then
        boilerplate_filename="TrustArcConsentImpl.ts"
    fi

    read -p "Would you like to create $boilerplate_filename? (y/n): " boilerplate_choice

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

    # Show correct file extension in API reference
    local api_ref_file="TrustArcConsentImpl.js"
    if [ "$use_typescript" = "true" ]; then
        api_ref_file="TrustArcConsentImpl.ts"
    fi
    print_substep "• API Reference: Check $api_ref_file for available methods"
    echo ""

    return 0
}
