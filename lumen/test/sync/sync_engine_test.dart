import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/sync/remote_data_source.dart';
import 'package:lumen/data/sync/sync_engine.dart';
import 'package:lumen/data/sync/sync_queue_store.dart';
import 'package:lumen/domain/entities/enums.dart';
import 'package:lumen/domain/entities/sync_operation.dart';

/// In-memory queue store.
class FakeQueueStore implements SyncQueueStore {
  FakeQueueStore([List<SyncOperation>? initial]) {
    for (final op in initial ?? const <SyncOperation>[]) {
      _ops[op.id] = op;
    }
  }
  final Map<String, SyncOperation> _ops = {};
  final _counts = StreamController<int>.broadcast();

  void _emit() => _counts.add(_ops.length);

  @override
  Future<void> add(SyncOperation op) async {
    _ops[op.id] = op;
    _emit();
  }

  @override
  Future<List<SyncOperation>> pending() async =>
      _ops.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  @override
  Future<void> saveState(SyncOperation op) async {
    _ops[op.id] = op;
    _emit();
  }

  @override
  Future<void> remove(String id) async {
    _ops.remove(id);
    _emit();
  }

  @override
  Stream<int> watchPendingCount() => _counts.stream;
}

/// Records pushes; can be told to fail for specific entity ids.
class RecordingRemote implements RemoteDataSource {
  RecordingRemote({this.failFor = const {}});
  final Set<String> failFor;
  final List<String> pushed = [];
  final List<String> removed = [];

  @override
  Future<void> push(
    SyncEntityType type,
    String id,
    Map<String, dynamic> data,
  ) async {
    if (failFor.contains(id)) throw Exception('boom');
    pushed.add(id);
  }

  @override
  Future<void> remove(SyncEntityType type, String id) async => removed.add(id);

  @override
  Future<String> uploadBookFile(String bookId, String localPath) async =>
      localPath;

  @override
  Future<List<RemoteChange>> pullSince(DateTime? since) async => const [];
}

SyncOperation op(String id, {SyncAction action = SyncAction.update}) =>
    SyncOperation(
      id: id,
      entityType: SyncEntityType.progress,
      entityId: id,
      action: action,
      createdAt: DateTime(2026).add(Duration(seconds: id.hashCode % 100)),
      payload: const {'percent': 0.5},
    );

void main() {
  test('pushes all due operations and clears them when online', () async {
    final store = FakeQueueStore([op('a'), op('b')]);
    final remote = RecordingRemote();
    final engine = SyncEngine(
      queue: store,
      remote: remote,
      isOnline: () async => true,
    );

    await engine.syncNow();

    expect(remote.pushed.toSet(), {'a', 'b'});
    expect(await store.pending(), isEmpty);
    await engine.dispose();
  });

  test('a failed push is retained with backoff; others still clear', () async {
    final store = FakeQueueStore([op('ok'), op('bad')]);
    final remote = RecordingRemote(failFor: {'bad'});
    final engine = SyncEngine(
      queue: store,
      remote: remote,
      isOnline: () async => true,
    );

    await engine.syncNow();

    expect(remote.pushed, contains('ok'));
    final remaining = await store.pending();
    expect(remaining.map((o) => o.id), ['bad']);
    expect(remaining.single.status, SyncOperationStatus.failed);
    expect(remaining.single.retryCount, 1);
    expect(remaining.single.nextAttemptAt, isNotNull);
    await engine.dispose();
  });

  test(
    'does nothing and reports offline when there is no connection',
    () async {
      final store = FakeQueueStore([op('a')]);
      final remote = RecordingRemote();
      final engine = SyncEngine(
        queue: store,
        remote: remote,
        isOnline: () async => false,
      );

      await engine.syncNow();

      expect(remote.pushed, isEmpty);
      expect(await store.pending(), hasLength(1));
      final state = await engine.watchState().first;
      expect(state.status, SyncStatus.offline);
      await engine.dispose();
    },
  );

  test('delete operations call remote.remove (tombstone)', () async {
    final store = FakeQueueStore([op('gone', action: SyncAction.delete)]);
    final remote = RecordingRemote();
    final engine = SyncEngine(
      queue: store,
      remote: remote,
      isOnline: () async => true,
    );

    await engine.syncNow();

    expect(remote.removed, ['gone']);
    expect(await store.pending(), isEmpty);
    await engine.dispose();
  });

  test('enqueue persists and triggers a push', () async {
    final store = FakeQueueStore();
    final remote = RecordingRemote();
    final engine = SyncEngine(
      queue: store,
      remote: remote,
      isOnline: () async => true,
    );

    await engine.enqueue(op('new'));
    // enqueue triggers syncNow asynchronously; allow it to run.
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(remote.pushed, contains('new'));
    await engine.dispose();
  });
}
