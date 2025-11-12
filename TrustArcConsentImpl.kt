/**
 * TrustArc Consent Implementation for Android
 *
 * This file provides a simplified interface for integrating the TrustArc Mobile Consent SDK
 * into your Android application. It handles SDK initialization, consent management,
 * and event callbacks.
 *
 * Quick Start:
 * 1. Initialize in your Application class: TrustArcConsentImpl.initialize(this)
 * 2. Show consent dialog: TrustArcConsentImpl.openCm()
 * 3. Get consent status: TrustArcConsentImpl.getConsentData()
 *
 * @author TrustArc Mobile Team
 * @version 1.0.0
 */

import android.app.Application
import android.util.Log
import com.truste.androidmobileconsentsdk.SdkMode
import com.truste.androidmobileconsentsdk.TrustArc
import com.truste.androidmobileconsentsdk.vendors.TAConsent

/**
 * TrustArc Consent Manager Implementation
 *
 * Provides a streamlined interface for TrustArc consent management operations
 * including SDK initialization, consent dialog presentation, and status retrieval.
 *
 * This singleton object manages the TrustArc SDK lifecycle and provides convenient
 * methods for consent operations throughout your application.
 */
object TrustArcConsentImpl {

    private const val TAG = "TrustArcConsent"

    // ===== CONFIGURATION =====
    /// TrustArc domain name for consent management
    /// This will be replaced during CLI installation with your specific domain
    private const val DOMAIN = "__TRUSTARC_DOMAIN_PLACEHOLDER__"

    /// SDK mode: Standard for regular operation, IAB for TCF compliance
    private val SDK_MODE = SdkMode.Standard

    /// Enable debug logging for development and troubleshooting
    private const val ENABLE_DEBUG_LOGS = true

    // ===== SDK INSTANCE =====
    private lateinit var trustArc: TrustArc

    // ===== STATE TRACKING =====
    private var isInitialized = false

    // ===== EVENT CALLBACKS =====
    /// Callback function for consent changes
    private var onConsentChangedCallback: ((Map<String, TAConsent>) -> Unit)? = null

    /// Callback function for Google consent changes
    private var onGoogleConsentChangedCallback: ((Map<String, String>) -> Unit)? = null

    /// Callback function for SDK initialization completion
    private var onSdkInitFinishCallback: (() -> Unit)? = null

    // ===== INITIALIZATION METHODS =====

    /**
     * Initialize the TrustArc SDK
     *
     * This is the main entry point for integrating TrustArc consent management.
     * Call this method once when your app starts, typically in your Application class's
     * onCreate() method.
     *
     * Example usage in Application class:
     * ```kotlin
     * class MyApplication : Application() {
     *     override fun onCreate() {
     *         super.onCreate()
     *         TrustArcConsentImpl.initialize(this)
     *     }
     * }
     * ```
     *
     * Example usage with Hilt/Dagger:
     * ```kotlin
     * @HiltAndroidApp
     * class MyApplication : Application() {
     *     override fun onCreate() {
     *         super.onCreate()
     *         TrustArcConsentImpl.initialize(this)
     *     }
     * }
     * ```
     *
     * @param application Application context
     */
    fun initialize(application: Application) {
        if (isInitialized) {
            Log.d(TAG, "TrustArc already initialized, skipping")
            return
        }

        if (ENABLE_DEBUG_LOGS) {
            Log.d(TAG, "Initializing TrustArc SDK with domain: $DOMAIN")
        }

        try {
            // Create TrustArc instance with SDK mode
            trustArc = TrustArc(application, SDK_MODE)

            // Enable debug logging if configured
            trustArc.enableDebugLog(ENABLE_DEBUG_LOGS)

            // Optional: Configure GDPR detection
            // Uncomment to disable automatic GDPR detection based on IP
            // trustArc.useGdprDetection(false)

            // Start the SDK with domain configuration
            trustArc.start(domainName = DOMAIN)

            // Register consent change listener
            trustArc.addConsentListener { consents ->
                handleConsentChanged(consents)
            }

            // Register Google consent listener
            trustArc.addGoogleConsentListener { googleConsents ->
                handleGoogleConsentChanged(googleConsents)
            }

            isInitialized = true

            if (ENABLE_DEBUG_LOGS) {
                Log.d(TAG, "TrustArc SDK initialized successfully")
            }

            // Notify initialization completion
            onSdkInitFinishCallback?.invoke()

        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize TrustArc SDK", e)
            throw e
        }
    }

    // ===== CONSENT MANAGEMENT METHODS =====

