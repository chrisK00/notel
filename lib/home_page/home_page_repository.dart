import 'package:notel/infrastructure/db.dart';

import '../infrastructure/note.dart';

// TODO repos names are a bit weird rn. should be one repo tbh. same with the <Note> data type better to have VM?
class HomePageRepository {
  static Future<Iterable<Note>> loadNotes() async {
    // TODO should select 36 chars from every insert not just first insert. lösning finns ju nedanför
    final rows = await Db.instance.rawQuery(r'''
        SELECT
          id,
          substr((CASE WHEN LENGTH(text) > 0 THEN json_extract(text, '$[0].insert') ELSE '' END), 0, 36) text,
          date,
          title
        FROM NOTE
        ORDER BY date DESC
        ''');

    return rows.map(Note.fromMap);
  }

  static Future<Note?> loadNote(int noteId) async {
    final rows = await Db.instance.rawQuery(r'''
        SELECT
          id,
          substr((CASE WHEN LENGTH(text) > 0 THEN json_extract(text, '$[0].insert') ELSE '' END), 0, 100) text,
          date,
          title
        FROM NOTE
        WHERE id = ?
        ''', [noteId]);

    return rows.length == 1 ? rows.map(Note.fromMap).first : null;
  }

  static Future<Iterable<Note>> findNotesByText(text) async {
    {
      final rows = await Db.instance.rawQuery(r'''
        SELECT
          NOTE.id,
          substr((CASE WHEN LENGTH(text) > 0 THEN json_extract(text, '$[0].insert') ELSE '' END), 0, 100) text,
          date,
          title
        FROM Note,
        json_each(Note.text) AS json_data
        WHERE json_extract(json_data.value, '$.insert') LIKE ? OR title LIKE ?
        ORDER BY Note.date DESC
        ''', ['%$text%', '%$text%']);
      return rows.map(Note.fromMap);
    }
  }
}
