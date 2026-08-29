import 'package:flutter_test/flutter_test.dart';
import 'package:notel/infrastructure/category_repository.dart';
import 'package:notel/infrastructure/db.dart';
import 'package:notel/home_page/home_page_repository.dart';
import 'package:notel/note_page/note_page_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Test DB version 5 setup and note creation in category', () async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 5,
      onCreate: (db, version) async {
        await db.execute("""CREATE TABLE Note(
  id INTEGER PRIMARY KEY, text TEXT, date TEXT
  )""");
        await db.execute("""CREATE TABLE Settings(
  id TEXT PRIMARY KEY, value TEXT
  )""");
        await db.execute("""ALTER TABLE Note
  ADD COLUMN title TEXT""");
        await db.execute("""ALTER TABLE Note
  ADD COLUMN lastModified TEXT""");
        await db.execute("""CREATE TABLE IF NOT EXISTS Category(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL
  )""");
        await db.execute("""ALTER TABLE Note
  ADD COLUMN categoryId INTEGER""");
      },
    );

    Db.instance = db;

    // Create a category
    final cat = await CategoryRepository.create('Work');
    expect(cat.id, greaterThan(0));

    // Create note in category
    final note = await NotePageRepository.createNote(categoryId: cat.id);
    expect(note.id, greaterThan(0));
    expect(note.categoryId, cat.id);

    // Create note without category
    final note2 = await NotePageRepository.createNote();
    expect(note2.id, greaterThan(0));
    expect(note2.categoryId, isNull);

    // Deleting category deletes its notes
    await CategoryRepository.delete(cat.id);
    final remainingCategories = await CategoryRepository.getAll();
    expect(remainingCategories.any((c) => c.id == cat.id), isFalse);

    // Verify note in category is deleted
    final note1Rows = await db.query('Note', where: 'id = ?', whereArgs: [note.id]);
    expect(note1Rows.isEmpty, isTrue);

    // Verify note without category is intact
    final note2Rows = await db.query('Note', where: 'id = ?', whereArgs: [note2.id]);
    expect(note2Rows.isNotEmpty, isTrue);

    await db.close();
  });

  test('HomePageRepository loads note with empty or non-JSON text', () async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 5,
      onCreate: (db, version) async {
        await db.execute("""CREATE TABLE Note(
  id INTEGER PRIMARY KEY, text TEXT, date TEXT, title TEXT, lastModified TEXT, categoryId INTEGER
  )""");
        await db.execute("""CREATE TABLE IF NOT EXISTS Category(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL
  )""");
      },
    );

    Db.instance = db;

    final cat = await CategoryRepository.create('Personal');
    final note = await NotePageRepository.createNote();
    await NotePageRepository.updateNoteCategory(note.id, cat.id);

    final loaded = await HomePageRepository.loadNote(note.id);
    expect(loaded, isNotNull);
    expect(loaded!.categoryId, cat.id);
    expect(loaded.displayText, '');

    final notes = await HomePageRepository.loadNotes(categoryId: cat.id);
    expect(notes.length, 1);

    await db.close();
  });
}
