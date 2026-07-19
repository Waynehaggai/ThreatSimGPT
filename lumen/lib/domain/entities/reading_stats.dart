/// Aggregated reading statistics for the current user.
///
/// Updated incrementally from reading sessions and synced as a rolling
/// document. Heavy per-day series are stored separately; this entity holds the
/// headline figures the stats dashboard renders.
class ReadingStats {
  const ReadingStats({
    this.booksCompleted = 0,
    this.pagesRead = 0,
    this.secondsRead = 0,
    this.currentStreakDays = 0,
    this.longestStreakDays = 0,
    this.dailyGoalMinutes = 20,
    this.wordsPerMinute = 238,
    this.minutesToday = 0,
    this.minutesByHour = const <int>[],
    this.genreMinutes = const <String, int>{},
    this.lastReadDate,
  });

  final int booksCompleted;
  final int pagesRead;
  final int secondsRead;
  final int currentStreakDays;
  final int longestStreakDays;
  final int dailyGoalMinutes;

  /// Learned average reading speed, seeds remaining-time estimates.
  final int wordsPerMinute;

  /// Minutes read so far today (reset when [lastReadDate] rolls to a new day).
  final int minutesToday;

  /// 24-length histogram of minutes read per hour-of-day (most productive hours).
  final List<int> minutesByHour;

  /// Minutes read per genre/tag (favorite genres).
  final Map<String, int> genreMinutes;

  final DateTime? lastReadDate;

  Duration get totalTime => Duration(seconds: secondsRead);

  int get hoursRead => secondsRead ~/ 3600;

  /// The most productive hour-of-day (0–23), or `null` with no data.
  int? get peakHour {
    if (minutesByHour.length != 24) return null;
    var best = 0;
    for (var h = 1; h < 24; h++) {
      if (minutesByHour[h] > minutesByHour[best]) best = h;
    }
    return minutesByHour[best] == 0 ? null : best;
  }

  ReadingStats copyWith({
    int? booksCompleted,
    int? pagesRead,
    int? secondsRead,
    int? currentStreakDays,
    int? longestStreakDays,
    int? dailyGoalMinutes,
    int? wordsPerMinute,
    int? minutesToday,
    List<int>? minutesByHour,
    Map<String, int>? genreMinutes,
    DateTime? lastReadDate,
  }) {
    return ReadingStats(
      booksCompleted: booksCompleted ?? this.booksCompleted,
      pagesRead: pagesRead ?? this.pagesRead,
      secondsRead: secondsRead ?? this.secondsRead,
      currentStreakDays: currentStreakDays ?? this.currentStreakDays,
      longestStreakDays: longestStreakDays ?? this.longestStreakDays,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      wordsPerMinute: wordsPerMinute ?? this.wordsPerMinute,
      minutesToday: minutesToday ?? this.minutesToday,
      minutesByHour: minutesByHour ?? this.minutesByHour,
      genreMinutes: genreMinutes ?? this.genreMinutes,
      lastReadDate: lastReadDate ?? this.lastReadDate,
    );
  }
}
