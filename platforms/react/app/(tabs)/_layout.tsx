/**
 * Tab Navigation Layout
 * 
 * Configures the bottom tab navigation for the TrustArc Mobile App.
 * 
 * Tab Structure:
 * 1. Home (index) - Main consent management interface
 * 2. Web Test (webtest) - WebView integration testing
 * 3. Preferences (sharedprefs) - SDK data inspection
 * 
 * Features:
 * - Platform-specific styling (iOS blur effects, Android material design)
 * - Haptic feedback on tab selection
 * - Dynamic theming support (light/dark mode)
 * - FontAwesome6 icons for consistent design
 * 
 * @author TrustArc Mobile Team
 * @version 1.0.0
 */

// Navigation imports
import { Tabs } from 'expo-router';
import React from 'react';
import { Platform } from 'react-native';
// Custom component imports
import { HapticTab } from '@/components/HapticTab';
import TabBarBackground from '@/components/ui/TabBarBackground';
// Styling and theming imports
import { Colors } from '@/constants/Colors';
import { useColorScheme } from '@/hooks/useColorScheme';
// Icon library
import { FontAwesome6 } from '@expo/vector-icons';

/**
 * Tab Layout Component
 * 
 * Defines the navigation structure and styling for the bottom tab bar.
 * Implements platform-specific optimizations and theme support.
 */
export default function TabLayout() {
  // === THEME CONFIGURATION ===
  const colorScheme = useColorScheme();

  return (
    <Tabs
      screenOptions={{
        // Theme-aware tab styling
        tabBarActiveTintColor: Colors[colorScheme ?? 'light'].tint,
        headerShown: false, // Hide default headers (using custom headers)
        tabBarButton: HapticTab, // Add haptic feedback to tab presses
        tabBarBackground: TabBarBackground, // Custom background with blur effects
        // Platform-specific tab bar styling
        tabBarStyle: Platform.select({
          ios: {
            // Transparent background on iOS for native blur effect
            position: 'absolute',
          },
          default: {}, // Android uses default material design
        }),
      }}>
      {/* === TAB SCREEN DEFINITIONS === */}
      
      {/* Home Tab - Main consent management interface */}
      <Tabs.Screen
        name="index"
        options={{
          title: 'Home',
          tabBarIcon: ({ color }) => <FontAwesome6 size={20} color={color} name='house' />,
        }}
      />

      {/* Web Test Tab - WebView integration and script injection testing */}
      <Tabs.Screen
        name="webtest"
        options={{
          title: 'Web Test',
          tabBarIcon: ({ color }) => <FontAwesome6 size={20} color={color} name='earth-americas' />,
        }}
      />

      {/* Preferences Tab - SDK data access and inspection */}
      <Tabs.Screen
        name="sharedprefs"
        options={{
          title: 'Preferences',
          tabBarIcon: ({ color }) => <FontAwesome6 size={20} color={color} name='gears' />,
        }}
      />
    </Tabs>
  );
}
