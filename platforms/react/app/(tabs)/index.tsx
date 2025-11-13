/**
 * TrustArc Mobile Consent Management - Main Interface
 * 
 * This is the primary screen for managing user consent preferences using the TrustArc SDK.
 * Features:
 * - SDK initialization and status monitoring
 * - Real-time consent status display
 * - Consent management dialog access
 * - Event-driven consent updates
 * 
 * @author TrustArc Mobile Team
 * @version 1.0.0
 */

// React and React Native core imports
import React, { useEffect, useState } from "react";
import {
  NativeEventEmitter,
  NativeModules,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

// TrustArc SDK imports
import {
  TrustArcSdk,
  SdkMode,
} from "@trustarc/trustarc-react-native-consent-sdk";

// Local imports
import { SharedValueProps, useSharedValue, useTrustArcSdk } from "../_layout";
import { getDomainName } from "../../config/app.config";

/**
 * Interface representing consent data structure from TrustArc SDK
 * @interface TAConsent
 * @property {number} value - Consent category level (0=required, 1=functional, 2=advertising, etc.)
 * @property {Object[]} domains - Array of domain-specific consent values
 */
interface TAConsent {
  value: number;
  domains: { [key: string]: string }[];
}

/**
 * Main Consent Management Component
 * 
 * Handles TrustArc SDK initialization, consent status monitoring,
 * and provides user interface for consent management.
 */
const Main = () => {
  // === SHARED STATE MANAGEMENT ===
  const appState = useSharedValue();

  // === STATE VARIABLES ===
  // Domain configuration from centralized config
  const [domain] = useState(getDomainName());
  
  // SDK initialization state tracking
  const [isSdkInitialized, setSdkInitialized] = useState(false);
  const [isSdkLoading, setSdkLoading] = useState(false);
  
  // Current consent status for all categories
  const [consentStatus, setConsentStatus] = useState<{
    [key: string]: TAConsent;
  }>({});

  // === SDK SETUP ===
  // Event emitter for listening to native SDK events
  const eventEmitter = new NativeEventEmitter(NativeModules.TrustArcMobileSdk);
  // TrustArc SDK instance from context provider
  const trustArcSdk: TrustArcSdk = useTrustArcSdk();

  // === SHARED STATE SYNCHRONIZATION ===
  // Update shared app state when domain changes
  useEffect(() => {
    appState.setValue({
      domain,
    } as SharedValueProps);
  }, [domain]);

  // === EVENT LISTENERS SETUP ===
  // Setup native event listeners for SDK state changes
  useEffect(() => {
    if (!trustArcSdk) {
      console.error("TrustArcSdk is undefined");
      return;
    }

    // Listen for consent changes (user updates preferences)
    let consentChangeListener = eventEmitter.addListener(
      "onConsentChanges",
      async () => {
        updateConsentStatus();
      }
    );
    
    // Listen for SDK initialization completion
    let sdkInitializedEvent = eventEmitter.addListener(
      "onSdkInitFinish",
      async () => {
        setSdkInitialized(true);
        setSdkLoading(false);
        updateConsentStatus();
        sdkInitializedEvent.remove(); // One-time event
      }
    );

    // Cleanup listeners on component unmount
    return () => {
      consentChangeListener.remove();
      sdkInitializedEvent.remove();
    };
  }, []);

  // === SDK INITIALIZATION ===
  // Initialize SDK when component mounts or SDK instance changes
  useEffect(() => {
    const initializeSdk = async () => {
      // Check if SDK is already initialized
      const isInitialized = await trustArcSdk.isSdkInitialized();
      if (isInitialized) {
        setSdkInitialized(true);
        updateConsentStatus();
      } else {
        // Start fresh initialization
        await loadSdk();
      }
    };
    initializeSdk();
  }, [trustArcSdk]);

  // === SDK LOADING FUNCTION ===
  /**
   * Initialize and start the TrustArc SDK
   * This function handles the complete SDK initialization process
   */
  const loadSdk = async () => {
    try {
      setSdkLoading(true);
      
      // Initialize SDK in standard mode (vs. iabTCFv_2_2)
      await trustArcSdk.initialize(SdkMode.standard);
      
      // Start SDK with domain configuration
      // Parameters: domain, IP address (empty for auto-detect), locale (empty for auto-detect)
      await trustArcSdk.start(domain, "", "");
    } catch (error) {
      console.error("Error initializing SDK:", error);
      setSdkLoading(false);
    }
  };

  // === CONSENT DATA MANAGEMENT ===
  /**
   * Fetch and update current consent status from SDK
   * Called after initialization and when consent changes
   */
  const updateConsentStatus = async () => {
    try {
      // Get consent data organized by category
      const consents = await trustArcSdk.getConsentDataByCategory();
      setConsentStatus(JSON.parse(consents));
    } catch (error) {
      console.error("Error getting consent status:", error);
    }
  };

  // === USER ACTIONS ===
  /**
   * Open the TrustArc Consent Manager dialog
   * This presents the user with consent preferences UI
   */
  const openCM = async () => {
    // Parameters: domain, IP address (empty for auto-detect)
    await trustArcSdk.openCM(domain, "");
  };


  // === UI STATE HELPERS ===
  // Determine if consent dialog button should be enabled
  const isButtonEnabled = isSdkInitialized && !isSdkLoading;

  // === UI RENDERING HELPERS ===
  /**
   * Render individual consent status card for a category
   * @param {string} category - Consent category name
   * @param {TAConsent} taConsent - Consent data object
   * @returns {JSX.Element} Formatted consent status card
   */
  const renderConsentStatusCard = (category: string, taConsent: TAConsent) => {
    // Check if user has granted consent for this category
    // Consent is granted if any domain has value "1"
    
    let isGranted = true;
    
    // Required category is always opted-in
    if(Number(taConsent.value) !== 0) {
       isGranted = taConsent.domains.some((domain) =>
        Object.values(domain).includes("1")
      );
    }

    return (
      <View key={category} style={styles.statusCard}>
        <View style={styles.statusCardContent}>
          <Text style={styles.categoryName}>{category}</Text>
          <View style={styles.statusRow}>
            {/* Status indicator circle */}
            <View
              style={[
                styles.statusIndicator,
                { backgroundColor: isGranted ? "#22C55E" : "#EF4444" },
              ]}
            />
            {/* Status text */}
            <Text
              style={[
                styles.statusText,
                { color: isGranted ? "#22C55E" : "#EF4444" },
              ]}
            >
              {isGranted ? "OPTED-IN" : "OPTED-OUT"}
            </Text>
          </View>
        </View>
      </View>
    );
  };

  // === MAIN COMPONENT RENDER ===
  return (
    <SafeAreaView style={styles.safeArea}>
      {/* App Header */}
      <View style={styles.header}>
        <Text style={styles.headerText}>TrustArc SDK Testing</Text>
      </View>

      <ScrollView contentContainerStyle={styles.scrollViewContent}>
        {/* Consent Status Dashboard Section */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Consent Status Dashboard</Text>

          {/* Show placeholder or consent status cards */}
          {Object.keys(consentStatus).length === 0 ? (
            <View style={styles.placeholderContainer}>
              <Text style={styles.placeholderText}>Consents not set</Text>
            </View>
          ) : (
            <View style={styles.statusCardsContainer}>
              {/* Render consent status cards sorted by category value */}
              {Object.entries(consentStatus)
                .sort((a, b) => {
                  const [keyA, consentA] = a;
                  const [keyB, consentB] = b;
                  // Sort by consent category level (0=required, 1=functional, etc.)
                  return consentA.value - consentB.value;
                })
                .map(([category, taConsent]) =>
                  renderConsentStatusCard(category, taConsent)
                )}
            </View>
          )}
        </View>

        {/* SDK Controls Section */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>SDK Controls</Text>

          {/* Loading indicator during SDK initialization */}
          {isSdkLoading && (
            <View style={styles.loadingContainer}>
              <Text style={styles.loadingText}>Initializing SDK...</Text>
            </View>
          )}

          {/* Consent Management Dialog Button */}
          <TouchableOpacity
            style={isButtonEnabled ? styles.button : styles.disabledButton}
            onPress={openCM}
            disabled={!isButtonEnabled}
          >
            <Text
              style={
                isButtonEnabled ? styles.buttonText : styles.disabledButtonText
              }
            >
              Show Consent Dialog
            </Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: "#EBF2FA",
  },
  header: {
    backgroundColor: "#1A2D3E",
    padding: 20,
  },
  headerText: {
    color: "#FFFFFF",
    fontSize: 20,
    fontWeight: "600",
    fontFamily: "System",
  },
  scrollViewContent: {
    flexGrow: 1,
    padding: 16,
  },
  section: {
    backgroundColor: "#FFFFFF",
    marginBottom: 16,
    borderRadius: 8,
    padding: 16,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: "600",
    color: "#05668D",
    marginBottom: 16,
    fontFamily: "System",
  },
  placeholderContainer: {
    padding: 20,
    alignItems: "center",
  },
  placeholderText: {
    fontSize: 16,
    color: "#9CA3AF",
    fontWeight: "600",
    fontFamily: "System",
  },
  loadingContainer: {
    padding: 16,
    alignItems: "center",
    marginBottom: 12,
  },
  loadingText: {
    fontSize: 16,
    color: "#05668D",
    fontWeight: "500",
    fontFamily: "System",
  },
  statusCardsContainer: {
    gap: 8,
  },
  statusCard: {
    backgroundColor: "#F9FAFB",
    borderRadius: 8,
    padding: 16,
    borderWidth: 1,
    borderColor: "#E5E7EB",
  },
  statusCardContent: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  categoryName: {
    fontSize: 16,
    color: "#1F2937",
    fontWeight: "500",
    fontFamily: "System",
    flex: 1,
  },
  statusRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  statusIndicator: {
    width: 12,
    height: 12,
    borderRadius: 6,
  },
  statusText: {
    fontSize: 14,
    fontWeight: "600",
    fontFamily: "System",
  },
  button: {
    backgroundColor: "#1A2D3E",
    padding: 16,
    borderRadius: 8,
    alignItems: "center",
    marginBottom: 12,
  },
  buttonText: {
    color: "#FFFFFF",
    fontSize: 16,
    fontWeight: "600",
    fontFamily: "System",
  },
  disabledButton: {
    backgroundColor: "#F3F4F6",
    padding: 16,
    borderRadius: 8,
    alignItems: "center",
    marginBottom: 12,
  },
  disabledButtonText: {
    color: "#6B7280",
    fontSize: 16,
    fontWeight: "500",
    fontFamily: "System",
  },
});

export default Main;
