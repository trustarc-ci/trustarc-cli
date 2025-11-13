# TrustArc iOS Mobile Consent App

A comprehensive iOS demonstration application showcasing the integration and usage of the TrustArc Consent SDK for SwiftUI applications. This app provides a complete testing interface for consent management, real-time status tracking, and SDK initialization workflows.

## Quick Run

### Prerequisites
- Xcode 12.0 or later
- iOS 14.0+ simulator or device
- TrustArc domain credentials

### Setup & Run
1. **Open the project**
   ```bash
   cd ios/trustarc-mobile-app
   open TrustArcMobileApp.xcworkspace
   ```

2. **Configure TRUSTARC_TOKEN**
   
   **Step 1: Export token as environment variable**
   ```bash
   export TRUSTARC_TOKEN=your-token-here
   ```
   
   **Step 2: Update Podfile dependency URL**
   ```ruby
   pod 'TrustArcConsentSDK', :git => 'https://YOUR_TRUSTARC_TOKEN@github.com/trustarc/trustarc-mobile-consent.git', :branch => 'v2025.09.2'
   ```
   
   *Note: Both steps are required - export the token AND manually update the Podfile with your actual token*

3. **Configure your domain**
   - Open `AppConfig.swift`
   - Replace `"mac_trustarc.com"` in `macDomain` with your TrustArc domain

4. **Install dependencies**
   ```bash
   pod install
   ```

5. **Build and run**
   - Select your target device/simulator in Xcode
   - Press ⌘+R to build and run
   - Test consent dialog functionality

## Features

- **Real-time Consent Dashboard**: Visual display of consent categories with color-coded status indicators
- **SDK Initialization Management**: Complete SDK lifecycle handling with delegate callbacks
- **Consent Dialog Integration**: Modal consent management interface with WebKit display
- **Automated Data Processing**: Intelligent consent data categorization and status determination
- **SwiftUI Architecture**: Modern MVVM pattern with reactive UI updates
- **iOS Privacy Compliance**: Integration with App Tracking Transparency framework

## Architecture Overview

### Design Pattern
- **MVVM (Model-View-ViewModel)**: Uses SwiftUI with `ObservableObject` for reactive data binding
- **Delegate Pattern**: Implements TrustArc SDK delegate protocols for event handling
- **Reactive UI**: `@Published` properties automatically update the interface when data changes

### Key Components

#### ContentView (Main UI)
- Header section with app branding
- Consent Status Dashboard displaying active consent categories
- SDK Controls section with consent dialog trigger button
- Responsive layout with ScrollView for various screen sizes

#### ContentViewController (View Model)
- Manages TrustArc SDK initialization and configuration
- Processes consent data and transforms it for UI display
- Handles all SDK delegate callbacks and lifecycle events
- Maintains UI state through `@Published` properties

#### ConsentStatusCard (UI Component)
- Individual card component for displaying consent categories
- Color-coded status indicators (green=granted, red=denied, gray=undefined)
- Displays category names and current consent status

## TrustArc SDK Integration

### SDK Initialization

The app initializes the TrustArc SDK with the following configuration:

```swift
// Configure SDK settings
_ = TrustArc.sharedInstance.setDomain("mac_trustarc.com")    // Test domain
_ = TrustArc.sharedInstance.setMode(.standard)                    // Standard consent mode
_ = TrustArc.sharedInstance.enableAppTrackingTransparencyPrompt(true) // Enable iOS ATT

// Start SDK with callback
TrustArc.sharedInstance.start { shouldShowConsentUI in
    // Handle initialization completion
}
```

**Important**: The domain `"mac_trustarc.com"` is configured for testing purposes. In production, replace this with your actual domain.

### SDK Configuration Options

| Setting | Value | Description |
|---------|-------|-------------|
| Domain | `mac_trustarc.com` | TrustArc domain for consent management |
| Mode | `.standard` | Standard consent collection mode |
| ATT Integration | `true` | Enable iOS App Tracking Transparency |

### Delegate Implementations

The app implements three key TrustArc delegate protocols:

#### TADelegate (SDK Lifecycle)
- `sdkIsNotInitialized()`: Called when SDK is uninitialized
- `sdkIsInitializing()`: Called during SDK initialization
- `sdkIsInitialized()`: Called when SDK is ready for use

