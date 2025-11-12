/// TrustArc Consent Implementation for Flutter
///
/// This file provides a simplified interface for integrating the TrustArc Mobile Consent SDK
/// into your Flutter application. It handles SDK initialization, consent management,
/// and event subscriptions.
///
/// Quick Start:
/// 1. Import this file: import 'TrustArcConsentImpl.dart';
/// 2. Initialize in your app: TrustArcConsentImpl.initialize(context);
/// 3. Show consent dialog: TrustArcConsentImpl.openCm();
///
/// @author TrustArc Mobile Team
/// @version 1.0.0

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_trustarc_mobile_consent_sdk/flutter_trustarc_mobile_consent_sdk.dart';

/// TrustArc Consent Manager Implementation
///
/// Provides a streamlined interface for TrustArc consent management operations
/// including SDK initialization, consent dialog presentation, and status retrieval.
class TrustArcConsentImpl {
  // === CONFIGURATION ===
  /// TrustArc domain name for consent management
  /// This will be replaced during CLI installation with your specific domain
  static const String domain = "__TRUSTARC_DOMAIN_PLACEHOLDER__";

  // === SDK INSTANCE ===
  /// Singleton instance of the TrustArc Mobile Consent SDK
  static final FlutterTrustarcMobileConsentSdk _mobileSdk =
      FlutterTrustarcMobileConsentSdk();

  // === STATE TRACKING ===
  /// Track SDK initialization status
  static bool _isInitialized = false;

  /// Track SDK loading status
  static bool _isLoading = false;

  // === EVENT CALLBACKS ===
  /// Callback function for SDK initialization completion
  static Function? _onSdkInitFinishCallback;

  /// Callback function for consent changes
  static Function? _onConsentChangesCallback;

  /// Callback function for Google consent changes
  static Function? _onGoogleConsentChangesCallback;

  // === INITIALIZATION METHODS ===

  /// Initialize the TrustArc SDK
  ///
  /// This is the main entry point for integrating TrustArc consent management.
  /// Call this method once when your app starts, typically in your main widget's
  /// initState or in a Provider/Bloc initialization.
  ///
  /// Example usage in a StatefulWidget:
  /// ```dart
  /// @override
  /// void initState() {
  ///   super.initState();
  ///   WidgetsBinding.instance.addPostFrameCallback((_) {
  ///     TrustArcConsentImpl.initialize(context);
  ///   });
  /// }
  /// ```
  ///
  /// Example usage in main.dart:
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   runApp(MyApp());
  /// }
  ///
  /// class MyApp extends StatelessWidget {
  ///   @override
  ///   Widget build(BuildContext context) {
  ///     // Initialize after first frame
  ///     WidgetsBinding.instance.addPostFrameCallback((_) {
  ///       TrustArcConsentImpl.initialize(context);
  ///     });
  ///     return MaterialApp(...);
  ///   }
  /// }
  /// ```
  ///
  /// @param context BuildContext for showing toast notifications (optional)
  /// @returns Future<void>
  static Future<void> initialize([BuildContext? context]) async {
    if (_isLoading) {
      debugPrint('TrustArc: SDK initialization already in progress');
      return;
    }

    try {
      // Check if SDK is already initialized
      final isInitialized = await _mobileSdk.isSdkInitialized();
      if (isInitialized) {
        _isInitialized = true;
        debugPrint('TrustArc: SDK already initialized');
        _onSdkInitFinishCallback?.call();
        return;
      }

      // Setup event subscriptions
      _setupEventSubscriptions();

      // Start initialization
      _isLoading = true;
      debugPrint('TrustArc: Initializing SDK with domain: $domain');

      // Initialize SDK in standard mode (production mode)
      await _mobileSdk.initialize(SdkMode.standard);

      // Start SDK with domain configuration
      // Empty IP and locale strings allow SDK to auto-detect
      await _mobileSdk.start(domain, "", "");

      debugPrint('TrustArc: SDK initialization started successfully');
    } catch (error) {
      _isLoading = false;
      _isInitialized = false;
      debugPrint('TrustArc: Error initializing SDK: $error');
      rethrow;
    }
  }

  /// Setup event subscriptions for SDK callbacks
  ///
  /// Configures the SDK to notify the application of important events:
  /// - SDK initialization completion
  /// - User consent preference changes
  /// - Google-specific consent updates
  ///
  /// These subscriptions are set up once during initialization and remain
  /// active for the lifetime of the application.
  static void _setupEventSubscriptions() {
    _mobileSdk.subscribe(
      onSdkInitFinish: () {
        _isInitialized = true;
        _isLoading = false;
        debugPrint('TrustArc: SDK initialization finished');
        _onSdkInitFinishCallback?.call();
      },
      onConsentChanges: () {
        debugPrint('TrustArc: Consent preferences changed');
        _onConsentChangesCallback?.call();
      },
      onGoogleConsentChanges: () {
        debugPrint('TrustArc: Google consent preferences changed');
        _onGoogleConsentChangesCallback?.call();
      },
    );
  }

  // === CONSENT MANAGEMENT METHODS ===

