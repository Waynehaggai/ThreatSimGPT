import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../domain/entities/annotation.dart';
import '../../../../domain/entities/book_content.dart';
import 'annotated_text.dart';
import 'reader_typography.dart';

/// Reports a text selection within a block, in absolute character offsets.
typedef BlockSelected = void Function(int start, int end, String text);

/// Renders a single [ContentBlock] of Smart Mode content.
///
/// Text blocks are selectable ([SelectableText.rich]) and paint any overlapping
/// [annotations] (highlights/underlines). Selecting text reports absolute
/// offsets via [onSelect] so the reader can create an annotation anchored to the
/// exact words — anchoring survives reflow because offsets are absolute.
///
/// Everything reflows to the available width: no zooming, no horizontal scroll.
class BlockView extends StatelessWidget {
  const BlockView({
    required this.block,
    required this.typography,
    this.annotations = const [],
    this.onSelect,
    super.key,
  });

  final ContentBlock block;
  final ReaderTypography typography;
  final List<Annotation> annotations;
  final BlockSelected? onSelect;

  @override
  Widget build(BuildContext context) {
    return switch (block.type) {
      BlockType.heading => _text(typography.heading(block.level)),
      BlockType.paragraph => _text(typography.paragraph, align: typography.textAlign),
      BlockType.quote => _Quote(child: _text(typography.quote, palette: true)),
      BlockType.caption => _text(typography.caption, align: TextAlign.center),
      BlockType.list => _ListBlock(text: block.text ?? '', typo: typography),
      BlockType.code => _CodeBlock(child: _text(typography.code)),
      BlockType.image => _ImageBlock(path: block.imagePath),
      BlockType.pageBreak => const SizedBox(height: 32),
    };
  }

  Widget _text(TextStyle style, {TextAlign align = TextAlign.start, bool palette = false}) {
    final text = block.text ?? '';
    final span = buildAnnotatedSpan(
      text: text,
      baseOffset: block.charOffset,
      style: style,
      annotations: annotations,
    );
    return SelectableText.rich(
      span as TextSpan,
      textAlign: align,
      onSelectionChanged: onSelect == null
          ? null
          : (selection, _) {
              if (!selection.isValid || selection.isCollapsed) return;
              final start = selection.start.clamp(0, text.length);
              final end = selection.end.clamp(0, text.length);
              if (end > start) {
                onSelect!(
                  block.charOffset + start,
                  block.charOffset + end,
                  text.substring(start, end),
                );
              }
            },
    );
  }
}

class _Quote extends StatelessWidget {
  const _Quote({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
            width: 3,
          ),
        ),
      ),
      child: child,
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
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
                Expanded(child: SelectableText(item.trim(), style: typo.paragraph)),
              ],
            ),
          ),
      ],
    );
  }
}

class _ImageBlock extends StatelessWidget {
  const _ImageBlock({required this.path});
  final String? path;

  @override
  Widget build(BuildContext context) {
    final p = path;
    if (p == null || !File(p).existsSync()) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(File(p), fit: BoxFit.fitWidth, width: double.infinity),
    );
  }
}
