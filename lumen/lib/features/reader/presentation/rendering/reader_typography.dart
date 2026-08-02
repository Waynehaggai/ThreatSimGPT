import 'package:flutter/material.dart';

import '../../../../core/theme/reading_theme.dart';
import '../../../../domain/entities/enums.dart';
import '../../../../domain/entities/reading_settings.dart';

/// Resolves the user's [ReadingSettings] + the active [ReadingPalette] into the
/// concrete [TextStyle]s used by the Smart Mode renderer.
///
/// Centralising this keeps every block type visually consistent and makes the
/// mapping (settings → styles) unit-testable without pumping widgets.
class ReaderTypography {
  const ReaderTypography(this.settings, this.palette);

  final ReadingSettings settings;
  final ReadingPalette palette;

  FontWeight get _weight {
    // Clamp to the nearest supported FontWeight (100–900).
    final index = (settings.fontWeight ~/ 100 - 1).clamp(0, 8);
    return FontWeight.values[index];
  }

  TextAlign get textAlign => switch (settings.textAlign) {
        ReadingTextAlign.start => TextAlign.start,
        ReadingTextAlign.justify => TextAlign.justify,
        ReadingTextAlign.center => TextAlign.center,
      };

  /// Body paragraph style — the baseline all others derive from.
  TextStyle get paragraph => TextStyle(
        fontFamily: _familyOrNull,
        fontSize: settings.fontSizeSp,
        height: settings.lineHeight,
        fontWeight: _weight,
        color: palette.text,
      );

  /// Headings scale off the body size by their level (h1 largest).
  TextStyle heading(int level) {
    const scales = [1.9, 1.6, 1.38, 1.2, 1.1, 1.05];
    final scale = scales[level.clamp(0, scales.length - 1)];
    return paragraph.copyWith(
      fontSize: settings.fontSizeSp * scale,
      fontWeight: FontWeight.w700,
      height: 1.25,
    );
  }

  TextStyle get quote => paragraph.copyWith(
        fontStyle: FontStyle.italic,
        color: palette.text.withValues(alpha: 0.85),
      );

  TextStyle get caption => paragraph.copyWith(
        fontSize: settings.fontSizeSp * 0.82,
        color: palette.secondaryText,
      );

  TextStyle get code => paragraph.copyWith(
        fontFamily: 'monospace',
        fontSize: settings.fontSizeSp * 0.9,
        height: 1.4,
      );

  /// Vertical gap between blocks, driven by the paragraph-spacing setting.
  double get blockSpacing => settings.paragraphSpacing;

  double get horizontalMargin => settings.horizontalMargin;

  /// First-line indent for body paragraphs — the classic printed-book cue that
  /// a new paragraph has begun. Scales with the font size (~1.4em).
  double get paragraphIndent => settings.fontSizeSp * 1.4;

  /// Left indent applied to list items so they sit in from the body text.
  double get listIndent => settings.fontSizeSp * 1.1;

  // Treat the platform default sentinel as "no explicit family".
  String? get _familyOrNull =>
      settings.fontFamily.isEmpty ? null : settings.fontFamily;
}
