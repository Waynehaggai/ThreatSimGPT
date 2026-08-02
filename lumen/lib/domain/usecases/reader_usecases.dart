import '../../core/constants/app_constants.dart';
import '../../core/result/result.dart';
import '../entities/reading_progress.dart';
import '../repositories/progress_repository.dart';
import 'usecase.dart';

/// Persists the current reading position (debounced by the caller).
class SaveProgress implements UseCase<void, ReadingProgress> {
  const SaveProgress(this._repo);
  final ProgressRepository _repo;

  @override
  Future<Result<void>> call(ReadingProgress progress) =>
      _repo.saveProgress(progress);
}

/// On book open, checks whether another device has a newer position and, if so,
/// returns it so the UI can prompt "Continue from page X?".
class ResolveResumePoint implements UseCase<ResumeDecision, String> {
  const ResolveResumePoint(this._repo);
  final ProgressRepository _repo;

  @override
  Future<Result<ResumeDecision>> call(String bookId) async {
    final localResult = await _repo.getProgress(bookId);
    if (localResult.isFailure) {
      return Result.failure(localResult.failureOrNull!);
    }
    final local = localResult.valueOrNull;

    final remoteResult = await _repo.checkRemoteNewer(bookId);
    // Offline or no remote is fine — just resume locally.
    final remote = remoteResult.valueOrNull;

    if (remote != null && (local == null || local.isSupersededBy(remote))) {
      return Result.success(
        ResumeDecision(local: local, remoteNewer: remote, promptUser: true),
      );
    }
    return Result.success(ResumeDecision(local: local, promptUser: false));
  }
}

/// Outcome of [ResolveResumePoint].
class ResumeDecision {
  const ResumeDecision({this.local, this.remoteNewer, this.promptUser = false});

  final ReadingProgress? local;
  final ReadingProgress? remoteNewer;

  /// When `true`, show the cross-device resume prompt before opening.
  final bool promptUser;
}

/// Estimates remaining reading time from words left and the user's speed.
class EstimateRemainingTime {
  const EstimateRemainingTime();

  Duration call({
    required int wordsRemaining,
    int wordsPerMinute = AppConstants.defaultWordsPerMinute,
  }) {
    if (wordsPerMinute <= 0) return Duration.zero;
    final minutes = wordsRemaining / wordsPerMinute;
    return Duration(seconds: (minutes * 60).round());
  }
}
