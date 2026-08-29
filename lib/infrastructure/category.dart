class Category {
  Category({required this.id, required this.name});

  int id;
  String name;

  Map<String, Object?> toMap() {
    return {
      'id': id == 0 ? null : id,
      'name': name,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int,
      name: map['name'] as String,
    );
  }

  @override
  String toString() => 'Category{id: $id, name: $name}';
}
