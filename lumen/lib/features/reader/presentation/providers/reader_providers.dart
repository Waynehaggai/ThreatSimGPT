import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/book.dart';
import '../../../../domain/entities/enums.dart';
import '../../../library/presentation/providers/library_providers.dart';

/// Transient per-session reader UI state (not persisted).
class ReaderUiState {
  const ReaderUiState({
    this.immersive = false,
    this.mode = ReadingMode.smart,
    this.percent = 0.0,
  });

  final bool immersive;
  final ReadingMode mode;
  final double percent;

  ReaderUiState copyWith({bool? immersive, ReadingMode? mode, double? percent}) =>
      ReaderUiState(
        immersive: immersive ?? this.immersive,
        mode: mode ?? this.mode,
        percent: percent ?? this.percent,
      );
}

class ReaderController extends FamilyNotifier<ReaderUiState, String> {
  @override
  ReaderUiState build(String bookId) => const ReaderUiState();

  void toggleImmersive() =>
      state = state.copyWith(immersive: !state.immersive);

  void setMode(ReadingMode mode) => state = state.copyWith(mode: mode);

  void onProgress(double percent) {
    state = state.copyWith(percent: percent);
    // TODO(progress): debounce + SaveProgress use case + enqueue sync.
  }
}

final readerControllerProvider =
    NotifierProvider.family<ReaderController, ReaderUiState, String>(
        ReaderController.new);

/// Loads the [Book] being read.
final readerBookProvider = FutureProvider.family<Book, String>((ref, id) async {
  final repo = ref.watch(libraryRepositoryProvider);
  final result = await repo.getBook(id);
  return result.fold(
    onSuccess: (book) => book,
    onFailure: (f) => throw Exception(f.message),
  );
});
