import 'remote_data_source.dart';

/// Applies pulled remote changes into the local database with conflict
/// resolution (newest reading position wins; notes/highlights merge; deletions
/// are tombstones). Defined as an interface so the engine stays decoupled from
/// the concrete local stores; the Isar-backed sink plugs in via DI.
abstract interface class LocalMergeSink {
  Future<void> apply(List<RemoteChange> changes);
}

/// Default sink used when no pull-merge target is wired (e.g. offline builds):
/// pulled changes are ignored. Push still works.
class NoopLocalMergeSink implements LocalMergeSink {
  const NoopLocalMergeSink();

  @override
  Future<void> apply(List<RemoteChange> changes) async {}
}
