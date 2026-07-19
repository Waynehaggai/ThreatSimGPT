import 'dart:async';

import '../../core/result/result.dart';
import '../../domain/entities/annotation.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/repositories/annotation_repository.dart';

/// Pure-Dart [AnnotationRepository] used as the default (and in tests), so
/// highlights, notes and bookmarks work without Isar configured. Production
/// swaps in `IsarAnnotationRepository` via the DI bootstrap. Deletions are
/// tombstoned, mirroring the persistent implementation.
class InMemoryAnnotationRepository implements AnnotationRepository {
  final Map<String, Annotation> _annotations = {};
  final Map<String, Bookmark> _bookmarks = {};
  final _annotationsCtrl = StreamController<void>.broadcast();
  final _bookmarksCtrl = StreamController<void>.broadcast();

  List<Annotation> _annotationsFor(String bookId) => _annotations.values
      .where((a) => a.bookId == bookId && !a.isDeleted)
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  List<Bookmark> _bookmarksFor(String bookId) => _bookmarks.values
      .where((b) => b.bookId == bookId && !b.isDeleted)
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  @override
  Stream<List<Annotation>> watchAnnotations(String bookId) async* {
    yield _annotationsFor(bookId);
    yield* _annotationsCtrl.stream.map((_) => _annotationsFor(bookId));
  }

  @override
  Future<Result<void>> saveAnnotation(Annotation annotation) async {
    _annotations[annotation.id] = annotation;
    _annotationsCtrl.add(null);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> deleteAnnotation(String id) async {
    final a = _annotations[id];
    if (a != null) {
      _annotations[id] = a.copyWith(isDeleted: true, updatedAt: DateTime.now());
      _annotationsCtrl.add(null);
    }
    return const Result.success(null);
  }

  @override
  Stream<List<Bookmark>> watchBookmarks(String bookId) async* {
    yield _bookmarksFor(bookId);
    yield* _bookmarksCtrl.stream.map((_) => _bookmarksFor(bookId));
  }

  @override
  Future<Result<void>> saveBookmark(Bookmark bookmark) async {
    _bookmarks[bookmark.id] = bookmark;
    _bookmarksCtrl.add(null);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> deleteBookmark(String id) async {
    final b = _bookmarks[id];
    if (b != null) {
      _bookmarks[id] = b.copyWith(isDeleted: true);
      _bookmarksCtrl.add(null);
    }
    return const Result.success(null);
  }

  @override
  Future<Result<List<Annotation>>> searchAnnotations(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const Result.success(<Annotation>[]);
    final matches = _annotations.values.where((a) {
      if (a.isDeleted) return false;
      return a.selectedText.toLowerCase().contains(q) ||
          (a.noteText?.toLowerCase().contains(q) ?? false);
    }).toList();
    return Result.success(matches);
  }

  @override
  Future<Result<String>> exportNotes(String bookId, {String format = 'md'}) async {
    final buffer = StringBuffer('# Notes & Highlights\n\n');
    for (final a in _annotationsFor(bookId)) {
      if (a.selectedText.isNotEmpty) buffer.writeln('> ${a.selectedText}');
      if (a.noteText?.isNotEmpty ?? false) buffer.writeln('\n${a.noteText}');
      buffer.writeln('\n---\n');
    }
    return Result.success(buffer.toString());
  }
}
