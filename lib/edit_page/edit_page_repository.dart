import 'package:notel/infrastructure/db.dart';

class EditPageRepository {
  static Future<Note> getNoteById(int noteId) async {
    final getNoteResult = await Db.instance
        .query(Db.noteTable, where: "id= ?", whereArgs: [noteId], limit: 1);
    return Note.fromMap(getNoteResult.first);
  }
}
