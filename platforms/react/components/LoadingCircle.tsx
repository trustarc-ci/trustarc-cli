import { FontAwesome6 } from '@expo/vector-icons';
import React, { useEffect, useRef } from 'react';
import { Animated, StyleSheet, Text, View } from 'react-native';

const LoadingCircle = () => {
  const rotation = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    const spinAnimation = Animated.loop(
      Animated.timing(rotation, {
        toValue: 1,
        duration: 1000,
        useNativeDriver: true,
      })
    );
    spinAnimation.start();

    return () => spinAnimation.stop();
  }, [rotation]);

  const rotateInterpolate = rotation.interpolate({
    inputRange: [0, 1],
    outputRange: ['0deg', '360deg'],
  });

  return (
    <View style={styles.overlay}>
      <View style={styles.loaderContainer}>
        {/* Animated FontAwesome Spinner Icon */}
        <Animated.View style={{ transform: [{ rotate: rotateInterpolate }] }}>
          <FontAwesome6 name="circle-notch" size={50} color="#3498db" />
        </Animated.View>
        <Text style={styles.loadingText}>Loading, please wait...</Text>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  overlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0, 0, 0, 0.5)', // Semi-transparent black background
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 1000, // Ensure it renders on top of other elements
  },
  loaderContainer: {
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
    backgroundColor: '#ffffff',
    borderRadius: 10,
  },
  loadingText: {
    marginTop: 20,
    fontSize: 16,
    color: '#333',
  },
});

export default LoadingCircle;
