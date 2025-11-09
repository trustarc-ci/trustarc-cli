import Foundation
import SwiftUI
import WebKit
import trustarc_consent_sdk

// MARK: - TrustArc Consent Manager

@MainActor
class TrustArcConsentImpl: ObservableObject {

    static let shared = TrustArcConsentImpl()
    private init() {}

    @Published var isReady = false

    // Configuration - update with your domain
    private let domain = "__TRUSTARC_DOMAIN_PLACEHOLDER__"
    private let sdkMode: SdkMode = .standard
    private let enableATT = true
    private let enableDebugLogs = true

    // Initialize TrustArc SDK
    func initialize() {
        Task { @MainActor in
            guard !TrustArc.sharedInstance.isInitialized else { return }

            // Register delegates
            _ = TrustArc.sharedInstance.addSdkInitializationDelegate(self)
            _ = TrustArc.sharedInstance.addConsentViewControllerDelegate(self)
            _ = TrustArc.sharedInstance.addReportingDelegate(self)

            // Configure SDK
            _ = TrustArc.sharedInstance.setDomain(domain)
            _ = TrustArc.sharedInstance.setMode(sdkMode)
            _ = TrustArc.sharedInstance.enableAppTrackingTransparencyPrompt(enableATT)
            _ = TrustArc.sharedInstance.enableDebugLogs(enableDebugLogs)

            // Start SDK
            TrustArc.sharedInstance.start { shouldShowConsentUI in
                Task { @MainActor in
                    self.isReady = true
                    if shouldShowConsentUI {
                        self.openCm()
                    }
                }
            }
        }
    }

    // Open consent management dialog
    @MainActor
    func openCm() {
        guard let rootView = getRootViewController() else { return }
        TrustArc.sharedInstance.openCM(in: rootView, delegate: self)
    }

    // Get root view controller
    @MainActor
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return nil
        }
        return rootViewController
    }
}

// MARK: - TADelegate

@MainActor
extension TrustArcConsentImpl: TADelegate {

    func sdkIsNotInitialized() {
        print("SDK is not initialized")
    }

    func sdkIsInitializing() {
        print("SDK is initializing")
    }

    func sdkIsInitialized() {
        print("SDK initialized")
        let consentData = TrustArc.sharedInstance.getConsentDataByCategory()
        print("Consent data: \(consentData)")
    }
}

// MARK: - TAConsentViewControllerDelegate

@MainActor
extension TrustArcConsentImpl: TAConsentViewControllerDelegate {

    func consentViewController(_ consentViewController: TAConsentViewController, isLoadingWebView webView: WKWebView) {
        print("Consent dialog is loading")
    }

    func consentViewController(_ consentViewController: TAConsentViewController, didFinishLoadingWebView webView: WKWebView) {
        print("Consent dialog finished loading")
    }

    func consentViewController(_ consentViewController: TAConsentViewController, didReceiveConsentData consentData: [String: Any]) {
        print("Received consent data: \(consentData)")

        consentViewController.dismiss(animated: true) {
            let consentDataByCategory = TrustArc.sharedInstance.getConsentDataByCategory()
            print("Consent data by category: \(consentDataByCategory)")
        }
    }
}

// MARK: - TAConsentReporterDelegate

@MainActor
extension TrustArcConsentImpl: TAConsentReporterDelegate {

    func consentReporterWillSend(report: TAConsentReportInfo) {
        print("Consent report will be sent")
    }

    func consentReporterDidSend(report: TAConsentReportInfo) {
        print("Consent report sent successfully")
    }

    func consentReporterDidFailSending(report: TAConsentReportInfo) {
        print("Failed to send consent report")
    }
}
