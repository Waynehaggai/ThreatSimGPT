import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../domain/entities/book_content.dart';

/// Converts an HTML fragment (an EPUB chapter, a DOCX-derived body) into an
/// ordered list of [ContentBlock]s for Smart Reading Mode.
///
/// Pure Dart (uses `package:html`), so it is fully unit-testable. Block-level
/// elements are read in document order; inline markup is flattened to text
/// (Smart Mode restyles via reading settings, not the source's inline styles).
/// Character offsets accumulate across blocks so annotations anchor correctly.
List<ContentBlock> parseHtmlToBlocks(String html, {int startOffset = 0}) {
  final document = html_parser.parse(html);
  final body = document.body ?? document.documentElement;
  if (body == null) return const [];

  final blocks = <ContentBlock>[];
  var offset = startOffset;

  void add(BlockType type, String text, {int level = 0, bool collapse = true}) {
    // List blocks arrive pre-collapsed per item and joined with newlines, which
    // must be preserved; collapsing would merge the items onto one line.
    final trimmed = collapse ? _collapse(text) : text.trim();
    if (trimmed.isEmpty && type != BlockType.image) return;
    blocks.add(
      ContentBlock(type: type, text: trimmed, level: level, charOffset: offset),
    );
    offset += trimmed.length + 1;
  }

  const selector =
      'h1, h2, h3, h4, h5, h6, p, blockquote, pre, ul, ol, figcaption, li';
  final seenListItems = <Element>{};

  for (final el in body.querySelectorAll(selector)) {
    final tag = el.localName;
    switch (tag) {
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        add(BlockType.heading, el.text, level: int.parse(tag![1]) - 1);
      case 'p':
        // Skip empty paragraphs that only wrap an image/line break.
        add(BlockType.paragraph, el.text);
      case 'blockquote':
        add(BlockType.quote, el.text);
      case 'pre':
        add(BlockType.code, el.text);
      case 'figcaption':
        add(BlockType.caption, el.text);
      case 'ul' || 'ol':
        final items = el.querySelectorAll('li')..forEach(seenListItems.add);
        final text = items.map((li) => _collapse(li.text)).join('\n');
        add(BlockType.list, text, collapse: false);
      case 'li':
        // Standalone list items (not inside a captured ul/ol) become a list.
        if (!seenListItems.contains(el)) add(BlockType.list, el.text);
    }
  }
  return blocks;
}

/// Collapses runs of whitespace/newlines introduced by HTML formatting.
String _collapse(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();
