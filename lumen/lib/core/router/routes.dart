/// Centralized route path + name constants for GoRouter. Referencing these
/// instead of raw strings keeps navigation refactors safe.
abstract final class Routes {
  const Routes._();

  static const String splash = '/';
  static const String signIn = '/sign-in';
  static const String register = '/register';

  static const String library = '/library';
  static const String collections = '/collections';
  static const String statistics = '/statistics';
  static const String settings = '/settings';

  /// Reader takes a book id: `/reader/:bookId`.
  static const String reader = '/reader/:bookId';
  static String readerPath(String bookId) => '/reader/$bookId';

  static const String search = '/search';
  static const String lock = '/lock';

  // Route names (for pushNamed).
  static const String nSignIn = 'sign-in';
  static const String nRegister = 'register';
  static const String nLibrary = 'library';
  static const String nCollections = 'collections';
  static const String nStatistics = 'statistics';
  static const String nSettings = 'settings';
  static const String nReader = 'reader';
  static const String nSearch = 'search';
  static const String nLock = 'lock';
}
