// NOTE: This test imports Isar model classes, which depend on generated
// `*.g.dart` files. Run `dart run build_runner build` before `flutter test`.
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/mappers/library_mappers.dart';
import 'package:lumen/data/mappers/reading_mappers.dart';
import 'package:lumen/data/mappers/sync_mappers.dart';
import 'package:lumen/domain/entities/book.dart';
import 'package:lumen/domain/entities/enums.dart';
import 'package:lumen/domain/entities/reading_progress.dart';
import 'package:lumen/domain/entities/reading_stats.dart';
import 'package:lumen/domain/entities/sync_operation.dart';

void main() {
  test('Book survives a model round-trip', () {
    final book = Book(
      id: 'b-1',
      title: 'Test',
      author: 'Author',
      format: BookFormat.epub,
      filePath: '/x/test.epub',
      fileSizeBytes: 1234,
      pageCount: 320,
      dateImported: DateTime(2026, 3, 14),
      progressPercent: 0.42,
      isFavorite: true,
      collectionIds: const ['c1', 'c2'],
      defaultMode: ReadingMode.smart,
    );

    final restored = book.toModel().toEntity();
    expect(restored.id, book.id);
    expect(restored.format, BookFormat.epub);
    expect(restored.progressPercent, 0.42);
    expect(restored.isFavorite, isTrue);
    expect(restored.collectionIds, ['c1', 'c2']);
  });

  test('ReadingProgress survives a model round-trip', () {
    final progress = ReadingProgress(
      bookId: 'b-1',
      updatedAt: DateTime(2026, 3, 14, 9, 30),
      deviceId: 'device-A',
      page: 12,
      percent: 0.33,
      mode: ReadingMode.original,
      ttsSentenceIndex: 7,
    );
    final restored = progress.toModel().toEntity();
    expect(restored.deviceId, 'device-A');
    expect(restored.mode, ReadingMode.original);
    expect(restored.ttsSentenceIndex, 7);
  });

  test('ReadingStats genre map round-trips through JSON', () {
    const stats = ReadingStats(
      booksCompleted: 3,
      genreMinutes: {'Sci-Fi': 120, 'History': 45},
      minutesByHour: [0, 0, 0],
    );
    final restored = stats.toModel().toEntity();
    expect(restored.genreMinutes['Sci-Fi'], 120);
    expect(restored.genreMinutes['History'], 45);
    expect(restored.booksCompleted, 3);
  });

  test('SyncOperation payload round-trips through JSON', () {
    final op = SyncOperation(
      id: 'op-1',
      entityType: SyncEntityType.progress,
      entityId: 'b-1',
      action: SyncAction.update,
      createdAt: DateTime(2026),
      payload: const {'percent': 0.5, 'page': 10},
    );
    final restored = op.toModel().toEntity();
    expect(restored.payload?['percent'], 0.5);
    expect(restored.entityType, SyncEntityType.progress);
  });
}
