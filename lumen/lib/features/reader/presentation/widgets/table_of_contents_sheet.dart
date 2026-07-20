import 'package:flutter/material.dart';

import '../../../../domain/entities/book_content.dart';

/// Bottom sheet listing the book's chapters. Selecting one returns its start
/// fraction (0–1) so the reader can jump there.
class TableOfContentsSheet extends StatelessWidget {
  const TableOfContentsSheet({
    required this.content,
    required this.currentChapterId,
    super.key,
  });

  final BookContent content;
  final String? currentChapterId;

  /// Shows the sheet and completes with the selected chapter's start fraction,
  /// or `null` if dismissed.
  static Future<double?> show(
    BuildContext context, {
    required BookContent content,
    String? currentChapterId,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => TableOfContentsSheet(
        content: content,
        currentChapterId: currentChapterId,
      ),
    );
  }

  int get _totalChars {
    final last =
        content.chapters.isEmpty || content.chapters.last.blocks.isEmpty
            ? null
            : content.chapters.last.blocks.last;
    return last == null ? 1 : last.charOffset + (last.text?.length ?? 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _totalChars;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text('Contents', style: theme.textTheme.titleLarge),
          ),
          for (final chapter in content.chapters)
            ListTile(
              contentPadding: EdgeInsets.only(
                left: 20 + chapter.level * 16.0,
                right: 20,
              ),
              title: Text(
                chapter.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: chapter.id == currentChapterId
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
              selected: chapter.id == currentChapterId,
              onTap: () {
                final startOffset = chapter.blocks.isEmpty
                    ? 0
                    : chapter.blocks.first.charOffset;
                Navigator.of(
                  context,
                ).pop((startOffset / total).clamp(0.0, 1.0));
              },
            ),
        ],
      ),
    );
  }
}
