import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/parsers/pdf_parser.dart';
import 'package:lumen/domain/entities/book_content.dart';

void main() {
  test('reflows hard-wrapped lines into a single paragraph', () {
    const raw = 'This is the first paragraph that has been\n'
        'hard wrapped across several visual\n'
        'lines by the PDF layout.\n'
        'A second paragraph then begins here and\n'
        'also wraps onto two lines.';
    final blocks = structurePdfText(raw);

    final paras = blocks.where((b) => b.type == BlockType.paragraph).toList();
    expect(paras, hasLength(2));
    expect(paras.first.text, isNot(contains('\n')));
    expect(paras.first.text, contains('first paragraph that has been hard'));
    expect(paras.first.text, endsWith('PDF layout.'));
  });

  test('keeps numbered points as separate list items, markers intact', () {
    const raw = 'Intro line before the list.\n'
        '1. First point here.\n'
        '2. Second point that is a little\n'
        'longer and wraps.\n'
        '3. Third point.\n'
        'A closing paragraph after the list.';
    final blocks = structurePdfText(raw);

    final lists = blocks.where((b) => b.type == BlockType.list).toList();
    expect(lists, hasLength(3));
    expect(lists[0].text, startsWith('1.'));
    expect(lists[1].text, startsWith('2.'));
    expect(lists[2].text, startsWith('3.'));
    // The wrapped continuation joined onto its own item, not a new one.
    expect(lists[1].text, contains('longer and wraps'));
    // Numbered points are not fused into one block.
    expect(
      blocks.where((b) => b.text.startsWith('1.')).length,
      1,
    );
  });

  test('de-hyphenates words split across a line break', () {
    const raw =
        'The congre-\ngation gathered together for the even-\ning service.';
    final blocks = structurePdfText(raw);
    expect(blocks.single.type, BlockType.paragraph);
    expect(blocks.single.text, contains('congregation'));
    expect(blocks.single.text, contains('evening'));
  });

  test('splits run-on numbered items glued after punctuation', () {
    const raw = 'Instructions for the candidate:1.Stand still.2.Hold your '
        'breath.3.Come up slowly.';
    final blocks = structurePdfText(raw);
    final lists = blocks.where((b) => b.type == BlockType.list).toList();
    expect(lists, hasLength(3));
    expect(lists[0].text, startsWith('1.'));
    expect(lists[1].text, startsWith('2.'));
    expect(lists[2].text, startsWith('3.'));
  });

  test('leaves ordinary prose and years untouched', () {
    const raw = 'Chapter 1. The story began in 1990. It was a good year.';
    final blocks = structurePdfText(raw);
    // No spurious list items carved out of normal sentences.
    expect(blocks.every((b) => b.type != BlockType.list), isTrue);
  });

  test('strips repeating running headers/footers and page numbers', () {
    // Same running head + a page number at the foot of every page.
    final pages = [
      for (var n = 1; n <= 6; n++)
        'The Marriage Covenant\n'
            'Body sentence for page $n that is real content.\n'
            '$n',
    ];
    final cleaned = stripRunningHeadersFooters(pages);

    for (final page in cleaned) {
      expect(page, isNot(contains('The Marriage Covenant')));
      expect(page, contains('real content'));
      // The bare page-number line is gone.
      final lines = page.split('\n');
      expect(lines.any((l) => RegExp(r'^\d+$').hasMatch(l)), isFalse);
    }
  });

  test('does not strip a title that appears only once (not a running head)',
      () {
    final pages = [
      'The Marriage Covenant\nOpening paragraph of the book.',
      'A completely different second page of prose.',
      'A third page with more prose and ideas.',
    ];
    final cleaned = stripRunningHeadersFooters(pages);
    // Appears once → not a running head → kept.
    expect(cleaned.first, contains('The Marriage Covenant'));
  });

  test('lifts a short ALL-CAPS line as a heading', () {
    const raw = 'THE MARRIAGE COVENANT\n'
        'This chapter opens with a paragraph of\n'
        'ordinary prose that wraps.';
    final blocks = structurePdfText(raw);
    expect(blocks.first.type, BlockType.heading);
    expect(blocks.first.text, 'THE MARRIAGE COVENANT');
    expect(blocks[1].type, BlockType.paragraph);
  });
}
