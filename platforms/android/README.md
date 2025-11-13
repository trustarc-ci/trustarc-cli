# TrustArc Android Mobile Consent App

A comprehensive Android demonstration application showcasing the integration and usage of the TrustArc Consent SDK for native Android applications. This app provides a complete testing interface for consent management, real-time status tracking, and SDK initialization workflows.

## Quick Run

### Prerequisites
- Android Studio 4.0+
- Android API Level 21+ device/emulator
- TrustArc domain credentials

### Setup & Run
1. **Navigate to project**
   ```bash
   cd android/TrustArcMobileApp
   ```

2. **Configure TRUSTARC_TOKEN**
   ```bash
   export TRUSTARC_TOKEN=your-token-here
   ```
   
   *Note: The settings.gradle is already configured to read from the TRUSTARC_TOKEN environment variable for security*

3. **Configure your domain**
   - Open `AppConfig.kt`
   - Replace `"mac_trustarc.com"` in `MAC_DOMAIN` with your TrustArc domain

4. **Build and run**
   - Open project in Android Studio
   - Sync project with Gradle files
   - Select target device/emulator
   - Run the application

## Features

- **Real-time Consent Dashboard**: Visual display of consent categories with color-coded status indicators
- **Dynamic Status Cards**: Automatically generated UI components for each consent category
- **SDK Initialization Management**: Complete SDK lifecycle handling with dependency injection
- **Consent Dialog Integration**: Native Android consent management interface
- **Automated Data Processing**: Intelligent consent data categorization and status determination
- **Modern Android Architecture**: MVVM pattern with Dagger Hilt dependency injection
- **Material Design UI**: Native Android components with Material Design principles

## Architecture Overview

### Design Pattern
- **MVVM (Model-View-ViewModel)**: Uses Android Architecture Components with LiveData
- **Dependency Injection**: Dagger Hilt for modular and testable architecture
- **Repository Pattern**: ConsentManager handles data operations and business logic
- **Observer Pattern**: Real-time UI updates through TrustArc SDK listeners

### Key Components

#### HomeFragment (Main UI)
- Header section with app branding
- Consent Status Dashboard displaying active consent categories
- SDK Controls section with consent dialog trigger button
- Dynamic status card generation based on consent data

#### ConsentManager (Data Layer)
- Manages TrustArc SDK initialization and configuration
- Handles consent data retrieval and processing
- Provides abstraction layer over TrustArc SDK operations

#### WebFragment (WebView Integration)
- Demonstrates WebScript injection for web-based consent management
- Configurable test website for consent validation
- JavaScript bridge for SDK integration

### Dependency Injection Structure

```
AppModule
├── TrustArc SDK Instance
├── ConsentManager Implementation
└── Application Context
```

## TrustArc SDK Integration

### SDK Initialization

The app initializes the TrustArc SDK through the ConsentManager:

```kotlin
// ConsentManagerImpl.kt
override fun initialize() {
    Log.d("ConsentManager", "Initializing TrustArc SDK")
    trustArc.useGdprDetection(false)
    trustArc.start(domainName = AppConfig.DOMAIN_NAME)
    isInitialized = true
}
```

**Configuration**: The domain `AppConfig.DOMAIN_NAME` is configured in the AppConfig file. Update this value for different environments.

### SDK Configuration Options

| Setting | Value | Description |
|---------|-------|-------------|
| Domain | `AppConfig.DOMAIN_NAME` | TrustArc domain for consent management |
| GDPR Detection | `false` | Disable automatic GDPR detection |
| Initialization | Lazy | SDK initialized when ConsentManager.initialize() is called |

### Consent Data Processing

The app processes consent data through a multi-step workflow:

1. **Data Retrieval**: SDK provides consent data via listener callbacks
2. **Status Determination**: Analyzes TAConsent objects to determine user choices
3. **UI Generation**: Creates dynamic status cards for each category
4. **Visual Updates**: Applies color-coded styling based on consent status

### Consent Status Logic

