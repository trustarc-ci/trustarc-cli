# TrustArc Flutter Mobile Consent SDK Demo

A comprehensive Flutter demonstration app showcasing TrustArc Mobile Consent SDK integration patterns and best practices.

## 🚀 Overview

This Flutter application demonstrates the complete implementation of TrustArc's Mobile Consent SDK, providing a reference implementation for mobile consent management with cross-platform support.

### Key Features

- **Complete SDK Integration**: Comprehensive TrustArc SDK setup with proper initialization and lifecycle management
- **Cross-Platform Support**: Native iOS and Android implementation with platform-specific optimizations
- **WebView Integration**: Advanced WebScript injection for seamless mobile-to-web consent synchronization
- **Real-Time Consent Management**: Live consent status monitoring with event-driven updates
- **Data Access Patterns**: Complete demonstration of all TrustArc SDK data access methods
- **Material Design UI**: Modern, accessible interface following Material Design principles

## 📱 App Structure

### Tab Navigation
- **Home**: Main consent management interface with SDK controls
- **Web Test**: WebView integration demonstrating mobile-to-web consent sync
- **Preferences**: SDK data inspection and debugging tools

### Core Components
- **Provider Pattern**: Dependency injection for SDK instance management
- **Event-Driven Updates**: Real-time consent change notifications
- **Error Handling**: Comprehensive error states and user feedback
- **Environment Configuration**: Flexible domain and URL configuration

## 🛠 Technical Architecture

### Dependencies
```yaml
dependencies:
  flutter: ^3.0.0
  provider: ^6.0.0
  flutter_trustarc_mobile_consent_sdk: ^latest
  flutter_inappwebview: ^5.0.0
  flutter_dotenv: ^5.0.0
  fluttertoast: ^8.0.0
```

### Project Structure
```
lib/
├── main.dart                 # App entry point and navigation setup
├── home.dart                 # Main consent management interface
├── consentWebTestPage.dart   # WebView integration with script injection
├── sharedPrefs.dart          # SDK data access and inspection
├── childActivity.dart        # Secondary navigation screen
└── tools.dart                # Reusable UI components and utilities
```

## 🔧 SDK Initialization

The TrustArc SDK follows a structured initialization pattern:

### 1. Provider Setup (main.dart)
```dart
MultiProvider(
  providers: [
    Provider<FlutterTrustarcMobileConsentSdk>.value(value: mobileSdk),
  ],
  child: MaterialApp(...)
)
```

### 2. SDK Initialization (home.dart)
```dart
// Initialize SDK in standard mode
await mobileSdk.initialize(SdkMode.standard);

// Start SDK with domain configuration
await mobileSdk.start(domain, "", ""); // Empty strings for auto-detection
```

### 3. Event Subscription
```dart
mobileSdk.subscribe(
  onSdkInitFinish: () => {
    // SDK initialization complete
    updateConsentStatus();
  },
  onConsentChanges: () => {
    // User consent preferences changed
    updateConsentStatus();
  }
);
```

## 🌐 WebView Integration

### Critical WebScript Timing

The WebView implementation demonstrates **critical timing requirements** for TrustArc WebScript injection:

```dart
initialUserScripts: UnmodifiableListView<UserScript>([
  UserScript(
    source: webScript,
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START, // CRITICAL
    forMainFrameOnly: true,
  ),
])
```

**⚠️ IMPORTANT**: WebScript injection at `AT_DOCUMENT_START` is **mandatory** to ensure:
- Consent preferences are applied before page content loads
- Tracking scripts respect user preferences from mobile app
- Web consent UI reflects mobile consent choices

### WebScript Injection Flow
1. **SDK Check**: Verify SDK is initialized before WebView load
2. **Script Fetch**: Retrieve WebScript from `mobileSdk.getWebScript()`
3. **Injection**: Inject at document start for proper timing
4. **Synchronization**: Mobile consent preferences apply to web content

## 📊 SDK Data Access

The app demonstrates access to all TrustArc SDK data types:

### Consent Preferences
```dart
// Get basic consent data by category
final consents = await mobileSdk.getConsentDataByCategory();
final consentMap = json.decode(consents);
```

