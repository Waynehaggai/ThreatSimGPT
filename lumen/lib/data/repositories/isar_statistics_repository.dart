import 'package:isar_community/isar.dart';

import '../../core/error/failures.dart';
import '../../core/result/result.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/reading_stats.dart';
import '../../domain/repositories/statistics_repository.dart';
import '../local/daos/sync_queue_dao.dart';
import '../local/models/reading_models.dart';
import '../mappers/reading_mappers.dart';
import '../stats/stats_aggregator.dart';

/// Isar-backed [StatisticsRepository]. Aggregates are a singleton row synced as
/// one document; each recorded session folds through the pure [applySession].
class IsarStatisticsRepository implements StatisticsRepository {
  IsarStatisticsRepository(this._isar, this._syncQueue);

  final Isar _isar;
  final SyncQueueDao _syncQueue;

  @override
  Stream<ReadingStats> watchStats() {
    return _isar.statsModels
        .watchObject(StatsModel.singletonId, fireImmediately: true)
        .map((model) => model?.toEntity() ?? const ReadingStats());
  }

  @override
  Future<ReadingStats> getStats() async {
    final model = await _isar.statsModels.get(StatsModel.singletonId);
    return model?.toEntity() ?? const ReadingStats();
  }

  @override
  Future<Result<void>> recordSession(ReadingSession session) async {
    try {
      final next = applySession(await getStats(), session);
      await _isar.writeTxn(() => _isar.statsModels.put(next.toModel()));
      await _enqueue();
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(
        StorageFailure('Failed to record session.', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> setDailyGoalMinutes(int minutes) async {
    try {
      final next = (await getStats()).copyWith(dailyGoalMinutes: minutes);
      await _isar.writeTxn(() => _isar.statsModels.put(next.toModel()));
      await _enqueue();
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(StorageFailure('Failed to set goal.', cause: e));
    }
  }

  Future<void> _enqueue() => _syncQueue.enqueue(
        entityType: SyncEntityType.statistics,
        entityId: 'current',
        action: SyncAction.update,
      );
}
