/**
 * TrustArc Consent Implementation for iOS
 *
 * This file provides a simplified interface for integrating the TrustArc Mobile Consent SDK
 * into your iOS application. It handles SDK initialization, consent management,
 * and delegate callbacks.
 *
 * Quick Start:
 * 1. Initialize when app starts: TrustArcConsentImpl.shared.initialize()
 * 2. Show consent dialog: TrustArcConsentImpl.shared.openCm()
 * 3. Get consent status: TrustArc.sharedInstance.getConsentDataByCategory()
 *
 * @author TrustArc Mobile Team
 * @version 1.0.0
 */

import Foundation
import SwiftUI
import WebKit
import trustarc_consent_sdk

// MARK: - TrustArc Consent Manager

/**
 * TrustArc Consent Manager Implementation
 *
 * Provides a streamlined interface for TrustArc consent management operations
 * including SDK initialization, consent dialog presentation, and delegate handling.
 *
 * This class manages the TrustArc SDK lifecycle and provides convenient
 * methods for consent operations throughout your application.
 */
@MainActor
class TrustArcConsentImpl: ObservableObject {

    // ===== SINGLETON =====
    static let shared = TrustArcConsentImpl()
    private init() {}

    // ===== STATE TRACKING =====
    /// SDK initialization status
    @Published var isReady = false

    // ===== CONFIGURATION =====
    /// TrustArc domain name for consent management
    /// This will be replaced during CLI installation with your specific domain
    private let domain = "__TRUSTARC_DOMAIN_PLACEHOLDER__"

    /// SDK mode: .standard for regular operation, .iabTCFv_2_2 for TCF compliance
    private let sdkMode: SdkMode = .standard

    /// Enable App Tracking Transparency prompt
    private let enableATT = true

    /// Enable debug logging for development and troubleshooting
    private let enableDebugLogs = true

    // ===== EVENT CALLBACKS =====
    /// Callback function for consent changes
    private var onConsentChangedCallback: (([String: TAConsent]) -> Void)?

    /// Callback function for SDK initialization completion
    private var onSdkInitFinishCallback: (() -> Void)?

    // ===== INITIALIZATION METHODS =====

    /**
     * Initialize the TrustArc SDK
     *
     * This is the main entry point for integrating TrustArc consent management.
     * Call this method once when your app starts, typically in your SwiftUI App
     * struct or in your AppDelegate.
     *
     * Example usage in SwiftUI App:
     * ```swift
     * @main
     * struct MyApp: App {
     *     init() {
     *         TrustArcConsentImpl.shared.initialize()
     *     }
     *
     *     var body: some Scene {
     *         WindowGroup {
     *             ContentView()
     *         }
     *     }
     * }
     * ```
     *
     * Example usage in a View:
     * ```swift
     * struct ContentView: View {
     *     var body: some View {
     *         Text("Hello World")
     *             .onAppear {
     *                 TrustArcConsentImpl.shared.initialize()
     *             }
     *     }
     * }
     * ```
     *
     * Example usage with UIKit AppDelegate:
     * ```swift
     * func application(_ application: UIApplication,
     *                  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
     *     Task { @MainActor in
     *         TrustArcConsentImpl.shared.initialize()
     *     }
     *     return true
     * }
     * ```
     */
    func initialize() {
        Task { @MainActor in
            // Do not run init when already initialized
            guard !TrustArc.sharedInstance.isInitialized else {
                if enableDebugLogs {
                    print("[TrustArc] Already initialized, skipping")
                }
                return
            }

            if enableDebugLogs {
                print("[TrustArc] Initializing SDK with domain: \(domain)")
            }

            // Register delegates to handle SDK callbacks
            _ = TrustArc.sharedInstance.addSdkInitializationDelegate(self)
            _ = TrustArc.sharedInstance.addConsentViewControllerDelegate(self)
            _ = TrustArc.sharedInstance.addReportingDelegate(self)

            // Configure TrustArc SDK settings
            _ = TrustArc.sharedInstance.setDomain(domain)
            _ = TrustArc.sharedInstance.setMode(sdkMode)
            _ = TrustArc.sharedInstance.enableAppTrackingTransparencyPrompt(enableATT)
            _ = TrustArc.sharedInstance.enableDebugLogs(enableDebugLogs)

            // Start the SDK with completion callback
            TrustArc.sharedInstance.start { shouldShowConsentUI in
                Task { @MainActor in
                    self.isReady = true

                    if self.enableDebugLogs {
                        print("[TrustArc] SDK initialization completed")
                    }

                    // Notify callback
                    self.onSdkInitFinishCallback?()

                    // Auto-show consent dialog if required
                    if shouldShowConsentUI {
                        self.openCm()
                    }
                }
            }
        }
    }

