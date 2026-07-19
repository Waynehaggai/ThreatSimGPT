import '../../../../domain/entities/book_content.dart';

/// One spoken unit: a sentence with its absolute position in the book's text
/// stream. The absolute [start]/[end] offsets let TTS highlight the exact words
/// on screen and resume from the exact sentence across sessions and devices.
class Sentence {
  const Sentence({
    required this.index,
    required this.text,
    required this.start,
    required this.end,
    this.chapterId,
  });

  final int index;
  final String text;
  final int start;
  final int end;
  final String? chapterId;
}

/// Splits [content] into an ordered list of [Sentence]s for read-aloud.
///
/// Pure and deterministic (no Flutter/TTS), so segmentation is unit-tested in
/// isolation. Offsets are absolute (block offset + local position) and thus
/// aligned with annotation/bookmark anchoring.
List<Sentence> segmentBook(BookContent content) {
  final sentences = <Sentence>[];
  var index = 0;
  for (final chapter in content.chapters) {
    for (final block in chapter.blocks) {
      final text = block.text;
      if (text == null || text.trim().isEmpty) continue;
      for (final span in splitSentences(text)) {
        sentences.add(Sentence(
          index: index++,
          text: span.text,
          start: block.charOffset + span.start,
          end: block.charOffset + span.end,
          chapterId: chapter.id,
        ));
      }
    }
  }
  return sentences;
}

/// A sentence span within a single block's local coordinates.
class SentenceSpan {
  const SentenceSpan(this.text, this.start, this.end);
  final String text;
  final int start;
  final int end;
}

/// Splits a block of text into sentences, preserving local offsets.
///
/// A boundary is a `.`, `!` or `?` (optionally repeated) followed by whitespace
/// or end-of-text. Trailing whitespace is excluded from the span; empty spans
/// are dropped.
List<SentenceSpan> splitSentences(String text) {
  final spans = <SentenceSpan>[];
  var start = 0;
  var i = 0;
  final len = text.length;

  void emit(int end) {
    // Trim leading whitespace of the span for a clean start offset.
    var s = start;
    while (s < end && _isSpace(text.codeUnitAt(s))) {
      s++;
    }
    if (end > s) {
      spans.add(SentenceSpan(text.substring(s, end), s, end));
    }
  }

  while (i < len) {
    final c = text.codeUnitAt(i);
    if (c == 0x2E || c == 0x21 || c == 0x3F) {
      // consume repeated terminators (…, !!, ?!)
      var j = i + 1;
      while (j < len && _isTerminator(text.codeUnitAt(j))) {
        j++;
      }
      final atEnd = j >= len;
      final followedBySpace = !atEnd && _isSpace(text.codeUnitAt(j));
      if (atEnd || followedBySpace) {
        emit(j);
        start = j;
        i = j;
        continue;
      }
    }
    i++;
  }
  if (start < len) emit(len);
  return spans;
}

bool _isSpace(int c) => c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D;
bool _isTerminator(int c) => c == 0x2E || c == 0x21 || c == 0x3F;
