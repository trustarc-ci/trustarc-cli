/// TrustArc Flutter Mobile Consent - Main Interface
///
/// This is the primary screen for managing user consent preferences using the TrustArc SDK.
/// Features:
/// - SDK initialization and status monitoring
/// - Real-time consent status display
/// - Consent management dialog access
/// - Event-driven consent updates
/// - Material Design UI with proper theming
///
/// This file demonstrates the complete TrustArc SDK integration pattern for Flutter,
/// including initialization, event handling, consent status management, and UI updates.
///
/// @author TrustArc Mobile Team
/// @version 1.0.0

// Dart core imports
import 'dart:convert';
// Flutter framework imports
import 'package:flutter/material.dart';
// TrustArc SDK imports
import 'package:flutter_trustarc_mobile_consent_sdk/flutter_trustarc_mobile_consent_sdk.dart';
// Local utility imports
import 'package:trustarc_mobile_app/tools.dart';
// State management imports
import 'package:provider/provider.dart';
// Configuration imports
import 'package:trustarc_mobile_app/main.dart';

// === HOME SCREEN WIDGET ===
/// Main consent management screen widget
///
/// Provides the primary interface for TrustArc consent management including
/// SDK initialization, consent status display, and consent dialog access.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

/// State class for the home screen
///
/// Manages TrustArc SDK initialization, consent status, and UI state updates.
/// Handles all consent-related operations and user interactions.
class HomeScreenState extends State<HomeScreen> {
  // === TRUSTARC SDK CONFIGURATION ===
  /// Domain name for TrustArc consent management
  /// Retrieved from environment variables with fallback to default
  final String domain = domainName;

  // === TRUSTARC SDK INSTANCE ===
  /// TrustArc Mobile Consent SDK instance
  /// Provided via Provider pattern for dependency injection
  late FlutterTrustarcMobileConsentSdk mobileSdk;

  // === SDK STATE MANAGEMENT ===
  /// SDK initialization status
  /// Used to enable/disable UI elements and track loading states
  bool isSdkInitialized = false;
  bool isSdkLoading = false;

  /// Current consent status for all categories
  /// Map of category keys to TAConsent objects containing consent data
  Map<String, TAConsent> consentStatus = {};

