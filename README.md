# TrustArc Mobile Consent SDK CLI

A command-line installer for integrating the TrustArc Mobile Consent SDK into your mobile applications.

## Features

- **Automated SDK Integration**: Streamlined installation process for iOS, Android, and React Native projects
- **Multi-Platform Support**:
  - iOS: Swift Package Manager (SPM) & CocoaPods
  - Android: Gradle with version catalog support
  - React Native: Expo & Bare Metal with auto-linking
- **Sample Implementation**: Automatic boilerplate code generation
- **Demo App Downloads**: Pull full sample projects from the private `trustarc/ccm-mobile-consent-test-apps` repository (release branch) for reference
- **AI Assistant (Beta)**: Local AI-powered help for SDK integration
  - Runs completely offline after initial setup
  - Trained on TrustArc SDK documentation and implementation examples
  - PDF documentation indexing support
  - No data sent to external APIs
- **Platform Detection**: Auto-detects your project configuration
- **Git-Safe**: Validates git status before making changes

## Installation

### Method 1: Run from URL (Recommended)

Run the installer directly from GitHub:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/refs/heads/main/install.sh)"
```

### Method 2: Run with Cache Bypass

If you need the latest version and want to bypass any caching:

```bash
sh -c "$(curl -fsSL -H 'Cache-Control: no-cache, no-store, must-revalidate' https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/refs/heads/main/install.sh)"
```

### Method 3: Using wget

If you don't have curl installed:

```bash
sh -c "$(wget https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/refs/heads/main/install.sh -O -)"
```

### Method 4: Clone and Run Locally

For development or offline use:

```bash
git clone https://github.com/trustarc-ci/trustarc-cli.git
cd trustarc-cli
./install.sh
```

## Prerequisites

Before running the installer, make sure you have:

- **Operating System**: macOS or Linux
- **Xcode**: Required for iOS integration (macOS only)
- **Git**: Recommended for better change tracking
- **GitHub Token**: Personal Access Token with `repo` and `read:package` scopes
  - Create one at: https://github.com/settings/tokens
  - Required scopes: `repo`, `read:package`
  - Must have access to `trustarc/trustarc-mobile-consent` and `trustarc/ccm-mobile-consent-test-apps`

### CocoaPods Projects (Additional Requirements)

If you're using CocoaPods:
- **CocoaPods**: Install with `sudo gem install cocoapods`
- **Ruby**: CocoaPods requires Ruby (usually pre-installed on macOS)

## What It Does

1. **Authentication**: Securely stores your GitHub token
2. **Platform Detection**: Identifies your project type (iOS, Android, React Native, Flutter)
3. **Dependency Management**: Adds TrustArc SDK to your project
4. **Code Generation**: Creates implementation boilerplate
5. **Verification**: Confirms successful integration

## Platform-Specific Integration

### iOS Integration

The CLI supports:
- Swift Package Manager (SPM)
- CocoaPods
- Swift 5.0+ and iOS 12.0+

**CocoaPods**: Automatically adds the pod with git URL and branch to your Podfile and runs `pod install`
```ruby
pod 'TrustArcConsentSDK', :git => 'https://TOKEN@github.com/...', :branch => 'release'
```

**SPM**: Provides step-by-step instructions for adding the package in Xcode with authentication.

#### Generated Code (iOS)

```swift
// Initialize SDK on app launch
TrustArcConsentImpl.shared.initialize()

// Show consent dialog
TrustArcConsentImpl.shared.openCm()
```

### Android Integration

The CLI supports:
- Gradle (Groovy & Kotlin DSL)
- Version Catalog (libs.versions.toml)
- Android API 28+ (minSdk)
- Kotlin required

**Automatic Configuration**:
- Adds Maven repository to `settings.gradle`
- Configures dependency in `app/build.gradle` or version catalog
- Installs required dependencies (AndroidX, Retrofit, Material)
- Validates AGP-Kotlin compatibility

#### Generated Code (Android)

```kotlin
// Initialize in Application class
TrustArcConsentImpl.initialize(this)

// Show consent dialog
TrustArcConsentImpl.openCm()

