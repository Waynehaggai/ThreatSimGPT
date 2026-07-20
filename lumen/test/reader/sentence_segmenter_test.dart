import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/entities/book_content.dart';
import 'package:lumen/features/reader/presentation/rendering/sentence_segmenter.dart';

void main() {
  group('splitSentences', () {
    test('splits on . ! ? followed by space or end', () {
      final spans = splitSentences('Hello world. How are you? Fine!');
      expect(spans.map((s) => s.text).toList(), [
        'Hello world.',
        'How are you?',
        'Fine!',
      ]);
    });

    test('local offsets bound each sentence', () {
      final spans = splitSentences('One. Two.');
      expect(spans[0].start, 0);
      expect(spans[0].end, 4); // "One."
      expect('One. Two.'.substring(spans[1].start, spans[1].end), 'Two.');
    });

    test('text with no terminator is a single sentence', () {
      final spans = splitSentences('no ending punctuation here');
      expect(spans, hasLength(1));
      expect(spans.single.text, 'no ending punctuation here');
    });

    test('handles repeated terminators', () {
      final spans = splitSentences('Wait?! Yes.');
      expect(spans.map((s) => s.text).toList(), ['Wait?!', 'Yes.']);
    });

    test('empty / whitespace text yields no sentences', () {
      expect(splitSentences('   '), isEmpty);
    });
  });

  group('segmentBook', () {
    test('produces globally-indexed sentences with absolute offsets', () {
      const content = BookContent(
        bookId: 'b',
        chapters: [
          Chapter(
            id: 'c0',
            title: 'One',
            order: 0,
            blocks: [
              ContentBlock(
                type: BlockType.paragraph,
                text: 'A. B.',
                charOffset: 0,
              ),
            ],
          ),
          Chapter(
            id: 'c1',
            title: 'Two',
            order: 1,
            blocks: [
              ContentBlock(
                type: BlockType.paragraph,
                text: 'C.',
                charOffset: 100,
              ),
            ],
          ),
        ],
      );

      final sentences = segmentBook(content);
      expect(sentences.map((s) => s.text).toList(), ['A.', 'B.', 'C.']);
      expect(sentences.map((s) => s.index).toList(), [0, 1, 2]);
      // Absolute offset = block.charOffset + local start.
      expect(sentences[2].start, 100);
      expect(sentences[0].chapterId, 'c0');
      expect(sentences[2].chapterId, 'c1');
    });
  });
}
