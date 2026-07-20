import 'package:isar_community/isar.dart';

import '../../core/error/failures.dart';
import '../../core/result/result.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/reading_progress.dart';
import '../../domain/repositories/progress_repository.dart';
import '../local/daos/sync_queue_dao.dart';
import '../local/models/reading_models.dart';
import '../mappers/reading_mappers.dart';

/// Isar-backed [ProgressRepository]. One row per book; last-write-wins on sync.
///
/// [checkRemoteNewer] is a no-op until the Firestore data source lands (M6) —
/// it returns success(null) so callers simply resume locally when offline or
/// cloud-less, exactly as the offline-first contract requires.
class IsarProgressRepository implements ProgressRepository {
  IsarProgressRepository(this._isar, this._syncQueue);

  final Isar _isar;
  final SyncQueueDao _syncQueue;

  @override
  Stream<ReadingProgress?> watchProgress(String bookId) {
    return _isar.progressModels
        .filter()
        .bookIdEqualTo(bookId)
        .watch(fireImmediately: true)
        .map((rows) => rows.isEmpty ? null : rows.first.toEntity());
  }

  @override
  Future<Result<ReadingProgress?>> getProgress(String bookId) async {
    try {
      final model =
          await _isar.progressModels.filter().bookIdEqualTo(bookId).findFirst();
      return Result.success(model?.toEntity());
    } on Object catch (e) {
      return Result.failure(
        StorageFailure('Failed to load progress.', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> saveProgress(ReadingProgress progress) async {
    try {
      await _isar.writeTxn(() => _isar.progressModels.put(progress.toModel()));
      await _syncQueue.enqueue(
        entityType: SyncEntityType.progress,
        entityId: progress.bookId,
        action: SyncAction.update,
        payload: {
          'percent': progress.percent,
          'page': progress.page,
          'updatedAt': progress.updatedAt.toIso8601String(),
          'deviceId': progress.deviceId,
        },
      );
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(
        StorageFailure('Failed to save progress.', cause: e),
      );
    }
  }

  @override
  Future<Result<ReadingProgress?>> checkRemoteNewer(String bookId) async {
    // Cloud comparison is wired with the Firestore source in ROADMAP M6.
    return const Result.success(null);
  }
}
