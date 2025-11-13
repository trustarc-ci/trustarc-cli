/**
 * Root Application Layout
 * 
 * This is the main entry point and layout configuration for the TrustArc Mobile App.
 * It sets up the core application structure including:
 * 
 * - TrustArc SDK Context Provider (makes SDK available throughout app)
 * - Shared Value Context (for cross-component state management)
 * - Navigation structure and theming
 * - System UI configuration (status bar, navigation bar)
 * - Font loading and splash screen management
 * 
 * Provider Hierarchy:
 * SafeAreaProvider -> TrustArcSdkProvider -> SharedValueProvider -> ThemeProvider
 * 
 * @author TrustArc Mobile Team
 * @version 1.0.0
 */

// Navigation and theming imports
import {
  DarkTheme,
  DefaultTheme,
  ThemeProvider,
} from "@react-navigation/native";
// Expo framework imports
import { useFonts } from "expo-font";
import * as NavigationBar from 'expo-navigation-bar';
import { Stack } from "expo-router";
import * as SplashScreen from "expo-splash-screen";
import { StatusBar } from "expo-status-bar";
import * as SystemUI from "expo-system-ui";
// React imports
import { useContext, useEffect, useState } from "react";
import { Platform, StyleSheet, View } from 'react-native';
import "react-native-reanimated";
import { SafeAreaProvider } from "react-native-safe-area-context";
// Local and TrustArc imports
import { useColorScheme } from "@/hooks/useColorScheme";
import { TrustArcSdk } from "@trustarc/trustarc-react-native-consent-sdk";
import React from "react";

// === APP INITIALIZATION ===
// Prevent the splash screen from auto-hiding before asset loading is complete
SplashScreen.preventAutoHideAsync();

// === TRUSTARC SDK CONTEXT SETUP ===
/**
 * React Context for TrustArc SDK instance
 * Provides a single SDK instance throughout the application
 */
const TrustArcSdkContext = React.createContext<TrustArcSdk | null>(null);

/**
 * TrustArc SDK Provider Component
 * 
 * Creates and provides a TrustArc SDK instance to all child components.
 * This ensures a single SDK instance is used throughout the application.
 * 
 * @param {Object} props - Component props
 * @param {React.ReactNode} props.children - Child components
 */
export const TrustArcSdkProvider = ({
  children,
}: {
  children: React.ReactNode;
}) => {
  // Create single SDK instance for entire app
  const sdkInstance = new TrustArcSdk();
  return (
    <TrustArcSdkContext.Provider value={sdkInstance}>
      {children}
    </TrustArcSdkContext.Provider>
  );
};

/**
 * Hook to access TrustArc SDK instance
 * 
 * Provides access to the TrustArc SDK throughout the application.
 * Must be used within a TrustArcSdkProvider.
 * 
 * @returns {TrustArcSdk} The TrustArc SDK instance
 * @throws {Error} If used outside of TrustArcSdkProvider
 */
export const useTrustArcSdk = () => {
  const context = useContext(TrustArcSdkContext);
  if (context === null) {
    throw new Error("useTrustArcSdk must be used within a TrustArcSdkProvider");
  }

  return context;
};

// === TYPE DEFINITIONS ===

/**
 * Navigation interface for app routing
 * @interface Navigation
 */
export interface Navigation {
  navigate: (url: string, params?: any) => Promise<void>;
  goBack: () => void;
}

/**
 * Shared configuration properties used across components
 * @interface SharedValueProps
 */
export interface SharedValueProps {
  domain: string;        // TrustArc domain for SDK
  ipAddress: string;     // IP address for geolocation
  locale: string;        // User locale/language
  gdprDetection: boolean; // Enable GDPR detection
  iabLayout: boolean;    // Use IAB layout
}

/**
 * App state interface for shared value context
 * @interface AppState
 */
export interface AppState {
  value: SharedValueProps | null;
  setValue: React.Dispatch<React.SetStateAction<SharedValueProps | null>>;
}

// === SHARED VALUE CONTEXT SETUP ===
/**
 * React Context for sharing configuration values across components
 */
const SharedValueContext = React.createContext<AppState | null>(null);

/**
 * Shared Value Provider Component
 * 
 * Provides shared configuration state management across the application.
 * Used for passing domain, locale, and other settings between components.
 * 
 * @param {Object} props - Component props
 * @param {React.ReactNode} props.children - Child components
 */
export function SharedValueProvider({
  children,
}: {
  children: React.ReactNode;
}) {
  const [value, setValue] = useState<SharedValueProps | null>(null);

  return (
    <SharedValueContext.Provider value={{ value, setValue }}>
      {children}
    </SharedValueContext.Provider>
  );
}

/**
 * Hook to access shared configuration values
 * 
 * Provides access to shared configuration state throughout the application.
 * Must be used within a SharedValueProvider.
 * 
 * @returns {AppState} The shared configuration state and setter
 * @throws {Error} If used outside of SharedValueProvider
 */
export function useSharedValue() {
  const context = useContext(SharedValueContext);

  if (!context) {
    throw new Error("useSharedValue must be used within a SharedValueProvider");
  }

  return context;
}

// === ROOT LAYOUT COMPONENT ===
/**
 * Root Layout Component
 * 
 * Main application layout that sets up:
 * - Font loading and splash screen management
 * - System UI configuration (Android)
 * - Provider hierarchy for SDK and state management
 * - Navigation structure
 */
export default function RootLayout() {
  // === THEME AND FONT SETUP ===
  const colorScheme = useColorScheme();
  const [loaded] = useFonts({
    SpaceMono: require("../assets/fonts/SpaceMono-Regular.ttf"),
  });

  // === SPLASH SCREEN MANAGEMENT ===
  // Hide splash screen once fonts are loaded
  useEffect(() => {
    if (loaded) {
      SplashScreen.hideAsync();
    }
  }, [loaded]);

  // === ANDROID SYSTEM UI CONFIGURATION ===
  // Configure transparent system bars for immersive experience
  useEffect(() => {
    if (Platform.OS === "android") {
      // Make system bars transparent + immersive
      SystemUI.setBackgroundColorAsync("transparent");
      NavigationBar.setBackgroundColorAsync("transparent");
      NavigationBar.setVisibilityAsync("hidden");
    }
  }, []);

  // === LOADING STATE ===
  // Don't render app until fonts are loaded
  if (!loaded) {
    return null;
  }

  // === PROVIDER HIERARCHY RENDER ===
  return (
    <SafeAreaProvider>
      {/* TrustArc SDK Provider - Makes SDK available throughout app */}
      <TrustArcSdkProvider>
        {/* Shared Value Provider - Cross-component state management */}
        <SharedValueProvider>
          {/* Theme Provider - Dark/light theme support */}
          <ThemeProvider
            value={colorScheme === "dark" ? DarkTheme : DefaultTheme}
          >
            {/* Root View - Edge-to-edge layout */}
            <View style={styles.root}>
              {/* Navigation Stack */}
              <Stack>
                <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
                <Stack.Screen name="+not-found" />
              </Stack>

              {/* Status Bar - Translucent for immersive experience */}
              <StatusBar
                style="dark"
                translucent
                backgroundColor="transparent"
              />
            </View>
          </ThemeProvider>
        </SharedValueProvider>
      </TrustArcSdkProvider>
    </SafeAreaProvider>
  );
}

// === COMPONENT STYLES ===
const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: "#fff", // Main app background color
  },
});
