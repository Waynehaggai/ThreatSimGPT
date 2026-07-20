import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/sync/conflict_resolver.dart';
import 'package:lumen/domain/entities/annotation.dart';
import 'package:lumen/domain/entities/enums.dart';
import 'package:lumen/domain/entities/reading_progress.dart';

void main() {
  const resolver = ConflictResolver();
  final t0 = DateTime(2026, 1, 1, 10);
  final t1 = DateTime(2026, 1, 1, 11);

  ReadingProgress progress(String device, DateTime at, double pct) =>
      ReadingProgress(
        bookId: 'b1',
        deviceId: device,
        updatedAt: at,
        percent: pct,
      );

  Annotation ann(
    String id,
    DateTime at, {
    bool deleted = false,
    String? note,
  }) =>
      Annotation(
        id: id,
        bookId: 'b1',
        type: AnnotationType.highlight,
        createdAt: t0,
        updatedAt: at,
        noteText: note,
        isDeleted: deleted,
      );

  group('resolveProgress', () {
    test('keeps the newest reading position', () {
      final local = progress('A', t0, 0.3);
      final remote = progress('B', t1, 0.5);
      expect(resolver.resolveProgress(local, remote), remote);
    });

    test('never moves progress backwards on a timestamp tie', () {
      final behind = progress('A', t0, 0.2);
      final ahead = progress('B', t0, 0.6);
      expect(resolver.resolveProgress(behind, ahead).percent, 0.6);
    });

    test('returns the non-null side when one is missing', () {
      final only = progress('A', t0, 0.4);
      expect(resolver.resolveProgress(null, only), only);
      expect(resolver.resolveProgress(only, null), only);
    });
  });

  group('mergeAnnotations', () {
    test('unions disjoint annotations from both devices', () {
      final merged = resolver.mergeAnnotations([ann('1', t0)], [ann('2', t0)]);
      expect(merged.map((a) => a.id).toSet(), {'1', '2'});
    });

    test('newer edit wins for the same id', () {
      final merged = resolver.mergeAnnotations(
        [ann('1', t0, note: 'old')],
        [ann('1', t1, note: 'new')],
      );
      expect(merged.single.noteText, 'new');
    });

    test('a newer deletion overrides an older edit', () {
      final merged = resolver.mergeAnnotations(
        [ann('1', t0)],
        [ann('1', t1, deleted: true)],
      );
      expect(merged.single.isDeleted, isTrue);
    });

    test('an older deletion does not erase a newer edit', () {
      final merged = resolver.mergeAnnotations(
        [ann('1', t1, note: 'restored')],
        [ann('1', t0, deleted: true)],
      );
      expect(merged.single.isDeleted, isFalse);
      expect(merged.single.noteText, 'restored');
    });
  });
}
