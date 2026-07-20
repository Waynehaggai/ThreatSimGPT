import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/repository_providers.dart';
import '../../../../data/repositories/in_memory_library_repository.dart';
import '../../../../domain/entities/book.dart';
import '../../../../domain/repositories/library_repository.dart';
import '../../../../domain/usecases/library_usecases.dart';

/// The active [LibraryRepository]. Defaults to the in-memory implementation
/// (wired with the real import pipeline) and is overridden with
/// `IsarLibraryRepository` in the bootstrap for production.
final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return InMemoryLibraryRepository(
    seed: _demoSeed(),
    importService: ref.watch(importServiceProvider),
  );
});

/// How the library is currently viewed (grid vs list) — a UI-only concern.
enum LibraryLayout { grid, list }

final libraryLayoutProvider = StateProvider<LibraryLayout>(
  (_) => LibraryLayout.grid,
);

/// Current search / filter / sort selection.
final libraryQueryProvider = StateProvider<LibraryQuery>(
  (_) => const LibraryQuery(),
);

/// Reactive stream of books for the current query.
final libraryBooksProvider = StreamProvider<List<Book>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  final query = ref.watch(libraryQueryProvider);
  return repo.watchBooks(query);
});

/// Use-case-backed actions for the library UI.
final importBookProvider = Provider(
  (ref) => ImportBook(ref.watch(libraryRepositoryProvider)),
);
final toggleFavoriteProvider = Provider(
  (ref) => ToggleFavorite(ref.watch(libraryRepositoryProvider)),
);
final deleteBookProvider = Provider(
  (ref) => DeleteBook(ref.watch(libraryRepositoryProvider)),
);

/// Seed data for the in-memory repository. Empty by default so a fresh install
/// shows the real empty state; populated by importing books.
List<Book> _demoSeed() => const <Book>[];
