import '../../core/result/result.dart';
import '../entities/annotation.dart';
import '../entities/bookmark.dart';

/// Contract for bookmarks, highlights, and notes on a book. Offline-first;
/// deletions are tombstoned (never hard-removed) so they sync safely.
abstract interface class AnnotationRepository {
  Stream<List<Annotation>> watchAnnotations(String bookId);
  Future<Result<void>> saveAnnotation(Annotation annotation);
  Future<Result<void>> deleteAnnotation(String id);

  Stream<List<Bookmark>> watchBookmarks(String bookId);
  Future<Result<void>> saveBookmark(Bookmark bookmark);
  Future<Result<void>> deleteBookmark(String id);

  /// Full-text search across the user's highlights and notes.
  Future<Result<List<Annotation>>> searchAnnotations(String query);

  /// Serializes a book's notes/highlights to a shareable document (md/txt).
  Future<Result<String>> exportNotes(String bookId, {String format = 'md'});
}
