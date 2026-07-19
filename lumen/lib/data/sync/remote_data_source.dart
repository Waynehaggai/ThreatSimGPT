import '../../domain/entities/enums.dart';

/// One remote change pulled during a sync cycle.
class RemoteChange {
  const RemoteChange({
    required this.type,
    required this.id,
    required this.data,
    required this.updatedAt,
    this.deleted = false,
  });

  final SyncEntityType type;
  final String id;
  final Map<String, dynamic> data;
  final DateTime updatedAt;
  final bool deleted;
}

/// Abstraction over the cloud backend the sync engine pushes to and pulls from.
///
/// Defined as an interface so the engine can be unit-tested with an in-memory
/// fake, while `FirestoreRemoteDataSource` provides the real Cloud Firestore /
/// Storage implementation. All methods are scoped to the signed-in user by the
/// implementation (the engine is user-agnostic).
abstract interface class RemoteDataSource {
  /// Upserts an entity document.
  Future<void> push(SyncEntityType type, String id, Map<String, dynamic> data);

  /// Marks an entity deleted remotely (tombstone).
  Future<void> remove(SyncEntityType type, String id);

  /// Uploads a book's original file blob, returning its remote reference.
  Future<String> uploadBookFile(String bookId, String localPath);

  /// Pulls remote changes with `updatedAt` strictly after [since]
  /// (all changes when [since] is null).
  Future<List<RemoteChange>> pullSince(DateTime? since);
}

/// A no-op remote used as the default (offline / no Firebase configured):
/// local writes still queue, but nothing uploads until a real backend is wired.
class NoopRemoteDataSource implements RemoteDataSource {
  const NoopRemoteDataSource();

  @override
  Future<void> push(SyncEntityType type, String id, Map<String, dynamic> data) async {}

  @override
  Future<void> remove(SyncEntityType type, String id) async {}

  @override
  Future<String> uploadBookFile(String bookId, String localPath) async => localPath;

  @override
  Future<List<RemoteChange>> pullSince(DateTime? since) async => const [];
}
