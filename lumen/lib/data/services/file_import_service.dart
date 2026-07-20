import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/error/failures.dart';
import '../../core/result/result.dart';
import '../../domain/entities/book.dart';
import '../../domain/entities/enums.dart';
import '../../domain/services/document_parser.dart';
import '../../domain/services/import_service.dart';

/// Default [ImportService]: checksum → copy into app storage → inspect metadata.
///
/// Pure orchestration around injected collaborators, so the file/checksum logic
/// is unit-testable with a temp directory and a fake parsing service (see
/// `test/data/file_import_service_test.dart`).
class FileImportService implements ImportService {
  FileImportService(
    this._parsing, {
    Directory? storageDir,
    Uuid uuid = const Uuid(),
    DateTime Function() now = DateTime.now,
  })  : _storageOverride = storageDir,
        _uuid = uuid,
        _now = now;

  final DocumentParsingService _parsing;
  final Directory? _storageOverride;
  final Uuid _uuid;
  final DateTime Function() _now;

  Directory? _cachedBooksDir;

  Future<Directory> _booksDir() async {
    if (_cachedBooksDir != null) return _cachedBooksDir!;
    final base = _storageOverride ?? await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'books'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return _cachedBooksDir = dir;
  }

  @override
  Future<Result<String>> checksumOf(String path) async {
    try {
      final digest = await sha256.bind(File(path).openRead()).first;
      return Result.success(digest.toString());
    } on Object catch (e) {
      return Result.failure(
        DocumentFailure('Could not read file for checksum.', cause: e),
      );
    }
  }

  @override
  Future<Result<Book>> prepare(String sourcePath) async {
    final source = File(sourcePath);
    if (!source.existsSync()) {
      return const Result.failure(DocumentFailure('Source file not found.'));
    }

    final ext = p.extension(sourcePath).replaceAll('.', '').toLowerCase();
    final format = BookFormat.fromExtension(ext);
    if (!format.supportsSmartMode && !format.hasOriginalLayout) {
      return Result.failure(DocumentFailure('Unsupported format: .$ext'));
    }

    final checksumResult = await checksumOf(sourcePath);
    if (checksumResult.isFailure) {
      return Result.failure(checksumResult.failureOrNull!);
    }
    final checksum = checksumResult.valueOrNull!;

    try {
      final id = _uuid.v4();
      final dir = await _booksDir();
      final destPath = p.join(dir.path, '$id.$ext');
      await source.copy(destPath);

      final size = await File(destPath).length();

      // Inspect metadata from the copied file (parser owns cover extraction).
      final metaResult = await _parsing.inspect(destPath, format);
      final meta = metaResult.valueOrNull;

      final needsOcr = meta?.isImageOnly ?? false;
      final book = Book(
        id: id,
        title: meta?.title ?? p.basenameWithoutExtension(sourcePath),
        author: meta?.author ?? 'Unknown',
        format: format,
        filePath: destPath,
        fileSizeBytes: size,
        pageCount: meta?.pageCount ?? 0,
        dateImported: _now(),
        coverPath: meta?.coverImagePath,
        language: meta?.language,
        checksum: checksum,
        needsOcr: needsOcr,
        // Scanned PDFs open in Original mode until OCR builds Smart content.
        defaultMode: needsOcr
            ? ReadingMode.original
            : (format.supportsSmartMode
                ? ReadingMode.smart
                : ReadingMode.original),
      );
      return Result.success(book);
    } on Object catch (e) {
      return Result.failure(
        DocumentFailure('Failed to import file.', cause: e),
      );
    }
  }
}
