import android.app.Application
import android.util.Log
import com.truste.androidmobileconsentsdk.SdkMode
import com.truste.androidmobileconsentsdk.TrustArc
import com.truste.androidmobileconsentsdk.vendors.TAConsent

/**
 * TrustArc Consent Manager Implementation for Android
 *
 * This singleton class manages the TrustArc SDK lifecycle and consent operations.
 *
 * Usage:
 * 1. Initialize in your Application class:
 *    TrustArcConsentImpl.initialize(this)
 *
 * 2. Show consent dialog:
 *    TrustArcConsentImpl.openCm()
 *
 * 3. Get consent data:
 *    val consents = TrustArcConsentImpl.getConsentData()
 */
object TrustArcConsentImpl {

    private const val TAG = "TrustArcConsent"

    // Configuration - update with your domain
    private const val DOMAIN = "__TRUSTARC_DOMAIN_PLACEHOLDER__"
    private val SDK_MODE = SdkMode.Standard
    private const val ENABLE_DEBUG_LOGS = true

    private lateinit var trustArc: TrustArc
    private var isInitialized = false

    /**
     * Initialize TrustArc SDK
     * Call this method once in your Application class
     *
     * @param application Application context
     */
    fun initialize(application: Application) {
        if (isInitialized) {
            Log.d(TAG, "TrustArc already initialized, skipping")
            return
        }

        Log.d(TAG, "Initializing TrustArc SDK with domain: $DOMAIN")

        // Create TrustArc instance
        trustArc = TrustArc(application, SDK_MODE)

        // Optional: Configure GDPR detection
        // trustArc.useGdprDetection(false)

        // Start the SDK
        trustArc.start(domainName = DOMAIN)

        // Listen for consent changes
        trustArc.addConsentListener { consents ->
            onConsentChanged(consents)
        }

        isInitialized = true
        Log.d(TAG, "TrustArc SDK initialized successfully")
    }

    /**
     * Open consent management dialog
     * This displays the TrustArc consent UI to the user
     */
    fun openCm() {
        if (!::trustArc.isInitialized) {
            Log.e(TAG, "TrustArc not initialized. Call initialize() first")
            return
        }

        Log.d(TAG, "Opening consent management dialog")
        trustArc.openCM()
    }

    /**
     * Get current consent data
     *
     * @return Map of consent categories and their values
     */
    fun getConsentData(): Map<String, TAConsent> {
        if (!::trustArc.isInitialized) {
            Log.e(TAG, "TrustArc not initialized. Call initialize() first")
            return emptyMap()
        }

        return trustArc.consentData ?: emptyMap()
    }

    /**
     * Check if user has consented to a specific category
     *
     * @param category Category name to check
     * @return true if user has consented, false otherwise
     */
    fun hasConsentForCategory(category: String): Boolean {
        val consentData = getConsentData()
        val categoryConsent = consentData[category] ?: return false

        // Check if category has consent
        return when {
            categoryConsent.value == "0" -> true // Required category
            categoryConsent.domains.isNullOrEmpty() -> false
            else -> categoryConsent.domains!!.any { it.values.contains("1") }
        }
    }

    /**
     * Called when consent data changes
     * Override this method to handle consent changes in your application
     *
     * @param consents Updated consent data
     */
    private fun onConsentChanged(consents: Map<String, TAConsent>) {
        if (ENABLE_DEBUG_LOGS) {
            Log.d(TAG, "Consent data changed: ${consents.size} categories")
            consents.forEach { (key, value) ->
                Log.d(TAG, "  Category: $key, Value: ${value.value}")
            }
        }

        // TODO: Handle consent changes in your application
        // For example: enable/disable analytics, update user preferences, etc.
    }
}