    // ===== CONSENT MANAGEMENT METHODS =====

    /**
     * Open the TrustArc consent management dialog
     *
     * Presents the consent preferences UI to the user, allowing them to
     * review and modify their consent choices.
     *
     * Example usage in SwiftUI:
     * ```swift
     * Button("Manage Privacy") {
     *     TrustArcConsentImpl.shared.openCm()
     * }
     * ```
     *
     * Example usage in UIKit:
     * ```swift
     * @IBAction func managePrivacyTapped(_ sender: UIButton) {
     *     Task { @MainActor in
     *         TrustArcConsentImpl.shared.openCm()
     *     }
     * }
     * ```
     *
     * The SDK must be initialized before calling this method.
     * The method requires a valid root view controller to present the dialog.
     */
    @MainActor
    func openCm() {
        guard let rootView = getRootViewController() else {
            if enableDebugLogs {
                print("[TrustArc] Cannot open CM - no root view controller")
            }
            return
        }

        if enableDebugLogs {
            print("[TrustArc] Opening consent management dialog")
        }

        TrustArc.sharedInstance.openCM(in: rootView, delegate: self)
    }

    /**
     * Get current consent data organized by category
     *
     * Retrieves the user's current consent preferences organized by category.
     * Returns a dictionary where keys are category names and values contain consent details.
     *
     * Example usage:
     * ```swift
     * let consents = TrustArcConsentImpl.shared.getConsentData()
     * for (category, consent) in consents {
     *     print("Category: \(category), Value: \(consent.value)")
     * }
     * ```
     *
     * Example checking specific category:
     * ```swift
     * let consents = TrustArcConsentImpl.shared.getConsentData()
     * if let analyticsConsent = consents["Analytics"] {
     *     let hasConsent = TrustArcConsentImpl.shared.hasConsentForCategory("Analytics", consent: analyticsConsent)
     *     if hasConsent {
     *         // Enable analytics tracking
     *         Analytics.start()
     *     }
     * }
     * ```
     *
     * @return Dictionary of consent categories and their values
     */
    func getConsentData() -> [String: TAConsent] {
        return TrustArc.sharedInstance.getConsentDataByCategory()
    }

    /**
     * Get IAB TCF string
     *
     * Returns the current IAB TCF consent string if available.
     */
    func getTcfString() -> String? {
        return TrustArc.sharedInstance.getTcfString()
    }

    /**
     * Get Google consent mappings
     *
     * Returns Google consent mappings as a JSON string.
     */
    func getGoogleConsents() -> String? {
        return TrustArc.sharedInstance.getGoogleConsents()
    }

    /**
     * Get TrustArc WebScript for WebView injection
     *
     * Returns an empty string when WebScript is unavailable.
     */
    func getWebScript() -> String {
        return TrustArc.sharedInstance.getWebScript()
    }

    /**
     * Check if a consent category is granted by index
     */
    func isCategoryConsented(_ categoryIndex: Int) -> Bool {
        return TrustArc.sharedInstance.isCategoryConsented(categoryIndex: categoryIndex)
    }

    /**
     * Get consent details for a category index
     */
    func getCategoryConsent(_ categoryIndex: Int) -> TACategoryConsent? {
        return TrustArc.sharedInstance.getCategoryConsent(categoryIndex: categoryIndex)
    }

