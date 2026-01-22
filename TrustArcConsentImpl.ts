import { NativeModules, NativeEventEmitter } from 'react-native';
import { SdkMode, TrustArcSdk } from '@trustarc/trustarc-react-native-consent-sdk';

const { TrustArcMobileSdk } = NativeModules;

/**
 * TrustArc Consent Manager Implementation for React Native
 *
 * This singleton class manages the TrustArc SDK lifecycle and consent operations
 * across both iOS and Android platforms using the native SDK modules.
 *
 * Usage:
 * 1. Initialize the SDK (typically in App.tsx or _layout.tsx):
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
  private static instance: TrustArcConsentImpl;
  private eventEmitter: NativeEventEmitter;
  private trustArcSdk: TrustArcSdk;
  private consentChangeListeners: Array<(data: any) => void> = [];
  private googleConsentChangeListeners: Array<(data: any) => void> = [];
  private sdkInitListeners: Array<() => void> = [];
  private isInitialized = false;
  private isReady = false;

  // Configuration - update with your domain
  private readonly DOMAIN = '__TRUSTARC_DOMAIN_PLACEHOLDER__';
  private readonly IP_ADDRESS = ''; // Optional: set user IP for GDPR detection
  private readonly LANGUAGE = 'en'; // Optional: set language code
  private readonly SDK_MODE = SdkMode.standard;
  private readonly USE_GDPR_DETECTION = true;
  private readonly ENABLE_DEBUG_LOGS = true;

  private constructor() {
    if (!TrustArcMobileSdk) {
      throw new Error(
        'TrustArcMobileSdk native module not found. Make sure the SDK is properly installed and linked.'
      );
    }

    this.trustArcSdk = new TrustArcSdk();
    this.eventEmitter = new NativeEventEmitter(TrustArcMobileSdk);
    this.setupEventListeners();
  }

  /**
   * Get singleton instance
   */
  public static getInstance(): TrustArcConsentImpl {
    if (!TrustArcConsentImpl.instance) {
      TrustArcConsentImpl.instance = new TrustArcConsentImpl();
    }
    return TrustArcConsentImpl.instance;
  }

  /**
   * Setup native event listeners
   */
  private setupEventListeners(): void {
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
  public async initialize(): Promise<void> {
    if (this.isInitialized) {
      console.log('[TrustArc] Already initialized, skipping');
      return;
    }

    try {
      const alreadyInitialized = await this.trustArcSdk.isSdkInitialized();
      if (alreadyInitialized) {
        this.isInitialized = true;
        this.isReady = true;
        this.sdkInitListeners.forEach((listener) => listener());
        return;
      }

      console.log(`[TrustArc] Initializing SDK with domain: ${this.DOMAIN}`);

      await this.trustArcSdk.enableDebugLog(this.ENABLE_DEBUG_LOGS);
      await this.trustArcSdk.initialize(this.SDK_MODE);
      await this.trustArcSdk.useGdprDetection(this.USE_GDPR_DETECTION);
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
  public async openCm(): Promise<void> {
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
   * @returns Promise<Record<string, any>> Map of consent categories and their values
   */
  public async getConsentData(): Promise<Record<string, any>> {
    if (!this.isInitialized) {
      throw new Error('TrustArc not initialized. Call initialize() first');
    }

    try {
      const consentData = await this.trustArcSdk.getConsentDataByCategory();
      if (!consentData) {
        return {};
      }
      if (typeof consentData === 'string') {
        return JSON.parse(consentData || '{}');
      }
      return consentData as Record<string, any>;
    } catch (error) {
      console.error('[TrustArc] Failed to get consent data:', error);
      return {};
    }
  }

  /**
   * Get consent value for a specific tracker
   *
   * @param trackerId Tracker ID to check
   * @returns Promise<string | null> Consent value for the tracker
   */
  public async getConsentValue(trackerId: string): Promise<string | null> {
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
  public async getTcfString(): Promise<string | null> {
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
   * @returns Promise<Record<string, any>> Google consent data
   */
  public async getGoogleConsents(): Promise<Record<string, any>> {
    if (!this.isInitialized) {
      throw new Error('TrustArc not initialized. Call initialize() first');
    }

    try {
      const googleConsents = await this.trustArcSdk.getGoogleConsents();
      if (!googleConsents) {
        return {};
      }
      if (typeof googleConsents === 'string') {
        return JSON.parse(googleConsents || '{}');
      }
      return googleConsents as Record<string, any>;
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
  public async getWebScript(): Promise<string | null> {
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
   * Check if a consent category is granted by index
   *
   * @param categoryIndex Consent category index
   * @returns Promise<boolean> true if consented
   */
  public async isCategoryConsented(categoryIndex: number): Promise<boolean> {
    if (!this.isInitialized) {
      throw new Error('TrustArc not initialized. Call initialize() first');
    }

    try {
      return await this.trustArcSdk.isCategoryConsented(categoryIndex);
    } catch (error) {
      console.error('[TrustArc] Failed to check category consent:', error);
      return false;
    }
  }

  /**
   * Get consent details for a category index
   *
   * @param categoryIndex Consent category index
   * @returns Promise<Record<string, any> | null> Consent details
   */
  public async getCategoryConsent(
    categoryIndex: number
  ): Promise<Record<string, any> | null> {
    if (!this.isInitialized) {
      throw new Error('TrustArc not initialized. Call initialize() first');
    }

    try {
      const categoryConsent = await this.trustArcSdk.getCategoryConsent(categoryIndex);
      if (!categoryConsent) {
        return null;
      }
      if (typeof categoryConsent === 'string') {
        return JSON.parse(categoryConsent || '{}');
      }
      return categoryConsent as Record<string, any>;
    } catch (error) {
      console.error('[TrustArc] Failed to get category consent:', error);
      return null;
    }
  }

  /**
   * Get stored consent data (SDK persistence)
   *
   * @returns Promise<Record<string, any>> Stored consent data
   */
  public async getStoredConsentData(): Promise<Record<string, any>> {
    if (!this.isInitialized) {
      throw new Error('TrustArc not initialized. Call initialize() first');
    }

    try {
      const storedConsent = await this.trustArcSdk.getStoredConsentData();
      if (!storedConsent) {
        return {};
      }
      if (typeof storedConsent === 'string') {
        return JSON.parse(storedConsent || '{}');
      }
      return storedConsent as Record<string, any>;
    } catch (error) {
      console.error('[TrustArc] Failed to get stored consent data:', error);
      return {};
    }
  }

  /**
   * Get IAB TCF preferences
   *
   * @returns Promise<Record<string, any> | string | null> IAB preferences payload
   */
  public async getIABTCFPreferences(): Promise<Record<string, any> | string | null> {
    if (!this.isInitialized) {
      throw new Error('TrustArc not initialized. Call initialize() first');
    }

    try {
      const iabPrefs = await this.trustArcSdk.getIABTCFPreferences();
      if (!iabPrefs) {
        return null;
      }
      if (typeof iabPrefs === 'string') {
        return JSON.parse(iabPrefs || '{}');
      }
      return iabPrefs as Record<string, any>;
    } catch (error) {
      console.error('[TrustArc] Failed to get IAB TCF preferences:', error);
      return null;
    }
  }

  /**
   * Check if user has consented to a specific category
   *
   * @param category Category name to check
   * @returns Promise<boolean> true if user has consented, false otherwise
   */
  public async hasConsentForCategory(category: string): Promise<boolean> {
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
      return categoryConsent.domains.some((domain: any) =>
        domain.values && domain.values.includes('1')
      );
    }

    return false;
  }

  /**
   * Register a listener for consent changes
   *
   * @param listener Callback function to be called when consent changes
   * @returns Function to unregister the listener
   */
  public onConsentChange(listener: (data: any) => void): () => void {
    this.consentChangeListeners.push(listener);
    return () => {
      this.consentChangeListeners = this.consentChangeListeners.filter((l) => l !== listener);
    };
  }

  /**
   * Register a listener for Google consent changes
   *
   * @param listener Callback function to be called when Google consent changes
   * @returns Function to unregister the listener
   */
  public onGoogleConsentChange(listener: (data: any) => void): () => void {
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
   * @param listener Callback function to be called when SDK initialization finishes
   * @returns Function to unregister the listener
   */
  public onSdkInitFinish(listener: () => void): () => void {
    this.sdkInitListeners.push(listener);
    return () => {
      this.sdkInitListeners = this.sdkInitListeners.filter((l) => l !== listener);
    };
  }

  /**
   * Check if SDK is initialized
   */
  public getIsInitialized(): boolean {
    return this.isInitialized;
  }

  /**
   * Check if SDK is ready (initialization complete)
   */
  public getIsReady(): boolean {
    return this.isReady;
  }

  /**
   * Remove all event listeners
   * Call this when your app is being destroyed
   */
  public cleanup(): void {
    this.eventEmitter.removeAllListeners('onConsentChanges');
    this.eventEmitter.removeAllListeners('onGoogleConsentChanges');
    this.eventEmitter.removeAllListeners('onSdkInitFinish');
    this.consentChangeListeners = [];
    this.googleConsentChangeListeners = [];
    this.sdkInitListeners = [];
  }
}

// Export singleton instance for convenience
export default TrustArcConsentImpl.getInstance();

// Also export the class for type-safe access
export { TrustArcConsentImpl };
