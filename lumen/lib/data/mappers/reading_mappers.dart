import 'dart:convert';

import '../../domain/entities/reading_progress.dart';
import '../../domain/entities/reading_settings.dart';
import '../../domain/entities/reading_stats.dart';
import '../local/isar_ids.dart';
import '../local/models/reading_models.dart';

extension ProgressModelMapper on ProgressModel {
  ReadingProgress toEntity() => ReadingProgress(
        bookId: bookId,
        updatedAt: updatedAt,
        deviceId: deviceId,
        page: page,
        percent: percent,
        charOffset: charOffset,
        cfi: cfi,
        chapterId: chapterId,
        mode: mode,
        ttsSentenceIndex: ttsSentenceIndex,
      );
}

extension ProgressEntityMapper on ReadingProgress {
  ProgressModel toModel() => ProgressModel()
    ..id = fastHash(bookId)
    ..bookId = bookId
    ..page = page
    ..percent = percent
    ..charOffset = charOffset
    ..cfi = cfi
    ..chapterId = chapterId
    ..mode = mode
    ..ttsSentenceIndex = ttsSentenceIndex
    ..updatedAt = updatedAt
    ..deviceId = deviceId;
}

extension SettingsModelMapper on SettingsModel {
  ReadingSettings toEntity() => ReadingSettings(
        fontFamily: fontFamily,
        fontSizeSp: fontSizeSp,
        fontWeight: fontWeight,
        lineHeight: lineHeight,
        paragraphSpacing: paragraphSpacing,
        horizontalMargin: horizontalMargin,
        textAlign: textAlign,
        theme: theme,
        pageNavigation: pageNavigation,
        brightnessOverride: brightnessOverride,
        keepScreenOn: keepScreenOn,
        immersiveByDefault: immersiveByDefault,
        defaultReadingMode: defaultReadingMode,
        ttsSpeed: ttsSpeed,
        ttsVoiceId: ttsVoiceId,
        ttsPitch: ttsPitch,
        sleepTimer: sleepTimerSeconds == null
            ? null
            : Duration(seconds: sleepTimerSeconds!),
        updatedAt: updatedAt,
      );
}

extension SettingsEntityMapper on ReadingSettings {
  SettingsModel toModel() => SettingsModel()
    ..id = SettingsModel.singletonId
    ..fontFamily = fontFamily
    ..fontSizeSp = fontSizeSp
    ..fontWeight = fontWeight
    ..lineHeight = lineHeight
    ..paragraphSpacing = paragraphSpacing
    ..horizontalMargin = horizontalMargin
    ..textAlign = textAlign
    ..theme = theme
    ..pageNavigation = pageNavigation
    ..brightnessOverride = brightnessOverride
    ..keepScreenOn = keepScreenOn
    ..immersiveByDefault = immersiveByDefault
    ..defaultReadingMode = defaultReadingMode
    ..ttsSpeed = ttsSpeed
    ..ttsVoiceId = ttsVoiceId
    ..ttsPitch = ttsPitch
    ..sleepTimerSeconds = sleepTimer?.inSeconds
    ..updatedAt = updatedAt;
}

extension StatsModelMapper on StatsModel {
  ReadingStats toEntity() => ReadingStats(
        booksCompleted: booksCompleted,
        pagesRead: pagesRead,
        secondsRead: secondsRead,
        currentStreakDays: currentStreakDays,
        longestStreakDays: longestStreakDays,
        dailyGoalMinutes: dailyGoalMinutes,
        wordsPerMinute: wordsPerMinute,
        minutesByHour: minutesByHour,
        genreMinutes: _decodeGenres(genreMinutesJson),
        lastReadDate: lastReadDate,
      );

  static Map<String, int> _decodeGenres(String json) {
    if (json.isEmpty) return const {};
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
  }
}

extension StatsEntityMapper on ReadingStats {
  StatsModel toModel() => StatsModel()
    ..id = StatsModel.singletonId
    ..booksCompleted = booksCompleted
    ..pagesRead = pagesRead
    ..secondsRead = secondsRead
    ..currentStreakDays = currentStreakDays
    ..longestStreakDays = longestStreakDays
    ..dailyGoalMinutes = dailyGoalMinutes
    ..wordsPerMinute = wordsPerMinute
    ..minutesByHour = minutesByHour
    ..genreMinutesJson = jsonEncode(genreMinutes)
    ..lastReadDate = lastReadDate;
}