    /**
     * Check if user has consented to a specific category
     *
     * Convenience method to check if the user has granted consent for a specific
     * category (e.g., "Analytics", "Advertising", "Functional").
     *
     * Example usage:
     * ```swift
     * let consents = TrustArcConsentImpl.shared.getConsentData()
     * if let consent = consents["Analytics"] {
     *     if TrustArcConsentImpl.shared.hasConsentForCategory("Analytics", consent: consent) {
     *         // Enable analytics
     *         Analytics.trackEvent("app_opened")
     *     } else {
     *         // Disable analytics
     *         Analytics.disable()
     *     }
     * }
     * ```
     *
     * Example with multiple categories:
     * ```swift
     * let consents = TrustArcConsentImpl.shared.getConsentData()
     *
     * let hasAnalytics = consents["Analytics"].map {
     *     TrustArcConsentImpl.shared.hasConsentForCategory("Analytics", consent: $0)
     * } ?? false
     *
     * let hasAdvertising = consents["Advertising"].map {
     *     TrustArcConsentImpl.shared.hasConsentForCategory("Advertising", consent: $0)
     * } ?? false
     *
     * switch (hasAnalytics, hasAdvertising) {
     * case (true, true):
     *     // Both consents granted
     *     enableAllTracking()
     * case (true, false):
     *     // Only analytics
     *     enableAnalyticsOnly()
     * default:
     *     // No tracking consent
     *     disableTracking()
     * }
     * ```
     *
     * @param category Category name (not used, kept for API consistency)
     * @param consent TAConsent object to check
     * @return true if user has consented, false otherwise
     */
    func hasConsentForCategory(_ category: String, consent: TAConsent) -> Bool {
        // Value "0" indicates required category (always consented)
        if consent.value == "0" {
            return true
        }

        // Check if any domain has consent value "1" (granted)
        if let domains = consent.domains, !domains.isEmpty {
            return domains.contains { domain in
                domain.values.contains("1")
            }
        }

        return false
    }

    // ===== EVENT LISTENER METHODS =====

    /**
     * Register callback for consent changes
     *
     * The callback will be invoked whenever the user modifies their consent preferences.
     * This is the primary way to react to consent changes in your application.
     *
     * Example usage:
     * ```swift
     * TrustArcConsentImpl.shared.onConsentChange { consents in
     *     print("[TrustArc] User consent preferences changed")
     *
     *     // Update analytics based on new consent
     *     if let analyticsConsent = consents["Analytics"] {
     *         let hasConsent = TrustArcConsentImpl.shared.hasConsentForCategory(
     *             "Analytics",
     *             consent: analyticsConsent
     *         )
     *
     *         if hasConsent {
     *             Analytics.enable()
     *         } else {
     *             Analytics.disable()
     *         }
     *     }
     * }
     * ```
     *
     * @param callback Function to call when consent preferences change
     */
    func onConsentChange(callback: @escaping ([String: TAConsent]) -> Void) {
        onConsentChangedCallback = callback
    }

    /**
     * Register callback for SDK initialization completion
     *
     * The callback will be invoked when the SDK finishes initializing.
     * This is useful for updating UI state or triggering post-initialization logic.
     *
     * Example usage:
     * ```swift
     * TrustArcConsentImpl.shared.onSdkInitFinish {
     *     print("[TrustArc] SDK is ready!")
     *     // Update UI or check existing consent
     *     let consents = TrustArcConsentImpl.shared.getConsentData()
     *     self.updateUI(with: consents)
     * }
     * ```
     *
     * @param callback Function to call when SDK initialization completes
     */
    func onSdkInitFinish(callback: @escaping () -> Void) {
        onSdkInitFinishCallback = callback
    }

    // ===== UTILITY METHODS =====

    /**
     * Get root view controller for presenting modal dialogs
     *
     * This helper method retrieves the root view controller from the active window scene.
     * Required for the TrustArc SDK to display the consent management interface.
     *
     * @return The root UIViewController if available, nil otherwise
     */
    @MainActor
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return nil
        }
        return rootViewController
    }
}

// MARK: - TADelegate (SDK Initialization Callbacks)

/**
 * TADelegate Implementation
 *
 * Handles SDK initialization lifecycle callbacks.
 * These callbacks allow the app to respond to SDK state changes.
 */
@MainActor
extension TrustArcConsentImpl: TADelegate {

    /**
     * Called when the SDK is in an uninitialized state
     */
    func sdkIsNotInitialized() {
        if enableDebugLogs {
            print("[TrustArc] SDK is not initialized")
        }
    }

    /**
     * Called when the SDK initialization process is in progress
     */
    func sdkIsInitializing() {
        if enableDebugLogs {
            print("[TrustArc] SDK is initializing")
        }
    }

