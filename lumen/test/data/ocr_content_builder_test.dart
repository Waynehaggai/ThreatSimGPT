import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/parsers/ocr_content_builder.dart';
import 'package:lumen/domain/entities/book_content.dart';
import 'package:lumen/domain/services/ocr_service.dart';

void main() {
  OcrPageResult page(int i, String text, {double conf = 0.9}) =>
      OcrPageResult(pageIndex: i, text: text, confidence: conf);

  test('splits page text into paragraphs and inserts page breaks', () {
    final content = buildOcrContent('b', [
      page(0, 'Para one.\n\nPara two.'),
      page(1, 'Second page text.'),
    ]);

    final types = content.blocks.map((b) => b.type).toList();
    expect(types, [
      BlockType.paragraph,
      BlockType.paragraph,
      BlockType.pageBreak,
      BlockType.paragraph,
    ]);
    expect(content.chapters.single.title, 'Scanned document');
  });

  test('joins OCR mid-paragraph line wraps into one paragraph', () {
    final content = buildOcrContent('b', [
      page(0, 'a line that the scanner\nwrapped in the middle'),
    ]);
    expect(
      content.blocks.single.text,
      'a line that the scanner wrapped in the middle',
    );
  });

  test('char offsets are monotonically increasing', () {
    final content = buildOcrContent('b', [
      page(0, 'One.\n\nTwo.'),
      page(1, 'Three.'),
    ]);
    final blocks = content.blocks.toList();
    for (var i = 1; i < blocks.length; i++) {
      expect(blocks[i].charOffset, greaterThan(blocks[i - 1].charOffset));
    }
  });

  test('sorts pages by index before building', () {
    final content = buildOcrContent('b', [
      page(1, 'Second.'),
      page(0, 'First.'),
    ]);
    final paras = content.blocks
        .where((b) => b.type == BlockType.paragraph)
        .map((b) => b.text)
        .toList();
    expect(paras, ['First.', 'Second.']);
  });

  test('lowConfidencePages flags pages below the threshold', () {
    final low = lowConfidencePages([
      page(0, 'clean', conf: 0.95),
      page(1, 'blurry', conf: 0.4),
    ]);
    expect(low, {1});
  });
}
