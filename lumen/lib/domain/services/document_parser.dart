import '../../core/result/result.dart';
import '../entities/book.dart';
import '../entities/book_content.dart';
import '../entities/enums.dart';

/// Extracted metadata produced while importing a document.
class DocumentMetadata {
  const DocumentMetadata({
    required this.title,
    required this.author,
    required this.pageCount,
    this.coverImagePath,
    this.language,
    this.isImageOnly = false,
  });

  final String title;
  final String author;
  final int pageCount;
  final String? coverImagePath;
  final String? language;

  /// `true` for scanned PDFs with no embedded text — triggers OCR.
  final bool isImageOnly;
}

/// Strategy interface for parsing one book format. Registering a new
/// [DocumentParser] (e.g. for MOBI) is the only change needed to support a new
/// format — the import pipeline and reader are format-agnostic.
abstract interface class DocumentParser {
  /// Formats this parser handles.
  Set<BookFormat> get supportedFormats;

  /// Reads title/author/pages/cover without loading the whole document.
  Future<Result<DocumentMetadata>> extractMetadata(String filePath);

  /// Builds reflowable Smart Reading content (chapters, headings, blocks).
  Future<Result<BookContent>> extractContent(Book book);
}

/// Facade that dispatches to the correct [DocumentParser] by format and owns
/// the OCR fallback for image-only PDFs.
abstract interface class DocumentParsingService {
  Future<Result<DocumentMetadata>> inspect(String filePath, BookFormat format);
  Future<Result<BookContent>> buildSmartContent(Book book);
}
