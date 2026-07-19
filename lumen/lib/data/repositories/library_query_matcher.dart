import '../../domain/entities/book.dart';
import '../../domain/repositories/library_repository.dart';

/// Pure, shared implementation of [LibraryQuery] filtering + sorting.
///
/// Both the in-memory and Isar repositories run their candidate books through
/// this so search/filter/sort behaviour is identical and independently testable
/// (see `test/data/library_query_matcher_test.dart`). The Isar repo narrows
/// with native indexes first where it can, then applies this for the remaining
/// predicates and ordering.
List<Book> applyLibraryQuery(List<Book> books, LibraryQuery q) {
  final search = q.search?.trim().toLowerCase();

  final filtered = books.where((b) {
    if (!q.includeArchived && b.isArchived) return false;
    if (q.favoritesOnly && !b.isFavorite) return false;
    if (q.collectionId != null && !b.collectionIds.contains(q.collectionId)) {
      return false;
    }
    if (search != null && search.isNotEmpty) {
      final hay = '${b.title} ${b.author}'.toLowerCase();
      if (!hay.contains(search)) return false;
    }
    return true;
  }).toList();

  int cmp(Book a, Book b) => switch (q.sortBy) {
        LibrarySort.title =>
          a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        LibrarySort.author =>
          a.author.toLowerCase().compareTo(b.author.toLowerCase()),
        LibrarySort.dateImported => a.dateImported.compareTo(b.dateImported),
        LibrarySort.lastOpened => (a.lastOpened ?? a.dateImported)
            .compareTo(b.lastOpened ?? b.dateImported),
        LibrarySort.progress => a.progressPercent.compareTo(b.progressPercent),
        LibrarySort.fileSize => a.fileSizeBytes.compareTo(b.fileSizeBytes),
      };

  filtered.sort((a, b) => q.descending ? cmp(b, a) : cmp(a, b));
  return filtered;
}