    /**
     * Open the TrustArc consent management dialog
     *
     * Presents the consent preferences UI to the user, allowing them to
     * review and modify their consent choices.
     *
     * Example usage in an Activity:
     * ```kotlin
     * class MainActivity : AppCompatActivity() {
     *     private fun showPrivacySettings() {
     *         TrustArcConsentImpl.openCm()
     *     }
     * }
     * ```
     *
     * Example usage in a Fragment:
     * ```kotlin
     * class SettingsFragment : Fragment() {
     *     private fun manageConsent() {
     *         TrustArcConsentImpl.openCm()
     *     }
     * }
     * ```
     *
     * Example usage in Jetpack Compose:
     * ```kotlin
     * @Composable
     * fun PrivacySettingsButton() {
     *     Button(onClick = { TrustArcConsentImpl.openCm() }) {
     *         Text("Manage Privacy")
     *     }
     * }
     * ```
     *
     * The SDK must be initialized before calling this method.
     */
    fun openCm() {
        if (!::trustArc.isInitialized) {
            Log.e(TAG, "TrustArc not initialized. Call initialize() first")
            return
        }

        if (ENABLE_DEBUG_LOGS) {
            Log.d(TAG, "Opening consent management dialog")
        }

        try {
            trustArc.openCM()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open consent dialog", e)
        }
    }

    /**
     * Get current consent data organized by category
     *
     * Retrieves the user's current consent preferences organized by category.
     * Returns a map where keys are category names and values contain consent details.
     *
     * Example usage:
     * ```kotlin
     * val consents = TrustArcConsentImpl.getConsentData()
     * consents.forEach { (category, consent) ->
     *     Log.d("Consent", "Category: $category, Value: ${consent.value}")
     * }
     * ```
     *
     * Example checking specific category:
     * ```kotlin
     * val analyticsConsent = TrustArcConsentImpl.getConsentData()["Analytics"]
     * if (analyticsConsent != null) {
     *     val hasConsent = TrustArcConsentImpl.hasConsentForCategory("Analytics")
     *     if (hasConsent) {
     *         // Enable analytics tracking
     *         Analytics.initialize()
     *     }
     * }
     * ```
     *
     * @return Map of consent categories and their values, or empty map if not initialized
     */
    fun getConsentData(): Map<String, TAConsent> {
        if (!::trustArc.isInitialized) {
            Log.e(TAG, "TrustArc not initialized. Call initialize() first")
            return emptyMap()
        }

        return try {
            trustArc.getConsentDataByCategory()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get consent data", e)
            emptyMap()
        }
    }

    /**
     * Get Google Consent Mode data
     *
     * Retrieves consent data formatted for Google Consent Mode v2.
     * This is useful if your app uses Google services and needs to handle
     * Google consent separately.
     *
     * Example usage:
     * ```kotlin
     * val googleConsents = TrustArcConsentImpl.getGoogleConsents()
     * googleConsents.forEach { (key, value) ->
     *     Log.d("GoogleConsent", "$key: $value")
     * }
     * ```
     *
     * Example with Firebase:
     * ```kotlin
     * val googleConsents = TrustArcConsentImpl.getGoogleConsents()
     * val adStorageConsent = googleConsents["ad_storage"] == "granted"
     * val analyticsConsent = googleConsents["analytics_storage"] == "granted"
     *
     * FirebaseAnalytics.getInstance(context).setConsent {
     *     adStorage(if (adStorageConsent) GRANTED else DENIED)
     *     analyticsStorage(if (analyticsConsent) GRANTED else DENIED)
     * }
     * ```
     *
     * @return Map of Google consent keys and their values
     */
    fun getGoogleConsents(): Map<String, String> {
        if (!::trustArc.isInitialized) {
            Log.e(TAG, "TrustArc not initialized. Call initialize() first")
            return emptyMap()
        }

        return try {
            trustArc.getGoogleConsents()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get Google consents", e)
            emptyMap()
        }
    }

    /**
     * Check if user has consented to a specific category
     *
     * Convenience method to check if the user has granted consent for a specific
     * category (e.g., "Analytics", "Advertising", "Functional").
     *
     * Example usage:
     * ```kotlin
     * if (TrustArcConsentImpl.hasConsentForCategory("Analytics")) {
     *     // Enable analytics tracking
     *     Analytics.trackEvent("app_opened")
     * } else {
     *     // Analytics disabled
     *     Analytics.disable()
     * }
     * ```
     *
     * Example with multiple categories:
     * ```kotlin
     * val hasAnalytics = TrustArcConsentImpl.hasConsentForCategory("Analytics")
     * val hasAdvertising = TrustArcConsentImpl.hasConsentForCategory("Advertising")
     *
     * when {
     *     hasAnalytics && hasAdvertising -> {
     *         // Both consents granted
     *         enableAllTracking()
     *     }
     *     hasAnalytics -> {
     *         // Only analytics
     *         enableAnalyticsOnly()
     *     }
     *     else -> {
     *         // No tracking consent
     *         disableTracking()
     *     }
     * }
     * ```
     *
     * @param category Category name to check
     * @return true if user has consented, false otherwise
     */
    fun hasConsentForCategory(category: String): Boolean {
        val consentData = getConsentData()
        val categoryConsent = consentData[category] ?: return false

        // Check if category has consent
        return when {
            // Value "0" indicates required category (always consented)
            categoryConsent.value == "0" -> true
            // No domains means no consent data available
            categoryConsent.domains.isNullOrEmpty() -> false
            // Check if any domain has value "1" (consented)
            else -> categoryConsent.domains!!.any { it.values.contains("1") }
        }
    }

