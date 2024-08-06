import 'package:notel/infrastructure/db.dart';

import '../infrastructure/note.dart';

class EditPageRepository {
  static Future<Note> getNoteById(int noteId) async {
    final getNoteResult = await Db.instance
        .query(Db.noteTable, where: "id= ?", whereArgs: [noteId], limit: 1);
    return Note.fromMap(getNoteResult.first);
  }

  static Future deleteNote(int noteId) async {
    await Db.instance
        .delete(Db.noteTable, where: 'id = ?', whereArgs: [noteId]);
  }

  static Future<int> createNote(Note note) async {
    return await Db.instance.insert(Db.noteTable, note.toMap());
  }

  static Future<int> updateNote(int noteId, String jsonText) async {
    return await Db.instance.update(Db.noteTable, {'TEXT': jsonText},
        where: 'id = ?', whereArgs: [noteId]);
  }
}
