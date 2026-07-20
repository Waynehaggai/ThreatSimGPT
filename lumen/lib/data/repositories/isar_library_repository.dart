import 'package:isar_community/isar.dart';

import '../../core/error/exceptions.dart';
import '../../core/error/failures.dart';
import '../../core/result/result.dart';
import '../../domain/entities/book.dart';
import '../../domain/entities/book_content.dart';
import '../../domain/entities/collection.dart';
import '../../domain/entities/enums.dart';
import '../../domain/repositories/library_repository.dart';
import '../../domain/services/import_service.dart';
import '../local/daos/sync_queue_dao.dart';
import '../local/models/library_models.dart';
import '../mappers/library_mappers.dart';
import 'library_query_matcher.dart';

/// Isar-backed [LibraryRepository]: offline-first, reactive, sync-aware.
///
/// Reads/writes go to the local encrypted-at-rest DB and every mutation
/// enqueues a [SyncQueueDao] operation for eventual cloud replication. The
/// `DocumentParsingService` (ROADMAP M2) supplies import metadata and Smart
/// content; here import persists the record and the parser is injected.
class IsarLibraryRepository implements LibraryRepository {
  IsarLibraryRepository(this._isar, this._syncQueue, this._import);

  final Isar _isar;
  final SyncQueueDao _syncQueue;
  final ImportService _import;

  @override
  Stream<List<Book>> watchBooks(LibraryQuery query) {
    // Watch the whole collection reactively, then apply the shared query logic.
    // Hot paths (large libraries) can pre-narrow with native indexes; the
    // predicate/sort semantics stay in one shared, tested place.
    return _isar.bookModels.where().watch(fireImmediately: true).map(
          (rows) =>
              applyLibraryQuery(rows.map((m) => m.toEntity()).toList(), query),
        );
  }

  @override
  Future<Result<Book>> getBook(String id) async {
    try {
      final model = await _isar.bookModels.filter().uidEqualTo(id).findFirst();
      return model == null
          ? const Result.failure(StorageFailure('Book not found.'))
          : Result.success(model.toEntity());
    } on Object catch (e) {
      return Result.failure(StorageFailure('Failed to load book.', cause: e));
    }
  }

  @override
  Future<Result<Book>> importBook(String sourcePath) async {
    final prepared = await _import.prepare(sourcePath);
    final book = prepared.valueOrNull;
    if (book == null) return Result.failure(prepared.failureOrNull!);

    try {
      // Dedupe by content checksum — re-importing the same file returns the
      // existing book instead of creating a copy.
      final checksum = book.checksum;
      if (checksum != null) {
        final existing = await _isar.bookModels
            .filter()
            .checksumEqualTo(checksum)
            .findFirst();
        if (existing != null) return Result.success(existing.toEntity());
      }

      await _isar.writeTxn(() => _isar.bookModels.put(book.toModel()));
      await _syncQueue.enqueue(
        entityType: SyncEntityType.book,
        entityId: book.id,
        action: SyncAction.create,
      );
      return Result.success(book);
    } on Object catch (e) {
      return Result.failure(StorageFailure('Failed to save import.', cause: e));
    }
  }

  @override
  Future<Result<void>> updateBook(Book book) async {
    try {
      await _isar.writeTxn(() => _isar.bookModels.put(book.toModel()));
      await _syncQueue.enqueue(
        entityType: SyncEntityType.book,
        entityId: book.id,
        action: SyncAction.update,
      );
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(StorageFailure('Failed to update book.', cause: e));
    }
  }

  @override
  Future<Result<void>> deleteBook(String id, {bool permanent = false}) async {
    try {
      final model = await _isar.bookModels.filter().uidEqualTo(id).findFirst();
      if (model == null) {
        return const Result.failure(StorageFailure('Book not found.'));
      }
      await _isar.writeTxn(() async {
        if (permanent) {
          await _isar.bookModels.delete(model.id);
        } else {
          model.isArchived = true;
          await _isar.bookModels.put(model);
        }
      });
      await _syncQueue.enqueue(
        entityType: SyncEntityType.book,
        entityId: id,
        action: permanent ? SyncAction.delete : SyncAction.update,
      );
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(StorageFailure('Failed to delete book.', cause: e));
    }
  }

  @override
  Future<Result<Book>> duplicateBook(String id) async {
    final source = await getBook(id);
    final book = source.valueOrNull;
    if (book == null) return Result.failure(source.failureOrNull!);

    // A real duplicate also copies the underlying file (M2); here we copy the
    // metadata record.
    final dup = Book(
      id: '${book.id}-copy-${DateTime.now().millisecondsSinceEpoch}',
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
    final saved = await updateBook(dup);
    return saved.map((_) => dup);
  }

  @override
  Future<Result<BookContent>> getSmartContent(String bookId) async {
    // Smart content generation + caching is the reading engine (M3).
    return const Result.failure(
      DocumentFailure('Smart content generation is implemented in ROADMAP M3.'),
    );
  }

  // ── Collections ────────────────────────────────────────────────────────
  @override
  Stream<List<Collection>> watchCollections() {
    return _isar.collectionModels
        .filter()
        .isDeletedEqualTo(false)
        .sortBySortIndex()
        .watch(fireImmediately: true)
        .map((rows) => rows.map((m) => m.toEntity()).toList());
  }

  @override
  Future<Result<Collection>> createCollection(Collection collection) async {
    try {
      await _isar.writeTxn(
        () => _isar.collectionModels.put(collection.toModel()),
      );
      await _syncQueue.enqueue(
        entityType: SyncEntityType.collection,
        entityId: collection.id,
        action: SyncAction.create,
      );
      return Result.success(collection);
    } on Object catch (e) {
      return Result.failure(
        StorageFailure('Failed to create collection.', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> updateCollection(Collection collection) async {
    try {
      await _isar.writeTxn(
        () => _isar.collectionModels.put(collection.toModel()),
      );
      await _syncQueue.enqueue(
        entityType: SyncEntityType.collection,
        entityId: collection.id,
        action: SyncAction.update,
      );
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(
        StorageFailure('Failed to update collection.', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> deleteCollection(String id) async {
    try {
      final model =
          await _isar.collectionModels.filter().uidEqualTo(id).findFirst();
      if (model == null) {
        return const Result.failure(StorageFailure('Collection not found.'));
      }
      await _isar.writeTxn(() async {
        model
          ..isDeleted = true
          ..updatedAt = DateTime.now();
        await _isar.collectionModels.put(model);
      });
      await _syncQueue.enqueue(
        entityType: SyncEntityType.collection,
        entityId: id,
        action: SyncAction.delete,
      );
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(
        StorageFailure('Failed to delete collection.', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> setBookCollections(
    String bookId,
    List<String> collectionIds,
  ) async {
    try {
      final model =
          await _isar.bookModels.filter().uidEqualTo(bookId).findFirst();
      if (model == null) {
        return const Result.failure(StorageFailure('Book not found.'));
      }
      await _isar.writeTxn(() async {
        model.collectionIds = collectionIds;
        await _isar.bookModels.put(model);
      });
      await _syncQueue.enqueue(
        entityType: SyncEntityType.book,
        entityId: bookId,
        action: SyncAction.update,
      );
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(
        StorageFailure('Failed to set collections.', cause: e),
      );
    }
  }
}
