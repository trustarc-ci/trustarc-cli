# TrustArc Mobile Consent SDK CLI

A command-line installer for integrating the TrustArc Mobile Consent SDK into your mobile applications.

## Features

- **Automated SDK Integration**: Streamlined installation process for iOS projects
- **Swift Package Manager Support**: Easy integration with SPM-based projects
- **CocoaPods Support**: Automatic Podfile modification and pod install
- **Sample Implementation**: Automatic boilerplate code generation
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
  - Must have access to `trustarc/trustarc-mobile-consent` repository

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

## iOS Integration

The CLI supports:
- Swift Package Manager (SPM)
- CocoaPods
- Swift 5.0+ and iOS 12.0+

**CocoaPods**: Automatically adds the pod with git URL and branch to your Podfile and runs `pod install`
```ruby
pod 'TrustArcConsentSDK', :git => 'https://TOKEN@github.com/...', :branch => 'release'
```

### Integration Steps

1. Choose "Integrate SDK" from the main menu
2. Provide your project path
3. Confirm git status is clean
4. Enter your TrustArc domain
5. Follow the guided integration process
6. Optionally generate implementation boilerplate

## Generated Code

The CLI generates a `TrustArcConsentImpl` class with:
- `initialize()` - Initialize the SDK
- `openCm()` - Open the consent management dialog
- Delegate implementations for SDK callbacks

### Usage

```swift
// Initialize SDK on app launch
TrustArcConsentImpl.shared.initialize()

// Show consent dialog
TrustArcConsentImpl.shared.openCm()
```

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
