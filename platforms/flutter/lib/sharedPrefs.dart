/// TrustArc SDK Data Access and Preferences Inspector
///
/// This component provides a comprehensive interface for accessing and viewing
/// all data types available from the TrustArc SDK. It demonstrates the various
/// data access patterns and serves as a debugging/testing tool.
///
/// Data Types Accessible:
/// - Consent Preferences: User's consent choices by category
/// - IAB TCF String: Transparency & Consent Framework string for European compliance
/// - Google Consents: Google-specific consent mappings for AdMob, Analytics, etc.
/// - Web Script: JavaScript code for WebView integration
///
/// Features:
/// - Accordion-style expandable sections for organized data presentation
/// - Copy-to-clipboard functionality for easy data sharing
/// - Real-time data fetching from TrustArc SDK
/// - Error handling and loading states
/// - Lazy loading - data is fetched only when section is expanded
///
/// UI Design:
/// - Material Design accordion components
/// - Consistent styling with app theme
/// - Loading indicators for better user experience
/// - Error states for missing or invalid data
///
/// @author TrustArc Mobile Team
/// @version 1.0.0

// Dart core imports
import 'dart:convert';
// Flutter framework imports
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// TrustArc SDK imports
import 'package:flutter_trustarc_mobile_consent_sdk/flutter_trustarc_mobile_consent_sdk.dart';
// Local utility imports
import 'package:trustarc_mobile_app/tools.dart';
// State management imports
import 'package:provider/provider.dart';

// === SHARED PREFERENCES SCREEN WIDGET ===
/// Shared Preferences Screen Widget
///
/// Provides interface for viewing all TrustArc SDK stored preferences and data types.
/// Uses accordion-style expandable sections for organized data presentation.
class SharedPrefs extends StatefulWidget {
  const SharedPrefs({super.key});

  @override
  SharedPrefsState createState() => SharedPrefsState();
}

/// State class for Shared Preferences Screen
///
/// Manages TrustArc SDK data access, UI state, and accordion interactions.
/// Implements lazy loading pattern - data is fetched only when needed.
class SharedPrefsState extends State<SharedPrefs> {
  // === TRUSTARC SDK INSTANCE ===
  /// TrustArc Mobile Consent SDK instance
  /// Accessed via Provider pattern for dependency injection
  late FlutterTrustarcMobileConsentSdk mobileSdk;

  // === TRUSTARC DATA STATE MANAGEMENT ===
  /// Stored consent preferences data
  /// Map of consent category keys to their values ("1" = granted)
  Map<String, String>? consentData;

  /// IAB Transparency & Consent Framework string
  /// Encoded string containing detailed consent preferences for European compliance
  String? tcfString;

  /// Google-specific consent mappings
  /// Used for Google services like AdMob, Analytics, etc.
  Map<String, String>? googleConsents;

  /// TrustArc WebScript for WebView injection
  /// JavaScript code that applies mobile consent preferences to web content
  String? webScript;

  // === UI STATE MANAGEMENT ===
  /// Currently expanded accordion section
  /// Only one section can be expanded at a time
  String? expandedSection;

  /// Section currently loading data
  /// Used to show loading indicators
  String? loadingSection;

  // === WIDGET LIFECYCLE ===
  /// Initialize widget state
  ///
  /// Uses lazy loading pattern - data is not fetched initially.
  /// Data fetching is triggered when user expands accordion sections.
  @override
  void initState() {
    super.initState();
    // Don't fetch data initially, wait for user interaction
  }

  // === ACCORDION UI MANAGEMENT ===

  /// Toggle accordion section and fetch data when expanding
  ///
  /// This method implements the accordion behavior:
  /// - If section is already expanded, collapse it
  /// - If section is collapsed, expand it and fetch data
  ///
  /// @param section Section identifier to toggle
  void toggleAccordion(String section) {
    if (expandedSection == section) {
      setState(() {
        expandedSection = null; // Collapse current section
      });
    } else {
      setState(() {
        expandedSection = section; // Expand new section
      });
      _fetchData(section); // Fetch data for expanded section
    }
  }

  // === TRUSTARC DATA FETCHING METHODS ===

  /// Fetch data for the specified section from TrustArc SDK
  ///
  /// This method coordinates data fetching for different TrustArc data types.
  /// Sets loading state during fetch and clears it regardless of success/failure.
  ///
  /// @param section Section identifier ('ConsentPreferences', 'IABTCFString', 'GoogleConsents', 'WebScript')
  Future<void> _fetchData(String section) async {
    setState(() {
      loadingSection = section;
    });

    try {
      switch (section) {
        case 'ConsentPreferences':
          await _fetchConsentPreferences();
          break;
        case 'IABTCFString':
          await _fetchTCFString();
          break;
        case 'GoogleConsents':
          await _fetchGoogleConsents();
          break;
        case 'WebScript':
          await _fetchWebScript();
          break;
      }
    } finally {
      setState(() {
        loadingSection = null;
      });
    }
  }

