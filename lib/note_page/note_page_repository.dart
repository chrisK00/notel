import 'package:notel/infrastructure/db.dart';
import 'package:notel/infrastructure/date_only.dart';

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

  static Future<Note> createNote({int? categoryId}) async {
    final now = DateTime.now();
    final today = DateOnly.today();
    final noteId = await Db.instance.insert(Db.noteTable, {
      'text': '',
      'date': today.toString(),
      'lastModified': now.toString(),
      'categoryId': categoryId,
    });
    final newNote = Note(id: noteId, date: today, lastModified: now, displayText: '', categoryId: categoryId);
    return newNote;
  }

  static Future<int> updateNoteCategory(int noteId, int? categoryId) async {
    final now = DateTime.now();
    return await Db.instance.update(
        Db.noteTable,
        {'categoryId': categoryId, 'lastModified': now.toString()},
        where: 'id = ?',
        whereArgs: [noteId]);
  }

  static Future<int> updateNoteText(int noteId, String jsonText) async {
    final now = DateTime.now();
    return await Db.instance.update(Db.noteTable, {'TEXT': jsonText, 'lastModified': now.toString()},
        where: 'id = ?', whereArgs: [noteId]);
  }

  static Future<int> updateNoteTitle(int noteId, String? title) async {
    final now = DateTime.now();
    return await Db.instance.update(Db.noteTable, {'title': title, 'lastModified': now.toString()},
        where: 'id = ?', whereArgs: [noteId]);
  }

  /// [date] comes from Flutter's date picker which returns a [DateTime].
  /// We strip the time component and store as DateOnly.
  static Future<int> updateNoteDate(int noteId, DateTime date) async {
    final now = DateTime.now();
    final dateOnly = DateOnly.fromDateTime(date);
    return await Db.instance.update(
        Db.noteTable,
        {'date': dateOnly.toString(), 'lastModified': now.toString()},
        where: 'id = ?',
        whereArgs: [noteId]);
  }
}
