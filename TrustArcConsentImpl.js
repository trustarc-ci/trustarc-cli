import { NativeModules, NativeEventEmitter } from 'react-native';
import { SdkMode, TrustArcSdk } from '@trustarc/trustarc-react-native-consent-sdk';

/**
 * TrustArc Consent Manager Implementation for React Native
 *
 * This singleton class manages the TrustArc SDK lifecycle and consent operations
 * across both iOS and Android platforms using the native SDK modules.
 *
 * Usage:
 * 1. Initialize the SDK (typically in App.js or _layout.js):
 *    await TrustArcConsentImpl.getInstance().initialize();
 *
 * 2. Show consent dialog:
 *    TrustArcConsentImpl.getInstance().openCm();
 *
 * 3. Get consent data:
 *    const consents = await TrustArcConsentImpl.getInstance().getConsentData();
 *
 * 4. Listen for consent changes:
 *    TrustArcConsentImpl.getInstance().onConsentChange((data) => {
 *      console.log('Consent changed:', data);
 *    });
 */
class TrustArcConsentImpl {
  static instance;

  constructor() {
    this.consentChangeListeners = [];
    this.googleConsentChangeListeners = [];
    this.sdkInitListeners = [];
    this.isInitialized = false;
    this.isReady = false;

    // Configuration - update with your domain
    this.DOMAIN = 'mac_trustarc.com';
    this.IP_ADDRESS = ''; // Optional: set user IP for GDPR detection
    this.LANGUAGE = 'en'; // Optional: set language code
    this.ENABLE_DEBUG_LOGS = true;

    // Only initialize SDK components if native module is available
    if (NativeModules.TrustArcMobileSdk) {
      this.trustArcSdk = new TrustArcSdk();
      this.eventEmitter = new NativeEventEmitter(NativeModules.TrustArcMobileSdk);
      this.setupEventListeners();
    } else {
      console.warn('[TrustArc] Native module not available. SDK features will be disabled.');
      this.trustArcSdk = null;
      this.eventEmitter = null;
    }
  }

  /**
   * Get singleton instance
   */
  static getInstance() {
    if (!TrustArcConsentImpl.instance) {
      TrustArcConsentImpl.instance = new TrustArcConsentImpl();
    }
    return TrustArcConsentImpl.instance;
  }

  /**
   * Setup native event listeners
   */
  setupEventListeners() {
    // Listen for consent changes
    this.eventEmitter.addListener('onConsentChanges', (data) => {
      if (this.ENABLE_DEBUG_LOGS) {
        console.log('[TrustArc] Consent data changed:', data);
      }
      this.consentChangeListeners.forEach((listener) => listener(data));
    });

    // Listen for Google consent changes
    this.eventEmitter.addListener('onGoogleConsentChanges', (data) => {
      if (this.ENABLE_DEBUG_LOGS) {
        console.log('[TrustArc] Google consent data changed:', data);
      }
      this.googleConsentChangeListeners.forEach((listener) => listener(data));
    });

    // Listen for SDK initialization completion
    this.eventEmitter.addListener('onSdkInitFinish', () => {
      if (this.ENABLE_DEBUG_LOGS) {
        console.log('[TrustArc] SDK initialization finished');
      }
      this.isReady = true;
      this.sdkInitListeners.forEach((listener) => listener());
    });
  }

  /**
   * Initialize TrustArc SDK
   * Call this method once when your app starts
   *
   * @returns Promise<void>
   */
  async initialize() {
    if (!this.trustArcSdk) {
      console.warn('[TrustArc] SDK not available. Skipping initialization.');
      return;
    }

    if (this.isInitialized) {
      console.log('[TrustArc] Already initialized, skipping');
      return;
    }

    try {
      console.log(`[TrustArc] Initializing SDK with domain: ${this.DOMAIN}`);

      await this.trustArcSdk.enableDebugLog(this.ENABLE_DEBUG_LOGS);

      // Initialize the native SDK
      await this.trustArcSdk.initialize(SdkMode.standard);

      // Start the SDK with configuration
      await this.trustArcSdk.start(this.DOMAIN, this.IP_ADDRESS, this.LANGUAGE);

      this.isInitialized = true;
      console.log('[TrustArc] SDK initialized successfully');

      // Note: The SDK may automatically show consent UI if needed
      // The native layer handles this automatically via the shouldShowConsentUI callback
    } catch (error) {
      console.error('[TrustArc] Initialization failed:', error);
      throw error;
    }
  }

  /**
   * Open consent management dialog
   * This displays the TrustArc consent UI to the user
   *
   * @returns Promise<void>
   */
  async openCm() {
    if (!this.isInitialized) {
      throw new Error('TrustArc not initialized. Call initialize() first');
    }

    try {
      console.log('[TrustArc] Opening consent management dialog');
      await this.trustArcSdk.openCM();
    } catch (error) {
      console.error('[TrustArc] Failed to open consent dialog:', error);
      throw error;
    }
  }

  /**
   * Get current consent data by category
   *
   * @returns Promise<Object> Map of consent categories and their values
   */
  async getConsentData() {
    if (!this.isInitialized) {
      throw new Error('TrustArc not initialized. Call initialize() first');
    }

    try {
      const consentData = await this.trustArcSdk.getConsentDataByCategory();
      return consentData || {};
    } catch (error) {
      console.error('[TrustArc] Failed to get consent data:', error);
      return {};
    }
  }

