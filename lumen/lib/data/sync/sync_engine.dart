import 'dart:async';

import '../../core/result/result.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/sync_operation.dart';
import '../../domain/repositories/sync_repository.dart';
import 'local_merge_sink.dart';
import 'remote_data_source.dart';
import 'sync_queue.dart';
import 'sync_queue_store.dart';

/// The offline-first synchronization engine ([SyncRepository]).
///
/// Drains the durable [SyncQueueStore] to a [RemoteDataSource] whenever the
/// device is online, applying per-operation exponential backoff (via the pure,
/// tested [SyncQueue]) and pulling remote changes through a [LocalMergeSink].
///
/// It is deliberately decoupled from Firebase and the local DB — both arrive as
/// injected interfaces — so the whole push/backoff/state machine is unit-tested
/// with in-memory fakes (see `test/sync/sync_engine_test.dart`).
class SyncEngine implements SyncRepository {
  SyncEngine({
    required SyncQueueStore queue,
    required RemoteDataSource remote,
    required Future<bool> Function() isOnline,
    Stream<bool>? onlineChanges,
    LocalMergeSink mergeSink = const NoopLocalMergeSink(),
    DateTime Function() now = DateTime.now,
  })  : _queue = queue,
        _remote = remote,
        _isOnline = isOnline,
        _mergeSink = mergeSink,
        _now = now {
    _online = onlineChanges?.listen((online) {
      if (online) unawaited(syncNow()); // flush on regaining connectivity
    });
    _queue.watchPendingCount().listen((count) {
      _emit(_current.copyWith(pendingCount: count));
    });
  }

  final SyncQueueStore _queue;
  final RemoteDataSource _remote;
  final Future<bool> Function() _isOnline;
  final LocalMergeSink _mergeSink;
  final DateTime Function() _now;
  final _log = AppLogger('sync');

  final _stateController = StreamController<SyncState>.broadcast();
  SyncState _current = const SyncState();
  StreamSubscription<bool>? _online;
  DateTime? _watermark;
  bool _running = false;

  void _emit(SyncState state) {
    _current = state;
    if (!_stateController.isClosed) _stateController.add(state);
  }

  @override
  Stream<SyncState> watchState() async* {
    yield _current;
    yield* _stateController.stream;
  }

  @override
  Stream<List<SyncOperation>> watchQueue() async* {
    yield await _queue.pending();
    yield* _queue.watchPendingCount().asyncMap((_) => _queue.pending());
  }

  @override
  Future<Result<void>> enqueue(SyncOperation operation) async {
    await _queue.add(operation);
    unawaited(syncNow()); // opportunistic; safe no-op when offline
    return const Result.success(null);
  }

  @override
  Future<Result<void>> syncNow() async {
    if (_running) return const Result.success(null);
    _running = true;
    try {
      if (!await _isOnline()) {
        _emit(_current.copyWith(status: SyncStatus.offline));
        return const Result.success(null);
      }
      _emit(_current.copyWith(status: SyncStatus.syncing));

      await _push();
      await _pull();

      _emit(
        SyncState(
          status: SyncStatus.idle,
          pendingCount: (await _queue.pending()).length,
          lastSyncedAt: _now(),
        ),
      );
      return const Result.success(null);
    } on Object catch (e, s) {
      _log.error('Sync cycle failed', e, s);
      _emit(_current.copyWith(status: SyncStatus.error, message: '$e'));
      return const Result.success(null); // failures are retried, never fatal
    } finally {
      _running = false;
    }
  }

  Future<void> _push() async {
    final scheduler = SyncQueue(await _queue.pending());
    final now = _now();
    for (final op in scheduler.dueOperations(now)) {
      try {
        await _apply(op);
        await _queue.remove(op.id);
      } on Object catch (e) {
        scheduler.fail(op.id, e, now);
        final updated = scheduler.all.firstWhere(
          (o) => o.id == op.id,
          orElse: () => op,
        );
        await _queue.saveState(updated);
        _log.warning('Push failed for ${op.entityType.name}:${op.entityId}', e);
      }
    }
  }

  Future<void> _apply(SyncOperation op) async {
    switch (op.action) {
      case SyncAction.delete:
        await _remote.remove(op.entityType, op.entityId);
      case SyncAction.create:
      case SyncAction.update:
        await _remote.push(op.entityType, op.entityId, op.payload ?? const {});
    }
  }

  Future<void> _pull() async {
    final changes = await _remote.pullSince(_watermark);
    if (changes.isEmpty) return;
    await _mergeSink.apply(changes);
    // Advance the watermark to the newest change seen.
    for (final c in changes) {
      if (_watermark == null || c.updatedAt.isAfter(_watermark!)) {
        _watermark = c.updatedAt;
      }
    }
  }

  @override
  Future<Result<void>> flushBeforeLogout() => syncNow();

  Future<void> dispose() async {
    await _online?.cancel();
    await _stateController.close();
  }
}