// Get consent data
val consents = TrustArcConsentImpl.getConsentData()
```

### React Native Integration

The CLI supports both:
- **Expo (Managed)**: Uses `expo prebuild` to generate native code
- **Bare Metal**: Direct iOS (CocoaPods) and Android (Gradle) integration

**Automatic Detection**:
- Detects project type (Expo vs Bare Metal)
- Identifies package manager (npm/yarn)
- Verifies native module linking

**Expo Flow**:
1. Configures `.npmrc` for GitHub Package Registry authentication
2. Adds `@trustarc/trustarc-react-native-consent-sdk` to package.json
3. Runs `npm install` or `yarn install`
4. Executes `npx expo prebuild` to generate native directories
5. Verifies iOS (Podfile.lock) and Android (build.gradle) integration

**Bare Metal Flow**:
1. Configures `.npmrc` for GitHub Package Registry authentication
2. Adds SDK package to package.json
3. Runs package manager install
4. Executes `pod install` for iOS (if needed)
5. Verifies auto-linking for Android
6. Confirms native modules are properly linked

**`.npmrc` Configuration**:

The CLI automatically creates or updates `.npmrc` with:
```
@trustarc:registry=https://npm.pkg.github.com
//npm.pkg.github.com/:_authToken=${TRUSTARC_TOKEN}
```

This configuration:
- Routes `@trustarc` scoped packages to GitHub Package Registry
- Uses `TRUSTARC_TOKEN` environment variable for authentication
- Preserves existing `.npmrc` settings (appends if file exists)
- Creates backup before modification

#### Generated Code (React Native)

```typescript
// Initialize in App.tsx or _layout.tsx
useEffect(() => {
  TrustArcConsentImpl.initialize();
}, []);

// Show consent dialog
TrustArcConsentImpl.openCm();

// Listen for consent changes
useEffect(() => {
  const unsubscribe = TrustArcConsentImpl.onConsentChange((data) => {
    console.log('Consent changed:', data);
  });
  return unsubscribe;
}, []);

// Get consent data
const consents = await TrustArcConsentImpl.getConsentData();
```

### Integration Steps

1. Choose "Integrate SDK" from the main menu
2. Provide your project path
3. Confirm git status is clean
4. CLI auto-detects platform type
5. Enter your TrustArc domain
6. Follow the guided integration process
7. Optionally generate implementation boilerplate

## AI Assistant (Beta)

The CLI includes a local AI assistant to help with SDK integration questions. It runs completely offline after initial setup and doesn't send any data to external APIs.

### First-Time Setup

When you first select "AI Assistant" from the main menu:

1. The CLI will ask to download required components (~700MB one-time download):
   - llama.cpp inference engine (~10MB)
   - DeepSeek-Coder 1.3B model (~700MB)
   - Pre-built knowledge base trained on TrustArc SDK documentation
2. Files are stored in `~/.trustarc-cli/ai/` for reuse
3. Setup is automatic - just confirm the download

### Features

**Chat Mode**: Ask questions about SDK integration
```
You: How do I initialize the SDK in Swift?
AI: To initialize the TrustArc SDK in Swift, call TrustArcConsentImpl.shared.initialize()
    in your AppDelegate's didFinishLaunchingWithOptions method...
