#!/usr/bin/env python3
"""
TrustArc SDK Diagnostic Q&A Interface
Interactive question-answering about SDK integration issues
"""

import os
import sys
import json
from typing import List, Dict, Optional

# Knowledge base of common issues and solutions
KNOWLEDGE_BASE = {
    "initialization": {
        "keywords": ["initialize", "init", "start", "setup", "constructor"],
        "qa_pairs": [
            {
                "question": "How do I initialize the TrustArc SDK?",
                "answer": """
The initialization process varies by platform:

ANDROID (Kotlin):
```kotlin
val trustArc = TrustArc(context, SdkMode.Standard)
trustArc.enableDebugLog(true)  // Optional, for debugging
trustArc.start(domainName = "your.domain.com")
```

iOS (Swift):
```swift
let trustArc = TrustArc(context: context, sdkMode: .standard)
trustArc.enableDebugLog(true)  // Optional
trustArc.start(domainName: "your.domain.com")
```

REACT NATIVE:
```javascript
import TrustArc from '@trustarc/react-native-sdk';

await TrustArc.initialize({
  domain: 'your.domain.com',
  debugMode: true
});
```

FLUTTER:
```dart
import 'package:trustarc_sdk/trustarc_sdk.dart';

await TrustArc.initialize(
  domain: 'your.domain.com',
  debugMode: true,
);
```
"""
            },
            {
                "question": "Why is my SDK not initializing?",
                "answer": """
Common reasons for initialization failure:

1. Missing dependency - Ensure SDK is added to your dependencies:
   - Android: Check build.gradle for com.trustarc:trustarc-consent-sdk
   - iOS: Check Package.swift or Podfile for TrustArcMobileConsent
   - React Native: Check package.json
   - Flutter: Check pubspec.yaml

2. Missing permissions (Android):
   - INTERNET permission required in AndroidManifest.xml
   - ACCESS_NETWORK_STATE recommended

3. Invalid domain name:
   - Ensure domain is correctly configured in TrustArc dashboard
   - Check for typos in domain string

4. Network connectivity:
   - SDK needs internet to fetch consent configuration
   - Check device/emulator has network access

5. Initialization timing:
   - Initialize in Application.onCreate() (Android) or AppDelegate (iOS)
   - Don't initialize too late in app lifecycle
"""
            },
            {
                "question": "What is the difference between SdkMode.Standard and SdkMode.IabTCFv_2_2?",
                "answer": """
SdkMode.Standard:
- General consent management
- Custom consent categories
- Simpler implementation
- Use for: Most applications

SdkMode.IabTCFv_2_2:
- IAB Transparency & Consent Framework v2.2
- Standardized consent for advertising
- TCF string generation for ad partners
- Use for: Apps with programmatic advertising

Choose based on your needs:
- Use Standard if you just need basic consent management
- Use IabTCFv_2_2 if you work with IAB-compliant ad networks
"""
            }
        ]
    },
    "consent_dialog": {
        "keywords": ["dialog", "show", "display", "ui", "opencm", "consent form"],
        "qa_pairs": [
            {
                "question": "How do I show the consent dialog?",
                "answer": """
Call openCM() method after SDK is initialized:

ANDROID:
```kotlin
trustArc.openCM()
```

iOS:
```swift
trustArc.openCM()
```

IMPORTANT:
- SDK must be initialized first (start() called)
- Dialog opens as a native modal/dialog
- User interaction updates consent preferences automatically
"""
            },
            {
                "question": "Why is my consent dialog not showing?",
                "answer": """
Checklist:

1. SDK initialized? → Call start() before openCM()
2. UI thread? → Ensure openCM() called on main/UI thread
3. Already shown? → Dialog won't show if user already consented
4. Network error? → Check logs for initialization errors
5. Domain configured? → Verify domain exists in TrustArc dashboard

Debug steps:
1. Enable debug logging: trustArc.enableDebugLog(true)
2. Check logs for initialization success
3. Verify start() completed before openCM()
4. Check isConsentPresent() to see if consent already exists
"""
            },
            {
                "question": "How do I auto-show consent dialog on first launch?",
                "answer": """
Check if consent exists, then show dialog:

ANDROID:
```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    // Initialize SDK first
    trustArc.start(domainName = "your.domain.com")

    // Show dialog if no consent present
    if (!trustArc.isConsentPresent()) {
        trustArc.openCM()
    }
}
```

iOS:
```swift
func applicationDidFinishLaunching(_ application: UIApplication) {
    trustArc.start(domainName: "your.domain.com")

    if !trustArc.isConsentPresent() {
        trustArc.openCM()
    }
}
```
"""
            }
        ]
    },
    "data_retrieval": {
        "keywords": ["get", "retrieve", "data", "consent", "tcf", "google"],
        "qa_pairs": [
            {
                "question": "How do I get user consent data?",
                "answer": """
Available data retrieval methods:

1. Get all consent data:
   `trustArc.getStoredConsentData()` → List of consent categories

2. Get IAB TCF string:
   `trustArc.getTcfString()` → TCF consent string for ad partners

3. Get Google consents:
   `trustArc.getGoogleConsents()` → Google-specific consent settings

4. Check specific consent:
   `trustArc.getConsentValue(trackerId)` → Consent for specific tracker

5. Check if consent exists:
   `trustArc.isConsentPresent()` → Boolean

6. Get last consent timestamp:
   `trustArc.getLastConsent()` → Timestamp of last update

Example (Android):
```kotlin
val consentData = trustArc.getStoredConsentData()
for (consent in consentData) {
    Log.d("Consent", "${consent.domain}: ${consent.consent}")
}

val tcfString = trustArc.getTcfString()
// Share with ad partners
```
"""
            }
        ]
    },
    "webview": {
        "keywords": ["webview", "web", "javascript", "script", "inject"],
        "qa_pairs": [
            {
                "question": "How do I integrate consent with WebView?",
                "answer": """
Inject consent script into WebView:

ANDROID:
```kotlin
webView.settings.javaScriptEnabled = true
webView.settings.domStorageEnabled = true

webView.webViewClient = object : WebViewClient() {
    override fun onPageCommitVisible(view: WebView?, url: String?) {
        val script = trustArc.getWebScript()
        if (script != null) {
            webView.evaluateJavascript(script) { result ->
                Log.d("WebView", "Script injected: $result")
            }
        }
    }
}

webView.loadUrl("https://your-website.com")
```

iOS:
```swift
webView.configuration.preferences.javaScriptEnabled = true

func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    if let script = trustArc.getWebScript() {
        webView.evaluateJavaScript(script) { (result, error) in
            print("Script injected")
        }
    }
}
```

This syncs native consent with web consent cookies.
"""
            }
        ]
    },
    "listeners": {
        "keywords": ["listener", "callback", "event", "change", "update"],
        "qa_pairs": [
            {
                "question": "How do I listen for consent changes?",
                "answer": """
Register consent listener before calling start():

ANDROID:
```kotlin
trustArc.addConsentListener { consentCategories ->
    // Called when user changes consent
    Log.d("Consent", "Consent updated: $consentCategories")

    // Update analytics, ad SDKs, etc.
    updateAnalyticsConsent(consentCategories)
}

trustArc.start(domainName = "your.domain.com")
```

iOS:
```swift
trustArc.addConsentListener { consents in
    print("Consent updated: \\(consents)")
    // Update SDKs based on new consent
}

trustArc.start(domainName: "your.domain.com")
```

The listener fires whenever:
- User updates consent via openCM()
- Consent is loaded on first launch
- Consent expires and needs refresh
"""
            }
        ]
    },
    "errors": {
        "keywords": ["error", "crash", "exception", "fail", "problem"],
        "qa_pairs": [
            {
                "question": "Common errors and solutions",
                "answer": """
1. "SDK not initialized" error:
   → Call start() before using SDK methods
   → Check TASharedInstance.isSdkInitialized() (Android)

2. Network/timeout errors:
   → Check INTERNET permission (Android)
   → Verify device has network connectivity
   → Check domain configuration in TrustArc dashboard

3. "openCM() does nothing":
   → Ensure start() completed successfully
   → Enable debug logging to see errors
   → Check if consent already present

4. Dependency resolution errors:
   → Verify correct repository configuration
   → Check GitHub token has package read access
   → Ensure correct SDK version

5. WebView script not working:
   → Enable JavaScript: javaScriptEnabled = true
   → Enable DOM storage: domStorageEnabled = true
   → Inject at correct time: onPageCommitVisible

Enable debug logging for detailed error info:
```
trustArc.enableDebugLog(true)
```
"""
            }
        ]
    }
}


