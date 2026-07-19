import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/result/result.dart';
import 'package:lumen/domain/entities/book_content.dart';
import 'package:lumen/domain/services/ocr_service.dart';
import 'package:lumen/features/reader/presentation/providers/ocr_run_controller.dart';

/// Fake OCR that streams a fixed set of page results (optionally erroring).
class FakeOcr implements OcrService {
  FakeOcr(this._pages, {this.error});
  final List<OcrPageResult> _pages;
  final Object? error;

  @override
  Stream<OcrPageResult> recognizeDocument(String filePath) async* {
    for (final page in _pages) {
      yield page;
    }
    if (error != null) throw error!;
  }

  @override
  Future<Result<OcrPageResult>> recognizeImage(String imagePath) async =>
      Result.success(_pages.first);

  @override
  Future<Result<bool>> isImageOnly(String filePath) async =>
      const Result.success(true);
}

void main() {
  final pages = [
    const OcrPageResult(pageIndex: 0, text: 'Page one.', confidence: 0.9),
    const OcrPageResult(pageIndex: 1, text: 'Page two.', confidence: 0.5),
  ];

  test('aggregates streamed pages and completes as done', () async {
    final controller = OcrRunController(FakeOcr(pages));
    await controller.run('doc.pdf', totalPages: 2);

    final state = controller.state.value;
    expect(state.status, OcrStatus.done);
    expect(state.pagesDone, 2);
    expect(state.results, hasLength(2));
    expect(state.fraction, 1.0);
    controller.dispose();
  });

  test('builds Smart content from the recognised pages', () async {
    final controller = OcrRunController(FakeOcr(pages));
    await controller.run('doc.pdf');
    final content = controller.buildContent('b1');
    expect(content, isA<BookContent>());
    expect(content.blocks.where((b) => b.type == BlockType.paragraph),
        isNotEmpty);
    controller.dispose();
  });

  test('reports an error status when the stream fails', () async {
    final controller = OcrRunController(FakeOcr(pages, error: 'scanner jam'));
    await controller.run('doc.pdf');
    expect(controller.state.value.status, OcrStatus.error);
    expect(controller.state.value.error, contains('scanner jam'));
    controller.dispose();
  });
}
