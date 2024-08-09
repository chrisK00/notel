import 'package:notel/infrastructure/db.dart';

import '../infrastructure/note.dart';

class NotePageRepository {
  static Future<Note> getNoteById(int noteId) async {
    final getNoteResult = await Db.instance
        .query(Db.noteTable, where: "id= ?", whereArgs: [noteId], limit: 1);
    return Note.fromMap(getNoteResult.first);
  }

  static Future deleteNote(int noteId) async {
    await Db.instance
        .delete(Db.noteTable, where: 'id = ?', whereArgs: [noteId]);
  }

  static Future<Note> createNote() async {
    final now = DateTime.now();
    final noteId = await Db.instance.insert(Db.noteTable, {
      'id': null,
      'text': '',
      'date': now.toString(),
    });
    final newNote = Note(id: noteId, date: now, displayText: '');
    return newNote;
  }

  static Future<int> updateNoteText(int noteId, String jsonText) async {
    return await Db.instance.update(Db.noteTable, {'TEXT': jsonText},
        where: 'id = ?', whereArgs: [noteId]);
  }

  static Future<int> updateNoteDate(int noteId, DateTime date) async {
    return await Db.instance.update(Db.noteTable, {'date': date.toString()},
        where: 'id = ?', whereArgs: [noteId]);
  }
}
