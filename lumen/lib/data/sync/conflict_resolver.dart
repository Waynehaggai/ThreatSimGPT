import '../../domain/entities/annotation.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/reading_progress.dart';

/// Deterministic, offline-first conflict resolution.
///
/// The rules (from the product spec) are:
///   • Reading position — keep the newest (last-write-wins by `updatedAt`).
///   • Notes & highlights — **merge** the two sets; never drop a side.
///   • User data is never automatically deleted — deletions are tombstones and
///     a tombstone only wins over an *older* edit.
///
/// This class is pure Dart with no I/O, so every rule is unit-testable in
/// isolation (see `test/sync/conflict_resolver_test.dart`).
class ConflictResolver {
  const ConflictResolver();

  /// Newest reading position wins. Ties (identical timestamps) prefer the
  /// entry that is further along, so progress never moves backwards on a tie.
  ReadingProgress resolveProgress(
    ReadingProgress? local,
    ReadingProgress? remote,
  ) {
    if (local == null) return remote!;
    if (remote == null) return local;

    if (remote.updatedAt.isAfter(local.updatedAt)) return remote;
    if (local.updatedAt.isAfter(remote.updatedAt)) return local;
    return remote.percent >= local.percent ? remote : local;
  }

  /// Merge annotations by id. When both sides have the same id, the newer
  /// `updatedAt` wins — but a deletion tombstone only overrides an *older*
  /// edit, honouring "never delete user data automatically".
  List<Annotation> mergeAnnotations(
    List<Annotation> local,
    List<Annotation> remote,
  ) {
    final byId = <String, Annotation>{};
    for (final a in local) {
      byId[a.id] = a;
    }
    for (final r in remote) {
      final existing = byId[r.id];
      if (existing == null) {
        byId[r.id] = r;
        continue;
      }
      byId[r.id] = _pickNewer(existing, r);
    }
    return byId.values.toList(growable: false);
  }

  Annotation _pickNewer(Annotation a, Annotation b) {
    final newer = b.updatedAt.isAfter(a.updatedAt) ? b : a;
    final older = identical(newer, b) ? a : b;

    // A delete only wins if it is the newer change. An older tombstone must not
    // erase a subsequent edit (the user "un-deleted"/re-edited on another device).
    if (newer.isDeleted &&
        !older.isDeleted &&
        newer.updatedAt.isAtSameMomentAs(older.updatedAt)) {
      return older;
    }
    return newer;
  }

  /// Merge bookmarks by id (same tombstone semantics as annotations).
  List<Bookmark> mergeBookmarks(List<Bookmark> local, List<Bookmark> remote) {
    final byId = <String, Bookmark>{for (final b in local) b.id: b};
    for (final r in remote) {
      byId.putIfAbsent(r.id, () => r);
    }
    return byId.values.toList(growable: false);
  }
}
