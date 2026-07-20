import '../../../../domain/entities/book_content.dart';

/// A rich sample [BookContent] used to demonstrate Smart Reading Mode before
/// the real import/parse pipeline (M2) is wired. Exercises every [BlockType].
BookContent sampleBookContent(String bookId, String title) {
  var offset = 0;
  ContentBlock block(BlockType type, String? text, {int level = 0}) {
    final b = ContentBlock(
      type: type,
      text: text,
      level: level,
      charOffset: offset,
    );
    offset += (text?.length ?? 0) + 1;
    return b;
  }

  return BookContent(
    bookId: bookId,
    generatedAt: DateTime.now(),
    wordCount: 420,
    chapters: [
      Chapter(
        id: 'ch-0',
        title: 'A Note on Reading',
        order: 0,
        blocks: [
          block(BlockType.heading, title, level: 0),
          block(
            BlockType.paragraph,
            'This page is rendered in Smart Reading Mode. The text you are '
            'reading has been reflowed to fit your screen — there is no '
            'zooming and no horizontal scrolling. Change the font, size, '
            'spacing, margins or theme in settings and this page re-lays out '
            'instantly, exactly as an eBook should.',
          ),
          block(
            BlockType.quote,
            'Reading should feel effortless. The reader disappears; only the '
            'words remain.',
          ),
          block(
            BlockType.paragraph,
            'Every paragraph carries an absolute character offset, so your '
            'highlights, bookmarks and resume point stay anchored to the '
            'right words even after the page reflows to a different size.',
          ),
        ],
      ),
      Chapter(
        id: 'ch-1',
        title: 'What Smart Mode Preserves',
        order: 1,
        blocks: [
          block(BlockType.heading, 'What Smart Mode Preserves', level: 0),
          block(
            BlockType.paragraph,
            'From the original document, Lumen keeps:',
          ),
          block(
            BlockType.list,
            'Headings and chapter structure\n'
            'Paragraphs and reading order\n'
            'Images and their captions\n'
            'Lists, quotes and code blocks',
          ),
          block(
            BlockType.caption,
            'Figure 1 — a caption renders smaller and centered.',
          ),
          block(
            BlockType.code,
            'final reader = Lumen();\nreader.open(book, mode: smart);',
          ),
          block(
            BlockType.paragraph,
            'When a document is better read as authored — engineering '
            'drawings, tables, forms — switch to Original Mode from the '
            'bottom bar and the exact pages appear, pixel for pixel.',
          ),
        ],
      ),
    ],
  );
}
