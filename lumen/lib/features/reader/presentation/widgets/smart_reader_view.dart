import 'package:flutter/material.dart';

import '../../../../domain/entities/annotation.dart';
import '../../../../domain/entities/book_content.dart';
import '../../../../domain/entities/enums.dart';
import '../rendering/block_renderer.dart';
import '../rendering/page_packer.dart';
import '../rendering/reader_typography.dart';
import '../rendering/reflow_paginator.dart';

/// Callback fired as the reader position changes.
typedef PositionChanged = void Function({
  required double percent,
  required int charOffset,
  String? chapterId,
});

/// Annotations overlapping a block's [start, start+len) character range.
List<Annotation> annotationsForBlock(List<Annotation> all, ContentBlock block) {
  if (all.isEmpty) return const [];
  final start = block.charOffset;
  final end = start + (block.text?.length ?? 0);
  return all.where((a) {
    final s = a.startOffset;
    final e = a.endOffset;
    if (s == null || e == null) return false;
    return s < end && e > start; // ranges overlap
  }).toList();
}

/// Renders Smart Reading Mode content responsively.
///
/// Chooses between continuous vertical scroll and page-turn (paginated) based on
/// [navigation]. Both report position back via [onPosition] and resume from
/// [initialPercent]. Typography, spacing and margins all come from
/// [typography] (i.e. the user's reading settings), so a settings change
/// re-lays out the whole book.
class SmartReaderView extends StatefulWidget {
  const SmartReaderView({
    required this.content,
    required this.typography,
    required this.navigation,
    required this.initialPercent,
    required this.onPosition,
    this.annotations = const [],
    this.onSelect,
    this.onToggleChrome,
    super.key,
  });

  final BookContent content;
  final ReaderTypography typography;
  final PageNavigation navigation;
  final double initialPercent;
  final PositionChanged onPosition;

  /// Existing highlights/underlines to paint over the text.
  final List<Annotation> annotations;

  /// Fired when the user selects text (absolute offsets + the selected string).
  final BlockSelected? onSelect;

  /// Fired on a centre tap so the reader can show/hide its chrome. Side and
  /// bottom taps turn the page instead (page-turn mode only).
  final VoidCallback? onToggleChrome;

  @override
  State<SmartReaderView> createState() => _SmartReaderViewState();
}

class _SmartReaderViewState extends State<SmartReaderView> {
  late final List<ContentBlock> _blocks;
  late final List<String> _chapterIds;

  @override
  void initState() {
    super.initState();
    _blocks = [];
    _chapterIds = [];
    for (final chapter in widget.content.chapters) {
      for (final block in chapter.blocks) {
        _blocks.add(block);
        _chapterIds.add(chapter.id);
      }
    }
  }

  int _charOffsetFor(double percent) {
    if (_blocks.isEmpty) return 0;
    final index = (percent * (_blocks.length - 1)).round().clamp(
          0,
          _blocks.length - 1,
        );
    return _blocks[index].charOffset;
  }

  String? _chapterFor(double percent) {
    if (_chapterIds.isEmpty) return null;
    final index = (percent * (_chapterIds.length - 1)).round().clamp(
          0,
          _chapterIds.length - 1,
        );
    return _chapterIds[index];
  }

  @override
  Widget build(BuildContext context) {
    final paginated = widget.navigation == PageNavigation.pageTurn ||
        widget.navigation == PageNavigation.horizontalScroll;
    return paginated ? _buildPaginated(context) : _buildContinuous(context);
  }

  // ── Continuous vertical scroll ─────────────────────────────────────────
  Widget _buildContinuous(BuildContext context) {
    return GestureDetector(
      onTap: widget.onToggleChrome,
      child: _ContinuousScroll(
        blocks: _blocks,
        typography: widget.typography,
        annotations: widget.annotations,
        onSelect: widget.onSelect,
        initialPercent: widget.initialPercent,
        onPercent: (percent) => widget.onPosition(
          percent: percent,
          charOffset: _charOffsetFor(percent),
          chapterId: _chapterFor(percent),
        ),
      ),
    );
  }

  // ── Page-turn (paginated) ──────────────────────────────────────────────

