import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/features/reader/presentation/rendering/page_packer.dart';

void main() {
  const packer = PagePacker();

  test('empty input yields no pages', () {
    expect(packer.pack([], 100), isEmpty);
  });

  test('packs items greedily without overflowing a page', () {
    final pages = packer.pack([10, 10, 10], 25);
    expect(pages, [const PageRange(0, 2), const PageRange(2, 3)]);
  });

  test('fills exact-fit pages fully', () {
    final pages = packer.pack([5, 5, 5, 5], 10);
    expect(pages, [const PageRange(0, 2), const PageRange(2, 4)]);
  });

  test('an oversized item gets its own page', () {
    final pages = packer.pack([10, 30, 10], 25);
    expect(pages, [
      const PageRange(0, 1),
      const PageRange(1, 2),
      const PageRange(2, 3),
    ]);
  });

  test('every item lands on exactly one page, in order', () {
    final heights = List<double>.generate(50, (i) => (i % 5) * 3.0 + 4);
    final pages = packer.pack(heights, 40);
    var expectedNext = 0;
    for (final page in pages) {
      expect(page.start, expectedNext);
      expect(page.end, greaterThan(page.start));
      expectedNext = page.end;
    }
    expect(expectedNext, heights.length);
  });
}
