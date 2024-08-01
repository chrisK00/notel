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

class Note {
  Note({this.id, this.text = "", DateTime? date})
      : date = date ?? DateTime.now();
  int? id;
  String text = "";
  DateTime date = DateTime.now();

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'text': text,
      'date': date.toString(),
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      text: map['text'] ?? '',
      date: DateTime.parse(map['date']),
    );
  }

  @override
  String toString() {
    return 'Note{id: $id, date: $date, text length: ${text.length}}';
  }
}
