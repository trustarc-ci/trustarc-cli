/**
 * TrustArc iOS Mobile Consent App - Main Content View
 * 
 * This iOS application demonstrates the integration and usage of the TrustArc Consent SDK
 * for SwiftUI applications. It provides a comprehensive testing interface for consent
 * management, status tracking, and SDK initialization workflows.
 * 
 * Key Features:
 * - Real-time consent status dashboard with visual indicators
 * - SDK initialization and consent dialog management
 * - Automated consent data processing and categorization
 * - SwiftUI-based responsive interface design
 * 
 * Architecture:
 * - Uses SwiftUI with MVVM pattern via ObservableObject
 * - Implements TrustArc SDK delegate protocols for event handling
 * - Provides reactive UI updates through @Published properties
 * 
 * Dependencies:
 * - TrustArc Consent SDK for consent management
 * - WebKit for consent dialog display
 * - App Tracking Transparency for iOS privacy compliance
 */

// Standard iOS frameworks
import SwiftUI                    // SwiftUI framework for declarative UI
import WebKit                     // WebKit for consent dialog display
import AdSupport                  // AdSupport framework for advertising identifier
import os.log                     // Logging framework for debugging

// Privacy frameworks
import AppTrackingTransparency    // iOS App Tracking Transparency integration

// Third-party SDK
import trustarc_consent_sdk       // TrustArc Consent Management SDK

// ===== CONSENT DATA MODELS =====

/**
 * Represents the three possible states of user consent for a category
 */
enum ConsentStatus {
    case granted     // User has opted in to this category
    case denied      // User has opted out of this category
    case undefined   // Consent state is not yet determined
}

/**
 * Data model representing a consent category and its current status
 * Used to display individual consent cards in the dashboard
 */
struct ConsentCard {
    let categoryKey: String    // Display name for the consent category
    let status: ConsentStatus  // Current consent state (granted/denied/undefined)
}

// ===== MAIN UI COMPONENTS =====

/**
 * Main content view that displays the TrustArc SDK testing interface
 * 
 * This view is structured into several key sections:
 * 1. Header - App title and branding
 * 2. Consent Status Dashboard - Real-time display of consent categories and their states
 * 3. SDK Controls - Buttons to interact with the TrustArc SDK
 * 
 * The view uses reactive data binding with the ContentViewController to automatically
 * update the UI when consent status changes occur.
 */
struct ContentView: View {
    @StateObject private var contentViewController = ContentViewController()
    
    var body: some View {
        VStack(spacing: 0) {
            // ===== APP HEADER =====
            VStack {
                Text(AppConfig.shared.appDisplayName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.vertical, 16)
            }
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.systemIndigo)) // Primary brand color - adapts to dark mode
            
            ScrollView {
                VStack(spacing: 16) {
                    // ===== CONSENT STATUS DASHBOARD =====
                    /**
                     * This section displays the current consent status for all categories.
                     * When no consent data is available, it shows a placeholder message.
                     * Otherwise, it dynamically generates cards for each consent category.
                     */
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Consent Status Dashboard")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(UIColor.systemBlue)) // Primary color - adapts to dark mode
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if contentViewController.consentCards.isEmpty {
                            // Empty state - no consent data available
                            Text("Consents not set")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(UIColor.secondaryLabel)) // Secondary text - adapts to dark mode
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        } else {
                            // Active state - display consent category cards
                            LazyVStack(spacing: 8) {
                                ForEach(contentViewController.consentCards, id: \.categoryKey) { card in
                                    ConsentStatusCard(
                                        categoryName: card.categoryKey,
                                        status: card.status
                                    )
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground)) // Adapts to dark mode
                    .cornerRadius(8)
                    
                    // ===== SDK CONTROLS =====
                    /**
                     * This section provides interactive controls for the TrustArc SDK.
                     * The "Show Consent Dialog" button is only enabled after successful SDK initialization.
                     */
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SDK Controls")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(UIColor.systemBlue)) // Primary color - adapts to dark mode
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Primary action button to launch the consent management dialog
                        Button("Show Consent Dialog") {
                            contentViewController.openCmAction()
                        }
                        .disabled(!contentViewController.isButtonEnabled)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(contentViewController.isButtonEnabled ? Color(UIColor.systemIndigo) : Color(UIColor.systemGray))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .font(.system(size: 16, weight: .medium))
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground)) // Adapts to dark mode
                    .cornerRadius(8)
                }
                .padding(16)
            }
        }
        .background(Color(UIColor.systemGroupedBackground)) // Adapts to dark mode
        .onAppear {
            // Initialize the TrustArc SDK when the view first appears
            contentViewController.loadTrustArcSdk()
        }
    }
}

