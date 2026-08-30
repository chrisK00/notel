import 'package:notel/infrastructure/db.dart';
import 'package:notel/infrastructure/date_only.dart';

import '../infrastructure/note.dart';
import '../infrastructure/settings_repository.dart';

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
    var hidden = 0;
    if (categoryId != null) {
      final setting = await SettingsRepository(Db.instance).getOrNull(
          StringSettings.categoryHiddenDefaultKey(categoryId), StringSettings.fromMap);
      hidden = setting?.value == 'true' ? 1 : 0;
    }
    final noteId = await Db.instance.insert(Db.noteTable, {
      'text': '',
      'date': today.toString(),
      'lastModified': now.toString(),
      'categoryId': categoryId,
      'hidden': hidden,
    });
    final newNote = Note(id: noteId, date: today, lastModified: now, displayText: '', categoryId: categoryId, hidden: hidden == 1);
    return newNote;
  }

  static Future<int> updateNoteCategory(int noteId, int? categoryId) async {
    final now = DateTime.now();
    return await Db.instance.update(
        Db.noteTable,
        {'categoryId': categoryId, 'lastModified': now.toString(), if (categoryId == null) 'hidden': 0},
        where: 'id = ?',
        whereArgs: [noteId]);
  }

  static Future<int> setHiddenFromHome(int noteId, bool hidden) => Db.instance.update(
        Db.noteTable, {'hidden': hidden ? 1 : 0}, where: 'id = ?', whereArgs: [noteId]);

  static Future<int> setCategoryNotesHidden(int categoryId, bool hidden) => Db.instance.update(
      Db.noteTable, {'hidden': hidden ? 1 : 0}, where: 'categoryId = ?', whereArgs: [categoryId]);

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
