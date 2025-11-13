/**
 * TrustArc Android Mobile Consent App - Configuration
 * 
 * Centralized configuration file containing all configurable values for the TrustArc SDK
 * and application settings. This approach allows for easy maintenance and environment-specific
 * configurations without modifying core application code.
 * 
 * Usage:
 * - Import this file in any Kotlin file that needs configuration values
 * - Access values via AppConfig.DOMAIN_NAME or AppConfig.TEST_WEBSITE_URL
 * - Modify values here for different environments (development, staging, production)
 */

package com.example.trustarcmobileapp.config

// ===== APPLICATION CONFIGURATION =====

/**
 * Centralized configuration object for the TrustArc Android application
 * 
 * This object provides access to all configurable application settings,
 * making it easy to manage different environments and update configuration
 * without touching core business logic.
 */
object AppConfig {
    
    // ===== TRUSTARC SDK CONFIGURATION =====
    
    /**
     * TrustArc domain name for consent management
     * 
     * This domain should match your TrustArc account configuration.
     * 
     * Environment Usage:
     * - Development: Use test domain for development and testing
     * - Staging: Use staging domain for pre-production testing  
     * - Production: Use your actual production domain
     * 
     * IMPORTANT: Replace "mac_trustarc.com" with your actual domain for production use
     */
    const val MAC_DOMAIN: String = "app.mattel.speedway"
    
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
    const val TEST_WEBSITE_URL: String = "https://trustarc.com"
    
    // ===== SDK BEHAVIOR CONFIGURATION =====
    
    /**
     * TrustArc SDK mode configuration
     * 
     * Available modes:
     * - "standard": Standard consent collection mode
     * - "strict": Strict consent enforcement mode
     * - "custom": Custom implementation mode
     */
    const val SDK_MODE: String = "standard"
    
    /**
     * Enable or disable debug mode for development and testing
     * 
     * When enabled, the SDK will output detailed logging information
     * to help with debugging and development.
     * 
     * IMPORTANT: Set to false for production builds
     */
    const val ENABLE_DEBUG_MODE: Boolean = true
    
    // ===== UI CONFIGURATION =====
    
    /**
     * Application display name shown in the header
     */
    const val APP_DISPLAY_NAME: String = "TrustArc SDK Testing"
    
    /**
     * Enable or disable automatic consent dialog display
     * 
     * When enabled, the consent dialog will automatically appear
     * when the SDK determines it should be shown (e.g., first launch)
     */
    const val AUTO_SHOW_CONSENT_DIALOG: Boolean = true
    
    // ===== WEBVIEW CONFIGURATION =====
    
    /**
     * Enable JavaScript in WebView components
     * Required for TrustArc consent management functionality
     */
    const val WEBVIEW_JAVASCRIPT_ENABLED: Boolean = true
    
    /**
     * Enable DOM storage in WebView components
     * Required for consent data persistence in web context
     */
    const val WEBVIEW_DOM_STORAGE_ENABLED: Boolean = true
    
    /**
     * WebView user agent string suffix
     * Can be used to identify the app in web analytics
     */
    const val WEBVIEW_USER_AGENT_SUFFIX: String = "TrustArcMobileApp/1.0"
    
    // ===== LOGGING CONFIGURATION =====
    
    /**
     * Tag used for Android logging throughout the application
     */
    const val LOG_TAG: String = "TrustArcMobileApp"
    
    /**
     * Enable verbose logging for detailed debugging
     * Only used when ENABLE_DEBUG_MODE is true
     */
    const val ENABLE_VERBOSE_LOGGING: Boolean = true
}