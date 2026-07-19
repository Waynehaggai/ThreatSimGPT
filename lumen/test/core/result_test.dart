import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/error/failures.dart';
import 'package:lumen/core/result/result.dart';

void main() {
  group('Result', () {
    test('success carries a value and folds to onSuccess', () {
      const result = Result<int>.success(42);
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, 42);
      expect(
        result.fold(onSuccess: (v) => v * 2, onFailure: (_) => -1),
        84,
      );
    });

    test('failure carries a Failure and folds to onFailure', () {
      const result = Result<int>.failure(ValidationFailure('bad'));
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(
        result.fold(onSuccess: (_) => 'ok', onFailure: (f) => f.message),
        'bad',
      );
    });

    test('map transforms success and preserves failure', () {
      const ok = Result<int>.success(3);
      expect(ok.map((v) => v + 1).valueOrNull, 4);

      const err = Result<int>.failure(StorageFailure('x'));
      expect(err.map((v) => v + 1).isFailure, isTrue);
    });
  });
}
