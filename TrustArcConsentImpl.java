import android.app.Application;
import android.util.Log;
import com.truste.androidmobileconsentsdk.SdkMode;
import com.truste.androidmobileconsentsdk.TrustArc;
import com.truste.androidmobileconsentsdk.vendors.TAConsent;
import java.util.Collections;
import java.util.Map;

/**
 * TrustArc Consent Manager Implementation for Android
 *
 * This singleton class manages the TrustArc SDK lifecycle and consent operations.
 *
 * Usage:
 * 1. Initialize in your Application class:
 *    TrustArcConsentImpl.getInstance().initialize(this);
 *
 * 2. Show consent dialog:
 *    TrustArcConsentImpl.getInstance().openCm();
 *
 * 3. Get consent data:
 *    Map<String, TAConsent> consents = TrustArcConsentImpl.getInstance().getConsentData();
 */
public class TrustArcConsentImpl {

    private static final String TAG = "TrustArcConsent";

    // Configuration - update with your domain
    private static final String DOMAIN = "__TRUSTARC_DOMAIN_PLACEHOLDER__";
    private static final SdkMode SDK_MODE = SdkMode.Standard;
    private static final boolean ENABLE_DEBUG_LOGS = true;

    private static TrustArcConsentImpl instance;
    private TrustArc trustArc;
    private boolean isInitialized = false;

    /**
     * Private constructor for singleton pattern
     */
    private TrustArcConsentImpl() {
    }

    /**
     * Get singleton instance
     *
     * @return TrustArcConsentImpl instance
     */
    public static synchronized TrustArcConsentImpl getInstance() {
        if (instance == null) {
            instance = new TrustArcConsentImpl();
        }
        return instance;
    }

    /**
     * Initialize TrustArc SDK
     * Call this method once in your Application class
     *
     * @param application Application context
     */
    public void initialize(Application application) {
        if (isInitialized) {
            Log.d(TAG, "TrustArc already initialized, skipping");
            return;
        }

        Log.d(TAG, "Initializing TrustArc SDK with domain: " + DOMAIN);

        // Create TrustArc instance
        trustArc = new TrustArc(application, SDK_MODE);

        // Optional: Configure GDPR detection
        // trustArc.useGdprDetection(false);

        // Start the SDK
        trustArc.start(DOMAIN);

        // Listen for consent changes
        trustArc.addConsentListener(this::onConsentChanged);

        isInitialized = true;
        Log.d(TAG, "TrustArc SDK initialized successfully");
    }

    /**
     * Open consent management dialog
     * This displays the TrustArc consent UI to the user
     */
    public void openCm() {
        if (trustArc == null) {
            Log.e(TAG, "TrustArc not initialized. Call initialize() first");
            return;
        }

        Log.d(TAG, "Opening consent management dialog");
        trustArc.openCM();
    }

    /**
     * Get current consent data
     *
     * @return Map of consent categories and their values
     */
    public Map<String, TAConsent> getConsentData() {
        if (trustArc == null) {
            Log.e(TAG, "TrustArc not initialized. Call initialize() first");
            return Collections.emptyMap();
        }

        Map<String, TAConsent> consentData = trustArc.getConsentData();
        return consentData != null ? consentData : Collections.emptyMap();
    }

    /**
     * Check if user has consented to a specific category
     *
     * @param category Category name to check
     * @return true if user has consented, false otherwise
     */
    public boolean hasConsentForCategory(String category) {
        Map<String, TAConsent> consentData = getConsentData();
        TAConsent categoryConsent = consentData.get(category);

        if (categoryConsent == null) {
            return false;
        }

        // Check if category has consent
        if ("0".equals(categoryConsent.getValue())) {
            return true; // Required category
        }

        if (categoryConsent.getDomains() == null || categoryConsent.getDomains().isEmpty()) {
            return false;
        }

        // Check if any domain has value "1" (consented)
        for (TAConsent.Domain domain : categoryConsent.getDomains()) {
            if (domain.getValues() != null && domain.getValues().contains("1")) {
                return true;
            }
        }

        return false;
    }

    /**
     * Called when consent data changes
     * Override this method to handle consent changes in your application
     *
     * @param consents Updated consent data
     */
    private void onConsentChanged(Map<String, TAConsent> consents) {
        if (ENABLE_DEBUG_LOGS) {
            Log.d(TAG, "Consent data changed: " + consents.size() + " categories");
            for (Map.Entry<String, TAConsent> entry : consents.entrySet()) {
                Log.d(TAG, "  Category: " + entry.getKey() + ", Value: " + entry.getValue().getValue());
            }
        }

        // TODO: Handle consent changes in your application
        // For example: enable/disable analytics, update user preferences, etc.
    }
}