#### TAConsentViewControllerDelegate (Consent Dialog)
- `isLoadingWebView()`: Called when consent dialog starts loading
- `didFinishLoadingWebView()`: Called when consent dialog is ready
- `didReceiveConsentData()`: Called when user completes consent choices

#### TAConsentReporterDelegate (Data Transmission)
- `consentReporterWillSend()`: Called before sending consent data
- `consentReporterDidSend()`: Called after successful data transmission
- `consentReporterDidFailSending()`: Called when data transmission fails

## Consent Data Management

### Data Processing Flow

1. **Raw Data Retrieval**: Uses `TrustArc.sharedInstance.getConsentDataByCategory()` to fetch consent data
2. **Data Grouping**: Groups consent categories by their value (consent level)
3. **Status Determination**: Analyzes domain values to determine granted/denied status
4. **UI Updates**: Transforms data into `ConsentCard` objects for display

### Consent Categories

The app categorizes consent data by levels:

| Level | Type | Description |
|-------|------|-------------|
| 0 | Required | Always granted, necessary for basic functionality |
| 1 | Functional | Optional functional features and enhancements |
| 2 | Advertising | Marketing and advertising-related data collection |

### Status Logic

```swift
// Consent status determination
if taConsent.value == "0" {
    return .granted  // Required categories always granted
}

// Check domain values for "1" indicating user consent
let hasConsent = taConsent.domains?.contains { domain in
    domain.values.contains("1")
} ?? false

return hasConsent ? .granted : .denied
```

## User Interface

### Consent Status Dashboard

The dashboard dynamically displays consent categories with visual indicators:

- **Green Circle + "OPTED-IN"**: User has granted consent
- **Red Circle + "OPTED-OUT"**: User has denied consent  
- **Gray Circle + "UNDEFINED"**: Consent status not determined

### SDK Controls

- **Show Consent Dialog**: Opens the TrustArc consent management interface
- **Button State Management**: Disabled during initialization, enabled when SDK is ready

### Empty States

- **"Consents not set"**: Displayed when no consent data is available
- **Automatic Updates**: UI refreshes when consent status changes

## Prerequisites

### iOS Requirements
- iOS 14.0 or later
- Xcode 12.0 or later
- Swift 5.3 or later

### Dependencies
- TrustArc Consent SDK
- iOS App Tracking Transparency framework
- WebKit framework

### Installation via CocoaPods

Add to your `Podfile`:

```ruby
pod 'TrustArcConsentSDK'
```

Then run:
```bash
pod install
```

## Getting Started

### 1. Configure Your Domain

Replace the test domain in `ContentViewController.loadTrustArcSdk()`:

```swift
// Replace with your actual TrustArc domain
_ = TrustArc.sharedInstance.setDomain("your-domain.com")
```

### 2. Add Privacy Permissions

Add to your `Info.plist`:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>This app would like to track you across apps and websites to provide personalized ads.</string>
```

### 3. Build and Run

1. Open `TrustArcMobileApp.xcworkspace` in Xcode
2. Select your target device or simulator
3. Build and run the project
4. Test consent dialog functionality

## Usage Examples

### Opening Consent Dialog

```swift
@MainActor
func openConsentDialog() {
    if let rootView = getRootView() {
        TrustArc.sharedInstance.openCM(in: rootView, delegate: self)
    }
}
```

### Checking Consent Status

```swift
let consentData = TrustArc.sharedInstance.getConsentDataByCategory()
if let consents = consentData as? [String: TAConsent] {
    // Process consent data
    updateConsentCards(consents: consents)
}
```

### Handling Consent Updates

```swift
func consentViewController(_ controller: TAConsentViewController, 
                          didReceiveConsentData data: [String: Any]) {
    // Update UI with new consent data
    let updatedConsents = TrustArc.sharedInstance.getConsentDataByCategory()
    updateConsentCards(consents: updatedConsents)
}
```

## Data Access and Storage

### Local Data Access

The TrustArc SDK stores consent data locally on the device:

```swift
// Retrieve all consent data
let consentData = TrustArc.sharedInstance.getConsentDataByCategory()

