import 'enums.dart';

/// The precise location a reader last stopped at, per book.
///
/// Progress is intentionally granular: [charOffset] and [cfi] allow resuming at
/// the exact sentence even after font/size changes reflow the page differently.
/// This entity is the unit of the "Continue from page X?" multi-device prompt.
class ReadingProgress {
  const ReadingProgress({
    required this.bookId,
    required this.updatedAt,
    required this.deviceId,
    this.page = 0,
    this.percent = 0.0,
    this.charOffset,
    this.cfi,
    this.chapterId,
    this.mode = ReadingMode.smart,
    this.ttsSentenceIndex,
  });

  final String bookId;

  /// Page index in Original Mode (0-based).
  final int page;

  /// Fraction read, 0.0–1.0. Canonical progress value shown in the library.
  final double percent;

  /// Character offset into the reflowed text stream (Smart Mode resume point).
  final int? charOffset;

  /// EPUB-style Canonical Fragment Identifier for robust cross-render resume.
  final String? cfi;

  final String? chapterId;
  final ReadingMode mode;

  /// Sentence index the TTS engine last spoke, so playback can resume exactly.
  final int? ttsSentenceIndex;

  /// Last-write-wins timestamp used by the conflict resolver.
  final DateTime updatedAt;

  /// Which device produced this progress (drives the cross-device prompt).
  final String deviceId;

  ReadingProgress copyWith({
    int? page,
    double? percent,
    int? charOffset,
    String? cfi,
    String? chapterId,
    ReadingMode? mode,
    int? ttsSentenceIndex,
    DateTime? updatedAt,
    String? deviceId,
  }) {
    return ReadingProgress(
      bookId: bookId,
      page: page ?? this.page,
      percent: percent ?? this.percent,
      charOffset: charOffset ?? this.charOffset,
      cfi: cfi ?? this.cfi,
      chapterId: chapterId ?? this.chapterId,
      mode: mode ?? this.mode,
      ttsSentenceIndex: ttsSentenceIndex ?? this.ttsSentenceIndex,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  /// `true` when [other] represents a strictly newer position from a *different*
  /// device — the condition that triggers the resume prompt.
  bool isSupersededBy(ReadingProgress other) =>
      other.bookId == bookId &&
      other.deviceId != deviceId &&
      other.updatedAt.isAfter(updatedAt) &&
      (other.percent - percent).abs() > 0.001;
}
