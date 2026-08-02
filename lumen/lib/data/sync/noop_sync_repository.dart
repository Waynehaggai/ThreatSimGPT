import '../../core/result/result.dart';
import '../../domain/entities/sync_operation.dart';
import '../../domain/repositories/sync_repository.dart';

/// Inert [SyncRepository] used when no cloud backend is configured.
///
/// The app is offline-first, so with sync disabled everything still works
/// locally — this simply reports an idle/offline status and accepts (drops)
/// enqueue calls. Production overrides it with [SyncEngine].
class NoopSyncRepository implements SyncRepository {
  const NoopSyncRepository();

  @override
  Stream<SyncState> watchState() =>
      Stream.value(const SyncState(status: SyncStatus.offline));

  @override
  Stream<List<SyncOperation>> watchQueue() => Stream.value(const []);

  @override
  Future<Result<void>> enqueue(SyncOperation operation) async =>
      const Result.success(null);

  @override
  Future<Result<void>> syncNow() async => const Result.success(null);

  @override
  Future<Result<void>> flushBeforeLogout() async => const Result.success(null);
}
