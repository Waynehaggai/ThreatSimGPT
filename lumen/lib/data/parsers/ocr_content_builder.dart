import '../../domain/entities/book_content.dart';
import '../../domain/services/ocr_service.dart';

/// Builds reflowable [BookContent] from OCR page results.
///
/// Pure and deterministic (no ML Kit / platform), so the page → block mapping is
/// unit-tested in isolation. Each page's recognised text is split into paragraph
/// blocks carrying absolute char offsets (so highlights/bookmarks/TTS anchor
/// correctly), with a page-break block between pages. Low-confidence pages are
/// still included — the user can correct them in the OCR review screen.
BookContent buildOcrContent(
  String bookId,
  List<OcrPageResult> pages, {
  double lowConfidenceThreshold = 0.6,
}) {
  final sorted = [...pages]..sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
  final blocks = <ContentBlock>[];
  var offset = 0;
  var wordCount = 0;

  void addBlock(BlockType type, String text) {
    blocks.add(ContentBlock(type: type, text: text, charOffset: offset));
    offset += text.length + 1;
  }

  for (var i = 0; i < sorted.length; i++) {
    final page = sorted[i];
    if (i > 0) {
      blocks.add(ContentBlock(type: BlockType.pageBreak, charOffset: offset));
      offset += 1;
    }
    for (final para in _paragraphs(page.text)) {
      addBlock(BlockType.paragraph, para);
      wordCount += para.split(RegExp(r'\s+')).length;
    }
  }

  return BookContent(
    bookId: bookId,
    generatedAt: DateTime.now(),
    wordCount: wordCount,
    chapters: [
      Chapter(id: 'ocr-0', title: 'Scanned document', order: 0, blocks: blocks),
    ],
  );
}

/// Splits OCR page text into paragraphs: blank lines separate paragraphs, and
/// single newlines within a paragraph are joined (OCR wraps mid-sentence).
Iterable<String> _paragraphs(String text) {
  return text
      .replaceAll('\r\n', '\n')
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim())
      .where((p) => p.isNotEmpty);
}

/// Pages whose recognition confidence is below [threshold] — surfaced in the
/// review UI so the user can check them first.
Set<int> lowConfidencePages(
  List<OcrPageResult> pages, {
  double threshold = 0.6,
}) =>
    pages
        .where((p) => p.confidence < threshold)
        .map((p) => p.pageIndex)
        .toSet();
