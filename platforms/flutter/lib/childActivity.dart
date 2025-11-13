/// TrustArc Child Activity - Secondary Navigation Screen
///
/// This component provides a secondary activity screen for advanced TrustArc SDK operations
/// and navigation. It demonstrates route parameter passing and alternative SDK methods.
///
/// Features:
/// - Route parameter extraction for domain, IP address, and locale configuration
/// - Language-specific consent manager access
/// - Navigation to shared preferences screen
/// - Back navigation to main screen
///
/// Use Cases:
/// - Testing consent manager with specific locale settings
/// - Accessing SDK data from different parts of the app
/// - Demonstrating advanced SDK configuration options
///
/// Navigation Pattern:
/// - Receives configuration via route arguments
/// - Provides buttons for common SDK operations
/// - Integrates with app navigation stack
///
/// @author TrustArc Mobile Team
/// @version 1.0.0

// Flutter framework imports
import 'package:flutter/material.dart';
// TrustArc SDK imports
import 'package:flutter_trustarc_mobile_consent_sdk/flutter_trustarc_mobile_consent_sdk.dart';
// State management imports
import 'package:provider/provider.dart';
// Local utility imports
import 'tools.dart';

// === CHILD ACTIVITY SCREEN WIDGET ===
/// Child Activity Screen Widget
///
/// Secondary navigation screen for advanced TrustArc SDK operations.
/// Demonstrates route parameter handling and alternative SDK methods.
class ChildActivity extends StatefulWidget {
  const ChildActivity({super.key});

  @override
  ChildActivityState createState() => ChildActivityState();
}

/// State class for Child Activity Screen
///
/// Manages TrustArc SDK operations with route-specific configuration.
/// Handles parameter extraction and navigation actions.
class ChildActivityState extends State<ChildActivity> {
  // === TRUSTARC SDK INSTANCE ===
  /// TrustArc Mobile Consent SDK instance
  /// Accessed via Provider pattern for dependency injection
  late FlutterTrustarcMobileConsentSdk mobileSdk;

  // === MAIN WIDGET BUILD ===
  @override
  Widget build(BuildContext context) {
    // === TRUSTARC SDK PROVIDER ACCESS ===
    // Get SDK instance from Provider for dependency injection
    mobileSdk = Provider.of<FlutterTrustarcMobileConsentSdk>(context);

    // === ROUTE ARGUMENTS EXTRACTION ===
    /**
     * Extract configuration parameters from route arguments
     * 
     * Expected parameters:
     * - domain: TrustArc domain name for SDK operations
     * - ipAddress: IP address for geolocation (empty for auto-detection)
     * - locale: Language locale for consent manager UI
     */

    return Scaffold(
        appBar: AppBar(title: const Text("Child Activity")),
        body: SafeArea(
            child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // === TRUSTARC CONSENT MANAGER ACTIONS ===
            /**
             * Open Consent Manager button
             * 
             * Demonstrates two SDK methods:
             * - openCMWithLanguage(): For locale-specific consent UI
             * - openCM(): For default locale consent UI
             * 
             * The method selection is based on locale parameter availability.
             */
            buildButton("Open CM", () async {
              // Open consent manager with language support
              await mobileSdk.openCM();
            }),

            // === NAVIGATION ACTIONS ===
            /**
             * Navigation buttons for accessing different app screens
             * 
             * - View Shared Prefs: Navigate to SDK data inspection screen
             * - Back To Main: Return to main home screen
             */
            buildButton("View Shared Prefs", () {
              Navigator.pushNamed(context, '/sharedPrefs');
            }),
            buildButton("Back To Main", () {
              Navigator.popUntil(context, ModalRoute.withName('/home'));
            }),
          ],
        )));
  }
}
