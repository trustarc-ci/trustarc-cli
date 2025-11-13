/**
 * TrustArc Android Mobile Consent App - Home Fragment
 * 
 * This fragment serves as the main interface for the TrustArc Consent SDK demonstration app.
 * It provides a comprehensive testing interface for consent management, real-time status tracking,
 * and SDK integration workflows.
 * 
 * Key Features:
 * - Real-time consent status dashboard with visual indicators
 * - Dynamic consent card generation based on SDK data
 * - SDK initialization and consent dialog management
 * - Automated consent data processing and categorization
 * - Material Design UI components with color-coded status indicators
 * 
 * Architecture:
 * - Uses Dagger Hilt for dependency injection
 * - Implements Observer pattern for consent status updates
 * - Follows MVVM pattern with ConsentManager as data layer
 * - Uses Android View system with fragment-based navigation
 * 
 * Dependencies:
 * - TrustArc Android Mobile Consent SDK for consent management
 * - Dagger Hilt for dependency injection
 * - Android ViewBinding for UI component access
 */

package com.example.trustarcmobileapp.presentation.fragments

// Standard Android imports
import android.os.Bundle              // Bundle for fragment state management
import android.view.LayoutInflater    // Layout inflater for view creation
import android.view.View             // Base view class
import android.view.ViewGroup        // ViewGroup for container views
import android.widget.Button         // Button UI component
import android.widget.LinearLayout   // Linear layout container
import android.widget.TextView       // TextView UI component

// AndroidX and support libraries
import androidx.core.content.ContextCompat  // Context compatibility utilities
import androidx.fragment.app.Fragment       // Base fragment class

// Application-specific imports
import com.example.trustarcmobileapp.R                         // App resources
import com.example.trustarcmobileapp.config.AppConfig          // Application configuration
import com.example.trustarcmobileapp.domain.ConsentStatus      // Consent status enumeration
import com.example.trustarcmobileapp.data.manager.ConsentManager // Consent data management

// TrustArc SDK imports
import com.truste.androidmobileconsentsdk.TrustArc              // Main TrustArc SDK class
import com.truste.androidmobileconsentsdk.vendors.TAConsent     // Consent data model

// Dependency injection
import dagger.hilt.android.AndroidEntryPoint  // Hilt dependency injection annotation
import javax.inject.Inject                    // Injection annotation

// ===== HOME FRAGMENT CLASS =====

/**
 * Main fragment class that manages the TrustArc SDK integration and UI state
 * 
 * This fragment serves as the primary interface for consent management and demonstrates
 * the complete integration workflow with the TrustArc Android SDK. It handles:
 * - SDK initialization and configuration
 * - Consent data processing and UI state management
 * - Dynamic UI updates based on consent status changes
 * - User interactions with consent management features
 * 
 * The fragment uses Dagger Hilt for dependency injection and follows Android's
 * lifecycle patterns for proper resource management.
 */
@AndroidEntryPoint
class HomeFragment : Fragment() {

    // ===== DEPENDENCY INJECTION =====
    
    /**
     * Injected ConsentManager for handling consent data operations
     * Manages consent state, processing, and business logic
     */
    @Inject
    lateinit var consentManager: ConsentManager
    
    /**
     * Injected TrustArc SDK instance for direct SDK operations
     * Handles consent dialog display and SDK lifecycle management
     */
    @Inject
    lateinit var trustArc: TrustArc

    // ===== UI COMPONENTS =====
    
    /**
     * Container for dynamically generated consent status cards
     * Populated based on current consent data from the SDK
     */
    private lateinit var statusCardContainer: LinearLayout
    
    /**
     * Placeholder text displayed when no consent data is available
     * Hidden when consent cards are displayed
     */
    private lateinit var tvConsentPlaceholder: TextView
    
    /**
     * Primary action button to open the consent management dialog
     * Triggers the TrustArc consent interface
     */
    private lateinit var btnShowConsentDialog: Button

    // ===== FRAGMENT LIFECYCLE METHODS =====
    
