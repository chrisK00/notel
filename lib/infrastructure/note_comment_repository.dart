import 'package:notel/infrastructure/db.dart';
import 'package:notel/infrastructure/note_comment.dart';

class NoteCommentRepository {
  static Future<List<NoteComment>> forNote(int noteId) async {
    final rows = await Db.instance.query(
      Db.commentTable,
      where: 'noteId = ?',
      whereArgs: [noteId],
      orderBy: 'id ASC',
    );
    return rows.map(NoteComment.fromMap).toList();
  }

  static Future<void> create({
    required int noteId,
    int? parentId,
    required String quotedText,
    required int startOffset,
    required int endOffset,
    required String body,
  }) async {
    await Db.instance.insert(Db.commentTable, {
      'noteId': noteId,
      'parentId': parentId,
      'quotedText': quotedText,
      'startOffset': startOffset,
      'endOffset': endOffset,
      'body': body,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> deleteForNote(int noteId) async {
    final tables = await Db.instance.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [Db.commentTable],
    );
    if (tables.isEmpty) return;
    await Db.instance.delete(
      Db.commentTable,
      where: 'noteId = ?',
      whereArgs: [noteId],
    );
  }
}