  /// Open the TrustArc Consent Manager dialog
  ///
  /// Presents the consent preferences UI to the user, allowing them to
  /// review and modify their consent choices.
  ///
  /// Example usage in a button:
  /// ```dart
  /// ElevatedButton(
  ///   onPressed: () async {
  ///     await TrustArcConsentImpl.openCm();
  ///   },
  ///   child: Text('Manage My Privacy'),
  /// )
  /// ```
  ///
  /// The SDK must be initialized before calling this method. If not initialized,
  /// this method will return without action.
  ///
  /// @returns Future<void>
  static Future<void> openCm() async {
    if (!_isInitialized) {
      debugPrint('TrustArc: Cannot open CM - SDK not initialized');
      return;
    }

    try {
      debugPrint('TrustArc: Opening Consent Manager');
      await _mobileSdk.openCM();
    } catch (error) {
      debugPrint('TrustArc: Error opening Consent Manager: $error');
      rethrow;
    }
  }

  /// Get current consent status by category
  ///
  /// Retrieves the user's current consent preferences organized by category.
  /// Returns a map where keys are category names and values contain consent details.
  ///
  /// Example usage:
  /// ```dart
  /// final consents = await TrustArcConsentImpl.getConsentStatus();
  /// print('User consents: $consents');
  ///
  /// // Check specific category
  /// if (consents.containsKey('Analytics')) {
  ///   final analyticsConsent = consents['Analytics'];
  ///   print('Analytics consent value: ${analyticsConsent['value']}');
  /// }
  /// ```
  ///
  /// Returns null if SDK is not initialized or if an error occurs.
  ///
  /// @returns Future<Map<String, dynamic>?> Consent data organized by category
  static Future<Map<String, dynamic>?> getConsentStatus() async {
    if (!_isInitialized) {
      debugPrint('TrustArc: Cannot get consent status - SDK not initialized');
      return null;
    }

    try {
      final consentsJson = await _mobileSdk.getConsentDataByCategory();
      final Map<String, dynamic> consents = json.decode(consentsJson);
      return consents;
    } catch (error) {
      debugPrint('TrustArc: Error getting consent status: $error');
      return null;
    }
  }

  /// Check if a specific consent category is granted
  ///
  /// Convenience method to check if the user has granted consent for a specific
  /// category (e.g., "Analytics", "Advertising", "Functional").
  ///
  /// Example usage:
  /// ```dart
  /// final hasAnalyticsConsent = await TrustArcConsentImpl.hasConsent('Analytics');
  /// if (hasAnalyticsConsent) {
  ///   // Initialize analytics tracking
  ///   Analytics.initialize();
  /// }
  /// ```
  ///
  /// @param categoryName Name of the consent category to check
  /// @returns Future<bool> true if consent is granted, false otherwise
  static Future<bool> hasConsent(String categoryName) async {
    final consents = await getConsentStatus();
    if (consents == null || !consents.containsKey(categoryName)) {
      return false;
    }

    final category = consents[categoryName];
    if (category['value'] == "0") {
      // Required category (value 0) is always granted
      return true;
    }

    // Check if any domain has consent value "1" (granted)
    final domains = category['domains'] as List?;
    if (domains == null || domains.isEmpty) {
      return false;
    }

    return domains.any((domain) {
      final values = domain['values'] as List?;
      return values?.contains("1") ?? false;
    });
  }

  // === EVENT LISTENER METHODS ===

  /// Register callback for SDK initialization completion
  ///
  /// The callback will be invoked when the SDK finishes initializing.
  /// This is useful for updating UI state or triggering post-initialization logic.
  ///
  /// Example usage:
  /// ```dart
  /// TrustArcConsentImpl.onSdkInitFinish(() {
  ///   print('SDK is ready!');
  ///   setState(() {
  ///     sdkReady = true;
  ///   });
  /// });
  /// ```
  ///
  /// @param callback Function to call when SDK initialization completes
  static void onSdkInitFinish(Function callback) {
    _onSdkInitFinishCallback = callback;
  }

  /// Register callback for consent changes
  ///
  /// The callback will be invoked whenever the user modifies their consent preferences.
  /// This is the primary way to react to consent changes in your application.
  ///
  /// Example usage:
  /// ```dart
  /// TrustArcConsentImpl.onConsentChange(() async {
  ///   print('User consent preferences changed');
  ///   final hasAnalytics = await TrustArcConsentImpl.hasConsent('Analytics');
  ///   if (hasAnalytics) {
  ///     // Enable analytics
  ///   } else {
  ///     // Disable analytics
  ///   }
  /// });
  /// ```
  ///
  /// @param callback Function to call when consent preferences change
  static void onConsentChange(Function callback) {
    _onConsentChangesCallback = callback;
  }

  /// Register callback for Google consent changes
  ///
  /// The callback will be invoked when Google-specific consent preferences change.
  /// This is useful if your app uses Google services and needs to handle
  /// Google consent separately.
  ///
  /// Example usage:
  /// ```dart
  /// TrustArcConsentImpl.onGoogleConsentChange(() {
  ///   print('Google consent preferences changed');
  ///   // Update Google services configuration
  /// });
  /// ```
  ///
  /// @param callback Function to call when Google consent changes
  static void onGoogleConsentChange(Function callback) {
    _onGoogleConsentChangesCallback = callback;
  }

  // === STATUS QUERY METHODS ===

  /// Check if SDK is currently initialized
  ///
  /// @returns bool true if SDK is initialized and ready to use
  static bool isInitialized() {
    return _isInitialized;
  }

  /// Check if SDK is currently loading
  ///
  /// @returns bool true if SDK initialization is in progress
  static bool isLoading() {
    return _isLoading;
  }

  /// Get the configured domain name
  ///
  /// @returns String TrustArc domain configured for this SDK instance
  static String getDomain() {
    return domain;
  }
}
