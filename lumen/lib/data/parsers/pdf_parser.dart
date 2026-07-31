import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../core/error/failures.dart';
import '../../core/result/result.dart';
import '../../domain/entities/book.dart';
import '../../domain/entities/book_content.dart';
import '../../domain/entities/enums.dart';
import '../../domain/services/document_parser.dart';

/// Extracts text + structure from `.pdf` documents (via
/// `syncfusion_flutter_pdf`) for Smart Reading Mode, and flags scanned
/// (image-only) PDFs so the OCR pipeline (M8) can build Smart content.
///
/// Original Mode still renders the authored PDF via `pdfrx`; this parser only
/// produces the reflowable representation. Native/third-party parsing — verified
/// on device. Cover rasterization is handled by the viewer layer, so no cover is
/// emitted here.
class PdfParser implements DocumentParser {
  const PdfParser();

  @override
  Set<BookFormat> get supportedFormats => const {BookFormat.pdf};

  @override
  Future<Result<DocumentMetadata>> extractMetadata(String filePath) async {
    PdfDocument? doc;
    try {
      doc = PdfDocument(inputBytes: await File(filePath).readAsBytes());
      final count = doc.pages.count;
      final info = doc.documentInformation;

      // Sample the first few pages to decide whether the PDF is image-only.
      final sample = PdfTextExtractor(
        doc,
      ).extractText(startPageIndex: 0, endPageIndex: (count - 1).clamp(0, 4));
      final isImageOnly = sample.trim().length < 8;

      return Result.success(
        DocumentMetadata(
          title: (info.title.isNotEmpty)
              ? info.title
              : p.basenameWithoutExtension(filePath),
          author: info.author.isNotEmpty ? info.author : 'Unknown',
          pageCount: count,
          isImageOnly: isImageOnly,
        ),
      );
    } on Object catch (e) {
      return Result.failure(DocumentFailure('Could not read PDF.', cause: e));
    } finally {
      doc?.dispose();
    }
  }

  @override
  Future<Result<BookContent>> extractContent(Book book) async {
    PdfDocument? doc;
    try {
      doc = PdfDocument(inputBytes: await File(book.filePath).readAsBytes());
      final count = doc.pages.count;
      final extractor = PdfTextExtractor(doc);

      final blocks = <ContentBlock>[];
      var offset = 0;
      var wordCount = 0;

      for (var page = 0; page < count; page++) {
        final text = extractor.extractText(
          startPageIndex: page,
          endPageIndex: page,
        );
        for (final block in structurePdfText(text)) {
          blocks.add(
            ContentBlock(
              type: block.type,
              text: block.text,
              level: block.level,
              charOffset: offset,
            ),
          );
          offset += block.text.length + 1;
          wordCount += block.text
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .length;
        }
      }

      if (blocks.isEmpty) {
        return const Result.failure(
          DocumentFailure(
            'This PDF has no extractable text (likely scanned). OCR (M8) will '
            'build Smart content.',
          ),
        );
      }

      return Result.success(
        BookContent(
          bookId: book.id,
          chapters: [
            Chapter(id: 'ch-0', title: book.title, order: 0, blocks: blocks),
          ],
          generatedAt: DateTime.now(),
          wordCount: wordCount,
        ),
      );
    } on Object catch (e) {
      return Result.failure(DocumentFailure('Could not parse PDF.', cause: e));
    } finally {
      doc?.dispose();
    }
  }
}

/// A structured block recovered from raw extracted text.
class StructuredBlock {
  const StructuredBlock(this.type, this.text, this.level);
  final BlockType type;
  final String text;
  final int level;
}

// A line that opens a list item: "1.", "1)", "a)", "iv)", or a bullet glyph.
// Deliberately conservative so ordinary prose ("I. went home") is not mistaken
// for a list.
final _listItem = RegExp(
  r'^(\d{1,3}[.)]|[a-z][)]|[ivxlcdm]{1,5}[)]|[-•*▪◦‣·])\s+\S',
);

