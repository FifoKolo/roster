import 'package:flutter/material.dart';

/// Responsive design utilities for mobile and tablet optimization
class ResponsiveHelper {
  /// Screen size breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;
  
  /// Get current device type
  static DeviceType getDeviceType(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth < mobileBreakpoint) {
      return DeviceType.mobile;
    } else if (screenWidth < tabletBreakpoint) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }
  
  /// Check if device is mobile
  static bool isMobile(BuildContext context) {
    return getDeviceType(context) == DeviceType.mobile;
  }
  
  /// Check if device is tablet
  static bool isTablet(BuildContext context) {
    return getDeviceType(context) == DeviceType.tablet;
  }
  
  /// Check if device is desktop
  static bool isDesktop(BuildContext context) {
    return getDeviceType(context) == DeviceType.desktop;
  }
  
  /// Get orientation-aware dimensions
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }
  
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }
  
  /// Get responsive padding
  static EdgeInsets getResponsivePadding(BuildContext context) {
    final deviceType = getDeviceType(context);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    switch (deviceType) {
      case DeviceType.mobile:
        return isLandscape 
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
          : const EdgeInsets.all(8);
      case DeviceType.tablet:
        return isLandscape 
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
          : const EdgeInsets.all(12);
      case DeviceType.desktop:
        return const EdgeInsets.all(16);
    }
  }
  
  /// Get responsive margin
  static EdgeInsets getResponsiveMargin(BuildContext context) {
    final deviceType = getDeviceType(context);
    
    switch (deviceType) {
      case DeviceType.mobile:
        return const EdgeInsets.symmetric(horizontal: 4, vertical: 2);
      case DeviceType.tablet:
        return const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
      case DeviceType.desktop:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
    }
  }
  
  /// Get responsive font size
  static double getResponsiveFontSize(BuildContext context, double baseFontSize) {
    final deviceType = getDeviceType(context);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    switch (deviceType) {
      case DeviceType.mobile:
        return isLandscape 
          ? baseFontSize * 0.8  // Smaller in landscape to fit more content
          : baseFontSize * 0.9; // Slightly smaller in portrait
      case DeviceType.tablet:
        return baseFontSize;
      case DeviceType.desktop:
        return baseFontSize * 1.1;
    }
  }
  
  /// Get responsive icon size
  static double getResponsiveIconSize(BuildContext context, double baseIconSize) {
    final deviceType = getDeviceType(context);
    
    switch (deviceType) {
      case DeviceType.mobile:
        return baseIconSize * 0.8;
      case DeviceType.tablet:
        return baseIconSize;
      case DeviceType.desktop:
        return baseIconSize * 1.2;
    }
  }
  
  /// Get responsive button height
  static double getResponsiveButtonHeight(BuildContext context) {
    final deviceType = getDeviceType(context);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    switch (deviceType) {
      case DeviceType.mobile:
        return isLandscape ? 40 : 48; // Smaller in landscape
      case DeviceType.tablet:
        return 52;
      case DeviceType.desktop:
        return 56;
    }
  }
  
  /// Get responsive dialog width
  static double getResponsiveDialogWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final deviceType = getDeviceType(context);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    switch (deviceType) {
      case DeviceType.mobile:
        return isLandscape 
          ? screenWidth * 0.7  // Use more width in landscape
          : screenWidth * 0.9; // Almost full width in portrait
      case DeviceType.tablet:
        return screenWidth * 0.6;
      case DeviceType.desktop:
        return 450; // Fixed width for desktop
    }
  }
  
  /// Get responsive dialog max height
  static double getResponsiveDialogMaxHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return isLandscape 
      ? screenHeight * 0.9  // Use more height in landscape
      : screenHeight * 0.8; // Standard height in portrait
  }
  
  /// Get responsive grid columns for roster table
  static int getResponsiveGridColumns(BuildContext context) {
    final deviceType = getDeviceType(context);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    switch (deviceType) {
      case DeviceType.mobile:
        return isLandscape ? 8 : 4; // Show all days in landscape, 4 in portrait
      case DeviceType.tablet:
        return 8; // Always show all 7 days + name column
      case DeviceType.desktop:
        return 8; // Full table
    }
  }
  
  /// Get responsive app bar height
  static double getResponsiveAppBarHeight(BuildContext context) {
    final deviceType = getDeviceType(context);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    switch (deviceType) {
      case DeviceType.mobile:
        return isLandscape ? 48 : 56; // Smaller in landscape
      case DeviceType.tablet:
        return 60;
      case DeviceType.desktop:
        return 64;
    }
  }
  
  /// Get responsive floating action button size
  static double getResponsiveFABSize(BuildContext context) {
    final deviceType = getDeviceType(context);
    
    switch (deviceType) {
      case DeviceType.mobile:
        return 48;
      case DeviceType.tablet:
        return 52;
      case DeviceType.desktop:
        return 56;
    }
  }
  
  /// Check if should use bottom sheet instead of dialog
  static bool shouldUseBottomSheet(BuildContext context) {
    final deviceType = getDeviceType(context);
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    
    return deviceType == DeviceType.mobile && isPortrait;
  }
  
  /// Get safe area padding
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }
}

/// Device type enumeration
enum DeviceType {
  mobile,
  tablet,
  desktop,
}