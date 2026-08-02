import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/entities/reading_progress.dart';

void main() {
  final t0 = DateTime(2026, 1, 1, 10);
  final t1 = DateTime(2026, 1, 1, 11);

  group('ReadingProgress.isSupersededBy', () {
    test('true when another device has strictly newer, different progress', () {
      final local = ReadingProgress(
        bookId: 'b',
        deviceId: 'A',
        updatedAt: t0,
        percent: 0.2,
      );
      final remote = ReadingProgress(
        bookId: 'b',
        deviceId: 'B',
        updatedAt: t1,
        percent: 0.5,
      );
      expect(local.isSupersededBy(remote), isTrue);
    });

    test('false for progress from the same device', () {
      final local = ReadingProgress(
        bookId: 'b',
        deviceId: 'A',
        updatedAt: t0,
        percent: 0.2,
      );
      final same = ReadingProgress(
        bookId: 'b',
        deviceId: 'A',
        updatedAt: t1,
        percent: 0.5,
      );
      expect(local.isSupersededBy(same), isFalse);
    });

    test('false when the remote position is effectively identical', () {
      final local = ReadingProgress(
        bookId: 'b',
        deviceId: 'A',
        updatedAt: t0,
        percent: 0.5,
      );
      final remote = ReadingProgress(
        bookId: 'b',
        deviceId: 'B',
        updatedAt: t1,
        percent: 0.5,
      );
      expect(local.isSupersededBy(remote), isFalse);
    });
  });
}