    // ===== EVENT LISTENER METHODS =====

    /**
     * Register callback for consent changes
     *
     * The callback will be invoked whenever the user modifies their consent preferences.
     * This is the primary way to react to consent changes in your application.
     *
     * Example usage:
     * ```kotlin
     * TrustArcConsentImpl.onConsentChange { consents ->
     *     Log.d("Consent", "User consent preferences changed")
     *
     *     // Update analytics based on new consent
     *     val hasAnalyticsConsent = consents["Analytics"]?.let { consent ->
     *         consent.value == "0" || consent.domains?.any {
     *             it.values.contains("1")
     *         } == true
     *     } ?: false
     *
     *     if (hasAnalyticsConsent) {
     *         Analytics.enable()
     *     } else {
     *         Analytics.disable()
     *     }
     * }
     * ```
     *
     * @param callback Function to call when consent preferences change
     */
    fun onConsentChange(callback: (Map<String, TAConsent>) -> Unit) {
        onConsentChangedCallback = callback
    }

    /**
     * Register callback for Google consent changes
     *
     * The callback will be invoked when Google-specific consent preferences change.
     * This is useful if your app uses Google services and needs to handle
     * Google consent separately.
     *
     * Example usage:
     * ```kotlin
     * TrustArcConsentImpl.onGoogleConsentChange { googleConsents ->
     *     Log.d("GoogleConsent", "Google consent preferences changed")
     *
     *     // Update Google services configuration
     *     val adStorageGranted = googleConsents["ad_storage"] == "granted"
     *     val analyticsGranted = googleConsents["analytics_storage"] == "granted"
     *
     *     // Configure Firebase Analytics
     *     FirebaseAnalytics.getInstance(context).setConsent {
     *         adStorage(if (adStorageGranted) GRANTED else DENIED)
     *         analyticsStorage(if (analyticsGranted) GRANTED else DENIED)
     *     }
     * }
     * ```
     *
     * @param callback Function to call when Google consent changes
     */
    fun onGoogleConsentChange(callback: (Map<String, String>) -> Unit) {
        onGoogleConsentChangedCallback = callback
    }

    /**
     * Register callback for SDK initialization completion
     *
     * The callback will be invoked when the SDK finishes initializing.
     * This is useful for updating UI state or triggering post-initialization logic.
     *
     * Example usage:
     * ```kotlin
     * TrustArcConsentImpl.onSdkInitFinish {
     *     Log.d("TrustArc", "SDK is ready!")
     *     // Update UI or check existing consent
     *     val consents = TrustArcConsentImpl.getConsentData()
     *     updateUIWithConsents(consents)
     * }
     * ```
     *
     * @param callback Function to call when SDK initialization completes
     */
    fun onSdkInitFinish(callback: () -> Unit) {
        onSdkInitFinishCallback = callback
    }

    // ===== STATUS QUERY METHODS =====

    /**
     * Check if SDK is currently initialized
     *
     * @return true if SDK is initialized and ready to use
     */
    fun isInitialized(): Boolean {
        return isInitialized
    }

    /**
     * Get the configured domain name
     *
     * @return TrustArc domain configured for this SDK instance
     */
    fun getDomain(): String {
        return DOMAIN
    }

    // ===== INTERNAL EVENT HANDLERS =====

    /**
     * Internal handler for consent changes
     *
     * Called by the SDK when consent data changes.
     * Logs the change and notifies registered callbacks.
     *
     * @param consents Updated consent data
     */
    private fun handleConsentChanged(consents: Map<String, TAConsent>) {
        if (ENABLE_DEBUG_LOGS) {
            Log.d(TAG, "Consent data changed: ${consents.size} categories")
            consents.forEach { (key, value) ->
                Log.d(TAG, "  Category: $key, Value: ${value.value}")
            }
        }

        // Notify callback
        onConsentChangedCallback?.invoke(consents)
    }

    /**
     * Internal handler for Google consent changes
     *
     * Called by the SDK when Google consent data changes.
     * Logs the change and notifies registered callbacks.
     *
     * @param googleConsents Updated Google consent data
     */
    private fun handleGoogleConsentChanged(googleConsents: Map<String, String>) {
        if (ENABLE_DEBUG_LOGS) {
            Log.d(TAG, "Google consent data changed")
            googleConsents.forEach { (key, value) ->
                Log.d(TAG, "  $key: $value")
            }
        }

        // Notify callback
        onGoogleConsentChangedCallback?.invoke(googleConsents)
    }
}
