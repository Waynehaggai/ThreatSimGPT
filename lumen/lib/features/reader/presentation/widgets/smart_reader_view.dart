import 'package:flutter/material.dart';

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
    super.key,
  });

  final BookContent content;
  final ReaderTypography typography;
  final PageNavigation navigation;
  final double initialPercent;
  final PositionChanged onPosition;

  @override
  State<SmartReaderView> createState() => _SmartReaderViewState();
}

class _SmartReaderViewState extends State<SmartReaderView> {
  late final List<ContentBlock> _blocks;
  late final List<String> _chapterIds;
  late final int _totalChars;

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
    final last = _blocks.isEmpty ? null : _blocks.last;
    _totalChars = last == null ? 1 : last.charOffset + (last.text?.length ?? 1);
  }

  int _charOffsetFor(double percent) {
    if (_blocks.isEmpty) return 0;
    final index = (percent * (_blocks.length - 1)).round().clamp(0, _blocks.length - 1);
    return _blocks[index].charOffset;
  }

  String? _chapterFor(double percent) {
    if (_chapterIds.isEmpty) return null;
    final index = (percent * (_chapterIds.length - 1)).round().clamp(0, _chapterIds.length - 1);
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
    return _ContinuousScroll(
      blocks: _blocks,
      typography: widget.typography,
      initialPercent: widget.initialPercent,
      onPercent: (percent) => widget.onPosition(
        percent: percent,
        charOffset: _charOffsetFor(percent),
        chapterId: _chapterFor(percent),
      ),
    );
  }

  // ── Page-turn (paginated) ──────────────────────────────────────────────
  Widget _buildPaginated(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final margin = widget.typography.horizontalMargin;
        final pageSize = Size(
          constraints.maxWidth - margin * 2,
          constraints.maxHeight - 96, // room for top/bottom chrome
        );
        final ranges = ReflowPaginator(widget.typography).paginate(
          blocks: _blocks,
          pageSize: pageSize,
          textDirection: Directionality.of(context),
        );
        if (ranges.isEmpty) return const SizedBox.shrink();

        return _PaginatedScroll(
          // Rebuild the controller only when the pagination actually changes.
          key: ValueKey('${constraints.maxWidth}x${constraints.maxHeight}'
              '-${widget.typography.settings.fontSizeSp}-${ranges.length}'),
          blocks: _blocks,
          ranges: ranges,
          typography: widget.typography,
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
    required this.margin,
    required this.initialPercent,
    required this.onPercent,
    super.key,
  });

  final List<ContentBlock> blocks;
  final List<PageRange> ranges;
  final ReaderTypography typography;
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
    final initialPage =
        (widget.initialPercent * (count - 1)).round().clamp(0, count - 1);
    _controller = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.ranges.length;
    return PageView.builder(
      controller: _controller,
      itemCount: count,
      onPageChanged: (page) =>
          widget.onPercent(count <= 1 ? 0.0 : page / (count - 1)),
      itemBuilder: (context, page) {
        final range = widget.ranges[page];
        return Padding(
          padding: EdgeInsets.fromLTRB(widget.margin, 24, widget.margin, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = range.start; i < range.end; i++) ...[
                renderBlock(widget.blocks[i], widget.typography),
                SizedBox(height: widget.typography.blockSpacing),
              ],
            ],
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
    required this.initialPercent,
    required this.onPercent,
  });

  final List<ContentBlock> blocks;
  final ReaderTypography typography;
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
        child: renderBlock(widget.blocks[i], widget.typography),
      ),
    );
  }
}
