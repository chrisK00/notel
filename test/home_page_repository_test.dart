import 'package:flutter_test/flutter_test.dart';
import 'package:notel/infrastructure/category_repository.dart';
import 'package:notel/infrastructure/date_only.dart';
import 'package:notel/infrastructure/db.dart';
import 'package:notel/home_page/home_page_repository.dart';
import 'package:notel/search/search_query_parser.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE Note(
            id INTEGER PRIMARY KEY,
            text TEXT,
            date TEXT,
            title TEXT,
            lastModified TEXT,
            categoryId INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE Settings(
            id TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS Category(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          )
        ''');
      },
    );
    Db.instance = db;

    // Seed test categories
    await db.insert('Category', {'id': 1, 'name': 'Work'});
    await db.insert('Category', {'id': 2, 'name': 'Personal'});

    // Seed test notes
    // Note 1: Work meeting
    await db.insert('Note', {
      'id': 1,
      'title': 'Sprint Planning Meeting',
      'text': r'[{"insert":"Discuss Q3 objectives and roadmap deliverables\n"}]',
      'date': '2026-08-28',
      'lastModified': '2026-08-28 10:00:00.000',
      'categoryId': 1,
    });

    // Note 2: Personal groceries with apples
    await db.insert('Note', {
      'id': 2,
      'title': 'Shopping List',
      'text': r'[{"insert":"Buy fresh apples and organic milk\n"}]',
      'date': '2026-08-27',
      'lastModified': '2026-08-27 15:30:00.000',
      'categoryId': 2,
    });

    // Note 3: Personal groceries with oranges
    await db.insert('Note', {
      'id': 3,
      'title': 'Weekend Market',
      'text': r'[{"insert":"Get oranges and coffee beans\n"}]',
      'date': '2026-08-20',
      'lastModified': '2026-08-20 09:00:00.000',
      'categoryId': 2,
    });

    // Note 4: Health note with exclusion word
    await db.insert('Note', {
      'id': 4,
      'title': 'Health Log',
      'text': r'[{"insert":"Doctor visit notes, avoid sugar and junk food\n"}]',
      'date': '2026-05-15',
      'lastModified': '2026-05-15 14:00:00.000',
      'categoryId': null,
    });
  });

  tearDown(() async {
    await db.close();
  });

  group('HomePageRepository Integration Tests', () {
    test('loadNotes returns notes in descending date order with pagination', () async {
      final allNotes = (await HomePageRepository.loadNotes(offset: 0)).toList();
      expect(allNotes.length, 4);
      expect(allNotes[0].id, 1); // 2026-08-28
      expect(allNotes[1].id, 2); // 2026-08-27
      expect(allNotes[2].id, 3); // 2026-08-20
      expect(allNotes[3].id, 4); // 2026-05-15

      final page = (await HomePageRepository.loadNotes(offset: 2)).toList();
      expect(page.length, 2);
      expect(page[0].id, 3);
      expect(page[1].id, 4);
    });

    test('loadNotes returns notes with same date ordered by id, not lastModified', () async {
      await db.insert('Note', {
        'id': 10,
        'title': 'Older Note',
        'text': '[]',
        'date': '2026-08-29',
        'lastModified': '2026-08-29 10:15:45.000',
      });
      await db.insert('Note', {
        'id': 11,
        'title': 'Newer Note',
        'text': '[]',
        'date': '2026-08-29',
        'lastModified': '2026-08-29 10:15:10.000',
      });

      final notes = (await HomePageRepository.loadNotes(offset: 0)).toList();
      expect(notes[0].id, 11);
      expect(notes[1].id, 10);
    });

    test('loadNotes with categoryId filter returns only category notes', () async {
      final workNotes = (await HomePageRepository.loadNotes(categoryId: 1)).toList();
      expect(workNotes.length, 1);
      expect(workNotes[0].title, 'Sprint Planning Meeting');

      final personalNotes = (await HomePageRepository.loadNotes(categoryId: 2)).toList();
      expect(personalNotes.length, 2);
      expect(personalNotes.map((n) => n.id), containsAll([2, 3]));
    });

    test('loadNote by ID retrieves specific note', () async {
      final note = await HomePageRepository.loadNote(2);
      expect(note, isNotNull);
      expect(note!.title, 'Shopping List');
      expect(note.categoryId, 2);

      final nonexistent = await HomePageRepository.loadNote(999);
      expect(nonexistent, isNull);
    });

    test('findNotes with empty query returns all notes', () async {
      final query = SearchQueryParser.parse('');
      final results = (await HomePageRepository.findNotes(query)).toList();
      expect(results.length, 4);
    });

    test('findNotes by title filter', () async {
      final query = SearchQueryParser.parse("title:'Shopping'");
      final results = (await HomePageRepository.findNotes(query)).toList();
      expect(results.length, 1);
      expect(results[0].title, 'Shopping List');
    });

    test('findNotes by text search in note body', () async {
      final query = SearchQueryParser.parse('deliverables');
      final results = (await HomePageRepository.findNotes(query)).toList();
      expect(results.length, 1);
      expect(results[0].id, 1);
    });

    test('findNotes with OR text group matches any term', () async {
      final query = SearchQueryParser.parse('apples || oranges');
      final results = (await HomePageRepository.findNotes(query)).toList();
      expect(results.length, 2);
      expect(results.map((n) => n.id), containsAll([2, 3]));
    });

    test('findNotes with date range filter', () async {
      final query = SearchQueryParser.parse('date:2026-08-01..2026-08-31');
      final results = (await HomePageRepository.findNotes(query)).toList();
      expect(results.length, 3);
      expect(results.map((n) => n.id), containsAll([1, 2, 3]));
    });

    test('findNotes with exclusion filter (-term)', () async {
      // Find personal notes without 'oranges'
      final query = SearchQueryParser.parse('-oranges');
      final results = (await HomePageRepository.findNotes(query, categoryId: 2)).toList();
      expect(results.length, 1);
      expect(results[0].id, 2); // Only 'Shopping List' remains
    });

    test('findNotes with startswith filter', () async {
      final query = SearchQueryParser.parse('startswith:Discuss');
      final results = (await HomePageRepository.findNotes(query)).toList();
      expect(results.length, 1);
      expect(results[0].id, 1);
    });
  });
}
