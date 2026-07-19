import '../../core/result/result.dart';
import '../entities/book.dart';
import '../repositories/library_repository.dart';
import 'usecase.dart';

/// Imports a document from disk into the library.
class ImportBook implements UseCase<Book, String> {
  const ImportBook(this._repo);
  final LibraryRepository _repo;

  @override
  Future<Result<Book>> call(String sourcePath) => _repo.importBook(sourcePath);
}

/// Toggles a book's favorite flag.
class ToggleFavorite implements UseCase<void, Book> {
  const ToggleFavorite(this._repo);
  final LibraryRepository _repo;

  @override
  Future<Result<void>> call(Book book) =>
      _repo.updateBook(book.copyWith(isFavorite: !book.isFavorite));
}

/// Archives (soft-delete) or permanently deletes a book.
class DeleteBook implements UseCase<void, DeleteBookParams> {
  const DeleteBook(this._repo);
  final LibraryRepository _repo;

  @override
  Future<Result<void>> call(DeleteBookParams params) =>
      _repo.deleteBook(params.bookId, permanent: params.permanent);
}

class DeleteBookParams {
  const DeleteBookParams(this.bookId, {this.permanent = false});
  final String bookId;
  final bool permanent;
}

/// Reactive library query stream (search/filter/sort applied in the repo).
class WatchLibrary {
  const WatchLibrary(this._repo);
  final LibraryRepository _repo;

  Stream<List<Book>> call(LibraryQuery query) => _repo.watchBooks(query);
}
