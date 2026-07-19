import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../domain/entities/book_content.dart';
import 'reader_typography.dart';

/// Renders a single [ContentBlock] of Smart Mode content into a widget.
///
/// Pure presentation: given a block and the resolved [ReaderTypography] it
/// returns the styled widget. No zooming, no horizontal scrolling — everything
/// reflows to the available width. Kept as a top-level function so it is trivial
/// to widget-test each block type in isolation.
Widget renderBlock(ContentBlock block, ReaderTypography typo) {
  final text = block.text ?? '';
  return switch (block.type) {
    BlockType.heading => Text(text, style: typo.heading(block.level)),
    BlockType.paragraph =>
      Text(text, style: typo.paragraph, textAlign: typo.textAlign),
    BlockType.quote => _Quote(text: text, typo: typo),
    BlockType.caption => Text(
        text,
        style: typo.caption,
        textAlign: TextAlign.center,
      ),
    BlockType.list => _ListBlock(text: text, typo: typo),
    BlockType.code => _CodeBlock(text: text, typo: typo),
    BlockType.image => _ImageBlock(path: block.imagePath),
    BlockType.pageBreak => const SizedBox(height: 32),
  };
}

class _Quote extends StatelessWidget {
  const _Quote({required this.text, required this.typo});
  final String text;
  final ReaderTypography typo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: typo.palette.text.withValues(alpha: 0.3), width: 3),
        ),
      ),
      child: Text(text, style: typo.quote, textAlign: typo.textAlign),
    );
  }
}

class _ListBlock extends StatelessWidget {
  const _ListBlock({required this.text, required this.typo});
  final String text;
  final ReaderTypography typo;

  @override
  Widget build(BuildContext context) {
    final items = text.split('\n').where((l) => l.trim().isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: typo.paragraph),
                Expanded(
                  child: Text(item.trim(), style: typo.paragraph),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.text, required this.typo});
  final String text;
  final ReaderTypography typo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: typo.palette.text.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: typo.code),
    );
  }
}

class _ImageBlock extends StatelessWidget {
  const _ImageBlock({required this.path});
  final String? path;

  @override
  Widget build(BuildContext context) {
    final p = path;
    if (p == null || !File(p).existsSync()) {
      return const SizedBox.shrink();
    }
    // Responsive: never exceed the column width; preserve aspect ratio.
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(File(p), fit: BoxFit.fitWidth, width: double.infinity),
    );
  }
}
