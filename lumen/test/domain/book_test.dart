import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/entities/book.dart';
import 'package:lumen/domain/entities/enums.dart';

void main() {
  Book book({double progress = 0.0, BookFormat format = BookFormat.pdf}) => Book(
        id: 'b1',
        title: 'Test',
        author: 'Author',
        format: format,
        filePath: '/tmp/test.pdf',
        fileSizeBytes: 1000,
        pageCount: 100,
        dateImported: DateTime(2026),
        progressPercent: progress,
      );

  test('BookFormat.fromExtension maps common extensions', () {
    expect(BookFormat.fromExtension('.pdf'), BookFormat.pdf);
    expect(BookFormat.fromExtension('EPUB'), BookFormat.epub);
    expect(BookFormat.fromExtension('.xyz'), BookFormat.unknown);
  });

  test('isFinished reflects progress at/above 100%', () {
    expect(book(progress: 1.0).isFinished, isTrue);
    expect(book(progress: 0.5).isFinished, isFalse);
  });

  test('supportsBothModes is true for PDFs (fixed layout + smart-capable)', () {
    expect(book(format: BookFormat.pdf).supportsBothModes, isTrue);
    expect(book(format: BookFormat.txt).supportsBothModes, isFalse);
  });

  test('copyWith preserves identity and updates fields', () {
    final b = book();
    final updated = b.copyWith(isFavorite: true, progressPercent: 0.3);
    expect(updated.id, b.id);
    expect(updated.isFavorite, isTrue);
    expect(updated.progressPercent, 0.3);
    expect(updated, equals(b)); // equality is id-based
  });
}
