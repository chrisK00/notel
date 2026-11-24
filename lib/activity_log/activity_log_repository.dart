import 'package:notel/infrastructure/db.dart';
import 'package:notel/infrastructure/note.dart';

class ActivityLogRepository {
  static Future<List<Note>> loadActivityNotes() async {
    final rows = await Db.instance.rawQuery(
      '''
      SELECT id, text, date, lastModified, title, categoryId, hidden
      FROM Note
      WHERE hidden = 0 AND (lower(text) LIKE '%start %' OR lower(text) LIKE '%stop %')
      ORDER BY date ASC, id ASC
      ''',
    );
    return rows.map(Note.fromMap).toList();
  }
}
