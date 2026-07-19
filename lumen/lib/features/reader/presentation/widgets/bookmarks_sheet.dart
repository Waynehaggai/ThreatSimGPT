import 'package:flutter/material.dart';

import '../../../../domain/entities/bookmark.dart';

/// A bookmark action returned from the sheet.
sealed class BookmarkAction {
  const BookmarkAction();
}

class JumpToBookmark extends BookmarkAction {
  const JumpToBookmark(this.bookmark);
  final Bookmark bookmark;
}

class DeleteBookmark extends BookmarkAction {
  const DeleteBookmark(this.bookmark);
  final Bookmark bookmark;
}

/// Lists a book's bookmarks with jump / delete. Returns the chosen action.
class BookmarksSheet extends StatelessWidget {
  const BookmarksSheet({required this.bookmarks, super.key});

  final List<Bookmark> bookmarks;

  static Future<BookmarkAction?> show(
    BuildContext context, {
    required List<Bookmark> bookmarks,
  }) {
    return showModalBottomSheet<BookmarkAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => BookmarksSheet(bookmarks: bookmarks),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        if (bookmarks.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('No bookmarks yet.',
                  style: theme.textTheme.bodyLarge),
            ),
          );
        }
        return ListView(
          controller: scrollController,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text('Bookmarks', style: theme.textTheme.titleLarge),
            ),
            for (final b in bookmarks)
              Dismissible(
                key: ValueKey(b.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: theme.colorScheme.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete_outline_rounded),
                ),
                onDismissed: (_) =>
                    Navigator.of(context).pop(DeleteBookmark(b)),
                child: ListTile(
                  leading: const Icon(Icons.bookmark_rounded),
                  title: Text(
                    b.label ?? b.chapterTitle ?? 'Bookmark',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: b.previewText == null
                      ? (b.percent != null
                          ? Text('${(b.percent! * 100).round()}%')
                          : null)
                      : Text(b.previewText!,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.of(context).pop(JumpToBookmark(b)),
                ),
              ),
          ],
        );
      },
    );
  }
}
