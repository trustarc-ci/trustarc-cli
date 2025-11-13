/// TrustArc WebView Integration - Consent Script Testing
///
/// This component demonstrates TrustArc SDK integration with WebView for web consent synchronization.
///
/// Key Features:
/// - TrustArc WebScript injection into web pages
/// - Cross-platform WebView configuration (iOS/Android)
/// - Real-time consent synchronization between native and web
/// - Environment-based configuration management
/// - Debug support for development builds
///
/// Critical Implementation Details:
/// - WebScript injection at document start ensures consent rules apply before page content loads
/// - Platform-specific debugging configurations for iOS 16.4+ and Android
/// - Error handling for SDK initialization failures
/// - Loading states for better user experience
///
/// @author TrustArc Mobile Team
/// @version 1.0.0

// Dart core imports
import 'dart:collection';
import 'dart:io';
// Flutter framework imports
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// WebView and TrustArc SDK imports
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_trustarc_mobile_consent_sdk/flutter_trustarc_mobile_consent_sdk.dart';
// State management and configuration imports
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// === WEBVIEW CONFIGURATION ===
/// Default test website URL for demonstrating TrustArc SDK integration with web consent
///
/// This website is used to test the Mobile App Consent (MAC) to Web consent functionality,
/// demonstrating how mobile consent preferences sync with web-based consent management.
const String kDefaultTestWebsiteUrl = 'https://trustarc.com';

/// Get test website URL from environment variables or fallback to default
///
/// Environment variable: TEST_WEBSITE_URL
/// Fallback: kDefaultTestWebsiteUrl (Smashburger demo site)
///
/// @returns String URL for WebView testing
String get testWebsiteUrl {
  try {
    return dotenv.env['TEST_WEBSITE_URL'] ?? kDefaultTestWebsiteUrl;
  } catch (e) {
    // If dotenv is not initialized yet, return default
    return kDefaultTestWebsiteUrl;
  }
}

// === WEBVIEW TEST SCREEN WIDGET ===
/// WebView Test Screen Widget
///
/// Provides interface for testing TrustArc SDK WebScript injection and web consent synchronization.
/// Demonstrates how mobile consent preferences are applied to web content through script injection.
class WebTestScreen extends StatefulWidget {
  const WebTestScreen({super.key});

  @override
  WebTestScreenState createState() => WebTestScreenState();
}

/// State class for WebView Test Screen
///
/// Manages TrustArc WebScript injection, WebView configuration, and UI state.
/// Handles SDK initialization checking and error states.
class WebTestScreenState extends State<WebTestScreen> {
  // === TRUSTARC WEB SCRIPT STATE ===
  /// TrustArc WebScript for injection into WebView
  ///
  /// This script contains the necessary JavaScript to apply mobile consent
  /// preferences to web content. Fetched from SDK after initialization.
  String? webScript;

  // === UI STATE MANAGEMENT ===
  /// WebView loading state
  /// Shows loading indicator while page is loading
  bool isLoading = false;

  /// Error state for SDK or WebScript failures
  /// Displays error message if SDK is not initialized or WebScript is unavailable
  bool hasError = false;

  // === WIDGET LIFECYCLE ===
  /// Initialize widget state and setup WebView configuration
  ///
  /// Sets up web debugging for development and fetches TrustArc WebScript
  /// for injection into the WebView.
  @override
  void initState() {
    super.initState();
    _enableWebDebugging();
    _fetchWebScript();
  }

  // === WEBVIEW CONFIGURATION METHODS ===

  /// Enable web debugging for development builds
  ///
  /// Platform-specific debugging configuration:
  /// - Android: Enables WebView debugging in debug mode for Chrome DevTools access
  /// - iOS: Uses isInspectable setting in WebView configuration
  ///
  /// Only enabled in debug builds for security.
  Future<void> _enableWebDebugging() async {
    // Enable debugging for Android in debug mode only
    if (!kIsWeb && Platform.isAndroid && kDebugMode) {
      await InAppWebViewController.setWebContentsDebuggingEnabled(true);
    }
  }

