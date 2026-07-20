import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/data/parsers/html_block_parser.dart';
import 'package:lumen/domain/entities/book_content.dart';

void main() {
  test('maps block-level HTML elements to content blocks in order', () {
    const html = '''
      <h1>The Title</h1>
      <p>First paragraph of prose.</p>
      <blockquote>A memorable quote.</blockquote>
      <ul><li>alpha</li><li>beta</li></ul>
      <pre>code = 1;</pre>
    ''';

    final blocks = parseHtmlToBlocks(html);
    final types = blocks.map((b) => b.type).toList();

    expect(
      types,
      containsAllInOrder([
        BlockType.heading,
        BlockType.paragraph,
        BlockType.quote,
        BlockType.list,
        BlockType.code,
      ]),
    );
  });

  test('heading level derives from the tag', () {
    final blocks = parseHtmlToBlocks('<h3>Sub</h3>');
    expect(blocks.single.type, BlockType.heading);
    expect(blocks.single.level, 2); // h3 -> level 2 (0-based)
  });

  test('list items are joined into one list block', () {
    final blocks = parseHtmlToBlocks('<ul><li>one</li><li>two</li></ul>');
    final list = blocks.firstWhere((b) => b.type == BlockType.list);
    expect(list.text, 'one\ntwo');
  });

  test('char offsets increase across blocks and honour startOffset', () {
    final blocks = parseHtmlToBlocks(
      '<p>aaa</p><p>bbb</p><p>ccc</p>',
      startOffset: 100,
    );
    expect(blocks.first.charOffset, 100);
    for (var i = 1; i < blocks.length; i++) {
      expect(blocks[i].charOffset, greaterThan(blocks[i - 1].charOffset));
    }
  });

  test('collapses whitespace and skips empty blocks', () {
    final blocks = parseHtmlToBlocks('<p>  spaced   out  </p><p>   </p>');
    expect(blocks, hasLength(1));
    expect(blocks.single.text, 'spaced out');
  });
}
