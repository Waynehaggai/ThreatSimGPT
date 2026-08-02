import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/di/repository_providers.dart';
import 'package:lumen/core/error/failures.dart';
import 'package:lumen/core/result/result.dart';
import 'package:lumen/domain/entities/reading_progress.dart';
import 'package:lumen/domain/repositories/library_repository.dart';
import 'package:lumen/domain/repositories/progress_repository.dart';
import 'package:lumen/domain/repositories/statistics_repository.dart';
import 'package:lumen/features/library/presentation/providers/library_providers.dart';
import 'package:lumen/features/reader/presentation/providers/reader_providers.dart';
import 'package:mocktail/mocktail.dart';

class _MockProgressRepo extends Mock implements ProgressRepository {}

class _MockLibraryRepo extends Mock implements LibraryRepository {}

class _MockStatsRepo extends Mock implements StatisticsRepository {}

class _FakeProgress extends Fake implements ReadingProgress {}

ProviderContainer _container() {
  final progress = _MockProgressRepo();
  final library = _MockLibraryRepo();
  // Debounced position writes may fire once the fake clock passes the debounce;
  // stub them to be harmless no-ops so the tests stay focused on chrome state.
  when(() => progress.saveProgress(any()))
      .thenAnswer((_) async => const Result.success(null));
  when(() => library.getBook(any()))
      .thenAnswer((_) async => const Result.failure(StorageFailure('n/a')));

  final container = ProviderContainer(
    overrides: [
      progressRepositoryProvider.overrideWithValue(progress),
      libraryRepositoryProvider.overrideWithValue(library),
      statisticsRepositoryProvider.overrideWithValue(_MockStatsRepo()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  const bookId = 'book-1';

  setUpAll(() => registerFallbackValue(_FakeProgress()));

  test('chrome auto-hides into the full-screen view after ~3s', () {
    fakeAsync((async) {
      final container = _container();
      final controller =
          container.read(readerControllerProvider(bookId).notifier);

      // Chrome starts visible on open.
      expect(controller.state.immersive, isFalse);

      async.elapse(const Duration(seconds: 2));
      expect(controller.state.immersive, isFalse, reason: 'still within grace');

      async.elapse(const Duration(seconds: 2));
      expect(controller.state.immersive, isTrue, reason: 'auto-hidden by 3s');
    });
  });

  test('tapping reveals the chrome, which then auto-hides again', () {
    fakeAsync((async) {
      final container = _container();
      final controller =
          container.read(readerControllerProvider(bookId).notifier);

      async.elapse(const Duration(seconds: 4)); // let it hide first
      expect(controller.state.immersive, isTrue);

      controller.toggleImmersive(); // tap → reveal
      expect(controller.state.immersive, isFalse);

      async.elapse(const Duration(seconds: 4)); // countdown restarts
      expect(controller.state.immersive, isTrue);
    });
  });

  test('turning pages while the chrome is up keeps it up', () {
    fakeAsync((async) {
      final container = _container();
      final controller =
          container.read(readerControllerProvider(bookId).notifier);

      // Just before it would hide, a page turn resets the countdown.
      async.elapse(const Duration(milliseconds: 2500));
      controller.onPositionChanged(percent: 0.1, charOffset: 10);
      async.elapse(const Duration(milliseconds: 2000));
      expect(controller.state.immersive, isFalse, reason: 'countdown reset');

      // With no further use, it eventually hides.
      async.elapse(const Duration(seconds: 2));
      expect(controller.state.immersive, isTrue);
    });
  });
}
