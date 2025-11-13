# TrustArc React Native Mobile Consent App

A comprehensive React Native application demonstrating TrustArc Mobile Consent SDK integration, WebView consent synchronization, and data access patterns.

## Quick Run

### Prerequisites
- Node.js 18+
- React Native development environment
- iOS Simulator or Android Emulator
- TrustArc domain credentials

### Setup & Run
1. **Navigate to project**
   ```bash
   cd react/trustarc-mobile-app
   ```

2. **Configure TRUSTARC_TOKEN**
   ```bash
   export TRUSTARC_TOKEN=your-token-here
   ```
   
   *Note: The .npmrc file is already configured to use this environment variable*

3. **Install dependencies**
   ```bash
   npm install
   ```

4. **Configure your domain**
   
   **Option A: Use MAC_DOMAIN environment variable**
   ```bash
   export MAC_DOMAIN=your-domain.com
   ```
   
   **Option B: Update config file directly**
   - Open `config/app.config.ts`
   - Replace `"mac_trustarc.com"` in `macDomain` with your TrustArc domain

5. **Prebuild and run the app**
   ```bash
   # Clean prebuild (recommended for first run or after dependency changes)
   npx expo prebuild --clean
   
   # For iOS
   npx expo run:ios
   
   # For Android
   npx expo run:android
   ```

6. **Test the app**
   - Initialize SDK on Home tab
   - Open Consent Manager to set preferences
   - Test WebView integration on Web Test tab

## 🚀 Features

- **Complete SDK Integration**: Full TrustArc Mobile Consent SDK implementation
- **WebView Consent Bridge**: Seamless consent synchronization between mobile and web
- **Real-time Data Access**: Comprehensive SDK data inspection and debugging tools
- **Cross-platform Support**: Optimized for both iOS and Android
- **Modern Architecture**: React Native with Expo Router and TypeScript

## 📱 App Structure

### Tab Navigation
1. **Home** (`app/(tabs)/index.tsx`) - Main consent management interface
2. **Web Test** (`app/(tabs)/webtest.tsx`) - WebView integration testing
3. **Preferences** (`app/(tabs)/sharedprefs.tsx`) - SDK data access and inspection

## 🛠️ Installation & Setup

### Prerequisites
- Node.js 18+ 
- React Native development environment
- iOS Simulator or Android Emulator
- TrustArc SDK credentials

### Installation Steps

1. **Clone and Install Dependencies**
   ```bash
   cd react/trustarc-mobile-app
   npm install
   ```

2. **Configure TrustArc Domain**
   
   Update your domain in `config/app.config.ts`:
   ```typescript
   export const APP_CONFIG: AppConfig = {
     domainName: "your-domain.com", // Replace with your TrustArc domain
     testWebsiteUrl: "https://your-test-site.com",
   };
   ```

3. **Run the Application**
   ```bash
   # iOS
   npx expo run:ios
   
   # Android  
   npx expo run:android
   ```

## 📚 TrustArc SDK Integration Guide

### 1. SDK Initialization

The TrustArc SDK follows a specific initialization flow that must be completed before any consent operations:

#### Initialization Process

```typescript
// 1. Initialize SDK in standard mode
await trustArcSdk.initialize(SdkMode.standard);

// 2. Start SDK with domain configuration
await trustArcSdk.start(domain, "", "");

// 3. Check initialization status
const isInitialized = await trustArcSdk.isSdkInitialized();
```

#### Key Implementation Details

**Location**: `app/(tabs)/index.tsx:138-152`

**Critical Requirements**:
- SDK must be initialized before any consent operations
- Domain parameter is required (configured in `config/app.config.ts`)
- IP address and locale parameters can be empty for auto-detection

**Event Handling**:
```typescript
// Listen for initialization completion
eventEmitter.addListener("onSdkInitFinish", () => {
  setSdkInitialized(true);
  setSdkLoading(false);
  updateConsentStatus();
});

// Listen for consent changes
eventEmitter.addListener("onConsentChanges", () => {
  updateConsentStatus();
});
```

**Error Handling**:
- Wrap initialization in try-catch blocks
- Provide user feedback during loading states
- Handle network failures gracefully

