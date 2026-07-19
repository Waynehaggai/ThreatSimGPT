import '../../domain/entities/enums.dart';
import '../../domain/entities/sync_operation.dart';

/// In-memory model of the durable sync queue's scheduling logic.
///
/// The persistence of operations lives in the local DB (an Isar collection);
/// this class owns the *ordering and backoff* decisions so they can be unit
/// tested without a database. The real [SyncRepository] delegates scheduling
/// here and persists the resulting state.
class SyncQueue {
  SyncQueue(List<SyncOperation> initial)
      : _ops = {for (final op in initial) op.id: op};

  final Map<String, SyncOperation> _ops;

  List<SyncOperation> get all => _ops.values.toList(growable: false);

  int get pendingCount => _ops.values
      .where((o) => o.status != SyncOperationStatus.completed)
      .length;

  /// Adds an operation, collapsing redundant ones: a newer update to the same
  /// entity supersedes an older still-pending update (keeps the queue small and
  /// avoids uploading stale intermediate states).
  void enqueue(SyncOperation op) {
    final existing = _ops.values.where(
      (o) =>
          o.entityType == op.entityType &&
          o.entityId == op.entityId &&
          o.status == SyncOperationStatus.pending &&
          o.action == SyncAction.update &&
          op.action == SyncAction.update,
    );
    for (final stale in existing.toList()) {
      _ops.remove(stale.id);
    }
    _ops[op.id] = op;
  }

  /// The next batch of operations eligible to run [now], respecting per-op
  /// backoff gates. Returned oldest-first so causal order is preserved.
  List<SyncOperation> dueOperations(DateTime now, {int limit = 25}) {
    final due = _ops.values.where((o) {
      if (o.status == SyncOperationStatus.completed) return false;
      if (o.status == SyncOperationStatus.inFlight) return false;
      final gate = o.nextAttemptAt;
      return gate == null || !gate.isAfter(now);
    }).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return due.take(limit).toList();
  }

  /// Marks an operation completed and drops it from the queue.
  void complete(String id) => _ops.remove(id);

  /// Records a failure, applying exponential backoff for the next attempt.
  void fail(String id, Object error, DateTime now) {
    final op = _ops[id];
    if (op == null) return;
    final retry = op.retryCount + 1;
    final next = op.copyWith(
      status: SyncOperationStatus.failed,
      retryCount: retry,
      lastError: error.toString(),
      nextAttemptAt: now.add(op.backoff),
    );
    _ops[id] = next;
  }

  void markInFlight(String id) {
    final op = _ops[id];
    if (op != null) {
      _ops[id] = op.copyWith(status: SyncOperationStatus.inFlight);
    }
  }
}
