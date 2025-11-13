/**
 * TrustArc WebScript Integration Test
 * 
 * This component demonstrates the integration between TrustArc Mobile App Consent (MAC)
 * and web consent systems using WebView and injected JavaScript.
 * 
 * Key Features:
 * - Retrieves WebScript from TrustArc SDK after initialization
 * - Injects script before web content loads (CRITICAL TIMING)
 * - Tests consent synchronization between mobile and web
 * - Handles script loading errors gracefully
 * 
 * @author TrustArc Mobile Team
 * @version 1.0.0
 */

// Component imports
import LoadingCircle from "@/components/LoadingCircle";
// Navigation imports
import { useIsFocused } from "@react-navigation/native";
// React imports
import { useEffect, useState } from "react";
import { StyleSheet, Text, View } from "react-native";
// WebView imports
import WebView from "react-native-webview";
// Local imports
import { useSharedValue, useTrustArcSdk } from "../_layout";
import { getTestWebsiteUrl } from "../../config/app.config";

/**
 * WebScript Integration Testing Component
 * 
 * Tests the bridge between mobile consent and web consent using
 * TrustArc's WebScript injection mechanism.
 */
function WebTester() {
  // === SHARED STATE AND SDK ACCESS ===
  const appState = useSharedValue();
  const trustArcSdk = useTrustArcSdk();

  // === STATE MANAGEMENT ===
  // JavaScript code to inject into WebView
  const [webScript, setWebScript] = useState<string | null>(null);
  // Force WebView re-render when script changes
  const [key, setKey] = useState(0);
  // Tab focus state for refreshing script
  const isFocused = useIsFocused();
  // Loading state for WebView content
  const [loading, setLoading] = useState(false);

  // === WEBSCRIPT FETCHING ===
  /**
   * Fetch WebScript from TrustArc SDK
   * 
   * CRITICAL TIMING: This script MUST be retrieved AFTER SDK initialization
   * and injected BEFORE the WebView content loads to ensure proper
   * consent synchronization between mobile and web.
   */
  useEffect(() => {
    const fetchWebScript = async () => {
      // Check if SDK is initialized before attempting to get script
      if (!await trustArcSdk.isSdkInitialized()) {
        setLoading(false);
        return;
      }
      
      try {
        // Get JavaScript code for web consent integration
        const script = await trustArcSdk.getWebScript();
        setWebScript(script);
      } catch (error) {
        console.error("Error fetching web script:", error);
      }
    };

    fetchWebScript();
    // Force WebView refresh with new key
    setKey(prevKey => prevKey + 1);

  }, [trustArcSdk, isFocused]); // Re-run when SDK changes or tab becomes focused

  // === COMPONENT RENDER ===
  return (
    <View style={styles.container}>
      {/* Loading indicator overlay */}
      {loading ? (<LoadingCircle />) : (<></>)}
      
      {/* WebView with injected script or error state */}
      {webScript ? (
        <WebView
          key={key} // Force re-render when script changes
          originWhitelist={["*"]} // Allow all origins
          style={[styles.webview, loading ? styles.hidden : null]}
          // CRITICAL: Inject script BEFORE content loads
          injectedJavaScriptBeforeContentLoaded={webScript}
          source={{
            uri: getTestWebsiteUrl(), // Test website from config
          }}
          onLoadStart={() => setLoading(true)}
          onLoadEnd={() => setLoading(false)}
        />
      ) : (
        // Error state when script cannot be loaded
        <View style={styles.errorContainer}>
          <Text>Error loading WebScript from TrustArc SDK</Text>
        </View>
      )}
    </View>
  );
}

// === COMPONENT STYLES ===
const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: "stretch",
    justifyContent: "flex-start",
    backgroundColor: '#FFFFFF',
  },
  webview: {
    backgroundColor: '#F8F9FA', // Light background
    height: "100%",
    width: "100%",
    marginTop: 20,
  },
  hidden: {
    visibility: 'hidden', // Hide during loading
  },
  errorContainer: {
    flex: 1,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#FFFFFF',
  }
});

export default WebTester;
