import '../../core/result/result.dart';
import '../entities/reading_progress.dart';

/// Contract for reading/listening progress persistence and cross-device resume.
abstract interface class ProgressRepository {
  Stream<ReadingProgress?> watchProgress(String bookId);

  Future<Result<ReadingProgress?>> getProgress(String bookId);

  /// Persists progress locally immediately and enqueues a sync op. Callers
  /// should debounce (see [AppConstants.progressPersistDebounce]).
  Future<Result<void>> saveProgress(ReadingProgress progress);

  /// Returns remote progress that is newer and from another device — the input
  /// to the "Continue from page X?" prompt. `null` when local is up to date.
  Future<Result<ReadingProgress?>> checkRemoteNewer(String bookId);
}