// ===== CONSENT STATUS CARD COMPONENT =====

/**
 * Individual card component that displays a consent category and its current status
 * 
 * Features:
 * - Category name display on the left
 * - Status text and colored indicator on the right
 * - Color-coded visual feedback (green=granted, red=denied, gray=undefined)
 * - Consistent styling with border and background
 */
struct ConsentStatusCard: View {
    let categoryName: String  // Display name for the consent category
    let status: ConsentStatus // Current consent state
    
    var body: some View {
        HStack {
            // Category name display
            Text(categoryName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(UIColor.label)) // Primary text - adapts to dark mode
            
            Spacer()
            
            // Status indicator section
            HStack(spacing: 8) {
                Text(statusText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(statusColor)
                
                // Visual status indicator circle
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(16)
        .background(Color(UIColor.tertiarySystemBackground)) // Card background - adapts to dark mode
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(UIColor.separator), lineWidth: 1) // Border - adapts to dark mode
        )
        .cornerRadius(8)
    }
    
    /**
     * Returns the appropriate color for the current consent status
     * - Green for granted consent
     * - Red for denied consent  
     * - Gray for undefined consent
     */
    private var statusColor: Color {
        switch status {
        case .granted:
            return Color(red: 0.13, green: 0.77, blue: 0.37) // Success green
        case .denied:
            return Color(red: 0.94, green: 0.27, blue: 0.27) // Error red
        case .undefined:
            return Color(red: 0.61, green: 0.64, blue: 0.69) // Neutral gray
        }
    }
    
    /**
     * Returns the appropriate text label for the current consent status
     */
    private var statusText: String {
        switch status {
        case .granted:
            return "OPTED-IN"
        case .denied:
            return "OPTED-OUT"
        case .undefined:
            return "UNDEFINED"
        }
    }
}

// ===== SDK CARD COMPONENT =====

/**
 * Reusable card component for SDK testing actions (currently unused in main interface)
 * This component could be used for additional SDK testing features in the future
 */
struct SDKCard: View {
    let title: String           // Card title/label
    let iconColor: Color        // Color for the indicator icon
    let testAction: () -> Void  // Action to execute when test button is pressed
    
    var body: some View {
        HStack {
            // Colored status indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(iconColor)
                .frame(width: 20, height: 20)
            
            // Card title
            Text(title)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.black)
            
            Spacer()
            
            // Action button
            Button("TEST") {
                testAction()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color(red: 0.7, green: 0.7, blue: 0.7))
            .foregroundColor(.black)
            .cornerRadius(20)
            .font(.system(size: 14, weight: .medium))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
        )
    }
}

// ===== CONTENT VIEW CONTROLLER =====

/**
 * Main controller class that manages the TrustArc SDK integration and UI state
 * 
 * This ObservableObject serves as the MVVM view model for the ContentView and handles:
 * - TrustArc SDK initialization and configuration
 * - Consent data processing and UI state management
 * - Delegate protocol implementations for SDK callbacks
 * - UI reactive property management through @Published properties
 * 
 * Key Responsibilities:
 * 1. SDK Lifecycle Management - Initialize and configure the TrustArc SDK
 * 2. Consent Data Processing - Parse and transform consent data for UI display
 * 3. UI State Management - Track button states, loading states, and data availability
 * 4. Event Handling - Respond to SDK callbacks and user interactions
 */
