import 'package:flutter_test/flutter_test.dart';
import 'package:notel/activity_log/activity_log_repository.dart';
import 'package:notel/infrastructure/db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE Note(
            id INTEGER PRIMARY KEY,
            text TEXT,
            date TEXT,
            lastModified TEXT,
            title TEXT,
            categoryId INTEGER,
            hidden INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
    Db.instance = db;
  });

  tearDown(() async {
    await db.close();
  });

  test('loads activity notes across months and skips hidden or unrelated notes',
      () async {
    await db.insert('Note', {
      'text': '[{"insert":"08:00 start zo\\n"}]',
      'date': '2026-10-03',
    });
    await db.insert('Note', {
      'text': '[{"insert":"stop zo\\n"}]',
      'date': '2026-12-01',
    });
    await db.insert('Note', {
      'text': '[]',
      'date': '2026-11-03',
    });
    await db.insert('Note', {
      'text': '[{"insert":"start hidden\\n"}]',
      'date': '2026-11-10',
      'hidden': 1,
    });

    final notes = await ActivityLogRepository.loadActivityNotes();

    expect(notes.map((note) => note.date.toString()),
        ['2026-10-03', '2026-12-01']);
  });
}
