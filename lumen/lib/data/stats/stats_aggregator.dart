import '../../domain/entities/reading_stats.dart';
import '../../domain/repositories/statistics_repository.dart';

/// Folds a finished [ReadingSession] into aggregate [ReadingStats].
///
/// Pure and deterministic (keyed off the session's own timestamps) so all the
/// fiddly rules — streak transitions, per-hour histogram, learned reading speed,
/// daily rollover — are unit-testable without a database.
///
/// Rules:
///  • Streak: same day → unchanged; next day → +1; a gap → reset to 1.
///  • `minutesToday` resets when the calendar day changes.
///  • `minutesByHour[endHour]` accumulates (most-productive-hours histogram).
///  • Reading speed is an exponential moving average of observed WPM.
///  • `booksCompleted` increments only when [bookCompleted] is true.
ReadingStats applySession(
  ReadingStats current,
  ReadingSession session,
) {
  final minutes = (session.duration.inSeconds / 60).round();
  final endDay = _dateOnly(session.endedAt);
  final last = current.lastReadDate == null
      ? null
      : _dateOnly(current.lastReadDate!);

  // Streak + minutes-today rollover.
  int streak;
  int minutesToday;
  if (last == null) {
    streak = 1;
    minutesToday = minutes;
  } else {
    final gap = endDay.difference(last).inDays;
    if (gap == 0) {
      streak = current.currentStreakDays == 0 ? 1 : current.currentStreakDays;
      minutesToday = current.minutesToday + minutes;
    } else if (gap == 1) {
      streak = current.currentStreakDays + 1;
      minutesToday = minutes;
    } else {
      streak = 1; // gap > 1 day (or reading "in the past") resets
      minutesToday = minutes;
    }
  }

  // Per-hour histogram.
  final byHour = current.minutesByHour.length == 24
      ? List<int>.of(current.minutesByHour)
      : List<int>.filled(24, 0);
  byHour[session.endedAt.hour] += minutes;

  // Genre totals.
  final genres = Map<String, int>.of(current.genreMinutes);
  final genre = session.genre;
  if (genre != null && genre.isNotEmpty) {
    genres[genre] = (genres[genre] ?? 0) + minutes;
  }

  // Learned reading speed (EMA) when the sample is meaningful.
  var wpm = current.wordsPerMinute;
  if (minutes > 0 && session.wordsRead > 20) {
    final observed = session.wordsRead / minutes;
    wpm = (0.8 * wpm + 0.2 * observed).round();
  }

  return current.copyWith(
    secondsRead: current.secondsRead + session.duration.inSeconds,
    pagesRead: current.pagesRead + session.pagesRead,
    booksCompleted: current.booksCompleted + (session.completed ? 1 : 0),
    currentStreakDays: streak,
    longestStreakDays:
        streak > current.longestStreakDays ? streak : current.longestStreakDays,
    wordsPerMinute: wpm,
    minutesToday: minutesToday,
    minutesByHour: byHour,
    genreMinutes: genres,
    lastReadDate: session.endedAt,
  );
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
