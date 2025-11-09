# TrustArc Mobile Consent SDK CLI

A command-line installer for integrating the TrustArc Mobile Consent SDK into your mobile applications.

## Features

- **Automated SDK Integration**: Streamlined installation process for iOS projects
- **Swift Package Manager Support**: Easy integration with SPM-based projects
- **CocoaPods Support**: Automatic Podfile modification and pod install
- **Sample Implementation**: Automatic boilerplate code generation
- **Platform Detection**: Auto-detects your project configuration
- **Git-Safe**: Validates git status before making changes

## Quick Start

Run the installer with a single command:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/refs/heads/main/install.sh)"
```

Or with wget:

```bash
sh -c "$(wget https://raw.githubusercontent.com/trustarc-ci/trustarc-cli/refs/heads/main/install.sh -O -)"
```

## Requirements

- macOS or Linux
- Xcode (for iOS integration)
- Git (recommended)
- GitHub Personal Access Token with access to TrustArc repositories

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

The CLI stores configuration in `~/.trustarc-cli-config`:
- GitHub token
- Last used domain
- Platform preferences

You can safely delete this file when no longer needed.

## Support

For issues or questions, please visit:
- [TrustArc Documentation](https://docs.trustarc.com)
- [GitHub Issues](https://github.com/trustarc-ci/trustarc-cli/issues)

## License

Copyright © 2024 TrustArc. All rights reserved.
