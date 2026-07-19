import 'package:flutter/material.dart';

/// Friendly empty state shown when the library has no books yet.
class LibraryEmptyState extends StatelessWidget {
  const LibraryEmptyState({required this.onImport, super.key});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_rounded,
                size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 20),
            Text('Your library is empty',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Import a PDF, EPUB, TXT or DOCX to start reading. Everything '
              'stays on your device and syncs when you sign in.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Import your first book'),
            ),
          ],
        ),
      ),
    );
  }
}
