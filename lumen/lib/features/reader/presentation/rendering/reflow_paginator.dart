import 'package:flutter/material.dart';

import '../../../../domain/entities/book_content.dart';
import 'page_packer.dart';
import 'reader_typography.dart';

/// Turns a flat list of [ContentBlock]s into page ranges for page-turn mode.
///
/// It measures each block's laid-out height at the given content [width] using
/// [TextPainter] (for text) or an aspect-ratio estimate (for images), then hands
/// the heights to the pure [PagePacker]. Splitting the measurement (Flutter) from
/// the packing (pure Dart) keeps the fiddly boundary logic unit-testable.
class ReflowPaginator {
  const ReflowPaginator(this.typography, {this.packer = const PagePacker()});

  final ReaderTypography typography;
  final PagePacker packer;

  List<PageRange> paginate({
    required List<ContentBlock> blocks,
    required Size pageSize,
    required TextDirection textDirection,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    final heights = [
      for (final block in blocks)
        _measure(block, pageSize.width, textDirection, textScaler) +
            typography.blockSpacing,
    ];
    return packer.pack(heights, pageSize.height);
  }

  double _measure(
    ContentBlock block,
    double width,
    TextDirection dir,
    TextScaler scaler,
  ) {
    switch (block.type) {
      case BlockType.image:
        // Estimate a 3:2 image scaled to the column width.
        return width * (2 / 3);
      case BlockType.pageBreak:
        return 32;
      case BlockType.heading:
        return _text(
          block.text ?? '',
          typography.heading(block.level),
          width,
          dir,
          scaler,
        );
      case BlockType.quote:
        return _text(
          block.text ?? '',
          typography.quote,
          width - 16,
          dir,
          scaler,
        );
      case BlockType.caption:
        return _text(block.text ?? '', typography.caption, width, dir, scaler);
      case BlockType.code:
        return _text(
              block.text ?? '',
              typography.code,
              width - 24,
              dir,
              scaler,
            ) +
            24;
      case BlockType.list:
      case BlockType.paragraph:
        return _text(
          block.text ?? '',
          typography.paragraph,
          width,
          dir,
          scaler,
        );
    }
  }

  double _text(
    String text,
    TextStyle style,
    double width,
    TextDirection dir,
    TextScaler scaler,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: dir,
      textScaler: scaler,
      maxLines: null,
    )..layout(maxWidth: width);
    return painter.height;
  }
}
