import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/domain/entities/book_content.dart';
import 'package:lumen/features/reader/presentation/providers/document_cleanup_providers.dart';

BookContent _content(List<String> paragraphs) => BookContent(
      bookId: 'b',
      chapters: [
        Chapter(
          id: 'c',
          title: 't',
          order: 0,
          blocks: [
            for (final p in paragraphs)
              ContentBlock(type: BlockType.paragraph, text: p),
          ],
        ),
      ],
    );

void main() {
  test('chunkForCleanup splits on block boundaries and keeps all text', () {
    final content = _content([for (var i = 0; i < 10; i++) 'x' * 1000]);
    final chunks = chunkForCleanup(content, maxChars: 2500);

    expect(chunks.length, greaterThan(1));
    // No chunk exceeds the budget by more than one block.
    expect(chunks.every((c) => c.length <= 3000), isTrue);
    // Every character is preserved across the chunks.
    final total =
        chunks.join('\n').replaceAll('\n', '').replaceAll(RegExp('[^x]'), '');
    expect(total.length, 10 * 1000);
  });

  test('chunkForCleanup skips empty blocks', () {
    final content = _content(['Real text.', '   ', 'More text.']);
    final chunks = chunkForCleanup(content);
    expect(chunks, hasLength(1));
    expect(chunks.single, contains('Real text.'));
    expect(chunks.single, contains('More text.'));
  });

  test('contentFromCleanedText re-parses paragraphs and list items', () {
    final content = contentFromCleanedText(
      'book-9',
      'My Title',
      'A clean paragraph that reads normally.\n\n'
          '1. First item.\n2. Second item.',
    );

    expect(content.bookId, 'book-9');
    expect(content.chapters.single.title, 'My Title');
    final blocks = content.chapters.single.blocks;
    expect(blocks.any((b) => b.type == BlockType.paragraph), isTrue);
    final lists = blocks.where((b) => b.type == BlockType.list).toList();
    expect(lists, hasLength(2));
    expect(lists.first.text, startsWith('1.'));
  });

  test('cleanup reports an error when AI is disabled', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller =
        container.read(documentCleanupControllerProvider('b').notifier);
    await controller.run();

    final state = container.read(documentCleanupControllerProvider('b'));
    expect(state.status, CleanupStatus.error);
    expect(state.error, isNotNull);
  });
}
