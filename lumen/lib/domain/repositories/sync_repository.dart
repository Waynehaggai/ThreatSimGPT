import '../../core/result/result.dart';
import '../entities/sync_operation.dart';

/// High-level state of the background sync engine, surfaced in the UI.
enum SyncStatus { idle, syncing, offline, error }

class SyncState {
  const SyncState({
    this.status = SyncStatus.idle,
    this.pendingCount = 0,
    this.lastSyncedAt,
    this.message,
  });

  final SyncStatus status;
  final int pendingCount;
  final DateTime? lastSyncedAt;
  final String? message;

  SyncState copyWith({
    SyncStatus? status,
    int? pendingCount,
    DateTime? lastSyncedAt,
    String? message,
  }) {
    return SyncState(
      status: status ?? this.status,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      message: message ?? this.message,
    );
  }
}

/// Contract for the offline-first synchronization engine.
///
/// Local writes enqueue [SyncOperation]s; the engine drains the queue whenever
/// connectivity allows, pushing local changes and pulling remote ones with
/// deterministic conflict resolution (newest reading position wins; notes and
/// highlights merge; user data is never auto-deleted).
abstract interface class SyncRepository {
  Stream<SyncState> watchState();

  /// Enqueue a local mutation for eventual upload.
  Future<Result<void>> enqueue(SyncOperation operation);

  /// Attempt a full push+pull cycle now (no-op when offline).
  Future<Result<void>> syncNow();

  /// Drains the queue and performs a final push; called before logout.
  Future<Result<void>> flushBeforeLogout();

  /// Pending (not-yet-synced) operations, for diagnostics/UI.
  Stream<List<SyncOperation>> watchQueue();
}
