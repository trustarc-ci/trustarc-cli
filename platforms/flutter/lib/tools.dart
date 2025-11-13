/// TrustArc Mobile App - UI Helper Utilities
///
/// This file contains reusable UI components and utility functions used throughout
/// the TrustArc Mobile Consent demonstration app.
///
/// Components:
/// - Styled button widgets with consistent theming
/// - Switch row components for boolean settings
/// - Text input row components for form data
/// - Toast notification helper for user feedback
///
/// Design Patterns:
/// - Consistent Material Design styling
/// - Brand color scheme integration
/// - Reusable component architecture
/// - Accessibility-friendly UI elements
///
/// Usage:
/// These utilities are imported and used across multiple screens to maintain
/// consistent UI/UX patterns throughout the application.
///
/// @author TrustArc Mobile Team
/// @version 1.0.0

// Flutter framework imports
import 'package:flutter/material.dart';
// Toast notification imports
import 'package:fluttertoast/fluttertoast.dart';

// === UI HELPER FUNCTIONS ===
// Reusable UI components for the TrustArc Mobile App

/// Build a styled button widget with consistent theming
///
/// Creates an elevated button with TrustArc brand styling including:
/// - Primary blue background color
/// - White text color
/// - Rounded corners
/// - Proper padding and sizing
/// - Disabled state support
///
/// @param text Button label text
/// @param callback Function to execute when button is pressed
/// @param enabled Whether the button should be enabled (default: true)
/// @returns Widget Styled ElevatedButton
Widget buildButton(String text, Function() callback, {bool enabled = true}) {
  return ElevatedButton(
    onPressed: enabled ? callback : null,
    style: ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: const Color(0xFF007BFF), // TrustArc brand blue
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    child: Text(text),
  );
}

/// Build a switch row widget with label and consistent styling
///
/// Creates a row layout with label text on the left and a toggle switch on the right.
/// Uses TrustArc brand colors for the active switch state.
///
/// @param label Text label displayed next to the switch
/// @param value Current boolean value of the switch
/// @param valueChange Callback function executed when switch value changes
/// @returns Widget Row containing label and switch
Widget buildSwitchRow(String label, bool value, Function(bool) valueChange) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Switch(
          value: value,
          onChanged: valueChange,
          activeColor: const Color(0xFF007BFF), // TrustArc brand blue
        ),
      ],
    ),
  );
}

/// Build a text input row widget with label and styled text field
///
/// Creates a row layout with a bold label on the left and a text input field on the right.
/// The text field includes:
/// - Outlined border styling
/// - TrustArc brand blue focus border
/// - Placeholder text support
/// - Flexible sizing to accommodate different screen sizes
///
/// @param label Text label displayed next to the input field
/// @param placeholder Hint text shown in the input field when empty
/// @param controller TextEditingController for managing input value
/// @param spaceWidth Optional spacing width between label and field (default: 50.0)
/// @returns Widget Row containing label and text input field
Widget buildTextRow(
    String label, String placeholder, TextEditingController controller,
    {double spaceWidth = 50.0}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(width: spaceWidth),
        Flexible(
            child: TextField(
          controller: controller,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(
                  color: Color(0xFF007BFF), width: 2), // TrustArc brand blue
            ),
            hintText: placeholder,
          ),
        ))
      ],
    ),
  );
}

// === TOAST NOTIFICATION HELPER ===

/// Show a toast notification with the given message
///
/// Displays a temporary notification message at the bottom of the screen.
/// Used throughout the app to provide user feedback for actions like:
/// - SDK initialization completion
/// - Consent changes
/// - Data copying to clipboard
/// - Error notifications
///
/// Configuration:
/// - Long duration for better visibility
/// - Bottom gravity for non-intrusive display
/// - Dark theme with white text for readability
/// - Cross-platform support (iOS and Android)
///
/// @param message Text message to display (default: "Hello")
void showToast({String message = "Hello"}) {
  Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.black,
      textColor: Colors.white,
      fontSize: 16.0);
}
