import 'dart:async';

import 'package:path/path.dart' as p;

import '../../core/error/failures.dart';
import '../../core/result/result.dart';
import '../../domain/entities/book.dart';
import '../../domain/entities/book_content.dart';
import '../../domain/entities/collection.dart';
import '../../domain/entities/enums.dart';
import '../../domain/repositories/library_repository.dart';
import '../../domain/services/import_service.dart';
import 'library_query_matcher.dart';

/// A pure-Dart, in-memory [LibraryRepository].
///
/// It ships as the default so the UI is fully interactive and the widget/unit
/// tests run without Isar or platform channels. In production it is replaced via
/// DI by `IsarLibraryRepository`, which persists to the encrypted local DB and
/// enqueues sync operations — the interface and behaviour are identical, so no
/// caller changes.
class InMemoryLibraryRepository implements LibraryRepository {
  InMemoryLibraryRepository({List<Book>? seed, ImportService? importService})
      : _import = importService {
    if (seed != null) {
      for (final b in seed) {
        _books[b.id] = b;
      }
    }
    _emit();
    _emitCollections();
  }

  final ImportService? _import;

  final Map<String, Book> _books = {};
  final Map<String, Collection> _collections = {};
  final Map<String, BookContent> _content = {};

  final _booksController = StreamController<List<Book>>.broadcast();
  final _collectionsController =
      StreamController<List<Collection>>.broadcast();

  int _idSeq = 0;
  String _nextId() => 'book-${DateTime.now().millisecondsSinceEpoch}-${_idSeq++}';

  List<Book> get _snapshot => _books.values.toList(growable: false);

  void _emit() => _booksController.add(_snapshot);
  void _emitCollections() =>
      _collectionsController.add(_collections.values.toList(growable: false));

  @override
  Stream<List<Book>> watchBooks(LibraryQuery query) async* {
    yield applyLibraryQuery(_snapshot, query);
    yield* _booksController.stream
        .map((books) => applyLibraryQuery(books, query));
  }

  @override
  Future<Result<Book>> getBook(String id) async {
    final book = _books[id];
    return book == null
        ? const Result.failure(StorageFailure('Book not found.'))
        : Result.success(book);
  }

  @override
  Future<Result<Book>> importBook(String sourcePath) async {
    // With the import pipeline configured, use it (copy + checksum + metadata).
    final importer = _import;
    if (importer != null) {
      final prepared = await importer.prepare(sourcePath);
      final book = prepared.valueOrNull;
      if (book == null) return Result.failure(prepared.failureOrNull!);

      // Dedupe by content checksum — re-importing the same file is a no-op.
      final duplicate = _findByChecksum(book.checksum);
      if (duplicate != null) return Result.success(duplicate);

      _books[book.id] = book;
      _emit();
      return Result.success(book);
    }

    // Fallback (no pipeline): register a minimal record pointing at the source.
    final ext = p.extension(sourcePath);
    final format = BookFormat.fromExtension(ext);
    if (!format.supportsSmartMode && !format.hasOriginalLayout) {
      return Result.failure(DocumentFailure('Unsupported format: $ext'));
    }
    final book = Book(
      id: _nextId(),
      title: p.basenameWithoutExtension(sourcePath),
      author: 'Unknown',
      format: format,
      filePath: sourcePath,
      fileSizeBytes: 0,
      pageCount: 0,
      dateImported: DateTime.now(),
      defaultMode:
          format.supportsSmartMode ? ReadingMode.smart : ReadingMode.original,
    );
    _books[book.id] = book;
    _emit();
    return Result.success(book);
  }

  Book? _findByChecksum(String? checksum) {
    if (checksum == null) return null;
    for (final b in _books.values) {
      if (b.checksum == checksum) return b;
    }
    return null;
  }

  @override
  Future<Result<void>> updateBook(Book book) async {
    if (!_books.containsKey(book.id)) {
      return const Result.failure(StorageFailure('Book not found.'));
    }
    _books[book.id] = book;
    _emit();
    return const Result.success(null);
  }

  @override
  Future<Result<void>> deleteBook(String id, {bool permanent = false}) async {
    final book = _books[id];
    if (book == null) {
      return const Result.failure(StorageFailure('Book not found.'));
    }
    if (permanent) {
      _books.remove(id);
    } else {
      _books[id] = book.copyWith(isArchived: true);
    }
    _emit();
    return const Result.success(null);
  }

  @override
  Future<Result<Book>> duplicateBook(String id) async {
    final book = _books[id];
    if (book == null) {
      return const Result.failure(StorageFailure('Book not found.'));
    }
    final dup = Book(
      id: _nextId(),
      title: '${book.title} (copy)',
      author: book.author,
      format: book.format,
      filePath: book.filePath,
      fileSizeBytes: book.fileSizeBytes,
      pageCount: book.pageCount,
      dateImported: DateTime.now(),
      coverPath: book.coverPath,
      defaultMode: book.defaultMode,
    );
    _books[dup.id] = dup;
    _emit();
    return Result.success(dup);
  }

  @override
  Future<Result<BookContent>> getSmartContent(String bookId) async {
    final cached = _content[bookId];
    if (cached != null) return Result.success(cached);
    return const Result.failure(
      DocumentFailure('Smart content not yet generated for this book.'),
    );
  }

  // ── Collections ────────────────────────────────────────────────────────
  @override
  Stream<List<Collection>> watchCollections() async* {
    yield _collections.values.toList(growable: false);
    yield* _collectionsController.stream;
  }

  @override
  Future<Result<Collection>> createCollection(Collection collection) async {
    _collections[collection.id] = collection;
    _emitCollections();
    return Result.success(collection);
  }

  @override
  Future<Result<void>> updateCollection(Collection collection) async {
    _collections[collection.id] = collection;
    _emitCollections();
    return const Result.success(null);
  }

  @override
  Future<Result<void>> deleteCollection(String id) async {
    _collections.remove(id);
    _emitCollections();
    return const Result.success(null);
  }

  @override
  Future<Result<void>> setBookCollections(
    String bookId,
    List<String> collectionIds,
  ) async {
    final book = _books[bookId];
    if (book == null) {
      return const Result.failure(StorageFailure('Book not found.'));
    }
    _books[bookId] = book.copyWith(collectionIds: collectionIds);
    _emit();
    return const Result.success(null);
  }
}
