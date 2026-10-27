class Category {
  Category({
    required this.id,
    required this.name,
    this.showNoteDate = true,
    this.showLastModified,
  });

  int id;
  String name;
  bool showNoteDate;

  /// Null means this category follows the app-wide preference.
  bool? showLastModified;

  Map<String, Object?> toMap() {
    return {
      'id': id == 0 ? null : id,
      'name': name,
      'showNoteDate': showNoteDate ? 1 : 0,
      'showLastModified': showLastModified == null ? null : (showLastModified! ? 1 : 0),
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int,
      name: map['name'] as String,
      showNoteDate: map['showNoteDate'] == null || map['showNoteDate'] == 1 || map['showNoteDate'] == true,
      showLastModified: map['showLastModified'] == null
          ? null
          : map['showLastModified'] == 1 || map['showLastModified'] == true,
    );
  }

  @override
  String toString() => 'Category{id: $id, name: $name, showNoteDate: $showNoteDate, showLastModified: $showLastModified}';
}