  // === WIDGET LIFECYCLE ===
  /// Initialize widget state and trigger SDK initialization
  ///
  /// Uses post-frame callback to ensure widget tree is fully built
  /// before attempting SDK operations.
  @override
  void initState() {
    super.initState();
    // Initialize SDK after the widget tree is built to avoid context issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupSdkSubscription();
      _initializeSdk();
    });
  }

  // === MAIN WIDGET BUILD ===
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF2FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF1A2D3E),
              ),
              child: const Text(
                'TrustArc SDK Testing',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildConsentStatusSection(),
                    const SizedBox(height: 16),
                    _buildSdkControlsSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentStatusSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, 2),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Consent Status Dashboard',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF05668D),
            ),
          ),
          const SizedBox(height: 16),
          consentStatus.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.center,
                  child: const Text(
                    'Consents not set',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : Column(
                  children: _buildConsentCards(),
                ),
        ],
      ),
    );
  }

  List<Widget> _buildConsentCards() {
    var sortedEntries = consentStatus.entries.toList()
      ..sort((a, b) => a.value.value.compareTo(b.value.value));

    return sortedEntries.map((entry) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                entry.key,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _isConsentGranted(entry.value)
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isConsentGranted(entry.value) ? 'OPTED-IN' : 'OPTED-OUT',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _isConsentGranted(entry.value)
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildSdkControlsSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, 2),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SDK Controls',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF05668D),
            ),
          ),
          const SizedBox(height: 16),
          if (isSdkLoading)
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF05668D)),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Initializing SDK...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF05668D),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          _buildActionButton(
            text: 'Show Consent Dialog',
            onPressed: _isButtonEnabled() ? _openCM : null,
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback? onPressed,
    required bool isPrimary,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed == null
              ? const Color(0xFFF3F4F6)
              : isPrimary
                  ? const Color(0xFF1A2D3E)
                  : Colors.white,
          foregroundColor: onPressed == null
              ? const Color(0xFF6B7280)
              : isPrimary
                  ? Colors.white
                  : const Color(0xFF05668D),
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: isPrimary
                ? BorderSide.none
                : BorderSide(
                    color: onPressed == null
                        ? Colors.transparent
                        : const Color(0xFF05668D),
                  ),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: onPressed == null
                ? const Color(0xFF6B7280)
                : isPrimary
                    ? Colors.white
                    : const Color(0xFF05668D),
          ),
        ),
      ),
    );
  }

  // === UI STATE HELPERS ===
  /// Determine if consent dialog button should be enabled
  ///
  /// Button is enabled when SDK is initialized and not currently loading
  ///
  /// @returns bool true if button should be enabled
  bool _isButtonEnabled() {
    return isSdkInitialized && !isSdkLoading;
  }

  /// Check if user has granted consent for a specific category
  ///
  /// Required categories (value "0") are always considered granted.
  /// Other categories are granted if any domain has value "1".
  ///
  /// @param consent TAConsent object to check
  /// @returns bool true if consent is granted
  bool _isConsentGranted(TAConsent consent) {
    // Required category (level 0) is always opted-in
    if (consent.value == "0") {
      return true;
    }

    // Check if any domain has consent value "1" (granted)
    return consent.domains
        .any((domain) => domain.values.any((value) => value == "1"));
  }

  // === TRUSTARC SDK INITIALIZATION METHODS ===

  /// Setup TrustArc SDK event subscriptions
  ///
  /// Subscribe to SDK events for real-time consent management.
  /// Called once during widget initialization to avoid duplicate subscriptions.
  ///
  /// These event handlers provide immediate feedback when:
  /// - SDK initialization completes
  /// - User consent preferences change
  /// - Google-specific consents are updated
  void _setupSdkSubscription() {
    // Get SDK instance from Provider for dependency injection
    mobileSdk =
        Provider.of<FlutterTrustarcMobileConsentSdk>(context, listen: false);

    // Subscribe to SDK events for real-time consent management
    mobileSdk.subscribe(
      onSdkInitFinish: () {
        showToast(message: "SDK Init Finished");
        setState(() {
          isSdkInitialized = true;
          isSdkLoading = false;
        });
        _updateConsentStatus();
      },
      onConsentChanges: () {
        showToast(message: "Consents has been changed");
        _updateConsentStatus();
      },
      onGoogleConsentChanges: () {
        showToast(message: "Google Consents has been changed");
      },
    );
  }

  /// Initialize the TrustArc SDK and check if it's already initialized
  ///
  /// This method handles the complete SDK initialization flow:
  /// 1. Check if SDK is already initialized
  /// 2. If yes, update UI state and fetch consent data
  /// 3. If no, start fresh initialization process
  ///
  /// Called automatically after widget initialization.
  Future<void> _initializeSdk() async {
    try {
      final isInitialized = await mobileSdk.isSdkInitialized();
      if (isInitialized) {
        setState(() {
          isSdkInitialized = true;
        });
        _updateConsentStatus();
      } else {
        await _loadSdk();
      }
    } catch (error) {
      print('Error checking SDK initialization: $error');
    }
  }

  /// Load and start the TrustArc SDK with the configured domain
  ///
  /// This method handles the complete SDK startup process:
  /// 1. Set loading state for UI feedback
  /// 2. Initialize SDK in standard mode (vs. test mode)
  /// 3. Start SDK with domain configuration
  ///
  /// Parameters for start():
  /// - domain: TrustArc domain from configuration
  /// - IP address: empty for auto-detection
  /// - locale: empty for auto-detection
  ///
  /// Loading state is managed via onSdkInitFinish event subscription.
  Future<void> _loadSdk() async {
    try {
      setState(() {
        isSdkLoading = true;
      });
      // Initialize SDK in standard mode (production mode)
      await mobileSdk.initialize(SdkMode.standard);
      // Start SDK with domain configuration
      // Empty IP and locale strings allow SDK to auto-detect
      await mobileSdk.start(domain, "", "");
    } catch (error) {
      print('Error initializing SDK: $error');
      setState(() {
        isSdkLoading = false;
      });
    }
  }

  // === CONSENT MANAGEMENT METHODS ===

  /// Update the consent status from TrustArc SDK
  ///
  /// Fetches current consent data and updates the UI state.
  /// Called after SDK initialization and when consent changes occur.
  ///
  /// Process:
  /// 1. Fetch consent data by category from SDK
  /// 2. Parse JSON response into TAConsent objects
  /// 3. Update local state to trigger UI refresh
  Future<void> _updateConsentStatus() async {
    try {
      final consents = await mobileSdk.getConsentDataByCategory();
      final Map<String, dynamic> parsed = json.decode(consents);
      setState(() {
        consentStatus = parsed
            .map((key, value) => MapEntry(key, TAConsent.fromJson(value)));
      });
    } catch (error) {
      print('Error getting consent status: $error');
    }
  }

  /// Open TrustArc Consent Manager dialog
  ///
  /// Presents the consent preferences UI to the user.
  ///
  /// Parameters:
  /// - domain: TrustArc domain configuration
  /// - IP address: empty for auto-detection
  ///
  /// Consent changes are automatically handled via onConsentChanges event.
  Future<void> _openCM() async {
    await mobileSdk.openCM();
  }
}

// === TRUSTARC CONSENT DATA MODEL ===
/// Model class representing consent data from TrustArc SDK
///
/// Represents a single consent category with its consent level and domain-specific values.
///
/// @property value Consent category level ("0"=required, "1"=functional, "2"=advertising, etc.)
/// @property domains List of domain-specific consent values
class TAConsent {
  final String value;
  final List<Map<String, String>> domains;

  TAConsent({required this.value, required this.domains});

  /// Create TAConsent instance from JSON data
  ///
  /// Factory constructor to parse SDK JSON response into TAConsent object.
  /// Handles missing or null values gracefully with fallbacks.
  ///
  /// @param json Map containing consent data from SDK
  /// @returns TAConsent instance
  factory TAConsent.fromJson(Map<String, dynamic> json) {
    return TAConsent(
      value: json['value'] ?? 0,
      domains: (json['domains'] as List?)
              ?.map((e) => Map<String, String>.from(e))
              .toList() ??
          [],
    );
  }
}