/// Rebuilds readable structure from a PDF page's raw extracted text.
///
/// PDF text extraction emits one line per *visual* line, so a single paragraph
/// arrives as many hard-wrapped lines. This reflows those wrapped lines back
/// into paragraphs (de-hyphenating words split across a line break), keeps
/// numbered / bulleted items on their own lines, and lifts obvious headings —
/// giving Smart Mode the paragraph structure a reader expects instead of one
/// flattened wall of text.
List<StructuredBlock> structurePdfText(String pageText) {
  final lines = pageText
      .split('\n')
      .map((l) => l.replaceAll(RegExp(r'[ \t ]+'), ' ').trimRight())
      .toList();

  // The widest line approximates a full column width; a line much shorter than
  // that is likely the last line of a paragraph rather than a mid-wrap.
  var maxLen = 0;
  for (final l in lines) {
    maxLen = math.max(maxLen, l.trim().length);
  }
  final wrapThreshold = maxLen * 0.72;

  final out = <StructuredBlock>[];
  final buf = StringBuffer();
  var bufIsList = false;

  void flush() {
    final t = buf.toString().trim();
    if (t.isNotEmpty) {
      out.add(
        StructuredBlock(bufIsList ? BlockType.list : BlockType.paragraph, t, 0),
      );
    }
    buf.clear();
    bufIsList = false;
  }

  void appendWrapped(String line) {
    if (buf.isEmpty) {
      buf.write(line);
      return;
    }
    final prev = buf.toString();
    if (prev.endsWith('-') && !prev.endsWith(' -')) {
      // Word hyphenated across a line break — rejoin without the hyphen.
      buf
        ..clear()
        ..write(prev.substring(0, prev.length - 1))
        ..write(line);
    } else {
      buf
        ..write(' ')
        ..write(line);
    }
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) {
      flush();
      continue;
    }

    final isMarker = _listItem.hasMatch(line);
    if (isMarker) {
      flush(); // a new marker always starts a fresh item
      bufIsList = true;
      buf.write(line);
    } else if (buf.isEmpty && _headingLevel(line) != null) {
      // Headings are only recognised at a block boundary, so a heading-looking
      // line mid-paragraph is treated as ordinary wrapped text.
      out.add(StructuredBlock(BlockType.heading, line, _headingLevel(line)!));
      continue;
    } else {
      // Paragraph text, or a wrapped continuation of the current list item.
      appendWrapped(line);
    }

    final endsSentence = RegExp('[.!?:"\'”’)]\$').hasMatch(line);
    final isShort = line.length < wrapThreshold;
    final next = i + 1 < lines.length ? lines[i + 1].trim() : '';
    final nextStartsBlock = next.isEmpty || _listItem.hasMatch(next);
    if (bufIsList) {
      // A list item runs until it closes a sentence or the next line opens a
      // new item / blank — so wrapped items stay whole without swallowing the
      // paragraph that follows.
      if (endsSentence || nextStartsBlock) flush();
    } else if ((isShort && endsSentence) || nextStartsBlock) {
      flush();
    }
  }
  flush();
  return out;
}

/// A conservative heading test: short lines that don't read like a sentence —
/// an explicit "Chapter/Part/Section …", or a short ALL-CAPS title.
int? _headingLevel(String line) {
  if (line.length > 64) return null;
  if (RegExp(r'[.,;:!?]$').hasMatch(line)) return null;
  if (RegExp(r'^(chapter|part|section|book)\b', caseSensitive: false)
      .hasMatch(line)) {
    return 0;
  }
  final letters = line.replaceAll(RegExp('[^A-Za-z]'), '');
  final words = line.split(' ').where((w) => w.isNotEmpty).length;
  if (letters.length >= 3 && letters == letters.toUpperCase() && words <= 10) {
    return 1;
  }
  return null;
}