def find_relevant_answers(query: str, diagnostic_report: Optional[Dict] = None) -> List[Dict]:
    """Find relevant Q&A pairs based on query"""
    query_lower = query.lower()
    results = []

    # Search through all categories
    for category, data in KNOWLEDGE_BASE.items():
        # Check if query matches category keywords
        keyword_match = any(keyword in query_lower for keyword in data["keywords"])

        if keyword_match:
            # Add all Q&A pairs from this category
            for qa in data["qa_pairs"]:
                results.append({
                    "category": category,
                    "question": qa["question"],
                    "answer": qa["answer"]
                })

    # If diagnostic report provided, add context-specific answers
    if diagnostic_report:
        results.extend(get_diagnostic_specific_answers(diagnostic_report, query_lower))

    return results


def get_diagnostic_specific_answers(report: Dict, query: str) -> List[Dict]:
    """Generate answers specific to diagnostic findings"""
    answers = []

    # Check for specific errors in the report
    if not report.get("sdk_found"):
        if any(word in query for word in ["dependency", "install", "add", "setup"]):
            platform = report.get("platform", "unknown")
            answer = get_dependency_help(platform)
            answers.append({
                "category": "diagnostic",
                "question": f"How to add TrustArc SDK to {platform}?",
                "answer": answer
            })

    return answers