class ContentViewController: ObservableObject, @unchecked Sendable{
    
    // ===== UI STATE PROPERTIES =====
    
    @Published var isButtonEnabled = false        // Controls consent dialog button availability
    @Published var attStatusString = "Not Determined"  // App tracking transparency status
    @Published var sdkStatus = "Not Initialized"      // Current SDK initialization state
    @Published var consentStatus = "No Consents"      // Summary of consent data availability
    @Published var consentCards: [ConsentCard] = []   // Processed consent cards for UI display
    
    // ===== ALERT AND DIALOG STATE =====
    
    @Published var showDeepLinkAlert = false      // Controls deep link alert visibility
    @Published var deepLinkMessage = ""          // Message content for deep link alerts
    @Published var showAdvertisingIdAlert = false // Controls advertising ID alert visibility
    @Published var advertisingIdMessage = ""      // Message content for advertising ID alerts
    
    // ===== PRIVATE PROPERTIES =====
    
    private var currentAdvertisingId: String = "" // Cached advertising ID for clipboard operations
    
    /**
     * Initialize the controller with default state
     * Consent dialog button starts disabled until SDK initialization completes
     */
    init() {
        isButtonEnabled = false
    }
    
    // ===== UTILITY METHODS =====
    
    /**
     * Helper method to retrieve the root view controller for presenting modal dialogs
     * This is required for the TrustArc SDK to display the consent management interface
     * 
     * @returns The root UIViewController if available, nil otherwise
     */
    @MainActor private func getRootView() -> UIViewController? {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            return rootViewController
        }
        
