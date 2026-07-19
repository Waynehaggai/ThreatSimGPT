import '../../core/result/result.dart';
import '../entities/book.dart';
import '../entities/book_content.dart';
import '../entities/collection.dart';

/// Options for querying the library (search / filter / sort).
class LibraryQuery {
  const LibraryQuery({
    this.search,
    this.collectionId,
    this.favoritesOnly = false,
    this.includeArchived = false,
    this.sortBy = LibrarySort.lastOpened,
    this.descending = true,
  });

  final String? search;
  final String? collectionId;
  final bool favoritesOnly;
  final bool includeArchived;
  final LibrarySort sortBy;
  final bool descending;
}

enum LibrarySort { title, author, dateImported, lastOpened, progress, fileSize }

/// Contract for the personal library. Implemented in the data layer against the
/// local DB first (offline-first); sync is handled separately by [SyncRepository].
abstract interface class LibraryRepository {
  /// Reactive stream of the library, re-emitting on any local change.
  Stream<List<Book>> watchBooks(LibraryQuery query);

  Future<Result<Book>> getBook(String id);

  /// Imports a file from [sourcePath] into the library: copies it into app
  /// storage, extracts metadata/cover, and (lazily) prepares Smart content.
  Future<Result<Book>> importBook(String sourcePath);

  Future<Result<void>> updateBook(Book book);

  /// Soft-deletes (archives) or hard-deletes a book and its local assets.
  Future<Result<void>> deleteBook(String id, {bool permanent = false});

  Future<Result<Book>> duplicateBook(String id);

  /// Returns cached Smart Reading content, generating it on first access.
  Future<Result<BookContent>> getSmartContent(String bookId);

  // ── Collections ──────────────────────────────────────────────────────────
  Stream<List<Collection>> watchCollections();
  Future<Result<Collection>> createCollection(Collection collection);
  Future<Result<void>> updateCollection(Collection collection);
  Future<Result<void>> deleteCollection(String id);
  Future<Result<void>> setBookCollections(String bookId, List<String> collectionIds);
}