### IAB TCF Compliance
```dart
// Get IAB Transparency & Consent Framework string
final tcfString = await mobileSdk.getTcfString();

// Get detailed IAB TCF preferences
final iabPrefs = await mobileSdk.getIABTCFPreferences();
```

### Google Integration
```dart
// Get Google-specific consent mappings
final googleConsents = await mobileSdk.getGoogleConsents();
```

### WebScript Access
```dart
// Get JavaScript for WebView injection
final webScript = await mobileSdk.getWebScript();
```

## ⚙️ Configuration

### Environment Variables (.env)
```env
MAC_DOMAIN=your-trustarc-domain.com
TEST_WEBSITE_URL=https://your-test-website.com
```

### Default Configuration (main.dart)
```dart
const String kDefaultDomainName = "mac_trustarc.com";
String get domainName => dotenv.env['MAC_DOMAIN'] ?? kDefaultDomainName;
```

## 🚀 Getting Started

### Prerequisites
- Flutter 3.0+
- iOS development environment (Xcode)
- Android development environment (Android Studio)
- TrustArc domain credentials

### Installation
1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd trustarc_mobile_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure environment**
   ```bash
   # Create .env file with your TrustArc domain
   echo "MAC_DOMAIN=your-domain.com" > .env
   ```

4. **Clean and run the app**
   ```bash
   # Clean build (recommended for first run or after dependency changes)
   flutter clean
   flutter pub get
   
   # For iOS
   flutter run ios
   
   # For Android
   flutter run android
   ```

## 📱 Platform-Specific Setup

### iOS Configuration
- **Minimum iOS Version**: 12.0+
- **WebView Debugging**: Available in iOS 16.4+ development builds
- **Info.plist**: Add network security configuration if needed

### Android Configuration
- **Minimum SDK**: API 21 (Android 5.0)
- **WebView Debugging**: Enabled automatically in debug builds
- **Permissions**: Internet permission for network requests

## 🔍 Debugging and Testing

### WebView Debugging
- **iOS**: Use Safari Web Inspector when `isInspectable: true`
- **Android**: Use Chrome DevTools when debugging is enabled

### Console Logs
- SDK initialization status
- Consent change events
- WebScript injection success/failure
- Error states and exceptions

### Testing Consent Flow
1. Initialize SDK on Home tab
2. Open Consent Manager to set preferences
3. View consent status updates in real-time
4. Test WebView integration on Web Test tab
5. Inspect SDK data on Preferences tab

## 🎨 UI/UX Design

### Design System
- **Colors**: TrustArc brand blue (#1A2D3E, #05668D)
- **Typography**: System fonts with consistent sizing
- **Components**: Material Design with custom styling
- **Accessibility**: Full accessibility support

### User Feedback
- **Toast Notifications**: Status updates and confirmations
- **Loading States**: Progress indicators during SDK operations
- **Error States**: Clear error messages with recovery options

## 🔐 Security Considerations

### WebScript Security
- Scripts are injected only in main frame (not iframes)
- Debug features disabled in production builds
- Network requests use secure HTTPS connections

### Data Protection
- All SDK data access follows TrustArc security guidelines
- No sensitive data is logged in production
- User preferences are stored securely by SDK

## 📚 Additional Resources

### TrustArc Documentation
- [Mobile SDK Documentation](https://docs.trustarc.com)
- [Integration Guides](https://support.trustarc.com)
- [Best Practices](https://www.trustarc.com/resources)

### Flutter Resources
- [Flutter Documentation](https://flutter.dev/docs)
- [Provider Pattern](https://pub.dev/packages/provider)
- [WebView Integration](https://pub.dev/packages/flutter_inappwebview)

## 🤝 Contributing

This demo app serves as a reference implementation. For production use:

1. **Customize Configuration**: Update domain and branding
2. **Enhance Error Handling**: Add production-grade error management
3. **Optimize Performance**: Implement caching and optimization strategies
4. **Add Analytics**: Integrate usage tracking and metrics

## 📄 License

This demo application is provided as-is for educational and demonstration purposes. Please refer to TrustArc's licensing terms for SDK usage in production applications.

---

**📞 Support**: For technical support and questions, contact TrustArc Mobile Team or refer to the official TrustArc documentation.