        return nil
    }
    
    // ===== SDK LIFECYCLE METHODS =====
    
    /**
     * Initialize and start the TrustArc SDK with proper configuration
     * 
     * This method performs the complete SDK initialization sequence:
     * 1. Disable UI controls until initialization completes
     * 2. Register delegate handlers for SDK events
     * 3. Configure SDK with domain and settings
     * 4. Start the SDK and handle the initialization callback
     * 
     * The domain is configured in AppConfig.swift for easy environment management.
     * Update AppConfig.shared.domainName for different environments.
     */
    func loadTrustArcSdk() {
        Task { @MainActor in
            // Do not run init when already initialized
            if TrustArc.sharedInstance.isInitialized {
                return
            }
            
            // Disable consent dialog button during initialization
            self.isButtonEnabled = false
            
            // Register delegates to handle SDK callbacks and UI events
            _ = TrustArc.sharedInstance.addSdkInitializationDelegate(self)
            _ = TrustArc.sharedInstance.addConsentViewControllerDelegate(self)
            
            // Configure TrustArc SDK with settings from AppConfig
            _ = TrustArc.sharedInstance.setDomain(AppConfig.shared.macDomain)
            _ = TrustArc.sharedInstance.setMode(AppConfig.shared.sdkMode) // Using AppConfig.shared.sdkMode would require enum mapping
            _ = TrustArc.sharedInstance.enableAppTrackingTransparencyPrompt(AppConfig.shared.enableAppTrackingTransparency)
            
            _ = TrustArc.sharedInstance.enableDebugLogs(AppConfig.shared.enableDebugMode)
            
            // Start the SDK with completion callback
            TrustArc.sharedInstance.start { shouldShowConsentUI in
                Task { @MainActor in
                    // Re-enable UI controls after successful initialization
                    self.isButtonEnabled = true
                    
                    // Auto-show consent dialog if required and enabled in config
                    if shouldShowConsentUI {
                        self.openCmAction()
                    }
                }
            }
        }
    }

    /**
     * Open the TrustArc consent management dialog
     * 
     * This method displays the consent management interface to the user, allowing them
     * to review and modify their consent preferences. The dialog is presented modally
     * over the current view controller.
     * 
     * The method requires a valid root view controller to present the dialog.
     * Delegate callbacks will be triggered when the user completes their consent choices.
     */
    @MainActor
    func openCmAction() {
        if let rootView = self.getRootView() {
            TrustArc.sharedInstance.openCM(in: rootView, delegate: self)
        }
    }
    
    // ===== CONSENT DATA PROCESSING =====
    
    /**
     * Process and update consent data for UI display
     * 
     * This method transforms the raw TrustArc consent data into UI-friendly ConsentCard objects.
     * It groups consent categories by their value (consent level) and determines the overall
     * status for each group to display in the dashboard.
     * 
     * Processing Logic:
     * 1. Group consents by their value (0=required, 1=functional, 2=advertising, etc.)
     * 2. Determine overall status for each group (granted/denied/undefined)
     * 3. Create display-friendly category names
     * 4. Update the UI with the processed consent cards
     * 
     * @param consents Dictionary of consent data from TrustArc SDK
     */
    private func updateConsentCards(consents: [String: TAConsent]) {
        // Group consent categories by their value (consent level)
        var consentsByValue: [String: [String: TAConsent]] = [:]
        
        for (categoryKey, categoryValue) in consents {
            let value = categoryValue.value
            if consentsByValue[value] == nil {
                consentsByValue[value] = [:]
            }
            consentsByValue[value]![categoryKey] = categoryValue
        }
        
        var newCards: [ConsentCard] = []
        
        // Create consent cards organized by category value
        for (value, categoriesForValue) in consentsByValue.sorted(by: { $0.key < $1.key }) {
            // Determine overall consent status for this category value group
            let hasAnyGranted = categoriesForValue.values.contains { consent in
                determineConsentStatus(consent) == .granted
            }
            let hasAnyDenied = categoriesForValue.values.contains { consent in
                determineConsentStatus(consent) == .denied
            }
            
            // Calculate overall status based on individual consent states
            let overallStatus: ConsentStatus
            if value == "0" {
                // Required categories (value "0") are always considered granted
                overallStatus = .granted
            } else if hasAnyGranted && !hasAnyDenied {
                overallStatus = .granted
            } else if hasAnyDenied && !hasAnyGranted {
                overallStatus = .denied
            } else if hasAnyGranted && hasAnyDenied {
                overallStatus = .granted // Mixed state - show as granted if any are granted
            } else {
                overallStatus = .undefined
            }
            
            // Generate user-friendly category name for display
            let categoryName = getCategoryNameForValue(value, categoriesForValue: categoriesForValue)
            let card = ConsentCard(categoryKey: categoryName, status: overallStatus)
            newCards.append(card)
        }
        
        // Update UI on main thread
        Task { @MainActor in
            self.consentCards = newCards
            if !newCards.isEmpty {
                self.consentStatus = "Has \(newCards.count) consent categories"
            }
        }
    }
    
    /**
     * Generate a user-friendly display name for a consent category group
     * 
     * This method creates readable category names for the UI based on the consent data.
     * When multiple categories share the same value (consent level), it intelligently
     * combines their names or provides a summary for better UX.
     * 
     * @param value The consent level/value (e.g., "0", "1", "2")
     * @param categoriesForValue Dictionary of categories that share this value
     * @returns A formatted display name for the category group
     */
    private func getCategoryNameForValue(_ value: String, categoriesForValue: [String: TAConsent]) -> String {
        // Single category - use its key directly as the display name
        if categoriesForValue.count == 1 {
            return categoriesForValue.keys.first!
        }
        
        // Multiple categories - combine their names intelligently
        let categoryKeys = Array(categoriesForValue.keys).sorted()
        
        // For better UX, limit displayed names and show summary for large groups
        if categoryKeys.count > 3 {
            return "\(categoryKeys.prefix(2).joined(separator: ", ")) +\(categoryKeys.count - 2) more"
        } else {
            return categoryKeys.joined(separator: ", ")
        }
    }
    
    /**
     * Determine the consent status for an individual TrustArc consent object
     * 
     * This method analyzes a TAConsent object to determine whether the user has
     * granted, denied, or left undefined their consent for that category.
     * 
     * Logic:
     * - Value "0" categories are required and always considered granted
     * - Other categories check domain values for "1" (granted) vs absence (denied)
     * 
     * @param taConsent The TrustArc consent object to analyze
     * @returns ConsentStatus indicating the current state
     */
    private func determineConsentStatus(_ taConsent: TAConsent) -> ConsentStatus {
        // Required categories (value "0") are always granted by definition
        if taConsent.value == "0" {
            return .granted
        }
        
        // Check domain values to determine consent state
        let hasConsent = if taConsent.domains == nil || taConsent.domains!.isEmpty {
            false
        } else {
            // Look for "1" value in any domain, indicating user granted consent
            taConsent.domains!.contains { domain in
                domain.values.contains("1")
            }
        }
        
        return hasConsent ? .granted : .denied
    }
    
    /**
     * Update visual styling based on consent state (legacy method)
     * 
     * This method processes consent data to determine functional and advertising consent states.
     * Originally used for card color updates, it now primarily serves as a diagnostic tool
     * to log consent state changes.
     * 
     * Category Levels:
     * - Level 0: Required (always granted)
     * - Level 1: Functional consent
     * - Level 2: Advertising/marketing consent
     * 
     * @param consents Dictionary of consent data from TrustArc SDK
     */
    private func updateCardColorsBasedOnConsent(consents: [String: TAConsent]) {
        // Analyze consent categories to determine specific consent types
        var hasFunctionalConsent = false
        var hasAdvertisingConsent = false
        
        for (_, consent) in consents {
            let level = Int(consent.value) ?? 0
            let hasConsent = consent.domains?.contains { domain in
                domain.values.contains("1")
            } ?? false
            
            // Categorize consent based on level
            switch level {
            case 1:
                hasFunctionalConsent = hasConsent
            case 2:
                hasAdvertisingConsent = hasConsent
            default:
                break // Required categories or other levels
            }
        }
        
        // Log consent state for debugging and monitoring
        print("Consent state updated - Functional: \(hasFunctionalConsent), Advertising: \(hasAdvertisingConsent)")
    }
    
}

