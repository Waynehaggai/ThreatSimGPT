import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/reading_theme.dart';
import '../../../../domain/entities/book.dart';
import '../../../../domain/entities/book_content.dart';
import '../../../../domain/entities/enums.dart';
import '../../../../domain/usecases/reader_usecases.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../providers/reader_providers.dart';
import '../rendering/reader_typography.dart';
import '../widgets/original_reader_view.dart';
import '../widgets/smart_reader_view.dart';
import '../widgets/table_of_contents_sheet.dart';

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

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(readerBookProvider(widget.bookId));
    final ui = ref.watch(readerControllerProvider(widget.bookId));
    final settings = ref.watch(settingsProvider);
    final palette = ReadingPalette.of(settings.theme);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: palette.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: palette.background,
        body: bookAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ReaderError(message: '$e'),
          data: (book) => Stack(
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
                  ),
                ),
              ),
              AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                offset: ui.immersive ? const Offset(0, -1) : Offset.zero,
                child: _TopBar(book: book, palette: palette),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 220),
                  offset: ui.immersive ? const Offset(0, 1) : Offset.zero,
                  child: _BottomBar(
                    bookId: widget.bookId,
                    book: book,
                    palette: palette,
                    onJump: (percent) => setState(() => _jumpPercent = percent),
                  ),
                ),
              ),
            ],
          ),
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
  });

  final String bookId;
  final Book book;
  final ReadingMode mode;
  final ReadingPalette palette;
  final double? jumpPercent;

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
      data: (content) => SmartReaderView(
        // Changing the key on a TOC jump re-lays out at the new fraction.
        key: ValueKey('smart-$jumpPercent-${settings.fontSizeSp}'
            '-${settings.pageNavigation}'),
        content: content,
        typography: ReaderTypography(settings, palette),
        navigation: settings.pageNavigation,
        initialPercent: initialPercent,
        onPosition: ({required percent, required charOffset, chapterId}) =>
            controller.onPositionChanged(
          percent: percent,
          charOffset: charOffset,
          chapterId: chapterId,
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.book, required this.palette});
  final Book book;
  final ReadingPalette palette;

  @override
  Widget build(BuildContext context) {
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
              icon: Icon(Icons.bookmark_border_rounded, color: palette.text),
              onPressed: () {}, // add bookmark — AnnotationRepository (M4)
            ),
            IconButton(
              icon: Icon(Icons.headphones_rounded, color: palette.text),
              onPressed: () {}, // start TTS (M7)
            ),
          ],
        ),
      ),
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
