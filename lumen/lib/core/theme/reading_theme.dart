import 'package:flutter/material.dart';

import '../../domain/entities/enums.dart';
import 'app_colors.dart';

/// Resolved colours for a reader page, derived from a [ReadingTheme].
///
/// The reader consumes a [ReadingPalette] rather than the app [ThemeData] so the
/// page surface (paper/sepia/AMOLED) is independent of the app chrome theme.
class ReadingPalette {
  const ReadingPalette({
    required this.background,
    required this.text,
    required this.isDark,
  });

  final Color background;
  final Color text;
  final bool isDark;

  Color get secondaryText => text.withValues(alpha: 0.6);
  Color get divider => text.withValues(alpha: 0.12);

  static ReadingPalette of(ReadingTheme theme) {
    return switch (theme) {
      ReadingTheme.light => const ReadingPalette(
          background: AppColors.paperLight,
          text: AppColors.inkLight,
          isDark: false,
        ),
      ReadingTheme.sepia => const ReadingPalette(
          background: AppColors.paperSepia,
          text: AppColors.textSepia,
          isDark: false,
        ),
      ReadingTheme.cream => const ReadingPalette(
          background: AppColors.paperCream,
          text: AppColors.textCream,
          isDark: false,
        ),
      ReadingTheme.dark => const ReadingPalette(
          background: AppColors.paperDark,
          text: AppColors.textDark,
          isDark: true,
        ),
      ReadingTheme.amoledBlack => const ReadingPalette(
          background: AppColors.paperAmoled,
          text: AppColors.textAmoled,
          isDark: true,
        ),
    };
  }
}
