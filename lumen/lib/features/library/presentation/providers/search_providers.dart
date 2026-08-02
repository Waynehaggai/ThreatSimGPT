import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/repository_providers.dart';
import '../../../../domain/entities/annotation.dart';
import '../../../../domain/entities/book.dart';
import '../../../../domain/repositories/library_repository.dart';
import 'library_providers.dart';

/// The current global search query.
final searchQueryProvider = StateProvider<String>((_) => '');

/// Books whose title/author match the query.
final bookSearchProvider = FutureProvider<List<Book>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return const [];
  final repo = ref.watch(libraryRepositoryProvider);
  return repo
      .watchBooks(LibraryQuery(search: query, includeArchived: true))
      .first;
});

/// Highlights and notes whose text matches the query.
final annotationSearchProvider = FutureProvider<List<Annotation>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return const [];
  final result =
      await ref.watch(annotationRepositoryProvider).searchAnnotations(query);
  return result.valueOrNull ?? const [];
});