    /**
     * Create and return the view hierarchy associated with the fragment
     * 
     * This method inflates the fragment_home layout, which contains:
     * - Header section with app title
     * - Consent status dashboard area
     * - SDK control buttons
     * 
     * @param inflater LayoutInflater to inflate the fragment layout
     * @param container ViewGroup container for the fragment
     * @param savedInstanceState Bundle containing saved state (if any)
     * @return View hierarchy for the fragment
     */
    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        return inflater.inflate(R.layout.fragment_home, container, false)
    }

    /**
     * Called after the view hierarchy has been created
     * 
     * This method performs the complete fragment initialization sequence:
     * 1. Initialize UI component references
     * 2. Set up click listeners for user interactions
     * 3. Register observers for consent data changes
     * 4. Initialize the ConsentManager
     * 5. Check for existing consent data
     * 
     * @param view The fragment's root view
     * @param savedInstanceState Bundle containing saved state (if any)
     */
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        
        // Initialize UI component references
        initViews(view)
        
        // Set up user interaction handlers
        setupClickListeners()
        
        // Register for consent data change notifications
        observeConsentChanges()
        
        // Initialize the consent management system
        consentManager.initialize()
        
        // Check for existing consent data after view is ready
        view.post {
            checkInitialConsentState()
        }
    }

    // ===== UI INITIALIZATION METHODS =====
    
    /**
     * Initialize references to UI components from the inflated layout
     * 
     * This method establishes connections to key UI elements:
     * - statusCardContainer: Container for dynamic consent status cards
     * - tvConsentPlaceholder: Placeholder text for empty states
     * - btnShowConsentDialog: Primary action button for consent management
     * 
     * @param view The fragment's root view containing the UI components
     */
    private fun initViews(view: View) {
        statusCardContainer = view.findViewById(R.id.statusCardContainer)
        tvConsentPlaceholder = view.findViewById(R.id.tvConsentPlaceholder)
        btnShowConsentDialog = view.findViewById(R.id.btnShowConsentDialog)
    }

    /**
     * Set up click listeners for interactive UI components
     * 
     * Configures user interaction handlers:
     * - Consent dialog button: Opens the TrustArc consent management interface
     * 
     * Additional click listeners can be added here for future functionality
     */
    private fun setupClickListeners() {
        btnShowConsentDialog.setOnClickListener {
            showConsentDialog()
        }
    }
    
    // ===== CONSENT STATE MANAGEMENT =====
    
    /**
     * Check for existing consent data on initial load
     * 
     * This method examines the TrustArc SDK's SharedPreferences to determine
     * if any consent data has been previously stored. If no data exists,
     * it displays the placeholder message indicating consent hasn't been set.
     * 
     * The SharedPreferences key "com.truste.androidmobileconsentsdk" is the
     * standard key used by the TrustArc SDK for storing consent data.
     */
    private fun checkInitialConsentState() {
        val consentPrefs = requireContext().getSharedPreferences(
            "com.truste.androidmobileconsentsdk", 
            android.content.Context.MODE_PRIVATE
        )
        
        if (consentPrefs.all.isEmpty()) {
            showConsentPlaceholder()
        }
    }

    /**
     * Set up observer for consent data changes
     * 
     * This method registers a listener with the TrustArc SDK to receive
     * notifications when consent data changes. This enables real-time UI
     * updates when users modify their consent preferences.
     * 
     * The listener callback runs on the SDK's background thread, so UI
     * updates are posted to the main thread using runOnUiThread().
     * 
     * @see updateUIWithDynamicConsents for the UI update logic
     */
    private fun observeConsentChanges() {
        trustArc.addConsentListener { consents ->
            activity?.runOnUiThread {
                updateUIWithDynamicConsents(consents)
            }
        }
    }

    // ===== UI UPDATE METHODS =====
    
    /**
     * Update the UI with dynamic consent status cards
     * 
     * This method processes consent data from the TrustArc SDK and generates
     * individual status cards for each consent category. The method:
     * 1. Clears any existing status cards from the container
     * 2. Hides the placeholder text (since we have consent data)
     * 3. Creates a status card for each consent category
     * 
     * Each status card displays the category name and current consent state
     * with appropriate visual indicators (colors, icons, status text).
     * 
     * @param consents Map of consent data from TrustArc SDK, where:
     *                 - Key: Category identifier/name
     *                 - Value: TAConsent object containing consent details
     */
    private fun updateUIWithDynamicConsents(consents: Map<String, TAConsent>) {
        // Clear existing status cards to prevent duplicates
        statusCardContainer.removeAllViews()
        
        // Hide placeholder text since we have consent data to display
        tvConsentPlaceholder.visibility = View.GONE
        
        // Generate individual status cards for each consent category
        consents.forEach { (categoryKey, categoryValue) ->
            createStatusCard(categoryKey, categoryValue)
        }
    }
    
    /**
     * Create and configure an individual consent status card
     * 
     * This method generates a status card UI component for a specific consent category.
     * The card displays:
     * - Category name/identifier
     * - Current consent status (granted/denied/undefined)
     * - Visual status indicator (colored circle)
     * - Status text with appropriate styling
     * 
     * The card layout is inflated from item_consent_status_card.xml and dynamically
     * added to the statusCardContainer.
     * 
     * @param categoryKey The consent category identifier/name to display
     * @param categoryValue The TAConsent object containing consent details
     */
    private fun createStatusCard(categoryKey: String, categoryValue: TAConsent) {
        // Inflate the status card layout
        val statusCard = layoutInflater.inflate(R.layout.item_consent_status_card, statusCardContainer, false)
        
        // Set the category name in the card
        val tvCategoryName = statusCard.findViewById<TextView>(R.id.tvCategoryName)
        tvCategoryName.text = categoryKey
        
        // Determine and apply the consent status styling
        val status = determineConsentStatus(categoryValue)
        updateStatusCard(statusCard, status)

        // Add the configured card to the container
        statusCardContainer.addView(statusCard)
    }
    
    // ===== CONSENT DATA PROCESSING =====
    
    /**
     * Determine the consent status for an individual TrustArc consent object
     * 
     * This method analyzes a TAConsent object to determine whether the user has
     * granted, denied, or left undefined their consent for that category.
     * 
     * Logic:
     * - Value "0" categories are required and always considered granted
     * - Other categories check domain values for "1" (granted) vs absence (denied)
     * - Any exceptions during processing result in UNDEFINED status
     * 
     * Category Value Meanings:
     * - "0": Required/necessary cookies (always granted)
     * - "1": Functional cookies (user choice)
     * - "2": Advertising/marketing cookies (user choice)
     * 
     * @param taConsent The TrustArc consent object to analyze
     * @return ConsentStatus indicating the current state (GRANTED/DENIED/UNDEFINED)
     */
    private fun determineConsentStatus(taConsent: TAConsent): ConsentStatus {
        try {
            // Required categories (value "0") are always granted by definition
            if (taConsent.value == "0") {
                return ConsentStatus.GRANTED
            }
            
            // Check domain values to determine consent state
            val hasConsent = if (taConsent.domains == null || taConsent.domains!!.isEmpty()) {
                false
            } else {
                // Look for "1" value in any domain, indicating user granted consent
                taConsent.domains!!.any { domain -> 
                    domain.values.contains("1") 
                }
            }
            
            return if (hasConsent) ConsentStatus.GRANTED else ConsentStatus.DENIED
            
        } catch (e: Exception) {
            // Handle any exceptions during consent analysis
            android.util.Log.w(AppConfig.LOG_TAG, "Error determining consent status", e)
            return ConsentStatus.UNDEFINED
        }
    }
    
    /**
     * Update a status card with visual styling based on consent status
     * 
     * This method applies appropriate visual styling to a consent status card
     * based on the determined consent status. The styling includes:
     * - Status text (OPTED-IN, OPTED-OUT, UNDEFINED)
     * - Text color (green, red, gray)
     * - Status indicator background (colored circles)
     * 
     * Visual Indicators:
     * - GRANTED: Green text and circle - user has consented
     * - DENIED: Red text and circle - user has opted out
     * - UNDEFINED: Gray text and circle - status not determined
     * 
     * @param cardView The inflated status card view to update
     * @param status The consent status to apply to the card
     */
    private fun updateStatusCard(cardView: View, status: ConsentStatus) {
        val tvStatus = cardView.findViewById<TextView>(R.id.tvStatus)
        val statusIndicator = cardView.findViewById<View>(R.id.statusIndicator)

        when (status) {
            ConsentStatus.GRANTED -> {
                // User has granted consent - show positive green styling
                tvStatus.text = "OPTED-IN"
                tvStatus.setTextColor(ContextCompat.getColor(requireContext(), R.color.status_green))
                statusIndicator.background = ContextCompat.getDrawable(requireContext(), R.drawable.status_indicator_granted)
            }
            ConsentStatus.DENIED -> {
                // User has denied consent - show negative red styling
                tvStatus.text = "OPTED-OUT"
                tvStatus.setTextColor(ContextCompat.getColor(requireContext(), R.color.status_red))
                statusIndicator.background = ContextCompat.getDrawable(requireContext(), R.drawable.status_indicator_denied)
            }
            ConsentStatus.UNDEFINED -> {
                // Consent status unknown - show neutral gray styling
                tvStatus.text = "UNDEFINED"
                tvStatus.setTextColor(ContextCompat.getColor(requireContext(), R.color.status_gray))
                statusIndicator.background = ContextCompat.getDrawable(requireContext(), R.drawable.status_indicator_undefined)
            }
        }
    }
    
    // ===== UI STATE MANAGEMENT =====
    
    /**
     * Display the consent placeholder message
     * 
     * This method shows the placeholder text that appears when no consent
     * data is available. It:
     * 1. Removes any existing status cards from the container
     * 2. Makes the placeholder text visible
     * 
     * The placeholder typically displays "Consents not set" to indicate
     * that the user hasn't provided any consent preferences yet.
     */
    private fun showConsentPlaceholder() {
        statusCardContainer.removeAllViews()
        tvConsentPlaceholder.visibility = View.VISIBLE
    }

    // ===== USER INTERACTION METHODS =====
    
    /**
     * Open the TrustArc consent management dialog
     * 
     * This method triggers the TrustArc SDK to display the consent management
     * interface to the user. The dialog allows users to:
     * - Review available consent categories
     * - Grant or deny consent for each category
     * - Modify existing consent preferences
     * 
     * The dialog is managed entirely by the TrustArc SDK and will trigger
     * consent change callbacks when the user completes their choices.
     * 
     * The domain configuration is loaded from AppConfig.DOMAIN_NAME
     */
    private fun showConsentDialog() {
        if (AppConfig.ENABLE_DEBUG_MODE) {
            android.util.Log.d(AppConfig.LOG_TAG, "Opening consent dialog for domain: ${AppConfig.MAC_DOMAIN}")
        }
        trustArc.openCM()
    }
}