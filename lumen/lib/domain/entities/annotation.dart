import 'enums.dart';

/// A user annotation over book content: highlight, underline, note, or sticky.
///
/// A single entity models every [AnnotationType] because they share the same
/// anchoring, colour, and sync semantics — only presentation differs. This keeps
/// merge/conflict logic uniform (see the sync engine's annotation merge).
class Annotation {
  const Annotation({
    required this.id,
    required this.bookId,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.selectedText = '',
    this.noteText,
    this.colorValue,
    this.page,
    this.startOffset,
    this.endOffset,
    this.cfi,
    this.chapterId,
    this.isDeleted = false,
  });

  final String id;
  final String bookId;
  final AnnotationType type;

  /// The highlighted/underlined source text (empty for free sticky notes).
  final String selectedText;

  /// User's own note body (for [AnnotationType.note]/[AnnotationType.stickyNote],
  /// or an optional comment attached to a highlight).
  final String? noteText;

  /// ARGB colour of the highlight/underline. `null` uses the theme default.
  final int? colorValue;

  // ── Anchoring (mirrors ReadingProgress so annotations survive reflow) ──────
  final int? page;
  final int? startOffset;
  final int? endOffset;
  final String? cfi;
  final String? chapterId;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Tombstone flag — annotations are never hard-deleted so deletions can sync
  /// and the "never delete user data automatically" rule is preserved.
  final bool isDeleted;

  Annotation copyWith({
    AnnotationType? type,
    String? selectedText,
    String? noteText,
    int? colorValue,
    int? page,
    int? startOffset,
    int? endOffset,
    String? cfi,
    String? chapterId,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return Annotation(
      id: id,
      bookId: bookId,
      type: type ?? this.type,
      selectedText: selectedText ?? this.selectedText,
      noteText: noteText ?? this.noteText,
      colorValue: colorValue ?? this.colorValue,
      page: page ?? this.page,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      cfi: cfi ?? this.cfi,
      chapterId: chapterId ?? this.chapterId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  bool operator ==(Object other) => other is Annotation && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
