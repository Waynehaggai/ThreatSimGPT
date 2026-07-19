import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/routes.dart';
import '../providers/library_providers.dart';
import '../widgets/book_grid_tile.dart';
import '../widgets/book_list_tile.dart';
import '../widgets/library_empty_state.dart';

/// The user's personal library: searchable, sortable, grid or list.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(libraryBooksProvider);
    final layout = ref.watch(libraryLayoutProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search_rounded),
            onPressed: () {}, // wired to SearchScreen (see roadmap)
          ),
          IconButton(
            tooltip: layout == LibraryLayout.grid ? 'List view' : 'Grid view',
            icon: Icon(layout == LibraryLayout.grid
                ? Icons.view_list_rounded
                : Icons.grid_view_rounded),
            onPressed: () => ref.read(libraryLayoutProvider.notifier).state =
                layout == LibraryLayout.grid
                    ? LibraryLayout.list
                    : LibraryLayout.grid,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _import(ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Import'),
      ),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load library:\n$e')),
        data: (books) {
          if (books.isEmpty) {
            return LibraryEmptyState(onImport: () => _import(ref));
          }
          return layout == LibraryLayout.grid
              ? GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    childAspectRatio: 0.62,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: books.length,
                  itemBuilder: (_, i) => BookGridTile(
                    book: books[i],
                    onTap: () =>
                        context.push(Routes.readerPath(books[i].id)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: books.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => BookListTile(
                    book: books[i],
                    onTap: () =>
                        context.push(Routes.readerPath(books[i].id)),
                  ),
                );
        },
      ),
    );
  }

  Future<void> _import(WidgetRef ref) async {
    // A real build uses file_picker to choose a document; the import use case
    // then copies it into app storage and extracts metadata. Wired in roadmap
    // milestone M2 (Import pipeline).
  }
}
