import '../../core/error/failures.dart';
import '../../core/result/result.dart';
import '../../domain/entities/book.dart';
import '../../domain/entities/book_content.dart';
import '../../domain/entities/enums.dart';
import '../../domain/services/document_parser.dart';

/// Dispatches parsing to the registered [DocumentParser] for a given format.
///
/// Adding a new format (PDF, EPUB, DOCX, MOBI…) is a one-line registration here
/// plus the parser implementation — the reader and import pipeline never change.
/// This is the seam the OCR fallback plugs into for image-only PDFs (M8).
class DocumentParsingServiceImpl implements DocumentParsingService {
  DocumentParsingServiceImpl(List<DocumentParser> parsers)
      : _byFormat = {
          for (final parser in parsers)
            for (final format in parser.supportedFormats) format: parser,
        };

  final Map<BookFormat, DocumentParser> _byFormat;

  @override
  Future<Result<DocumentMetadata>> inspect(
    String filePath,
    BookFormat format,
  ) async {
    final parser = _byFormat[format];
    if (parser == null) {
      return Result.failure(
          DocumentFailure('No parser registered for ${format.name}.'));
    }
    return parser.extractMetadata(filePath);
  }

  @override
  Future<Result<BookContent>> buildSmartContent(Book book) async {
    final parser = _byFormat[book.format];
    if (parser == null) {
      return Result.failure(
          DocumentFailure('No parser registered for ${book.format.name}.'));
    }
    return parser.extractContent(book);
  }
}
