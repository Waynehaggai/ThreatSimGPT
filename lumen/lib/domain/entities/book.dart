import 'enums.dart';

/// A book in the user's personal library.
///
/// This is a pure domain entity: immutable, framework-agnostic, and free of any
/// persistence or serialization concerns (those live in `data/`). Instances are
/// produced by repositories and consumed by use cases and view models.
class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.format,
    required this.filePath,
    required this.fileSizeBytes,
    required this.pageCount,
    required this.dateImported,
    this.coverPath,
    this.lastOpened,
    this.progressPercent = 0.0,
    this.isFavorite = false,
    this.isArchived = false,
    this.collectionIds = const <String>[],
    this.needsOcr = false,
    this.hasSmartContent = false,
    this.defaultMode = ReadingMode.smart,
    this.language,
    this.checksum,
  });

  /// Stable app-generated identifier (UUID v4), used as the sync key.
  final String id;
  final String title;
  final String author;
  final BookFormat format;

  /// Absolute path to the original imported file in app storage.
  final String filePath;
  final int fileSizeBytes;
  final int pageCount;
  final DateTime dateImported;

  /// Absolute path to a generated/extracted cover image, if any.
  final String? coverPath;
  final DateTime? lastOpened;

  /// Reading progress in the range 0.0–1.0.
  final double progressPercent;

  final bool isFavorite;
  final bool isArchived;

  /// Collections this book belongs to (many-to-many by id).
  final List<String> collectionIds;

  /// `true` when the PDF is image-only and requires OCR before Smart Mode.
  final bool needsOcr;

  /// `true` once reflowable Smart Reading content has been generated.
  final bool hasSmartContent;

  /// Which mode opens by default (user-overridable per book).
  final ReadingMode defaultMode;

  final String? language;

  /// Content hash of the source file — used for dedupe on import and to detect
  /// remote/local divergence during sync.
  final String? checksum;

  bool get isFinished => progressPercent >= 0.999;
  bool get isUnread => progressPercent <= 0.0 && lastOpened == null;

  /// Whether the reader may offer a mode switch for this book.
  bool get supportsBothModes =>
      format.hasOriginalLayout && (hasSmartContent || format.supportsSmartMode);

  Book copyWith({
    String? title,
    String? author,
    String? coverPath,
    DateTime? lastOpened,
    double? progressPercent,
    bool? isFavorite,
    bool? isArchived,
    List<String>? collectionIds,
    bool? needsOcr,
    bool? hasSmartContent,
    ReadingMode? defaultMode,
    String? language,
    String? checksum,
  }) {
    return Book(
      id: id,
      title: title ?? this.title,
      author: author ?? this.author,
      format: format,
      filePath: filePath,
      fileSizeBytes: fileSizeBytes,
      pageCount: pageCount,
      dateImported: dateImported,
      coverPath: coverPath ?? this.coverPath,
      lastOpened: lastOpened ?? this.lastOpened,
      progressPercent: progressPercent ?? this.progressPercent,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
      collectionIds: collectionIds ?? this.collectionIds,
      needsOcr: needsOcr ?? this.needsOcr,
      hasSmartContent: hasSmartContent ?? this.hasSmartContent,
      defaultMode: defaultMode ?? this.defaultMode,
      language: language ?? this.language,
      checksum: checksum ?? this.checksum,
    );
  }

  @override
  bool operator ==(Object other) => other is Book && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
