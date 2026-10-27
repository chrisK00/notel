import 'package:notel/infrastructure/category.dart';
import 'package:notel/infrastructure/db.dart';

class CategoryRepository {
  static Future<List<Category>> getAll() async {
    await _ensureSortOrderColumn();
    final rows = await Db.instance.query(Db.categoryTable, orderBy: 'sortOrder ASC, id ASC');
    return rows.map(Category.fromMap).toList();
  }

  static Future<Category> create(String name) async {
    final trimmedName = name.trim();
    await _ensureSortOrderColumn();
    final lastOrder = await Db.instance.rawQuery(
      'SELECT MAX(sortOrder) AS value FROM ${Db.categoryTable}',
    );
    final sortOrder = (lastOrder.single['value'] as int? ?? -1) + 1;
    final id = await Db.instance.insert(
      Db.categoryTable,
      {'name': trimmedName, 'sortOrder': sortOrder, 'showNoteDate': 1},
    );
    return Category(id: id, name: trimmedName);
  }

  static Future<void> updateOrder(List<int> categoryIds) async {
    await _ensureSortOrderColumn();
    await Db.instance.transaction((txn) async {
      final batch = txn.batch();
      for (var index = 0; index < categoryIds.length; index++) {
        batch.update(
          Db.categoryTable,
          {'sortOrder': index},
          where: 'id = ?',
          whereArgs: [categoryIds[index]],
        );
      }
      await batch.commit(noResult: true);
    });
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

  static Future<void> updateDisplaySettings(
    int id, {
    required bool showNoteDate,
    required bool? showLastModified,
  }) async {
    await Db.instance.update(
      Db.categoryTable,
      {
        'showNoteDate': showNoteDate ? 1 : 0,
        'showLastModified': showLastModified == null ? null : (showLastModified ? 1 : 0),
      },
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

  static Future<void> _ensureSortOrderColumn() async {
    final columns = await Db.instance.rawQuery('PRAGMA table_info(${Db.categoryTable})');
    if (!columns.any((column) => column['name'] == 'sortOrder')) {
      await Db.instance.execute(
        'ALTER TABLE ${Db.categoryTable} ADD COLUMN sortOrder INTEGER NOT NULL DEFAULT 0',
      );
      await Db.instance.execute('UPDATE ${Db.categoryTable} SET sortOrder = id');
    }
    if (!columns.any((column) => column['name'] == 'showNoteDate')) {
      await Db.instance.execute(
        'ALTER TABLE ${Db.categoryTable} ADD COLUMN showNoteDate INTEGER NOT NULL DEFAULT 1',
      );
    }
    if (!columns.any((column) => column['name'] == 'showLastModified')) {
      await Db.instance.execute(
        'ALTER TABLE ${Db.categoryTable} ADD COLUMN showLastModified INTEGER',
      );
    }
  }
}
