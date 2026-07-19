import 'dart:io';

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
      final sample = PdfTextExtractor(doc).extractText(
        startPageIndex: 0,
        endPageIndex: (count - 1).clamp(0, 4),
      );
      final isImageOnly = sample.trim().length < 8;

      return Result.success(DocumentMetadata(
        title: (info.title.isNotEmpty)
            ? info.title
            : p.basenameWithoutExtension(filePath),
        author: info.author.isNotEmpty ? info.author : 'Unknown',
        pageCount: count,
        isImageOnly: isImageOnly,
      ));
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
        for (final para in text.split(RegExp(r'\n\s*\n'))) {
          final clean = para.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (clean.isEmpty) continue;
          blocks.add(ContentBlock(
            type: BlockType.paragraph,
            text: clean,
            charOffset: offset,
          ));
          offset += clean.length + 1;
          wordCount += clean.split(' ').length;
        }
      }

      if (blocks.isEmpty) {
        return const Result.failure(DocumentFailure(
          'This PDF has no extractable text (likely scanned). OCR (M8) will '
          'build Smart content.',
        ));
      }

      return Result.success(BookContent(
        bookId: book.id,
        chapters: [
          Chapter(id: 'ch-0', title: book.title, order: 0, blocks: blocks),
        ],
        generatedAt: DateTime.now(),
        wordCount: wordCount,
      ));
    } on Object catch (e) {
      return Result.failure(DocumentFailure('Could not parse PDF.', cause: e));
    } finally {
      doc?.dispose();
    }
  }
}
