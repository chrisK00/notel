import 'package:notel/infrastructure/date_only.dart';
import 'package:notel/infrastructure/db.dart';

import '../infrastructure/note.dart';
import '../infrastructure/category.dart';
import 'package:sqflite_common/sqlite_api.dart';

class DebugUtil {
  static Future<void> seedDatabase() async {
    await Db.instance.delete(Db.noteTable);
    await Db.instance.delete(Db.categoryTable);
    await Db.instance.insert(Db.categoryTable, Category(id: 1, name: 'Debug Category').toMap());
    await Db.instance.insert(Db.categoryTable,
        Category(id: 2, name: 'Test Category 2', showNoteDate: false, showLastModified: false).toMap());

    final today = DateTime.now();
    final batch = Db.instance.batch();

    for (int i = 1; i < 5; i++) {
      batch.insert(
          Db.noteTable,
          Note(
                  id: i,
                  title: i % 2 == 0 ? "$i ape" : null,
                  displayText: i == 4
                      ? '[{"insert":"hi $i\\n energy pooper\\n"}, {"insert":"section 2\\n"}]'
                      : '[{"insert":"start d3 25mg\\n"}]',
                  date: DateOnly(today.year, 3, i))
              .toMap());
    }

    createCategorizedNotes(batch, today);

    await batch.commit(noResult: true);
  }

  static void createCategorizedNotes(Batch batch, DateTime today) {
    batch.insert(
      Db.noteTable,
      Note(
        id: 5,
        title: 'Categorized Debug Note',
        displayText: '[{"insert":"This note belongs to Debug Category.\\n"}]',
        date: DateOnly(today.year, 3, 5),
        categoryId: 1,
      ).toMap(),
    );
    batch.insert(
      Db.noteTable,
      Note(
        id: 6,
        title: 'Hidden Debug Note 2',
        displayText: '[{"insert":"This note belongs to Debug Category.\\n"}]',
        date: DateOnly(today.year, 3, 5),
        categoryId: 1,
        hidden: true,
        lastModified: DateTime.now().subtract(const Duration(days: 1)),
      ).toMap(),
    );

    batch.insert(
      Db.noteTable,
      Note(
        id: 7,
        title: 'Hidden Test Category Note 1',
        displayText: '[{"insert":"This note belongs to Test Category 2.\\n"}]',
        date: DateOnly(today.year, 3, 5),
        categoryId: 2,
        hidden: true,
        lastModified: DateTime.now().subtract(const Duration(days: 1)),
      ).toMap(),
    );

    batch.insert(
      Db.noteTable,
      Note(
        id: 8,
        title: 'Hidden Test Category Note 2',
        displayText: '[{"insert":"This note belongs to Test Category 2.\\n"}]',
        date: DateOnly(today.year, 3, 5),
        categoryId: 2,
        hidden: true,
        lastModified: DateTime.now().subtract(const Duration(days: 1)),
      ).toMap(),
    );
  }
}
