import 'dart:math' as math;

import '../../../../domain/entities/book_content.dart';

/// Lightweight, dependency-free passage retrieval for grounded Q&A (RAG).
///
/// Scores each text block by term overlap with the query (bag-of-words TF with
/// a light IDF-style rarity boost and a length normalisation) and returns the
/// top-N passages. This is deliberately a pure function over already-parsed
/// [BookContent] so it is fast, offline, and unit-testable — no embeddings, no
/// network. A future upgrade can swap in vector search behind the same
/// signature without touching callers.
List<String> retrievePassages(
  BookContent content,
  String query, {
  int limit = 4,
  int minChars = 24,
}) {
  final queryTerms = _tokenize(query).toSet();
  if (queryTerms.isEmpty) return const <String>[];

  final candidates = <_Passage>[];
  final docFreq = <String, int>{};

  for (final block in content.blocks) {
    final text = block.text?.trim();
    if (text == null || text.length < minChars) continue;
    final terms = _tokenize(text);
    if (terms.isEmpty) continue;
    final counts = <String, int>{};
    for (final t in terms) {
      counts[t] = (counts[t] ?? 0) + 1;
    }
    for (final t in counts.keys) {
      docFreq[t] = (docFreq[t] ?? 0) + 1;
    }
    candidates.add(_Passage(text, counts, terms.length));
  }
  if (candidates.isEmpty) return const <String>[];

  final n = candidates.length;
  final scored = <_Scored>[];
  for (final c in candidates) {
    var score = 0.0;
    for (final term in queryTerms) {
      final tf = c.counts[term];
      if (tf == null) continue;
      // Rarer terms across the book carry more weight.
      final idf = math.log(1 + n / (docFreq[term] ?? 1));
      score += tf * idf;
    }
    if (score <= 0) continue;
    // Normalise by sqrt(length) so long blocks don't win purely by size.
    score /= math.sqrt(c.length.toDouble());
    scored.add(_Scored(c.text, score));
  }
  if (scored.isEmpty) return const <String>[];

  scored.sort((a, b) => b.score.compareTo(a.score));
  return scored.take(limit).map((s) => s.text).toList(growable: false);
}

List<String> _tokenize(String text) {
  final out = <String>[];
  final buffer = StringBuffer();
  void flush() {
    if (buffer.isEmpty) return;
    final token = buffer.toString();
    if (token.length > 2 && !_stopWords.contains(token)) out.add(token);
    buffer.clear();
  }

  for (final rune in text.toLowerCase().runes) {
    final isWord = (rune >= 0x61 && rune <= 0x7a) || // a-z
        (rune >= 0x30 && rune <= 0x39); // 0-9
    if (isWord) {
      buffer.writeCharCode(rune);
    } else {
      flush();
    }
  }
  flush();
  return out;
}

const _stopWords = <String>{
  'the',
  'and',
  'for',
  'are',
  'but',
  'not',
  'you',
  'all',
  'any',
  'can',
  'her',
  'was',
  'one',
  'our',
  'out',
  'his',
  'has',
  'had',
  'him',
  'she',
  'they',
  'them',
  'that',
  'this',
  'with',
  'from',
  'what',
  'when',
  'were',
  'their',
  'there',
  'which',
  'would',
  'about',
  'into',
  'than',
  'then',
  'your',
  'have',
  'been',
  'more',
  'some',
  'such',
  'only',
  'over',
  'also',
};

class _Passage {
  _Passage(this.text, this.counts, this.length);
  final String text;
  final Map<String, int> counts;
  final int length;
}

class _Scored {
  _Scored(this.text, this.score);
  final String text;
  final double score;
}
