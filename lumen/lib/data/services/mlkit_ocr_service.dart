import 'dart:io';
import 'dart:math' as math;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/error/failures.dart';
import '../../core/result/result.dart';
import '../../domain/services/ocr_service.dart';

/// On-device OCR via Google ML Kit ([OcrService]).
///
/// For scanned PDFs it rasterizes each page (via `pdfrx`) to a PNG and runs ML
/// Kit text recognition on it, streaming per-page results so long documents can
/// show progress and be cancelled. Fully native — verified on device; the
/// OCR-results → `BookContent` mapping is separately unit-tested
/// (`buildOcrContent`).
class MlKitOcrService implements OcrService {
  MlKitOcrService();

  final _recognizer = TextRecognizer();

  @override
  Future<Result<bool>> isImageOnly(String filePath) async {
    try {
      final doc = await PdfDocument.openFile(filePath);
      var chars = 0;
      final sample = math.min(doc.pages.length, 5);
      for (var i = 0; i < sample; i++) {
        final text = await doc.pages[i].loadText();
        chars += text.fullText.trim().length;
      }
      await doc.dispose();
      return Result.success(chars < 8);
    } on Object catch (e) {
      return Result.failure(OcrFailure('Could not inspect PDF.', cause: e));
    }
  }

  @override
  Future<Result<OcrPageResult>> recognizeImage(String imagePath) async {
    try {
      final input = InputImage.fromFilePath(imagePath);
      final recognized = await _recognizer.processImage(input);
      return Result.success(OcrPageResult(
        pageIndex: 0,
        text: recognized.text,
        confidence: _confidence(recognized),
      ));
    } on Object catch (e) {
      return Result.failure(OcrFailure('Image OCR failed.', cause: e));
    }
  }

  @override
  Stream<OcrPageResult> recognizeDocument(String filePath) async* {
    final doc = await PdfDocument.openFile(filePath);
    final tempDir = await getTemporaryDirectory();
    try {
      for (var i = 0; i < doc.pages.length; i++) {
        final page = doc.pages[i];
        // Render at ~2x for legible OCR without exploding memory.
        final rendered = await page.render(
          width: (page.width * 2).toInt(),
          height: (page.height * 2).toInt(),
        );
        if (rendered == null) continue;

        final pngPath = p.join(tempDir.path, 'ocr_page_$i.png');
        final image = img.Image.fromBytes(
          width: rendered.width,
          height: rendered.height,
          bytes: rendered.pixels.buffer,
          numChannels: 4,
        );
        await File(pngPath).writeAsBytes(img.encodePng(image));
        rendered.dispose();

        final result = await recognizeImage(pngPath);
        final page0 = result.valueOrNull;
        await File(pngPath).delete().catchError((_) => File(pngPath));

        yield OcrPageResult(
          pageIndex: i,
          text: page0?.text ?? '',
          confidence: page0?.confidence ?? 0.0,
        );
      }
    } finally {
      await doc.dispose();
    }
  }

  /// ML Kit does not expose an overall score; approximate from whether legible
  /// text was recovered. The review UI lets the user verify low pages anyway.
  double _confidence(RecognizedText recognized) {
    final text = recognized.text.trim();
    if (text.isEmpty) return 0.0;
    final alnum = text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length;
    final ratio = alnum / text.length;
    return (0.5 + ratio / 2).clamp(0.0, 1.0);
  }

  Future<void> dispose() => _recognizer.close();
}
