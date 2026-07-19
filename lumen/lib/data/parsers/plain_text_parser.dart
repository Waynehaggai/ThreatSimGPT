import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/error/failures.dart';
import '../../core/result/result.dart';
import '../../domain/entities/book.dart';
import '../../domain/entities/book_content.dart';
import '../../domain/entities/enums.dart';
import '../../domain/services/document_parser.dart';

/// Parses `.txt` documents into reflowable [BookContent].
///
/// This is a complete, native-dependency-free [DocumentParser] — importing a
/// text file yields a genuinely working Smart Reading experience. It also serves
/// as the reference implementation the PDF/EPUB/DOCX parsers (M2) follow: emit
/// [ContentBlock]s carrying an absolute [ContentBlock.charOffset] so highlights,
/// bookmarks and resume points survive reflow.
class PlainTextParser implements DocumentParser {
  const PlainTextParser();

  @override
  Set<BookFormat> get supportedFormats => const {BookFormat.txt};

  @override
  Future<Result<DocumentMetadata>> extractMetadata(String filePath) async {
    try {
      final file = File(filePath);
      final text = await file.readAsString();
      final words = _wordCount(text);
      return Result.success(
        DocumentMetadata(
          title: p.basenameWithoutExtension(filePath),
          author: 'Unknown',
          // ~300 words per page is a common paperback estimate.
          pageCount: (words / 300).ceil().clamp(1, 1 << 30),
        ),
      );
    } on Object catch (e) {
      return Result.failure(
          DocumentFailure('Could not read text file.', cause: e));
    }
  }

  @override
  Future<Result<BookContent>> extractContent(Book book) async {
    try {
      final text = await File(book.filePath).readAsString();
      final chapters = _parse(text);
      return Result.success(
        BookContent(
          bookId: book.id,
          chapters: chapters,
          generatedAt: DateTime.now(),
          wordCount: _wordCount(text),
        ),
      );
    } on Object catch (e) {
      return Result.failure(
          DocumentFailure('Could not parse text file.', cause: e));
    }
  }

  // ── Parsing ────────────────────────────────────────────────────────────
  List<Chapter> _parse(String text) {
    final normalized = text.replaceAll('\r\n', '\n');
    final rawParagraphs = normalized.split(RegExp(r'\n\s*\n'));

    final chapters = <Chapter>[];
    var chapterBlocks = <ContentBlock>[];
    var chapterTitle = 'Beginning';
    var chapterOrder = 0;
    var offset = 0;

    void flushChapter() {
      if (chapterBlocks.isEmpty) return;
      chapters.add(Chapter(
        id: 'ch-$chapterOrder',
        title: chapterTitle,
        order: chapterOrder,
        blocks: List.unmodifiable(chapterBlocks),
      ));
      chapterOrder++;
      chapterBlocks = <ContentBlock>[];
    }

    for (final raw in rawParagraphs) {
      final para = raw.trim();
      if (para.isEmpty) {
        offset += raw.length + 2;
        continue;
      }

      final block = _classify(para, offset);

      // A heading starts a new chapter (unless it's the very first block).
      if (block.type == BlockType.heading) {
        if (chapterBlocks.isNotEmpty) flushChapter();
        chapterTitle = para;
      }
      chapterBlocks.add(block);
      offset += raw.length + 2; // account for the paragraph + blank separator
    }
    flushChapter();

    if (chapters.isEmpty) {
      chapters.add(const Chapter(id: 'ch-0', title: 'Beginning', order: 0));
    }
    return chapters;
  }

  ContentBlock _classify(String para, int charOffset) {
    final lines = para.split('\n');

    // Bulleted / numbered list.
    if (lines.every((l) => _isListLine(l.trim()))) {
      final stripped =
          lines.map((l) => l.trim().replaceFirst(RegExp(r'^([-*•]|\d+\.)\s+'), '')).join('\n');
      return ContentBlock(
          type: BlockType.list, text: stripped, charOffset: charOffset);
    }

    // Block quote.
    if (lines.every((l) => l.trimLeft().startsWith('>'))) {
      final stripped =
          lines.map((l) => l.trimLeft().replaceFirst(RegExp(r'^>\s?'), '')).join('\n');
      return ContentBlock(
          type: BlockType.quote, text: stripped, charOffset: charOffset);
    }

    // Heading heuristic: a short single line that looks like a title.
    if (lines.length == 1 && _looksLikeHeading(para)) {
      return ContentBlock(
        type: BlockType.heading,
        text: para.replaceFirst(RegExp(r'^#+\s*'), ''),
        level: _headingLevel(para),
        charOffset: charOffset,
      );
    }

    return ContentBlock(
        type: BlockType.paragraph, text: para, charOffset: charOffset);
  }

  bool _isListLine(String line) =>
      RegExp(r'^([-*•]|\d+\.)\s+').hasMatch(line);

  bool _looksLikeHeading(String line) {
    if (line.startsWith('#')) return true; // markdown heading
    if (line.length > 64) return false;
    if (RegExp(r'^(chapter|part|section)\b', caseSensitive: false)
        .hasMatch(line)) {
      return true;
    }
    // ALL-CAPS short line with no sentence-ending punctuation.
    final endsSentence = RegExp(r'[.?!]$').hasMatch(line);
    return !endsSentence && line == line.toUpperCase() && line.length <= 48;
  }

  int _headingLevel(String line) {
    final hashes = RegExp(r'^(#+)').firstMatch(line)?.group(1)?.length;
    if (hashes != null) return (hashes - 1).clamp(0, 5);
    return 0;
  }

  int _wordCount(String text) =>
      text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
}
