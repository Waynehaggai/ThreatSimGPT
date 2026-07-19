import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../core/error/failures.dart';
import '../../core/result/result.dart';
import '../../domain/entities/book.dart';
import '../../domain/entities/book_content.dart';
import '../../domain/entities/enums.dart';
import '../../domain/services/document_parser.dart';
import 'html_block_parser.dart';

/// Parses `.epub` documents (via `package:epubx`) into metadata + reflowable
/// [BookContent], reusing [parseHtmlToBlocks] for each chapter's HTML.
///
/// EPUB reading uses native file bytes and third-party parsing; this parser is
/// verified on device rather than in the pure-Dart suite (the HTML→blocks step
/// it depends on is separately unit-tested).
class EpubParser implements DocumentParser {
  const EpubParser();

  @override
  Set<BookFormat> get supportedFormats => const {BookFormat.epub};

  @override
  Future<Result<DocumentMetadata>> extractMetadata(String filePath) async {
    try {
      final book = await EpubReader.readBook(await File(filePath).readAsBytes());
      final wordCount = _estimateWords(book);
      final coverPath = await _writeCover(book, filePath);
      return Result.success(DocumentMetadata(
        title: book.Title ?? p.basenameWithoutExtension(filePath),
        author: book.Author ?? 'Unknown',
        pageCount: (wordCount / 300).ceil().clamp(1, 1 << 30),
        coverImagePath: coverPath,
      ));
    } on Object catch (e) {
      return Result.failure(DocumentFailure('Could not read EPUB.', cause: e));
    }
  }

  @override
  Future<Result<BookContent>> extractContent(Book book) async {
    try {
      final epub =
          await EpubReader.readBook(await File(book.filePath).readAsBytes());
      final chapters = <Chapter>[];
      var offset = 0;
      var order = 0;

      void walk(List<EpubChapter> src, int level) {
        for (final ch in src) {
          final blocks = parseHtmlToBlocks(ch.HtmlContent ?? '', startOffset: offset);
          if (blocks.isNotEmpty) {
            offset = blocks.last.charOffset + (blocks.last.text?.length ?? 0) + 1;
          }
          chapters.add(Chapter(
            id: 'ch-$order',
            title: ch.Title ?? 'Chapter ${order + 1}',
            order: order,
            level: level,
            blocks: blocks,
          ));
          order++;
          if (ch.SubChapters?.isNotEmpty ?? false) {
            walk(ch.SubChapters!, level + 1);
          }
        }
      }

      walk(epub.Chapters ?? const [], 0);
      return Result.success(BookContent(
        bookId: book.id,
        chapters: chapters,
        generatedAt: DateTime.now(),
        wordCount: _estimateWords(epub),
      ));
    } on Object catch (e) {
      return Result.failure(DocumentFailure('Could not parse EPUB.', cause: e));
    }
  }

  int _estimateWords(EpubBook book) {
    var chars = 0;
    for (final ch in book.Chapters ?? const <EpubChapter>[]) {
      chars += (ch.HtmlContent?.length ?? 0);
    }
    // Rough: ~5.5 chars per word after markup.
    return (chars / 5.5).round();
  }

  Future<String?> _writeCover(EpubBook book, String filePath) async {
    final cover = book.CoverImage;
    if (cover == null) return null;
    try {
      final png = img.encodePng(cover);
      final dir = p.dirname(filePath);
      final coverPath =
          p.join(dir, '${p.basenameWithoutExtension(filePath)}.cover.png');
      await File(coverPath).writeAsBytes(png);
      return coverPath;
    } on Object {
      return null; // cover is best-effort
    }
  }
}
