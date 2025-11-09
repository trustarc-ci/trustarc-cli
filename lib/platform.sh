#!/bin/bash

# Platform detection functions for TrustArc CLI
# This file contains logic to detect mobile app platforms

# Detect platform type in current directory
detect_platform() {
    local dir=${1:-.}

    # Check for iOS (Xcode projects, Swift Package Manager, or CocoaPods)
    # Check for .xcodeproj or .xcworkspace first (most common)
    if ls "$dir"/*.xcodeproj >/dev/null 2>&1 || ls "$dir"/*.xcworkspace >/dev/null 2>&1; then
        echo "ios"
        return 0
    fi

    # Check for Swift Package Manager
    if [ -f "$dir/Package.swift" ] && grep -q "platforms" "$dir/Package.swift" 2>/dev/null; then
        echo "ios"
        return 0
    fi

    # Check for CocoaPods
    if [ -f "$dir/Podfile" ] && grep -q "platform :ios" "$dir/Podfile" 2>/dev/null; then
        echo "ios"
        return 0
    fi

    # Check for Android
    if [ -f "$dir/build.gradle" ] || [ -f "$dir/build.gradle.kts" ] || [ -f "$dir/app/build.gradle" ]; then
        if grep -r "com.android" "$dir" 2>/dev/null | grep -q "application\|library"; then
            echo "android"
            return 0
        fi
    fi

    # Check for React Native (both Expo and non-Expo)
    if [ -f "$dir/app.json" ] && [ -f "$dir/package.json" ]; then
        if grep -q "expo" "$dir/package.json" 2>/dev/null; then
            echo "react-native"
            return 0
        fi
    fi

    if [ -f "$dir/package.json" ] && grep -q "react-native" "$dir/package.json" 2>/dev/null; then
        if [ -d "$dir/android" ] && [ -d "$dir/ios" ]; then
            echo "react-native"
            return 0
        fi
    fi

    # Check for Flutter
    if [ -f "$dir/pubspec.yaml" ] && grep -q "flutter:" "$dir/pubspec.yaml" 2>/dev/null; then
        echo "flutter"
        return 0
    fi

    return 1
}