```

**Pre-Trained Knowledge Base**: Includes
- iOS Swift implementation examples
- Android Kotlin implementation examples
- React Native TypeScript implementation
- Flutter Dart implementation
- Common troubleshooting and FAQ
- Platform-specific integration guides

**Simple Menu**:
1. Chat with AI Assistant
2. Update knowledge base (re-download latest from GitHub)
3. View AI status (downloads, disk usage)
4. Back to main menu

### Requirements

- **macOS**: Apple Silicon (arm64) or Intel (x64)
- **Linux**: x64 architecture
- **Disk Space**: ~1GB for AI files

### Performance

- First response: ~2-5 seconds (model loading)
- Subsequent responses: ~1-3 seconds
- Runs on CPU (no GPU required)

### Privacy

- Everything runs locally on your machine
- No data is sent to external servers
- Knowledge base stays on your computer
- Safe for proprietary projects

### Limitations

- Responses may not be 100% accurate (beta feature)
- Best for general SDK questions and code examples
- For complex issues, consult official documentation
- Knowledge base is maintained by TrustArc and cannot be customized by end users

## Configuration

The CLI stores configuration in two places:

### 1. Shell Configuration File
Your GitHub token is saved to your shell configuration file:
- **zsh**: `~/.zshrc`
- **bash**: `~/.bashrc` or `~/.bash_profile`
- **fish**: `~/.config/fish/config.fish`

The token is exported as `TRUSTARC_TOKEN` environment variable.

### 2. CLI Configuration File
Project preferences are stored in `~/.trustarc-cli-config`:
- Last used domain
- Platform preferences
- Other settings

## Cleanup

To remove all CLI configuration and tokens:

1. Run the installer again:
   ```bash
   sh -c "$(curl -fsSL https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/refs/heads/main/install.sh)"
   ```

2. Select option **3) Clean up (remove token and config)**

3. Restart your terminal for changes to take effect

This will:
- Remove `TRUSTARC_TOKEN` from your shell configuration
- Delete `~/.trustarc-cli-config`
- Remove AI Assistant files and models (`~/.trustarc-cli/ai/`)
- Create a backup of your shell config

## Troubleshooting

### "Token validation failed"
- Verify your token has `repo` and `read:package` scopes
- Ensure the token has access to `trustarc/trustarc-mobile-consent` repository
- Try regenerating your GitHub token

### "Could not detect platform type"
- Make sure you're in a valid iOS project directory
- Look for `.xcodeproj`, `.xcworkspace`, or `Podfile` files

### "You have uncommitted changes"
- Commit or stash your changes before running integration
- Use `git status` to see uncommitted files
- Run `git commit` or `git stash`

### "Package does not appear in project.pbxproj" (SPM)
- Close and reopen Xcode
- Clean build folder (Cmd+Shift+K)
- Verify the package appears in Package Dependencies tab

### "pod install failed" (CocoaPods)
- Verify the podspec exists in the repository
- Check that CocoaPods is installed: `pod --version`
- Try running `pod repo update`

### "Unable to resolve @trustarc/trustarc-react-native-consent-sdk" (React Native)
- Check that `.npmrc` exists in your project root
- Verify `.npmrc` contains the GitHub registry configuration:
  ```
  @trustarc:registry=https://npm.pkg.github.com
  //npm.pkg.github.com/:_authToken=${TRUSTARC_TOKEN}
  ```
- Ensure `TRUSTARC_TOKEN` environment variable is set:
  ```bash
  echo $TRUSTARC_TOKEN  # Should output your token
  ```
- Restart your terminal after setting the token
- Try clearing npm cache: `npm cache clean --force`
- For yarn: `yarn cache clean`

### "TrustArcMobileSdk native module not found" (React Native)
- Ensure you ran `npm install` or `yarn install` after adding the package
- For Expo: Run `npx expo prebuild` to generate native directories
- For Bare Metal iOS: Run `cd ios && pod install`
- For Bare Metal Android: Clean and rebuild with `cd android && ./gradlew clean`
- Restart Metro bundler: `npx react-native start --reset-cache`

### "Prebuild failed" (Expo)
- Check that all dependencies are properly installed
- Verify `app.json` has correct configuration
- Try removing `ios/` and `android/` directories and running prebuild again
- Check Expo CLI version: `npx expo --version`

### "Auto-linking not working" (React Native Bare Metal)
- Verify `use_native_modules!` is in your iOS Podfile
- Check `applyNativeModulesSettingsGradle` is in Android settings.gradle
- Clean both platforms:
  - iOS: `cd ios && pod deintegrate && pod install`
  - Android: `cd android && ./gradlew clean`

### Getting the latest version
Use the cache-bypass command:
```bash
sh -c "$(curl -fsSL -H 'Cache-Control: no-cache, no-store, must-revalidate' https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/refs/heads/main/install.sh)"
```

## Support

For issues or questions, please visit:
- [TrustArc Documentation](https://docs.trustarc.com)
- [GitHub Issues](https://github.com/trustarc-ci/trustarc-cli/issues)

## License

Copyright © 2024 TrustArc. All rights reserved.
