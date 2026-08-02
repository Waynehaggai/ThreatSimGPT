import 'enums.dart';

/// All reader customization options. Persisted locally and synced as a single
/// document so every device reads identically.
class ReadingSettings {
  const ReadingSettings({
    this.fontFamily = 'Merriweather',
    this.fontSizeSp = 18.0,
    this.fontWeight = 400,
    this.lineHeight = 1.5,
    this.paragraphSpacing = 12.0,
    this.horizontalMargin = 24.0,
    this.textAlign = ReadingTextAlign.justify,
    this.theme = ReadingTheme.light,
    this.pageNavigation = PageNavigation.pageTurn,
    this.brightnessOverride,
    this.keepScreenOn = true,
    this.immersiveByDefault = false,
    this.defaultReadingMode = ReadingMode.smart,
    this.ttsSpeed = 1.0,
    this.ttsVoiceId,
    this.ttsPitch = 1.0,
    this.sleepTimer,
    this.updatedAt,
  });

  // ── Typography ─────────────────────────────────────────────────────────
  final String fontFamily; // Serif, Sans, Roboto, Georgia, Merriweather, …
  final double fontSizeSp;
  final int fontWeight; // 100–900
  final double lineHeight;
  final double paragraphSpacing;
  final double horizontalMargin;
  final ReadingTextAlign textAlign;

  // ── Appearance ─────────────────────────────────────────────────────────
  final ReadingTheme theme;
  final PageNavigation pageNavigation;

  /// In-reader brightness override (0.0–1.0). `null` = follow system.
  final double? brightnessOverride;
  final bool keepScreenOn;
  final bool immersiveByDefault;
  final ReadingMode defaultReadingMode;

  // ── Text-to-speech ─────────────────────────────────────────────────────
  final double ttsSpeed;
  final String? ttsVoiceId;
  final double ttsPitch;

  /// Auto-stop TTS after this duration. `null` = no timer.
  final Duration? sleepTimer;

  final DateTime? updatedAt;

  ReadingSettings copyWith({
    String? fontFamily,
    double? fontSizeSp,
    int? fontWeight,
    double? lineHeight,
    double? paragraphSpacing,
    double? horizontalMargin,
    ReadingTextAlign? textAlign,
    ReadingTheme? theme,
    PageNavigation? pageNavigation,
    double? brightnessOverride,
    bool? keepScreenOn,
    bool? immersiveByDefault,
    ReadingMode? defaultReadingMode,
    double? ttsSpeed,
    String? ttsVoiceId,
    double? ttsPitch,
    Duration? sleepTimer,
    DateTime? updatedAt,
  }) {
    return ReadingSettings(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSizeSp: fontSizeSp ?? this.fontSizeSp,
      fontWeight: fontWeight ?? this.fontWeight,
      lineHeight: lineHeight ?? this.lineHeight,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      horizontalMargin: horizontalMargin ?? this.horizontalMargin,
      textAlign: textAlign ?? this.textAlign,
      theme: theme ?? this.theme,
      pageNavigation: pageNavigation ?? this.pageNavigation,
      brightnessOverride: brightnessOverride ?? this.brightnessOverride,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      immersiveByDefault: immersiveByDefault ?? this.immersiveByDefault,
      defaultReadingMode: defaultReadingMode ?? this.defaultReadingMode,
      ttsSpeed: ttsSpeed ?? this.ttsSpeed,
      ttsVoiceId: ttsVoiceId ?? this.ttsVoiceId,
      ttsPitch: ttsPitch ?? this.ttsPitch,
      sleepTimer: sleepTimer ?? this.sleepTimer,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
