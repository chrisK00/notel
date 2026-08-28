import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notel/home_page/home_page.dart';
import 'package:notel/infrastructure/date_only.dart';
import 'package:notel/infrastructure/db.dart';
import 'package:notel/infrastructure/note.dart';
import 'package:notel/notes_provider.dart';
import 'package:provider/provider.dart';
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

    // Seed notes
    await db.insert('Note', {
      'id': 1,
      'title': 'Flutter Architecture',
      'text': r'[{"insert":"Deep dive into state management and performance\n"}]',
      'date': DateOnly.today().toString(),
      'lastModified': '2026-08-28 12:00:00.000',
      'categoryId': null,
    });

    await db.insert('Note', {
      'id': 2,
      'title': 'Grocery Run',
      'text': r'[{"insert":"Almond milk, avocados, dark chocolate\n"}]',
      'date': '2026-08-15',
      'lastModified': null,
      'categoryId': null,
    });

    await db.insert('Note', {
      'id': 3,
      'title': null,
      'text': r'[{"insert":"Quick note preview text\n"}]',
      'date': '2026-08-10',
      'lastModified': null,
      'categoryId': null,
    });

    // Default settings
    await db.insert('Settings', {'id': 'hideNoteText', 'value': 'false'});
    await db.insert('Settings', {'id': 'autoBackupEnabled', 'value': 'false'});
    await db.insert('Settings', {'id': 'lastExportReminder', 'value': DateTime.now().toString()});
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('HomePage displays note cards with title, date, and preview', (tester) async {
    final notesProvider = NotesProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<NotesProvider>.value(
        value: notesProvider,
        child: const MaterialApp(
          home: HomePage(),
        ),
      ),
    );

    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();

    // Verify note titles are displayed
    expect(find.text('Flutter Architecture'), findsOneWidget);
    expect(find.text('Grocery Run'), findsOneWidget);

    // Verify note preview is displayed for note without title
    expect(find.text('Quick note preview text\n'), findsOneWidget);

    // Verify today's note displays 'today' label
    expect(find.text('today'), findsOneWidget);

    // Verify day numbers
    expect(find.text(DateOnly.today().day.toString()), findsWidgets);
    expect(find.text('15'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);

    // Verify last edited timestamp is shown for Note 1
    expect(find.textContaining('Last edited'), findsOneWidget);
  });

  testWidgets('HomePage search bar filters notes with 300ms debounce', (tester) async {
    final notesProvider = NotesProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<NotesProvider>.value(
        value: notesProvider,
        child: const MaterialApp(
          home: HomePage(),
        ),
      ),
    );

    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();

    // Both notes should be visible initially
    expect(find.text('Flutter Architecture'), findsOneWidget);
    expect(find.text('Grocery Run'), findsOneWidget);

    // Type query into search bar
    final searchInput = find.byType(TextField).first;
    await tester.enterText(searchInput, 'Grocery');
    await tester.pump();

    // Before debounce (100ms), still showing both
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Flutter Architecture'), findsOneWidget);

    // Advance past 300ms debounce
    await tester.pump(const Duration(milliseconds: 250));
    // Let async DB query run
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();

    // Filtered: only 'Grocery Run' should be visible
    expect(find.text('Grocery Run'), findsOneWidget);
    expect(find.text('Flutter Architecture'), findsNothing);

    // Clear search
    final clearBtn = find.byIcon(Icons.clear);
    expect(clearBtn, findsOneWidget);
    await tester.tap(clearBtn);
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();

    // Both notes restored
    expect(find.text('Flutter Architecture'), findsOneWidget);
    expect(find.text('Grocery Run'), findsOneWidget);
  });
}
