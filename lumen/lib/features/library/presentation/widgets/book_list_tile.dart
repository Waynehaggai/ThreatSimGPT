import 'package:flutter/material.dart';

import '../../../../domain/entities/book.dart';

/// A row in the library list view showing richer metadata than the grid.
class BookListTile extends StatelessWidget {
  const BookListTile({required this.book, required this.onTap, super.key});

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      leading: Container(
        width: 44,
        height: 60,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.menu_book_rounded,
          color: theme.colorScheme.primary,
          size: 22,
        ),
      ),
      title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${book.author}  ·  ${book.format.name.toUpperCase()}'
        '${book.pageCount > 0 ? '  ·  ${book.pageCount} pp' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: book.isFavorite
          ? const Icon(Icons.favorite_rounded, size: 18)
          : Text(
              '${(book.progressPercent * 100).round()}%',
              style: theme.textTheme.labelSmall,
            ),
    );
  }
}
