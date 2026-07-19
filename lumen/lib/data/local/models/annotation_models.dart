import 'package:isar/isar.dart';

import '../../../domain/entities/enums.dart';

part 'annotation_models.g.dart';

/// Isar persistence model for an [Annotation] (highlight/underline/note/sticky).
@collection
class AnnotationModel {
  Id id = Isar.autoIncrement;

  @Index()
  late String uid;

  /// Indexed so a book's annotations load and watch efficiently.
  @Index()
  late String bookId;

  @Enumerated(EnumType.name)
  late AnnotationType type;

  late String selectedText;
  String? noteText;
  int? colorValue;

  // Anchoring.
  int? page;
  int? startOffset;
  int? endOffset;
  String? cfi;
  String? chapterId;

  late DateTime createdAt;

  /// Conflict-resolution timestamp (last write wins per id on merge).
  late DateTime updatedAt;

  /// Tombstone — annotations are never hard-deleted.
  @Index()
  late bool isDeleted;
}

/// Isar persistence model for a [Bookmark].
@collection
class BookmarkModel {
  Id id = Isar.autoIncrement;

  @Index()
  late String uid;

  @Index()
  late String bookId;

  String? label;
  int? page;
  double? percent;
  int? charOffset;
  String? cfi;
  String? chapterTitle;
  String? previewText;

  late DateTime createdAt;

  @Index()
  late bool isDeleted;
}
