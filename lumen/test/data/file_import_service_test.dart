import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/result/result.dart';
import 'package:lumen/data/services/file_import_service.dart';
import 'package:lumen/domain/entities/book.dart';
import 'package:lumen/domain/entities/book_content.dart';
import 'package:lumen/domain/entities/enums.dart';
import 'package:lumen/domain/services/document_parser.dart';

/// Fake parsing service returning canned metadata (no real parsing).
class _FakeParsing implements DocumentParsingService {
  const _FakeParsing();

  @override
  Future<Result<DocumentMetadata>> inspect(String filePath, BookFormat format) async =>
      const Result.success(DocumentMetadata(
        title: 'Parsed Title',
        author: 'Parsed Author',
        pageCount: 42,
      ));

  @override
  Future<Result<BookContent>> buildSmartContent(Book book) async =>
      Result.success(BookContent(bookId: book.id, chapters: const []));
}

void main() {
  late Directory tempDir;
  late FileImportService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lumen_import_test');
    service = FileImportService(const _FakeParsing(), storageDir: tempDir);
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<String> writeSource(String name, String contents) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsString(contents);
    return file.path;
  }

  test('copies the file into app storage and applies parsed metadata', () async {
    final src = await writeSource('novel.txt', 'Once upon a time.');
    final result = await service.prepare(src);

    final book = result.valueOrNull!;
    expect(book.title, 'Parsed Title');
    expect(book.author, 'Parsed Author');
    expect(book.pageCount, 42);
    expect(book.checksum, isNotNull);
    expect(book.fileSizeBytes, greaterThan(0));

    // The stored file is a copy under <storage>/books/, not the source path.
    expect(book.filePath, isNot(src));
    expect(book.filePath, contains('books'));
    expect(File(book.filePath).existsSync(), isTrue);
  });

  test('checksum is stable for identical content and differs otherwise', () async {
    final a = await writeSource('a.txt', 'same bytes');
    final b = await writeSource('b.txt', 'same bytes');
    final c = await writeSource('c.txt', 'different');

    final ca = (await service.checksumOf(a)).valueOrNull;
    final cb = (await service.checksumOf(b)).valueOrNull;
    final cc = (await service.checksumOf(c)).valueOrNull;

    expect(ca, cb);
    expect(ca, isNot(cc));
  });

  test('rejects unsupported formats', () async {
    final src = await writeSource('audio.mp3', 'not a book');
    final result = await service.prepare(src);
    expect(result.isFailure, isTrue);
  });

  test('fails cleanly when the source is missing', () async {
    final result = await service.prepare('${tempDir.path}/nope.txt');
    expect(result.isFailure, isTrue);
  });
}
