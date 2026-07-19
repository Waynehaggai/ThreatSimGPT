import '../../domain/entities/annotation.dart';
import '../../domain/entities/bookmark.dart';
import '../local/isar_ids.dart';
import '../local/models/annotation_models.dart';

extension AnnotationModelMapper on AnnotationModel {
  Annotation toEntity() => Annotation(
        id: uid,
        bookId: bookId,
        type: type,
        createdAt: createdAt,
        updatedAt: updatedAt,
        selectedText: selectedText,
        noteText: noteText,
        colorValue: colorValue,
        page: page,
        startOffset: startOffset,
        endOffset: endOffset,
        cfi: cfi,
        chapterId: chapterId,
        isDeleted: isDeleted,
      );
}

extension AnnotationEntityMapper on Annotation {
  AnnotationModel toModel() => AnnotationModel()
    ..id = fastHash(id)
    ..uid = id
    ..bookId = bookId
    ..type = type
    ..selectedText = selectedText
    ..noteText = noteText
    ..colorValue = colorValue
    ..page = page
    ..startOffset = startOffset
    ..endOffset = endOffset
    ..cfi = cfi
    ..chapterId = chapterId
    ..createdAt = createdAt
    ..updatedAt = updatedAt
    ..isDeleted = isDeleted;
}

extension BookmarkModelMapper on BookmarkModel {
  Bookmark toEntity() => Bookmark(
        id: uid,
        bookId: bookId,
        createdAt: createdAt,
        label: label,
        page: page,
        percent: percent,
        charOffset: charOffset,
        cfi: cfi,
        chapterTitle: chapterTitle,
        previewText: previewText,
        isDeleted: isDeleted,
      );
}

extension BookmarkEntityMapper on Bookmark {
  BookmarkModel toModel() => BookmarkModel()
    ..id = fastHash(id)
    ..uid = id
    ..bookId = bookId
    ..label = label
    ..page = page
    ..percent = percent
    ..charOffset = charOffset
    ..cfi = cfi
    ..chapterTitle = chapterTitle
    ..previewText = previewText
    ..createdAt = createdAt
    ..isDeleted = isDeleted;
}