  /// Fetch consent preferences from TrustArc SDK
  ///
  /// Retrieves stored consent data showing user's category-level preferences.
  /// Data format: Map<String, String> where keys are category names and values are consent levels.
  ///
  /// Error handling: Sets consentData to null if fetch fails.
  Future<void> _fetchConsentPreferences() async {
    try {
      final consentDataStr = await mobileSdk.getStoredConsentData();
      final consentMap = json.decode(consentDataStr) as Map<String, dynamic>;

      setState(() {
        consentData =
            consentMap.map((key, value) => MapEntry(key, value.toString()));
      });
    } catch (e) {
      setState(() {
        consentData = null;
      });
    }
  }

  /// Fetch IAB TCF (Transparency & Consent Framework) string
  ///
  /// Retrieves the encoded TCF string containing detailed consent preferences
  /// for European GDPR compliance. This string is used by advertising partners
  /// to understand user consent choices.
  ///
  /// Error handling: Sets tcfString to null if fetch fails or string is empty.
  Future<void> _fetchTCFString() async {
    try {
      final iabPrefs = await mobileSdk.getIABTCFPreferences();
      setState(() {
        tcfString = iabPrefs.IABTCF_TCString.isNotEmpty
            ? iabPrefs.IABTCF_TCString
            : null;
      });
    } catch (e) {
      setState(() {
        tcfString = null;
      });
    }
  }

  /// Fetch Google consent preferences
  ///
  /// Retrieves Google-specific consent mappings used for Google services
  /// like AdMob, Analytics, etc. These mappings translate TrustArc consent
  /// categories to Google's consent framework.
  ///
  /// Error handling: Sets googleConsents to null if fetch fails.
  Future<void> _fetchGoogleConsents() async {
    try {
      final googleConsentsStr = await mobileSdk.getGoogleConsents();
      final googleConsentsMap =
          json.decode(googleConsentsStr) as Map<String, dynamic>;

      setState(() {
        googleConsents = googleConsentsMap
            .map((key, value) => MapEntry(key, value.toString()));
      });
    } catch (e) {
      setState(() {
        googleConsents = null;
      });
    }
  }

  /// Fetch TrustArc WebScript for injection
  ///
  /// Retrieves JavaScript code that applies mobile consent preferences
  /// to web content in WebView. This script ensures web consent UI
  /// reflects mobile app consent choices.
  ///
  /// Used in: WebView integration (consentWebTestPage.dart)
  /// Error handling: Sets webScript to null if fetch fails or script is empty.
  Future<void> _fetchWebScript() async {
    try {
      final webScriptStr = await mobileSdk.getWebScript();
      setState(() {
        webScript = webScriptStr.isNotEmpty ? webScriptStr : null;
      });
    } catch (e) {
      setState(() {
        webScript = null;
      });
    }
  }

