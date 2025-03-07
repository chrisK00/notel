import 'package:notel/infrastructure/db.dart';

import '../infrastructure/note.dart';

class DebugUtil {
  static Future<void> seedDatabase() async {
    final today = DateTime.now();
    Db.instance.delete(Db.noteTable);
    final batch = Db.instance.batch();
    for (int i = 1; i < 5; i++) {
      batch.insert(
          Db.noteTable,
          Note(
                  id: i,
                  title: i % 2 == 0 ? "$i ape" : null,
                  displayText:
                      '[{"insert":"hi $i\\n energy pooper\\n"}, {"insert":"section 2\\n"}]',
                  date: DateTime(today.year, 3, i))
              .toMap());
    }
    await batch.commit(noResult: true);
  }
}
