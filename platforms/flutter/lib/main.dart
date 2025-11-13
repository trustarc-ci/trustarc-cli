/// TrustArc Flutter Mobile Consent App - Main Entry Point
///
/// This is the main application entry point for the TrustArc Flutter Mobile Consent demonstration app.
/// It sets up the core application structure including:
///
/// - Environment variable configuration and domain management
/// - TrustArc SDK Provider setup for dependency injection
/// - Tab-based navigation structure
/// - Material Design theming and styling
/// - Route configuration for child activities
///
/// App Structure:
/// - Home: Main consent management interface
/// - Web Test: WebView integration and script injection testing
/// - Preferences: SDK data access and inspection
///
/// @author TrustArc Mobile Team
/// @version 1.0.0

// Flutter framework imports
import 'package:flutter/material.dart';
// TrustArc SDK imports
import 'package:flutter_trustarc_mobile_consent_sdk/flutter_trustarc_mobile_consent_sdk.dart';
// App screen imports
import 'package:trustarc_mobile_app/childActivity.dart';
import 'package:trustarc_mobile_app/consentWebTestPage.dart';
import 'package:trustarc_mobile_app/home.dart';
import 'package:trustarc_mobile_app/sharedPrefs.dart';
// State management and configuration imports
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// === APP CONFIGURATION ===
/// Default domain name for TrustArc SDK initialization
/// This serves as a fallback if the .env file is not available or MAC_DOMAIN is not set
const String kDefaultDomainName = "app.mattel.speedway";

// === ENVIRONMENT VARIABLE GETTERS ===
/// Get TrustArc domain name from environment variables or fallback to default
///
/// This follows the configuration pattern established in the project:
/// 1. Try to load from .env file (MAC_DOMAIN)
/// 2. Fall back to default domain if not available
///
/// @returns String domain name for TrustArc SDK initialization
String get domainName {
  try {
    return dotenv.env['MAC_DOMAIN'] ?? kDefaultDomainName;
  } catch (e) {
    // If dotenv is not initialized yet, return default
    return kDefaultDomainName;
  }
}

// === MAIN APP ENTRY POINT ===
/// Main application entry point
///
/// Handles environment variable loading and app initialization.
/// The app will function with default values even if .env file is missing.
Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // === ENVIRONMENT VARIABLES LOADING ===
  // Load environment variables from .env file for configuration
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // .env file not found, app will use default values - this is okay
    print('Warning: .env file not found, using default configuration');
  }

  // Start the Flutter application
  runApp(MyApp());
}

/// Root Application Widget
///
/// Sets up the core application structure including:
/// - TrustArc SDK Provider for dependency injection
/// - Material Design theme configuration
/// - Navigation structure and routing
class MyApp extends StatelessWidget {
  // === TRUSTARC SDK INSTANCE ===
  /// TrustArc Mobile Consent SDK instance
  /// This single instance is provided throughout the app via Provider
  final mobileSdk = FlutterTrustarcMobileConsentSdk();

  MyApp({super.key});

  // === APP WIDGET BUILD ===
  @override
  Widget build(BuildContext context) {
    // === PROVIDER SETUP ===
    // Provide TrustArc SDK instance throughout the app for dependency injection
    return MultiProvider(
      providers: [
        Provider<FlutterTrustarcMobileConsentSdk>.value(value: mobileSdk),
      ],
      // === MATERIAL APP CONFIGURATION ===
      child: MaterialApp(
        title: 'TrustArc Mobile App',
        // === THEME CONFIGURATION ===
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor:
              const Color(0xFFEBF2FA), // Light blue background
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1A2D3E), // Dark blue app bars
            foregroundColor: Colors.white,
            elevation: 0,
          ),
        ),
        home: const MainTabScreen(),
        // === APP ROUTES ===
        // Define named routes for navigation
        routes: {
          "/childActivity": (context) => const ChildActivity(),
        },
      ),
    );
  }
}

// === MAIN TAB NAVIGATION SCREEN ===
/// Main tab navigation screen widget
///
/// Provides bottom tab navigation between:
/// 1. Home - Main consent management interface
/// 2. Web Test - WebView integration testing
/// 3. Preferences - SDK data access and inspection
class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

/// State class for main tab navigation
///
/// Manages tab selection and screen rendering
class _MainTabScreenState extends State<MainTabScreen> {
  // === TAB NAVIGATION STATE ===
  // Currently selected tab index
  int _currentIndex = 0;

  // === SCREEN CONFIGURATION ===
  /// Available screens in the tab navigation
  /// Index corresponds to tab position in bottom navigation bar
  final List<Widget> _screens = [
    const HomeScreen(), // 0: Main consent management
    const WebTestScreen(), // 1: WebView integration testing
    const SharedPrefs(), // 2: SDK data access and inspection
  ];

  // === MAIN WIDGET BUILD ===
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Display current screen based on selected tab
      body: _screens[_currentIndex],
      // === BOTTOM NAVIGATION BAR ===
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        // Navigation bar styling
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF1A2D3E), // Dark blue for selected
        unselectedItemColor: Colors.grey,
        // === TAB DEFINITIONS ===
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home', // Main consent management interface
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.language),
            label: 'Web Test', // WebView integration testing
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Preferences', // SDK data access and inspection
          ),
        ],
      ),
    );
  }
}