// ===== TRUSTARC SDK DELEGATE IMPLEMENTATIONS =====

/**
 * TAConsentViewControllerDelegate implementation
 * 
 * This extension handles callbacks from the TrustArc consent management dialog.
 * It manages the lifecycle of the consent dialog and processes user consent choices.
 */
@MainActor
extension ContentViewController: TAConsentViewControllerDelegate {
    
    /**
     * Called when the consent dialog WebView starts loading
     * This can be used to show loading indicators or prepare the UI
     */
    func consentViewController(_ consentViewController: trustarc_consent_sdk.TAConsentViewController, isLoadingWebView webView: WKWebView) {
        print("Consent dialog WebView is loading")
    }
    
    /**
     * Called when the consent dialog WebView finishes loading
     * This indicates the dialog is ready for user interaction
     */
    func consentViewController(_ consentViewController: trustarc_consent_sdk.TAConsentViewController, didFinishLoadingWebView webView: WKWebView) {
        print("Consent dialog WebView finished loading")
    }
    
    /**
     * Called when the user completes their consent choices and closes the dialog
     * 
     * This is the primary callback for processing user consent decisions.
     * The method:
     * 1. Dismisses the consent dialog
     * 2. Retrieves the updated consent data from the SDK
     * 3. Updates the UI with the new consent status
     * 
     * @param consentViewController The consent dialog view controller
     * @param consentData Raw consent data from the dialog (for debugging)
     */
    func consentViewController(_ consentViewController: trustarc_consent_sdk.TAConsentViewController, didReceiveConsentData consentData: [String : Any]) {
        print("Received consent data: \(consentData)")
        
        // Dismiss the consent dialog with animation
        consentViewController.dismiss(animated: true) {
            // Retrieve structured consent data from SDK
            let consentDataByCategory = TrustArc.sharedInstance.getConsentDataByCategory()
            print("Consent data by category: \(consentDataByCategory)")
            
            if !consentDataByCategory.isEmpty {
                // Process and display consent data
                self.updateConsentCards(consents: consentDataByCategory)
                self.updateCardColorsBasedOnConsent(consents: consentDataByCategory)
            } else {
                print("No consent data available or invalid format")
                // Clear consent display if no data is available
                Task { @MainActor in
                    self.consentCards.removeAll()
                    self.consentStatus = "No Consents"
                }
            }
        }
    }
}

