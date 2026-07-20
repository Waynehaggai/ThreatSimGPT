/// The reflowable representation of a book used by Smart Reading Mode.
///
/// Produced by the document parsing / OCR pipeline and cached locally. The
/// reader lays these blocks out responsively — no fixed pages, no zooming.
class BookContent {
  const BookContent({
    required this.bookId,
    required this.chapters,
    this.generatedAt,
    this.wordCount = 0,
  });

  final String bookId;
  final List<Chapter> chapters;
  final DateTime? generatedAt;
  final int wordCount;

  /// Flattened block stream across all chapters (reader iteration order).
  Iterable<ContentBlock> get blocks => chapters.expand((c) => c.blocks);
}

/// A table-of-contents entry plus the content it owns.
class Chapter {
  const Chapter({
    required this.id,
    required this.title,
    required this.order,
    this.blocks = const <ContentBlock>[],
    this.level = 0,
  });

  final String id;
  final String title;

  /// Position within the book (0-based).
  final int order;

  /// Nesting depth in the TOC (0 = top-level).
  final int level;

  final List<ContentBlock> blocks;
}

/// Semantic block kinds recovered from the source document.
enum BlockType {
  heading,
  paragraph,
  image,
  list,
  quote,
  caption,
  code,
  pageBreak,
}

/// One renderable unit of reflowed content.
class ContentBlock {
  const ContentBlock({
    required this.type,
    this.text,
    this.imagePath,
    this.level = 0,
    this.charOffset = 0,
  });

  final BlockType type;

  /// Text content (for text-bearing blocks).
  final String? text;

  /// Local path to an extracted image (for [BlockType.image]).
  final String? imagePath;

  /// Heading level / list depth.
  final int level;

  /// Absolute character offset of this block in the book's text stream — the
  /// anchor used to place highlights, bookmarks, and resume points.
  final int charOffset;
}
