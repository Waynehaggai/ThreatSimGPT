/// A named position a user can jump back to. Unlimited per book.
class Bookmark {
  const Bookmark({
    required this.id,
    required this.bookId,
    required this.createdAt,
    this.label,
    this.page,
    this.percent,
    this.charOffset,
    this.cfi,
    this.chapterTitle,
    this.previewText,
    this.isDeleted = false,
  });

  final String id;
  final String bookId;

  /// User-editable name; falls back to chapter/page in the UI when null.
  final String? label;

  final int? page;
  final double? percent;
  final int? charOffset;
  final String? cfi;
  final String? chapterTitle;

  /// Short snippet of surrounding text shown in the bookmarks list.
  final String? previewText;

  final DateTime createdAt;
  final bool isDeleted;

  Bookmark copyWith({
    String? label,
    int? page,
    double? percent,
    int? charOffset,
    String? cfi,
    String? chapterTitle,
    String? previewText,
    bool? isDeleted,
  }) {
    return Bookmark(
      id: id,
      bookId: bookId,
      label: label ?? this.label,
      page: page ?? this.page,
      percent: percent ?? this.percent,
      charOffset: charOffset ?? this.charOffset,
      cfi: cfi ?? this.cfi,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      previewText: previewText ?? this.previewText,
      createdAt: createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  bool operator ==(Object other) => other is Bookmark && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
