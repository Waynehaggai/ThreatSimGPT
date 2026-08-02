import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/parsers/pdf_parser.dart';
import '../../../../core/di/repository_providers.dart';
import '../../../../domain/entities/book_content.dart';
import 'reader_providers.dart';

/// Session cache of AI-cleaned Smart content, keyed by book id. The reader
/// prefers this over on-the-fly parsing once a cleanup has run.
///
/// (Persisting across restarts is a tracked follow-up — mirrors how OCR content
/// is cached for the session.)
final enhancedContentProvider = StateProvider.family<BookContent?, String>(
  (ref, bookId) => null,
);

/// Splits a book's block text into chunks small enough for one AI request,
/// breaking only on block boundaries so a paragraph is never cut mid-way.
List<String> chunkForCleanup(BookContent content, {int maxChars = 6000}) {
  final texts = [
    for (final chapter in content.chapters)
      for (final block in chapter.blocks)
        if ((block.text ?? '').trim().isNotEmpty) block.text!.trim(),
  ];
  final chunks = <String>[];
  final buf = StringBuffer();
  for (final t in texts) {
    if (buf.isNotEmpty && buf.length + t.length + 1 > maxChars) {
      chunks.add(buf.toString());
      buf.clear();
    }
    if (buf.isNotEmpty) buf.write('\n');
    buf.write(t);
  }
  if (buf.isNotEmpty) chunks.add(buf.toString());
  return chunks;
}

/// Builds Smart content from AI-cleaned plain text by running it back through
/// the structural parser (paragraphs, list items, headings).
BookContent contentFromCleanedText(String bookId, String title, String text) {
  final blocks = <ContentBlock>[];
  var offset = 0;
  var words = 0;
  for (final b in structurePdfText(text)) {
    blocks.add(
      ContentBlock(
        type: b.type,
        text: b.text,
        level: b.level,
        charOffset: offset,
      ),
    );
    offset += b.text.length + 1;
    words += b.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }
  return BookContent(
    bookId: bookId,
    chapters: [Chapter(id: 'ch-0', title: title, order: 0, blocks: blocks)],
    generatedAt: DateTime.now(),
    wordCount: words,
  );
}

/// Progress of an AI formatting cleanup for one book.
enum CleanupStatus { idle, running, done, error }

class CleanupState {
  const CleanupState({
    this.status = CleanupStatus.idle,
    this.done = 0,
    this.total = 0,
    this.error,
  });

  final CleanupStatus status;
  final int done;
  final int total;
  final String? error;

  bool get isRunning => status == CleanupStatus.running;
}

/// Runs the on-demand "Clean up formatting (AI)" flow for a book: chunk the
/// current (messy) content, send each chunk to the AI for repair, reassemble,
/// re-parse, and publish the result so the reader re-lays it out.
class DocumentCleanupController extends FamilyNotifier<CleanupState, String> {
  @override
  CleanupState build(String bookId) => const CleanupState();

  Future<void> run() async {
    final ai = ref.read(aiServiceProvider);
    if (!ai.isEnabled) {
      state = const CleanupState(
        status: CleanupStatus.error,
        error: 'AI features are not enabled in this build.',
      );
      return;
    }

    final content = await ref.read(readerContentProvider(arg).future);
    final chunks = chunkForCleanup(content);
    if (chunks.isEmpty) {
      state = const CleanupState(status: CleanupStatus.done);
      return;
    }

    state = CleanupState(status: CleanupStatus.running, total: chunks.length);
    final cleaned = <String>[];
    for (var i = 0; i < chunks.length; i++) {
      final result = await ai.restructureText(chunks[i]);
      final text = result.valueOrNull;
      if (text == null || text.isEmpty) {
        state = CleanupState(
          status: CleanupStatus.error,
          done: i,
          total: chunks.length,
          error: 'The AI could not clean up this document. Please try again.',
        );
        return;
      }
      cleaned.add(text);
      state = CleanupState(
        status: CleanupStatus.running,
        done: i + 1,
        total: chunks.length,
      );
    }

    final book = await ref.read(readerBookProvider(arg).future);
    final result =
        contentFromCleanedText(arg, book.title, cleaned.join('\n\n'));
    ref.read(enhancedContentProvider(arg).notifier).state = result;
    // Re-parse path picks up the cached enhanced content on next read.
    ref.invalidate(readerContentProvider(arg));
    state = CleanupState(
      status: CleanupStatus.done,
      done: chunks.length,
      total: chunks.length,
    );
  }
}

final documentCleanupControllerProvider =
    NotifierProvider.family<DocumentCleanupController, CleanupState, String>(
  DocumentCleanupController.new,
);
