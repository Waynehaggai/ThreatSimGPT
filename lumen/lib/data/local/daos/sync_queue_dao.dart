import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/enums.dart';
import '../../../domain/entities/sync_operation.dart';
import '../../mappers/sync_mappers.dart';
import '../models/sync_models.dart';

/// Durable, Isar-backed access to the sync queue.
///
/// Repositories call [enqueue] after every local mutation. The sync engine
/// (ROADMAP M6) reads/updates rows here as it drains the queue; `SyncQueue`
/// owns the in-memory scheduling/backoff decisions.
class SyncQueueDao {
  SyncQueueDao(this._isar);

  final Isar _isar;
  static const _uuid = Uuid();

  /// Records an intent to sync a local change. Runs in its own write txn so
  /// callers can fire-and-forget from repository methods.
  Future<void> enqueue({
    required SyncEntityType entityType,
    required String entityId,
    required SyncAction action,
    Map<String, dynamic>? payload,
  }) async {
    final op = SyncOperation(
      id: _uuid.v4(),
      entityType: entityType,
      entityId: entityId,
      action: action,
      createdAt: DateTime.now(),
      payload: payload,
    );
    await _isar.writeTxn(() async {
      await _isar.syncOperationModels.put(op.toModel());
    });
  }

  /// All not-yet-completed operations, oldest first.
  Future<List<SyncOperation>> pending() async {
    final rows = await _isar.syncOperationModels
        .filter()
        .not()
        .statusEqualTo(SyncOperationStatus.completed)
        .sortByCreatedAt()
        .findAll();
    return rows.map((m) => m.toEntity()).toList();
  }

  Stream<int> watchPendingCount() {
    return _isar.syncOperationModels
        .filter()
        .not()
        .statusEqualTo(SyncOperationStatus.completed)
        .watch(fireImmediately: true)
        .map((rows) => rows.length);
  }

  Future<void> saveState(SyncOperation op) async {
    await _isar.writeTxn(() async {
      await _isar.syncOperationModels.put(op.toModel());
    });
  }
}
