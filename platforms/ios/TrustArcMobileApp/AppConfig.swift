/**
 * TrustArc iOS Mobile Consent App - Configuration
 * 
 * Centralized configuration file containing all configurable values for the TrustArc SDK
 * and application settings. This approach allows for easy maintenance and environment-specific
 * configurations without modifying core application code.
 * 
 * Usage:
 * - Import this file in any Swift file that needs configuration values
 * - Access values via AppConfig.shared.domainName or AppConfig.shared.testWebsiteUrl
 * - Modify values here for different environments (development, staging, production)
 */

import Foundation
import trustarc_consent_sdk

// ===== APPLICATION CONFIGURATION =====

/**
 * Centralized configuration structure for the TrustArc iOS application
 * 
 * This singleton provides access to all configurable application settings,
 * making it easy to manage different environments and update configuration
 * without touching core business logic.
 */
class AppConfig {
    
    // ===== SINGLETON INSTANCE =====
    
    /**
     * Shared singleton instance for global access to configuration
     * Use AppConfig.shared.propertyName to access any configuration value
     */
    @MainActor static let shared = AppConfig()
    
    // Private initializer to enforce singleton pattern
    private init() {}
    
    // ===== TRUSTARC SDK CONFIGURATION =====
    
    /**
     * TrustArc domain name for consent management
     * 
     * This domain should match your TrustArc account configuration.
     * 
     * 
     * Environment Usage:
     * - Development: Use test domain for development and testing
     * - Staging: Use staging domain for pre-production testing  
     * - Production: Use your actual production domain
     * 
     * IMPORTANT: Replace "mac_trustarc.com" with your actual domain for production use
     */
    let macDomain: String = "mac_trustarc.com"
    
    // ===== TEST WEBSITE CONFIGURATION =====
    
    /**
     * Test website URL for consent testing and demonstration
     * 
     * This URL can be used for:
     * - Testing WebScript injection in WebView components
     * - Demonstrating consent management on actual websites
     * - Validation of consent data collection workflows
     * 
     * The URL should be a website that has TrustArc consent management implemented
     */
    let testWebsiteUrl: String = "https://trustarc.com"
    
    // ===== SDK BEHAVIOR CONFIGURATION =====
    
    /**
     * TrustArc SDK mode configuration
     * 
     * Available modes:
     * - .standard: Standard consent collection mode
     * - .strict: Strict consent enforcement mode
     * - .custom: Custom implementation mode
     */
    let sdkMode: SdkMode = .standard
    
    /**
     * Enable or disable App Tracking Transparency integration
     * 
     * When enabled, the SDK will integrate with iOS App Tracking Transparency
     * framework to request tracking permission from users.
     * 
     * Set to false if you handle ATT separately in your app
     */
    let enableAppTrackingTransparency: Bool = true
    
    /**
     * Enable debug mode for development and testing
     * 
     * When enabled, the SDK will output detailed logging information
     * to help with debugging and development.
     * 
     * IMPORTANT: Set to false for production builds
     */
    let enableDebugMode: Bool = true
    
    // ===== UI CONFIGURATION =====
    
    /**
     * Application display name shown in the header
     */
    let appDisplayName: String = "TrustArc SDK Testing"
}
