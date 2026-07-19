/// Application-wide constants. Keep this free of any Flutter imports so it can
/// be reused from pure-Dart tests and (future) server code.
abstract final class AppConstants {
  const AppConstants._();

  static const String appName = 'Lumen';
  static const String tagline = 'Read Anything. Anywhere. Forever.';

  /// Supported import formats today.
  static const Set<String> supportedImportExtensions = {
    'pdf',
    'epub',
    'txt',
    'docx',
  };

  /// Formats the architecture is designed to support next (not yet wired).
  static const Set<String> plannedImportExtensions = {
    'mobi',
    'azw3',
    'cbz',
    'cbr',
  };

  /// Average adult silent reading speed (words per minute), used to estimate
  /// remaining reading time until per-user speed is learned from statistics.
  static const int defaultWordsPerMinute = 238;

  /// Number of pages rendered/pre-cached ahead of the current page.
  static const int readerPreloadWindow = 3;

  /// Debounce applied before persisting reading progress while scrolling.
  static const Duration progressPersistDebounce = Duration(seconds: 2);

  /// How long the app may stay in the background before requiring re-auth.
  static const Duration autoLockGracePeriod = Duration(minutes: 2);

  /// Max attempts for a single sync operation before it is parked for manual
  /// retry (see the sync engine's exponential backoff).
  static const int maxSyncRetries = 5;

  /// Firestore collection names (single source of truth).
  static const String usersCollection = 'users';
  static const String booksCollection = 'books';
  static const String annotationsCollection = 'annotations';
  static const String progressCollection = 'progress';
  static const String collectionsCollection = 'collections';
  static const String settingsCollection = 'settings';
  static const String statisticsCollection = 'statistics';
}