/**
 * TAConsentReporterDelegate implementation
 * 
 * This extension handles callbacks related to consent data reporting to TrustArc servers.
 * These callbacks provide visibility into the data transmission process for monitoring
 * and debugging purposes.
 */
@MainActor
extension ContentViewController: TAConsentReporterDelegate {
    
    /**
     * Called when the SDK is about to send consent data to TrustArc servers
     * This can be used for logging or showing upload progress indicators
     */
    func consentReporterWillSend(report: trustarc_consent_sdk.TAConsentReportInfo) {
        print("Consent report will be sent to TrustArc servers")
    }
    
    /**
     * Called when consent data has been successfully sent to TrustArc servers
     * This confirms the consent preferences have been recorded remotely
     */
    func consentReporterDidSend(report: trustarc_consent_sdk.TAConsentReportInfo) {
        print("Consent report successfully sent to TrustArc servers")
    }
    
    /**
     * Called when sending consent data to TrustArc servers fails
     * This could indicate network issues or server problems
     */
    func consentReporterDidFailSending(report: trustarc_consent_sdk.TAConsentReportInfo) {
        print("Failed to send consent report to TrustArc servers")
    }
}

/**
 * TADelegate implementation
 * 
 * This extension handles SDK initialization lifecycle callbacks.
 * These callbacks allow the app to respond to SDK state changes and update the UI accordingly.
 */
@MainActor
extension ContentViewController: TADelegate {
    
    /**
     * Called when the SDK is in an uninitialized state
     * This typically occurs before initialization or after reset
     */
    func sdkIsNotInitialized() {
        sdkStatus = "Not Initialized"
    }
    
    /**
     * Called when the SDK initialization process is in progress
     * This can be used to show loading indicators
     */
    func sdkIsInitializing() {
        sdkStatus = "Initializing"
    }
    
    /**
     * Called when the SDK has completed initialization successfully
     * 
     * This is the primary callback for post-initialization setup:
     * 1. Updates the SDK status in the UI
     * 2. Checks for existing consent data
     * 3. Updates the consent dashboard with any found data
     * 4. Prepares the UI for user interaction
     */
    func sdkIsInitialized() {
        Task { @MainActor in
            sdkStatus = "Done Initializing"
            
            // Check for any existing consent data after SDK initialization
            let consentDataByCategory = TrustArc.sharedInstance.getConsentDataByCategory()
            print("SDK initialized - checking existing consent data: \(consentDataByCategory)")
            
            if let consents = consentDataByCategory as? [String: TAConsent], !consents.isEmpty {
                // Found existing consent data - update the UI
                consentStatus = "Has \(consents.count) consent categories"
                updateConsentCards(consents: consents)
                updateCardColorsBasedOnConsent(consents: consents)
            } else {
                // No existing consent data found - show empty state
                consentStatus = "No Consents"
                consentCards.removeAll()
            }
        }
    }
}
