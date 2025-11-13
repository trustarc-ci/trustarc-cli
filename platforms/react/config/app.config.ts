/**
 * TrustArc Mobile App Configuration
 * 
 * Centralized configuration file for TrustArc SDK settings and app constants.
 * Following the pattern from the Flutter implementation for consistency.
 */

export interface AppConfig {
  /** TrustArc domain for SDK initialization */
  macDomain: string;
  /** Test website URL for WebView demonstrations */
  testWebsiteUrl: string;
}

/**
 * Default configuration values
 * These values can be overridden by environment variables or other configuration methods
 */
export const APP_CONFIG: AppConfig = {
  // TrustArc domain provided during onboarding
  macDomain: "mac_trustarc.com",
  
  // Test website for demonstrating Mobile App Consent (MAC) to Web consent functionality
  testWebsiteUrl: "https://trustarc.com",
};

/**
 * Getter functions for configuration values
 * These provide a consistent interface and support environment variable integration
 */
export const getDomainName = (): string => {
  // Check for MAC_DOMAIN environment variable first, fallback to config
  return process.env.MAC_DOMAIN || APP_CONFIG.macDomain;
};

export const getTestWebsiteUrl = (): string => APP_CONFIG.testWebsiteUrl;