  // Pagination is expensive (a TextPainter.layout per block), so it is cached
  // and only recomputed when an input that affects layout actually changes —
  // never on incidental rebuilds (page turns, TTS ticks, annotation edits).
  List<PageRange>? _cachedRanges;
  Object? _cachedKey;

  List<PageRange> _paginate(
    Size pageSize,
    TextDirection dir,
    TextScaler scaler,
  ) {
    final s = widget.typography.settings;
    final key = (
      pageSize,
      dir,
      scaler.scale(s.fontSizeSp),
      s.fontSizeSp,
      s.lineHeight,
      s.paragraphSpacing,
      s.horizontalMargin,
      s.fontWeight,
      s.fontFamily,
      s.textAlign,
    );
    if (_cachedRanges != null && key == _cachedKey) return _cachedRanges!;
    final ranges = ReflowPaginator(widget.typography).paginate(
      blocks: _blocks,
      pageSize: pageSize,
      textDirection: dir,
      textScaler: scaler,
    );
    _cachedRanges = ranges;
    _cachedKey = key;
    return ranges;
  }

  Widget _buildPaginated(BuildContext context) {
    // The device's system font scale must feed the height measurement so the
    // packer matches what actually renders — otherwise a phone with enlarged
    // system text over-fills each page and the column overflows.
    final textScaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final margin = widget.typography.horizontalMargin;
        final pageSize = Size(
          constraints.maxWidth - margin * 2,
          constraints.maxHeight - 96, // room for top/bottom chrome
        );
        final ranges =
            _paginate(pageSize, Directionality.of(context), textScaler);
        if (ranges.isEmpty) return const SizedBox.shrink();

        return _PaginatedScroll(
          // Rebuild the controller only when the pagination actually changes.
          key: ValueKey(
            '${constraints.maxWidth}x${constraints.maxHeight}'
            '-${widget.typography.settings.fontSizeSp}'
            '-${textScaler.scale(widget.typography.settings.fontSizeSp)}'
            '-${ranges.length}',
          ),
          blocks: _blocks,
          ranges: ranges,
          typography: widget.typography,
          annotations: widget.annotations,
          onSelect: widget.onSelect,
          onToggleChrome: widget.onToggleChrome,
          margin: margin,
          initialPercent: widget.initialPercent,
          onPercent: (percent) => widget.onPosition(
            percent: percent,
            charOffset: _charOffsetFor(percent),
            chapterId: _chapterFor(percent),
          ),
        );
      },
    );
  }
}

/// PageView over pre-computed [PageRange]s, owning its [PageController].
class _PaginatedScroll extends StatefulWidget {
  const _PaginatedScroll({
    required this.blocks,
    required this.ranges,
    required this.typography,
    required this.annotations,
    required this.onSelect,
    required this.onToggleChrome,
    required this.margin,
    required this.initialPercent,
    required this.onPercent,
    super.key,
  });

  final List<ContentBlock> blocks;
  final List<PageRange> ranges;
  final ReaderTypography typography;
  final List<Annotation> annotations;
  final BlockSelected? onSelect;
  final VoidCallback? onToggleChrome;
  final double margin;
  final double initialPercent;
  final ValueChanged<double> onPercent;

  @override
  State<_PaginatedScroll> createState() => _PaginatedScrollState();
}