### 2. WebScript Injection (`getWebScript()`)

⚠️ **CRITICAL TIMING REQUIREMENTS** ⚠️

The WebScript injection is the most timing-sensitive part of the TrustArc integration. Proper timing ensures seamless consent synchronization between mobile and web.

#### Critical Timing Rules

1. **MUST** call `getWebScript()` AFTER SDK initialization
2. **MUST** inject script BEFORE WebView content loads
3. **MUST** use `injectedJavaScriptBeforeContentLoaded` property

#### Implementation Pattern

**Location**: `app/(tabs)/webtest.tsx:34-54`

```typescript
useEffect(() => {
  const fetchWebScript = async () => {
    // ✅ CRITICAL: Check SDK initialization first
    if (!await trustArcSdk.isSdkInitialized()) {
      return;
    }
    
    try {
      // ✅ Get WebScript after initialization
      const script = await trustArcSdk.getWebScript();
      setWebScript(script);
    } catch (error) {
      console.error("Error fetching web script:", error);
    }
  };

  fetchWebScript();
}, [trustArcSdk, isFocused]);
```

#### WebView Integration

```typescript
{webScript ? (
  <WebView
    key={key} // Force re-render when script changes
    // ✅ CRITICAL: Inject BEFORE content loads
    injectedJavaScriptBeforeContentLoaded={webScript}
    source={{ uri: getTestWebsiteUrl() }}
    onLoadStart={() => setLoading(true)}
    onLoadEnd={() => setLoading(false)}
  />
) : (
  <ErrorComponent />
)}
```

#### WebScript Best Practices

- **Always check SDK initialization** before calling `getWebScript()`
- **Handle script errors gracefully** with fallback UI
- **Force WebView re-render** when script changes (using `key` prop)
- **Show loading states** during script retrieval
- **Test with your target websites** to ensure compatibility

#### Common Integration Issues

❌ **Wrong**: Calling `getWebScript()` before SDK initialization
```typescript
// This will fail!
const script = await trustArcSdk.getWebScript(); // SDK not ready
```

✅ **Correct**: Check initialization first
```typescript
if (await trustArcSdk.isSdkInitialized()) {
  const script = await trustArcSdk.getWebScript(); // ✅ Safe to call
}
```

❌ **Wrong**: Injecting after content loads
```typescript
<WebView
  injectedJavaScript={webScript} // ❌ Too late!
  source={{ uri: url }}
/>
```

✅ **Correct**: Inject before content loads
```typescript
<WebView
  injectedJavaScriptBeforeContentLoaded={webScript} // ✅ Perfect timing
  source={{ uri: url }}
/>
```

### 3. Data Access from TrustArc SDK

The TrustArc SDK provides comprehensive data access methods for consent management, compliance reporting, and integration purposes.

#### Available Data Types

**Reference Implementation**: `app/(tabs)/sharedprefs.tsx`

The Preferences tab demonstrates all available SDK data access patterns:

1. **Consent Preferences** - Basic user consent choices
2. **IAB TCF String** - Transparency & Consent Framework data
3. **IAB TCF Preferences** - Detailed IAB consent information  
4. **Google Consents** - Google-specific consent mappings
5. **Web Script** - JavaScript for WebView integration

#### Data Access Methods

```typescript
// 1. Basic Consent Data
const consentData = await trustArcSdk.getStoredConsentData();
const parsedConsents = JSON.parse(consentData);

// 2. IAB TCF String (for European compliance)
const tcfString = await trustArcSdk.getTcfString();

// 3. Detailed IAB Preferences
const iabPreferences = await trustArcSdk.getIABTCFPreferences();

// 4. Google Consent Mappings
const googleConsents = await trustArcSdk.getGoogleConsents();
const parsedGoogle = JSON.parse(googleConsents);

// 5. WebView Integration Script
const webScript = await trustArcSdk.getWebScript();
```

#### Consent Data Structure

```typescript
interface TAConsent {
  value: number;                    // Category level (0=required, 1=functional, 2=advertising)
  domains: { [key: string]: string }[]; // Domain-specific consent values
}

// Usage example
const isGranted = consent.domains.some(domain => 
  Object.values(domain).includes("1")
);
```

