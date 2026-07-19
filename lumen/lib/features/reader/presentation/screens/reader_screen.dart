import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/reading_theme.dart';
import '../../../../domain/entities/book.dart';
import '../../../../domain/entities/enums.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../providers/reader_providers.dart';

/// The reading surface.
///
/// This scaffolds the full reader experience — immersive fullscreen with
/// tap-to-reveal controls, an Original/Smart mode switch, a themed page surface,
/// and a progress bar. The concrete page renderers (PDF via `pdfrx` for Original
/// Mode, a reflow engine for Smart Mode) plug into [_ReaderSurface] and are the
/// focus of roadmap milestone M3.
class ReaderScreen extends ConsumerWidget {
  const ReaderScreen({required this.bookId, super.key});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(readerBookProvider(bookId));
    final ui = ref.watch(readerControllerProvider(bookId));
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
              // Page surface — tap toggles immersive mode.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => ref
                      .read(readerControllerProvider(bookId).notifier)
                      .toggleImmersive(),
                  child: _ReaderSurface(
                    book: book,
                    mode: ui.mode,
                    palette: palette,
                    fontSize: settings.fontSizeSp,
                    fontFamily: settings.fontFamily,
                    lineHeight: settings.lineHeight,
                    margin: settings.horizontalMargin,
                  ),
                ),
              ),
              // Top + bottom control bars, hidden in immersive mode.
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
                  child: _BottomBar(bookId: bookId, mode: ui.mode,
                      supportsBoth: book.supportsBothModes, palette: palette),
                ),
              ),
            ],
          ),
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
              onPressed: () {}, // add bookmark (AnnotationRepository)
            ),
            IconButton(
              icon: Icon(Icons.headphones_rounded, color: palette.text),
              onPressed: () {}, // start TTS (TtsService)
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
    required this.mode,
    required this.supportsBoth,
    required this.palette,
  });

  final String bookId;
  final ReadingMode mode;
  final bool supportsBoth;
  final ReadingPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(readerControllerProvider(bookId));
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
                onChanged: (v) => ref
                    .read(readerControllerProvider(bookId).notifier)
                    .onProgress(v),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${(ui.percent * 100).round()}%',
                      style: TextStyle(color: palette.secondaryText)),
                  if (supportsBoth)
                    SegmentedButton<ReadingMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                            value: ReadingMode.smart,
                            icon: Icon(Icons.article_outlined),
                            label: Text('Smart')),
                        ButtonSegment(
                            value: ReadingMode.original,
                            icon: Icon(Icons.picture_as_pdf_outlined),
                            label: Text('Original')),
                      ],
                      selected: {mode},
                      onSelectionChanged: (s) => ref
                          .read(readerControllerProvider(bookId).notifier)
                          .setMode(s.first),
                    ),
                  IconButton(
                    icon: Icon(Icons.menu_rounded, color: palette.text),
                    onPressed: () {}, // table of contents
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The themed page surface. Swap the body for the real PDF/reflow renderers.
class _ReaderSurface extends StatelessWidget {
  const _ReaderSurface({
    required this.book,
    required this.mode,
    required this.palette,
    required this.fontSize,
    required this.fontFamily,
    required this.lineHeight,
    required this.margin,
  });

  final Book book;
  final ReadingMode mode;
  final ReadingPalette palette;
  final double fontSize;
  final String fontFamily;
  final double lineHeight;
  final double margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: palette.background,
      padding: EdgeInsets.symmetric(horizontal: margin, vertical: 64),
      child: Center(
        child: Text(
          mode == ReadingMode.smart
              ? 'Smart Reading Mode\n\nReflowed, responsive text renders here — '
                  'no zooming, no horizontal scrolling. Typography follows the '
                  'reader settings (font, size, spacing, theme).\n\n'
                  '“${book.title}” by ${book.author}.'
              : 'Original Mode\n\nThe authored ${book.format.name.toUpperCase()} '
                  'renders pixel-perfect here (engineering drawings, tables, '
                  'forms and academic papers stay exactly as designed).',
          style: TextStyle(
            color: palette.text,
            fontSize: fontSize,
            height: lineHeight,
            // The bundled/Google font family selected in reader settings.
            // Falls back to the platform default if unavailable.
            fontFamily: fontFamily,
          ),
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
