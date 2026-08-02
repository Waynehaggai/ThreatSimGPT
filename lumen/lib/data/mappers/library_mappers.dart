import '../../domain/entities/book.dart';
import '../../domain/entities/collection.dart';
import '../local/isar_ids.dart';
import '../local/models/library_models.dart';

/// Maps between the [Book] domain entity and its Isar [BookModel].
extension BookModelMapper on BookModel {
  Book toEntity() => Book(
        id: uid,
        title: title,
        author: author,
        format: format,
        filePath: filePath,
        fileSizeBytes: fileSizeBytes,
        pageCount: pageCount,
        dateImported: dateImported,
        coverPath: coverPath,
        lastOpened: lastOpened,
        progressPercent: progressPercent,
        isFavorite: isFavorite,
        isArchived: isArchived,
        collectionIds: collectionIds,
        needsOcr: needsOcr,
        hasSmartContent: hasSmartContent,
        defaultMode: defaultMode,
        language: language,
        checksum: checksum,
      );
}

extension BookEntityMapper on Book {
  BookModel toModel() => BookModel()
    ..id = fastHash(id)
    ..uid = id
    ..title = title
    ..author = author
    ..format = format
    ..filePath = filePath
    ..coverPath = coverPath
    ..fileSizeBytes = fileSizeBytes
    ..pageCount = pageCount
    ..dateImported = dateImported
    ..lastOpened = lastOpened
    ..progressPercent = progressPercent
    ..isFavorite = isFavorite
    ..isArchived = isArchived
    ..collectionIds = collectionIds
    ..needsOcr = needsOcr
    ..hasSmartContent = hasSmartContent
    ..defaultMode = defaultMode
    ..language = language
    ..checksum = checksum;
}

extension CollectionModelMapper on CollectionModel {
  Collection toEntity() => Collection(
        id: uid,
        name: name,
        createdAt: createdAt,
        updatedAt: updatedAt,
        description: description,
        colorValue: colorValue,
        iconCodePoint: iconCodePoint,
        sortIndex: sortIndex,
        isDeleted: isDeleted,
      );
}

extension CollectionEntityMapper on Collection {
  CollectionModel toModel() => CollectionModel()
    ..id = fastHash(id)
    ..uid = id
    ..name = name
    ..description = description
    ..colorValue = colorValue
    ..iconCodePoint = iconCodePoint
    ..sortIndex = sortIndex
    ..createdAt = createdAt
    ..updatedAt = updatedAt
    ..isDeleted = isDeleted;
}