  /**
   * Get consent value for a specific tracker
   *
   * @param {string} trackerId Tracker ID to check
   * @returns Promise<string | null> Consent value for the tracker
   */
  async getConsentValue(trackerId) {
    if (!this.isInitialized) {
      throw new Error('TrustArc not initialized. Call initialize() first');
    }

    try {
      return await this.trustArcSdk.getConsentValue(trackerId);
    } catch (error) {
      console.error(`[TrustArc] Failed to get consent value for tracker ${trackerId}:`, error);
      return null;
    }
  }

  /**
   * Get IAB TCF consent string
   * Only applicable if SDK is configured in IAB TCF mode
   *
   * @returns Promise<string | null> TCF consent string
   */
  async getTcfString() {
    if (!this.isInitialized) {
      throw new Error('TrustArc not initialized. Call initialize() first');
    }

    try {
      return await this.trustArcSdk.getTcfString();
    } catch (error) {
      console.error('[TrustArc] Failed to get TCF string:', error);
      return null;
    }
  }

  /**
   * Get Google Consent Mode data
   *
   * @returns Promise<Object> Google consent data
   */
  async getGoogleConsents() {
    if (!this.isInitialized) {
      throw new Error('TrustArc not initialized. Call initialize() first');
    }

    try {
      const googleConsents = await this.trustArcSdk.getGoogleConsents();
      return googleConsents || {};
    } catch (error) {
      console.error('[TrustArc] Failed to get Google consents:', error);
      return {};
    }
  }

  /**
   * Get web script for web view integration
   *
   * @returns Promise<string | null> Web script
   */
  async getWebScript() {
    if (!this.isInitialized) {
      throw new Error('TrustArc not initialized. Call initialize() first');
    }

    try {
      return await this.trustArcSdk.getWebScript();
    } catch (error) {
      console.error('[TrustArc] Failed to get web script:', error);
      return null;
    }
  }

  /**
   * Get shared preferences data
   * Platform-specific consent storage
   *
   * @returns Promise<Object> Shared preferences data
   */
  async getSharedPreferences() {
    if (!this.isInitialized) {
      throw new Error('TrustArc not initialized. Call initialize() first');
    }

    try {
      const preferences = await this.trustArcSdk.getSharedPreferences();
      return preferences || {};
    } catch (error) {
      console.error('[TrustArc] Failed to get shared preferences:', error);
      return {};
    }
  }

  /**
   * Check if user has consented to a specific category
   *
   * @param {string} category Category name to check
   * @returns Promise<boolean> true if user has consented, false otherwise
   */
  async hasConsentForCategory(category) {
    const consentData = await this.getConsentData();
    const categoryConsent = consentData[category];

    if (!categoryConsent) {
      return false;
    }

    // Check if category has consent
    // Value "0" typically means required/always consented
    if (categoryConsent.value === '0') {
      return true;
    }

    // Check if any domain has consent
    if (categoryConsent.domains && Array.isArray(categoryConsent.domains)) {
      return categoryConsent.domains.some((domain) =>
        domain.values && domain.values.includes('1')
      );
    }

    return false;
  }

  /**
   * Register a listener for consent changes
   *
   * @param {Function} listener Callback function to be called when consent changes
   * @returns Function to unregister the listener
   */
  onConsentChange(listener) {
    this.consentChangeListeners.push(listener);
    return () => {
      this.consentChangeListeners = this.consentChangeListeners.filter((l) => l !== listener);
    };
  }

  /**
   * Register a listener for Google consent changes
   *
   * @param {Function} listener Callback function to be called when Google consent changes
   * @returns Function to unregister the listener
   */
  onGoogleConsentChange(listener) {
    this.googleConsentChangeListeners.push(listener);
    return () => {
      this.googleConsentChangeListeners = this.googleConsentChangeListeners.filter(
        (l) => l !== listener
      );
    };
  }

  /**
   * Register a listener for SDK initialization completion
   *
   * @param {Function} listener Callback function to be called when SDK initialization finishes
   * @returns Function to unregister the listener
   */
  onSdkInitFinish(listener) {
    this.sdkInitListeners.push(listener);
    return () => {
      this.sdkInitListeners = this.sdkInitListeners.filter((l) => l !== listener);
    };
  }

  /**
   * Check if SDK is initialized
   */
  getIsInitialized() {
    return this.isInitialized;
  }

  /**
   * Check if SDK is ready (initialization complete)
   */
  getIsReady() {
    return this.isReady;
  }

  /**
   * Remove all event listeners
   * Call this when your app is being destroyed
   */
  cleanup() {
    this.eventEmitter.removeAllListeners('onConsentChanges');
    this.eventEmitter.removeAllListeners('onGoogleConsentChanges');
    this.eventEmitter.removeAllListeners('onSdkInitFinish');
    this.consentChangeListeners = [];
    this.googleConsentChangeListeners = [];
    this.sdkInitListeners = [];
  }
}

// Export the class as default
export default TrustArcConsentImpl;

// Also export a named export for the class
export { TrustArcConsentImpl };