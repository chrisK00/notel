import 'package:notel/infrastructure/db.dart';
import 'package:sqflite/sqflite.dart';

class SettingsPageRepository {
  static Future<List<Map<String, Object?>>> getNotes() async {
    return await Db.instance.query(Db.noteTable);
  }

  static Future<void> insertNotes(List<Map<String, Object?>> notes) async {
    final batch = Db.instance.batch();

    for (var note in notes) {
      batch.insert(
        Db.noteTable,
        note,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    await batch.commit(noResult: true);
  }
}
