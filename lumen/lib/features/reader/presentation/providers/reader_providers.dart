import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/repository_providers.dart';
import '../../../../core/utils/debouncer.dart';
import '../../../../domain/entities/book.dart';
import '../../../../domain/entities/book_content.dart';
import '../../../../domain/entities/enums.dart';
import '../../../../domain/entities/reading_progress.dart';
import '../../../../domain/repositories/library_repository.dart';
import '../../../../domain/repositories/progress_repository.dart';
import '../../../../domain/repositories/statistics_repository.dart';
import '../../../../domain/usecases/reader_usecases.dart';
import '../../../library/presentation/providers/library_providers.dart';
import 'ocr_providers.dart';
import 'sample_content.dart';

/// A stable-per-install device id, driving the cross-device resume prompt.
/// A production build persists this (secure storage / Hive); here it is stable
/// for the app session.
final deviceIdProvider = Provider<String>((_) => const Uuid().v4());

/// Loads the [Book] being read.
final readerBookProvider = FutureProvider.family<Book, String>((ref, id) async {
  final repo = ref.watch(libraryRepositoryProvider);
  final result = await repo.getBook(id);
  return result.fold(
    onSuccess: (book) => book,
    onFailure: (f) => throw Exception(f.message),
  );
});

/// Loads reflowable Smart content for a book.
///
/// Resolution order:
///   1. OCR-generated/corrected content for this session (scanned PDFs);
///   2. parse the real file for any Smart-capable format with extractable text;
///   3. a rich sample document (demo / not-yet-imported books).
///
/// Books flagged `needsOcr` skip step 2 (there is no text layer) and show the
/// sample until the user runs OCR from the reader.
final readerContentProvider = FutureProvider.family<BookContent, String>((
  ref,
  bookId,
) async {
  final book = await ref.watch(readerBookProvider(bookId).future);

  // 1. Session OCR cache wins.
  final ocr = ref.watch(ocrContentProvider(bookId));
  if (ocr != null) return ocr;

  // 2. Parse the real file when it has an extractable text layer.
  if (!book.needsOcr &&
      book.format.supportsSmartMode &&
      File(book.filePath).existsSync()) {
    final result =
        await ref.watch(documentParsingServiceProvider).buildSmartContent(book);
    final content = result.valueOrNull;
    if (content != null && content.chapters.isNotEmpty) return content;
  }

  // 3. Fallback sample.
  return sampleBookContent(book.id, book.title);
});

/// The last-saved position for a book, used to resume exactly.
final readerResumeProvider = FutureProvider.family<ReadingProgress?, String>((
  ref,
  bookId,
) async {
  final result =
      await ref.watch(progressRepositoryProvider).getProgress(bookId);
  return result.valueOrNull;
});

/// Cross-device resume decision: on open, checks whether another device has a
/// newer position (→ "Continue from X%?" prompt) or we simply resume locally.
final resumeDecisionProvider = FutureProvider.family<ResumeDecision, String>((
  ref,
  bookId,
) async {
  final usecase = ResolveResumePoint(ref.watch(progressRepositoryProvider));
  final result = await usecase(bookId);
  return result.valueOrNull ?? const ResumeDecision();
});

/// Transient per-session reader UI state.
class ReaderUiState {
  const ReaderUiState({
    this.immersive = false,
    this.mode = ReadingMode.smart,
    this.percent = 0.0,
    this.charOffset = 0,
    this.chapterId,
  });

  final bool immersive;
  final ReadingMode mode;
  final double percent;
  final int charOffset;
  final String? chapterId;

  ReaderUiState copyWith({
    bool? immersive,
    ReadingMode? mode,
    double? percent,
    int? charOffset,
    String? chapterId,
  }) =>
      ReaderUiState(
        immersive: immersive ?? this.immersive,
        mode: mode ?? this.mode,
        percent: percent ?? this.percent,
        charOffset: charOffset ?? this.charOffset,
        chapterId: chapterId ?? this.chapterId,
      );
}

/// Owns reader UI state and persists reading position (debounced) so the user
/// resumes exactly where they stopped, on this and every other device.
class ReaderController extends FamilyNotifier<ReaderUiState, String> {
  /// How long the chrome (top/bottom bars) stays up before auto-hiding into the
  /// full-screen reading view.
  static const _autoHideAfter = Duration(seconds: 3);