class _PaginatedScrollState extends State<_PaginatedScroll> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    final count = widget.ranges.length;
    final initialPage = (widget.initialPercent * (count - 1)).round().clamp(
          0,
          count - 1,
        );
    _controller = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The page currently settled under the viewport.
  int get _currentPage =>
      (_controller.hasClients ? _controller.page : null)?.round() ??
      _controller.initialPage;

  void _turn(int delta) {
    final target = (_currentPage + delta).clamp(0, widget.ranges.length - 1);
    if (target == _currentPage) return;
    _controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  /// Maps a tap position to an action: left third → previous, right third or
  /// bottom strip → next, centre → toggle the reader chrome.
  void _onTapAt(Offset pos, Size size) {
    if (pos.dy > size.height * 0.82) {
      _turn(1); // bottom strip advances — reachable one-handed
    } else if (pos.dx < size.width * 0.30) {
      _turn(-1);
    } else if (pos.dx > size.width * 0.70) {
      _turn(1);
    } else {
      widget.onToggleChrome?.call();
    }
  }

  // A pointer is only treated as a tap (not a swipe or a long-press for text
  // selection) when it lifts quickly and close to where it went down.
  Offset? _downPos;
  DateTime? _downAt;

  void _onPointerDown(PointerDownEvent e) {
    _downPos = e.localPosition;
    _downAt = DateTime.now();
  }

  void _onPointerUp(PointerUpEvent e, Size size) {
    final down = _downPos;
    final at = _downAt;
    _downPos = null;
    _downAt = null;
    if (down == null || at == null) return;
    final moved = (e.localPosition - down).distance;
    final elapsed = DateTime.now().difference(at);
    // A drag (swipe to turn) or a long-press (text selection) is not a tap.
    if (moved > 14 || elapsed > const Duration(milliseconds: 300)) return;
    _onTapAt(e.localPosition, size);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.ranges.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        // A passive Listener (not a GestureDetector) reads raw pointer events,
        // so tap-to-turn works even over selectable text — which would
        // otherwise win the gesture arena — while still leaving swipe-to-turn
        // and long-press selection untouched.
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onPointerDown,
          onPointerUp: (e) => _onPointerUp(e, size),
          child: PageView.builder(
            controller: _controller,
            itemCount: count,
            onPageChanged: (page) =>
                widget.onPercent(count <= 1 ? 0.0 : page / (count - 1)),
            itemBuilder: (context, page) {
              final range = widget.ranges[page];
              // Isolate each page's raster so turning one doesn't repaint the
              // neighbour, keeping the swipe/turn animation smooth.
              return RepaintBoundary(
                child: Padding(
                  padding:
                      EdgeInsets.fromLTRB(widget.margin, 24, widget.margin, 24),
                  // Non-scrollable viewport as insurance: measurement matches
                  // rendering closely, but any sub-pixel drift should crop
                  // quietly rather than surface a RenderFlex overflow band.
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = range.start; i < range.end; i++) ...[
                          BlockView(
                            block: widget.blocks[i],
                            typography: widget.typography,
                            annotations: annotationsForBlock(
                              widget.annotations,
                              widget.blocks[i],
                            ),
                            onSelect: widget.onSelect,
                          ),
                          SizedBox(height: widget.typography.blockSpacing),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Continuous vertical scroll with resume + percent reporting.
class _ContinuousScroll extends StatefulWidget {
  const _ContinuousScroll({
    required this.blocks,
    required this.typography,
    required this.annotations,
    required this.onSelect,
    required this.initialPercent,
    required this.onPercent,
  });

  final List<ContentBlock> blocks;
  final ReaderTypography typography;
  final List<Annotation> annotations;
  final BlockSelected? onSelect;
  final double initialPercent;
  final ValueChanged<double> onPercent;

  @override
  State<_ContinuousScroll> createState() => _ContinuousScrollState();
}

class _ContinuousScrollState extends State<_ContinuousScroll> {
  final _controller = ScrollController();
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restorePosition());
  }

  void _restorePosition() {
    if (_restored || !_controller.hasClients) return;
    final max = _controller.position.maxScrollExtent;
    if (max > 0 && widget.initialPercent > 0) {
      _controller.jumpTo(widget.initialPercent * max);
    }
    _restored = true;
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final max = _controller.position.maxScrollExtent;
    final percent = max <= 0 ? 0.0 : (_controller.offset / max).clamp(0.0, 1.0);
    widget.onPercent(percent);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final margin = widget.typography.horizontalMargin;
    return ListView.builder(
      controller: _controller,
      padding: EdgeInsets.fromLTRB(margin, 32, margin, 96),
      itemCount: widget.blocks.length,
      itemBuilder: (context, i) => Padding(
        padding: EdgeInsets.only(bottom: widget.typography.blockSpacing),
        child: BlockView(
          block: widget.blocks[i],
          typography: widget.typography,
          annotations: annotationsForBlock(
            widget.annotations,
            widget.blocks[i],
          ),
          onSelect: widget.onSelect,
        ),
      ),
    );
  }
}