  /// Fetch TrustArc WebScript for injection into WebView
  ///
  /// This method retrieves the JavaScript code that applies mobile consent
  /// preferences to web content. The script must be injected at document start
  /// to ensure consent rules are applied before page content loads.
  ///
  /// Prerequisites:
  /// - TrustArc SDK must be initialized
  /// - WebScript must be available from SDK
  ///
  /// Error Handling:
  /// - Sets error state if SDK is not initialized
  /// - Sets error state if WebScript is empty or unavailable
  /// - Displays error message to user
  Future<void> _fetchWebScript() async {
    try {
      final mobileSdk =
          Provider.of<FlutterTrustarcMobileConsentSdk>(context, listen: false);
      final isInitialized = await mobileSdk.isSdkInitialized();

      if (!isInitialized || (await mobileSdk.getWebScript()).isEmpty) {
        setState(() => hasError = true);
        return;
      }

      final script = await mobileSdk.getWebScript();
      setState(() => webScript = script);
    } catch (error) {
      setState(() => hasError = true);
    }
  }

  // === MAIN WIDGET BUILD ===
  @override
  Widget build(BuildContext context) {
    // === ERROR STATE HANDLING ===
    // Display error message if SDK is not initialized or WebScript is unavailable
    if (hasError) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red),
              SizedBox(height: 16),
              Text('Error loading WebScript from TrustArc SDK'),
            ],
          ),
        ),
      );
    }

    // === LOADING STATE ===
    // Show loading indicator while fetching WebScript
    if (webScript == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // === MAIN WEBVIEW INTERFACE ===
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        toolbarHeight: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFFF8F9FA),
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      body: Stack(
        children: [
          // === TRUSTARC WEBVIEW INTEGRATION ===
          /**
           * InAppWebView with TrustArc WebScript injection
           * 
           * Critical implementation details:
           * - WebScript injection at AT_DOCUMENT_START ensures consent rules apply before content loads
           * - forMainFrameOnly: true prevents script injection in iframes for security
           * - JavaScript enabled for TrustArc consent functionality
           * - Debug inspection enabled only in development builds
           */
          InAppWebView(
            // === WEBSITE LOADING ===
            // Load test website with TrustArc consent script injection
            initialUrlRequest: URLRequest(url: WebUri(testWebsiteUrl)),

            // === TRUSTARC SCRIPT INJECTION ===
            /**
             * Inject TrustArc consent script at document start
             * 
             * CRITICAL TIMING: AT_DOCUMENT_START injection ensures:
             * - Consent preferences are applied before page content loads
             * - Web consent UI reflects mobile consent choices
             * - Tracking scripts respect user preferences from mobile app
             * 
             * Security: forMainFrameOnly prevents injection in iframes
             */
            initialUserScripts: UnmodifiableListView<UserScript>([
              UserScript(
                source: webScript!,
                injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                forMainFrameOnly: true,
              ),
            ]),
            // === WEBVIEW SETTINGS ===
            /**
             * WebView configuration for TrustArc integration
             * 
             * Settings:
             * - javaScriptEnabled: Required for TrustArc consent functionality
             * - isInspectable: Enables Web Inspector on iOS 16.4+ in debug builds only
             */
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              // Enable inspection for iOS 16.4+ and debug mode only
              isInspectable: kDebugMode,
            ),

            // === WEBVIEW EVENT HANDLERS ===
            /**
             * WebView lifecycle event handlers
             * 
             * - onLoadStart: Show loading indicator when page starts loading
             * - onLoadStop: Hide loading indicator when page finishes loading
             * - onReceivedError: Display error state if page fails to load
             */
            onLoadStart: (controller, url) => setState(() => isLoading = true),
            onLoadStop: (controller, url) => setState(() => isLoading = false),
            onReceivedError: (controller, request, error) =>
                setState(() => hasError = true),
          ),

          // === LOADING OVERLAY ===
          /**
           * Loading indicator overlay
           * 
           * Displays while WebView is loading the page with injected TrustArc script.
           * Uses brand colors consistent with app theme.
           */
          if (isLoading)
            Container(
              color: const Color(0xFFF8F9FA),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF05668D)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
