import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class Db {
  static const databaseName = 'notel.db';
  static const noteTable = "Note";

  // ignore: null_check_always_fails
  static Database instance = null!;

  static void _setupDatabase(Database db, int version) {
    db.execute("""CREATE TABLE Note(
  id INTEGER PRIMARY KEY, text TEXT, date TEXT
  )""");
  }

  static Future initialize() async {
    instance = await openDatabase(
        path.join(await getDatabasesPath(), databaseName),
        onCreate: _setupDatabase,
        version: 1);
  }
}
