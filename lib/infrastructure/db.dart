import 'package:notel/infrastructure/settings_repository.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class Db {
  static const databaseName = 'notel.db';
  static const debugDatabaseName = 'notel_debug.db';
  static const noteTable = "Note";
  static const settingsTable = "Settings";
  static const categoryTable = "Category";

  // ignore: null_check_always_fails
  static Database instance = null!;

  static Future<void> _upgradeDatabase(db, oldVersion, newVersion) async {
    if (oldVersion < 2) {
      await _version2(db);
    }

    if (oldVersion < 3) {
      await _version3(db);
    }

    if (oldVersion < 4) {
      await _version4(db);
    }

    if (oldVersion < 5) {
      await _version5(db);
    }
    if (oldVersion < 6) {
      await _version6(db);
    }
  }

  static Future<void> _setupDatabase(Database db, int version) async {
    await db.execute("""CREATE TABLE Note(
  id INTEGER PRIMARY KEY, text TEXT, date TEXT
  )""");

    await _version2(db);
    await _version3(db);
    await _version4(db);
    await _version5(db);
  }

  static Future<void> _version2(Database db) async {
    await db.execute("""CREATE TABLE Settings(
  id TEXT PRIMARY KEY, value TEXT
  )""");

    await SettingsRepository(db).insertOrUpdate(BoolSettings.hideNoteTextKey,
        BoolSettings(BoolSettings.hideNoteTextKey, false).toMap);
  }

  static Future<void> _version3(Database db) async {
    await db.execute("""ALTER TABLE Note
  ADD COLUMN title TEXT""");
  }

  static Future<void> _version4(Database db) async {
    await db.execute("""ALTER TABLE Note
  ADD COLUMN lastModified TEXT""");
  }

  static Future<void> _version5(Database db) async {
    await db.execute("""CREATE TABLE IF NOT EXISTS Category(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL
  )""");
    final columns = await db.rawQuery("PRAGMA table_info(Note)");
    final hasCategoryId = columns.any((c) => c['name'] == 'categoryId');
    if (!hasCategoryId) {
      await db.execute("ALTER TABLE Note ADD COLUMN categoryId INTEGER");
    }
  }

  static Future<void> _version6(Database db) async {
    final columns = await db.rawQuery("PRAGMA table_info(Note)");
    if (!columns.any((c) => c['name'] == 'hidden')) {
      await db.execute("ALTER TABLE Note ADD COLUMN hidden INTEGER NOT NULL DEFAULT 0");
    }
  }

  static Future initialize({bool useDebugDatabase = false}) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final dbName = useDebugDatabase ? debugDatabaseName : databaseName;
    instance = await openDatabase(
        path.join(documentsDirectory.path, dbName),
        onCreate: _setupDatabase,
        onUpgrade: _upgradeDatabase,
        onOpen: (db) async {
          await db.execute("""CREATE TABLE IF NOT EXISTS Category(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          )""");
          final columns = await db.rawQuery("PRAGMA table_info(Note)");
          final hasCategoryId = columns.any((c) => c['name'] == 'categoryId');
          if (!hasCategoryId) {
            await db.execute("ALTER TABLE Note ADD COLUMN categoryId INTEGER");
          }
          final hasLastModified = columns.any((c) => c['name'] == 'lastModified');
          if (!hasLastModified) {
            await db.execute("ALTER TABLE Note ADD COLUMN lastModified TEXT");
          }
          final hasHidden = columns.any((c) => c['name'] == 'hidden');
          if (!hasHidden) await db.execute("ALTER TABLE Note ADD COLUMN hidden INTEGER NOT NULL DEFAULT 0");
        },
        version: 6);
  }
}