#### Data Access Best Practices

- **Always check SDK initialization** before data access calls
- **Handle JSON parsing errors** for string-based responses
- **Implement loading states** for better user experience
- **Cache data appropriately** to avoid unnecessary SDK calls
- **Respect user privacy** when logging or storing consent data

#### Real-time Data Updates

```typescript
// Listen for consent changes to update data
useEffect(() => {
  const listener = eventEmitter.addListener("onConsentChanges", () => {
    // Refresh all data when consents change
    updateConsentStatus();
    updateGoogleConsents();
    updateIABData();
  });

  return () => listener.remove();
}, []);
```

## 🏗️ Project Architecture

### Core Configuration

- **`config/app.config.ts`** - Centralized domain and URL configuration
- **`app/_layout.tsx`** - Root layout with SDK provider setup
- **`app/(tabs)/_layout.tsx`** - Tab navigation configuration

### SDK Integration Layer

- **Context Providers**: TrustArc SDK instance management
- **Event Handling**: Native event bridge for consent changes
- **State Management**: React hooks for SDK state synchronization

### Component Structure

```
app/
├── _layout.tsx           # Root layout & SDK providers
├── (tabs)/
│   ├── _layout.tsx       # Tab navigation setup
│   ├── index.tsx         # Main consent interface
│   ├── webtest.tsx       # WebView integration
│   └── sharedprefs.tsx   # Data access demo
├── +not-found.tsx        # 404 error page
└── config/
    └── app.config.ts     # Configuration constants
```

## 🔧 Troubleshooting

### Common Issues

#### SDK Initialization Fails
- **Check domain configuration** in `config/app.config.ts`
- **Verify network connectivity** 
- **Ensure valid TrustArc domain** provided during onboarding
- **Check console logs** for specific error messages

#### WebScript Not Working
- **Verify SDK is initialized** before calling `getWebScript()`
- **Check script injection timing** (use `injectedJavaScriptBeforeContentLoaded`)
- **Test with known working websites**
- **Verify WebView permissions** and network access

#### Consent Data Empty
- **Initialize SDK completely** before accessing data
- **User must have interacted** with consent dialog at least once
- **Check for consent dialog dismissal** without selections
- **Verify consent domain matches** SDK initialization domain

#### Tab Navigation Issues
- **Check React Navigation setup** in `_layout.tsx` files
- **Verify all tab screens** are properly configured
- **Ensure SafeAreaProvider** wraps navigation

### Debugging Tools

#### Enable Debug Logging
```typescript
// Add to your initialization code
console.log("SDK Initialized:", await trustArcSdk.isSdkInitialized());
console.log("Consent Data:", await trustArcSdk.getStoredConsentData());
```

#### Use Preferences Tab
Navigate to the **Preferences** tab to inspect all SDK data in real-time:
- View consent categories and values
- Copy data to clipboard for analysis
- Monitor real-time consent changes
- Debug WebScript generation

#### Network Debugging
- **Monitor network requests** during SDK initialization
- **Check TrustArc domain accessibility**
- **Verify API response formats**

## 📋 Best Practices

### Performance
- **Initialize SDK early** in app lifecycle
- **Cache consent data** to minimize SDK calls
- **Use loading states** for better UX
- **Implement proper error boundaries**

### Security
- **Never log sensitive consent data** in production
- **Respect user privacy preferences**
- **Validate all SDK responses**
- **Use HTTPS for all network requests**

### User Experience
- **Provide clear loading indicators** during SDK operations
- **Handle network failures gracefully**
- **Offer retry mechanisms** for failed operations
- **Keep consent UI accessible** and user-friendly

### Development
- **Use TypeScript** for better type safety
- **Comment complex consent logic**
- **Test on both iOS and Android**
- **Validate consent synchronization** between mobile and web

## 📞 Support

For technical support and questions:
- **TrustArc Documentation**: Contact your Technical Account Manager
- **SDK Issues**: Check console logs and contact TrustArc support
- **Integration Questions**: Reference this README and code comments

## 📄 License

This project is for demonstration purposes. TrustArc SDK usage requires valid licensing from TrustArc.