  // === MAIN WIDGET BUILD ===
  @override
  Widget build(BuildContext context) {
    // === TRUSTARC SDK PROVIDER ACCESS ===
    // Get SDK instance from Provider for dependency injection
    mobileSdk =
        Provider.of<FlutterTrustarcMobileConsentSdk>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // === SCREEN HEADER ===
            /**
             * Application header with consistent styling
             * Matches the design theme used throughout the app
             */
            Container(
              width: double.infinity,
              color: const Color(0xFF1A2D3A),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: const Text(
                'Preferences',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // === TRUSTARC DATA SECTIONS ===
                    /**
                     * Accordion sections for different TrustArc data types
                     * Each section fetches data lazily when expanded
                     */

                    // === CONSENT PREFERENCES ACCORDION ===
                    // Basic consent data showing user's category-level preferences
                    _buildAccordion(
                      title: 'Consent Preferences',
                      sectionKey: 'ConsentPreferences',
                      content: _buildConsentPreferencesContent(),
                      onCopy: () => _copyToClipboard(
                          json.encode(consentData ?? {}),
                          'Consent Preferences Copied'),
                    ),

                    const SizedBox(height: 10),

                    // === IAB TCF STRING ACCORDION ===
                    // Transparency & Consent Framework encoded string for European compliance
                    _buildAccordion(
                      title: 'IAB TCF String',
                      sectionKey: 'IABTCFString',
                      content: _buildTCFStringContent(),
                      onCopy: () => _copyToClipboard(
                          tcfString ?? '', 'TCF String Copied'),
                    ),

                    const SizedBox(height: 10),

                    // === GOOGLE CONSENTS ACCORDION ===
                    // Google-specific consent mappings for AdMob, Analytics, etc.
                    _buildAccordion(
                      title: 'Google Consents',
                      sectionKey: 'GoogleConsents',
                      content: _buildGoogleConsentsContent(),
                      onCopy: () => _copyToClipboard(
                          json.encode(googleConsents ?? {}),
                          'Google Consents Copied'),
                    ),

                    const SizedBox(height: 10),

                    // === CONSENT WEB SCRIPT ACCORDION ===
                    // JavaScript code for WebView integration (used in WebTest tab)
                    _buildAccordion(
                      title: 'Consent Web Script',
                      sectionKey: 'WebScript',
                      content: _buildWebScriptContent(),
                      onCopy: () => _copyToClipboard(
                          webScript ?? '', 'Web Script Copied'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === ACCORDION UI COMPONENT ===
  /// Build reusable accordion component for data sections
  ///
  /// Creates expandable/collapsible sections with:
  /// - Header with title and chevron icon
  /// - Loading indicator during data fetch
  /// - Copy-to-clipboard button when data is available
  /// - Scrollable content area for large data
  ///
  /// @param title Display title for the accordion section
  /// @param sectionKey Unique identifier for the section
  /// @param content Widget containing the section content
  /// @param onCopy Callback for copy-to-clipboard functionality
  /// @returns Widget Accordion component
  Widget _buildAccordion({
    required String title,
    required String sectionKey,
    required Widget content,
    required VoidCallback onCopy,
  }) {
    final bool isExpanded = expandedSection == sectionKey;
    final bool isLoadingSection = loadingSection == sectionKey;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDEDEDE), width: 1),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => toggleAccordion(sectionKey),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFF007AFF), // iOS blue
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFDEDEDE)),
            Padding(
              padding: const EdgeInsets.all(10),
              child: isLoadingSection
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                      ),
                    )
                  : Column(
                      children: [
                        // Copy button (only show if there's data)
                        if (_hasData(sectionKey))
                          InkWell(
                            onTap: onCopy,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF007AFF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Click here to copy the contents',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),

                        // Content
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 300),
                          child: SingleChildScrollView(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: content,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }

  // === DATA AVAILABILITY CHECKER ===
  /// Check if data is available for a section
  ///
  /// Used to determine whether to show the copy-to-clipboard button.
  /// Returns true only if data exists and is not empty.
  ///
  /// @param sectionKey Section identifier to check
  /// @returns bool True if section has data available
  bool _hasData(String sectionKey) {
    switch (sectionKey) {
      case 'ConsentPreferences':
        return consentData != null && consentData!.isNotEmpty;
      case 'IABTCFString':
        return tcfString != null && tcfString!.isNotEmpty;
      case 'GoogleConsents':
        return googleConsents != null && googleConsents!.isNotEmpty;
      case 'WebScript':
        return webScript != null && webScript!.isNotEmpty;
      default:
        return false;
    }
  }

  // === CONTENT BUILDERS ===
  /// Build content for Consent Preferences section
  ///
  /// Displays user's consent choices by category in key-value format.
  /// Shows "(No Data)" if no consent data is available.
  ///
  /// @returns Widget Content for consent preferences accordion
  Widget _buildConsentPreferencesContent() {
    if (consentData == null || consentData!.isEmpty) {
      return const Text(
        '(No Data)',
        style: TextStyle(fontSize: 14, color: Color(0xFF555555)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: consentData!.entries
          .map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${entry.key}: ${entry.value}',
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFF555555)),
                ),
              ))
          .toList(),
    );
  }

  /// Build content for IAB TCF String section
  ///
  /// Displays the encoded TCF string or "(No Data)" if unavailable.
  /// The TCF string contains detailed consent preferences for European compliance.
  ///
  /// @returns Widget Content for TCF string accordion
  Widget _buildTCFStringContent() {
    return Text(
      tcfString ?? '(No Data)',
      style: const TextStyle(fontSize: 14, color: Color(0xFF555555)),
    );
  }

  /// Build content for Google Consents section
  ///
  /// Displays Google-specific consent mappings in key-value format.
  /// Shows "(No Data)" if no Google consent data is available.
  ///
  /// @returns Widget Content for Google consents accordion
  Widget _buildGoogleConsentsContent() {
    if (googleConsents == null || googleConsents!.isEmpty) {
      return const Text(
        '(No Data)',
        style: TextStyle(fontSize: 14, color: Color(0xFF555555)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: googleConsents!.entries
          .map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${entry.key}: ${entry.value}',
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFF555555)),
                ),
              ))
          .toList(),
    );
  }

  /// Build content for Web Script section
  ///
  /// Displays the TrustArc WebScript JavaScript code or "(No Data)" if unavailable.
  /// This script is used for WebView integration to apply mobile consent to web content.
  ///
  /// @returns Widget Content for web script accordion
  Widget _buildWebScriptContent() {
    return Text(
      webScript ?? '(No Data)',
      style: const TextStyle(fontSize: 14, color: Color(0xFF555555)),
    );
  }

  // === UTILITY METHODS ===
  /// Copy data to device clipboard with user feedback
  ///
  /// Copies the provided data to the device clipboard and shows
  /// a toast notification to confirm the action.
  ///
  /// @param data String data to copy to clipboard
  /// @param message Success message to display in toast
  void _copyToClipboard(String data, String message) {
    Clipboard.setData(ClipboardData(text: data));
    showToast(message: message);
  }
}
