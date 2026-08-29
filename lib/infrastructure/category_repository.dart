import 'package:notel/infrastructure/category.dart';
import 'package:notel/infrastructure/db.dart';

class CategoryRepository {
  static Future<List<Category>> getAll() async {
    final rows = await Db.instance.query(Db.categoryTable, orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Category.fromMap).toList();
  }

  static Future<Category> create(String name) async {
    final trimmedName = name.trim();
    final id = await Db.instance.insert(Db.categoryTable, {'name': trimmedName});
    return Category(id: id, name: trimmedName);
  }

  static Future<void> updateName(int id, String name) async {
    final trimmedName = name.trim();
    await Db.instance.update(
      Db.categoryTable,
      {'name': trimmedName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> delete(int id) async {
    await Db.instance.transaction((txn) async {
      await txn.delete(
        Db.noteTable,
        where: 'categoryId = ?',
        whereArgs: [id],
      );
      await txn.delete(
        Db.categoryTable,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}
