/// Domain-level enumerations shared across entities.
///
/// These are pure Dart (no Flutter, no persistence annotations) so they can be
/// referenced from any layer and unit-tested in isolation.

/// The source format a book was imported from.
enum BookFormat {
  pdf,
  epub,
  txt,
  docx,
  // Planned — see AppConstants.plannedImportExtensions.
  mobi,
  azw3,
  cbz,
  cbr,
  unknown;

  static BookFormat fromExtension(String ext) {
    return switch (ext.toLowerCase().replaceAll('.', '')) {
      'pdf' => BookFormat.pdf,
      'epub' => BookFormat.epub,
      'txt' => BookFormat.txt,
      'docx' => BookFormat.docx,
      'mobi' => BookFormat.mobi,
      'azw3' => BookFormat.azw3,
      'cbz' => BookFormat.cbz,
      'cbr' => BookFormat.cbr,
      _ => BookFormat.unknown,
    };
  }

  /// Whether Smart Reading Mode (reflowable text) can be generated for this
  /// format. PDFs may still require OCR — see [Book.needsOcr].
  bool get supportsSmartMode => switch (this) {
        BookFormat.pdf ||
        BookFormat.epub ||
        BookFormat.txt ||
        BookFormat.docx =>
          true,
        _ => false,
      };

  /// Whether an authored fixed layout exists worth preserving in Original Mode.
  bool get hasOriginalLayout => this == BookFormat.pdf ||
      this == BookFormat.cbz ||
      this == BookFormat.cbr;
}

/// How the reader currently renders a book.
enum ReadingMode {
  /// Pixel-perfect reproduction of the authored document (e.g. PDF pages).
  original,

  /// Reflowable, responsive eBook rebuilt from extracted content.
  smart,
}

/// Page navigation style inside the reader.
enum PageNavigation {
  pageTurn,
  verticalScroll,
  horizontalScroll,
  twoPageLandscape,
  continuous,
}

/// Visual themes available in the reader (distinct from the app-chrome theme).
enum ReadingTheme {
  light,
  dark,
  sepia,
  cream,
  amoledBlack,
}

/// Text alignment within reflowed content.
enum ReadingTextAlign { start, justify, center }

/// Annotation kinds a user can create over text.
enum AnnotationType { highlight, underline, note, stickyNote }

/// Lifecycle state of a queued offline operation.
enum SyncOperationStatus { pending, inFlight, failed, completed }

/// The kind of local change a sync operation represents.
enum SyncEntityType { book, annotation, progress, collection, settings, statistics }

/// CRUD verb for a sync operation.
enum SyncAction { create, update, delete }

/// How the user is authenticated.
enum AuthMethod { emailPassword, google, apple, guest }
