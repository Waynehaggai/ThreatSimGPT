import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen/core/theme/reading_theme.dart';
import 'package:lumen/domain/entities/book_content.dart';
import 'package:lumen/domain/entities/enums.dart';
import 'package:lumen/domain/entities/reading_settings.dart';
import 'package:lumen/features/reader/presentation/rendering/reader_typography.dart';
import 'package:lumen/features/reader/presentation/rendering/reflow_paginator.dart';

void main() {
  final typography = ReaderTypography(
    const ReadingSettings(fontFamily: '', fontSizeSp: 18),
    ReadingPalette.of(ReadingTheme.light),
  );
  final paginator = ReflowPaginator(typography);

  // A page's worth of prose split into several paragraph blocks.
  final blocks = [
    for (var i = 0; i < 20; i++)
      ContentBlock(
        type: BlockType.paragraph,
        text: 'Paragraph $i. ${'word ' * 12}'.trim(),
        charOffset: i * 80,
      ),
  ];
  const pageSize = Size(320, 560);

  test('paginates content into ordered, gap-free pages', () {
    final pages = paginator.paginate(
      blocks: blocks,
      pageSize: pageSize,
      textDirection: TextDirection.ltr,
    );
    expect(pages, isNotEmpty);
    var next = 0;
    for (final page in pages) {
      expect(page.start, next);
      expect(page.end, greaterThan(page.start));
      next = page.end;
    }
    expect(next, blocks.length);
  });

  test('a larger text scale packs fewer blocks per page (more pages)', () {
    final normal = paginator.paginate(
      blocks: blocks,
      pageSize: pageSize,
      textDirection: TextDirection.ltr,
    );
    final scaled = paginator.paginate(
      blocks: blocks,
      pageSize: pageSize,
      textDirection: TextDirection.ltr,
      textScaler: const TextScaler.linear(1.6),
    );
    // Enlarged system text must be reflected in measurement: taller lines mean
    // the same content no longer fits in as few pages.
    expect(scaled.length, greaterThan(normal.length));
  });
}
