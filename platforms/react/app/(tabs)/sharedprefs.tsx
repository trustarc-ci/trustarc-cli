/**
 * TrustArc SDK Data Access and Preferences Inspector
 *
 * This component provides a comprehensive interface for accessing and viewing
 * all data types available from the TrustArc SDK. It demonstrates the various
 * data access patterns and serves as a debugging/testing tool.
 *
 * Data Types Accessible:
 * - Consent Preferences: User's consent choices by category
 * - IAB TCF String: Transparency & Consent Framework string
 * - IAB TCF Preferences: Detailed IAB consent data
 * - Google Consents: Google-specific consent mappings
 * - Web Script: JavaScript for web integration
 *
 * Features:
 * - Accordion-style expandable sections
 * - Copy-to-clipboard functionality
 * - Real-time data fetching from SDK
 * - Error handling and loading states
 *
 * @author TrustArc Mobile Team
 * @version 1.0.0
 */

// External library imports
import Clipboard from "@react-native-clipboard/clipboard";
import { FontAwesome6 } from "@expo/vector-icons";
// TrustArc SDK imports
import { TrustArcSdk } from "@trustarc/trustarc-react-native-consent-sdk";
import { IABTCFPreferences } from "@trustarc/trustarc-react-native-consent-sdk/lib/trustarc-mobile-sdk";
// React and React Native imports
import React, { useEffect, useState } from "react";
import {
  Alert,
  StyleSheet,
  ScrollView,
  Text,
  View,
  ActivityIndicator,
  TouchableOpacity,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
// Local imports
import { useTrustArcSdk } from "../_layout";

/**
 * Type definition for consent preferences data
 * @typedef {Object} Preferences
 * @property {string} [key] - Consent key with value "1" (granted)
 */
type Preferences = {
  [key: string]: "1";
};

/**
 * Reusable Accordion Component
 *
 * Provides expandable/collapsible sections for organizing SDK data types.
 * Includes loading states and smooth expand/collapse animations.
 *
 * @param {Object} props - Component props
 * @param {string} props.title - Section title
 * @param {Function} props.onPress - Click handler
 * @param {boolean} props.expanded - Whether section is expanded
 * @param {boolean} props.loading - Whether data is loading
 * @param {React.ReactNode} props.children - Content to display when expanded
 */
const Accordion = ({ title, onPress, expanded, loading, children }: any) => (
  <View style={styles.accordionContainer}>
    {/* Accordion Header with Title and Chevron */}
    <TouchableOpacity style={styles.accordionHeader} onPress={onPress}>
      <Text style={styles.accordionTitle}>{title}</Text>
      <FontAwesome6
        name={expanded ? "chevron-up" : "chevron-down"}
        size={18}
        color="#007AFF"
      />
    </TouchableOpacity>

    {/* Expandable Content Area */}
    {expanded && (
      <View style={styles.accordionContent}>
        {loading ? (
          <ActivityIndicator size="small" color="#007AFF" />
        ) : (
          children
        )}
      </View>
    )}
  </View>
);

/**
 * Main SharedPreferences Component
 *
 * Provides interface for inspecting all TrustArc SDK data types.
 * Each data type is presented in an expandable accordion section.
 */
const SharedPref = () => {
  // === SDK ACCESS ===
  const trustArcSdk: TrustArcSdk = useTrustArcSdk();

  // === STATE MANAGEMENT ===
  // Data state for each SDK data type
  const [googleConsents, setGoogleConsents] = useState<Preferences | null>(
    null
  );
  const [tcfString, setTcfString] = useState<string | null>(null);
  const [consentData, setConsentData] = useState<Preferences | null>(null);
  const [iabConsentData, setIabConsentData] =
    useState<IABTCFPreferences | null>(null);
  const [webScript, setWebScript] = useState<string | null>(null);

  // UI state management
  const [loadingSection, setLoadingSection] = useState<string | null>(null);
  const [expandedSection, setExpandedSection] = useState<string | null>(null);

  // === DATA FETCHING FUNCTIONS ===
  /**
   * Fetch data from TrustArc SDK based on section type
   *
   * This function demonstrates all the different data access methods
   * available in the TrustArc SDK.
   *
   * @param {string} section - The data section to fetch
   */
  const fetchData = async (section: string) => {
    setLoadingSection(section);
    try {
      if (section === "ConsentPreferences") {
        // Get stored consent data (user's preferences)
        const consentDataStr = await trustArcSdk.getStoredConsentData();
        setConsentData(JSON.parse(consentDataStr));
      } else if (section === "IABTCFString") {
        // Get IAB Transparency & Consent Framework string
        const tcfStr = await trustArcSdk.getTcfString();
        setTcfString(tcfStr);
      } else if (section === "GoogleConsents") {
        // Get Google-specific consent mappings
        const googleConsentsStr = await trustArcSdk.getGoogleConsents();
        setGoogleConsents(JSON.parse(googleConsentsStr));
      } else if (section === "WebScript") {
        // Get JavaScript for web integration (used in WebView)
        const webScriptStr = await trustArcSdk.getWebScript();
        setWebScript(webScriptStr);
      } else if (section === "IABConsentPreferences") {
        // Get detailed IAB TCF preferences
        const consentDataStr = await trustArcSdk.getIABTCFPreferences();
        setIabConsentData(consentDataStr);
      }
    } catch (error) {
      console.error(`Error fetching data for ${section}:`, error);
    } finally {
      setLoadingSection(null);
    }
  };

  // === UI INTERACTION HANDLERS ===
  /**
   * Toggle accordion section and trigger data fetching
   *
   * @param {string} section - Section identifier to toggle
   */
  const toggleAccordion = (section: string) => {
    if (expandedSection === section) {
      setExpandedSection(null); // Collapse current section
    } else {
      setExpandedSection(section); // Expand new section
      fetchData(section); // Fetch data when expanding
    }
  };

  /**
   * Copy data to device clipboard with user feedback
   *
   * @param {string} data - Data to copy
   * @param {string} message - Success message to display
   */
  const copyToClipboard = (data: string, message: string) => {
    Clipboard.setString(data);
    Alert.alert("Copied to Clipboard", message);
  };

  // === COMPONENT RENDER ===
  return (
    <SafeAreaView style={styles.safeArea}>
      <ScrollView style={styles.container}>
        {/* === CONSENT PREFERENCES SECTION === */}
        {/* Basic consent data showing user's category-level preferences */}
        <Accordion
          title="Consent Preferences"
          expanded={expandedSection === "ConsentPreferences"}
          loading={loadingSection === "ConsentPreferences"}
          onPress={() => toggleAccordion("ConsentPreferences")}
        >
          {consentData ? (
            <>
              <TouchableOpacity
                onPress={() =>
                  copyToClipboard(
                    JSON.stringify(consentData || {}),
                    "Consent Data Copied"
                  )
                }
              >
                <Text style={styles.copyLabel}>
                  Click here to copy the contents
                </Text>
              </TouchableOpacity>
              <ScrollView style={styles.contentContainer}>
                {Object.keys(consentData).map((key, index) => (
                  <Text
                    key={index}
                    style={styles.content}
                  >{`${key}: ${consentData[key]}`}</Text>
                ))}
              </ScrollView>
            </>
          ) : (
            <Text style={[styles.content, styles.alignCenter]}>(No Data)</Text>
          )}
        </Accordion>

        {/* === IAB TCF STRING SECTION === */}
        {/* Transparency & Consent Framework encoded string for European compliance */}
        <Accordion
          title="IAB TCF String"
          expanded={expandedSection === "IABTCFString"}
          loading={loadingSection === "IABTCFString"}
          onPress={() => toggleAccordion("IABTCFString")}
        >
          {tcfString ? (
            <>
              <TouchableOpacity
                onPress={() =>
                  copyToClipboard(tcfString || "", "TCF String Copied")
                }
              >
                <Text style={styles.copyLabel}>
                  Click here to copy the contents
                </Text>
              </TouchableOpacity>
              <ScrollView style={styles.contentContainer}>
                <Text style={styles.content}>{tcfString}</Text>
              </ScrollView>
            </>
          ) : (
            <Text style={[styles.content, styles.alignCenter]}>(No Data)</Text>
          )}
        </Accordion>

        {/* === IAB TCF PREFERENCES SECTION === */}
        {/* Detailed IAB TCF preferences with vendor and purpose information */}
        <Accordion
          title="IABTCF Preferences"
          expanded={expandedSection === "IABConsentPreferences"}
          loading={loadingSection === "IABConsentPreferences"}
          onPress={() => toggleAccordion("IABConsentPreferences")}
        >
          {iabConsentData ? (
            <>
              <TouchableOpacity
                onPress={() =>
                  copyToClipboard(
                    JSON.stringify(iabConsentData || {}),
                    "IAB Consent Data Copied"
                  )
                }
              >
                <Text style={styles.copyLabel}>
                  Click here to copy the contents
                </Text>
              </TouchableOpacity>
              <ScrollView style={styles.contentContainer}>
                {Object.keys(iabConsentData).map((key, index) => (
                  <Text key={index} style={styles.content}>{`${key}: ${
                    iabConsentData[key as keyof IABTCFPreferences]
                  }`}</Text>
                ))}
              </ScrollView>
            </>
          ) : (
            <Text style={[styles.content, styles.alignCenter]}>(No Data)</Text>
          )}
        </Accordion>

        {/* === GOOGLE CONSENTS SECTION === */}
        {/* Google-specific consent mappings for AdMob, Analytics, etc. */}
        <Accordion
          title="Google Consents"
          expanded={expandedSection === "GoogleConsents"}
          loading={loadingSection === "GoogleConsents"}
          onPress={() => toggleAccordion("GoogleConsents")}
        >
          {googleConsents ? (
            <>
              <TouchableOpacity
                onPress={() =>
                  copyToClipboard(
                    JSON.stringify(googleConsents || {}),
                    "Google Consents Copied"
                  )
                }
              >
                <Text style={styles.copyLabel}>
                  Click here to copy the contents
                </Text>
              </TouchableOpacity>
              <ScrollView style={styles.contentContainer}>
                {Object.keys(googleConsents).map((key, index) => (
                  <Text
                    key={index}
                    style={styles.content}
                  >{`${key}: ${googleConsents[key]}`}</Text>
                ))}
              </ScrollView>
            </>
          ) : (
            <Text style={[styles.content, styles.alignCenter]}>(No Data)</Text>
          )}
        </Accordion>
        {/* === WEB SCRIPT SECTION === */}
        {/* JavaScript code for WebView integration (used in WebTest tab) */}
        <Accordion
          title="Consent Web Script"
          expanded={expandedSection === "WebScript"}
          loading={loadingSection === "WebScript"}
          onPress={() => toggleAccordion("WebScript")}
        >
          {webScript ? (
            <>
              <TouchableOpacity
                onPress={() =>
                  copyToClipboard(webScript || "", "Web Script Copied")
                }
              >
                <Text style={styles.copyLabel}>
                  Click here to copy the contents
                </Text>
              </TouchableOpacity>
              <ScrollView style={styles.contentContainer}>
                <Text style={styles.content}>{webScript}</Text>
              </ScrollView>
            </>
          ) : (
            <Text style={[styles.content, styles.alignCenter]}>(No Data)</Text>
          )}
        </Accordion>
      </ScrollView>
    </SafeAreaView>
  );
};

// === COMPONENT STYLES ===

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: "#F8F9FA",
  },
  container: {
    flex: 1,
    padding: 16,
    paddingTop: 30,
    backgroundColor: "#FFFFFF",
  },
  contentContainer: {
    maxHeight: 300,
  },
  accordionContainer: {
    marginBottom: 10,
    borderWidth: 1,
    borderColor: "#DDD",
    paddingVertical: 5,
    paddingHorizontal: 10,
    borderRadius: 10,
  },
  accordionHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    paddingVertical: 10,
  },
  accordionTitle: {
    fontSize: 16,
    fontWeight: "600",
    color: "#333",
  },
  accordionContent: {
    paddingVertical: 10,
    paddingLeft: 10,
    borderRadius: 5,
    display: "flex",
  },
  content: {
    fontSize: 14,
    color: "#555",
    marginBottom: 5,
    marginTop: 10,
  },
  copyLabel: {
    fontSize: 14,
    color: "#FFFFFF",
    fontWeight: "bold",
    marginBottom: 10,
    alignSelf: "center",
    width: "100%",
    padding: 10,
    borderRadius: 10,
    backgroundColor: "#007AFF",
    textAlign: "center",
  },
  alignCenter: {
    width: "100%",
    textAlign: "center",
  },
});

export default SharedPref;
