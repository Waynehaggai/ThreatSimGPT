import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/repositories/in_memory_statistics_repository.dart';
import 'package:lumen/domain/repositories/statistics_repository.dart';

void main() {
  late InMemoryStatisticsRepository repo;

  setUp(() => repo = InMemoryStatisticsRepository());

  test('recording a session folds into the aggregate stats', () async {
    await repo.recordSession(ReadingSession(
      bookId: 'b',
      startedAt: DateTime(2026, 1, 1, 8),
      endedAt: DateTime(2026, 1, 1, 8, 30),
      pagesRead: 12,
      wordsRead: 3000,
    ));

    final stats = await repo.getStats();
    expect(stats.pagesRead, 12);
    expect(stats.currentStreakDays, 1);
    expect(stats.minutesToday, 30);
  });

  test('watchStats emits updates as sessions are recorded', () async {
    final future = repo.watchStats().skip(1).first; // skip initial snapshot
    await repo.recordSession(ReadingSession(
      bookId: 'b',
      startedAt: DateTime(2026, 1, 1, 8),
      endedAt: DateTime(2026, 1, 1, 8, 10),
      pagesRead: 3,
      wordsRead: 500,
    ));
    final emitted = await future;
    expect(emitted.pagesRead, 3);
  });

  test('setDailyGoalMinutes updates the goal', () async {
    await repo.setDailyGoalMinutes(45);
    expect((await repo.getStats()).dailyGoalMinutes, 45);
  });
}
