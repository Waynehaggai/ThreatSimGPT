import '../../domain/entities/sync_operation.dart';

/// Durable storage for the offline sync queue, abstracted so the [SyncEngine]
/// can be unit-tested with an in-memory fake while `SyncQueueDao` provides the
/// Isar-backed implementation.
abstract interface class SyncQueueStore {
  /// Persists a new operation (or replaces one with the same id).
  Future<void> add(SyncOperation op);

  /// All not-yet-completed operations, oldest first.
  Future<List<SyncOperation>> pending();

  /// Persists an updated operation (status/backoff changes).
  Future<void> saveState(SyncOperation op);

  /// Removes a completed operation from the queue.
  Future<void> remove(String id);

  /// Reactive count of pending operations, for the sync status UI.
  Stream<int> watchPendingCount();
}
