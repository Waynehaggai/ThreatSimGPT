import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/stats/stats_aggregator.dart';
import 'package:lumen/domain/entities/reading_stats.dart';
import 'package:lumen/domain/repositories/statistics_repository.dart';

void main() {
  ReadingSession session(
    DateTime start,
    DateTime end, {
    int pages = 0,
    int words = 0,
    bool completed = false,
  }) =>
      ReadingSession(
        bookId: 'b',
        startedAt: start,
        endedAt: end,
        pagesRead: pages,
        wordsRead: words,
        completed: completed,
      );

  test('first session starts a streak and accumulates time/pages', () {
    final s = applySession(
      const ReadingStats(),
      session(DateTime(2026, 1, 1, 8, 30), DateTime(2026, 1, 1, 9),
          pages: 20, words: 6000),
    );
    expect(s.currentStreakDays, 1);
    expect(s.longestStreakDays, 1);
    expect(s.secondsRead, 1800);
    expect(s.pagesRead, 20);
    expect(s.minutesToday, 30);
    expect(s.minutesByHour[9], 30);
    // EMA from 238 toward observed 200 wpm.
    expect(s.wordsPerMinute, 230);
  });

  test('second session same day keeps the streak, adds minutes-today', () {
    var s = applySession(const ReadingStats(),
        session(DateTime(2026, 1, 1, 8, 30), DateTime(2026, 1, 1, 9)));
    s = applySession(
        s, session(DateTime(2026, 1, 1, 19, 50), DateTime(2026, 1, 1, 20)));
    expect(s.currentStreakDays, 1);
    expect(s.minutesToday, 40);
    expect(s.minutesByHour[9], 30);
    expect(s.minutesByHour[20], 10);
  });

  test('reading the next day increments the streak and resets minutes-today', () {
    var s = applySession(const ReadingStats(),
        session(DateTime(2026, 1, 1, 8), DateTime(2026, 1, 1, 8, 30)));
    s = applySession(
        s, session(DateTime(2026, 1, 2, 10), DateTime(2026, 1, 2, 10, 20)));
    expect(s.currentStreakDays, 2);
    expect(s.longestStreakDays, 2);
    expect(s.minutesToday, 20);
  });

  test('a gap of more than one day resets the streak (keeps longest)', () {
    const base = ReadingStats(
      currentStreakDays: 3,
      longestStreakDays: 3,
    );
    final s = applySession(
      base.copyWith(lastReadDate: DateTime(2026, 1, 1)),
      session(DateTime(2026, 1, 5, 9), DateTime(2026, 1, 5, 9, 30)),
    );
    expect(s.currentStreakDays, 1);
    expect(s.longestStreakDays, 3);
  });

  test('completed sessions increment books completed', () {
    final s = applySession(
      const ReadingStats(),
      session(DateTime(2026, 1, 1, 8), DateTime(2026, 1, 1, 8, 20),
          completed: true),
    );
    expect(s.booksCompleted, 1);
  });
}
