import '../../core/result/result.dart';
import '../entities/reading_stats.dart';

/// A discrete reading session used to update aggregate statistics.
class ReadingSession {
  const ReadingSession({
    required this.bookId,
    required this.startedAt,
    required this.endedAt,
    required this.pagesRead,
    required this.wordsRead,
    this.genre,
    this.completed = false,
  });

  final String bookId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int pagesRead;
  final int wordsRead;
  final String? genre;

  /// `true` if the book was finished during this session (→ books-completed++).
  final bool completed;

  Duration get duration => endedAt.difference(startedAt);
}

/// Contract for reading statistics and goals.
abstract interface class StatisticsRepository {
  Stream<ReadingStats> watchStats();
  Future<ReadingStats> getStats();

  /// Folds a finished [ReadingSession] into the aggregate stats (streaks,
  /// hours, per-hour histogram, genre totals) and persists + enqueues sync.
  Future<Result<void>> recordSession(ReadingSession session);

  Future<Result<void>> setDailyGoalMinutes(int minutes);
}
