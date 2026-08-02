import 'dart:async';

import '../../core/result/result.dart';
import '../../domain/entities/reading_progress.dart';
import '../../domain/repositories/progress_repository.dart';

/// Pure-Dart [ProgressRepository] used as the default (and in tests), so the
/// reader's resume/position tracking works without Isar configured. Production
/// swaps in `IsarProgressRepository` via the DI bootstrap.
class InMemoryProgressRepository implements ProgressRepository {
  final Map<String, ReadingProgress> _byBook = {};
  final Map<String, StreamController<ReadingProgress?>> _controllers = {};

  StreamController<ReadingProgress?> _controllerFor(String bookId) =>
      _controllers.putIfAbsent(
        bookId,
        () => StreamController<ReadingProgress?>.broadcast(),
      );

  @override
  Stream<ReadingProgress?> watchProgress(String bookId) async* {
    yield _byBook[bookId];
    yield* _controllerFor(bookId).stream;
  }

  @override
  Future<Result<ReadingProgress?>> getProgress(String bookId) async =>
      Result.success(_byBook[bookId]);

  @override
  Future<Result<void>> saveProgress(ReadingProgress progress) async {
    _byBook[progress.bookId] = progress;
    _controllerFor(progress.bookId).add(progress);
    return const Result.success(null);
  }

  @override
  Future<Result<ReadingProgress?>> checkRemoteNewer(String bookId) async =>
      const Result.success(null);
}