    /**
     * Called when the SDK has completed initialization successfully
     *
     * This callback:
     * 1. Checks for existing consent data
     * 2. Updates any registered callbacks
     * 3. Prepares the SDK for user interaction
     */
    func sdkIsInitialized() {
        if enableDebugLogs {
            print("[TrustArc] SDK initialized successfully")

            // Log existing consent data
            let consentData = TrustArc.sharedInstance.getConsentDataByCategory()
            if let consents = consentData as? [String: TAConsent], !consents.isEmpty {
                print("[TrustArc] Found \(consents.count) existing consent categories")
            } else {
                print("[TrustArc] No existing consent data")
            }
        }

        // Notify consent change callback with existing data
        if let consents = TrustArc.sharedInstance.getConsentDataByCategory() as? [String: TAConsent] {
            onConsentChangedCallback?(consents)
        }
    }
}

// MARK: - TAConsentViewControllerDelegate (Consent Dialog Callbacks)

/**
 * TAConsentViewControllerDelegate Implementation
 *
 * Handles callbacks from the TrustArc consent management dialog.
 * Manages the lifecycle of the consent dialog and processes user consent choices.
 */
@MainActor
extension TrustArcConsentImpl: TAConsentViewControllerDelegate {

    /**
     * Called when the consent dialog WebView starts loading
     */
    func consentViewController(_ consentViewController: TAConsentViewController,
                             isLoadingWebView webView: WKWebView) {
        if enableDebugLogs {
            print("[TrustArc] Consent dialog is loading")
        }
    }

    /**
     * Called when the consent dialog WebView finishes loading
     */
    func consentViewController(_ consentViewController: TAConsentViewController,
                             didFinishLoadingWebView webView: WKWebView) {
        if enableDebugLogs {
            print("[TrustArc] Consent dialog finished loading")
        }
    }

    /**
     * Called when the user completes their consent choices and closes the dialog
     *
     * This is the primary callback for processing user consent decisions.
     * The method:
     * 1. Logs the received consent data
     * 2. Dismisses the consent dialog
     * 3. Retrieves the updated consent data from the SDK
     * 4. Notifies registered callbacks
     *
     * @param consentViewController The consent dialog view controller
     * @param consentData Raw consent data from the dialog
     */
    func consentViewController(_ consentViewController: TAConsentViewController,
                             didReceiveConsentData consentData: [String: Any]) {
        if enableDebugLogs {
            print("[TrustArc] Received consent data: \(consentData)")
        }

        // Dismiss the consent dialog with animation
        consentViewController.dismiss(animated: true) {
            // Retrieve structured consent data from SDK
            let consentDataByCategory = TrustArc.sharedInstance.getConsentDataByCategory()

            if self.enableDebugLogs {
                print("[TrustArc] Consent data by category: \(consentDataByCategory)")
            }

            if let consents = consentDataByCategory as? [String: TAConsent], !consents.isEmpty {
                // Notify callback with updated consent data
                self.onConsentChangedCallback?(consents)
            } else {
                if self.enableDebugLogs {
                    print("[TrustArc] No consent data available or invalid format")
                }
            }
        }
    }
}

// MARK: - TAConsentReporterDelegate (Reporting Callbacks)

/**
 * TAConsentReporterDelegate Implementation
 *
 * Handles callbacks related to consent data reporting to TrustArc servers.
 * These callbacks provide visibility into the data transmission process.
 */
@MainActor
extension TrustArcConsentImpl: TAConsentReporterDelegate {

    /**
     * Called when the SDK is about to send consent data to TrustArc servers
     */
    func consentReporterWillSend(report: TAConsentReportInfo) {
        if enableDebugLogs {
            print("[TrustArc] Consent report will be sent")
        }
    }

    /**
     * Called when consent data has been successfully sent to TrustArc servers
     */
    func consentReporterDidSend(report: TAConsentReportInfo) {
        if enableDebugLogs {
            print("[TrustArc] Consent report sent successfully")
        }
    }

    /**
     * Called when sending consent data to TrustArc servers fails
     */
    func consentReporterDidFailSending(report: TAConsentReportInfo) {
        if enableDebugLogs {
            print("[TrustArc] Failed to send consent report")
        }
    }
}
