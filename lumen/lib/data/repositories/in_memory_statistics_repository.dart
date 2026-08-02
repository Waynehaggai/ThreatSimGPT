import 'dart:async';

import '../../core/result/result.dart';
import '../../domain/entities/reading_stats.dart';
import '../../domain/repositories/statistics_repository.dart';
import '../stats/stats_aggregator.dart';

/// Pure-Dart [StatisticsRepository] (default + tests): folds sessions in memory
/// via [applySession]. Production uses `IsarStatisticsRepository`.
class InMemoryStatisticsRepository implements StatisticsRepository {
  InMemoryStatisticsRepository([ReadingStats? initial])
      : _stats = initial ?? const ReadingStats();

  ReadingStats _stats;
  final _controller = StreamController<ReadingStats>.broadcast();

  @override
  Stream<ReadingStats> watchStats() {
    // Subscribe to updates synchronously on listen (before returning control to
    // the caller) and emit the current snapshot, so an update recorded right
    // after subscribing can't slip through the gap an `async*` generator leaves
    // between yielding the snapshot and subscribing to the broadcast stream.
    final out = StreamController<ReadingStats>();
    StreamSubscription<ReadingStats>? sub;
    out.onListen = () {
      out.add(_stats);
      sub = _controller.stream.listen(out.add, onError: out.addError);
    };
    out.onCancel = () async => sub?.cancel();
    return out.stream;
  }

  @override
  Future<ReadingStats> getStats() async => _stats;

  @override
  Future<Result<void>> recordSession(ReadingSession session) async {
    _stats = applySession(_stats, session);
    _controller.add(_stats);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> setDailyGoalMinutes(int minutes) async {
    _stats = _stats.copyWith(dailyGoalMinutes: minutes);
    _controller.add(_stats);
    return const Result.success(null);
  }
}
