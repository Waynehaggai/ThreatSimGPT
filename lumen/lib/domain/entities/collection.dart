/// A user-defined grouping of books (e.g. "To Read", "Sci-Fi", a course).
class Collection {
  const Collection({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.colorValue,
    this.iconCodePoint,
    this.sortIndex = 0,
    this.isDeleted = false,
  });

  final String id;
  final String name;
  final String? description;
  final int? colorValue;
  final int? iconCodePoint;

  /// Manual ordering position within the collections list.
  final int sortIndex;

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  Collection copyWith({
    String? name,
    String? description,
    int? colorValue,
    int? iconCodePoint,
    int? sortIndex,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return Collection(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      sortIndex: sortIndex ?? this.sortIndex,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  bool operator ==(Object other) => other is Collection && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
