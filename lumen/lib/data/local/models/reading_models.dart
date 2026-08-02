import 'package:isar_community/isar.dart';

import '../../../domain/entities/enums.dart';

part 'reading_models.g.dart';

/// Isar persistence model for [ReadingProgress] (one row per book).
@collection
class ProgressModel {
  Id id = Isar.autoIncrement;

  /// The book uid — one progress record per book.
  @Index(unique: true, replace: true)
  late String bookId;

  late int page;
  late double percent;
  int? charOffset;
  String? cfi;
  String? chapterId;

  @Enumerated(EnumType.name)
  late ReadingMode mode;

  int? ttsSentenceIndex;

  /// Last-write-wins timestamp.
  late DateTime updatedAt;

  /// Device that produced this position (drives the cross-device prompt).
  late String deviceId;
}

/// Isar persistence model for [ReadingSettings] (singleton).
///
/// The whole app has exactly one settings row, stored under [singletonId].
@collection
class SettingsModel {
  /// Fixed id — there is only ever one settings row.
  Id id = singletonId;

  static const Id singletonId = 1;

  late String fontFamily;
  late double fontSizeSp;
  late int fontWeight;
  late double lineHeight;
  late double paragraphSpacing;
  late double horizontalMargin;

  @Enumerated(EnumType.name)
  late ReadingTextAlign textAlign;

  @Enumerated(EnumType.name)
  late ReadingTheme theme;

  @Enumerated(EnumType.name)
  late PageNavigation pageNavigation;

  double? brightnessOverride;
  late bool keepScreenOn;
  late bool immersiveByDefault;

  @Enumerated(EnumType.name)
  late ReadingMode defaultReadingMode;

  late double ttsSpeed;
  String? ttsVoiceId;
  late double ttsPitch;

  /// Sleep timer stored as whole seconds (null = off).
  int? sleepTimerSeconds;

  DateTime? updatedAt;
}

/// Isar persistence model for [ReadingStats] (singleton aggregate).
@collection
class StatsModel {
  Id id = singletonId;

  static const Id singletonId = 1;

  late int booksCompleted;
  late int pagesRead;
  late int secondsRead;
  late int currentStreakDays;
  late int longestStreakDays;
  late int dailyGoalMinutes;
  late int wordsPerMinute;
  int minutesToday = 0;

  /// 24-length histogram of minutes read per hour-of-day.
  late List<int> minutesByHour;

  /// Minutes read per genre, encoded as JSON (Isar has no Map type).
  late String genreMinutesJson;

  DateTime? lastReadDate;
}
