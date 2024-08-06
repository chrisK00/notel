import 'package:notel/infrastructure/db.dart';

import '../infrastructure/note.dart';

class HomePageRepository {
  static Future<Iterable<Note>> loadNotes() async {
    // TODO should select 36 chars from every insert not just first insert. lösning finns ju nedanför
    final rows = await Db.instance.rawQuery(r'''SELECT
        id,
        substr((CASE WHEN LENGTH(text) > 0 THEN json_extract(text, '$[0].insert') ELSE '' END), 0, 36) text,
        date
        FROM NOTE
        ORDER BY date DESC
        ''');

    return rows.map(Note.fromMap);
  }

  static Future<Note> loadNote(int noteId) async {
    final rows = await Db.instance.rawQuery(r'''SELECT
        id,
        substr((CASE WHEN LENGTH(text) > 0 THEN json_extract(text, '$[0].insert') ELSE '' END), 0, 36) text,
        date
        FROM NOTE
        WHERE id = ?
        ''', [noteId]);

    return rows.map(Note.fromMap).first;
  }

  static Future<Iterable<int>> findNoteIdsByText(text) async {
    {
      final rows = await Db.instance.rawQuery(r'''SELECT Note.id
FROM Note,
     json_each(Note.text) AS json_data
WHERE json_extract(json_data.value, '$.insert') LIKE ?
ORDER BY Note.date DESC
        ''', ['%$text%']);
      return rows.map((row) => int.parse(row['id'].toString()));
    }
  }
}
