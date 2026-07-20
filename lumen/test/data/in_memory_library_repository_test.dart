import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/repositories/in_memory_library_repository.dart';
import 'package:lumen/domain/repositories/library_repository.dart';

void main() {
  late InMemoryLibraryRepository repo;

  setUp(() => repo = InMemoryLibraryRepository());

  test('imports a supported document and exposes it in the stream', () async {
    final result = await repo.importBook('/downloads/Dune.epub');
    expect(result.isSuccess, isTrue);

    final books = await repo.watchBooks(const LibraryQuery()).first;
    expect(books, hasLength(1));
    expect(books.single.title, 'Dune');
  });

  test('rejects an unsupported format', () async {
    final result = await repo.importBook('/downloads/song.mp3');
    expect(result.isFailure, isTrue);
  });

  test('search filters by title/author', () async {
    await repo.importBook('/x/Clean Architecture.pdf');
    await repo.importBook('/x/The Pragmatic Programmer.pdf');

    final filtered =
        await repo.watchBooks(const LibraryQuery(search: 'pragmatic')).first;
    expect(filtered, hasLength(1));
    expect(filtered.single.title, contains('Pragmatic'));
  });

  test('archiving hides a book unless includeArchived is set', () async {
    final imported = await repo.importBook('/x/Old.pdf');
    final id = imported.valueOrNull!.id;
    await repo.deleteBook(id);

    final visible = await repo.watchBooks(const LibraryQuery()).first;
    expect(visible, isEmpty);

    final all =
        await repo.watchBooks(const LibraryQuery(includeArchived: true)).first;
    expect(all, hasLength(1));
  });
}
