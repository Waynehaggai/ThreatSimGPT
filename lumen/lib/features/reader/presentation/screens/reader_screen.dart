import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/reading_theme.dart';
import '../../../../domain/entities/annotation.dart';
import '../../../../domain/entities/book.dart';
import '../../../../domain/entities/book_content.dart';
import '../../../../domain/entities/enums.dart';
import '../../../../domain/usecases/reader_usecases.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../../domain/services/tts_service.dart';
import '../providers/annotation_providers.dart';
import '../providers/ocr_providers.dart';
import '../providers/reader_providers.dart';
import '../providers/tts_controller.dart';
import '../providers/tts_providers.dart';
import '../rendering/reader_typography.dart';
import '../rendering/sentence_segmenter.dart';
import '../widgets/bookmarks_sheet.dart';
import '../widgets/original_reader_view.dart';
import '../widgets/resume_prompt.dart';
import '../widgets/selection_toolbar.dart';
import '../widgets/smart_reader_view.dart';
import '../widgets/table_of_contents_sheet.dart';
import '../widgets/tts_bar.dart';

/// A pending text selection awaiting an annotation action.
typedef _PendingSelection = ({int start, int end, String text});

/// The reading surface: immersive, tap-to-reveal controls, an Original/Smart
/// mode switch, a themed page, TOC, and live progress + remaining-time.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({required this.bookId, super.key});

  final String bookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  /// Set when the user jumps via the table of contents; overrides the resume
  /// point and re-lays the view out at that fraction.
  double? _jumpPercent;

  /// The current text selection awaiting a highlight/note action.
  _PendingSelection? _pending;

  @override
  void initState() {
    super.initState();
    // On open, check whether another device read further and offer to jump.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptResume());
  }

  Future<void> _maybePromptResume() async {
    final decision =
        await ref.read(resumeDecisionProvider(widget.bookId).future);
    if (!mounted || !decision.promptUser || decision.remoteNewer == null) return;
    final accept = await ResumePrompt.show(
      context,
      remote: decision.remoteNewer!,
      localPercent: decision.local?.percent,
    );
    if (accept ?? false) {
      setState(() => _jumpPercent = decision.remoteNewer!.percent);
    }
  }

  /// Cached sentence segmentation for the current book (built on first play).
  List<Sentence>? _sentences;

  void _clearSelection() => setState(() => _pending = null);

  /// Starts / pauses / resumes read-aloud from the current position.
  Future<void> _toggleTts() async {
    final content = ref.read(readerContentProvider(widget.bookId)).valueOrNull;
    if (content == null) return;
    final tts = ref.read(ttsControllerProvider(widget.bookId));
    final status = tts.state.value.status;

    if (status == TtsState.playing) {
      await tts.pause();
      return;
    }
    if (status == TtsState.paused) {
      await tts.resume();
      return;
    }
    final sentences = _sentences ??= segmentBook(content);
    if (sentences.isEmpty) return;
    // Resume from the last spoken sentence, else the nearest to reading position.
    final resume = ref.read(readerResumeProvider(widget.bookId)).valueOrNull;
    final fromIndex = resume?.ttsSentenceIndex ??
        (tts.state.value.currentIndex).clamp(0, sentences.length - 1);
    await tts.play(sentences, fromIndex: fromIndex);
  }

  /// A transient highlight over the sentence currently being spoken.
  Annotation? _spokenSentenceHighlight(TtsUiState ttsState) {
    if (!ttsState.isActive) return null;
    final sentences = _sentences;
    if (sentences == null) return null;
    final i = ttsState.currentIndex;
    if (i < 0 || i >= sentences.length) return null;
    final s = sentences[i];
    final now = DateTime.now();
    return Annotation(
      id: '__tts_current__',
      bookId: widget.bookId,
      type: AnnotationType.highlight,
      createdAt: now,
      updatedAt: now,
      colorValue: 0xFF80D8FF, // distinct read-aloud tint
      startOffset: s.start,
      endOffset: s.end,
    );
  }

  Future<void> _applyHighlight({
    int? color,
    AnnotationType type = AnnotationType.highlight,
  }) async {
    final sel = _pending;
    if (sel == null) return;
    await ref.read(annotationControllerProvider(widget.bookId)).addHighlight(
          start: sel.start,
          end: sel.end,
          text: sel.text,
          colorValue: color,
          type: type,
        );
    _clearSelection();
  }

  Future<void> _copySelection() async {
    final sel = _pending;
    if (sel == null) return;
    await Clipboard.setData(ClipboardData(text: sel.text));
    _clearSelection();
  }

  Future<void> _addNote() async {
    final sel = _pending;
    if (sel == null) return;
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => _NoteDialog(selectedText: sel.text),
    );
    if (note != null && note.trim().isNotEmpty) {
      await ref.read(annotationControllerProvider(widget.bookId)).addNote(
            start: sel.start,
            end: sel.end,
            selectedText: sel.text,
            noteText: note.trim(),
          );
    }
    _clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(readerBookProvider(widget.bookId));
    final ui = ref.watch(readerControllerProvider(widget.bookId));
    final settings = ref.watch(settingsProvider);
    final palette = ReadingPalette.of(settings.theme);
    final annotations =
        ref.watch(annotationsProvider(widget.bookId)).valueOrNull ?? const [];
    final hasOcrContent =
        ref.watch(ocrContentProvider(widget.bookId)) != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: palette.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: palette.background,
        body: bookAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ReaderError(message: '$e'),
          data: (book) {
            final tts = ref.read(ttsControllerProvider(widget.bookId));
            return ValueListenableBuilder<TtsUiState>(
              valueListenable: tts.state,
              builder: (context, ttsState, _) {
                final spoken = _spokenSentenceHighlight(ttsState);
                final allAnnotations =
                    spoken == null ? annotations : [...annotations, spoken];
                return Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => ref
                            .read(readerControllerProvider(widget.bookId).notifier)
                            .toggleImmersive(),
                        child: _ReaderSurface(
                          bookId: widget.bookId,
                          book: book,
                          mode: ui.mode,
                          palette: palette,
                          jumpPercent: _jumpPercent,
                          annotations: allAnnotations,
                          onSelect: (start, end, text) => setState(
                              () => _pending = (start: start, end: end, text: text)),
                        ),
                      ),
                    ),
                    if (book.needsOcr && !hasOcrContent && !ui.immersive)
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 88, left: 16, right: 16),
                          child: _OcrBanner(
                            onRun: () =>
                                context.push(Routes.ocrPath(widget.bookId)),
                          ),
                        ),
                      ),
                    AnimatedSlide(
                      duration: const Duration(milliseconds: 220),
                      offset: ui.immersive ? const Offset(0, -1) : Offset.zero,
                      child: _TopBar(
                        bookId: widget.bookId,
                        book: book,
                        palette: palette,
                        onJump: (percent) => setState(() => _jumpPercent = percent),
                        onToggleTts: _toggleTts,
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_pending != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: SelectionToolbar(
                                onHighlight: (color) =>
                                    _applyHighlight(color: color),
                                onUnderline: () => _applyHighlight(
                                    type: AnnotationType.underline),
                                onNote: _addNote,
                                onCopy: _copySelection,
                                onDismiss: _clearSelection,
                              ),
                            ),
                          if (ttsBarVisible(ttsState) && !ui.immersive)
                            TtsBar(
                              state: ttsState,
                              palette: palette,
                              onPlayPause: _toggleTts,
                              onStop: tts.stop,
                              onSpeed: tts.setSpeed,
                              onSleepTimer: tts.setSleepTimer,
                            ),
                          AnimatedSlide(
                            duration: const Duration(milliseconds: 220),
                            offset: ui.immersive
                                ? const Offset(0, 1)
                                : Offset.zero,
                            child: _BottomBar(
                              bookId: widget.bookId,
                              book: book,
                              palette: palette,
                              onJump: (percent) =>
                                  setState(() => _jumpPercent = percent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Selects the renderer for the active mode and feeds it content + resume point.
class _ReaderSurface extends ConsumerWidget {
  const _ReaderSurface({
    required this.bookId,
    required this.book,
    required this.mode,
    required this.palette,
    required this.jumpPercent,
    required this.annotations,
    required this.onSelect,
  });

  final String bookId;
  final Book book;
  final ReadingMode mode;
  final ReadingPalette palette;
  final double? jumpPercent;
  final List<Annotation> annotations;
  final void Function(int start, int end, String text) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(readerControllerProvider(bookId).notifier);
    final resume = ref.watch(readerResumeProvider(bookId)).valueOrNull;
    final initialPercent = jumpPercent ?? resume?.percent ?? 0.0;

    if (mode == ReadingMode.original) {
      return OriginalReaderView(
        key: ValueKey('orig-$jumpPercent'),
        filePath: book.filePath,
        initialPercent: initialPercent,
        onProgress: (percent, page, count) => controller.onPositionChanged(
          percent: percent,
          charOffset: 0,
        ),
      );
    }

    final contentAsync = ref.watch(readerContentProvider(bookId));
    return contentAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ReaderError(message: '$e'),
      data: (content) {
        // Feed session tracking the totals for pages/words-read estimates.
        controller.setBookMetrics(
            pageCount: book.pageCount, wordCount: content.wordCount);
        return SmartReaderView(
        // Changing the key on a TOC jump re-lays out at the new fraction.
        key: ValueKey('smart-$jumpPercent-${settings.fontSizeSp}'
            '-${settings.pageNavigation}'),
        content: content,
        typography: ReaderTypography(settings, palette),
        navigation: settings.pageNavigation,
        initialPercent: initialPercent,
        annotations: annotations,
          onSelect: onSelect,
          onPosition: ({required percent, required charOffset, chapterId}) =>
              controller.onPositionChanged(
            percent: percent,
            charOffset: charOffset,
            chapterId: chapterId,
          ),
        );
      },
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.bookId,
    required this.book,
    required this.palette,
    required this.onJump,
    required this.onToggleTts,
  });

  final String bookId;
  final Book book;
  final ReadingPalette palette;
  final ValueChanged<double> onJump;
  final VoidCallback onToggleTts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(readerControllerProvider(bookId));
    final controller = ref.read(annotationControllerProvider(bookId));

    return Material(
      color: palette.background.withValues(alpha: 0.96),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: palette.text),
              onPressed: () => context.pop(),
            ),
            Expanded(
              child: Text(
                book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: palette.text, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'Add bookmark',
              icon: Icon(Icons.bookmark_add_outlined, color: palette.text),
              onPressed: () async {
                await controller.addBookmark(
                  percent: ui.percent,
                  charOffset: ui.charOffset,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bookmark added')),
                  );
                }
              },
            ),
            IconButton(
              tooltip: 'Bookmarks',
              icon: Icon(Icons.bookmarks_outlined, color: palette.text),
              onPressed: () => _openBookmarks(context, ref),
            ),
            IconButton(
              tooltip: 'Read aloud',
              icon: Icon(Icons.headphones_rounded, color: palette.text),
              onPressed: onToggleTts,
            ),
            PopupMenuButton<String>(
              iconColor: palette.text,
              onSelected: (value) {
                if (value == 'export') _exportNotes(context, controller);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'export', child: Text('Export notes')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBookmarks(BuildContext context, WidgetRef ref) async {
    final bookmarks =
        ref.read(bookmarksProvider(bookId)).valueOrNull ?? const [];
    final action = await BookmarksSheet.show(context, bookmarks: bookmarks);
    final controller = ref.read(annotationControllerProvider(bookId));
    switch (action) {
      case DeleteBookmark(:final bookmark):
        await controller.deleteBookmark(bookmark.id);
      case JumpToBookmark(:final bookmark):
        final percent = bookmark.percent;
        if (percent != null) onJump(percent);
      case null:
        break;
    }
  }

  Future<void> _exportNotes(
    BuildContext context,
    AnnotationController controller,
  ) async {
    final markdown = await controller.exportNotes();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exported notes'),
        content: SingleChildScrollView(child: SelectableText(markdown)),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: markdown));
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Simple dialog to capture a note's text for the current selection.
class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.selectedText});
  final String selectedText;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add note'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '“${widget.selectedText}”',
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(hintText: 'Your note…'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({
    required this.bookId,
    required this.book,
    required this.palette,
    required this.onJump,
  });

  final String bookId;
  final Book book;
  final ReadingPalette palette;
  final ValueChanged<double> onJump;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(readerControllerProvider(bookId));
    final content = ref.watch(readerContentProvider(bookId)).valueOrNull;
    final settings = ref.watch(settingsProvider);

    final wordsRemaining = content == null
        ? 0
        : (content.wordCount * (1 - ui.percent)).round();
    final remaining = const EstimateRemainingTime()
        .call(wordsRemaining: wordsRemaining, wordsPerMinute: 238);

    return Material(
      color: palette.background.withValues(alpha: 0.96),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: ui.percent.clamp(0.0, 1.0),
                onChanged: (v) => onJump(v),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${(ui.percent * 100).round()}%',
                      style: TextStyle(color: palette.secondaryText)),
                  if (ui.mode == ReadingMode.smart && remaining.inMinutes > 0)
                    Text('${remaining.inMinutes} min left',
                        style: TextStyle(color: palette.secondaryText)),
                  Row(
                    children: [
                      if (book.supportsBothModes)
                        IconButton(
                          tooltip: ui.mode == ReadingMode.smart
                              ? 'Original mode'
                              : 'Smart mode',
                          icon: Icon(
                            ui.mode == ReadingMode.smart
                                ? Icons.picture_as_pdf_outlined
                                : Icons.article_outlined,
                            color: palette.text,
                          ),
                          onPressed: () => ref
                              .read(readerControllerProvider(bookId).notifier)
                              .setMode(ui.mode == ReadingMode.smart
                                  ? ReadingMode.original
                                  : ReadingMode.smart),
                        ),
                      IconButton(
                        tooltip: 'Contents',
                        icon: Icon(Icons.menu_rounded, color: palette.text),
                        onPressed: content == null
                            ? null
                            : () => _openToc(context, content, ui.chapterId),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openToc(
    BuildContext context,
    BookContent content,
    String? currentChapterId,
  ) async {
    final target = await TableOfContentsSheet.show(
      context,
      content: content,
      currentChapterId: currentChapterId,
    );
    if (target != null) onJump(target);
  }
}

/// Prompt shown over a scanned (image-only) book offering to run OCR.
class _OcrBanner extends StatelessWidget {
  const _OcrBanner({required this.onRun});
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            const Icon(Icons.document_scanner_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'This looks like a scanned document. Run OCR to read it in '
                'Smart Mode.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: onRun, child: const Text('Run OCR')),
          ],
        ),
      ),
    );
  }
}

class _ReaderError extends StatelessWidget {
  const _ReaderError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 12),
            Text('Could not open this book.\n$message',
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