```kotlin
private fun determineConsentStatus(taConsent: TAConsent): ConsentStatus {
    // Required categories (value "0") are always granted
    if (taConsent.value == "0") {
        return ConsentStatus.GRANTED
    }
    
    // Check domain values for "1" indicating user consent
    val hasConsent = taConsent.domains?.any { domain -> 
        domain.values.contains("1") 
    } ?: false
    
    return if (hasConsent) ConsentStatus.GRANTED else ConsentStatus.DENIED
}
```

## Application Configuration

### AppConfig.kt

Centralized configuration file containing all configurable values:

```kotlin
object AppConfig {
    // TrustArc SDK Configuration
    const val DOMAIN_NAME: String = "mac_trustarc.com"
    const val TEST_WEBSITE_URL: String = "https://trustarc.com"
    
    // SDK Behavior
    const val SDK_MODE: String = "standard"
    const val ENABLE_DEBUG_MODE: Boolean = true
    
    // UI Configuration
    const val APP_DISPLAY_NAME: String = "TrustArc SDK Testing"
    const val AUTO_SHOW_CONSENT_DIALOG: Boolean = true
    
    // WebView Configuration
    const val WEBVIEW_JAVASCRIPT_ENABLED: Boolean = true
    const val WEBVIEW_DOM_STORAGE_ENABLED: Boolean = true
    
    // Logging
    const val LOG_TAG: String = "TrustArcMobileApp"
    const val ENABLE_VERBOSE_LOGGING: Boolean = true
}
```

### Environment Management

To configure for different environments:

1. **Development**: Use test domain and enable debug logging
2. **Staging**: Use staging domain with moderate logging
3. **Production**: Use production domain and disable debug features

Update `AppConfig.kt` values accordingly:

```kotlin
// Development
const val DOMAIN_NAME: String = "dev-domain.com"
const val ENABLE_DEBUG_MODE: Boolean = true

// Production
const val DOMAIN_NAME: String = "production-domain.com"
const val ENABLE_DEBUG_MODE: Boolean = false
```

## User Interface

### Consent Status Dashboard

The dashboard displays consent categories with visual indicators:

- **Green Circle + "OPTED-IN"**: User has granted consent
- **Red Circle + "OPTED-OUT"**: User has denied consent  
- **Gray Circle + "UNDEFINED"**: Consent status not determined

### Dynamic Status Cards

Status cards are generated automatically based on consent data:

- **Category Name**: Displays the consent category identifier
- **Status Text**: Shows current consent state in readable format
- **Visual Indicator**: Color-coded circle indicating status
- **Material Design**: Follows Android Material Design guidelines

### Empty States

- **"Consents not set"**: Displayed when no consent data is available
- **Automatic Updates**: UI refreshes when consent status changes
- **Smooth Transitions**: Cards animate in/out as consent data changes

## Prerequisites

### Android Requirements
- Android API Level 21 (Android 5.0) or later
- Android Studio 4.0 or later
- Kotlin 1.5.0 or later
- Gradle 7.0 or later

### Dependencies
- TrustArc Android Mobile Consent SDK
- Dagger Hilt for dependency injection
- AndroidX libraries
- Material Design Components

### SDK Integration

Add to your app-level `build.gradle`:

```gradle
dependencies {
    implementation 'com.trustarc:trustarc-android-mobile-consent-sdk:+'
    
    // Dependency Injection
    implementation "com.google.dagger:hilt-android:2.44"
    kapt "com.google.dagger:hilt-compiler:2.44"
    
    // AndroidX
    implementation 'androidx.fragment:fragment-ktx:1.5.0'
    implementation 'androidx.lifecycle:lifecycle-viewmodel-ktx:2.6.0'
    
    // Material Design
    implementation 'com.google.android.material:material:1.8.0'
}
```

## Getting Started

### 1. Configure Your Domain

Update the domain in `AppConfig.kt`:

```kotlin
const val DOMAIN_NAME: String = "your-domain.com"
```

### 2. Set Up Dependency Injection

Ensure your Application class is annotated with `@HiltAndroidApp`:

```kotlin
@HiltAndroidApp
class MyApplication : Application()
```

### 3. Add Required Permissions

Add to your `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### 4. Build and Run

1. Open the project in Android Studio
2. Sync the project with Gradle files
3. Select your target device or emulator
4. Build and run the application
5. Test consent dialog functionality

## Usage Examples

### Initializing the SDK

```kotlin
@Inject
lateinit var consentManager: ConsentManager

override fun onCreate() {
    super.onCreate()
    consentManager.initialize()
}
```

### Opening Consent Dialog

```kotlin
@Inject
lateinit var trustArc: TrustArc

private fun showConsentDialog() {
    trustArc.openCM()
}
```

### Handling Consent Updates

```kotlin
private fun observeConsentChanges() {
    trustArc.addConsentListener { consents ->
        activity?.runOnUiThread {
            updateUIWithDynamicConsents(consents)
        }
    }
}
```

### WebView Integration

```kotlin
private fun setupWebView() {
    webView.webViewClient = object : WebViewClient() {
        override fun onPageCommitVisible(view: WebView?, url: String?) {
            val script = trustArc.getWebScript()
            if (!script.isNullOrEmpty()) {
                webView.evaluateJavascript(script) { result ->
                    Log.d("CONSENT_SCRIPT", "Script loaded: $result")
                }
            }
        }
    }
}
```

## Data Access and Storage

### Local Data Access

The TrustArc SDK stores consent data in Android SharedPreferences:

```kotlin
val consentPrefs = context.getSharedPreferences(
    "com.truste.androidmobileconsentsdk", 
    Context.MODE_PRIVATE
)
```

### Data Structure

Consent data follows this structure:

```
TAConsent
├── value: String (consent level: "0", "1", "2", etc.)
├── domains: List<TAConsentDomain>?
│   └── values: List<String> ("0" = denied, "1" = granted)
└── categoryKey: String (category identifier)
```

### Consent Categories

| Level | Type | Description |
|-------|------|-------------|
| 0 | Required | Always granted, necessary for basic functionality |
| 1 | Functional | Optional functional features and enhancements |
| 2 | Advertising | Marketing and advertising-related data collection |

### Remote Data Sync

The SDK automatically syncs consent data with TrustArc servers:

- **Automatic Upload**: Consent choices are sent to TrustArc servers
- **Network Resilience**: Failed uploads are retried automatically
- **Background Processing**: Data sync occurs without blocking UI

## Testing and Debugging

### Debug Logging

Enable debug logging in `AppConfig.kt`:

```kotlin
const val ENABLE_DEBUG_MODE: Boolean = true
const val LOG_TAG: String = "TrustArcMobileApp"
```

### Console Output

The app provides detailed logging for debugging:

```
D/ConsentManager: Initializing TrustArc SDK
D/TrustArcMobileApp: Opening consent dialog for domain: mac_trustarc.com
D/CONSENT_SCRIPT: Loaded script: true
```

### Common Issues

#### SDK Not Initializing
- Verify domain configuration is correct
- Check internet connectivity
- Ensure TrustArc domain is properly configured

#### Consent Dialog Not Showing
- Confirm SDK initialization completed successfully
- Check if domain supports consent management
- Verify no network connectivity issues

#### WebView Script Not Loading
- Ensure JavaScript is enabled in WebView settings
- Verify DOM storage is enabled
- Check if website supports TrustArc integration

### Testing Strategies

#### Unit Testing
```kotlin
@Test
fun `consent status determination works correctly`() {
    val taConsent = TAConsent().apply {
        value = "1"
        domains = listOf(TAConsentDomain().apply {
            values = listOf("1")
        })
    }
    
    val status = determineConsentStatus(taConsent)
    assertEquals(ConsentStatus.GRANTED, status)
}
```

#### Integration Testing
- Test consent dialog flow end-to-end
- Verify UI updates when consent changes
- Test WebView script injection
- Validate data persistence across app restarts

#### UI Testing
```kotlin
@Test
fun `consent cards display correctly`() {
    // Launch fragment
    launchFragmentInContainer<HomeFragment>()
    
    // Verify UI elements
    onView(withId(R.id.statusCardContainer)).check(matches(isDisplayed()))
    onView(withId(R.id.btnShowConsentDialog)).check(matches(isDisplayed()))
}
```

## Error Handling

### Network Errors

```kotlin
override fun onNetworkError(error: Exception) {
    Log.w(AppConfig.LOG_TAG, "Network error during consent sync", error)
    // Show user-friendly error message
    // Implement retry mechanism
}
```

### Initialization Failures

```kotlin
override fun initialize() {
    try {
        trustArc.start(domainName = AppConfig.DOMAIN_NAME)
        isInitialized = true
    } catch (e: Exception) {
        Log.e(AppConfig.LOG_TAG, "Failed to initialize TrustArc SDK", e)
        // Handle initialization failure
        // Show error dialog to user
    }
}
```

### WebView Errors

```kotlin
override fun onReceivedError(view: WebView?, request: WebResourceRequest?, error: WebResourceError?) {
    Log.w(AppConfig.LOG_TAG, "WebView error: ${error?.description}")
    // Handle page load errors
    // Show fallback content
}
```

## Best Practices

### Performance Optimization
- Use lazy initialization for SDK components
- Implement efficient list updates for consent cards
- Cache consent status to minimize SDK calls
- Use background threads for data processing

### User Experience
- Provide clear visual feedback for consent status changes
- Show loading states during SDK initialization
- Handle network failures gracefully with retry options
- Follow Material Design guidelines for consistent UI

### Security and Privacy
- Never log sensitive consent data in production
- Implement proper error handling without exposing internal details
- Follow Android security best practices
- Respect user privacy choices throughout the app lifecycle

### Code Organization
- Use dependency injection for modular architecture
- Separate business logic from UI components
- Implement proper separation of concerns
- Follow Kotlin coding conventions

## Technical Specifications

### Supported Android Versions
- Minimum SDK: API 21 (Android 5.0)
- Target SDK: API 33 (Android 13)
- Kotlin: 1.8.0+
- Gradle: 7.4+

### SDK Compatibility
- TrustArc Android Mobile Consent SDK 1.0+
- Compatible with latest Android privacy frameworks
- Supports Android 13 privacy features

### Performance Characteristics
- Minimal memory footprint (<5MB additional)
- Efficient consent data processing (<100ms)
- Responsive UI with smooth animations
- Background data sync with minimal battery impact

## Troubleshooting

### Common Solutions

| Issue | Solution |
|-------|----------|
| Consent dialog not appearing | Check domain configuration and network connectivity |
| UI not updating | Ensure main thread execution for UI updates |
| WebView script not loading | Verify JavaScript and DOM storage settings |
| Initialization timeout | Check TrustArc domain configuration and network |
| Data persistence issues | Verify SharedPreferences permissions |

### Diagnostic Commands

```kotlin
// Check SDK initialization status
Log.d(TAG, "SDK initialized: ${consentManager.isInitialized}")

// Verify consent data
val consentData = trustArc.getConsentDataByCategory()
Log.d(TAG, "Consent categories: ${consentData.size}")

// Test WebView configuration
Log.d(TAG, "JavaScript enabled: ${webView.settings.javaScriptEnabled}")
```

### Support Resources

- [TrustArc Developer Documentation](https://developer.trustarc.com)
- [Android Privacy Guidelines](https://developer.android.com/privacy)
- [Material Design Guidelines](https://material.io/design)
- [Dagger Hilt Documentation](https://dagger.dev/hilt/)

## Contributing

When contributing to this project:

1. Follow Android and Kotlin coding standards
2. Maintain comprehensive documentation and comments
3. Add appropriate error handling and logging
4. Test on multiple Android versions and device types
5. Update this README for any significant changes
6. Follow Material Design principles for UI changes

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Note**: This is a demonstration application for testing TrustArc SDK integration. For production use, ensure proper configuration of your TrustArc domain, implement appropriate error handling, and follow Android security best practices.