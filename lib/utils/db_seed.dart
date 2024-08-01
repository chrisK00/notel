import 'package:notel/infrastructure/db.dart';

class DebugUtil {
  static Future<void> seedDatabase() async {
    final today = DateTime.now();
    Db.instance.delete(Db.noteTable);
    final batch = Db.instance.batch();
    batch.insert(
        Db.noteTable,
        Note(
                text: r'[{"insert":"food time\n"}]',
                date: DateTime(today.year, 1, 1))
            .toMap());
    batch.insert(
        Db.noteTable,
        Note(
                text:
                    r'[{"insert":"10:00 awake finally\ntime to eat n poo. Yummy\n"}]',
                date: today)
            .toMap());
    batch.insert(
        Db.noteTable,
        Note(
                text:
                    r'[{"insert":"10:30 fk i am zo energy ball attack party popper ok its ok\ntime to eat n poo. Yummy\n"}]',
                date: DateTime(today.year, 2, 2))
            .toMap());

    for (int i = 1; i < 8; i++) {
      batch.insert(
          Db.noteTable,
          Note(
                  text: '[{"insert":"hi $i\\n"}]',
                  date: DateTime(today.year, 3, i))
              .toMap());
    }
    await batch.commit(noResult: true);
  }
}
