import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../providers/search_providers.dart';

/// Global search across the library (titles/authors) and the user's highlights
/// & notes. Results update instantly as the query changes.
class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(bookSearchProvider);
    final annotations = ref.watch(annotationSearchProvider);
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search books, highlights, notes…',
            border: InputBorder.none,
          ),
          onChanged: (v) =>
              ref.read(searchQueryProvider.notifier).state = v,
        ),
      ),
      body: query.trim().isEmpty
          ? const _Hint()
          : ListView(
              children: [
                _Section(
                  title: 'Books',
                  child: books.when(
                    loading: () => const _Loading(),
                    error: (e, _) => _ErrorText('$e'),
                    data: (list) => list.isEmpty
                        ? const _Empty('No matching books')
                        : Column(
                            children: [
                              for (final book in list)
                                ListTile(
                                  leading:
                                      const Icon(Icons.menu_book_outlined),
                                  title: Text(book.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  subtitle: Text(book.author),
                                  onTap: () =>
                                      context.push(Routes.readerPath(book.id)),
                                ),
                            ],
                          ),
                  ),
                ),
                _Section(
                  title: 'Highlights & notes',
                  child: annotations.when(
                    loading: () => const _Loading(),
                    error: (e, _) => _ErrorText('$e'),
                    data: (list) => list.isEmpty
                        ? const _Empty('No matching highlights or notes')
                        : Column(
                            children: [
                              for (final a in list)
                                ListTile(
                                  leading: Icon(
                                    a.noteText != null
                                        ? Icons.sticky_note_2_outlined
                                        : Icons.format_quote_rounded,
                                  ),
                                  title: Text(
                                    a.selectedText.isNotEmpty
                                        ? a.selectedText
                                        : (a.noteText ?? ''),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: a.noteText != null &&
                                          a.selectedText.isNotEmpty
                                      ? Text(a.noteText!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis)
                                      : null,
                                  onTap: () =>
                                      context.push(Routes.readerPath(a.bookId)),
                                ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: 1.2,
                  )),
        ),
        child,
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Start typing to search your library and notes.',
              textAlign: TextAlign.center),
        ),
      );
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(message,
            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message,
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );
}
