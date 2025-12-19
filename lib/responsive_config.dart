import 'package:flutter/material.dart';

// Responsive layout configuration for Qurani app
class ResponsiveConfig {
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 360;
  }

  static bool isMediumScreen(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 360 && width < 600;
  }

  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= 600;
  }

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 768;
  }

  static double getAppBarHeight(BuildContext context) {
    if (isSmallScreen(context)) return 48.0;
    if (isTablet(context)) return 64.0;
    return 56.0;
  }

  static double getFontSize(BuildContext context, double baseSize) {
    if (isSmallScreen(context)) return baseSize * 0.9;
    if (isTablet(context)) return baseSize * 1.1;
    return baseSize;
  }

  static EdgeInsets getPadding(BuildContext context) {
    if (isSmallScreen(context)) return const EdgeInsets.all(8.0);
    if (isTablet(context)) return const EdgeInsets.all(16.0);
    return const EdgeInsets.all(12.0);
  }
}

