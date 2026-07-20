import 'package:isar_community/isar.dart';

import '../../domain/entities/enums.dart';
import '../../domain/entities/reading_progress.dart';
import '../local/models/reading_models.dart';
import '../mappers/reading_mappers.dart';
import 'conflict_resolver.dart';
import 'local_merge_sink.dart';
import 'remote_data_source.dart';

/// Parses a remote progress document into a [ReadingProgress].
///
/// Pure (no Isar), so the deserialization is unit-tested. Mirrors the payload
/// the progress repository pushes (`percent`, `page`, `deviceId`) plus the
/// document's `updatedAt` (carried on the [RemoteChange]).
ReadingProgress? progressFromRemote(RemoteChange change) {
  if (change.type != SyncEntityType.progress) return null;
  final data = change.data;
  return ReadingProgress(
    bookId: change.id,
    updatedAt: change.updatedAt,
    deviceId: '${data['deviceId'] ?? ''}',
    percent: (data['percent'] as num?)?.toDouble() ?? 0.0,
    page: (data['page'] as num?)?.toInt() ?? 0,
  );
}

/// Applies pulled remote changes into the local Isar DB with conflict
/// resolution.
///
/// Reading **progress** is fully merged here (newest position wins via
/// [ConflictResolver]) — the headline cross-device behaviour. Annotations,
/// bookmarks, collections and settings require full-entity payloads in the sync
/// documents (tracked follow-up); until then they are skipped rather than
/// written from partial data, so a pull can never clobber richer local records.
class IsarLocalMergeSink implements LocalMergeSink {
  IsarLocalMergeSink(this._isar,
      {ConflictResolver resolver = const ConflictResolver()})
      : _resolver = resolver;

  final Isar _isar;
  final ConflictResolver _resolver;

  @override
  Future<void> apply(List<RemoteChange> changes) async {
    for (final change in changes) {
      if (change.type != SyncEntityType.progress) continue;
      final remote = progressFromRemote(change);
      if (remote == null) continue;

      final localModel = await _isar.progressModels
          .filter()
          .bookIdEqualTo(change.id)
          .findFirst();
      final local = localModel?.toEntity();
      final winner = _resolver.resolveProgress(local, remote);

      final changed = local == null ||
          winner.updatedAt.isAfter(local.updatedAt) ||
          (winner.percent - local.percent).abs() > 0.0001;
      if (changed) {
        await _isar.writeTxn(() => _isar.progressModels.put(winner.toModel()));
      }
    }
  }
}
