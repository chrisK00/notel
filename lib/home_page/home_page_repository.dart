import 'package:notel/infrastructure/db.dart';
import 'package:notel/search/search_query.dart';

import '../infrastructure/note.dart';

// TODO repo names are a bit weird rn. should be one repo tbh. same with the <Note> data type better to have VM?
class HomePageRepository {
  static const _previewSql = r'''
        CASE
          WHEN json_valid(Note.text) = 1 THEN
            substr(
              coalesce(
                (
                  SELECT group_concat(json_extract(json_data.value, '$.insert'), ' ')
                  FROM (
                    SELECT value
                    FROM json_each(CASE WHEN json_valid(Note.text) = 1 THEN Note.text ELSE '[]' END)
                    LIMIT 4
                  ) AS json_data
                ),
                ''
              ),
              0,
              100
            )
          ELSE coalesce(Note.text, '')
        END
      ''';

  static const int pageSize = 30;

  static Future<Iterable<Note>> loadNotes({int offset = 0, int? categoryId}) async {
    final where = categoryId != null ? 'WHERE categoryId = ?' : '';
    final args = categoryId != null ? [categoryId, pageSize, offset] : [pageSize, offset];
    final rows = await Db.instance.rawQuery('''
        SELECT
          id,
          $_previewSql text,
          date,
          lastModified,
          title,
          categoryId
        FROM NOTE
        $where
        ORDER BY date DESC, id DESC
        LIMIT ? OFFSET ?
        ''', args);

    return rows.map(Note.fromMap);
  }

  static Future<Note?> loadNote(int noteId) async {
    final rows = await Db.instance.rawQuery('''
        SELECT
          id,
          $_previewSql text,
          date,
          lastModified,
          title,
          categoryId
        FROM NOTE
        WHERE id = ?
        ''', [noteId]);

    return rows.length == 1 ? rows.map(Note.fromMap).first : null;
  }

  /// Searches notes using a structured [SearchQuery].
  ///
  /// Builds a parameterized SQL WHERE clause from the query fields:
  ///   - titleTerm     → title LIKE '%term%'
  ///   - startsWithTerm → first delta insert starts with term
  ///   - dateFrom/To   → date column range
  ///   - textOrGroups  → each group is an OR of LIKE checks on title + body deltas
  static Future<Iterable<Note>> findNotes(SearchQuery query, {int? categoryId}) async {
    if (query.isEmpty) return loadNotes(categoryId: categoryId);

    final conditions = <String>[];
    final args = <Object>[];

    if (categoryId != null) {
      conditions.add('categoryId = ?');
      args.add(categoryId);
    }

    // Title filter (OR across multiple title terms).
    if (query.titleTerms.isNotEmpty) {
      final clauses = query.titleTerms.map((_) => 'title LIKE ?').join(' OR ');
      conditions.add('($clauses)');
      for (final t in query.titleTerms) {
        args.add('%$t%');
      }
    }

    // Date range filter.
    // The date column is stored via DateTime.toString() which uses a space
    // separator: "2025-08-26 22:00:00.000". Use the same format for comparisons.
    if (query.dateFrom != null) {
      conditions.add("date >= ?");
      args.add(query.dateFrom!.toString());
    }
    if (query.dateTo != null) {
      conditions.add("date <= ?");
      args.add(query.dateTo!.toString());
    }

    // lastModified range filter.
    if (query.modifiedFrom != null) {
      conditions.add("lastModified >= ?");
      args.add(query.modifiedFrom!.toString());
    }
    if (query.modifiedTo != null) {
      conditions.add("lastModified <= ?");
      args.add(query.modifiedTo!.toString());
    }

    // startswith: checks whether the first text delta starts with any of the terms (OR).
    if (query.startsWithTerms.isNotEmpty) {
      final clauses = query.startsWithTerms.map((_) => '''
        json_extract(
          (SELECT value FROM json_each(CASE WHEN json_valid(Note.text) = 1 THEN Note.text ELSE '[]' END) LIMIT 1),
          '\$.insert'
        ) LIKE ?
      ''').join(' OR ');
      conditions.add('($clauses)');
      for (final t in query.startsWithTerms) {
        args.add('$t%');
      }
    }

    // Exclusion terms — must not appear in title or any delta insert.
    for (final term in query.excludeTerms) {
      conditions.add('''
        (title NOT LIKE ? OR title IS NULL)
        AND NOT EXISTS (
          SELECT 1 FROM json_each(CASE WHEN json_valid(Note.text) = 1 THEN Note.text ELSE '[]' END) AS jd
          WHERE json_extract(jd.value, '\$.insert') LIKE ?
        )
      ''');
      args.add('%$term%');
      args.add('%$term%');
    }

    // Text OR groups. Each group produces one AND condition made of OR clauses.
    for (final orGroup in query.textOrGroups) {
      final orClauses = <String>[];
      for (final phrase in orGroup) {
        // Match in title.
        orClauses.add('title LIKE ?');
        args.add('%$phrase%');
        // Match anywhere in the delta inserts.
        orClauses.add('''
          EXISTS (
            SELECT 1 FROM json_each(CASE WHEN json_valid(Note.text) = 1 THEN Note.text ELSE '[]' END) AS jd
            WHERE json_extract(jd.value, '\$.insert') LIKE ?
          )
        ''');
        args.add('%$phrase%');
      }
      conditions.add('(${orClauses.join(' OR ')})');
    }

    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

    final sql = '''
      SELECT
        NOTE.id,
        $_previewSql text,
        date,
        lastModified,
        title,
        categoryId
      FROM Note
      $where
      ORDER BY Note.date DESC, Note.id DESC
    ''';

    final rows = await Db.instance.rawQuery(sql, args);
    return rows.map(Note.fromMap);
  }
}
