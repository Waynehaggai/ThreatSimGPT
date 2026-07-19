import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/repositories/in_memory_annotation_repository.dart';
import 'package:lumen/domain/entities/annotation.dart';
import 'package:lumen/domain/entities/bookmark.dart';
import 'package:lumen/domain/entities/enums.dart';

void main() {
  late InMemoryAnnotationRepository repo;
  final now = DateTime(2026);

  setUp(() => repo = InMemoryAnnotationRepository());

  Annotation ann(String id, {String text = 'selected', String? note}) =>
      Annotation(
        id: id,
        bookId: 'b1',
        type: note == null ? AnnotationType.highlight : AnnotationType.note,
        createdAt: now,
        updatedAt: now,
        selectedText: text,
        noteText: note,
        startOffset: 0,
        endOffset: text.length,
      );

  test('saved annotations appear in the book stream', () async {
    await repo.saveAnnotation(ann('a1'));
    final list = await repo.watchAnnotations('b1').first;
    expect(list, hasLength(1));
  });

  test('deleting tombstones the annotation (excluded from the stream)', () async {
    await repo.saveAnnotation(ann('a1'));
    await repo.deleteAnnotation('a1');
    final list = await repo.watchAnnotations('b1').first;
    expect(list, isEmpty);
  });

  test('search matches highlighted text and note bodies', () async {
    await repo.saveAnnotation(ann('a1', text: 'the quick brown fox'));
    await repo.saveAnnotation(ann('a2', text: 'x', note: 'remember Newton'));

    expect((await repo.searchAnnotations('brown')).valueOrNull, hasLength(1));
    expect((await repo.searchAnnotations('newton')).valueOrNull, hasLength(1));
    expect((await repo.searchAnnotations('zzz')).valueOrNull, isEmpty);
  });

  test('bookmarks save, stream, and tombstone on delete', () async {
    final bm = Bookmark(
      id: 'bm1',
      bookId: 'b1',
      createdAt: now,
      percent: 0.4,
    );
    await repo.saveBookmark(bm);
    expect(await repo.watchBookmarks('b1').first, hasLength(1));

    await repo.deleteBookmark('bm1');
    expect(await repo.watchBookmarks('b1').first, isEmpty);
  });

  test('exportNotes produces markdown for the book', () async {
    await repo.saveAnnotation(ann('a1', text: 'a memorable line'));
    final md = (await repo.exportNotes('b1')).valueOrNull!;
    expect(md, contains('a memorable line'));
    expect(md, contains('#'));
  });
}
