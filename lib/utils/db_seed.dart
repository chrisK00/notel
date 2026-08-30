import 'package:notel/infrastructure/date_only.dart';
import 'package:notel/infrastructure/db.dart';

import '../infrastructure/note.dart';
import '../infrastructure/category.dart';

class DebugUtil {
  static Future<void> seedDatabase() async {
    final today = DateTime.now();
    await Db.instance.delete(Db.noteTable);
    await Db.instance.delete(Db.categoryTable);
    await Db.instance.insert(Db.categoryTable, Category(id: 1, name: 'Debug Category').toMap());
    final batch = Db.instance.batch();
    for (int i = 1; i < 5; i++) {
      batch.insert(
          Db.noteTable,
          Note(
                  id: i,
                  title: i % 2 == 0 ? "$i ape" : null,
                  displayText:
                      '[{"insert":"hi $i\\n energy pooper\\n"}, {"insert":"section 2\\n"}]',
                  date: DateOnly(today.year, 3, i))
              .toMap());
    }
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
    await batch.commit(noResult: true);
  }
}
