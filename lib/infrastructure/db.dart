import 'package:notel/infrastructure/settings_repository.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class Db {
  static const databaseName = 'notel.db';
  static const noteTable = "Note";
  static const settingsTable = "Settings";

  // ignore: null_check_always_fails
  static Database instance = null!;

  static Future<void> _version2(Database db) async {
    db.execute("""CREATE TABLE Settings(
  id TEXT PRIMARY KEY, value TEXT
  )""");

    await SettingsRepository(db).insertOrUpdate(BoolSettings.hideNoteTextKey,
        BoolSettings(BoolSettings.hideNoteTextKey, false).toMap);
  }

  static Future<void> _setupDatabase(Database db, int version) async {
    db.execute("""CREATE TABLE Note(
  id INTEGER PRIMARY KEY, text TEXT, date TEXT
  )""");

    await _version2(db);
  }

  static Future<void> _upgradeDatabase(db, oldVersion, newVersion) async {
    if (oldVersion < 2) {
      await _version2(db);
    }
  }

  static Future initialize() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    instance = await openDatabase(
        path.join(documentsDirectory.path, databaseName),
        onCreate: _setupDatabase,
        onUpgrade: _upgradeDatabase,
        version: 2);
  }
}
