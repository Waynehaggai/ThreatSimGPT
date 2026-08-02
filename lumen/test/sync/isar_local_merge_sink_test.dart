import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/sync/isar_local_merge_sink.dart';
import 'package:lumen/data/sync/remote_data_source.dart';
import 'package:lumen/domain/entities/enums.dart';

void main() {
  test('parses a remote progress document into ReadingProgress', () {
    final change = RemoteChange(
      type: SyncEntityType.progress,
      id: 'book-1',
      updatedAt: DateTime(2026, 5, 1, 9, 30),
      data: const {'percent': 0.42, 'page': 12, 'deviceId': 'device-B'},
    );

    final progress = progressFromRemote(change)!;
    expect(progress.bookId, 'book-1');
    expect(progress.percent, 0.42);
    expect(progress.page, 12);
    expect(progress.deviceId, 'device-B');
    expect(progress.updatedAt, DateTime(2026, 5, 1, 9, 30));
  });

  test('returns null for non-progress changes', () {
    final change = RemoteChange(
      type: SyncEntityType.annotation,
      id: 'a1',
      updatedAt: DateTime(2026),
      data: const {},
    );
    expect(progressFromRemote(change), isNull);
  });

  test('tolerates missing fields with safe defaults', () {
    final change = RemoteChange(
      type: SyncEntityType.progress,
      id: 'b',
      updatedAt: DateTime(2026),
      data: const {},
    );
    final progress = progressFromRemote(change)!;
    expect(progress.percent, 0.0);
    expect(progress.page, 0);
    expect(progress.deviceId, '');
  });
}
