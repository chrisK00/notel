import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

// i think this should be a singleton and DB should never be closed unless app is disposed
class Db {
  static const databaseName = 'notel.db';
  static const noteTable = "Note";

  static void _setupDatabase(Database db, int version) {
    db.execute("""CREATE TABLE Note(
  id INTEGER PRIMARY KEY, text TEXT, date TEXT
  )""");
  }

// https://docs.flutter.dev/cookbook/persistence/sqlite
  //https://medium.com/@dpatel312002/guide-for-sqflite-in-flutter-59e429db1088
  static Future<Database> open() async {
    final database = await openDatabase(
        path.join(await getDatabasesPath(), databaseName),
        onCreate: _setupDatabase,
        version: 1);

    return database;
  }

  static Future<void> seed(Database db) async {
    db.database.delete(noteTable);
    final batch = db.batch();
    batch.insert(
        Db.noteTable,
        Note(
                text: "10:00 awake finally\ntime to eat n poo. Yummy",
                date: DateTime.now())
            .toMap());
    batch.insert(
        Db.noteTable, Note(text: "food time", date: DateTime.now()).toMap());
    batch.insert(Db.noteTable,
        Note(text: "where are my keys", date: DateTime.now()).toMap());
    await batch.commit(noResult: true);
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
      text: map['text'] ?? '', // should never be null need to fix
      date: DateTime.parse(map['date']),
    );
  }

  @override
  String toString() {
    return 'Note{id: $id, date: $date, text length: ${text.length}}';
  }
}
