import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/repository_providers.dart';
import '../../../../domain/entities/annotation.dart';
import '../../../../domain/entities/bookmark.dart';
import '../../../../domain/entities/enums.dart';
import '../../../../domain/repositories/annotation_repository.dart';

/// Highlights/notes for a book, reactive.
final annotationsProvider = StreamProvider.family<List<Annotation>, String>((
  ref,
  bookId,
) {
  return ref.watch(annotationRepositoryProvider).watchAnnotations(bookId);
});

/// Bookmarks for a book, reactive.
final bookmarksProvider = StreamProvider.family<List<Bookmark>, String>((
  ref,
  bookId,
) {
  return ref.watch(annotationRepositoryProvider).watchBookmarks(bookId);
});

final annotationControllerProvider =
    Provider.family<AnnotationController, String>(
  (ref, bookId) => AnnotationController(ref, bookId),
);

/// Imperative annotation actions for the reader UI.
class AnnotationController {
  AnnotationController(this._ref, this.bookId);

  final Ref _ref;
  final String bookId;
  static const _uuid = Uuid();

  AnnotationRepository get _repo => _ref.read(annotationRepositoryProvider);

  Future<void> addHighlight({
    required int start,
    required int end,
    required String text,
    int? colorValue,
    AnnotationType type = AnnotationType.highlight,
  }) {
    final now = DateTime.now();
    return _repo.saveAnnotation(
      Annotation(
        id: _uuid.v4(),
        bookId: bookId,
        type: type,
        createdAt: now,
        updatedAt: now,
        selectedText: text,
        colorValue: colorValue,
        startOffset: start,
        endOffset: end,
      ),
    );
  }

  Future<void> addNote({
    required int start,
    required int end,
    required String selectedText,
    required String noteText,
  }) {
    final now = DateTime.now();
    return _repo.saveAnnotation(
      Annotation(
        id: _uuid.v4(),
        bookId: bookId,
        type: AnnotationType.note,
        createdAt: now,
        updatedAt: now,
        selectedText: selectedText,
        noteText: noteText,
        startOffset: start,
        endOffset: end,
      ),
    );
  }

  Future<void> deleteAnnotation(String id) => _repo.deleteAnnotation(id);

  Future<void> addBookmark({
    required double percent,
    required int charOffset,
    String? label,
    String? chapterTitle,
    String? previewText,
  }) {
    return _repo.saveBookmark(
      Bookmark(
        id: _uuid.v4(),
        bookId: bookId,
        createdAt: DateTime.now(),
        label: label,
        percent: percent,
        charOffset: charOffset,
        chapterTitle: chapterTitle,
        previewText: previewText,
      ),
    );
  }

  Future<void> deleteBookmark(String id) => _repo.deleteBookmark(id);

  Future<String> exportNotes() async {
    final result = await _repo.exportNotes(bookId);
    return result.valueOrNull ?? '';
  }
}
