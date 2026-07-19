import 'package:flutter/material.dart';

/// Lumen's brand palette. The seed color drives the Material 3 [ColorScheme];
/// the reader palettes live in `reading_theme.dart`.
abstract final class AppColors {
  const AppColors._();

  /// Warm amber — the "lumen" (light) of the brand.
  static const Color seed = Color(0xFFE8A33D);

  static const Color inkLight = Color(0xFF1C1B1A);
  static const Color inkDark = Color(0xFFECE6DF);

  // Reader surface colors, one per ReadingTheme.
  static const Color paperLight = Color(0xFFFFFFFF);
  static const Color paperSepia = Color(0xFFFBF0D9);
  static const Color paperCream = Color(0xFFF7F2E7);
  static const Color paperDark = Color(0xFF1A1A1A);
  static const Color paperAmoled = Color(0xFF000000);

  static const Color textSepia = Color(0xFF5B4636);
  static const Color textCream = Color(0xFF3A3730);
  static const Color textDark = Color(0xFFCFCAC3);
  static const Color textAmoled = Color(0xFFBFBFBF);

  // Default highlight swatches offered in the annotation toolbar.
  static const List<Color> highlightSwatches = [
    Color(0xFFFFF176), // yellow
    Color(0xFF80CBC4), // teal
    Color(0xFFF48FB1), // pink
    Color(0xFFA5D6A7), // green
    Color(0xFF90CAF9), // blue
    Color(0xFFCE93D8), // purple
  ];
}
