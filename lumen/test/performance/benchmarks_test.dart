import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/repositories/library_query_matcher.dart';
import 'package:lumen/data/local/isar_ids.dart';
import 'package:lumen/data/sync/sync_queue.dart';
import 'package:lumen/domain/entities/book.dart';
import 'package:lumen/domain/entities/enums.dart';
import 'package:lumen/domain/entities/sync_operation.dart';
import 'package:lumen/domain/repositories/library_repository.dart';
import 'package:lumen/features/reader/presentation/rendering/page_packer.dart';

/// Performance guardrails for the perf-critical pure logic (the spec targets
/// 20,000+-book libraries and 2,000+-page documents). Thresholds are generous
/// so the suite stays stable across CI hardware while still catching a
/// regression into quadratic behaviour.
void main() {
  test('library query over 20,000 books filters + sorts quickly', () {
    final library = [
      for (var i = 0; i < 20000; i++)
        Book(
          id: 'b$i',
          title: 'Book $i ${i % 3 == 0 ? 'Dune' : 'Other'}',
          author: 'Author ${i % 500}',
          format: BookFormat.epub,
          filePath: '/x/$i.epub',
          fileSizeBytes: i,
          pageCount: 100,
          dateImported: DateTime(2026).add(Duration(minutes: i)),
          isArchived: i % 50 == 0,
        ),
    ];

    final sw = Stopwatch()..start();
    final result = applyLibraryQuery(
      library,
      const LibraryQuery(search: 'Dune', sortBy: LibrarySort.title),
    );
    sw.stop();

    expect(result, isNotEmpty);
    expect(
      sw.elapsedMilliseconds,
      lessThan(1000),
      reason: 'query took ${sw.elapsedMilliseconds}ms',
    );
  });

  test('paginating a very long document is fast', () {
    const packer = PagePacker();
    final heights = List<double>.generate(60000, (i) => (i % 7) * 4 + 12);

    final sw = Stopwatch()..start();
    final pages = packer.pack(heights, 800);
    sw.stop();

    expect(pages, isNotEmpty);
    expect(
      sw.elapsedMilliseconds,
      lessThan(500),
      reason: 'pagination took ${sw.elapsedMilliseconds}ms',
    );
  });

  test('fastHash yields no collisions across 100k ids', () {
    final ids = <int>{};
    final sw = Stopwatch()..start();
    for (var i = 0; i < 100000; i++) {
      ids.add(fastHash('book-uuid-$i'));
    }
    sw.stop();
    expect(ids.length, 100000);
    expect(sw.elapsedMilliseconds, lessThan(500));
  });

  test('sync queue scheduling scales to thousands of pending ops', () {
    final ops = [
      for (var i = 0; i < 5000; i++)
        SyncOperation(
          id: 'op$i',
          entityType: SyncEntityType.annotation,
          entityId: 'e$i',
          action: SyncAction.update,
          createdAt: DateTime(2026).add(Duration(seconds: i)),
        ),
    ];

    final sw = Stopwatch()..start();
    final queue = SyncQueue(ops);
    final due = queue.dueOperations(DateTime(2027), limit: 100);
    sw.stop();

    expect(due, hasLength(100));
    expect(sw.elapsedMilliseconds, lessThan(500));
  });
}
