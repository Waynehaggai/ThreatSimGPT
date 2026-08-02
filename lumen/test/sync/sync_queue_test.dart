import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/sync/sync_queue.dart';
import 'package:lumen/domain/entities/enums.dart';
import 'package:lumen/domain/entities/sync_operation.dart';

void main() {
  SyncOperation op(
    String id, {
    SyncAction action = SyncAction.update,
    String entityId = 'e1',
    DateTime? created,
  }) =>
      SyncOperation(
        id: id,
        entityType: SyncEntityType.progress,
        entityId: entityId,
        action: action,
        createdAt: created ?? DateTime(2026, 1, 1),
      );

  test('collapses redundant pending updates to the same entity', () {
    final queue = SyncQueue([])
      ..enqueue(op('1'))
      ..enqueue(op('2'));
    expect(queue.pendingCount, 1);
    expect(queue.all.single.id, '2');
  });

  test('does not collapse updates to different entities', () {
    final queue = SyncQueue([])
      ..enqueue(op('1', entityId: 'a'))
      ..enqueue(op('2', entityId: 'b'));
    expect(queue.pendingCount, 2);
  });

  test('dueOperations respects backoff gates', () {
    final now = DateTime(2026, 1, 1, 12);
    final queue = SyncQueue([op('1')]);
    queue.fail('1', 'network', now);

    // Immediately after failure, the op is gated by backoff.
    expect(queue.dueOperations(now), isEmpty);
    // After the backoff window it becomes due again.
    expect(
      queue.dueOperations(now.add(const Duration(seconds: 3))),
      isNotEmpty,
    );
  });

  test('exponential backoff grows with retry count', () {
    final now = DateTime(2026, 1, 1, 12);
    final queue = SyncQueue([op('1')]);
    queue
      ..fail('1', 'e', now)
      ..fail('1', 'e', now)
      ..fail('1', 'e', now);
    final only = queue.all.single;
    expect(only.retryCount, 3);
    expect(only.backoff, const Duration(seconds: 8)); // 2^3
  });

  test('completed operations leave the queue', () {
    final queue = SyncQueue([op('1')])..complete('1');
    expect(queue.pendingCount, 0);
  });
}
