import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/parsers/plain_text_parser.dart';
import 'package:lumen/domain/entities/book.dart';
import 'package:lumen/domain/entities/book_content.dart';
import 'package:lumen/domain/entities/enums.dart';

void main() {
  late Directory tempDir;
  const parser = PlainTextParser();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lumen_txt_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<Book> writeBook(String contents) async {
    final file = File('${tempDir.path}/sample.txt');
    await file.writeAsString(contents);
    return Book(
      id: 'b1',
      title: 'sample',
      author: 'Unknown',
      format: BookFormat.txt,
      filePath: file.path,
      fileSizeBytes: contents.length,
      pageCount: 1,
      dateImported: DateTime(2026),
    );
  }

  test('splits paragraphs and detects a heading as a new chapter', () async {
    final book = await writeBook(
      'CHAPTER ONE\n\n'
      'The first paragraph of prose sits here, long enough to be a sentence.\n\n'
      'A second paragraph follows the first one.\n\n'
      'CHAPTER TWO\n\n'
      'The story continues in a brand new chapter entirely.',
    );

    final result = await parser.extractContent(book);
    final content = result.valueOrNull!;
    expect(content.chapters.length, 2);
    expect(content.chapters.first.title, 'CHAPTER ONE');
    expect(content.chapters[1].title, 'CHAPTER TWO');
  });

  test('classifies lists and quotes', () async {
    final book = await writeBook(
      'Intro paragraph that is clearly prose and not a heading at all.\n\n'
      '- first item\n- second item\n- third item\n\n'
      '> a wise quotation worth remembering',
    );

    final result = await parser.extractContent(book);
    final blocks = result.valueOrNull!.blocks.toList();
    expect(blocks.any((b) => b.type == BlockType.list), isTrue);
    expect(blocks.any((b) => b.type == BlockType.quote), isTrue);
  });

  test('char offsets are monotonically increasing', () async {
    final book = await writeBook(
      'Para one is here.\n\nPara two is here.\n\nPara three is here.',
    );
    final blocks = (await parser.extractContent(
      book,
    ))
        .valueOrNull!
        .blocks
        .toList();
    for (var i = 1; i < blocks.length; i++) {
      expect(
        blocks[i].charOffset,
        greaterThanOrEqualTo(blocks[i - 1].charOffset),
      );
    }
  });

  test('metadata estimates a page count from word count', () async {
    final book = await writeBook(List.filled(600, 'word').join(' '));
    final meta = (await parser.extractMetadata(book.filePath)).valueOrNull!;
    expect(meta.pageCount, greaterThanOrEqualTo(2));
    expect(meta.title, 'sample');
  });
}
