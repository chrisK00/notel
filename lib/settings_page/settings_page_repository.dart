import 'package:notel/infrastructure/db.dart';
import 'package:sqflite/sqflite.dart';

class SettingsPageRepository {
  static Future<List<Map<String, Object?>>> getNotes() async {
    return await Db.instance.query(Db.noteTable);
  }

  static Future<List<Map<String, Object?>>> getCategories() async {
    return await Db.instance.query(Db.categoryTable);
  }

  static Future<Map<String, Object?>> createBackupPayload() async {
    final notes = await getNotes();
    final categories = await getCategories();
    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'notes': notes,
      'categories': categories,
    };
  }

  static Future<void> restoreBackupPayload(dynamic decoded) async {
    if (decoded is List) {
      final notesJson = decoded.map<Map<String, Object?>>((e) => Map<String, Object?>.from(e)).toList();
      await insertNotes(notesJson);
    } else if (decoded is Map) {
      if (decoded['categories'] is List) {
        final categoriesJson = (decoded['categories'] as List)
            .map<Map<String, Object?>>((e) => Map<String, Object?>.from(e))
            .toList();
        await insertCategories(categoriesJson);
      }
      if (decoded['notes'] is List) {
        final notesJson = (decoded['notes'] as List)
            .map<Map<String, Object?>>((e) => Map<String, Object?>.from(e))
            .toList();
        await insertNotes(notesJson);
      }
    }
  }

  static Future<void> insertCategories(List<Map<String, Object?>> categories) async {
    final batch = Db.instance.batch();
    for (var cat in categories) {
      batch.insert(
        Db.categoryTable,
        cat,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<void> insertNotes(List<Map<String, Object?>> notes) async {
    final batch = Db.instance.batch();

    for (var note in notes) {
      batch.insert(
        Db.noteTable,
        note,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    await batch.commit(noResult: true);
  }
}
