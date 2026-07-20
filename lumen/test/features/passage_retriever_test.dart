import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/entities/book_content.dart';
import 'package:lumen/features/reader/presentation/rendering/passage_retriever.dart';

BookContent _content(List<String> paragraphs) => BookContent(
      bookId: 'b1',
      chapters: [
        Chapter(
          id: 'c0',
          title: 'Ch',
          order: 0,
          blocks: [
            for (final p in paragraphs)
              ContentBlock(type: BlockType.paragraph, text: p),
          ],
        ),
      ],
    );

void main() {
  test('ranks the most relevant passage first', () {
    final content = _content([
      'The sailors prepared the ship for a long ocean voyage at dawn.',
      'Photosynthesis converts sunlight into chemical energy in plants.',
      'The whale surfaced beside the ship, startling the entire crew.',
    ]);

    final results = retrievePassages(content, 'ship crew whale', limit: 2);

    expect(results, isNotEmpty);
    // The passage mentioning ship + whale + crew should win.
    expect(results.first, contains('whale surfaced'));
    expect(results.length, lessThanOrEqualTo(2));
    // The photosynthesis paragraph is irrelevant and should not appear.
    expect(results.any((p) => p.contains('Photosynthesis')), isFalse);
  });

  test('returns nothing for a query with no meaningful overlap', () {
    final content = _content([
      'The quiet garden bloomed with roses in the warm spring air.',
    ]);
    expect(retrievePassages(content, 'quantum entanglement'), isEmpty);
  });

  test('empty query yields no passages', () {
    final content = _content(['Any text at all here to consider.']);
    expect(retrievePassages(content, '   '), isEmpty);
  });

  test('skips blocks shorter than the minimum length', () {
    final content = _content(['ship', 'The ship sailed across the wide sea.']);
    final results = retrievePassages(content, 'ship');
    // The tiny "ship" block is below minChars and excluded.
    expect(results, hasLength(1));
    expect(results.first, contains('sailed'));
  });

  test('respects the limit', () {
    final content = _content([
      'The ship sailed north across the cold grey sea.',
      'A different ship sailed south toward warmer waters.',
      'Yet another ship sailed east into the rising sun.',
    ]);
    final results = retrievePassages(content, 'ship sailed', limit: 2);
    expect(results, hasLength(2));
  });
}
