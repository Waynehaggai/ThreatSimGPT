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
import '../../../library/presentation/providers/library_providers.dart';
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
/// If the book is a real `.txt` file on disk it is parsed for a genuine reading
/// experience; otherwise a rich sample document is returned so the reader is
/// demonstrable before the M2 import pipeline lands.
final readerContentProvider =
    FutureProvider.family<BookContent, String>((ref, bookId) async {
  final book = await ref.watch(readerBookProvider(bookId).future);
  final parser = ref.watch(documentParsingServiceProvider);

  if (book.format == BookFormat.txt && File(book.filePath).existsSync()) {
    final result = await parser.buildSmartContent(book);
    final content = result.valueOrNull;
    if (content != null) return content;
  }
  return sampleBookContent(book.id, book.title);
});

/// The last-saved position for a book, used to resume exactly.
final readerResumeProvider =
    FutureProvider.family<ReadingProgress?, String>((ref, bookId) async {
  final result = await ref.watch(progressRepositoryProvider).getProgress(bookId);
  return result.valueOrNull;
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
  late final Debouncer _debouncer;

  // Captured at build time so the dispose-time flush never touches `ref` after
  // the provider is disposed (which would throw).
  late final ProgressRepository _progressRepo;
  late final LibraryRepository _libraryRepo;
  late final String _deviceId;

  @override
  ReaderUiState build(String bookId) {
    _debouncer = Debouncer(AppConstants.progressPersistDebounce);
    _progressRepo = ref.read(progressRepositoryProvider);
    _libraryRepo = ref.read(libraryRepositoryProvider);
    _deviceId = ref.read(deviceIdProvider);
    ref.onDispose(() {
      // Flush any pending position write when leaving the reader.
      _debouncer.flush(_persistNow);
      _debouncer.dispose();
    });
    return const ReaderUiState();
  }

  void toggleImmersive() =>
      state = state.copyWith(immersive: !state.immersive);

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
    state = state.copyWith(
      percent: percent,
      charOffset: charOffset,
      chapterId: chapterId,
    );
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
        _libraryRepo.updateBook(book.copyWith(
          progressPercent: state.percent,
          lastOpened: DateTime.now(),
        ));
      }
    });
  }
}

final readerControllerProvider =
    NotifierProvider.family<ReaderController, ReaderUiState, String>(
        ReaderController.new);
