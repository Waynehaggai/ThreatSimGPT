import '../../core/result/result.dart';
import '../entities/book.dart';

/// Prepares an imported file for the library.
///
/// "Prepare" means the offline-first, side-effecting work that must happen once
/// per import — compute a content checksum (for dedupe), copy the file into the
/// app's private storage (so the library owns its copy), and extract metadata
/// (title/author/pages/cover, and whether OCR is needed). Persisting the
/// resulting [Book] and enqueuing sync remains the repository's job.
abstract interface class ImportService {
  /// Copies + inspects the file at [sourcePath], returning an unsaved [Book].
  Future<Result<Book>> prepare(String sourcePath);

  /// SHA-256 of the file contents, used to detect duplicate imports.
  Future<Result<String>> checksumOf(String path);
}
