import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/local/isar_ids.dart';

void main() {
  group('fastHash', () {
    test('is deterministic for the same input', () {
      const uid = '3f2504e0-4f89-41d3-9a0c-0305e82c3301';
      expect(fastHash(uid), fastHash(uid));
    });

    test('differs for different inputs (no trivial collisions)', () {
      final a = fastHash('book-alpha');
      final b = fastHash('book-beta');
      expect(a, isNot(equals(b)));
    });

    test('distributes a batch of ids without collision', () {
      final ids = <int>{};
      for (var i = 0; i < 5000; i++) {
        ids.add(fastHash('book-$i'));
      }
      expect(ids.length, 5000);
    });
  });
}
