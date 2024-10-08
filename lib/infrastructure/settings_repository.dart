import 'package:notel/infrastructure/db.dart';
import 'package:sqflite/sqflite.dart';

class BoolSettings {
  BoolSettings(this.id, this.value);
  String id;
  bool value;

  static const hideNoteTextKey = "hideNoteText";

  factory BoolSettings.fromMap(Map<String, dynamic> map) => BoolSettings(
        map['id'],
        bool.parse(map['value']),
      );

  Map<String, Object?> toMap() => {'id': id, 'value': value.toString()};
}

class SettingsRepository {
  SettingsRepository(this.db);
  Database db;

  Future<T> get<T>(
      String settingsId, T Function(Map<String, dynamic>) fromMap) async {
    final getSettingsResult = await db.query(Db.settingsTable,
        where: "id= ?", whereArgs: [settingsId], limit: 1);

    return fromMap(getSettingsResult.first);
  }

  Future<void> insertOrUpdate(
      String id, Map<String, Object?> Function() toMap) async {
    await db.insert(Db.settingsTable, toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
