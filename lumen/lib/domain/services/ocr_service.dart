import '../../core/result/result.dart';

/// Result of OCR over one page/image.
class OcrPageResult {
  const OcrPageResult({
    required this.pageIndex,
    required this.text,
    this.confidence = 0.0,
  });

  final int pageIndex;
  final String text;

  /// 0.0–1.0 average recognition confidence, used to flag pages for review.
  final double confidence;
}

/// Contract for optical character recognition (Google ML Kit by default).
///
/// Kept behind an interface so the engine (on-device ML Kit, or a future
/// cloud/AI OCR) can be swapped without touching the parsing pipeline.
abstract interface class OcrService {
  /// Whether a document at [filePath] appears to be image-only (needs OCR).
  Future<Result<bool>> isImageOnly(String filePath);

  /// Runs OCR across a document, streaming per-page results so long scans can
  /// report progress and be cancelled.
  Stream<OcrPageResult> recognizeDocument(String filePath);

  /// OCR a single image file.
  Future<Result<OcrPageResult>> recognizeImage(String imagePath);
}