// Access specific consent category
if let consent = consentData["category_name"] as? TAConsent {
    let status = determineConsentStatus(consent)
    print("Category status: \(status)")
}
```

### Data Structure

Consent data follows this structure:

```
TAConsent
├── value: String (consent level: "0", "1", "2", etc.)
├── domains: [TAConsentDomain]?
│   └── values: [String] ("0" = denied, "1" = granted)
└── categoryKey: String (category identifier)
```

### Remote Data Sync

The SDK automatically syncs consent data with TrustArc servers:

- **Automatic Upload**: Consent choices are sent to TrustArc servers
- **Network Resilience**: Failed uploads are retried automatically
- **Delegate Callbacks**: Monitor upload status via `TAConsentReporterDelegate`

## Testing and Debugging

### Console Logging

The app provides detailed console output for debugging:

```
SDK initialized - checking existing consent data: [...]
Updating consent cards with 3 categories
Category value 1 (functional_cookies) has status: granted
Consent report successfully sent to TrustArc servers
```

### Common Issues

#### SDK Not Initializing
- Verify domain configuration is correct
- Check internet connectivity
- Ensure TrustArc domain is properly configured

#### Consent Dialog Not Showing
- Confirm root view controller is available
- Check if SDK initialization completed successfully
- Verify delegate registration

#### Data Not Updating
- Ensure UI updates occur on main thread
- Check delegate method implementations
- Verify consent data retrieval logic

### Debug Mode

Enable detailed SDK logging during development:

```swift
// Add to SDK initialization
TrustArc.sharedInstance.enableDebugMode(true)
```

## Error Handling

### Network Errors

```swift
func consentReporterDidFailSending(report: TAConsentReportInfo) {
    print("Failed to send consent report to TrustArc servers")
    // Implement retry logic or user notification
}
```

### Initialization Failures

```swift
func sdkIsNotInitialized() {
    sdkStatus = "Initialization Failed"
    // Show error message to user
    // Implement retry mechanism
}
```

### WebView Loading Issues

```swift
func consentViewController(_ controller: TAConsentViewController, 
                          isLoadingWebView webView: WKWebView) {
    // Show loading indicator
    // Implement timeout handling
}
```

## Best Practices

### Performance Optimization
- Use `@MainActor` for UI updates to ensure thread safety
- Implement lazy loading for consent cards with `LazyVStack`
- Cache consent status to minimize SDK calls

### User Experience
- Provide clear visual feedback for consent status changes
- Show loading states during SDK initialization
- Handle network failures gracefully with retry options

### Privacy Compliance
- Follow Apple's App Tracking Transparency guidelines
- Implement proper consent dialog timing
- Respect user consent choices throughout the app lifecycle

### Testing Strategy
- Test consent dialog on various screen sizes
- Verify data persistence across app launches
- Test network failure scenarios
- Validate consent status accuracy

## Technical Specifications

### Supported iOS Versions
- iOS 14.0+ (required for App Tracking Transparency)
- Swift 5.3+
- Xcode 12.0+

### SDK Compatibility
- TrustArc Consent SDK 1.0+
- Compatible with latest iOS privacy frameworks

### Performance Characteristics
- Minimal memory footprint
- Efficient consent data processing
- Responsive UI with smooth animations

## Troubleshooting

### Common Solutions

| Issue | Solution |
|-------|----------|
| Consent dialog not appearing | Check root view controller availability |
| SDK initialization timeout | Verify network connection and domain config |
| UI not updating | Ensure main thread execution for UI updates |
| Data persistence issues | Check device storage and permissions |

### Support Resources

- [TrustArc Developer Documentation](https://developer.trustarc.com)
- [iOS Privacy Guidelines](https://developer.apple.com/privacy/)
- [App Tracking Transparency Framework](https://developer.apple.com/documentation/apptrackingtransparency)

## Contributing

When contributing to this project:

1. Follow iOS and Swift coding standards
2. Maintain comprehensive documentation
3. Add appropriate error handling
4. Test on multiple iOS versions and device types
5. Update this README for any significant changes

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Note**: This is a demonstration application for testing TrustArc SDK integration. For production use, ensure proper configuration of your TrustArc domain and implementation of appropriate error handling and user experience patterns.