def get_dependency_help(platform: str) -> str:
    """Get platform-specific dependency installation help"""
    if platform == "android":
        return """
To add TrustArc SDK to Android:

1. Add GitHub Packages repository to settings.gradle.kts:
```kotlin
dependencyResolutionManagement {
    repositories {
        maven {
            name = "TrustArcMobileConsent"
            url = uri("https://maven.pkg.github.com/trustarc/trustarc-mobile-consent")
            credentials {
                username = "your-github-username"
                password = "your-github-token"
            }
        }
    }
}
```

2. Add dependency to app/build.gradle.kts:
```kotlin
dependencies {
    implementation("com.trustarc:trustarc-consent-sdk:VERSION")
}
```

3. Sync gradle and rebuild
"""
    elif platform == "ios":
        return """
To add TrustArc SDK to iOS:

OPTION 1: Swift Package Manager
1. In Xcode: File → Add Package Dependencies
2. Enter: https://github.com/trustarc/trustarc-mobile-consent
3. Select version and add to target

OPTION 2: CocoaPods
1. Add to Podfile:
```ruby
pod 'TrustArcMobileConsent', '~> VERSION'
```
2. Run: pod install
"""
    elif platform == "react-native":
        return """
To add TrustArc SDK to React Native:

1. Add to package.json:
```bash
npm install @trustarc/react-native-sdk
# or
yarn add @trustarc/react-native-sdk
```

2. Link native dependencies:
```bash
npx pod-install  # iOS
```

3. Import in your code:
```javascript
import TrustArc from '@trustarc/react-native-sdk';
```
"""
    elif platform == "flutter":
        return """
To add TrustArc SDK to Flutter:

1. Add to pubspec.yaml:
```yaml
dependencies:
  trustarc_sdk: ^VERSION
```

2. Get dependencies:
```bash
flutter pub get
```

3. Import in your code:
```dart
import 'package:trustarc_sdk/trustarc_sdk.dart';
```
"""
    else:
        return "Platform-specific help not available."


def interactive_qa(diagnostic_file: Optional[str] = None):
    """Interactive Q&A session"""
    print("=" * 80)
    print("TrustArc SDK Q&A Assistant")
    print("=" * 80)
    print("")
    print("Ask questions about TrustArc SDK integration (or 'quit' to exit)")
    print("Example questions:")
    print("  - How do I initialize the SDK?")
    print("  - Why is my consent dialog not showing?")
    print("  - How do I get consent data?")
    print("")

    # Load diagnostic report if available
    diagnostic_report = None
    if diagnostic_file and os.path.exists(diagnostic_file):
        try:
            with open(diagnostic_file) as f:
                diagnostic_report = json.load(f)
                print(f"✓ Loaded diagnostic report (Platform: {diagnostic_report.get('platform')})")
                print("")
        except:
            pass

    while True:
        try:
            query = input("Your question: ").strip()

            if not query:
                continue

            if query.lower() in ['quit', 'exit', 'q']:
                print("\nGoodbye!")
                break

            # Find relevant answers
            answers = find_relevant_answers(query, diagnostic_report)

            if not answers:
                print("\nI couldn't find a specific answer for that question.")
                print("Try asking about:")
                print("  - Initialization")
                print("  - Consent dialog")
                print("  - Data retrieval")
                print("  - WebView integration")
                print("  - Listeners/callbacks")
                print("  - Common errors")
                print("")
                continue

            # Display answers
            print("\n" + "-" * 80)
            for i, answer in enumerate(answers, 1):
                print(f"\n[{answer['category'].upper()}] {answer['question']}")
                print(answer['answer'])
                if i < len(answers):
                    print("\n" + "─" * 80)

            print("\n" + "-" * 80)
            print("")

        except KeyboardInterrupt:
            print("\n\nGoodbye!")
            break
        except Exception as e:
            print(f"\nError: {e}")
            print("")


def main():
    """Main entry point"""
    diagnostic_file = None

    if len(sys.argv) > 1:
        diagnostic_file = sys.argv[1]

    interactive_qa(diagnostic_file)


if __name__ == "__main__":
    main()
