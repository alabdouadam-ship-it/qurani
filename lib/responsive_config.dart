import 'package:flutter/material.dart';

// Responsive layout configuration for Qurani app.
//
// Five width-based tiers:
//   - small       : width < 360        (compact phones)
//   - medium      : 360  <= width < 600 (standard phones)
//   - large       : 600  <= width < 768 (phablets, small tablets)
//   - tablet      : 768  <= width       (portrait tablets)
//   - landscapeTablet: width >= 960 AND width > height  (landscape tablets)
//
// Prefer querying the semantic helpers (isLandscapeTablet, isTablet, etc.)
// over raw width checks at call sites — it keeps breakpoint changes in one
// place and avoids the phone-style 2-column grids that used to appear on
// 1200 dp landscape tablets.
class ResponsiveConfig {
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 360;
  }

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 768;
  }

  /// 5th tier: landscape tablet.
  /// True when the device is at least 960 dp wide AND wider than tall —
  /// typically tablets held in landscape, Chromebooks, or foldables unfolded.
  /// Screens should switch to 3-4 column layouts in this mode instead of
  /// stretching 2 columns across the full width.
  static bool isLandscapeTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width >= 960 && size.width > size.height;
  }

  static double getFontSize(BuildContext context, double baseSize) {
    if (isSmallScreen(context)) return baseSize * 0.9;
    if (isLandscapeTablet(context)) return baseSize * 1.15;
    if (isTablet(context)) return baseSize * 1.1;
    return baseSize;
  }

  static EdgeInsets getPadding(BuildContext context) {
    if (isSmallScreen(context)) return const EdgeInsets.all(8.0);
    if (isLandscapeTablet(context)) return const EdgeInsets.all(20.0);
    if (isTablet(context)) return const EdgeInsets.all(16.0);
    return const EdgeInsets.all(12.0);
  }
}

