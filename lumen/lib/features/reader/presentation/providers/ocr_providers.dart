import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/mlkit_ocr_service.dart';
import '../../../../domain/entities/book_content.dart';
import '../../../../domain/services/ocr_service.dart';
import 'ocr_run_controller.dart';

/// The active [OcrService]. On-device ML Kit by default; a fake is injected in
/// tests via override.
final ocrServiceProvider = Provider<OcrService>((ref) {
  final service = MlKitOcrService();
  ref.onDispose(service.dispose);
  return service;
});

/// Per-book OCR run controller (progress + streamed results).
final ocrRunControllerProvider =
    Provider.family<OcrRunController, String>((ref, bookId) {
  final controller = OcrRunController(ref.watch(ocrServiceProvider));
  ref.onDispose(controller.dispose);
  return controller;
});

/// Session cache of OCR-generated (and user-corrected) Smart content, keyed by
/// book id. The reader prefers this over on-the-fly parsing when present.
///
/// (Persisting OCR content to Isar across sessions is a tracked follow-up; for
/// now a re-open re-uses it within the session and re-runs OCR after a restart.)
final ocrContentProvider =
    StateProvider.family<BookContent?, String>((ref, bookId) => null);
