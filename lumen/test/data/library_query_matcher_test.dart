import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/repositories/library_query_matcher.dart';
import 'package:lumen/domain/entities/book.dart';
import 'package:lumen/domain/entities/enums.dart';
import 'package:lumen/domain/repositories/library_repository.dart';

void main() {
  Book book(
    String title, {
    String author = 'Author',
    bool archived = false,
    bool favorite = false,
    double progress = 0.0,
    List<String> collections = const [],
  }) =>
      Book(
        id: title,
        title: title,
        author: author,
        format: BookFormat.pdf,
        filePath: '/x/$title.pdf',
        fileSizeBytes: 1,
        pageCount: 1,
        dateImported: DateTime(2026),
        isArchived: archived,
        isFavorite: favorite,
        progressPercent: progress,
        collectionIds: collections,
      );

  final library = [
    book('Dune', author: 'Herbert'),
    book('Foundation', author: 'Asimov', favorite: true),
    book('Old Notes', archived: true),
    book('Sci-Fi Essays', collections: ['c1']),
  ];

  test('excludes archived unless includeArchived', () {
    expect(applyLibraryQuery(library, const LibraryQuery()).length, 3);
    expect(
      applyLibraryQuery(
        library,
        const LibraryQuery(includeArchived: true),
      ).length,
      4,
    );
  });

  test('favoritesOnly filters to favorites', () {
    final result = applyLibraryQuery(
      library,
      const LibraryQuery(favoritesOnly: true),
    );
    expect(result.single.title, 'Foundation');
  });

  test('search matches title and author, case-insensitive', () {
    expect(
      applyLibraryQuery(
        library,
        const LibraryQuery(search: 'asimov'),
      ).single.title,
      'Foundation',
    );
  });

  test('collectionId filters by membership', () {
    final result = applyLibraryQuery(
      library,
      const LibraryQuery(collectionId: 'c1'),
    );
    expect(result.single.title, 'Sci-Fi Essays');
  });

  test('sorts by title ascending when requested', () {
    final result = applyLibraryQuery(
      library,
      const LibraryQuery(
        includeArchived: true,
        sortBy: LibrarySort.title,
        descending: false,
      ),
    );
    expect(result.first.title, 'Dune');
    expect(result.last.title, 'Sci-Fi Essays');
  });
}
