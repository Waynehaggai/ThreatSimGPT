import 'enums.dart';

/// A single unit of work in the offline sync queue.
///
/// Every local mutation that must reach the cloud is enqueued as a
/// [SyncOperation]. The sync engine drains the queue whenever connectivity is
/// available, applying exponential backoff on failure (see [nextAttemptAt]).
class SyncOperation {
  const SyncOperation({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.createdAt,
    this.status = SyncOperationStatus.pending,
    this.retryCount = 0,
    this.lastError,
    this.nextAttemptAt,
    this.payload,
  });

  final String id;
  final SyncEntityType entityType;

  /// Id of the domain entity this operation mutates.
  final String entityId;
  final SyncAction action;

  final SyncOperationStatus status;
  final int retryCount;
  final String? lastError;

  /// Earliest time this operation may be retried (backoff gate).
  final DateTime? nextAttemptAt;

  /// Optional serialized snapshot of the entity at enqueue time. Progress and
  /// settings ops carry a payload so the queue is self-contained; large blobs
  /// (book files) are uploaded by reference instead.
  final Map<String, dynamic>? payload;

  final DateTime createdAt;

  bool get isRetryable =>
      status == SyncOperationStatus.failed && retryCount < 5;

  /// Backoff schedule: 2^retryCount seconds, capped at 5 minutes.
  Duration get backoff {
    final seconds = 1 << retryCount; // 1,2,4,8,16,32…
    final capped = seconds > 300 ? 300 : seconds;
    return Duration(seconds: capped);
  }

  SyncOperation copyWith({
    SyncOperationStatus? status,
    int? retryCount,
    String? lastError,
    DateTime? nextAttemptAt,
    Map<String, dynamic>? payload,
  }) {
    return SyncOperation(
      id: id,
      entityType: entityType,
      entityId: entityId,
      action: action,
      createdAt: createdAt,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      payload: payload ?? this.payload,
    );
  }
}
