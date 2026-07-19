import 'package:isar/isar.dart';

import '../../core/error/failures.dart';
import '../../core/result/result.dart';
import '../../domain/entities/annotation.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/enums.dart';
import '../../domain/repositories/annotation_repository.dart';
import '../local/daos/sync_queue_dao.dart';
import '../local/models/annotation_models.dart';
import '../mappers/annotation_mappers.dart';

/// Isar-backed [AnnotationRepository]. Deletions are tombstoned (never hard
/// removed) so they sync safely and honour "never delete user data".
class IsarAnnotationRepository implements AnnotationRepository {
  IsarAnnotationRepository(this._isar, this._syncQueue);

  final Isar _isar;
  final SyncQueueDao _syncQueue;

  @override
  Stream<List<Annotation>> watchAnnotations(String bookId) {
    return _isar.annotationModels
        .filter()
        .bookIdEqualTo(bookId)
        .isDeletedEqualTo(false)
        .sortByCreatedAt()
        .watch(fireImmediately: true)
        .map((rows) => rows.map((m) => m.toEntity()).toList());
  }

  @override
  Future<Result<void>> saveAnnotation(Annotation annotation) async {
    try {
      await _isar.writeTxn(
          () => _isar.annotationModels.put(annotation.toModel()));
      await _syncQueue.enqueue(
        entityType: SyncEntityType.annotation,
        entityId: annotation.id,
        action: SyncAction.update,
      );
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(
          StorageFailure('Failed to save annotation.', cause: e));
    }
  }

  @override
  Future<Result<void>> deleteAnnotation(String id) async {
    try {
      final model =
          await _isar.annotationModels.filter().uidEqualTo(id).findFirst();
      if (model == null) return const Result.success(null);
      await _isar.writeTxn(() async {
        model
          ..isDeleted = true
          ..updatedAt = DateTime.now();
        await _isar.annotationModels.put(model);
      });
      await _syncQueue.enqueue(
        entityType: SyncEntityType.annotation,
        entityId: id,
        action: SyncAction.delete,
      );
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(
          StorageFailure('Failed to delete annotation.', cause: e));
    }
  }

  @override
  Stream<List<Bookmark>> watchBookmarks(String bookId) {
    return _isar.bookmarkModels
        .filter()
        .bookIdEqualTo(bookId)
        .isDeletedEqualTo(false)
        .sortByCreatedAt()
        .watch(fireImmediately: true)
        .map((rows) => rows.map((m) => m.toEntity()).toList());
  }

  @override
  Future<Result<void>> saveBookmark(Bookmark bookmark) async {
    try {
      await _isar.writeTxn(
          () => _isar.bookmarkModels.put(bookmark.toModel()));
      await _syncQueue.enqueue(
        entityType: SyncEntityType.annotation,
        entityId: bookmark.id,
        action: SyncAction.update,
      );
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(
          StorageFailure('Failed to save bookmark.', cause: e));
    }
  }

  @override
  Future<Result<void>> deleteBookmark(String id) async {
    try {
      final model =
          await _isar.bookmarkModels.filter().uidEqualTo(id).findFirst();
      if (model == null) return const Result.success(null);
      await _isar.writeTxn(() async {
        model.isDeleted = true;
        await _isar.bookmarkModels.put(model);
      });
      await _syncQueue.enqueue(
        entityType: SyncEntityType.annotation,
        entityId: id,
        action: SyncAction.delete,
      );
      return const Result.success(null);
    } on Object catch (e) {
      return Result.failure(
          StorageFailure('Failed to delete bookmark.', cause: e));
    }
  }

  @override
  Future<Result<List<Annotation>>> searchAnnotations(String query) async {
    try {
      final q = query.trim();
      if (q.isEmpty) return const Result.success(<Annotation>[]);
      final rows = await _isar.annotationModels
          .filter()
          .isDeletedEqualTo(false)
          .group((g) => g
              .selectedTextContains(q, caseSensitive: false)
              .or()
              .noteTextContains(q, caseSensitive: false))
          .findAll();
      return Result.success(rows.map((m) => m.toEntity()).toList());
    } on Object catch (e) {
      return Result.failure(StorageFailure('Search failed.', cause: e));
    }
  }

  @override
  Future<Result<String>> exportNotes(String bookId, {String format = 'md'}) async {
    try {
      final rows = await _isar.annotationModels
          .filter()
          .bookIdEqualTo(bookId)
          .isDeletedEqualTo(false)
          .sortByCreatedAt()
          .findAll();
      final buffer = StringBuffer('# Notes & Highlights\n\n');
      for (final a in rows) {
        if (a.selectedText.isNotEmpty) {
          buffer.writeln('> ${a.selectedText}');
        }
        if (a.noteText != null && a.noteText!.isNotEmpty) {
          buffer.writeln('\n${a.noteText}');
        }
        buffer.writeln('\n---\n');
      }
      return Result.success(buffer.toString());
    } on Object catch (e) {
      return Result.failure(StorageFailure('Export failed.', cause: e));
    }
  }
}