  late final Debouncer _debouncer;
  Timer? _autoHideTimer;

  // Captured at build time so the dispose-time flush never touches `ref` after
  // the provider is disposed (which would throw).
  late final ProgressRepository _progressRepo;
  late final LibraryRepository _libraryRepo;
  late final StatisticsRepository _statsRepo;
  late final String _deviceId;

  // Reading-session tracking (folded into stats on close).
  late final DateTime _sessionStart;
  double? _sessionStartPercent;
  double _lastPercent = 0;
  int _pageCount = 0;
  int _wordCount = 0;
  bool _finished = false;

  @override
  ReaderUiState build(String bookId) {
    _debouncer = Debouncer(AppConstants.progressPersistDebounce);
    _progressRepo = ref.read(progressRepositoryProvider);
    _libraryRepo = ref.read(libraryRepositoryProvider);
    _statsRepo = ref.read(statisticsRepositoryProvider);
    _deviceId = ref.read(deviceIdProvider);
    _sessionStart = DateTime.now();
    ref.onDispose(() {
      // Flush any pending position write when leaving the reader.
      _debouncer.flush(_persistNow);
      _debouncer.dispose();
      _autoHideTimer?.cancel();
      _recordSession();
    });
    // Chrome starts visible on open, then fades into the full-screen view.
    _scheduleAutoHide();
    return const ReaderUiState();
  }

  /// (Re)starts the countdown that hides the chrome after [_autoHideAfter] of
  /// no interaction, yielding an immersive full-screen reading view.
  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(_autoHideAfter, () {
      if (!state.immersive) state = state.copyWith(immersive: true);
    });
  }

  /// Called by the reader once the book + content are known, so a session can
  /// estimate pages/words read from the progress delta.
  void setBookMetrics({required int pageCount, required int wordCount}) {
    _pageCount = pageCount;
    _wordCount = wordCount;
  }

  void _recordSession() {
    final duration = DateTime.now().difference(_sessionStart);
    if (duration.inSeconds < 5) return; // ignore accidental opens
    final delta = (_lastPercent - (_sessionStartPercent ?? _lastPercent)).clamp(
      0.0,
      1.0,
    );
    _statsRepo.recordSession(
      ReadingSession(
        bookId: arg,
        startedAt: _sessionStart,
        endedAt: DateTime.now(),
        pagesRead: (delta * _pageCount).round(),
        wordsRead: (delta * _wordCount).round(),
        completed: _finished,
      ),
    );
  }

  void toggleImmersive() {
    final showChrome = state.immersive; // tapping while immersive reveals it
    state = state.copyWith(immersive: !showChrome);
    if (showChrome) {
      _scheduleAutoHide(); // now visible → start the auto-hide countdown
    } else {
      _autoHideTimer?.cancel(); // now hidden → nothing to hide
    }
  }

  void setMode(ReadingMode mode) {
    state = state.copyWith(mode: mode);
    _persistNow();
  }

  /// Called by the renderer as the user scrolls/turns pages.
  void onPositionChanged({
    required double percent,
    required int charOffset,
    String? chapterId,
  }) {
    _sessionStartPercent ??= percent;
    _lastPercent = percent;
    if (percent >= 0.999) _finished = true;
    state = state.copyWith(
      percent: percent,
      charOffset: charOffset,
      chapterId: chapterId,
    );
    // Turning pages while the chrome is up counts as use: keep it up a bit more.
    if (!state.immersive) _scheduleAutoHide();
    _debouncer(_persistNow);
  }

  void _persistNow() {
    final progress = ReadingProgress(
      bookId: arg,
      updatedAt: DateTime.now(),
      deviceId: _deviceId,
      percent: state.percent,
      charOffset: state.charOffset,
      chapterId: state.chapterId,
      mode: state.mode,
    );
    // Local-first, fire-and-forget; failures are non-fatal to reading.
    _progressRepo.saveProgress(progress);
    // Reflect progress on the library tile too.
    _libraryRepo.getBook(arg).then((r) {
      final book = r.valueOrNull;
      if (book != null) {
        _libraryRepo.updateBook(
          book.copyWith(
            progressPercent: state.percent,
            lastOpened: DateTime.now(),
          ),
        );
      }
    });
  }
}

final readerControllerProvider =
    NotifierProvider.family<ReaderController, ReaderUiState, String>(
  ReaderController.new,
);
